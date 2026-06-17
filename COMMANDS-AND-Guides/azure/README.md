# Azure — Zero to Hero Command Guide

## Reading Order

| # | File | What You'll Learn |
|---|------|-------------------|
| 00 | `00-fundamentals-and-cli.md` | Subscription/ResourceGroup/Resource hierarchy, Azure CLI setup, VMs, Storage accounts |
| 01 | `01-aks-databases-monitoring.md` | AKS Kubernetes, Workload Identity, PostgreSQL, Key Vault, Azure Monitor |

## Key Concepts

- **Resource Groups**: logical containers — delete the group to delete everything inside
- **Deallocate vs Stop**: `az vm stop` still charges you; `az vm deallocate` stops billing
- **Managed Identity**: Azure's version of IAM roles — no credentials in code or config
- **Key Vault**: where secrets live in production (not Kubernetes Secrets)
- **AKS Workload Identity**: pods get Azure credentials without any secrets

## Quick Reference

```bash
# Login
az login
az account set --subscription "My Sub"

# Resource Groups
az group create --name myRG --location centralindia
az group list --output table

# VMs
az vm list --output table
az vm start/stop/deallocate --resource-group myRG --name myVM

# AKS
az aks create --resource-group myRG --name myCluster --node-count 3
az aks get-credentials --resource-group myRG --name myCluster

# Storage
az storage account create --name mystorageacct --resource-group myRG
az storage blob upload --account-name mystorageacct --container-name mycontainer --name file.txt --file file.txt

# Key Vault
az keyvault secret set --vault-name myvault --name mysecret --value myvalue
az keyvault secret show --vault-name myvault --name mysecret --query value
```

## Azure vs AWS Equivalent Concepts

| AWS | Azure |
|-----|-------|
| IAM Role | Managed Identity |
| EC2 | Virtual Machine |
| S3 | Blob Storage |
| VPC | Virtual Network (VNet) |
| Security Group | Network Security Group (NSG) |
| EKS | AKS |
| RDS | Azure Database (Flexible Server) |
| Secrets Manager | Key Vault |
| CloudWatch | Azure Monitor + Log Analytics |
| ELB | Azure Load Balancer / Application Gateway |
