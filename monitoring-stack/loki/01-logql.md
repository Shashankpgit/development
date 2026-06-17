# Loki — Part 01: LogQL — The Log Query Language

LogQL is Loki's query language. It's inspired by PromQL and follows a similar structure. Once you know PromQL, LogQL feels familiar.

---

## The Two Query Types

### Log Queries — Return Log Lines

A log query returns actual log lines. Use for: viewing logs in Grafana's Logs panel, LogCLI, Explore.

```logql
{service="vault-api"}                    # all logs from vault-api
{service="vault-api", level="error"}     # error logs from vault-api
```

### Metric Queries — Return Numbers Over Time

A metric query aggregates log data into numbers. Use for: Grafana panels, alerting, counting log events over time.

```logql
count_over_time({service="vault-api"}[5m])           # count of log lines in 5m windows
rate({service="vault-api", level="error"}[5m])        # error log rate per second
```

---

## Stream Selectors — The Starting Point

Every LogQL query starts with a stream selector in `{}`. This uses the labels you assigned when shipping logs.

```logql
# Exact match
{service="vault-api"}

# Multiple labels (AND)
{service="vault-api", namespace="production"}

# Regex match
{service=~"vault.*"}           # any service starting with "vault"
{namespace=~"prod.*|staging"}  # production or staging

# Not equal
{level!="debug"}               # everything except debug

# Regex not match
{service!~"test.*"}
```

---

## Pipeline Stages — Filter and Transform

After the stream selector, you can pipe the logs through filter/transform stages.

### Line Filter — Search Within Log Content

```logql
{service="vault-api"} |= "ERROR"             # lines containing "ERROR"
{service="vault-api"} != "healthcheck"        # lines NOT containing "healthcheck"
{service="vault-api"} |~ "failed.*connection" # regex match
{service="vault-api"} !~ "GET /health"        # regex not match

# Multiple filters (AND)
{service="vault-api"} |= "ERROR" |= "database"
```

### JSON Parser — Extract Fields From JSON Logs

Most modern apps log in JSON format. Loki can parse JSON and make fields available for filtering:

```logql
# Original log line: {"level":"error","msg":"connection refused","database":"postgres","retry":3}

{service="vault-api"} | json
# Now the fields level, msg, database, retry are extracted

# Filter on extracted fields
{service="vault-api"} | json | level="error"
{service="vault-api"} | json | database="postgres" | retry > 2

# Select specific fields (reduce memory usage)
{service="vault-api"} | json level, msg, database
```

### Logfmt Parser — Key=Value Logs

```logql
# Original: level=info msg="user created" user_id=12345 email=shashank@example.com

{service="vault-api"} | logfmt
{service="vault-api"} | logfmt | level="error"
{service="vault-api"} | logfmt | user_id="12345"
```

### Regex Parser — Custom Pattern Extraction

```logql
# Original: 2026-06-17 10:32:45 ERROR vault-api: Database timeout after 5000ms

{service="vault-api"} | regexp `(?P<ts>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}) (?P<level>\w+) (?P<service>[\w-]+): (?P<msg>.*)`
# Now: ts, level, service, msg are extracted
```

### Line Format — Reformat Output

```logql
{service="vault-api"} | json | line_format "{{.level}} | {{.msg}} | db={{.database}}"
# Output: error | connection refused | db=postgres
```

### Label Format — Add/Rename Labels

```logql
{service="vault-api"} | json | label_format error_msg=msg
# Renames extracted field "msg" to "error_msg" for use in metrics
```

---

## Metric Queries — Counting and Aggregating

### count_over_time — Count Log Lines

```logql
# How many error logs per 5-minute window?
count_over_time({service="vault-api", level="error"}[5m])

# With a filter stage
count_over_time({service="vault-api"} |= "database timeout"[5m])
```

### rate — Log Events Per Second

```logql
# Error logs per second
rate({service="vault-api", level="error"}[5m])

# All log lines per second (total log throughput)
rate({namespace="production"}[5m])
```

### bytes_over_time / bytes_rate — Log Volume

```logql
# Bytes of logs per service per 5 minutes
bytes_over_time({namespace="production"}[5m])

# Bytes per second per service
bytes_rate({namespace="production"}[5m])
```

### Aggregation Over Multiple Streams

