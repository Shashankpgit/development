# KT — How the Database Connection Works

---

## The big picture first

There are 4 files involved in connecting to the database. Each one has a single job:

```
.env                 → stores the credentials (username, password, host)
app/config.py        → reads .env and makes credentials available in Python
app/database.py      → uses credentials to create the actual connection
app/main.py          → tells SQLAlchemy to create tables when server starts
```

They form a chain. Each file depends on the one above it.

```
.env
  ↓  (python-dotenv reads it)
config.py
  ↓  (imports DATABASE_URL)
database.py
  ↓  (creates engine + session)
main.py  →  routers  →  your routes
```

---

## Step by step — what each file does

---

### 1. `.env` — the credentials file

```
DATABASE_URL=postgresql://vault_user:vault_pass@localhost:5432/vault
```

This is just a text file. Nothing fancy. It holds sensitive values that should never be committed to git.

Breaking down the URL:

```
postgresql://vault_user:vault_pass@localhost:5432/vault
     │            │          │         │        │     │
     │            │          │         │        │     └── database name
     │            │          │         │        └──────── port
     │            │          │         └───────────────── host
     │            │          └─────────────────────────── password
     │            └────────────────────────────────────── username
     └─────────────────────────────────────────────────── database type
```

**Who created this:** You. It lives on your machine only, gitignored.
**What it does:** Nothing by itself — it's just a file sitting on disk.

---

### 2. `app/config.py` — reads `.env` into Python

```python
from dotenv import load_dotenv
import os

load_dotenv()   # ← reads the .env file and loads each line as an env variable

DATABASE_URL = os.getenv("DATABASE_URL", "")  # ← picks up the value
```

`load_dotenv()` is from the `python-dotenv` library. It reads your `.env` file and registers each `KEY=VALUE` pair as an environment variable in the current process.

`os.getenv("DATABASE_URL")` then reads that environment variable.

**Who created this:** We created it in Phase 1 Step 1.
**What it does:** Makes the credentials available anywhere in the Python code via `from app.config import DATABASE_URL`.

Think of it like this: `.env` is a locked drawer. `config.py` opens the drawer and puts the values on the desk where everyone can see them.

---

### 3. `app/database.py` — creates the actual connection machinery

This is the most important file. Let's go through it line by line:

```python
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker, DeclarativeBase
from app.config import DATABASE_URL
```
Imports SQLAlchemy tools and the URL from config.

---

```python
engine = create_engine(DATABASE_URL)
```

**The engine.** This is the connection pool — a group of open connections to the database that the app can reuse.

Think of the engine like a phone exchange at a company. The exchange is always on. When someone needs to make a call (run a query), they pick up a line (borrow a connection), use it, and put it back. The exchange manages all the lines.

Important: `create_engine()` does NOT connect to the database immediately. It just sets up the machinery. The actual first connection happens when something tries to use the engine.

---

```python
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
```

**The session factory.** `SessionLocal` is not a session — it's a factory that creates sessions. Like a stamp that makes copies.

When you call `SessionLocal()`, you get a new session object.

- `autocommit=False` → changes are not saved automatically. You must explicitly call `db.commit()`. This is intentional — you want control over when data is written.
- `autoflush=False` → SQLAlchemy won't automatically sync pending changes to the DB before queries. More control for you.
- `bind=engine` → every session created by this factory will use your PostgreSQL engine.

---

```python
class Base(DeclarativeBase):
    pass
```

**The model base class.** Every SQLAlchemy model (table) you create in `app/models/` will inherit from this `Base`. This is how SQLAlchemy knows which Python classes represent database tables.

Right now `Base` is empty because we have no models yet. When we create `class Note(Base)` in Phase 2, SQLAlchemy will be able to see it through `Base.metadata`.

---

```python
def get_db():
    db = SessionLocal()   # create a new session
    try:
        yield db          # hand it to whoever asked for it
    finally:
        db.close()        # always close it when done, even if something crashed
```

**The dependency.** This function is used by FastAPI's dependency injection system.

Any route that needs the database will declare `db = Depends(get_db)`. FastAPI will:
1. Call `get_db()`
2. Run your route function with the session
3. After the route returns (or crashes), continue past `yield` and close the session

