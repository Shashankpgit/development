# Claude Mastery — 19: Prompt Engineering — Getting Better Results

> **Last updated:** June 17, 2026
> **Covers:** Writing better prompts, reducing back-and-forth, getting exactly what you want

**20-minute read. Small changes to how you ask produce dramatically better results.**

---

## The Core Principle

Claude's output quality is directly proportional to the quality of context you give it.

Not prompt COMPLEXITY — context. A long, confusing prompt is worse than a short, precise one. The goal is: Claude should have exactly the information it needs to make good decisions without guessing.

---

## The 5 Elements of a High-Quality Prompt

### 1. The Goal (what you want)
Not just the action — the end state you're trying to reach.

```
Weak:  "Update the auth function"
Strong: "Update the auth function to reject tokens that are more 
        than 24 hours old. Currently it only checks the signature, 
        not the issued-at time."
```

### 2. The Constraints (what you don't want)
What NOT to change is as important as what to change.

```
Weak:  "Refactor this service"
Strong: "Refactor this service to use async/await instead of callbacks. 
        Don't change the function signatures — they're called from 20 
        other places. Don't add new dependencies."
```

### 3. The Context (why it matters)
Claude makes better decisions when it understands the reason.

```
Weak:  "Make this query faster"
Strong: "Make this query faster. It runs on every page load for all 
        users — currently averaging 400ms which is killing UX. 
        The users table has 50k rows and grows by 1k/day."
```

### 4. The Format (what the output should look like)
Don't let Claude decide the output format if you have a preference.

```
Weak:  "Document this API"
Strong: "Document this API in OpenAPI 3.0 YAML format. 
        Include all endpoints, request/response schemas, 
        and error responses."
```

### 5. The Examples (what good looks like)
The fastest way to communicate intent is to show a "like this" example.

```
"Write error messages that sound like this existing one:
  'This email is already registered. Sign in instead, or use 
   a different email to create an account.'
  — conversational, tells the user what to do next, not just what went wrong."
```

---

## Common Prompting Mistakes (and Fixes)

### Mistake 1: Asking Claude to Guess Your Stack

**Bad:**
```
> "Add caching to this API endpoint"
```
Claude guesses: Redis? In-memory? With what library?

**Good:**
```
> "Add Redis caching to this endpoint using ioredis (already in package.json).
   Cache the response for 5 minutes, keyed by userId.
   Invalidate the cache when the user updates their profile."
```

Even better: put your stack in CLAUDE.md and just write:
```
> "Add Redis caching to this endpoint — 5 minute TTL, key by userId, 
   invalidate on profile update"
```

### Mistake 2: Describing the Implementation Instead of the Outcome

**Bad:**
```
> "Add a useRef and a useEffect that clears the timeout and 
   sets up a new one when the input changes"
```
You're doing Claude's job.

**Good:**
```
> "Add debouncing to this search input — 
   only call the API after the user stops typing for 300ms"
```
Claude knows what debouncing is and picks the right implementation.

### Mistake 3: Asking Multiple Questions at Once

**Bad:**
```
> "Why is this slow and how do I fix it and should I add indexes or caching?"
```
Claude answers all three, probably superficially.

**Good:**
```
> "Why is this query slow?"
[Get the diagnosis]
> "Given that cause, should I fix it with indexes or caching?"
[Focused decision]
> "Implement the indexes you recommended"
[Focused implementation]
```

### Mistake 4: Being Too Vague About "Fix This"

**Bad:**
```
> "Fix the validation"
```

**Good:**
```
> "The email field accepts 'test@' (no domain) — that should be invalid.
   Fix the email validation to require a proper domain."
```

### Mistake 5: Not Saying What "Done" Looks Like

**Bad:**
```
> "Add tests for the payment service"
```
Claude picks coverage level arbitrarily.

**Good:**
```
> "Add tests for the payment service. I need:
   - Unit tests for calculateTax() and applyDiscount()
   - Integration test for the full checkout flow using Supertest
   - At least one test for each error case documented in the JSDoc"
```

---

## Advanced Techniques

### The "Tell Me Before You Do It" Pattern

