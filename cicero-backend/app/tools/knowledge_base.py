from langchain_core.tools import tool
from app.rag_service import rag_service


@tool
def search_legal_precedents(query: str):
    """
    Search the internal knowledge base for specific legal documents, 
    past case notes, or uploaded PDFs.
    Use this when the user asks about specific documents we have stored.
    
    This tool uses RAG (Retrieval-Augmented Generation) to find relevant
    context from the knowledge base and returns formatted results.
    """
    # Use RAG service to retrieve context
    context, matches = rag_service.retrieve_context(
        query=query,
        top_k=5,
        min_score=0.7,
        max_tokens=2000
    )
    
    if not matches:
        return "No relevant documents found in knowledge base."
    
    # Format results for the tool output
    formatted_results = []
    for match in matches[:5]:  # Limit to top 5
        case_name = match.get("case_name", "Document")
        citation = match.get("citation", "")
        text = match.get("text", "")
        score = match.get("score", 0.0)
        
        # Create snippet (first 600 chars)
        snippet = text if len(text) <= 600 else text[:600].rstrip() + "..."
        
        score_prefix = f"[Relevance: {score:.2f}] " if score > 0 else ""
        cite_suffix = f" ({citation})" if citation else ""
        
        formatted_results.append(
            f"{score_prefix}{case_name}{cite_suffix}:\n{snippet}"
        )
    
    return "\n\n---\n\n".join(formatted_results)
