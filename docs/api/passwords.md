# API — Password Entries

Stored passwords for external services (Gmail, GitHub, etc.).

> **Added in:** Phase 2 Step 3
> This file will be filled in when Phase 2 Step 3 is implemented.

---

## Endpoints

| Method | Path | Description | Auth |
|---|---|---|---|
| `POST` | `/passwords` | Store a new password | Phase 4+ |
| `GET` | `/passwords` | List entries (no values shown) | Phase 4+ |
| `GET` | `/passwords/{id}` | Get single entry with decrypted value | Phase 4+ |
| `PUT` | `/passwords/{id}` | Update an entry | Phase 4+ |
| `DELETE` | `/passwords/{id}` | Delete an entry | Phase 4+ |
