# 002 — First API Endpoint

---

## Part 1: What we are doing

**Goal:** Add a single `GET /health` endpoint. First time the server starts and returns a real response.

### Files being created / modified
```
vault/app/routers/health.py     ← new: the health endpoint
vault/app/main.py               ← modified: register the router
```

### The endpoint
```
GET /health
→ 200 OK
→ {"status": "ok", "version": "0.1.0"}
```

### Steps
1. Create `vault/app/routers/health.py` with the route
2. Register the router in `main.py`
3. Start the server
4. Open Swagger UI at `http://localhost:8000/docs`
5. Call the endpoint from Swagger

### What is NOT done in this step
- No database
- No business endpoints (notes, users, passwords)
- No request bodies or path parameters

---

## Part 2: Concepts / KT

### HTTP request/response cycle
Every API interaction is a two-part conversation:
1. **Request** — client (browser, curl, Swagger) sends: method + URL + optional body
2. **Response** — server sends back: status code + optional body

```
Client                          Server
  |                               |
  |  GET /health                  |
  | ─────────────────────────►   |
  |                               |  finds the matching route
  |  200 OK                       |  runs the function
  |  {"status": "ok"}             |
  | ◄─────────────────────────   |
```

### HTTP methods
The method tells the server *what you want to do* with a resource:
- `GET` — read something (no body sent)
- `POST` — create something (body contains the new data)
- `PUT` — update/replace something
- `DELETE` — remove something

`/health` uses GET because we're just reading the server's status.

### HTTP status codes
The first thing the server tells you is a 3-digit number:
- `2xx` — success. `200 OK`, `201 Created`
- `4xx` — your fault. `400 Bad Request`, `401 Unauthorized`, `404 Not Found`
- `5xx` — server's fault. `500 Internal Server Error`

A `404` doesn't always mean "page not found" — it means "this URL doesn't exist on this server." You'll see this in the deliberate mistake below.

### FastAPI router
If every endpoint lived in `main.py`, it would become thousands of lines. Instead FastAPI lets you create `APIRouter` objects in separate files — each focused on one feature — and register them in `main.py`.

```python
# health.py
router = APIRouter()

@router.get("/health")
def health_check():
    return {"status": "ok"}
```

```python
# main.py
from app.routers import health
app.include_router(health.router)   ← this line connects the two
```

The route only exists if `include_router` is called. Just creating the file is not enough.

### Swagger UI (`/docs`)
FastAPI automatically generates interactive API documentation at `http://localhost:8000/docs`. You can see all endpoints, their inputs/outputs, and call them directly from the browser — no frontend needed. This is your primary testing tool until Phase 3.
