from pydantic import BaseModel, Field, validator
from typing import List, Optional

# Valid US state codes
VALID_STATE_CODES = {
    "AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "FL", "GA",
    "HI", "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME", "MD",
    "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ",
    "NM", "NY", "NC", "ND", "OH", "OK", "OR", "PA", "RI", "SC",
    "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV", "WI", "WY",
    "DC", "US"  # DC and US for federal
}


class ChatRequest(BaseModel):
    message: str = Field(..., min_length=1, max_length=2000)
    history: List[dict] = []  # e.g. [{"role": "user", "content": "..."}]
    state: Optional[str] = "CA"  # User's selected state

    @validator("message")
    def validate_message(cls, v):
        if not v or not v.strip():
            raise ValueError("Message cannot be empty")
        return v.strip()

    @validator("state")
    def validate_state(cls, v):
        if v and v.upper() not in VALID_STATE_CODES:
            raise ValueError(f"Invalid state code. Must be one of: {', '.join(sorted(VALID_STATE_CODES))}")
        return v.upper() if v else "US"


class ChatResponse(BaseModel):
    response: str
    citations: List[str] = []
    thought_process: List[str] = []  # Optional: show the user what Cicero "thought"


class SubscriptionStatusResponse(BaseModel):
    tier: str
    queries_today: int
    queries_limit: Optional[int]  # None for unlimited
    stripe_customer_id: Optional[str] = None
    stripe_subscription_id: Optional[str] = None
