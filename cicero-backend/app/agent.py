from typing import TypedDict, List, Annotated
import re
from langgraph.graph import StateGraph, END
from langgraph.graph.message import add_messages
from langchain_groq import ChatGroq
from langchain_core.messages import SystemMessage, BaseMessage, ToolMessage, AIMessage, HumanMessage
from pydantic import SecretStr
from app.config import settings
from app.tools.legal_search import search_case_law, search_statutes

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
tools = [search_case_law, search_statutes]
llm_with_tools = llm.bind_tools(tools)


# 3. Define the Nodes
async def reasoner(state: AgentState):
    """
    The reasoning node. This is where Cicero 'thinks'.
    He looks at the conversation and decides if he needs to search the law.
    """
    messages = state["messages"].copy()  # Work with a copy to avoid mutating state
    user_state = state.get("user_state", "US")

    base_system_content = f"""You are Cicero, a warm and empathetic legal companion who helps people understand the law.

IMPORTANT: The user is located in {user_state}. When searching for laws or statutes, ALWAYS use state="{user_state}" to get relevant local laws.

PERSONA:
- You are like a "cool, non-judgemental Mr. Rogers with a Law Degree"
- You are warm, empathetic, and patient
- You explain legal concepts in plain, simple English (5th grade level)
- You use helpful analogies and metaphors

TOOL USAGE GUIDELINES:
- You have tools available: search_case_law, search_statutes.
- Use tools when you need specific, current, or state-specific information.
- For well-established legal concepts (Miranda rights, police stop rights, etc.), you can answer from your knowledge without tools.
- When searching statutes, ALWAYS use state="{user_state}" for the user's state.

IMPORTANT TOOL SELECTION - READ CAREFULLY:
- search_case_law: Use for legal rules, standards, requirements, case law, court decisions, and established legal concepts. 
  * ALWAYS use this for: "statute of limitations", "eviction notice", "Miranda rights", "probable cause", "search and seizure", "tenant rights", "business registration", "LLC formation", "business name registration", "corporate requirements", etc.
  * These are established legal concepts found in case law, NOT in recent bills.
  
- search_statutes: ONLY use for RECENT BILLS or LEGISLATION (bills being considered in the last 2 years, recently passed laws).
  * DO NOT use for: "statute of limitations", "eviction notice requirements", "Miranda rights", "business registration", "LLC requirements", "business name registration", or any established legal concept.
  * ONLY use when user explicitly asks about a recent bill, new legislation, or pending law.

CRITICAL: If the user asks about "statute of limitations", "eviction notice", "business registration", "LLC formation", "business name requirements", or similar established legal concepts, you MUST use search_case_law, NOT search_statutes. The search_statutes tool only finds recent bills, not established laws.

IMPORTANT: If search_case_law returns results that don't seem relevant to the user's question, you should:
1. Still provide a helpful answer using your general legal knowledge if the question is about well-established legal concepts (like Miranda rights, police stop rights, etc.)
2. You can answer general legal questions from your training knowledge - you don't need case law for every question
3. Only mention that case law wasn't found if it's critical to the answer
4. For well-known legal rights (Miranda, police stops, etc.), you can provide accurate information even without specific case citations

- If you already have tool results, synthesize them—do NOT call the same tool again for the same question unless you need a different scope.
- For general legal concepts or advice, you can answer directly from your knowledge
- When you DO use a tool, just make the function call - the system handles execution
- After getting tool results, check if they're actually relevant to the question. If a result is about a completely different topic, say "I couldn't find specific information about that, but let me try a different search" and use a different tool or approach.
- Synthesize tool results into a clear, friendly response. If you received any results, do not say you couldn't find information UNLESS the results are clearly irrelevant.

RESPONSE STYLE:
- Acknowledge the person's concerns first
- Explain concepts simply with examples
- Cite sources when you have them from tool searches
- If you can answer well from your knowledge, do so confidently - don't add unnecessary disclaimers
- Only mention limitations if the information is truly unavailable or uncertain
- If something fails, say "I'm having some trouble finding that information" - never show errors"""

    system_prompt = SystemMessage(content=base_system_content)

    # Ensure system prompt is always the first message
    if not messages or not isinstance(messages[0], SystemMessage):
        messages.insert(0, system_prompt)
    else:
        # Replace existing system message with our updated one
        messages[0] = system_prompt

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


