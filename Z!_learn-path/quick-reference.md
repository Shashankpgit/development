# Backend Development Quick Reference Guide 📖

This is your cheat sheet! Bookmark this file and refer to it whenever you need a quick reminder.

---

## 🌐 Core Concepts

### Client-Server Model
```
Client (You)  ----request---->  Server (Backend)
                               (Processes request)
                               (Checks database)
              <---response----  (Sends data back)
```

### API (Application Programming Interface)
A set of rules that lets different programs talk to each other.
Think: Restaurant menu - you can only order what's on the menu.

---

## 🔤 HTTP Methods (CRUD)

| Method | Action | Example | SQL Equivalent |
|--------|--------|---------|----------------|
| **GET** | Read | Get user profile | SELECT |
| **POST** | Create | Register new user | INSERT |
| **PUT** | Update | Edit profile | UPDATE |
| **DELETE** | Delete | Remove account | DELETE |

### When to Use What?

```python
# GET - Retrieve data
GET /users          # Get all users
GET /users/123      # Get specific user

# POST - Create new data
POST /users         # Create new user
Body: {"name": "Alice", "email": "alice@example.com"}

# PUT - Update existing data
PUT /users/123      # Update user 123
Body: {"name": "Alice Smith"}

# DELETE - Remove data
DELETE /users/123   # Delete user 123
```

---

## 📊 HTTP Status Codes

### Success (2xx)
- **200 OK** - Request successful
- **201 Created** - New resource created
- **204 No Content** - Success, no data to return

### Client Errors (4xx) - User's fault
- **400 Bad Request** - Invalid data sent
- **401 Unauthorized** - Need to login
- **403 Forbidden** - No permission
- **404 Not Found** - Resource doesn't exist
- **422 Unprocessable** - Validation failed

### Server Errors (5xx) - Server's fault
- **500 Internal Server Error** - Code broke
- **503 Service Unavailable** - Server down

---

## 📝 JSON Format

```json
{
  "string": "text",
  "number": 42,
  "boolean": true,
  "null": null,
  "array": [1, 2, 3],
  "object": {
    "nested": "value"
  }
}
```

### Common API Response Format
```json
{
  "success": true,
  "data": {
    "id": 1,
    "name": "Alice"
  },
  "message": "User created successfully"
}
```

---

## 🎯 REST Principles

### 1. Use Correct HTTP Methods
```
✅ GET /users          (retrieve)
✅ POST /users         (create)
❌ GET /createUser     (don't use verbs in URL)
```

### 2. URLs Should Be Nouns
```
✅ /users
✅ /posts
✅ /comments
❌ /getUsers
❌ /createPost
```

### 3. Use Plural Names
```
✅ /users/123
❌ /user/123
```

### 4. Nested Resources
```
✅ /users/123/posts         (posts by user 123)
✅ /posts/456/comments      (comments on post 456)
```

### 5. Version Your API
```
✅ /api/v1/users
✅ /api/v2/users
```

---

## 🐍 FastAPI Basics

### Create API Application
```python
from fastapi import FastAPI

app = FastAPI()

@app.get("/")
def root():
    return {"message": "Hello World"}
```

### Path Parameter
```python
@app.get("/users/{user_id}")
def get_user(user_id: int):
    return {"user_id": user_id}

# URL: /users/123
```

### Query Parameter
```python
@app.get("/items")
def get_items(skip: int = 0, limit: int = 10):
    return {"skip": skip, "limit": limit}

# URL: /items?skip=0&limit=10
```

### Request Body
```python
from pydantic import BaseModel

class User(BaseModel):
    name: str
    email: str

@app.post("/users")
def create_user(user: User):
    return user
```

---

## 🗄️ Database Concepts

### SQL Commands
```sql
-- CREATE (INSERT)
INSERT INTO users (name, email) VALUES ('Alice', 'alice@example.com');

-- READ (SELECT)
SELECT * FROM users;
SELECT * FROM users WHERE id = 1;

-- UPDATE
UPDATE users SET name = 'Alice Smith' WHERE id = 1;

-- DELETE
DELETE FROM users WHERE id = 1;
```

### SQLAlchemy Model
```python
from sqlalchemy import Column, Integer, String
from database import Base

class User(Base):
    __tablename__ = "users"
    
    id = Column(Integer, primary_key=True)
    name = Column(String(100))
    email = Column(String(100), unique=True)
```

---

## 📦 Pydantic Schemas

### Purpose
Models for request/response validation

```python
from pydantic import BaseModel, Field
from typing import Optional

# For creating (input)
class UserCreate(BaseModel):
    name: str = Field(..., min_length=1)
    email: str
    password: str

# For response (output)
class UserResponse(BaseModel):
    id: int
    name: str
    email: str
    # Note: No password in response!
    
    class Config:
        from_attributes = True
```

---

## 🏗️ Project Structure

```
project/
├── app/
│   ├── __init__.py           # Makes 'app' a package
│   ├── main.py               # Application entry point
│   ├── config.py             # Settings/configuration
│   ├── database.py           # DB connection
│   │
│   ├── models/               # Database models (tables)
│   │   ├── __init__.py
│   │   └── user.py
│   │
│   ├── schemas/              # Pydantic models (validation)
│   │   ├── __init__.py
│   │   └── user.py
│   │
│   ├── crud/                 # Database operations
│   │   ├── __init__.py
│   │   └── crud_user.py
│   │
│   └── api/                  # API routes
│       ├── deps.py           # Dependencies (get_db)
│       └── v1/
│           ├── api.py        # Router aggregator
│           └── endpoints/
│               └── users.py
│
├── .env                      # Environment variables
├── requirements.txt          # Dependencies
└── README.md
```

---

## 🔧 Common Commands

### Virtual Environment
```bash
# Create
python -m venv venv

# Activate (Windows)
venv\Scripts\activate

# Activate (Mac/Linux)
source venv/bin/activate

# Deactivate
deactivate
```

### Dependencies
```bash
# Install package
pip install fastapi

# Install from requirements.txt
pip install -r requirements.txt

# Create requirements.txt
pip freeze > requirements.txt
```

### Run Application
```bash
# Development (with auto-reload)
uvicorn app.main:app --reload

# Production
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

### Database
```bash
# Create database (PostgreSQL)
psql -U postgres
CREATE DATABASE mydb;

# Run migrations (Alembic)
alembic revision --autogenerate -m "message"
alembic upgrade head
```

---

## 🔐 Authentication Flow

### Password Hashing
```python
from passlib.context import CryptContext

pwd_context = CryptContext(schemes=["bcrypt"])

# Hash password
hashed = pwd_context.hash("mypassword")

# Verify password
is_valid = pwd_context.verify("mypassword", hashed)
```

### JWT Token
```python
from jose import jwt

# Create token
token = jwt.encode(
    {"user_id": 123},
    "secret_key",
    algorithm="HS256"
)

# Decode token
payload = jwt.decode(token, "secret_key", algorithms=["HS256"])
```

---

## 🧪 Testing

### Basic Test
```python
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_read_users():
    response = client.get("/users")
    assert response.status_code == 200
    assert isinstance(response.json(), list)
```

### Run Tests
```bash
# Run all tests
pytest

# Run with coverage
pytest --cov=app

# Run specific test
pytest tests/test_users.py
```

---

## 🐛 Common Errors & Solutions

### ImportError: No module named 'X'
```bash
# Solution: Install the package
pip install X
```

### 422 Unprocessable Entity
```
Problem: Request body doesn't match schema
Solution: Check your Pydantic model and request data
```

### 500 Internal Server Error
```
Problem: Bug in your code
Solution: Check server logs for error message
```

### Database connection error
```
Problem: Wrong DATABASE_URL or database not running
Solution: Check .env file and start database
```

---

## 💡 Best Practices

### ✅ DO
- Use type hints everywhere
- Validate all input data
- Use environment variables for secrets
- Write descriptive variable names
- Handle errors properly
- Use dependency injection
- Return appropriate status codes
- Document your API

### ❌ DON'T
- Hardcode passwords/secrets
- Return sensitive data (passwords, tokens)
- Use GET to modify data
- Ignore validation errors
- Store plain text passwords
- Mix business logic with routes
- Use generic variable names (x, y, data)

---

## 📚 Useful Links

### Official Documentation
- FastAPI: https://fastapi.tiangolo.com
- Pydantic: https://docs.pydantic.dev
- SQLAlchemy: https://docs.sqlalchemy.org
- PostgreSQL: https://www.postgresql.org/docs

### Learning Resources
- FastAPI Tutorial: https://fastapi.tiangolo.com/tutorial
- Real Python: https://realpython.com
- Python Docs: https://docs.python.org

---

## 🎯 Debugging Checklist

When something doesn't work:

1. **Read the error message** - It usually tells you what's wrong
2. **Check your imports** - Are all modules installed?
3. **Verify database connection** - Is DB running? Is URL correct?
4. **Check .env file** - Are environment variables set?
5. **Look at server logs** - What does the terminal say?
6. **Test with /docs** - Use Swagger UI to test endpoints
7. **Print/log values** - Add print() to see what's happening
8. **Google the error** - Someone else has had this problem!

---

## 📊 Request/Response Flow Diagram

```
1. USER SENDS REQUEST
   POST /api/v1/users
   Body: {"name": "Alice", "email": "alice@example.com"}
   
   ↓

2. FASTAPI RECEIVES (main.py)
   Routes to correct endpoint
   
   ↓

3. VALIDATION (schemas/user.py)
   Checks if data is valid
   
   ↓

4. DEPENDENCY INJECTION (deps.py)
   Gets database session
   
   ↓

5. BUSINESS LOGIC (endpoints/users.py)
   Calls CRUD function
   
   ↓

6. DATABASE OPERATION (crud/crud_user.py)
   Saves to database using model
   
   ↓

7. RESPONSE (schemas/user.py)
   Formats response
   
   ↓

8. USER RECEIVES
   Status: 201 Created
   Body: {"id": 1, "name": "Alice", "email": "alice@example.com"}
```

---

**Use this guide whenever you need a quick reference!**
**Bookmark it and keep it handy while coding.**