from pydantic import BaseModel
from typing import List, Optional


class ChatRequest(BaseModel):
    message: str
    history: List[dict] = []  # e.g. [{"role": "user", "content": "..."}]
    state: Optional[str] = "CA"  # User's selected state


class ChatResponse(BaseModel):
    response: str
    citations: List[str] = []
    thought_process: List[str] = []  # Optional: show the user what Cicero "thought"
