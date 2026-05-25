# KT — JWT Authentication

## 1. The problem we have right now

Our API has zero security. Any request to any endpoint works:

```bash
curl http://localhost:8000/notes?user_id=1   # gets user 1's notes
curl http://localhost:8000/notes?user_id=2   # gets user 2's notes — anyone can do this
```

There is no concept of "who is making this request." Bob can read Alice's
notes just by changing the user_id. This is not a real application — it's
an open database with a web interface.

Authentication fixes this. After Phase 4:
- You must prove who you are before accessing any data
- You can only access YOUR data — the server enforces this, not the frontend

---

## 2. Authentication vs Authorization

These two words are often confused:

| Term | Question it answers | Example |
|---|---|---|
| **Authentication** | Who are you? | "I am Bob, here is my password" |
| **Authorization** | What are you allowed to do? | "Bob can only see Bob's notes" |

Authentication comes first. You cannot authorize someone whose identity
you don't know.

---

## 3. How websites used to do this — Sessions

The old approach (still used in many apps):

```
1. User logs in with username + password
2. Server creates a "session" — stores it in a database
3. Server sends back a session ID in a cookie
4. Every request: browser sends cookie → server looks up session in DB
5. Server confirms who you are → processes request
```

Problem: the server must query the database on EVERY request just to
confirm who the user is. At scale (millions of users), this is slow
and expensive.

---

## 4. The JWT approach — stateless authentication

JWT (JSON Web Token) solves this differently:

```
1. User logs in with username + password
2. Server verifies password — if correct, creates a signed token
3. Server sends token back — does NOT store anything in the database
4. Every request: client sends token in the Authorization header
5. Server VERIFIES the token's signature — no DB lookup needed
6. Server confirms who you are from the token itself → processes request
```

The key difference: **the server stores nothing.** The token itself
contains the user's identity, and the signature proves it hasn't been tampered with.

This is called **stateless** — the server has no state to look up.

---

## 5. What a JWT token looks like

A JWT is a string with three parts separated by dots:

```
eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.abc123signature
─────────────────────.────────────────.────────────────
      HEADER               PAYLOAD         SIGNATURE
```

Each part is Base64-encoded (not encrypted — just encoded).

### Header
```json
{
  "alg": "HS256"    ← algorithm used to sign this token
}
```

### Payload
```json
{
  "sub": "1",                    ← subject = user ID
  "exp": 1748123456              ← expiry timestamp
}
```

This is the data the server trusts. `sub` tells the server "this token
belongs to user 1."

### Signature
```
HMAC_SHA256(
  base64(header) + "." + base64(payload),
  SECRET_KEY          ← only the server knows this
)
```

The signature is computed using a secret key only the server knows.
If anyone tries to tamper with the payload (e.g. change user ID from 1 to 2),
the signature won't match — the server rejects the token.

---

## 6. Paste a token here to see inside it

Go to https://jwt.io — paste any JWT token and you can see the decoded
header and payload. This shows that JWTs are NOT encrypted — they are
only signed. Never put sensitive data (passwords, card numbers) in a JWT.

---

## 7. The complete authentication flow in our app

```
REGISTRATION
─────────────
User fills form → POST /auth/register {username, password}
Server hashes password → stores user in DB
Server returns 201 Created

LOGIN
─────
User fills form → POST /auth/login {username, password}
Server looks up user in DB
Server checks: does hash(password) match stored hash? YES
Server creates JWT token with {sub: user_id, exp: tomorrow}
Server returns {access_token: "eyJ..."}

AUTHENTICATED REQUEST
──────────────────────
Client stores token (in memory or localStorage)
Client sends any request with header:
  Authorization: Bearer eyJhbGciOiJIUzI1NiJ9...
Server receives request
Server reads the token from the Authorization header
Server verifies the signature using SECRET_KEY
Server reads user_id from token payload
Server fetches ONLY that user's data
```

---

## 8. Where does the token live on the frontend?

Two common options:

| Storage | Pros | Cons |
|---|---|---|
| `localStorage` | Survives page refresh | Accessible to JS — XSS risk |
| Memory (React state) | Not accessible to JS attacks | Lost on page refresh |
| `httpOnly` cookie | Not accessible to JS at all | Requires more backend setup |

We will use **localStorage** for simplicity during development.
In production, `httpOnly` cookies are more secure.

---

## 9. How our current code will change

### Backend changes (FastAPI)

New router: `vault/app/routers/auth.py`
- `POST /auth/register` — hash password, create user
- `POST /auth/login` — verify password, return JWT token

New dependency: `get_current_user`
- Reads the `Authorization` header from every request
- Verifies the token signature
- Returns the user object
- Any route that uses this dependency is now protected

Updated routes: all notes and passwords endpoints will require
`current_user: User = Depends(get_current_user)` — they will use
the user ID from the token, not from the request body.

New packages:
- `python-jose` — create and verify JWT tokens
- `passlib[bcrypt]` — hash passwords properly

### Frontend changes (React)

New components:
- `LoginForm.jsx` — POST /auth/login, store token
- `RegisterForm.jsx` — POST /auth/register

Updated fetch calls:
- Every API call adds the Authorization header:
  ```javascript
  headers: {
    "Content-Type": "application/json",
    "Authorization": `Bearer ${token}`
  }
  ```

---

## 10. What is bcrypt and why not store plain passwords?

Right now we store passwords as plain text in the DB:
```python
db_user = User(username=user.username, hashed_password=user.password)
```

This is dangerous. If the database is breached, all passwords are exposed.

bcrypt is a **one-way hashing algorithm** designed for passwords:
```
bcrypt("mysecret123") → "$2b$12$abc...xyz"  (60-character hash)
```

One-way means: you cannot reverse the hash to get the original password.
To verify a login, you hash the input and compare hashes:
```
bcrypt.verify("mysecret123", stored_hash) → True or False
```

This is different from Fernet encryption (used for stored passwords in
the vault) — Fernet is two-way (encrypt → decrypt). bcrypt is one-way
(hash → cannot unhash). Login passwords are hashed, not encrypted,
because you never need the original — you only need to verify it.

---

## 11. Summary — what JWT gives us

| Before Phase 4 | After Phase 4 |
|---|---|
| Anyone can access any user's data | Must log in to access anything |
| user_id passed in request body | user_id comes from the verified token |
| Passwords stored as plain text | Passwords hashed with bcrypt |
| No concept of "current user" | Every request knows exactly who is asking |
