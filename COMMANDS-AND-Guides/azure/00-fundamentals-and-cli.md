# Azure — Part 00: Fundamentals and Azure CLI

---

## Azure's Organizational Hierarchy

Understanding Azure's structure is critical before anything else:

```
Management Group (optional — for large enterprises)
    │
    ▼
Subscription
    │  (billing boundary, access boundary)
    ▼
Resource Group
    │  (logical grouping of related resources)
    ▼
Resources (VMs, Databases, Storage, etc.)
```

**Management Group**: organize multiple subscriptions (e.g., "Production subscriptions", "Dev subscriptions"). Useful for large enterprises with many subscriptions.

**Subscription**: the billing and access boundary. All resources belong to a subscription. You can have multiple subscriptions for isolation (production vs dev).

**Resource Group**: a logical container for related resources. A resource group for "vault-app-production" might contain: a VM, a PostgreSQL database, a storage account, and a virtual network — all resources related to the production vault application.

All resources in a resource group share a lifecycle — deleting the resource group deletes everything in it. This makes cleanup easy.

**Resource**: any Azure service you create — VMs, databases, networks, storage accounts, etc.

---

## Azure Identity: Azure Active Directory (Entra ID)

Azure uses **Azure Active Directory** (now called Microsoft Entra ID) for identity:

- **Users**: people with accounts in your Azure AD tenant
- **Service Principals**: like IAM service accounts — identities for apps and automation
- **Managed Identity**: like AWS IAM roles — an identity assigned to an Azure resource (VM, AKS pod) that gets tokens automatically, no credentials needed
- **RBAC (Role-Based Access Control)**: assign roles to users/groups/service principals at different scopes (subscription, resource group, or individual resource)

**Azure RBAC built-in roles:**
- `Owner`: full access + can assign roles to others
- `Contributor`: create/manage resources, can't assign roles
- `Reader`: view-only
- Service-specific: `Storage Blob Data Contributor`, `AKS Cluster Admin`, etc.

---

## Installing and Configuring Azure CLI

```bash
# Install on Ubuntu/Debian
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Verify
az --version
# azure-cli 2.x.x

# Login
az login
# Opens browser for interactive login
# Or for service principal login:
az login --service-principal \
  --username <client-id> \
  --password <client-secret> \
  --tenant <tenant-id>

# List subscriptions you have access to
az account list --output table

# Set default subscription
az account set --subscription "My Production Subscription"

# Show current account
az account show
```

---

## Core Azure CLI Patterns

```bash
# Azure CLI follows: az <service> <action> [options]
# Examples:
az vm list
az group create --name myRG --location eastus
az storage account create ...

# Output formats: json (default), table, tsv, yaml
az vm list --output table

# Query with JMESPath (like AWS --query)
az vm list --query "[*].[name, location, provisioningState]" --output table

# All commands support --help
az vm create --help
```

---

## Resource Groups — Managing the Container

```bash
# Create a resource group
az group create \
  --name vault-app-production \
  --location centralindia    # Azure region

# List resource groups
az group list --output table

# List all resources in a group
az resource list --resource-group vault-app-production --output table

# Delete a resource group (DELETES EVERYTHING INSIDE)
az group delete --name vault-app-production --yes --no-wait
# --yes: skip confirmation
# --no-wait: return immediately, deletion continues in background
```

### Azure Regions

```bash
# List all available Azure regions
az account list-locations --output table

# Common regions:
# Central India: centralindia
# South India: southindia
# East US: eastus
# West Europe: westeurope
# Southeast Asia: southeastasia
```

---

## Azure VMs — Virtual Machines

