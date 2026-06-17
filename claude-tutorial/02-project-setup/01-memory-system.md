# Claude Mastery — 07: The Persistent Memory System

> **Last updated:** June 17, 2026
> **Covers:** Auto-memory types, MEMORY.md index, how memory persists across sessions, reading/writing memory

**20-minute read. Memory is what makes Claude feel like it knows you — not just your project.**

---

## Memory vs CLAUDE.md — The Difference

```
CLAUDE.md               ← what YOU explicitly tell Claude about the project
                           You write it, you maintain it, it's in version control

Memory system           ← what Claude learns ABOUT YOU over time
                           Claude writes it, it accumulates automatically
                           Stored in ~/.claude/projects/.../memory/
```

CLAUDE.md: "Here's our tech stack and conventions."
Memory: "Shashank prefers concise explanations. He's a DevOps engineer. He got burned by this pattern in March."

---

## Where Memory Is Stored

```
~/.claude/projects/
  -home-sanketika7420-projects-vault-app/    ← one directory per project path
    memory/
      MEMORY.md                              ← index of all memories (always loaded)
      user_profile.md                        ← who you are
      feedback_testing.md                    ← how you like testing done
      project_active_work.md                 ← current sprint/focus
      reference_monitoring.md               ← where to find things
```

The path is derived from the absolute project path. Each project has its own isolated memory.

---

## The Four Types of Memory

### 1. `user` — Who You Are

```markdown
---
name: user-profile
description: Shashank is a senior DevOps engineer at Sanketika
metadata:
  type: user
---

Senior DevOps engineer at Sanketika (startup, ~30 person team).
Deep Linux/networking knowledge. Strong Kubernetes + AWS background.
New to frontend (React) — explain frontend concepts with backend analogies.
Prefers hands-on commands over theory.
Works on vault-app infrastructure and CI/CD.
```

Claude uses this to calibrate responses. "New to React → explain frontend concepts with backend analogies" means Claude explains React state management as "like a Redis cache for your UI component."

### 2. `feedback` — How You Like to Work

```markdown
---
name: feedback-response-style
description: User wants concise responses, no trailing summaries, commands with examples
metadata:
  type: feedback
---

Never end responses with "In summary..." or "To recap..." — user can read the diff.
Always show actual commands, not just concepts.
Explain WHY before HOW for non-obvious decisions.
When suggesting K8s changes, show the full YAML.
Flag security concerns immediately, before the rest of the answer.

**Why:** User explicitly said "I can read the diff, stop summarizing."
**How to apply:** End every response cleanly. No recap. Just the work.
```

These accumulate over time. Every correction you give Claude is a candidate for a feedback memory.

### 3. `project` — Current Work Context

```markdown
---
name: project-jwt-migration
description: Active migration from session auth to JWT (started May 2026)
metadata:
  type: project
---

We are migrating from express-session (Redis-backed) to JWT auth.
Branch: feature/jwt-auth

**Why:** Redis session store was causing connection pool issues under load (issue #234).
**Status as of June 2026:** Login and registration endpoints migrated. Protected routes still use old middleware.
**Next:** Update src/middleware/auth.js and all route files that use requireSession.
**Constraint:** Must be backward-compatible during rollout (both old + new sessions must work temporarily).

**How to apply:** When touching auth code, default to JWT pattern, not session pattern.
```

### 4. `reference` — Where to Find Things

```markdown
---
name: reference-monitoring
description: Grafana/Prometheus at internal monitoring URLs
metadata:
  type: reference
---

Monitoring stack:
- Grafana: http://grafana.internal.sanketika.in (monitoring namespace)
- Prometheus: http://prometheus.internal.sanketika.in
- Loki: accessed via Grafana

Logs are in Loki, labeled by namespace and pod name.
Alerts fire to #infra-alerts Slack channel.
On-call rotation in PagerDuty.
```

---

## MEMORY.md — The Index

`MEMORY.md` is always loaded. It's a one-line-per-memory index:

```markdown
# Memory Index

- [User Profile](user_profile.md) — senior DevOps engineer, new to React, prefers commands
- [Project: vault-app](project_vault_app.md) — password manager, K8s + AWS, 50 users
- [Feedback: Response Style](feedback_response.md) — concise, no summaries, show WHY
- [Feedback: Testing](feedback_testing.md) — integration tests must hit real DB
- [Reference: Monitoring](reference_monitoring.md) — Grafana/Prometheus URLs
- [Reference: AWS Accounts](reference_aws.md) — account IDs, cluster names, regions
```

This index is kept compact (max ~200 lines). The detail is in individual files.

---

