from langchain_core.tools import tool
from pinecone import Pinecone
from app.config import settings

# Initialize Pinecone once
pc = Pinecone(api_key=settings.PINECONE_API_KEY)

# Connect to your index
# We assume you created an index named "cicero-knowledge" with model="llama-text-embed-v2"
index = pc.Index(settings.PINECONE_INDEX_NAME) 

@tool
def search_legal_precedents(query: str):
    """
    Search the internal knowledge base for specific legal documents, 
    past case notes, or uploaded PDFs.
    Use this when the user asks about specific documents we have stored.
    """
    try:
        # Pinecone Inference lets us query with TEXT directly!
        # We don't need to generate a vector first.
        results = index.search(
            query=query, 
            k=3, 
            fields=["text", "case_name", "citation"] # Fields we want back
        )
        
        matches = []
        for match in results['matches']:
            # Safe access to metadata
            meta = match.get('metadata', {})
            text = meta.get('text', 'No text content')
            case = meta.get('case_name', 'Unknown Case')
            score = match.get('score', 0.0)
            matches.append(f"[Score: {score:.2f}] {case}: {text}")
            
        return "\n\n".join(matches) if matches else "No relevant documents found in knowledge base."

    except Exception as e:
        return f"Error searching knowledge base: {str(e)}"