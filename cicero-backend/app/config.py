from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    # The "Brain" (Fast Reasoning)
    GROQ_API_KEY: str
    GROQ_MODEL: str = "llama-3.3-70b-versatile"  # Currently supported Groq model

    # The "Reader" (Large Context & Embeddings)
    GEMINI_API_KEY: str
    GEMINI_MODEL: str = "gemini-1.5-flash"  # using 1.5 as 2.5 is not yet standard API, change if you have beta access
    
    PINECONE_API_KEY: str  # Add this!
    PINECONE_INDEX_NAME: str = "cicero-knowledge" # Default index name

    # Memory
    QDRANT_URL: str = (
        ":memory:"  # Use in-memory for dev, change to "http://localhost:6333" for prod
    )
    QDRANT_API_KEY: str | None = None

    # Legal Tools
    COURTLISTENER_API_KEY: str
    LEGISCAN_API_KEY: str
    CONGRESS_GOV_API_KEY: str

    class Config:
        env_file = ".env"
        extra = "ignore"


settings = Settings()  # type: ignore
