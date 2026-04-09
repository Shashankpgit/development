# Week 6: Advanced Database Features & Relationships 🔗

**Goal**: Master advanced database concepts for production-ready applications

**What You'll Learn**:
- Database relationships (One-to-Many, Many-to-Many)
- Foreign keys and referential integrity
- Database migrations with Alembic
- Query optimization and indexes
- Transactions and data consistency
- Complex queries and joins

**What You'll Build**: Multi-table Todo application with Users, Categories, and Tags

---

## Part 1: Understanding Database Relationships (Deep Dive)

### Why Do We Need Relationships?

**Without Relationships (Bad Design):**

```python
# Storing user info in every todo
class Todo(Base):
    __tablename__ = "todos"
    id = Column(Integer, primary_key=True)
    title = Column(String)
    user_name = Column(String)      # ❌ Duplicate data
    user_email = Column(String)     # ❌ Duplicate data
    user_phone = Column(String)     # ❌ Duplicate data
```

**Problems:**
- ❌ Data duplication (user info repeated in every todo)
- ❌ Update anomaly (change email? must update 100 todos!)
- ❌ Inconsistency risk (typos, outdated info)
- ❌ Wasted storage
- ❌ Query inefficiency

---

**With Relationships (Good Design):**

```python
# User stored once
class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True)
    name = Column(String)
    email = Column(String)
    phone = Column(String)

# Todo references user
class Todo(Base):
    __tablename__ = "todos"
    id = Column(Integer, primary_key=True)
    title = Column(String)
    user_id = Column(Integer, ForeignKey("users.id"))  # ✅ Reference
```

**Benefits:**
- ✅ No duplication
- ✅ Update once, reflects everywhere
- ✅ Data consistency
- ✅ Efficient storage
- ✅ Fast queries with indexes

---

### The Three Types of Relationships

```
1. ONE-TO-MANY (Most Common)
   One User → Many Todos
   One Category → Many Products
   One Author → Many Books

2. MANY-TO-MANY
   Many Students ↔ Many Courses
   Many Todos ↔ Many Tags
   Many Users ↔ Many Groups

3. ONE-TO-ONE (Rare)
   One User → One Profile
   One Person → One Passport
```

---

## Part 2: One-to-Many Relationships (Complete Guide)

### Real-World Example: Users and Todos

**Scenario:** 
- Each user can have many todos
- Each todo belongs to one user

```
┌─────────────┐         ┌─────────────┐
│   users     │         │    todos    │
├─────────────┤         ├─────────────┤
│ id (PK)     │←──┐     │ id (PK)     │
│ name        │   │     │ title       │
│ email       │   └─────│ user_id(FK) │
└─────────────┘         └─────────────┘
  One User                Many Todos
```

---

### Implementation Step-by-Step

#### Step 1: Create User Model

**File: `app/models/user.py`**

```python
"""
User model - represents users table
"""
from sqlalchemy import Column, Integer, String, DateTime
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.database import Base


class User(Base):
    """User model with one-to-many relationship to todos"""
    
    __tablename__ = "users"
    
    # Primary Key
    id = Column(Integer, primary_key=True, index=True)
    
    # User fields
    name = Column(String(100), nullable=False)
    email = Column(String(100), unique=True, nullable=False, index=True)
    
    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Relationship: One user has many todos
    # This creates a virtual attribute user.todos
    todos = relationship(
        "Todo",                    # Related model name
        back_populates="owner",    # Attribute name in Todo model
        cascade="all, delete-orphan"  # Delete todos when user deleted
    )
    
    def __repr__(self):
        return f"<User(id={self.id}, email='{self.email}')>"
```

**Key Concepts Explained:**

```python
# relationship() creates a virtual attribute
todos = relationship("Todo", ...)

# This allows:
user = session.query(User).first()
user.todos  # ← List of Todo objects (automatic JOIN!)

# back_populates connects both sides
# User.todos ↔ Todo.owner

# cascade="all, delete-orphan" means:
# When user is deleted → all their todos are deleted too
```

---

#### Step 2: Update Todo Model with Foreign Key

**File: `app/models/todo.py`**

