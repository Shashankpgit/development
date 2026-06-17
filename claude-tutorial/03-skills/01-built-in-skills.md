# Claude Mastery — 09: Built-In Skills and Creating Custom Skills

> **Last updated:** June 17, 2026
> **Covers:** Every built-in skill, creating project skills, personal skills, skill patterns for different roles

**20-minute read. The skills you get for free — and how to build your own.**

---

## Built-In Skills Reference

These come with Claude Code. Invoke them with `/command-name`.

### `/review` — Code Review
Reviews staged or recent changes.
```
> /review
```
Claude runs `git diff --cached` (or recent uncommitted changes), reviews for bugs, security, quality, and missing tests.

Best for: pre-commit review, PR preparation.

### `/commit` — AI Commit Message
Creates a commit with an AI-generated message.
```
> /commit
```
Reads staged diff → generates conventional commit message (feat/fix/chore/docs) → shows for approval → commits.

Best for: every single commit (fast, consistent messages).

### `/pr` — Pull Request Creation
Creates a GitHub/GitLab PR with AI-generated description.
```
> /pr
```
Reads all commits on current branch → generates title and body → runs `gh pr create`.

Requires: GitHub CLI (`gh`) installed and authenticated.

### `/init` — Generate CLAUDE.md
Analyzes the project and creates a CLAUDE.md.
```
> /init
```
Run once per new project. Then refine the generated file.

### `/plan` — Plan Before Acting
Enters plan mode. Claude creates a plan and waits for approval.
```
> /plan
```
Use before large changes. Claude won't touch any file until you approve the plan.

### `/memory` — View Memory
Shows all current auto-memory content.
```
> /memory
```

### `/status` — Session Status
Shows token usage, model, session ID.
```
> /status
```

### `/cost` — Cost Estimate
Shows current session's estimated API cost.
```
> /cost
```

### `/doctor` — Diagnose Issues
Checks Claude Code setup for problems.
```
> /doctor
```

### `/clear` — Clear Conversation
Clears conversation history. CLAUDE.md context persists.
```
> /clear
```

### `/compact` — Compress Context
Manually compacts the conversation to free up context space.
```
> /compact
```

### `/model` — Switch Model
```
> /model claude-opus-4-8
> /model claude-haiku-4-5-20251001
```

### `/fast` — Toggle Opus Fast Mode
```
> /fast
```

### `/verbose` — Toggle Verbose Output
```
> /verbose
```

### `/bug` — Report a Claude Bug
```
> /bug "Claude keeps suggesting console.log instead of our logger"
```

---

## Creating Your Own Skills

### File Naming → Command Name

```
.claude/commands/deploy-staging.md     → /deploy-staging
.claude/commands/write-unit-tests.md   → /write-unit-tests
.claude/commands/security-audit.md     → /security-audit
```

Hyphens in filenames become the command name with hyphens. Keep names short and descriptive.

---

## DevOps Engineer Skills

### `/deploy-staging`
```markdown
# deploy-staging.md

Deploy the current branch to the staging environment.

Steps:
1. Run `git log --oneline -5` to confirm current commits
2. Run `helm diff upgrade vault-app ./helm/vault-app/ -n staging --values helm/values.staging.yaml --set image.tag=$(git rev-parse --short HEAD)` to preview changes
3. Ask me to confirm the diff before proceeding
4. If confirmed, run `helm upgrade vault-app ./helm/vault-app/ -n staging --values helm/values.staging.yaml --set image.tag=$(git rev-parse --short HEAD) --atomic --timeout 5m`
5. Run `kubectl rollout status deployment/vault-api -n staging --timeout=3m`
6. Run `curl -sf https://staging.vault.internal/health` to verify
7. Report success or failure with details

Always show me the Helm diff before applying. Never skip the diff step.
```

### `/health-check`
```markdown
# health-check.md

Run a complete health check on the $ARGUMENTS environment (default: staging).

Check:
1. `kubectl get pods -n $ARGUMENTS` — any pods not Running?
2. `kubectl get pods -n $ARGUMENTS | grep -v Running | grep -v Completed` — list unhealthy pods
3. `kubectl top pods -n $ARGUMENTS` — any pods near resource limits?
4. `kubectl get events -n $ARGUMENTS --sort-by=.lastTimestamp | tail -20` — recent events
5. `curl -sf https://$ARGUMENTS.vault.internal/health` — API health endpoint
6. `kubectl logs -n $ARGUMENTS deployment/vault-api --tail=20` — recent app logs

Summarize: HEALTHY / DEGRADED / DOWN with specific issues.
```

Usage:
```
> /health-check staging
> /health-check production
```

### `/explain-failure`
```markdown
# explain-failure.md

A deployment or operation failed with this error: $ARGUMENTS

1. Explain what this error means in plain English (no jargon)
2. List the 3 most likely root causes, ranked by probability
3. For each cause: the diagnostic command to confirm it
4. For each cause: the fix command

Context:
- We run on AWS EKS (Kubernetes 1.29)
- Applications deployed via Helm
- Images in AWS ECR
- Secrets from AWS Secrets Manager

Be specific. Show exact commands.
```

### `/cost-estimate`
```markdown
# cost-estimate.md

Estimate the AWS cost change from the following infrastructure modification:

$ARGUMENTS

Analyze:
1. What resources are being added/changed/removed?
2. Estimated monthly cost BEFORE the change
3. Estimated monthly cost AFTER the change
4. Cost difference (increase/decrease)
5. Any hidden costs (data transfer, API calls, storage growth)

Use ap-south-1 (Mumbai) pricing. Be conservative in estimates.
```

---

## Backend Developer Skills

### `/write-tests`
```markdown
# write-tests.md

Write comprehensive tests for: $ARGUMENTS

