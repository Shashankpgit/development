# Phase 5 — Step 1: Service Layer

## What this step covers
Refactor the codebase by extracting business logic from route handlers into a dedicated service layer. No new features — this is an architecture improvement.

---

## Pre-step checklist (Claude must do before any code)

- [ ] Create `docs/011-service-layer-plan.md` first
- [ ] Explain the problem that exists NOW in the codebase that the service layer solves

---

## Why this step exists

By the end of Phase 4, the route handlers are doing too much:
- Parsing the request
- Validating ownership
- Running business logic
- Querying the database directly
- Building the response

This is the "fat controller" anti-pattern. It makes code hard to test, hard to reuse, and hard to understand. Real engineering teams always separate these concerns.

The service layer sits between the route handler (HTTP concerns) and the database (storage concerns). It owns the business rules.

---

## Current problem (show before refactoring)

Show the current `notes.py` router — the route function directly does:
```python
@router.post("/notes")
def create_note(note: NoteCreate, db: Session = Depends(get_db), current_user = Depends(get_current_user)):
    db_note = Note(user_id=current_user.id, title=note.title, body=note.body)
    db.add(db_note)
    db.commit()
    db.refresh(db_note)
    return db_note
```

The route knows about database internals. This is the problem.

---

## After refactoring

```python
# router
@router.post("/notes")
def create_note(note: NoteCreate, current_user = Depends(get_current_user), note_service = Depends(get_note_service)):
    return note_service.create_note(user_id=current_user.id, data=note)

# service
class NoteService:
    def create_note(self, user_id: int, data: NoteCreate) -> Note:
        # business logic lives here
```

The route handler only handles HTTP concerns. The service handles business logic.

---

## What to implement

### `app/services/note_service.py`
- `NoteService` class
- Methods: `create_note`, `get_notes_for_user`, `get_note_by_id`, `update_note`, `delete_note`
- All ownership checks move here (not in the router)

### `app/services/password_service.py`
- `PasswordService` class
- Same pattern as NoteService

### `app/services/auth_service.py`
- `AuthService` class
- Methods: `register_user`, `authenticate_user`, `create_token`

### Update routers
- Routers become thin: parse request → call service → return response
- No direct DB access from routers

---

## Concepts to teach during this step

- **Separation of Concerns (SoC)**: Each layer has one job. Router: handle HTTP. Service: handle business logic. Database: handle storage.

- **Why testability matters**: With a service layer, you can unit test `NoteService.create_note()` without running a web server. Without it, you have to spin up HTTP to test business logic.

- **Dependency Injection for services**: Services should receive their dependencies (DB session) from outside — not create them internally. This makes them testable and flexible.

- **Fat controller anti-pattern**: The problem we're solving. Named so you can recognize it and name it in a code review.

- **Refactoring is not a luxury**: This is how real codebases evolve. You write it first to make it work, then refactor to make it maintainable. This step simulates that real cycle.

---

## Teaching moment: Before and after

Show a diff of the router file before and after. The router after should be visibly simpler — the complexity moved to the service. "The complexity didn't disappear, it just moved to where it belongs."

---

## What NOT to do in this step

- Do NOT change any API behavior — all endpoints should work identically before and after
- Do NOT add the Repository pattern yet (that's Phase 5 Step 2)
- Do NOT add new features
- Do NOT change the database schema

---

## File changes

| File | Action |
|---|---|
| `app/services/__init__.py` | Create |
| `app/services/note_service.py` | Create |
| `app/services/password_service.py` | Create |
| `app/services/auth_service.py` | Create |
| `app/routers/notes.py` | Modify — thin down, call service |
| `app/routers/passwords.py` | Modify — thin down, call service |
| `app/routers/auth.py` | Modify — thin down, call service |

---

## Success criteria

1. All existing tests (manual via Swagger) still pass identically
2. No route handler directly imports `Session` or makes DB calls
3. Service functions are individually callable (testable in isolation)
4. `git diff` shows moved logic, no behavior change
