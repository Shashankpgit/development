# Phase 2 — Step 1: User Model

## What this step covers
Define the `User` SQLAlchemy model and the matching Pydantic schemas. No authentication yet — just the table and the ability to create users via a plain API (password stored in plaintext temporarily, then hashed immediately after in step 4.2).

---

## Pre-step checklist (Claude must do before any code)

- [ ] Create `docs/004-user-model-plan.md` first
- [ ] Explain WHY we create the User model before notes or passwords (users own everything else)

---

## Why this step exists

Every piece of data in the Vault belongs to a user. Before we can create notes or passwords, we need a User table to attach them to. This introduces:
- SQLAlchemy model classes (Python class → database table)
- Pydantic schemas (separate from models — for request/response shapes)
- The model/schema split: a critical architecture pattern

---

## What to implement

### `app/models/user.py`
```python
class User:
    id: int (primary key, auto-increment)
    username: str (unique, not null, max 50 chars)
    hashed_password: str (not null)
    created_at: datetime (server default = now)
```

### `app/schemas/user.py`
- `UserCreate` schema: `username`, `password` (plain, for input)
- `UserResponse` schema: `id`, `username`, `created_at` (NEVER return hashed_password)

### `app/routers/users.py`
- `POST /users` — create a user (store password as-is for now, a comment marks it as TODO: hash)
- `GET /users` — list all users (dev-only endpoint; mark it as to be removed before auth phase)

---

## Concepts to teach during this step

- **SQLAlchemy model**: Python class that maps 1:1 to a database table
- **Column types**: Integer, String, DateTime — how Python types map to SQL types
- **Primary key + auto-increment**: Why every table needs a unique identifier
- **Unique constraint**: What `unique=True` does at the DB level
- **Pydantic schema vs SQLAlchemy model**: Two different things that look similar. Model = DB shape. Schema = API input/output shape. This split is intentional and important.
- **Why never return hashed_password**: A response schema that excludes sensitive fields is a security pattern, not an afterthought
- **`POST` vs `GET`**: Creating resources uses POST; reading uses GET

---

## Important teaching moment

Show the user:
1. After `POST /users`, open `sqlite3 vault.db` and run `SELECT * FROM users;`
2. See the row appear in the database
3. Connect this to: "your API call → SQLAlchemy → SQL → database file on disk"

This is the first time they see the full chain working end-to-end.

---

## What NOT to do in this step

- Do NOT hash passwords yet (that comes in Phase 4 when auth is added; add a clear TODO comment)
- Do NOT add authentication
- Do NOT relate users to notes yet (foreign keys come in Phase 2 Steps 2 and 3)
- Do NOT add login

---

## File changes

| File | Action |
|---|---|
| `app/models/user.py` | Create |
| `app/models/__init__.py` | Modify — import User so `create_all` finds it |
| `app/schemas/user.py` | Create |
| `app/routers/users.py` | Create |
| `app/main.py` | Modify — include users router |

---

## Success criteria

```bash
# POST /users with {"username": "bob", "password": "secret123"}
# Returns {"id": 1, "username": "bob", "created_at": "..."}
# sqlite3 vault.db: SELECT * FROM users; → shows the row
# hashed_password is NOT in the response
```
