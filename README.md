# Personal Vault

A multi-user private storage application for notes and passwords.
Built progressively across 13 phases as a full-stack learning project.

---

## Project structure

```
development/
├── vault/                  ← application code
├── docs/                   ← planning docs, KT docs, API reference
├── claude-instructions/    ← phase-by-phase implementation playbooks
└── README.md               ← this file
```

---

## Prerequisites

- Python 3.11+
- Docker (for PostgreSQL)

---

## First-time setup

```bash
# 1. Clone and enter the repo
cd development/vault

# 2. Create and activate the virtual environment
python3 -m venv .venv
source .venv/bin/activate

# 3. Install dependencies
pip install -r requirements.txt

# 4. Copy the environment file and fill in your values
cp .env.example .env
# edit .env with your credentials

# 5. Start the PostgreSQL container
docker run --name vault-db \
  -e POSTGRES_USER=vault_user \
  -e POSTGRES_PASSWORD=vault_pass \
  -e POSTGRES_DB=vault \
  -p 5432:5432 \
  -d postgres:16
```

---

## Daily workflow

Every time you start working on the project:

```bash
# 1. Start the database (if not already running)
docker start vault-db

# 2. Activate the virtual environment
cd vault
source .venv/bin/activate

# 3. Start the server
uvicorn app.main:app --reload
```

---

## Stopping everything

```bash
# Stop the server
Ctrl+C

# Stop the database container (data is preserved)
docker stop vault-db
```

---

## Useful URLs (while server is running)

| URL | What it is |
|---|---|
| `http://localhost:8000/health` | Health check — confirms server + DB are up |
| `http://localhost:8000/docs` | Swagger UI — interactive API explorer |
| `http://localhost:8000/redoc` | ReDoc — alternative API documentation |

---

## Useful commands

```bash
# Check if the database container is running
docker ps --filter name=vault-db

# View database container logs
docker logs vault-db

# Connect directly to PostgreSQL (inspect data)
docker exec -it vault-db psql -U vault_user -d vault

# Inside psql — list tables
\dt

# Inside psql — exit
\q

# Check installed Python packages
pip list

# Install new dependencies after pulling changes
pip install -r requirements.txt
```

---

## Current phase

**Phase 1 complete** — project setup, first API endpoint, PostgreSQL connection.

See `docs/` for planning documents and KT notes.
See `docs/api/` for API reference.
