# Grafana Alloy — Part 01: Configuration Syntax and Real-World Examples

---

## The Alloy Configuration Syntax

Alloy uses its own configuration language (formerly called "River"). It's declarative, HCL-like, and built around the concept of **components**.

```hcl
// This is a comment in Alloy config syntax

// A component definition:
component_type "component_name" {
  argument_name = "value"
  argument_name = reference.to.another.component.output
}
```

Every component has:
- A **type** (what it does): `loki.source.file`, `prometheus.scrape`, `loki.write`
- A **label** (its unique name within that type): `"app_logs"`, `"kubernetes_pods"`
- **Arguments** (configuration)
- **Exports** (outputs you can reference from other components)

---

## Example 1: Collect Log Files and Send to Loki

```hcl
// config.alloy — collect /var/log/*.log and send to Loki

// Step 1: Define where to send logs
loki.write "loki_backend" {
  endpoint {
    url = "http://loki:3100/loki/api/v1/push"
  }
}

// Step 2: Define what log files to collect
loki.source.file "app_logs" {
  targets    = [
    {
      __path__ = "/var/log/vault-api/*.log",
      service  = "vault-api",
      env      = "production",
    },
    {
      __path__ = "/var/log/nginx/access.log",
      service  = "nginx",
      env      = "production",
    },
  ]
  forward_to = [loki.write.loki_backend.receiver]
  // The output of loki.source.file goes to loki.write.loki_backend
}
```

---

## Example 2: Collect Kubernetes Pod Logs

```hcl
// config.alloy — collect all Kubernetes pod logs

// Where to send logs
loki.write "loki_backend" {
  endpoint {
    url = "http://loki.monitoring.svc.cluster.local:3100/loki/api/v1/push"
  }
}

// Discover Kubernetes pods
discovery.kubernetes "pods" {
  role = "pod"     // discover all pods in the cluster
}

// Relabel metadata: extract namespace, pod name, container, etc.
discovery.relabel "kubernetes_pods" {
  targets = discovery.kubernetes.pods.targets

  // Keep only pods that have this annotation:
  // prometheus.io/scrape: "true" — wait, this is for logs
  // For logs: keep all by default, or filter here

  // Add namespace as a label
  rule {
    source_labels = ["__meta_kubernetes_namespace"]
    target_label  = "namespace"
  }

  // Add pod name as a label
  rule {
    source_labels = ["__meta_kubernetes_pod_name"]
    target_label  = "pod"
  }

  // Add container name
  rule {
    source_labels = ["__meta_kubernetes_pod_container_name"]
    target_label  = "container"
  }

  // Extract the "app" label from Kubernetes pod labels
  rule {
    source_labels = ["__meta_kubernetes_pod_label_app"]
    target_label  = "app"
  }
}

// Collect pod logs using the discovered targets
loki.source.kubernetes "pod_logs" {
  targets    = discovery.relabel.kubernetes_pods.output
  forward_to = [loki.write.loki_backend.receiver]
}
```

---

## Example 3: Scrape Metrics and Remote Write to Prometheus

```hcl
// config.alloy — scrape metrics and forward to remote storage

// Where to send metrics
prometheus.remote_write "prometheus_backend" {
  endpoint {
    url = "http://prometheus:9090/api/v1/write"
  }
}

// Scrape your application
prometheus.scrape "vault_api" {
  targets = [
    {"__address__" = "vault-api:3000", "service" = "vault-api"},
    {"__address__" = "vault-api-2:3000", "service" = "vault-api"},
  ]
  metrics_path    = "/metrics"
  scrape_interval = "15s"
  forward_to      = [prometheus.remote_write.prometheus_backend.receiver]
}

// Scrape node_exporter for host metrics
prometheus.scrape "node_exporter" {
  targets = [
    {"__address__" = "localhost:9100", "job" = "node"},
  ]
  forward_to = [prometheus.remote_write.prometheus_backend.receiver]
}
```

---

## Example 4: Full Kubernetes Alloy — Logs + Metrics

