from typing import TypedDict, List, Annotated
from langgraph.graph import StateGraph, END
from langgraph.graph.message import add_messages
from langchain_groq import ChatGroq
from langchain_core.messages import SystemMessage, BaseMessage, ToolMessage
from app.config import settings
from app.tools.legal_search import search_case_law, search_statutes
from app.tools.knowledge_base import search_legal_precedents

# 1. Define the State
class AgentState(TypedDict):
    messages: Annotated[List[BaseMessage], add_messages]
    citations: List[str]


# 2. Setup the "Brain" (Groq)
# We use Llama 3 on Groq because it is excellent at following tool-use instructions.
llm = ChatGroq(
    temperature=0, model_name=settings.GROQ_MODEL, api_key=settings.GROQ_API_KEY
)

# Bind the tools to the LLM so it knows they exist
tools = [search_case_law, search_statutes, search_legal_precedents]
llm_with_tools = llm.bind_tools(tools)


# 3. Define the Nodes
async def reasoner(state: AgentState):
    """
    The reasoning node. This is where Cicero 'thinks'.
    He looks at the conversation and decides if he needs to search the law.
    """
    messages = state["messages"]

    # System Prompt: defining the Persona
    system_prompt = SystemMessage(
        content="""
        You are Cicero, your personal legal companion who cares about you.
        Your goal is to turn "Scary Law" into "Helpful English" for people who are stressed and confused.

        PERSONA:
        - You are the "cool, non-judgemental Mr. Rogers with a Law Degree".
        - You are warm, empathetic, and patient.
        - You NEVER use complex legal jargon.

        INSTRUCTIONS:
        1. **Translate Legalese**: Always convert complex legal terms into plain, 5th-grade English.
        2. **Use Analogies**: Explain concepts using simple metaphors (e.g., "Res Judicata" is like "Double Jeopardy for civil cases").
        3. **Be Empathetic**: Acknowledge the user's stress. Don't just give facts; give comfort.
        4. **Verify Everything**: ALWAYS use your tools (search_case_law, search_statutes) to find the truth. Never guess.
        5. **Cite Sources**: When you give an answer, cite the specific case or statute found by your tools.
        6. **No Raw Errors**: If a tool fails, say "I'm having trouble reaching the court records," never show a JSON error.
        7. **Tool Protocol**: When you need to search, do not write any text. Just invoke the tool. Do NOT use XML tags like <function>.
    """
    )

    # Ensure system prompt is always the first message
    if not isinstance(messages[0], SystemMessage):
        messages.insert(0, system_prompt)

    response = await llm_with_tools.ainvoke(messages)
    return {"messages": [response]}


async def tool_executor(state: AgentState):
    """
    The action node. This executes the tools Cicero asked for.
    """
    last_message = state["messages"][-1]
    tool_calls = last_message.tool_calls
    results = []

    print(f"--- Cicero is using tools: {len(tool_calls)} calls ---")

    for call in tool_calls:
        if call["name"] == "search_case_law":
            res = await search_case_law.ainvoke(call["args"])
            results.append(res)
        elif call["name"] == "search_statutes":
            res = await search_statutes.ainvoke(call["args"])
            results.append(res)
        elif call["name"] == "search_legal_precedents":
            res = await search_legal_precedents.ainvoke(call["args"])
            results.append(res)
        else:
            print(f"Unknown tool called: {call['name']}")
            results.append(f"Error: Tool '{call['name']}' is not available.")
    
    # Return results as ToolMessages so Cicero can read them
    tool_messages = [
        ToolMessage(tool_call_id=call["id"], content=str(res))
        for call, res in zip(tool_calls, results)
    ]
    return {"messages": tool_messages}


# 4. Build the Graph
workflow = StateGraph(AgentState)
workflow.add_node("agent", reasoner)
workflow.add_node("tools", tool_executor)

workflow.set_entry_point("agent")


# Conditional Logic: Does Cicero want to use a tool?
def should_continue(state: AgentState):
    last_message = state["messages"][-1]
    if last_message.tool_calls:
        return "tools"
    return END


workflow.add_conditional_edges("agent", should_continue)
workflow.add_edge("tools", "agent")  # Loop back to agent to synthesize answer

app_graph = workflow.compile()
