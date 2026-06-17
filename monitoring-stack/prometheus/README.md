# Prometheus — Study Guide

## Reading Order

| # | File | What You'll Learn |
|---|------|-------------------|
| 00 | `00-what-is-prometheus.md` | Why Prometheus exists, pull model, metric types, labels, ecosystem |
| 01 | `01-architecture-and-setup.md` | TSDB internals, prometheus.yml, service discovery, alerting rules, Alertmanager, deployment modes |
| 02 | `02-promql.md` | Rate/irate/increase, aggregation, real queries for CPU/memory/latency/errors |

## Key Concepts Summary

- **Pull model**: Prometheus scrapes /metrics endpoints, not the other way around
- **4 metric types**: Counter (only up), Gauge (up/down), Histogram (distributions), Summary
- **Labels** = dimensions — each unique label combo is a separate time series
- **PromQL**: always `rate()` for counters, `sum() by ()` to aggregate, `histogram_quantile()` for percentiles
- **Exporters**: bridge non-native software (Linux, Postgres, Redis) to Prometheus format
- **Alertmanager**: separate component that routes/groups/silences alerts

## Deployment Modes

| Mode | Storage | Use Case |
|------|---------|----------|
| Standalone | Local disk | Small setups, < 15 day retention |
| Remote Write + Thanos/Mimir | Object store (S3) | Long-term storage, multi-cluster |
| Agent Mode | None (forward only) | Per-cluster collector, lightweight |
| Federation | Hierarchical | Global aggregation from regional instances |
