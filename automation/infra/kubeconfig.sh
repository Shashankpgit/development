#!/usr/bin/env bash
# ============================================================================
# Point kubectl at the cluster.
#
#   ./kubeconfig.sh dev               # merge into ~/.kube/config (usual case)
#   ./kubeconfig.sh dev --standalone  # write a separate file instead
#
# provision.sh already does this as its step 3, so you only need this when you
# ran terragrunt directly, or you are on a second machine, or your context got
# clobbered.
#
# WHAT "update-kubeconfig" ACTUALLY DOES: nothing is downloaded from the
# cluster. The AWS CLI builds the config locally from the cluster's endpoint
# and CA cert (both public API data) and writes a context into ~/.kube/config.
# There is no long-lived token in that file -- see the note at the bottom.
# ============================================================================
set -euo pipefail

ENV_DIR="${1:-dev}"
MODE="${2:-merge}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACK="$HERE/$ENV_DIR"

[[ -d "$STACK" ]] || { echo "no such environment: $ENV_DIR"; exit 1; }

if [[ -f "$HERE/tf.sh" ]]; then
  # shellcheck source=/dev/null
  source "$HERE/tf.sh"
fi
: "${AWS_REGION:?not set -- run ./create_tf_backend.sh $ENV_DIR first}"

CLUSTER="$(yq -r '.global.name_prefix' "$STACK/global-values.yaml")-eks"

aws eks describe-cluster --name "$CLUSTER" --region "$AWS_REGION" \
  --query 'cluster.status' --output text >/dev/null 2>&1 || {
  echo "Cluster '$CLUSTER' not found in $AWS_REGION."
  echo "Provision it first:  ./provision.sh $ENV_DIR"
  exit 1
}

if [[ "$MODE" == "--standalone" ]]; then
  # A separate file keeps this cluster out of ~/.kube/config entirely, which
  # is the safer habit once you juggle several clusters: you cannot fat-finger
  # `kubectl delete` against the wrong one if the wrong one is not in scope.
  OUT="$HERE/$ENV_DIR/kubeconfig-$CLUSTER.yaml"
  KUBECONFIG="$OUT" aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER"
  chmod 600 "$OUT"
  echo
  echo "✔ wrote $OUT"
  echo "  use it for one command:   KUBECONFIG=$OUT kubectl get nodes"
  echo "  or for the whole shell:   export KUBECONFIG=$OUT"
  echo
  echo "  (gitignored -- see .gitignore)"
  exit 0
fi

aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER"

echo
echo "▸ contexts now available (* = current):"
kubectl config get-contexts

echo
echo "▸ checking the connection..."
if kubectl version -o json 2>/dev/null | yq -r '.serverVersion.gitVersion' 2>/dev/null | grep -q .; then
  echo "  server: $(kubectl version -o json 2>/dev/null | yq -r '.serverVersion.gitVersion')"
  echo
  kubectl get nodes -o wide 2>/dev/null || echo "  no nodes yet (still joining, or scaled to 0)"
else
  cat <<EOF
  Could not reach the API server. Usual causes, in order:

  1. Your public IP is not in eks_public_access_cidrs
     (currently: $(yq -r '.global.eks_public_access_cidrs | join(", ")' "$STACK/global-values.yaml"))
     Your IP right now: \$(curl -s ifconfig.me)

  2. The cluster is still finishing creation. Check:
       aws eks describe-cluster --name $CLUSTER --region $AWS_REGION --query cluster.status

  3. Your AWS identity has no access entry on the cluster. The identity that
     ran 'tofu apply' gets cluster-admin automatically; a DIFFERENT identity
     needs granting explicitly:
       aws eks create-access-entry --cluster-name $CLUSTER --region $AWS_REGION \\
         --principal-arn <your-iam-arn> --type STANDARD
       aws eks associate-access-policy --cluster-name $CLUSTER --region $AWS_REGION \\
         --principal-arn <your-iam-arn> --access-scope type=cluster \\
         --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy
EOF
fi

cat <<EOF

Note on credentials: ~/.kube/config holds NO token for EKS. It stores an exec
plugin entry that shells out to 'aws eks get-token' on every kubectl call, so
access follows your live AWS credentials and expires with them. Two
consequences worth knowing:
  - the file is not a secret in the way a token-based kubeconfig would be
  - if your AWS session expires, kubectl fails too -- refresh AWS, not kubectl
EOF
