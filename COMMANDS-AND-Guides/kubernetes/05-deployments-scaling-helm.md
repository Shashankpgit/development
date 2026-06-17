# Kubernetes — Part 05: Deployments, Scaling, and Helm

---

## Horizontal Pod Autoscaler (HPA) — Autoscaling

HPA automatically adjusts the number of pod replicas based on CPU usage, memory usage, or custom metrics.

```yaml
# hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: vault-api-hpa
  namespace: production
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: vault-api
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70    # scale when average CPU > 70%
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80
```

```bash
kubectl apply -f hpa.yaml
kubectl get hpa -n production         # check current replicas and target
kubectl describe hpa vault-api-hpa    # see scaling events and decisions
```

HPA requires the metrics-server to be installed in the cluster. For cloud clusters (EKS, GKE, AKS), it's usually pre-installed.

---

## Pod Disruption Budget — Safe Autoscaling and Node Maintenance

A PodDisruptionBudget (PDB) tells Kubernetes "never take down more than X pods at once." This protects you during:
- Node upgrades (drain node → evict pods)
- Cluster autoscaler scale-down
- Manual pod deletions

```yaml
# pdb.yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: vault-api-pdb
  namespace: production
spec:
  minAvailable: 2             # always keep at least 2 pods running
  # OR:
  # maxUnavailable: 1         # at most 1 can be unavailable at any time
  selector:
    matchLabels:
      app: vault-api
```

```bash
kubectl apply -f pdb.yaml
kubectl get pdb -n production
```

---

## Resource Quotas — Limit What a Namespace Can Use

In a shared cluster, you can prevent any one team/namespace from consuming all resources:

```yaml
# quota.yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: production-quota
  namespace: production
spec:
  hard:
    requests.cpu: "10"           # total CPU requests across all pods: max 10 cores
    requests.memory: 20Gi        # total memory requests: max 20GB
    limits.cpu: "20"
    limits.memory: 40Gi
    pods: "50"                   # max 50 pods in this namespace
    services: "10"
    persistentvolumeclaims: "10"
    secrets: "20"
    configmaps: "20"
```

---

## Affinity and Anti-Affinity — Pod Placement Rules

Control WHERE pods are scheduled.

### Pod Anti-Affinity — Spread Replicas Across Nodes

```yaml
# Don't put two vault-api pods on the same node (high availability)
spec:
  affinity:
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        - labelSelector:
            matchExpressions:
              - key: app
                operator: In
                values:
                  - vault-api
          topologyKey: kubernetes.io/hostname  # spread across nodes
```

