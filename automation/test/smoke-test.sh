#!/usr/bin/env bash
# ============================================================================
# End-to-end smoke test for all 24 CRUD endpoints.
#
# Deliberately runs through the FRONTEND's nginx (port 8080 -> shop-web:80),
# not directly against the API. That exercises the whole chain the browser
# uses -- nginx reverse proxy -> API Service -> Postgres -- so a broken
# BACKEND_URL is caught here rather than by a user.
#
#   ./smoke-test.sh [namespace]
# ============================================================================
set -uo pipefail

NS="${1:-shop}"
PORT="${PORT:-18080}"
BASE="http://localhost:${PORT}"

# Every created record carries this stamp in its name. WHY: a test that only
# passes on an empty database is not a test you can trust -- it fails the
# second time you run it, or when a previous run left something behind.
STAMP=$(date +%s)

pass=0; fail=0
# `set -e` is NOT used: we want every check to run and report, not stop at the
# first failure.

cleanup() { [[ -n "${PF_PID:-}" ]] && kill "$PF_PID" 2>/dev/null; }
trap cleanup EXIT

echo "▸ port-forward svc/shop-web -> localhost:${PORT}"
kubectl port-forward -n "$NS" svc/shop-web "${PORT}:80" >/dev/null 2>&1 &
PF_PID=$!

# Wait for the tunnel instead of a fixed sleep -- a fixed sleep is either too
# short (flaky) or too long (slow).
for _ in $(seq 1 40); do
  curl -sf "${BASE}/nginx-health" >/dev/null 2>&1 && break
  sleep 0.25
done

