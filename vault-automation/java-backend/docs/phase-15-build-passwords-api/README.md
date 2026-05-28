# Phase 15 — Build: Passwords API
## "AES-256 encryption + password entries CRUD"

> Goal: store encrypted passwords using Java's built-in javax.crypto.
> Functionally identical to the Python version using Fernet.

---

## What Gets Built

```
db/migration/
  V3__create_password_entries_table.sql

com/vaultapp/passwords/
  PasswordEntry.java              ← @Entity
  PasswordEntryRepository.java
  PasswordEntryService.java       ← encryption/decryption here
  PasswordEntryController.java
  PasswordEntryCreateRequest.java
  PasswordEntryResponse.java      ← never includes raw password
  EncryptionService.java          ← AES-256-GCM operations
```

---

## Migration: V3__create_password_entries_table.sql

```sql
CREATE TABLE password_entries (
    id             BIGSERIAL    PRIMARY KEY,
    label          VARCHAR(255) NOT NULL,
    username       VARCHAR(255),
    encrypted_value TEXT        NOT NULL,   -- AES-256-GCM encrypted
    user_id        BIGINT       NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at     TIMESTAMP    NOT NULL DEFAULT NOW(),
    updated_at     TIMESTAMP    NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_password_entries_user_id ON password_entries(user_id);
```

---

## EncryptionService

Java ships AES-256-GCM in the JDK. No external library needed.

```java
@Service
public class EncryptionService {
    
    private final SecretKeySpec keySpec;
    
    public EncryptionService(@Value("${app.encryption-key}") String base64Key) {
        byte[] keyBytes = Base64.getDecoder().decode(base64Key);
        if (keyBytes.length != 32) {
            throw new IllegalArgumentException("Encryption key must be 32 bytes (AES-256)");
        }
        this.keySpec = new SecretKeySpec(keyBytes, "AES");
    }
    
    public String encrypt(String plaintext) {
        try {
            // Generate a random 12-byte IV (initialisation vector) — unique per encryption
            byte[] iv = new byte[12];
            new SecureRandom().nextBytes(iv);
            
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.ENCRYPT_MODE, keySpec, new GCMParameterSpec(128, iv));
            
            byte[] encrypted = cipher.doFinal(plaintext.getBytes(StandardCharsets.UTF_8));
            
            // Prepend IV to encrypted data: [iv (12 bytes)][encrypted data]
            byte[] combined = new byte[iv.length + encrypted.length];
            System.arraycopy(iv, 0, combined, 0, iv.length);
            System.arraycopy(encrypted, 0, combined, iv.length, encrypted.length);
            
            return Base64.getEncoder().encodeToString(combined);
            
        } catch (Exception e) {
            throw new RuntimeException("Encryption failed", e);
        }
    }
    
    public String decrypt(String encryptedBase64) {
        try {
            byte[] combined = Base64.getDecoder().decode(encryptedBase64);
            
            // Split IV and encrypted data
            byte[] iv = Arrays.copyOfRange(combined, 0, 12);
            byte[] encrypted = Arrays.copyOfRange(combined, 12, combined.length);
            
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.DECRYPT_MODE, keySpec, new GCMParameterSpec(128, iv));
            
            byte[] decrypted = cipher.doFinal(encrypted);
            return new String(decrypted, StandardCharsets.UTF_8);
            
        } catch (Exception e) {
            throw new RuntimeException("Decryption failed", e);
        }
    }
}
```

### AES-GCM vs Python Fernet

Python Fernet uses AES-128-CBC with HMAC-SHA256.  
Java version uses AES-256-GCM — more modern (authenticated encryption, no separate HMAC).  
The keys are not compatible, but the security level is similar or better.

GCM (Galois/Counter Mode):
- Authenticated encryption — detects tampering
- No padding needed — works on any length
- Random IV per encryption — same plaintext → different ciphertext every time

---

## PasswordEntryResponse — Never Return the Raw Password

```java
public record PasswordEntryResponse(
    Long id,
    String label,
    String username,
    // password field intentionally omitted — never send encrypted blob to client
    LocalDateTime createdAt
) {}
```

The encrypted value stays in the database. When the user wants the password:

```java
@GetMapping("/{id}/reveal")
public RevealResponse reveal(@PathVariable Long id, @CurrentUser User user) {
    return passwordEntryService.revealPassword(id, user.getId());
}

public record RevealResponse(String password) {}
```

---

## Deliverable

```bash
TOKEN="your-jwt"

# Create
curl -X POST -H "Authorization: Bearer $TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"label":"GitHub","username":"shashank","password":"my-github-password"}' \
     localhost:8000/api/passwords

# List — no passwords in response
curl -H "Authorization: Bearer $TOKEN" localhost:8000/api/passwords
# [{"id":1,"label":"GitHub","username":"shashank","createdAt":"..."}]

# Reveal one password
curl -H "Authorization: Bearer $TOKEN" localhost:8000/api/passwords/1/reveal
# {"password":"my-github-password"}
```
