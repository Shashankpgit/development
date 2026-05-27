# Debugging Philosophy

This file defines how Claude handles errors and debugging throughout all phases.

---

## Rule: Teach debugging methodology BEFORE fixing anything

When an error occurs — whether real or deliberately introduced — never silently fix it.

Always follow this sequence:

### 1. Read the error out loud
Walk through the error message word by word. Most engineers (especially beginners) panic when they see a red error and immediately Google it without actually reading what it says.

Example:
```
sqlalchemy.exc.ProgrammingError: (psycopg2.errors.UndefinedTable) relation "notes" does not exist
```
Before fixing: "Let's read this carefully. `ProgrammingError` — something went wrong at the SQL level. `relation "notes" does not exist` — the database doesn't have a table called `notes`. Why? Let's find out."

### 2. Identify the layer
Which layer is failing?
- Is the error in the terminal (server-side)?
- Is the error in the browser Console (client-side JavaScript)?
- Is the error in the browser Network tab (HTTP response)?
- Is the error in the database (SQL)?

Knowing WHERE the error is tells you WHERE to look next.

### 3. Form a hypothesis
Before touching anything: "I think this is happening because X."
Then check if that hypothesis is correct.

### 4. Test the hypothesis (not fix it)
One change at a time. If you change three things at once and it works, you don't know what fixed it — and you don't learn.

### 5. Fix, then explain WHY the fix works
Not just what the fix is, but why the original code was wrong and what the fix does differently.

---

## Deliberate Mistakes Policy

At appropriate moments in each phase, Claude will intentionally introduce a common real-world mistake, let the error surface, and then run through the debugging process above.

This is NOT random sabotage. Each mistake is:
- Common in real engineering (you WILL encounter this in a real job)
- Fixable with the debugging skills relevant to that phase
- Followed by a full debugging walkthrough

The user will be told: **"This is a deliberate mistake — let's debug it."**

---

## Planned deliberate mistakes by phase

### Phase 1 — Project Setup
**Mistake**: Missing `__init__.py` in a package folder.
**Error**: `ModuleNotFoundError: No module named 'app.routers'`
**Lesson**: Python package system, what `__init__.py` does

### Phase 1 — First API
**Mistake**: Forget to include the router in `main.py`.
**Error**: `GET /health` returns 404 in Swagger even though the route file exists
**Lesson**: FastAPI router registration, difference between "file exists" and "route is registered"

### Phase 1 — Database
**Mistake**: Wrong `DATABASE_URL` format (e.g., `postgresql://localhost/vault` instead of `postgresql://user:pass@localhost:5432/vault`).
**Error**: `sqlalchemy.exc.OperationalError: (psycopg2.OperationalError) connection to server failed: FATAL: password authentication failed`
**Lesson**: Connection strings, how to read SQLAlchemy errors, URL format rules

### Phase 2 — Models
**Mistake**: Forget to import the model in `models/__init__.py` before calling `create_all()`.
**Error**: Table doesn't get created, then `OperationalError: no such table: notes` when inserting
**Lesson**: How SQLAlchemy discovers models, why `create_all` needs to see the model class

### Phase 2 — CRUD
**Mistake**: Return the SQLAlchemy model object directly from a route (instead of using Pydantic response schema).
**Error**: `ValueError: sqlalchemy.orm.DeclarativeBase is not a valid pydantic field type`
**Lesson**: The model/schema separation, why response schemas exist, what Pydantic serialization does

### Phase 3 — Frontend
**Mistake**: Wrong API URL in `fetch()` (e.g., `/notes` instead of `/api/notes` after the prefix change).
**Error**: Browser Console shows `404 Not Found` on the fetch call, but the API endpoint exists
**Lesson**: DevTools Network tab, how to trace a 404 from frontend to backend

### Phase 4 — CORS
**Mistake**: Add CORS middleware AFTER mounting static files in `main.py`.
**Error**: CORS headers missing on API responses, error appears in browser Console
**Lesson**: FastAPI middleware order matters, middleware executes in reverse registration order

### Phase 4 — JWT
**Mistake**: Forget to set `SECRET_KEY` in `.env` (use empty string).
**Error**: All tokens validate as valid (empty key = no security) OR all tokens fail depending on the library
**Lesson**: Why secret key management matters, how to verify a config value is actually loaded

### Phase 6 — Docker
**Mistake**: Forget `.dockerignore` — copy `.env` into the image.
**Error**: Not an immediate crash, but show using `docker inspect` that secrets are baked into the image
**Lesson**: Security-in-containers, why `.dockerignore` is as important as `.gitignore`

