# Prometheus — Part 01: Architecture, Configuration, and Setup

---

## Prometheus Architecture — Deep Dive

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Prometheus Server                                  │
│                                                                       │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │                    Retrieval (Scraper)                        │   │
│  │                                                               │   │
│  │  Service Discovery ──► Target List ──► HTTP scrape /metrics  │   │
│  │  (Kubernetes, EC2,                      every 15s (default)  │   │
│  │   static configs,                                             │   │
│  │   DNS, Consul)                                                │   │
│  └────────────────────────────┬──────────────────────────────────┘  │
│                                │                                       │
│  ┌─────────────────────────────▼──────────────────────────────────┐  │
│  │                    TSDB (Time-Series Database)                  │  │
│  │                                                                 │  │
│  │  Chunks (2h blocks in memory) ──► Compacted blocks on disk    │  │
│  │  WAL (Write-Ahead Log)                                         │  │
│  │  Default retention: 15 days                                    │  │
│  └────────────────────────────┬───────────────────────────────────┘  │
│                                │                                       │
│  ┌─────────────────────────────▼──────────────────────────────────┐  │
│  │                    HTTP API + Web UI                            │  │
│  │                                                                 │  │
│  │  PromQL endpoint ─────────────────────────► Grafana, etc.     │  │
│  │  /api/v1/query                                                  │  │
│  │  /api/v1/query_range                                            │  │
│  └────────────────────────────────────────────────────────────────┘  │
│                                                                       │
│  ┌─────────────────────────────────────────────────────────────────┐  │
│  │                    Rule Evaluator                               │  │
│  │                                                                 │  │
│  │  Recording rules ──► precompute expensive queries              │  │
│  │  Alerting rules ───► fire alerts to Alertmanager               │  │
│  └─────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

### How the TSDB Works

Prometheus stores data in 2-hour chunks in memory (WAL for durability). Every 2 hours, the chunk is sealed and compacted to disk. Over time, older chunks are merged and downsampled.

```
Memory:  [current 2h block + WAL]
Disk:    [2h] [2h] [6h compacted] [24h compacted] [7d compacted]
```

Default retention: 15 days. After that, old blocks are deleted.

Data format on disk: each time series = a sequence of (timestamp, value) pairs, compressed.

---

## prometheus.yml — The Configuration File

Everything Prometheus does is configured in `prometheus.yml`:

```yaml
# prometheus.yml

global:
  scrape_interval: 15s         # how often to scrape targets
  evaluation_interval: 15s     # how often to evaluate alerting rules
  scrape_timeout: 10s          # timeout for each scrape

# Alert rules files
rule_files:
  - "rules/*.yml"              # load all rule files from rules/ directory

# Where to send alerts
alerting:
  alertmanagers:
    - static_configs:
        - targets: ["alertmanager:9093"]

# What to scrape
scrape_configs:

  # Scrape Prometheus itself
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  # Scrape Linux node metrics
  - job_name: 'node'
    static_configs:
      - targets:
          - 'node1:9100'
          - 'node2:9100'
          - 'node3:9100'

  # Scrape your application
  - job_name: 'vault-api'
    static_configs:
      - targets: ['vault-api:3000']
    metrics_path: /metrics      # default is /metrics
    scheme: http                # or https

  # Scrape with authentication
  - job_name: 'secured-app'
    static_configs:
      - targets: ['secured-app:8080']
    basic_auth:
      username: prometheus
      password: scrapepassword

  # Scrape Kubernetes pods (service discovery)
  - job_name: 'kubernetes-pods'
    kubernetes_sd_configs:
      - role: pod
    relabel_configs:
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: "true"
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
        action: replace
        target_label: __metrics_path__
        regex: (.+)
      - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
        action: replace
        regex: ([^:]+)(?::\d+)?;(\d+)
        replacement: $1:$2
        target_label: __address__
```

---

## Service Discovery — How Prometheus Finds Targets

