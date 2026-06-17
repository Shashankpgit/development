# Kubernetes — Part 03: Services and Networking

---

## The Problem Services Solve

Pods are ephemeral. When a pod crashes and gets replaced, it gets a new IP address. When you scale from 3 pods to 5, there are now 5 IPs. You can't hardcode any of these in your application code.

A **Service** solves this by providing:
1. A stable IP that never changes
2. A DNS name (`my-service.my-namespace.svc.cluster.local`)
3. Load balancing across all healthy pods that match its label selector

```
Before Services:
  App → hardcoded IP 10.0.0.42 → but pod died, new pod is at 10.0.0.67 → broken

After Services:
  App → vault-api-service → Service picks a healthy pod → always works
```

---

## How Services Find Pods: Label Selectors

A Service doesn't know about pods by name — it finds them by labels.

```yaml
# Service selects pods with label app: vault-api
apiVersion: v1
kind: Service
metadata:
  name: vault-api-service
spec:
  selector:
    app: vault-api       # select all pods with this label

# Deployment creates pods with this label
template:
  metadata:
    labels:
      app: vault-api     # these pods are selected by the Service above
```

When you add a pod with `app: vault-api`, the Service immediately starts sending traffic to it. When you remove the label (or the pod dies), the Service stops. This is how rolling updates work — traffic automatically follows healthy pods.

---

## Service Types

### ClusterIP — Internal Traffic Only (Default)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: vault-api-service
  namespace: production
spec:
  type: ClusterIP           # default if you don't specify
  selector:
    app: vault-api
  ports:
    - name: http
      port: 80              # the port clients use to reach the Service
      targetPort: 3000      # the port the pods are actually listening on
```

- Gets a stable cluster-internal IP (e.g., `10.96.45.123`)
- Gets a DNS name: `vault-api-service.production.svc.cluster.local`
- Short form within the same namespace: `vault-api-service`
- NOT accessible from outside the cluster
- Use for: microservice-to-microservice communication, databases

### NodePort — Direct Node Access

```yaml
spec:
  type: NodePort
  selector:
    app: vault-api
  ports:
    - port: 80
      targetPort: 3000
      nodePort: 30080       # optional: specific port (30000-32767 range)
                            # if omitted, Kubernetes assigns one
```

- Opens port 30080 on EVERY node in the cluster
- Traffic to `<any-node-ip>:30080` → Service → pods
- Accessible from outside (if nodes have public IPs)
- Awkward for production (ports limited to 30000-32767, exposes nodes directly)
- Use for: development, simple external access when no cloud load balancer is available

### LoadBalancer — Cloud Load Balancer

```yaml
spec:
  type: LoadBalancer
  selector:
    app: vault-api
  ports:
    - port: 80
      targetPort: 3000
```

- Works in cloud environments (AWS, GCP, Azure)
- Provisions a cloud load balancer (AWS ELB, GCP Load Balancer) automatically
- Gets a public IP / DNS name
- The standard way to expose services externally in production
- Each LoadBalancer Service creates one cloud load balancer — can get expensive

### Headless Service — No Load Balancing

```yaml
spec:
  clusterIP: None           # makes it headless
  selector:
    app: postgres
```

- No stable IP — DNS returns all pod IPs directly
- Used with StatefulSets: `postgres-0.postgres-service`, `postgres-1.postgres-service`
- Used when clients need to connect to specific pods (database replicas, Kafka brokers)

---

## Kubernetes DNS — How Services Are Discovered

Every Service gets a DNS entry automatically. From any pod in the cluster:

```
Full DNS name:  vault-api-service.production.svc.cluster.local
Short form:     vault-api-service                    (same namespace)
Cross-namespace: vault-api-service.production        (different namespace)
```

```bash
# Test DNS from inside a pod
kubectl run dns-test --image=busybox --rm -it --restart=Never -- \
  nslookup vault-api-service.production.svc.cluster.local

# Test if service is reachable
kubectl run curl-test --image=curlimages/curl --rm -it --restart=Never -- \
  curl http://vault-api-service.production/health
