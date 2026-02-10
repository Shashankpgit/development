# Week 5: Database Integration with PostgreSQL 🗄️

**Goal**: Connect your API to a real database so data persists between server restarts

**What You'll Build**: Todo API with PostgreSQL database (properly structured!)

**New Concepts**: 
- PostgreSQL database
- SQLAlchemy ORM
- Database models vs Pydantic schemas
- Sessions and connections
- Database migrations (basic)

---

## Part 1: Understanding Databases - Deep Dive

### What is a Database?

**Simple explanation:**
A database is like a smart filing cabinet that:
- Stores data permanently (even after computer restarts)
- Organizes data in tables (like Excel spreadsheets)
- Allows fast searching and filtering
- Handles multiple users simultaneously
- Ensures data integrity

---

### Why Do We Need a Database?

**What we've been doing (In-Memory Storage):**

```python
# Week 4 approach
todos_db = []  # Just a Python list

@app.post("/todos")
def create_todo(todo: TodoCreate):
    todos_db.append(todo)  # Stored in RAM
    return todo

# Problem: When you restart server...
# todos_db = []  # ALL DATA IS GONE! 💥
```

**Problems with in-memory storage:**
- ❌ Data lost on server restart
- ❌ Can't handle large amounts of data (RAM is limited)
- ❌ No concurrent access control
- ❌ No search optimization
- ❌ No data relationships
- ❌ No backup/recovery

---

**With a Real Database:**

```python
# Week 5 approach
@app.post("/todos")
def create_todo(todo: TodoCreate, db: Session):
    db_todo = Todo(**todo.dict())  # Create database object
    db.add(db_todo)                # Add to database
    db.commit()                    # Save permanently
    return db_todo

# Benefits:
# ✅ Data persists forever (even after restart)
# ✅ Can store millions of records
# ✅ Handles multiple users
# ✅ Fast searching with indexes
# ✅ Data integrity with constraints
# ✅ Automatic backups
```

---

### Database vs In-Memory: Visual Comparison

```
IN-MEMORY (Week 4):
┌─────────────────────┐
│   Python Process    │
│  ┌───────────────┐  │
│  │ todos_db = [] │  │  ← Lives in RAM
│  └───────────────┘  │
└─────────────────────┘
      ↓
  Server restarts
      ↓
┌─────────────────────┐
│   Python Process    │
│  ┌───────────────┐  │
│  │ todos_db = [] │  │  ← EMPTY! Data lost!
│  └───────────────┘  │
└─────────────────────┘


DATABASE (Week 5):
┌─────────────────────┐
│   Python Process    │  ← Your FastAPI app
└─────────────────────┘
          ↕
    Talks to...
          ↕
┌─────────────────────┐
│   PostgreSQL DB     │  ← Separate process
│  ┌───────────────┐  │
│  │ todos table   │  │  ← Saved on disk
│  │ users table   │  │
│  └───────────────┘  │
└─────────────────────┘
      ↓
  Server restarts
      ↓
┌─────────────────────┐
│   Python Process    │  ← App restarts
└─────────────────────┘
          ↕
    Reconnects...
          ↕
┌─────────────────────┐
│   PostgreSQL DB     │  
│  ┌───────────────┐  │
│  │ todos table   │  │  ← DATA STILL HERE! ✅
│  │ users table   │  │
│  └───────────────┘  │
└─────────────────────┘
```

---

### SQL vs NoSQL (Quick Overview)

**SQL Databases (Relational):**
- PostgreSQL ← We'll use this
- MySQL
- SQLite

**Characteristics:**
- Data in tables with rows and columns
- Strict schema (defined structure)
- Relationships between tables
- Good for structured data

**Example Table:**
```
todos table:
┌────┬─────────────┬─────────────┬───────────┐
│ id │    title    │ description │ completed │
├────┼─────────────┼─────────────┼───────────┤
│ 1  │ Learn SQL   │ Study DB    │   false   │
│ 2  │ Build API   │ FastAPI     │   true    │
└────┴─────────────┴─────────────┴───────────┘
```

**NoSQL Databases:**
- MongoDB
- Redis
- DynamoDB

**Characteristics:**
- Flexible schema
- Document/key-value based
- Good for unstructured data

**We're using PostgreSQL (SQL) because:**
- ✅ Industry standard
- ✅ Powerful querying
- ✅ Great for learning
- ✅ Free and open source
- ✅ Widely used

---

## Part 2: What is an ORM (SQLAlchemy)?

### ORM = Object Relational Mapper

**The Problem ORM Solves:**

