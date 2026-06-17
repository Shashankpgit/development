# Claude Mastery — 11: Agent Types — Pick the Right Specialist

> **Last updated:** June 17, 2026
> **Covers:** Every agent type, their capabilities, when to use each, real examples

**20-minute read. The right agent type gets you better results faster. Don't always reach for the generic one.**

---

## The Agent Registry

Claude Code has built-in specialized agents. The main Claude selects the right type automatically, but you can also guide it.

```
Available agent types:
  general-purpose     ← catch-all
  Explore             ← code search and navigation
  Plan                ← architecture and design
  code-reviewer       ← independent code review
  claude-code-guide   ← questions about Claude Code itself
  statusline-setup    ← configuring the status line
```

When Claude spawns an agent, it picks the type that best fits the task description. You can override this in your prompts.

---

## `general-purpose` — The Default Worker

```
Best for: Complex multi-step tasks that don't fit a specific category
Tools: All tools (Read, Write, Edit, Bash, Agent, WebSearch, WebFetch, etc.)
Context: Fresh — only knows what main Claude puts in its prompt
```

**What it does well:**
- Multi-file code changes
- Research + implementation combined
- Anything that needs to read, think, AND write
- Long automation tasks

**Example uses:**
```
> "Add pagination to all API endpoints that return lists. 
   Use cursor-based pagination, add tests for each."
   [Main Claude spawns general-purpose agents, one per endpoint]

> "Migrate all console.log statements to use our Winston logger"
   [Spawns a general-purpose agent with the codebase context]

> "For each microservice in ./services/, check if it has a health endpoint.
   For those that don't, add one."
   [Spawns one agent per microservice]
```

---

## `Explore` — The Fast Code Navigator

```
Best for: Finding code, locating symbols, answering "where is X defined?"
Tools: Read, Bash (for grep/find), NOT Write/Edit
Context: Read-only — cannot modify files
Speed: Fast (optimized for search, not writing)
```

`Explore` agents are explicitly read-only. They search, they read, they report. They cannot change files. This makes them:
- Safe to use freely (no risk of unintended changes)
- Fast (no need to reason about changes)
- Great for reconnaissance before acting

**When to use `Explore`:**
- "Where is the authentication middleware defined?"
- "Which files reference the User model?"
- "Find all TODO/FIXME comments in the codebase"
- "What's the directory structure of the project?"
- "Do we have any tests for the payment service?"

**In the main Claude's workflow:**
```
Main Claude: "I need to refactor the auth module. Let me first 
understand the full scope before changing anything."

[Spawns Explore agent: "Map all files that import or use the auth 
module. List each file, what they import, and what they use it for."]

Explore agent searches, reads, returns the map.

Main Claude: now knows the full impact area, proceeds with changes.
```

**You can request Explore explicitly:**
```
> "Use an Explore agent to find all files that import from 
   src/utils/crypto.js before we change it"
```

---

## `Plan` — The Architect

```
Best for: Before complex implementations — designing the approach
Tools: Read (to understand current state), no execution tools
Output: Structured implementation plan
```

`Plan` agents read the codebase, understand the current state, and produce an actionable implementation plan. They don't write code — that comes after approval.

**When to use `Plan`:**
- Before any non-trivial refactor
- When you need to understand what will change before changing it
- Architecture decisions ("how should we structure this new feature?")
- Migration planning ("how do we move from X to Y safely?")

**Example:**
```
> "I want to migrate from REST to GraphQL. Before you start, 
   use a Plan agent to design the migration approach."

Plan agent reads:
  - Current REST endpoints
  - Client code using the API
  - Database models
  - Test structure

Plan agent outputs:
  Phase 1: Add GraphQL endpoint alongside REST (3 days)
    - Install Apollo Server
    - Define schema for User and Vault types
    - Implement resolvers for existing REST functionality
  
  Phase 2: Migrate clients (5 days)
    ...
  
  Phase 3: Deprecate REST (2 weeks after Phase 2)
    ...
  
  Risk: Mobile clients not under our control — cannot deprecate REST until mobile v3 ships

> "Looks good. Proceed with Phase 1."
[Main Claude implements the plan]
```

**Use `/plan` command as an alternative:**
```
> /plan
> Migrate the authentication module from sessions to JWT
```

---

## `code-reviewer` — The Independent Reviewer

```
Best for: Getting a fresh perspective on code changes
Tools: Read, no write
Key property: Starts with NO knowledge of the conversation history
```

`code-reviewer` agents are explicitly designed to give **independent** reviews. They don't see the conversation history — they approach the code fresh, like a real code reviewer who wasn't involved in writing it.

This is important: if Main Claude wrote the code, it might be biased toward thinking it's correct. A `code-reviewer` agent has no such bias.

**When to use `code-reviewer`:**
- After implementing a non-trivial feature
- Before a production deploy
- When you want a second opinion without anchoring on your own perspective
- Security-sensitive code

