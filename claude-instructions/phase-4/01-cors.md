# Phase 4 — Step 1: CORS

## What this step covers
Move the frontend to its own port (port 3000), observe the CORS error, then fix it by configuring `CORSMiddleware` in FastAPI.

---

## Pre-step checklist (Claude must do before any code)

- [ ] Create `docs/008-cors-plan.md` first
- [ ] Explain WHY CORS exists before touching any code — this is a security feature, not a bug

---

## Why this step exists

Until now, the frontend and backend are on the same origin (`localhost:8000`). In production (and in Phase 6+), they will be on different domains. CORS errors will appear immediately. Understanding CORS before adding auth prevents hours of debugging later.

This step is also the first time the user sees a real security error in the browser console — a critical learning moment.

---

## What to implement

### Step 1: Trigger the error (teach first, fix second)
1. Serve the frontend with Python's `http.server` on port 3000:
   `python -m http.server 3000 --directory frontend`
2. Open `http://localhost:3000` in browser
3. Open DevTools → Console tab
4. Watch the CORS error appear in red
5. Open Network tab → see the blocked request
6. **Do not fix it yet — let the user read and understand the error**

### Step 2: Explain CORS
(See concepts section)

### Step 3: Add CORSMiddleware to FastAPI
In `app/main.py`:
```python
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"],  # dev only
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

### Step 4: Move to environment variable
- `ALLOWED_ORIGINS=http://localhost:3000` in `.env`
- In production, this becomes the real domain

---

## Concepts to teach during this step

- **Same-Origin Policy**: A browser security rule — JavaScript from `localhost:3000` cannot talk to `localhost:8000` by default. This prevents malicious websites from reading your bank data.

- **CORS (Cross-Origin Resource Sharing)**: A mechanism that lets the server say "I trust requests from these origins." The browser checks the server's permission before allowing the request.

- **Preflight request (`OPTIONS`)**: For non-simple requests (POST with JSON), the browser first sends an `OPTIONS` request to check if the server allows it. Show this in the Network tab.

- **`allow_origins`**: The list of origins the server trusts. In dev: `localhost:3000`. In production: `https://yourdomain.com`.

- **Why `allow_origins=["*"]` is dangerous in production**: Never do this with `allow_credentials=True`. Briefly explain why.

- **CORS is a browser feature, not a server feature**: `curl` doesn't care about CORS. Only browsers enforce it. This is why your Swagger UI tests worked fine but the browser blocked it.

---

## Teaching moment: Read the error

Before fixing, have the user read the full CORS error message in the console:
```
Access to fetch at 'http://localhost:8000/notes' from origin 'http://localhost:3000' 
has been blocked by CORS policy: No 'Access-Control-Allow-Origin' header is present 
on the requested resource.
```

Walk through each part of the message. This is a skill — reading error messages, not just Googling the fix.

---

## What NOT to do in this step

- Do NOT use `allow_origins=["*"]` and call it done
- Do NOT skip the "trigger the error" step — that's the learning
- Do NOT add authentication yet (that's Step 4.2 and 4.3)

---

## File changes

| File | Action |
|---|---|
| `app/main.py` | Modify — add CORSMiddleware |
| `app/config.py` | Modify — add ALLOWED_ORIGINS |
| `.env.example` | Modify — add ALLOWED_ORIGINS= |

---

## Success criteria

1. Frontend served at `localhost:3000` → CORS error visible in DevTools
2. CORS error explained and understood
3. CORSMiddleware added → error disappears
4. App works from `localhost:3000` calling `localhost:8000`
5. `ALLOWED_ORIGINS` in `.env`, not hardcoded
