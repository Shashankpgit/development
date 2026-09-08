#!/usr/bin/env bash
# ============================================================================
# Provisions the VPC and the EKS cluster, then points kubectl at it.
#
#   ./create_tf_backend.sh dev    # once per AWS account (writes tf.sh)
#   ./provision.sh dev            # tf.sh is picked up automatically
#   ./provision.sh dev --plan     # review only, change nothing
#
# Order is network -> eks. Terragrunt derives that from the `dependency`
# block in _common/eks.hcl, so `run --all` gets it right without being told.
# ============================================================================
set -euo pipefail

ENV_DIR="${1:-dev}"
MODE="${2:-apply}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACK="$HERE/$ENV_DIR"

step() { printf '\n\033[1;35m▸ %s\033[0m\n' "$1"; }

[[ -d "$STACK" ]] || { echo "no such environment: $ENV_DIR"; exit 1; }

# tf.sh holds AWS_REGION and TF_STATE_BUCKET, written by create_tf_backend.sh.
#
# WHY SOURCE IT HERE instead of asking you to: `source` only sets variables in
# the shell that runs it, and `bash provision.sh` starts a NEW shell that
# inherits nothing. Making the script read its own config removes a whole
# class of "not set" error that has nothing to do with your infrastructure.
if [[ -f "$HERE/tf.sh" ]]; then
  # shellcheck source=/dev/null
  source "$HERE/tf.sh"
fi

# Checking these up front turns three separate confusing failures into one
# clear message.
: "${TF_STATE_BUCKET:?not set -- run ./create_tf_backend.sh $ENV_DIR first (it writes tf.sh)}"
: "${AWS_REGION:?not set -- run ./create_tf_backend.sh $ENV_DIR first (it writes tf.sh)}"
command -v terragrunt >/dev/null || { echo "terragrunt is required"; exit 1; }
command -v tofu       >/dev/null || { echo "opentofu is required"; exit 1; }
aws sts get-caller-identity >/dev/null 2>&1 || { echo "AWS credentials are not valid"; exit 1; }

# TG_TF_PATH tells terragrunt to shell out to `tofu` rather than `terraform`.
export TG_TF_PATH="${TG_TF_PATH:-tofu}"

CLUSTER=$(yq -r '.global.name_prefix' "$STACK/global-values.yaml")-eks

if [[ "$MODE" == "--plan" ]]; then
  step "planning the whole stack (nothing will change)"
  # This works before anything exists thanks to the mock_outputs in
  # _common/eks.hcl -- otherwise planning eks would fail on missing state.
  cd "$STACK" && terragrunt run --all plan
  exit 0
fi

step "1/3  network (VPC, subnets, internet gateway)"
cd "$STACK/network" && terragrunt apply -auto-approve

# The control plane takes ~10 minutes and the node group another ~3. That is
# normal, not a hang.
step "2/3  eks (control plane ~10min, nodes ~3min -- be patient)"
cd "$STACK/eks" && terragrunt apply -auto-approve

step "3/3  kubeconfig + gp3 StorageClass"
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER"

# Wait for nodes before applying anything: kubectl can reach the API server
# several minutes before a node is actually Ready.
echo "  waiting for nodes to become Ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=600s

# Applied here rather than in Tofu -- see the comment in dev/gp3-sc.yaml.
kubectl apply -f "$STACK/gp3-sc.yaml"

# EKS ships a gp2 class already marked default. Two default classes is an
# undefined state: a PVC that names no class may get either one. Demote gp2.
kubectl patch storageclass gp2 \
  -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}' \
  2>/dev/null || true

step "cluster is up"
kubectl get nodes -o wide
kubectl get storageclass

cat <<EOF

▸ Deploy the app onto it (same three charts as minikube, different values):

    kubectl create namespace shop

    helm upgrade --install shop-db  ../helmcharts/postgresql -n shop \\
      -f ../helmcharts/values/postgresql-eks.yaml --wait

    helm upgrade --install shop-api ../helmcharts/shop-api -n shop \\
      -f ../helmcharts/values/shop-api-eks.yaml --wait

    helm upgrade --install shop-web ../helmcharts/shop-web -n shop \\
      -f ../helmcharts/values/shop-web-eks.yaml --wait

▸ Open it:
    kubectl port-forward -n shop svc/shop-web 8080:80

▸ Verify:
    ../test/smoke-test.sh shop

▸ WHEN YOU ARE DONE FOR THE DAY -- the control plane bills \$0.10/hr idle:
    ./destroy.sh $ENV_DIR
EOF
