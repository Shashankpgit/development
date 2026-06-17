# Helm — Part 01: CLI Basics — Install, Upgrade, Rollback, Debug

**20-minute read. The commands you'll run every day managing Helm releases.**

---

## Installing Helm

```bash
# Linux (recommended)
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# macOS
brew install helm

# Verify
helm version
# version.BuildInfo{Version:"v3.14.0", GitCommit:"..."}
```

Helm uses your current `kubectl` context — whatever cluster `kubectl` points to, Helm operates on.

```bash
# Check which context Helm is using
kubectl config current-context

# Change context
kubectl config use-context production-cluster
```

---

## helm install — Deploy a Chart as a Release

```bash
helm install <release-name> <chart>

# From a local chart directory
helm install vault-app ./vault-app/

# From a repo (covered in file 04)
helm install vault-app sanketika/vault-app

# Install into a specific namespace (creates namespace if it doesn't exist)
helm install vault-app ./vault-app/ \
  --namespace production \
  --create-namespace

# Override values at install time
helm install vault-app ./vault-app/ \
  --namespace production \
  --create-namespace \
  --set image.tag=v1.2.3 \
  --set replicaCount=3

# Override with a values file
helm install vault-app ./vault-app/ \
  --values values.production.yaml

# Both (values file first, --set overrides win)
helm install vault-app ./vault-app/ \
  --values values.production.yaml \
  --set image.tag=v1.2.3          # this wins over image.tag in the values file

# Wait until all pods are ready before returning
helm install vault-app ./vault-app/ \
  --namespace production \
  --wait \
  --timeout 5m

# Dry run — show what would be deployed without actually deploying
helm install vault-app ./vault-app/ \
  --dry-run \
  --debug                         # also prints the rendered templates
```

**What `--wait` does:** Helm waits until all Deployments, StatefulSets, and Jobs created by the chart reach a ready state. Without `--wait`, the command returns immediately after resources are submitted to the API server — even if pods are still Pending or in CrashLoopBackOff.

---

## helm upgrade — Update a Running Release

```bash
# Upgrade to a new chart version or new values
helm upgrade vault-app ./vault-app/ \
  --namespace production \
  --set image.tag=v1.3.0

# Install if not exists, upgrade if already installed (idempotent — great for CI/CD)
helm upgrade --install vault-app ./vault-app/ \
  --namespace production \
  --create-namespace \
  --set image.tag=v1.3.0

# Upgrade with values file
helm upgrade vault-app ./vault-app/ \
  --namespace production \
  --values values.production.yaml \
  --set image.tag=v1.3.0

# --atomic: if upgrade fails, auto rollback to previous revision
helm upgrade vault-app ./vault-app/ \
  --namespace production \
  --atomic \
  --timeout 10m

# --cleanup-on-fail: delete new resources created during upgrade if it fails
# (useful when upgrade adds new resources that conflict if rollback is manual)
helm upgrade vault-app ./vault-app/ \
  --namespace production \
  --cleanup-on-fail \
  --atomic

# Reuse values from previous release (don't need to pass --values again)
helm upgrade vault-app ./vault-app/ \
  --namespace production \
  --reuse-values \
  --set image.tag=v1.4.0     # only override the tag, keep all other previous values
```

