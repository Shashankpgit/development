# Loki — Study Guide

## Reading Order

| # | File | What You'll Learn |
|---|------|-------------------|
| 00 | `00-what-is-loki.md` | Loki's philosophy vs Elasticsearch, architecture (distributor/ingester/querier), labels, log shipping, deployment modes |
| 01 | `01-logql.md` | Stream selectors, pipeline stages, JSON/logfmt parsing, count_over_time/rate, real query patterns |
| 02 | `02-deployment-and-setup.md` | Loki config file, Docker Compose PLG stack, Kubernetes Helm setup, alerting rules, retention |

## Key Concepts

- Loki **only indexes labels**, not log content — 10-100x cheaper than Elasticsearch
- **Low cardinality labels** only: service, namespace, level — NOT user_id, request_id
- **LogQL = stream selector + pipeline stages**: `{service="api"} | json | level="error"`
- **3 deployment modes**: Monolithic (simple), SSD (scale read/write separately), Microservices (large scale)
- **Always configure retention** — Loki won't auto-delete without explicit retention config

## Quick LogQL Reference

```logql
# View logs
{service="vault-api"} |= "ERROR"
{namespace="production"} | json | level="error"

# Count errors per minute (for dashboards)
sum(count_over_time({namespace="production"} | json | level="error" [1m])) by (service)

# Error rate (for alerting)
sum(rate({namespace="production"} | json | level="error" [5m])) by (service) > 1
```

## Deployment Modes

| Mode | Scale | Storage | Use Case |
|------|-------|---------|----------|
| Monolithic | Single binary | Local / S3 | Dev, small prod ≤ 100GB/day |
| SSD (SimpleScalable) | Read/write separate | S3/GCS | Production K8s, 100GB-1TB/day |
| Microservices | Each component separate | S3/GCS | Large scale, dedicated team |
