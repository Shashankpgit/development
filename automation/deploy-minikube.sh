#!/usr/bin/env bash
# ============================================================================
# One-command local deploy: Postgres + backend + frontend on minikube.
#
#   ./deploy-minikube.sh            # build images + install/upgrade all three
#   ./deploy-minikube.sh --no-build # skip the image builds
#
# Three SEPARATE Helm releases, deployed in dependency order. They are separate
# so each can be upgraded and rolled back on its own.
# ============================================================================
set -euo pipefail

NS="${NS:-shop}"
API_TAG="${API_TAG:-1.0.1}"
WEB_TAG="${WEB_TAG:-1.0.0}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHARTS="$ROOT/automation/helmcharts"
BUILD=true
[[ "${1:-}" == "--no-build" ]] && BUILD=false

step() { printf '\n\033[1;35m▸ %s\033[0m\n' "$1"; }

step "checking minikube"
minikube status >/dev/null 2>&1 || { echo "minikube is not running: minikube start"; exit 1; }

if $BUILD; then
  step "building images INSIDE minikube's Docker daemon"
  # This is the trick that removes the need for a registry entirely: point the
  # local docker CLI at the cluster node's own daemon, so the image it builds
  # is already where kubelet will look for it. Requires the docker driver.
  eval "$(minikube docker-env)"
  docker build --provenance=false -q -t "shop-api:${API_TAG}" "$ROOT/development/back-end"
  docker build --provenance=false -q -t "shop-web:${WEB_TAG}" "$ROOT/development/front-end"
  docker images --format '{{.Repository}}:{{.Tag}}  {{.Size}}' | grep '^shop-'
fi

step "namespace $NS"
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -

# --- 1. Postgres FIRST -----------------------------------------------------
# The API's readiness probe checks the database, so starting it first means
# the API is Ready as soon as it boots instead of flapping while it waits.
step "1/3  postgresql (vendored Bitnami chart)"
helm upgrade --install shop-db "$CHARTS/postgresql" -n "$NS" \
  -f "$CHARTS/values/postgresql-minikube.yaml" --wait --timeout 10m

# --- 2. Backend ------------------------------------------------------------
# It reads the password from the Secret the Postgres chart just created, so it
# has to come second.
step "2/3  shop-api"
helm upgrade --install shop-api "$CHARTS/shop-api" -n "$NS" \
  -f "$CHARTS/values/shop-api-minikube.yaml" \
  --set "image.tag=${API_TAG}" --wait --timeout 5m

# --- 3. Frontend -----------------------------------------------------------
step "3/3  shop-web"
helm upgrade --install shop-web "$CHARTS/shop-web" -n "$NS" \
  -f "$CHARTS/values/shop-web-minikube.yaml" \
  --set "image.tag=${WEB_TAG}" --wait --timeout 5m

step "releases"
helm list -n "$NS"
step "pods"
kubectl get pods -n "$NS"

cat <<EOF

▸ Open the app:
    kubectl port-forward -n $NS svc/shop-web 8080:80
    then browse http://localhost:8080

▸ API docs (through nginx):
    http://localhost:8080/docs   -- or port-forward svc/shop-api 8000:8000

▸ Verify all 24 endpoints:
    ./automation/test/smoke-test.sh $NS
EOF
