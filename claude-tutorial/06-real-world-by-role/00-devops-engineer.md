# Claude Mastery — 15: Claude for DevOps Engineers

> **Last updated:** June 17, 2026
> **Covers:** Infrastructure, Kubernetes, CI/CD, monitoring, incident response — all with Claude

**20-minute read. The patterns a DevOps engineer reaches for every day.**

---

## Your Claude Code Setup for DevOps

### CLAUDE.md (project root)
```markdown
# Infrastructure Project — CLAUDE.md

## Environment
- AWS EKS (ap-south-1), cluster: vault-cluster
- Kubernetes 1.29, namespaces: staging / production / monitoring
- Helm v3, charts in ./helm/
- Terraform in ./terraform/, state in S3
- CI/CD: GitHub Actions

## Key Commands
\`\`\`bash
# K8s
kubectl get pods -n production
kubectl logs -n production deployment/vault-api -f
kubectl rollout status -n production deployment/vault-api

# Helm
helm diff upgrade vault-app ./helm/vault-app/ -n production --values helm/values.production.yaml
helm upgrade vault-app ./helm/vault-app/ -n production --values helm/values.production.yaml --atomic

# Terraform  
terraform plan -var-file=production.tfvars
terraform apply -var-file=production.tfvars
\`\`\`

## Conventions
- Never deploy to production without helm diff review first
- All Terraform changes need plan approval before apply
- kubectl delete commands require explicit confirmation
- Rollbacks via: helm rollback vault-app -n production
```

### Settings (.claude/settings.json)
```json
{
  "permissions": {
    "allow": [
      "Bash(kubectl get *)", "Bash(kubectl describe *)",
      "Bash(kubectl logs *)", "Bash(kubectl rollout status *)",
      "Bash(helm diff *)", "Bash(helm status *)", "Bash(helm history *)",
      "Bash(terraform plan *)", "Bash(terraform validate)",
      "Bash(git *)", "Bash(aws * --dry-run)", "Read(*)"
    ],
    "deny": [
      "Bash(kubectl delete *)", "Bash(kubectl exec *)",
      "Bash(helm upgrade *)", "Bash(helm install *)", "Bash(helm uninstall *)",
      "Bash(terraform apply *)", "Bash(terraform destroy *)",
      "Bash(git push --force *)"
    ]
  }
}
```

### Skills (.claude/commands/)
```
deploy-staging.md       → /deploy-staging
deploy-production.md    → /deploy-production
rollback.md             → /rollback
incident-response.md    → /incident-response
health-check.md         → /health-check
cost-estimate.md        → /cost-estimate
```

---

## Day-to-Day DevOps Workflows

### Diagnosing Production Issues

```
> Pods in production are in CrashLoopBackOff. Diagnose and fix.

Claude:
1. kubectl get pods -n production     [identifies which pods]
2. kubectl logs pod-name -n production  [reads logs]
3. kubectl describe pod pod-name -n production  [checks events]
4. Reads the Dockerfile, deployment.yaml
5. Identifies root cause
6. Suggests fix
7. Implements fix (with your approval)
8. Redeployes and verifies
```

```
> "The API response times jumped from 50ms to 2 seconds at 3pm. 
   What changed and what's causing it?"

Claude:
1. git log --since="3pm" --until="4pm"  [what deployed around that time?]
2. kubectl get events -n production --sort-by=.lastTimestamp
3. kubectl top pods -n production  [resource usage spike?]
4. Reads recent Helm changes
5. Checks if DB queries changed (if postgres MCP available)
6. Reports: "The slow queries started after revision 12 was deployed — 
   that added a missing database index removal in migration 019"
```

### Helm Operations

```
> "Deploy v1.3.0 to production — show me the diff first"

Claude:
1. helm diff upgrade vault-app ./helm/vault-app/ \
   -n production --values helm/values.production.yaml \
   --set image.tag=v1.3.0
2. Shows you the diff
3. Waits for your go-ahead
4. helm upgrade ... --atomic --timeout 10m
5. kubectl rollout status ...
6. curl health endpoint
7. Reports result
```

```
> "The last deploy broke something — roll back immediately"

Claude:
1. helm history vault-app -n production  [finds previous revision]
2. helm rollback vault-app -n production --wait  [rolls back]
3. kubectl rollout status ...
4. Verifies health
5. Reports: "Rolled back from revision 8 to revision 7. Health check passing."
```

### Terraform Operations