In dynamic environments (Kubernetes, AWS), you can't hardcode IP addresses. Prometheus has built-in service discovery for many platforms.

### Kubernetes Service Discovery

```yaml
scrape_configs:
  - job_name: 'kubernetes-nodes'
    kubernetes_sd_configs:
      - role: node     # discover nodes
    # automatically scrapes each node's kubelet metrics

  - job_name: 'kubernetes-pods'
    kubernetes_sd_configs:
      - role: pod      # discover pods
    relabel_configs:
      # Only scrape pods that have this annotation:
      # prometheus.io/scrape: "true"
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: "true"
```

To make a pod discoverable, add annotations to its deployment:

```yaml
metadata:
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "3000"
    prometheus.io/path: "/metrics"
```

### AWS EC2 Service Discovery

```yaml
scrape_configs:
  - job_name: 'ec2'
    ec2_sd_configs:
      - region: ap-south-1
        port: 9100               # node-exporter port
    relabel_configs:
      - source_labels: [__meta_ec2_tag_Environment]
        target_label: environment
      - source_labels: [__meta_ec2_instance_id]
        target_label: instance
```

---

## Relabeling — Shape the Data Before Storing

`relabel_configs` runs before a scrape. It lets you:
- Keep only certain targets
- Drop certain targets
- Add labels from metadata
- Rename labels

```yaml
relabel_configs:
  # Keep only targets where the label "env" equals "production"
  - source_labels: [__meta_kubernetes_namespace]
    regex: production
    action: keep

  # Drop monitoring namespace (don't monitor the monitoring tools)
  - source_labels: [__meta_kubernetes_namespace]
    regex: monitoring
    action: drop

  # Copy the pod name to a "pod" label in the final metrics
  - source_labels: [__meta_kubernetes_pod_name]
    target_label: pod

  # Rename a label
  - source_labels: [__meta_kubernetes_service_name]
    target_label: service
```

---

## Alerting Rules

```yaml
# rules/vault-api-alerts.yml
groups:
  - name: vault-api
    interval: 1m              # evaluate these rules every 1 minute
    rules:

      # Recording rule: precompute expensive query
      - record: job:http_requests:rate5m
        expr: sum(rate(http_requests_total[5m])) by (job)

      # Alert: high error rate
      - alert: HighErrorRate
        expr: |
          sum(rate(http_requests_total{status=~"5.."}[5m])) by (service)
          /
          sum(rate(http_requests_total[5m])) by (service)
          > 0.05
        for: 2m           # must be true for 2 minutes before firing
        labels:
          severity: critical
          team: backend
        annotations:
          summary: "High error rate on {{ $labels.service }}"
          description: "Error rate is {{ $value | humanizePercentage }} on {{ $labels.service }}"
          runbook: "https://wiki.company.com/runbooks/high-error-rate"

      # Alert: service down
      - alert: ServiceDown
        expr: up{job="vault-api"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Service {{ $labels.instance }} is down"

      # Alert: high memory usage
      - alert: HighMemoryUsage
        expr: |
          container_memory_usage_bytes{container!=""}
          / container_spec_memory_limit_bytes{container!=""}
          > 0.85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Container {{ $labels.container }} memory at {{ $value | humanizePercentage }}"
```

---

## Alertmanager Configuration

