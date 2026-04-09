from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from app.api import deps
from app.crud import crud_user
from app.schemas.user import UserCreate, UserUpdate, UserResponse, UserWithTodos

router = APIRouter()


@router.post("/", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
def create_user(
    *,
    db: Session = Depends(deps.get_db),
    user_in: UserCreate
):
    """Create new user"""
    user = crud_user.get_user_by_email(db, email=user_in.email)
    if user:
        raise HTTPException(
            status_code=400,
            detail="The user with this email already exists in the system.",
        )
    return crud_user.create_user(db, user=user_in)


@router.get("/", response_model=List[UserResponse])
def read_users(
    db: Session = Depends(deps.get_db),
    skip: int = 0,
    limit: int = 100
):
    """Retrieve users"""
    users = crud_user.get_users(db, skip=skip, limit=limit)
    return users


@router.get("/{user_id}", response_model=UserWithTodos)
def read_user_by_id(
    user_id: int,
    db: Session = Depends(deps.get_db)
):
    """Get user by ID with todos"""
    user = crud_user.get_user_with_todos(db, user_id=user_id)
    if not user:
        raise HTTPException(
            status_code=404,
            detail="User not found",
        )
    return user


@router.put("/{user_id}", response_model=UserResponse)
def update_user(
    *,
    db: Session = Depends(deps.get_db),
    user_id: int,
    user_in: UserUpdate
):
    """Update a user"""
    user = crud_user.update_user(db, user_id=user_id, user_update=user_in)
    if not user:
        raise HTTPException(
            status_code=404,
            detail="User not found",
        )
    return user


@router.delete("/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_user(
    *,
    db: Session = Depends(deps.get_db),
    user_id: int
):
    """Delete a user"""
    success = crud_user.delete_user(db, user_id=user_id)
    if not success:
        raise HTTPException(
            status_code=404,
            detail="User not found",
        )
    return None
