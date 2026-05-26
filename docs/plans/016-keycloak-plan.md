# Phase 9 — Keycloak Plan

## Part 1: What we are doing

Replacing our custom JWT auth with Keycloak as the Identity Provider. Kong will verify all tokens using Keycloak's public key. FastAPI will only handle business logic.

## Part 2: What changes

| Before | After |
|---|---|
| FastAPI issues JWTs | Keycloak issues JWTs |
| FastAPI verifies JWTs | Kong verifies JWTs using Keycloak's public key |
| FastAPI stores passwords (hashed) | Keycloak stores passwords |
| Custom `/auth/login`, `/auth/register` | Keycloak login page + OIDC flow |
| Users table has password field | Users table has only `sub` + app data |

## Part 3: Architecture

```
Browser → Nginx :80
              ├── /           → React static files
              └── /api/*      → Kong :8000
                                    └── FastAPI :8000

Browser → Keycloak :8080  (login page, token issuance)

Kong Admin API → Keycloak JWKS endpoint (fetch public key once)
```

## Part 4: New services in docker-compose

| Service | Purpose |
|---|---|
| `keycloak` | Identity Provider — login, token issuance |
| `keycloak-db` | PostgreSQL for Keycloak's own data |

## Part 5: Steps

### Step 1 — Add Keycloak to docker-compose
- `keycloak-db` service (postgres for Keycloak)
- `keycloak` service (image: quay.io/keycloak/keycloak:24.0)
- Expose port 8080 on the host (for browser access to Keycloak admin console)

### Step 2 — Configure Keycloak (via admin console in browser)
- Create realm: `vault`
- Create client: `vault-frontend` (public, OIDC)
- Create a test user with password
- Assign `user` role

### Step 3 — Configure Kong JWT plugin
- Fetch Keycloak's JWKS URI
- Add Kong `jwt` plugin to the vault-api route
- Configure it to verify tokens against Keycloak's public key

### Step 4 — Update FastAPI
- Remove auth router (`/auth/login`, `/auth/register`)
- Remove auth middleware (JWT verification)
- Remove `passlib`, `bcrypt`, `python-jose` from requirements
- Update User model — remove `hashed_password` field
- Read `sub` from token header (Kong passes it after verification)

### Step 5 — Update frontend
- Replace login form with redirect to Keycloak login page
- Handle the callback (exchange code for tokens)
- Store tokens, attach Access Token to every API request

### Step 6 — Test end to end
- Login through Keycloak
- Verify Kong rejects requests without a valid token (401)
- Verify authenticated requests reach FastAPI

## Part 6: Keycloak environment variables

| Variable | Value |
|---|---|
| `KEYCLOAK_ADMIN` | admin |
| `KEYCLOAK_ADMIN_PASSWORD` | (from .env) |
| `KC_DB` | postgres |
| `KC_DB_URL` | jdbc:postgresql://keycloak-db:5432/keycloak |
| `KC_DB_USERNAME` | keycloak |
| `KC_DB_PASSWORD` | (from .env) |
| `KC_HOSTNAME` | localhost |
