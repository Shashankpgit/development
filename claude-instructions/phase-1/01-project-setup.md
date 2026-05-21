# Phase 1 — Step 1: Project Setup

## What this step covers
Initialize the project folder structure, Python virtual environment, and core dependencies. Nothing runs yet — this is scaffolding only.

---

## Pre-step checklist (Claude must do before any code)

- [ ] Create `docs/001-project-setup-plan.md` first
- [ ] Explain WHY we use a virtual environment and WHY this folder structure

---

## Why this step exists

Before writing a single line of application code, a real engineering team establishes:
- A consistent, agreed-upon folder structure (so everyone knows where things go)
- Isolated dependencies (so this project doesn't pollute the system Python)
- A clear entry point (so anyone can clone the repo and run the app)

Skipping this step leads to "it works on my machine" problems within weeks.

---

## What to create

### Folder structure
```
app/
├── __init__.py
├── main.py
├── config.py
├── database.py
├── models/
│   └── __init__.py
├── schemas/
│   └── __init__.py
└── routers/
    └── __init__.py
docs/
tests/
    └── __init__.py
.env.example
requirements.txt
README.md (update, not create)
```

### Files
- `requirements.txt` — list: fastapi, uvicorn, sqlalchemy, python-dotenv
- `.env.example` — template: APP_ENV, DATABASE_URL, SECRET_KEY (empty values)
- `.gitignore` — include: .env, __pycache__, *.pyc, .venv/, vault.db
- `app/main.py` — bare FastAPI app, no routes yet
- `app/config.py` — load env vars using python-dotenv

---

## Concepts to teach during this step

- **Virtual environment**: Why Python projects need isolated dependencies
- **requirements.txt**: How Python projects declare their dependencies (like package.json in Node)
- **.env and .env.example pattern**: Why secrets are never committed to git
- **`__init__.py`**: What it does and why Python packages need it (briefly)
- **FastAPI app object**: What `FastAPI()` actually creates and why it's the entry point

---

## Implementation order (small steps)

1. Create folder structure (mkdir commands)
2. Create `.gitignore`
3. Create `.env.example` with placeholder values
4. Create `requirements.txt`
5. Create `app/__init__.py` and sub-package `__init__.py` files
6. Create `app/config.py` (load env vars)
7. Create `app/main.py` (bare FastAPI app — no routes yet, just the app object)
8. Confirm the app can be imported: `python -c "from app.main import app; print('OK')`

---

## What NOT to do in this step

- Do NOT add any routes (that's Phase 1 Step 2)
- Do NOT connect a database (that's Phase 1 Step 3)
- Do NOT install SQLAlchemy models yet (just add to requirements.txt)
- Do NOT create a frontend

---

## Success criteria

The project installs cleanly:
```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python -c "from app.main import app; print('Setup OK')"
```

Git status shows all expected files committed (except .env and .venv).
