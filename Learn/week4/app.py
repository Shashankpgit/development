from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime

app = FastAPI(
    title="Todo List API",
    description="A simple todo list API with CRUD operations",
    version="1.0.0"
)

# ============= MODELS =============

class TodoBase(BaseModel):
    """Base Todo model with common fields"""
    title: str = Field(..., min_length=1, max_length=100, description="Todo title")
    description: str = Field(..., max_length=500, description="Todo description")
    completed: bool = Field(default=False, description="Completion status")

class TodoCreate(TodoBase):
    """Model for creating a new todo - inherits from TodoBase"""
    pass

class TodoUpdate(BaseModel):
    """Model for updating a todo - all fields optional"""
    title: Optional[str] = Field(None, min_length=1, max_length=100)
    description: Optional[str] = Field(None, max_length=500)
    completed: Optional[bool] = None

class TodoResponse(TodoBase):
    """Model for todo response - includes ID and timestamp"""
    id: int
    created_at: datetime
    
    class Config:
        # This allows the model to work with ORM objects later
        from_attributes = True

# ============= IN-MEMORY DATABASE =============
# In a real app, this would be a real database
# For now, we'll use a simple list

todos_db: List[dict] = []
next_id = 1

# ============= ENDPOINTS =============

@app.get("/", tags=["Root"])
def root():
    """Welcome endpoint"""
    return {
        "message": "Welcome to Todo API",
        "endpoints": {
            "docs": "/docs",
            "create_todo": "POST /todos",
            "get_todos": "GET /todos",
            "get_todo": "GET /todos/{todo_id}",
            "update_todo": "PUT /todos/{todo_id}",
            "delete_todo": "DELETE /todos/{todo_id}"
        }
    }

@app.post("/todos", response_model=TodoResponse, status_code=201, tags=["Todos"])
def create_todo(todo: TodoCreate):
    """
    Create a new todo item
    
    - **title**: Todo title (1-100 characters)
    - **description**: Todo description (max 500 characters)
    - **completed**: Completion status (default: false)
    
    Returns the created todo with ID and timestamp
    """
    global next_id
    
    # Create todo with ID and timestamp
    todo_dict = {
        "id": next_id,
        "title": todo.title,
        "description": todo.description,
        "completed": todo.completed,
        "created_at": datetime.now()
    }
    
    # Add to "database"
    todos_db.append(todo_dict)
    next_id += 1
    
    return todo_dict

@app.get("/todos", response_model=List[TodoResponse], tags=["Todos"])
def get_todos(
    completed: Optional[bool] = None,
    skip: int = 0,
    limit: int = 10
):
    """
    Get all todos with optional filtering
    
    - **completed**: Filter by completion status (optional)
    - **skip**: Number of todos to skip (pagination)
    - **limit**: Maximum number of todos to return
    """
    # Filter by completed status if provided
    if completed is not None:
        filtered_todos = [t for t in todos_db if t["completed"] == completed]
    else:
        filtered_todos = todos_db
    
    # Apply pagination
    return filtered_todos[skip : skip + limit]

@app.get("/todos/{todo_id}", response_model=TodoResponse, tags=["Todos"])
def get_todo(todo_id: int):
    """
    Get a specific todo by ID
    
    - **todo_id**: The ID of the todo to retrieve
    
    Returns 404 if todo not found
    """
    # Find todo by ID
    for todo in todos_db:
        if todo["id"] == todo_id:
            return todo
    
    # If not found, raise 404 error
    raise HTTPException(
        status_code=404,
        detail=f"Todo with id {todo_id} not found"
    )

@app.put("/todos/{todo_id}", response_model=TodoResponse, tags=["Todos"])
def update_todo(todo_id: int, todo_update: TodoUpdate):
    """
    Update a todo item
    
    - **todo_id**: The ID of the todo to update
    - **title**: New title (optional)
    - **description**: New description (optional)
    - **completed**: New completion status (optional)
    
    Only provided fields will be updated
    """
    # Find todo
    for todo in todos_db:
        if todo["id"] == todo_id:
            # Update only provided fields
            if todo_update.title is not None:
                todo["title"] = todo_update.title
            if todo_update.description is not None:
                todo["description"] = todo_update.description
            if todo_update.completed is not None:
                todo["completed"] = todo_update.completed
            
            return todo
    
    # If not found, raise 404 error
    raise HTTPException(
        status_code=404,
        detail=f"Todo with id {todo_id} not found"
    )

@app.delete("/todos/{todo_id}", status_code=204, tags=["Todos"])
def delete_todo(todo_id: int):
    """
    Delete a todo item
    
    - **todo_id**: The ID of the todo to delete
    
    Returns 204 No Content on success, 404 if not found
    """
    global todos_db
    
    # Find and remove todo
    for i, todo in enumerate(todos_db):
        if todo["id"] == todo_id:
            todos_db.pop(i)
            return
    
    # If not found, raise 404 error
    raise HTTPException(
        status_code=404,
        detail=f"Todo with id {todo_id} not found"
    )

@app.get("/todos/stats/summary", tags=["Stats"])
def get_stats():
    """Get statistics about todos"""
    total = len(todos_db)
    completed = sum(1 for t in todos_db if t["completed"])
    pending = total - completed
    
    return {
        "total": total,
        "completed": completed,
        "pending": pending,
        "completion_rate": (completed / total * 100) if total > 0 else 0
    }