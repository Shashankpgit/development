# Kubernetes — Part 01: kubectl — The Kubernetes CLI

`kubectl` is to Kubernetes what `git` is to version control. Every interaction with your cluster flows through it.

---

## Installation and Setup

```bash
# Install kubectl on Ubuntu/Debian
sudo apt update
sudo apt install -y apt-transport-https ca-certificates curl

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | \
  sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
  https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | \
  sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt update && sudo apt install -y kubectl

# Verify
kubectl version --client
```

### The kubeconfig file

kubectl knows how to connect to your cluster via `~/.kube/config`. This file contains:
- The cluster's API server address
- Your credentials (certificate, token)
- Which cluster/user combination is "current"

```bash
# See your current config
kubectl config view

# See which cluster/context you're pointing at
kubectl config current-context

# List all contexts (if you manage multiple clusters)
kubectl config get-contexts

# Switch to a different cluster
kubectl config use-context production-cluster
kubectl config use-context staging-cluster
```

When you get a new cluster (EKS, GKE, etc.), the cloud CLI sets up your kubeconfig:
```bash
aws eks update-kubeconfig --region ap-south-1 --name my-cluster   # AWS
gcloud container clusters get-credentials my-cluster              # GCP
az aks get-credentials --resource-group myRG --name myCluster     # Azure
```

---

## The Shape of Every kubectl Command

```
kubectl [verb] [resource-type] [resource-name] [flags]
```

| Verb | What it does |
|------|-------------|
| `get` | List resources |
| `describe` | Detailed info about a resource |
| `apply` | Create or update from YAML file |
| `delete` | Delete a resource |
| `exec` | Run a command inside a pod |
| `logs` | View pod logs |
| `port-forward` | Forward a local port to a pod |
| `scale` | Change replica count |
| `rollout` | Manage deployments (status, history, rollback) |
| `top` | Show resource usage |

---

## Getting Information

### Get — List resources

```bash
# Pods
kubectl get pods                          # pods in default namespace
kubectl get pods -n kube-system           # pods in kube-system namespace
kubectl get pods -A                       # pods in ALL namespaces
kubectl get pods -o wide                  # show more columns (node, IP)
kubectl get pods -o yaml                  # full YAML output
kubectl get pods -o json                  # full JSON output
kubectl get pods --watch                  # watch for changes in real time

# Filter by label
kubectl get pods -l app=vault-api
kubectl get pods -l environment=production,app=api

# All resource types
kubectl get deployments
kubectl get services
kubectl get ingress
kubectl get configmaps
kubectl get secrets
kubectl get nodes
kubectl get namespaces
kubectl get persistentvolumes
kubectl get persistentvolumeclaims

# Multiple resource types at once
kubectl get pods,services,deployments
```

### Describe — Detailed information

```bash
kubectl describe pod vault-api-7d4b9c-xyz
kubectl describe deployment vault-api
kubectl describe node worker-node-1
kubectl describe service vault-api-service
```

`describe` is the #1 debugging command. It shows:
- Current status and conditions
- Recent events (what Kubernetes has been trying to do)
- For pods: which containers, their images, their restart count, why they last died

---

## Applying Configuration Files

In Kubernetes, you don't typically create resources by hand — you write YAML files describing what you want and apply them.

```bash
# Create or update whatever is described in the file
kubectl apply -f deployment.yaml

# Apply everything in a directory
kubectl apply -f ./k8s/

# Apply from a URL (be careful!)
kubectl apply -f https://example.com/manifest.yaml

# Delete what's described in a file
kubectl delete -f deployment.yaml

# Dry run — see what would change without doing it
kubectl apply -f deployment.yaml --dry-run=client
kubectl apply -f deployment.yaml --dry-run=server   # validates against server too

# Diff — see what would change
kubectl diff -f deployment.yaml
```

---

## Working With Pods Directly

```bash
# Get a shell inside a running pod
kubectl exec -it vault-api-7d4b9c-xyz -- bash
kubectl exec -it vault-api-7d4b9c-xyz -- sh    # if bash isn't available

# Run a command in a pod
kubectl exec vault-api-7d4b9c-xyz -- cat /etc/config/app.conf
kubectl exec vault-api-7d4b9c-xyz -- env       # print environment variables

# Run a specific container in a multi-container pod
kubectl exec -it vault-api-7d4b9c-xyz -c sidecar-container -- sh

# View pod logs
kubectl logs vault-api-7d4b9c-xyz
kubectl logs -f vault-api-7d4b9c-xyz                # follow (like tail -f)
kubectl logs --tail=100 vault-api-7d4b9c-xyz        # last 100 lines
kubectl logs --since=1h vault-api-7d4b9c-xyz        # last 1 hour
kubectl logs vault-api-7d4b9c-xyz -c sidecar        # specific container

# Previous run logs (crucial when a container keeps crashing)
kubectl logs vault-api-7d4b9c-xyz --previous

# Port forward — access a pod's port on your local machine
kubectl port-forward pod/vault-api-7d4b9c-xyz 8080:3000
# Now: http://localhost:8080 → pod's port 3000
kubectl port-forward service/vault-api-service 8080:80
```

