"""
User management endpoints (all protected)
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List

from app.api.deps import (
    get_db,
    get_current_active_user,
    get_current_superuser
)
from app.crud import user as crud_user
from app.schemas.user import UserResponse, UserUpdate
from app.models.user import User

router = APIRouter()


@router.get("/me", response_model=UserResponse)
def read_user_me(
    current_user: User = Depends(get_current_active_user)
):
    """
    Get current user profile
    
    Protected - requires authentication
    """
    return current_user


@router.put("/me", response_model=UserResponse)
def update_user_me(
    user_in: UserUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """
    Update current user profile
    
    Protected - can only update own profile
    """
    user = crud_user.update_user(db, user_id=current_user.id, user_in=user_in)
    return user


@router.get("/", response_model=List[UserResponse])
def read_users(
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_superuser)
):
    """
    Get all users
    
    Protected - requires superuser permissions
    """
    users = crud_user.get_users(db, skip=skip, limit=limit)
    return users


@router.get("/{user_id}", response_model=UserResponse)
def read_user_by_id(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """
    Get user by ID
    
    Protected - authenticated users can view other users
    """
    user = crud_user.get_user(db, user_id=user_id)
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    return user


@router.delete("/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_user(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_superuser)
):
    """
    Delete user
    
    Protected - requires superuser permissions
    """
    success = crud_user.delete_user(db, user_id=user_id)
    
    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )