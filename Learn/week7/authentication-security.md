# Week 7: Authentication & Security 🔐

**Goal**: Secure your API with authentication and authorization

**What You'll Learn**:
- User authentication (login/register)
- Password hashing and security
- JWT (JSON Web Tokens)
- Protected routes
- Authorization (permissions)
- Security best practices
- OAuth2 with FastAPI

**What You'll Build**: Secure Todo API with user authentication and protected endpoints

---

## Part 1: Understanding Authentication vs Authorization

### The Difference (Critical to Understand!)

```
AUTHENTICATION (Who are you?)
├── Verifying identity
├── Login with username/password
├── Proving you are who you claim to be
└── Answer: "Are you Alice?"

AUTHORIZATION (What can you do?)
├── Checking permissions
├── What resources can you access?
├── What actions can you perform?
└── Answer: "Can Alice delete this?"
```

---

### Real-World Analogy

```
🏢 ENTERING AN OFFICE BUILDING:

AUTHENTICATION (Security Guard):
"Show me your ID badge"
→ You prove who you are
→ Guard verifies your identity
→ You're authenticated ✅

AUTHORIZATION (Floor Access):
"Your badge allows floors 1-5"
→ You try to enter floor 10
→ System checks permissions
→ Access denied ❌ (not authorized for floor 10)
→ Floor 3: Access granted ✅ (authorized)
```

---

### In Our Todo API

```python
# AUTHENTICATION
POST /auth/login
Body: {"email": "alice@example.com", "password": "secret123"}
Response: {"access_token": "eyJ0eXAiOi..."}
→ System verifies: Is this really Alice? ✅

# AUTHORIZATION  
GET /todos/123
Headers: {"Authorization": "Bearer eyJ0eXAiOi..."}
→ System checks: Can Alice access todo 123? ✅
→ System checks: Can Alice delete todo 456 (belongs to Bob)? ❌
```

---

## Part 2: Password Security (Deep Dive)

### Why We NEVER Store Plain Text Passwords

**The Disaster Scenario:**

```
❌ BAD DATABASE (Plain text passwords):
┌────┬─────────────┬──────────────┐
│ id │    email    │   password   │
├────┼─────────────┼──────────────┤
│ 1  │ alice@x.com │  password123 │
│ 2  │ bob@x.com   │  secret456   │
└────┴─────────────┴──────────────┘

HACKER GETS DATABASE ACCESS:
→ Instantly has ALL passwords! 💥
→ Can login as anyone
→ Can use passwords on other sites (people reuse!)
→ Complete disaster! 🔥
```

---

### Password Hashing (The Solution)

```
USER REGISTERS:
Password: "mysecret123"
    ↓
HASH FUNCTION (one-way, irreversible):
    ↓
Hashed: "$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/L..."
    ↓
STORE IN DATABASE (safe!)

✅ GOOD DATABASE (Hashed passwords):
┌────┬─────────────┬──────────────────────────────────┐
│ id │    email    │         password_hash            │
├────┼─────────────┼──────────────────────────────────┤
│ 1  │ alice@x.com │ $2b$12$LQv3c1yqBWVHxkd0LH...    │
│ 2  │ bob@x.com   │ $2b$12$XYZ9abc1defGHIjkl0MN...    │
└────┴─────────────┴──────────────────────────────────┘

HACKER GETS DATABASE:
→ Has hashes, but can't reverse them! ✅
→ Can't login (doesn't know original passwords)
→ Database breach is bad, but passwords are safe! 🛡️
```

---

### How Password Hashing Works

```python
# REGISTRATION:
plain_password = "mysecret123"

# Hash it (one-way function)
hashed = hash_function(plain_password)
# Result: "$2b$12$LQv3c1yqBWVHxkd0LHAkCO..."

# Store ONLY the hash
user.password_hash = hashed


# LOGIN ATTEMPT:
input_password = "mysecret123"

# Hash the input
input_hashed = hash_function(input_password)

# Compare hashes
if input_hashed == stored_hash:
    print("Password correct! ✅")
else:
    print("Password incorrect! ❌")
```

**Key Properties:**
1. **One-way**: Cannot reverse hash → password
2. **Deterministic**: Same password → same hash
3. **Random salt**: Same password for different users → different hashes!
4. **Slow**: Intentionally slow to prevent brute force

