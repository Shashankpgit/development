# 004 — EKS infrastructure with OpenTofu + Terragrunt

## What we are doing

Writing the infrastructure-as-code to run the app on EKS. Deliberately minimal:
a VPC, a cluster, and the S3 bucket holding state. Nothing that is not needed to
get the three Helm releases running.

Structure follows the conventions in the `bluedots-automation` reference repo —
`modules/` + `_common/*.hcl` + a thin per-environment stack, `root.hcl`
generating the backend, `global-values.yaml` holding every environment value.

```
automation/infra/
├── modules/network/    VPC, 2 public subnets, IGW        (no NAT gateway)
├── modules/eks/        control plane, node group, IRSA, addons
├── _common/*.hcl       module wiring (source + dependencies + inputs)
├── dev/                one environment: root.hcl + global-values.yaml
├── create_tf_backend.sh
├── provision.sh
└── destroy.sh
```

### What gets created

| Resource | Why it is needed |
|---|---|
| VPC + 2 public subnets + IGW | EKS needs subnets in ≥ 2 AZs |
| EKS control plane | The Kubernetes API |
| 1 managed node group (2× t3.medium SPOT) | Somewhere for pods to run |
| IAM: cluster role, node role | EKS and the nodes act on your behalf |
| IAM OIDC provider | IRSA — pods assume roles without static keys |
| Addons: vpc-cni, kube-proxy, coredns | Pod networking, Service routing, DNS |
| Addon: aws-ebs-csi-driver + IRSA role | **Required** — the Postgres PVC |
| gp3 StorageClass | Cheaper/faster than the built-in gp2 |
| S3 bucket (by script) | OpenTofu state, versioned and encrypted |

### What is deliberately absent

- **No NAT Gateway.** ~$32/month per gateway, billed hourly whether used or
  not, and the single largest avoidable cost. Nodes sit in public subnets and
  egress via the free Internet Gateway instead. The trade-off is stated in
  `modules/network/main.tf`: nodes have public IPs (their security group still
  admits nothing inbound), which is not a production posture.
- **No RDS.** Postgres runs in-cluster on an EBS volume, using the chart already
  proven on minikube. RDS `db.t4g.micro` is free-tier for 12 months and is the
  natural next step — swapping it in means changing `database.existingSecret`
  and `database.host` in `values/shop-api-eks.yaml`, nothing else.
- **No load balancer.** An ALB is ~$16/month plus LCU charges.
  `kubectl port-forward` is free. The Ingress templates are already written and
  gated behind `ingress.enabled=false`.
- **No bastion, no VPN, no output-file module.** The API endpoint is public and
  IAM-authenticated; restrict `eks_public_access_cidrs` to your own IP.

### Cost, plainly

| Item | Rate | Monthly if left running |
|---|---|---|
| EKS control plane | $0.10/hr | **~$73** |
| 2× t3.medium SPOT | ~$0.025/hr | ~$18 |
| 2× 20GB gp3 | — | ~$3 |
| NAT / ALB | $0 | $0 |
| **Total** | **~$0.13/hr** | **~$94** |

The control plane is the whole story: it is a flat hourly charge with **no free
tier**, billed from cluster creation to cluster deletion regardless of load. On
$300 of credits, always-on ≈ 3 months. `./destroy.sh` between sessions turns
that into months of actual working time, because a destroyed cluster bills
nothing and the VPC is free to leave in place.

### Running it

```bash
cd automation/infra

./create_tf_backend.sh dev      # once per AWS account; writes tf.sh

./provision.sh dev --plan       # review the whole stack, change nothing
./provision.sh dev              # network → eks → kubeconfig → StorageClass
```

Then the same three charts as minikube, with EKS values:

```bash
kubectl create namespace shop
helm upgrade --install shop-db  automation/helmcharts/postgresql -n shop \
  -f automation/helmcharts/values/postgresql-eks.yaml --wait
helm upgrade --install shop-api automation/helmcharts/shop-api -n shop \
  -f automation/helmcharts/values/shop-api-eks.yaml --wait
helm upgrade --install shop-web automation/helmcharts/shop-web -n shop \
  -f automation/helmcharts/values/shop-web-eks.yaml --wait

kubectl port-forward -n shop svc/shop-web 8080:80
./automation/test/smoke-test.sh shop
```

