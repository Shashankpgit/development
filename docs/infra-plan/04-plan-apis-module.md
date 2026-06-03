# Plan 04 — APIs Module

## What we are building in this step

Two files:
```
infra/modules/apis/main.tf
infra/modules/apis/variables.tf
infra/live/vault/apis/terragrunt.hcl
```

This is the simplest module — it enables GCP project APIs. It runs first because
every other module needs at least one API to be enabled before it can create resources.

---

## File 1: `infra/modules/apis/variables.tf`

### Block 1: project_id variable

```hcl
variable "project_id" {
  description = "GCP project ID in which to enable APIs"
  type        = string
}
```

Every module needs `project_id` because every GCP resource is created in a specific
project. This comes from the root `terragrunt.hcl` inputs block automatically.

`type = string` — OpenTofu validates that whatever value is passed is actually a
string, not a number or boolean.

### Block 2: region variable

```hcl
variable "region" {
  description = "GCP region (passed from root; not used by this module)"
  type        = string
  default     = ""
}
```

The root `terragrunt.hcl` passes `region` as an input to every module. Even though
the APIs module does not use `region` at all (enabling APIs is project-wide, not
regional), we must declare the variable here. Without it, OpenTofu raises:

```
Error: Unsupported argument
  An argument named "region" is not expected here.
```

The `default = ""` means the variable is optional — it won't error if not provided.

---

## File 2: `infra/modules/apis/main.tf`

### Block 1: the APIs resource

```hcl
resource "google_project_service" "apis" {
  for_each = toset([
    "compute.googleapis.com",
    "container.googleapis.com",
    "iam.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "servicenetworking.googleapis.com",
  ])

  project = var.project_id
  service = each.value

  disable_on_destroy = false
}
```

**`resource "google_project_service" "apis"`**

`google_project_service` is the OpenTofu resource type for enabling a GCP API.
`"apis"` is the local name — used to reference this resource elsewhere (e.g. in
outputs or other resources).

**`for_each = toset([...])`**

Without `for_each`, you'd write one resource block per API:
```hcl
resource "google_project_service" "compute" { service = "compute.googleapis.com" }
resource "google_project_service" "container" { service = "container.googleapis.com" }
# ... 3 more
```

With `for_each`, one block creates all 5. OpenTofu creates one resource instance
for each item in the set. The state tracks them as:
```
google_project_service.apis["compute.googleapis.com"]
google_project_service.apis["container.googleapis.com"]
...
```

`toset([...])` — converts the list to a set. Sets have no duplicates and no order.
`for_each` requires a set or map (not a list) because list indices can shift if items
are added/removed, causing unintended resource replacements.

**`each.value`**

Inside a `for_each` block, `each.value` is the current item (the API string like
`"compute.googleapis.com"`). `each.key` is the same value for a set (keys and values
are identical in a set).

**`project = var.project_id`**

Explicitly setting the project makes the resource work even if the provider's
`project` argument is not set. Explicit is always better than relying on defaults.

**`disable_on_destroy = false`**

When you run `tofu destroy`, should this API be disabled? The answer is almost always
**no**:
- Other workloads in the same project may use the same API
- Disabling `container.googleapis.com` while someone else in the project has a GKE
  cluster would delete their cluster
- Re-enabling an API has a delay — resources cannot be created until the API is
  fully enabled again

---

## File 3: `infra/live/vault/apis/terragrunt.hcl`

### Block 1: source

```hcl
terraform {
  source = "../../../modules/apis"
}
```

`source` — tells Terragrunt where to find the OpenTofu module code.
`"../../../modules/apis"` is a relative path:

```
Current file:  infra/live/vault/apis/terragrunt.hcl
Go up 3 dirs:  infra/live/vault/ → infra/live/ → infra/
Then enter:    modules/apis/
Result:        infra/modules/apis/
```

Terragrunt copies the module code into `.terragrunt-cache/` before running `tofu`,
so the actual working directory is `.terragrunt-cache/.../modules/apis/`.

### Block 2: include root

```hcl
include "root" {
  path = find_in_parent_folders()
}
```

Inherits everything from `infra/live/terragrunt.hcl`:
- The GCS remote state config → OpenTofu knows to save state at `gs://bucket/vault/apis/`
- The generated `provider.tf` → OpenTofu knows how to authenticate to GCP
- The shared inputs → `project_id` and `region` are passed to the module

No extra `inputs` block needed — `project_id` and `region` already come from the root.

---

## How Terragrunt processes this module

```
You run: cd infra/live/vault/apis && terragrunt apply

Terragrunt:
  1. Reads infra/live/vault/apis/terragrunt.hcl
  2. Reads infra/live/terragrunt.hcl (via include)
  3. Evaluates: GCP_PROJECT_ID = "your-project" (from env)
  4. Creates .terragrunt-cache/.../ directory
  5. Copies modules/apis/ into .terragrunt-cache/
  6. Writes backend.tf: GCS bucket + prefix "vault/apis"
  7. Writes provider.tf: google provider with project + region
  8. Runs: tofu init (downloads google provider, connects to GCS)
  9. Runs: tofu apply

OpenTofu:
  10. Reads main.tf + variables.tf
  11. Resolves var.project_id = "your-project" (from inputs)
  12. Plans: 5 google_project_service resources to create
  13. Creates them via GCP API
  14. Saves state to gs://bucket/vault/apis/terraform.tfstate
```

---

## The dependency graph position

```
  [apis]          ← no dependencies, runs first
     │
     ▼
  [network]       ← depends on apis (needs compute API enabled)
     │
     ▼
  [gke]           ← depends on network (needs VPC, subnet)
```

The `apis` module has no dependency blocks — it is the root of the graph.

---

## Verification for this step

After `terragrunt apply` in `infra/live/vault/apis/`:

```bash
# All 5 APIs should be enabled
gcloud services list --project $GCP_PROJECT_ID --enabled \
  | grep -E "compute|container|iam|cloudresource|servicenetwork"

# Expected output (5 lines):
# cloudresourcemanager.googleapis.com
# compute.googleapis.com
# container.googleapis.com
# iam.googleapis.com
# servicenetworking.googleapis.com
```

State is saved to:
```
gs://<bucket>/vault/apis/terraform.tfstate
```

Inspect it with:
```bash
gcloud storage cat gs://$TF_STATE_BUCKET/vault/apis/terraform.tfstate
```
