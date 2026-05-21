# Phase 10 — Step 1: Kubernetes

## What this step covers
Deploy the Personal Vault application to Kubernetes. Convert docker-compose services to Kubernetes manifests (Deployments, Services, ConfigMaps, Secrets).

---

## Pre-step checklist (Claude must do before any code)

- [ ] Create `docs/017-kubernetes-plan.md` first
- [ ] Teach core Kubernetes concepts BEFORE writing any YAML
- [ ] Confirm the Docker images are built and work correctly

---

## Why this step exists

docker-compose is for local development and small single-server deployments. Kubernetes is for:
- Running applications across multiple machines (nodes)
- Automatically restarting crashed containers
- Scaling: run 3 copies of the API to handle load
- Rolling updates: deploy new versions without downtime
- Self-healing: if a node dies, pods are rescheduled elsewhere

This is the infrastructure reality at companies with more than a handful of users.

---

## Prerequisite: Local Kubernetes

Use one of:
- **k3d** (lightweight K3s in Docker) — recommended for this learning phase
- **minikube** — common alternative
- **kind** — Kubernetes in Docker

Install k3d and create a local cluster:
```bash
k3d cluster create vault-cluster
```

---

## What to implement

### Directory: `k8s/`
```
k8s/
├── namespace.yaml
├── api/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── configmap.yaml
├── db/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── pvc.yaml
├── keycloak/
│   ├── deployment.yaml
│   └── service.yaml
└── ingress/
    └── ingress.yaml
```

### Core manifests

**Namespace**: `vault` — isolate the application from other workloads

**API Deployment**:
- Replicas: 2 (two copies for availability)
- Image: the Docker image built earlier
- Environment from ConfigMap + Secrets
- LivenessProbe: `GET /api/health`
- ReadinessProbe: `GET /api/health`

**API Service**: ClusterIP (internal only)

**Ingress**: Routes external traffic to services (replaces Kong/Nginx for routing in K8s)

**PostgreSQL**: StatefulSet (not Deployment — databases need stable identity + storage)
**PersistentVolumeClaim**: Storage for PostgreSQL data

**Secrets**: `DATABASE_URL`, `SECRET_KEY` → stored as Kubernetes Secrets (base64 encoded)
**ConfigMap**: Non-sensitive config (APP_ENV, KEYCLOAK_URL)

---

## Concepts to teach during this step

- **Pod**: The smallest deployable unit. One or more containers that share network and storage. Think of it as a "container wrapper."

- **Deployment**: Manages a set of identical pods. "I want 2 replicas of the API pod always running." If one crashes, Deployment restarts it.

- **Service**: A stable network endpoint for pods. Pods come and go (they're ephemeral — they get new IPs). A Service has a stable DNS name and routes to healthy pods.

- **Ingress**: Routes external HTTP/HTTPS traffic to internal Services. Like Nginx but managed by Kubernetes.

- **ConfigMap vs Secret**: ConfigMap = non-sensitive config (key-value). Secret = sensitive config (stored base64-encoded, separate RBAC controls).

- **StatefulSet vs Deployment**: Deployment pods are interchangeable. StatefulSet pods have stable identity (pod-0, pod-1) and stable storage — required for databases.

- **PersistentVolumeClaim (PVC)**: A request for storage. The cluster provides a PersistentVolume; the PVC claims it.

- **Liveness vs Readiness probes**:
  - Liveness: "Is this pod alive?" — K8s restarts if fails
  - Readiness: "Is this pod ready to receive traffic?" — K8s removes from Service if fails

- **Why K8s over docker-compose**: docker-compose manages containers on ONE machine. K8s manages containers across a CLUSTER of machines, with self-healing, scaling, and rolling updates.

---

## kubectl commands to learn

```bash
kubectl get pods -n vault
kubectl describe pod <name> -n vault
kubectl logs <pod-name> -n vault
kubectl get services -n vault
kubectl apply -f k8s/
kubectl rollout status deployment/api -n vault
```

---

## What NOT to do in this step

- Do NOT use a managed cloud K8s (GKE, EKS) yet — learn locally first
- Do NOT add Helm yet (Phase 11 wraps these manifests in a Helm chart)
- Do NOT add HorizontalPodAutoscaler yet

---

## File changes

| File | Action |
|---|---|
| `k8s/` directory | Create with all manifests |
| `docker-compose.yml` | Keep — still used for local development |

---

## Success criteria

```bash
kubectl apply -f k8s/
kubectl get pods -n vault  # all pods Running
# http://localhost (via Ingress) → application accessible
# kubectl delete pod <api-pod> -n vault → new pod starts automatically (self-healing)
# kubectl scale deployment api --replicas=3 -n vault → 3 API pods running
```
