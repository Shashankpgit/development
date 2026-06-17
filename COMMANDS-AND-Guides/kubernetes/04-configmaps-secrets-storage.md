# Kubernetes — Part 04: ConfigMaps, Secrets, and Storage

---

## ConfigMaps — Externalizing Configuration

A ConfigMap stores configuration data as key-value pairs. Instead of hardcoding config in your image or passing dozens of `-e` flags, you store it in a ConfigMap and inject it into pods.

```yaml
# configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: vault-api-config
  namespace: production
data:
  NODE_ENV: "production"
  PORT: "3000"
  LOG_LEVEL: "info"
  # Multi-line values are supported
  app.properties: |
    max_connections=100
    timeout=30s
    feature_new_ui=true
  nginx.conf: |
    server {
      listen 80;
      location / {
        proxy_pass http://localhost:3000;
      }
    }
```

### Inject ConfigMap as Environment Variables

```yaml
spec:
  containers:
    - name: vault-api
      image: vault-app:v1.0
      
      # Option 1: Load specific keys as env vars
      env:
        - name: NODE_ENV
          valueFrom:
            configMapKeyRef:
              name: vault-api-config
              key: NODE_ENV
        - name: PORT
          valueFrom:
            configMapKeyRef:
              name: vault-api-config
              key: PORT
      
      # Option 2: Load ALL keys as env vars (simpler but less explicit)
      envFrom:
        - configMapRef:
            name: vault-api-config
```

### Inject ConfigMap as a File (Volume)

```yaml
spec:
  containers:
    - name: nginx
      image: nginx:1.24
      volumeMounts:
        - name: nginx-config
          mountPath: /etc/nginx/conf.d/   # ConfigMap keys become files here
  volumes:
    - name: nginx-config
      configMap:
        name: vault-api-config
        items:
          - key: nginx.conf
            path: default.conf    # nginx.conf key → /etc/nginx/conf.d/default.conf
```

When you update a ConfigMap, pods using it as a volume see the updated files within ~1-2 minutes (without restart). Pods using it as env vars need to be restarted.

---

## Secrets — Sensitive Configuration

Secrets are exactly like ConfigMaps but designed for sensitive data: passwords, API keys, TLS certificates, SSH keys.

Important: by default, Kubernetes Secrets are only base64-encoded (not encrypted). Anyone with access to etcd can read them. For real security, enable encryption at rest and use a secrets management tool (HashiCorp Vault, AWS Secrets Manager, External Secrets Operator).

```yaml
# Create a secret imperatively (values are automatically base64-encoded)
kubectl create secret generic postgres-secret \
  --from-literal=username=vaultuser \
  --from-literal=password=supersecret123 \
  --from-literal=url=postgresql://vaultuser:supersecret123@postgres:5432/vault \
  -n production

# Create from files
kubectl create secret generic tls-certs \
  --from-file=tls.crt=./cert.pem \
  --from-file=tls.key=./key.pem

# Create TLS secret directly
kubectl create secret tls vault-tls \
  --cert=./cert.pem \
  --key=./key.pem
```

```yaml
# secret.yaml — store base64 encoded values
apiVersion: v1
kind: Secret
metadata:
  name: postgres-secret
  namespace: production
type: Opaque
data:
  username: dmF1bHR1c2Vy          # base64("vaultuser")
  password: c3VwZXJzZWNyZXQxMjM=  # base64("supersecret123")
```

```bash
# Encode to base64
echo -n "supersecret123" | base64
# Decode
echo "c3VwZXJzZWNyZXQxMjM=" | base64 --decode
```

### Use Secrets in Pods

```yaml
spec:
  containers:
    - name: vault-api
      env:
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: password
        - name: DB_USERNAME
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: username
      envFrom:
        - secretRef:
            name: postgres-secret  # all keys loaded as env vars
```

---

## Storage: PersistentVolumes and PersistentVolumeClaims

### The Problem

Containers have ephemeral storage — data inside a container is lost when it restarts. For databases and other stateful apps, you need storage that persists beyond the pod's lifetime.

Kubernetes storage model:
```
PersistentVolume (PV)    — actual storage resource (EBS volume, NFS, disk)
PersistentVolumeClaim (PVC) — a request for storage from a pod
StorageClass             — defines how to dynamically provision PVs
```

The separation exists because ops teams manage actual storage (PVs), while developers just request storage (PVCs) without needing to know the underlying infrastructure.

### StorageClass — Dynamic Provisioning

In cloud environments, you typically use StorageClasses for dynamic provisioning: create a PVC, Kubernetes automatically creates the underlying volume (EBS, GCE PD, Azure Disk).