```bash
# Create a VM (Ubuntu)
az vm create \
  --resource-group vault-app-production \
  --name vault-api-vm \
  --image Ubuntu2204 \
  --admin-username azureuser \
  --generate-ssh-keys \
  --size Standard_B2s \
  --vnet-name vault-vnet \
  --subnet app-subnet

# Common VM sizes:
# B-series: burstable, dev/test (B1s: 1vCPU, 1GB; B2s: 2vCPU, 4GB)
# D-series: general purpose (D2s_v3: 2vCPU, 8GB)
# E-series: memory optimized
# F-series: compute optimized

# List VMs
az vm list --resource-group vault-app-production --output table

# Start/stop/restart
az vm start --resource-group vault-app-production --name vault-api-vm
az vm stop --resource-group vault-app-production --name vault-api-vm
az vm restart --resource-group vault-app-production --name vault-api-vm
az vm deallocate --resource-group vault-app-production --name vault-api-vm
# NOTE: 'stop' still charges for the VM! 'deallocate' stops billing for compute.

# Get public IP
az vm show \
  --resource-group vault-app-production \
  --name vault-api-vm \
  --show-details \
  --query publicIps --output tsv

# Open port in NSG (Network Security Group)
az vm open-port \
  --resource-group vault-app-production \
  --name vault-api-vm \
  --port 80

# SSH using generated key
ssh azureuser@<public-ip>

# Run commands on a VM without SSH (via Azure VM extension)
az vm run-command invoke \
  --resource-group vault-app-production \
  --name vault-api-vm \
  --command-id RunShellScript \
  --scripts "apt update && apt install -y nginx"

# Resize a VM
az vm resize \
  --resource-group vault-app-production \
  --name vault-api-vm \
  --size Standard_D2s_v3

# Delete VM
az vm delete \
  --resource-group vault-app-production \
  --name vault-api-vm \
  --yes
```

---

## Azure Storage — Blobs, Files, Tables, Queues

Azure Storage Account is the top-level container for Azure's storage services.

```bash
# Create storage account
az storage account create \
  --name vaultappstorage2026 \
  --resource-group vault-app-production \
  --location centralindia \
  --sku Standard_LRS \
  --kind StorageV2

# Storage SKUs:
# Standard_LRS: locally redundant (3 copies in one datacenter) — cheapest
# Standard_ZRS: zone redundant (across 3 AZs) — recommended
# Standard_GRS: geo-redundant (across 2 regions) — highest durability

# Get storage account key
az storage account keys list \
  --resource-group vault-app-production \
  --account-name vaultappstorage2026 \
  --query "[0].value" --output tsv

# Create a blob container
az storage container create \
  --name uploads \
  --account-name vaultappstorage2026 \
  --public-access off

# Upload blob
az storage blob upload \
  --account-name vaultappstorage2026 \
  --container-name uploads \
  --name profile-photos/user123.jpg \
  --file ./user123.jpg

# List blobs
az storage blob list \
  --account-name vaultappstorage2026 \
  --container-name uploads \
  --output table

# Download blob
az storage blob download \
  --account-name vaultappstorage2026 \
  --container-name uploads \
  --name profile-photos/user123.jpg \
  --file ./downloaded-photo.jpg

# Generate SAS URL (time-limited public access)
az storage blob generate-sas \
  --account-name vaultappstorage2026 \
  --container-name uploads \
  --name profile-photos/user123.jpg \
  --permissions r \
  --expiry 2026-06-18T00:00Z
```

---

## Common Misunderstanding: "Stopping an Azure VM stops billing"

**The misunderstanding:** "I'll stop the VM to save money."

**The reality:** There are two types of "stopped" in Azure:

- `az vm stop` → VM is powered off but still ALLOCATED. The compute resources are reserved for you. **You still pay for the VM.**
- `az vm deallocate` → VM is stopped AND the compute allocation is released. **Billing for compute stops.** But you still pay for managed disks.

The Azure portal's "Stop" button deallocates by default. But `az vm stop` in the CLI does NOT deallocate. Always use `az vm deallocate` in scripts if you want to stop billing.

→ Continue to: `01-aks-and-monitoring.md`
