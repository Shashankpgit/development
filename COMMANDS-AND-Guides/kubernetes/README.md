# Kubernetes — Zero to Hero Guide

## Reading Order

| # | File | What You'll Learn |
|---|------|-------------------|
| 00 | `00-kubernetes-concepts.md` | WHY Kubernetes exists, control plane, nodes, pods, all the objects — start here |
| 01 | `01-kubectl-basics.md` | Every kubectl command you'll use daily, kubeconfig, contexts |
| 02 | `02-pods-and-workloads.md` | Pod YAML, Deployment, StatefulSet, DaemonSet, Job, CronJob, health probes |
| 03 | `03-services-and-networking.md` | ClusterIP, NodePort, LoadBalancer, Ingress, DNS, NetworkPolicy |
| 04 | `04-configmaps-secrets-storage.md` | ConfigMaps, Secrets, PersistentVolumes, PersistentVolumeClaims |
| 05 | `05-deployments-scaling-helm.md` | HPA, PDB, affinity, taints/tolerations, Helm package manager, RBAC |
| 06 | `06-troubleshooting.md` | Systematic debugging: CrashLoopBackOff, Pending, ImagePullBackOff, network issues |

## Quick Reference

| I want to... | Command |
|-------------|---------|
| See all pods | `kubectl get pods -A` |
| Why is a pod failing? | `kubectl describe pod <name>` |
| See app error logs | `kubectl logs <pod> --previous` |
| Open shell in pod | `kubectl exec -it <pod> -- bash` |
| Access a service locally | `kubectl port-forward service/<svc> 8080:80` |
| Deploy a new version | `kubectl set image deployment/<name> <container>=<image>:<tag>` |
| Roll back a deployment | `kubectl rollout undo deployment/<name>` |
| Scale a deployment | `kubectl scale deployment/<name> --replicas=5` |
| Restart all pods | `kubectl rollout restart deployment/<name>` |
| See resource usage | `kubectl top pods` / `kubectl top nodes` |
| Apply YAML | `kubectl apply -f file.yaml` |
