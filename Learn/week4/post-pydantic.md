# Week 4: POST Requests & Pydantic Models 📬

**Goal**: Learn to accept data from users and validate it properly

**What You'll Build**: A Todo List API where users can create, read, update, and delete todos

**New Concepts**: POST requests, Request Body, Pydantic models, Data validation

---

## Part 1: Understanding HTTP Methods in Depth

### GET vs POST - The Fundamental Difference

In Week 3, you only used **GET** requests. Let's understand why we need other methods.

#### GET Requests (What You've Been Using)

```python
@app.get("/users")
def get_users():
    return [{"id": 1, "name": "Alice"}]
```

**Characteristics of GET:**
- **Purpose**: Retrieve/Read data
- **Data location**: URL (query parameters)
- **Visible**: Data shows in browser address bar
- **Cacheable**: Browser can cache results
- **Idempotent**: Calling it multiple times = same result
- **Should NOT modify data**: Only reads

**Real-world example:**
```
GET /search?query=fastapi&limit=10
      ↑
  All data is in URL - anyone can see it!
```

#### POST Requests (New!)

```python
@app.post("/users")
def create_user(user: User):
    return {"message": "User created"}
```

**Characteristics of POST:**
- **Purpose**: Create new data
- **Data location**: Request body (hidden from URL)
- **Not visible**: Data NOT in address bar
- **Not cacheable**: Creates something new each time
- **Not idempotent**: Calling multiple times = multiple records
- **Modifies data**: Creates new resources

**Real-world example:**
```
POST /users
Body: {
  "name": "Alice",
  "email": "alice@example.com",
  "password": "secret123"
}
↑
Data is hidden in request body - not in URL
```

### Why Use POST Instead of GET?

**Scenario 1: Security**
```python
# ❌ BAD - Password visible in URL!
GET /register?name=Alice&password=secret123

# ✅ GOOD - Password hidden in body
POST /register
Body: {"name": "Alice", "password": "secret123"}
```

**Scenario 2: Data Size**
```python
# ❌ BAD - URL has character limits
GET /create-post?title=...&content=5000_words_here...

# ✅ GOOD - Body can handle large data
POST /posts
Body: {"title": "...", "content": "5000 words..."}
```

**Scenario 3: Semantic Correctness**
```python
# ❌ BAD - GET should not create things
GET /create-user?name=Alice

# ✅ GOOD - POST is for creating
POST /users
Body: {"name": "Alice"}
```

---

## Part 2: What is a Request Body?

### Understanding Request Structure

When a client (browser, app, etc.) talks to your API, it sends a **request**. A request has several parts:

```
HTTP REQUEST STRUCTURE:
┌─────────────────────────────────────┐
│ 1. METHOD: POST                     │ ← What action?
├─────────────────────────────────────┤
│ 2. PATH: /users                     │ ← Where to go?
├─────────────────────────────────────┤
│ 3. HEADERS:                         │ ← Metadata
│    Content-Type: application/json   │
│    Authorization: Bearer token123   │
├─────────────────────────────────────┤
│ 4. BODY:                            │ ← The actual data!
│    {                                │
│      "name": "Alice",               │
│      "email": "alice@example.com"   │
│    }                                │
└─────────────────────────────────────┘
```

### Request Body Deep Dive

**What is it?**
- The **payload** of data sent with the request
- Usually in JSON format (for APIs)
- Can be any size (within server limits)
- Completely separate from the URL

**Visual Comparison:**

```python
# GET Request - Data in URL
GET /calculate?a=5&b=3
[No body]

# POST Request - Data in Body
POST /calculate
Body:
{
  "a": 5,
  "b": 3,
  "operation": "add",
  "precision": 2
}
```

**In Week 3, you did this:**
```python
@app.get("/add")
def add(a: int, b: int):  # FastAPI gets a & b from URL
    return {"result": a + b}

# URL: /add?a=5&b=3
```

**Now in Week 4, you'll do this:**
```python
@app.post("/calculate")
def calculate(data: CalculationRequest):  # FastAPI gets data from body
    return {"result": data.a + data.b}

# URL: /calculate
# Body: {"a": 5, "b": 3}
```

---

## Part 3: Introduction to Pydantic Models

