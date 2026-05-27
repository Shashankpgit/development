# Phase 10 — K8s Concepts + Minikube Setup

## What this phase covers

Pure concepts and setup. No application deployment yet. By the end you will:
- Understand what Kubernetes is and why it exists
- Know every K8s object you will use in Phase 13
- Have minikube running and kubectl working
- Have run a single practice pod to see kubectl in action

This is the foundation. Rushing past it means you'll be copy-pasting YAML without understanding what any of it does.

---

## Pre-step checklist

- [ ] Create `docs/plans/018-k8s-concepts-plan.md` first
- [ ] Teach ALL concepts before writing any YAML
- [ ] Docker must be installed and running (minikube uses Docker as driver)

---

## Why Kubernetes at all — the honest explanation

docker-compose solves: "run multiple containers together on one machine."

Kubernetes solves: "run containers reliably across many machines, automatically restart failures, deploy new versions without downtime, and scale up/down on demand."

In production, a single machine is a single point of failure. If that machine dies, your app dies. K8s runs your containers across a **cluster** of machines. If one machine dies, K8s moves your containers to another machine automatically — without you doing anything.

The tradeoff: K8s is significantly more complex than docker-compose. The complexity pays off at scale. For a single-developer project, docker-compose is often the right choice. We're learning K8s because it's the industry standard for production deployments.

---

## K8s Architecture (control plane + worker nodes)

```
┌─────────────────────────────────────────┐
│  Control Plane (the "brain")            │
│                                         │
│  ┌──────────┐  ┌──────────┐            │
│  │  API     │  │  etcd    │            │
│  │  Server  │  │ (state)  │            │
│  └──────────┘  └──────────┘            │
│  ┌──────────┐  ┌──────────┐            │
│  │Scheduler │  │Controller│            │
│  │          │  │ Manager  │            │
│  └──────────┘  └──────────┘            │
└─────────────────────────────────────────┘
        │  kubectl talks to API Server
┌───────▼────────┐  ┌────────────────┐
│  Worker Node 1 │  │  Worker Node 2 │
│  ┌──────────┐  │  │  ┌──────────┐  │
│  │  kubelet │  │  │  │  kubelet │  │
│  └──────────┘  │  │  └──────────┘  │
│  ┌───┐ ┌───┐   │  │  ┌───┐ ┌───┐  │
│  │Pod│ │Pod│   │  │  │Pod│ │Pod│  │
│  └───┘ └───┘   │  │  └───┘ └───┘  │
└────────────────┘  └────────────────┘
```

- **API Server**: Every command you run with `kubectl` hits the API server. It's the single entry point to the cluster.
- **etcd**: The cluster's database. Stores the desired state of every object. "I want 3 replicas of the API pod." etcd holds that.
- **Scheduler**: Decides which worker node a new pod should run on.
- **Controller Manager**: Watches the actual state vs desired state. If you want 3 pods but only 2 are running, the controller creates a 3rd.
- **kubelet**: Agent running on every worker node. Receives pod specs from the control plane and runs containers.

With **minikube**, the control plane and one worker node all run inside a single VM/container on your laptop. Same API, same YAML, different scale.

---

## Core Objects — what you WILL use

### Namespace
A virtual cluster inside the physical cluster. Isolates resources by name. Two teams can both have a `deployment/api` if they're in different namespaces.

We'll put everything in namespace `vault`.

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: vault
```

### Pod
The smallest deployable unit. One or more containers that share:
- The same network interface (same IP, same ports)
- The same storage volumes

In practice: almost always one container per pod.

Pods are **ephemeral**. They can be killed and replaced at any time. They get new IPs when restarted. You never address a pod by IP directly — that's what Services are for.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: vault-api
  namespace: vault
spec:
  containers:
    - name: api
      image: vault-api:latest
      ports:
        - containerPort: 8000
```

You almost never write a raw Pod. You write a Deployment that manages pods for you.

### Deployment
Manages a set of identical pods. Tells K8s: "I want exactly N copies of this pod always running."

When you update the image → Deployment does a rolling update (zero downtime).
When a pod crashes → Deployment starts a replacement automatically.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vault-api
  namespace: vault
spec:
  replicas: 2
  selector:
    matchLabels:
      app: vault-api
  template:              # ← this is the pod template
    metadata:
      labels:
        app: vault-api
    spec:
      containers:
        - name: api
          image: vault-api:latest
```

### ReplicaSet
Deployment actually creates a ReplicaSet under the hood. ReplicaSet ensures N pods are running. You almost never interact with ReplicaSets directly — Deployment manages them.

### Service
Pods are ephemeral (they get new IPs). A Service gives a stable DNS name and IP that always points to the healthy pods.

```
Service (stable: api.vault.svc.cluster.local)
  ├── Pod A (IP: 10.0.0.1)   ← may come and go
  ├── Pod B (IP: 10.0.0.2)
  └── Pod C (IP: 10.0.0.3)
