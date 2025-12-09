from fastapi import FastAPI, HTTPException, Depends, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from app.models import ChatRequest, ChatResponse, SubscriptionStatusResponse
from app.agent import app_graph
from app.auth import get_current_user, check_usage_limit, increment_usage
from app.subscription import (
    create_checkout_session,
    handle_stripe_webhook,
    cancel_subscription,
    get_subscription_status
)
from app.database import get_db, User, UsageLog
from app.middleware import SecurityHeadersMiddleware
from app.rate_limit import limiter, get_user_id_for_rate_limit
from app.config import settings
from langchain_core.messages import HumanMessage, AIMessage, ToolMessage
from app.tools.legal_search import search_case_law
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware
from slowapi import Limiter, _rate_limit_exceeded_handler
from datetime import datetime

app = FastAPI(title="Cicero API", version="2.0")

# Add rate limit exception handler
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
app.add_middleware(SlowAPIMiddleware)

# Add security headers middleware
app.add_middleware(SecurityHeadersMiddleware)

# CORS configuration
allowed_origins = [origin.strip() for origin in settings.ALLOWED_ORIGINS.split(",")]
app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.exception_handler(RateLimitExceeded)
async def rate_limit_handler(request: Request, exc: RateLimitExceeded):
    response = JSONResponse(
        status_code=status.HTTP_429_TOO_MANY_REQUESTS,
        content={"detail": "Rate limit exceeded. Please try again later."}
    )
    response = request.app.state.limiter._inject_headers(
        response, request.state.view_rate_limit
    )
    return response


@app.get("/")
def health_check():
    return {"status": "online", "system": "Cicero 2.0 Agentic Brain"}


@app.get("/auth/verify")
async def verify_auth(current_user: User = Depends(get_current_user)):
    """Verify authentication token"""
    return {
        "authenticated": True,
        "user_id": current_user.id,
        "email": current_user.email,
        "subscription_tier": current_user.subscription_tier.value
    }


@app.post("/chat", response_model=ChatResponse)
@limiter.limit("100/hour", key_func=get_user_id_for_rate_limit)
async def chat_endpoint(
    request: Request,
    chat_request: ChatRequest,
    current_user: User = Depends(get_current_user),
    db = Depends(get_db)
):
    """Chat endpoint with authentication and usage limits"""
    try:
        # Check usage limits
        if not check_usage_limit(current_user, db):
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="Daily query limit reached. Upgrade to Premium for unlimited queries."
            )

        # Convert request history and current message to LangGraph format
        history_messages = []
        for item in chat_request.history:
            if isinstance(item, dict) and "role" in item and "content" in item:
                if item["role"] == "user":
                    history_messages.append(HumanMessage(content=item["content"]))
                elif item["role"] == "assistant":
                    history_messages.append(AIMessage(content=item["content"]))
        
        # Include the user's state in the message context
        user_state = chat_request.state or "US"
        current_message = HumanMessage(content=f"[User is in {user_state}] {chat_request.message}")
        messages = history_messages + [current_message]
        inputs = {"messages": messages, "user_state": user_state}

        # Run the agent with recursion limit to prevent infinite loops
        try:
            final_state = await app_graph.ainvoke(
                inputs, 
                config={"recursion_limit": 20}
            )

            # Extract the final response from the AI
            final_message = final_state["messages"][-1].content

            # Fallback: if the model failed to deliver useful info, run a case-law search directly.
            msg_lower = str(final_message).lower() if final_message else ""
            last_tool_content = None
            for m in reversed(final_state.get("messages", [])):
                if isinstance(m, ToolMessage) and m.content:
                    last_tool_content = str(m.content)
                    break
            
            fallback_triggers = [
                "i'm having trouble",
                "technical difficulties",
                "couldn't find",
                "search_statutes(",
                "trouble processing",
            ]
            if any(trigger in msg_lower for trigger in fallback_triggers):
                if last_tool_content:
                    final_message = last_tool_content
                else:
                    try:
                        case_result = await search_case_law.ainvoke({
                            "query": chat_request.message,
                            "jurisdiction": user_state,
                        })
                        final_message = str(case_result)
                    except Exception:
                        pass

            # Increment usage and log query
            increment_usage(current_user, db)
            usage_log = UsageLog(
                user_id=current_user.id,
                query_text=chat_request.message[:500],  # Truncate for storage
                timestamp=datetime.utcnow()
            )
            db.add(usage_log)
            db.commit()

            return ChatResponse(
                response=str(final_message),
                citations=[],
                thought_process=[],
            )
        except Exception as graph_error:
            error_str = str(graph_error)
            if "recursion_limit" in error_str.lower():
                try:
                    last_ai_message = None
                    for msg in reversed(inputs["messages"]):
                        if isinstance(msg, AIMessage) and not hasattr(msg, "tool_calls"):
                            last_ai_message = msg.content
                            break
                    
                    if last_ai_message:
                        return ChatResponse(
                            response=f"{last_ai_message}\n\n(I'm having some trouble finding complete information right now. Please try rephrasing your question.)",
                            citations=[],
                            thought_process=[],
                        )
                except:
                    pass
                
                return ChatResponse(
                    response="I'm having trouble processing that request right now. Could you try rephrasing your question or breaking it into smaller parts?",
                    citations=[],
                    thought_process=[],
                )
            else:
                raise graph_error
    except HTTPException:
        raise
    except Exception as e:
        with open("error.log", "a") as f:
            import traceback
            f.write(f"Error: {str(e)}\n")
            f.write(traceback.format_exc())
            f.write("\n" + "-"*20 + "\n")
        raise HTTPException(status_code=500, detail="An error occurred processing your request")


# Subscription endpoints
@app.post("/subscription/create-checkout")
async def create_checkout(
    current_user: User = Depends(get_current_user),
    db = Depends(get_db)
):
    """Create Stripe Checkout session for Premium subscription"""
    return create_checkout_session(current_user, db)


@app.post("/subscription/webhook")
async def stripe_webhook(request: Request):
    """Handle Stripe webhook events"""
    payload = await request.body()
    sig_header = request.headers.get("stripe-signature")
    return handle_stripe_webhook(payload, sig_header)


@app.get("/subscription/status", response_model=SubscriptionStatusResponse)
async def subscription_status(current_user: User = Depends(get_current_user)):
    """Get user's subscription status"""
    status_data = get_subscription_status(current_user)
    return SubscriptionStatusResponse(**status_data)


@app.post("/subscription/cancel")
async def cancel_user_subscription(
    current_user: User = Depends(get_current_user),
    db = Depends(get_db)
):
    """Cancel user's subscription"""
    return cancel_subscription(current_user, db)


# Legal documents endpoints
@app.get("/legal/privacy")
async def privacy_policy():
    """Return privacy policy"""
    try:
        with open("legal/privacy_policy.md", "r") as f:
            return {"content": f.read()}
    except FileNotFoundError:
        return {"content": "Privacy policy not yet available"}


@app.get("/legal/terms")
async def terms_of_service():
    """Return terms of service"""
    try:
        with open("legal/terms_of_service.md", "r") as f:
            return {"content": f.read()}
    except FileNotFoundError:
        return {"content": "Terms of service not yet available"}