### What is Pydantic?

**Pydantic** is a data validation library that comes with FastAPI.

**Think of Pydantic models as:**
- A **blueprint** for your data
- A **contract** - data must match this shape
- An **automatic validator** - checks everything for you
- A **documentation generator** - shows what data is expected

### Your First Pydantic Model

Let's create a model step by step:

```python
from pydantic import BaseModel

class User(BaseModel):
    name: str
    age: int
```

**What this means:**
```
This is a User blueprint that says:
- User must have a "name" field
- name must be a string
- User must have an "age" field  
- age must be an integer

If data doesn't match this, Pydantic will reject it!
```

### Using the Model

```python
# Creating a User object
user = User(name="Alice", age=25)

print(user.name)  # Alice
print(user.age)   # 25

# Try invalid data
try:
    invalid_user = User(name="Bob", age="twenty-five")
except ValueError as e:
    print(e)
    # Error: age must be an integer!
```

### Behind the Scenes

When you create `User(name="Alice", age=25)`, Pydantic:

1. **Checks field existence**: Does name exist? ✅ Does age exist? ✅
2. **Validates types**: Is name a string? ✅ Is age an int? ✅
3. **Creates object**: Everything valid, create the User object
4. **Raises error if invalid**: If anything fails, give detailed error

**This all happens automatically!** You don't write any validation code.

---

## Part 4: Your First POST Endpoint

### Setup Project

Create a new file `main.py`:

```python
from fastapi import FastAPI
from pydantic import BaseModel

app = FastAPI(title="Todo API", version="1.0.0")

# This is a Pydantic model - defines what a Todo looks like
class Todo(BaseModel):
    title: str
    description: str
    completed: bool = False

@app.get("/")
def home():
    return {"message": "Welcome to Todo API"}
```

### Understanding the Todo Model

Let's break down each part:

```python
class Todo(BaseModel):
    # Field 1: title
    title: str
    # - Required field (no default value)
    # - Must be a string
    # - If missing or wrong type, Pydantic raises error
    
    # Field 2: description
    description: str
    # - Also required
    # - Must be a string
    
    # Field 3: completed
    completed: bool = False
    # - Optional field (has default value)
    # - If not provided, defaults to False
    # - If provided, must be boolean
```

### Create Your First POST Endpoint

Add this to `main.py`:

```python
@app.post("/todos")
def create_todo(todo: Todo):
    """
    Create a new todo item
    
    The 'todo: Todo' means:
    - Expect data in request body
    - Data should match Todo model
    - FastAPI automatically validates
    - If valid, todo is a Todo object
    - If invalid, FastAPI returns error
    """
    return {
        "message": "Todo created successfully!",
        "todo": todo
    }
```

### Test It!

**Start the server:**
```bash
uvicorn main:app --reload
```

**Visit docs:** http://127.0.0.1:8000/docs

**In /docs:**
1. Click on "POST /todos"
2. Click "Try it out"
3. You'll see a request body editor with example:
   ```json
   {
     "title": "string",
     "description": "string",
     "completed": false
   }
   ```
4. Change it to:
   ```json
   {
     "title": "Learn FastAPI",
     "description": "Complete Week 4 exercises",
     "completed": false
   }
   ```
5. Click "Execute"

**Response:**
```json
{
  "message": "Todo created successfully!",
  "todo": {
    "title": "Learn FastAPI",
    "description": "Complete Week 4 exercises",
    "completed": false
  }
}
```

### What Just Happened? (Step by Step)

```
1. You clicked "Execute" in /docs
   ↓
2. Browser sent POST request to /todos with JSON body
   ↓
3. FastAPI received the request
   ↓
4. FastAPI looked at create_todo function signature
   - Saw: todo: Todo
   - Knows: Need to validate body against Todo model
   ↓
5. Pydantic validated the data:
   ✅ title exists and is string
   ✅ description exists and is string
   ✅ completed is boolean (or use default)
   ↓
6. Validation passed! Created Todo object
   ↓
7. Called create_todo(todo=Todo(...))
   ↓
8. Function returned data
   ↓
9. FastAPI converted to JSON
   ↓
10. Sent response back to browser
```

---

## Part 5: Data Validation in Action

