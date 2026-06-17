# Kubernetes — Part 02: Pods, Deployments, and Workload Objects

---

## Pod YAML — The Foundation

Everything in Kubernetes is described in YAML. Understanding pod YAML is the foundation for all other workload objects.

```yaml
# pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: vault-api-pod
  namespace: production
  labels:                         # key-value pairs — used for selection and filtering
    app: vault-api
    version: v1.0
    environment: production
spec:
  containers:
    - name: vault-api
      image: vault-app:v1.0
      ports:
        - containerPort: 3000
      env:
        - name: NODE_ENV
          value: production
        - name: PORT
          value: "3000"
      resources:
        requests:                 # guaranteed minimum allocation
          cpu: "250m"             # 250 millicores = 0.25 CPU
          memory: "256Mi"
        limits:                   # hard maximum
          cpu: "500m"
          memory: "512Mi"
      readinessProbe:             # is the app ready to receive traffic?
        httpGet:
          path: /health
          port: 3000
        initialDelaySeconds: 5
        periodSeconds: 10
      livenessProbe:              # is the app still alive?
        httpGet:
          path: /health
          port: 3000
        initialDelaySeconds: 15
        periodSeconds: 20
        failureThreshold: 3
  restartPolicy: Always           # Always / OnFailure / Never
```

---

## Resource Requests and Limits — Critical Concept

Every pod should define resource requests and limits. Without them, a runaway pod can starve other pods on the same node.

```
requests: the scheduler uses this to decide WHERE to place the pod
limits:   the kubelet enforces this as a hard cap at runtime
```

**CPU is expressed in millicores:**
- `1000m` = 1 CPU core
- `250m` = 0.25 CPU core (quarter of a core)
- `500m` = 0.5 CPU core

**Memory is expressed in bytes with suffixes:**
- `256Mi` = 256 mebibytes (≈ 268 MB)
- `1Gi` = 1 gibibyte
- `512Mi` = 512 mebibytes

What happens when limits are exceeded:
- CPU: throttled (slowed down, not killed)
- Memory: killed (OOMKilled — Out of Memory Killed) and restarted

---

## Health Probes — Readiness vs Liveness vs Startup

These three probes solve three different problems:

### Readiness Probe
"Is this pod ready to serve traffic?"

If the readiness probe fails, the pod is removed from the Service's load balancer. It still runs — it just doesn't receive traffic. This prevents sending requests to a pod that's still warming up.

```yaml
readinessProbe:
  httpGet:
    path: /ready
    port: 3000
  initialDelaySeconds: 5    # wait 5s before first check
  periodSeconds: 10          # check every 10s
  failureThreshold: 3        # 3 failures = not ready
```

### Liveness Probe
"Is this pod still alive and healthy?"

If the liveness probe fails, Kubernetes kills and restarts the container. Use this to detect deadlocks or hung processes that are still running but can't do any work.

```yaml
livenessProbe:
  httpGet:
    path: /healthz
    port: 3000
  initialDelaySeconds: 30   # give the app time to start
  periodSeconds: 10
  failureThreshold: 3
```

### Startup Probe
"Has the app finished starting?"

For slow-starting apps that need a long time to initialize. While the startup probe is running, liveness and readiness probes are disabled. Once startup probe succeeds, the other probes take over.

```yaml
startupProbe:
  httpGet:
    path: /healthz
    port: 3000
  failureThreshold: 30      # allow up to 300s (30 * 10s) for startup
  periodSeconds: 10
```

---

## Deployment — The Standard for Stateless Apps

You should almost never create bare Pods in production. Use a Deployment. A Deployment manages a ReplicaSet, which manages the pods. This gives you rolling updates, rollback, and self-healing.

```yaml
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vault-api
  namespace: production
spec:
  replicas: 3                   # keep 3 pods running always
  selector:
    matchLabels:
      app: vault-api             # manages pods with this label
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1          # at most 1 pod can be unavailable during update
      maxSurge: 1                # at most 1 extra pod during update (temporarily 4 pods)
  template:                     # the pod template — everything below is a pod spec
    metadata:
      labels:
        app: vault-api           # must match selector.matchLabels
        version: v1.0
    spec:
      containers:
        - name: vault-api
          image: vault-app:v1.0
          ports:
            - containerPort: 3000
          resources:
            requests:
              cpu: "250m"
              memory: "256Mi"
            limits:
              cpu: "500m"
              memory: "512Mi"
          readinessProbe:
            httpGet:
              path: /health
              port: 3000
            initialDelaySeconds: 5
            periodSeconds: 10
          env:
            - name: NODE_ENV
              value: production
```

---

## Rolling Update — How Zero-Downtime Deploys Work

When you update the image in a Deployment, Kubernetes does this:

