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

        # Run the agent
        final_state = await app_graph.ainvoke(
            inputs, 
            config={"recursion_limit": 75} 
        )

        # Extract the final response from the AI
        final_message = final_state["messages"][-1].content

        return ChatResponse(
            response=str(final_message),
            citations=[],  # We will wire up citation extraction later
            thought_process=[],
        )
    except Exception as e:
        with open("error.log", "a") as f:
            import traceback
            f.write(f"Error: {str(e)}\n")
            f.write(traceback.format_exc())
            f.write("\n" + "-"*20 + "\n")
        raise HTTPException(status_code=500, detail=str(e))
