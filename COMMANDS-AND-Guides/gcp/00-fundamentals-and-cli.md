# GCP — Part 00: Fundamentals and gcloud CLI

---

## GCP's Organizational Hierarchy

```
Organization (your company's domain, e.g., sanketika.in)
    │
    ▼
Folders (optional — departments, business units)
    │
    ▼
Projects
    │  (the primary unit: billing, APIs, IAM, quotas are per-project)
    ▼
Resources (VMs, Databases, GKE clusters, etc.)
```

**Project**: the fundamental unit in GCP. Every resource belongs to a project. Every project has:
- A project ID (globally unique, immutable): `vault-app-production-2026`
- A project number (numeric, auto-assigned): `123456789012`
- A display name: `Vault App Production`

Best practice: separate projects for production, staging, development. This gives you clean billing separation, IAM isolation, and easy cleanup.

---

## GCP Identity and Access: IAM

GCP IAM uses **principals** (who) and **roles** (what they can do) on **resources** (what).

**Principals:**
- Google Account: a person's Google account
- Service Account: an identity for applications/VMs/GKE pods (like AWS IAM role)
- Google Group: a collection of accounts
- Cloud Identity domain: all accounts in your organization domain

**Roles:**
- **Basic roles**: `roles/viewer`, `roles/editor`, `roles/owner` — very broad, avoid in production
- **Predefined roles**: `roles/storage.objectViewer`, `roles/container.admin` — specific to a service
- **Custom roles**: you define exactly which permissions

**Service Accounts** are the key identity mechanism for automation:
- VMs get a service account (access GCP APIs without credentials in code)
- GKE workloads use **Workload Identity** to assume a service account
- CI/CD pipelines authenticate as service accounts

---

## Installing and Configuring gcloud CLI

```bash
# Install Google Cloud SDK (Ubuntu/Debian)
curl https://sdk.cloud.google.com | bash
exec -l $SHELL    # restart shell to apply changes

# Verify
gcloud version

# Initialize and authenticate
gcloud init
# Follow prompts: log in, select project, select default region/zone

# Explicit login
gcloud auth login

# Set default project
gcloud config set project vault-app-production-2026

# Set default region and zone
gcloud config set compute/region asia-south1         # Mumbai
gcloud config set compute/zone asia-south1-a

# List current configuration
gcloud config list

# Named configurations (like AWS profiles)
gcloud config configurations create staging
gcloud config configurations activate production
gcloud config configurations list
```

### gcloud CLI Pattern

```bash
# Pattern: gcloud <service> <resource> <action> [flags]
gcloud compute instances list
gcloud container clusters create
gcloud storage buckets create
gcloud iam service-accounts create
```

---

## IAM Commands

```bash
# View current identity
gcloud auth list

# List IAM policy for a project
gcloud projects get-iam-policy vault-app-production-2026

# Add a role binding (grant user access)
gcloud projects add-iam-policy-binding vault-app-production-2026 \
  --member="user:shashank@sanketika.in" \
  --role="roles/container.admin"

# Create a service account
gcloud iam service-accounts create vault-api-sa \
  --display-name="Vault API Service Account" \
  --project=vault-app-production-2026

# Grant role to service account
gcloud projects add-iam-policy-binding vault-app-production-2026 \
  --member="serviceAccount:vault-api-sa@vault-app-production-2026.iam.gserviceaccount.com" \
  --role="roles/storage.objectViewer"

# Create and download a service account key (for external tools — avoid when possible)
gcloud iam service-accounts keys create sa-key.json \
  --iam-account=vault-api-sa@vault-app-production-2026.iam.gserviceaccount.com

# Use the key for authentication
export GOOGLE_APPLICATION_CREDENTIALS="$(pwd)/sa-key.json"
gcloud auth activate-service-account --key-file=sa-key.json
```

---

## Compute Engine — GCP Virtual Machines

