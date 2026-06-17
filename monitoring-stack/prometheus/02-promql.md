# Prometheus — Part 02: PromQL — The Query Language

PromQL is the language you use to ask Prometheus questions. It looks intimidating at first, but it follows a small set of patterns. Once you understand those patterns, you can write any query.

---

## The Two Basic Data Types

### Instant Vector
A set of time series where each series has ONE value at a specific point in time.

```promql
http_requests_total
```

Returns: all time series matching this metric name, each with their current value.

### Range Vector
A set of time series where each series has a RANGE of values over a time window. Always written with `[duration]`.

```promql
http_requests_total[5m]
```

Returns: all time series, each with all values from the last 5 minutes. Range vectors are used inside functions like `rate()`, `increase()`, `avg_over_time()`.

---

## Label Matching — Filtering Time Series

```promql
# Exact match
http_requests_total{job="vault-api"}

# Multiple labels (AND logic)
http_requests_total{job="vault-api", status="200"}

# Regex match (~=)
http_requests_total{status=~"5.."}      # matches 500, 501, 502, 503...
http_requests_total{status=~"2..|3.."}  # 2xx or 3xx

# Regex NOT match (!~)
http_requests_total{status!~"2.."}      # not 2xx

# Not equal (!=)
http_requests_total{job!="blackbox"}

# Combine
http_requests_total{job="vault-api", status=~"5..", path!="/health"}
```

---

## Functions — The Real Power of PromQL

### rate() — Per-Second Rate of a Counter

`rate()` calculates the per-second average rate of increase of a counter over a time window.

```promql
rate(http_requests_total[5m])
```

This answers: "How many requests per second, averaged over the last 5 minutes?"

Why use rate instead of the raw counter?
- The raw counter is always increasing — it's not useful on a graph
- `rate()` gives you the rate of change — how fast the counter is growing
- If the counter resets (pod restart), `rate()` handles it correctly

```promql
# Requests per second by service
rate(http_requests_total[5m])

# Error rate (5xx errors per second)
rate(http_requests_total{status=~"5.."}[5m])

# Error rate as a percentage
rate(http_requests_total{status=~"5.."}[5m])
/
rate(http_requests_total[5m])
* 100
```

### increase() — Total Increase Over a Window

```promql
increase(http_requests_total[1h])
```

"How many requests total in the last hour?" — not per second, but total count.

### irate() — Instant Rate (Last Two Samples)

Like `rate()` but only uses the last two data points. More sensitive to spikes but noisier.

```promql
irate(http_requests_total[5m])
```

Use `rate()` for dashboards (smoother). Use `irate()` for alerting (faster to respond).

---

## Aggregation Operators

These reduce multiple time series into fewer series or a single value.

```promql
# Sum all time series matching the selector
sum(http_requests_total)

# Sum and keep certain labels in the result
sum(rate(http_requests_total[5m])) by (service)
# Result: one time series per unique "service" label value

# Sum and drop certain labels
sum(rate(http_requests_total[5m])) without (instance, pod)

# Average
avg(container_memory_usage_bytes) by (namespace)

# Maximum
max(container_cpu_usage_seconds_total) by (node)

# Minimum
min(up) by (job)

# Count (how many time series)
count(http_requests_total) by (service)

# 95th percentile (from histograms)
histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))
```

---

## Real Queries You'll Actually Use

### Request Rate

```promql
# Total requests per second across all services
sum(rate(http_requests_total[5m]))

# Requests per second per service
sum(rate(http_requests_total[5m])) by (service)

# Requests per second for a specific service
sum(rate(http_requests_total{service="vault-api"}[5m]))
```

### Error Rate

```promql
# Error rate percentage per service
100 * sum(rate(http_requests_total{status=~"5.."}[5m])) by (service)
    / sum(rate(http_requests_total[5m])) by (service)

# Error rate for a specific service (alert-friendly)
sum(rate(http_requests_total{service="vault-api", status=~"5.."}[5m]))
/ sum(rate(http_requests_total{service="vault-api"}[5m]))
> 0.05     # alert if > 5%
```

