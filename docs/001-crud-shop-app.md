# 001 — CRUD Shop App (Products, Categories, Users, Cart, Orders)

## What we are doing

Building a small but complete e-commerce CRUD application, so that the
`automation/` half of this repo has something real to containerise, deploy and
operate.

### Layout

```
development/                 <- repo root (git)
├── docs/                    <- these documents (never mixed with code)
│   ├── 001-crud-shop-app.md
│   ├── 002-containers-and-helm.md
│   └── api/                 <- one file per resource
├── development/             <- application code
│   ├── back-end/            <- FastAPI + SQLAlchemy + PostgreSQL
│   └── front-end/           <- React (Vite) + nginx
└── automation/
    ├── deploy-minikube.sh   <- builds images + installs all three releases
    ├── helmcharts/
    │   ├── postgresql/      <- vendored Bitnami chart (PostgreSQL 18.6)
    │   ├── shop-api/        <- backend chart
    │   ├── shop-web/        <- frontend chart
    │   └── values/          <- per-environment values files
    ├── test/smoke-test.sh   <- all 24 endpoints, through nginx
    └── infra/               <- (empty) Terraform / EKS cluster provisioning
```

Three separate Helm releases, not one umbrella chart — see
[`docs/002`](./002-containers-and-helm.md#three-charts-not-one) for why.

### Backend files and why each exists

| File | Responsibility |
|---|---|
| `app/config.py` | Reads every setting from environment variables |
| `app/database.py` | One engine, one connection pool, one session-per-request |
| `app/models.py` | The 6 tables, as Python classes |
| `app/schemas.py` | What the HTTP API accepts and returns |
| `app/routers/*.py` | One file per resource — the 24 endpoints |
| `app/main.py` | Assembles the app, CORS, health probes |
| `app/seed.py` | Demo data so the UI is not empty on first run |

### The 6 tables

```
categories ──┐
             ├──< products >──┬──< cart_items >── users
             │                └──< order_items >── orders >── users
```

- `cart_items` — one row per (user, product). There is no `carts` table: a cart
  *is* the set of cart items belonging to a user.
- `order_items` — stores a **copy** of the product name and price. Prices
  change; an invoice must not silently change with them.

### Endpoints — all 24, as specified

| Resource | Endpoints |
|---|---|
| Products | `POST /api/products` · `GET /api/products` · `GET /api/products/{id}` · `PUT /api/products/{id}` · `DELETE /api/products/{id}` |
| Categories | `POST /api/categories` · `GET /api/categories` · `GET /api/categories/{id}` · `PUT /api/categories/{id}` · `DELETE /api/categories/{id}` |
| Users | `POST /api/users` · `GET /api/users` · `GET /api/users/{id}` · `PUT /api/users/{id}` · `DELETE /api/users/{id}` |
| Cart | `POST /api/cart/items` · `GET /api/cart/{userId}` · `PUT /api/cart/items/{id}` · `DELETE /api/cart/items/{id}` |
| Orders | `POST /api/orders` · `GET /api/orders` · `GET /api/orders/{id}` · `PUT /api/orders/{id}` · `DELETE /api/orders/{id}` |

Plus two operational endpoints that Kubernetes needs: `GET /health` and
`GET /health/ready`.

Full request/response detail per resource lives in [`docs/api/`](./api/).

### Frontend pages

| Route | Page | What it exercises |
|---|---|---|
| `/` | Storefront — hero, search, filter, sort, add-to-cart | `GET /api/products`, `POST /api/cart/items` |
| `/cart` | Cart — quantity changes, checkout | all 4 cart endpoints, `POST /api/orders` |
| `/orders` | Order history — advance status, cancel | `GET/PUT/DELETE /api/orders` |
| `/admin/products` | Product CRUD table | all 5 product endpoints |
| `/admin/categories` | Category CRUD table | all 5 category endpoints |
| `/admin/users` | User CRUD table | all 5 user endpoints |

Every endpoint you asked for is reachable from the UI.

### Running it locally

```bash
# --- backend -------------------------------------------------------------
cd development/back-end
cp .env.example .env                 # then edit DATABASE_URL
# (or point it at the minikube Postgres:
#   kubectl port-forward -n shop svc/shop-db-postgresql 5432:5432)
.venv/bin/python -m app.seed         # optional: demo data
.venv/bin/uvicorn app.main:app --reload --port 8000
# interactive API docs: http://localhost:8000/docs

# --- frontend ------------------------------------------------------------
cd development/front-end
npm run dev                          # http://localhost:5173
```

### Postman

Per our process: **you** build the collection inside Postman and export it to
`development/back-end/postman/`. Hand-written collection JSON is not
maintainable. Start from `http://localhost:8000/openapi.json` — Postman can
import that file directly and generate all 24 requests for you.

---

## Concepts / KT

**FastAPI** — a Python web framework that reads your type hints and, from them,
validates incoming JSON, serialises outgoing JSON, and generates interactive API
docs at `/docs`. The type hints are not decoration; they are the implementation.

**Pydantic** — the validation library FastAPI uses. A Pydantic model declares
the shape of data; anything that does not fit is rejected with a `422` and a
per-field explanation, before your code runs.

**SQLAlchemy ORM** — maps Python classes to SQL tables. `db.get(Product, 3)`
becomes `SELECT * FROM products WHERE id = 3`. You get Python objects instead
of tuples, and you never build SQL strings by hand (which is also how SQL
injection is avoided).

**Session** — one short-lived conversation with the database, roughly one per
HTTP request. Changes you make are staged in memory and only written when you
`commit()`. That is what makes "create the order, decrement stock, empty the
cart" all-or-nothing.

**Connection pool** — opening a TCP connection to Postgres costs milliseconds,
so SQLAlchemy keeps a set of them open and lends them out. `pool_size=5` with
10 pods means up to 50 connections against Postgres's default limit of 100 —
arithmetic worth doing before you scale up.

**Dependency injection (`Depends`)** — FastAPI supplies arguments your endpoint
declares. `db: Session = Depends(get_db)` means "hand me a session, and close
it when the response is sent" without any boilerplate in the endpoint.

**HTTP status codes as a language** —
`200` fine · `201` created · `204` done, nothing to say ·
`400` your request is wrong · `404` no such id ·
`409` valid request, conflicts with reality (duplicate email, out of stock) ·
`422` your JSON does not fit the schema · `500` our bug · `503` a dependency is down.

**PUT vs PATCH** — strictly, PUT replaces the whole resource and PATCH changes
some fields. This API accepts partial bodies on PUT because it is far easier to
drive from a UI. `exclude_unset=True` in the routers is what makes that safe:
it distinguishes "field not sent" from "field explicitly set to null".

**Soft delete** — `DELETE /api/orders/{id}` does not remove the row; it sets
`status = "cancelled"` and returns the stock. Orders are financial history.
This is the one deliberate deviation from textbook REST in the app, which is
why that endpoint returns `200` and a body rather than `204`.

**React** — a JavaScript library that builds the page in the browser. The HTML
file the server sends contains one empty `<div id="root">`; React fills it in.
This is why "view source" shows almost nothing.

**Component** — a function that returns markup. `<Storefront />` calls that
function. Components nest, which is how a page is assembled from parts.

**State (`useState`)** — data a component remembers between renders. Changing
state via its setter re-runs the component and updates the screen. Assigning
directly to a variable does not, which is the most common beginner bug.

**Effect (`useEffect`)** — code that runs *after* rendering, for things that are
not rendering: fetching data, adding event listeners, timers. Its dependency
array controls when it re-runs.

**Context** — shared state any component can read without it being passed down
through every intermediate component ("prop drilling"). Here it holds the
selected user, the cart count and the toasts.

**Vite** — the build tool. In development it serves your files instantly and
hot-reloads on save. For production, `npm run build` bundles everything into a
few hashed static files in `dist/`.

**CORS** — a *browser* rule. JavaScript loaded from `localhost:5173` may not
read a response from `localhost:8000`, because host+port make them different
origins. The browser asks permission first (an `OPTIONS` preflight) and
`CORSMiddleware` answers. curl and Postman ignore CORS entirely — which is why
an endpoint can work perfectly in Postman and fail in the browser.

**The dev proxy** — instead of relying on CORS, `vite.config.js` forwards
`/api/*` from the dev server to `:8000`. The browser only ever sees one origin,
so the question never arises. nginx does exactly the same thing in production,
which is why no frontend file contains a backend hostname.

**Liveness vs readiness** — two different questions.
*Liveness* ("is the process wedged?") failing **restarts** the pod, so it must
not check the database — a DB blip would crash-loop every pod.
*Readiness* ("can it serve traffic now?") failing only removes the pod from
the load balancer, so that is where the DB check belongs.
