# KT 18 — Kubernetes Concepts

## Why Kubernetes exists

You've been running the app with `docker compose up`. That works great on one machine. The problem is the one machine itself.

If that VM dies → app is gone. If traffic spikes → you can't run more copies of the API without logging in manually. If you deploy a bad version → you have to roll it back manually.

Kubernetes solves exactly these three problems:
- **Self-healing**: if a container crashes, K8s restarts it automatically
- **Scaling**: run 3 copies of the API with one command
- **Rolling updates**: deploy a new version without any downtime

The tradeoff: K8s is significantly more complex than docker-compose. That complexity only pays off when you need what it provides.

---

## Architecture — what's inside a K8s cluster

```
┌─────────────────────────────────────────────────────┐
│  Control Plane  (the "brain")                       │
│                                                     │
│  ┌────────────┐  ┌──────┐  ┌───────────────────┐   │
│  │ API Server │  │ etcd │  │ Controller Manager│   │
│  └────────────┘  └──────┘  └───────────────────┘   │
│        ▲              ┌──────────────┐              │
│        │              │  Scheduler   │              │
│   kubectl             └──────────────┘              │
└───────────────────────┬─────────────────────────────┘
                        │
         ┌──────────────┼──────────────┐
         ▼              ▼              ▼
    Worker Node 1   Worker Node 2   Worker Node 3
    ┌──────────┐    ┌──────────┐    ┌──────────┐
    │ kubelet  │    │ kubelet  │    │ kubelet  │
    ├──────────┤    ├──────────┤    ├──────────┤
    │Pod  │Pod │    │Pod  │Pod │    │   Pod    │
    └──────────┘    └──────────┘    └──────────┘
```

| Component | What it does |
|---|---|
| **API Server** | Every `kubectl` command hits this. Single entry point to the cluster. |
| **etcd** | The cluster's database. Stores desired state. "I want 2 API pods." |
| **Scheduler** | Decides which worker node a new pod runs on. |
| **Controller Manager** | Watches actual vs desired state. 2 pods wanted, 1 running → create another. |
| **kubelet** | Agent on every worker node. Receives pod specs and runs containers. |

With **minikube**, the control plane and one worker node all run inside a single VM on your laptop. Same API, same YAML, same kubectl — just smaller scale.

---

## Object 1 — Namespace

A virtual boundary inside the cluster. Keeps resources isolated by name. Two teams can each have a `deployment/api` as long as they're in different namespaces.

We put everything in namespace `vault`.

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: vault
```

---

## Object 2 — Pod

The smallest deployable unit. One or more containers that share:
- The same network interface (same IP, same ports)
- The same storage volumes

In practice: almost always **one container per pod**.

Two things to internalize:
- Pods are **ephemeral** — K8s can kill and replace them at any time
- Pods get **new IP addresses** on every restart — you never hardcode a pod IP

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: vault-api
  namespace: vault
spec:
  containers:
    - name: api
      image: ghcr.io/username/vault-api:latest
      ports:
        - containerPort: 8000
```

You almost never write a raw Pod in real work. You write a Deployment that manages pods for you.

---

## Object 3 — Deployment

Manages a set of identical pods. You tell it: "I want exactly N copies of this pod always running."

What Deployment does automatically:
- Pod crashes → starts a replacement
- You update the image → rolling update (zero downtime)
- You scale up → starts more pods

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vault-api
  namespace: vault
spec:
  replicas: 2                      # how many copies
  selector:
    matchLabels:
      app: vault-api               # which pods this manages
  template:                        # the pod template
    metadata:
      labels:
        app: vault-api
    spec:
      containers:
        - name: api
          image: ghcr.io/username/vault-api:latest
          ports:
            - containerPort: 8000
```

The `selector.matchLabels` and `template.metadata.labels` must match — that's how Deployment knows which pods belong to it.

---

## Object 4 — Service

Since pods are ephemeral (they come and go, get new IPs), you need something with a **stable address** that always points to the healthy pods.

A Service:
- Has a stable DNS name: `api.vault.svc.cluster.local` (or just `api` within the same namespace)
- Load-balances traffic across all healthy pods matching its selector
- Stays alive even when pods restart

```
Service "api"  →  Pod A (10.0.0.1)
                  Pod B (10.0.0.2)  ← pods come and go, Service stays
                  Pod C (10.0.0.3)
```

**Service types:**

| Type | Accessible from | When to use |
|---|---|---|
| ClusterIP (default) | Inside cluster only | Internal services (API, DB, Keycloak) |
| NodePort | Outside cluster on a high port (30000-32767) | Debugging only |
| LoadBalancer | Outside cluster via cloud load balancer | Production ingress (GKE) |

```yaml
apiVersion: v1
kind: Service
metadata:
  name: api
  namespace: vault
spec:
  selector:
    app: vault-api          # routes to pods with this label
  ports:
    - port: 8000
      targetPort: 8000
  type: ClusterIP