---

### Using bcrypt (Industry Standard)

```python
from passlib.context import CryptContext

# Create password context
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# Hash password
password = "mysecret123"
hashed = pwd_context.hash(password)
print(hashed)
# $2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/L...

# Verify password
is_correct = pwd_context.verify("mysecret123", hashed)
print(is_correct)  # True ✅

is_correct = pwd_context.verify("wrongpassword", hashed)
print(is_correct)  # False ❌
```

---

### Rainbow Table Attack (Why Salt Matters)

**Without Salt (Vulnerable):**

```
ATTACKER PRE-COMPUTES HASHES:
"password123" → hash1
"letmein"     → hash2
"admin123"    → hash3
... millions of passwords ...

YOUR DATABASE:
user1: hash1  ← Attacker finds "password123" instantly!
user2: hash2  ← Attacker finds "letmein" instantly!

ATTACK SUCCEEDS! 💥
```

**With Salt (Secure):**

```
BCRYPT ADDS RANDOM SALT:
user1: "password123" + "randomsalt1" → hash_unique_1
user2: "password123" + "randomsalt2" → hash_unique_2

Same password, DIFFERENT hashes!

ATTACKER'S PRE-COMPUTED TABLE:
→ Useless! ✅
→ Must crack each hash individually
→ Extremely time-consuming (bcrypt is slow by design)

ATTACK FAILS! 🛡️
```

---

## Part 3: JSON Web Tokens (JWT)

### What is JWT?

**Traditional Session-Based Auth:**

```
USER LOGS IN:
    ↓
SERVER CREATES SESSION
    ↓
SERVER STORES SESSION IN DATABASE
    ↓
COOKIE SENT TO USER (session_id: "abc123")
    ↓
EVERY REQUEST:
1. User sends cookie
2. Server looks up session in database ← SLOW!
3. Server verifies user
```

**Problems:**
- ❌ Database lookup on every request
- ❌ Hard to scale (sessions on one server)
- ❌ Doesn't work well with mobile apps
- ❌ CORS issues with cookies

---

**JWT-Based Auth (Stateless):**

```
USER LOGS IN:
    ↓
SERVER CREATES JWT TOKEN
    ↓
TOKEN CONTAINS USER INFO (encrypted & signed)
    ↓
TOKEN SENT TO USER
    ↓
EVERY REQUEST:
1. User sends token in header
2. Server verifies signature ← FAST! (no DB lookup)
3. Server reads user info from token
```

**Benefits:**
- ✅ No database lookup needed
- ✅ Stateless (any server can verify)
- ✅ Works with mobile/SPA/APIs
- ✅ Can include user data in token

---

### JWT Structure

A JWT has **3 parts** separated by dots:

```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c
│                                      │                                                                  │
├─────────────────────────────────────┼──────────────────────────────────────────────────────────────────┤
     HEADER (algorithm)                         PAYLOAD (data)                                    SIGNATURE
```

---

**Decoded:**

```json
// HEADER
{
  "alg": "HS256",
  "typ": "JWT"
}

// PAYLOAD (your data)
{
  "sub": "user_id_123",        // Subject (user ID)
  "email": "alice@example.com",
  "exp": 1735689600,            // Expiration timestamp
  "iat": 1735686000             // Issued at timestamp
}

// SIGNATURE (verifies token hasn't been tampered with)
HMACSHA256(
  base64UrlEncode(header) + "." + base64UrlEncode(payload),
  secret_key
)
```

---

### How JWT Security Works

```
SERVER CREATES TOKEN:
1. Creates payload: {"user_id": 123, "exp": timestamp}
2. Signs with SECRET KEY
3. Sends token to user

USER MAKES REQUEST:
1. Sends token: "eyJhbGci..."
2. Server verifies signature with SECRET KEY
3. If signature valid → trust the payload
4. If signature invalid → reject (token tampered with)

ATTACKER TRIES TO FAKE TOKEN:
1. Changes payload: {"user_id": 999}  (try to impersonate admin)
2. Sends modified token
3. Server verifies signature
4. Signature doesn't match! ❌
5. Token rejected! 🛡️
```

