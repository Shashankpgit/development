# GCP — Part 01: GKE, Cloud SQL, Cloud Run, and Monitoring

---

## GKE — Google Kubernetes Engine

GKE is Google's managed Kubernetes. Google invented Kubernetes internally (as Borg), so GKE tends to have the most polished K8s experience of the three major clouds.

### GKE Modes

**Standard mode**: you manage node pools (choose VM types, sizes, autoscaling). More control. Charged for nodes.

**Autopilot mode**: Google manages everything about nodes. You only define pod specs. You pay per pod resource requests (not per node). Less operational overhead.

### GKE CLI Commands

```bash
# Enable the Kubernetes Engine API
gcloud services enable container.googleapis.com

# Create a Standard cluster
gcloud container clusters create vault-k8s-cluster \
  --zone=asia-south1-a \
  --num-nodes=3 \
  --machine-type=e2-standard-2 \
  --enable-autoscaling \
  --min-nodes=2 \
  --max-nodes=10 \
  --workload-pool=vault-app-production-2026.svc.id.goog \
  --enable-ip-alias

# Create an Autopilot cluster (recommended for most use cases)
gcloud container clusters create-auto vault-autopilot-cluster \
  --region=asia-south1

# Configure kubectl
gcloud container clusters get-credentials vault-k8s-cluster \
  --zone=asia-south1-a

# Verify
kubectl get nodes

# List clusters
gcloud container clusters list

# Add a node pool (e.g., add a high-memory pool)
gcloud container node-pools create high-memory-pool \
  --cluster=vault-k8s-cluster \
  --zone=asia-south1-a \
  --machine-type=n2-highmem-4 \
  --num-nodes=2

# Scale a node pool
gcloud container clusters resize vault-k8s-cluster \
  --zone=asia-south1-a \
  --node-pool=default-pool \
  --num-nodes=5

# Upgrade Kubernetes version
gcloud container clusters upgrade vault-k8s-cluster \
  --zone=asia-south1-a \
  --master

gcloud container clusters upgrade vault-k8s-cluster \
  --zone=asia-south1-a \
  --node-pool=default-pool

# Delete cluster
gcloud container clusters delete vault-k8s-cluster \
  --zone=asia-south1-a
```

### Workload Identity — GKE Pods with GCP Access

Workload Identity allows GKE pods to call GCP APIs as a service account, without key files:

```bash
# 1. Bind the Kubernetes service account to a GCP service account
gcloud iam service-accounts add-iam-policy-binding \
  vault-api-sa@vault-app-production-2026.iam.gserviceaccount.com \
  --role=roles/iam.workloadIdentityUser \
  --member="serviceAccount:vault-app-production-2026.svc.id.goog[production/vault-api-sa]"
# Format: PROJECT.svc.id.goog[K8S_NAMESPACE/K8S_SERVICE_ACCOUNT]

# 2. Annotate the Kubernetes service account
kubectl annotate serviceaccount vault-api-sa \
  --namespace production \
  iam.gke.io/gcp-service-account=vault-api-sa@vault-app-production-2026.iam.gserviceaccount.com

# 3. Use the service account in your deployment
spec:
  serviceAccountName: vault-api-sa
  # Pods now have GCP credentials via Workload Identity
```

---

## Cloud SQL — Managed PostgreSQL/MySQL/SQL Server

```bash
# Enable Cloud SQL API
gcloud services enable sqladmin.googleapis.com

# Create a PostgreSQL instance
gcloud sql instances create vault-postgres-prod \
  --database-version=POSTGRES_15 \
  --tier=db-g1-small \
  --region=asia-south1 \
  --storage-type=SSD \
  --storage-size=50GB \
  --availability-type=REGIONAL \
  --backup-start-time=03:00 \
  --retained-backups-count=7 \
  --deletion-protection

# Cloud SQL tiers: db-f1-micro (dev), db-g1-small, db-n1-standard-1 to db-n1-highmem-96

# Create a database
gcloud sql databases create vault \
  --instance=vault-postgres-prod

# Create a user
gcloud sql users create vaultadmin \
  --instance=vault-postgres-prod \
  --password="$(openssl rand -base64 32)"

# List instances
gcloud sql instances list

# Connect using Cloud SQL Proxy (recommended — no public IP needed)
# Download Cloud SQL Proxy:
wget https://storage.googleapis.com/cloud-sql-connectors/cloud-sql-proxy/v2.x.x/cloud-sql-proxy.linux.amd64 \
  -O cloud-sql-proxy && chmod +x cloud-sql-proxy

# Run proxy (creates a local socket for psql to connect to)
./cloud-sql-proxy vault-app-production-2026:asia-south1:vault-postgres-prod &

# Connect
psql "host=127.0.0.1 port=5432 dbname=vault user=vaultadmin"

# In Kubernetes: use the Cloud SQL Proxy as a sidecar container
# (Google provides documentation and sample YAML for this pattern)

# Create a read replica
gcloud sql instances create vault-postgres-read-1 \
  --master-instance-name=vault-postgres-prod \
  --region=asia-south1

# Delete instance
gcloud sql instances delete vault-postgres-prod
```

