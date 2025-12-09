from langchain_core.tools import tool
from pinecone import Pinecone, SearchQuery
from app.config import settings

# Initialize Pinecone once
pc = Pinecone(api_key=settings.PINECONE_API_KEY)

# Connect to your index
# We assume you created an index named "cicero-knowledge" with model="llama-text-embed-v2"
index = pc.Index(settings.PINECONE_INDEX_NAME)

# Try the configured namespace first, then reasonable fallbacks so searches keep working.
_namespaces = []
for ns in (getattr(settings, "PINECONE_NAMESPACE", None), "case-law", "general", ""):
    if ns is None:
        continue
    ns_clean = ns.strip()
    if ns_clean == "":
        ns_clean = "__default__"
    if ns_clean not in _namespaces:
        _namespaces.append(ns_clean)

@tool
def search_legal_precedents(query: str):
    """
    Search the internal knowledge base for specific legal documents, 
    past case notes, or uploaded PDFs.
    Use this when the user asks about specific documents we have stored.
    """
    search_request = SearchQuery(inputs={"text": query}, top_k=3)
    last_error: Exception | None = None

    for namespace in _namespaces:
        try:
            results = index.search(namespace=namespace, query=search_request)
        except Exception as exc:
            last_error = exc
            continue

        hits = getattr(getattr(results, "result", None), "hits", []) or []
        if not hits:
            continue

        matches = []
        for hit in hits:
            fields = getattr(hit, "fields", {}) or {}
            metadata = fields.get("metadata", {}) if isinstance(fields.get("metadata"), dict) else {}
            text = fields.get("text") or metadata.get("text") or "No text content"
            snippet = text if len(text) <= 600 else text[:600].rstrip() + "..."
            case = (
                metadata.get("case_name")
                or metadata.get("title")
                or metadata.get("source")
                or "Document"
            )
            citation = metadata.get("citation")
            score = getattr(hit, "_score", None)
            score_prefix = f"[Score: {score:.2f}] " if isinstance(score, (int, float)) else ""
            cite_suffix = f" ({citation})" if citation else ""
            matches.append(f"{score_prefix}{case}{cite_suffix}: {snippet}")

        if matches:
            return "\n\n".join(matches)

    if last_error:
        return f"Error searching knowledge base: {last_error}"
    return "No relevant documents found in knowledge base."
