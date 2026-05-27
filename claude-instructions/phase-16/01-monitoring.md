# Phase 16 — Monitoring + Observability

## What this phase covers

Add observability to the vault app running in GKE: structured JSON logging from FastAPI, Prometheus metrics collection, and a Grafana dashboard. After this phase you can answer "what is my app doing right now?" by looking at data, not guessing.

---

## Pre-step checklist

- [ ] Create `docs/plans/024-monitoring-plan.md` first
- [ ] Phase 15 complete: app running in GKE
- [ ] Explain the three pillars of observability before any code

---

## The three pillars of observability

Teach this clearly before implementation:

1. **Logs**: Discrete events. "At 14:32:01, user bob called GET /api/notes, returned 200 in 45ms."
2. **Metrics**: Aggregated numbers over time. "1,234 requests in the last minute. p99 latency: 120ms."
3. **Traces**: How a single request flowed through multiple services. (Advanced — mentioned but not implemented here.)

This phase covers logs + metrics. Together they let you know when something is wrong and where to look.

---

## Step 1 — Structured logging in FastAPI

### Why logs go to stdout in K8s

In docker-compose, it's common to write logs to files. In K8s, you never write logs to files inside a container. Containers are ephemeral — when the pod restarts, the file is gone.

The correct pattern: **log to stdout**. K8s captures stdout from every container. `kubectl logs` reads it. In production, a log aggregation system (Loki, ELK) collects stdout from every pod into a central searchable store.

### Why structured (JSON) logs

Plain text logs:
```
2026-05-27 14:32:01 INFO GET /api/notes 200 45ms
```

You can read it but you can't query it programmatically.

JSON logs:
```json
{"timestamp":"2026-05-27T14:32:01Z","level":"INFO","method":"GET","path":"/api/notes","status":200,"duration_ms":45,"user":"bob"}
```

Now you can filter: `jq 'select(.status >= 500)'` or query in Grafana Loki: `{app="vault-api"} | json | status >= 500`.

### Implementation

`vault/backend/app/middleware/logging_middleware.py`:
```python
import time, json, logging
from fastapi import Request

logger = logging.getLogger("vault")

async def logging_middleware(request: Request, call_next):
    start = time.time()
    response = await call_next(request)
    duration_ms = round((time.time() - start) * 1000)
    log = {
        "method": request.method,
        "path": request.url.path,
        "status": response.status_code,
        "duration_ms": duration_ms,
    }
    logger.info(json.dumps(log))
    return response
```

Configure Python logging to output JSON to stdout, add middleware to `main.py`.

---

## Step 2 — Prometheus metrics

### How Prometheus works (pull model)

Prometheus does NOT receive metrics pushed to it. It **scrapes** — it calls `GET /metrics` on your app every 15 seconds and reads the numbers.

Your app exposes a `/metrics` endpoint. Prometheus is configured to scrape it. This is the pull model.

```
Prometheus → scrapes → vault-api /metrics  every 15s
           → scrapes → postgresql /metrics
           → scrapes → keycloak /metrics
           → stores time-series data
```

### Three metric types
- **Counter**: only goes up. Total requests. Total errors. Never resets.
- **Gauge**: can go up or down. Active connections. Memory usage.
- **Histogram**: records distribution of values. Latency buckets (0-10ms, 10-50ms, 50-100ms, 100ms+). From histograms you compute p50, p95, p99 latency.

### Implementation

`prometheus-fastapi-instrumentator` auto-instruments FastAPI and exposes `/metrics`:

```bash
pip install prometheus-fastapi-instrumentator
```

```python
# app/main.py
from prometheus_fastapi_instrumentator import Instrumentator

app = FastAPI()
Instrumentator().instrument(app).expose(app)
```

This adds these metrics automatically:
- `http_requests_total` — counter by method, path, status code
- `http_request_duration_seconds` — histogram (latency)
- `http_requests_in_progress` — gauge

---

## Step 3 — Deploy Prometheus + Grafana via Helm

The `kube-prometheus-stack` chart bundles Prometheus, Alertmanager, and Grafana together. One Helm install for the whole monitoring stack.

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set grafana.adminPassword=admin
```

This deploys:
- Prometheus (scrapes metrics from all pods)
- Grafana (visualization UI at port 3000)
- AlertManager (sends alerts — for future use)
- Node exporters (CPU/memory for each K8s node)

### Configure Prometheus to scrape vault-api

Add a `ServiceMonitor` resource — this tells Prometheus which services to scrape:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: vault-api
  namespace: vault
spec:
  selector:
    matchLabels:
      app: vault-api
  endpoints:
    - port: http
      path: /metrics
      interval: 15s
```

---

## Step 4 — Grafana dashboard

Access Grafana:
```bash
kubectl port-forward svc/monitoring-grafana 3000:80 -n monitoring
# → http://localhost:3000 (admin/admin)
```

Create a dashboard with:
- **Request rate**: `rate(http_requests_total[5m])` — requests per second
- **Error rate**: `rate(http_requests_total{status=~"5.."}[5m])` — 5xx per second
- **p99 latency**: `histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))`
- **Pod restarts**: K8s built-in metric from kube-prometheus-stack

---

## Deliberate mistake for this step

**Mistake**: Configure Prometheus `static_configs` to scrape `localhost:8000` instead of `api.vault.svc.cluster.local:8000`.

```yaml
# Wrong
static_configs:
  - targets: ['localhost:8000']
```

**Error**: Prometheus shows `connection refused` for the vault-api target.

**Lesson**: `localhost` means the Prometheus pod itself, not the API pod. In K8s, pods communicate via Service DNS: `serviceName.namespace.svc.cluster.local`. Within the same namespace you can use just `serviceName`.

---

## Success criteria

```bash
# Logs are structured JSON
kubectl logs deployment/vault-api -n vault | head -5 | jq '.'
# → {"method":"GET","path":"/health","status":200,"duration_ms":3}

# Metrics endpoint works
kubectl port-forward svc/api 8000:8000 -n vault
curl http://localhost:8000/metrics | grep http_requests_total
# → http_requests_total{handler="/health",method="GET",status_code="200"} 42.0

# Grafana dashboard
# http://localhost:3000 → request rate graph shows traffic
# Generate load: for i in {1..50}; do curl http://vault.local/api/health; done
# → graph spikes
```
