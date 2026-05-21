# Phase 5 — Step 2: Repository Pattern

## What this step covers
Extract all direct database access (SQLAlchemy queries) from services into a Repository layer. Services will call repositories; repositories will talk to SQLAlchemy.

---

## Pre-step checklist (Claude must do before any code)

- [ ] Create `docs/012-repository-pattern-plan.md` first
- [ ] Explain why the service layer still has a problem after Phase 5 Step 1

---

## Why this step exists

After Phase 5 Step 1, the services still contain raw SQLAlchemy queries:
```python
# In NoteService
note = db.query(Note).filter(Note.id == note_id).first()
```

This means:
- If you swap SQLAlchemy for something else (or switch databases), services must change
- Unit testing services requires a real database (or a complex SQLAlchemy mock)
- Database-specific logic bleeds into business logic

The Repository pattern solves this by making services talk to an abstract interface (`NoteRepository`) instead of directly to the database.

---

## What to implement

### `app/repositories/note_repository.py`
```python
class NoteRepository:
    def __init__(self, db: Session): ...
    def create(self, note: Note) -> Note: ...
    def get_by_id(self, note_id: int) -> Note | None: ...
    def get_by_user_id(self, user_id: int) -> list[Note]: ...
    def update(self, note: Note) -> Note: ...
    def delete(self, note_id: int) -> None: ...
```

### `app/repositories/password_repository.py`
Same pattern for PasswordEntry.

### `app/repositories/user_repository.py`
```python
class UserRepository:
    def get_by_username(self, username: str) -> User | None: ...
    def create(self, user: User) -> User: ...
```

### Update services
- Services receive repository via dependency injection (not the `db` session directly)
- Services call `self.note_repo.get_by_id(id)` instead of `db.query(Note)...`

---

## Concepts to teach during this step

- **Repository pattern**: An abstraction layer between business logic and data storage. The service asks "give me note with id=5" — the repository knows HOW to get it (SQL, file, cache, etc.).

- **Why swap-ability matters**: You might start with SQLite, move to PostgreSQL, later add Redis cache on top. If your services talk to a repository interface, swapping the implementation is isolated.

- **Dependency injection for repositories**: Services receive `NoteRepository` from outside (via `Depends()`), not create it internally. This is the same principle as receiving `db` session via Depends().

- **Unit testing with repos**: With repositories injected, you can unit test `NoteService` by passing a `FakeNoteRepository` that returns mock data — no database needed. (Don't implement tests now, but establish the design that enables them.)

- **When NOT to use repositories**: Acknowledge the tradeoff — for small projects, this is over-engineering. You add it here because: (a) you'll need it when the project scales, and (b) learning the pattern on a small codebase is easier than on a big one.

---

## Teaching moment: The three-layer architecture

Draw this clearly:

```
HTTP Request
     ↓
  Router       ← HTTP: parse request, return response
     ↓
  Service      ← Business logic: rules, validation, orchestration  
     ↓
  Repository   ← Data access: SQL queries, ORM operations
     ↓
  Database
```

"Every production application you've heard of — Google, Netflix, your bank — has some version of this. The names differ, but the layering exists."

---

## What NOT to do in this step

- Do NOT change any API behavior
- Do NOT add the Alembic migration system yet (save for a future improvement)
- Do NOT build unit tests yet (establish the design that enables them)
- Do NOT add new endpoints

---

## File changes

| File | Action |
|---|---|
| `app/repositories/__init__.py` | Create |
| `app/repositories/note_repository.py` | Create |
| `app/repositories/password_repository.py` | Create |
| `app/repositories/user_repository.py` | Create |
| `app/services/note_service.py` | Modify — use NoteRepository |
| `app/services/password_service.py` | Modify — use PasswordRepository |
| `app/services/auth_service.py` | Modify — use UserRepository |

---

## Success criteria

1. All existing API endpoints work identically
2. No raw `db.query(Model)` calls anywhere in services
3. Repositories contain all SQLAlchemy-specific code
4. Services can be instantiated with a fake repository for testing (verify the design, not the test)