```

---

## Object 5 — Ingress

An Ingress defines HTTP routing rules: "requests to `/api/` → Service `api`."

An Ingress on its own does nothing. You also need an **Ingress Controller** — a pod that reads Ingress rules and actually routes the traffic. minikube ships with nginx as the Ingress Controller (`minikube addons enable ingress`).

This replaces your custom nginx container from docker-compose. Instead of writing an nginx.conf, you write Ingress rules. The controller handles the rest.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: vault
  namespace: vault
spec:
  ingressClassName: nginx
  rules:
    - host: vault.local
      http:
        paths:
          - path: /api/
            pathType: Prefix
            backend:
              service:
                name: api
                port:
                  number: 8000
          - path: /
            pathType: Prefix
            backend:
              service:
                name: vault-frontend
                port:
                  number: 80
```

---

## Object 6 — ConfigMap

Non-sensitive configuration stored in Kubernetes. Pods read it as environment variables or as mounted files.

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

Used as a mounted file (for `kong.yml`, `realm-export.json`):
```yaml
volumes:
  - name: kong-config
    configMap:
      name: kong-config
volumeMounts:
  - name: kong-config
    mountPath: /kong/kong.yml
    subPath: kong.yml
```

---

## Object 7 — Secret

Same structure as ConfigMap but for sensitive values. Stored base64-encoded in etcd.

```bash
# Create from command line — NOT in git
kubectl create secret generic vault-secrets \
  --from-literal=POSTGRES_PASSWORD=strongpassword \
  --from-literal=VAULT_ENCRYPTION_KEY=mykey \
  -n vault
```

Used in a pod:
```yaml
env:
  - name: POSTGRES_PASSWORD
    valueFrom:
      secretKeyRef:
        name: vault-secrets
        key: POSTGRES_PASSWORD
```

**Important**: Secrets created with `kubectl create secret` are NOT stored in git — which is correct. Never put real secret values in YAML files committed to git.

---

## Storage Objects

### PersistentVolume (PV)
Actual storage in the cluster. A directory on a node, a cloud disk, an NFS share. Usually provisioned automatically by the cloud provider.

### PersistentVolumeClaim (PVC)
A request for storage: "I need 5Gi." K8s finds a matching PV and binds them. Pods reference the PVC.

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-data
  namespace: vault
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
```

### StatefulSet

Like a Deployment but for stateful services (databases). Key guarantees:
- **Stable pod names**: always `postgres-0`, never a random suffix
- **Stable storage**: same PVC reattaches after pod restart
- **Ordered startup**: pod-0 starts before pod-1

| | Deployment | StatefulSet |
|---|---|---|
| Pod names | random (vault-api-abc123) | stable (postgres-0) |
| Storage | new PVC each time | same PVC reattaches |
| Use for | API, frontend, Kong, Keycloak | PostgreSQL |

---

## How docker-compose maps to K8s

| docker-compose | Kubernetes |
|---|---|
| `service:` | Deployment + Service |
| `ports:` | Service + Ingress |
| `environment:` | ConfigMap + Secret (envFrom) |
| `volumes:` | PVC + PV |
| `depends_on:` | readinessProbe (K8s waits for healthy) |
| `networks:` | Namespace (automatic DNS between pods) |
| `docker compose up` | `kubectl apply -f k8s/` or `helm install` |
| nginx container | Ingress Controller |
| certbot | cert-manager (Phase 15) |

---

## kubectl — the CLI

Every command goes through `kubectl`. It talks to the API Server.

```bash
# Cluster info
kubectl get nodes
kubectl cluster-info

# Namespaces
kubectl get namespaces
kubectl create namespace vault

# Pods
kubectl get pods -n vault
kubectl get pods -n vault -w              # watch (live updates)
kubectl describe pod <name> -n vault      # detailed info + Events
kubectl logs <pod> -n vault
kubectl logs <pod> -n vault -f            # follow (live tail)
kubectl exec -it <pod> -n vault -- sh     # shell into pod

# All resources
kubectl get all -n vault

# Apply / delete
kubectl apply -f <file or directory>
kubectl delete -f <file>

# Debugging
kubectl get events -n vault --sort-by=.lastTimestamp
kubectl port-forward svc/<name> 8000:8000 -n vault
```

---

## minikube — K8s on your laptop

minikube runs a full K8s cluster inside a single VM or Docker container on your machine. Same API, same kubectl, same YAML as production.

```bash
# Start
minikube start --driver=docker

# Stop
minikube stop

# Delete cluster (fresh start)
minikube delete

# Get cluster IP (for browser access)
minikube ip

# Enable addons
minikube addons enable ingress        # nginx ingress controller
minikube addons enable metrics-server # CPU/memory metrics

# Load a local image into minikube
minikube image load vault-api:latest

# Open Kubernetes dashboard in browser
minikube dashboard
```

---

## What we will NOT need for local minikube

- **cert-manager**: Let's Encrypt needs a real domain. `vault.local` is a fake domain. HTTP is fine locally.
- **Cloud load balancer**: minikube uses NodePort or the Ingress Controller. No cloud needed.
- **imagePullSecrets** (maybe): if GHCR images are public, minikube can pull without credentials.

These come in Phase 15 (GKE production deployment).