Note the images now come from Docker Hub (`shashank04515/shop-api:1.0.1`,
`shashank04515/shop-web:1.0.0`) rather than minikube's local daemon. That is the
only difference between the two environments' values files, besides
`storageClass: gp3` instead of `standard`.

### Before the first apply

- [ ] Set `eks_public_access_cidrs` to `["YOUR.IP/32"]` in `global-values.yaml`
- [ ] Replace the `CHANGE_ME` passwords in `values/postgresql-eks.yaml`
- [ ] Check `eks_cluster_version` is a version AWS still offers
- [ ] Confirm your `kubectl` is within one minor version of it

### Validation done without an AWS account

```
tofu validate  modules/network   -> Success
tofu validate  modules/eks       -> Success
tofu fmt -check -recursive       -> clean
terragrunt hcl format --check    -> clean
terragrunt render dev/network    -> inputs resolve from global-values.yaml
terragrunt render dev/eks        -> dependency falls back to mock_outputs
```

That last line is the useful one: because `_common/eks.hcl` declares
`mock_outputs`, the eks stack can be planned *before* the network has ever been
applied. Without it you could never review the full plan up front — only apply
one component at a time and hope.

**Not verified:** nothing has been applied. No AWS account was touched, so the
code is syntactically valid and internally consistent but has never provisioned
a real cluster. Expect to hit at least one thing on the first run — a
`cluster_version` AWS no longer offers, or an IAM permission your user lacks.

---

## Concepts / KT

**OpenTofu** — the open-source fork of Terraform, same language and providers.
`tofu` is a drop-in replacement for `terraform`. Terragrunt is told to use it
via `TG_TF_PATH=tofu`.

