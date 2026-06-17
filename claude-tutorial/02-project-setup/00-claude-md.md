# Claude Mastery — 06: CLAUDE.md — Your Project's Permanent Instructions

> **Last updated:** June 17, 2026
> **Covers:** CLAUDE.md structure, what to put in it, examples for different project types, inheritance

**20-minute read. CLAUDE.md is the single most impactful thing you can set up. It transforms Claude from a generic assistant to a project-aware partner.**

---

## What CLAUDE.md Is

`CLAUDE.md` is a Markdown file you put in your project root. Claude Code reads it at the start of every session and after every `/clear`. It's permanent project context.

Without CLAUDE.md:
```
Session 1: "This is a Node.js app with PostgreSQL..."
Session 2: "This is a Node.js app with PostgreSQL..." (re-explaining everything)
Session 3: "This is a Node.js app with PostgreSQL..." (again)
```

With CLAUDE.md:
```
Session 1: "Fix the auth bug"  [Claude already knows your stack]
Session 2: "Deploy to staging" [Claude already knows the deploy process]
Session 3: "Review this PR"    [Claude already knows your conventions]
```

---

## Quick Start: `/init`

The fastest way to create a good CLAUDE.md:

```bash
cd your-project
claude
> /init
```

Claude reads your entire project and generates a CLAUDE.md automatically. Then you refine it.

---

## CLAUDE.md File Locations

```
your-project/
├── CLAUDE.md          ← PRIMARY: loaded for every session in this project
├── src/
│   └── CLAUDE.md      ← loaded when Claude works on files under src/
├── backend/
│   └── CLAUDE.md      ← loaded for backend-specific context
└── frontend/
    └── CLAUDE.md      ← loaded for frontend-specific context
```

Claude reads all relevant CLAUDE.md files based on which files it's working with. For a monorepo, sub-directory CLAUDE.md files give focused context.

There's also a global CLAUDE.md:
```
~/.claude/CLAUDE.md    ← your PERSONAL global instructions (all projects)
```

Use the global one for:
- Your personal preferences (e.g., "always explain security implications")
- Your identity (e.g., "I'm a senior DevOps engineer")
- Universal behaviors you want everywhere

---

## What to Put in CLAUDE.md

This is the most important section. Here's what matters:

### 1. Project Description (1-2 paragraphs)
What does the project do? Who uses it? What's the current state?

### 2. Tech Stack
Specific versions, not just technologies. "Node.js 20.11, Express 4.18, PostgreSQL 15.4, Redis 7.2"

### 3. Architecture Overview
How the parts fit together. A brief diagram in ASCII or a bullet list.

### 4. Common Commands
The commands Claude will need to run. Tests, builds, deployments.

### 5. Key Conventions
Your team's specific patterns — naming conventions, file structure rules, coding style.

### 6. Important Constraints
What NOT to do. Dependencies to not upgrade. Patterns to avoid. Files to not touch.

### 7. Current State / Active Work
What's being worked on right now. Active bugs, in-progress features.

---

## Complete CLAUDE.md Example — DevOps Project

```markdown
# vault-app — DevOps CLAUDE.md

## Project Overview
Vault is a team password manager. Multi-user, web-based.
Backend: Node.js API. Frontend: React SPA.
Currently in production serving 50 users.

## Architecture
```
Users → Cloudflare → AWS ALB → Nginx Ingress (EKS)
                              ├── vault-api (3 replicas, port 3000)
                              └── vault-frontend (2 replicas, port 80)

vault-api → PostgreSQL (RDS, private subnet)
vault-api → Redis (ElastiCache, sessions)
```

## Tech Stack
- **Runtime:** Node.js 20.11 (LTS)
- **Framework:** Express 4.18
- **Database:** PostgreSQL 15.4 (AWS RDS)
- **Cache:** Redis 7.2 (AWS ElastiCache)
- **Container:** Docker (Dockerfile in root)
- **Orchestration:** Kubernetes 1.29 on AWS EKS
- **Helm:** v3.14, chart in ./helm/vault-app/
- **CI/CD:** GitHub Actions (.github/workflows/)
- **IaC:** Terraform in ./terraform/
- **Monitoring:** Prometheus + Grafana + Loki (in monitoring/ namespace)

## Environments
| Environment | Namespace | Cluster | URL |
|------------|-----------|---------|-----|
| staging | staging | vault-staging-cluster | staging.vault.internal |
| production | production | vault-prod-cluster | vault.sanketika.in |

## Common Commands
```bash
# Development
npm install           # install dependencies
npm run dev           # start dev server (port 3000)
npm test              # run all tests
npm run test:unit     # unit tests only
npm run test:integration  # integration tests (needs DB)
npm run lint          # ESLint
npm run build         # production build

# Docker
docker build -t vault-app .
docker compose up -d  # local stack (app + postgres + redis)
docker compose logs -f vault-api

# Kubernetes (requires kubectl context set to correct cluster)
kubectl get pods -n production
kubectl logs -n production deployment/vault-api -f
kubectl rollout status -n production deployment/vault-api

# Helm
helm diff upgrade vault-app ./helm/vault-app/ -n production --values helm/values.production.yaml
helm upgrade vault-app ./helm/vault-app/ -n production --values helm/values.production.yaml --atomic

