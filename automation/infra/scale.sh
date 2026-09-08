#!/usr/bin/env bash
# ============================================================================
# Scale the node group down to 0 between sessions and back up when needed.
#
#   ./scale.sh dev          # show current state
#   ./scale.sh dev 0        # scale to 0 nodes  (stops EC2 charges)
#   ./scale.sh dev 1        # scale to 1 node   (waits until it is Ready)
#
# WHAT THIS SAVES, honestly:
#
#   EC2 (1x t3.medium SPOT)   ~$0.0125/hr  ~$9/month   <- SAVED at 0 nodes
#   Node root EBS (20GB gp3)  ~$1.60/month             <- SAVED (deleted with the instance)
#   EKS CONTROL PLANE          $0.10/hr    ~$73/month  <- STILL BILLED at 0 nodes
#   Postgres PVC (8GB gp3)    ~$0.64/month             <- STILL BILLED (that is the point)
#   ---------------------------------------------------------------------
#   scaling to 0 saves  ~$11/month of a ~$84/month bill  (~13%)
#   ./destroy.sh saves  ~$84/month                       (~100%)
#
# So this is for "I'll be back tomorrow" -- it keeps your cluster, your Helm
# releases and your database contents intact. If you are done for more than a
# few days, ./destroy.sh is the far bigger saving.
#
# Uses the AWS API directly rather than tofu, because it is instant and
# because modules/eks has ignore_changes on desired_size -- so the next
# `tofu apply` will NOT undo whatever you set here.
# ============================================================================
set -euo pipefail

ENV_DIR="${1:-dev}"
WANT="${2:-}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACK="$HERE/$ENV_DIR"

[[ -d "$STACK" ]] || { echo "no such environment: $ENV_DIR"; exit 1; }

if [[ -f "$HERE/tf.sh" ]]; then
  # shellcheck source=/dev/null
  source "$HERE/tf.sh"
fi
: "${AWS_REGION:?not set -- run ./create_tf_backend.sh $ENV_DIR first}"

PREFIX=$(yq -r '.global.name_prefix' "$STACK/global-values.yaml")
CLUSTER="${PREFIX}-eks"
NODEGROUP="${PREFIX}-ng"

current() {
  aws eks describe-nodegroup \
    --cluster-name "$CLUSTER" --nodegroup-name "$NODEGROUP" \
    --region "$AWS_REGION" \
    --query 'nodegroup.{status:status,desired:scalingConfig.desiredSize,min:scalingConfig.minSize,max:scalingConfig.maxSize}' \
    --output json 2>/dev/null
}

STATE=$(current) || {
  echo "Cannot read nodegroup '$NODEGROUP' on cluster '$CLUSTER' in $AWS_REGION."
  echo "Has it been provisioned?  ./provision.sh $ENV_DIR"
  exit 1
}

echo "▸ cluster   : $CLUSTER"
echo "▸ nodegroup : $NODEGROUP"
echo "▸ current   : $(echo "$STATE" | jq -c .)"

# No target given -> report only. Showing the nodes too, because "desired: 1"
# and "one Ready node" are not the same thing.
if [[ -z "$WANT" ]]; then
  echo
  kubectl get nodes 2>/dev/null || echo "(kubectl cannot reach the cluster -- 0 nodes, or kubeconfig not set)"
  echo
  echo "Usage: ./scale.sh $ENV_DIR 0   |   ./scale.sh $ENV_DIR 1"
  exit 0
fi

[[ "$WANT" =~ ^[0-9]+$ ]] || { echo "node count must be a number, got '$WANT'"; exit 1; }

MIN=$(echo "$STATE" | jq -r .min)
MAX=$(echo "$STATE" | jq -r .max)

# Fail with an explanation instead of letting AWS return a bare
# InvalidParameterException.
if (( WANT < MIN )); then
  echo
  echo "Refusing: desired ($WANT) is below the node group's min_size ($MIN)."
  echo "AWS rejects this. Set eks_node_count_min: $WANT in"
  echo "  $STACK/global-values.yaml"
  echo "then apply it:  cd $STACK/eks && terragrunt apply"
  exit 1
fi
if (( WANT > MAX )); then
  echo
  echo "Refusing: desired ($WANT) is above max_size ($MAX). Raise"
  echo "eks_node_count_max in $STACK/global-values.yaml and apply."
  exit 1
fi

echo
echo "▸ scaling to $WANT node(s)..."
aws eks update-nodegroup-config \
  --cluster-name "$CLUSTER" --nodegroup-name "$NODEGROUP" \
  --scaling-config "minSize=${MIN},maxSize=${MAX},desiredSize=${WANT}" \
  --region "$AWS_REGION" \
  --query 'update.{id:id,status:status}' --output json

if (( WANT == 0 )); then
  cat <<EOF

✔ scaling down. Takes a couple of minutes to drain and terminate.

What happens to your app: every pod becomes Pending. Nothing is deleted --
the Deployments, StatefulSet, Services and the Postgres PersistentVolumeClaim
all survive, so you do NOT need to reinstall the Helm releases. When you
scale back up, pods reschedule and the database volume reattaches with its
data intact.

Still billing: the control plane (~\$0.10/hr) and the Postgres volume.
Come back with:  ./scale.sh $ENV_DIR 1
EOF
else
  echo
  echo "  waiting for the node group to finish updating..."
  # ACTIVE only means AWS finished its update -- the kubelet may still be
  # joining, so wait for a Ready node too.
  aws eks wait nodegroup-active \
    --cluster-name "$CLUSTER" --nodegroup-name "$NODEGROUP" --region "$AWS_REGION"

  echo "  waiting for a Ready node (SPOT capacity can take a moment)..."
  kubectl wait --for=condition=Ready nodes --all --timeout=600s 2>/dev/null || {
    echo "  no node Ready yet. If this persists, SPOT capacity may be unavailable"
    echo "  for this instance type in this AZ. Check:"
    echo "    kubectl get nodes"
    echo "    aws eks describe-nodegroup --cluster-name $CLUSTER --nodegroup-name $NODEGROUP --region $AWS_REGION --query 'nodegroup.health'"
  }

  echo
  kubectl get nodes -o wide 2>/dev/null || true
  echo
  echo "  pods rescheduling (give them a minute):"
  kubectl get pods -n shop 2>/dev/null || echo "  (namespace 'shop' not deployed yet)"
fi
