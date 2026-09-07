# Users

Contact records. There is **no authentication** in this app: no passwords, no
tokens, no login. Auth is a separate topic with its own hazards (hashing,
sessions, refresh) and mixing it into a CRUD exercise would blur both. The
frontend picks "who you are" from a dropdown instead.

## Object

```json
{
  "id": 1,
  "full_name": "Asha Rao",
  "email": "asha@example.com",
  "phone": "+91-9800000001",
  "address": "12 MG Road, Bengaluru 560001",
  "created_at": "2026-09-07T18:30:00Z"
}
```

## POST /api/users — create

| Field | Type | Required | Notes |
|---|---|---|---|
| `full_name` | string | yes | 1–120 chars |
| `email` | string | yes | validated format, **unique** |
| `phone` | string \| null | no | max 20 |
| `address` | string \| null | no | max 300, used as the default shipping address |

```bash
curl -X POST http://localhost:8000/api/users \
  -H 'Content-Type: application/json' \
  -d '{"full_name":"Asha Rao","email":"asha@example.com",
       "address":"12 MG Road, Bengaluru 560001"}'
```

`201` with the created object.

| Error | Cause |
|---|---|
| `409` | `Email asha@example.com is already used` |
| `422` | Malformed email (`"abc"`), or `full_name` empty |

## GET /api/users — list

`200` with an array, ordered by `id`.

## GET /api/users/{id} — read one

`200` with the object · `404` `User 9 not found`

## PUT /api/users/{id} — update

Partial body.

```bash
curl -X PUT http://localhost:8000/api/users/1 \
  -H 'Content-Type: application/json' -d '{"phone":"+91-9800000009"}'
```

`200` updated · `404` unknown id · `409` new email already used · `422` malformed email

## DELETE /api/users/{id} — delete

```bash
curl -i -X DELETE http://localhost:8000/api/users/1
```

`204` empty body.

| Error | Cause |
|---|---|
| `404` | Unknown id |
| `409` | `Cannot delete a user who has orders. Cancel or reassign them first.` |

**Why the cart is deleted but orders block deletion:** a cart is disposable
working state, so it cascades away automatically. Orders are financial records
— silently destroying them to make a `DELETE` succeed is the kind of
convenience that ends up in an audit finding.
