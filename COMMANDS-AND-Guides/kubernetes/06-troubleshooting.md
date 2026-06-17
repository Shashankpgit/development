# Kubernetes — Part 06: Troubleshooting

Kubernetes failures have predictable patterns. This guide gives you a systematic approach and the commands to diagnose every common failure.

---

## The Troubleshooting Mindset

Always work from the outside in:

```
1. Is the pod running?              kubectl get pods
2. Why isn't it running?            kubectl describe pod <name>
3. What are the logs?               kubectl logs <pod>
4. Can it reach other services?     kubectl exec <pod> -- curl <service>
5. Does the service route traffic?  kubectl get endpoints
6. Is there enough capacity?        kubectl describe node / kubectl top
```

---

## Pod Status Reference

When you run `kubectl get pods`, the STATUS column tells the story:

| Status | Meaning | Likely Cause |
|--------|---------|--------------|
| `Running` | Everything good | — |
| `Pending` | Can't be scheduled | No resources, no matching node, PVC pending |
| `CrashLoopBackOff` | App crashes immediately on start | Bug in app, wrong command, missing config |
| `OOMKilled` | Ran out of memory | Memory limit too low, memory leak |
| `ImagePullBackOff` | Can't pull container image | Wrong image name, registry auth failure |
| `ErrImagePull` | Same as above | — |
| `Error` | Container exited with non-zero code | App error |
| `Completed` | Container finished successfully | Normal for Jobs |
| `Terminating` | Being deleted | Stuck finalizer if stays here too long |
| `Init:0/1` | Init container not done | Init container failing or waiting |

---

## Diagnosing CrashLoopBackOff

```bash
# Step 1: See what the pod is doing
kubectl describe pod vault-api-7d4b9c-xyz -n production

# Look at the EVENTS section at the bottom:
# Events:
#   Warning  BackOff  2m   kubelet  Back-off restarting failed container
#   Normal   Pulled   3m   kubelet  Successfully pulled image
#   Warning  Failed   3m   kubelet  Error: failed to start container

# Step 2: Look at the logs of the current (crashing) container
kubectl logs vault-api-7d4b9c-xyz -n production

# Step 3: If it crashed before you could read logs, look at the PREVIOUS run
kubectl logs vault-api-7d4b9c-xyz -n production --previous
# This is the crucial one — the previous container's output before it died

# Common causes and fixes:
# - "Cannot connect to database" → DB not ready, wrong DB URL, wrong secret
# - "Permission denied: /app/data" → volume mounted as wrong user
# - "MODULE_NOT_FOUND" → missing dependency, wrong image
# - Exit code 1 → app error, check logs
# - Exit code 137 → OOMKilled (memory limit exceeded)
# - Exit code 139 → segmentation fault
```

---

## Diagnosing Pending Pods

```bash
kubectl describe pod vault-api-7d4b9c-xyz -n production
# Look at Events:
# Warning  FailedScheduling  0/3 nodes available:
#   1 node has insufficient cpu
#   2 node(s) had taint {node.kubernetes.io/not-ready}, that pod didn't tolerate
```

**Common causes of Pending:**

```bash
# 1. Not enough resources
kubectl describe nodes | grep -A 5 "Allocated resources"
kubectl top nodes

# 2. PVC not bound
kubectl get pvc -n production
# If STATUS is Pending, no PV matches the claim
kubectl describe pvc postgres-data -n production

# 3. Node selector / affinity not matching
kubectl get nodes --show-labels
# Compare with pod's nodeSelector or affinity rules

# 4. All nodes have a taint the pod doesn't tolerate
kubectl describe node worker-1 | grep Taints
```

---

## Diagnosing ImagePullBackOff

```bash
kubectl describe pod failing-pod | grep -A 10 Events
# Events:
#   Warning  Failed  30s  kubelet  Failed to pull image "vault-app:v99"
#             reason: rpc error: code = Unknown desc = Error response from daemon:
#             manifest for vault-app:v99 not found
```

**Common causes:**

```bash
# 1. Image doesn't exist — check the name and tag
# kubectl get deployment vault-api -o yaml | grep image

# 2. Private registry — needs an imagePullSecret
# Create the pull secret:
kubectl create secret docker-registry ecr-secret \
  --docker-server=123456.dkr.ecr.ap-south-1.amazonaws.com \
  --docker-username=AWS \
  --docker-password=$(aws ecr get-login-password)

# Reference in pod spec:
spec:
  imagePullSecrets:
    - name: ecr-secret
  containers:
    - image: 123456.dkr.ecr.ap-south-1.amazonaws.com/vault-app:v1.0
```

---

## Diagnosing Service/Network Issues

