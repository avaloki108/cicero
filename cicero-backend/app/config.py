from pydantic_settings import BaseSettings
from typing import Optional


class Settings(BaseSettings):
    # The "Brain" (Fast Reasoning)
    GROQ_API_KEY: str
    # llama-3.3-70b-versatile is the best available on standard Groq plan
    GROQ_MODEL: str = "llama-3.3-70b-versatile"

    # The "Reader" (Large Context & Embeddings)
    GEMINI_API_KEY: str
    GEMINI_MODEL: str = "gemini-1.5-flash"  # using 1.5 as 2.5 is not yet standard API, change if you have beta access

    # Pinecone
    PINECONE_API_KEY: str
    PINECONE_INDEX_NAME: str = "cicero-knowledge"
    PINECONE_NAMESPACE: str = "case-law"
    USE_RAG: bool = True

    # Memory
    QDRANT_URL: str = (
        ":memory:"  # Use in-memory for dev, change to "http://localhost:6333" for prod
    )
    QDRANT_API_KEY: str | None = None

    # Legal Tools
    COURTLISTENER_API_KEY: str
    LEGISCAN_API_KEY: str
    CONGRESS_GOV_API_KEY: str

    # Database
    DATABASE_URL: str

    # Firebase
    FIREBASE_CREDENTIALS: Optional[str] = None  # Path to service account JSON or JSON string

    # Stripe
    STRIPE_SECRET_KEY: str
    STRIPE_WEBHOOK_SECRET: str
    STRIPE_PREMIUM_PRICE_ID: str  # Stripe Price ID for Premium subscription

    # CORS
    ALLOWED_ORIGINS: str = "http://localhost:3000,http://127.0.0.1:3000"  # Comma-separated list

    class Config:
        env_file = ".env"
        extra = "ignore"


settings = Settings()  # type: ignore