**Key Insight:** 
- ✅ Payload is readable (base64, not encrypted)
- ✅ But signature ensures it hasn't been modified
- ❌ Don't put sensitive data in payload (it's visible!)

---

## Part 4: Implementation - Complete Auth System

### Project Structure

```
app/
├── core/
│   ├── __init__.py
│   ├── security.py      # Password hashing, JWT functions
│   └── config.py        # Updated with SECRET_KEY
│
├── models/
│   └── user.py          # Updated User model with password_hash
│
├── schemas/
│   ├── token.py         # Token schemas
│   └── user.py          # Updated User schemas
│
├── crud/
│   └── crud_user.py     # Updated with auth functions
│
└── api/
    └── v1/
        └── endpoints/
            ├── auth.py  # Login, register endpoints
            └── users.py # Protected user endpoints
```

---

### Step 1: Install Dependencies

```bash
pip install python-jose[cryptography] passlib[bcrypt] python-multipart

# python-jose: JWT handling
# passlib: Password hashing
# python-multipart: Form data (for OAuth2)

pip freeze > requirements.txt
```

---

### Step 2: Update Configuration

**File: `app/core/config.py`**

```python
"""
Application configuration with security settings
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
    
    # Security
    SECRET_KEY: str  # For signing JWT tokens
    ALGORITHM: str = "HS256"  # JWT algorithm
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30  # Token validity
    
    class Config:
        env_file = ".env"
        case_sensitive = True


@lru_cache()
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
```

**Update `.env` file:**

```bash
# Existing settings
DATABASE_URL=postgresql://postgres:password@localhost:5432/tododb
PROJECT_NAME=Todo API
VERSION=1.0.0

# Add security settings
SECRET_KEY=your-secret-key-change-this-in-production-min-32-chars
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30
```

**Generate a secure SECRET_KEY:**

```python
# Run this once to generate a key
import secrets
print(secrets.token_urlsafe(32))
# Copy output to .env as SECRET_KEY
```

---

### Step 3: Security Utilities

**File: `app/core/security.py`**

```python
"""
Security utilities: password hashing and JWT token handling
"""
from datetime import datetime, timedelta
from typing import Optional
from jose import JWTError, jwt
from passlib.context import CryptContext
from app.core.config import settings

# Password hashing context
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """
    Verify a password against a hash
    
    Args:
        plain_password: The plain text password
        hashed_password: The bcrypt hash
        
    Returns:
        True if password matches, False otherwise
    """
    return pwd_context.verify(plain_password, hashed_password)


def get_password_hash(password: str) -> str:
    """
    Hash a password using bcrypt
    
    Args:
        password: Plain text password
        
    Returns:
        Bcrypt hash string
    """
    return pwd_context.hash(password)


def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    """
    Create a JWT access token
    
    Args:
        data: Data to encode in the token (usually {"sub": user_id})
        expires_delta: Optional expiration time
        
    Returns:
        Encoded JWT token string
    """
    to_encode = data.copy()
    
    # Set expiration time
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    
    to_encode.update({"exp": expire})
    
    # Create token
    encoded_jwt = jwt.encode(
        to_encode,
        settings.SECRET_KEY,
        algorithm=settings.ALGORITHM
    )
    
    return encoded_jwt


def verify_token(token: str) -> Optional[str]:
    """
    Verify and decode a JWT token
    
    Args:
        token: JWT token string
        
    Returns:
        User ID (subject) if valid, None if invalid
    """
    try:
        payload = jwt.decode(
            token,
            settings.SECRET_KEY,
            algorithms=[settings.ALGORITHM]
        )
        user_id: str = payload.get("sub")
        if user_id is None:
            return None
        return user_id
    except JWTError:
        return None
```

**What each function does:**

```python
# Password functions
verify_password("password123", "$2b$12$...")  # → True/False
get_password_hash("password123")  # → "$2b$12$..."

# Token functions
token = create_access_token({"sub": "123"})  # → "eyJhbGci..."
user_id = verify_token(token)  # → "123" or None
```

---

### Step 4: Update User Model

**File: `app/models/user.py`** (update existing)

