"""
Security utilities: Password hashing and JWT tokens
"""
from datetime import datetime, timedelta
from typing import Optional, Any
from jose import jwt, JWTError
from passlib.context import CryptContext
from app.core.config import settings

# Password hashing context
pwd_context = CryptContext(schemes=["bcrypt_sha256", "bcrypt"], deprecated="auto")


def create_access_token(subject: str | int, expires_delta: Optional[timedelta] = None) -> str:
    """
    Create JWT access token
    
    Args:
        subject: User ID (what the token represents)
        expires_delta: Optional custom expiration time
        
    Returns:
        Encoded JWT token
    """
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(
            minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES
        )
    
    to_encode = {
        "exp": expire,
        "sub": str(subject)
    }
    
    encoded_jwt = jwt.encode(
        to_encode,
        settings.SECRET_KEY,
        algorithm=settings.ALGORITHM
    )
    
    return encoded_jwt


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """
    Verify password against hash
    
    Args:
        plain_password: Plain text password
        hashed_password: Bcrypt hash
        
    Returns:
        True if password matches
    """
    return pwd_context.verify(plain_password, hashed_password)


def get_password_hash(password: str) -> str:
    """
    Hash password using bcrypt
    
    Args:
        password: Plain text password
        
    Returns:
        Bcrypt hash
    """
    return pwd_context.hash(password)