```
> "We need to add a new RDS read replica. Write the Terraform and show me the plan."

Claude:
1. Reads existing terraform/rds.tf
2. Writes the new resource block for the read replica
3. terraform validate  [checks syntax]
4. terraform plan -var-file=production.tfvars  [shows what will change]
5. Shows you the plan — waits for approval
6. (With your approval) terraform apply
```

### Writing Infrastructure as Code

```
> "Write a Helm chart for the vault-worker service. 
   It's similar to vault-api but has no ingress and needs a 
   Kubernetes CronJob, not a Deployment."

Claude reads vault-api chart as reference, creates vault-worker chart 
with appropriate modifications. Asks clarifying questions if needed.
```

---

## Monitoring and Alerting with Claude

```
> "The CPU alert fired for vault-api. It's at 95%. 
   Should I scale up or is something else wrong?"

Claude:
1. kubectl top pods -n production -l app=vault-api  [current usage]
2. kubectl describe hpa vault-api-hpa -n production  [HPA status]
3. kubectl get pods -n production -l app=vault-api   [how many pods?]
4. kubectl logs -n production deployment/vault-api --tail=50  [recent logs]
5. Analyzes: "HPA is at max replicas (5). CPU usage is sustained, 
   not a spike. Recent logs show increased request volume. 
   Consider: 1) increase HPA max, 2) optimize the CPU-intensive endpoint 
   (POST /api/encrypt shows 400ms p99), 3) add more nodes."
```

```
> "Write a Prometheus alert for when deployment rollout fails"

Claude writes the PrometheusRule YAML:
- Watches kube_deployment_status_replicas_unavailable
- Fires after 5 minutes of unavailable replicas
- With appropriate labels and annotations for Alertmanager routing
```

---

## CI/CD Pipeline Development

```
> "Write a GitHub Actions workflow that builds Docker image, 
   pushes to ECR, and deploys to EKS using OIDC (no stored credentials)"

Claude:
1. Reads existing workflows for patterns
2. Reads CLAUDE.md for ECR registry URL, cluster name, region
3. Writes a complete workflow with:
   - OIDC permissions
   - Docker buildx with GHA cache
   - ECR push
   - EKS kubeconfig
   - Helm upgrade --atomic
   - Slack notification (if Slack MCP is available)
```

---

## Cost Analysis

```
> "We're over AWS budget this month. Find what's costing the most 
   and where we can cut."

Claude:
1. Reads terraform/ to understand all resources
2. Runs aws cost analysis commands (if configured)
3. Identifies: "3 NAT Gateways in different AZs = $120/month. 
   Could consolidate to 1 for non-HA environments.
   Also: 2 idle EC2 instances tagged 'test' running since March."
```

---

## Security and Compliance

```
> "Audit our Kubernetes manifests for security issues"

Claude spawns agents to check:
- Pods running as root
- Missing resource limits
- Containers with privileged: true
- Missing network policies
- Secrets in environment variables (vs mounted secrets)
- Missing pod security standards

Returns prioritized list with fixes.
```

---

## The DevOps MCP Stack

For maximum DevOps power, configure these:

```json
{
  "mcpServers": {
    "github": { ... },     // Create issues, PRs, manage code
    "slack": { ... },      // Notify teams, read incident channels
    "postgres": { ... }    // Query dev/staging databases directly
  }
}
```

With this stack:
```
> "Incident: users can't create accounts. Diagnose, fix, and handle comms."

Claude:
1. [Postgres] SELECT errors from recent signups
2. Reads auth code based on DB findings
3. Identifies: migration 023 dropped a required column
4. Writes rollback migration
5. [Slack] Posts to #incidents: "Investigating signup failures"
6. Applies the rollback (with your approval)
7. Verifies users can signup
8. [Slack] Updates #incidents: "Resolved — migration rollback applied"
9. [GitHub] Creates issue with full timeline for post-mortem
```

---

## Common Misunderstanding: "Claude can't handle production — too risky"

**The misunderstanding:** "I'll only use Claude for development work. Production is too risky."

**The reality:** Claude is as risky as you configure it. With the settings above:
- Claude can INSPECT production freely (kubectl get, helm status, logs)
- Claude ASKS before CHANGING production (helm upgrade, kubectl delete)
- Claude NEVER force pushes or deletes without explicit approval

The key: Claude does exactly what you permit it to do. Configure restrictive permissions for production, allow-list only read operations, and deny all destructive operations. You get the diagnosis speed without the deployment risk.

The engineers who get the most value: they let Claude run read operations autonomously, review Claude's suggested changes manually, then approve the execution.

→ Continue to: `01-backend-developer.md`
