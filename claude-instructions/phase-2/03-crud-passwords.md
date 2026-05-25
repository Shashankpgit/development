# Phase 2 — Step 3: CRUD for Password Entries

## What this step covers
Create the `PasswordEntry` model and full CRUD endpoints. Password values should be stored encrypted, not plaintext. This introduces the concept of encryption at rest.

---

## Pre-step checklist (Claude must do before any code)

- [ ] Create `docs/006-crud-passwords-plan.md` first
- [ ] Explain the difference between hashing and encryption, and why passwords stored in the vault need encryption (not hashing)

---

## Why this step exists

The Vault's second core feature is storing passwords for other services. This step:
- Repeats the CRUD pattern (reinforcing it)
- Introduces a critical security distinction: stored passwords must be *recoverable* (encryption), while login passwords must NOT be (hashing)
- Introduces `cryptography` library and Fernet symmetric encryption

The user needs to understand: storing your Gmail password in the Vault is different from storing your Vault login password. One must be read back; one must never be.

---

## What to implement

### `app/models/password_entry.py`
```
class PasswordEntry:
    id: int (PK)
    user_id: int (FK → users.id)
    label: str (e.g., "Gmail", "GitHub")
    username: str (the username for that service)
    encrypted_value: str (the actual password, encrypted)
    created_at: datetime
    updated_at: datetime
```

### Encryption utility: `app/utils/crypto.py`
- Use `cryptography` library (Fernet symmetric encryption)
- `VAULT_ENCRYPTION_KEY` comes from `.env`
- `encrypt(value: str) → str`
- `decrypt(value: str) → str`

### `app/schemas/password_entry.py`
- `PasswordEntryCreate`: `user_id`, `label`, `username`, `value` (plain — will be encrypted)
- `PasswordEntryUpdate`: `label`, `username`, `value` (all optional)
- `PasswordEntryResponse`: `id`, `user_id`, `label`, `username`, `created_at` — NOTE: **do NOT include the password value in list responses**
- `PasswordEntryDetailResponse`: includes `value` (decrypted) — returned only on `GET /passwords/{id}`

### `app/routers/passwords.py`
| Method | Path | Action |
|---|---|---|
| POST | /passwords | Store a new password (encrypt before save) |
| GET | /passwords?user_id=1 | List entries (no decrypted value) |
| GET | /passwords/{id} | Get single entry with decrypted value |
| PUT | /passwords/{id} | Update (re-encrypt if value changed) |
| DELETE | /passwords/{id} | Delete |

---

## Concepts to teach during this step

- **Hashing vs Encryption**:
  - Hashing: one-way, cannot be reversed (bcrypt for passwords you verify). Used for login passwords.
  - Encryption: two-way, can be decrypted with a key (Fernet). Used for secrets you need to read back.
  - "Your Vault login password is hashed. Your Gmail password stored in the Vault is encrypted. Same word 'password', completely different treatment."

- **Fernet symmetric encryption**: One key encrypts and decrypts. The key must be kept secret (in `.env`, never committed).

- **Key management**: In v1, the key lives in `.env`. In production, this would be a secrets manager (AWS Secrets Manager, Vault by HashiCorp). Note this for Phase 12+.

- **Never return sensitive data in list endpoints**: List of passwords should show label + username, NOT the actual password value. This is a real-world API design principle.

- **`VAULT_ENCRYPTION_KEY` rotation**: If the key changes, all existing encrypted values become unreadable. Brief mention — don't solve it now.

---

## What NOT to do in this step

- Do NOT implement key rotation
- Do NOT add tags or categories
- Do NOT build frontend
- Do NOT guard by user auth yet (that's Phase 4)

---

## File changes

| File | Action |
|---|---|
| `app/models/password_entry.py` | Create |
| `app/models/__init__.py` | Modify — import PasswordEntry |
| `app/schemas/password_entry.py` | Create |
| `app/utils/crypto.py` | Create |
| `app/routers/passwords.py` | Create |
| `app/main.py` | Modify — include passwords router |
| `requirements.txt` | Modify — add `cryptography` |
| `.env.example` | Modify — add `VAULT_ENCRYPTION_KEY=` |

---

## Success criteria

1. `POST /passwords` with `{"user_id": 1, "label": "GitHub", "username": "bob", "value": "mysecret"}` → stores encrypted value in DB
2. Run `psql $DATABASE_URL -c "SELECT * FROM password_entries;"` → `encrypted_value` column shows gibberish (cipher text), NOT "mysecret"
3. `GET /passwords/1` → response includes `"value": "mysecret"` (decrypted)
4. `GET /passwords?user_id=1` → response does NOT include `value` field
5. `DELETE /passwords/1` → gone
