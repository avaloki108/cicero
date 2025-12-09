from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
from fastapi import Request

limiter = Limiter(key_func=get_remote_address)


def get_user_id_for_rate_limit(request: Request) -> str:
    """Get user ID from request state (set by auth middleware)"""
    # Try to get user from request state (set by auth middleware)
    if hasattr(request.state, "user_id"):
        return str(request.state.user_id)
    # Fall back to IP address
    return get_remote_address(request)

