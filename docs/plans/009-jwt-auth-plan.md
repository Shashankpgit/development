# Plan 009 — JWT Authentication

## Phase 4, Step 2

---

## What we are building

Full authentication system:
- `POST /auth/register` — hash password, create user
- `POST /auth/login` — verify password, return JWT token
- `get_current_user` dependency — verifies token on every protected request
- All notes and passwords routes protected behind auth

---

## New packages

| Package | Purpose |
|---|---|
| `python-jose[cryptography]` | Create and verify JWT tokens |
| `passlib[bcrypt]` | Hash and verify passwords |

---

## New files

```
vault/app/
├── utils/
│   └── auth.py          ← create_token(), verify_token(), hash_password(), verify_password()
├── routers/
│   └── auth.py          ← POST /auth/register, POST /auth/login
└── dependencies.py      ← get_current_user() — FastAPI dependency
```

## Changed files

```
vault/app/main.py            ← register auth router
vault/app/routers/users.py   ← hash password on user creation
vault/app/routers/notes.py   ← protect all endpoints
vault/app/routers/passwords.py ← protect all endpoints
vault/app/config.py          ← add SECRET_KEY usage (already in config, just unused)
vault/requirements.txt       ← add new packages
```

---

## Steps

1. Install packages, update requirements.txt
2. Create vault/app/utils/auth.py — password hashing + JWT functions
3. Create vault/app/routers/auth.py — register + login endpoints
4. Create vault/app/dependencies.py — get_current_user
5. Register auth router in main.py
6. Fix users.py — hash password properly
7. Protect notes.py routes
8. Protect passwords.py routes
9. Test with curl — register, login, use token
