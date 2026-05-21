# Phase 9 — Step 1: Keycloak (Replace Custom JWT)

## What this step covers
Replace the custom JWT auth system (built in Phase 4) with Keycloak — an open-source Identity and Access Management (IAM) system. Keycloak becomes the single source of truth for users and authentication.

---

## Pre-step checklist (Claude must do before any code)

- [ ] Create `docs/016-keycloak-plan.md` first
- [ ] Explain what IAM is and WHY custom JWT is not enough for production
- [ ] This is a significant architectural change — explain the before/after clearly

---

## Why this step exists

The custom JWT system in Phase 4 works, but it's a toy compared to what real applications need:
- No MFA (multi-factor authentication) support
- No social login (Google, GitHub)
- No fine-grained roles and permissions
- No token revocation
- No audit logs
- No user management UI
- Security vulnerabilities require you to patch your own code

Keycloak provides all of this out of the box. It's used at enterprise scale (Red Hat, banks, government systems). Learning Keycloak means you can implement SSO at any company.

---

## Architecture after this phase

```
Client
  ↓
Kong (API gateway)
  ↓
Keycloak (auth decisions) ←→ FastAPI (business logic)
  ↓
FastAPI (validates token from Keycloak)
  ↓
PostgreSQL
```

Flow:
1. User opens frontend → redirected to Keycloak login page
2. User logs in on Keycloak → Keycloak issues an OIDC token
3. Frontend sends token to FastAPI
4. FastAPI validates token against Keycloak's public key (JWKS endpoint)
5. FastAPI trusts the token — no custom JWT code needed

---

## What to implement

### Keycloak in docker-compose
- Service: `keycloak` (official image)
- Admin credentials via env vars
- Port: 8080 (internal; expose only for dev access)

### Keycloak Realm setup
- Create realm: `vault`
- Create client: `vault-app` (for the frontend)
- Configure redirect URIs: `http://localhost`

### FastAPI: Replace custom JWT validation
- Remove `app/utils/jwt_utils.py` (custom JWT)
- Add OIDC token validation using Keycloak's JWKS endpoint
- `app/dependencies/auth.py` now validates Keycloak tokens (not self-signed tokens)

### Frontend: Replace login form
- Replace custom login form with Keycloak's login page
- Use Keycloak JS adapter (or redirect flow)

### Migrate users
- Existing users in the vault DB need to match Keycloak users
- Options: re-register via Keycloak, or import (explain both)

---

## Concepts to teach during this step

- **IAM (Identity and Access Management)**: The discipline of managing who can access what. Keycloak is an IAM system.

- **OIDC (OpenID Connect)**: An identity layer on top of OAuth2. Adds "who you are" (ID token) on top of OAuth2's "what you're allowed to do" (access token).

- **OAuth2**: An authorization framework. A bit complex — simplify: "It's a standard way for users to grant apps access to their account without sharing passwords."

- **Realm**: Keycloak's namespace for tenants. You could have one realm per product, or per environment (dev/staging/prod).

- **Client**: In Keycloak, your frontend app is a "client" that requests tokens on behalf of the user.

- **JWKS endpoint**: Keycloak publishes its public keys at a JWKS URL. Any service can verify Keycloak-signed tokens without asking Keycloak for each request.

- **Why replace custom JWT**: The security burden of managing keys, expiry, revocation, and rotation is non-trivial. Keycloak handles this so you don't have to.

- **SSO (Single Sign-On)**: One Keycloak login works across multiple applications. If you add a second service later, users don't need a second account.

---

## What NOT to do in this step

- Do NOT implement Keycloak's full admin features (roles, groups, policies — save for later)
- Do NOT delete the custom JWT code until Keycloak is fully working
- Do NOT expose the Keycloak admin port publicly

---

## File changes

| File | Action |
|---|---|
| `docker-compose.yml` | Modify — add keycloak service |
| `app/utils/jwt_utils.py` | Delete (after Keycloak works) |
| `app/utils/security.py` | Keep — still used for password migration |
| `app/dependencies/auth.py` | Modify — validate Keycloak tokens via JWKS |
| `app/config.py` | Modify — add KEYCLOAK_URL, REALM, CLIENT_ID |
| `frontend/` | Modify — replace login form with Keycloak redirect |

---

## Success criteria

1. `docker-compose up` → Keycloak admin at `http://localhost:8080`
2. Register a user in Keycloak admin → can log in from the frontend
3. FastAPI validates the Keycloak token (not a custom-signed token)
4. `GET /api/notes` with Keycloak token → 200 OK
5. `GET /api/notes` with old custom token → 401 Unauthorized (tokens are incompatible)