```python
"""
Todo model with foreign key to users
"""
from sqlalchemy import Column, Integer, String, Boolean, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.database import Base


class Todo(Base):
    """Todo model with many-to-one relationship to users"""
    
    __tablename__ = "todos"
    
    # Primary Key
    id = Column(Integer, primary_key=True, index=True)
    
    # Todo fields
    title = Column(String(100), nullable=False, index=True)
    description = Column(String(500))
    completed = Column(Boolean, default=False)
    
    # Foreign Key - links to users table
    user_id = Column(
        Integer,
        ForeignKey("users.id", ondelete="CASCADE"),  # CASCADE delete
        nullable=False,
        index=True  # Index for faster queries
    )
    
    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Relationship: Many todos belong to one user
    # This creates a virtual attribute todo.owner
    owner = relationship(
        "User",
        back_populates="todos"
    )
    
    def __repr__(self):
        return f"<Todo(id={self.id}, title='{self.title}', user_id={self.user_id})>"
```

**Foreign Key Explained:**

```python
user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"))

# What this does:
# 1. Creates user_id column (stores integer)
# 2. Links to users.id (foreign key constraint)
# 3. ondelete="CASCADE" - when user deleted, delete todos
# 4. Database enforces this (can't create todo with invalid user_id)

# Database-level constraint:
# ALTER TABLE todos
# ADD CONSTRAINT fk_user
# FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
```

---

#### Step 3: Update `models/__init__.py`

```python
"""
Export all models
"""
from .user import User
from .todo import Todo

__all__ = ["User", "Todo"]
```

---

### How Relationships Work

#### Creating Related Data

```python
from app.models import User, Todo

# Create a user
user = User(name="Alice", email="alice@example.com")
db.add(user)
db.commit()
db.refresh(user)

# Method 1: Create todo with user_id
todo1 = Todo(
    title="Buy groceries",
    description="Milk, eggs, bread",
    user_id=user.id  # ← Explicitly set foreign key
)
db.add(todo1)
db.commit()

# Method 2: Create todo via relationship
todo2 = Todo(title="Clean house", description="Living room")
user.todos.append(todo2)  # ← Use relationship
db.commit()

# Method 3: Create todo and set owner
todo3 = Todo(title="Pay bills", description="Electricity")
todo3.owner = user  # ← Set relationship
db.add(todo3)
db.commit()
```

---

#### Querying Related Data

```python
# Get user with all todos (eager loading)
from sqlalchemy.orm import joinedload

user = db.query(User)\
    .options(joinedload(User.todos))\
    .filter(User.id == 1)\
    .first()

# Access todos (no additional query!)
for todo in user.todos:
    print(todo.title)

# Get todo with owner
todo = db.query(Todo).filter(Todo.id == 1).first()
print(todo.owner.name)  # Automatically fetches user

# Filter by relationship
# Get all todos by specific user
user_todos = db.query(Todo).filter(Todo.user_id == 1).all()

# Or via relationship
user = db.query(User).filter(User.id == 1).first()
todos = user.todos  # Same result
```

---

### The N+1 Query Problem

**Problem:**

```python
# Get all todos
todos = db.query(Todo).all()  # 1 query

# Access owner for each (N queries - BAD!)
for todo in todos:
    print(todo.owner.name)  # ❌ New query for EACH todo!

# If you have 100 todos, this makes 101 queries! 💥
```

**Solution: Eager Loading**

```python
from sqlalchemy.orm import joinedload

# Fetch todos WITH owners in ONE query
todos = db.query(Todo)\
    .options(joinedload(Todo.owner))\
    .all()  # ✅ 1 query total

for todo in todos:
    print(todo.owner.name)  # ✅ No additional queries!
```

---

## Part 3: Many-to-Many Relationships

### Real-World Example: Todos and Tags

**Scenario:**
- Each todo can have many tags
- Each tag can be on many todos

```
┌─────────────┐    ┌─────────────────┐    ┌─────────────┐
│    todos    │    │  todo_tags      │    │    tags     │
├─────────────┤    │ (association)   │    ├─────────────┤
│ id (PK)     │←───│ todo_id (FK)    │    │ id (PK)     │
│ title       │    │ tag_id (FK)     │───→│ name        │
└─────────────┘    └─────────────────┘    └─────────────┘
  Many                 Junction              Many
```

---

### Implementation

#### Step 1: Create Association Table

**File: `app/models/todo.py`** (add to existing file)

