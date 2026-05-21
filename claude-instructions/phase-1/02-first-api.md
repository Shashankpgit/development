# Phase 1 — Step 2: First API Endpoint

## What this step covers
Add a single `GET /health` endpoint to the app and run it. This is the first time the user sees a working API.

---

## Pre-step checklist (Claude must do before any code)

- [ ] Create `docs/002-first-api-plan.md` first
- [ ] Explain WHY a health check endpoint is the right first endpoint (not a business endpoint)

---

## Why this step exists

The first endpoint should not be a business feature. It should be the simplest possible proof that the server is running. A health check endpoint:
- Confirms the web server starts and listens
- Is used in production by load balancers and Kubernetes liveness probes (hint for later phases)
- Teaches the request/response cycle with zero business logic distraction

This is the "hello world" of web APIs — but done the real way.

---

## What to implement

### `GET /health`
Response:
```json
{
  "status": "ok",
  "version": "1.0.0"
}
```

### Steps
1. Add route in `app/routers/health.py`
2. Register the router in `app/main.py` using `app.include_router()`
3. Run the server: `uvicorn app.main:app --reload`
4. Open `http://localhost:8000/docs` in browser → show Swagger UI
5. Call the endpoint from Swagger UI → show the response

---

## Concepts to teach during this step

- **HTTP request/response cycle**: What actually happens when you call an API
- **HTTP methods**: GET vs POST vs PUT vs DELETE — what each means
- **HTTP status codes**: 200 OK, 404 Not Found, 500 Internal Server Error — what they mean
- **FastAPI router**: Why we separate routes into routers instead of putting everything in main.py
- **`include_router()`**: How FastAPI assembles multiple routers into one app
- **Swagger UI (`/docs`)**: FastAPI generates this automatically — this is your primary testing tool in v1 (before frontend exists)
- **uvicorn**: What it is — the ASGI server that actually runs the FastAPI app

---

## Show in Swagger UI (teach this)

Walk the user through:
1. Open `http://localhost:8000/docs`
2. Find the `GET /health` endpoint
3. Click "Try it out" → "Execute"
4. See the response body, status code, and response headers
5. Explain: "This is how you test APIs without a frontend. In a real company, backend engineers test this way daily."

---

## What NOT to do in this step

- Do NOT create any business endpoints (notes, users, passwords) yet
- Do NOT connect a database yet
- Do NOT add request bodies or path parameters yet
- Do NOT think about authentication yet

---

## File changes

| File | Action |
|---|---|
| `app/routers/health.py` | Create |
| `app/main.py` | Modify — include health router |

---

## Success criteria

```bash
uvicorn app.main:app --reload
# Server starts at http://localhost:8000
# GET http://localhost:8000/health returns {"status": "ok", "version": "1.0.0"}
# http://localhost:8000/docs loads Swagger UI
```
