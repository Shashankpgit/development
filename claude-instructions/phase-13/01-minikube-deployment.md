# Phase 13 — Deploy to Minikube (Local, HTTP)

## What this phase covers

Deploy the full vault stack to local minikube using the Helm charts from Phase 12. Expose it via the nginx Ingress controller. Verify the complete flow: browser → Ingress → Kong → API → PostgreSQL, with Keycloak auth.

No TLS, no cert-manager. HTTP only. This is local validation before GKE.

---

## Pre-step checklist

- [ ] Create `docs/plans/021-minikube-deployment-plan.md` first
- [ ] Phase 12 complete: Helm charts written and linted
- [ ] minikube running with ingress addon enabled

---

## Why HTTP is fine here

On production (Phase 15), HTTPS is mandatory — tokens travel over the network, encryption is required.

On local minikube, all traffic stays on your own machine (loopback). Nothing leaves your laptop. HTTP is fine for local development and testing.

cert-manager (the tool that handles Let's Encrypt in K8s) is only needed when you have a real domain pointing to a real server. `minikube.local` isn't a real domain — Let's Encrypt can't issue a cert for it.

---

## What changes from docker-compose

| docker-compose | minikube |
|---|---|
| `http://localhost` | `http://$(minikube ip)` or `http://vault.local` (via /etc/hosts) |
| nginx container handles routing | Ingress Controller handles routing |
| certbot handles TLS | no TLS locally |
| `KC_HOSTNAME: localhost` | `KC_HOSTNAME: vault.local` |
| `.env` files | K8s Secrets + Helm `--set` |
| `docker compose up` | `helm upgrade --install vault helm/vault/` |

---

## Step 1 — Prepare the cluster

```bash
# Start minikube if not running
minikube start --driver=docker

# Enable ingress controller
minikube addons enable ingress

# Verify ingress controller is running
kubectl get pods -n ingress-nginx
# → ingress-nginx-controller-xxx   Running

# Create namespace
kubectl create namespace vault
```

---

## Step 2 — Create Secrets

Secrets are created directly with kubectl — NOT in values.yaml or git:

```bash
# App secrets
kubectl create secret generic vault-secrets \
  --from-literal=databaseUrl="postgresql://vault:strongpassword@postgresql:5432/vault" \
  --from-literal=vaultEncryptionKey="your-fernet-key" \
  -n vault

# Registry pull secret (if images are private)
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=YOUR_GITHUB_USERNAME \
  --docker-password=YOUR_PAT \
  -n vault
```

---

## Step 3 — Create ConfigMaps from files

```bash
# Keycloak realm import
kubectl create configmap keycloak-realm \
  --from-file=realm-export.json=vault/keycloak/realm-export.json \
  -n vault

# Kong declarative config
kubectl create configmap kong-config \
  --from-file=kong.yml=vault/kong/kong.yml \
  -n vault
```

---

## Step 4 — Write the Ingress resource

`helm/vault/templates/ingress.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: vault
  namespace: vault
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$2
spec:
  ingressClassName: nginx
  rules:
    - host: vault.local
      http:
        paths:
          - path: /api(/|$)(.*)
            pathType: ImplementationSpecific
            backend:
              service:
                name: kong-proxy
                port:
                  number: 8000
          - path: /realms(/|$)(.*)
            pathType: ImplementationSpecific
            backend:
              service:
                name: keycloak
                port:
                  number: 8080
          - path: /resources(/|$)(.*)
            pathType: ImplementationSpecific
            backend:
              service:
                name: keycloak
                port:
                  number: 8080
          - path: /
            pathType: Prefix
            backend:
              service:
                name: vault-frontend
                port:
                  number: 80
```

Add to `/etc/hosts` on your local machine:
```bash
echo "$(minikube ip) vault.local" | sudo tee -a /etc/hosts
```

---

## Step 5 — Deploy

```bash
# Download subchart dependencies
helm dependency update helm/vault/

# Deploy
helm upgrade --install vault helm/vault/ \
  --namespace vault \
  --values helm/vault/values.yaml \
  --set postgresql.auth.password=strongpassword \
  --set keycloak.auth.adminPassword=strongpassword \
  --set "vault-api.config.keycloakUrl=http://vault.local"

# Watch pods come up
kubectl get pods -n vault -w
```

Expected pod list:
```
NAME                              READY   STATUS
vault-api-xxx                     1/1     Running
vault-frontend-xxx                1/1     Running
postgresql-0                      1/1     Running    ← StatefulSet
vault-keycloak-xxx                1/1     Running
vault-kong-xxx                    1/1     Running
```

Keycloak takes 60-90 seconds to be ready. Be patient.

---

## Step 6 — Verify end-to-end

```bash
# Health check via Ingress
curl http://vault.local/api/health
# → {"status":"ok","database":"ok"}

# Open browser
# http://vault.local → Keycloak login page (custom dark theme)
# Register → Login → Create note → Delete note
```

---

## Troubleshooting commands

```bash
# Pod not starting
kubectl describe pod <name> -n vault    # check Events section at bottom

# App crashing
kubectl logs <pod> -n vault
kubectl logs <pod> -n vault --previous  # logs from previous crashed container

# Ingress not routing
kubectl describe ingress vault -n vault

# Service not reachable
kubectl get endpoints -n vault          # shows actual pod IPs behind each service

# Get a shell inside a pod
kubectl exec -it <pod> -n vault -- sh
```

---

## Deliberate mistake for this step

**Mistake**: Set `KC_HOSTNAME: localhost` in Keycloak values (same as docker-compose) instead of `vault.local`.

Symptom: Login page loads, but after successful login Keycloak redirects to `localhost/...` instead of `vault.local/...`. Browser hits nothing.

**Lesson**: Keycloak embeds the hostname in every redirect URL and JWT `iss` claim. `KC_HOSTNAME` must exactly match how users and Kong reach the app. In minikube it's `vault.local`, in production it'll be the real domain.

---

## Success criteria

```bash
kubectl get pods -n vault
# → all pods Running

curl http://vault.local/api/health
# → {"status":"ok","database":"ok"}

# In browser: http://vault.local
# → Keycloak login page loads with dark theme
# → Can register, login, create note, delete note
# → Logout works

helm list -n vault
# → vault   deployed
```

Full app running in local Kubernetes. Ready for Phase 14: CI/CD.
