# 004 — User Model

---

## Part 1: What we are doing

**Goal:** Create the `User` database table and the API endpoints to create and fetch users. No authentication yet — passwords stored as plaintext with a clear TODO marker.

### Files being created / modified
```
vault/app/models/user.py        ← new: SQLAlchemy User model (the table)
vault/app/schemas/user.py       ← new: Pydantic schemas (request/response shapes)
vault/app/routers/users.py      ← new: POST /users, GET /users/{id}
vault/app/models/__init__.py    ← modified: import User so create_all finds it
vault/app/main.py               ← modified: register users router
docs/api/users.md               ← updated: full endpoint documentation
```

### The table being created
```
users
├── id             INTEGER, primary key, auto-increment
├── username       VARCHAR(50), unique, not null
├── hashed_password TEXT, not null
└── created_at     TIMESTAMP, default = now
```

### Steps
1. Create `app/models/user.py`
2. Import User in `app/models/__init__.py`
3. Create `app/schemas/user.py`
4. Create `app/routers/users.py`
5. Register router in `app/main.py`
6. Start server → verify table is created in PostgreSQL
7. Test via Swagger, curl, and Postman

### What is NOT done in this step
- No password hashing (plaintext for now, TODO comment added — fixed in Phase 4)
- No login
- No authentication
- No relationship to notes or passwords yet

---

## Part 2: Concepts / KT

### SQLAlchemy model
A Python class that maps directly to a database table. You define columns as class attributes using SQLAlchemy's `Column` type. When `create_all()` runs at startup, SQLAlchemy reads these class definitions and generates the `CREATE TABLE` SQL automatically.

```python
class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True)
    username = Column(String(50), unique=True, nullable=False)
```

SQLAlchemy generates:
```sql
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL
);
```

You write Python. SQLAlchemy writes SQL.

### Pydantic schema vs SQLAlchemy model
Two different things that look similar but serve different purposes:

| | SQLAlchemy Model | Pydantic Schema |
|---|---|---|
| Purpose | Defines the database table | Defines the API input/output shape |
| Used by | SQLAlchemy (DB operations) | FastAPI (request validation + response serialisation) |
| Location | `app/models/` | `app/schemas/` |

Why keep them separate? The `User` model has a `hashed_password` column. You never want to return that in an API response. So `UserResponse` schema simply doesn't include it. Two shapes for two different contexts.

### `model_config = ConfigDict(from_attributes=True)`
Pydantic v2 needs this on response schemas to read data from SQLAlchemy model objects. Without it, Pydantic wouldn't know how to convert a SQLAlchemy `User` object into a JSON-serialisable dict.

### `nullable=False` vs `unique=True`
- `nullable=False` → the column must always have a value. Inserting a row without this column fails.
- `unique=True` → no two rows can have the same value in this column. Trying to create two users with the same username fails with an `IntegrityError`.

### `server_default=func.now()`
Instead of setting `created_at` in Python, we tell the database to set it automatically at insert time using the database's own clock. More reliable than Python time (no timezone confusion between app server and DB server).

### Why plaintext passwords now
Hashing is a Phase 4 concern — it belongs with JWT and authentication. Introducing it now would mix two concepts at once. A `TODO` comment marks it clearly. This is how real teams work — ship the minimum, mark the gap, fix it in the right phase.