```python
from sqlalchemy import Table, Column, Integer, ForeignKey

# Association table for many-to-many
# This is NOT a model class, just a Table
todo_tags = Table(
    'todo_tags',
    Base.metadata,
    Column('todo_id', Integer, ForeignKey('todos.id', ondelete='CASCADE'), primary_key=True),
    Column('tag_id', Integer, ForeignKey('tags.id', ondelete='CASCADE'), primary_key=True)
)
```

**What this creates:**

```sql
CREATE TABLE todo_tags (
    todo_id INTEGER NOT NULL,
    tag_id INTEGER NOT NULL,
    PRIMARY KEY (todo_id, tag_id),
    FOREIGN KEY (todo_id) REFERENCES todos(id) ON DELETE CASCADE,
    FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
);

-- Example data:
-- todo_id | tag_id
-- --------|-------
--    1    |   1     (Todo 1 has Tag 1)
--    1    |   2     (Todo 1 has Tag 2)
--    2    |   1     (Todo 2 has Tag 1)
```

---

#### Step 2: Create Tag Model

**File: `app/models/tag.py`**

```python
"""
Tag model for many-to-many relationship with todos
"""
from sqlalchemy import Column, Integer, String, DateTime
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.database import Base
from app.models.todo import todo_tags


class Tag(Base):
    """Tag model"""
    
    __tablename__ = "tags"
    
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(50), unique=True, nullable=False, index=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Many-to-many relationship with todos
    todos = relationship(
        "Todo",
        secondary=todo_tags,  # ← Association table
        back_populates="tags"
    )
    
    def __repr__(self):
        return f"<Tag(id={self.id}, name='{self.name}')>"
```

---

#### Step 3: Update Todo Model

**Add to `app/models/todo.py`:**

```python
class Todo(Base):
    # ... existing code ...
    
    # Many-to-many relationship with tags
    tags = relationship(
        "Tag",
        secondary=todo_tags,  # ← Association table
        back_populates="todos"
    )
```

---

### Using Many-to-Many Relationships

```python
# Create tags
tag_work = Tag(name="work")
tag_urgent = Tag(name="urgent")
tag_personal = Tag(name="personal")
db.add_all([tag_work, tag_urgent, tag_personal])
db.commit()

# Create todo with tags
todo = Todo(title="Finish report", user_id=1)
todo.tags.append(tag_work)      # Add work tag
todo.tags.append(tag_urgent)    # Add urgent tag
db.add(todo)
db.commit()

# Query todos by tag
work_todos = db.query(Todo)\
    .join(Todo.tags)\
    .filter(Tag.name == "work")\
    .all()

# Get all tags for a todo
todo = db.query(Todo).filter(Todo.id == 1).first()
for tag in todo.tags:
    print(tag.name)

# Get all todos for a tag
tag = db.query(Tag).filter(Tag.name == "work").first()
for todo in tag.todos:
    print(todo.title)

# Add tag to existing todo
todo.tags.append(tag_personal)
db.commit()

# Remove tag
todo.tags.remove(tag_urgent)
db.commit()
```

---

## Part 4: Database Migrations with Alembic

### Why Migrations?

**The Problem:**

```python
# Week 1: You create tables
Base.metadata.create_all(engine)

# Week 2: You add a column to User model
class User(Base):
    # ... existing columns ...
    phone = Column(String)  # ← NEW COLUMN

# Problem: Existing database doesn't have 'phone' column!
# Base.metadata.create_all() doesn't update existing tables 💥
```

**The Solution: Migrations**

Migrations are version-controlled database changes:
- Track every schema change
- Apply changes incrementally
- Can rollback if needed
- Team members stay in sync

---

### Setting Up Alembic

#### Step 1: Install Alembic

```bash
pip install alembic
pip freeze > requirements.txt
```

---

#### Step 2: Initialize Alembic

```bash
# Run from project root
alembic init alembic

# This creates:
# alembic/
# ├── env.py           # Alembic configuration
# ├── script.py.mako   # Migration template
# └── versions/        # Migration files go here
# alembic.ini          # Alembic config file
```

---

#### Step 3: Configure Alembic

**Edit `alembic/env.py`:**