### Test Invalid Data

**Test 1: Missing Required Field**

In /docs, try:
```json
{
  "title": "My Todo"
}
```
(Missing description)

**Response:** 422 Unprocessable Entity
```json
{
  "detail": [
    {
      "loc": ["body", "description"],
      "msg": "field required",
      "type": "value_error.missing"
    }
  ]
}
```

**What happened:**
- Pydantic checked: title? ✅ description? ❌ Missing!
- Automatically returned error with exact problem
- You didn't write any validation code!

---

**Test 2: Wrong Type**

Try:
```json
{
  "title": "My Todo",
  "description": "Learn FastAPI",
  "completed": "yes"
}
```
(completed should be boolean, not string)

**Response:** 422 Error
```json
{
  "detail": [
    {
      "loc": ["body", "completed"],
      "msg": "value could not be parsed to a boolean",
      "type": "type_error.bool"
    }
  ]
}
```

**Pydantic caught it!**

---

**Test 3: Extra Fields**

Try:
```json
{
  "title": "My Todo",
  "description": "Learn FastAPI",
  "completed": false,
  "priority": "high"
}
```
(priority not in model)

**Response:** Success! Extra fields ignored by default.

---

## Part 6: Advanced Pydantic Features

### Field Validation with Constraints

```python
from pydantic import BaseModel, Field

class Todo(BaseModel):
    title: str = Field(..., min_length=1, max_length=100)
    # - Required field (... means required)
    # - Must be 1-100 characters
    # - Empty string rejected
    
    description: str = Field(..., max_length=500)
    # - Required
    # - Max 500 characters
    
    completed: bool = Field(default=False)
    # - Optional, defaults to False
```

**Test it:**
```json
{
  "title": "",
  "description": "Test"
}
```
**Error:** title must be at least 1 character!

---

### Optional Fields

```python
from typing import Optional

class Todo(BaseModel):
    title: str
    description: Optional[str] = None  # Can be None
    completed: bool = False
```

**Valid requests:**
```json
// Option 1: Provide description
{
  "title": "My Todo",
  "description": "Do something"
}

// Option 2: Don't provide description (uses None)
{
  "title": "My Todo"
}

// Option 3: Explicitly set to null
{
  "title": "My Todo",
  "description": null
}
```

---

### Default Values

```python
from datetime import datetime

class Todo(BaseModel):
    title: str
    description: str = "No description"
    completed: bool = False
    created_at: datetime = Field(default_factory=datetime.now)
    # default_factory calls datetime.now() when creating object
```

**Usage:**
```python
todo = Todo(title="My Task")
# description = "No description" (default)
# completed = False (default)
# created_at = current timestamp (generated)
```

---

### Nested Models

```python
class Address(BaseModel):
    street: str
    city: str
    country: str

class User(BaseModel):
    name: str
    age: int
    address: Address  # Nested model!

# Valid request:
{
  "name": "Alice",
  "age": 25,
  "address": {
    "street": "123 Main St",
    "city": "New York",
    "country": "USA"
  }
}
```

---

## Part 7: Building Complete Todo API

### Full Implementation

Create this complete `main.py`:

```python
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
```

---

## Part 8: Understanding the Complete API

### Model Inheritance

```python
class TodoBase(BaseModel):
    title: str
    description: str
    completed: bool = False

class TodoCreate(TodoBase):
    # Inherits all fields from TodoBase
    pass  # No additional fields

class TodoResponse(TodoBase):
    # Inherits TodoBase fields + adds new ones
    id: int
    created_at: datetime
```

**Why separate models?**

1. **TodoCreate**: What user sends when creating
   - No ID (we generate it)
   - No timestamp (we add it)

2. **TodoResponse**: What we return to user
   - Includes ID
   - Includes timestamp

3. **TodoUpdate**: For updating
   - All fields optional
   - Only update what's provided

---

### Response Models

```python
@app.post("/todos", response_model=TodoResponse)
def create_todo(todo: TodoCreate):
    return todo_dict
```

**`response_model=TodoResponse` means:**
- FastAPI validates the response
- Filters fields to match TodoResponse
- Generates correct documentation
- Ensures type safety

---

### Status Codes