# Database
psql $DATABASE_URL -c "SELECT 1"   # test connection
npm run db:migrate                 # run pending migrations
npm run db:rollback                # rollback last migration
```

## File Structure
```
vault-app/
├── src/
│   ├── api/          # Express routes
│   ├── services/     # Business logic
│   ├── models/       # Database models (Knex.js)
│   ├── middleware/   # Auth, validation, logging
│   └── utils/        # Helpers
├── tests/
│   ├── unit/
│   └── integration/
├── helm/vault-app/   # Helm chart
├── terraform/        # Infrastructure as code
├── .github/workflows/# CI/CD
└── docker-compose.yml# Local development
```

## Conventions
- **Naming:** kebab-case for files, camelCase for variables, PascalCase for classes
- **API routes:** RESTful, versioned under /api/v1/
- **Error handling:** Use AppError class (src/utils/error.js), HTTP status codes
- **Logging:** Winston logger in src/utils/logger.js — always use this, not console.log
- **Database:** Knex.js query builder — NO raw SQL except for complex aggregations
- **Auth:** JWT tokens — 24hr expiry. Token validation in src/middleware/auth.js
- **Secrets:** From environment variables — NEVER hardcode. See .env.example for required vars.
- **Migrations:** Always create reversible migrations with both up() and down()

## Important Constraints
- **DO NOT upgrade knex.js** — we're on 2.5.1, 3.x has breaking changes we haven't addressed
- **DO NOT touch the audit_log table** — compliance requirement, schema is locked
- **DO NOT use `console.log`** — always use the Winston logger
- **DO NOT edit values.production.yaml** without review — changes deploy to production
- **Database migrations must be backward-compatible** — we do rolling deploys

## AWS Context
- Region: ap-south-1
- Account: 123456789 (DO NOT share this)
- IAM role for deploys: arn:aws:iam::123456789:role/github-actions-vault-deploy
- ECR registry: 123456789.dkr.ecr.ap-south-1.amazonaws.com/vault-app

## Current State (June 2026)
- Active: migrating from sessions to JWT (branch: feature/jwt-auth)
- Known issue: connection pool exhaustion under load (tracked in issue #234)
- Upcoming: PostgreSQL upgrade to 16.x (scheduled July 2026)
- Tech debt: middleware tests are sparse — new middleware MUST include tests
```

---

## CLAUDE.md for a Frontend Project

```markdown
# vault-frontend — CLAUDE.md

## Project
React SPA for the Vault password manager.
Built with React 18, TypeScript, Tailwind CSS.
Deployed as a Docker container served by Nginx.

## Commands
```bash
npm install
npm run dev           # Vite dev server, port 5173
npm run build         # production build to ./dist/
npm test              # Vitest
npm run type-check    # TypeScript type checking
npm run lint          # ESLint + Prettier check
npm run storybook     # Component stories, port 6006
```

## Architecture
- **Router:** React Router v6 (file-based routing in src/pages/)
- **State:** Zustand stores in src/stores/
- **API calls:** React Query + custom hooks in src/hooks/
- **Forms:** React Hook Form + Zod validation
- **UI:** Tailwind CSS + shadcn/ui components
- **Icons:** Lucide React

## Conventions
- Components: PascalCase, one per file
- Hooks: camelCase starting with 'use', in src/hooks/
- Types: defined in src/types/, never inline complex types
- No `any` — TypeScript strict mode is on
- CSS: Tailwind utility classes only, no custom CSS files except globals.css

## Key Files
- src/App.tsx — root component and router setup
- src/stores/authStore.ts — auth state (JWT token, user info)
- src/hooks/useApi.ts — base API hook
- src/components/ui/ — reusable UI components (don't modify directly — upgrade via shadcn)
```

---

## CLAUDE.md Inheritance and Multi-Repo

### Monorepo: Sub-directory CLAUDE.md Files

```
monorepo/
├── CLAUDE.md          ← shared: company conventions, repo structure
├── backend/
│   └── CLAUDE.md      ← backend-specific: DB, API, Node.js conventions
├── frontend/
│   └── CLAUDE.md      ← frontend-specific: React, TypeScript, Tailwind
└── infra/
    └── CLAUDE.md      ← infra-specific: Terraform, K8s, Helm patterns
```

When Claude works on backend files, it reads both the root CLAUDE.md AND backend/CLAUDE.md.

---

## Tips for a Great CLAUDE.md

**What makes a CLAUDE.md excellent:**
- Specific versions, not just technologies ("PostgreSQL 15.4" not "PostgreSQL")
- Exact command syntax you actually use
- The WHY behind constraints ("DO NOT upgrade knex — 3.x has breaking changes")
- Current state (what's in progress, what's broken)
- What Claude will get WRONG without guidance

**What makes a CLAUDE.md bad:**
- Generic descriptions that apply to any project ("We use best practices")
- Missing commands — Claude has to guess how to test/build
- No conventions — Claude makes up its own style
- Out of date — CLAUDE.md that reflects how the project WAS, not IS

**Keep it updated:** When your stack changes, update CLAUDE.md. Treat it like documentation — when you upgrade a major dependency, update the version number in CLAUDE.md.

---

## Common Misunderstanding: "CLAUDE.md is for big projects only"

**The misunderstanding:** "My project is small — I don't need CLAUDE.md."

**The reality:** CLAUDE.md is MORE valuable for smaller projects because you don't have extensive documentation elsewhere. A 3-person startup's vault-app has:
- No architecture docs
- No onboarding guide
- Implicit conventions only the team knows

Without CLAUDE.md, Claude guesses at all of these. A 20-line CLAUDE.md with your commands, stack, and one key constraint eliminates 80% of the "Claude suggested the wrong approach" problems.

A minimal useful CLAUDE.md:
```markdown
# my-app

Node.js 20 + PostgreSQL. Run tests: `npm test`. Build: `npm run build`.
We use camelCase everywhere. No console.log — use logger.js.
Don't modify anything in src/generated/ — auto-generated files.
```

That's 4 lines. Already dramatically better than nothing.

→ Continue to: `01-memory-system.md`
