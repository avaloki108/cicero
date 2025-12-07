from fastapi import FastAPI, HTTPException
from app.models import ChatRequest, ChatResponse
from app.agent import app_graph
from langchain_core.messages import HumanMessage, AIMessage

app = FastAPI(title="Cicero API", version="2.0")


@app.get("/")
def health_check():
    return {"status": "online", "system": "Cicero 2.0 Agentic Brain"}


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
        current_message = HumanMessage(content=request.message)
        messages = history_messages + [current_message]
        inputs = {"messages": messages}

        # Run the agent with recursion limit to prevent infinite loops
        try:
            final_state = await app_graph.ainvoke(
                inputs, 
                config={"recursion_limit": 20}  # Reduced from 75 to prevent long loops
            )

            # Extract the final response from the AI
            final_message = final_state["messages"][-1].content

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
