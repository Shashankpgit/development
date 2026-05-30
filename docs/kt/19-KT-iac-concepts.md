# KT 19 — Infrastructure as Code: OpenTofu + Terragrunt

## What you will understand after this

- Why "just run gcloud" does not scale and what IaC solves
- How OpenTofu thinks: resources, state, plan, apply
- What Terraform state actually is and why losing it is catastrophic
- Why remote state is non-negotiable for team/CI use
- What Terragrunt adds on top of OpenTofu and why you need it
- The `modules/` vs `live/` pattern and why it exists
- How a `dependency {}` block enforces apply order automatically
- GCP networking concepts you need to understand before writing a single `.tf` file

---

## Part 1 — The problem with manual cloud setup

### What you have been doing so far

Every GCP resource in the current stack — the GKE cluster, the VPC, the firewall
rules, the node pool — was created by running `gcloud` commands or clicking in the
console. That works fine once.

Now imagine:

- You destroy the cluster tonight to save money (GKE is billed per hour)
- You need to recreate it tomorrow
- You have to remember every `gcloud` command in the right order
- You forget one firewall rule → cert-manager cannot reach Let's Encrypt → no HTTPS
- You spend 2 hours debugging a 503 that should never have happened

Or:

- A teammate needs to set up the same infra in a different GCP project
- They try to follow your runbook but your runbook is 3 months old and the flags changed
- 4 hours of their time wasted

This is the problem IaC solves.

### What Infrastructure as Code gives you

| Manual (`gcloud` / console) | IaC (OpenTofu) |
|---|---|
| Create resources by running commands | Declare resources in files |
| Must remember order | Tool figures out order |
| Recreating requires re-running all commands | `tofu apply` → same state every time |
| No history of what changed | Git diff shows every infra change |
| Hard to reproduce in new environment | Copy `live/staging/`, change a few variables |
| "Works on my machine" | Same code, same infra, always |

IaC treats infrastructure the same way application code treats logic: write it,
review it, version it, reproduce it.

---

## Part 2 — OpenTofu

### What OpenTofu is

Terraform was the dominant IaC tool for years. In 2023, HashiCorp changed Terraform's
licence from open-source (MPL) to the Business Source Licence (BSL), which restricts
commercial use. The community forked the last open-source version into **OpenTofu**.

OpenTofu is functionally identical to Terraform:
- Same HCL (HashiCorp Configuration Language) syntax
- Same providers (Google, AWS, Azure, Kubernetes, ...)
- Same state format
- `terraform` is replaced by `tofu` in all commands

You write HCL files describing resources. OpenTofu talks to cloud APIs to make the
real world match what you wrote.

---

### The core idea: desired state vs actual state

OpenTofu is declarative. You write what you *want*, not the steps to get there.

```hcl
# You write this:
resource "google_compute_network" "vpc" {
  name                    = "vault-vpc"
  auto_create_subnetworks = false
}
```

This says: "I want a VPC called `vault-vpc`".

OpenTofu's job is to figure out whether:
- The VPC doesn't exist yet → create it
- The VPC exists with the right settings → do nothing
- The VPC exists but the name is different → destroy the old one, create the new one

You never write "first check if the VPC exists, then create it if not". OpenTofu
handles that logic internally.

---

### The four primitives

#### 1. Resource

A `resource` block declares a real cloud object you want to exist.

```hcl
resource "<provider>_<resource_type>" "<local_name>" {
  # configuration arguments
}
```

Example:
```hcl
resource "google_compute_firewall" "allow_http" {
  name    = "allow-http"
  network = google_compute_network.vpc.name   # reference to another resource

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["0.0.0.0/0"]
}
```

- `google_compute_firewall` — the resource type (from the Google provider)
- `allow_http` — the local name (used to reference this resource from other resources)
- The block body — configuration specific to this resource type
- `google_compute_network.vpc.name` — references the `name` attribute of the VPC
  resource defined earlier; OpenTofu knows to create the VPC first

#### 2. Variable

A `variable` block declares an input your module expects. Makes modules reusable
without hardcoding project-specific values.

```hcl
variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "node_count" {
  description = "Number of GKE worker nodes"
  type        = number
  default     = 2
}
```

Used in the module as `var.project_id`, `var.node_count`.

#### 3. Output

An `output` block exposes a value so other modules (or you) can consume it.