```python
# Add near the top (after imports)
from app.database import Base
from app.models import User, Todo, Tag  # Import all models

# Find this line and replace:
# target_metadata = None
target_metadata = Base.metadata  # ← Use our models' metadata

# Find run_migrations_offline() and update:
def run_migrations_offline():
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        compare_type=True,  # ← Add this
    )
    # ... rest of function

# Find run_migrations_online() and update:
def run_migrations_online():
    # ... existing code ...
    with connectable.connect() as connection:
        context.configure(
            connection=connection,
            target_metadata=target_metadata,
            compare_type=True,  # ← Add this
        )
        # ... rest of function
```

**Edit `alembic.ini`:**

```ini
# Replace this line:
sqlalchemy.url = driver://user:pass@localhost/dbname

# With your actual database URL:
sqlalchemy.url = postgresql://postgres:password@localhost:5432/tododb
```

---

### Creating Migrations

#### Initial Migration (Create All Tables)

```bash
# Generate migration from current models
alembic revision --autogenerate -m "Initial migration - create users, todos, tags tables"

# This creates: alembic/versions/xxxx_initial_migration.py
```

**What gets generated:**

```python
# alembic/versions/xxxx_initial_migration.py

def upgrade():
    # Create users table
    op.create_table('users',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('name', sa.String(length=100), nullable=False),
        sa.Column('email', sa.String(length=100), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_users_id'), 'users', ['id'], unique=False)
    op.create_index(op.f('ix_users_email'), 'users', ['email'], unique=True)
    
    # Create todos table
    op.create_table('todos',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('title', sa.String(length=100), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    # ... more tables ...

def downgrade():
    # Reverse all changes
    op.drop_table('todos')
    op.drop_table('users')
    # ... reverse order ...
```

---

#### Apply Migration

```bash
# Apply all pending migrations
alembic upgrade head

# You'll see:
# INFO  [alembic.runtime.migration] Running upgrade  -> xxxx, Initial migration
# INFO  [alembic.runtime.migration] Context impl PostgresqlImpl.
```

---

#### Adding a New Column (Example)

**1. Modify model:**

```python
# app/models/user.py
class User(Base):
    # ... existing columns ...
    phone = Column(String(20), nullable=True)  # ← NEW
```

**2. Generate migration:**

```bash
alembic revision --autogenerate -m "Add phone column to users"
```

**3. Review generated migration:**

```python
# alembic/versions/yyyy_add_phone_column.py

def upgrade():
    op.add_column('users', sa.Column('phone', sa.String(length=20), nullable=True))

def downgrade():
    op.drop_column('users', 'phone')
```

**4. Apply migration:**

```bash
alembic upgrade head
```

---

### Common Migration Commands

```bash
# Generate migration
alembic revision --autogenerate -m "description"

# Apply all migrations
alembic upgrade head

# Apply next migration
alembic upgrade +1

# Rollback one migration
alembic downgrade -1

# Rollback all migrations
alembic downgrade base

# Show current version
alembic current

# Show migration history
alembic history

# Show SQL without executing
alembic upgrade head --sql
```

---

## Part 5: Database Indexes & Performance

### What is an Index?

**Book Analogy:**

```
Book without index:
- Want page about "SQLAlchemy"
- Must read EVERY page to find it ❌
- Slow! 📖📖📖

Book with index:
- Look in index: "SQLAlchemy - Page 127"
- Go directly to page 127 ✅
- Fast! 📖
```

**Database Index:**
- Special data structure
- Allows fast lookups
- Trade-off: Slower writes, more storage

---

### When to Add Indexes

```python
class User(Base):
    __tablename__ = "users"
    
    # Always index primary keys (automatic)
    id = Column(Integer, primary_key=True, index=True)
    
    # Index columns used in WHERE clauses
    email = Column(String, unique=True, index=True)  # ✅ Often searched
    
    # Index foreign keys
    # SQLAlchemy doesn't auto-index FKs, you must!
    
    # Don't index everything (slower writes)
    bio = Column(Text)  # ❌ Not indexed - large text, rarely searched
```

**Rules of thumb:**
- ✅ Index columns in WHERE clauses
- ✅ Index columns in JOIN conditions
- ✅ Index foreign keys
- ✅ Index unique columns
- ❌ Don't index columns that change frequently
- ❌ Don't index large text fields
- ❌ Don't index columns with few unique values (gender, boolean)

---

### Creating Indexes

**In model definition:**

```python
class Todo(Base):
    __tablename__ = "todos"
    
    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, index=True)  # Simple index
    user_id = Column(Integer, ForeignKey("users.id"), index=True)  # FK index
```