```python
"""
User model with password hash
"""
from sqlalchemy import Column, Integer, String, Boolean, DateTime
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.database import Base


class User(Base):
    """User model with authentication"""
    
    __tablename__ = "users"
    
    # Identity
    id = Column(Integer, primary_key=True, index=True)
    email = Column(String(100), unique=True, nullable=False, index=True)
    
    # Authentication
    hashed_password = Column(String, nullable=False)  # ← NEW!
    is_active = Column(Boolean, default=True)         # ← NEW!
    is_superuser = Column(Boolean, default=False)     # ← NEW! (for admin)
    
    # Profile
    full_name = Column(String(100))
    
    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Relationships
    todos = relationship("Todo", back_populates="owner", cascade="all, delete-orphan")
    
    def __repr__(self):
        return f"<User(id={self.id}, email='{self.email}')>"
```

**Create migration:**

```bash
alembic revision --autogenerate -m "Add authentication fields to users"
alembic upgrade head
```

---

### Step 5: Token Schemas

**File: `app/schemas/token.py`**

```python
"""
Token schemas for authentication
"""
from pydantic import BaseModel
from typing import Optional


class Token(BaseModel):
    """Access token response"""
    access_token: str
    token_type: str = "bearer"


class TokenData(BaseModel):
    """Data stored in token"""
    user_id: Optional[int] = None
```

---

### Step 6: Update User Schemas

**File: `app/schemas/user.py`** (update)

```python
"""
User schemas with authentication
"""
from pydantic import BaseModel, EmailStr, Field
from typing import Optional
from datetime import datetime


class UserBase(BaseModel):
    """Base user schema"""
    email: EmailStr
    full_name: Optional[str] = None


class UserCreate(UserBase):
    """Schema for user registration"""
    password: str = Field(..., min_length=8, max_length=100)
    # Password requirements could be added here


class UserLogin(BaseModel):
    """Schema for user login"""
    email: EmailStr
    password: str


class UserUpdate(BaseModel):
    """Schema for user update"""
    email: Optional[EmailStr] = None
    full_name: Optional[str] = None
    password: Optional[str] = Field(None, min_length=8, max_length=100)


class UserResponse(UserBase):
    """Public user data (no password!)"""
    id: int
    is_active: bool
    created_at: datetime
    
    class Config:
        from_attributes = True


class UserInDB(UserResponse):
    """User as stored in database (includes hashed_password)"""
    hashed_password: str
```

---

### Step 7: Auth CRUD Operations

**File: `app/crud/crud_user.py`** (update)

```python
"""
User CRUD operations with authentication
"""
from sqlalchemy.orm import Session
from typing import Optional
from app.models.user import User
from app.schemas.user import UserCreate, UserUpdate
from app.core.security import get_password_hash, verify_password


def get_user(db: Session, user_id: int) -> Optional[User]:
    """Get user by ID"""
    return db.query(User).filter(User.id == user_id).first()


def get_user_by_email(db: Session, email: str) -> Optional[User]:
    """Get user by email"""
    return db.query(User).filter(User.email == email).first()


def create_user(db: Session, user: UserCreate) -> User:
    """
    Create new user with hashed password
    """
    # Hash the password
    hashed_password = get_password_hash(user.password)
    
    # Create user (exclude password, add hashed_password)
    db_user = User(
        email=user.email,
        full_name=user.full_name,
        hashed_password=hashed_password,
        is_active=True,
        is_superuser=False
    )
    
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user


def authenticate_user(db: Session, email: str, password: str) -> Optional[User]:
    """
    Authenticate user with email and password
    
    Returns:
        User object if credentials valid, None otherwise
    """
    # Get user
    user = get_user_by_email(db, email)
    if not user:
        return None
    
    # Verify password
    if not verify_password(password, user.hashed_password):
        return None
    
    return user


def update_user(db: Session, user_id: int, user_update: UserUpdate) -> Optional[User]:
    """Update user"""
    db_user = get_user(db, user_id)
    if not db_user:
        return None
    
    update_data = user_update.model_dump(exclude_unset=True)
    
    # Handle password separately
    if "password" in update_data:
        hashed_password = get_password_hash(update_data["password"])
        update_data["hashed_password"] = hashed_password
        del update_data["password"]
    
    for field, value in update_data.items():
        setattr(db_user, field, value)
    
    db.commit()
    db.refresh(db_user)
    return db_user
```

