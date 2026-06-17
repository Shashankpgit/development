# Kubernetes — Part 00: Core Concepts and Architecture

Before you touch a single `kubectl` command, you need to understand WHY Kubernetes exists and how it thinks about running software. This file is purely conceptual — no commands, just the mental model.

---

## Why Does Kubernetes Exist?

Imagine you're running a web application. You have:
- 3 servers in case one fails (high availability)
- Traffic is growing, so you need to add more servers
- App v2.0 needs to be deployed without downtime
- If a server crashes, the app needs to restart automatically
- Service A needs to talk to Service B, but not to Service C

Doing all of this manually is a full-time job. You'd need scripts to health-check containers, scripts to restart failures, scripts to balance load, scripts to roll out new versions... and then scripts to fix your scripts.

**Kubernetes is the answer to: "Who manages the managers?"**

You tell Kubernetes WHAT you want (3 copies of my API, always running, exposed on port 80). Kubernetes figures out HOW to make that happen and keeps it that way forever — even as servers fail, load spikes, and versions change.

---

## The Mental Model: Desired State vs Actual State

This is the single most important concept in Kubernetes.

```
You describe:   "I want 3 replicas of my API running"
                           ↓
Kubernetes says: "Currently I see 2. Let me start one more."
                           ↓
A server dies:   "Now I see 1. Let me start 2 more."
                           ↓
K8s keeps reality matching your description — forever
```

You don't say "start a container." You say "make sure this container is always running." Kubernetes continuously reconciles reality with your description. This is called the **reconciliation loop** or **control loop**.

---

## The Cluster Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Kubernetes Cluster                        │
│                                                                  │
│  ┌─────────────────────────────────────────┐                   │
│  │            Control Plane (Master)        │                   │
│  │                                          │                   │
│  │  ┌──────────────┐  ┌─────────────────┐  │                   │
│  │  │  API Server  │  │    etcd          │  │                   │
│  │  │  (front door)│  │  (the database)  │  │                   │
│  │  └──────────────┘  └─────────────────┘  │                   │
│  │                                          │                   │
│  │  ┌──────────────┐  ┌─────────────────┐  │                   │
│  │  │  Scheduler   │  │ Controller Mgr  │  │                   │
│  │  │  (where to?) │  │ (reconciler)    │  │                   │
│  │  └──────────────┘  └─────────────────┘  │                   │
│  └─────────────────────────────────────────┘                   │
│                                                                  │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐   │
│  │  Worker Node 1 │  │  Worker Node 2 │  │  Worker Node 3 │   │
│  │                │  │                │  │                │   │
│  │  ┌──────────┐  │  │  ┌──────────┐  │  │  ┌──────────┐  │   │
│  │  │ Pod A    │  │  │  │ Pod B    │  │  │  │ Pod C    │  │   │
│  │  │ Pod D    │  │  │  │ Pod E    │  │  │  │          │  │   │
│  │  └──────────┘  │  │  └──────────┘  │  │  └──────────┘  │   │
│  │                │  │                │  │                │   │
│  │  kubelet       │  │  kubelet       │  │  kubelet       │   │
│  │  kube-proxy    │  │  kube-proxy    │  │  kube-proxy    │   │
│  └────────────────┘  └────────────────┘  └────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

---

## Control Plane Components

### API Server
The front door to the entire cluster. Every command you run with `kubectl` talks to the API server. It validates requests, stores the desired state in etcd, and exposes the Kubernetes API.

When you run `kubectl apply -f deployment.yaml`, you're sending an HTTP request to the API server saying "please store this desired state."

### etcd
A distributed key-value store that is the **brain of the cluster** — it stores the entire cluster state. What pods should be running, what's actually running, all configuration, all secrets. If etcd is lost, the cluster state is lost.

This is why etcd must be backed up regularly in production.

