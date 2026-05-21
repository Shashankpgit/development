# Phase 1 — Step 3: Database Connection

## What this step covers
Connect the application to SQLite using SQLAlchemy. Verify the connection. No tables yet — just the connection layer.

---

## Pre-step checklist (Claude must do before any code)

- [ ] Create `docs/003-db-connection-plan.md` first
- [ ] Explain WHY we connect the database before creating any tables or queries

---

## Why this step exists

Connecting to a database and verifying the connection is a separate concern from defining tables or writing queries. Real engineering teams always establish the connection layer first, then build on top of it. This step:
- Creates the database session factory that every route will use later
- Confirms the database file is created and accessible
- Introduces SQLAlchemy's session concept (the thing that wraps every DB operation)

Without this step working cleanly, adding models (Step 2.x) will fail in hard-to-debug ways.

---

## What to implement

### `app/database.py`
- Create SQLAlchemy engine pointing to `vault.db` (SQLite)
- Create `SessionLocal` — the session factory
- Create `Base` — the declarative base for all models
- Create `get_db()` — a FastAPI dependency that yields a DB session per request

### `app/main.py` update
- On startup, call `Base.metadata.create_all(bind=engine)` (for now; Alembic replaces this in Phase 5)

### `.env` update
- Add `DATABASE_URL=sqlite:///./vault.db`

### Verify endpoint: `GET /health` update
- Return `"database": "connected"` if DB session opens successfully

---

## Concepts to teach during this step

- **ORM (Object-Relational Mapper)**: What SQLAlchemy is — you write Python objects, it writes SQL
- **Connection string / DATABASE_URL**: The format `dialect://user:pass@host/dbname` — explain each part
- **SQLite vs PostgreSQL**: Why SQLite is great for learning (file-based, zero setup), and why we'll migrate to PostgreSQL before going to production
- **Engine vs Session**: Engine = the connection pool (long-lived). Session = one "conversation" with the DB (short-lived, one per request)
- **`get_db()` dependency**: How FastAPI's dependency injection works — the `yield` pattern
- **`Base.metadata.create_all()`**: What this does (creates tables if they don't exist) and why it's a development shortcut (Alembic is the real answer)
- **Why `.env` for DATABASE_URL**: Never hardcode connection strings — they contain credentials in production

---

## Show in action (teach this)

After implementation, demonstrate:
1. The `vault.db` file appears in the project root
2. Health endpoint returns `"database": "connected"`
3. Open `vault.db` with `sqlite3 vault.db` or a GUI tool — show it's empty but real

---

## What NOT to do in this step

- Do NOT create any model classes yet (that's Phase 2 Step 1)
- Do NOT write any queries yet
- Do NOT switch to PostgreSQL yet (that comes in Phase 4 when Docker arrives)
- Do NOT add database migrations (Alembic comes in Phase 5)

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
uvicorn app.main:app --reload
# vault.db file appears in project root
# GET /health returns {"status": "ok", "version": "1.0.0", "database": "connected"}
```

Git: commit with message "feat: connect SQLite database via SQLAlchemy"
