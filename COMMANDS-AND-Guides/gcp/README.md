# GCP — Zero to Hero Command Guide

## Reading Order

| # | File | What You'll Learn |
|---|------|-------------------|
| 00 | `00-fundamentals-and-cli.md` | Organization/Project hierarchy, IAM, gcloud CLI setup, Compute Engine VMs, Cloud Storage |
| 01 | `01-gke-cloudsql-monitoring.md` | GKE Kubernetes (Standard + Autopilot), Workload Identity, Cloud SQL, Cloud Run, Artifact Registry, Monitoring |

## Key Concepts

- **Projects** are the primary unit — create many of them (one per env, per dev, per service)
- **Service Accounts** = GCP's IAM roles — assign to VMs and GKE pods, no key files needed
- **Workload Identity** = GKE pods get GCP credentials without any secrets
- **Cloud Run** = serverless containers, scales to zero — great for HTTP APIs
- **GKE Autopilot** = managed K8s nodes, pay per pod — no node management
- **Cloud SQL Proxy** = secure database connection without public IP

## Quick Reference

```bash
# Login and setup
gcloud auth login
gcloud config set project my-project-id
gcloud config set compute/region asia-south1

# Compute Engine
gcloud compute instances list
gcloud compute instances start/stop/delete INSTANCE --zone=ZONE
gcloud compute ssh INSTANCE --zone=ZONE

# Cloud Storage
gcloud storage buckets create gs://BUCKET --location=ASIA-SOUTH1
gcloud storage cp file.txt gs://BUCKET/
gcloud storage ls gs://BUCKET/

# GKE
gcloud container clusters create CLUSTER --zone=ZONE
gcloud container clusters get-credentials CLUSTER --zone=ZONE

# Cloud Run
gcloud run deploy SERVICE --image=IMAGE --region=REGION

# Cloud SQL
gcloud sql instances create INSTANCE --database-version=POSTGRES_15 --region=REGION
```

## GCP vs AWS vs Azure

| GCP | AWS | Azure |
|-----|-----|-------|
| Project | Account | Subscription + Resource Group |
| Service Account | IAM Role | Managed Identity |
| Compute Engine | EC2 | Virtual Machine |
| Cloud Storage | S3 | Blob Storage |
| VPC | VPC | Virtual Network |
| GKE | EKS | AKS |
| Cloud SQL | RDS | Azure Database |
| Artifact Registry | ECR | Azure Container Registry |
| Cloud Monitoring | CloudWatch | Azure Monitor |
| Cloud Run | App Runner / Lambda + API GW | Azure Container Apps |
