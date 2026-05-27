# KT — Phase 5: Service Layer + Repository Pattern

## 1. The problem with our current code

Open any router file right now — `vault/app/routers/notes.py`. One function does everything:

```python
@router.post("")
def create_note(note: NoteCreate, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    db_note = Note(user_id=current_user.id, title=note.title, body=note.body)  # ← DB object creation
    db.add(db_note)       # ← DB operation
    db.commit()           # ← DB operation
    db.refresh(db_note)   # ← DB operation
    return db_note        # ← HTTP response
```

This single function is doing three completely different jobs:
1. **HTTP handling** — receiving a request, returning a response
2. **Business logic** — deciding what to do (create a note for this user)
3. **Database operations** — actually talking to the DB

This is called **mixing concerns**. It works for a small app but becomes a problem as the app grows.

---

## 2. Why mixing concerns is a problem

### Problem 1 — Hard to test

To test `create_note`, you need a real HTTP request AND a real database running.
You cannot test the business logic alone.

In a real team, developers write unit tests for business logic — fast tests
that run without a database. Our current structure makes this impossible.

### Problem 2 — Hard to reuse

Imagine you want to create a note from two places:
- `POST /notes` (HTTP API)
- A scheduled job that auto-creates daily notes
- A CLI admin tool

With the current structure, you'd have to copy-paste the DB code everywhere.
If the logic changes, you update it in 3 places — and miss one.

### Problem 3 — Hard to read

When a new developer joins the team and reads `routers/notes.py`, they see
HTTP + business logic + DB all tangled together. Hard to understand quickly.

---

## 3. The solution — Layered Architecture

Split responsibilities into three distinct layers:

```
┌─────────────────────────────────────┐
│           ROUTER LAYER              │  HTTP only — request in, response out
│   routers/notes.py                  │  Knows nothing about DB
└─────────────────┬───────────────────┘
                  │ calls
┌─────────────────▼───────────────────┐
│           SERVICE LAYER             │  Business logic only
│   services/note_service.py          │  Knows nothing about HTTP
└─────────────────┬───────────────────┘
                  │ calls
┌─────────────────▼───────────────────┐
│        REPOSITORY LAYER             │  Database only — queries only
│   repositories/note_repository.py   │  Knows nothing about business logic
└─────────────────────────────────────┘
```

Each layer only talks to the layer directly below it.
Each layer has one job and one job only.

---

## 4. What each layer does — with examples

### Router layer (what we have now, just slimmed down)

```python
@router.post("")
def create_note(note: NoteCreate, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    return note_service.create(db, user_id=current_user.id, title=note.title, body=note.body)
```

That's it. The router just calls the service and returns the result.
No DB code. No business decisions. Just HTTP in → service call → HTTP out.

### Service layer (new)

```python
# services/note_service.py
def create(db, user_id, title, body):
    # Business logic lives here:
    # - validate title is not empty
    # - apply any business rules
    # - call repository to save
    return note_repo.create(db, user_id=user_id, title=title, body=body)
```

Business logic only. No `@router`, no HTTP status codes, no `Depends`.
Could be called from an HTTP request, a CLI tool, a test — doesn't matter.

### Repository layer (new)

```python
# repositories/note_repository.py
def create(db, user_id, title, body):
    db_note = Note(user_id=user_id, title=title, body=body)
    db.add(db_note)
    db.commit()
    db.refresh(db_note)
    return db_note
```

DB code only. No business logic. No HTTP. Just talking to the database.
If we switch from PostgreSQL to MongoDB tomorrow, only this file changes.

---

## 5. The real-world analogy

Think of a restaurant:

| Layer | Restaurant equivalent |
|---|---|
| Router | Waiter — takes the order from customer, brings food back |
| Service | Chef — decides how to prepare the dish, applies the recipe |
| Repository | Kitchen equipment — actually executes the cooking (DB) |

The waiter doesn't cook. The chef doesn't serve. Each person has one job.

---

## 6. How our file structure changes

### Before Phase 5
```
vault/app/
├── routers/
│   ├── notes.py       ← HTTP + business logic + DB mixed together
│   ├── passwords.py   ← same problem
│   └── users.py       ← same problem
```

### After Phase 5
```
vault/app/
├── routers/
│   ├── notes.py       ← HTTP only (thin layer, ~5 lines per endpoint)
│   ├── passwords.py
│   └── users.py
├── services/
│   ├── note_service.py      ← business logic for notes
│   ├── password_service.py  ← business logic for passwords
│   └── user_service.py      ← business logic for users
└── repositories/
    ├── note_repository.py      ← DB queries for notes
    ├── password_repository.py  ← DB queries for passwords
    └── user_repository.py      ← DB queries for users
```

---

## 7. What actually changes in the code

The behaviour of the API does not change at all. Same endpoints, same
responses, same business logic. We are only reorganising where the code
lives — this is called **refactoring**.

Before:
```python
# routers/notes.py — does everything
def list_notes(db, current_user):
    return db.query(Note).filter(Note.user_id == current_user.id).all()
```

After:
```python
# routers/notes.py — only HTTP
def list_notes(db, current_user):
    return note_service.list_for_user(db, user_id=current_user.id)

# services/note_service.py — business logic
def list_for_user(db, user_id):
    return note_repo.get_by_user(db, user_id=user_id)

# repositories/note_repository.py — DB only
def get_by_user(db, user_id):
    return db.query(Note).filter(Note.user_id == user_id).all()
```

Same result. Three times more files. But each file is small, focused,
and independently understandable.

---

## 8. Is this overkill for a small app?

Honestly — yes, for this app specifically it is extra work with limited
immediate benefit. But the reason we implement it is:

1. **This is how real production codebases are structured.** Every FastAPI
   codebase at a real company uses this pattern (or something similar).

2. **Phase 9 (Keycloak) and Phase 12 (CI/CD) assume this structure.**
   Tests in Phase 12 will test the service layer directly without HTTP.

3. **You will recognise this pattern in every new codebase you join.**
   Learning it here means you'll understand it everywhere.

---

## 9. What we will implement in Phase 5

Step 1 — Create `repositories/` with one repository per model:
- `note_repository.py` — all Note DB queries
- `password_repository.py` — all PasswordEntry DB queries
- `user_repository.py` — all User DB queries

Step 2 — Create `services/` with one service per domain:
- `note_service.py` — note business logic
- `password_service.py` — password business logic
- `user_service.py` — user business logic

Step 3 — Slim down `routers/` — each route becomes a 1-2 line call to
the service.

Step 4 — Verify: restart the server, run the same curl commands,
everything works identically.

---

## 10. Summary

| | Before | After |
|---|---|---|
| Router | HTTP + business logic + DB | HTTP only |
| Service | Does not exist | Business logic only |
| Repository | Does not exist | DB queries only |
| API behaviour | Works | Identical — nothing changes externally |
| Code quality | Mixed concerns | Each file has one responsibility |
| Testability | Needs full stack | Services testable in isolation |
