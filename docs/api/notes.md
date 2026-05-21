# API — Notes

Text note management. Notes belong to a user.

---

## Endpoints

| Method | Path | Description | Auth required |
|---|---|---|---|
| `POST` | `/notes` | Create a note | Phase 4+ |
| `GET` | `/notes?user_id=1` | List notes for a user | Phase 4+ |
| `GET` | `/notes/{id}` | Get a single note | Phase 4+ |
| `PUT` | `/notes/{id}` | Update a note (partial) | Phase 4+ |
| `DELETE` | `/notes/{id}` | Delete a note | Phase 4+ |

---

### POST /notes

**Auth required:** No (until Phase 4)

#### Request body
```json
{
  "user_id": 1,
  "title": "My first note",
  "body": "Hello Vault"
}
```

| Field | Type | Required | Notes |
|---|---|---|---|
| `user_id` | integer | Yes | Must reference an existing user |
| `title` | string | Yes | Max 200 chars |
| `body` | string | No | Can be null |

#### Response — 201 Created
```json
{
  "id": 1,
  "user_id": 1,
  "title": "My first note",
  "body": "Hello Vault",
  "created_at": "2026-05-21T18:07:51Z",
  "updated_at": "2026-05-21T18:07:51Z"
}
```

#### curl
```bash
curl -s -X POST http://localhost:8000/notes \
  -H "Content-Type: application/json" \
  -d '{"user_id": 1, "title": "My note", "body": "Hello"}' | jq
```

---

### GET /notes

**Auth required:** No (until Phase 4)

#### Query parameter
| Parameter | Type | Required | Notes |
|---|---|---|---|
| `user_id` | integer | Yes | Filter notes by user |

#### Response — 200 OK
```json
[
  {
    "id": 1,
    "user_id": 1,
    "title": "My note",
    "body": "Hello",
    "created_at": "...",
    "updated_at": "..."
  }
]
```

#### curl
```bash
curl -s "http://localhost:8000/notes?user_id=1" | jq
```

---

### GET /notes/{id}

**Auth required:** No (until Phase 4)

#### Response — 200 OK
Single note object (same shape as above).

#### Response — 404 Not Found
```json
{ "detail": "Note not found" }
```

#### curl
```bash
curl -s http://localhost:8000/notes/1 | jq
```

---

### PUT /notes/{id}

Partial update — only fields included in the body are changed.

**Auth required:** No (until Phase 4)

#### Request body (all fields optional)
```json
{
  "title": "New title",
  "body": "New body"
}
```

#### Response — 200 OK
Updated note. `updated_at` will reflect the change time.

#### curl
```bash
curl -s -X PUT http://localhost:8000/notes/1 \
  -H "Content-Type: application/json" \
  -d '{"title": "New title"}' | jq
```

---

### DELETE /notes/{id}

**Auth required:** No (until Phase 4)

#### Response — 204 No Content
Empty body. The note is gone.

#### Response — 404 Not Found
```json
{ "detail": "Note not found" }
```

#### curl
```bash
curl -s -X DELETE http://localhost:8000/notes/1 -o /dev/null -w "%{http_code}\n"
```
