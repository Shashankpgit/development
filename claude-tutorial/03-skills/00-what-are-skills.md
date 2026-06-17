# Claude Mastery — 08: Skills — What They Are

> **Last updated:** June 17, 2026
> **Covers:** What skills are, skills vs slash commands vs prompts, the skill invocation model

**20-minute read. Skills turn your best prompts into reusable, shareable commands.**

---

## The Problem Skills Solve

You find a great prompt that works perfectly for your team's code reviews:

```
Review the staged changes for: security vulnerabilities, missing error handling, 
performance issues, and test coverage. For each issue: file:line, severity (P1/P2/P3), 
and specific fix. Flag any secrets or credentials immediately.
```

Without skills, every team member:
1. Has to remember this exact prompt
2. Types it out every time (or keeps it in a notes doc)
3. Might use a slightly different version → inconsistent results

With skills:
```
> /code-review
```

One command. Always the same behavior. Everyone on the team uses it.

---

## What Is a Skill?

A **skill** is a Markdown file in `.claude/commands/` that defines a reusable prompt accessible as a slash command.

```
.claude/
  commands/
    code-review.md         → /code-review
    deploy-staging.md      → /deploy-staging
    write-tests.md         → /write-tests
    explain-error.md       → /explain-error
    security-audit.md      → /security-audit
```

Typing `/` in Claude Code shows all available skills alongside built-in slash commands.

The skill file IS the prompt. When you run `/code-review`, Claude Code runs the prompt defined in `code-review.md`.

---

## Skills vs Slash Commands vs Prompts

These three things look similar but are fundamentally different:

| | Regular Prompt | Slash Command | Skill |
|--|---------------|--------------|-------|
| Where defined | You type it | Built into Claude Code | `.claude/commands/*.md` |
| Reusable | No (type every time) | Yes | Yes |
| Customizable | Fully | No | Fully |
| Shareable | No | N/A | Yes (commit to git) |
| Project-specific | No | No | Yes |
| Arguments | Manual | Some have flags | Via `$ARGUMENTS` |

**Slash commands** (`/commit`, `/review`, `/init`) are hardcoded into Claude Code — you can't change what they do.

**Skills** are YOUR definitions — you control the prompt, the behavior, and the name.

---

## Skill File Structure

A skill is just a Markdown file. The filename becomes the command name (hyphens become the separator):

```markdown
# code-review.md → /code-review

Review the current staged git changes for production readiness.

Check for:
1. Security vulnerabilities (SQL injection, XSS, exposed secrets, insecure defaults)
2. Missing error handling (unhandled promises, missing try/catch, no input validation)
3. Performance issues (N+1 queries, missing indexes, unnecessary computations)
4. Missing or inadequate tests

For each issue found:
- File path and line number
- Severity: P1 (must fix before deploy) / P2 (fix soon) / P3 (nice to have)
- Specific suggested fix

Start by running `git diff --cached` to see what's staged.
Flag any hardcoded secrets or credentials immediately as CRITICAL.
```

That's it. When you run `/code-review`, Claude receives that entire text as its instruction and executes it.

---

## The `$ARGUMENTS` Variable

Skills can accept arguments from the command line:

```markdown
# explain-error.md → /explain-error

The user encountered this error: $ARGUMENTS

1. Explain what this error means in plain English
2. List the 3 most likely causes, ranked by probability
3. Show the specific commands to diagnose which cause it is
4. Show the fix for each cause

Be specific to our tech stack (Node.js, PostgreSQL, Kubernetes).
```

Usage:
```
> /explain-error "CrashLoopBackOff: exit code 1"
> /explain-error "ECONNREFUSED 127.0.0.1:5432"
> /explain-error "Helm upgrade failed: UPGRADE FAILED: another operation is in progress"
```

Claude replaces `$ARGUMENTS` with everything you typed after the command name.

---

## Where Skills Are Stored — Scope

```
Scope               Location                      Visible to
─────────────────────────────────────────────────────────────
Project skills      .claude/commands/*.md         This project only
User skills         ~/.claude/commands/*.md        All your projects
```

**Project skills** (`.claude/commands/`): commit these to git. The whole team gets them.

**User skills** (`~/.claude/commands/`): personal skills that apply everywhere. Don't commit these.

---

## Built-in Skills from Claude Code

Claude Code comes with several built-in skills (accessible via slash commands). These are covered in detail in the next file (`01-built-in-skills.md`).

---

## Skills Available via Plugins / Extensions

Some skills are provided by MCP servers or external sources. These appear prefixed:
```
/github:create-issue
/linear:create-ticket
/my-plugin:custom-skill
```

---

## When to Create a Skill

Create a skill when:
- You've used the same prompt 3+ times
- The task requires specific context about your project's conventions
- Multiple team members need to do the same thing consistently
- You want to encode "how we do things" as executable commands

Don't create a skill for:
- One-off tasks you'll never repeat
- Tasks that change so often the skill would always be outdated
- Simple things you can type in 3 words

---

## Real-World Scenario: A DevOps Team's Skill Library

```
.claude/commands/
  deploy-staging.md        → /deploy-staging
  deploy-production.md     → /deploy-production
  rollback.md              → /rollback
  health-check.md          → /health-check
  explain-failure.md       → /explain-failure
  write-runbook.md         → /write-runbook
  security-scan.md         → /security-scan
  cost-estimate.md         → /cost-estimate
```

These are committed to the `vault-infra` repo. Every engineer on the team automatically gets all of them when they clone the repo.

New engineer joins → clones repo → immediately has the team's entire "how we do deployments" encoded in slash commands. No Confluence page to read, no tribal knowledge to transfer.

---

## Common Misunderstanding: "Skills are AI magic"

**The misunderstanding:** "Skills are some special AI capability that makes Claude smarter."

**The reality:** A skill is just a text file containing a prompt. When you run `/code-review`, Claude receives the text of `code-review.md` as its instruction. That's it. No special API, no special model, no magic.

The power is in the **prompt quality** and **discoverability**. A well-crafted skill prompt beats a hastily typed one-liner. And having it as a slash command means you actually USE your best prompts consistently instead of half-remembering them.

If you can write a great prompt that solves a problem well, you can make it a skill. That's the entire mechanism.

→ Continue to: `01-built-in-skills.md`