---

### Step 8: Authentication Dependencies

**File: `app/api/deps.py`** (update)

```python
"""
API dependencies including authentication
"""
from typing import Generator, Optional
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session
from jose import JWTError, jwt

from app.database import SessionLocal
from app.core.config import settings
from app.core.security import verify_token
from app.crud import crud_user
from app.models.user import User

# OAuth2 scheme (tells FastAPI where to look for token)
# tokenUrl is the endpoint that returns tokens (we'll create this)
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")


def get_db() -> Generator:
    """Get database session"""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def get_current_user(
    db: Session = Depends(get_db),
    token: str = Depends(oauth2_scheme)
) -> User:
    """
    Get current authenticated user from JWT token
    
    This dependency:
    1. Extracts token from Authorization header
    2. Verifies token signature
    3. Gets user from database
    4. Returns user or raises 401
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    try:
        # Decode token
        payload = jwt.decode(
            token,
            settings.SECRET_KEY,
            algorithms=[settings.ALGORITHM]
        )
        user_id: str = payload.get("sub")
        if user_id is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception
    
    # Get user from database
    user = crud_user.get_user(db, user_id=int(user_id))
    if user is None:
        raise credentials_exception
    
    return user


def get_current_active_user(
    current_user: User = Depends(get_current_user)
) -> User:
    """
    Get current active user (not disabled)
    """
    if not current_user.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Inactive user"
        )
    return current_user


def get_current_superuser(
    current_user: User = Depends(get_current_user)
) -> User:
    """
    Get current superuser (admin check)
    """
    if not current_user.is_superuser:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not enough permissions"
        )
    return current_user
```

**How dependencies work:**

```python
@app.get("/protected")
def protected_route(current_user: User = Depends(get_current_active_user)):
    # current_user is automatically:
    # 1. Extracted from token
    # 2. Verified
    # 3. Fetched from database
    # 4. Checked if active
    # If any step fails → 401 Unauthorized
    
    return {"message": f"Hello, {current_user.email}!"}
```

---

### Step 9: Authentication Endpoints

**File: `app/api/v1/endpoints/auth.py`**

```python
"""
Authentication endpoints: register, login
"""
from datetime import timedelta
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session

from app.api.deps import get_db
from app.core.config import settings
from app.core.security import create_access_token
from app.crud import crud_user
from app.schemas.user import UserCreate, UserResponse
from app.schemas.token import Token

router = APIRouter()


@router.post("/register", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
def register(
    user_in: UserCreate,
    db: Session = Depends(get_db)
):
    """
    Register a new user
    
    - **email**: Valid email address (unique)
    - **password**: Minimum 8 characters
    - **full_name**: Optional full name
    """
    # Check if user exists
    user = crud_user.get_user_by_email(db, email=user_in.email)
    if user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered"
        )
    
    # Create user
    user = crud_user.create_user(db, user=user_in)
    return user


@router.post("/login", response_model=Token)
def login(
    db: Session = Depends(get_db),
    form_data: OAuth2PasswordRequestForm = Depends()
):
    """
    OAuth2 compatible login (returns JWT token)
    
    Use username field for email
    """
    # Authenticate user
    user = crud_user.authenticate_user(
        db,
        email=form_data.username,  # OAuth2 uses 'username' field
        password=form_data.password
    )
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    # Check if active
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Inactive user"
        )
    
    # Create access token
    access_token_expires = timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": str(user.id)},
        expires_delta=access_token_expires
    )
    
    return {
        "access_token": access_token,
        "token_type": "bearer"
    }


@router.post("/login/json", response_model=Token)
def login_json(
    email: str,
    password: str,
    db: Session = Depends(get_db)
):
    """
    Alternative login with JSON body (not OAuth2)
    
    For frontends that prefer JSON over form data
    """
    user = crud_user.authenticate_user(db, email=email, password=password)
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password"
        )
    
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Inactive user"
        )
    
    access_token_expires = timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": str(user.id)},
        expires_delta=access_token_expires
    )
    
    return {
        "access_token": access_token,
        "token_type": "bearer"
    }
```

