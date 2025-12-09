from sqlalchemy import create_engine, Column, Integer, String, DateTime, ForeignKey, Text, Enum as SQLEnum
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, relationship
from datetime import datetime
import enum
from app.config import settings

Base = declarative_base()


class SubscriptionTier(str, enum.Enum):
    FREE = "FREE"
    PREMIUM = "PREMIUM"


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True, nullable=False)
    firebase_uid = Column(String, unique=True, index=True, nullable=False)
    subscription_tier = Column(SQLEnum(SubscriptionTier), default=SubscriptionTier.FREE, nullable=False)
    queries_today = Column(Integer, default=0, nullable=False)
    queries_reset_date = Column(DateTime, default=datetime.utcnow, nullable=False)
    stripe_customer_id = Column(String, nullable=True)
    stripe_subscription_id = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    usage_logs = relationship("UsageLog", back_populates="user")


class UsageLog(Base):
    __tablename__ = "usage_logs"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    query_text = Column(Text, nullable=False)
    timestamp = Column(DateTime, default=datetime.utcnow, nullable=False)
    tokens_used = Column(Integer, nullable=True)

    user = relationship("User", back_populates="usage_logs")


# Database connection
engine = create_engine(
    settings.DATABASE_URL,
    pool_pre_ping=True,
    pool_size=10,
    max_overflow=20
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def get_db():
    """Dependency for getting database session"""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