For any non-trivial change, ask Claude to explain the plan first:

```
> "I want to migrate from JWT to session-based auth. Before you 
   start making changes, explain your migration plan — what you'll 
   change, what the risks are, and in what order."
```

Catch bad plans before any code changes. Approve first, then implement.

### The "Assume Nothing" Pattern

When introducing Claude to an unfamiliar codebase:

```
> "You're new to this codebase. Read the CLAUDE.md and the main entry points. 
   Tell me what you understand about the architecture before we start. 
   Ask me about anything that's unclear."
```

Surfaces Claude's misunderstandings before they become bugs.

### The "Constraints First" Pattern

State what can't change before saying what should:

```
> "The API must remain backwards compatible — no breaking changes.
   Existing clients use /api/v1/users — that endpoint must continue 
   to work exactly as it does today.
   
   Given that constraint, add support for filtering users by role."
```

### The "Red Team It" Pattern

After implementation, ask Claude to critique its own work:

```
> "You just built the password reset flow. Now put on an attacker's hat.
   What are the 3 most likely ways someone would try to exploit this?
   For each attack, tell me if the current implementation is vulnerable."
```

This catches security issues the original implementation missed.

### The "Explain Like I'm Debugging" Pattern

When you don't understand a behavior:

```
> "This function returns undefined sometimes. Walk me through the 
   execution step by step for the case where input is an empty array.
   Don't jump to solutions — just trace the execution."
```

Forces a methodical trace instead of jumping to guesses.

---

## Calibrating Depth

Claude adjusts depth to what you ask for. Use these phrases intentionally:

| Phrase | Effect |
|--------|--------|
| "brief overview" | High-level summary, 3-5 sentences |
| "explain this" | Standard depth, assumes competence |
| "deep dive" | Thorough explanation, internals |
| "explain like I haven't used X before" | First-principles explanation |
| "just the code, no explanation" | Code only, no commentary |
| "explain every line" | Maximum verbosity |

---

## When to Use Claude Code vs Claude.ai

| Task | Best Tool | Why |
|------|-----------|-----|
| "Fix this bug" | Claude Code | Has access to your files |
| "Explain this concept" | Either | No file access needed |
| "Review this screenshot" | Claude.ai | Supports image upload |
| "Design this architecture" | Claude.ai | Longer back-and-forth, no code needed |
| "Write this new feature" | Claude Code | Needs to read context, write files |
| "What library should I use?" | Either | Research task |
| "Implement from Figma design" | Both | Design in claude.ai, implement in Code |

---

## System Prompt Engineering (CLAUDE.md as System Prompt)

Your CLAUDE.md is effectively a system prompt for all Claude Code sessions. Write it like instructions, not documentation:

**Weak CLAUDE.md:**
```markdown
# Project Info
This is a Node.js project using Express and PostgreSQL.
```

**Strong CLAUDE.md:**
```markdown
# Project Conventions (follow these without being asked)

## Code Style
- Functions must have explicit return type annotations
- Use const unless reassignment is necessary
- All database queries must use parameterized inputs

## When Adding Features
1. Check if a similar function already exists in src/utils/
2. Add to existing route file if the resource already has one
3. Always add a test for the happy path and the main error case

## Never Do This
- Import from node_modules directly in route files (always via services/)
- Return raw database error messages to clients
- Use console.log in production code (use logger instead)
```

---

## Common Misunderstanding: "Longer prompts always get better results"

**The misunderstanding:** "I should write very detailed prompts to get better results."

**The reality:** Length ≠ quality. What matters is signal-to-noise ratio. A 300-word prompt full of redundant context is worse than a 50-word prompt that gives Claude exactly what it needs to decide.

Signs your prompt is too long:
- You're explaining things Claude already knows (how React hooks work)
- You're describing what the code does instead of what you want
- You're repeating yourself

Signs your prompt is too short:
- Claude asks a clarifying question → your prompt was missing context
- Claude's output uses the wrong library/pattern → missing stack context
- Claude changes things you didn't want changed → missing constraints

The goal: enough context for Claude to make the right decision, nothing more.

→ Continue to: `01-context-management.md`