### Scheduler
When a new pod needs to run, the Scheduler decides WHICH node it runs on. It looks at:
- Available resources on each node (CPU, memory)
- Node constraints (don't run this on arm nodes)
- Pod requirements (this pod needs a GPU)
- Spread requirements (don't put all 3 replicas on the same node)

### Controller Manager
Runs a collection of controllers — each one watches for a specific kind of discrepancy and fixes it:
- **ReplicaSet controller**: "I see 2 pods but you wanted 3 — creating one"
- **Node controller**: "Node 2 hasn't sent a heartbeat in 5 minutes — marking it NotReady"
- **Deployment controller**: "New version uploaded — starting rolling update"

---

## Worker Node Components

### kubelet
An agent that runs on every worker node. It receives pod specs from the API server and tells the container runtime (Docker, containerd) to start/stop containers. It also reports the node's status and pod health back to the control plane.

kubelet is the bridge between Kubernetes and the actual container runtime on each machine.

### kube-proxy
Maintains network rules on each node. When you create a Service (a stable endpoint for a group of pods), kube-proxy programs the node's network rules so traffic to the Service IP gets forwarded to the right pods.

---

## The Core Objects

### Pod — The Smallest Unit

A Pod is NOT a container. A Pod is a wrapper around one or more containers that share:
- The same network namespace (same IP address)
- The same storage volumes
- The same lifecycle (start/stop together)

```
Pod
├── Container 1: nginx (main app)
└── Container 2: log-shipper (sidecar — reads nginx logs and sends to central logging)

Both containers share the same IP. The sidecar can reach nginx at localhost:80.
```

Pods are ephemeral — they can be killed and replaced at any time. Never rely on a pod's IP address being stable. That's what Services are for.

### Node — A Machine

A node is a physical or virtual machine in the cluster. Each node runs the kubelet and kube-proxy. Kubernetes schedules pods onto nodes based on available resources.

### Namespace — Virtual Cluster

Namespaces divide a cluster into virtual sub-clusters. Teams or environments can have their own namespace:

```
default namespace     → your apps if you don't specify
kube-system           → Kubernetes internal components
monitoring            → Prometheus, Grafana
production            → production workloads
staging               → staging workloads
team-alpha            → team alpha's services
```

Objects in different namespaces are isolated (you can set different RBAC permissions per namespace). Objects within the same namespace can communicate freely.

---

## The Workload Objects

### Deployment — Stateless Apps

The most common object. Manages a set of identical pods. Handles:
- Keeping N replicas running
- Rolling updates (deploy v2 gradually, roll back if unhealthy)
- Rollback to previous versions

Use for: web servers, APIs, stateless microservices — anything where pods are interchangeable.

### StatefulSet — Stateful Apps

Like a Deployment, but pods have:
- Stable, predictable names: `postgres-0`, `postgres-1`, `postgres-2`
- Stable storage: each pod gets its own PersistentVolume that survives pod restarts
- Ordered startup/shutdown: `postgres-0` starts before `postgres-1`

Use for: databases (PostgreSQL, MySQL, MongoDB), message queues (Kafka, RabbitMQ), anything that needs stable identity.

### DaemonSet — One Pod Per Node

Ensures one copy of a pod runs on every node (or every matching node). As nodes are added to the cluster, the DaemonSet automatically runs a pod there too.

Use for: log collection agents (Fluent Bit, Filebeat), monitoring agents (node-exporter), network plugins (Calico, Flannel).

### Job — Run Once

Runs a pod until it completes successfully. If it fails, it restarts (up to a configured limit).

Use for: database migrations, batch data processing, one-time setup tasks.

### CronJob — Scheduled Jobs

Runs a Job on a schedule (cron syntax).

Use for: nightly backups, scheduled reports, periodic cleanups.

---

## The Network Objects

### Service — Stable Endpoint for Pods

Pods come and go with changing IPs. A Service provides a stable IP and DNS name that always routes to the current set of healthy pods.

Types:
- **ClusterIP**: Internal-only. Accessible within the cluster.
- **NodePort**: Exposes on a port on every node. Used for direct external access (not recommended for production).
- **LoadBalancer**: Creates a cloud load balancer (AWS ELB, GCP Load Balancer). The standard production pattern for external traffic.

### Ingress — HTTP Routing

Routes HTTP/HTTPS traffic to different Services based on the URL path or hostname. Think of it as nginx + routing rules, managed by Kubernetes.

```
traffic → Ingress → /api/*       → api-service
                 → /static/*    → frontend-service
                 → /admin/*     → admin-service
```

---

## The Configuration Objects

### ConfigMap — Non-Secret Configuration

Key-value pairs of configuration data that can be injected into pods as environment variables or files. Change a ConfigMap and restart the pod — no need to rebuild the image.

### Secret — Sensitive Configuration

Like ConfigMap, but for sensitive values (passwords, API keys, TLS certificates). Values are base64-encoded (NOT encrypted by default — encryption at rest requires additional setup).

### PersistentVolume (PV) and PersistentVolumeClaim (PVC)

PV: A piece of storage in the cluster (an EBS volume, NFS share, etc.)
PVC: A pod's request for storage ("I need 10GB of fast SSD storage")

Kubernetes matches PVCs to available PVs. When a pod needs storage, it creates a PVC — Kubernetes binds it to a matching PV.

---

## Summary: The Kubernetes Vocabulary

| Object | What It Is | Use For |
|--------|-----------|---------|
| Pod | One or more containers | Smallest deployable unit |
| Deployment | Manages ReplicaSets | Stateless apps |
| StatefulSet | Ordered, stable pods | Databases, queues |
| DaemonSet | One pod per node | Agents, monitoring |
| Job | Run-to-completion | Batch tasks, migrations |
| CronJob | Scheduled Job | Periodic tasks |
| Service | Stable network endpoint | Route traffic to pods |
| Ingress | HTTP routing rules | External HTTP traffic |
| ConfigMap | Non-secret config | App configuration |
| Secret | Sensitive config | Passwords, keys, certs |
| PV/PVC | Storage | Persistent data |
| Namespace | Virtual cluster | Isolation, organization |
| Node | Machine | Where pods run |

---

## Common Misunderstanding: "A Pod = A Container"

**The misunderstanding:** "I have a container, so I have a pod."

**The reality:** A pod is a logical wrapper. One pod can hold multiple containers that work together as a unit. The sidecar pattern is fundamental to Kubernetes: your main app container + a helper container (log shipper, certificate reloader, proxy) in the same pod, sharing networking and storage.

The key insight: containers in a pod communicate via `localhost` — they share the same network interface. This is fundamentally different from two separate pods, which communicate over the cluster network.

→ Continue to: `01-kubectl-basics.md`
