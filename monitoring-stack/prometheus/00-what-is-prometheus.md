# Prometheus — Part 00: What Is Prometheus and Why Does It Exist?

---

## The Problem Before Prometheus

Imagine you're running 20 microservices across 10 servers. At 3 AM, one service starts returning errors. You wake up to an alert. Now what?

- Which service is slow? You don't know — you'd have to SSH into each server
- Is it a memory leak? You don't know — the server threw away that data
- When did it start? You don't know — there's no historical data
- Is it affecting users? You don't know — you have no visibility

This is **operating blind**. Before Prometheus, most monitoring was:
- Log-based: you'd grep through logs hoping to find the error
- External checks: "ping this URL every minute and alert if it fails"
- Manual: someone notices in the morning

**Prometheus changes this entirely.** It gives you:
- A time-series database: "this metric had this value at this second"
- Multi-dimensional data: not just "CPU is 80%" but "CPU is 80% on service=api, instance=server-2"
- A query language (PromQL) to answer questions like "show me services where error rate > 1% over the last 5 minutes"
- Alerting: define rules, get notified when conditions are met

---

## What Prometheus Actually Is

Prometheus is a **monitoring system and time-series database** built at SoundCloud in 2012, inspired by Google's internal Borgmon monitoring system. It became a CNCF (Cloud Native Computing Foundation) project in 2016 and is now the standard for cloud-native monitoring.

At its core, Prometheus does one thing: **it collects numbers over time and lets you query them.**

Those numbers are metrics:
- How many HTTP requests per second is my API handling?
- What percentage of my disk is used?
- How many errors did my database return in the last minute?
- How much memory is my app using right now?

---

## The Pull Model — How Prometheus Collects Data

Most monitoring systems use a **push model**: applications send metrics to the monitoring server.

Prometheus uses a **pull model**: Prometheus goes out and ASKS services for their metrics on a schedule.

```
Push model (statsd, CloudWatch, Datadog agent):
  App ─────────────────────────────────► Monitoring server
  "Here are my metrics, please store them"

Pull model (Prometheus):
  Prometheus ──► "Give me your metrics" ──► App (at /metrics endpoint)
  App ──► responds with current metrics ──► Prometheus stores them
```

**Why pull is better:**
- Prometheus controls the scrape rate — it can't be overwhelmed by a misbehaving app sending too many metrics
- If a target disappears, Prometheus knows — it tried to scrape and got nothing
- Easier debugging — you can `curl http://my-app:8080/metrics` yourself to see exactly what Prometheus sees
- The app doesn't need to know where Prometheus lives

**The /metrics endpoint** is the contract: any application that exposes a `/metrics` endpoint in the Prometheus format can be monitored. This format is called the **OpenMetrics** format.

A typical `/metrics` response looks like:

```
# HELP http_requests_total Total number of HTTP requests
# TYPE http_requests_total counter
http_requests_total{method="GET",status="200",path="/api/users"} 4523
http_requests_total{method="GET",status="404",path="/api/users"} 12
http_requests_total{method="POST",status="200",path="/api/users"} 891
http_requests_total{method="POST",status="500",path="/api/users"} 3

# HELP process_resident_memory_bytes Resident memory size in bytes
# TYPE process_resident_memory_bytes gauge
process_resident_memory_bytes 45678592
```

---

## The Four Metric Types

Every metric in Prometheus is one of four types:

### Counter
A number that only ever goes up. Never decreases (except when it resets to 0 on restart).

```
http_requests_total{status="200"} 4523
```

Use for: total requests, total errors, total bytes sent, total jobs completed.

You almost never look at the raw counter value. You use `rate()` or `increase()` in PromQL to calculate how fast it's increasing:
- "How many requests per second in the last 5 minutes?" → `rate(http_requests_total[5m])`

### Gauge
A number that can go up OR down. It represents a current snapshot.

```
process_resident_memory_bytes 45678592
active_connections 47
temperature_celsius 72.4
```

Use for: current memory usage, current CPU, number of active connections, queue size, disk space.

