"""
Token schemas
"""
from pydantic import BaseModel
from typing import Optional


class Token(BaseModel):
    """Token response"""
    access_token: str
    token_type: str = "bearer"


class TokenPayload(BaseModel):
    """Token payload data"""
    sub: Optional[int] = None  # Subject (user ID)