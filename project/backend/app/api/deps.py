"""
API dependencies for authentication
"""
from typing import Generator
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import jwt, JWTError
from sqlalchemy.orm import Session

from app.core.config import settings
from app.db.session import get_db
from app.crud import user as crud_user
from app.models.user import User
from app.schemas.token import TokenPayload

# OAuth2 scheme - tells FastAPI where to find the token
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")


def get_current_user(
    db: Session = Depends(get_db),
    token: str = Depends(oauth2_scheme)
) -> User:
    """
    Get current authenticated user from JWT token
    
    This dependency:
    1. Extracts token from Authorization header
    2. Verifies token signature
    3. Gets user ID from token
    4. Fetches user from database
    5. Returns user or raises 401
    
    Usage:
        @app.get("/protected")
        def protected(user: User = Depends(get_current_user)):
            return {"user": user.email}
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    try:
        # Decode JWT token
        payload = jwt.decode(
            token,
            settings.SECRET_KEY,
            algorithms=[settings.ALGORITHM]
        )
        
        # Extract user ID
        token_data = TokenPayload(**payload)
        
        if token_data.sub is None:
            raise credentials_exception
            
        user_id = int(token_data.sub)
        
    except (JWTError, ValueError):
        raise credentials_exception
    
    # Get user from database
    user = crud_user.get_user(db, user_id=user_id)
    
    if user is None:
        raise credentials_exception
    
    return user


def get_current_active_user(
    current_user: User = Depends(get_current_user)
) -> User:
    """
    Get current active user (not deactivated)
    
    Checks if user account is active
    """
    if not current_user.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Inactive user"
        )
    
    return current_user


def get_current_verified_user(
    current_user: User = Depends(get_current_active_user)
) -> User:
    """
    Get current verified user (email verified)
    
    Checks if user has verified their email
    """
    if not current_user.is_verified:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email not verified"
        )
    
    return current_user


def get_current_superuser(
    current_user: User = Depends(get_current_user)
) -> User:
    """
    Get current superuser (admin)
    
    Checks if user has superuser privileges
    """
    if not current_user.is_superuser:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not enough permissions"
        )
    
    return current_user