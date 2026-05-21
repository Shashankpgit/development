# KT — Project Structure

---

## What is this?

This document explains why we organize the project the way we do, what each folder is responsible for, and what happens if you don't follow a structure.

---

## Why structure matters at all

Imagine you join a new company. On your first day, you clone their repo and see this:

```
project/
├── utils.py
├── db.py
├── routes.py
├── helpers.py
├── stuff.py
├── models.py
├── main.py
└── misc.py
```

Every file is at the root. There are 8 files now. In 6 months there are 80. Nobody knows where anything is. You want to change how users are fetched from the database — do you look in `db.py`? `utils.py`? `helpers.py`? `misc.py`?

This is called a **flat structure** and it becomes unmanageable fast.

A good project structure solves one problem: **a new person (or future you) should be able to look at the folder and know exactly where to find anything.**

---

## The structure we are using

```
development/                     ← git repository root
│
├── vault/                       ← the entire application lives here
│   ├── app/                     ← application source code
│   │   ├── main.py
│   │   ├── config.py
│   │   ├── database.py
│   │   ├── models/
│   │   ├── schemas/
│   │   ├── routers/
│   │   ├── services/            (added in Phase 5)
│   │   └── repositories/        (added in Phase 5)
│   ├── tests/
│   ├── .env
│   ├── .env.example
│   └── requirements.txt
│
├── docs/                        ← planning docs and KT documents
├── claude-instructions/         ← Claude's own playbooks
├── goal.md
├── .gitignore
└── README.md
```

---

## What each folder does — and why it exists

---

### `vault/`

The application is isolated in its own folder. This means the repo root can hold other things — docs, instructions, future scripts — without them being mixed into the application code.

Think of it like a workspace. The workspace (repo root) holds different projects. One of those projects is `vault/`. Another could be `vault-frontend/` or `infra/` in the future — each in its own folder, each independently runnable.

**If you deleted `vault/` nothing else would break. If you deleted `docs/` the app still runs.**
That separation is the goal.

---

### `vault/app/`

All runnable Python source code lives here. This is the application itself.

The name `app` is a Python convention for FastAPI projects. When you run:
```bash
uvicorn app.main:app
```
The first `app` refers to this folder. Python needs to find `app/main.py` and inside it an object also called `app`.

---

### `vault/app/main.py`

The **entry point**. This is the first file uvicorn reads when you start the server.

Its only responsibilities:
- Create the FastAPI app object
- Register all routers (attach routes to the app)
- Add middleware (CORS, logging, auth — added in later phases)
- Connect to the database on startup

It does NOT contain any business logic. It is the assembly point — it pulls everything else together.

Real-world analogy: `main.py` is like the reception desk of a company. It doesn't do the actual work — it receives requests and directs them to the right department.

---

### `vault/app/config.py`

Reads environment variables from `.env` and exposes them as Python variables.

Why a dedicated file for this? Because every part of the app needs config (database URL, secret key, etc.). If each file reads from `os.getenv()` directly, you have the same string `"DATABASE_URL"` scattered across 15 files. If the name ever changes, you hunt through every file.

With `config.py`, there is one place where env vars are read. Everything else imports from there:
```python
from app.config import DATABASE_URL
```

---

### `vault/app/database.py`

Everything related to connecting to the database — the engine, the session factory, the base class for models.

This is separate from `config.py` (which just reads env vars) and from `models/` (which defines tables). The database file handles the *connection itself*.

Think of it as the plumbing — it sets up the pipe between your application and the database. The models define what data looks like. The database file defines how the connection is made.

---

### `vault/app/models/`

**SQLAlchemy model classes.** Each file in here corresponds to a database table.

A model is a Python class that maps to a table:
```
class Note(Base):       →   CREATE TABLE notes (
    id = Column(int)    →       id INTEGER PRIMARY KEY,
    title = Column(str) →       title TEXT
                        →   );
```

You write Python. SQLAlchemy writes SQL.

Why a folder instead of one file? Because as the app grows, you end up with User, Note, PasswordEntry, Tag, AuditLog... One file becomes hundreds of lines. A folder lets you have `user.py`, `note.py`, `password_entry.py` — each focused on one thing.

