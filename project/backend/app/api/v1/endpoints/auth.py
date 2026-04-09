"""
Authentication endpoints
"""
from datetime import timedelta
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session

from app.api.deps import get_db, get_current_active_user
from app.core.config import settings
from app.core.security import create_access_token
from app.crud import user as crud_user
from app.schemas.user import UserCreate, UserResponse
from app.schemas.token import Token
from app.models.user import User

router = APIRouter()


@router.post("/register", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
def register(
    user_in: UserCreate,
    db: Session = Depends(get_db)
):
    """
    Register a new user
    
    - **email**: Valid email address (must be unique)
    - **password**: Minimum 8 characters, must include uppercase, lowercase, and digit
    - **full_name**: Optional full name
    
    Returns created user info (no password!)
    """
    # Check if user already exists
    user = crud_user.get_user_by_email(db, email=user_in.email)
    
    if user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered"
        )
    
    # Create user
    user = crud_user.create_user(db=db, user_in=user_in)
    
    return user


@router.post("/login", response_model=Token)
def login(
    db: Session = Depends(get_db),
    form_data: OAuth2PasswordRequestForm = Depends()
):
    """
    OAuth2 compatible token login
    
    Use 'username' field for email
    Returns JWT access token
    """
    # Authenticate user
    user = crud_user.authenticate(
        db,
        email=form_data.username,  # OAuth2 spec uses 'username'
        password=form_data.password
    )
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Inactive user"
        )
    
    # Create access token
    access_token_expires = timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        subject=user.id,
        expires_delta=access_token_expires
    )
    
    return {
        "access_token": access_token,
        "token_type": "bearer"
    }


@router.post("/login/json", response_model=Token)
def login_json(
    email: str,
    password: str,
    db: Session = Depends(get_db)
):
    """
    Alternative JSON login (not OAuth2 standard)
    
    For clients that prefer JSON over form data
    """
    user = crud_user.authenticate(db, email=email, password=password)
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password"
        )
    
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Inactive user"
        )
    
    access_token_expires = timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        subject=user.id,
        expires_delta=access_token_expires
    )
    
    return {
        "access_token": access_token,
        "token_type": "bearer"
    }


@router.post("/test-token", response_model=UserResponse)
def test_token(current_user: User = Depends(get_current_active_user)):
    """
    Test access token
    
    Protected endpoint - requires valid JWT token
    Returns current user info
    """
    return current_user