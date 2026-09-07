# infra — OpenTofu + Terragrunt for EKS

Two modules, one environment. Just enough to run the shopping app.

```
infra/
├── modules/
│   ├── network/   VPC, 2 public subnets, internet gateway   (no NAT)
│   └── eks/       control plane, node group, IRSA, addons
├── _common/       module wiring, shared by every environment
│   ├── network.hcl
│   └── eks.hcl
├── dev/
│   ├── root.hcl            generates backend.tf + provider.tf
│   ├── global-values.yaml   ← every value that defines this environment
│   ├── gp3-sc.yaml          gp3 StorageClass (applied with kubectl)
│   ├── network/terragrunt.hcl
│   └── eks/terragrunt.hcl
├── create_tf_backend.sh    run once: S3 state bucket + tf.sh
├── provision.sh            network → eks → kubeconfig → StorageClass
└── destroy.sh              tear down (run this; the control plane bills hourly)
```

## Use it

```bash
./create_tf_backend.sh dev      # once per account
source ./tf.sh                  # once per shell
./provision.sh dev --plan       # review, change nothing
./provision.sh dev              # ~15 minutes
```

When you're done for the day:

```bash
./destroy.sh dev                # cluster only, keeps the free VPC
./destroy.sh dev --all          # cluster + VPC
```

## What it costs

| | |
|---|---|
| EKS control plane | $0.10/hr — **~$73/mo, no free tier, billed idle** |
| 2× t3.medium SPOT | ~$18/mo |
| 2× 20GB gp3 EBS | ~$3/mo |
| NAT Gateway | **$0** — not created ([why](./modules/network/main.tf)) |
| Load balancer | **$0** — not created; use `kubectl port-forward` |
| **while running** | **~$0.13/hr ≈ $3.10/day** |

On $300 of credits an always-on cluster lasts ~3 months. Destroying it between
sessions makes that credit last far longer — the VPC and state bucket cost
essentially nothing while the cluster is gone.

## Deliberately not here

No RDS, no NAT, no bastion, no ALB controller, no output-file module. Postgres
runs in-cluster on an EBS volume via the chart already tested on minikube.
Each of those is a sensible next step, not a requirement for running this app.

Full explanation and concepts: [`docs/004-eks-infrastructure.md`](../../docs/004-eks-infrastructure.md).