```yaml
# alertmanager.yml
global:
  smtp_smarthost: 'smtp.gmail.com:587'
  smtp_from: 'alerts@company.com'
  slack_api_url: 'https://hooks.slack.com/services/YOUR/WEBHOOK/URL'

templates:
  - '/etc/alertmanager/templates/*.tmpl'

route:
  receiver: 'default'           # default receiver if no routes match
  group_by: ['alertname', 'service']
  group_wait: 30s               # wait 30s to collect more alerts before first notification
  group_interval: 5m            # wait 5m before re-sending for group changes
  repeat_interval: 4h           # wait 4h before re-sending unchanged alerts

  routes:
    # Critical alerts: PagerDuty
    - match:
        severity: critical
      receiver: pagerduty
      continue: true            # also send to default (Slack)

    # Database alerts: DBA team Slack
    - match:
        team: database
      receiver: dba-slack

receivers:
  - name: 'default'
    slack_configs:
      - channel: '#alerts'
        title: '{{ .GroupLabels.alertname }}'
        text: '{{ range .Alerts }}{{ .Annotations.description }}\n{{ end }}'

  - name: 'pagerduty'
    pagerduty_configs:
      - service_key: 'YOUR_PAGERDUTY_KEY'

  - name: 'dba-slack'
    slack_configs:
      - channel: '#dba-alerts'

inhibit_rules:
  # If datacenter is down, suppress individual service alerts
  - source_match:
      alertname: DatacenterDown
    target_match:
      severity: critical
    equal: ['datacenter']
```

---

## Deployment Modes

### Standalone (Single Instance)

The simplest setup. One Prometheus server scrapes everything and stores data locally.

```
Targets ──► Prometheus ──► Grafana
                │
           Local TSDB
```

**Pros:** Simple, low resource usage
**Cons:** Single point of failure, limited storage, limited query performance for large setups

Use when: small to medium infrastructure, single team, retention < 30 days.

### Prometheus with Remote Write (Long-Term Storage)

Prometheus writes all data to an external storage system (Thanos, Cortex, VictoriaMetrics) while also keeping local storage for fast queries.

```
Targets ──► Prometheus ──► Thanos Sidecar ──► Object Store (S3/GCS)
                │                                       │
           Local TSDB                        Long-term storage
           (15 days fast)                    (years, cheap)
```

**Pros:** Long-term storage, high availability, global querying across multiple Prometheus instances
**Cons:** More complexity, requires external storage

Use when: you need > 15 days retention, multi-region setups, HA requirements.

### Prometheus Agent Mode

Prometheus runs in "agent" mode — it scrapes targets and forwards all metrics to a remote_write endpoint. It does NOT store data locally at all.

```yaml
# Run in agent mode
prometheus --enable-feature=agent
```

```
Targets ──► Prometheus (agent) ──► remote_write ──► Central Prometheus / Thanos / Mimir
```

**Pros:** Minimal local storage, ideal for Kubernetes per-cluster collectors that forward to central store, lightweight
**Cons:** Can't query locally, no alerting (alerts fire at the central receiver)

Use when: large Kubernetes cluster that forwards to a central observability platform. You deploy one agent per cluster and one central Thanos/Mimir for the whole organization.

### Federation — Scraping Another Prometheus

```yaml
# Global Prometheus scrapes other Prometheus instances
scrape_configs:
  - job_name: 'federate'
    honor_labels: true
    metrics_path: '/federate'
    params:
      match[]:
        - '{job="vault-api"}'     # only pull these metrics
    static_configs:
      - targets:
          - 'prometheus-datacenter-1:9090'
          - 'prometheus-datacenter-2:9090'
```

Use for: hierarchical setups where a global Prometheus aggregates key metrics from regional instances, without needing to store everything globally.

---

## Common Misunderstanding: "Prometheus stores logs"

**The misunderstanding:** "Prometheus is my monitoring system, so I'll send my application logs to it."

**The reality:** Prometheus stores ONLY metrics — numbers with timestamps and labels. It has no concept of log lines, strings, or events. You cannot store "ERROR: connection refused at 2026-06-17 03:45:12" in Prometheus.

For logs, you need a dedicated log aggregation system:
- **Loki** (from Grafana Labs) — the most common Prometheus companion for logs
- **Elasticsearch/OpenSearch** — more powerful, higher resource cost
- **CloudWatch Logs**, **Stackdriver** — cloud-native options

The typical stack:
- Prometheus: metrics (numbers over time)
- Loki: logs (text/events over time)
- Grafana: visualization layer for both

→ Continue to: `02-promql.md`