**Composite index (multiple columns):**

```python
from sqlalchemy import Index

class Todo(Base):
    __tablename__ = "todos"
    
    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    completed = Column(Boolean, default=False)
    created_at = Column(DateTime, server_default=func.now())
    
    # Composite index for common query
    __table_args__ = (
        Index('ix_user_completed', 'user_id', 'completed'),
        # Speeds up: WHERE user_id = X AND completed = Y
    )
```

---

### Query Performance Tips

```python
# ❌ BAD: Fetch all then filter in Python
todos = db.query(Todo).all()
user_todos = [t for t in todos if t.user_id == 1]  # Slow!

# ✅ GOOD: Filter in database
user_todos = db.query(Todo).filter(Todo.user_id == 1).all()


# ❌ BAD: N+1 queries
todos = db.query(Todo).all()
for todo in todos:
    print(todo.owner.name)  # New query each time!

# ✅ GOOD: Eager loading
from sqlalchemy.orm import joinedload
todos = db.query(Todo).options(joinedload(Todo.owner)).all()
for todo in todos:
    print(todo.owner.name)  # No additional queries!


# ❌ BAD: Load everything then slice
todos = db.query(Todo).all()[0:10]  # Loads ALL from DB!

# ✅ GOOD: Limit in database
todos = db.query(Todo).limit(10).all()


# ❌ BAD: Count with len()
count = len(db.query(Todo).all())  # Loads all rows!

# ✅ GOOD: COUNT query
count = db.query(Todo).count()  # Just counts in DB
```

---

## Part 6: Transactions & Data Consistency

### What is a Transaction?

**Real-world analogy: Bank transfer**

```
Transfer $100 from Alice to Bob:

WITHOUT TRANSACTION:
1. Subtract $100 from Alice's account  ✅
2. [💥 Power outage!]
3. Add $100 to Bob's account  ❌ Never happens

Result: $100 disappeared! Money lost! 💸


WITH TRANSACTION:
1. BEGIN TRANSACTION
2. Subtract $100 from Alice's account
3. Add $100 to Bob's account
4. COMMIT (both succeed) or ROLLBACK (both fail)

Result: Either both happen or neither happens! ✅
```

---

### ACID Properties

```
A - Atomicity:    All or nothing
C - Consistency:  Valid state to valid state
I - Isolation:    Concurrent transactions don't interfere
D - Durability:   Committed data persists
```

---

### Using Transactions in SQLAlchemy

**Automatic transaction per request:**

```python
from app.database import get_db

@app.post("/transfer")
def transfer_money(
    from_user: int,
    to_user: int,
    amount: float,
    db: Session = Depends(get_db)
):
    try:
        # Everything in this block is ONE transaction
        
        # Deduct from sender
        sender = db.query(User).filter(User.id == from_user).first()
        if sender.balance < amount:
            raise ValueError("Insufficient funds")
        sender.balance -= amount
        
        # Add to receiver
        receiver = db.query(User).filter(User.id == to_user).first()
        receiver.balance += amount
        
        # Commit both changes together
        db.commit()
        
        return {"status": "success"}
        
    except Exception as e:
        # Rollback if anything goes wrong
        db.rollback()
        raise HTTPException(status_code=400, detail=str(e))
```

---

**Manual transaction control:**

```python
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

engine = create_engine(DATABASE_URL)
Session = sessionmaker(bind=engine)

# Method 1: Manual commit/rollback
session = Session()
try:
    # Do operations
    user = User(name="Alice")
    session.add(user)
    
    todo = Todo(title="Task", user_id=user.id)
    session.add(todo)
    
    # Commit both together
    session.commit()
except:
    # Rollback if error
    session.rollback()
    raise
finally:
    session.close()


# Method 2: Context manager (preferred)
with Session() as session:
    with session.begin():
        # Auto-commit on exit, auto-rollback on exception
        user = User(name="Alice")
        session.add(user)
        
        todo = Todo(title="Task", user_id=user.id)
        session.add(todo)
    # Automatic commit here
```

---

### Savepoints (Nested Transactions)

