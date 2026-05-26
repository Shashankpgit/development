# KT — Keycloak and Identity Management

---

## Part 1: The Problem — What Happens Without an Identity Provider

### Every application builds auth from scratch

When you build a web application, you need:
- User registration
- Login with username + password
- Password hashing
- JWT or session token issuance
- Token validation on every request
- Password reset (email flow)
- Account lockout after failed attempts
- Two-factor authentication (2FA)
- "Remember me" / refresh tokens
- Logout and token invalidation

We built a version of this in Phase 4. It works. But now imagine your company grows.

### The multi-service problem

Your company now has:
- A main web app
- A mobile app
- An internal admin panel
- A reporting service
- A notification service
- A payment service

Every one of these needs authentication. You have two choices:

**Option A — Build auth in every service:**
```
Web App     → its own users table, JWT logic, password reset
Mobile App  → its own users table, JWT logic, password reset
Admin Panel → its own users table, JWT logic, password reset
...
```

Problems:
- You write the same auth code 6 times
- A security bug in your JWT logic is now in 6 places
- A user has 6 different passwords
- If you want to add 2FA, you add it 6 times
- If auth standards change, you update 6 codebases

**Option B — One central auth service, everything else trusts it:**
```
Web App  ─────────────────────┐
Mobile App  ──────────────────┤→ Central Auth Service → issues tokens
Admin Panel ──────────────────┤
Reporting   ──────────────────┘
```

Auth logic lives in one place. Every service trusts the tokens that central auth issues. This is what an **Identity Provider (IdP)** is.

---

## Part 2: Single Sign-On (SSO)

### What it is

SSO means: **log in once, access everything**.

You already experience this every day. Open Gmail in your browser — already logged in. Open Google Drive in a new tab — still logged in. Open YouTube — still logged in. You never entered your Google password three times. You entered it once and all three apps recognized you. That is SSO.

### How it works

```
You log in at Google (the Identity Provider)
    ↓
Google issues you a token
    ↓
You open Gmail   → Gmail asks Google "is this token valid?" → Yes → access granted
You open Drive   → Drive asks Google "is this token valid?" → Yes → access granted
You open YouTube → YouTube asks Google "is this token valid?" → Yes → access granted
```

Gmail, Drive, and YouTube do not manage auth themselves. They all trust Google as the single source of truth. They delegate auth entirely to Google. Google is their Identity Provider.

### The enterprise version

A large company — say a bank — has 10,000 employees and 200 internal tools: Slack, Jira, GitHub, the expense system, the HR system, the trading platform, the compliance dashboard, and so on.

**Without SSO:** employees log in 200 times a day with 200 different passwords. The IT team manages 200 separate user databases. When an employee leaves, someone has to go into 200 systems and disable their account manually.

**With SSO:** employees log in once in the morning to the company's Identity Provider (Keycloak, Okta, Active Directory). Every tool recognizes that single login. When an employee leaves, you disable their account in one place — and they instantly lose access to all 200 tools simultaneously.

This is why enterprises pay hundreds of thousands of dollars for identity management. It is not a nice-to-have — it is a security requirement.

### What this means for our vault app

Right now our vault app has no SSO. If we add a second service tomorrow — say an admin panel — that admin panel would need its own separate login, its own user table, completely isolated from vault.

With Keycloak:
```
Realm: vault
    ↑
Alice logs in once
    ↓
vault-frontend  → Alice is logged in
admin-panel     → Alice is already logged in (same token)
mobile-app      → Alice is already logged in (same token)
```

One login. Every service that trusts this Keycloak realm recognizes Alice without asking her to log in again.

---

## Part 3: The Protocols — OAuth 2.0 and OpenID Connect

Keycloak implements two protocols. They sound intimidating but the concepts are straightforward.

### OAuth 2.0 — Authorization (what are you allowed to do)

You use OAuth 2.0 every time you see "Login with Google" or "Connect your GitHub account."

Concrete example: you sign up on Canva. Canva asks "Can I access your Google Drive to import files?" You click Allow.

```
You → Google: "Canva is asking to read my Drive files. Allow?"
Google → You: "Confirmed. Here is a temporary code."
You → Canva: "Here is the code Google gave me."
Canva → Google: "Exchange this code for an access token."
Google → Canva: "Here is your access token."
Canva → Google Drive API: "Give me this user's files." (sends token)
Google Drive: "Token is valid. Here are the files."
```