### Histogram
Samples observations and counts them in configurable buckets. Used for measuring distributions (response times, request sizes).

```
http_request_duration_seconds_bucket{le="0.005"} 24054
http_request_duration_seconds_bucket{le="0.01"} 33444
http_request_duration_seconds_bucket{le="0.025"} 100392
http_request_duration_seconds_bucket{le="0.05"} 129389
http_request_duration_seconds_bucket{le="+Inf"} 144320
http_request_duration_seconds_sum 53423.147
http_request_duration_seconds_count 144320
```

This tells you: "24,054 requests completed in under 5ms, 33,444 in under 10ms..."

Use for: request latency, response sizes. Lets you calculate percentiles (P50, P95, P99).

### Summary
Like Histogram but pre-calculates quantiles client-side. Less flexible than Histogram (can't aggregate across instances), mostly used for cases where you know exactly what quantiles you want.

---

## Labels — The Superpower of Prometheus

Labels are the most important concept after understanding metric types. Labels allow one metric to represent many different time series.

```
http_requests_total{method="GET", status="200", path="/api/users"} 4523
http_requests_total{method="GET", status="404", path="/api/users"} 12
http_requests_total{method="POST", status="200", path="/api/users"} 891
```

This is ONE metric (`http_requests_total`) with three different label combinations. Each unique combination of label values is a separate **time series**.

Labels let you ask questions like:
- "Error rate per service" → filter by `service="vault-api"`
- "Slow endpoints" → filter by `path`
- "Errors in production only" → filter by `environment="production"`
- "Which instance is the bottleneck?" → group by `instance`

**The cardinality trap:** each unique combination of label values = one time series stored in memory. If you add a label `user_id` with 1 million unique values, you've just created 1 million time series for that metric. This can crash Prometheus. Only use labels for low-cardinality values (status codes, method names, service names — things with a small bounded set of values).

---

## The Prometheus Ecosystem

Prometheus doesn't work alone. It's part of an ecosystem:

```
┌──────────────────────────────────────────────────────────────────────┐
│                        Prometheus Ecosystem                           │
│                                                                       │
│  Your Apps ─── expose /metrics ─── Prometheus Server ─── PromQL     │
│                                           │                           │
│  Exporters ─────────────────────────────┘           Grafana          │
│  (node-exporter, postgres_exporter,                 (visualization)  │
│   blackbox_exporter, etc.)                                            │
│                                           │                           │
│                               Alertmanager                           │
│                               (route alerts to Slack, PagerDuty,     │
│                               email, OpsGenie)                        │
│                                                                       │
│  Pushgateway ── for short-lived jobs that can't be scraped           │
└──────────────────────────────────────────────────────────────────────┘
```

### Exporters — Bridge Between the World and Prometheus

Most software (databases, Linux servers, hardware) doesn't expose a `/metrics` endpoint natively. Exporters fill this gap — they read from an existing interface and translate it to Prometheus format.

| Exporter | What It Monitors |
|---------|-----------------|
| `node_exporter` | Linux host: CPU, memory, disk, network, filesystem |
| `postgres_exporter` | PostgreSQL: connections, query times, table sizes |
| `redis_exporter` | Redis: memory, commands, connections |
| `blackbox_exporter` | External probing: HTTP, DNS, TCP, ICMP health checks |
| `mysqld_exporter` | MySQL metrics |
| `nginx-prometheus-exporter` | Nginx connections and requests |
| `kube-state-metrics` | Kubernetes: pod states, deployment status, PVC usage |
| `cadvisor` | Container CPU, memory, network (per container) |

### Alertmanager — Routing Alerts

Prometheus evaluates alerting rules and fires alerts. But it doesn't send notifications itself — that's Alertmanager's job. Alertmanager handles:
- **Routing**: send database alerts to the DBA team, send API alerts to the dev team
- **Grouping**: 50 alerts about the same problem → one notification, not 50
- **Silencing**: "maintenance window, don't alert for the next 2 hours"
- **Inhibition**: if datacenter is down, suppress individual service alerts

→ Continue to: `01-architecture-and-components.md`