---

### `vault/app/schemas/`

**Pydantic schemas.** These define the shape of data coming IN (request body) and going OUT (response body).

This is one of the most important concepts to understand early: **models and schemas are different things.**

| | SQLAlchemy Model | Pydantic Schema |
|---|---|---|
| Lives in | `models/` | `schemas/` |
| Purpose | Defines the database table | Defines the API request/response shape |
| Used by | SQLAlchemy (for DB operations) | FastAPI (for validation + serialization) |
| Includes | All DB columns including internals | Only what should be visible to the API caller |

Example of why they're separate:

Your `User` model has a `hashed_password` column in the database. You never want to return that in an API response. So `UserResponse` schema simply doesn't include it. The model has it; the schema doesn't. Two different shapes for two different purposes.

---

### `vault/app/routers/`

**FastAPI route handlers.** Each file groups related API endpoints.

Instead of putting every route in `main.py` (which would be hundreds of lines), they are split by feature:
- `routers/health.py` → `GET /health`
- `routers/notes.py` → `GET /notes`, `POST /notes`, `PUT /notes/{id}`, `DELETE /notes/{id}`
- `routers/auth.py` → `POST /auth/register`, `POST /auth/login`

Each router file is focused on one resource. `main.py` just imports and registers them.

---

### `vault/app/services/` *(added in Phase 5)*

**Business logic.** The rules of what the app does.

Right now, the route handlers do everything — receive the request, validate, query the database, return the response. That becomes messy fast. In Phase 5 we extract the actual business logic (the "rules") into service classes.

Example: "A note can only be deleted by its owner" is a business rule. It belongs in a service, not a route handler.

---

### `vault/app/repositories/` *(added in Phase 5)*

**Database access layer.** All raw database queries live here.

Services will call repositories instead of writing SQLAlchemy queries directly. This makes the services easier to test (you can swap the real database for a fake one in tests).

---

### `vault/tests/`

**pytest test files.** Tests live next to the app code but outside `app/` so they don't get packaged or deployed.

Naming convention: `test_*.py` — pytest automatically discovers files matching this pattern.

---

### `vault/.env` and `vault/.env.example`

Already covered in the project setup KT. Quick recap:
- `.env` — your real secrets. Gitignored. Never committed.
- `.env.example` — committed template. Shows what variables exist with empty values.

---

### `vault/requirements.txt`

Lives inside `vault/` because it belongs to the application, not the repo as a whole. If you later add a second sub-project, it would have its own `requirements.txt`.

---

### `docs/`

Every planning document and KT document Claude creates. This is the paper trail of the project — what was built, why, and what you learned.

Lives at the repo root, not inside `vault/`, because documentation is about the project as a whole, not the application code.

---

## The principle behind all of this

**Each folder has one clear responsibility. Files go where they belong, not where they fit.**

When you add a new feature, you know:
- The database table goes in `models/`
- The API shape goes in `schemas/`
- The routes go in `routers/`
- The business rules go in `services/` (Phase 5)
- The database queries go in `repositories/` (Phase 5)

You never ask "where does this go?" — the structure tells you.

---

## What happens without structure

Real example from a production incident at a startup: a developer needed to change how user passwords were hashed. The hashing logic was copied in 4 different files — the registration route, the password reset route, a helper file, and a test. They updated 3 of 4. The 4th silently continued using the old (weaker) algorithm for 6 months before it was caught in a security audit.

If the logic had lived in one place (`services/auth_service.py`), there would have been one file to change.

**Structure is not bureaucracy. Structure prevents bugs.**

---

## Common mistakes

| Mistake | Problem |
|---|---|
| Putting business logic in route handlers | Routes become hundreds of lines, untestable |
| Putting DB queries directly in routes | Same — and you can't swap the DB later |
| One giant `models.py` file | Becomes unreadable as tables multiply |
| Skipping schemas, returning models directly | You accidentally expose internal DB fields (like `hashed_password`) in API responses |
| Mixing app code with docs/scripts at the root | You can't tell what's runnable code and what's reference material |