```bash
# "My app can't connect to the database"

# Step 1: Does the Service have Endpoints?
kubectl get endpoints postgres-service -n production
# NAME              ENDPOINTS         AGE
# postgres-service  10.0.1.5:5432     2h    ← good, pods are found
# postgres-service  <none>            2h    ← bad, no pods match selector

# Step 2: If no endpoints, check selector vs pod labels
kubectl get service postgres-service -n production -o yaml | grep selector
kubectl get pods -n production --show-labels | grep postgres
# The selector key:value must match pod labels exactly

# Step 3: Test DNS from inside a pod
kubectl run debug --image=busybox --rm -it --restart=Never -- sh
# Inside: nslookup postgres-service.production.svc.cluster.local
# Inside: wget -qO- http://vault-api-service/health

# Step 4: Port forward to test a service directly
kubectl port-forward service/vault-api-service 8080:80 -n production
# Then test locally: curl http://localhost:8080/health
```

---

## Diagnosing Node Issues

```bash
# See node status
kubectl get nodes
# NAME          STATUS     ROLES    AGE
# worker-1      Ready      <none>   10d
# worker-2      NotReady   <none>   10d    ← problem here

# Detailed node info
kubectl describe node worker-2
# Look at: Conditions section and Events section

# Conditions:
#   Type          Status  Reason
#   MemoryPressure  False
#   DiskPressure    False
#   PIDPressure     False
#   Ready           True    KubeletReady

# Check node resource usage
kubectl top nodes
# If a node is at 95%+ CPU or memory, pods get evicted
```

---

## Diagnosing Ingress Issues

```bash
# Check Ingress status
kubectl get ingress -n production -o wide
# NAME           CLASS   HOSTS              ADDRESS          PORTS
# vault-ingress  nginx   vault.example.com  34.100.200.50    80, 443

# Describe for events and annotations
kubectl describe ingress vault-ingress -n production

# Check if Ingress controller is running
kubectl get pods -n ingress-nginx
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller

# Test: does the Ingress controller reach the Service?
kubectl port-forward -n ingress-nginx service/ingress-nginx-controller 8080:80
# curl -H "Host: vault.example.com" http://localhost:8080/health
```

---

## The Master Debugging Command Sequence

When something is broken and you don't know where to start:

```bash
#!/bin/bash
# Quick cluster health check
NAMESPACE=${1:-default}

echo "=== Pods ==="
kubectl get pods -n $NAMESPACE

echo "=== Recent Events (warnings only) ==="
kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp' \
  | grep -i warning | tail -20

echo "=== Failing Pods Details ==="
kubectl get pods -n $NAMESPACE | grep -v Running | grep -v Completed | \
  awk '{print $1}' | tail -n +2 | \
  xargs -I{} kubectl describe pod {} -n $NAMESPACE

echo "=== Node Resources ==="
kubectl top nodes
```

---

## Common kubectl Debug Commands Cheatsheet

```bash
# Get events sorted by time (most recent last)
kubectl get events -n production --sort-by='.lastTimestamp'

# Watch all pods change in real time
kubectl get pods -n production --watch

# Get everything in a namespace at once
kubectl get all -n production

# Describe all failing pods
kubectl get pods -n production | grep -v Running | grep -v Completed

# Shell into a pod for investigation
kubectl exec -it vault-api-7d4b9c-xyz -n production -- bash

# Run temporary debug container in the pod's network namespace
kubectl debug -it vault-api-7d4b9c-xyz --image=busybox --target=vault-api

# Copy files from a pod for analysis
kubectl cp production/vault-api-7d4b9c-xyz:/app/logs/error.log ./error.log

# Watch HPA scaling decisions
kubectl describe hpa vault-api-hpa -n production

# Show what changed in a deployment's rollout
kubectl rollout history deployment/vault-api -n production
kubectl rollout history deployment/vault-api --revision=3 -n production
```

---

## Common Misunderstanding: "kubectl describe shows the problem"

**The misunderstanding:** "If I run `kubectl describe pod`, I'll see the error message."

**The reality:** `describe` shows the pod's metadata and events — it tells you WHAT happened (started, failed, back-off). The actual error (the exception stack trace, the "connection refused" message) is only in `kubectl logs`. You need BOTH:

- `kubectl describe`: WHY kubernetes is reacting (OOMKilled, image not found, no nodes available)
- `kubectl logs --previous`: WHAT the app itself printed before it died

When a pod is in CrashLoopBackOff, always check `kubectl logs --previous` — without `--previous`, you get the logs of the current (short-lived) attempt, which may be empty. The previous run's logs are usually where the actual error message lives.