```
Initial state: 3 pods running v1.0

Step 1: Start 1 new pod with v2.0 (maxSurge: 1 → now 4 pods total)
Step 2: Wait for new pod to pass readiness probe
Step 3: Terminate 1 old v1.0 pod (maxUnavailable: 1 → still 3 pods)
Step 4: Repeat until all pods are v2.0

Final state: 3 pods running v2.0
Traffic was served throughout — zero downtime
```

If the new pods fail their readiness probe, the update pauses — old pods keep serving traffic. No cascading failure.

```bash
# Trigger a rolling update
kubectl set image deployment/vault-api vault-api=vault-app:v2.0 -n production

# Watch the update live
kubectl rollout status deployment/vault-api -n production

# If something's wrong, roll back immediately
kubectl rollout undo deployment/vault-api -n production
```

---

## StatefulSet — For Databases and Stateful Services

StatefulSets are like Deployments, but each pod gets:
- A predictable, stable name: `postgres-0`, `postgres-1`, `postgres-2`
- Its own dedicated PersistentVolumeClaim (storage doesn't move between pods)
- Ordered startup and shutdown

```yaml
# statefulset.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
  namespace: production
spec:
  serviceName: postgres           # required: headless service name
  replicas: 1
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
          ports:
            - containerPort: 5432
          env:
            - name: POSTGRES_DB
              value: vault
            - name: POSTGRES_USER
              valueFrom:
                secretKeyRef:
                  name: postgres-secret
                  key: username
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: postgres-secret
                  key: password
          volumeMounts:
            - name: postgres-data
              mountPath: /var/lib/postgresql/data
  volumeClaimTemplates:           # each pod gets its own PVC
    - metadata:
        name: postgres-data
      spec:
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: 20Gi
```

---

## DaemonSet — One Pod Per Node

```yaml
# daemonset.yaml — run Fluent Bit on every node to collect logs
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluent-bit
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: fluent-bit
  template:
    metadata:
      labels:
        app: fluent-bit
    spec:
      containers:
        - name: fluent-bit
          image: fluent/fluent-bit:2.1
          volumeMounts:
            - name: varlog
              mountPath: /var/log
            - name: varlibdockercontainers
              mountPath: /var/lib/docker/containers
              readOnly: true
      volumes:
        - name: varlog
          hostPath:
            path: /var/log
        - name: varlibdockercontainers
          hostPath:
            path: /var/lib/docker/containers
      tolerations:                # allow on master nodes too
        - key: node-role.kubernetes.io/control-plane
          effect: NoSchedule
          operator: Exists
```

---

## Job — Run to Completion

```yaml
# job.yaml — database migration
apiVersion: batch/v1
kind: Job
metadata:
  name: db-migration-v2
spec:
  backoffLimit: 3               # retry 3 times on failure
  template:
    spec:
      restartPolicy: OnFailure  # Jobs must have OnFailure or Never (not Always)
      containers:
        - name: migrate
          image: vault-app:v2.0
          command: ["node", "scripts/migrate.js"]
          env:
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: postgres-secret
                  key: url
```

---

## CronJob — Scheduled Tasks

```yaml
# cronjob.yaml — nightly database backup
apiVersion: batch/v1
kind: CronJob
metadata:
  name: db-backup
spec:
  schedule: "0 2 * * *"          # 2 AM every day (cron syntax)
  concurrencyPolicy: Forbid       # don't run if previous one is still running
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 1
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: OnFailure
          containers:
            - name: backup
              image: postgres:15
              command:
                - /bin/sh
                - -c
                - pg_dump $DATABASE_URL | gzip > /backup/$(date +%Y%m%d).sql.gz
```

---

## Init Containers — Run Before Main Container

Init containers run and complete BEFORE the main containers start. Use them for setup tasks: wait for the database, download config, run migrations.

```yaml
spec:
  initContainers:
    - name: wait-for-db
      image: busybox
      command:
        - sh
        - -c
        - |
          until nc -z postgres-service 5432; do
            echo "waiting for postgres..."
            sleep 2
          done
          echo "postgres is ready!"
  containers:
    - name: vault-api
      image: vault-app:v1.0
      # This only starts after wait-for-db finishes
```

---

## Common Misunderstanding: "Pods are units of scaling"

**The misunderstanding:** "If I need to scale my app, I scale up the pods."

**The reality:** You scale the DEPLOYMENT, not individual pods. Pods are ephemeral workers managed by the Deployment. When you run `kubectl scale deployment vault-api --replicas=5`, the Deployment creates the right number of pods. You never create pods directly in production — you let the Deployment do it.

The hierarchy is:
```
Deployment  →  manages →  ReplicaSet  →  manages →  Pods
```

When you scale or roll out a new version, Kubernetes creates a new ReplicaSet with the new pod spec, scales it up, and scales the old ReplicaSet down. `kubectl rollout undo` simply reverses this — it scales the old ReplicaSet back up.

→ Continue to: `03-services-and-networking.md`
