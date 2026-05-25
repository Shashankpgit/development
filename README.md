# Personal Vault

A multi-user private storage application for notes and passwords.
Built progressively across 13 phases as a full-stack learning project.

---

## Project structure

```
development/
├── vault/
│   ├── backend/            ← FastAPI backend (Python)
│   └── frontend/           ← React + Vite frontend
├── docs/                   ← planning docs, KT docs, API reference
├── claude-instructions/    ← phase-by-phase implementation playbooks
└── README.md               ← this file
```

---

## Prerequisites

- Python 3.11+
- Node.js 18+
- Docker (for PostgreSQL)

---

## First-time setup

### Backend

```bash
# 1. Enter the backend directory
cd development/vault/backend

# 2. Create and activate the virtual environment
python3 -m venv .venv
source .venv/bin/activate

# 3. Install dependencies
python3 -m pip install -r requirements.txt

# 4. Copy the environment file
cp .env.example .env
```

Now generate the required secret values and paste them into `.env`:

```bash
# Generate SECRET_KEY (used to sign JWT tokens)
python3 -c "import secrets; print(secrets.token_hex(32))"

# Generate VAULT_ENCRYPTION_KEY (used to encrypt stored passwords)
python3 -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
```

Your `.env` should look like this when filled in:

```
APP_ENV=development
DATABASE_URL=postgresql://vault_user:vault_pass@localhost:5432/vault
SECRET_KEY=<output of first command>
VAULT_ENCRYPTION_KEY=<output of second command>
CORS_ORIGINS=http://localhost:5173
```

### Docker Compose env (for running with docker-compose)

```bash
cd development/vault
cp .env.example .env
# values are already filled — change only if you want different credentials
```

### Frontend

```bash
# 1. Enter the frontend directory
cd development/vault/frontend

# 2. Install dependencies
npm install

# 3. Copy the environment file
cp .env.example .env
# VITE_API_URL=http://localhost:8000
```

### Database (PostgreSQL via Docker)

```bash
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

# 2. Start the backend
cd vault/backend
source .venv/bin/activate
python3 -m uvicorn app.main:app --reload

# 3. In a separate terminal — start the frontend
cd vault/frontend
npm run dev
```

---

## Stopping everything

```bash
# Stop the backend server
Ctrl+C

# Stop the frontend dev server
Ctrl+C

# Stop the database container (data is preserved)
docker stop vault-db
```

---

## Useful URLs (while everything is running)

| URL | What it is |
|---|---|
| `http://localhost:5173` | React frontend (Vite dev server) |
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

# Install new frontend dependencies after pulling changes
npm install
```

---

## Current phase

**Phase 6 complete** — backend and PostgreSQL containerized with Docker. Run the full stack with `docker-compose up --build` from `vault/`.

See `docs/` for planning documents and KT notes.
See `docs/api/` for API reference.
