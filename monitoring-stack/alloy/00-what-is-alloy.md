# Grafana Alloy — Part 00: What Is Alloy and Why Does It Exist?

---

## The Problem: Too Many Agents

Before Alloy, if you ran the Grafana observability stack, you needed multiple agents:

- **Prometheus**: scrapes your apps' `/metrics` endpoints
- **Promtail**: collects and ships logs to Loki
- **Grafana Agent** (old): a lighter-weight Prometheus that could also do remote_write
- **Tempo agent**: collects distributed traces

Four separate binaries to install, configure, update, and monitor on every machine and in every Kubernetes cluster. Each with different config syntax, different update cadences, different resource footprints.

**Alloy is the answer to: "What if one agent did everything?"**

---

## What Is Grafana Alloy?

Grafana Alloy is the **OpenTelemetry-compatible, unified observability agent** from Grafana Labs. It is:

- The **successor to Grafana Agent** (Grafana Agent Operator, Grafana Agent Static, Grafana Agent Flow are all converging into Alloy)
- A single binary that collects **metrics, logs, and traces**
- Configured in **Alloy config syntax** (formerly called "River") — a HCL-like declarative language
- OpenTelemetry-native: supports OTLP as both input and output
- A **programmable pipeline**: you define components and wire them together

---

## The Alloy Mental Model: Components and Pipelines

Alloy is built around a pipeline model. You define **components**, and wire their inputs to their outputs using the component reference syntax.

```
┌──────────────────────────────────────────────────────────────────┐
│                         Alloy Pipeline                            │
│                                                                   │
│  Source                Processing               Destination       │
│  ──────                ──────────               ───────────       │
│                                                                   │
│  loki.source.file  →  loki.process  →  loki.write                │
│  (read log files)    (add labels,      (send to Loki)            │
│                       filter)                                     │
│                                                                   │
│  prometheus.scrape →  prometheus.relabel → prometheus.remote_write│
│  (scrape /metrics)   (add/remove labels) (send to Prometheus/     │
│                                           Thanos/Mimir)           │
│                                                                   │
│  otelcol.receiver  →  otelcol.processor →  otelcol.exporter      │
│  (receive OTLP)      (batch, attribute)    (send to Tempo/        │
│                                             Jaeger)               │
└──────────────────────────────────────────────────────────────────┘
```

Each component:
- Has **arguments** (configuration)
- Exports **outputs** (data or references)
- Consumes **outputs from other components**

This means you can wire things together in very flexible ways — for example, Alloy can receive logs via OpenTelemetry protocol and forward them to Loki, while simultaneously scraping Prometheus metrics and forwarding them to two different remote_write endpoints.

---

## Alloy vs Its Predecessors

| Agent | Status | What It Did |
|-------|--------|-------------|
| Promtail | Deprecated (use Alloy) | Log collection only, Loki-specific |
| Grafana Agent Static | Deprecated | Metrics (Prometheus-compatible) + logs |
| Grafana Agent Flow | Deprecated → became Alloy | Pipeline-based, multi-signal |
| **Grafana Alloy** | **Current** | **Metrics + logs + traces + profiles, OTLP-native** |

If you see any docs or tutorials mentioning `Grafana Agent` or `Promtail`, the current equivalent is Alloy.

---

## What Alloy Can Collect

### Metrics
- Scrape Prometheus `/metrics` endpoints (like Prometheus itself)
- Receive metrics via OpenTelemetry OTLP
- Receive metrics via StatsD
- Scrape Kubernetes pod metrics

### Logs
- Tail log files from disk (`/var/log/*.log`)
- Read Kubernetes pod logs
- Receive logs via OpenTelemetry OTLP
- Receive logs via Loki's push API
- Collect systemd journal logs
- Docker container logs

### Traces
- Receive traces via OpenTelemetry OTLP
- Receive traces via Jaeger protocol
- Receive traces via Zipkin protocol
- Sample, process, and forward to Tempo

### Profiles (Continuous Profiling)
- Collect Go pprof profiles
- Collect Python py-spy profiles
- Forward to Grafana Pyroscope

---

## Alloy Deployment Modes

### Standalone Binary on a Host

Install Alloy directly on Linux/Mac/Windows servers:

```bash
# Ubuntu/Debian
sudo apt install grafana-alloy

# Or download binary directly
curl -L https://github.com/grafana/alloy/releases/latest/download/alloy-linux-amd64.zip \
  | unzip - && mv alloy-linux-amd64 /usr/local/bin/alloy
chmod +x /usr/local/bin/alloy
```

```bash
# Run Alloy with a config file
alloy run /etc/alloy/config.alloy

# Run as systemd service
systemctl start alloy
systemctl enable alloy
```

Use when: collecting logs/metrics from VMs, bare metal servers, or any non-Kubernetes environment.

### Kubernetes DaemonSet

Deploy Alloy on every node to collect all pod logs and node metrics:

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

helm install alloy grafana/alloy \
  --namespace monitoring \
  --set alloy.configMap.content="$(cat config.alloy)"
```

Alloy as a DaemonSet automatically gets access to:
- `/var/log/pods/` — all Kubernetes pod logs
- `/var/log/` — system logs
- Node metrics (if you configure a `prometheus.scrape` pointing to `node_exporter`)

Use when: Kubernetes clusters — the standard deployment pattern.

### Kubernetes Operator

The Grafana Alloy Operator lets you configure Alloy through Kubernetes custom resources (CRDs). Instead of writing Alloy config files, you write Kubernetes YAML.

```yaml
# Instead of writing alloy config syntax,
# you write Kubernetes resources like:
apiVersion: monitoring.grafana.com/v1alpha1
kind: MetricsInstance
# ...that the operator converts to Alloy config
```

Use when: large organizations that want GitOps-native configuration of Alloy.

### Grafana Cloud Integration

In Grafana Cloud, you configure the Grafana Agent Integration (powered by Alloy) through the UI. Grafana provides a pre-built `config.alloy` that you download and run. No configuration needed from scratch.

---

## Common Misunderstanding: "Alloy replaces Prometheus"

**The misunderstanding:** "If I run Alloy, I don't need Prometheus anymore."

**The reality:** Alloy is a **collector/forwarder** — it scrapes metrics and forwards them to Prometheus (or Thanos, Mimir, etc.). It does NOT replace Prometheus's TSDB (storage), PromQL engine, or alerting evaluation.

```
WITHOUT Alloy:
  Prometheus scrapes 1000 endpoints itself → high load on Prometheus
  
WITH Alloy (Agent mode):
  Alloy deployed on each cluster/host scrapes local targets
  Alloy remote_writes to central Prometheus/Thanos
  Central Prometheus handles storage + alerting + PromQL only
  → distributed scraping, centralized storage
```

Alloy is the **data collection pipeline**. Prometheus is the **storage and query engine**. They're complementary, not competing.

→ Continue to: `01-configuration.md`