```python
@app.post("/todos", status_code=201)  # 201 = Created
@app.delete("/todos/{id}", status_code=204)  # 204 = No Content
```

**Common status codes:**
- `200` - OK (default)
- `201` - Created (for POST)
- `204` - No Content (for DELETE)
- `404` - Not Found
- `422` - Validation Error

---

### HTTPException

```python
from fastapi import HTTPException

raise HTTPException(
    status_code=404,
    detail=f"Todo with id {todo_id} not found"
)
```

**What this does:**
1. Stops function execution
2. Returns error response to client
3. Sets HTTP status code
4. Includes error message

---

## Part 9: Testing the Complete API

### Workflow Example

**1. Create a todo:**
```
POST /todos
{
  "title": "Learn FastAPI",
  "description": "Complete Week 4"
}

Response: 201 Created
{
  "id": 1,
  "title": "Learn FastAPI",
  "description": "Complete Week 4",
  "completed": false,
  "created_at": "2026-02-07T10:30:00"
}
```

**2. Create another:**
```
POST /todos
{
  "title": "Build project",
  "description": "Create a real API"
}

Response: 201 Created
{
  "id": 2,
  ...
}
```

**3. Get all todos:**
```
GET /todos

Response:
[
  {"id": 1, "title": "Learn FastAPI", ...},
  {"id": 2, "title": "Build project", ...}
]
```

**4. Update a todo:**
```
PUT /todos/1
{
  "completed": true
}

Response:
{
  "id": 1,
  "title": "Learn FastAPI",
  "description": "Complete Week 4",
  "completed": true,
  "created_at": "..."
}
```

**5. Filter completed:**
```
GET /todos?completed=true

Response:
[
  {"id": 1, "title": "Learn FastAPI", "completed": true, ...}
]
```

**6. Get stats:**
```
GET /todos/stats/summary

Response:
{
  "total": 2,
  "completed": 1,
  "pending": 1,
  "completion_rate": 50.0
}
```

**7. Delete a todo:**
```
DELETE /todos/2

Response: 204 No Content
(empty response)
```

---

## Part 10: Tasks for You

### Task 1: Add Priority Field

Add a priority field to todos with validation.

**Requirements:**
- Priority must be one of: "low", "medium", "high"
- Default: "medium"
- Use Pydantic's `Field` with enum

**Hint:**
```python
from enum import Enum

class Priority(str, Enum):
    low = "low"
    medium = "medium"
    high = "high"

class TodoBase(BaseModel):
    # Add priority field here
    priority: Priority = Field(default=Priority.medium)
```

<details>
<summary>Full Solution</summary>

```python
from enum import Enum

class Priority(str, Enum):
    low = "low"
    medium = "medium"
    high = "high"

class TodoBase(BaseModel):
    title: str = Field(..., min_length=1, max_length=100)
    description: str = Field(..., max_length=500)
    completed: bool = Field(default=False)
    priority: Priority = Field(default=Priority.medium, description="Todo priority")
```

Test:
```json
{
  "title": "Urgent task",
  "description": "Fix bug",
  "priority": "high"
}
```
</details>

---

### Task 2: Due Date Feature

Add a due date field to todos.

**Requirements:**
- Optional field (can be None)
- Must be a future date
- Use datetime type

**Hint:**
```python
from datetime import datetime
from typing import Optional
from pydantic import Field, validator

class TodoBase(BaseModel):
    # existing fields...
    due_date: Optional[datetime] = None
    
    @validator('due_date')
    def validate_due_date(cls, v):
        if v and v < datetime.now():
            raise ValueError('Due date must be in the future')
        return v
```

<details>
<summary>Full Solution</summary>

```python
from datetime import datetime
from typing import Optional
from pydantic import Field, validator

class TodoBase(BaseModel):
    title: str = Field(..., min_length=1, max_length=100)
    description: str = Field(..., max_length=500)
    completed: bool = Field(default=False)
    due_date: Optional[datetime] = Field(default=None, description="Due date")
    
    @validator('due_date')
    def validate_due_date(cls, v):
        if v and v < datetime.now():
            raise ValueError('Due date must be in the future')
        return v
```

Test:
```json
{
  "title": "Submit report",
  "description": "Q4 report",
  "due_date": "2026-12-31T23:59:59"
}
```
</details>