**Example:**
```
> "You just implemented the JWT auth. Spawn a code-reviewer agent 
   to independently review it — don't tell it what you were trying 
   to do, just give it the files."

code-reviewer agent (fresh context, no history):
  Reads src/middleware/auth.js
  Reads src/utils/jwt.js
  Reads tests/auth.test.js
  
  Reports:
  - CRITICAL: JWT secret falls back to a hardcoded default "secret" if env var not set
  - HIGH: Token expiry is checked but not the issuedAt time (allows replayed old tokens)
  - MEDIUM: No rate limiting on token validation endpoint
  - LOW: Missing test for expired token behavior
```

The main Claude missed the fallback secret issue because it wrote the code. The independent reviewer caught it immediately.

---

## `claude-code-guide` — Questions About Claude Code

```
Best for: Asking "how does Claude Code work?", "what's this feature?", "how do I configure X?"
Tools: Read, WebFetch, WebSearch
Use: When you have questions about Claude Code itself
```

This specialized agent knows Claude Code's documentation, features, and capabilities. Use it when you're confused about Claude Code — not when you're working on your project code.

**Example:**
```
> "How do I set up GitHub MCP server with Claude Code?"
[Spawns claude-code-guide agent that knows Claude Code's MCP documentation]

> "What's the difference between /compact and /clear?"
[Spawns claude-code-guide — this guide file you're reading could help this agent]
```

---

## How to Guide Agent Type Selection

You can tell Claude which agent type to use:

```
> "Use an Explore agent to find all database migrations"

> "Before making any changes, use a Plan agent to design the approach"

> "After implementing, get an independent code-reviewer to check it"

> "How do I use MCP servers?" (triggers claude-code-guide automatically)
```

You can also tell Claude HOW MANY agents:
```
> "Use 3 parallel agents to simultaneously check the API, the auth 
   module, and the database layer"
```

---

## Combining Agent Types in One Task

The most powerful pattern: use different agent types for different phases of a task.

```
Task: "Implement email verification for new user registration"

Phase 1 — Explore: Map current registration flow
  [Explore agent finds all relevant files, current endpoints]

Phase 2 — Plan: Design the implementation
  [Plan agent reads the map, designs the feature]
  [You approve the plan]

Phase 3 — Implement: general-purpose agents do the work
  [Agent 1: update User model (add emailVerified field, migration)]
  [Agent 2: create verification token service]
  [Agent 3: update registration endpoint]
  [Agent 4: create verification email template]
  [Run in parallel]

Phase 4 — Review: independent review
  [code-reviewer agent reviews ALL new files fresh]
  [Reports security issues, missing tests]

Phase 5 — Fix: general-purpose agent addresses review findings
```

This is what a senior engineer does naturally: understand → plan → build → review → fix. Claude automates the entire cycle.

---

## Real-World Scenario: Onboarding to a New Codebase

New DevOps engineer joins the team on day 1:

```
> "I just joined this team. Use multiple agents to give me a complete 
   technical onboarding. One agent should understand the app architecture,
   one should understand the infrastructure, one should understand the 
   CI/CD pipeline, and one should find known issues and tech debt."

Main Claude spawns 4 Explore agents simultaneously:

Agent 1 (architecture): Reads src/, package.json, docker-compose.yml
  → Returns: Express API, React frontend, PostgreSQL, Redis, service dependencies

Agent 2 (infrastructure): Reads terraform/, helm/, kubernetes/
  → Returns: AWS EKS, 3 environments, Helm charts, networking setup

Agent 3 (CI/CD): Reads .github/workflows/
  → Returns: CI on PR, CD on main, ECR for images, EKS deploy via kubectl

Agent 4 (issues): Searches for TODO, FIXME, deprecation warnings, old deps
  → Returns: 12 TODOs, 3 deprecated packages, known issue with connection pooling

Main Claude synthesizes:
"Here's your technical onboarding:
  Architecture: ...
  Infrastructure: ...
  CI/CD: ...
  Known Issues: ..."
```

30-minute onboarding delivered in 4 minutes. All from the codebase itself.

---

## Common Misunderstanding: "Agents remember what other agents found"

**The misunderstanding:** "If Agent 1 finds something, Agent 2 will know about it."

**The reality:** Agents are completely isolated from each other. Agent 2 has NO knowledge of what Agent 1 found unless:

1. The main Claude reads Agent 1's result and includes it in Agent 2's prompt
2. Agent 1 wrote its findings to a file that Agent 2 then reads

This isolation is intentional — it's what allows independent review. But it means you (and the main Claude) must explicitly pass context between agents when needed.

```
WRONG (Agent 2 won't know):
  Agent 1: "Find all auth bugs"
  Agent 2: "Fix the bugs Agent 1 found"   ← Agent 2 has no idea what Agent 1 found

CORRECT (explicit context passing):
  Agent 1: "Find all auth bugs" → returns list
  Main Claude reads the list, then:
  Agent 2: "Fix these specific bugs: [list from Agent 1's result]"
```

→ Continue to: `02-workflows.md`