```logql
# Total error rate across all services
sum(rate({namespace="production", level="error"}[5m]))

# Error rate per service
sum(rate({namespace="production", level="error"}[5m])) by (service)

# Top 5 services by log volume
topk(5, sum(rate({namespace="production"}[5m])) by (service))

# Error rate as percentage
sum(rate({namespace="production", level="error"}[5m])) by (service)
/
sum(rate({namespace="production"}[5m])) by (service)
```

---

## Real Queries You'll Actually Use

### Application Errors

```logql
# All errors from vault-api in the last hour
{service="vault-api"} |= "ERROR" | json | level="error"

# Error count per minute (for a Grafana panel)
sum(count_over_time({service="vault-api"} |= "error"[1m])) by (service)

# Specific error type
{namespace="production"} | json | msg =~ ".*database.*"

# Stack traces (multi-line — look for lines with leading spaces)
{service="vault-api"} |= "Exception" != "DEBUG"
```

### Kubernetes Pod Logs

```logql
# Logs from a specific pod
{pod="vault-api-7d4b9c-xyz"}

# All pods in a namespace
{namespace="production"}

# All containers in a pod
{pod="vault-api-7d4b9c-xyz"} 

# All restarts (look for OOMKilled or started messages)
{namespace="production"} |= "OOMKilled"
{namespace="production"} |= "Started container"

# Slow request logs (extract and filter)
{service="vault-api"} | json | duration > 1000
# requires your app logs duration as: {"duration": 1234, ...}
```

### Security and Audit Logs

```logql
# Failed login attempts
{service="vault-api"} | json | msg="authentication failed"

# Count failed logins per 5 minutes (for alerting)
sum(count_over_time({service="vault-api"} | json | msg="authentication failed" [5m]))

# Sudo/privilege escalation on Linux hosts
{job="systemd-journal", hostname=~"prod-.*"} |= "sudo"
```

### Log Rate Anomalies

```logql
# Is one service logging much more than usual? (rate per service)
sum(rate({namespace="production"}[5m])) by (service)
```

---

## LogQL in Grafana

### Logs Panel

```logql
# Query for a Grafana Logs panel
{namespace="production", service="$service"} |= "$search" | json
```

Variables `$service` and `$search` come from Grafana template variables — the user picks a service from a dropdown and types a search term.

### Metric Panel From Logs

```logql
# Error rate panel (Time series)
sum(rate({namespace="$namespace"} | json | level="error" [5m])) by (service)

# Log volume panel (bar chart)
sum(bytes_rate({namespace="$namespace"}[5m])) by (service)
```

---

## LogCLI — Query Loki From Terminal

```bash
# Install
brew install logcli     # macOS
# Or download from github.com/grafana/loki/releases

# Configure
export LOKI_ADDR=http://localhost:3100

# Basic query
logcli query '{service="vault-api"}' --limit=50

# Tail logs (like tail -f)
logcli query '{service="vault-api"}' --tail

# With time range
logcli query '{service="vault-api", level="error"}' \
  --from="2026-06-17T09:00:00Z" \
  --to="2026-06-17T10:00:00Z"

# Labels info
logcli labels
logcli labels service
```

---

## Common Misunderstanding: "Adding more labels makes Loki more powerful"

**The misunderstanding:** "I'll add a label for every piece of information — request_id, user_id, trace_id — so I can search faster."

**The reality:** High-cardinality labels are Loki's biggest pitfall. Each unique label value combination = one log stream. If you have 1,000 pods and add `request_id` as a label with billions of unique values, you'd have billions of streams. Loki's index would explode in size, query performance would crater, and ingestion would fail.

**The correct pattern:**

```
LABELS (low cardinality, index them):
  service, namespace, level, environment, node

LOG CONTENT (high cardinality, grep for them):
  request_id=abc123
  user_id=98765
  trace_id=xyz
```

```logql
# WRONG: label-based (would require high-cardinality label)
{request_id="abc123"}

# CORRECT: stream selector first (uses index), then grep content
{service="vault-api"} |= "abc123"

# BETTER: if logs are JSON, extract and filter
{service="vault-api"} | json | request_id="abc123"
```

Anything unique per request goes in the log content, not labels. Labels are for groupings (service, level) — the things that define what category of logs you're looking at.

→ Continue to: `02-deployment-and-setup.md`
