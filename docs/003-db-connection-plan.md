# 003 — Database Connection (PostgreSQL via Docker)

---

## Part 1: What we are doing

**Goal:** Start a PostgreSQL container and connect the FastAPI app to it. The `/health` endpoint will confirm the database is reachable.

### Setup
- PostgreSQL runs inside a Docker container, port `5432` exposed to localhost
- FastAPI app runs locally and connects to `localhost:5432`

### Files being created / modified
```
vault/app/database.py         ← new: SQLAlchemy engine + session setup
vault/app/config.py           ← modified: add DB config variables
vault/app/routers/health.py   ← modified: verify DB connection in response
vault/app/main.py             ← modified: initialise DB tables on startup
vault/.env                    ← modified: PostgreSQL DATABASE_URL
vault/.env.example            ← modified: PostgreSQL URL template
vault/requirements.txt        ← modified: add psycopg2-binary
```

### Steps
1. Start PostgreSQL in Docker
2. Add `psycopg2-binary` to `requirements.txt` and install it
3. Create `app/database.py`
4. Update `app/config.py`
5. Update `.env` with real PostgreSQL credentials
6. Update `app/main.py` to create tables on startup
7. Update `GET /health` to report database status
8. Test: start server, call `/health`, see `"database": "connected"`

### What is NOT done in this step
- No tables yet (just the connection layer)
- No models
- No queries

### API change
`GET /health` response gains a new field:
```json
{
  "status": "ok",
  "version": "0.1.0",
  "database": "connected"
}
```
See: `docs/api/health.md`

---

## Part 2: Concepts / KT

### Why PostgreSQL over SQLite
SQLite stores everything in a single file on disk. It works for one person on one machine. It cannot handle multiple users writing at the same time (it locks the whole file). PostgreSQL is a proper database server — it manages concurrent connections, has user permissions, supports large data, and is what every production application uses.

### Docker for just the database
We're not Dockerizing the whole app yet — that's Phase 6. Right now Docker is just a clean way to run PostgreSQL without installing it on your machine. The app runs locally and connects to the container over `localhost:5432`.

```
Your machine
├── FastAPI app (local, port 8000)
└── Docker
    └── PostgreSQL container (port 5432 → exposed to localhost)
```

### DATABASE_URL format
SQLAlchemy uses a connection string called a URL to know how to connect:

```
postgresql://username:password@host:port/database_name
```

Real example:
```
postgresql://vault_user:secret@localhost:5432/vault
```

Breaking it down:
- `postgresql://` — the database type (tells SQLAlchemy which driver to use)
- `vault_user:secret` — credentials
- `localhost:5432` — where the database is (host:port)
- `/vault` — which database to connect to (one PostgreSQL server can have many databases)

### psycopg2 — the PostgreSQL driver
SQLAlchemy is an ORM — it writes SQL for you. But it doesn't know *how* to talk to PostgreSQL over the network. That's `psycopg2`'s job — it's the low-level driver that actually makes the connection.

Think of it like this:
- SQLAlchemy = translator (Python → SQL)
- psycopg2 = the wire (SQL → PostgreSQL server)

Without `psycopg2`, SQLAlchemy sees `postgresql://` in the URL and says "I don't know how to connect to this." You'll see this exact error in the deliberate mistake below.

### SQLAlchemy engine vs session
Two separate concepts that are often confused:

**Engine** — created once when the app starts. It manages a pool of database connections. Think of it as the phone line between your app and the database — it's always open, ready to use.

**Session** — a short-lived conversation with the database. One session per HTTP request. It opens when a request comes in, you run queries through it, and it closes when the request is done. If something goes wrong mid-request, the session can roll back everything — like "undo" for database changes.

### `get_db()` dependency
FastAPI has a built-in dependency injection system. `get_db()` is a function that yields a database session to any route that needs it:

```python
def get_db():
    db = SessionLocal()
    try:
        yield db        # hand the session to the route
    finally:
        db.close()      # always close it, even if the route crashed
```

Any route that declares `db: Session = Depends(get_db)` automatically gets a fresh session for that request. FastAPI handles calling `get_db()` and closing the session after.

### `create_all()` — table creation shortcut
`Base.metadata.create_all(bind=engine)` looks at all SQLAlchemy models and creates their tables in the database if they don't exist yet. It's a development shortcut — fast and simple. In Phase 5 we'll replace this with Alembic, which tracks schema changes properly (like git for your database).
