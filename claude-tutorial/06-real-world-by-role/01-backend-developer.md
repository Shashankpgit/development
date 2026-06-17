# Claude Mastery — 16: Claude for Backend Developers

> **Last updated:** June 17, 2026
> **Covers:** APIs, databases, testing, debugging, performance — backend development with Claude

**20-minute read. The patterns a backend developer uses daily.**

---

## Your Claude Code Setup for Backend Work

### CLAUDE.md example
```markdown
# vault-api — CLAUDE.md

## Stack
- Node.js 20, Express 5
- PostgreSQL 15 via pg + pg-pool
- Redis (caching + sessions)
- Jest (tests), Supertest (integration tests)

## Project Structure
src/
  routes/       → Express route files, one per resource
  middleware/   → auth, validation, error handling
  services/     → business logic, database calls
  utils/        → crypto, email, logging helpers
migrations/     → PostgreSQL migrations (raw SQL)
tests/
  unit/         → pure function tests
  integration/  → Supertest + real DB

## Commands
npm test               → all tests
npm run test:watch     → watch mode
npm run migrate        → apply pending migrations
npm run migrate:rollback → rollback last migration
DATABASE_URL=postgresql://... npm run test:integration

## Conventions
- All DB queries in src/services/, never in route files
- Validation happens in middleware before reaching routes
- Never throw raw errors to clients — always use AppError
- Migrations are append-only, never modify past migrations
```

---

## Daily Backend Workflows

### Adding a New API Endpoint

```
> "Add a PATCH /api/vaults/:id endpoint that updates a vault's 
   name and description. It should only work for the vault owner."

Claude:
1. Reads src/routes/vaults.js for existing pattern
2. Reads src/services/vaultService.js for DB patterns
3. Reads src/middleware/auth.js for owner check pattern
4. Writes the route handler, service method, SQL query
5. Writes the tests (unit + integration)
6. Runs npm test to verify
```

**Output includes:**
- Route file with input validation
- Service method with parameterized SQL (no injection risk)
- Integration test with auth scenarios (owner can update, non-owner 403, not found 404)
- Already follows your project's error handling pattern (read from CLAUDE.md)

### Writing Database Migrations

```
> "Write a migration to add email_verified and 
   email_verified_at columns to the users table"

Claude:
1. Reads last migration for naming convention
2. Reads users table schema
3. Writes up.sql with ALTER TABLE statements
4. Writes down.sql rollback
5. Generates the migration file with proper timestamp name
```

