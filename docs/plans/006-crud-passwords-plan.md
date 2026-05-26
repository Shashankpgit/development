# 006 — Passwords CRUD

---

## Part 1: What we are doing

**Goal:** Build CRUD for stored password entries. Passwords are encrypted before being saved to the database and decrypted on retrieval. The encryption key lives in `.env`.

### Files being created / modified
```
vault/app/utils/__init__.py         ← new: makes utils a package
vault/app/utils/crypto.py           ← new: encrypt / decrypt helpers
vault/app/models/password_entry.py  ← new: PasswordEntry SQLAlchemy model
vault/app/schemas/password_entry.py ← new: request/response schemas
vault/app/routers/passwords.py      ← new: 5 endpoints
vault/app/models/__init__.py        ← modified: import PasswordEntry
vault/app/main.py                   ← modified: register passwords router
vault/requirements.txt              ← modified: add cryptography
vault/.env.example                  ← modified: add VAULT_ENCRYPTION_KEY
docs/api/passwords.md               ← updated: full endpoint documentation
```

### The table being created
```
password_entries
├── id               INTEGER, primary key, auto-increment
├── user_id          INTEGER, foreign key → users.id
├── label            VARCHAR(100), not null  (e.g. "Gmail", "GitHub")
├── username         VARCHAR(100), not null  (the username for that service)
├── encrypted_value  TEXT, not null          (the password, encrypted)
├── created_at       TIMESTAMP, default = now
└── updated_at       TIMESTAMP, default = now, updates on change
```

### Endpoints
| Method | Path | Description |
|---|---|---|
| `POST` | `/passwords` | Store a new password (encrypted) |
| `GET` | `/passwords?user_id=1` | List entries — value NOT included |
| `GET` | `/passwords/{id}` | Get single entry WITH decrypted value |
| `PUT` | `/passwords/{id}` | Update (re-encrypts if value changes) |
| `DELETE` | `/passwords/{id}` | Delete |

### What is NOT done in this step
- No auth guard (Phase 4)
- No key rotation
- No tags

---

## Part 2: Concepts / KT

### Hashing vs Encryption — the critical distinction

This is the most important concept in this step.

| | Hashing | Encryption |
|---|---|---|
| Direction | One-way — cannot be reversed | Two-way — can be decrypted |
| Algorithm | bcrypt, SHA256 | AES, Fernet |
| Use case | Login passwords | Secrets you need to read back |
| Example | Your Vault login password | Your Gmail password stored in Vault |

Your Vault login password is **hashed** — the server never needs to know the original, it just checks if what you typed matches the hash.

Your Gmail password stored inside the Vault is **encrypted** — you need to read it back in full when you open your vault. Hashing it would make it permanently unreadable.

Same word "password", completely different treatment.

### Fernet symmetric encryption
Fernet is a symmetric encryption scheme from the `cryptography` library. One key encrypts and decrypts. The key must be:
- Exactly 32 bytes
- URL-safe base64 encoded
- Generated using `Fernet.generate_key()` — not made up by hand

Generate one for your `.env`:
```bash
python3 -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
```

### Why the key must live in `.env`
The deliberate mistake in this step shows exactly what happens when it doesn't — a new random key is generated every server restart. Any previously encrypted values become permanently unreadable. In production, losing the key = losing all stored passwords.

### Two response schemas for passwords
- `PasswordListResponse` — used in `GET /passwords?user_id=1`. No `value` field. You don't return the password on every list call — only when specifically requested.
- `PasswordDetailResponse` — used in `GET /passwords/{id}`. Includes the decrypted `value`.

This is a real-world API design principle: return the minimum data needed for each context.
