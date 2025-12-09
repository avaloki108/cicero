from typing import TypedDict, List, Annotated
import re
from langgraph.graph import StateGraph, END
from langgraph.graph.message import add_messages
from langchain_groq import ChatGroq
from langchain_core.messages import SystemMessage, BaseMessage, ToolMessage, AIMessage, HumanMessage
from pydantic import SecretStr
from app.config import settings
from app.tools.legal_search import search_case_law, search_statutes
from app.tools.knowledge_base import search_legal_precedents
from app.rag_service import rag_service

# 1. Define the State
class AgentState(TypedDict):
    messages: Annotated[List[BaseMessage], add_messages]
    citations: List[str]
    user_state: str  # User's selected US state (e.g., "CO", "CA")


# 2. Setup the "Brain" (Groq)
# We use Llama 3 on Groq because it is excellent at following tool-use instructions.
llm = ChatGroq(
    temperature=0, model=settings.GROQ_MODEL, api_key=SecretStr(settings.GROQ_API_KEY)
)

# Bind the tools to the LLM so it knows they exist
tools = [search_case_law, search_statutes, search_legal_precedents]
llm_with_tools = llm.bind_tools(tools)


# 3. Define the Nodes
async def reasoner(state: AgentState):
    """
    The reasoning node. This is where Cicero 'thinks'.
    He looks at the conversation and decides if he needs to search the law.
    Now enhanced with RAG context retrieval.
    """
    messages = state["messages"].copy()  # Work with a copy to avoid mutating state
    user_state = state.get("user_state", "US")

    # Extract the latest user message for RAG context retrieval
    latest_user_message = None
    for msg in reversed(messages):
        if isinstance(msg, HumanMessage):
            latest_user_message = msg.content
            break
    
    # Retrieve RAG context if we have a user message
    rag_context = ""
    rag_matches = []
    if latest_user_message:
        try:
            context, matches = rag_service.retrieve_context(
                query=latest_user_message,
                top_k=3,
                min_score=0.6,  # Lower threshold to get more context
                max_tokens=2000
            )
            if context:
                rag_context = context
                rag_matches = matches
        except Exception as e:
            print(f"Error retrieving RAG context: {e}")
            # Continue without RAG context if retrieval fails

    # Build system prompt with RAG context if available
    base_system_content = f"""You are Cicero, a warm and empathetic legal companion who helps people understand the law.

IMPORTANT: The user is located in {user_state}. When searching for laws or statutes, ALWAYS use state="{user_state}" to get relevant local laws.

PERSONA:
- You are like a "cool, non-judgemental Mr. Rogers with a Law Degree"
- You are warm, empathetic, and patient
- You explain legal concepts in plain, simple English (5th grade level)
- You use helpful analogies and metaphors

TOOL USAGE GUIDELINES:
- You have tools available: search_case_law, search_statutes, search_legal_precedents
- ONLY use tools when you need to look up specific cases, statutes, or legal precedents
- When searching statutes, ALWAYS use state="{user_state}" for the user's state
- Default to search_case_law for legal rules, standards, and requirements. ONLY use search_statutes if the user explicitly asks about a statute/bill/code/act/section or legislation.
- If you already have tool results, synthesize them—do NOT call the same tool again for the same question unless you need a different scope.
- For general legal concepts or advice, you can answer directly from your knowledge
- When you DO use a tool, just make the function call - the system handles execution
- After getting tool results, synthesize them into a clear, friendly response. If you received any results, do not say you couldn't find information.

RESPONSE STYLE:
- Acknowledge the person's concerns first
- Explain concepts simply with examples
- Cite sources when you have them from tool searches
- If something fails, say "I'm having trouble finding that information" - never show errors"""

    # Add RAG context if available
    if rag_context:
        base_system_content += f"""

KNOWLEDGE BASE CONTEXT:
The following information from our knowledge base may be relevant to the user's question. Use this context to provide more accurate and informed answers. If the context doesn't fully answer the question, you can still use tools to search for additional information.

START KNOWLEDGE BASE CONTEXT
{rag_context}
END KNOWLEDGE BASE CONTEXT

When referencing information from the knowledge base context above, you can mention the source. However, prioritize using tools (search_case_law, search_statutes, search_legal_precedents) for the most up-to-date and comprehensive legal information."""

    system_prompt = SystemMessage(content=base_system_content)

    # Ensure system prompt is always the first message
    if not messages or not isinstance(messages[0], SystemMessage):
        messages.insert(0, system_prompt)
    else:
        # Replace existing system message with our updated one
        messages[0] = system_prompt

    # Get user_state with a default fallback
    user_state = state.get("user_state", "US")
    
    try:
        response = await llm_with_tools.ainvoke(messages)
        
        # Check if the response contains malformed XML-style function calls
        # and convert to a regular response if so
        if hasattr(response, 'content') and response.content:
            content = str(response.content)  # Ensure it's a string
            if '<function=' in content or '</function>' in content:
                # The model tried to use XML-style function syntax
                response = await handle_xml_tool_call(content, messages=messages, user_state=user_state)
                if response:
                    return {"messages": [response]}
        
        return {"messages": [response]}
    except Exception as e:
        error_str = str(e)
        print(f"Error in reasoner: {e}")
        
        # Check if this is a failed tool call with XML-style syntax
        if 'failed_generation' in error_str and '<function=' in error_str:
            # Extract the failed generation from the error
            import json as json_module
            try:
                # Parse the error to get the failed_generation
                # Error format: {...'failed_generation': '<function=...>'}
                match = re.search(r"'failed_generation':\s*'([^']+)'", error_str)
                if match:
                    failed_gen = match.group(1)
                    response = await handle_xml_tool_call(failed_gen, messages=messages, user_state=user_state)
                    if response:
                        return {"messages": [response]}
            except Exception as parse_err:
                print(f"Error parsing failed_generation: {parse_err}")
        
        # Return a helpful error message instead of crashing
        error_msg = AIMessage(
            content="I'm sorry, I'm having some technical difficulties right now. Please try asking your question again."
        )
        return {"messages": [error_msg]}


