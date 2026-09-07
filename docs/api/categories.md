# Categories

A grouping for products. `name` is unique.

## Object

```json
{
  "id": 1,
  "name": "Electronics",
  "description": "Phones, laptops and gadgets",
  "created_at": "2026-09-07T18:30:00Z"
}
```

## POST /api/categories — create

| Field | Type | Required | Notes |
|---|---|---|---|
| `name` | string | yes | 1–80 chars, unique |
| `description` | string \| null | no | max 255 |

```bash
curl -X POST http://localhost:8000/api/categories \
  -H 'Content-Type: application/json' \
  -d '{"name":"Electronics","description":"Phones, laptops and gadgets"}'
```

`201` with the created object.

| Error | Cause |
|---|---|
| `409` | `Category 'Electronics' already exists` |
| `422` | `name` missing or empty |

## GET /api/categories — list

```bash
curl http://localhost:8000/api/categories
```

`200` with an array, ordered by `id`. An empty catalogue returns `[]`, not a 404.

## GET /api/categories/{id} — read one

```bash
curl http://localhost:8000/api/categories/1
```

`200` with the object · `404` `Category 9 not found`

## PUT /api/categories/{id} — update

Partial body. Omitted fields are unchanged.

```bash
curl -X PUT http://localhost:8000/api/categories/1 \
  -H 'Content-Type: application/json' \
  -d '{"description":"Consumer electronics and accessories"}'
```

`200` with the updated object · `404` unknown id · `409` new name already taken

## DELETE /api/categories/{id} — delete

```bash
curl -i -X DELETE http://localhost:8000/api/categories/1
```

`204` with an empty body.

| Error | Cause |
|---|---|
| `404` | Unknown id |
| `409` | `Cannot delete a category that still has products assigned to it` |

**Why 409 rather than cascade-deleting the products:** deleting data the caller
never mentioned is how people lose catalogues. Reassign or delete the products
first — the refusal is the feature.
