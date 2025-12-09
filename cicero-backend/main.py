from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Dict, Any, Optional
from app.models import ChatRequest, ChatResponse
from app.agent import app_graph
from app.rag_service import rag_service
from langchain_core.messages import HumanMessage, AIMessage, ToolMessage
from app.tools.legal_search import search_case_law

app = FastAPI(title="Cicero API", version="2.0")

# Add CORS middleware to allow web app requests
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, replace with specific origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/")
def health_check():
    return {"status": "online", "system": "Cicero 2.0 Agentic Brain"}


# RAG Context Models
class RAGContextRequest(BaseModel):
    query: str
    top_k: int = 5
    min_score: float = 0.7
    namespace: Optional[str] = None
    max_tokens: int = 3000


class RAGContextResponse(BaseModel):
    context: str
    matches: List[Dict[str, Any]]
    has_context: bool
    match_count: int


@app.post("/rag/context", response_model=RAGContextResponse)
async def get_rag_context(request: RAGContextRequest):
    """
    Retrieve RAG context for a given query.
    This endpoint can be used by the frontend to get context before sending to chat,
    or for displaying relevant documents to the user.
    """
    try:
        rag_result = rag_service.get_rag_context(
            query=request.query,
            top_k=request.top_k,
            min_score=request.min_score,
            namespace=request.namespace,
            max_tokens=request.max_tokens
        )
        
        return RAGContextResponse(
            context=rag_result["context"],
            matches=rag_result["matches"],
            has_context=rag_result["has_context"],
            match_count=len(rag_result["matches"])
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error retrieving RAG context: {str(e)}")


@app.post("/chat", response_model=ChatResponse)
async def chat_endpoint(request: ChatRequest):
    try:
        # Convert request history and current message to LangGraph format
        history_messages = []
        for item in request.history:
            if isinstance(item, dict) and "role" in item and "content" in item:
                if item["role"] == "user":
                    history_messages.append(HumanMessage(content=item["content"]))
                elif item["role"] == "assistant":
                    history_messages.append(AIMessage(content=item["content"]))
            # ignore other roles or malformed items
        
        # Include the user's state in the message context
        user_state = request.state or "US"
        current_message = HumanMessage(content=f"[User is in {user_state}] {request.message}")
        messages = history_messages + [current_message]
        inputs = {"messages": messages, "user_state": user_state}

        # Run the agent with recursion limit to prevent infinite loops
        try:
            final_state = await app_graph.ainvoke(
                inputs, 
                config={"recursion_limit": 20}  # Reduced from 75 to prevent long loops
            )

            # Extract the final response from the AI
            final_message = final_state["messages"][-1].content

            # Fallback: if the model failed to deliver useful info, run a case-law search directly.
            msg_lower = str(final_message).lower() if final_message else ""
            # Grab the most recent tool output if we need to fall back
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
                # If we have tool results already, surface them directly.
                if last_tool_content:
                    final_message = last_tool_content
                else:
                    # Otherwise run a quick case-law search as a backup.
                    try:
                        case_result = await search_case_law.ainvoke({
                            "query": request.message,
                            "jurisdiction": request.state or "US",
                        })
                        final_message = str(case_result)
                    except Exception:
                        pass

            return ChatResponse(
                response=str(final_message),
                citations=[],  # We will wire up citation extraction later
                thought_process=[],
            )
        except Exception as graph_error:
            # Handle recursion limit and other graph errors gracefully
            error_str = str(graph_error)
            if "recursion_limit" in error_str.lower():
                # If we hit recursion limit, try to return the last message if available
                try:
                    # Get partial state if available
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
                # Re-raise other errors to be caught by outer exception handler
                raise graph_error
    except Exception as e:
        with open("error.log", "a") as f:
            import traceback
            f.write(f"Error: {str(e)}\n")
            f.write(traceback.format_exc())
            f.write("\n" + "-"*20 + "\n")
        raise HTTPException(status_code=500, detail=str(e))