```python
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

Session = sessionmaker(bind=engine)

with Session() as session:
    # Main transaction
    user = User(name="Alice")
    session.add(user)
    session.flush()  # Get user.id without committing
    
    # Savepoint
    savepoint = session.begin_nested()
    try:
        # This might fail
        todo = Todo(title="Risky task", user_id=user.id)
        session.add(todo)
        risky_operation()  # Might raise exception
        session.commit()  # Commit savepoint
    except:
        savepoint.rollback()  # Rollback just this savepoint
        # user is still added!
    
    session.commit()  # Commit main transaction
```

---

## Part 7: Complete Updated Application

Let's put it all together with the updated project structure.

### Updated Project Structure

```
todo-api/
├── app/
│   ├── __init__.py
│   ├── main.py
│   ├── config.py
│   ├── database.py
│   │
│   ├── models/
│   │   ├── __init__.py
│   │   ├── user.py         # User model
│   │   ├── todo.py         # Todo model with relationships
│   │   └── tag.py          # Tag model
│   │
│   ├── schemas/
│   │   ├── __init__.py
│   │   ├── user.py         # User schemas
│   │   ├── todo.py         # Updated Todo schemas
│   │   └── tag.py          # Tag schemas
│   │
│   ├── crud/
│   │   ├── __init__.py
│   │   ├── crud_user.py    # User CRUD
│   │   ├── crud_todo.py    # Updated Todo CRUD
│   │   └── crud_tag.py     # Tag CRUD
│   │
│   └── api/
│       ├── deps.py
│       └── v1/
│           ├── api.py
│           └── endpoints/
│               ├── __init__.py
│               ├── users.py    # User endpoints
│               ├── todos.py    # Updated Todo endpoints
│               └── tags.py     # Tag endpoints
│
├── alembic/
│   ├── versions/
│   └── env.py
├── alembic.ini
├── .env
└── requirements.txt
```

---

### Updated Schemas

**File: `app/schemas/user.py`**

```python
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
```

---

**File: `app/schemas/todo.py`**

```python
from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime


class TodoBase(BaseModel):
    title: str = Field(..., min_length=1, max_length=100)
    description: str = Field(..., max_length=500)
    completed: bool = Field(default=False)


class TodoCreate(TodoBase):
    user_id: int = Field(..., gt=0)
    tag_ids: Optional[List[int]] = []


class TodoUpdate(BaseModel):
    title: Optional[str] = Field(None, min_length=1, max_length=100)
    description: Optional[str] = Field(None, max_length=500)
    completed: Optional[bool] = None
    tag_ids: Optional[List[int]] = None


class TodoResponse(TodoBase):
    id: int
    user_id: int
    created_at: datetime
    updated_at: Optional[datetime] = None
    
    class Config:
        from_attributes = True


class TodoWithRelations(TodoResponse):
    """Todo with owner and tags"""
    owner: "UserResponse"
    tags: List["TagResponse"] = []


# Avoid circular imports
from app.schemas.user import UserResponse
from app.schemas.tag import TagResponse
TodoWithRelations.model_rebuild()
```

---

**File: `app/schemas/tag.py`**

```python
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
```

---

### Updated CRUD Operations

**File: `app/crud/crud_user.py`**

```python
from sqlalchemy.orm import Session, joinedload
from typing import List, Optional
from app.models.user import User
from app.schemas.user import UserCreate, UserUpdate


def get_user(db: Session, user_id: int) -> Optional[User]:
    """Get user by ID"""
    return db.query(User).filter(User.id == user_id).first()


def get_user_by_email(db: Session, email: str) -> Optional[User]:
    """Get user by email"""
    return db.query(User).filter(User.email == email).first()


def get_users(db: Session, skip: int = 0, limit: int = 100) -> List[User]:
    """Get all users"""
    return db.query(User).offset(skip).limit(limit).all()


def get_user_with_todos(db: Session, user_id: int) -> Optional[User]:
    """Get user with all their todos (eager loading)"""
    return db.query(User)\
        .options(joinedload(User.todos))\
        .filter(User.id == user_id)\
        .first()


def create_user(db: Session, user: UserCreate) -> User:
    """Create new user"""
    db_user = User(**user.model_dump())
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user


def update_user(db: Session, user_id: int, user_update: UserUpdate) -> Optional[User]:
    """Update user"""
    db_user = get_user(db, user_id)
    if not db_user:
        return None
    
    update_data = user_update.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(db_user, field, value)
    
    db.commit()
    db.refresh(db_user)
    return db_user


def delete_user(db: Session, user_id: int) -> bool:
    """Delete user (cascades to todos)"""
    db_user = get_user(db, user_id)
    if not db_user:
        return False
    
    db.delete(db_user)
    db.commit()
    return True
```

