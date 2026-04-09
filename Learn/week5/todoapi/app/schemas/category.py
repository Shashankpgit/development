from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime


class CategoryBase(BaseModel):
    name: str = Field(..., min_length=1, max_length=50)


class CategoryCreate(CategoryBase):
    pass


class CategoryResponse(CategoryBase):
    id: int
    created_at: datetime
    
    class Config:
        from_attributes = True


class CategoryWithTodos(CategoryResponse):
    """Category with associated todos"""
    todos: List["TodoResponse"] = []


# Avoid circular imports
from app.schemas.todo import TodoResponse
CategoryWithTodos.model_rebuild()