---

## Cloud Run — Serverless Containers

Cloud Run is GCP's serverless container platform. You give it a container image; it runs it and scales automatically — from zero to thousands of instances.

```bash
# Enable Cloud Run API
gcloud services enable run.googleapis.com

# Deploy a container image
gcloud run deploy vault-api \
  --image=gcr.io/vault-app-production-2026/vault-app:v1.0 \
  --platform=managed \
  --region=asia-south1 \
  --allow-unauthenticated \
  --port=3000 \
  --memory=512Mi \
  --cpu=1 \
  --min-instances=1 \
  --max-instances=10 \
  --set-env-vars NODE_ENV=production,PORT=3000 \
  --set-secrets DB_PASSWORD=vault-db-password:latest

# --allow-unauthenticated: public access
# --min-instances=1: keep one instance warm (no cold start)

# List Cloud Run services
gcloud run services list --region=asia-south1

# Get service URL
gcloud run services describe vault-api \
  --region=asia-south1 \
  --format="value(status.url)"

# View logs
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=vault-api" \
  --limit=50

# Update with new image (rolling deploy)
gcloud run deploy vault-api \
  --image=gcr.io/vault-app-production-2026/vault-app:v2.0 \
  --region=asia-south1

# Traffic splitting (gradual rollout)
gcloud run services update-traffic vault-api \
  --region=asia-south1 \
  --to-revisions=vault-api-00002-abc=90,vault-api-00001-xyz=10
# 90% to v2, 10% to v1

# Delete service
gcloud run services delete vault-api --region=asia-south1
```

---

## Google Artifact Registry — Container Registry

```bash
# Enable Artifact Registry API
gcloud services enable artifactregistry.googleapis.com

# Create a repository
gcloud artifacts repositories create vault-images \
  --repository-format=docker \
  --location=asia-south1

# Configure Docker to authenticate to Artifact Registry
gcloud auth configure-docker asia-south1-docker.pkg.dev

# Tag and push image
docker tag vault-app:v1.0 \
  asia-south1-docker.pkg.dev/vault-app-production-2026/vault-images/vault-app:v1.0

docker push \
  asia-south1-docker.pkg.dev/vault-app-production-2026/vault-images/vault-app:v1.0

# List images
gcloud artifacts docker images list \
  asia-south1-docker.pkg.dev/vault-app-production-2026/vault-images
```

---

## Cloud Monitoring — Google Cloud Observability

```bash
# List available metrics
gcloud monitoring metrics-scopes list

# GKE metrics are automatically available in Cloud Monitoring
# Access via: console.cloud.google.com → Monitoring

# View metrics in terminal
gcloud monitoring time-series list \
  --filter='metric.type="kubernetes.io/container/cpu/request_utilization"' \
  --interval-start-time=$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ) \
  --interval-end-time=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Create an alerting policy (alert when CPU > 80%)
gcloud alpha monitoring policies create \
  --display-name="High CPU Alert" \
  --policy-from-file=alert-policy.yaml

# Cloud Logging — view logs
gcloud logging read "resource.type=k8s_container" \
  --limit=50 \
  --format="value(timestamp,textPayload)"

# Export logs to Cloud Storage (for long-term retention/analysis)
gcloud logging sinks create vault-logs-sink \
  storage.googleapis.com/vault-logs-bucket \
  --log-filter="resource.type=k8s_container"
```

---

## Common Misunderstanding: "Cloud Run replaces GKE"

**The misunderstanding:** "Cloud Run is simpler — I'll use it for everything instead of GKE."

**The reality:** Cloud Run is excellent for stateless HTTP services but has limitations:

| Capability | Cloud Run | GKE |
|-----------|-----------|-----|
| Stateless HTTP APIs | Excellent | Good |
| Background workers | Limited | Excellent |
| Stateful apps (DBs) | No | Yes |
| Custom networking | Limited | Full control |
| Sidecars/DaemonSets | Limited | Full |
| Cost at constant high load | Can be expensive | Predictable |
| Cold starts | Yes (unless min-instances=1) | No |

Cloud Run is ideal for: APIs, webhooks, event-driven functions, services with spiky traffic.

GKE is ideal for: complex microservice architectures, stateful workloads, services that run 24/7 at high load, services needing rich networking.

In practice, many companies run both — Cloud Run for simple stateless services, GKE for the core platform.

→ Continue to: `README.md`
