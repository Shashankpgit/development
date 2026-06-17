# Loki — Part 02: Deployment, Configuration, and Setup

---

## Loki Configuration File

Loki is configured via a single YAML file. Here's a production-ready configuration for the SSD (Simple Scalable) deployment mode:

```yaml
# loki-config.yaml

auth_enabled: false    # set to true in multi-tenant setups

server:
  http_listen_port: 3100
  grpc_listen_port: 9096

common:
  path_prefix: /loki
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules
  replication_factor: 1
  ring:
    instance_addr: 0.0.0.0
    kvstore:
      store: inmemory

schema_config:
  configs:
    - from: 2024-01-01
      store: tsdb             # tsdb is the recommended index store
      object_store: filesystem
      schema: v13
      index:
        prefix: index_
        period: 24h           # create new index table every 24 hours

storage_config:
  tsdb_shipper:
    active_index_directory: /loki/index
    cache_location: /loki/index_cache
  filesystem:
    directory: /loki/chunks

compactor:
  working_directory: /loki/retention
  compaction_interval: 10m
  retention_enabled: true
  retention_delete_delay: 2h
  delete_request_store: filesystem

limits_config:
  retention_period: 30d          # delete logs older than 30 days
  ingestion_rate_mb: 16          # max 16MB/s ingestion per tenant
  ingestion_burst_size_mb: 32
  max_entries_limit_per_query: 5000
  max_query_series: 500

ruler:
  alertmanager_url: http://alertmanager:9093
```

---

## Docker Compose Setup — Complete PLG Stack

PLG = Promtail + Loki + Grafana (the Loki-centric equivalent of ELK)

```yaml
# docker-compose.yml
version: '3.8'

services:
  loki:
    image: grafana/loki:2.9.0
    ports:
      - "3100:3100"
    command: -config.file=/etc/loki/loki-config.yaml
    volumes:
      - ./loki-config.yaml:/etc/loki/loki-config.yaml
      - loki-data:/loki
    restart: unless-stopped

  alloy:               # log collection agent (replaces Promtail)
    image: grafana/alloy:latest
    ports:
      - "12345:12345"  # Alloy web UI
    command:
      - run
      - --server.http.listen-addr=0.0.0.0:12345
      - /etc/alloy/config.alloy
    volumes:
      - ./alloy-config.alloy:/etc/alloy/config.alloy
      - /var/log:/var/log:ro           # read host logs
      - /var/lib/docker/containers:/var/lib/docker/containers:ro
    restart: unless-stopped

  prometheus:
    image: prom/prometheus:v2.45.0
    ports:
      - "9090:9090"
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.retention.time=15d'
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus-data:/prometheus
    restart: unless-stopped

  grafana:
    image: grafana/grafana:10.0.0
    ports:
      - "3000:3000"
    environment:
      GF_SECURITY_ADMIN_PASSWORD: admin
    volumes:
      - grafana-data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning
    depends_on:
      - loki
      - prometheus
    restart: unless-stopped

volumes:
  loki-data:
  prometheus-data:
  grafana-data:
```

---

## Kubernetes Deployment With Helm

```bash
# Add Grafana Helm repo
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Install Loki (SSD mode — read/write separated)
helm install loki grafana/loki \
  --namespace monitoring \
  --create-namespace \
  -f loki-values.yaml
```

```yaml
# loki-values.yaml
loki:
  commonConfig:
    replication_factor: 1
  storage:
    type: s3
    s3:
      region: ap-south-1
      bucketnames: my-loki-bucket
      s3forcepathstyle: false
  auth_enabled: false
  limits_config:
    retention_period: 30d
    ingestion_rate_mb: 16

# Loki in SSD mode
deploymentMode: SingleBinary     # or: SimpleScalable, Distributed

singleBinary:
  replicas: 1

# For high availability, use SimpleScalable:
# read:
#   replicas: 2
# write:
#   replicas: 3
# backend:
#   replicas: 1
```

---

## Loki Alerting Rules

Loki can evaluate LogQL metric queries as alerting rules, just like Prometheus:

```yaml
# loki-rules.yaml
groups:
  - name: application-alerts
    rules:
      # Alert when error rate is high
      - alert: HighLogErrorRate
        expr: |
          sum(rate({namespace="production"} | json | level="error" [5m])) by (service)
          > 1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High error log rate on {{ $labels.service }}"
          description: "{{ $labels.service }} is logging {{ $value }} errors/second"

      # Alert on OOM kills detected in logs
      - alert: OOMKillDetected
        expr: |
          count_over_time({namespace="production"} |= "OOMKilled" [5m]) > 0
        labels:
          severity: critical
        annotations:
          summary: "OOMKill detected in namespace production"
```

---

## Retention and Storage

Loki's retention is configured in `limits_config`:

```yaml
limits_config:
  retention_period: 30d      # keep logs for 30 days
  # per-tenant override:
  # per_tenant_override_config: /etc/loki/overrides.yaml
```

For S3 storage, also configure lifecycle rules in S3 to delete objects after the retention period (belt-and-suspenders).

**Storage sizing:**
- Loki compresses logs very well (typically 10:1 to 20:1 compression ratio)
- 100GB raw logs per day → ~5-10GB compressed in Loki
- This makes Loki extremely cost-effective for long retention

---

## Monitoring Loki Itself

Loki exposes Prometheus metrics at `/metrics`. Key metrics to watch:

```promql
# Ingestion rate
rate(loki_ingester_streams_created_total[5m])

# Query duration
histogram_quantile(0.95, sum(rate(loki_logql_querystats_ingester_sent_lines_total[5m])) by (le))

# Storage operations
rate(loki_boltdb_shipper_compact_tables_operation_total[5m])

# Whether Loki is healthy
up{job="loki"}
```

---

## Common Misunderstanding: "Loki stores logs indefinitely by default"

**The misunderstanding:** "I set up Loki and it'll just keep my logs forever."

**The reality:** Without explicit retention configuration, Loki keeps logs indefinitely (until your disk fills up and Loki crashes). You MUST configure retention.

The compactor component handles retention, but it needs to be enabled:

```yaml
compactor:
  working_directory: /loki/retention
  compaction_interval: 10m
  retention_enabled: true     # ← must be explicitly true
  retention_delete_delay: 2h
  delete_request_store: filesystem

limits_config:
  retention_period: 30d      # ← must be set
```

Also, `retention_enabled: true` must be in the compactor block, NOT just the limits_config. Both are required.

In production, test your retention by:
1. Setting a short retention (e.g., 1h) in staging
2. Waiting for the compactor to run
3. Verifying old data is deleted
4. Then set your real retention before going to production