`--atomic` is the most important flag for production upgrades. If the rollout fails (pods don't become ready within the timeout), Helm automatically rolls back to the previous revision. Use this in CI/CD pipelines.

---

## helm list — See All Releases

```bash
# List releases in current namespace
helm list

# List in specific namespace
helm list --namespace production

# List across ALL namespaces
helm list --all-namespaces
helm list -A               # short form

# Output format
helm list -A --output table    # default
helm list -A --output json
helm list -A --output yaml

# Show failed releases (hidden by default)
helm list --all
helm list -a

# Filter by name
helm list --filter vault
```

Example output:
```
NAME           NAMESPACE    REVISION  UPDATED              STATUS    CHART             APP VERSION
vault-app      production   5         2026-06-15 10:30:00  deployed  vault-app-1.4.2   2.1.0
postgres       production   2         2026-05-01 09:00:00  deployed  postgresql-13.4.0  16.1.0
vault-app      staging      3         2026-06-15 09:45:00  deployed  vault-app-1.4.2   2.1.0
```

Columns:
- `REVISION` — how many times this release has been installed/upgraded
- `STATUS` — `deployed` (healthy), `failed` (last operation failed), `pending-upgrade`, `superseded` (in history only)

---

## helm status — Inspect a Release

```bash
helm status vault-app --namespace production

# Example output:
# NAME: vault-app
# LAST DEPLOYED: Mon Jun 15 10:30:00 2026
# NAMESPACE: production
# STATUS: deployed
# REVISION: 5
# NOTES:
# Application successfully deployed.
# Access via: https://vault.example.com
```

Shows the NOTES.txt content from the chart — typically contains access URLs and post-install instructions.

---

## helm history — View Release History

```bash
helm history vault-app --namespace production

# REVISION  UPDATED                  STATUS      CHART            APP VERSION  DESCRIPTION
# 1         Mon Jan 01 10:00:00 2026  superseded  vault-app-1.0.0  1.0.0       Install complete
# 2         Mon Feb 01 10:00:00 2026  superseded  vault-app-1.1.0  1.1.0       Upgrade complete
# 3         Mon Mar 01 10:00:00 2026  superseded  vault-app-1.2.0  1.2.0       Upgrade complete
# 4         Mon Apr 01 10:00:00 2026  superseded  vault-app-1.3.0  2.0.0       Upgrade complete
# 5         Mon Jun 15 10:30:00 2026  deployed    vault-app-1.4.2  2.1.0       Upgrade complete

# Limit history shown
helm history vault-app -n production --max 5
```

Helm stores up to 10 revisions by default. Configure with `--history-max` flag on install/upgrade:
```bash
helm upgrade vault-app ./vault-app/ --history-max 20
```

---

## helm rollback — Revert to a Previous Revision

```bash
# Rollback to previous revision (current - 1)
helm rollback vault-app --namespace production

# Rollback to a specific revision
helm rollback vault-app 3 --namespace production

# Wait until rollback completes
helm rollback vault-app 3 --namespace production --wait

# Check history after rollback
helm history vault-app -n production
# REVISION  STATUS      DESCRIPTION
# 1         superseded  Install complete
# 2         superseded  Upgrade complete
# 3         superseded  Upgrade complete
# 4         superseded  Upgrade complete  ← what we rolled back FROM
# 5         superseded  Upgrade complete
# 6         deployed    Rollback to 3    ← rollback creates a new revision
```

Rollback **always creates a new revision** — it doesn't rewind history. This preserves the audit trail.

---

## helm uninstall — Remove a Release

```bash
# Delete the release (removes all Kubernetes resources)
helm uninstall vault-app --namespace production

# Keep release history (allows rollback even after uninstall)
helm uninstall vault-app --namespace production --keep-history

# Dry run
helm uninstall vault-app --dry-run
```

After uninstall without `--keep-history`, all traces of the release are gone (resources + history Secrets).

---

## helm get — Inspect What's Deployed

```bash
# Get the values used for the deployed release (your overrides only)
helm get values vault-app --namespace production

# Get ALL values (defaults + overrides merged)
helm get values vault-app --namespace production --all

# Get the rendered manifest (what was actually sent to Kubernetes)
helm get manifest vault-app --namespace production

# Get the NOTES output
helm get notes vault-app --namespace production

# Get everything at once
helm get all vault-app --namespace production

# Inspect a specific revision
helm get values vault-app --namespace production --revision 3
helm get manifest vault-app --namespace production --revision 3
```

`helm get values` is extremely useful for debugging: "what values is the currently running release using?"

---

## helm template — Render Locally Without Deploying

```bash
# Render all templates and print to stdout
helm template vault-app ./vault-app/ \
  --values values.production.yaml \
  --set image.tag=v1.2.3

# Render a specific template file only
helm template vault-app ./vault-app/ \
  --show-only templates/deployment.yaml

# Render and pipe to kubectl (useful for reviewing before applying)
helm template vault-app ./vault-app/ \
  --values values.production.yaml | kubectl apply --dry-run=client -f -

# Validate against cluster API (needs a running cluster)
helm template vault-app ./vault-app/ \
  --values values.production.yaml \
  --validate
```

Use `helm template` for:
- Reviewing what Helm will actually apply (before installing/upgrading)
- Storing rendered manifests in git for GitOps workflows
- Debugging template errors without touching the cluster

---

## helm diff — Preview Changes Before Upgrading

`helm diff` is a plugin that shows what would change before you run `helm upgrade`. Install it once:

```bash
helm plugin install https://github.com/databus23/helm-diff
```

```bash
# Show diff between current deployed and what upgrade would apply
helm diff upgrade vault-app ./vault-app/ \
  --namespace production \
  --values values.production.yaml \
  --set image.tag=v1.3.0

# Output looks like git diff:
# deployment.yaml:
#   image: ghcr.io/sanketika/vault-app:v1.2.3
# + image: ghcr.io/sanketika/vault-app:v1.3.0

# Show diff between two revisions
helm diff revision vault-app 4 5 --namespace production
```

In a production workflow: always run `helm diff` before `helm upgrade` to sanity-check what's changing.

---

## helm lint — Validate a Chart

```bash
# Lint the chart (checks for YAML errors and Helm best practices)
helm lint ./vault-app/

# Lint with specific values
helm lint ./vault-app/ --values values.production.yaml

# Strict mode (warnings become errors)
helm lint ./vault-app/ --strict

# Example output:
# ==> Linting ./vault-app/
# [INFO] Chart.yaml: icon is recommended
# [WARNING] templates/deployment.yaml: container "vault-api" does not have a security context
# 1 chart(s) linted, 0 chart(s) failed
```

---

## Real-World Scenario: Safe Production Upgrade Workflow

```bash
# 1. Review what changes will be made
helm diff upgrade vault-app ./vault-app/ \
  --namespace production \
  --values values.production.yaml \
  --set image.tag=v2.0.0

# 2. Review looks good — do the upgrade
helm upgrade vault-app ./vault-app/ \
  --namespace production \
  --values values.production.yaml \
  --set image.tag=v2.0.0 \
  --atomic \          # auto-rollback if pods don't become ready
  --timeout 10m \     # give it 10 minutes
  --wait              # block until complete

# 3. Verify
helm status vault-app --namespace production
kubectl get pods --namespace production

# 4. If something's wrong, rollback immediately
helm rollback vault-app --namespace production --wait

# 5. Inspect what happened
helm history vault-app --namespace production
```

---

## Common Misunderstanding: "helm upgrade always applies all resources"

**The misunderstanding:** "Every `helm upgrade` re-applies every resource in the chart."

**The reality:** Helm sends **all** rendered resources to the Kubernetes API server on every upgrade. But Kubernetes itself uses server-side apply — if a resource hasn't changed, the API server does a no-op for that resource (no restart, no disruption).

However, Helm does NOT detect resources you manually deleted between upgrades. If you `kubectl delete deployment vault-api` and then run `helm upgrade`, Helm will recreate the deployment. This can look like "helm fixed it" but what actually happened is Helm submitted the resource and Kubernetes created it because it didn't exist.

The implication: **don't manually modify Helm-managed resources with kubectl**. If you change an annotation with `kubectl edit`, Helm will overwrite your change on the next `helm upgrade`. All changes must go through values or chart templates.

→ Continue to: `02-chart-structure.md`