```hcl
output "vpc_name" {
  description = "Name of the VPC"
  value       = google_compute_network.vpc.name
}

output "ingress_ip" {
  description = "Reserved static IP for the ingress LoadBalancer"
  value       = google_compute_address.ingress_ip.address
}
```

After `tofu apply`, you see outputs printed. You copy the static IP and paste it
into DuckDNS. Other modules read outputs via `dependency {}` blocks (covered in
the Terragrunt section).

#### 4. Data source

A `data` block reads an existing resource *without managing it*. Use this when you
need to reference something that already exists but was not created by this code.

```hcl
data "google_container_cluster" "existing" {
  name     = "vault-cluster"
  location = "asia-south1"
}
```

This reads the cluster's details but will never create, modify, or destroy it.

---

### The provider

Before OpenTofu can talk to GCP, it needs a provider — a plugin that knows how to
translate your HCL into GCP API calls.

```hcl
provider "google" {
  project = var.project_id
  region  = "asia-south1"
}
```

OpenTofu downloads the `google` provider automatically when you run `tofu init`.
The provider version is pinned in a `versions.tf` file so everyone uses the same
provider version.

---

### The three commands you will use every day

#### `tofu init`

Run once (and again if you add a new provider):
- Downloads the provider plugins
- Initializes the remote state backend (connects to the GCS bucket)
- Must be re-run if you change the backend config

#### `tofu plan`

**This is your safety check. Always run plan before apply.**

```
$ tofu plan

Terraform will perform the following actions:

  # google_compute_network.vpc will be created
  + resource "google_compute_network" "vpc" {
      + name = "vault-vpc"
    }

  # google_compute_firewall.allow_http will be created
  + resource "google_compute_firewall" "allow_http" {
      + name = "allow-http"
    }

Plan: 2 to add, 0 to change, 0 to destroy.
```

`+` = will be created  
`~` = will be modified in place  
`-` = will be destroyed  
`-/+` = will be destroyed and recreated (e.g. renaming a resource)

`-/+` is the dangerous one. Some changes (like renaming a GKE cluster) require
destroy + recreate — meaning downtime. Plan shows this before it happens.

#### `tofu apply`

Applies the plan. Creates/modifies/destroys resources to match your HCL. Asks for
confirmation unless you pass `-auto-approve` (which CI does).

---

## Part 3 — Terraform state

### What state is

OpenTofu maintains a file called `terraform.tfstate`. This JSON file is the record
of what OpenTofu has created.

A simplified example:

```json
{
  "resources": [
    {
      "type": "google_compute_network",
      "name": "vpc",
      "instances": [
        {
          "attributes": {
            "id": "projects/my-project/global/networks/vault-vpc",
            "name": "vault-vpc",
            "self_link": "https://www.googleapis.com/compute/v1/..."
          }
        }
      ]
    }
  ]
}
```

When you run `tofu plan`, OpenTofu:
1. Reads your HCL (desired state)
2. Reads `terraform.tfstate` (last known state)
3. Queries GCP APIs (actual current state)
4. Computes the diff between desired and actual

Without state, OpenTofu cannot know whether a resource already exists. It would
try to create everything from scratch every single time → duplicate resources,
errors, chaos.

### Drift

**Drift** is when the actual state of a resource no longer matches the state
OpenTofu recorded.

This happens when someone goes to the GCP console and manually changes something.
For example: you manually scaled the node pool from 2 to 3 nodes in the console.
OpenTofu's state still says 2. The next `tofu plan` will show:

```
~ google_container_node_pool.nodes
    node_count: 3 → 2
```

OpenTofu wants to bring it back to 2 because that's what your HCL says.

This is why you should never manually change resources managed by OpenTofu.
If you do, either update your HCL to match, or run `tofu import` to update the
state file.

### Why local state is dangerous

If `terraform.tfstate` lives on your laptop:

- Your teammate runs `tofu apply` → they have no state file → they try to create
  everything again → duplicate resources, conflicts, or overwriting your resources
- You `rm -rf` your project directory → state gone → OpenTofu has no idea what it
  created → to destroy resources you have to go to the console and delete everything
  manually (and hope you remember everything)
- CI runs `tofu apply` → no state file on the CI runner → same problem as teammate

### Why remote state is mandatory

With remote state, the `terraform.tfstate` file lives in a GCS bucket:

```
gs://vault-tofu-state/live/vault/network/terraform.tfstate
gs://vault-tofu-state/live/vault/gke/terraform.tfstate
```