### Latency (requires Histogram metrics)

```promql
# P50 (median) latency
histogram_quantile(0.5, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))

# P95 latency
histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))

# P99 latency
histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))

# P95 per service
histogram_quantile(0.95,
  sum(rate(http_request_duration_seconds_bucket{service="vault-api"}[5m])) by (le, service)
)
```

### CPU and Memory

```promql
# CPU usage per container (as % of limit)
100 * sum(rate(container_cpu_usage_seconds_total{container!=""}[5m])) by (container, pod)
    / sum(container_spec_cpu_quota{container!=""} / container_spec_cpu_period{container!=""}) by (container, pod)

# Memory usage per container
container_memory_working_set_bytes{container!=""}

# Memory usage as % of limit
100 * container_memory_working_set_bytes{container!=""}
    / container_spec_memory_limit_bytes{container!=""}

# Node CPU usage
100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) by (instance) * 100)

# Node memory available
node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes * 100
```

### Service Health

```promql
# Is a target up? (1 = up, 0 = down)
up{job="vault-api"}

# Which services are down?
up == 0

# Count of healthy vs unhealthy
sum(up) by (job)

# Uptime since last restart
time() - process_start_time_seconds{job="vault-api"}
```

### Kubernetes Specific

```promql
# Pod restart count (from kube-state-metrics)
kube_pod_container_status_restarts_total

# Pods not running
kube_pod_status_phase{phase!="Running", phase!="Succeeded"}

# Deployment desired vs available replicas
kube_deployment_status_replicas_available{namespace="production"}
/ kube_deployment_spec_replicas{namespace="production"}
< 1

# PVC usage
kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes * 100
```

---

## Binary Operators and Matching

```promql
# Divide two metrics (must have matching labels)
rate(http_errors_total[5m]) / rate(http_requests_total[5m])

# Ignoring label differences
rate(http_errors_total[5m]) / ignoring(method) rate(http_requests_total[5m])

# Group_left — one-to-many join
rate(http_errors_total[5m]) * on(pod) group_left(node) kube_pod_info
```

---

## Subqueries

```promql
# Max of 5-minute rate, over the last hour (samples every 1 minute)
max_over_time(rate(http_requests_total[5m])[1h:1m])
```

---

## PromQL Tips and Gotchas

**Tip 1: Always use rate() with counters on dashboards**
```promql
# Wrong: shows ever-increasing counter — useless on a graph
http_requests_total

# Right: shows rate of change — actually useful
rate(http_requests_total[5m])
```

**Tip 2: The [5m] window should be > 2x the scrape interval**
If Prometheus scrapes every 15s, use at least `[1m]` (but `[5m]` is safer and smoother).

**Tip 3: Use sum() by () to aggregate across pods**
```promql
# This gives you one line per pod — useful for debugging
rate(http_requests_total[5m])

# This gives you the total across all pods — useful for dashboards
sum(rate(http_requests_total[5m])) by (service)
```

**Tip 4: histogram_quantile requires le label**
```promql
# WRONG — missing by (le)
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# CORRECT
histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))

# If you want per-service P95, keep service in the by clause
histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le, service))
```

---

## Common Misunderstanding: "rate() and irate() are interchangeable"

**The misunderstanding:** "I'll use irate() because it's faster to respond to changes."

**The reality:** They serve different purposes:

| | `rate()` | `irate()` |
|--|---------|----------|
| Uses | All samples in window | Last 2 samples only |
| Behavior | Smooth average | Spiky, instant |
| Good for | Dashboards, trend analysis | Short-lived spikes, alerting |
| Staleness | Handles gaps better | Very sensitive to scrape gaps |

Using `irate()` on a dashboard produces a noisy, spikey graph that's hard to read. Using `rate()` for alerting means the alert might be delayed by the full window duration before firing. Use the right one for the right job — `rate()` for dashboards, `irate()` sparingly for very latency-sensitive alerts.

→ Continue to: `03-deployment-modes.md`