```bash
# Create a VM
gcloud compute instances create vault-api-vm \
  --zone=asia-south1-a \
  --machine-type=e2-medium \
  --image-family=ubuntu-2204-lts \
  --image-project=ubuntu-os-cloud \
  --boot-disk-size=50GB \
  --tags=vault-api \
  --service-account=vault-api-sa@vault-app-production-2026.iam.gserviceaccount.com \
  --scopes=cloud-platform

# Common machine types:
# e2-micro: 0.25 vCPU, 1GB — free tier eligible
# e2-small: 0.5 vCPU, 2GB
# e2-medium: 1 vCPU, 4GB
# e2-standard-2: 2 vCPU, 8GB
# n2-standard-4: 4 vCPU, 16GB (higher performance than e2)
# c2-standard-4: 4 vCPU, 16GB — compute-optimized

# List instances
gcloud compute instances list

# Start/stop/delete
gcloud compute instances start vault-api-vm --zone=asia-south1-a
gcloud compute instances stop vault-api-vm --zone=asia-south1-a
gcloud compute instances delete vault-api-vm --zone=asia-south1-a

# SSH into an instance (gcloud handles key management)
gcloud compute ssh vault-api-vm --zone=asia-south1-a

# Run commands without SSH
gcloud compute ssh vault-api-vm --zone=asia-south1-a --command="docker ps"

# Create a firewall rule (allow HTTP on port 80 to instances tagged "vault-api")
gcloud compute firewall-rules create allow-http \
  --allow tcp:80 \
  --target-tags vault-api \
  --source-ranges 0.0.0.0/0

# Allow SSH from your IP only
gcloud compute firewall-rules create allow-ssh \
  --allow tcp:22 \
  --source-ranges $(curl -s ifconfig.me)/32
```

---

## Cloud Storage — GCP Object Storage (Equivalent to S3)

```bash
# Create a bucket (globally unique name)
gcloud storage buckets create gs://vault-app-storage-2026 \
  --location=ASIA-SOUTH1 \
  --default-storage-class=STANDARD

# Storage classes:
# STANDARD: frequently accessed
# NEARLINE: accessed < once/month (30-day minimum)
# COLDLINE: accessed < once/quarter (90-day minimum)
# ARCHIVE: accessed < once/year (365-day minimum), cheapest

# List buckets
gcloud storage buckets list

# Upload
gcloud storage cp myfile.txt gs://vault-app-storage-2026/
gcloud storage cp -r ./backups/ gs://vault-app-storage-2026/backups/

# List objects
gcloud storage ls gs://vault-app-storage-2026/
gcloud storage ls -l gs://vault-app-storage-2026/   # with size and date

# Download
gcloud storage cp gs://vault-app-storage-2026/backups/2026-06-17.sql.gz ./

# Delete
gcloud storage rm gs://vault-app-storage-2026/old-file.txt
gcloud storage rm -r gs://vault-app-storage-2026/old-backups/

# Make object publicly accessible
gcloud storage objects update gs://vault-app-storage-2026/public-doc.pdf \
  --predefined-acl=publicRead

# Set lifecycle policy (auto-delete objects older than 90 days)
cat > lifecycle.json <<EOF
{
  "rule": [{
    "action": {"type": "Delete"},
    "condition": {"age": 90}
  }]
}
EOF
gcloud storage buckets update gs://vault-app-storage-2026 \
  --lifecycle-file=lifecycle.json

# Grant service account access to bucket
gcloud storage buckets add-iam-policy-binding gs://vault-app-storage-2026 \
  --member="serviceAccount:vault-api-sa@vault-app-production-2026.iam.gserviceaccount.com" \
  --role="roles/storage.objectViewer"
```

---

## Common Misunderstanding: "gcloud projects are like AWS accounts"

**The misunderstanding:** "A GCP project is like an AWS account — one per company."

**The reality:** GCP projects are MUCH lighter-weight than AWS accounts. You're expected to have many projects. They're the primary unit of isolation, billing, and API enablement.

Common patterns:
- `company-shared-services` (DNS, monitoring, CI/CD)
- `company-production`
- `company-staging`
- `company-dev-shashank` (each developer gets their own)
- `company-data-pipeline`

Each developer having their own project means no shared resource conflicts, and deleting the project deletes all their resources cleanly. AWS accounts have overhead (billing setup, email, IAM) that makes per-developer accounts impractical; GCP projects have almost no overhead.

→ Continue to: `01-gke-cloudsql-monitoring.md`