def _check_result_relevance(query: str, result: str) -> bool:
    """
    Simple check to see if a tool result is relevant to the query.
    Returns True if relevant, False if clearly irrelevant.
    """
    query_lower = query.lower()
    result_lower = result.lower()
    
    # Extract key terms from query (remove common words)
    stop_words = {'the', 'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for', 'of', 'with', 'by', 'is', 'are', 'was', 'were', 'what', 'when', 'where', 'why', 'how', 'about', 'can', 'could', 'should', 'would', 'do', 'does', 'did', 'my', 'me', 'i'}
    query_words = set(query_lower.split()) - stop_words
    
    # Check if any key query terms appear in the result
    if len(query_words) > 0:
        matches = sum(1 for word in query_words if word in result_lower)
        # Require at least one key term match
        return matches > 0
    
    return True  # If no meaningful terms, don't filter


async def tool_executor(state: AgentState):
    """
    The action node. This executes the tools Cicero asked for.
    """
    last_message = state["messages"][-1]
    
    # Check if the message has tool_calls attribute
    if not isinstance(last_message, AIMessage) or not last_message.tool_calls:
        print("--- Warning: No tool calls found in last message ---")
        return {"messages": []}
    
    # Get the original user query for relevance checking
    user_query = ""
    for msg in reversed(state["messages"]):
        if isinstance(msg, HumanMessage):
            content = msg.content
            # Handle both string and list content types
            if isinstance(content, str):
                user_query = content
            elif isinstance(content, list) and len(content) > 0:
                # If content is a list, try to extract text from first item
                first_item = content[0]
                if isinstance(first_item, str):
                    user_query = first_item
                elif isinstance(first_item, dict) and "text" in first_item:
                    user_query = first_item["text"]
            break
    
    tool_calls = last_message.tool_calls
    results: list[tuple[str, str, str]] = []

    print(f"--- Cicero is using tools: {len(tool_calls)} calls ---")

    for call in tool_calls:
        try:
            tool_name = call.get("name") if isinstance(call, dict) else call.name
            # Ensure args is a dict and not None
            raw_args = call.get("args") if isinstance(call, dict) else call.get("args", {})
            tool_args = raw_args or {}
            
            tool_id = call.get("id") if isinstance(call, dict) else call.id
            # Ensure tool_id is always a string
            tool_id = str(tool_id) if tool_id is not None else "unknown"
            
            # Prevent using search_statutes for established legal concepts
            if tool_name == "search_statutes" and user_query:
                query_lower = user_query.lower()
                # Check if this is about an established legal concept
                established_concepts = [
                    "statute of limitations", "statute limitations",
                    "eviction notice", "eviction requirements",
                    "miranda rights", "probable cause",
                    "search and seizure", "fourth amendment",
                    "business registration", "register a business", "business name registration",
                    "llc", "llc formation", "llc requirements", "form an llc",
                    "corporate requirements", "business license", "business name"
                ]
                if any(concept in query_lower for concept in established_concepts):
                    print(f"--- ERROR: search_statutes called for established legal concept. Redirecting to search_case_law ---")
                    # Redirect to search_case_law instead
                    tool_name = "search_case_law"
                    # Update tool_args if needed
                    if "state" in tool_args:
                        tool_args["jurisdiction"] = tool_args.pop("state")
            
            if tool_name == "search_case_law":
                res = await search_case_law.ainvoke(tool_args)
                # Check relevance
                if user_query and not _check_result_relevance(user_query, str(res)):
                    print(f"--- Warning: search_case_law result may not be relevant to query ---")
                    res = f"Note: The search results may not be directly relevant to your question. {res}"
                results.append((tool_id, res, tool_name))
            elif tool_name == "search_statutes":
                res = await search_statutes.ainvoke(tool_args)
                # Check relevance - statutes tool is more prone to irrelevant results
                if user_query and not _check_result_relevance(user_query, str(res)):
                    print(f"--- Warning: search_statutes result may not be relevant to query ---")
                    res = f"Note: This result may not be directly relevant to your question. The search_statutes tool finds recent bills, not established legal concepts. For questions about established laws like 'statute of limitations', try search_case_law instead. {res}"
                results.append((tool_id, res, tool_name))
            else:
                print(f"Unknown tool called: {tool_name}")
                tool_name_str = str(tool_name) if tool_name is not None else "unknown"
                results.append((tool_id, f"Error: Tool '{tool_name_str}' is not available.", tool_name_str))
        except Exception as e:
            print(f"Error executing tool call: {e}")
            tool_id = call.get("id") if isinstance(call, dict) else getattr(call, "id", "unknown")
            tool_id = str(tool_id) if tool_id is not None else "unknown"
            # Get tool_name from the call if available
            error_tool_name = call.get("name") if isinstance(call, dict) else getattr(call, "name", "unknown")
            error_tool_name = str(error_tool_name) if error_tool_name is not None else "unknown"
            results.append((tool_id, f"I'm having trouble reaching the court records right now. Please try again in a moment.", error_tool_name))
    
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
