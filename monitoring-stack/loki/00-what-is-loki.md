# Loki — Part 00: What Is Loki and How Is It Different?

---

## The Problem With Traditional Log Management

Before Loki, the go-to log management stack was **Elasticsearch + Logstash + Kibana (ELK)**. It works, but:

- Elasticsearch is **extremely resource-hungry** — indexing 10GB of logs/day requires significant CPU and memory
- It indexes EVERY word in every log line — powerful but expensive
- Operating Elasticsearch well (shards, replicas, index management) is a specialized skill
- The cost scales directly with log volume — more logs = much more money and compute

Grafana Labs built Loki with a different philosophy:

> **"What if logs worked like Prometheus?"**

---

## Loki's Core Design Philosophy

Loki does NOT index the content of your logs. Instead, it only indexes the **labels** you attach to log streams.

```
Traditional (Elasticsearch):
  Index EVERYTHING in every log line:
  "ERROR: connection refused at localhost:5432 (retried 3 times)"
  → index: "ERROR", "connection", "refused", "localhost", "5432", "retried", "3", "times"
  → You can search by any word instantly, but storage/CPU cost is high

Loki approach:
  Only index the labels (stream metadata):
  Labels: {service="vault-api", namespace="production", level="error"}
  Log content is compressed and stored as-is
  → You search by labels first (fast), then grep the content (slower but cheap)
```

**The result:**
- 10-100x cheaper to run than Elasticsearch
- Much simpler to operate
- Works perfectly alongside Prometheus (same label-based model)
- Searches within a stream are full-text grep (fast enough for most use cases)

**The trade-off:**
- Ad-hoc searches across all logs without label filtering are slow
- Full-text search across all data is not as instant as Elasticsearch
- Best used when you know what you're looking for (filter by service, then search)

---

