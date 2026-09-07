# Orders

The only endpoints in the app with real business logic. Creating an order does
three things — writes the order, decrements stock, empties the cart — inside a
**single transaction**. Either all three happen or none do.

## Objects

`order_items` stores a **snapshot** of the product name and unit price:

```json
{
  "id": 1,
  "user_id": 1,
  "status": "pending",
  "total_amount": 1229.99,
  "shipping_address": "12 MG Road, Bengaluru 560001",
  "created_at": "2026-09-07T18:30:00Z",
  "items": [
    { "id": 1, "product_id": 1, "product_name": "Aurora Laptop 14",
      "unit_price": 1099.0, "quantity": 1 }
  ]
}
```

**Why copy the name and price instead of just `product_id`:** prices and names
change. An invoice that silently rewrites itself when a product is renamed is a
real bug, not a hypothetical one.

It also means order history survives the product being deleted entirely:
`product_id` is nullable with `ON DELETE SET NULL`, so deleting a product
clears the reference (`"product_id": null`) and **keeps the line**, with
`product_name` and `unit_price` still describing what was bought. See
[`docs/003`](../003-minikube-deployment-and-debugging.md) — getting this wrong
produced a `500` that SQLite had been hiding.

## Statuses

`pending` → `paid` → `shipped` → `delivered`, plus `cancelled`.

`delivered` and `cancelled` are **final** — any attempt to change them returns
`409`. A free-text status column would eventually hold `"Shipped"`, `"shiped"`
and `"SHIPPED"`, and every report built on it would lie.

## POST /api/orders — create

Two ways to order, one code path:

| Body | Behaviour |
|---|---|
| `items` **omitted** | Checkout: build the order from the user's cart, then **empty the cart** |
| `items` **provided** | "Buy now": order exactly those lines, cart untouched |

| Field | Type | Required | Notes |
|---|---|---|---|
| `user_id` | integer | yes | must exist |
| `shipping_address` | string \| null | no | falls back to the user's `address` |
| `items` | array \| null | no | `[{ "product_id": 1, "quantity": 2 }]` |

Checkout from the cart:

```bash
curl -X POST http://localhost:8000/api/orders \
  -H 'Content-Type: application/json' -d '{"user_id":1}'
```

Buy now:

```bash
curl -X POST http://localhost:8000/api/orders \
  -H 'Content-Type: application/json' \
  -d '{"user_id":1,"items":[{"product_id":1,"quantity":1}],
       "shipping_address":"5 Marine Drive, Kochi 682011"}'
```

`201` with the created order, `status: "pending"`, `total_amount` computed
server-side (never trusted from the client).

| Error | Cause |
|---|---|
| `400` | `User 9 does not exist` / `Product 9 does not exist` / `Cart is empty — add items or pass them in the request body` |
| `409` | `Only 2 unit(s) of 'Aurora Laptop 14' in stock` |
| `422` | `quantity` ≤ 0 |

Because every check happens before the single `commit()`, a `409` on the third
line of a five-line order leaves stock and the cart completely untouched.

## GET /api/orders — list

| Query param | Effect |
|---|---|
| `user_id` | Only that user's orders |
| `status` | Only orders in that status |

```bash
curl 'http://localhost:8000/api/orders?user_id=1&status=pending'
```

`200` with an array, **newest first**.

## GET /api/orders/{id} — read one

`200` with the order · `404` `Order 42 not found`

## PUT /api/orders/{id} — update

Only `status` and `shipping_address` are editable.

**Why the line items are not:** `total_amount` and product stock were already
derived from them. Editing them would mean re-running all of that arithmetic;
in a real system you cancel and re-order instead.

```bash
curl -X PUT http://localhost:8000/api/orders/1 \
  -H 'Content-Type: application/json' -d '{"status":"paid"}'
```

`200` with the updated order.

| Error | Cause |
|---|---|
| `400` | `status must be one of: cancelled, delivered, paid, pending, shipped` |
| `404` | Unknown id |
| `409` | `Order 1 is already 'delivered' and cannot change` |

Setting `status` to `cancelled` here **returns the stock**, exactly as `DELETE`
does.

## DELETE /api/orders/{id} — cancel

```bash
curl -X DELETE http://localhost:8000/api/orders/1
```

This is a **soft delete**: the row is not removed. The status becomes
`cancelled`, stock is returned to every product in the order, and the order
stays readable — so a cancelled order still appears in `GET /api/orders`.

Note this endpoint returns **`200` with the cancelled order**, not `204` with an
empty body like the other deletes. That is deliberate: the resource still
exists, so there is something to return.

**Why not really delete it:** orders are history. A shop that forgets a
cancelled order cannot answer "why was I refunded?".

| Response | When |
|---|---|
| `200` | Cancelled — or already cancelled, which is **idempotent**, not an error |
| `404` | Unknown id |
| `409` | `A delivered order cannot be cancelled` |