---

**File: `app/crud/crud_todo.py`** (updated)

```python
from sqlalchemy.orm import Session, joinedload
from typing import List, Optional
from app.models.todo import Todo
from app.models.tag import Tag
from app.schemas.todo import TodoCreate, TodoUpdate


def get_todo(db: Session, todo_id: int) -> Optional[Todo]:
    """Get todo by ID"""
    return db.query(Todo).filter(Todo.id == todo_id).first()


def get_todo_with_relations(db: Session, todo_id: int) -> Optional[Todo]:
    """Get todo with owner and tags"""
    return db.query(Todo)\
        .options(joinedload(Todo.owner), joinedload(Todo.tags))\
        .filter(Todo.id == todo_id)\
        .first()


def get_todos(
    db: Session,
    skip: int = 0,
    limit: int = 100,
    user_id: Optional[int] = None,
    completed: Optional[bool] = None,
    tag_id: Optional[int] = None
) -> List[Todo]:
    """Get todos with filtering"""
    query = db.query(Todo)
    
    if user_id is not None:
        query = query.filter(Todo.user_id == user_id)
    
    if completed is not None:
        query = query.filter(Todo.completed == completed)
    
    if tag_id is not None:
        query = query.join(Todo.tags).filter(Tag.id == tag_id)
    
    return query.offset(skip).limit(limit).all()


def create_todo(db: Session, todo: TodoCreate) -> Todo:
    """Create new todo with tags"""
    # Extract tag_ids before creating todo
    tag_ids = todo.tag_ids if hasattr(todo, 'tag_ids') else []
    todo_data = todo.model_dump(exclude={'tag_ids'})
    
    # Create todo
    db_todo = Todo(**todo_data)
    
    # Add tags if provided
    if tag_ids:
        tags = db.query(Tag).filter(Tag.id.in_(tag_ids)).all()
        db_todo.tags = tags
    
    db.add(db_todo)
    db.commit()
    db.refresh(db_todo)
    return db_todo


def update_todo(db: Session, todo_id: int, todo_update: TodoUpdate) -> Optional[Todo]:
    """Update todo"""
    db_todo = get_todo(db, todo_id)
    if not db_todo:
        return None
    
    # Handle tags separately
    tag_ids = None
    if hasattr(todo_update, 'tag_ids') and todo_update.tag_ids is not None:
        tag_ids = todo_update.tag_ids
    
    # Update regular fields
    update_data = todo_update.model_dump(exclude={'tag_ids'}, exclude_unset=True)
    for field, value in update_data.items():
        setattr(db_todo, field, value)
    
    # Update tags if provided
    if tag_ids is not None:
        tags = db.query(Tag).filter(Tag.id.in_(tag_ids)).all()
        db_todo.tags = tags
    
    db.commit()
    db.refresh(db_todo)
    return db_todo


def delete_todo(db: Session, todo_id: int) -> bool:
    """Delete todo"""
    db_todo = get_todo(db, todo_id)
    if not db_todo:
        return False
    
    db.delete(db_todo)
    db.commit()
    return True
```

---

**File: `app/crud/crud_tag.py`**

```python
from sqlalchemy.orm import Session
from typing import List, Optional
from app.models.tag import Tag
from app.schemas.tag import TagCreate


def get_tag(db: Session, tag_id: int) -> Optional[Tag]:
    """Get tag by ID"""
    return db.query(Tag).filter(Tag.id == tag_id).first()


def get_tag_by_name(db: Session, name: str) -> Optional[Tag]:
    """Get tag by name"""
    return db.query(Tag).filter(Tag.name == name).first()


def get_tags(db: Session, skip: int = 0, limit: int = 100) -> List[Tag]:
    """Get all tags"""
    return db.query(Tag).offset(skip).limit(limit).all()


def create_tag(db: Session, tag: TagCreate) -> Tag:
    """Create new tag"""
    db_tag = Tag(**tag.model_dump())
    db.add(db_tag)
    db.commit()
    db.refresh(db_tag)
    return db_tag


def delete_tag(db: Session, tag_id: int) -> bool:
    """Delete tag"""
    db_tag = get_tag(db, tag_id)
    if not db_tag:
        return False
    
    db.delete(db_tag)
    db.commit()
    return True
```

