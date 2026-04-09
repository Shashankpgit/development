from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime


class CommentBase(BaseModel):
    text: str = Field(..., min_length=1, max_length=500)


class CommentCreate(CommentBase):
    todo_id: int
    user_id: int


class CommentResponse(CommentBase):
    id: int
    todo_id: int
    user_id: int
    created_at: datetime
    
    class Config:
        from_attributes = True


class CommentWithRelations(CommentResponse):
    """Comment with todo and author information"""
    author: "UserResponse"
    todo: "TodoResponse"


# Avoid circular imports
from app.schemas.user import UserResponse
from app.schemas.todo import TodoResponse
CommentWithRelations.model_rebuild()