---

### Step 10: Protected User Endpoints

**File: `app/api/v1/endpoints/users.py`** (update)

```python
"""
User endpoints (protected)
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List

from app.api.deps import get_db, get_current_active_user, get_current_superuser
from app.crud import crud_user
from app.schemas.user import UserResponse, UserUpdate
from app.models.user import User

router = APIRouter()


@router.get("/me", response_model=UserResponse)
def read_users_me(
    current_user: User = Depends(get_current_active_user)
):
    """
    Get current user info
    
    Protected route - requires authentication
    """
    return current_user


@router.put("/me", response_model=UserResponse)
def update_user_me(
    user_update: UserUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """
    Update current user
    
    Protected route - can only update own profile
    """
    user = crud_user.update_user(db, user_id=current_user.id, user_update=user_update)
    return user


@router.get("/", response_model=List[UserResponse])
def read_users(
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_superuser)  # Admin only!
):
    """
    Get all users
    
    Protected route - requires superuser permissions
    """
    users = crud_user.get_users(db, skip=skip, limit=limit)
    return users


@router.get("/{user_id}", response_model=UserResponse)
def read_user(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """
    Get specific user
    
    Protected route - authenticated users can view other users
    """
    user = crud_user.get_user(db, user_id=user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    return user
```

---

### Step 11: Update Todo Endpoints (User-Scoped)

**File: `app/api/v1/endpoints/todos.py`** (update)

```python
"""
Todo endpoints (user-scoped and protected)
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List, Optional

from app.api.deps import get_db, get_current_active_user
from app.crud import crud_todo
from app.schemas.todo import TodoCreate, TodoUpdate, TodoResponse, TodoWithRelations
from app.models.user import User

router = APIRouter()


@router.post("/", response_model=TodoResponse, status_code=status.HTTP_201_CREATED)
def create_todo(
    todo: TodoCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """
    Create a new todo for current user
    
    Protected route - todo automatically assigned to authenticated user
    """
    # Override user_id with current user
    todo.user_id = current_user.id
    return crud_todo.create_todo(db=db, todo=todo)


@router.get("/", response_model=List[TodoResponse])
def get_todos(
    skip: int = 0,
    limit: int = 100,
    completed: Optional[bool] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """
    Get all todos for current user
    
    Protected route - only returns todos owned by authenticated user
    """
    return crud_todo.get_todos(
        db=db,
        skip=skip,
        limit=limit,
        user_id=current_user.id,  # Filter by current user!
        completed=completed
    )


@router.get("/{todo_id}", response_model=TodoWithRelations)
def get_todo(
    todo_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """
    Get specific todo
    
    Protected route - can only view own todos
    """
    todo = crud_todo.get_todo_with_relations(db=db, todo_id=todo_id)
    
    if not todo:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Todo not found"
        )
    
    # Authorization check: is this user's todo?
    if todo.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to access this todo"
        )
    
    return todo


@router.put("/{todo_id}", response_model=TodoResponse)
def update_todo(
    todo_id: int,
    todo_update: TodoUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """
    Update todo
    
    Protected route - can only update own todos
    """
    # Get todo
    todo = crud_todo.get_todo(db=db, todo_id=todo_id)
    
    if not todo:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Todo not found"
        )
    
    # Authorization check
    if todo.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to update this todo"
        )
    
    return crud_todo.update_todo(db=db, todo_id=todo_id, todo_update=todo_update)


@router.delete("/{todo_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_todo(
    todo_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """
    Delete todo
    
    Protected route - can only delete own todos
    """
    todo = crud_todo.get_todo(db=db, todo_id=todo_id)
    
    if not todo:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Todo not found"
        )
    
    # Authorization check
    if todo.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to delete this todo"
        )
    
    crud_todo.delete_todo(db=db, todo_id=todo_id)
```

---

### Step 12: Update API Router

**File: `app/api/v1/api.py`** (update)