`required` = hard rule (pod won't schedule if violated)
`preferred` = soft preference (scheduler tries, but not mandatory)

### Node Affinity — Run on Specific Node Types

```yaml
# Only run on nodes with SSD storage
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: disktype
                operator: In
                values:
                  - ssd
```

---

## Taints and Tolerations — Reserve Nodes for Specific Workloads

Taints repel pods from a node. Tolerations allow specific pods to run on tainted nodes.

```bash
# Taint a node (reserved for GPU workloads only)
kubectl taint nodes gpu-node-1 workload=gpu:NoSchedule
# This means: no pod can run here UNLESS it has a matching toleration
```

```yaml
# Pod with toleration for the GPU node
spec:
  tolerations:
    - key: workload
      operator: Equal
      value: gpu
      effect: NoSchedule
```

Common use: add a taint to dedicated monitoring nodes, then only monitoring pods have the toleration to run there.

---

## Helm — The Kubernetes Package Manager

Helm is to Kubernetes what `apt` is to Ubuntu. Instead of managing 10 YAML files for a single application, Helm bundles them into a "chart" — a templated, versioned package.

```
Without Helm:
  - deployment.yaml
  - service.yaml
  - ingress.yaml
  - configmap.yaml
  - hpa.yaml
  - pdb.yaml
  - serviceaccount.yaml
  All slightly different for dev/staging/prod

With Helm:
  helm install vault-api ./vault-chart --values values.prod.yaml
  helm upgrade vault-api ./vault-chart --values values.prod.yaml
  helm rollback vault-api 2
```

### Install Helm

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version
```

### Add a Helm Repository

```bash
# Add the official stable charts repo
helm repo add stable https://charts.helm.sh/stable

# Add prometheus community charts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

# Update local repo cache
helm repo update

# Search for charts
helm search repo prometheus
helm search hub grafana     # search Artifact Hub (public registry)
```

### Install a Chart

```bash
# Install nginx-ingress
helm install nginx-ingress ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace

# Install with custom values
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set grafana.adminPassword=mysecretpassword \
  --set prometheus.retention=30d

# Install from a values file (preferred over --set for many values)
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  -f monitoring-values.yaml
```

### Helm Chart Management

```bash
# List installed releases
helm list -A               # all namespaces
helm list -n monitoring

# See what values a release is using
helm get values prometheus -n monitoring

# Get the full rendered YAML (useful for debugging)
helm get manifest prometheus -n monitoring

# Upgrade a release (update image, change values)
helm upgrade prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  -f monitoring-values.yaml

# Rollback to previous version
helm rollback prometheus 1   # rollback to revision 1
helm history prometheus -n monitoring   # see all revisions

# Uninstall
helm uninstall prometheus -n monitoring
```

### Creating Your Own Chart

```bash
# Create a chart skeleton
helm create vault-api-chart

# Structure:
vault-api-chart/
├── Chart.yaml          # chart metadata (name, version, description)
├── values.yaml         # default values
├── templates/
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   ├── hpa.yaml
│   ├── _helpers.tpl    # template helper functions
│   └── NOTES.txt       # displayed after install
└── charts/             # chart dependencies
```

```yaml
# values.yaml — defaults
replicaCount: 2
image:
  repository: vault-app
  tag: "v1.0"
  pullPolicy: IfNotPresent
service:
  type: ClusterIP
  port: 80
resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 250m
    memory: 256Mi
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
```

```yaml
# templates/deployment.yaml — using template values
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "vault-api-chart.fullname" . }}
  labels:
    {{- include "vault-api-chart.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      {{- include "vault-api-chart.selectorLabels" . | nindent 6 }}
  template:
    spec:
      containers:
        - name: {{ .Chart.Name }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
```

```bash
# Render templates locally (no cluster needed — debug your templates)
helm template vault-api-chart ./vault-api-chart --values values.prod.yaml

# Validate the chart
helm lint ./vault-api-chart

# Install/upgrade with the same command (use --install flag)
helm upgrade --install vault-api ./vault-api-chart \
  --namespace production \
  --create-namespace \
  -f values.prod.yaml
```

---

## Namespaces and RBAC

### Create Namespaces

```bash
kubectl create namespace production
kubectl create namespace staging
kubectl create namespace monitoring
```

### RBAC — Who Can Do What

```yaml
# ServiceAccount — identity for pods
apiVersion: v1
kind: ServiceAccount
metadata:
  name: vault-api-sa
  namespace: production
---
# Role — permissions within a namespace
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: vault-api-role
  namespace: production
rules:
  - apiGroups: [""]
    resources: ["configmaps", "secrets"]
    verbs: ["get", "list"]
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list", "watch"]
---
# RoleBinding — attach role to service account
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: vault-api-binding
  namespace: production
subjects:
  - kind: ServiceAccount
    name: vault-api-sa
    namespace: production
roleRef:
  kind: Role
  apiVersion: rbac.authorization.k8s.io/v1
  name: vault-api-role
```

```bash
# Test permissions
kubectl auth can-i get pods --as=system:serviceaccount:production:vault-api-sa
kubectl auth can-i delete deployments --as=system:serviceaccount:production:vault-api-sa
```

---

## Common Misunderstanding: "Helm is just YAML templating"

**The misunderstanding:** "I could just use envsubst or kustomize instead of Helm — it's the same thing."

**The reality:** Helm does templating, but also:
- **Release management**: tracks all resources deployed as part of a release
- **Atomic upgrades**: if part of an upgrade fails, Helm rolls back everything
- **Versioned rollbacks**: `helm rollback` undoes ALL changes to all resources in one command
- **Dependencies**: a chart can declare dependency charts (your app chart can depend on the postgres chart)
- **Test hooks**: `helm test` runs test pods to validate the deployment
- **Lifecycle hooks**: pre-install, post-install, pre-upgrade, post-upgrade hooks for migrations, etc.

Kustomize is better for simple environment-specific overlays without releases. Helm is better when you need package distribution, versioning, or the full release management lifecycle.

→ Continue to: `06-troubleshooting.md`
