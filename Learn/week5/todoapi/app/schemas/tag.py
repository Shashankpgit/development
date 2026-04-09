from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime


class TagBase(BaseModel):
    name: str = Field(..., min_length=1, max_length=50)


class TagCreate(TagBase):
    pass


class TagResponse(TagBase):
    id: int
    created_at: datetime
    
    class Config:
        from_attributes = True


class TagWithTodos(TagResponse):
    """Tag with associated todos"""
    todos: List["TodoResponse"] = []


# Avoid circular imports
from app.schemas.todo import TodoResponse
TagWithTodos.model_rebuild()