## How Claude Decides to Write a Memory

Claude writes a memory when:
- You explicitly say "remember this" or "don't forget that"
- You correct Claude's approach ("no, don't do it that way because...")
- You confirm a non-obvious approach worked ("yes, exactly, keep doing that")
- You share something important about yourself, your project, or your preferences

**Examples that trigger memory writes:**

```
You: "Remember that we never mock the database in tests — 
     we got burned when mocked tests passed but the prod migration failed."
→ Claude writes: feedback memory about integration tests requiring real DB

You: "Actually in our project we use Knex.js, not raw SQL or an ORM"
→ Claude writes: project memory about using Knex.js

You: "We got burned by force pushes to main last quarter — 
     never suggest force push to main"
→ Claude writes: feedback memory about never suggesting force push to main
```

---

## How to Trigger Memory Writes Explicitly

```
> Remember that our production database is on RDS in ap-south-1, 
  instance name vault-db-prod. Credentials come from AWS Secrets Manager.

> Always remember: when I ask about the monitoring stack, the Grafana 
  URL is grafana.sanketika.internal — don't suggest installing locally.

> Save this: we use Helmfile (not raw Helm) for multi-chart deployments.
```

Claude will write a memory file immediately when you say "remember."

---

## Reading and Managing Memory

### Viewing Current Memory
```
> /memory
```
Shows the full content of MEMORY.md and what's currently loaded.

### Asking Claude to Recall Something
```
> What do you know about our AWS setup?
[Claude checks reference memories]

> What are my preferences for how you should respond?
[Claude reads feedback memories]

> What project are we currently working on?
[Claude reads project memories]
```

### Updating a Memory
```
> The monitoring stack has changed — Grafana is now at 
  grafana.production.sanketika.in (not the old URL). Update your memory.
```

### Deleting a Memory
```
> Forget the reference to the old Redis session store — 
  we've migrated to JWT now.
```

---

## The Global Memory (~/.claude/CLAUDE.md)

Separate from the project-level memory, you can have a global personal instruction file:

```markdown
# ~/.claude/CLAUDE.md — Shashank's global instructions

I am a senior DevOps engineer. I learn by building, not reading theory.

## My Communication Preferences
- Always show commands I can run, not just concepts
- Explain WHY before HOW
- Be concise — I read fast
- Never use phrases like "Great question!" or "Certainly!"

## My Background
- Strong: Linux, Kubernetes, AWS, Docker, CI/CD, Helm, Terraform
- Learning: Frontend development (React, TypeScript)
- Not my area: iOS/Android, ML/AI engineering

## How I Like to Debug
- Show me the diagnosis steps, not just "try this"
- When something can be multiple causes, rank them by likelihood
- Always tell me what to look at in logs

## Red Lines
- Never suggest deleting production data without explicit backup step first
- Never suggest --force options without explaining consequences
- Always flag security implications immediately
```

This global CLAUDE.md applies to EVERY project you work on, not just one.

---

## Real-World Scenario: Memory Accumulating Over a Month

**Week 1:**
```
You: "Fix the login endpoint — it's returning 500s"
[Claude fixes it, but uses session auth pattern]
You: "We're migrating to JWT — don't use sessions for new code"
→ Memory: feedback about JWT migration
```

**Week 2:**
```
You: "Add password reset flow"
[Claude automatically uses JWT, not sessions]
[No re-explaining needed]
```

**Week 3:**
```
You: "The RDS connection string changed — update it everywhere"
[Claude remembers it knows about RDS in ap-south-1, finds all references quickly]
→ Memory: reference memory updated with new connection string
```

**Week 4:**
```
You: "Deploy the new feature to staging"
[Claude knows: helm in staging namespace, vault-staging-cluster, values.staging.yaml]
[Runs the exact right command without asking]
```

By week 4, Claude operates like someone who's been on the team for a month. This is the compounding value of memory.

---

## Common Misunderstanding: "Memory is the same as conversation context"

**The misunderstanding:** "Claude remembers what I said earlier in this session — that's memory."

**The reality:** There are three distinct things that give Claude "memory":

1. **Conversation history** — what you said IN THIS SESSION. Gone after you close the terminal or run `/clear`.

2. **CLAUDE.md** — project context YOU wrote. Always available. Permanent until you edit the file.

3. **Memory system** — what Claude learned about YOU over time. Stored in `~/.claude/projects/.../memory/`. Persists across sessions, across machines (if settings are synced), across months.

The memory system is what makes Claude feel like it "knows you" after a few weeks of use, not just a few hours.

→ Continue to: `../03-skills/00-what-are-skills.md`
