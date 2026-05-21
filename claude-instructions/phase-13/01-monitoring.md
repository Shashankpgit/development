# Phase 13 — Step 1: Monitoring and Logging

## What this step covers
Add observability to the Personal Vault: structured application logging, Prometheus metrics, and a Grafana dashboard. You should know what the application is doing without looking at code.

---

## Pre-step checklist (Claude must do before any code)

- [ ] Create `docs/020-monitoring-plan.md` first
- [ ] Explain the three pillars of observability before implementation
- [ ] Explain why logging to stdout and using structured logs matters

---

## Why this step exists

At this point the application is deployed and running. But how do you know:
- How many requests per second is the API handling?
- Are there errors happening that users aren't reporting?
- Which endpoints are slowest?
- Is the database running out of connections?
- Did the 3am deployment break something while you were sleeping?

Without monitoring, you're flying blind. Observability means you can ask questions about your system's behavior by looking at data, not guessing.

---

## The three pillars of observability

Teach this clearly before implementation:

1. **Logs**: Discrete events. "At 14:32:01, user bob called GET /api/notes, returned 200 in 45ms."
2. **Metrics**: Aggregated numbers. "1,234 requests in the last minute. 99th percentile latency: 120ms."
3. **Traces**: How a request flowed through multiple services. (Advanced — note for future.)

This phase covers logs and metrics. Traces are for microservices (future phase).

---

## What to implement

### Structured logging

Replace `print()` with proper logging. Add `structlog` or use Python's `logging` with JSON formatter.

Every log entry should be JSON with:
```json
{
  "timestamp": "2026-05-21T14:32:01Z",
  "level": "INFO",
  "message": "Request completed",
  "method": "GET",
  "path": "/api/notes",
  "status_code": 200,
  "duration_ms": 45,
  "user": "bob"
}
```

Add FastAPI middleware that logs every request/response automatically.

### `app/middleware/logging_middleware.py`
- Log: method, path, status code, duration, user (if authenticated)
- Log to stdout (so Docker/K8s can capture it)
- JSON format (so log aggregation tools can parse it)

### Prometheus metrics

Add `prometheus-fastapi-instrumentator` — it auto-instruments FastAPI and exposes `/metrics` endpoint.

Metrics available automatically:
- `http_requests_total` — count of requests by method, path, status
- `http_request_duration_seconds` — latency histogram
- `http_requests_in_progress` — active requests

### Prometheus in docker-compose
Add `prometheus` service scraping `http://api:8000/metrics` every 15s.

`prometheus.yml`:
```yaml
scrape_configs:
  - job_name: 'vault-api'
    scrape_interval: 15s
    static_configs:
      - targets: ['api:8000']
```

### Grafana in docker-compose
Add `grafana` service. Configure Prometheus as data source.

Create dashboard with panels:
- Request rate (req/sec)
- Error rate (5xx responses)
- Latency (p50, p95, p99)
- Active database connections

---

## Concepts to teach during this step

- **Why logs to stdout**: In Docker/K8s, you never write logs to files. The container orchestrator collects stdout and sends it to a log aggregation system (ELK, Loki). Writing to files in containers is fragile.

- **Why structured (JSON) logs**: Plain text logs are for humans. JSON logs are for machines — you can filter, query, and alert on them. `grep "ERROR"` vs `jq 'select(.level == "ERROR")'`.

- **Log levels**: DEBUG (too noisy for prod), INFO (normal events), WARNING (something unexpected but handled), ERROR (something failed), CRITICAL (system is broken). Use INFO in production by default.

- **Prometheus data model**: A time-series database. Metrics are scraped (pulled) from your app on a schedule. This is the pull model — Prometheus comes to your app, not the other way.

- **Histogram vs Counter vs Gauge**:
  - Counter: only goes up (total requests). Never resets.
  - Gauge: can go up or down (active connections).
  - Histogram: records distribution of values (latency buckets: 0–10ms, 10–50ms, 50–100ms...).

- **Grafana**: A visualization tool. Connects to Prometheus, lets you build dashboards with charts. The dashboards don't store data — Prometheus does.

- **Alerting** (brief mention): Grafana can send alerts (email, Slack, PagerDuty) when metrics cross thresholds. "Error rate > 5% for 5 minutes → wake up the on-call engineer." Don't implement now, but note it.

---

## What NOT to do in this step

- Do NOT set up distributed tracing (Jaeger/Zipkin) — too complex for now
- Do NOT set up a full ELK stack (Elasticsearch, Logstash, Kibana) — overkill at this stage
- Do NOT add alerting rules (note it as next step if desired)

---

## File changes

| File | Action |
|---|---|
| `app/middleware/logging_middleware.py` | Create |
| `app/main.py` | Modify — add logging middleware, Prometheus instrumentator |
| `prometheus.yml` | Create |
| `grafana/provisioning/` | Create — datasource + dashboard config |
| `docker-compose.yml` | Modify — add prometheus + grafana services |
| `requirements.txt` | Modify — add `structlog`, `prometheus-fastapi-instrumentator` |

---

## Success criteria

```bash
docker-compose up --build
# http://localhost:9090 → Prometheus UI
# Query: http_requests_total → shows request count
# http://localhost:3000 → Grafana (admin/admin)
# Import dashboard → see request rate and latency graphs

# Generate some traffic:
for i in {1..20}; do curl http://localhost/api/health; done
# Grafana dashboard updates with the spike
```

Application logs (JSON format):
```bash
docker logs vault_api_1 | jq '.'
# → structured JSON log entries, one per request
```