You never gave Canva your Google password. Google issued a token that only allows Canva to read Drive files — not access your Gmail, not change your password. That is authorization — controlling exactly what is permitted.

**What OAuth 2.0 does NOT do:** at no point does Canva know who you are. It got a token that allows it to read Drive files. That token does not say "this is Alice, aged 28, email alice@gmail.com." OAuth 2.0 handles permissions only, not identity.

### OpenID Connect (OIDC) — Identity (who are you)

OIDC is built on top of OAuth 2.0. It adds one thing: it tells you who the user is.

OIDC introduces the **ID Token** — a JWT containing the user's identity:

```json
{
  "sub": "user-uuid-abc123",
  "email": "alice@gmail.com",
  "name": "Alice Smith",
  "iat": 1716000000,
  "exp": 1716003600
}
```

`sub` (subject) is the user's unique ID inside Keycloak. Your application uses this to associate data with a user.

**The hotel key card analogy:**

- OAuth 2.0 = a key card that opens room 204. The hotel does not care who you are — just that you have the right card. It is about access.
- OIDC = a key card that opens room 204, and your name is printed on it. Now the hotel knows both that you can access room 204 AND that you are Alice Smith.

**In summary:**

| Protocol | Question it answers | Token it issues |
|---|---|---|
| OAuth 2.0 | What are you allowed to do? | Access Token |
| OIDC (on top of OAuth 2.0) | Who are you? | ID Token + Access Token |

Keycloak implements both. When a user logs in, Keycloak issues all three tokens — Access Token, Refresh Token, and ID Token — in one single response.

---

## Part 4: Token Types

When Keycloak authenticates a user, it issues three tokens in a single response. Each has a different purpose and a different lifetime.

### Access Token — the entry pass

This is the token your React app sends to the API with every request. It is a JWT, short-lived — typically 15 minutes.

```
Authorization: Bearer eyJhbGciOiJSUzI1NiJ9...
```

Kong receives this, verifies the signature using Keycloak's public key, and if valid — forwards the request to FastAPI. FastAPI never sees an invalid request.

**Why 15 minutes?** If this token gets stolen — intercepted, leaked in a log, copied from memory — the attacker can only use it for at most 15 minutes. After that it is worthless. Short lifetime = small attack window.

### Refresh Token — the long-lived silent worker

Here is the problem with a 15-minute access token: the user would have to log in every 15 minutes. That is terrible UX.

The refresh token solves this. It is long-lived — typically 1 to 7 days — and is stored securely by the React app. When the access token expires, React silently does this in the background:

```
React → Keycloak: "My access token expired. Here is my refresh token."
Keycloak → React: "Valid. Here is a new access token."
```

The user never sees a login prompt. They just keep working. This is what "stay logged in" means in any real application.

**Why can't the access token just be long-lived?** If a 7-day access token gets stolen, the attacker has 7 days of access. If a 15-minute access token gets stolen, they have 15 minutes. The refresh token is stored more carefully and only ever sent to Keycloak — never to your API.

### ID Token — who is the user

This token is only used by the frontend. It contains the user's identity — name, email, roles — so React can display "Hello Alice" or show/hide UI elements based on role.

```json
{
  "sub": "uuid-of-alice-in-keycloak",
  "email": "alice@example.com",
  "name": "Alice Smith",
  "realm_access": {
    "roles": ["user"]
  }
}
```

**Important:** the ID Token is never sent to the API. It is for the frontend only. The API receives the Access Token, not the ID Token.

### How all three work together

```
Alice logs in
    ↓
Keycloak issues:
    Access Token  → expires in 15 min  → sent to API with every request
    Refresh Token → expires in 7 days  → stored securely, used to renew access token
    ID Token      → expires in 15 min  → used by React to know who Alice is

15 minutes pass → Access Token expires
    ↓
React silently sends Refresh Token to Keycloak
    ↓
Keycloak issues a new Access Token
    ↓
Alice never saw a login page. She just kept working.

7 days pass → Refresh Token expires
    ↓
Alice is asked to log in again
```

```
Login happens
    ↓
Keycloak issues:
    Access Token  (15 min)   → sent to APIs for every request
    Refresh Token (7 days)   → stored securely, used to renew access token
    ID Token      (15 min)   → used by frontend to know who the user is
```

---

## Part 6: What Keycloak Is

