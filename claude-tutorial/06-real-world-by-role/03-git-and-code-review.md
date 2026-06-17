# Claude Mastery — 18: Claude for Git and Code Review

> **Last updated:** June 17, 2026
> **Covers:** Commits, PRs, branches, code review, git history, merge conflicts

**20-minute read. Git work is where Claude saves the most time on the mechanical parts.**

---

## The Git Problem Claude Solves

The mechanical parts of git work are tedious:
- Writing good commit messages (most people write bad ones)
- Generating PR descriptions that explain the WHY
- Reviewing your own code before pushing
- Untangling complicated merge conflicts
- Figuring out who changed what and why

Claude handles all of these. You do the actual thinking; Claude handles the writing.

---

## Commits

### `/commit` — Let Claude Write the Commit Message

```bash
# After staging your changes:
git add src/auth/jwt.js tests/auth/

# Then in Claude Code:
> /commit
```

Claude:
1. Reads `git diff --staged`
2. Understands what the changes DO (not just what files changed)
3. Writes a commit message that describes the WHY
4. Shows you the message before committing
5. Commits with your approval

**Example output:**
```
git diff shows: added exp field check + iat validation to JWT middleware

Message draft:
"fix(auth): reject JWTs with missing or future iat claim

Tokens were accepted if iat (issued-at) was absent or in the future,
allowing clock-skew attacks. Now validates that iat exists and is not
more than 30s ahead of server time."
```

Compare that to what most people write: "fix auth bug"

### Writing Commit Messages Manually (With Claude's Help)

```
> "Write a commit message for the changes I just staged"
[Same as /commit but more conversational]

> "I staged a bunch of changes. Write separate commit messages for each 
   logical change so I can commit them separately"
[Claude suggests how to split staged changes into atomic commits]
```

---

## Pull Requests

### `/pr` — Create a PR With a Real Description

```
> /pr
```

Claude:
1. `git log main..HEAD` → reads all commits in the branch
2. `git diff main...HEAD` → reads all changes
3. Writes a PR with:
   - Title that summarizes the work
   - Why section: what problem this solves
   - What changed: bullet list of key changes
   - Test plan: what the reviewer should check
   - Screenshots placeholder (if frontend changes detected)
4. `gh pr create` → creates it on GitHub

**The output (not a generic template, an actual description):**
```
Title: Add email verification to registration flow

## Why
Registration was allowing unverified emails, causing issues with
account recovery and support. This adds the required verification step.

## What Changed
- New `email_verified` column + migration (nullable until backfill)
- Verification token service with 24h expiry
- POST /api/auth/verify-email endpoint
- Registration now sends verification email via SendGrid
- Resend endpoint: POST /api/auth/resend-verification

## Test Plan
- [ ] Register with a new email → verify email arrives
- [ ] Click the verification link → account marked verified
- [ ] Try expired link (24h+) → appropriate error
- [ ] Login without verifying → check if you want to block/allow
```

---

## Code Review

### Reviewing Your Own Code Before Pushing

```
> /review
```

Claude spawns a `code-reviewer` agent (fresh context — unbiased) and reviews:
- Logic errors and edge cases
- Security issues
- Missing tests
- Error handling gaps
- Performance problems

```
> "Review the changes in this branch before I make a PR"
[Same as /review but more explicit]

> "Focus the review on security — this is a payment flow"
[Directs the review focus]
```

### Reviewing Others' Code

```
> "Review PR #42 and give me your analysis"
[With GitHub MCP] Claude reads the PR diff and gives detailed feedback

> "I'm reviewing https://github.com/org/repo/pull/42 — 
   summarize what changed and flag anything concerning"
[Without MCP] Paste the diff into the conversation, Claude reviews
```

**What Claude catches that humans miss in self-review:**
- Missing null checks (you assumed it would always be set)
- SQL injection via string interpolation
- Race conditions in concurrent code
- Cases where error is silently swallowed
- Missing test cases for the unhappy path

---

## Release Notes