```python
"""
API v1 router
"""
from fastapi import APIRouter
from app.api.v1.endpoints import auth, users, todos, tags

api_router = APIRouter()

# Public routes
api_router.include_router(
    auth.router,
    prefix="/auth",
    tags=["authentication"]
)

# Protected routes
api_router.include_router(
    users.router,
    prefix="/users",
    tags=["users"]
)

api_router.include_router(
    todos.router,
    prefix="/todos",
    tags=["todos"]
)

api_router.include_router(
    tags.router,
    prefix="/tags",
    tags=["tags"]
)
```

---

## Part 5: Testing the Authentication System

### Step 1: Register a User

**Using /docs (Swagger UI):**

```
1. Go to http://localhost:8000/docs
2. Find POST /api/v1/auth/register
3. Click "Try it out"
4. Enter:
   {
     "email": "alice@example.com",
     "password": "mysecret123",
     "full_name": "Alice Smith"
   }
5. Click "Execute"

Response: 201 Created
{
  "id": 1,
  "email": "alice@example.com",
  "full_name": "Alice Smith",
  "is_active": true,
  "created_at": "2026-02-10T10:00:00"
}
```

---

### Step 2: Login

**Method 1: OAuth2 (in /docs):**

```
1. Find POST /api/v1/auth/login
2. Click "Try it out"
3. Enter:
   username: alice@example.com  (use email here)
   password: mysecret123
4. Click "Execute"

Response: 200 OK
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer"
}

5. COPY THE TOKEN!
```

---

### Step 3: Use Token to Access Protected Routes

**In /docs:**

```
1. Click "Authorize" button (top right with lock icon)
2. Enter token: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
3. Click "Authorize"
4. Click "Close"

Now you're authenticated! 🎉
```

**Try protected endpoint:**

```
1. Find GET /api/v1/users/me
2. Click "Try it out"
3. Click "Execute"

Response: 200 OK
{
  "id": 1,
  "email": "alice@example.com",
  "full_name": "Alice Smith",
  "is_active": true,
  "created_at": "2026-02-10T10:00:00"
}
```

---

### Step 4: Create Todo (Authenticated)

```
1. POST /api/v1/todos
2. Click "Try it out"
3. Enter:
   {
     "title": "My first todo",
     "description": "Testing authentication"
   }
4. Click "Execute"

Response: 201 Created
{
  "id": 1,
  "title": "My first todo",
  "description": "Testing authentication",
  "completed": false,
  "user_id": 1,  ← Automatically set to your ID!
  "created_at": "2026-02-10T10:05:00"
}
```

---

### Step 5: Test Authorization (Try to Access Other User's Todo)

```
1. Register second user (bob@example.com)
2. Login as Bob, get token
3. Bob creates a todo (id: 2)
4. Login as Alice again
5. Try: GET /api/v1/todos/2

Response: 403 Forbidden
{
  "detail": "Not authorized to access this todo"
}

✅ Authorization working! Alice can't see Bob's todos!
```

---

## Part 6: Security Best Practices

### 1. Password Requirements

```python
# Add to UserCreate schema
from pydantic import validator
import re

class UserCreate(UserBase):
    password: str = Field(..., min_length=8, max_length=100)
    
    @validator('password')
    def validate_password(cls, v):
        """
        Password must have:
        - At least 8 characters
        - At least one uppercase letter
        - At least one lowercase letter
        - At least one digit
        """
        if len(v) < 8:
            raise ValueError('Password must be at least 8 characters')
        
        if not re.search(r'[A-Z]', v):
            raise ValueError('Password must contain uppercase letter')
        
        if not re.search(r'[a-z]', v):
            raise ValueError('Password must contain lowercase letter')
        
        if not re.search(r'\d', v):
            raise ValueError('Password must contain digit')
        
        return v
```

---

### 2. Rate Limiting (Prevent Brute Force)

```python
from slowapi import Limiter
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)

@router.post("/login")
@limiter.limit("5/minute")  # Max 5 login attempts per minute
def login(request: Request, ...):
    # Login logic
    pass
```

---

### 3. Token Expiration

```python
# Short-lived access tokens
ACCESS_TOKEN_EXPIRE_MINUTES=30  # 30 minutes

# For longer sessions, implement refresh tokens:
# - Access token: 15-30 minutes
# - Refresh token: 7-30 days
# - Use refresh token to get new access token
```

---

### 4. HTTPS Only (Production)