**Claude understands:**
- Add nullable columns (can't set NOT NULL without a DEFAULT for existing rows)
- Index creation (CONCURRENTLY to avoid locking production)
- Rolling deployments (migration runs before code — backwards compatibility)

```
> "I need to add a NOT NULL column to the users table 
   but there are existing rows. How do I do this safely?"

Claude: "Three-step migration:
  Step 1: Add nullable column (deploy this immediately)
    ALTER TABLE users ADD COLUMN phone VARCHAR(20);
    
  Step 2: Backfill existing rows (run async or next release)
    UPDATE users SET phone = '' WHERE phone IS NULL;
    
  Step 3: Add NOT NULL constraint (after backfill completes)
    ALTER TABLE users ALTER COLUMN phone SET NOT NULL;
    
  Never do all three in one migration on a table with active writes."
```

### Debugging Errors

```
> "I'm getting 'ERROR: duplicate key value violates unique constraint 
   users_email_key' in production but I can't reproduce it locally"

Claude asks: "Is this happening on user registration or somewhere else?"
You: "Registration"

Claude:
1. Reads registration code
2. Reads the DB schema — sees no upsert or race condition guard
3. Explains: "This is a race condition. Two requests with the same email 
   arrive simultaneously, both check 'email not exists', both insert. 
   The second one fails. Happens under load but not locally."
4. Gives fix options:
   Option A: Database-level (simplest): the unique constraint is already catching it
             — just need to handle the error properly (return 409 not 500)
   Option B: Application-level: use INSERT ... ON CONFLICT DO NOTHING
   Option C: Pessimistic lock: SELECT ... FOR UPDATE on the email first
5. Implements your chosen option
```

### Writing Tests

```
> "Write comprehensive tests for the auth middleware"

Claude:
1. Reads src/middleware/auth.js
2. Writes tests for:
   - Valid JWT → request continues
   - Missing Authorization header → 401
   - Malformed token → 401
   - Expired token → 401
   - Valid token but user deleted → 401
   - Valid token, rate limit exceeded → 429
   (Derives test cases from the code's actual logic)
3. Runs tests, fixes any failures
```

```
> "I have 20% test coverage. Get it to 80%."

Claude:
1. npm run coverage → reads coverage report
2. Identifies untested files
3. Spawns multiple agents in parallel — one per untested module
4. Each agent reads the module, writes tests, verifies they pass
5. Main Claude reports final coverage
```

### Performance Debugging

```
> "The GET /api/vaults endpoint is slow (800ms). Profile it."

Claude:
1. Reads the route and service code
2. Identifies: query does N+1 (fetches vault, then loops to fetch each vault's tags separately)
3. Proposes fix: JOIN query to fetch everything at once
4. Shows before/after SQL
5. Writes the optimized version
6. Suggests adding EXPLAIN ANALYZE to the query in tests
```

---

## API Design with Claude

```
> "I need to design a REST API for a notes-and-folders system. 
   Users can nest folders. Notes can have tags."

Claude:
1. Designs the resource model (nouns, not verbs)
2. Defines endpoints with correct HTTP methods
3. Shows request/response shapes
4. Flags design decisions:
   - Nested resources vs flat with filter params
   - Pagination strategy (cursor vs offset)
   - Tag as a standalone resource or embedded?
5. Asks which way you want to go, then implements
```

### Error Response Standardization

```
> "Make all error responses in this API follow a consistent format"

Claude:
1. Reads all route files
2. Reads existing error middleware
3. Identifies all the different error shapes currently returned
4. Designs a standard ErrorResponse format:
   { "error": { "code": "VALIDATION_ERROR", "message": "...", "fields": [...] } }
5. Updates AppError class, error middleware, all routes
6. Updates tests to match new format
```

---

## Security-Focused Workflows

```
> "Security audit this API. What are the vulnerabilities?"

Claude spawns agents for:
- SQL injection (are all queries parameterized?)
- IDOR (can user A access user B's resources?)
- Authentication bypass (JWT edge cases)
- Rate limiting (which endpoints lack it?)
- Input validation (what inputs are not validated?)
- Dependency vulnerabilities (npm audit)
- Secrets in code (hardcoded tokens, weak defaults)
```

```
> "Add rate limiting to all auth endpoints"

Claude:
1. Finds all auth routes: /login, /register, /password-reset, /verify-email
2. Reads current middleware setup
3. Installs express-rate-limit (if not present)
4. Adds appropriate limits per endpoint:
   - /login: 5 per 15 minutes (brute force protection)
   - /register: 3 per hour (signup spam)
   - /password-reset: 3 per hour (enumeration)
5. Adds tests for rate limit behavior
```

---

## Working with External Services

```
> "Add SendGrid email integration for transactional emails.
   Start with a welcome email on registration."

Claude:
1. Reads the registration flow
2. Creates src/services/emailService.js with:
   - SendGrid client setup (reads API key from env)
   - sendWelcomeEmail(user) function
   - Email template (HTML + text versions)
3. Integrates into registration flow
4. Creates mock for tests (real emails in unit tests = bad)
5. Writes test that verifies email was "sent" (mock verified)
```

---

## Common Misunderstanding: "Claude will introduce SQL injection"

**The misunderstanding:** "I can't trust Claude to write database queries — it might write unsafe SQL."

**The reality:** Claude defaults to parameterized queries because it knows the security implications. When you give it context in CLAUDE.md ("uses pg library"), it will write:
```javascript
// What Claude writes
const result = await pool.query(
  'SELECT * FROM users WHERE email = $1',
  [email]  // parameterized — safe
)
```

Not:
```javascript
// What it would write if you provided no context
`SELECT * FROM users WHERE email = '${email}'`  // injection risk
```

If you see Claude write string interpolation into a SQL query, point it out. It will fix it immediately and understands why it's wrong. The larger risk is Claude not knowing your specific ORM patterns — that's why the CLAUDE.md tech stack section matters.

→ Continue to: `02-frontend-developer.md`