Now:
- Everyone reads from the same state (laptop, teammate's laptop, CI runner)
- GCS bucket has versioning enabled → state corruption is recoverable
- State locking: when one `tofu apply` is running, it puts a lock on the state file.
  Another `tofu apply` that starts simultaneously will wait or fail. No two processes
  corrupt the same state at the same time.

**The bootstrap problem**: the GCS bucket itself cannot be created by OpenTofu
(OpenTofu needs the bucket before it can store state). We solve this with a
`scripts/bootstrap.sh` that runs once before anything else.

---

## Part 4 — Terragrunt

### What Terragrunt is

Terragrunt is a wrapper around OpenTofu. It does not replace HCL. You still write
OpenTofu modules in HCL. Terragrunt adds a thin layer on top that solves problems
that pure OpenTofu leaves to you.

Think of it like this:
- OpenTofu is the engine
- Terragrunt is the gearbox and dashboard

### The three problems Terragrunt solves

#### Problem 1: DRY backend config

Without Terragrunt, every module needs this block:

```hcl
# infra/modules/apis/backend.tf
terraform {
  backend "gcs" {
    bucket = "vault-tofu-state"
    prefix = "live/vault/apis"
  }
}

# infra/modules/network/backend.tf
terraform {
  backend "gcs" {
    bucket = "vault-tofu-state"
    prefix = "live/vault/network"
  }
}

# infra/modules/gke/backend.tf
terraform {
  backend "gcs" {
    bucket = "vault-tofu-state"
    prefix = "live/vault/gke"
  }
}
```

If the bucket name changes, you update 3 files. With 10 modules you update 10 files.
This is also the kind of thing where one wrong copy-paste puts two modules writing
to the same state key — silent corruption.

**With Terragrunt**, you write the backend config once in `infra/live/terragrunt.hcl`:

```hcl
remote_state {
  backend = "gcs"
  config = {
    bucket = "vault-tofu-state"
    prefix = "${path_relative_to_include()}"
  }
}
```

`path_relative_to_include()` is a Terragrunt built-in that returns the path of the
module relative to this root file. So:
- `live/vault/apis/` → prefix = `live/vault/apis`
- `live/vault/network/` → prefix = `live/vault/network`

Each module automatically gets its own unique state key. Change the bucket name once
in one place.

#### Problem 2: Dependency ordering

Without Terragrunt, you must apply modules in the right order manually:

```bash
cd infra/live/vault/apis && tofu apply
cd infra/live/vault/network && tofu apply   # must wait for apis to finish
cd infra/live/vault/gke && tofu apply       # must wait for network to finish
```

If you apply them out of order, you get obscure errors like "API not enabled" or
"subnet not found" — because the dependency was not ready.

**With Terragrunt**, each `live/vault/gke/terragrunt.hcl` declares:

```hcl
dependency "network" {
  config_path = "../network"
}

dependency "apis" {
  config_path = "../apis"
}
```

Then you run:

```bash
cd infra/live/vault
terragrunt run-all apply
```

Terragrunt reads all `terragrunt.hcl` files, builds a dependency graph, and applies
them in the correct order automatically. It also parallelises independent modules.

#### Problem 3: DRY shared inputs

Without Terragrunt, every module's variable block needs `project_id` and `region`,
and every place you call the module must pass them. 10 modules = 10 places to update
when you change the region.

**With Terragrunt**, the root `terragrunt.hcl` has:

```hcl
inputs = {
  project_id = "vault-project-123"
  region     = "asia-south1"
}
```

All child modules inherit these automatically. A child module's `terragrunt.hcl` only
needs to specify inputs that are specific to that module.

---

### The `modules/` vs `live/` pattern

This is the most important structural decision in the whole setup.

```
infra/
├── modules/          ← reusable logic, no environment-specific values
│   ├── network/
│   │   ├── main.tf   ← creates VPC, NAT, firewall rules
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── gke/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
│
└── live/             ← environment-specific values, calls modules
    └── vault/        ← "vault" is the environment name
        ├── network/
        │   └── terragrunt.hcl   ← calls modules/network, passes values
        └── gke/
            └── terragrunt.hcl   ← calls modules/gke, passes values
```

`infra/live/vault/network/terragrunt.hcl`:

```hcl
terraform {
  source = "../../../modules/network"
}

include "root" {
  path = find_in_parent_folders()   # picks up root terragrunt.hcl (state + provider)
}

inputs = {
  vpc_name    = "vault-vpc"
  subnet_cidr = "10.0.0.0/24"
  region      = "asia-south1"
}
```

The module in `modules/network/` has no hardcoded values. It uses variables.
The environment in `live/vault/network/` provides the values.

**Why this separation matters:**

To add a staging environment, you add `live/staging/network/terragrunt.hcl` with
different values (different subnet CIDRs, smaller machine types, different cluster name).
Nothing in `modules/` changes. The same logic runs, different values.

---

### Terragrunt `dependency {}` blocks in detail

When module B depends on module A, module B needs module A's outputs.

In `infra/live/vault/gke/terragrunt.hcl`:

```hcl
dependency "network" {
  config_path = "../network"

  mock_outputs = {                # used during `plan` when network hasn't been applied yet
    vpc_name           = "mock-vpc"
    subnet_name        = "mock-subnet"
    pods_range_name    = "mock-pods"
    services_range_name = "mock-services"
  }
}

inputs = {
  network_name        = dependency.network.outputs.vpc_name
  subnet_name         = dependency.network.outputs.subnet_name
  pods_range_name     = dependency.network.outputs.pods_range_name
  services_range_name = dependency.network.outputs.services_range_name
}
```

`dependency.network.outputs.vpc_name` reads the `vpc_name` output from the network
module's applied state. This is what makes the dependency graph work — the GKE module
literally cannot run without network outputs.

`mock_outputs` exist so you can run `tofu plan` on the GKE module before applying
the network module. Without mocks, Terragrunt would error because the network outputs
don't exist yet.

---

## Part 5 — GCP networking primer

Before writing the network module, you need to understand what you're building.

### VPC

A **Virtual Private Cloud** is a private network inside GCP. All resources you
create (GKE nodes, Cloud SQL, etc.) live inside a VPC. Resources in the same VPC
can talk to each other. Resources outside cannot reach them unless you create
firewall rules.

A GCP VPC is **global** — it spans all regions. Subnets are region-specific.

```
VPC: vault-vpc (global)
  └── Subnet: vault-subnet (asia-south1)
        CIDR: 10.0.0.0/24
```

### Subnet

A subnet is a portion of the VPC's IP space, in a specific region. Every GKE node
gets an IP from the subnet's primary CIDR range.

**Secondary ranges**: GKE (in VPC-native mode) needs two additional IP ranges:
- One range for pod IPs (`10.1.0.0/16` — up to 65,536 pod IPs)
- One range for service cluster IPs (`10.2.0.0/20` — up to 4,096 services)

These ranges are defined on the subnet but used internally by Kubernetes. Without
them, GKE cluster creation fails with "subnet missing secondary ranges".

### Private nodes

By default, GKE nodes have public IPs. Public IPs mean:
- Anyone on the internet can try to SSH into your nodes
- Attack surface is large

Private nodes have no public IPs. They can only be reached from inside the VPC.
The tradeoff: they have no outbound internet access either.

### Cloud Router + Cloud NAT

Private nodes need to pull container images and make API calls. Cloud NAT gives
them outbound internet access without giving them public IPs:

```
Node (private IP: 10.0.0.5)
  → Cloud NAT (outbound traffic, translates 10.0.0.5 → GCP external IP)
    → GHCR / Let's Encrypt / any external service

External service
  → sees a GCP external IP (the NAT's), not the node's private IP
  → response comes back to NAT, forwarded to 10.0.0.5
  → node receives the response
```

Cloud Router is the BGP routing component NAT uses to advertise route changes
across the network. You don't configure it directly — it just needs to exist.

**Critical dependency**: Without Cloud NAT:
- `imagePullBackOff` on every pod (can't reach GHCR)
- cert-manager's `CertificateRequest` stays in `pending` forever (can't reach
  `acme-v02.api.letsencrypt.org`)
- Any `curl` to an external URL from inside a pod fails

### Firewall rules

GCP's default behaviour is: **deny all inbound traffic, allow all outbound traffic**.

You must explicitly allow traffic you want to reach your nodes.

#### The four rules for this stack

**1. allow-inbound-http-https**
- Why: Users' browsers and cert-manager's HTTP-01 ACME challenge both send traffic
  to the cluster's public IP on ports 80 and 443. Without this rule, the traffic
  hits the GCP edge and is dropped before reaching ingress-nginx.
- Source: `0.0.0.0/0` (anyone on the internet)
- Target: nodes with tag `gke-node`
- Ports: TCP 80, 443

**2. allow-gcp-health-checks**
- Why: ingress-nginx runs as a `LoadBalancer` service, which creates a GCP Network
  Load Balancer. The GCP LB sends health probes to each backend (the ingress-nginx
  pods) every few seconds. If these probes cannot reach the nodes, GCP marks all
  backends as unhealthy and returns 502 for all external traffic — even though your
  pods are running fine.
- Source: `35.191.0.0/16`, `130.211.0.0/22` — these are GCP's internal health check
  IP ranges. They are not publicly documented in an obvious place; you have to know them.
- Target: nodes
- Ports: TCP 80, 443, 8443

**3. allow-internal**
- Why: Kubernetes needs pod-to-pod and node-to-node communication. A sidecar proxy
  talking to its main container, a pod calling a service on another node, kubelet
  health checks — all of this traverses the VPC.
- Source: the subnet's primary CIDR (e.g. `10.0.0.0/24`)
- Target: all nodes
- Ports: all

**4. allow-egress-https**
- Why: default outbound is allowed, but being explicit is good practice. This rule
  documents that nodes make HTTPS calls out. In high-security setups you'd restrict
  egress completely and only allow known destinations.
- Direction: EGRESS
- Destination: `0.0.0.0/0`
- Ports: TCP 443

#### Network tags

GCP firewall rules can target:
- All instances in the network (broad — every VM in the VPC gets the rule)
- Instances with a specific **network tag** (precise — only tagged VMs)

GKE nodes get a tag like `gke-node`. Firewall rules target this tag.
If you later add a Cloud SQL instance to the same VPC, the firewall rules for
ingress traffic don't apply to it — it doesn't have the `gke-node` tag.

### Reserved static external IP

ingress-nginx creates a GCP LoadBalancer. By default, the LoadBalancer gets an
ephemeral external IP — it changes every time you destroy and recreate the cluster.
After recreating, you'd have to update DuckDNS again.

A reserved static IP is a GCP resource that holds an external IP address. You assign
it to the LoadBalancer by setting `loadBalancerIP` in the ingress-nginx Helm values.
Even if you destroy the cluster and recreate it, the IP remains reserved — you just
assign it to the new LoadBalancer.

---

## Part 6 — Summary

### What you just learned

```
gcloud commands           → replaced by HCL files committed to git
Manual apply order        → Terragrunt dependency graph
Repeated backend config   → One root terragrunt.hcl
Local state file          → GCS bucket with versioning
"I forget what I created" → tofu plan shows everything before it changes
```

### The workflow you will use

```
1. Edit HCL files
2. git diff / PR review          ← infrastructure change is code-reviewed
3. tofu plan                     ← see exactly what will change
4. tofu apply (or merge to main) ← CI applies
5. git log                       ← full history of every infra change
```

### What comes next

| Phase | What you build |
|---|---|
| 19.2 | Bootstrap: GCS state bucket + root terragrunt.hcl |
| 19.3 | APIs module: enable GCP APIs |
| 19.4 | Network module: VPC + NAT + firewall + static IP |
| 19.5 | GKE module: cluster + node pool + IAM |
| 19.6 | Wire it all together: one command creates everything |
| 19.7 | CI/CD: PR shows plan diff, merge triggers apply |

---

## Quick reference

### Common OpenTofu commands

| Command | What it does |
|---|---|
| `tofu init` | Download providers, connect to remote state |
| `tofu plan` | Show what will change (does not change anything) |
| `tofu apply` | Apply changes (asks for confirmation) |
| `tofu apply -auto-approve` | Apply without confirmation (use in CI) |
| `tofu destroy` | Destroy all resources in current module |
| `tofu output` | Print output values |
| `tofu state list` | List all resources in state |
| `tofu import` | Add an existing resource to state |

### Common Terragrunt commands

| Command | What it does |
|---|---|
| `terragrunt plan` | Like `tofu plan` but in a `live/` directory |
| `terragrunt apply` | Like `tofu apply` but in a `live/` directory |
| `terragrunt run-all plan` | Plan all modules in dependency order |
| `terragrunt run-all apply` | Apply all modules in dependency order |
| `terragrunt run-all destroy` | Destroy all modules in reverse order |
