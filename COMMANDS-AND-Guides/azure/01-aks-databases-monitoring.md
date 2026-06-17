# Azure — Part 01: AKS, Databases, and Monitoring

---

## AKS — Azure Kubernetes Service

AKS is managed Kubernetes on Azure. Microsoft manages the control plane; you manage node pools and workloads.

### AKS Concepts

**Node Pool**: a group of VMs (nodes) with the same configuration. You can have multiple node pools with different VM sizes (e.g., general-purpose + GPU pool).

**System node pool**: required pool that runs Kubernetes system pods. Don't run user workloads here.

**User node pool**: where your application pods run. Scale separately from the system pool.

**Workload Identity**: the AKS equivalent of IRSA. Azure AD identity for pods — pods get Azure AD tokens to access Azure services (Key Vault, Storage, etc.) without credentials.

### AKS CLI Commands

```bash
# Create an AKS cluster
az aks create \
  --resource-group vault-app-production \
  --name vault-k8s-cluster \
  --node-count 3 \
  --node-vm-size Standard_D2s_v3 \
  --generate-ssh-keys \
  --enable-addons monitoring \
  --enable-oidc-issuer \
  --enable-workload-identity

# Get credentials (configure kubectl)
az aks get-credentials \
  --resource-group vault-app-production \
  --name vault-k8s-cluster

# Verify kubectl works
kubectl get nodes

# List AKS clusters
az aks list --output table

# Show cluster info
az aks show \
  --resource-group vault-app-production \
  --name vault-k8s-cluster

# Add a node pool
az aks nodepool add \
  --resource-group vault-app-production \
  --cluster-name vault-k8s-cluster \
  --name gpupool \
  --node-count 2 \
  --node-vm-size Standard_NC6

# Scale node pool
az aks nodepool scale \
  --resource-group vault-app-production \
  --cluster-name vault-k8s-cluster \
  --name nodepool1 \
  --node-count 5

# Enable cluster autoscaler
az aks nodepool update \
  --resource-group vault-app-production \
  --cluster-name vault-k8s-cluster \
  --name nodepool1 \
  --enable-cluster-autoscaler \
  --min-count 2 \
  --max-count 10

# Upgrade cluster Kubernetes version
az aks get-upgrades \
  --resource-group vault-app-production \
  --name vault-k8s-cluster

az aks upgrade \
  --resource-group vault-app-production \
  --name vault-k8s-cluster \
  --kubernetes-version 1.29.0

# Delete cluster
az aks delete \
  --resource-group vault-app-production \
  --name vault-k8s-cluster \
  --yes
```

### Workload Identity — Pods Without Credentials

```bash
# 1. Create user-assigned managed identity
az identity create \
  --resource-group vault-app-production \
  --name vault-api-identity

# Get the identity's client ID
IDENTITY_CLIENT_ID=$(az identity show \
  --resource-group vault-app-production \
  --name vault-api-identity \
  --query clientId --output tsv)

# 2. Assign Azure role to the identity (e.g., Storage Blob Data Reader)
STORAGE_ID=$(az storage account show \
  --name vaultappstorage2026 \
  --query id --output tsv)

az role assignment create \
  --role "Storage Blob Data Reader" \
  --assignee $IDENTITY_CLIENT_ID \
  --scope $STORAGE_ID

# 3. Create Kubernetes service account linked to the identity
kubectl create serviceaccount vault-api-sa -n production
kubectl annotate serviceaccount vault-api-sa \
  azure.workload.identity/client-id=$IDENTITY_CLIENT_ID \
  -n production

# 4. Use this service account in your deployment
spec:
  serviceAccountName: vault-api-sa
  # Now pods have Azure credentials to access Storage without any secrets
```

---

## Azure Database for PostgreSQL

```bash
# Create a flexible server (recommended over single server)
az postgres flexible-server create \
  --resource-group vault-app-production \
  --name vault-postgres-prod \
  --location centralindia \
  --admin-user vaultadmin \
  --admin-password "$(openssl rand -base64 32)" \
  --sku-name Standard_D2s_v3 \
  --tier GeneralPurpose \
  --storage-size 128 \
  --version 15 \
  --high-availability ZoneRedundant

# List databases
az postgres flexible-server list --output table

# Create a database
az postgres flexible-server db create \
  --resource-group vault-app-production \
  --server-name vault-postgres-prod \
  --database-name vault

# Show connection string
az postgres flexible-server show-connection-string \
  --server-name vault-postgres-prod

# Create firewall rule (allow AKS subnet)
az postgres flexible-server firewall-rule create \
  --resource-group vault-app-production \
  --name vault-postgres-prod \
  --rule-name AllowAKS \
  --start-ip-address 10.0.0.0 \
  --end-ip-address 10.0.255.255

# Scale compute
az postgres flexible-server update \
  --resource-group vault-app-production \
  --name vault-postgres-prod \
  --sku-name Standard_D4s_v3
```