# check <name> <expected-status> <curl args...>
check() {
  local name="$1" want="$2"; shift 2
  local got
  got=$(curl -s -o /tmp/st_body -w '%{http_code}' "$@")
  if [[ "$got" == "$want" ]]; then
    printf '  \033[32m✓\033[0m %-46s %s\n' "$name" "$got"
    pass=$((pass+1))
  else
    printf '  \033[31m✗\033[0m %-46s got %s want %s\n' "$name" "$got" "$want"
    echo "      $(head -c 300 /tmp/st_body)"
    fail=$((fail+1))
  fi
}
# Reads a field out of the last response body. Prints nothing (rather than a
# traceback) if the previous request failed, so one failure does not bury the
# rest of the output in Python stack traces.
jqid() { python3 -c "
import json
try:    print(json.load(open('/tmp/st_body'))$1)
except Exception: print('')
"; }
J=(-H 'Content-Type: application/json')

echo
echo "── health ────────────────────────────────────────────────────"
check "GET  /nginx-health (frontend itself)" 200 "${BASE}/nginx-health"
check "GET  / (SPA index.html)"              200 "${BASE}/"
check "GET  /orders (SPA fallback route)"    200 "${BASE}/orders"
check "GET  /health (proxied to API)"        200 "${BASE}/health"
check "GET  /health/ready (API + Postgres)"  200 "${BASE}/health/ready"

echo
echo "── categories ────────────────────────────────────────────────"
check "POST   /api/categories" 201 "${J[@]}" -X POST "${BASE}/api/categories" \
  -d "{\"name\":\"Smoke Gear ${STAMP}\",\"description\":\"created by smoke-test.sh\"}"
CAT=$(jqid "['id']")
check "POST   /api/categories (duplicate -> 409)" 409 "${J[@]}" -X POST "${BASE}/api/categories" \
  -d "{\"name\":\"Smoke Gear ${STAMP}\"}"
check "GET    /api/categories" 200 "${BASE}/api/categories"
check "GET    /api/categories/{id}" 200 "${BASE}/api/categories/${CAT}"
check "GET    /api/categories/999999 (-> 404)" 404 "${BASE}/api/categories/999999"
check "PUT    /api/categories/{id}" 200 "${J[@]}" -X PUT "${BASE}/api/categories/${CAT}" \
  -d '{"description":"updated by smoke-test.sh"}'

echo
echo "── products ──────────────────────────────────────────────────"
check "POST   /api/products" 201 "${J[@]}" -X POST "${BASE}/api/products" \
  -d "{\"name\":\"Smoke Widget ${STAMP}\",\"price\":19.99,\"stock\":5,\"category_id\":${CAT}}"
PROD=$(jqid "['id']")
check "POST   /api/products (price<=0 -> 422)" 422 "${J[@]}" -X POST "${BASE}/api/products" \
  -d '{"name":"Free Widget","price":0}'
check "POST   /api/products (bad category -> 400)" 400 "${J[@]}" -X POST "${BASE}/api/products" \
  -d '{"name":"Orphan","price":5,"category_id":999999}'
check "GET    /api/products" 200 "${BASE}/api/products"
check "GET    /api/products?search=" 200 "${BASE}/api/products?search=Smoke+Widget"
check "GET    /api/products/{id}" 200 "${BASE}/api/products/${PROD}"
check "GET    /api/products/999999 (-> 404)" 404 "${BASE}/api/products/999999"
check "PUT    /api/products/{id}" 200 "${J[@]}" -X PUT "${BASE}/api/products/${PROD}" \
  -d '{"price":24.99,"stock":8}'
check "DELETE /api/categories/{id} (in use -> 409)" 409 -X DELETE "${BASE}/api/categories/${CAT}"

echo
echo "── users ─────────────────────────────────────────────────────"
check "POST   /api/users" 201 "${J[@]}" -X POST "${BASE}/api/users" \
  -d "{\"full_name\":\"Smoke Tester\",\"email\":\"smoke-${STAMP}@example.com\",\"address\":\"1 Test Lane\"}"
USER=$(jqid "['id']")
check "POST   /api/users (dup email -> 409)" 409 "${J[@]}" -X POST "${BASE}/api/users" \
  -d "{\"full_name\":\"Copy\",\"email\":\"smoke-${STAMP}@example.com\"}"
check "POST   /api/users (bad email -> 422)" 422 "${J[@]}" -X POST "${BASE}/api/users" \
  -d '{"full_name":"Bad","email":"not-an-email"}'
check "GET    /api/users" 200 "${BASE}/api/users"
check "GET    /api/users/{id}" 200 "${BASE}/api/users/${USER}"
check "GET    /api/users/999999 (-> 404)" 404 "${BASE}/api/users/999999"
check "PUT    /api/users/{id}" 200 "${J[@]}" -X PUT "${BASE}/api/users/${USER}" \
  -d '{"phone":"+91-90000-00000"}'

echo
echo "── cart ──────────────────────────────────────────────────────"
check "POST   /api/cart/items" 201 "${J[@]}" -X POST "${BASE}/api/cart/items" \
  -d "{\"user_id\":${USER},\"product_id\":${PROD},\"quantity\":2}"
ITEM=$(jqid "['id']")
check "POST   /api/cart/items (same product increments)" 201 "${J[@]}" -X POST "${BASE}/api/cart/items" \
  -d "{\"user_id\":${USER},\"product_id\":${PROD},\"quantity\":1}"
QTY=$(jqid "['quantity']")
if [[ "$QTY" == "3" ]]; then
  printf '  \033[32m✓\033[0m %-46s qty=3 (2+1, one row)\n' "       incremented, did not duplicate"; pass=$((pass+1))
else
  printf '  \033[31m✗\033[0m %-46s qty=%s want 3\n' "       incremented, did not duplicate" "$QTY"; fail=$((fail+1))
fi
check "POST   /api/cart/items (over stock -> 409)" 409 "${J[@]}" -X POST "${BASE}/api/cart/items" \
  -d "{\"user_id\":${USER},\"product_id\":${PROD},\"quantity\":999}"
check "GET    /api/cart/{userId}" 200 "${BASE}/api/cart/${USER}"
check "GET    /api/cart/999999 (no user -> 404)" 404 "${BASE}/api/cart/999999"
check "PUT    /api/cart/items/{id}" 200 "${J[@]}" -X PUT "${BASE}/api/cart/items/${ITEM}" \
  -d '{"quantity":2}'
check "DELETE /api/cart/items/{id}" 204 -X DELETE "${BASE}/api/cart/items/${ITEM}"
check "DELETE /api/cart/items/{id} (gone -> 404)" 404 -X DELETE "${BASE}/api/cart/items/${ITEM}"

echo
echo "── orders ────────────────────────────────────────────────────"
check "POST   /api/orders (empty cart -> 400)" 400 "${J[@]}" -X POST "${BASE}/api/orders" \
  -d "{\"user_id\":${USER}}"
# refill the cart, then check out
curl -s "${J[@]}" -X POST "${BASE}/api/cart/items" \
  -d "{\"user_id\":${USER},\"product_id\":${PROD},\"quantity\":2}" >/dev/null
check "POST   /api/orders (checkout from cart)" 201 "${J[@]}" -X POST "${BASE}/api/orders" \
  -d "{\"user_id\":${USER}}"
ORDER=$(jqid "['id']")
# the cart must now be empty -- checkout is transactional
check "GET    /api/cart/{userId} (emptied by checkout)" 200 "${BASE}/api/cart/${USER}"
LEFT=$(jqid "['total_items']")
if [[ "$LEFT" == "0" ]]; then
  printf '  \033[32m✓\033[0m %-46s total_items=0\n' "       cart cleared transactionally"; pass=$((pass+1))
else
  printf '  \033[31m✗\033[0m %-46s total_items=%s want 0\n' "       cart cleared transactionally" "$LEFT"; fail=$((fail+1))
fi
check "POST   /api/orders (buy now, explicit items)" 201 "${J[@]}" -X POST "${BASE}/api/orders" \
  -d "{\"user_id\":${USER},\"items\":[{\"product_id\":${PROD},\"quantity\":1}]}"
ORDER2=$(jqid "['id']")
check "GET    /api/orders" 200 "${BASE}/api/orders"
check "GET    /api/orders?user_id=&status=" 200 "${BASE}/api/orders?user_id=${USER}&status=pending"
check "GET    /api/orders/{id}" 200 "${BASE}/api/orders/${ORDER}"
check "GET    /api/orders/999999 (-> 404)" 404 "${BASE}/api/orders/999999"
check "PUT    /api/orders/{id} (-> paid)" 200 "${J[@]}" -X PUT "${BASE}/api/orders/${ORDER}" \
  -d '{"status":"paid"}'
check "PUT    /api/orders/{id} (bad status -> 400)" 400 "${J[@]}" -X PUT "${BASE}/api/orders/${ORDER}" \
  -d '{"status":"teleported"}'
check "DELETE /api/orders/{id} (soft cancel -> 200)" 200 -X DELETE "${BASE}/api/orders/${ORDER}"
check "DELETE /api/orders/{id} (again, idempotent)" 200 -X DELETE "${BASE}/api/orders/${ORDER}"
check "GET    /api/orders/{id} (still readable)" 200 "${BASE}/api/orders/${ORDER}"
check "DELETE /api/users/{id} (has orders -> 409)" 409 -X DELETE "${BASE}/api/users/${USER}"

echo
echo "── cleanup ───────────────────────────────────────────────────"
curl -s -X DELETE "${BASE}/api/orders/${ORDER2}" >/dev/null
check "DELETE /api/products/{id}" 204 -X DELETE "${BASE}/api/products/${PROD}"
check "DELETE /api/categories/{id} (now unused)" 204 -X DELETE "${BASE}/api/categories/${CAT}"

echo
echo "═══════════════════════════════════════════════════════════════"
printf '  passed: \033[32m%d\033[0m   failed: \033[31m%d\033[0m\n' "$pass" "$fail"
echo "═══════════════════════════════════════════════════════════════"
[[ "$fail" -eq 0 ]]
