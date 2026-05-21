# 001 — Project Setup

---

## Part 1: What we are doing

**Goal:** Create the foundational scaffold for the Personal Vault application inside the `vault/` directory.

### Files being created
```
vault/
├── app/
│   ├── __init__.py
│   ├── main.py          ← FastAPI app entry point (no routes yet)
│   ├── config.py        ← reads .env and exposes variables
│   ├── models/
│   │   └── __init__.py
│   ├── schemas/
│   │   └── __init__.py
│   └── routers/
│       └── __init__.py
├── tests/
│   └── __init__.py
├── .env                 ← your real secrets (gitignored)
├── .env.example         ← committed template
└── requirements.txt
```

### Steps
1. Create folder structure
2. Create `.gitignore` at repo root
3. Create `.env.example` and `.env`
4. Create `requirements.txt`
5. Create all `__init__.py` files
6. Create `app/config.py`
7. Create `app/main.py`
8. Verify: `python -c "from app.main import app"` passes

### What is NOT done in this step
- No routes (Phase 1 Step 2)
- No database connection (Phase 1 Step 3)
- No frontend

---

## Part 2: Concepts / KT

### Virtual environment
Python is installed globally on your machine. If two projects need different versions of the same library, they conflict. A virtual environment is an isolated Python installation just for this project — its own `python`, its own `pip`, its own installed packages. Nothing bleeds between projects.

```bash
python3 -m venv .venv        # create it
source .venv/bin/activate    # activate (your terminal now uses the isolated python)
deactivate                   # exit back to system python
```

You know it's active when your prompt shows `(.venv)`.

### requirements.txt
A plain text list of every library this project needs, with pinned versions. Anyone who clones the repo runs:
```bash
pip install -r requirements.txt
```
...and gets the exact same setup. Like sharing a recipe — you share what ingredients and how much, not the food itself.

### `.env` and `.env.example` pattern
Secrets (database passwords, API keys, secret keys) must never go into git. Once committed, they live in git history forever — even if you delete the line later.

The pattern:
- `.env` — your real values. **Gitignored.** Never committed.
- `.env.example` — a template with empty values. **Committed.** Tells others what variables they need to set.

`python-dotenv` reads `.env` at startup and loads each line as an environment variable.

### `__init__.py`
A folder is just a folder in Python — unless it contains `__init__.py`. That file (even empty) tells Python "this folder is a package, you can import from it." Without it, `from app.routers.health import router` would crash with `ModuleNotFoundError`.

### FastAPI app object
`app = FastAPI(...)` creates the central object that holds all routes, middleware, and config. `uvicorn` (the HTTP server) receives this object and starts handling requests with it. It's the kitchen — empty now, but everything gets built inside it.

### uvicorn
FastAPI is a framework — it defines how your code handles requests. But something still needs to listen on a port and hand HTTP traffic to FastAPI. That's uvicorn. It's an ASGI server (Asynchronous Server Gateway Interface). You run:
```bash
uvicorn app.main:app --reload
```
`app.main` = the Python module (`vault/app/main.py`). `app` = the FastAPI object inside that module. `--reload` = restart automatically on file changes (dev only).
