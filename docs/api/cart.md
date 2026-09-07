# Cart

One row per (user, product) pair. There is **no `carts` table** — a cart *is*
the set of cart items belonging to a user. A parent row would be extra state to
keep consistent for no benefit.

Note the path shapes: item operations live under `/api/cart/items`, while
reading a whole cart is `/api/cart/{userId}`.

## Objects

Cart item — `subtotal` is computed on read, never stored, so it cannot drift
from the price it is derived from:

```json
{
  "id": 3,
  "user_id": 1,
  "product_id": 2,
  "quantity": 2,
  "product": { "id": 2, "name": "Pulse Wireless Earbuds", "price": 129.99, "…": "…" },
  "subtotal": 259.98
}
```

## POST /api/cart/items — add a product

| Field | Type | Required | Notes |
|---|---|---|---|
| `user_id` | integer | yes | must exist |
| `product_id` | integer | yes | must exist |
| `quantity` | integer | no | default `1`, must be > 0 |

```bash
curl -X POST http://localhost:8000/api/cart/items \
  -H 'Content-Type: application/json' \
  -d '{"user_id":1,"product_id":2,"quantity":2}'
```

`201` with the cart item.

**Adding a product already in the cart increments the existing row** rather
than creating a second one — a cart listing "Earbuds ×1" twice is a bug users
notice immediately. A `UNIQUE(user_id, product_id)` constraint enforces this at
the database level too.

| Error | Cause |
|---|---|
| `400` | `User 9 does not exist` / `Product 9 does not exist` |
| `409` | `Only 3 unit(s) of 'Pulse Wireless Earbuds' in stock` |
| `422` | `quantity` ≤ 0 |

## GET /api/cart/{userId} — read the whole cart

```bash
curl http://localhost:8000/api/cart/1
```

```json
{
  "user_id": 1,
  "items": [ { "…": "…" } ],
  "total_items": 3,
  "total_amount": 389.97
}
```

`200` · `404` only if the **user** does not exist.

**An empty cart is `200` with `items: []`, not a 404.** "You have nothing in
your cart" is a successful answer; a 404 would force the UI to treat a normal
empty state as an error.

## PUT /api/cart/items/{id} — set the quantity

Sets an **absolute** quantity — `PUT` replaces, it does not add.

```bash
curl -X PUT http://localhost:8000/api/cart/items/3 \
  -H 'Content-Type: application/json' -d '{"quantity":5}'
```

`200` with the updated item · `404` `Cart item 3 not found` ·
`409` more than available stock · `422` `quantity` ≤ 0

## DELETE /api/cart/items/{id} — remove an item

```bash
curl -i -X DELETE http://localhost:8000/api/cart/items/3
```

`204` empty body · `404` unknown item id

## Implementation note: route order

Within the router, `/items` paths are declared **before** `/{user_id}`.
FastAPI matches top to bottom, and `items` also fits the `{user_id}` pattern —
declared the other way round, `/api/cart/items` would try to parse `"items"` as
an integer and fail with a confusing `422`. Literal paths before dynamic ones.
