"""
RAG (Retrieval-Augmented Generation) Service

This module provides RAG functionality for the Cicero application:
- Context retrieval from Pinecone knowledge base
- Prompt augmentation with retrieved context
- Integration with the agent system
"""

from typing import List, Dict, Any, Optional, Tuple
from pinecone import Pinecone, SearchQuery
from app.config import settings


class RAGService:
    """Service for Retrieval-Augmented Generation using Pinecone."""
    
    def __init__(self):
        """Initialize the RAG service with Pinecone connection."""
        self.pc = Pinecone(api_key=settings.PINECONE_API_KEY)
        self.index = self.pc.Index(settings.PINECONE_INDEX_NAME)
        
        # Namespace fallback order
        self.namespaces = []
        for ns in (getattr(settings, "PINECONE_NAMESPACE", None), "case-law", "general", ""):
            if ns is None:
                continue
            ns_clean = ns.strip()
            if ns_clean == "":
                ns_clean = "__default__"
            if ns_clean not in self.namespaces:
                self.namespaces.append(ns_clean)
    
    def retrieve_context(
        self,
        query: str,
        top_k: int = 5,
        min_score: float = 0.7,
        namespace: Optional[str] = None,
        max_tokens: int = 3000
    ) -> Tuple[str, List[Dict[str, Any]]]:
        """
        Retrieve relevant context from Pinecone for a given query.
        
        Args:
            query: The user's query/question
            top_k: Number of results to retrieve
            min_score: Minimum similarity score threshold
            namespace: Specific namespace to search (None = try all)
            max_tokens: Maximum tokens to include in context
            
        Returns:
            Tuple of (context_string, list_of_matches_with_metadata)
        """
        search_request = SearchQuery(inputs={"text": query}, top_k=top_k)
        last_error: Exception | None = None
        
        # Use specific namespace or try all
        namespaces_to_try = [namespace] if namespace else self.namespaces
        
        for ns in namespaces_to_try:
            try:
                results = self.index.search(namespace=ns, query=search_request)
            except Exception as exc:
                last_error = exc
                continue
            
            hits = getattr(getattr(results, "result", None), "hits", []) or []
            if not hits:
                continue
            
            # Filter by score and extract context
            matches = []
            context_parts = []
            current_length = 0
            
            for hit in hits:
                score = getattr(hit, "_score", 0.0)
                if score < min_score:
                    continue
                
                fields = getattr(hit, "fields", {}) or {}
                metadata = fields.get("metadata", {}) if isinstance(fields.get("metadata"), dict) else {}
                
                # Extract text content
                text = fields.get("text") or metadata.get("text") or metadata.get("chunk") or ""
                if not text:
                    continue
                
                # Extract metadata for citation
                case_name = (
                    metadata.get("case_name")
                    or metadata.get("title")
                    or metadata.get("source")
                    or "Document"
                )
                citation = metadata.get("citation") or metadata.get("url", "")
                source = metadata.get("source", "knowledge_base")
                
                # Build match info
                match_info = {
                    "text": text,
                    "score": score,
                    "case_name": case_name,
                    "citation": citation,
                    "source": source,
                    "metadata": metadata
                }
                matches.append(match_info)
                
                # Build context string (respecting max_tokens)
                # Rough estimate: 1 token ≈ 4 characters
                text_length = len(text)
                if current_length + text_length > max_tokens * 4:
                    # Truncate this text if needed
                    remaining = (max_tokens * 4) - current_length
                    if remaining > 100:  # Only add if meaningful space remains
                        text = text[:remaining].rstrip() + "..."
                    else:
                        break
                
                # Format context entry
                cite_suffix = f" ({citation})" if citation else ""
                context_entry = f"[Source: {case_name}{cite_suffix}]\n{text}\n"
                context_parts.append(context_entry)
                current_length += len(context_entry)
            
            if matches:
                context = "\n---\n".join(context_parts)
                return context, matches
        
        # No matches found
        if last_error:
            return f"Error retrieving context: {last_error}", []
        return "", []
    
    def augment_prompt(
        self,
        query: str,
        context: str,
        system_instructions: Optional[str] = None
    ) -> str:
        """
        Augment a prompt with retrieved context.
        
        Args:
            query: The user's query
            context: Retrieved context from knowledge base
            system_instructions: Optional additional system instructions
            
        Returns:
            Augmented prompt string
        """
        if not context:
            return query
        
        base_instructions = """You are an AI assistant helping with legal questions. Use the context provided below to answer the user's question accurately and helpfully.

IMPORTANT INSTRUCTIONS:
- Use ONLY the information provided in the CONTEXT BLOCK below
- If the context doesn't contain enough information to answer the question, say so clearly
- Cite sources when referencing specific information from the context
- Do not make up information that isn't in the context
- Be clear and helpful in your explanations

START CONTEXT BLOCK
{context}
END OF CONTEXT BLOCK

User Question: {query}

Please provide a helpful answer based on the context above:"""
        
        if system_instructions:
            base_instructions = f"{system_instructions}\n\n{base_instructions}"
        
        return base_instructions.format(context=context, query=query)
    
    def get_rag_context(
        self,
        query: str,
        top_k: int = 5,
        min_score: float = 0.7,
        namespace: Optional[str] = None,
        max_tokens: int = 3000
    ) -> Dict[str, Any]:
        """
        Get RAG context for a query (convenience method).
        
        Returns a dictionary with:
        - context: Formatted context string
        - matches: List of match metadata
        - augmented_prompt: Full prompt with context
        """
        context, matches = self.retrieve_context(
            query=query,
            top_k=top_k,
            min_score=min_score,
            namespace=namespace,
            max_tokens=max_tokens
        )
        
        augmented_prompt = self.augment_prompt(query, context) if context else query
        
        return {
            "context": context,
            "matches": matches,
            "augmented_prompt": augmented_prompt,
            "has_context": bool(context)
        }


# Global instance
rag_service = RAGService()

