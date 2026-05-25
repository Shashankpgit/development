# Phase 4 — Step 2: JWT Authentication (Register + Login)

## What this step covers
Implement user registration (with proper password hashing) and login (returning a JWT access token). This is the first real authentication in the application.

---

## Pre-step checklist (Claude must do before any code)

- [ ] Create `docs/009-jwt-auth-plan.md` first
- [ ] Teach JWT and stateless authentication BEFORE writing any code
- [ ] Update the User model to hash passwords properly

---

## Why this step exists

Until now, users exist in the database but with plaintext passwords, and anyone can access anyone's data. This step:
- Replaces plaintext passwords with bcrypt hashing
- Adds `POST /auth/register` and `POST /auth/login`
- Issues a JWT access token on successful login
- Sets up the token structure that the next step (middleware) will verify

Without this, Phase 4 Step 3 (middleware) has nothing to verify.

---

## What to implement

### Password hashing: `app/utils/security.py`
- `hash_password(plain: str) → str` using `passlib[bcrypt]`
- `verify_password(plain: str, hashed: str) → bool`

### JWT utilities: `app/utils/jwt_utils.py`
- `create_access_token(data: dict) → str` — signs a token with SECRET_KEY
- `decode_access_token(token: str) → dict` — verifies and decodes
- Token payload: `{"sub": username, "exp": <expiry>}`
- Token expiry: `ACCESS_TOKEN_EXPIRE_MINUTES` from `.env` (default: 30 min)

### `app/routers/auth.py`
- `POST /auth/register` — create user with hashed password
- `POST /auth/login` — verify credentials → return `{"access_token": "...", "token_type": "bearer"}`

### Update User model
- Replace the TODO comment from Phase 2.1 with actual `hash_password()` call in register endpoint

---

## Concepts to teach during this step

- **Why plaintext passwords are catastrophic**: Database breaches happen. If passwords are plaintext, every user's password is exposed. If hashed, the attacker has useless gibberish.

- **bcrypt**: A slow hashing algorithm designed for passwords. Slow on purpose — makes brute-force attacks expensive. `passlib` wraps bcrypt with a clean API.

- **Why bcrypt, not SHA256**: SHA256 is fast (good for checksums, bad for passwords). bcrypt is slow (bad for checksums, good for passwords).

- **JWT (JSON Web Token)**: Three Base64-encoded parts: Header.Payload.Signature
  - Header: algorithm used
  - Payload: the claims (who you are, when it expires)
  - Signature: proves the token wasn't tampered with (signed with SECRET_KEY)
  - Show: paste a JWT into jwt.io and decode it live

- **Stateless authentication**: The server doesn't store sessions. The token contains everything. Any server instance can verify any token. This is why JWT scales horizontally.

- **`SECRET_KEY`**: Must be random and secret. If an attacker knows the SECRET_KEY, they can forge tokens. Goes in `.env`, never in code.

- **Token expiry**: Tokens expire to limit damage if stolen. Short-lived (15–30 min) access tokens + longer-lived refresh tokens is the real pattern (keep refresh tokens for later if asked).

- **Bearer token**: The convention for sending tokens in HTTP — `Authorization: Bearer <token>`. Show where this header appears.

---

## Teaching moment: jwt.io

Go to https://jwt.io with the user:
1. Paste a generated token
2. See the decoded header and payload
3. See "Signature Verified" vs "Invalid Signature"
4. "This is public. Never put passwords or sensitive data in the JWT payload — it's only base64, not encrypted."

---

## What NOT to do in this step

- Do NOT implement refresh tokens yet (add a comment noting it's a TODO)
- Do NOT protect existing endpoints yet (that's Phase 4 Step 3)
- Do NOT implement "forgot password" or email verification
- Do NOT add session cookies (token-based auth only for now)

---

## File changes

| File | Action |
|---|---|
| `app/utils/security.py` | Create |
| `app/utils/jwt_utils.py` | Create |
| `app/routers/auth.py` | Create |
| `app/routers/users.py` | Modify — use hash_password in create user |
| `app/main.py` | Modify — include auth router |
| `requirements.txt` | Modify — add `passlib[bcrypt]`, `python-jose[cryptography]` |
| `.env.example` | Modify — add SECRET_KEY=, ACCESS_TOKEN_EXPIRE_MINUTES= |

---

## Success criteria

1. `POST /auth/register` with `{"username": "bob", "password": "secret"}` → creates user with hashed password
2. `psql $DATABASE_URL -c "SELECT hashed_password FROM users;"` → shows bcrypt hash, NOT "secret"
3. `POST /auth/login` with correct credentials → returns `{"access_token": "eyJ...", "token_type": "bearer"}`
4. `POST /auth/login` with wrong password → returns 401 Unauthorized
5. Paste token into jwt.io → see `{"sub": "bob", "exp": ...}` in payload