Keycloak is an **open-source Identity and Access Management (IAM) system** built by Red Hat. It is self-hosted — you run it on your own server, not as a SaaS. It implements OAuth 2.0 and OIDC.

### What it gives you out of the box — without writing a single line of code

| Feature | Our Current App | Keycloak |
|---|---|---|
| Login page | We built it (HTML form) | Keycloak provides it (customizable) |
| Password hashing | bcrypt in FastAPI | Keycloak handles it |
| User registration | We built the endpoint | Keycloak handles it |
| Password reset | Not implemented | Built in — sends email automatically |
| Two-factor auth (2FA) | Not implemented | Built in — Google Authenticator, SMS |
| Social login (Google, GitHub) | Not implemented | Built in — configure once |
| Brute force protection | Not implemented | Built in — locks account after X failed attempts |
| Token rotation | Not implemented | Built in — refresh token flow |
| Session management | Basic | Full session control per user |
| User management UI | Not built | Full admin console built in |
| Audit logs | Not implemented | Every login, logout, failed attempt logged |
| SSO across services | Not possible | Built in |

All of this disappears from our application code. FastAPI becomes purely business logic.

### What changes in our architecture

**Before Keycloak:**
```
React → our login form → POST /auth/login
                            → FastAPI verifies password
                            → FastAPI issues JWT with our own SECRET_KEY
                            → FastAPI validates JWT on every request
```

**After Keycloak:**
```
React → Keycloak login page → Keycloak verifies password
                            → Keycloak issues JWT signed with Keycloak's private key
                            → Kong validates JWT using Keycloak's public key
                            → FastAPI only reads the sub from the token
```

FastAPI never touches a password again. Never issues a token again. Never validates a token again. It just receives requests that Kong already verified and reads the user identity from the token.

### What we remove from FastAPI

- `passlib` and `bcrypt` — Keycloak hashes passwords
- `python-jose` — Keycloak issues tokens
- `/auth/login` and `/auth/register` endpoints — Keycloak owns these flows
- Auth middleware — Kong validates tokens now

### What stays in FastAPI

