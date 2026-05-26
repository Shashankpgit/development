# 005 — Notes CRUD

---

## Part 1: What we are doing

**Goal:** Build full CRUD for text notes. A note belongs to a user via a foreign key. No authentication yet — user_id is passed in the request body for now.

### Files being created / modified
```
vault/app/models/note.py        ← new: Note SQLAlchemy model
vault/app/schemas/note.py       ← new: NoteCreate, NoteUpdate, NoteResponse
vault/app/routers/notes.py      ← new: 5 endpoints
vault/app/models/__init__.py    ← modified: import Note
vault/app/main.py               ← modified: register notes router
docs/api/notes.md               ← updated: full endpoint documentation
```

### The table being created
```
notes
├── id          INTEGER, primary key, auto-increment
├── user_id     INTEGER, foreign key → users.id
├── title       VARCHAR(200), not null
├── body        TEXT, nullable
├── created_at  TIMESTAMP, default = now
└── updated_at  TIMESTAMP, default = now, updates on every change
```

### Endpoints
| Method | Path | Action |
|---|---|---|
| `POST` | `/notes` | Create a note |
| `GET` | `/notes?user_id=1` | List notes for a user |
| `GET` | `/notes/{id}` | Get a single note |
| `PUT` | `/notes/{id}` | Update a note |
| `DELETE` | `/notes/{id}` | Delete a note |

### What is NOT done in this step
- No auth guard — any user_id can be passed freely (fixed in Phase 4)
- No tags or search
- No frontend

---

## Part 2: Concepts / KT

### Foreign key
A column that points to the primary key of another table. `notes.user_id` points to `users.id`. This is how relational databases connect data.

```
users table          notes table
id | username        id | user_id | title
1  | bob      ◄───  1  |    1    | "My first note"
2  | alice           2  |    1    | "Second note"
                     3  |    2    | "Alice's note"
```

If you try to create a note with `user_id=99` and no user with `id=99` exists, the database rejects it with a `ForeignKeyViolation` error. The database itself enforces the relationship — your code doesn't have to check manually.

### `onupdate=func.now()`
`updated_at` should automatically change every time the row is modified. SQLAlchemy's `onupdate` parameter does exactly this — whenever you `UPDATE` that row, SQLAlchemy sets the column to the current timestamp automatically.

### Query parameters vs path parameters
Two different ways to pass values in a URL:

```
GET /notes/5          ← path parameter: identifies WHICH note
GET /notes?user_id=1  ← query parameter: FILTERS the list
```

Path parameter = the identity of a specific resource. Always required.
Query parameter = optional filter or option. Appears after `?`.

### `NoteUpdate` with Optional fields
An update request shouldn't require all fields — you might only want to change the title without touching the body. Pydantic's `Optional` handles this:

```python
class NoteUpdate(BaseModel):
    title: Optional[str] = None
    body: Optional[str] = None
```

Only fields sent in the request get updated. Fields not sent stay as they are.

### `response_model` on routes
Every route that returns data should declare `response_model=NoteResponse`. This tells FastAPI exactly what shape to return and strips out anything not in the schema. This is also where the deliberate mistake in this step comes from — see what happens when `model_config = ConfigDict(from_attributes=True)` is missing from the schema.
