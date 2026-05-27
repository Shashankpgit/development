# Phase 10 — K8s Concepts + Minikube Setup

## What we are doing

Pure concepts and tooling setup. No application deployment. By the end of this phase:
- Every K8s object we'll use in Phase 13 is understood
- minikube is running on the local machine
- kubectl is configured and working
- A practice pod has been run to make kubectl feel familiar

## Why now

We have Docker images to deploy (Phase 11) and Helm charts to write (Phase 12). Before either of those, we need to understand what Kubernetes actually is and what the objects we'll be writing mean. Writing YAML without understanding it is copy-paste engineering — we don't do that.

## What is NOT in scope

- No vault app deployment (Phase 13)
- No Helm (Phase 12)
- No GHCR (Phase 11)
- No TLS, no cert-manager (Phase 15)

## Concepts to cover

1. Why K8s exists (vs docker-compose)
2. Architecture: control plane + worker nodes
3. Core objects: Namespace, Pod, Deployment, Service
4. Config objects: ConfigMap, Secret
5. Storage: PV, PVC, StatefulSet
6. Traffic: Ingress, Ingress Controller

## Tools to install

- minikube
- kubectl
- Enable ingress addon

## Files

| File | Action |
|---|---|
| `docs/plans/018-k8s-concepts-plan.md` | This file |
| None | No code changes — concepts phase |
