# Grafana — Part 01: Dashboards, Panels, and Variables

---

## Configuring a Data Source

Before building dashboards, you must configure at least one data source.

**Via UI:** Configuration (gear icon) → Data Sources → Add data source → Prometheus

```
URL: http://prometheus:9090        (if Prometheus is on the same Docker network or K8s cluster)
     http://localhost:9090         (if Grafana is running on the same host)
Access: Server (default)           (Grafana's backend makes the request, not your browser)
```

**Via provisioning (preferred for automated setups):**

```yaml
# /etc/grafana/provisioning/datasources/datasources.yaml
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    jsonData:
      timeInterval: "15s"     # match your Prometheus scrape_interval

  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100

  - name: PostgreSQL
    type: postgres
    url: postgres:5432
    database: vault
    user: grafana_readonly
    secureJsonData:
      password: readonlypassword
    jsonData:
      sslmode: disable
```

When Grafana starts, it reads this file and creates the data sources automatically. No manual UI setup needed.

---

## Building a Dashboard

### Creating a New Dashboard

1. Click + in the left sidebar → Dashboard
2. Click "Add visualization"
3. Select your data source
4. Write your query
5. Choose panel type
6. Set title, units, thresholds
7. Save

### Panel Configuration Walkthrough

```
┌──────────────────────────────────────────────────────────────┐
│  Panel Editor                                                 │
│                                                               │
│  Query editor:                                                │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │ A: sum(rate(http_requests_total{service="$service"}[5m]))│ │
│  │    by (status)                                           │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                               │
│  Panel options:                                               │
│  - Title: "Requests per second"                               │
│  - Description: "HTTP request rate by status code"            │
│                                                               │
│  Visualization settings:                                      │
│  - Type: Time series                                          │
│  - Unit: reqps (requests per second)                          │
│  - Fill opacity: 10                                           │
│  - Show points: Never                                         │
│                                                               │
│  Thresholds:                                                  │
│  - Red: > 1000 rps                                            │
└──────────────────────────────────────────────────────────────┘
```

### Important Panel Settings

**Units:** Always set the correct unit. Grafana formats values intelligently:
- `bytes` → auto-converts to KB, MB, GB as needed
- `percent (0-100)` → adds "%" suffix
- `ms` → milliseconds
- `reqps` → requests per second
- `short` → abbreviates (10K, 1M)

**Legend:** Customize how series are labeled:
```
Legend format: {{service}} - {{status}}
→ Shows: "vault-api - 200", "vault-api - 500"
```

**Thresholds:** Add color coding:
```
Green: 0
Yellow: 500
Red: 1000
(turns the panel yellow/red when the value exceeds those levels)
```

**Null value handling:**
- `Null` → missing data shows gaps in the line
- `Zero` → missing data shows as 0
- `Connected` → draws line across gaps

---

## Template Variables — Making Dashboards Dynamic

Variables turn a hardcoded dashboard into a flexible one that works for any service, namespace, or environment.

### Create a Variable

Dashboard settings → Variables → New variable

**Query variable (from Prometheus):**
```
Name: service
Label: Service
Type: Query
Data source: Prometheus
Query: label_values(http_requests_total, service)
# This runs the PromQL and returns all unique values of the "service" label
Multi-value: true      # allow selecting multiple services
Include All option: true
```

**Custom variable (manual list):**
```
Name: environment
Type: Custom
Values: production, staging, development
```

**Interval variable (for time window selection):**
```
Name: interval
Type: Interval
Values: 1m, 5m, 15m, 30m, 1h
```

### Using Variables in Queries

```promql
# Panel query using $service and $interval variables
sum(rate(http_requests_total{service="$service"}[$interval])) by (status)

# Multiple variables
sum(
  rate(
    http_requests_total{
      service=~"$service",      # =~ for multi-select
      namespace="$namespace"
    }[$interval]
  )
) by (status)
```

### Chained Variables

Variables can depend on each other:

```
Variable: namespace
Query: label_values(kube_pod_info, namespace)
→ returns: production, staging, monitoring

Variable: pod
Query: label_values(kube_pod_info{namespace="$namespace"}, pod)
→ returns only pods in the selected namespace
```