Without ORM, you write raw SQL:
```python
# Raw SQL (painful! 😫)
cursor.execute("""
    INSERT INTO todos (title, description, completed)
    VALUES (%s, %s, %s)
    RETURNING id
""", (todo.title, todo.description, todo.completed))

result = cursor.fetchone()
```

**Problems:**
- ❌ Have to write SQL strings
- ❌ SQL syntax errors
- ❌ Different for each database
- ❌ Prone to SQL injection
- ❌ Hard to maintain

---

**With ORM (beautiful! 😊):**

```python
# SQLAlchemy ORM (easy!)
todo = Todo(
    title=todo.title,
    description=todo.description,
    completed=todo.completed
)
db.add(todo)
db.commit()
```

**Benefits:**
- ✅ Write Python, not SQL
- ✅ Type-safe
- ✅ Database-independent
- ✅ SQL injection protection
- ✅ Easy to maintain

---

### How ORM Works (Behind the Scenes)

```
YOU WRITE (Python):
┌────────────────────────────────┐
│ todo = Todo(title="Learn")     │
│ db.add(todo)                   │
│ db.commit()                    │
└────────────────────────────────┘
          ↓
    ORM Converts
          ↓
ACTUAL SQL (Generated):
┌────────────────────────────────┐
│ INSERT INTO todos              │
│ (title, description, completed)│
│ VALUES ('Learn', '', false)    │
└────────────────────────────────┘
          ↓
    Sent to Database
          ↓
┌────────────────────────────────┐
│     PostgreSQL Database        │
│   Stores the data on disk      │
└────────────────────────────────┘
```

You work with Python objects, ORM handles SQL!

---

## Part 3: SQLAlchemy Models vs Pydantic Schemas

### The Confusion (Very Common!)

**Question:** "We have Pydantic models AND SQLAlchemy models. Why two models??"

**Answer:** They serve DIFFERENT purposes!

---

### SQLAlchemy Model (Database Layer)

**Purpose:** Represents database table structure

```python
# app/models/todo.py
from sqlalchemy import Column, Integer, String, Boolean
from app.database import Base

class Todo(Base):  # ← SQLAlchemy model
    __tablename__ = "todos"
    
    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, nullable=False)
    description = Column(String)
    completed = Column(Boolean, default=False)
```

**What it does:**
- Defines database table structure
- Maps to actual database columns
- Used for database operations (create, read, update, delete)
- Talks to PostgreSQL

**Think of it as:** Blueprint for database table

---

### Pydantic Schema (API Layer)

**Purpose:** Validates API request/response data

```python
# app/schemas/todo.py
from pydantic import BaseModel

class TodoCreate(BaseModel):  # ← Pydantic schema
    title: str
    description: str
    completed: bool = False
```

**What it does:**
- Validates incoming API data
- Defines request/response format
- Converts between JSON and Python
- Used in API endpoints

**Think of it as:** Contract for API communication

---

### Side-by-Side Comparison

```python
# DATABASE MODEL (SQLAlchemy)
# File: app/models/todo.py
class Todo(Base):
    __tablename__ = "todos"
    id = Column(Integer, primary_key=True)
    title = Column(String)
    created_at = Column(DateTime, default=datetime.now)

# Purpose: How data is STORED in database
# Used by: SQLAlchemy to create tables and run queries


# API SCHEMA (Pydantic)  
# File: app/schemas/todo.py
class TodoCreate(BaseModel):
    title: str
    description: str

class TodoResponse(BaseModel):
    id: int
    title: str
    created_at: datetime

# Purpose: How data is SENT/RECEIVED in API
# Used by: FastAPI to validate requests and format responses
```

---

### Why We Need Both

**Flow of data:**

```
CLIENT REQUEST:
{
  "title": "Learn DB",
  "description": "Study PostgreSQL"
}
      ↓
  Pydantic validates (TodoCreate)
      ↓
  Convert to SQLAlchemy model (Todo)
      ↓
  Save to database
      ↓
  Read from database
      ↓
  Convert to Pydantic (TodoResponse)
      ↓
RESPONSE TO CLIENT:
{
  "id": 1,
  "title": "Learn DB",
  "description": "Study PostgreSQL",
  "created_at": "2026-02-08T10:00:00"
}
```

