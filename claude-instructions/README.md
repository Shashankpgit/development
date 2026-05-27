# Claude Master Instructions — Personal Vault Project

This file is Claude's primary reference document. Read this at the start of every session before doing anything.

---

## Application: Personal Vault

A multi-user, private data storage application. Users register, log in, and store their own private data that no other user can see.

### What a user can do
- Register with a username and password
- Log in via Keycloak SSO
- Store **text notes** (title + body)
- Store **passwords** (label + username + password value, encrypted at rest)
- View, edit, and delete only their own data

### Real-world analogy
A self-hosted combination of Bitwarden (password manager) and a private notebook. Bob logs in and sees only Bob's data. Alice logs in and sees only Alice's data.

---

## ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
## STAGE 1 — DEVELOPMENT (COMPLETE ✓)
## ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Phases 1 through 9.5 are complete. The application is built and running in production on a real VM.

### What was built
| Version | Scope | Phase |
|---|---|---|
| v1 | FastAPI + PostgreSQL, no auth | 1–2 |
| v2 | React frontend | 3 |
| v3 | JWT auth + CORS | 4 |
| v4 | Service + Repository architecture | 5 |
| v5 | Docker + docker-compose | 6 |
| v6 | Nginx reverse proxy | 7 |
| v7 | Kong API gateway | 8 |
| v8 | Keycloak SSO | 9 |
| v8.5 | VM + real domain + HTTPS (Let's Encrypt) | 9.5 |

### Current running state
- **URL**: `https://vaultpraja.duckdns.org`
- **VM**: GCP `8.231.93.159`
- **Deployment**: `docker compose up -d` on the VM
- **Stack**: nginx (TLS termination) → Kong (JWT verify + rate limit) → FastAPI → PostgreSQL; Keycloak for auth

### Development stack
| Layer | Technology |
|---|---|
| Language | Python 3.11+ |
| API Framework | FastAPI |
| Database | PostgreSQL |
| ORM | SQLAlchemy 2.x |
| Auth | Keycloak (OIDC, Authorization Code Flow) |
| Frontend | React 18 + Vite |
| Container | Docker + docker-compose |
| Reverse Proxy | Nginx |
| API Gateway | Kong |

---

## ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
## STAGE 2 — DEVOPS (CURRENT → Phase 10+)
## ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

The application works. Now the focus shifts to how it is deployed, managed, scaled, and observed in production — the DevOps layer.

The same learn-by-doing philosophy applies. Every DevOps concept is taught by applying it to the Vault app.

### DevOps roadmap

```
Phase 10 → K8s concepts (KT only — architecture, objects, kubectl basics)
Phase 11 → GitHub Actions: KT + write workflow to auto-build + push images to GHCR
Phase 12 → Helm charts: write app charts locally, configure community charts for infra
Phase 13 → Deploy to GKE: full stack on real cluster with HTTPS via cert-manager
Phase 14 → CI/CD: extend GitHub Actions to auto-deploy via helm upgrade on push
Phase 15 → Monitoring: Prometheus + Grafana + structured logging
```

### Key principles

**1. All automation lives in `vault-automation/`**
Never run raw `helm install` or `kubectl apply` commands manually.
Everything is a file — reviewed, committed, version-controlled.

```
vault-automation/
├── helm/vault-api/        ← YOUR chart for FastAPI backend
├── helm/vault-frontend/   ← YOUR chart for React frontend
├── helm/vault/            ← umbrella chart (ties everything together)
├── helm/values/           ← values files for community charts
└── k8s/                   ← raw K8s manifests (namespace etc.)
```

**2. Community charts for infra, custom charts for your code**
You don't write PostgreSQL, Keycloak, or Kong manifests from scratch.
Community Helm charts exist. You configure them via values files in `helm/values/`.

```
Community charts (configure only):     Your charts (you write):
  bitnami/postgresql                     vault-automation/helm/vault-api/
  bitnami/keycloak                       vault-automation/helm/vault-frontend/
  kong/kong
  ingress-nginx/ingress-nginx
  cert-manager/cert-manager
```

**3. GitHub Actions builds images — you don't build manually**
Every push to `vault/backend/` or `vault/frontend/` triggers a GitHub Actions workflow
that builds the Docker image and pushes it to GHCR automatically.

### DevOps stack being added
| Tool | Purpose |
|---|---|
| Kubernetes (minikube) | Container orchestration — run the app across pods, self-heal, scale |
| kubectl | CLI for Kubernetes |
| Helm | Package manager for Kubernetes — template manifests for different environments |
| GitHub Container Registry (ghcr.io) | Store and version Docker images |
| GitHub Actions | CI/CD pipeline — test, build, push, deploy on every commit |
| cert-manager | Automated TLS certificate issuance from Let's Encrypt (GKE only) |
| GKE | Google managed Kubernetes — production cluster |
| Prometheus | Metrics collection — scrapes app and infra metrics |
| Grafana | Metrics visualization — dashboards and alerting |

---

## Non-Negotiable Process Rules (apply to ALL phases)

Claude MUST follow these in every session without exception.

### Rule 1 — Docs before code
Create `docs/NNN-*.md` first. Every doc has two parts:
- **Part 1**: What we are doing — files, steps, scope
- **Part 2**: Concepts / KT — why each tool/pattern exists, plain language, short examples

### Rule 2 — Explain WHY before implementing
Not "we are adding X" but "we are adding X because Y problem exists."

### Rule 3 — One small step at a time
Break phases into the smallest logical steps. K8s = 3 separate steps, not 1.

### Rule 4 — Teach during implementation
Concept appears in code → explain it then. Do not dump theory upfront.

### Rule 5 — Never skip a phase
Every phase has a learning purpose. Respect the sequence.

### Rule 6 — Real engineering practices always
Environment variables, proper naming, no secrets in code, meaningful error handling, git commits after logical steps.

### Rule 7 — KT docs on demand
User says "I don't understand" or "create KT document" → create `docs/kt/NN-KT-topic.md` immediately.

### Rule 8 — Deliberate mistakes
At appropriate moments, intentionally introduce a common real-world mistake. Always tell the user: **"This is a deliberate mistake — let's debug it."** Full walkthrough before fixing.

---

## DevOps-Specific Process Rules

These extend the general rules for the DevOps phase.

### Rule D1 — Start local, then cloud
Learn K8s locally with k3d before touching any cloud cluster. Same with Helm, CI/CD. Understand the tool before paying for managed services.

### Rule D2 — Infra changes are also code
Every K8s manifest, Helm value, and workflow file is code. Same standards: reviewed, committed, documented.

### Rule D3 — Teach operational thinking
For every component deployed to K8s: what happens if it crashes? How does it restart? Who monitors it? These questions must be answered during the phase, not after.

### Rule D4 — Keep docker-compose working
docker-compose remains the local dev environment throughout all DevOps phases. K8s is for production-like deployment, not local dev. Never break docker-compose.

### Rule D5 — One manifest at a time
When converting docker-compose to K8s, do it one service at a time. Get the API running in K8s before touching the database.

---

## Folder Structure

```
development/                        ← git repo root
├── claude-instructions/            ← Claude's playbooks (this directory)
│   ├── README.md                   ← this file
│   ├── debugging-philosophy.md     ← error handling + deliberate mistakes
│   ├── phase-1/ to phase-9.5/      ← COMPLETE — development phases
│   ├── phase-10/                   ← K8s concepts + minikube setup
│   ├── phase-11/                   ← Container Registry (GHCR)
│   ├── phase-12/                   ← Helm charts
│   ├── phase-13/                   ← Deploy to minikube (local, HTTP)
│   ├── phase-14/                   ← CI/CD (GitHub Actions)
│   ├── phase-15/                   ← Deploy to GKE (production, TLS)
│   └── phase-16/                   ← Monitoring (Prometheus + Grafana)
├── docs/
│   ├── plans/                      ← phase planning documents (NNN-*-plan.md)
│   ├── kt/                         ← KT knowledge transfer documents
│   ├── api/                        ← API reference docs
│   └── react/                      ← React learning docs
├── goal.md                         ← learning goals and mentorship rules
└── vault/                          ← the application
    ├── backend/                    ← FastAPI (Python)
    ├── frontend/                   ← React + Vite
    ├── nginx/                      ← nginx config + Dockerfile
    ├── kong/                       ← kong.yml (declarative config)
    ├── keycloak/                   ← realm export + custom theme
    ├── k8s/                        ← Kubernetes manifests (Phase 10)
    ├── helm/                       ← Helm chart (Phase 11)
    └── docker-compose.yml          ← local dev (NEVER remove)
```

---

## Reference Files

- `goal.md` — full learning goal and mentorship instructions
- `claude-instructions/debugging-philosophy.md` — **READ THIS** for error handling and deliberate mistakes
- `claude-instructions/phase-*/` — per-phase implementation playbooks
- `docs/` — all planning docs and KT documents
