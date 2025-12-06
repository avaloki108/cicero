from fastapi import FastAPI, HTTPException
from app.models import ChatRequest, ChatResponse
from app.agent import app_graph
from langchain_core.messages import HumanMessage

app = FastAPI(title="Cicero API", version="2.0")


@app.get("/")
def health_check():
    return {"status": "online", "system": "Cicero 2.0 Agentic Brain"}


@app.post("/chat", response_model=ChatResponse)
async def chat_endpoint(request: ChatRequest):
    try:
        # Convert request to LangGraph format
        inputs = {"messages": [HumanMessage(content=request.message)]}

        # Run the agent
        final_state = app_graph.invoke(inputs)

        # Extract the final response from the AI
        final_message = final_state["messages"][-1].content

        return ChatResponse(
            response=str(final_message),
            citations=[],  # We will wire up citation extraction later
            thought_process=[],
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