async def handle_xml_tool_call(content: str, messages: list, user_state: str = "US"):
    """Handle malformed XML-style tool calls from Llama models."""
    import json
    
    # Pattern matches: <function=tool_name{...json...}</function> or <function=tool_name {...json...}</function>
    match = re.search(r'<function=(\w+)\s*\{(.+?)\}', content)
    if not match:
        return None
        
    tool_name = match.group(1)
    try:
        # Parse the JSON-like arguments
        args_str = '{' + match.group(2) + '}'
        # Fix common issues: single quotes to double quotes
        args_str = args_str.replace("'", '"')
        args = json.loads(args_str)
        query = args.get('query', '')
        
        # Use user's state as default if not specified in the tool call
        if 'state' not in args and tool_name == 'search_statutes':
            args['state'] = user_state
            print(f"--- Using user's state setting: {user_state} ---")
        
        # Execute the tool directly using arun
        print(f"--- Manually executing {tool_name} with args: {args} ---")
        if tool_name == 'search_case_law':
            result = await search_case_law.arun(tool_input=args)
        elif tool_name == 'search_statutes':
            result = await search_statutes.arun(tool_input=args)
        elif tool_name == 'search_legal_precedents':
            result = await search_legal_precedents.arun(tool_input=args)
        else:
            result = "I couldn't find specific information on that topic."
        
        print(f"--- Tool result (first 200 chars): {str(result)[:200]} ---")
        
        # Now ask the LLM to synthesize the result (without tools to avoid loop)
        synth_messages = messages + [
            AIMessage(content=f"I searched for information about '{query}' in {user_state} and found:\n\n{result}"),
            HumanMessage(content="Please summarize this information in a helpful, friendly way for the user. Do not include any tool call text or instructions—just give the answer plainly.")
        ]
        synth_response = await llm.ainvoke(synth_messages)
        return synth_response
    except Exception as parse_error:
        print(f"Error parsing/executing tool call: {parse_error}")
        import traceback
        traceback.print_exc()
        return None


async def tool_executor(state: AgentState):
    """
    The action node. This executes the tools Cicero asked for.
    """
    last_message = state["messages"][-1]
    
    # Check if the message has tool_calls attribute
    if not isinstance(last_message, AIMessage) or not last_message.tool_calls:
        print("--- Warning: No tool calls found in last message ---")
        return {"messages": []}
    
    tool_calls = last_message.tool_calls
    results = []

    print(f"--- Cicero is using tools: {len(tool_calls)} calls ---")

    for call in tool_calls:
        try:
            tool_name = call.get("name") if isinstance(call, dict) else call.name
            # Ensure args is a dict and not None
            raw_args = call.get("args") if isinstance(call, dict) else call.get("args", {})
            tool_args = raw_args or {}
            
            tool_id = call.get("id") if isinstance(call, dict) else call.id
            
            if tool_name == "search_case_law":
                res = await search_case_law.ainvoke(tool_args)
                results.append((tool_id, res, tool_name))
            elif tool_name == "search_statutes":
                res = await search_statutes.ainvoke(tool_args)
                results.append((tool_id, res, tool_name))
            elif tool_name == "search_legal_precedents":
                res = await search_legal_precedents.ainvoke(tool_args)
                results.append((tool_id, res, tool_name))
            else:
                print(f"Unknown tool called: {tool_name}")
                results.append((tool_id, f"Error: Tool '{tool_name}' is not available.", tool_name))
        except Exception as e:
            print(f"Error executing tool call: {e}")
            tool_id = call.get("id") if isinstance(call, dict) else getattr(call, "id", "unknown")
            results.append((tool_id, f"I'm having trouble reaching the court records right now. Please try again in a moment.", tool_name if 'tool_name' in locals() else 'unknown'))
    
    # Return results as ToolMessages so Cicero can read them
    tool_messages = [
        ToolMessage(tool_call_id=tool_id, name=tool_name, content=str(res))
        for tool_id, res, tool_name in results
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
    # Check if message has tool_calls and they're not empty
    if isinstance(last_message, AIMessage) and last_message.tool_calls:
        return "tools"
    return END


workflow.add_conditional_edges("agent", should_continue)
workflow.add_edge("tools", "agent")  # Loop back to agent to synthesize answer

app_graph = workflow.compile()