### Phase 6 — Docker
**Mistake**: Use `localhost` in `DATABASE_URL` inside Docker instead of the service name `db`.
**Error**: `Connection refused` — the app tries to connect to its own container's localhost, not the db container
**Lesson**: Docker networking, container DNS, why service names are used in connection strings

---

---

## Planned deliberate mistakes — DevOps phases

### Phase 10 — K8s Step 1 (Concepts)
**Mistake**: Use `vault-api:latest` as the image name in deployment.yaml without importing it into k3d.
**Error**: `ImagePullBackOff` or `ErrImagePull` on `kubectl get pods`
**Lesson**: K8s clusters have their own image storage. Local Docker images are not automatically available inside k3d. Either import with `k3d image import` or push to a registry.

### Phase 10 — K8s Step 2 (Full Deployment)
**Mistake**: Use `Deployment` instead of `StatefulSet` for PostgreSQL.
**Error**: App appears to work, but after `kubectl delete pod vault-db-xxx`, data may be lost or the PVC may not reattach cleanly.
**Lesson**: Deployment pods are anonymous and interchangeable. StatefulSet pods have stable identity (`postgres-0`) and stable storage binding — required for databases.

### Phase 10 — K8s Step 3 (Ingress + Probes)
**Mistake**: Set `initialDelaySeconds: 0` on the liveness probe for Keycloak.
**Error**: `CrashLoopBackOff` — K8s kills Keycloak repeatedly because it fails the liveness check during startup.
**Lesson**: Health probe timing must match actual startup time. Keycloak takes ~60-90 seconds to start. Aggressive probes on slow-starting services cause restart loops.

### Phase 11 — Helm
**Mistake**: Run `helm install vault ./helm/vault` twice without checking if a release already exists.
**Error**: `Error: INSTALLATION FAILED: cannot re-use a name that is still in use`
**Lesson**: `helm install` fails if a release already exists. Use `helm upgrade --install` instead — it installs if absent, upgrades if present. This is what CI/CD pipelines use.

### Phase 12 — Container Registry
**Mistake**: Tag the image as `vault-api:latest` (without registry prefix) and try to push to ghcr.io.
**Error**: `denied: requested access to the resource is denied`
**Lesson**: Docker uses the image name to determine the registry. `vault-api:latest` tries Docker Hub. `ghcr.io/username/vault-api:latest` targets GitHub. The registry is part of the tag.

### Phase 12 — CI/CD
**Mistake**: Missing `needs: test` on the `build` job in the GitHub Actions workflow.
**Error**: The pipeline builds and deploys even when tests fail.
**Lesson**: GitHub Actions jobs run in parallel by default. `needs: test` makes `build` wait for `test` to succeed. Without it, a broken deploy can ship despite failing tests.

### Phase 13 — Monitoring
**Mistake**: Configure Prometheus to scrape `localhost:8000/metrics` instead of `api:8000/metrics`.
**Error**: Prometheus shows `connection refused` for the vault-api target.
**Lesson**: In K8s, `localhost` means the Prometheus pod itself, not the API. Service names (DNS) must be used for cross-pod communication: `api.vault.svc.cluster.local` or simply `api` within the same namespace.

---

## How to use DevTools for debugging (reference)

When the error is frontend-side, always open DevTools FIRST:

| Symptom | Where to look |
|---|---|
| Page loads but data doesn't appear | Network tab → find the failed request |
| JavaScript error on page | Console tab → read the error message |
| API call goes out but returns wrong data | Network tab → Response tab of the request |
| Token not being sent | Network tab → Headers tab → look for Authorization |
| CORS error | Console tab → red CORS message |
| App works in Swagger but not in browser | Usually CORS or wrong URL in fetch() |

---

## Debugging commands reference (backend)

```bash
# See what's running
ps aux | grep uvicorn

# Check if port is in use
lsof -i :8000

# Inspect PostgreSQL database directly
psql $DATABASE_URL -c "\dt"
psql $DATABASE_URL -c "SELECT * FROM users;"

# Check if env var is loaded
python -c "from app.config import settings; print(settings.database_url)"

# See Docker container logs
docker logs <container_name>
docker logs <container_name> --follow  # live tail

# Check container networking
docker exec -it <container_name> curl http://db:5432  # test internal DNS
docker network inspect vault_default  # see all containers on the network
```

---

## The mindset

A senior engineer does not panic at errors. They:
1. Read the error
2. Identify the layer
3. Form a hypothesis
4. Test it
5. Fix and explain

Developing this mental habit is more valuable than knowing any specific technology. Every technology breaks differently, but the debugging process is always the same.
