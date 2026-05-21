# API — Password Entries

Stored passwords for external services. Values are encrypted at rest.

---

## Endpoints

| Method | Path | Description | Auth required |
|---|---|---|---|
| `POST` | `/passwords` | Store a new password | Phase 4+ |
| `GET` | `/passwords?user_id=1` | List entries — value NOT included | Phase 4+ |
| `GET` | `/passwords/{id}` | Get single entry WITH decrypted value | Phase 4+ |
| `PUT` | `/passwords/{id}` | Update an entry | Phase 4+ |
| `DELETE` | `/passwords/{id}` | Delete an entry | Phase 4+ |

---

### POST /passwords

Encrypts the value before saving. Response never includes the value.

**Auth required:** No (until Phase 4)

#### Request body
```json
{
  "user_id": 1,
  "label": "GitHub",
  "username": "bob",
  "value": "mysecret123"
}
```

#### Response — 201 Created (`PasswordListResponse`)
```json
{
  "id": 1,
  "user_id": 1,
  "label": "GitHub",
  "username": "bob",
  "created_at": "...",
  "updated_at": "..."
}
```
> `value` is intentionally absent — it was encrypted and stored, not echoed back.

#### curl
```bash
curl -s -X POST http://localhost:8000/passwords \
  -H "Content-Type: application/json" \
  -d '{"user_id": 1, "label": "GitHub", "username": "bob", "value": "mysecret123"}' | jq
```

---

### GET /passwords

List all entries for a user. Passwords are never included in list responses.

**Auth required:** No (until Phase 4)

#### Query parameter
| Parameter | Type | Required |
|---|---|---|
| `user_id` | integer | Yes |

#### Response — 200 OK (`PasswordListResponse[]`)
Array of entries without `value`.

#### curl
```bash
curl -s "http://localhost:8000/passwords?user_id=1" | jq
```

---

### GET /passwords/{id}

Returns the entry with the decrypted password value.

**Auth required:** No (until Phase 4)

#### Response — 200 OK (`PasswordDetailResponse`)
```json
{
  "id": 1,
  "user_id": 1,
  "label": "GitHub",
  "username": "bob",
  "created_at": "...",
  "updated_at": "...",
  "value": "mysecret123"
}
```
> `value` is only returned here — on explicit single-entry request.

#### curl
```bash
curl -s http://localhost:8000/passwords/1 | jq
```

---

### PUT /passwords/{id}

All fields optional. If `value` is included it will be re-encrypted.

#### Request body
```json
{
  "label": "GitHub (work)",
  "value": "newpassword"
}
```

#### curl
```bash
curl -s -X PUT http://localhost:8000/passwords/1 \
  -H "Content-Type: application/json" \
  -d '{"label": "GitHub (work)"}' | jq
```

---

### DELETE /passwords/{id}

#### Response — 204 No Content

#### curl
```bash
curl -s -X DELETE http://localhost:8000/passwords/1 -o /dev/null -w "%{http_code}\n"
```

---

## Notes

- Database always stores cipher text — raw passwords are never persisted
- `VAULT_ENCRYPTION_KEY` in `.env` must never change after data is stored — changing it makes all existing entries unreadable
- Generate the key once with: `python3 -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"`