**Key insight:**
- **Pydantic** = API boundary (what goes in/out)
- **SQLAlchemy** = Database boundary (what's stored)

They work together but serve different roles!

---

## Part 4: Setting Up PostgreSQL

### Option 1: Install PostgreSQL Locally (Recommended for Learning)

**Windows:**
1. Download from: https://www.postgresql.org/download/windows/
2. Run installer (use default settings)
3. Set password for postgres user (remember this!)
4. Default port: 5432

**Mac:**
```bash
# Using Homebrew
brew install postgresql@14
brew services start postgresql@14
```

**Linux (Ubuntu/Debian):**
```bash
sudo apt update
sudo apt install postgresql postgresql-contrib
sudo systemctl start postgresql
```

---

### Option 2: Docker (Alternative)

```bash
docker run --name postgres-todo \
  -e POSTGRES_PASSWORD=mysecretpassword \
  -e POSTGRES_DB=tododb \
  -p 5432:5432 \
  -d postgres:14
```

---

### Create Database

**Using psql (PostgreSQL command line):**

```bash
# Connect to PostgreSQL
psql -U postgres

# Create database
CREATE DATABASE tododb;

# List databases
\l

# Connect to your database
\c tododb

# Exit
\q
```

**Or using GUI tool (pgAdmin):**
1. Open pgAdmin
2. Right-click "Databases"
3. Create → Database
4. Name: tododb

---

## Part 5: Project Structure (Proper Organization!)

### Complete Folder Structure

```
todo-api/
├── app/
│   ├── __init__.py
│   ├── main.py                 # Entry point
│   ├── config.py               # Configuration
│   ├── database.py             # Database connection
│   │
│   ├── models/                 # SQLAlchemy models (Database)
│   │   ├── __init__.py
│   │   └── todo.py
│   │
│   ├── schemas/                # Pydantic schemas (API)
│   │   ├── __init__.py
│   │   └── todo.py
│   │
│   ├── crud/                   # Database operations
│   │   ├── __init__.py
│   │   └── crud_todo.py
│   │
│   └── api/                    # API routes
│       ├── __init__.py
│       ├── deps.py             # Dependencies (DB session)
│       └── v1/
│           ├── __init__.py
│           ├── api.py          # Router aggregator
│           └── endpoints/
│               ├── __init__.py
│               └── todos.py
│
├── .env                        # Environment variables (SECRET!)
├── .env.example               # Example env file
├── .gitignore
├── requirements.txt
└── README.md
```

**Why this structure?**
- ✅ Clear separation of concerns
- ✅ Easy to find code
- ✅ Scalable (add users, auth, etc.)
- ✅ Team-friendly
- ✅ Industry standard

---

## Part 6: Building the Application (Step by Step)

### Step 1: Install Dependencies

```bash
# Create virtual environment
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

# Install packages
pip install fastapi uvicorn sqlalchemy psycopg2-binary python-dotenv pydantic-settings

# Save dependencies
pip freeze > requirements.txt
```

**What each package does:**
- `fastapi` - Web framework
- `uvicorn` - ASGI server
- `sqlalchemy` - ORM for database
- `psycopg2-binary` - PostgreSQL driver
- `python-dotenv` - Load environment variables
- `pydantic-settings` - Settings management

---

### Step 2: Create `.env` File

```bash
# .env (DO NOT COMMIT TO GIT!)
DATABASE_URL=postgresql://postgres:yourpassword@localhost:5432/tododb
PROJECT_NAME=Todo API
VERSION=1.0.0
```

**Important:**
- Replace `yourpassword` with your actual PostgreSQL password
- Never commit `.env` to Git!
- This file contains secrets

---

### Step 3: Create `.env.example`

```bash
# .env.example (Safe to commit)
DATABASE_URL=postgresql://user:password@localhost:5432/dbname
PROJECT_NAME=Your Project Name
VERSION=1.0.0
```

---

### Step 4: Create `.gitignore`

```
# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
venv/
env/

# Environment
.env

# IDE
.vscode/
.idea/
*.swp

# Database
*.db
*.sqlite3
```

---

### Step 5: Configuration (`app/config.py`)

```python
"""
Application configuration
Loads settings from environment variables
"""
from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    """Application settings"""
    
    # Project info
    PROJECT_NAME: str
    VERSION: str
    
    # Database
    DATABASE_URL: str
    
    class Config:
        env_file = ".env"
        case_sensitive = True


@lru_cache()
def get_settings() -> Settings:
    """
    Get settings (cached)
    lru_cache ensures we only load .env once
    """
    return Settings()


# Create settings instance
settings = get_settings()
```

**What this does:**
- Loads configuration from `.env` file
- Type-safe settings with Pydantic
- Cached (only reads file once)
- Easy to access anywhere: `from app.config import settings`

---

### Step 6: Database Connection (`app/database.py`)

```python
"""
Database connection and session management
"""
from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from app.config import settings

# Create database engine
# echo=True shows SQL queries in console (useful for debugging)
engine = create_engine(
    settings.DATABASE_URL,
    echo=True,  # Set to False in production
    pool_pre_ping=True,  # Verify connections before using
)

# Create session factory
# Session is how we talk to the database
SessionLocal = sessionmaker(
    autocommit=False,  # Don't auto-commit (we control when to save)
    autoflush=False,   # Don't auto-flush (we control when to sync)
    bind=engine        # Bind to our engine
)

# Base class for all database models
Base = declarative_base()


def get_db():
    """
    Dependency that provides database session
    
    Usage in endpoints:
        def my_endpoint(db: Session = Depends(get_db)):
            # Use db here
    
    The session is automatically closed after request
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
```

**Key concepts explained:**

**Engine:**
- Connection to database
- Manages connection pool
- Created once at startup

**Session:**
- Your "conversation" with database
- Create one per request
- Must be closed after use

**SessionLocal:**
- Factory that creates sessions
- Each request gets its own session

**get_db():**
- Dependency function
- Creates session
- Automatically closes it
- Used in all endpoints

---

### Step 7: Database Model (`app/models/todo.py`)

```python
"""
SQLAlchemy model for Todo
Defines the database table structure
"""
from sqlalchemy import Column, Integer, String, Boolean, DateTime
from sqlalchemy.sql import func
from app.database import Base


class Todo(Base):
    """
    Todo database model
    This creates the 'todos' table in PostgreSQL
    """
    
    __tablename__ = "todos"
    
    # Primary key - unique identifier
    id = Column(Integer, primary_key=True, index=True)
    
    # Title - required string
    title = Column(String(100), nullable=False, index=True)
    
    # Description - optional string
    description = Column(String(500), nullable=True)
    
    # Completion status - defaults to False
    completed = Column(Boolean, default=False, nullable=False)
    
    # Timestamp - automatically set on creation
    created_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),  # PostgreSQL function
        nullable=False
    )
    
    # Timestamp - automatically updated on modification
    updated_at = Column(
        DateTime(timezone=True),
        onupdate=func.now(),  # Update on every modification
        nullable=True
    )
    
    def __repr__(self):
        """String representation for debugging"""
        return f"<Todo(id={self.id}, title='{self.title}', completed={self.completed})>"
```

**Column types explained:**

- `Integer` - Whole numbers (1, 2, 3...)
- `String(100)` - Text up to 100 characters
- `Boolean` - True/False
- `DateTime` - Date and time

**Column options:**

- `primary_key=True` - Unique identifier
- `index=True` - Fast searching on this column
- `nullable=False` - Cannot be NULL (required)
- `default=False` - Default value if not provided
- `server_default=func.now()` - PostgreSQL sets the value

---

### Step 8: Pydantic Schemas (`app/schemas/todo.py`)

```python
"""
Pydantic schemas for Todo
Defines API request/response formats
"""
from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime


class TodoBase(BaseModel):
    """Base schema with common fields"""
    title: str = Field(..., min_length=1, max_length=100)
    description: str = Field(..., max_length=500)
    completed: bool = Field(default=False)


class TodoCreate(TodoBase):
    """
    Schema for creating a todo
    Client sends this in POST request
    """
    pass


class TodoUpdate(BaseModel):
    """
    Schema for updating a todo
    All fields are optional (client can update any combination)
    """
    title: Optional[str] = Field(None, min_length=1, max_length=100)
    description: Optional[str] = Field(None, max_length=500)
    completed: Optional[bool] = None


class TodoResponse(TodoBase):
    """
    Schema for todo response
    API returns this to client
    Includes fields that are generated by database (id, timestamps)
    """
    id: int
    created_at: datetime
    updated_at: Optional[datetime] = None
    
    class Config:
        """Pydantic configuration"""
        # Allows Pydantic to work with SQLAlchemy models
        from_attributes = True
        
        # Example for documentation
        json_schema_extra = {
            "example": {
                "id": 1,
                "title": "Learn SQLAlchemy",
                "description": "Study ORM concepts",
                "completed": False,
                "created_at": "2026-02-08T10:00:00",
                "updated_at": None
            }
        }


class TodoList(BaseModel):
    """
    Schema for paginated todo list
    """
    todos: list[TodoResponse]
    total: int
    skip: int
    limit: int
```

---

### Step 9: CRUD Operations (`app/crud/crud_todo.py`)

```python
"""
CRUD operations for Todo
All database interactions go here
"""
from sqlalchemy.orm import Session
from typing import List, Optional
from app.models.todo import Todo
from app.schemas.todo import TodoCreate, TodoUpdate


def get_todo(db: Session, todo_id: int) -> Optional[Todo]:
    """
    Get a single todo by ID
    
    Args:
        db: Database session
        todo_id: ID of the todo to retrieve
    
    Returns:
        Todo object if found, None otherwise
    """
    return db.query(Todo).filter(Todo.id == todo_id).first()


def get_todos(
    db: Session,
    skip: int = 0,
    limit: int = 100,
    completed: Optional[bool] = None
) -> List[Todo]:
    """
    Get all todos with optional filtering and pagination
    
    Args:
        db: Database session
        skip: Number of records to skip (for pagination)
        limit: Maximum number of records to return
        completed: Filter by completion status (optional)
    
    Returns:
        List of Todo objects
    """
    query = db.query(Todo)
    
    # Apply filter if provided
    if completed is not None:
        query = query.filter(Todo.completed == completed)
    
    # Apply pagination and return
    return query.offset(skip).limit(limit).all()


def create_todo(db: Session, todo: TodoCreate) -> Todo:
    """
    Create a new todo
    
    Args:
        db: Database session
        todo: TodoCreate schema with todo data
    
    Returns:
        Created Todo object
    """
    # Create SQLAlchemy model instance from Pydantic schema
    db_todo = Todo(**todo.model_dump())
    
    # Add to session
    db.add(db_todo)
    
    # Commit to database (actually save)
    db.commit()
    
    # Refresh to get generated fields (id, created_at)
    db.refresh(db_todo)
    
    return db_todo


def update_todo(
    db: Session,
    todo_id: int,
    todo_update: TodoUpdate
) -> Optional[Todo]:
    """
    Update an existing todo
    
    Args:
        db: Database session
        todo_id: ID of todo to update
        todo_update: TodoUpdate schema with fields to update
    
    Returns:
        Updated Todo object if found, None otherwise
    """
    # Get the todo
    db_todo = get_todo(db, todo_id)
    if not db_todo:
        return None
    
    # Get update data (only fields that were provided)
    update_data = todo_update.model_dump(exclude_unset=True)
    
    # Update fields
    for field, value in update_data.items():
        setattr(db_todo, field, value)
    
    # Commit changes
    db.commit()
    
    # Refresh to get updated timestamp
    db.refresh(db_todo)
    
    return db_todo


def delete_todo(db: Session, todo_id: int) -> bool:
    """
    Delete a todo
    
    Args:
        db: Database session
        todo_id: ID of todo to delete
    
    Returns:
        True if deleted, False if not found
    """
    db_todo = get_todo(db, todo_id)
    if not db_todo:
        return False
    
    db.delete(db_todo)
    db.commit()
    
    return True


def get_todo_count(db: Session) -> dict:
    """
    Get todo statistics
    
    Returns:
        Dictionary with total, completed, and pending counts
    """
    total = db.query(Todo).count()
    completed = db.query(Todo).filter(Todo.completed == True).count()
    pending = total - completed
    
    return {
        "total": total,
        "completed": completed,
        "pending": pending,
        "completion_rate": (completed / total * 100) if total > 0 else 0
    }
```

**CRUD explained:**

- **C**reate - `create_todo()`
- **R**ead - `get_todo()`, `get_todos()`
- **U**pdate - `update_todo()`
- **D**elete - `delete_todo()`

**Key SQLAlchemy methods:**

- `db.query(Todo)` - Start a query
- `.filter()` - Add WHERE condition
- `.first()` - Get first result
- `.all()` - Get all results
- `db.add()` - Stage for insertion
- `db.commit()` - Save changes
- `db.refresh()` - Reload from database
- `db.delete()` - Stage for deletion

---

### Step 10: Dependencies (`app/api/deps.py`)

```python
"""
Shared dependencies for API endpoints
"""
from typing import Generator
from sqlalchemy.orm import Session
from app.database import get_db as get_database_session


def get_db() -> Generator:
    """
    Get database session dependency
    
    This is used in endpoint functions like:
        def my_endpoint(db: Session = Depends(get_db)):
            # db is automatically provided and cleaned up
    """
    return get_database_session()
```

---

### Step 11: API Endpoints (`app/api/v1/endpoints/todos.py`)

```python
"""
Todo API endpoints
"""
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from typing import List, Optional

from app.api.deps import get_db
from app.schemas.todo import TodoCreate, TodoUpdate, TodoResponse
from app.crud import crud_todo

router = APIRouter()


@router.post(
    "/",
    response_model=TodoResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new todo",
    description="Create a new todo item with title and description"
)
def create_todo(
    todo: TodoCreate,
    db: Session = Depends(get_db)
):
    """
    Create a new todo:
    
    - **title**: Todo title (1-100 characters)
    - **description**: Todo description (max 500 characters)
    - **completed**: Completion status (default: false)
    """
    return crud_todo.create_todo(db=db, todo=todo)


@router.get(
    "/",
    response_model=List[TodoResponse],
    summary="Get all todos",
    description="Retrieve all todos with optional filtering and pagination"
)
def get_todos(
    skip: int = Query(0, ge=0, description="Number of records to skip"),
    limit: int = Query(100, ge=1, le=1000, description="Maximum records to return"),
    completed: Optional[bool] = Query(None, description="Filter by completion status"),
    db: Session = Depends(get_db)
):
    """
    Get all todos with optional filtering:
    
    - **skip**: Number of records to skip (for pagination)
    - **limit**: Maximum number of records to return (1-1000)
    - **completed**: Filter by completion status (optional)
    """
    return crud_todo.get_todos(
        db=db,
        skip=skip,
        limit=limit,
        completed=completed
    )


@router.get(
    "/{todo_id}",
    response_model=TodoResponse,
    summary="Get a specific todo",
    description="Retrieve a single todo by its ID"
)
def get_todo(
    todo_id: int,
    db: Session = Depends(get_db)
):
    """
    Get a specific todo by ID
    """
    todo = crud_todo.get_todo(db=db, todo_id=todo_id)
    if not todo:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Todo with id {todo_id} not found"
        )
    return todo


@router.put(
    "/{todo_id}",
    response_model=TodoResponse,
    summary="Update a todo",
    description="Update an existing todo item"
)
def update_todo(
    todo_id: int,
    todo_update: TodoUpdate,
    db: Session = Depends(get_db)
):
    """
    Update a todo:
    
    - **title**: New title (optional)
    - **description**: New description (optional)
    - **completed**: New completion status (optional)
    
    Only provided fields will be updated
    """
    todo = crud_todo.update_todo(db=db, todo_id=todo_id, todo_update=todo_update)
    if not todo:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Todo with id {todo_id} not found"
        )
    return todo


@router.delete(
    "/{todo_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete a todo",
    description="Delete a todo item by its ID"
)
def delete_todo(
    todo_id: int,
    db: Session = Depends(get_db)
):
    """
    Delete a todo by ID
    """
    success = crud_todo.delete_todo(db=db, todo_id=todo_id)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Todo with id {todo_id} not found"
        )


@router.get(
    "/stats/summary",
    summary="Get todo statistics",
    description="Get statistics about todos (total, completed, pending)"
)
def get_stats(db: Session = Depends(get_db)):
    """
    Get statistics:
    
    - Total todos
    - Completed todos
    - Pending todos
    - Completion rate
    """
    return crud_todo.get_todo_count(db=db)
```

**New FastAPI features:**

- `Query()` - Validation for query parameters
- `Depends(get_db)` - Dependency injection for database session
- Detailed docstrings for automatic documentation

---

### Step 12: Router Aggregator (`app/api/v1/api.py`)

```python
"""
API v1 router aggregator
Combines all endpoint routers
"""
from fastapi import APIRouter
from app.api.v1.endpoints import todos

api_router = APIRouter()

# Include todos router
api_router.include_router(
    todos.router,
    prefix="/todos",
    tags=["todos"]
)

# Future routers can be added here:
# api_router.include_router(users.router, prefix="/users", tags=["users"])
# api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
```

---

### Step 13: Main Application (`app/main.py`)

```python
"""
FastAPI application entry point
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.database import engine, Base
from app.api.v1.api import api_router

# Create database tables
# This creates tables if they don't exist
Base.metadata.create_all(bind=engine)

# Initialize FastAPI app
app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    description="A production-ready Todo API with PostgreSQL",
    docs_url="/docs",
    redoc_url="/redoc"
)

# Configure CORS (if needed for frontend)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify actual origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include API router
app.include_router(api_router, prefix="/api/v1")


@app.get("/", tags=["Root"])
def root():
    """Root endpoint"""
    return {
        "message": f"Welcome to {settings.PROJECT_NAME}",
        "version": settings.VERSION,
        "docs": "/docs"
    }


@app.get("/health", tags=["Health"])
def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "service": settings.PROJECT_NAME,
        "version": settings.VERSION
    }
```

**What happens on startup:**

1. `Base.metadata.create_all(bind=engine)` creates tables
2. FastAPI app is initialized
3. CORS middleware added (for frontend access)
4. Routes are registered

---

## Part 7: Running the Application

### Start the Server

```bash
# Make sure you're in the project directory
# Make sure virtual environment is activated
# Make sure PostgreSQL is running

uvicorn app.main:app --reload
```

**You should see:**
```
INFO:     Uvicorn running on http://127.0.0.1:8000
INFO:     Application startup complete.
```

**Check console for SQL:**
```sql
CREATE TABLE todos (
    id SERIAL PRIMARY KEY,
    title VARCHAR(100) NOT NULL,
    description VARCHAR(500),
    completed BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE
)
```

This means the table was created! ✅

---

### Test the API

**Visit:** http://127.0.0.1:8000/docs

**Try creating a todo:**
```json
POST /api/v1/todos
{
  "title": "Learn PostgreSQL",
  "description": "Master database concepts",
  "completed": false
}
```

**Response:**
```json
{
  "id": 1,
  "title": "Learn PostgreSQL",
  "description": "Master database concepts",
  "completed": false,
  "created_at": "2026-02-08T10:30:00.123456",
  "updated_at": null
}
```

**Now restart the server:**
```bash
# Stop: Ctrl+C
# Start again: uvicorn app.main:app --reload
```

**Get todos:**
```
GET /api/v1/todos
```

**The todo is still there!** 🎉

Your data persisted because it's in PostgreSQL, not in memory!

---

## Part 8: Understanding the Data Flow

### Complete Request Flow

```
1. CLIENT SENDS REQUEST
   POST /api/v1/todos
   Body: {"title": "Learn", "description": "Study"}
   
   ↓

2. FASTAPI RECEIVES
   Routes to: app/api/v1/endpoints/todos.py
   Function: create_todo()
   
   ↓

3. PYDANTIC VALIDATES
   Schema: TodoCreate
   ✅ title is string
   ✅ description is string
   ✅ completed defaults to false
   
   ↓

4. DEPENDENCY INJECTION
   get_db() creates database session
   Passes to function as 'db' parameter
   
   ↓

5. CRUD OPERATION
   crud_todo.create_todo(db, todo)
   Creates Todo SQLAlchemy model
   
   ↓

6. SQLALCHEMY GENERATES SQL
   INSERT INTO todos (title, description, completed)
   VALUES ('Learn', 'Study', false)
   RETURNING *
   
   ↓

7. POSTGRESQL EXECUTES
   Saves data to disk
   Returns saved record with id and timestamp
   
   ↓

8. SQLALCHEMY CONVERTS
   Database row → Python Todo object
   
   ↓

9. PYDANTIC FORMATS RESPONSE
   Todo object → TodoResponse schema
   
   ↓

10. FASTAPI SENDS JSON
    {
      "id": 1,
      "title": "Learn",
      "description": "Study",
      "completed": false,
      "created_at": "2026-02-08T10:30:00",
      "updated_at": null
    }
    
    ↓

11. SESSION CLEANUP
    get_db() closes database session
    Connection returned to pool
```

**Every layer has a purpose!**

---

## Part 9: Common Database Operations

### Query Examples

```python
# Get all todos
todos = db.query(Todo).all()

# Get first todo
todo = db.query(Todo).first()

# Filter by completion
completed_todos = db.query(Todo).filter(Todo.completed == True).all()

# Get by ID
todo = db.query(Todo).filter(Todo.id == 1).first()

# Get with multiple conditions
todos = db.query(Todo).filter(
    Todo.completed == False,
    Todo.title.like("%FastAPI%")
).all()

# Order by
todos = db.query(Todo).order_by(Todo.created_at.desc()).all()

# Limit
todos = db.query(Todo).limit(10).all()

# Offset (pagination)
todos = db.query(Todo).offset(20).limit(10).all()

# Count
count = db.query(Todo).count()

# Update
todo = db.query(Todo).filter(Todo.id == 1).first()
todo.completed = True
db.commit()

# Delete
todo = db.query(Todo).filter(Todo.id == 1).first()
db.delete(todo)
db.commit()
```

---

## Part 10: Tasks for You

### Task 1: Add User Field

Add a `user_id` field to associate todos with users.

**Requirements:**
1. Add `user_id` column to Todo model
2. Update schemas to include user_id
3. Filter todos by user_id

<details>
<summary>Hint</summary>

```python
# In models/todo.py
class Todo(Base):
    # ... existing fields ...
    user_id = Column(Integer, nullable=False, index=True)

# In schemas/todo.py
class TodoBase(BaseModel):
    # ... existing fields ...
    user_id: int
```
</details>

---

### Task 2: Add Search Functionality

Create an endpoint to search todos by title.

**Requirements:**
- GET /api/v1/todos/search?q=query
- Case-insensitive search
- Search in both title and description

<details>
<summary>Solution</summary>

```python
# In crud/crud_todo.py
def search_todos(db: Session, query: str) -> List[Todo]:
    search = f"%{query}%"
    return db.query(Todo).filter(
        (Todo.title.ilike(search)) | 
        (Todo.description.ilike(search))
    ).all()

# In api/v1/endpoints/todos.py
@router.get("/search", response_model=List[TodoResponse])
def search_todos(
    q: str = Query(..., min_length=1),
    db: Session = Depends(get_db)
):
    return crud_todo.search_todos(db=db, query=q)
```
</details>

---

### Task 3: Add Priority and Due Date

Extend Todo with priority and due date.

**Requirements:**
1. Add priority enum (low, medium, high)
2. Add optional due_date
3. Filter by priority
4. Get overdue todos

<details>
<summary>Hint</summary>

```python
# In models/todo.py
from sqlalchemy import Enum
import enum

class PriorityEnum(str, enum.Enum):
    low = "low"
    medium = "medium"
    high = "high"

class Todo(Base):
    # ... existing fields ...
    priority = Column(Enum(PriorityEnum), default=PriorityEnum.medium)
    due_date = Column(DateTime(timezone=True), nullable=True)
```
</details>

---

## Part 11: Troubleshooting

### Error: "Could not connect to database"

**Check:**
1. Is PostgreSQL running?
   ```bash
   # Check status
   # Mac: brew services list
   # Linux: sudo systemctl status postgresql
   # Windows: Check Services
   ```

2. Is DATABASE_URL correct in `.env`?
   ```
   postgresql://username:password@host:port/database
   ```

3. Can you connect with psql?
   ```bash
   psql -U postgres -d tododb
   ```

---

### Error: "Table already exists"

**Solution:**
```python
# Drop and recreate tables
Base.metadata.drop_all(bind=engine)
Base.metadata.create_all(bind=engine)
```

Or use database migrations (we'll cover in later weeks)

---

### Error: "column does not exist"

**Cause:** Database table doesn't match your model

**Solution:** Drop and recreate table, or use migrations

---

## ✅ Week 5 Checklist

- [ ] Installed PostgreSQL
- [ ] Created database
- [ ] Set up project structure
- [ ] Created all config files
- [ ] Created database connection
- [ ] Created SQLAlchemy models
- [ ] Created Pydantic schemas
- [ ] Created CRUD operations
- [ ] Created API endpoints
- [ ] Started application successfully
- [ ] Created a todo via API
- [ ] Retrieved todo from database
- [ ] Restarted server and data persisted
- [ ] Understand SQLAlchemy vs Pydantic
- [ ] Completed tasks

---

## 🎓 Knowledge Check

1. **What's the difference between SQLAlchemy model and Pydantic schema?**
2. **What does ORM stand for and what does it do?**
3. **Why do we need a Session?**
4. **What happens when you call db.commit()?**
5. **Why does data persist after server restart now?**

<details>
<summary>Answers</summary>

1. SQLAlchemy = database table, Pydantic = API validation
2. Object Relational Mapper - converts between Python objects and SQL
3. Session = conversation with database, manages transactions
4. Saves all changes to database permanently
5. Data is stored in PostgreSQL on disk, not in Python memory
</details>

---

## 🎉 Congratulations!

You now have:
- ✅ Real database integration
- ✅ Persistent data storage
- ✅ Proper project structure
- ✅ Production-ready code organization
- ✅ Understanding of ORM

**This is a HUGE milestone!** 🚀

---

## 📚 Week 6 Preview

**Next: Advanced Database Features**

- Database relationships (one-to-many, many-to-many)
- Alembic migrations
- Database indexes
- Query optimization
- Transactions

---

**Ready for Week 6? Say: "I completed Week 5, ready for Week 6!"**

Ask any questions! 😊

---

**Progress**: Week 5 of 14 ⭐⭐⭐⭐⭐
**Next Topic**: Advanced Database Features & Relationships
**Status**: You're building real applications now! 💪