from pydantic import BaseModel, EmailStr, Field
from typing import List, Optional
from datetime import datetime


class UserBase(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    email: EmailStr


class UserCreate(UserBase):
    pass


class UserUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=100)
    email: Optional[EmailStr] = None


class UserResponse(UserBase):
    id: int
    created_at: datetime
    updated_at: Optional[datetime] = None
    
    class Config:
        from_attributes = True


class UserWithTodos(UserResponse):
    """User response with todos included"""
    todos: List["TodoResponse"] = []


# Avoid circular imports
from app.schemas.todo import TodoResponse
UserWithTodos.model_rebuild()
