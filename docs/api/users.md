# API — Users

User account management.

---

## Endpoints

| Method | Path | Description | Auth required |
|---|---|---|---|
| `POST` | `/users` | Create a new user | No |
| `GET` | `/users/{id}` | Get a user by ID | No |

---

### POST /users

Create a new user account.

**Auth required:** No

#### Request body
```json
{
  "username": "bob",
  "password": "secret123"
}
```

| Field | Type | Required | Notes |
|---|---|---|---|
| `username` | string | Yes | Must be unique, max 50 chars |
| `password` | string | Yes | Stored as plaintext until Phase 4 |

#### Response — 201 Created
```json
{
  "id": 1,
  "username": "bob",
  "created_at": "2026-05-21T17:21:38.435025Z"
}
```

> `hashed_password` is never returned in any response.

#### Response — 400 Bad Request
```json
{
  "detail": "Username already taken"
}
```

#### curl
```bash
curl -s -X POST http://localhost:8000/users \
  -H "Content-Type: application/json" \
  -d '{"username": "bob", "password": "secret123"}' | jq
```

---

### GET /users/{id}

Get a single user by their ID.

**Auth required:** No

#### Path parameter
| Parameter | Type | Notes |
|---|---|---|
| `id` | integer | The user's ID |

#### Response — 200 OK
```json
{
  "id": 1,
  "username": "bob",
  "created_at": "2026-05-21T17:21:38.435025Z"
}
```

#### Response — 404 Not Found
```json
{
  "detail": "User not found"
}
```

#### curl
```bash
curl -s http://localhost:8000/users/1 | jq
```

---

## Notes

- Both endpoints will be protected by auth in Phase 4
- Password hashing (bcrypt) is added in Phase 4 Step 2
- A `GET /users` list endpoint is intentionally omitted — listing all users is a security risk