---

## Managing Deployments

```bash
# See deployment status
kubectl get deployment vault-api
kubectl describe deployment vault-api

# Scale up or down
kubectl scale deployment vault-api --replicas=5
kubectl scale deployment vault-api --replicas=1

# Trigger a rolling update (set new image version)
kubectl set image deployment/vault-api vault-api=vault-app:v2.0

# Check rollout status (watch the update progress)
kubectl rollout status deployment/vault-api

# Rollout history (see all versions)
kubectl rollout history deployment/vault-api

# Roll back to previous version
kubectl rollout undo deployment/vault-api

# Roll back to a specific version
kubectl rollout undo deployment/vault-api --to-revision=3

# Restart all pods in a deployment (without changing anything else)
kubectl rollout restart deployment/vault-api
```

---

## Creating Resources Quickly (Imperative Commands)

Sometimes you want to quickly test something without writing YAML:

```bash
# Run a temporary pod (deleted when you exit)
kubectl run test-pod --image=nginx --rm -it --restart=Never -- bash

# Run a curl container to test internal DNS
kubectl run curl-test --image=curlimages/curl --rm -it --restart=Never -- \
  curl http://vault-api-service:80/health

# Create a deployment
kubectl create deployment nginx --image=nginx --replicas=3

# Expose a deployment as a service
kubectl expose deployment nginx --port=80 --target-port=80 --type=ClusterIP

# Generate YAML without creating (useful to get a template)
kubectl create deployment nginx --image=nginx --dry-run=client -o yaml > deployment.yaml
```

---

## Namespace Management

```bash
# Create a namespace
kubectl create namespace monitoring
kubectl create namespace production

# Work within a specific namespace
kubectl get pods -n monitoring
kubectl apply -f grafana.yaml -n monitoring

# Set default namespace for your session (so you don't type -n every time)
kubectl config set-context --current --namespace=production

# Delete a namespace (deletes EVERYTHING inside it — careful!)
kubectl delete namespace old-staging
```

---

## Deleting Resources

```bash
kubectl delete pod vault-api-7d4b9c-xyz        # delete a specific pod
kubectl delete deployment vault-api             # delete deployment (and its pods)
kubectl delete service vault-api-service
kubectl delete -f deployment.yaml               # delete what's defined in a file

# Force delete a stuck pod
kubectl delete pod stuck-pod --grace-period=0 --force

# Delete all pods in a namespace matching a label
kubectl delete pods -l app=vault-api -n production
```

---

## Viewing Resource Usage

```bash
# Requires metrics-server to be installed in the cluster
kubectl top nodes       # CPU and memory per node
kubectl top pods        # CPU and memory per pod
kubectl top pods -n monitoring
kubectl top pods --containers   # per-container breakdown
```

---

## Output Formatting Tips

```bash
# Get just the pod names (for scripting)
kubectl get pods -o name

# Custom columns output
kubectl get pods -o custom-columns='NAME:.metadata.name,STATUS:.status.phase,NODE:.spec.nodeName'

# JSONPath — extract specific field
kubectl get pod vault-api-7d4b9c-xyz -o jsonpath='{.status.podIP}'

# Get all pod IPs
kubectl get pods -o jsonpath='{.items[*].status.podIP}'

# Sort by a field
kubectl get pods --sort-by='.metadata.creationTimestamp'
```

---

## Useful Aliases

Add these to your `~/.bashrc` or `~/.zshrc`:

```bash
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgpa='kubectl get pods -A'
alias kgs='kubectl get services'
alias kgd='kubectl get deployments'
alias kd='kubectl describe'
alias kl='kubectl logs -f'
alias ke='kubectl exec -it'
```

---

## Common Misunderstanding: "kubectl apply and kubectl create are the same"

**The misunderstanding:** "I can use `kubectl create` and `kubectl apply` interchangeably."

**The reality:** They have fundamentally different behaviors:

- `kubectl create`: Creates a resource. Fails with an error if the resource already exists.
- `kubectl apply`: Creates the resource if it doesn't exist, OR updates it if it does. Also stores the applied configuration as an annotation so future diffs work correctly.

**Always use `kubectl apply` in practice.** Here's why:

```bash
# First time: both work
kubectl create -f deployment.yaml    # creates it
kubectl apply -f deployment.yaml     # creates it

# Second time with a change:
kubectl create -f deployment.yaml    # ERROR: "deployment already exists"
kubectl apply -f deployment.yaml     # WORKS: updates the deployment
```

In CI/CD pipelines and real workflows, `kubectl apply` is the standard because it's idempotent — safe to run multiple times.

→ Continue to: `02-pods-and-workloads.md`
