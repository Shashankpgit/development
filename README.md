# Nimbus Store — full-stack CRUD app + its deployment automation

A learning repo in two halves:

- **`development/`** — the application: FastAPI backend, React frontend
- **`automation/`** — how it gets deployed: Docker, Helm, Kubernetes

The app exists to give the automation half something real to operate.

```
development/                       <- repo root
├── docs/                          <- all documentation (never mixed with code)
│   ├── 001-crud-shop-app.md       <- the app: design + concepts
│   ├── 002-containers-and-helm.md <- containers, charts, EKS
│   ├── 003-minikube-deployment-and-debugging.md
│   ├── 004-eks-infrastructure.md  <- OpenTofu/Terragrunt for EKS
│   └── api/                       <- endpoint reference, one file per resource
├── development/
│   ├── back-end/                  <- FastAPI + SQLAlchemy + PostgreSQL
│   └── front-end/                 <- React (Vite), served by nginx
└── automation/
    ├── deploy-minikube.sh         <- build images + install all three releases
    ├── helmcharts/
    │   ├── postgresql/            <- vendored Bitnami chart (PostgreSQL 18.6)
    │   ├── shop-api/              <- backend chart
    │   ├── shop-web/              <- frontend chart
    │   └── values/                <- per-environment values files
    ├── test/smoke-test.sh         <- all 24 endpoints, end to end
    └── infra/                     <- OpenTofu + Terragrunt: VPC + EKS
        ├── modules/{network,eks}/
        ├── _common/               <- module wiring
        ├── dev/                   <- one environment
        └── provision.sh / destroy.sh
```

## What it does

Five resources — **products, categories, users, cart, orders** — with full CRUD,
24 endpoints in total, all reachable from the UI. See
[`docs/api/`](./docs/api/) for the endpoint reference.

## Run it on Kubernetes (local)

```bash
minikube start
./automation/deploy-minikube.sh
kubectl port-forward -n shop svc/shop-web 8080:80
# http://localhost:8080
```

Verify:

```bash
./automation/test/smoke-test.sh shop     # 53 checks
```

## Run it on EKS

```bash
cd automation/infra
./create_tf_backend.sh dev     # once per account; writes tf.sh
./provision.sh dev --plan      # review first
./provision.sh dev             # ~15 min
```

~$0.115/hr while running (1 node). The EKS control plane is $0.10/hr with no
free tier — about 87% of that — so:

```bash
./scale.sh dev 0     # back tomorrow: keeps cluster, releases and data (~$74/mo)
./destroy.sh dev     # done for a while: the only real saving (~$0/mo)
```

Details and full cost breakdown: [`docs/004`](./docs/004-eks-infrastructure.md).

Images come from Docker Hub: `shashank04515/shop-api:1.0.1`,
`shashank04515/shop-web:1.0.0`.

## Run it locally, without Kubernetes

```bash
# backend  ->  http://localhost:8000/docs
cd development/back-end
python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
cp .env.example .env                     # edit DATABASE_URL
.venv/bin/python -m app.seed             # demo data
.venv/bin/uvicorn app.main:app --reload --port 8000

# frontend ->  http://localhost:5173
cd development/front-end
npm install && npm run dev
```

## Stack

| Layer | Choice | Why |
|---|---|---|
| Backend | FastAPI + Pydantic | Type hints double as validation and API docs |
| ORM | SQLAlchemy 2.0 | Python objects instead of SQL strings |
| Database | PostgreSQL 18 (psycopg3) | Enforces the constraints the schema declares |
| Frontend | React 19 + Vite | Fast builds, hashed immutable assets |
| Routing | react-router 7 | Client-side routes, no page reloads |
| Serving | nginx (unprivileged) | Static files + reverse proxy for `/api` |
| Packaging | Docker, multi-stage | 279MB api, 74MB web |
| Deployment | Helm, 3 separate releases | Independent upgrades and rollbacks |
| Infra | OpenTofu + Terragrunt | VPC + EKS, no NAT, no ALB — cost-conscious |

## Documentation

Start with [`docs/001-crud-shop-app.md`](./docs/001-crud-shop-app.md).
Every doc has two sections: *What we are doing* and *Concepts / KT*.

[`docs/003`](./docs/003-minikube-deployment-and-debugging.md) is the most useful
one to read second — it walks through the two real bugs the first Kubernetes
deploy exposed, and how each was tracked down.
