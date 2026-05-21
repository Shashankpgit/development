# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a multi-purpose development repository containing:
- A structured 7-week backend learning curriculum (Python/FastAPI)
- A FastAPI task manager application (skeleton/template)
- Helm charts for local Kubernetes deployment
- Kong API Gateway management scripts and charts

## Commands

### Task Manager (FastAPI)

```bash
cd task-manager

# Install dependencies
pip install -r requirements.txt

# Run the app
uvicorn app.main:app --reload

# Run tests
pytest tests/

# Run a single test
pytest tests/test_task.py::test_function_name -v
```

### Learning Week Projects (weeks 3–5 have Dockerfiles)

```bash
# Build Docker image for a week project
docker build -t week<N> ./Learn/week<N>

# Run container
docker run -p 8000:8000 week<N>
```

### Helm Charts

```bash
cd helmchart/<chart-name>

# Resolve chart dependencies
helm dependency update

# Validate chart rendering
helm template .

# Deploy
helm upgrade --install <release-name> .
```

### Kong API Sync

```bash
# Sync APIs with ownership tag (run from scripts/kong-api-scripts/)
python kong_apis.py --managed-by=core --upsert-only=false
python kong_apis.py --managed-by=discussion-forum --upsert-only=false
```

### GitHub Actions (CI/CD)

The Docker build workflow (`.github/workflows/docker-build.yml`) is manually dispatched and builds/pushes images for weeks 3, 4, 5 to ghcr.io.

## Architecture

### Task Manager (`/task-manager`)

Standard FastAPI project layout — most files are empty scaffolding awaiting implementation:

```
app/
├── main.py          # App initialization
├── config.py        # Settings
├── database.py      # SQLAlchemy engine + session
├── api/
│   ├── api.py       # Router aggregation
│   ├── deps.py      # Dependency injection
│   └── endpoints/tasks.py
├── models/task.py   # SQLAlchemy ORM models
├── schemas/task.py  # Pydantic schemas
└── crud/crud_task.py
```

Stack: FastAPI 0.128, Pydantic v2, SQLAlchemy 2.0, PostgreSQL (psycopg2), Uvicorn.

### Helm Charts (`/helmchart`)

Three charts for local development:
- **postgresql** — Bitnami PostgreSQL (v18.4.0)
- **todo-backend** — Custom FastAPI chart (Deployment + Service + Secret)
- **todo-frontend** — Nginx static serving (Deployment + Service)

### Kong API Decoupling Architecture

The most complex part of this repo. Core idea: Kong APIs are owned by different teams, tracked via `--managed-by` tag.

- **Core platform APIs** (~470): tagged `managed-by:core`, managed by `helmcharts/edbb/charts/kong-apis/`
- **Addon APIs** (~31): tagged `managed-by:discussion-forum`, managed by `addons/discussion-forum/helmcharts/`

**Two-phase sync in `kong_apis.py`**:
1. **CREATE/UPDATE**: fetches ALL services from Kong (so cross-tag references resolve)
2. **DELETE**: fetches ONLY services matching the current `--managed-by` tag (so each chart only deletes its own)

Key modified files: `scripts/kong-api-scripts/common.py` (tag filtering), `scripts/kong-api-scripts/kong_apis.py` (CLI param).

See `/docs/IMPLEMENTATION_SUMMARY.md` for full technical details.

### Learning Path (`/Learn`, `/Z!_learn-path`)

Weeks 1–7 of a 12-week backend curriculum. Each week builds on the last:
- Week 3: Basic FastAPI
- Week 4: Pydantic / request bodies
- Week 5: PostgreSQL + SQLAlchemy (includes a full Todo API with frontend)
- Week 6–7: Advanced DB patterns, auth/security

## Environment

Local dev uses `.env` files (see `task-manager/.env` and `Learn/week5/todoapi/.env`). Required env vars include database connection strings. Set `ENV_NAME` and `CLOUD_PROVIDER` for Kubernetes/Kong deployment scripts.