The `try/finally` guarantees the session is always closed — even if the route crashes halfway through. If you forgot this, connections would pile up and eventually the database would refuse new connections.

---

```python
def check_db_connection() -> bool:
    try:
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        return True
    except Exception:
        return False
```

**The health check helper.** Opens a connection, runs the simplest possible SQL (`SELECT 1` — just returns the number 1, used universally to check if a database is alive), and closes it. Returns `True` if it worked, `False` if anything failed.

Used by `GET /health` to report whether the database is reachable.

---

### 4. `app/main.py` — wires it all together on startup

```python
from app.database import Base, engine

@app.on_event("startup")
async def startup():
    Base.metadata.create_all(bind=engine)
```

When the server starts:
1. `Base.metadata` contains a list of all models that inherit from `Base` (none yet, will have many in Phase 2)
2. `create_all(bind=engine)` looks at each model and creates its table in the database if it doesn't already exist
3. If the table exists, it does nothing (it won't delete data)

---

## The full flow — one request that touches the database

Later in Phase 2, when you call `GET /notes`, here is exactly what happens:

```
Browser / curl
    │
    │  GET /notes
    ▼
uvicorn (receives the HTTP request)
    │
    ▼
FastAPI router (finds the matching route handler)
    │
    ▼
FastAPI calls get_db()
    │  SessionLocal() → new session created
    │  session handed to the route
    ▼
route handler runs:
    db.query(Note).filter(Note.user_id == 1).all()
    │
    ▼
SQLAlchemy translates to SQL:
    SELECT * FROM notes WHERE user_id = 1;
    │
    ▼
psycopg2 sends SQL over the network to PostgreSQL
    │
    ▼
PostgreSQL executes the query, returns rows
    │
    ▼
psycopg2 receives the rows, passes to SQLAlchemy
    │
    ▼
SQLAlchemy converts rows into Python Note objects
    │
    ▼
route handler returns the list
    │
    ▼
FastAPI serialises to JSON
    │
    ▼
Browser receives: [{"id": 1, "title": "My note", ...}]
    │
    ▼
get_db() finally block runs → session closed
```

---

## Why is psycopg2 needed separately?

SQLAlchemy is an ORM — it knows how to translate Python to SQL. But it doesn't know the PostgreSQL network protocol. That's `psycopg2`'s job.

```
Your code
    ↓
SQLAlchemy    ← "I'll write the SQL for you"
    ↓
psycopg2      ← "I'll send it to PostgreSQL and bring back the results"
    ↓
PostgreSQL
```

SQLAlchemy supports many databases (PostgreSQL, MySQL, SQLite, Oracle...). For each one it needs a different driver. For PostgreSQL that driver is psycopg2. When SQLAlchemy sees `postgresql://` in your URL, it looks for psycopg2. If it's not installed, you get:

```
ModuleNotFoundError: No module named 'psycopg2'
```

---

## Summary — who built what

| File | Built by | Purpose |
|---|---|---|
| `.env` | You (on your machine) | Stores real credentials, never committed |
| `.env.example` | Us (committed to git) | Template showing what variables are needed |
| `app/config.py` | Us (Phase 1 Step 1) | Reads `.env`, exposes variables to Python |
| `app/database.py` | Us (Phase 1 Step 3) | Creates engine, session factory, get_db() |
| `app/main.py` | Us (updated Phase 1 Step 3) | Calls create_all on startup |

---

## Common questions

**Q: Why not just put the database URL directly in database.py?**
If you hardcode `postgresql://vault_user:secret@...` in a Python file, it gets committed to git. Anyone with access to the repo (including future teammates, or if the repo becomes public) can see your database password. The `.env` pattern keeps secrets out of code.

**Q: What's the difference between engine and session?**
Engine = long-lived, shared, manages the connection pool. Created once.
Session = short-lived, one per request, tracks changes for that request. Created and destroyed thousands of times a day.

**Q: What happens if the database is down when the server starts?**
`create_engine()` won't fail — it's lazy. But the first actual query will. The health check will return `"database": "unreachable"` and your routes will return 500 errors until the database comes back.