Selecting "production" in the namespace dropdown automatically updates the pod dropdown.

---

## Dashboard Annotations

Annotations mark events on time series charts. Useful for correlating "something changed at this time."

**Query-based annotation from Prometheus:**
```
Data source: Prometheus
Query: changes(kube_deployment_status_replicas{deployment="vault-api"}[2m]) > 0
Title: Deployment change
```

This draws a vertical line on all panels whenever a deployment change is detected.

**Manual annotation:** Click a point on a graph → Add annotation. Add a note like "deployed v2.0".

---

## Dashboard Provisioning — Auto-Deploy Dashboards

Instead of manually creating dashboards in the UI, you can provision them from JSON files. When Grafana starts, it loads the dashboards automatically.

```yaml
# /etc/grafana/provisioning/dashboards/dashboards.yaml
apiVersion: 1

providers:
  - name: default
    folder: Infrastructure
    type: file
    options:
      path: /etc/grafana/dashboards    # Grafana loads all JSON files from here
```

```bash
# Your dashboard JSON files go here
/etc/grafana/dashboards/
├── kubernetes-cluster.json
├── vault-api.json
└── node-overview.json
```

**How to get dashboard JSON files:**
1. Build a dashboard in the UI
2. Dashboard settings → JSON model → copy
3. Save as a `.json` file

Or download pre-built dashboards from `grafana.com/dashboards` — search for "kubernetes", "node exporter", etc. Each has an ID you can import directly.

**Import from grafana.com:**
1. Find the dashboard (e.g., Node Exporter Full: ID 1860)
2. Grafana UI → Import → Enter ID: 1860 → Load
3. Select data source → Import

---

## Building a Practical Dashboard: Kubernetes Overview

Here's what a useful Kubernetes namespace dashboard looks like:

```
Row 1: Summary stats
  [Stat] Pod count: count(kube_pod_info{namespace="$namespace"})
  [Stat] Running pods: count(kube_pod_status_phase{namespace="$namespace", phase="Running"})
  [Stat] Error rate: sum(rate(http_requests_total{namespace="$namespace", status=~"5.."}[5m]))
  [Stat] P95 latency: histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket{namespace="$namespace"}[5m])) by (le))

Row 2: Request rate and errors
  [Time series] Request rate by service:
    sum(rate(http_requests_total{namespace="$namespace"}[5m])) by (service)
  [Time series] Error rate %:
    100 * sum(rate(http_requests_total{namespace="$namespace", status=~"5.."}[5m])) by (service)
      / sum(rate(http_requests_total{namespace="$namespace"}[5m])) by (service)

Row 3: Resources
  [Time series] CPU usage by pod:
    sum(rate(container_cpu_usage_seconds_total{namespace="$namespace"}[5m])) by (pod)
  [Time series] Memory by pod:
    container_memory_working_set_bytes{namespace="$namespace"}

Row 4: Logs (Loki)
  [Logs panel] Application logs:
    {namespace="$namespace"} |= "$search_term"
```

---

## Common Misunderstanding: "More panels = better dashboard"

**The misunderstanding:** "I'll add every metric I can think of to my dashboard so I have full visibility."

**The reality:** A dashboard with 40 panels is a noise machine, not a monitoring tool. When something goes wrong, you spend 10 minutes scanning panels before finding the problem.

**The better approach:** Design dashboards around questions you actually need to answer:

1. **Overview dashboard**: Is everything healthy? 3-5 stat panels. Red/green. Done.
2. **Drill-down dashboard**: Something is wrong — where exactly? More detailed. Used rarely.
3. **Capacity dashboard**: How are resources trending? Used weekly/monthly.

Each dashboard should have a clear purpose. If you can't describe the dashboard in one sentence ("shows request rate, error rate, and latency for the API service"), it's too broad.

The USE method for dashboards (Brendan Gregg):
- **U**tilization: how much of the resource is being used?
- **S**aturation: how much work is waiting?
- **E**rrors: how many errors are occurring?

These three questions, answered per service/resource, cover 80% of operational needs.

→ Continue to: `02-alerting.md`
