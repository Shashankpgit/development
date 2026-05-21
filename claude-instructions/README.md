# Claude Master Instructions — Personal Vault Project

This file is Claude's primary reference document. Read this at the start of every session before doing anything.

---

## Application: Personal Vault

A multi-user, private data storage application. Users register, log in, and store their own private data that no other user can see.

### What a user can do
- Register with a username and password
- Log in and receive a session token
- Store **text notes** (title + body)
- Store **passwords** (label + username + password value)
- Store **important notes** (tagged, searchable)
- View, edit, and delete only their own data

### Real-world analogy
Think of it as a personal, self-hosted combination of Bitwarden (password manager) and a private notebook. Bob logs in and sees only Bob's data. Alice logs in and sees only Alice's data.

---

## Version Strategy

| Version | Scope | Phases |
|---|---|---|
| v1 | API only, SQLite, no authentication | Phase 1–2 |
| v2 | Authentication added, multi-user, PostgreSQL | Phase 3–4 |
| v3 | Minimal frontend, DevTools learning | Phase 3 |
| v4 | Architecture refactor (service + repo layers) | Phase 5 |
| v5 | Containerized, Dockerized | Phase 6 |
| v6 | Nginx reverse proxy | Phase 7 |
| v7 | Kong API gateway | Phase 8 |
| v8 | Keycloak SSO replaces custom JWT | Phase 9 |
| v9 | Kubernetes deployment | Phase 10 |
| v10 | Helm charts | Phase 11 |
| v11 | CI/CD pipeline | Phase 12 |
| v12 | Monitoring and logging | Phase 13 |

---

## Tech Stack

| Layer | Choice | Reason |
|---|---|---|
| Language | Python 3.11+ | User has prior Python knowledge |
| API Framework | FastAPI | User knows basics; auto-docs at /docs; async |
| Database (v1) | SQLite | Zero setup; perfect for learning |
| Database (v2+) | PostgreSQL | Production-grade; migrate before Docker |
| ORM | SQLAlchemy 2.x | Industry standard; works with both DBs |
| Migrations | Alembic | Tracks schema changes like git does for code |
| Auth | Custom JWT first, then Keycloak | Learn JWT internals before enterprise SSO |
| Frontend | Plain HTML + vanilla JS (no framework) | Learn fundamentals before React |
| Container | Docker + docker-compose | Learn containers before Kubernetes |
| Reverse Proxy | Nginx | Industry standard reverse proxy |
| API Gateway | Kong | Real-world API management layer |
| Orchestration | Kubernetes | After Docker fundamentals are solid |
| Package manager | pip + requirements.txt → Poetry | Start simple, evolve tooling |

---

## Phase Roadmap

```
Phase 1  → Project setup + first API endpoint + database connection
Phase 2  → Full CRUD: notes, passwords, user model (no auth yet)
Phase 3  → Minimal HTML frontend + Chrome DevTools introduction
Phase 4  → CORS + JWT authentication + auth middleware
Phase 5  → Service layer + Repository pattern (architecture refactor)
Phase 6  → Docker + docker-compose
Phase 7  → Nginx reverse proxy
Phase 8  → Kong API gateway
Phase 9  → Keycloak (replace custom JWT)
Phase 10 → Kubernetes (pods, deployments, services)
Phase 11 → Helm charts
Phase 12 → GitHub Actions CI/CD
Phase 13 → Prometheus + Grafana + structured logging
```

---

## Non-Negotiable Process Rules

Claude MUST follow these rules in every session without exception.

### Rule 1 — Docs structure
Every `docs/NNN-*.md` file must have exactly two parts:

**Part 1: What we are doing** — files being created/modified, implementation steps, what is NOT in scope for this step.

**Part 2: Concepts / KT** — short explanation of every tool, pattern, or technology used in this step. Not a textbook. Just enough to understand why it exists and what role it plays. Written in plain language with short examples.

### Rule 2 — Explain WHY first
Before implementing, explain the business reason and technical reason. Not just "we are adding X" but "we are adding X because Y problem exists."

### Rule 3 — One small step at a time
Never implement an entire feature in one shot. Break it into the smallest logical steps. Example: adding auth = 6 separate steps, not 1.

### Rule 4 — Teach during implementation
When a concept appears in code, explain it inline. Do not dump theory upfront. JWT appears in code → explain JWT then.

### Rule 5 — Never skip a phase
Do not jump from Phase 1 to Phase 4. Every phase has a learning purpose. Respect the sequence.

### Rule 6 — Real engineering practices always
Even in v1 (SQLite, no auth), always use:
- Proper folder structure
- Environment variables (never hardcode secrets)
- Consistent naming conventions
- Meaningful error responses
- Git commits after every logical step

### Rule 7 — Frontend is last in each phase
Only build frontend after the backend step in that phase is stable and manually tested via `/docs` (FastAPI's swagger UI).

### Rule 8 — KT docs on demand
If the user says "I don't understand" or "create KT document" — immediately create `docs/KT-topic-name.md` using the structure defined in goal.md.

---

## Folder Structure (target for v1)

```
development/                     ← git repo root
├── claude-instructions/         ← Claude's playbooks (this directory)
├── docs/                        ← all planning + KT documents
├── goal.md                      ← learning goals and mentorship rules
├── README.md
├── .gitignore
└── vault/                       ← the actual application lives here
    ├── app/
    │   ├── main.py              ← FastAPI app entry point
    │   ├── config.py            ← environment + settings
    │   ├── database.py          ← DB engine + session setup
    │   ├── models/              ← SQLAlchemy ORM models
    │   ├── schemas/             ← Pydantic request/response schemas
    │   ├── routers/             ← FastAPI route handlers
    │   ├── services/            ← business logic (added in Phase 5)
    │   └── repositories/        ← DB access layer (added in Phase 5)
    ├── tests/                   ← pytest tests
    ├── .env                     ← local environment variables (gitignored)
    ├── .env.example             ← committed template of env vars
    └── requirements.txt
```

**Rule:** All application code lives inside `vault/`. All docs, plans, and Claude instructions live at the repo root level. Never mix them.

---

## Application Data Models (target)

### User
- id, username (unique), hashed_password, created_at

### Note
- id, user_id (FK), title, body, created_at, updated_at

### Password Entry
- id, user_id (FK), label, username, encrypted_value, created_at

### Tag (future, Phase 2+)
- id, name, user_id

---

## DevTools Learning Goals

The user has never used browser developer tools. These concepts should be taught progressively during Phase 3:
- Network tab: observe HTTP requests, status codes, headers, request/response bodies
- Console tab: JavaScript errors, console.log debugging
- Elements tab: inspect HTML structure
- Application tab: view localStorage, cookies, tokens stored in browser

Tie every DevTools lesson to something that just happened in the app (e.g., "open Network tab and watch what happens when you click Save").

---

## Cloud + Domain Goal

After Phase 6 (Docker), the project will be deployed to a cloud provider (to be decided) with a free domain. This simulates a real production deployment. Claude should keep this in mind when making infrastructure decisions — avoid anything that only works locally.

---

## Reference Files

- `goal.md` — user's full learning goal and mentorship instructions
- `claude-instructions/debugging-philosophy.md` — **READ THIS** for how to handle all errors and deliberate mistakes
- `claude-instructions/phase-*/` — per-phase implementation playbooks
- `docs/` — all feature planning docs and KT documents created during development
