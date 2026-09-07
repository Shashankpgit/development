# API reference

Base URL (local): `http://localhost:8000`
Interactive, always-current docs: `http://localhost:8000/docs`

| File | Resource |
|---|---|
| [health.md](./health.md) | Liveness and readiness probes |
| [categories.md](./categories.md) | `/api/categories` |
| [products.md](./products.md) | `/api/products` |
| [users.md](./users.md) | `/api/users` |
| [cart.md](./cart.md) | `/api/cart` |
| [orders.md](./orders.md) | `/api/orders` |

## Conventions used everywhere

- Request and response bodies are JSON. Sending a body without
  `Content-Type: application/json` gets a `422`.
- Timestamps are ISO-8601 UTC, e.g. `2026-09-07T18:30:00Z`.
- `PUT` accepts a **partial** body: fields you omit are left unchanged.
  Fields you send as `null` are set to null. This is a deliberate
  (documented) deviation from strict REST, for the benefit of the UI.

## Status codes

| Code | Meaning here |
|---|---|
| `200` | OK |
| `201` | Created |
| `204` | Success, empty body (all deletes except orders) |
| `400` | A referenced id does not exist, or the request makes no sense |
| `404` | No resource with that id |
| `409` | Valid request, conflicts with current state (duplicate, in use, out of stock) |
| `422` | Body failed schema validation — `detail` is an array of field errors |
| `503` | `/health/ready` only: the database is unreachable |

## Error shape

```json
{ "detail": "Product 42 not found" }
```

Validation errors (`422`) instead return an array:

```json
{
  "detail": [
    { "loc": ["body", "price"], "msg": "Input should be greater than 0",
      "type": "greater_than" }
  ]
}
```