**Terragrunt** — a thin wrapper over Tofu that removes repetition. It provides
three things this setup depends on: generated backend config (write it once,
not per component), `dependency` blocks (ordering plus reading another
component's outputs), and `run --all` (operate on the whole stack).

**Module vs stack** — a *module* (`modules/eks`) is reusable and knows nothing
about your environments. A *stack* (`dev/eks`) is one instance of it with real
values. Keeping them apart is what makes a second environment a copy of a
6-line file rather than a copy of the module.

**Remote state, and why S3** — state maps your code to real resource ids.
Locally it is a file only you have; in S3 it is shared, versioned and
encrypted. **Versioning is the important setting**: state is overwritten on
every apply, and if one write is ever corrupt, a previous version is the only
way back.

**State locking** — two concurrent applies interleaving writes will corrupt
state. `use_lockfile = true` uses an S3 conditional write to prevent it
(OpenTofu ≥ 1.10). The older approach needed an entire DynamoDB table for this
one job.

**One state file per component** — `key = "${path_relative_to_include()}/terraform.tfstate"`
gives `network/` and `eks/` separate state. That separation is what makes
`./destroy.sh dev` able to delete the cluster and leave the VPC untouched.

**The state bucket bootstrap problem** — the bucket that stores state cannot be
managed by the state it stores. Hence `create_tf_backend.sh`: a shell script,
run once, idempotent.

**`mock_outputs`** — placeholder values a `dependency` returns when the
upstream state does not exist yet, so the stack can be planned from scratch.
`mock_outputs_merge_strategy_with_state = "shallow"` prefers real values
per-key once they exist; without it, one missing key discards the whole real
output set.

**The `//` in a module source** — `modules//eks` marks where the module root
begins, so Terragrunt copies that directory into its cache rather than the
whole repo. Omit it and relative paths inside the module break.

**`for_each` vs `count`** — `count` indexes by position, so removing the first
item renumbers everything after it and Tofu plans to destroy and recreate them
all. `for_each` keys by a stable string. The subnets use `for_each` keyed by AZ
name for exactly this reason.

**IRSA** — IAM Roles for Service Accounts. The cluster issues signed JWTs for
service accounts; registering its OIDC issuer with IAM lets AWS trust them, so
a pod calls AWS APIs by presenting its token. No access keys in Secrets, and
credentials that expire on their own. The `sub` condition in the trust policy
is the entire security model — it pins the role to one exact service account in
one namespace. A wildcard there lets any pod in the cluster assume it.

**EKS access entries vs `aws-auth`** — the old way was hand-editing a ConfigMap
inside the cluster, famous for two failure modes: a YAML typo locked everyone
out irrecoverably, and access lived in the cluster instead of in your IaC.
Access entries are a real AWS API. `bootstrap_cluster_creator_admin_permissions
= true` is what stops you creating a cluster you cannot talk to.

**Managed node group** — AWS owns the AMI, the bootstrap and the drain-on-
replace behaviour. Self-managed ASGs mean writing userdata and handling node
lifecycle yourself, for no benefit at this scale.

**SPOT capacity** — ~70% cheaper, reclaimable with 2 minutes' notice. Genuinely
useful for learning: it exercises your PodDisruptionBudget and rolling updates
for real rather than in theory.

**Max pods per node** — with the AWS VPC CNI every pod gets a real VPC IP from
the node's network interfaces, so the pod ceiling is fixed by instance type:
t3.small 11, t3.medium 17, t3.large 35. kube-system alone uses 4–5. This
surprises people who sized purely on CPU and memory.

**EKS addons** — cluster components AWS installs and upgrades for you.
Declaring them in Tofu puts their versions in the same plan as everything else.
`resolve_conflicts_on_create = "OVERWRITE"` is needed because EKS pre-installs
default versions of vpc-cni, kube-proxy and coredns — without it the first
apply fails with "already exists" on a cluster you just created.

**Why coredns needs `depends_on` the node group** — it runs as ordinary pods,
so it needs a node to run *on*. vpc-cni and kube-proxy are DaemonSets that
install onto nodes as they appear, so they do not.

**`WaitForFirstConsumer`** — an EBS volume is locked to one availability zone.
This binding mode delays creating it until Kubernetes has scheduled the pod and
therefore knows the AZ. With the default `Immediate`, the volume is provisioned
up front and the pod is frequently unschedulable because the volume is in the
wrong AZ. This is the most common EBS-on-EKS mistake.

**Why the StorageClass is not in the Tofu code** — it is a Kubernetes object,
so it needs the `kubernetes` provider, which must be configured with the
cluster's endpoint and CA. In the same apply that *creates* the cluster, those
values do not exist at plan time. Mixing cloud resources and in-cluster objects
in one state produces an apply you cannot safely re-run, so it is applied with
`kubectl` afterwards.

**Two default StorageClasses is undefined** — EKS ships gp2 already marked
default. `provision.sh` demotes it after adding gp3, otherwise a PVC that names
no class may bind to either.

**Orphaned resources on destroy** — LoadBalancer Services and PVCs are created
by controllers *inside* the cluster, so Tofu does not know they exist.
Destroying the cluster without deleting them first leaves ELBs and EBS volumes
billing quietly, and orphaned ENIs that block the VPC from ever being deleted.
`destroy.sh` removes them first, which is why it runs `kubectl delete` before
`terragrunt destroy`.

**`ignore_changes` on `desired_size`** — the autoscaler changes node count at
runtime. Without this, the next `tofu apply` helpfully resets it to the number
in code, fighting the autoscaler and possibly evicting pods.

**`default_tags` on the provider** — applies tags to every taggable resource.
This is what makes "what is this cluster costing me?" answerable in Cost
Explorer; untagged resources are effectively invisible there.

**`source` vs executing a script** — `source ./tf.sh` runs it in your *current*
shell, so the exports persist. `bash ./tf.sh` runs it in a child shell that
exits immediately, taking the variables with it. This is why environment setup
scripts must be sourced, and why `provision.sh` sources `tf.sh` itself rather
than trusting you to have done it: a child shell inherits only *exported*
variables from its parent, so `bash provision.sh` starts with none of them.
