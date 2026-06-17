# Grafana Alloy — Study Guide

## Reading Order

| # | File | What You'll Learn |
|---|------|-------------------|
| 00 | `00-what-is-alloy.md` | What Alloy is, why it replaced Promtail/Agent, pipeline model, what it can collect, deployment modes |
| 01 | `01-configuration.md` | Alloy config syntax (not YAML!), component wiring, K8s pod logs, metric scraping, OTLP receiver, full examples |

## Key Concepts

- Alloy is the **unified successor** to Promtail + Grafana Agent — one binary for metrics + logs + traces
- Configured in **Alloy syntax** (`.alloy` files) — NOT YAML
- **Pipeline model**: components → wired together with references → `loki.write.backend.receiver`
- Alloy is a **collector**, NOT a storage engine — it forwards to Prometheus, Loki, Tempo
- Built-in **web UI** at `:12345` for debugging pipeline health

## Deployment Modes

| Mode | Environment | Pattern |
|------|-------------|---------|
| Standalone binary | VMs, bare metal | `alloy run config.alloy` as systemd service |
| Kubernetes DaemonSet | K8s clusters | One Alloy pod per node, collects all pod logs |
| Kubernetes Operator | K8s (GitOps) | Configure via CRDs, operator manages Alloy |
| Grafana Cloud | Cloud | Download pre-built config, run anywhere |

## The Standard Kubernetes Setup

```
Node 1:   Alloy (DaemonSet) ──► Loki (logs) + Mimir/Prometheus (metrics)
Node 2:   Alloy (DaemonSet) ──► Loki (logs) + Mimir/Prometheus (metrics)
Node 3:   Alloy (DaemonSet) ──► Loki (logs) + Mimir/Prometheus (metrics)
                                         │
                                         ▼
                              Grafana (visualization)
```

## Config Syntax Quick Reference

```hcl
// Send logs to Loki
loki.write "destination" {
  endpoint { url = "http://loki:3100/loki/api/v1/push" }
}

// Collect pod logs
loki.source.kubernetes "pods" {
  targets    = discovery.relabel.pods.output
  forward_to = [loki.write.destination.receiver]
}

// Send metrics to Prometheus
prometheus.remote_write "prom" {
  endpoint { url = "http://prometheus:9090/api/v1/write" }
}

// Scrape a service
prometheus.scrape "my_service" {
  targets    = [{"__address__" = "service:8080"}]
  forward_to = [prometheus.remote_write.prom.receiver]
}
```
