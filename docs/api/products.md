# Products

## Object

`category` is embedded so a UI can render "Laptop — Electronics" from a single
request instead of fetching every category separately.

```json
{
  "id": 1,
  "name": "Aurora Laptop 14",
  "description": "14-inch ultrabook, 16GB RAM",
  "price": 1099.0,
  "stock": 12,
  "image_url": "https://…",
  "category_id": 1,
  "created_at": "2026-09-07T18:30:00Z",
  "category": { "id": 1, "name": "Electronics", "description": "…",
                "created_at": "2026-09-07T18:30:00Z" }
}
```

## POST /api/products — create

| Field | Type | Required | Notes |
|---|---|---|---|
| `name` | string | yes | 1–120 chars |
| `price` | number | yes | **must be > 0** |
| `stock` | integer | no | default `0`, must be ≥ 0 |
| `description` | string \| null | no | max 500 |
| `image_url` | string \| null | no | max 500 |
| `category_id` | integer \| null | no | must exist if given |

```bash
curl -X POST http://localhost:8000/api/products \
  -H 'Content-Type: application/json' \
  -d '{"name":"Aurora Laptop 14","price":1099.00,"stock":12,"category_id":1}'
```

`201` with the created object.

| Error | Cause |
|---|---|
| `400` | `Category 99 does not exist` |
| `422` | `price` ≤ 0, negative `stock`, or `name` empty |

## GET /api/products — list

| Query param | Effect |
|---|---|
| `category_id` | Only products in that category |
| `search` | Case-insensitive substring match on `name` |

```bash
curl 'http://localhost:8000/api/products?category_id=1&search=laptop'
```

`200` with an array, ordered by `id`.

## GET /api/products/{id} — read one

`200` with the object · `404` `Product 42 not found`

## PUT /api/products/{id} — update

Partial body.

```bash
curl -X PUT http://localhost:8000/api/products/1 \
  -H 'Content-Type: application/json' -d '{"price":999.00,"stock":20}'
```

`200` updated · `400` unknown `category_id` · `404` unknown id · `422` invalid price

## DELETE /api/products/{id} — delete

```bash
curl -i -X DELETE http://localhost:8000/api/products/1
```

`204` empty body · `404` unknown id

**Side effects:**

- The product is removed from every cart containing it — a cart row pointing at
  a deleted product would break every cart read.
- **Order history is kept.** `order_items.product_id` is nullable with
  `ON DELETE SET NULL`, so the database clears the reference and the line
  survives; `product_name` and `unit_price` were copied at purchase time
  exactly so the invoice stays readable. Those duplicated columns are the whole
  reason this works.
