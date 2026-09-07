#!/usr/bin/env bash
# ============================================================================
# Tears the environment down. Run this at the end of a session -- the EKS
# control plane costs $0.10/hour whether or not anything is deployed on it.
#
#   source ./tf.sh
#   ./destroy.sh dev            # cluster only, keeps the VPC (default)
#   ./destroy.sh dev --all      # cluster AND VPC
#
# Destroying only the cluster is usually what you want: the VPC is free to
# keep, and re-provisioning skips straight to the cluster next time.
# ============================================================================
set -euo pipefail

ENV_DIR="${1:-dev}"
SCOPE="${2:-cluster-only}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACK="$HERE/$ENV_DIR"

step() { printf '\n\033[1;35m▸ %s\033[0m\n' "$1"; }

[[ -d "$STACK" ]] || { echo "no such environment: $ENV_DIR"; exit 1; }
: "${TF_STATE_BUCKET:?not set -- source ./tf.sh}"
: "${AWS_REGION:?not set -- source ./tf.sh}"
export TG_TF_PATH="${TG_TF_PATH:-tofu}"

echo "About to destroy: $ENV_DIR ($SCOPE)"
read -r -p "Type the environment name to confirm: " CONFIRM
[[ "$CONFIRM" == "$ENV_DIR" ]] || { echo "aborted"; exit 1; }

# Delete Kubernetes LoadBalancer Services and PVCs FIRST.
#
# WHY THIS MATTERS: those objects are created by controllers INSIDE the
# cluster, so Tofu has no idea they exist. Destroying the cluster without
# removing them leaves orphaned ELBs and EBS volumes that keep billing, and
# orphaned ENIs that then block the VPC from being deleted at all. This is the
# most common way a "destroyed" environment keeps charging you.
if kubectl cluster-info >/dev/null 2>&1; then
  step "removing in-cluster AWS resources (load balancers, volumes)"
  kubectl delete svc --all-namespaces --field-selector spec.type=LoadBalancer --ignore-not-found --timeout=180s || true
  kubectl delete pvc --all -n shop --ignore-not-found --timeout=180s || true
  echo "  giving AWS a moment to actually delete them..."
  sleep 30
else
  echo "  (kubectl cannot reach a cluster -- skipping in-cluster cleanup)"
fi

step "destroying eks"
cd "$STACK/eks" && terragrunt destroy -auto-approve

if [[ "$SCOPE" == "--all" ]]; then
  step "destroying network"
  cd "$STACK/network" && terragrunt destroy -auto-approve
else
  echo
  echo "▸ VPC kept (it costs nothing). Remove it too with:"
  echo "    ./destroy.sh $ENV_DIR --all"
fi

cat <<EOF

✔ done. Worth confirming nothing was left behind and is still billing:

    aws ec2 describe-volumes --region \$AWS_REGION \\
      --filters Name=status,Values=available --query 'Volumes[].VolumeId'
    aws elbv2 describe-load-balancers --region \$AWS_REGION --query 'LoadBalancers[].LoadBalancerName'
    aws eks list-clusters --region \$AWS_REGION

The S3 state bucket is deliberately NOT deleted -- it holds the history of
every apply, and it costs a few cents a month.
EOF
