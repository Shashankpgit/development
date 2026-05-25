# KT — CORS (Cross-Origin Resource Sharing)

## What is CORS?

CORS is a browser security mechanism that controls which origins (domains/ports)
are allowed to make requests to your API from JavaScript.

It exists to prevent a malicious website from silently calling your bank's API
using your browser's stored cookies.

---

## Key terms

| Term | Meaning |
|---|---|
| Origin | Protocol + Domain + Port. `http://localhost:5173` is one origin. `http://localhost:8000` is another. |
| Same-origin | Both the page and the API are on the same origin. No CORS needed. |
| Cross-origin | Page and API are on different origins. Browser enforces CORS. |

---

## The rule browsers enforce

> JavaScript on origin A cannot read responses from origin B —
> unless origin B explicitly says it allows origin A.

**curl and Postman do NOT enforce this rule.** Only browsers do.
This is why all your Postman tests passed even without CORS configured.

---

## How we hit the CORS error

React dev server runs on `http://localhost:5173`.
FastAPI runs on `http://localhost:8000`.

Different ports = different origins.

When React called `fetch("http://localhost:8000/notes")`:

```
1. Browser sends GET /notes to FastAPI
2. FastAPI processes the request — returns 200 OK with data
3. Browser checks the response headers:
     "Is there an Access-Control-Allow-Origin header?"
     "Does it include http://localhost:5173?"
4. No header found → browser BLOCKS the response
5. JavaScript never sees the data
6. Console shows: "blocked by CORS policy"
```

Note: FastAPI did its job correctly. The response was 200 OK.
The browser threw it away before JS could read it.

---

## The error we saw

```
Access to fetch at 'http://localhost:8000/notes?user_id=1'
from origin 'http://localhost:5173' has been blocked by CORS policy:
No 'Access-Control-Allow-Origin' header is present on the requested resource.

GET http://localhost:8000/notes?user_id=1 net::ERR_FAILED 200 (OK)
```

The `200 (OK)` in the error confirms the server responded successfully.
The browser blocked it.

---

## The fix — CORSMiddleware in FastAPI

### vault/app/config.py

```python
CORS_ORIGINS = os.getenv("CORS_ORIGINS", "http://localhost:5173").split(",")
```

Read allowed origins from `.env` as a comma-separated list.
`.split(",")` converts it to a Python list FastAPI needs.

### vault/app/main.py

```python
from fastapi.middleware.cors import CORSMiddleware
from app.config import APP_ENV, CORS_ORIGINS

app.add_middleware(
    CORSMiddleware,
    allow_origins=CORS_ORIGINS,      # which origins are allowed
    allow_credentials=True,           # allow cookies/auth headers
    allow_methods=["*"],              # allow all HTTP methods (GET, POST, DELETE...)
    allow_headers=["*"],              # allow all headers (Content-Type, Authorization...)
)
```

`CORSMiddleware` adds the `Access-Control-Allow-Origin` header to every
FastAPI response automatically. The browser sees it and allows the JS to
read the response.

---

## How it works after the fix

```
1. Browser sends GET /notes to FastAPI
2. FastAPI processes the request
3. CORSMiddleware adds header to response:
     Access-Control-Allow-Origin: http://localhost:5173
4. Browser checks: does it match the requesting origin? YES
5. Browser allows JS to read the response
6. Notes appear on the page
```

---

## Verify it in DevTools

DevTools → Network tab → click any API request → Response Headers tab:

```
access-control-allow-origin: http://localhost:5173
```

That one header is what makes everything work.

---

## The .env configuration

### vault/.env (your local, never committed)
```
CORS_ORIGINS=http://localhost:5173
```

### vault/.env.example (committed — template for others)
```
CORS_ORIGINS=http://localhost:5173
```

### In production
```
CORS_ORIGINS=https://myvault.com,https://www.myvault.com
```

Multiple origins are comma-separated. The `.split(",")` in config.py
handles this automatically.

---

## Why CORS lives in the backend, not the frontend

The frontend cannot configure CORS. CORS headers must come from the server.

The browser asks the server: "Do you allow requests from my origin?"
The server answers via response headers.
The browser enforces the answer.

If the server doesn't answer (no header), the browser blocks it.

---

## What changes in Phase 7 (Nginx)

When Nginx is set up, the architecture changes:

```
Browser → Nginx :80
            ├── /        → React static files (same origin as the browser)
            └── /api/*   → FastAPI :8000 (proxied server-to-server)
```

The browser only talks to Nginx — same origin. No CORS needed.
The Nginx-to-FastAPI call is server-to-server — not a browser request, no CORS check.

At that point we can either remove CORSMiddleware or keep it scoped to only
the allowed production domain — as a defence-in-depth measure.

---

## Summary

| | Detail |
|---|---|
| What caused the error | React on `:5173` calling API on `:8000` — different origins |
| What the browser checked | `Access-Control-Allow-Origin` header in the response |
| What we added | `CORSMiddleware` in FastAPI — adds that header to every response |
| Where origins are configured | `CORS_ORIGINS` in `.env` — comma-separated list |
| Who enforces CORS | The browser only — curl/Postman ignore it |
| Production plan | Nginx proxy removes the cross-origin problem entirely |
