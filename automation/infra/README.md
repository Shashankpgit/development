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
├── scale.sh                node group to 0 / back to 1, between sessions
└── destroy.sh              tear down (run this; the control plane bills hourly)
```

## Use it

```bash
./create_tf_backend.sh dev      # once per account; writes tf.sh
./provision.sh dev --plan       # review, change nothing
./provision.sh dev              # ~15 minutes
```

When you're done for the day:

```bash
./destroy.sh dev                # cluster only, keeps the free VPC
./destroy.sh dev --all          # cluster + VPC
```

## Scaling to save cost

```bash
./scale.sh dev          # show current state
./scale.sh dev 0        # 0 nodes -- back tomorrow
./scale.sh dev 1        # 1 node  -- waits until it is Ready
```

At 0 nodes every pod goes `Pending`, but nothing is deleted: Deployments,
Services and the Postgres PVC all survive, so **no Helm reinstall is needed**.
Scale back up and the data volume reattaches.

The node group is pinned to **one AZ** (`eks_node_az_suffixes: ["a"]`) because
an EBS volume is locked to a single AZ. Without pinning, a replacement node has
a ~50% chance of landing in the other AZ, stranding Postgres as `Pending` with
`volume node affinity conflict`.

## What it costs

| | Rate | Monthly |
|---|---|---|
| EKS control plane | $0.10/hr | **~$73** — flat, no free tier, billed idle |
| 1× t3.medium SPOT | ~$0.0125/hr | ~$9 |
| Node root EBS (20GB) | — | ~$1.60 |
| Postgres PVC (8GB) | — | ~$0.64 |
| NAT Gateway | — | **$0** — not created ([why](./modules/network/main.tf)) |
| Load balancer | — | **$0** — not created; use `kubectl port-forward` |
| **running, 1 node** | **~$0.115/hr** | **~$84** |
| **scaled to 0** | ~$0.101/hr | ~$74 |
| **destroyed** | — | ~$0 |

The control plane is ~87% of the bill, so **`scale.sh 0` only saves ~13%**.
It is for "back tomorrow", not for real savings — `destroy.sh` is the only
thing that stops the meter. On $300 of credits an always-on cluster lasts
~3.5 months; destroying it between sessions makes that last far longer.

## Deliberately not here

No RDS, no NAT, no bastion, no ALB controller, no output-file module. Postgres
runs in-cluster on an EBS volume via the chart already tested on minikube.
Each of those is a sensible next step, not a requirement for running this app.

Full explanation and concepts: [`docs/004-eks-infrastructure.md`](../../docs/004-eks-infrastructure.md).
