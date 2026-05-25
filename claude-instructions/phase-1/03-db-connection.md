# Phase 1 — Step 3: Database Connection

## What this step covers
Connect the application to PostgreSQL using SQLAlchemy. Verify the connection. No tables yet — just the connection layer.

---

## Pre-step checklist (Claude must do before any code)

- [ ] Create `docs/003-db-connection-plan.md` first
- [ ] Explain WHY we connect the database before creating any tables or queries

---

## Why this step exists

Connecting to a database and verifying the connection is a separate concern from defining tables or writing queries. Real engineering teams always establish the connection layer first, then build on top of it. This step:
- Creates the database session factory that every route will use later
- Confirms the database is reachable and accessible
- Introduces SQLAlchemy's session concept (the thing that wraps every DB operation)

Without this step working cleanly, adding models (Step 2.x) will fail in hard-to-debug ways.

---

## What to implement

### `app/database.py`
- Create SQLAlchemy engine pointing to PostgreSQL via `DATABASE_URL`
- Create `SessionLocal` — the session factory
- Create `Base` — the declarative base for all models
- Create `get_db()` — a FastAPI dependency that yields a DB session per request

### `app/main.py` update
- On startup, call `Base.metadata.create_all(bind=engine)` (for now; Alembic replaces this in Phase 5)

### `.env` update
- Add `DATABASE_URL=postgresql://user:password@localhost:5432/vault`

### Verify endpoint: `GET /health` update
- Return `"database": "connected"` if DB session opens successfully

---

## Concepts to teach during this step

- **ORM (Object-Relational Mapper)**: What SQLAlchemy is — you write Python objects, it writes SQL
- **Connection string / DATABASE_URL**: The format `dialect://user:pass@host:port/dbname` — explain each part
- **PostgreSQL**: Why we use a real database from the start instead of a file-based one. Production systems need proper concurrent access, transactions, and constraints.
- **Engine vs Session**: Engine = the connection pool (long-lived). Session = one "conversation" with the DB (short-lived, one per request)
- **`get_db()` dependency**: How FastAPI's dependency injection works — the `yield` pattern
- **`Base.metadata.create_all()`**: What this does (creates tables if they don't exist) and why it's a development shortcut (Alembic is the real answer)
- **Why `.env` for DATABASE_URL**: Never hardcode connection strings — they contain credentials in production

---

## Show in action (teach this)

After implementation, demonstrate:
1. Health endpoint returns `"database": "connected"`
2. Show tables using psql: `\dt` — empty but the connection works
3. Connect this to: "your API call → SQLAlchemy → SQL → PostgreSQL"

---

## What NOT to do in this step

- Do NOT create any model classes yet (that's Phase 2 Step 1)
- Do NOT write any queries yet
- Do NOT add database migrations (Alembic comes in a future phase)

---

## File changes

| File | Action |
|---|---|
| `app/database.py` | Create |
| `app/config.py` | Modify — add DATABASE_URL |
| `app/main.py` | Modify — import database, call create_all on startup |
| `app/routers/health.py` | Modify — test DB connection in response |
| `.env.example` | Modify — add DATABASE_URL= |

---

## Success criteria

```bash
# Start PostgreSQL (docker run postgres or local install)
uvicorn app.main:app --reload
# GET /health returns {"status": "ok", "version": "1.0.0", "database": "connected"}
```

Git: commit with message "feat: connect PostgreSQL database via SQLAlchemy"