```hcl
// config.alloy — DaemonSet on every Kubernetes node
// Collects: all pod logs → Loki, node metrics → Prometheus

// ─── DESTINATIONS ────────────────────────────────────────────────────

loki.write "loki" {
  endpoint {
    url = "http://loki.monitoring.svc.cluster.local:3100/loki/api/v1/push"
  }
}

prometheus.remote_write "mimir" {
  endpoint {
    url = "http://mimir.monitoring.svc.cluster.local:9009/api/v1/push"
  }
}

// ─── KUBERNETES POD LOGS ─────────────────────────────────────────────

discovery.kubernetes "k8s_pods" {
  role = "pod"
}

discovery.relabel "pod_labels" {
  targets = discovery.kubernetes.k8s_pods.targets

  // Drop pods in kube-system (too noisy)
  rule {
    source_labels = ["__meta_kubernetes_namespace"]
    regex         = "kube-system"
    action        = "drop"
  }

  // Standard metadata labels
  rule {
    source_labels = ["__meta_kubernetes_namespace"]
    target_label  = "namespace"
  }
  rule {
    source_labels = ["__meta_kubernetes_pod_name"]
    target_label  = "pod"
  }
  rule {
    source_labels = ["__meta_kubernetes_pod_container_name"]
    target_label  = "container"
  }
  rule {
    source_labels = ["__meta_kubernetes_pod_label_app"]
    target_label  = "app"
  }
  rule {
    source_labels = ["__meta_kubernetes_pod_label_version"]
    target_label  = "version"
  }
}

loki.source.kubernetes "pod_logs" {
  targets    = discovery.relabel.pod_labels.output
  forward_to = [loki.process.add_cluster_label.receiver]
}

// Add cluster-wide label to all logs
loki.process "add_cluster_label" {
  stage.static_labels {
    values = {
      cluster = "production-k8s",
    }
  }
  forward_to = [loki.write.loki.receiver]
}

// ─── KUBERNETES METRICS ──────────────────────────────────────────────

// Discover all pods annotated for scraping
discovery.kubernetes "k8s_metrics_pods" {
  role = "pod"
}

discovery.relabel "metrics_pods" {
  targets = discovery.kubernetes.k8s_metrics_pods.targets

  // Only scrape pods with: prometheus.io/scrape: "true" annotation
  rule {
    source_labels = ["__meta_kubernetes_pod_annotation_prometheus_io_scrape"]
    regex         = "true"
    action        = "keep"
  }

  // Use custom port if annotation exists
  rule {
    source_labels = ["__address__", "__meta_kubernetes_pod_annotation_prometheus_io_port"]
    regex         = "([^:]+)(?::\\d+)?;(\\d+)"
    replacement   = "$1:$2"
    target_label  = "__address__"
  }

  // Use custom path if annotation exists
  rule {
    source_labels = ["__meta_kubernetes_pod_annotation_prometheus_io_path"]
    target_label  = "__metrics_path__"
    regex         = "(.+)"
  }

  // Standard labels
  rule {
    source_labels = ["__meta_kubernetes_namespace"]
    target_label  = "namespace"
  }
  rule {
    source_labels = ["__meta_kubernetes_pod_name"]
    target_label  = "pod"
  }
  rule {
    source_labels = ["__meta_kubernetes_pod_label_app"]
    target_label  = "app"
  }
}

prometheus.scrape "k8s_pods" {
  targets         = discovery.relabel.metrics_pods.output
  scrape_interval = "15s"
  forward_to      = [prometheus.remote_write.mimir.receiver]
}

// ─── NODE METRICS ────────────────────────────────────────────────────

prometheus.exporter.unix "node" {
  // Built-in node_exporter — no external binary needed
  procfs_path = "/host/proc"
  sysfs_path  = "/host/sys"
  rootfs_path = "/host/root"
}

prometheus.scrape "node_metrics" {
  targets    = prometheus.exporter.unix.node.targets
  forward_to = [prometheus.remote_write.mimir.receiver]

  // Add node label
  job_name = "node"
}
```

---

## Example 5: Receive OTLP and Fan Out

Alloy can act as an OTLP receiver — accepting telemetry from apps instrumented with OpenTelemetry SDKs:

```hcl
// Receive OTLP from apps, forward metrics to Prometheus, logs to Loki, traces to Tempo

otelcol.receiver.otlp "otlp_in" {
  grpc {
    endpoint = "0.0.0.0:4317"
  }
  http {
    endpoint = "0.0.0.0:4318"
  }
  output {
    metrics = [otelcol.exporter.prometheus.prom.input]
    logs    = [otelcol.exporter.loki.loki.input]
    traces  = [otelcol.exporter.otlp.tempo.input]
  }
}

otelcol.exporter.prometheus "prom" {
  forward_to = [prometheus.remote_write.mimir.receiver]
}

otelcol.exporter.loki "loki" {
  forward_to = [loki.write.loki.receiver]
}

otelcol.exporter.otlp "tempo" {
  client {
    endpoint = "tempo.monitoring.svc.cluster.local:4317"
    tls {
      insecure = true
    }
  }
}
```

---

## Alloy UI — Built-in Debugging Interface

Alloy has a built-in web UI at `http://localhost:12345` (default port). It shows:
- All running components and their status
- The dependency graph between components (visual pipeline)
- Current component configuration and arguments
- Errors and health status

```bash
# Start Alloy with config
alloy run config.alloy

# Open http://localhost:12345 in browser
# See all components, click on any to see its current state
```

This is invaluable for debugging why logs or metrics aren't flowing.

---

## Common Misunderstanding: "Alloy config is just YAML like other K8s configs"

**The misunderstanding:** "I'll configure Alloy the same way I configure everything else in Kubernetes."

**The reality:** Alloy uses its own configuration syntax (River/Alloy syntax), NOT YAML. It looks like HCL (HashiCorp Config Language) or Terraform.

This trips people up constantly. Indentation doesn't matter, but curly braces do. Arrays use `[...]`, not YAML lists. References use dots: `loki.write.loki_backend.receiver`.

When you see tutorials using YAML for Grafana Agent configuration, those are for the OLD static-mode agent, not Alloy. Alloy configs use `.alloy` file extension.

```hcl
// Correct Alloy syntax
loki.write "backend" {
  endpoint {
    url = "http://loki:3100/loki/api/v1/push"
  }
}

# NOT YAML like this:
# loki_write:
#   backend:
#     endpoint:
#       url: http://loki:3100/...
```

→ Continue to: `README.md`
