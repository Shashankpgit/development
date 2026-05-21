# Phase 2 — Step 2: CRUD for Notes

## What this step covers
Create the `Note` model and full CRUD (Create, Read, Update, Delete) API endpoints for text notes. Notes belong to a user via a foreign key.

---

## Pre-step checklist (Claude must do before any code)

- [ ] Create `docs/005-crud-notes-plan.md` first
- [ ] Explain what CRUD means and why it maps to HTTP methods the way it does

---

## Why this step exists

Notes are the core feature of the Personal Vault. This step introduces:
- Foreign keys (note belongs to a user)
- Full CRUD: all four HTTP methods in one feature
- How to handle "not found" errors (404)
- How pagination starts being necessary even with small data sets

At this phase there is no authentication — anyone can read/create/delete any user's notes. That is intentional. We solve the "can it work" problem before the "who is allowed" problem.

---

## What to implement

### `app/models/note.py`
```
class Note:
    id: int (PK)
    user_id: int (FK → users.id)
    title: str (not null, max 200 chars)
    body: str (nullable — blank note is valid)
    created_at: datetime
    updated_at: datetime
```

### `app/schemas/note.py`
- `NoteCreate`: `user_id`, `title`, `body`
- `NoteUpdate`: `title`, `body` (both optional — partial update)
- `NoteResponse`: `id`, `user_id`, `title`, `body`, `created_at`, `updated_at`

### `app/routers/notes.py`
| Method | Path | Action |
|---|---|---|
| POST | /notes | Create a note |
| GET | /notes?user_id=1 | List notes for a user |
| GET | /notes/{note_id} | Get a single note |
| PUT | /notes/{note_id} | Update a note (full or partial) |
| DELETE | /notes/{note_id} | Delete a note |

---

## Concepts to teach during this step

- **Foreign key**: A column in one table that points to a row in another table. user_id in Note points to id in User. This is how relational databases connect data.
- **CRUD → HTTP mapping**: CREATE=POST, READ=GET, UPDATE=PUT/PATCH, DELETE=DELETE — and why
- **Path parameters vs query parameters**: `/notes/5` (path param: which note) vs `/notes?user_id=1` (query param: filter)
- **404 Not Found**: What to return when a note with that ID doesn't exist, and why 500 is wrong here
- **`updated_at` with `onupdate`**: How SQLAlchemy automatically sets this column when a row is modified
- **Relationship**: Briefly show `relationship("User")` — how SQLAlchemy can load the related user object automatically

---

## Teaching moment: REST conventions

Explain the pattern once here:
- The URL identifies the **resource** (`/notes`, `/notes/5`)
- The HTTP method says **what to do** with it (GET=read, POST=create, PUT=replace, DELETE=remove)
- This is REST. It's a convention, not a law, but a very widely followed one.

---

## What NOT to do in this step

- Do NOT guard endpoints by logged-in user yet (that's Phase 4)
- Do NOT add tags or categories yet (keep it simple)
- Do NOT add search yet (Phase 2 Step 3 or later)
- Do NOT build frontend for this yet

---

## File changes

| File | Action |
|---|---|
| `app/models/note.py` | Create |
| `app/models/__init__.py` | Modify — import Note |
| `app/schemas/note.py` | Create |
| `app/routers/notes.py` | Create |
| `app/main.py` | Modify — include notes router |

---

## Success criteria

Test via Swagger UI (`/docs`):
1. `POST /notes` with `{"user_id": 1, "title": "My first note", "body": "Hello Vault"}` → 201 response
2. `GET /notes?user_id=1` → returns list with the note
3. `GET /notes/1` → returns the single note
4. `PUT /notes/1` with `{"title": "Updated title"}` → returns updated note, `updated_at` changed
5. `DELETE /notes/1` → 204 no content
6. `GET /notes/1` after delete → 404 Not Found