- Notes and passwords endpoints
- User model — storing only `sub` (Keycloak's UUID) and app-specific data
- All business logic

### Keycloak vs Auth0 / Okta

Keycloak = self-hosted, free, full control, you manage the infrastructure.
Auth0 / Okta = someone else hosts it, you pay per user, zero infrastructure work.

Companies choose Keycloak when data cannot leave their servers — government, healthcare, banking. Startups choose Auth0 when they want zero ops overhead.

---

## Part 7: Keycloak Core Concepts

These are the building blocks you configure inside Keycloak before your app can use it.

### Realm

An isolated namespace — a separate user pool. One Keycloak instance can run many realms, each completely separate from the others.

```
Keycloak instance
    ├── Realm: vault              ← our application's realm
    │       Users: alice, bob
    │       Clients: vault-frontend, vault-api
    │
    ├── Realm: another-app        ← completely separate, different users
    │       Users: charlie, dave
    │
    └── Realm: master             ← Keycloak's own admin realm — never use for apps
```

We create one realm: `vault`. Never use the `master` realm for your application — it is for Keycloak's own administration only.

### Client

An application registered with Keycloak. It tells Keycloak: "this app is allowed to request tokens."

We register two clients inside the `vault` realm:

**`vault-frontend`** — the React app. This is a **public client** — it runs in the browser where anyone can open DevTools and read the source code, so it cannot keep a secret. Public clients use PKCE instead of a client secret.

**`vault-api`** — FastAPI. This is a **confidential client** — it runs on a server and can keep a secret. Used when services need to verify tokens or talk to each other without a user involved.

Think of registering a client like registering your app with Google for "Login with Google" — you get a `client_id` that identifies your app to the identity provider.

### User

A person registered in Keycloak. Has a username, email, password, and custom attributes.

**Your application database no longer stores passwords.** Users and credentials live in Keycloak. FastAPI only stores the `sub` (Keycloak's UUID for the user) plus app-specific data.

```
Keycloak stores:    username, email, hashed password, 2FA settings
FastAPI DB stores:  sub (UUID from Keycloak), created_at, notes, passwords
```

Linked by the `sub` field.

### Role

A label that defines what a user is allowed to do.

```
Role: admin  → can access admin endpoints, manage other users
Role: user   → can access their own notes and passwords
```

Roles are embedded inside the Access Token by Keycloak:

```json
{
  "sub": "uuid-alice",
  "realm_access": {
    "roles": ["user"]
  }
}
```

Kong or FastAPI reads this from the token and decides what the user can do — without calling Keycloak again.

### Group

A collection of users. Assign a role to a group and every user in it inherits that role automatically.

```
Group: admins → has role: admin
    Alice in admins group → Alice has admin role
    Bob in admins group   → Bob has admin role
```

Without groups, you assign roles to 50 users one by one. With groups, you add them once. When someone leaves the admin team, remove them from the group — role revoked instantly across all services.

For our vault app: one role (`user`), no groups needed yet.

### How they all connect

```
Realm: vault
    │
    ├── Clients
    │       vault-frontend  (public — used by React)
    │       vault-api       (confidential — used by FastAPI)
    │
    ├── Users
    │       alice → role: user
    │       bob   → role: user
    │
    ├── Roles
    │       user
    │       admin
    │
    └── Groups
            admins → role: admin
```

---

## Part 5: The Login Flow (Authorization Code Flow)

This is where everything from Part 2, 3, and 4 connects. This is what happens from the moment a user clicks Login to the moment they see their data.

### Step 1 — User clicks Login

React does not show its own login form. It redirects the browser to Keycloak's login page.

```
Browser redirects to:
http://keycloak:8080/realms/vault/protocol/openid-connect/auth
    ?client_id=vault-frontend
    ?redirect_uri=http://localhost/callback
    ?response_type=code
```

The user is now on Keycloak's login page — not our app. Keycloak owns this page.

### Step 2 — User enters credentials on Keycloak

The user types username and password. Keycloak verifies them against its own database. Our FastAPI never sees the password. Our database never sees the password.

### Step 3 — Keycloak redirects back with a code

Keycloak redirects the browser back to our app with a short-lived authorization code in the URL:

```
http://localhost/callback?code=Xk9mP2qR7nL4
```

This code is NOT a token. It is a one-time throwaway code. It expires in seconds. It is useless on its own.

**Why not put the real tokens in the URL?**

When Keycloak redirects back to React, the URL passes through the browser's address bar. If tokens were in the URL, they would be sitting in:
- The browser's address bar — visible to anyone looking at the screen
- The browser history — stored permanently on disk
- Server access logs — every web server logs the full URL
- Browser extensions — some extensions read the current URL
- The Referer header — if the page loads any third-party resource, the token gets sent to those third parties automatically

The code is safe to put in the URL because it expires in 60 seconds, can only be used once, and is useless without the client credentials that only React knows.

The token exchange is a background POST request — like any API call. Tokens come back in the response body, directly into JavaScript memory. No URL bar. No browser history. No logs.

**The coat check analogy:** You hand over your jacket (password) at the counter. The attendant gives you a numbered chip (the code) — visible to everyone nearby, but useless on its own. You privately exchange the chip at the counter for your actual jacket (the token). The jacket never sat in the open where anyone could grab it.

### Step 4 — React exchanges the code for tokens

React reads the code from the URL and makes a background POST request to Keycloak — never visible in the URL bar:

```
POST http://keycloak:8080/realms/vault/protocol/openid-connect/token
Body:
    grant_type=authorization_code
    code=Xk9mP2qR7nL4
    client_id=vault-frontend
    redirect_uri=http://localhost/callback
```

Keycloak responds with all three tokens:

```json
{
  "access_token": "eyJhbGc...",
  "refresh_token": "eyJhbGc...",
  "id_token": "eyJhbGc...",
  "expires_in": 900
}
```

### Step 5 — React stores tokens. User is logged in.

React stores the tokens. It reads the ID Token to know the user's name and roles. It shows the dashboard.

### Step 6 — Every API call carries the Access Token

```
GET /api/notes/
Authorization: Bearer eyJhbGc...
```

Kong receives the request. It verifies the Access Token signature using Keycloak's public key — no network call to Keycloak, just local cryptographic verification. Token is valid. Kong forwards to FastAPI.

FastAPI reads the `sub` from the token, queries the database for that user's notes, and returns them.

### The full picture

```
User clicks Login
    ↓
React → redirects browser to Keycloak login page
    ↓
User enters credentials on Keycloak
    ↓
Keycloak → redirects back to React with ?code=Xk9mP2qR7nL4
    ↓
React → POST to Keycloak: "exchange this code for tokens"
    ↓
Keycloak → React: Access Token + Refresh Token + ID Token
    ↓
React stores tokens. User sees dashboard.
    ↓
User clicks "My Notes"
    ↓
React → GET /api/notes/ with Authorization: Bearer <access_token>
    ↓
Kong verifies token signature (locally, no Keycloak call needed)
    ↓
Kong → FastAPI: request forwarded
    ↓
FastAPI reads sub from token → queries DB → returns notes
```

---

## Part 8: How Keycloak Changes Our Architecture

### Before Keycloak (what we have now)

```
React → Nginx → Kong → FastAPI
                         ↓
                  FastAPI verifies JWT
                  (using our own SECRET_KEY)
                  FastAPI manages users table
                  FastAPI does password hashing
```

Problems:
- If SECRET_KEY leaks, all tokens are compromised
- Our JWT has no standard structure — we invented it
- No SSO, no 2FA, no social login
- User management is manual (we built it)

### After Keycloak

```
React → Keycloak (login, token issuance)
React → Nginx → Kong → FastAPI
                 ↓
          Kong verifies JWT signature
          using Keycloak's PUBLIC KEY
          (Kong fetches it automatically from Keycloak's JWKS endpoint)
                         ↓
                  FastAPI trusts Kong
                  FastAPI reads user sub from token
                  FastAPI fetches user data from its own DB using sub
```

FastAPI no longer handles:
- Password verification
- JWT issuance
- Token validation

Kong handles token validation. Keycloak handles everything auth-related. FastAPI only handles business logic.

---

## Part 9: Keycloak vs Custom JWT — Side by Side

| Feature | Our Custom JWT | Keycloak |
|---|---|---|
| Token issuance | FastAPI (our code) | Keycloak |
| Token validation | FastAPI (our code) | Kong (using Keycloak's public key) |
| Password hashing | bcrypt in FastAPI | Keycloak |
| Password reset | Not implemented | Built in (email flow) |
| 2FA | Not implemented | Built in (TOTP, SMS) |
| Social login | Not implemented | Built in (Google, GitHub, etc.) |
| SSO across services | Not possible | Built in |
| User management UI | Not built | Built in (admin console) |
| Token rotation | Not implemented | Built in (refresh token flow) |
| Brute force protection | Not implemented | Built in |
| Standards compliance | Custom | OAuth 2.0 + OIDC |
| Audit logs | Not implemented | Built in |

---

## Part 10: Keycloak vs Auth0 / Okta

| | Keycloak | Auth0 | Okta |
|---|---|---|---|
| Hosting | Self-hosted | SaaS | SaaS |
| Cost | Free (infra cost only) | Free tier, then $$$  | Enterprise pricing |
| Control | Full | Limited | Limited |
| Compliance | You manage | Provider manages | Provider manages |
| Setup complexity | High | Low | Medium |
| Used by | Enterprises, governments | Startups | Large enterprises |

Keycloak is chosen when:
- Data sovereignty matters (government, healthcare — data cannot leave your servers)
- You want zero licensing cost at scale
- You need full control over the auth stack

Auth0/Okta is chosen when:
- You want managed, zero-ops identity
- You are a startup and want fast setup
- You can afford the SaaS cost

---

## Part 11: What Changes in Our Application

### What we REMOVE from FastAPI

- `User` model's password field (Keycloak stores passwords)
- `passlib` / `bcrypt` password hashing
- Our custom JWT issuance (python-jose)
- Auth router (`/auth/login`, `/auth/register`)
- Auth middleware (Kong validates tokens now)

### What we KEEP in FastAPI

- `User` model — but only with `sub` (Keycloak UUID) and app-specific fields
- Business logic endpoints (notes, passwords)
- Reading the `sub` from the token (Kong passes it as a header after verifying)

### What we ADD

- Keycloak service in docker-compose
- Realm + Client configuration in Keycloak
- Kong JWT plugin — verifies Keycloak-issued tokens automatically

---

## Reference Links

- **Keycloak Official Docs**: https://www.keycloak.org/documentation
- **Keycloak Getting Started**: https://www.keycloak.org/getting-started/getting-started-docker
- **OAuth 2.0 Explained (video)**: search "OAuth 2.0 explained simply" — Fireship has a good 100-second version
- **OpenID Connect Explained**: https://openid.net/connect/
- **Keycloak Admin Console Guide**: https://www.keycloak.org/docs/latest/server_admin/
- **PKCE Explained**: search "OAuth PKCE explained" — important for understanding public clients