```

Service types:
- **ClusterIP** (default): accessible only inside the cluster. `http://api:8000` from another pod in the same namespace.
- **NodePort**: exposes a port on every node. Accessible from outside but on a weird port (30000-32767). For debugging only.
- **LoadBalancer**: provisions a cloud load balancer (GKE, EKS). This is how production traffic enters.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: api
  namespace: vault
spec:
  selector:
    app: vault-api        # routes to pods with this label
  ports:
    - port: 8000
      targetPort: 8000
  type: ClusterIP
```

### Ingress
An Ingress defines HTTP routing rules: "traffic for `/api/` → Service `api`."

An **Ingress Controller** (a pod, usually nginx) reads these rules and enforces them. The controller is installed once; you write many Ingress resources.

This replaces your custom nginx container from docker-compose. You write routing rules, the controller handles the rest.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: vault
  namespace: vault
spec:
  rules:
    - http:
        paths:
          - path: /api/
            pathType: Prefix
            backend:
              service:
                name: api
                port:
                  number: 8000
```

minikube ships with a built-in nginx ingress controller: `minikube addons enable ingress`.

### ConfigMap
Non-sensitive configuration stored in K8s. Pods read it as environment variables or as mounted files.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: vault-config
  namespace: vault
data:
  APP_ENV: "production"
  KEYCLOAK_URL: "http://keycloak:8080"
```

Used in a pod:
```yaml
envFrom:
  - configMapRef:
      name: vault-config
```

### Secret
Same as ConfigMap but for sensitive values. Stored base64-encoded (not encrypted by default — requires additional cluster config for encryption at rest).

```bash
kubectl create secret generic vault-secrets \
  --from-literal=POSTGRES_PASSWORD=strongpassword \
  --from-literal=VAULT_ENCRYPTION_KEY=mykey \
  -n vault
```

Secrets created from the command line are NOT in git — correct. YAML with base64 values in git = bad practice for real secrets.

---

## Storage Objects

### PersistentVolume (PV)
Actual storage provisioned in the cluster. A directory on a node, a cloud disk, an NFS mount. Usually provisioned automatically.

### PersistentVolumeClaim (PVC)
A request for storage: "I need 5Gi." K8s finds a matching PV and binds them.

Pods reference the PVC, not the PV directly. This separates "what I need" from "where it physically is."

### StatefulSet
Like a Deployment but for stateful services (databases). Guarantees:
- Stable pod names (`postgres-0`, `postgres-1` — not random)
- Stable storage (same PVC reattaches after restart)
- Ordered startup (pod-0 before pod-1)

Use Deployment for stateless services (API, frontend).
Use StatefulSet for databases (PostgreSQL).

---

## Minikube setup

```bash
# Install minikube
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && sudo mv kubectl /usr/local/bin/kubectl

# Start cluster (uses Docker driver)
minikube start --driver=docker

# Verify
kubectl get nodes
# NAME       STATUS   ROLES           AGE   VERSION
# minikube   Ready    control-plane   1m    v1.x.x

# Enable ingress controller
minikube addons enable ingress

# Check ingress controller is running
kubectl get pods -n ingress-nginx
```

---

## Practice exercise — run a single pod

Before deploying the vault app, run a simple nginx pod to get comfortable with kubectl:

```bash
# Create a namespace
kubectl create namespace practice

# Run a pod
kubectl run nginx --image=nginx:alpine -n practice

# Watch it start
kubectl get pods -n practice -w

# Get into the container
kubectl exec -it nginx -n practice -- sh

# Clean up
kubectl delete pod nginx -n practice
kubectl delete namespace practice
```

---

## kubectl commands reference for this phase

```bash
kubectl get nodes
kubectl get pods -n vault
kubectl get pods -n vault -w               # watch live
kubectl get all -n vault                   # all objects
kubectl describe pod <name> -n vault       # detailed info + events
kubectl logs <pod-name> -n vault
kubectl logs <pod-name> -n vault -f        # follow
kubectl exec -it <pod> -n vault -- sh      # shell into pod
kubectl apply -f <file or dir>
kubectl delete -f <file>
kubectl port-forward svc/<name> 8000:8000 -n vault
minikube ip                                # cluster IP for browser access
minikube dashboard                         # web UI
```

---

## Success criteria

```bash
minikube status
# → Running

kubectl get nodes
# → minikube   Ready

kubectl get pods -n ingress-nginx
# → ingress-nginx-controller-xxx   Running

# Ran practice pod, executed into it, deleted it
```

Concepts are solid. Ready for Phase 11: push images to GHCR.