## Loki Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                           Loki                                        │
│                                                                       │
│  Log Agent (Alloy/Promtail)                                          │
│  ────────────────────────────                                         │
│  Reads logs from /var/log/*                                          │
│  Adds labels (service, namespace, pod, node)                         │
│  Sends to Loki                                                        │
│           │                                                           │
│           ▼                                                           │
│  ┌─────────────────────────────────────────────────────────────────┐ │
│  │  Distributor                                                    │ │
│  │  - Receives incoming log streams                                │ │
│  │  - Validates and replicates to ingesters                        │ │
│  └──────────────────┬──────────────────────────────────────────────┘ │
│                     │                                                 │
│  ┌──────────────────▼──────────────────────────────────────────────┐ │
│  │  Ingester                                                       │ │
│  │  - Receives log chunks                                          │ │
│  │  - Builds inverted index for labels                             │ │
│  │  - Buffers recent data in memory                                │ │
│  │  - Flushes chunks to storage (S3, GCS, local disk)             │ │
│  └──────────────────┬──────────────────────────────────────────────┘ │
│                     │                                                 │
│  ┌──────────────────▼──────────────────────────────────────────────┐ │
│  │  Querier + Query Frontend                                       │ │
│  │  - Receives LogQL queries from Grafana/LogCLI                   │ │
│  │  - Queries index (labels) to find matching chunks               │ │
│  │  - Fetches and decompresses log chunks from storage             │ │
│  │  - Returns matching log lines                                   │ │
│  └──────────────────────────────────────────────────────────────────┘ │
│                                                                       │
│  Storage:                                                             │
│  - Index: BoltDB Shipper (local) or Cassandra/DynamoDB              │
│  - Chunks: S3, GCS, Azure Blob, local filesystem                    │
└─────────────────────────────────────────────────────────────────────┘
```

### The Four Core Components

**Distributor**: The entry point. Validates incoming log streams, applies rate limiting, and replicates writes across multiple ingesters for reliability. Stateless — can be scaled horizontally easily.

**Ingester**: The write path. Holds recent logs in memory in a compressed format, builds the index, and periodically flushes chunks to long-term storage. Stateful — each ingester owns specific log streams.

**Querier**: The read path. Given a LogQL query, finds matching chunks in the index, fetches them from storage, decompresses them, and runs the filter/regex to find matching log lines.

**Query Frontend**: Optional but important in production. Splits large queries into smaller parallel subqueries, caches results, and queues requests to prevent overload.

---

## Labels — The Most Important Concept

Labels in Loki serve the same purpose as labels in Prometheus: they identify log streams.

```
{service="vault-api", namespace="production", pod="vault-api-7d4b9c-xyz", level="error"}
```

Each unique combination of label values = one **log stream**. Logs within a stream must be appended in time order.

**Good labels (low cardinality, meaningful grouping):**
- `service` / `app` — which service produced the log
- `namespace` / `environment` — which environment
- `level` — log level (info, warn, error, debug)
- `node` — which server

**Bad labels (high cardinality — will cause performance problems):**
- `pod_id` (every pod restart creates a new stream)
- `user_id` (potentially millions of unique values)
- `request_id` (unique per request)
- `ip_address` (millions of possible values)

High cardinality = many unique label combinations = many streams = large index = slow queries and high memory usage.

**Rule of thumb:** if a label value is something a user would type to identify what they're looking at in a system, it's probably fine. If it's something generated by the system (UUIDs, IPs, request IDs), it should be extracted from log content, not used as a label.

---

## Log Shipping — Getting Logs into Loki

Loki doesn't pull logs. Agents running on your machines or Kubernetes cluster push logs to Loki.

### Promtail (classic agent, now replaced by Alloy)

Promtail was the original log agent for Loki. It:
- Tails log files on disk (`/var/log/*.log`)
- Reads Kubernetes pod logs from `/var/lib/docker/containers/`
- Extracts labels from the file path or Kubernetes metadata
- Sends to Loki

### Grafana Alloy (current recommended agent)

Alloy is the successor to both Promtail and Grafana Agent. It ships logs, metrics, and traces in one agent. Covered in depth in the Alloy guide.

### Docker Logging Driver

Send Docker container logs directly to Loki without any agent on disk:

```yaml
# docker-compose.yml
services:
  vault-api:
    image: vault-app:v1.0
    logging:
      driver: loki
      options:
        loki-url: "http://loki:3100/loki/api/v1/push"
        loki-external-labels: "service=vault-api,environment=production"
```

### Kubernetes: Alloy as DaemonSet

Deploy Alloy on every node to collect all container logs:

```yaml
# Alloy runs as a DaemonSet, reads /var/log/pods/* on each node
# Automatically enriches logs with Kubernetes metadata:
# {namespace, pod, container, node, service}
```

---

## Deployment Modes

### Monolithic Mode (Single Binary)

All components (distributor, ingester, querier, etc.) run in one process. Simplest to deploy and operate.

```yaml
# loki-config.yaml
target: all          # run everything in one process
```

```bash
docker run -d \
  --name loki \
  -p 3100:3100 \
  -v $(pwd)/loki-config.yaml:/etc/loki/loki.yaml \
  grafana/loki:latest \
  -config.file=/etc/loki/loki.yaml
```

**Pros:** Simple, no inter-service communication overhead
**Cons:** Vertical scaling only, one component failure affects everything

Use when: small to medium log volumes, single server or simple setups, ≤ 100GB/day ingestion.

### Simple Scalable Deployment (SSD)

Splits Loki into two groups:
- **Read** path: query-frontend + querier
- **Write** path: distributor + ingester

```yaml
target: read   # for read-path pods
target: write  # for write-path pods
```

Read and write paths scale independently. Store data in S3/GCS.

**Pros:** Can scale reads and writes separately, good for Kubernetes
**Cons:** Needs object storage backend (S3/GCS), more configuration

Use when: production Kubernetes deployment, > 50GB/day ingestion, need to scale.

### Microservices Mode

Every component runs as a separate service. Maximum scalability and resilience.

```
distributor × 3
ingester × 6
querier × 4
query-frontend × 2
compactor × 1
ruler × 1
```

**Pros:** Each component scales independently, granular failure isolation
**Cons:** Complex to operate, requires a service mesh or careful networking

Use when: very large scale (TB/day), multiple teams, dedicated platform engineering team.

---

## Common Misunderstanding: "Loki is a replacement for Elasticsearch"

**The misunderstanding:** "We're switching to Loki because it's cheaper — we'll get the same capabilities."

**The reality:** Loki and Elasticsearch are designed for different use cases:

| Capability | Loki | Elasticsearch |
|-----------|------|---------------|
| Cost (at scale) | Much cheaper | Expensive |
| Full-text search without labels | Slow | Fast |
| Aggregations on content | Limited | Powerful |
| Setup complexity | Simple | Complex |
| Label-based filtering | Excellent | Good |
| Log volumes at low cost | Excellent | Poor |
| Analytics on log content | Limited | Excellent |

If your primary use case is "I want to search my application logs, filtered by service and time window, and see the raw lines" → Loki is perfect.

If your use case is "I need to aggregate log content, run complex analytics, or do full-text search across all logs without knowing the service" → Elasticsearch is better.

Most organizations doing cloud-native development are better served by Loki. Large security/compliance teams needing full-text search often keep Elasticsearch for that use case.

→ Continue to: `01-logql.md`