---

## Azure Key Vault — Secrets Management

Azure Key Vault stores secrets, keys, and certificates. The production alternative to Kubernetes Secrets.

```bash
# Create Key Vault
az keyvault create \
  --name vault-app-keyvault \
  --resource-group vault-app-production \
  --location centralindia

# Store a secret
az keyvault secret set \
  --vault-name vault-app-keyvault \
  --name "database-password" \
  --value "mysupersecretpassword"

# Retrieve a secret
az keyvault secret show \
  --vault-name vault-app-keyvault \
  --name "database-password" \
  --query "value" --output tsv

# List secrets
az keyvault secret list \
  --vault-name vault-app-keyvault --output table

# Grant a managed identity access to Key Vault
az keyvault set-policy \
  --name vault-app-keyvault \
  --object-id $IDENTITY_OBJECT_ID \
  --secret-permissions get list

# Use CSI Secret Store driver in AKS to mount Key Vault secrets as files in pods
# (requires the secrets-store-csi-driver addon)
az aks addon enable \
  --resource-group vault-app-production \
  --name vault-k8s-cluster \
  --addon azure-keyvault-secrets-provider
```

---

## Azure Monitor — Metrics and Logs

Azure Monitor is the equivalent of AWS CloudWatch — the built-in monitoring platform.

### Azure Monitor Components

**Metrics**: time-series data from Azure resources (VM CPU, AKS node count, Database connections, etc.)

**Logs (Log Analytics Workspace)**: central log store for all Azure resources, AKS container logs, custom logs.

**Alerts**: fire when metrics or log queries breach thresholds.

**Application Insights**: APM (Application Performance Monitoring) for your applications — request rates, response times, error rates, distributed traces.

```bash
# Create a Log Analytics Workspace
az monitor log-analytics workspace create \
  --resource-group vault-app-production \
  --workspace-name vault-logs \
  --location centralindia \
  --retention-time 30

# Enable AKS monitoring (sends container logs to Log Analytics)
az aks enable-addons \
  --resource-group vault-app-production \
  --name vault-k8s-cluster \
  --addons monitoring \
  --workspace-resource-id /subscriptions/.../resourceGroups/vault-app-production/providers/Microsoft.OperationalInsights/workspaces/vault-logs

# Create a metric alert (CPU > 80%)
az monitor metrics alert create \
  --name "High CPU" \
  --resource-group vault-app-production \
  --scopes /subscriptions/.../resourceGroups/vault-app-production/providers/Microsoft.Compute/virtualMachines/vault-api-vm \
  --condition "avg Percentage CPU > 80" \
  --window-size 5m \
  --evaluation-frequency 1m \
  --action /subscriptions/.../resourceGroups/vault-app-production/providers/microsoft.insights/actiongroups/ops-alerts

# Query Log Analytics (Kusto Query Language - KQL)
az monitor log-analytics query \
  --workspace /subscriptions/.../workspaces/vault-logs \
  --analytics-query "ContainerLog | where TimeGenerated > ago(1h) | where LogEntry contains 'ERROR' | project TimeGenerated, ContainerName, LogEntry | limit 50"
```

### KQL — Kusto Query Language (Azure's log query language)

```kusto
// KQL is Azure Monitor Logs' query language
// It's similar to SQL but designed for time-series log data

// Find errors in the last hour
ContainerLog
| where TimeGenerated > ago(1h)
| where LogEntry contains "ERROR"
| summarize count() by ContainerName, bin(TimeGenerated, 5m)
| render timechart

// Top 10 slowest API endpoints
AzureDiagnostics
| where Category == "ApplicationGatewayAccessLog"
| summarize avg(timeTaken_d) by requestUri_s
| top 10 by avg_timeTaken_d desc
```

---

## Common Misunderstanding: "AKS is just Kubernetes with Azure branding"

**The misunderstanding:** "AKS is just regular Kubernetes. Everything I know from vanilla K8s works the same."

**The reality:** AKS has important Azure-specific integrations:

1. **Azure Load Balancer integration**: `Service type: LoadBalancer` creates an Azure Load Balancer automatically — but with Azure-specific quirks (internal vs external, SKU tiers).

2. **Azure Disk / Azure Files for PVs**: PersistentVolumes use Azure Disk (ZRS or LRS) or Azure Files. Storage classes are different from AWS EBS.

3. **Networking (Azure CNI vs Kubenet)**: Azure CNI gives pods real VNet IPs (each pod needs its own IP in your VNet), requiring more IP planning. Kubenet uses an overlay network.

4. **AAD integration**: RBAC can be integrated with Azure Active Directory — Kubernetes RBAC + Azure RBAC, synced.

5. **Node pool restrictions**: system node pool MUST exist; you can't delete it without first marking another pool as system.

These integrations are powerful but require Azure-specific knowledge on top of Kubernetes knowledge.

→ Continue to: `README.md`
