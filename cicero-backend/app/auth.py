from fastapi import Depends, HTTPException, status, Request
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from firebase_admin import auth, credentials, initialize_app
from sqlalchemy.orm import Session
from app.database import get_db, User, SubscriptionTier
from app.config import settings
from datetime import datetime, timedelta
import json
import os

# Initialize Firebase Admin SDK (lazy initialization)
_firebase_initialized = False

def _initialize_firebase():
    """Initialize Firebase Admin SDK if not already initialized"""
    global _firebase_initialized
    if _firebase_initialized:
        return
    
    if not settings.FIREBASE_CREDENTIALS:
        raise ValueError("FIREBASE_CREDENTIALS environment variable is required")

    try:
        # Try to parse as JSON string first
        firebase_creds = json.loads(settings.FIREBASE_CREDENTIALS)
        cred = credentials.Certificate(firebase_creds)
    except (json.JSONDecodeError, ValueError):
        # If not JSON, treat as file path
        if os.path.exists(settings.FIREBASE_CREDENTIALS):
            cred = credentials.Certificate(settings.FIREBASE_CREDENTIALS)
        else:
            raise ValueError(f"FIREBASE_CREDENTIALS must be a valid JSON string or file path. Got: {settings.FIREBASE_CREDENTIALS[:50]}...")

    try:
        initialize_app(cred)
        _firebase_initialized = True
    except ValueError:
        # App already initialized (e.g., in tests)
        _firebase_initialized = True

security = HTTPBearer()


async def verify_firebase_token(credentials: HTTPAuthorizationCredentials = Depends(security)) -> dict:
    """Verify Firebase ID token and return decoded token"""
    _initialize_firebase()  # Ensure Firebase is initialized
    try:
        token = credentials.credentials
        decoded_token = auth.verify_id_token(token)
        return decoded_token
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid authentication token: {str(e)}",
            headers={"WWW-Authenticate": "Bearer"},
        )


async def get_current_user(
    request: Request,
    decoded_token: dict = Depends(verify_firebase_token),
    db: Session = Depends(get_db)
) -> User:
    """Get or create user from Firebase token"""
    firebase_uid = decoded_token.get("uid")
    email = decoded_token.get("email")
    
    if not firebase_uid or not email:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token: missing uid or email"
        )
    
    # Get or create user
    user = db.query(User).filter(User.firebase_uid == firebase_uid).first()
    
    if not user:
        # Create new user
        user = User(
            email=email,
            firebase_uid=firebase_uid,
            subscription_tier=SubscriptionTier.FREE,
            queries_today=0,
            queries_reset_date=datetime.utcnow()
        )
        db.add(user)
        db.commit()
        db.refresh(user)
    else:
        # Update email if changed
        if user.email != email:
            user.email = email
            db.commit()
    
    # Set user_id in request state for rate limiting
    request.state.user_id = user.id
    
    return user


def check_usage_limit(user: User, db: Session) -> bool:
    """Check if user can make a query based on subscription tier and usage"""
    now = datetime.utcnow()
    
    # Reset daily count if needed
    if user.queries_reset_date.date() < now.date():
        user.queries_today = 0
        user.queries_reset_date = now
        db.commit()
    
    # Check limits based on subscription tier
    if user.subscription_tier == SubscriptionTier.FREE:
        if user.queries_today >= 5:
            return False
    
    # Premium tier has no limits
    return True


def increment_usage(user: User, db: Session):
    """Increment user's query count"""
    user.queries_today += 1
    db.commit()

