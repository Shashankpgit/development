# Phase 4 — Step 3: Auth Middleware and Route Protection

## What this step covers
Protect notes and passwords endpoints so only authenticated users can access their own data. Implement a `get_current_user` dependency and apply it to all protected routes.

---

## Pre-step checklist (Claude must do before any code)

- [ ] Create `docs/010-auth-middleware-plan.md` first
- [ ] Confirm login works and tokens are being issued (Phase 4 Step 2 complete)

---

## Why this step exists

Having login and JWT issuance is meaningless if the protected endpoints don't verify the token. This step closes the auth loop:
- Adds a FastAPI dependency `get_current_user` that extracts and validates the JWT
- Applies it to notes and passwords endpoints
- Scopes data: a user can only see and modify their own notes/passwords

This is where the application transitions from "toy API" to "real multi-user application."

---

## What to implement

### `app/dependencies/auth.py`
```python
async def get_current_user(token: str = Depends(oauth2_scheme), db = Depends(get_db)):
    # Decode JWT → get username → fetch user from DB → return user object
    # Raise 401 if token invalid, expired, or user not found
```

Using FastAPI's `OAuth2PasswordBearer` scheme (reads `Authorization: Bearer <token>` header automatically).

### Update routers

`app/routers/notes.py`:
- All endpoints now require `current_user: User = Depends(get_current_user)`
- `POST /notes` — ignore `user_id` from body, use `current_user.id`
- `GET /notes` — return only current user's notes (remove `?user_id` query param)
- `GET /notes/{id}` — verify note belongs to `current_user` before returning (403 if not)
- `PUT /notes/{id}` — same ownership check
- `DELETE /notes/{id}` — same ownership check

`app/routers/passwords.py`: same pattern.

### Routes that stay public
- `GET /health` — no auth needed
- `POST /auth/register` — no auth needed (you're not logged in yet)
- `POST /auth/login` — no auth needed

### Remove dev-only endpoints
- Remove `GET /users` (the "list all users" endpoint added in Phase 2.1)

---

## Concepts to teach during this step

- **FastAPI dependency injection**: `Depends()` — how FastAPI resolves dependencies before calling the route handler. This is how middleware-like behavior is attached per-route.

- **`OAuth2PasswordBearer`**: FastAPI's built-in way to extract bearer tokens from the Authorization header. It also makes Swagger UI show an "Authorize" button automatically.

- **Authorization vs Authentication**:
  - Authentication: "Who are you?" (verified by the token)
  - Authorization: "Are you allowed to do this?" (verified by ownership check — is this note yours?)

- **403 vs 401**:
  - 401: You're not authenticated (no token or invalid token)
  - 403: You're authenticated but not authorized (valid token, but that's not your note)

- **Why we don't trust `user_id` from the request body**: Any client can send `{"user_id": 1}`. The server must derive user identity from the verified token, not from user-supplied data.

- **Dependency chain in FastAPI**: `get_current_user` → depends on `get_db` and `oauth2_scheme`. FastAPI resolves the full dependency tree automatically.

---

## Teaching moment: Test with Swagger UI

Walk through using the Authorize button in Swagger:
1. `POST /auth/login` → copy the token
2. Click "Authorize" button in Swagger → paste token
3. Now `GET /notes` works → returns only your notes
4. Try `GET /notes/{id}` with another user's note ID → 403

---

## Teaching moment: Token in Network tab

Open DevTools → Network tab:
1. Log in → see the token in the response
2. Make a notes request → see `Authorization: Bearer eyJ...` in the Request Headers
3. "This is how authentication flows through every authenticated request"

---

## What NOT to do in this step

- Do NOT implement refresh tokens (note it as a future improvement)
- Do NOT add role-based access control (admin vs user)
- Do NOT add token revocation (complex; note for Phase 9 with Keycloak)
- Do NOT add frontend login page yet (do it after this backend step is verified)

---

## File changes

| File | Action |
|---|---|
| `app/dependencies/__init__.py` | Create |
| `app/dependencies/auth.py` | Create |
| `app/routers/notes.py` | Modify — add auth dependency, scope to current user |
| `app/routers/passwords.py` | Modify — add auth dependency, scope to current user |
| `app/routers/users.py` | Modify — remove GET /users list endpoint |

---

## Then: Frontend login page
After the backend is verified, add to the frontend:
- `login.html` — username + password form → calls `POST /auth/login` → stores token in `localStorage`
- Update `app.js` — include `Authorization` header in all API calls using stored token
- Redirect to login if API returns 401

---

## Success criteria

1. `GET /notes` without token → 401 Unauthorized
2. `GET /notes` with valid token → returns only that user's notes
3. Create note as alice, try to GET it as bob → 403 Forbidden
4. Swagger UI "Authorize" button works for all protected endpoints
5. DevTools Network tab shows `Authorization: Bearer ...` on authenticated requests
6. Frontend redirects to login.html if no token stored
