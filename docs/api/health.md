# Health

Two endpoints, because Kubernetes asks two different questions. Getting them
the wrong way round turns a brief database outage into a cluster-wide crash
loop — see the KT note in `docs/002`.

## GET /health — liveness

"Is this process alive?" Deliberately does **not** touch the database.
Failing this probe makes Kubernetes **restart** the pod.

```bash
curl http://localhost:8000/health
```

```json
{ "status": "ok", "service": "Shop API" }
```

Always `200` if the process can answer at all.

## GET /health/ready — readiness

"Can this pod serve traffic right now?" Runs `SELECT 1` against Postgres.
Failing this only removes the pod from the load balancer; it is not restarted,
so it recovers by itself when the database returns.

```bash
curl http://localhost:8000/health/ready
```

```json
{ "status": "ready", "database": "connected" }
```

| Code | When |
|---|---|
| `200` | Database reachable |
| `503` | Database unreachable — `detail` carries the driver error |
