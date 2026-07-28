Absolutely. Here's a **minimal but real-world** SOPS setup that you can keep as a reference while learning.

## Project Structure

```text
my-project/
│
├── .sops.yaml
├── secrets.yaml
└── values.yaml
```

---

## 1. `.sops.yaml`

This tells SOPS **which public key(s) to use** when encrypting files.

```yaml
creation_rules:
  - path_regex: .*secrets.*\.yaml$
    age: age1vevksdrpr6l8zc3rssvkp96f8mzmwmhr6hcsfq5fugz0scundg0q7ve9hg
```

### If multiple developers need access

```yaml
creation_rules:
  - path_regex: .*secrets.*\.yaml$
    age: >
      age1shashankpublickeyxxxxxxxxxxxxxxxxxxxxxxxx,
      age1alicepublickeyxxxxxxxxxxxxxxxxxxxxxxxxxxx,
      age1bobpublickeyxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

---

## 2. `secrets.yaml` (Before Encryption)

```yaml
database:
  username: admin
  password: my-secret-password

redis:
  password: redis-password

api:
  token: super-secret-token
```

---

## 3. Encrypt the file

```bash
sops -e -i secrets.yaml
```

After encryption it will look similar to this (shortened):

```yaml
database:
    username: ENC[AES256_GCM,data:...,iv:...,tag:...,type:str]
    password: ENC[AES256_GCM,data:...,iv:...,tag:...,type:str]

redis:
    password: ENC[AES256_GCM,data:...,iv:...,tag:...,type:str]

api:
    token: ENC[AES256_GCM,data:...,iv:...,tag:...,type:str]

sops:
    age:
        - recipient: age1vevksdrpr6l8zc3rssvkp96f8mzmwmhr6hcsfq5fugz0scundg0q7ve9hg
          enc: |
            -----BEGIN AGE ENCRYPTED FILE-----
            ...
            -----END AGE ENCRYPTED FILE-----
    mac: ENC[AES256_GCM,data:...]
    version: 3.10.x
```

> **Never edit the encrypted `ENC[...]` values manually.** Always use `sops secrets.yaml`.

---

# Common Commands

## Generate an age key pair

```bash
age-keygen -o ~/.config/sops/age/keys.txt
```

Get your public key:

```bash
grep "public key" ~/.config/sops/age/keys.txt
```

---

## Encrypt

```bash
sops -e -i secrets.yaml
```

---

## Edit (decrypts temporarily)

```bash
sops secrets.yaml
```

---

## Decrypt and print to the terminal

```bash
sops -d secrets.yaml
```

---

## Decrypt to another file

```bash
sops -d secrets.yaml > secrets.dec.yaml
```

---

## TO add and update the new developer

1. Ask for the age public key from the new developer and run this command

```bash
sops updatekeys -y cred.yaml
```

# What happens internally?

```text
             secrets.yaml
                  │
                  ▼
      Generate Random AES Key (DEK)
                  │
        ┌─────────┴─────────┐
        ▼                   ▼
 AES encrypts secrets   age encrypts DEK
        │                   │
        └─────────┬─────────┘
                  ▼
      Encrypted YAML + Metadata
```

During decryption:

```text
Encrypted DEK
      │
      ▼
age Private Key
      │
      ▼
Recovered AES Key
      │
      ▼
AES decrypts secrets
      │
      ▼
Plaintext YAML
```

---

# Team Workflow

```text
Developer A
├── Public Key
└── Private Key

Developer B
├── Public Key
└── Private Key

                │
                ▼

           .sops.yaml
                │
                ▼

      Encrypt DEK for A
      Encrypt DEK for B
                │
                ▼

        Same encrypted secrets
```

Each developer uses **their own private key** to recover the **same AES key**, which decrypts the secrets.

---

# Quick Revision Cheat Sheet

| Item                   | Purpose                                                               |
| ---------------------- | --------------------------------------------------------------------- |
| `age-keygen`           | Generate age public/private key pair                                  |
| `keys.txt`             | Stores both your public and private key (keep the private key secret) |
| `.sops.yaml`           | Defines which recipient(s) SOPS should encrypt for                    |
| `secrets.yaml`         | Your plaintext or encrypted secrets file                              |
| `sops -e -i file.yaml` | Encrypt the file in place                                             |
| `sops file.yaml`       | Open the file decrypted in your editor, then re-encrypt on save       |
| `sops -d file.yaml`    | Decrypt and print to stdout                                           |
| **AES (DEK)**          | Encrypts the actual secret values (fast, symmetric)                   |
| **age**                | Encrypts the AES Data Encryption Key (DEK) using public/private keys  |
| **SOPS**               | Coordinates everything and stores the metadata                        |

This is the reference structure I would recommend keeping nearby while you practice. It's intentionally minimal but follows the same concepts you'll use in real Kubernetes and GitOps projects.
