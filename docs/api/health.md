# API — Health

Server status check. Used by load balancers and monitoring tools to verify the service is alive.

---

## Endpoints

### GET /health

Check if the server is running and the database is reachable.

**Auth required:** No

---

#### Request

No body, no parameters.

```
GET /health
```

---

#### Response — 200 OK

```json
{
  "status": "ok",
  "version": "0.1.0",
  "database": "connected"
}
```

`database` field values:
- `"connected"` — PostgreSQL is reachable
- `"unreachable"` — PostgreSQL is down or misconfigured (app still returns 200, but something is wrong)

---

#### curl

```bash
# Basic
curl http://localhost:8000/health

# Pretty-printed
curl -s http://localhost:8000/health | jq

# Status code only
curl -o /dev/null -s -w "%{http_code}\n" http://localhost:8000/health

# Full request + response headers
curl -v http://localhost:8000/health
```

---

#### Postman

Collection: `Personal Vault` → `Health` → `GET /health`

---

#### Notes

- This endpoint should always be public — never protected by auth
- In Kubernetes (Phase 10), this endpoint is used as the liveness and readiness probe
- A `200` here does not guarantee all features work — it only means the process is running
