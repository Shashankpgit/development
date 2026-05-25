# Personal Vault — Application Reference

This document is the single reference for what the Vault application is, what it does, and how it is structured. Read this if you need to understand the app quickly.

For detailed per-endpoint API docs see [`../../docs/api/`](../../docs/api/).

---

## What is Personal Vault?

A multi-user private storage application. Each user registers, logs in, and gets their own private space to store:
- **Text notes** — title + body, like a private notebook
- **Passwords** — label + username + password value (encrypted at rest)

Bob logs in and sees only Bob's data. Alice logs in and sees only Alice's data. No user can see another user's data.

Think of it as a self-hosted, simplified combination of Bitwarden (password manager) and a private notebook.

---

## Features (current)

- User registration and login
- JWT-based authentication (stateless, token in `Authorization` header)
- Full CRUD for text notes (create, read, update, delete)
- Full CRUD for password entries (passwords encrypted with Fernet before storage)
- All data scoped to the authenticated user — no cross-user access possible

---

## Tech Stack

| Layer | Technology |
|---|---|
| Language | Python 3.12 |
| API Framework | FastAPI 0.115 |
| Database | PostgreSQL 16 |
| ORM | SQLAlchemy 2.x |
| Auth | JWT via `python-jose` |
| Password hashing | bcrypt via `passlib` |
| Encryption | Fernet symmetric via `cryptography` |
| Frontend | React 18 + Vite |

---

## Architecture

The backend follows a three-layer architecture. Each layer has one job and talks only to the layer below it.

```
HTTP Request
     ↓
  Router        ← parse HTTP request, call service, return HTTP response
     ↓
  Service       ← business logic, validation, orchestration
     ↓
  Repository    ← all SQL queries live here, nothing else
     ↓
  PostgreSQL
```

**Why this matters:** A router never writes SQL. A service never reads HTTP headers. A repository never knows about HTTP status codes. This separation makes each layer independently testable and replaceable.

### Directory layout

```
vault/
├── backend/
│   └── app/
│       ├── main.py           ← FastAPI app, middleware, router registration
│       ├── config.py         ← reads .env values
│       ├── database.py       ← SQLAlchemy engine + session factory
│       ├── dependencies.py   ← get_current_user (JWT → User object)
│       ├── models/           ← SQLAlchemy table definitions
│       ├── schemas/          ← Pydantic request/response shapes
│       ├── routers/          ← HTTP layer (one file per resource)
│       ├── services/         ← business logic (one file per resource)
│       ├── repositories/     ← database queries (one file per resource)
│       └── utils/
│           ├── auth.py       ← hash_password, verify_password, create_token, decode_token
│           └── crypto.py     ← encrypt, decrypt (Fernet)
└── frontend/
    └── src/
        ├── components/       ← React UI components
        ├── context/          ← AuthContext (JWT token shared across app)
        ├── App.jsx           ← root component, routing between auth/app
        └── main.jsx          ← React entry point
```

---

## Data Models

### User

| Field | Type | Notes |
|---|---|---|
| `id` | integer | Primary key, auto-increment |
| `username` | string (50) | Unique, not null |
| `hashed_password` | string | bcrypt hash, never returned in API responses |
| `created_at` | datetime | Set on insert |

### Note

| Field | Type | Notes |
|---|---|---|
| `id` | integer | Primary key |
| `user_id` | integer | Foreign key → users.id |
| `title` | string (200) | Not null |
| `body` | text | Nullable |
| `created_at` | datetime | Set on insert |
| `updated_at` | datetime | Updated on every change |

### PasswordEntry

| Field | Type | Notes |
|---|---|---|
| `id` | integer | Primary key |
| `user_id` | integer | Foreign key → users.id |
| `label` | string (100) | e.g. "GitHub", "Gmail" |
| `username` | string (100) | The username for that service |
| `encrypted_value` | text | Fernet-encrypted password value |
| `created_at` | datetime | Set on insert |
| `updated_at` | datetime | Updated on every change |

---

## API — All Endpoints

Base URL: `http://localhost:8000`

All protected endpoints require: `Authorization: Bearer <token>`

### Health

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/health` | No | Server + DB status |

### Auth

| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/auth/register` | No | Create a new user account |
| POST | `/auth/login` | No | Login, returns JWT access token |

**Register request:**
```json
{ "username": "bob", "password": "secret123" }
```

**Login response:**
```json
{ "access_token": "eyJ...", "token_type": "bearer" }
```

### Notes

| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/notes` | Yes | Create a note |
| GET | `/notes` | Yes | List all notes for current user |
| GET | `/notes/{id}` | Yes | Get a single note |
| PUT | `/notes/{id}` | Yes | Partial update (only fields sent are changed) |
| DELETE | `/notes/{id}` | Yes | Delete a note |

**Create/update fields:** `title` (required), `body` (optional)

### Passwords

| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/passwords` | Yes | Store a new password |
| GET | `/passwords` | Yes | List all entries (no decrypted value) |
| GET | `/passwords/{id}` | Yes | Get single entry with decrypted value |
| PUT | `/passwords/{id}` | Yes | Update entry |
| DELETE | `/passwords/{id}` | Yes | Delete entry |

**Create fields:** `label` (required), `username` (required), `value` (required — stored encrypted)

**List response** does NOT include the password value. Only `GET /passwords/{id}` returns the decrypted `value`.

### Users

| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/users` | No | Create user (alias for register, legacy) |
| GET | `/users/{id}` | No | Get user by ID |

---

## Environment Variables

File: `vault/backend/.env`

| Variable | Required | Description |
|---|---|---|
| `APP_ENV` | No | `development` or `production`. Default: `development` |
| `DATABASE_URL` | Yes | PostgreSQL connection string. Format: `postgresql://user:pass@host:5432/dbname` |
| `SECRET_KEY` | Yes | Random secret used to sign JWT tokens. Generate: `python3 -c "import secrets; print(secrets.token_hex(32))"` |
| `VAULT_ENCRYPTION_KEY` | Yes | Fernet key for encrypting stored passwords. Generate: `python3 -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"` |
| `CORS_ORIGINS` | No | Comma-separated allowed origins. Default: `http://localhost:5173` |

**Important:** `SECRET_KEY` and `VAULT_ENCRYPTION_KEY` must be generated once and kept stable. Changing `SECRET_KEY` invalidates all active JWT tokens. Changing `VAULT_ENCRYPTION_KEY` makes all stored passwords unreadable.

---

## Security Design

| Concern | Approach |
|---|---|
| Login password storage | bcrypt hash — one-way, cannot be reversed |
| Vault password storage | Fernet encryption — reversible with the key, for retrieval |
| Authentication | Stateless JWT — server holds no session state |
| Data isolation | All queries filter by `user_id` from the verified token — never from request body |
| Secrets | Never hardcoded — always loaded from `.env` via `python-dotenv` |

---

## Detailed API Docs

Each resource has its own detailed file with full request/response examples and curl commands:

- [`../../docs/api/health.md`](../../docs/api/health.md)
- [`../../docs/api/auth.md`](../../docs/api/auth.md)
- [`../../docs/api/users.md`](../../docs/api/users.md)
- [`../../docs/api/notes.md`](../../docs/api/notes.md)
- [`../../docs/api/passwords.md`](../../docs/api/passwords.md)