```yaml
# StorageClass (usually pre-configured by cloud provider)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: ebs.csi.aws.com     # AWS EBS CSI driver
parameters:
  type: gp3
  iops: "3000"
reclaimPolicy: Retain             # Delete or Retain when PVC is deleted
allowVolumeExpansion: true
```

### PersistentVolumeClaim — Request Storage

```yaml
# pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-data
  namespace: production
spec:
  accessModes:
    - ReadWriteOnce           # RWO: one node; RWM: many nodes; ROX: many nodes read-only
  storageClassName: fast-ssd
  resources:
    requests:
      storage: 50Gi
```

```bash
kubectl apply -f pvc.yaml
kubectl get pvc -n production     # check status: Pending → Bound
```

### Use PVC in a Pod

```yaml
spec:
  containers:
    - name: postgres
      image: postgres:15
      volumeMounts:
        - name: db-storage
          mountPath: /var/lib/postgresql/data
  volumes:
    - name: db-storage
      persistentVolumeClaim:
        claimName: postgres-data  # reference the PVC by name
```

### StatefulSet with volumeClaimTemplates (Recommended for DBs)

StatefulSets use `volumeClaimTemplates` instead of a single PVC — each pod (replica) gets its own PVC automatically:

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
spec:
  replicas: 1
  serviceName: postgres
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
        - name: postgres
          image: postgres:15
          volumeMounts:
            - name: pgdata
              mountPath: /var/lib/postgresql/data
  volumeClaimTemplates:
    - metadata:
        name: pgdata
      spec:
        accessModes: ["ReadWriteOnce"]
        storageClassName: fast-ssd
        resources:
          requests:
            storage: 50Gi
# Result: postgres-0 gets pvc "pgdata-postgres-0"
#         postgres-1 gets pvc "pgdata-postgres-1"
# Deleting/restarting postgres-0 reattaches pgdata-postgres-0 (data preserved)
```

---

## Real-World: Full Stack with Config + Secrets + Storage

```yaml
---
# ConfigMap for app config
apiVersion: v1
kind: ConfigMap
metadata:
  name: vault-config
  namespace: production
data:
  NODE_ENV: production
  LOG_LEVEL: info
---
# Secret for sensitive values
apiVersion: v1
kind: Secret
metadata:
  name: vault-secrets
  namespace: production
type: Opaque
stringData:                     # stringData auto-encodes to base64
  DB_PASSWORD: "mysupersecretpassword"
  JWT_SECRET: "myjwtsecret"
  REDIS_PASSWORD: "redispassword"
---
# StatefulSet for postgres with its own storage
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
  namespace: production
spec:
  replicas: 1
  serviceName: postgres-service
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
        - name: postgres
          image: postgres:15
          env:
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: vault-secrets
                  key: DB_PASSWORD
            - name: POSTGRES_DB
              value: vault
          volumeMounts:
            - name: pgdata
              mountPath: /var/lib/postgresql/data
  volumeClaimTemplates:
    - metadata:
        name: pgdata
      spec:
        accessModes: ["ReadWriteOnce"]
        storageClassName: fast-ssd
        resources:
          requests:
            storage: 20Gi
---
# Deployment for the API with config + secrets injected
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vault-api
  namespace: production
spec:
  replicas: 3
  selector:
    matchLabels:
      app: vault-api
  template:
    metadata:
      labels:
        app: vault-api
    spec:
      containers:
        - name: vault-api
          image: vault-app:v1.0
          envFrom:
            - configMapRef:
                name: vault-config
            - secretRef:
                name: vault-secrets
          env:
            - name: DATABASE_URL
              value: "postgresql://postgres:$(DB_PASSWORD)@postgres-service:5432/vault"
```

---

## Common Misunderstanding: "Secrets are secure by default"

**The misunderstanding:** "I'm using Secrets, so my sensitive data is encrypted."

**The reality:** Kubernetes Secrets are base64-encoded, not encrypted. Base64 is reversible by anyone — it's just encoding, not encryption. Anyone with read access to the namespace (or direct access to etcd) can decode Secrets trivially:

```bash
kubectl get secret postgres-secret -o jsonpath='{.data.password}' | base64 --decode
```

**How to actually secure secrets:**

1. **Encryption at Rest**: Enable etcd encryption in your cluster so data is encrypted on disk. This requires cluster admin configuration.

2. **RBAC**: Restrict who can read secrets with Role-Based Access Control. Not everyone should be able to `kubectl get secret`.

3. **External Secrets Operator**: Store secrets in AWS Secrets Manager, HashiCorp Vault, or GCP Secret Manager. The External Secrets Operator pulls them into Kubernetes at runtime. The secret value never lives in etcd permanently.

4. **Audit Logs**: Enable Kubernetes audit logs to track who accessed which secrets and when.

→ Continue to: `05-deployments-and-scaling.md`