If no argument, write tests for the most recently modified function/module.

Test approach:
1. Read the implementation file
2. Identify all code paths, edge cases, and error conditions
3. Write tests covering:
   - Happy path (expected input → expected output)
   - Edge cases (empty, null, boundary values)
   - Error cases (invalid input, dependency failures)
   - Integration points (database, external APIs)

Use our existing test patterns (read existing test files for style).
Use our test framework (check package.json for jest/vitest/mocha).
Mock external services, use real database for integration tests.
```

### `/add-error-handling`
```markdown
# add-error-handling.md

Add proper error handling to: $ARGUMENTS

If no argument, check all recently modified files.

Requirements:
- Use the AppError class (src/utils/error.js)
- All async functions must have try/catch or .catch()
- Database errors must be caught and translated to user-friendly messages
- Never expose internal error details to API responses
- Log all errors with our Winston logger (src/utils/logger.js)
- Return appropriate HTTP status codes

Read the file, identify missing error handling, add it.
```

---

## Frontend Developer Skills

### `/component-review`
```markdown
# component-review.md

Review the React component: $ARGUMENTS

Check for:
1. **Accessibility** — proper ARIA labels, keyboard navigation, color contrast
2. **Performance** — unnecessary re-renders, missing useMemo/useCallback, heavy computations in render
3. **TypeScript** — any 'any' types, missing prop types, unsafe assertions
4. **Error boundaries** — does it handle loading/error states?
5. **Mobile** — responsive? Touch targets ≥ 44px?
6. **Tests** — does it have tests? Are edge cases covered?

Provide specific fixes with code snippets.
```

### `/accessibility-audit`
```markdown
# accessibility-audit.md

Run an accessibility audit on the current UI code.

Check:
1. All images have alt text
2. Form inputs have associated labels
3. Color contrast meets WCAG AA (4.5:1 for text)
4. Interactive elements are keyboard navigable
5. Screen reader order makes sense (DOM order vs visual order)
6. No reliance on color alone to convey meaning
7. Focus indicators are visible

Read the relevant component files and list all violations with severity and fix.
```

---

## Git Workflow Skills

### `/release-notes`
```markdown
# release-notes.md

Generate release notes for version: $ARGUMENTS

Steps:
1. Run `git log --oneline v<previous-version>...HEAD` to get all commits
2. Categorize commits by type (feat/fix/chore/docs)
3. Write release notes in this format:

## What's New (Features)
- [list features from feat: commits]

## Bug Fixes
- [list fixes from fix: commits]  

## Infrastructure & Maintenance
- [list from chore: commits]

Use non-technical language — these notes go to end users.
Omit: dependency updates, test changes, internal refactors.
```

### `/branch-cleanup`
```markdown
# branch-cleanup.md

Clean up merged and stale git branches.

Steps:
1. Run `git branch --merged main` — list locally merged branches
2. Run `git fetch --prune` — sync remote deletions
3. Run `git branch -r --merged origin/main` — merged remote branches
4. Show me the list of branches that can be deleted
5. Wait for my confirmation before deleting anything

DO NOT delete: main, develop, staging, release/*, any branch less than 7 days old.
```

---

## Code Quality Skills

### `/security-audit`
```markdown
# security-audit.md

Run a security audit on: $ARGUMENTS (or the entire codebase if no argument)

Check for:
1. **Injection flaws** — SQL injection, command injection, LDAP injection
2. **Authentication** — hardcoded credentials, weak tokens, missing auth on endpoints
3. **Authorization** — missing access control, privilege escalation paths
4. **Secrets** — API keys, passwords, private keys in code or config
5. **Dependencies** — run `npm audit` (or equivalent) for known CVEs
6. **Cryptography** — weak algorithms (MD5, SHA1, DES), hardcoded IVs/salts
7. **Error handling** — stack traces or internal details exposed to users
8. **Logging** — sensitive data (passwords, tokens) in logs

Report format:
CRITICAL: [immediate risk]
HIGH: [serious risk]
MEDIUM: [significant risk]
LOW: [minor risk]

For each: what it is, why it matters, exact fix.
```

---

## Personal (User-Level) Skills

These go in `~/.claude/commands/` and apply to all projects:

### `~/.claude/commands/daily-standup.md`
```markdown
# daily-standup.md

Based on my git activity and recent Claude conversations, help me write my daily standup.

Run:
1. `git log --author="Shashank" --since="yesterday" --oneline` — what I committed
2. Look at recent conversation context — what was I working on?

Format:
**Yesterday:** [what I did]
**Today:** [what I plan to do based on current work context]
**Blockers:** [anything mentioned that's blocked]

Keep it under 3 sentences per section.
```

### `~/.claude/commands/learning-note.md`
```markdown
# learning-note.md

I just learned something about: $ARGUMENTS

Write a concise learning note I can save:
1. What the concept is (1 sentence)
2. Why it matters (1 sentence)
3. The key command or pattern to remember
4. One common mistake to avoid

Format it as a markdown snippet I can paste into my notes.
```

---

## Common Misunderstanding: "Skills run in a separate context"

**The misunderstanding:** "When I run `/code-review`, Claude doesn't know about our conversation."

**The reality:** Skills run in the SAME session context. When you invoke `/code-review`, Claude receives:
1. The full conversation history (everything said so far)
2. All the context from CLAUDE.md
3. All loaded memories
4. PLUS the skill's prompt

A skill adds a focused instruction to an already-context-rich session. This is why `/code-review` can know about your project's conventions without you putting them in the skill file — they're already in CLAUDE.md.

Design skills to be focused on their specific task. Don't repeat information that's already in CLAUDE.md.

→ Continue to: `../04-agents/00-what-are-agents.md`