```python
# In production, ALWAYS use HTTPS
# Never send tokens over HTTP!

# Force HTTPS redirect
from fastapi.middleware.httpsredirect import HTTPSRedirectMiddleware
app.add_middleware(HTTPSRedirectMiddleware)
```

---

### 5. Secure Headers

```python
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware

# CORS (restrict origins)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://yourdomain.com"],  # Not "*"!
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Trusted hosts
app.add_middleware(
    TrustedHostMiddleware,
    allowed_hosts=["yourdomain.com", "*.yourdomain.com"]
)
```

---

### 6. Don't Log Sensitive Data

```python
# ❌ BAD
logger.info(f"User login: {email} with password {password}")

# ✅ GOOD
logger.info(f"User login attempt: {email}")
logger.info(f"Login successful for user {user_id}")
```

---

### 7. SQL Injection Prevention

```python
# ✅ GOOD (SQLAlchemy prevents this automatically)
user = db.query(User).filter(User.email == email).first()

# ❌ BAD (raw SQL vulnerable)
result = db.execute(f"SELECT * FROM users WHERE email = '{email}'")
```

---

## Part 7: Tasks for You

### Task 1: Implement Refresh Tokens

Add refresh token functionality:
- Access token expires in 15 minutes
- Refresh token expires in 7 days
- Endpoint to refresh access token

<details>
<summary>Hint</summary>

```python
def create_refresh_token(data: dict) -> str:
    expire = datetime.utcnow() + timedelta(days=7)
    to_encode = data.copy()
    to_encode.update({"exp": expire, "type": "refresh"})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

@router.post("/refresh")
def refresh_token(refresh_token: str):
    # Verify refresh token
    # Create new access token
    # Return new access token
    pass
```
</details>

---

### Task 2: Email Verification

Add email verification on registration:
- Send verification email
- User must verify before login
- Add `is_verified` field

---

### Task 3: Password Reset

Implement forgot password:
- User requests reset link
- Send email with token
- User sets new password

---

## ✅ Week 7 Checklist

- [ ] Understand authentication vs authorization
- [ ] Understand password hashing
- [ ] Know why we never store plain passwords
- [ ] Understand JWT structure
- [ ] Understand how JWT signature works
- [ ] Installed security dependencies
- [ ] Created security utilities
- [ ] Updated User model with password
- [ ] Created token schemas
- [ ] Implemented registration
- [ ] Implemented login
- [ ] Created protected routes
- [ ] Tested authentication flow
- [ ] Understand OAuth2PasswordBearer
- [ ] Know security best practices

---

## 🎓 Knowledge Check

1. **What's the difference between authentication and authorization?**
2. **Why do we hash passwords?**
3. **What are the 3 parts of a JWT?**
4. **Can you read JWT payload without the secret key?**
5. **What does OAuth2PasswordBearer do?**
6. **How does Depends(get_current_user) work?**
7. **What's the difference between 401 and 403?**

<details>
<summary>Answers</summary>

1. Authentication = who you are, Authorization = what you can do
2. So if database is stolen, passwords are still safe
3. Header, Payload, Signature
4. Yes (base64), but can't modify it (signature validates)
5. Tells FastAPI where to find the token (Authorization header)
6. Extracts token, verifies it, gets user from DB, injects into function
7. 401 = not authenticated, 403 = authenticated but not authorized
</details>

---

## 🎉 Congratulations!

You now have:
- ✅ Secure user authentication
- ✅ JWT-based authorization
- ✅ Password hashing with bcrypt
- ✅ Protected API endpoints
- ✅ User-scoped data access
- ✅ Production-ready security

**Your API is now secure and production-ready!** 🔐

---

## 📚 Week 8 Preview

**Next: Middleware, CORS, and Advanced FastAPI Features**

- Custom middleware
- Request/response interceptors
- CORS configuration
- Background tasks
- WebSockets
- File uploads
- Dependency injection patterns

---

**Ready for Week 8? Say: "I completed Week 7, ready for Week 8!"**

Ask any questions! 😊

---

**Progress**: Week 7 of 14 ⭐⭐⭐⭐⭐⭐⭐
**Next Topic**: Middleware & Advanced Features
**Status**: You're building secure, production-grade applications! 🚀