---

### Task 3: Search Endpoint

Create an endpoint to search todos by title.

**Requirements:**
- GET /todos/search?q=query
- Case-insensitive search
- Return matching todos

<details>
<summary>Solution</summary>

```python
@app.get("/todos/search", response_model=List[TodoResponse], tags=["Todos"])
def search_todos(q: str):
    """
    Search todos by title
    
    - **q**: Search query (case-insensitive)
    """
    results = [
        todo for todo in todos_db
        if q.lower() in todo["title"].lower()
    ]
    return results
```

Test: `/todos/search?q=fastapi`
</details>

---

### Task 4: Bulk Create

Create an endpoint to create multiple todos at once.

**Requirements:**
- POST /todos/bulk
- Accept list of todos
- Return list of created todos

<details>
<summary>Solution</summary>

```python
@app.post("/todos/bulk", response_model=List[TodoResponse], status_code=201, tags=["Todos"])
def create_todos_bulk(todos: List[TodoCreate]):
    """Create multiple todos at once"""
    global next_id
    
    created_todos = []
    for todo in todos:
        todo_dict = {
            "id": next_id,
            "title": todo.title,
            "description": todo.description,
            "completed": todo.completed,
            "created_at": datetime.now()
        }
        todos_db.append(todo_dict)
        created_todos.append(todo_dict)
        next_id += 1
    
    return created_todos
```

Test:
```json
[
  {
    "title": "Task 1",
    "description": "First task"
  },
  {
    "title": "Task 2",
    "description": "Second task"
  }
]
```
</details>

---

## Part 11: Common Errors and Solutions

### Error 1: "field required"
```json
{
  "detail": [
    {
      "loc": ["body", "title"],
      "msg": "field required"
    }
  ]
}
```
**Solution:** You forgot to include a required field. Check your model definition.

---

### Error 2: Type validation error
```json
{
  "detail": [
    {
      "loc": ["body", "completed"],
      "msg": "value is not a valid boolean"
    }
  ]
}
```
**Solution:** You sent wrong type. Check field should be `true/false`, not `"true"/"false"`.

---

### Error 3: 404 Not Found
```json
{
  "detail": "Todo with id 999 not found"
}
```
**Solution:** The ID doesn't exist in the database. Check the ID or create the todo first.

---

## ✅ Week 4 Checklist

- [ ] Understand GET vs POST
- [ ] Know what request body is
- [ ] Created first Pydantic model
- [ ] Created POST endpoint
- [ ] Tested validation in /docs
- [ ] Understand Field constraints
- [ ] Created complete Todo API
- [ ] Understand model inheritance
- [ ] Know about response_model
- [ ] Understand HTTPException
- [ ] Completed Task 1 (Priority)
- [ ] Completed Task 2 (Due Date)
- [ ] Completed Task 3 (Search)
- [ ] Completed Task 4 (Bulk Create)

---

## 🎓 Knowledge Check

1. **What's the difference between GET and POST?**
2. **Where is data located in POST requests?**
3. **What does Pydantic validate?**
4. **Why use separate models for Create/Update/Response?**
5. **What status code for successful creation?**

<details>
<summary>Answers</summary>

1. GET reads data (from URL), POST creates data (from body)
2. In the request body (not URL)
3. Types, required fields, constraints, custom validators
4. Different fields needed for different operations
5. 201 Created
</details>

---

## 🎉 Congratulations!

You now understand:
- ✅ POST requests and request body
- ✅ Pydantic models and validation
- ✅ Creating CRUD APIs
- ✅ Multiple model types
- ✅ Error handling

**You've built a real API with data validation!** 🚀

---

## 📚 Week 5 Preview

**Next week: Database Integration**

You'll learn:
- Setting up PostgreSQL
- SQLAlchemy ORM
- Database models vs Pydantic schemas
- Persisting data (not just in-memory)
- Migrations with Alembic

**Your todos will survive server restart!**

---

**Ready for Week 5? Say: "I completed Week 4, ready for Week 5!"**

Ask any questions! 😊

---

**Progress**: Week 4 of 14 ⭐⭐⭐⭐
**Next Topic**: Database Integration with PostgreSQL