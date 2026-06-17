# Grafana — Part 00: What Is Grafana and How Does It Work?

---

## The Problem Grafana Solves

Prometheus can answer questions through PromQL, but the interface is a basic query box. Loki can search logs, but not visually. You need a tool that:
- Connects to ALL your data sources (Prometheus, Loki, Elasticsearch, databases, cloud metrics)
- Lets you build visual dashboards without writing code
- Lets multiple people share and view the same dashboards
- Sends alerts when thresholds are breached
- Works as the single pane of glass for your entire infrastructure

**Grafana is that tool.** It is the visualization and observability platform that sits in front of your monitoring data. It doesn't collect data — it queries and displays data from any source.

---

## What Grafana Is (and Isn't)

**Grafana IS:**
- A data visualization and dashboarding tool
- A frontend for Prometheus, Loki, Elasticsearch, databases, and dozens of other sources
- An alert management UI
- A collaboration tool (share dashboards, annotations, teams)

**Grafana is NOT:**
- A data store (it doesn't store metrics or logs)
- A replacement for Prometheus or Loki (it needs them as backends)
- A log ingestion tool

The mental model:
```
Data Sources                    Grafana
─────────────                   ───────────────────────────────────
Prometheus ───────────────────► Queries with PromQL → Line charts
Loki ─────────────────────────► Queries with LogQL → Log panels
PostgreSQL ───────────────────► SQL queries → Tables, bar charts
CloudWatch ───────────────────► AWS metrics → Dashboards
Elasticsearch ────────────────► Full-text search → Log exploration
```

---

## Grafana Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                        Grafana Server                             │
│                                                                   │
│  ┌──────────────────┐    ┌─────────────────────────────────────┐ │
│  │   Web UI         │    │         Backend                     │ │
│  │   (React SPA)    │    │                                     │ │
│  │                  │    │  - REST API                         │ │
│  │  Dashboard        │    │  - Dashboard/alert storage          │ │
│  │  Panel editor     │    │  - User management                  │ │
│  │  Alert UI         │    │  - Plugin management                │ │
│  │  Explore          │    │  - Data source proxy                │ │
│  └──────────────────┘    └───────────────┬─────────────────────┘ │
│                                           │                        │
└───────────────────────────────────────────┼────────────────────────┘
                                            │ queries
              ┌─────────────────────────────┼─────────────────────┐
              │                             │                      │
              ▼                             ▼                      ▼
        Prometheus                        Loki                PostgreSQL
        (metrics)                         (logs)              (data)
```

The Grafana backend acts as a proxy — your browser talks to Grafana, Grafana talks to the actual data sources. This means:
- Data source credentials are stored in Grafana, not your browser
- Grafana can reach internal data sources that aren't exposed publicly
- You query through Grafana's API, not directly against Prometheus/Loki

---

## Core Concepts

### Data Source
A connection to a backend data system. You configure data sources in Grafana once, then reference them in panels.

Common data sources:
- Prometheus / Thanos / Cortex / VictoriaMetrics
- Loki (log aggregation)
- Tempo (distributed tracing)
- Elasticsearch / OpenSearch
- MySQL, PostgreSQL, Microsoft SQL Server
- AWS CloudWatch, Azure Monitor, Google Cloud Monitoring
- InfluxDB, Graphite, OpenTSDB
- JSON API (query any REST endpoint)

### Dashboard
A collection of panels arranged on a grid. Dashboards are stored as JSON in Grafana's database (by default, SQLite). They can be exported/imported, version controlled, and provisioned automatically.

### Panel
A single visualization widget on a dashboard. Panel types:
- **Time series**: the default — lines/bars over time
- **Stat**: single big number with optional sparkline
- **Gauge**: circular or bullet gauge for "current value within a range"
- **Bar chart**: comparison across categories
- **Table**: tabular data
- **Logs**: log lines from Loki/Elasticsearch
- **Heatmap**: 2D color grid, great for latency distributions
- **Geomap**: world/region map for geo-distributed data
- **Text**: markdown/HTML content
- **Alertlist**: shows current alert states
- **Traces**: distributed traces from Tempo

### Variable
A template variable defined at the dashboard level that panels can reference. Lets one dashboard work for all services/namespaces/environments.

```
Dashboard variable: $namespace = [all, production, staging, monitoring]
Panel query: sum(rate(http_requests_total{namespace="$namespace"}[5m]))

When you change the dropdown to "staging", all panels update automatically.
```

### Annotation
A vertical line on a time series panel marking an event (deployment, incident, maintenance). Can be added manually or from a data source.

---

## Explore — Ad Hoc Querying

Explore is Grafana's query workbench. No dashboard needed — just pick a data source and run queries. Essential for debugging:

- Go to Grafana → Explore
- Select Prometheus → run PromQL queries
- Select Loki → run LogQL queries
- Use "split view" to compare Prometheus metrics and Loki logs side by side for the same time window

---

## Grafana Deployment Modes

### OSS (Open Source)
The free, self-hosted version. Has all core features: dashboards, alerting, data sources, plugins.

Missing vs Cloud:
- No built-in SSO (you set up your own with OAuth/LDAP)
- Dashboard sharing requires self-hosting
- No managed storage

```yaml
# docker-compose.yml
services:
  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    environment:
      GF_SECURITY_ADMIN_PASSWORD: mysecretpassword
      GF_DATABASE_TYPE: postgres       # use postgres instead of SQLite for production
      GF_DATABASE_HOST: postgres:5432
      GF_DATABASE_NAME: grafana
      GF_DATABASE_USER: grafana
      GF_DATABASE_PASSWORD: grafanapass
    volumes:
      - grafana-data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning  # auto-configure dashboards
```

### Grafana Cloud
Fully managed SaaS. Includes:
- Grafana UI (hosted)
- Prometheus-compatible metrics storage (Mimir)
- Loki for logs
- Tempo for traces
- Free tier available (10K series, 50GB logs, 14-day retention)

No infrastructure to manage. Just register, configure your data sources (or use the Grafana Agent to forward), and start dashboarding.

### Grafana Enterprise
Like OSS, but with enterprise features:
- Advanced SAML/LDAP/OAuth SSO
- Reporting (PDF/CSV export of dashboards)
- Enhanced team management and permissions
- Data source level permissions (team A can only see service A's data)
- License-based (paid)

### Grafana on Kubernetes

```yaml
# Using the official Grafana Helm chart
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

helm install grafana grafana/grafana \
  --namespace monitoring \
  --set persistence.enabled=true \
  --set persistence.size=10Gi \
  --set adminPassword=mysecretpassword \
  --set datasources."datasources\.yaml".apiVersion=1 \
  --set datasources."datasources\.yaml".datasources[0].name=Prometheus \
  --set datasources."datasources\.yaml".datasources[0].type=prometheus \
  --set datasources."datasources\.yaml".datasources[0].url=http://prometheus:9090
```

---

## Installing Plugins

Grafana has 100+ plugins for additional panel types and data sources.

```bash
# Install a plugin (inside container or on the host)
grafana-cli plugins install grafana-worldmap-panel
grafana-cli plugins install grafana-piechart-panel
grafana-cli plugins install grafana-clock-panel

# In docker, set via environment variable
environment:
  GF_INSTALL_PLUGINS: grafana-worldmap-panel,grafana-clock-panel
```

---

## Common Misunderstanding: "Grafana can alert on anything"

**The misunderstanding:** "I'll set up Grafana to alert when my Loki log contains 'ERROR'."

**The reality:** Grafana's alerting system can query any data source, but there are important limitations:

1. Grafana alerts work best with time-series metric data
2. Alerting on log data (Loki) requires Grafana 9+ with the Loki alerting feature, and it's more limited than Prometheus alerting rules
3. For complex alerting logic (multi-condition, cross-metric), Prometheus alerting rules are more powerful and have Alertmanager for routing

**The recommended architecture:**
- For metric-based alerts: define rules in Prometheus, route via Alertmanager
- Use Grafana Alerting as a convenience layer for simpler alerts that ops teams can manage in the UI
- Never put your only copy of alerting rules in Grafana if Prometheus could own them

→ Continue to: `01-dashboards-and-panels.md`