```

---

## Ingress — HTTP/HTTPS Routing at the Edge

A LoadBalancer Service costs money (one cloud LB per service). Ingress lets you use ONE load balancer and route to many services based on hostname or path.

```
Browser → Cloud LB → Ingress Controller → Ingress Rules → Services → Pods
```

### Install an Ingress Controller first (example: nginx-ingress)

```bash
# The IngressClass must exist in the cluster — provided by an Ingress Controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml
```

### Create Ingress rules

```yaml
# ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: vault-ingress
  namespace: production
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - vault.example.com
      secretName: vault-tls-secret   # cert-manager puts TLS cert here
  rules:
    - host: vault.example.com
      http:
        paths:
          - path: /api
            pathType: Prefix
            backend:
              service:
                name: vault-api-service
                port:
                  number: 80
          - path: /
            pathType: Prefix
            backend:
              service:
                name: vault-frontend-service
                port:
                  number: 80
    - host: admin.vault.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: vault-admin-service
                port:
                  number: 80
```

---

## NetworkPolicy — Firewall Rules Between Pods

By default, all pods in a cluster can reach all other pods. NetworkPolicy restricts this.

```yaml
# Allow vault-api to only receive traffic from vault-frontend and monitoring
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: vault-api-policy
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: vault-api            # applies to pods with this label
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: vault-frontend   # allow from frontend
        - namespaceSelector:
            matchLabels:
              name: monitoring      # allow from monitoring namespace
      ports:
        - port: 3000
  egress:
    - to:
        - podSelector:
            matchLabels:
              app: postgres         # can reach postgres
      ports:
        - port: 5432
    - to:                           # allow DNS resolution
        - namespaceSelector: {}
      ports:
        - port: 53
          protocol: UDP
```

---

## Real-World Scenario: Full App Networking Stack

```yaml
# 1. Database service (internal only)
apiVersion: v1
kind: Service
metadata:
  name: postgres-service
  namespace: production
spec:
  type: ClusterIP
  selector:
    app: postgres
  ports:
    - port: 5432
      targetPort: 5432
---
# 2. API service (internal only, Ingress handles external)
apiVersion: v1
kind: Service
metadata:
  name: vault-api-service
  namespace: production
spec:
  type: ClusterIP
  selector:
    app: vault-api
  ports:
    - port: 80
      targetPort: 3000
---
# 3. Frontend service (internal only)
apiVersion: v1
kind: Service
metadata:
  name: vault-frontend-service
  namespace: production
spec:
  type: ClusterIP
  selector:
    app: vault-frontend
  ports:
    - port: 80
      targetPort: 3000
---
# 4. Ingress — single public entry point routes to both services
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: vault-ingress
  namespace: production
spec:
  ingressClassName: nginx
  rules:
    - host: vault.example.com
      http:
        paths:
          - path: /api
            pathType: Prefix
            backend:
              service:
                name: vault-api-service
                port:
                  number: 80
          - path: /
            pathType: Prefix
            backend:
              service:
                name: vault-frontend-service
                port:
                  number: 80
```

```
Internet
   │
   ▼
Cloud Load Balancer (one, shared)
   │
   ▼
Ingress Controller (nginx-ingress pod)
   │
   ├─ /api/* ──────────► vault-api-service ──────► vault-api pods
   │                                                     │
   │                                             postgres-service
   │                                                     │
   │                                               postgres pod
   │
   └─ /* ──────────────► vault-frontend-service ── frontend pods
```

---

## Debugging Services

```bash
# Is the service defined correctly?
kubectl describe service vault-api-service -n production

# Are there endpoints? (if Endpoints is empty, selector doesn't match any pods)
kubectl get endpoints vault-api-service -n production

# Test DNS resolution
kubectl run dns-debug --image=busybox --rm -it --restart=Never -- \
  nslookup vault-api-service.production.svc.cluster.local

# Test connectivity
kubectl run curl-debug --image=curlimages/curl --rm -it --restart=Never -- \
  curl -v http://vault-api-service.production/health

# Check if Ingress is working
kubectl describe ingress vault-ingress -n production
kubectl get ingress -n production   # look for ADDRESS column
```

---

## Common Misunderstanding: "A Service load-balances equally"

**The misunderstanding:** "Kubernetes load balances traffic equally across all pods."

**The reality:** kube-proxy uses iptables rules (or IPVS) for load balancing, which does round-robin at the connection level. BUT: long-lived connections (HTTP keep-alive, gRPC, database connections) will stay on the same pod once established. If your client maintains a connection pool, all queries may go to ONE pod even though three are running.

The fix:
- For HTTP APIs: usually not a problem (short-lived connections)
- For gRPC: use a client-side load balancer or a service mesh (Istio, Linkerd) that can load balance at the request level
- For databases: use connection pooling middleware (PgBouncer) that distributes connections properly

→ Continue to: `04-storage.md`
