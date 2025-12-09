# RAG Implementation Summary

This document describes the Retrieval-Augmented Generation (RAG) implementation in the Cicero application.

## Overview

The RAG system enhances Cicero's ability to answer legal questions by:
1. Retrieving relevant context from the Pinecone knowledge base
2. Augmenting prompts with retrieved context
3. Providing more accurate and grounded responses

## Components

### 1. RAG Service (`app/rag_service.py`)

The core RAG service provides:

- **`RAGService.retrieve_context()`**: Retrieves relevant documents from Pinecone based on a query
  - Uses Pinecone's Inference API with `llama-text-embed-v2` model
  - Supports multiple namespaces with fallback
  - Filters results by similarity score
  - Respects token limits for context

- **`RAGService.augment_prompt()`**: Formats retrieved context into a prompt-friendly format
  - Wraps context in clear delimiters
  - Includes instructions for the LLM on how to use the context

- **`RAGService.get_rag_context()`**: Convenience method that combines retrieval and augmentation

### 2. Enhanced Knowledge Base Tool (`app/tools/knowledge_base.py`)

The `search_legal_precedents` tool now uses the RAG service:
- Retrieves context using RAG
- Formats results with relevance scores and citations
- Returns structured information for the agent

### 3. Agent Integration (`app/agent.py`)

The agent's `reasoner` node now:
- Automatically retrieves RAG context for user queries
- Injects context into the system prompt
- Provides the LLM with relevant knowledge base information before tool calls

**How it works:**
1. Extracts the latest user message
2. Retrieves relevant context from Pinecone
3. Adds context to the system prompt if available
4. LLM can use both the context and tools to provide comprehensive answers

### 4. API Endpoint (`main.py`)

New `/rag/context` endpoint:
- **POST `/rag/context`**: Retrieve RAG context for a query
  - Request: `RAGContextRequest` with query, top_k, min_score, etc.
  - Response: `RAGContextResponse` with context, matches, and metadata
  - Useful for frontend to display relevant documents or pre-fetch context

## Configuration

The RAG system uses settings from `app/config.py`:
- `PINECONE_API_KEY`: Pinecone API key
- `PINECONE_INDEX_NAME`: Index name (default: "cicero-knowledge")
- `PINECONE_NAMESPACE`: Default namespace (default: "case-law")

## Usage Examples

### Using RAG in the Agent

The agent automatically uses RAG context. When a user asks a question:
1. RAG context is retrieved from the knowledge base
2. Context is added to the system prompt
3. Agent can answer using both context and tools

### Using the RAG Service Directly

```python
from app.rag_service import rag_service

# Retrieve context
context, matches = rag_service.retrieve_context(
    query="What is the statute of limitations for personal injury?",
    top_k=5,
    min_score=0.7
)

# Get full RAG result
rag_result = rag_service.get_rag_context(
    query="What is the statute of limitations?",
    top_k=3,
    max_tokens=2000
)
```

### Using the API Endpoint

```bash
curl -X POST http://localhost:8000/rag/context \
  -H "Content-Type: application/json" \
  -d '{
    "query": "What is the statute of limitations?",
    "top_k": 5,
    "min_score": 0.7
  }'
```

## Benefits

1. **More Accurate Answers**: LLM has access to relevant context from the knowledge base
2. **Reduced Hallucination**: Context grounds responses in actual documents
3. **Better Citations**: System can cite sources from retrieved context
4. **Flexible**: Works alongside existing tools (search_case_law, search_statutes)
5. **Automatic**: No manual intervention needed - context is retrieved automatically

## Architecture

```
User Query
    ↓
Agent Reasoner Node
    ↓
RAG Service (retrieves context from Pinecone)
    ↓
System Prompt (augmented with context)
    ↓
LLM (can use context + tools)
    ↓
Response
```

## Future Enhancements

Potential improvements:
- Hybrid search (dense + sparse)
- Reranking of results
- Multi-query retrieval
- Context compression for very long contexts
- Caching of frequently accessed contexts