---

## Part 8: Tasks for You

### Task 1: Add Category Model (One-to-Many)

Create a Category model where:
- One category has many todos
- Each todo belongs to one category

**Requirements:**
1. Create `models/category.py`
2. Add foreign key to Todo
3. Create CRUD operations
4. Create API endpoints

<details>
<summary>Hint</summary>

```python
# models/category.py
class Category(Base):
    __tablename__ = "categories"
    id = Column(Integer, primary_key=True)
    name = Column(String(50), unique=True)
    todos = relationship("Todo", back_populates="category")

# Update models/todo.py
class Todo(Base):
    # ... existing fields ...
    category_id = Column(Integer, ForeignKey("categories.id"))
    category = relationship("Category", back_populates="todos")
```
</details>

---

### Task 2: Add Comments (One-to-Many)

Add comments to todos:
- One todo has many comments
- Each comment belongs to one todo and one user

<details>
<summary>Hint</summary>

```python
class Comment(Base):
    __tablename__ = "comments"
    id = Column(Integer, primary_key=True)
    text = Column(String(500))
    todo_id = Column(Integer, ForeignKey("todos.id"))
    user_id = Column(Integer, ForeignKey("users.id"))
    
    todo = relationship("Todo", back_populates="comments")
    author = relationship("User")
```
</details>

---

### Task 3: Optimize Queries

Add indexes and optimize a slow query:

```python
# Slow query - fix this
def get_user_incomplete_todos(db: Session, user_id: int):
    todos = db.query(Todo).all()  # Loads everything!
    return [t for t in todos if t.user_id == user_id and not t.completed]
```

<details>
<summary>Solution</summary>

```python
# Add composite index to model
class Todo(Base):
    # ... existing columns ...
    __table_args__ = (
        Index('ix_user_completed', 'user_id', 'completed'),
    )

# Optimized query
def get_user_incomplete_todos(db: Session, user_id: int):
    return db.query(Todo).filter(
        Todo.user_id == user_id,
        Todo.completed == False
    ).all()
```
</details>

---

## ✅ Week 6 Checklist

- [ ] Understand one-to-many relationships
- [ ] Understand many-to-many relationships
- [ ] Created User model
- [ ] Updated Todo model with foreign key
- [ ] Created Tag model
- [ ] Created association table
- [ ] Installed and configured Alembic
- [ ] Created initial migration
- [ ] Applied migration
- [ ] Understand indexes
- [ ] Understand transactions
- [ ] Understand N+1 problem
- [ ] Know when to use eager loading
- [ ] Completed tasks

---

## 🎓 Knowledge Check

1. **What's the difference between one-to-many and many-to-many?**
2. **What is a foreign key?**
3. **Why do we need an association table for many-to-many?**
4. **What problem does Alembic solve?**
5. **What is the N+1 query problem?**
6. **When should you add an index?**
7. **What are ACID properties?**

<details>
<summary>Answers</summary>

1. One-to-many: One parent, many children (User → Todos). Many-to-many: Both sides can have many (Todos ↔ Tags)
2. Column that references another table's primary key
3. To store the relationship pairs (which todo has which tags)
4. Tracks database schema changes as version-controlled migrations
5. One query to get items, N queries to get related data (should be 1 query with JOIN)
6. Columns in WHERE/JOIN clauses, foreign keys, frequently searched columns
7. Atomicity, Consistency, Isolation, Durability - guarantees for transactions
</details>

---

## 🎉 Congratulations!

You now understand:
- ✅ Database relationships (one-to-many, many-to-many)
- ✅ Foreign keys and referential integrity
- ✅ Database migrations with Alembic
- ✅ Query optimization and indexes
- ✅ Transactions and ACID
- ✅ Complex queries with joins

**You can now build production-grade applications with complex data models!** 🚀

---

## 📚 Week 7 Preview

**Next: Authentication & Security**

- User registration and login
- Password hashing
- JWT tokens
- Protected routes
- Authorization (permissions)
- Security best practices

---

**Ready for Week 7? Say: "I completed Week 6, ready for Week 7!"**

Ask any questions! 😊

---

**Progress**: Week 6 of 14 ⭐⭐⭐⭐⭐⭐
**Next Topic**: Authentication & Security
**Status**: You're building real, complex applications now! 💪