### `/release-notes` Skill

```
> /release-notes
```

Claude:
1. `git log previous-tag..HEAD --oneline`
2. Groups commits by type (features, fixes, improvements, breaking changes)
3. Writes human-readable release notes

```
## v2.3.0 — June 17, 2026

### New Features
- Email verification is now required for new accounts
- Password strength meter on the registration form
- Export vault to encrypted JSON file

### Bug Fixes
- Fixed race condition in concurrent registration requests
- Fixed dropdown menu flickering near screen edges
- Fixed Enter key not submitting login form from password field

### Security
- JWT tokens now validate iat (issued-at) claim
- Rate limiting added to all authentication endpoints
```

---

## Merge Conflicts

```
> "I have merge conflicts. Help me resolve them."

Claude:
1. git status → sees which files have conflicts
2. Reads each conflicted file (both HEAD and theirs)
3. Understands what BOTH changes were trying to do
4. Proposes the correct merged version
5. Asks you to confirm before resolving
```

**Example:**
```
Conflict in src/services/vaultService.js

HEAD (your branch): Added encryption to the save function
theirs (main): Added audit logging to the save function

These are compatible — both changes should be kept.
Proposed resolution: apply encryption first, then audit log.
[Shows merged code]
Shall I apply this resolution?
```

---

## Git History and Archaeology

```
> "Who changed the JWT token expiry and why?"

Claude:
1. git log -S "expiry" -- src/auth/
2. git show <commit>
3. Reads the commit message and diff
4. Reports: "Changed in commit a3f2b1 on March 15 by @developer: 
   'Reduce JWT expiry from 30 days to 24 hours per security audit finding'"
```

```
> "When was the payment service added and what was the original design?"

Claude:
1. git log --follow src/services/paymentService.js
2. git show <first-commit>
3. Reports the original implementation and what has changed since
```

```
> "Find the commit that broke the user signup flow. 
   It was working last week."

Claude:
1. git log --oneline -30  [last 30 commits]
2. Looks for changes to auth/registration related files
3. Suggests candidate commits
4. Can help you run git bisect to find the exact breaking commit
```

---

## Branch Management

```
> "What branches do I have? Which can be deleted?"

Claude:
1. git branch --merged main  [branches already merged]
2. git branch --no-merged main  [branches with unmerged work]
3. Lists each unmerged branch with last commit date and message
4. Suggests which look abandoned vs active
```

```
> "I made commits on main by mistake. Move them to a new branch."

Claude:
1. git log --oneline [shows commits]
2. Identifies the commits that shouldn't be on main
3. Creates new branch at current HEAD
4. Resets main back to before those commits
5. Warns: "Are you sure? This will rewrite main's history. 
   If others have pulled, they'll have conflicts."
```

---

## Gitignore and .gitattributes

```
> "What should be in my .gitignore for a Node.js + Docker project?"

Claude generates the appropriate .gitignore with explanations:
- node_modules/ (dependencies, never commit)
- .env (secrets)
- dist/ (build output)
- .DS_Store (macOS metadata)
- *.log (log files)
- .docker/data (local Docker volumes)
```

---

## Common Misunderstanding: "Claude's commit messages are too verbose"

**The misunderstanding:** "The commit messages Claude writes are too long — I prefer one-liners."

**The reality:** You can tune this. Tell Claude your preference:

```
> "Write commit messages in this format: 
   <type>(<scope>): <short description>
   No body, no footer. Keep it under 72 chars."
   
[Save this in your CLAUDE.md under ## Commit conventions]
```

Or put it in CLAUDE.md permanently:
```markdown
## Commit Message Convention
- Format: type(scope): description
- Types: feat, fix, chore, refactor, test, docs
- Max 72 characters, no body
- Examples:
  feat(auth): add email verification step
  fix(vaults): prevent concurrent write race condition
```

After that, Claude automatically follows your format for every commit.

→ Continue to: `../07-advanced-mastery/00-prompt-engineering.md`
