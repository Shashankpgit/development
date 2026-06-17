# Grafana — Study Guide

## Reading Order

| # | File | What You'll Learn |
|---|------|-------------------|
| 00 | `00-what-is-grafana.md` | What Grafana is, architecture, data sources, deployment modes (OSS/Cloud/Enterprise/K8s) |
| 01 | `01-dashboards-and-panels.md` | Building dashboards, panel types, template variables, annotations, provisioning |
| 02 | `02-alerting-and-oncall.md` | Alert rules, contact points, notification policies, silences, SLOs, alert fatigue |

## Key Concepts

- Grafana is a **visualization layer** — it queries data sources, it doesn't store data
- Always set correct **units** on panels (bytes, ms, percent)
- **Template variables** make one dashboard work for all services/namespaces
- **Provision** dashboards from JSON files so they survive Grafana restarts
- Alert on **symptoms** (user-impacting events), not causes (CPU %)
- Use **silences** for planned maintenance and intentional scale-downs

## Deployment Modes

| Mode | Managed? | Cost | Best For |
|------|---------|------|----------|
| OSS | Self-hosted | Free | Full control, on-prem |
| Cloud | Fully managed | Free tier + paid | Quick start, no ops overhead |
| Enterprise | Self-hosted | Paid | Advanced SSO, reporting |
| Helm/K8s | Self-hosted | Free | GitOps, declarative config |

## Quick Recipes

```promql
# Standard 4 Golden Signals dashboard queries:
# 1. Latency (P95)
histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))

# 2. Traffic (req/s)
sum(rate(http_requests_total[5m])) by (service)

# 3. Errors (%)
100 * sum(rate(http_requests_total{status=~"5.."}[5m])) by (service)
    / sum(rate(http_requests_total[5m])) by (service)

# 4. Saturation (CPU %)
100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) by (instance) * 100)
```
