# Part 14 — Real-World Workflows: How Teams Use Git

All the individual commands mean nothing without understanding how they fit together in a daily development workflow. This guide describes the actual patterns that professional teams use.

---

## GitHub Flow — Simple and Effective (Most Teams)

This is the most widely adopted workflow. It has one rule: **main is always deployable.**

```
main: A ──► B ──────────────────────────── M (merged feature)
              \                            /
feature:       C ──► D ──► E ──► F ──────
```

### The full cycle, step by step:

```bash
# 1. Start fresh from the latest main
git switch main
git pull

# 2. Create a branch with a descriptive name
git switch -c feature/user-authentication

# (Convention: use lowercase-with-hyphens, optionally prefix with type)
# Examples: feature/payment-gateway, fix/login-timeout, chore/update-dependencies

# 3. Work in small, logical commits
git add src/auth.js
git commit -m "feat: add JWT token generation"

git add src/middleware/auth.js
git commit -m "feat: add authentication middleware"

git add tests/auth.test.js
git commit -m "test: add tests for JWT authentication"

# 4. Keep your branch up to date with main (do this daily)
git fetch origin
git rebase origin/main
# (This keeps your branch current and reduces conflicts at merge time)

# 5. Push your branch
git push -u origin feature/user-authentication

# 6. Open a Pull Request on GitHub
# Fill in: what, why, how to test

# 7. Address review feedback (more commits to the same branch)
git add src/auth.js
git commit -m "fix: use environment variable for JWT secret (review feedback)"
git push

# 8. PR is approved → merge (squash merge on GitHub, or rebase merge)

# 9. Delete the feature branch (cleanup)
git switch main
git pull
git branch -d feature/user-authentication
# Delete remote branch too:
git push origin --delete feature/user-authentication
```

---

## Gitflow — For Projects with Scheduled Releases

Gitflow is a more structured workflow used for software that has distinct release cycles (e.g., mobile apps, packaged software). It has multiple long-lived branches with specific roles.

### Branches in Gitflow:

| Branch | Purpose |
|--------|---------|
| `main` | Production code. Only contains released versions. Tagged with version numbers. |
| `develop` | Integration branch. All features merge here first. |
| `feature/*` | Individual features, branched from develop |
| `release/*` | Prep branch for a release (bug fixes only) |
| `hotfix/*` | Emergency fixes for production bugs (branched from main) |

### The Gitflow cycle:

```bash
# Feature development:
git switch develop
git switch -c feature/payment
# ... work ...
git switch develop
git merge --no-ff feature/payment
git branch -d feature/payment

# Preparing a release:
git switch -c release/2.0.0 develop
# Bug fixes only, no new features on this branch
# Bump version numbers
git commit -m "chore: bump version to 2.0.0"
# When ready:
git switch main
git merge --no-ff release/2.0.0
git tag -a v2.0.0 -m "Release 2.0.0"
git switch develop
git merge --no-ff release/2.0.0    # merge back to develop too
git branch -d release/2.0.0

# Emergency hotfix for production:
git switch -c hotfix/login-crash main    # branches from MAIN, not develop
# Fix the bug
git switch main
git merge --no-ff hotfix/login-crash
git tag -a v2.0.1 -m "Hotfix: login crash"
git switch develop
git merge --no-ff hotfix/login-crash     # merge to develop too
git branch -d hotfix/login-crash
```

**Gitflow is powerful but complex.** Most startups and small teams don't need it. GitHub Flow covers 90% of use cases. Use Gitflow only if you have multiple versions of your software in production simultaneously (e.g., supporting v1.x and v2.x at the same time).

---

## Trunk-Based Development — For Large, Fast-Moving Teams

Used by Google, Facebook, and many large tech companies. The idea: **everyone commits to `main` (trunk) daily.** Feature branches exist for at most a few days.

The key technology that makes this work: **feature flags** (also called feature toggles). New, incomplete features are deployed to production but hidden behind a flag. The flag is turned off until the feature is complete.

```bash
# Very short-lived branches (hours to days, never weeks)
git switch -c fix/typo-in-header
# small, complete change
git commit -m "fix: correct spelling of 'Authentication' in header"
git push
# Open PR → fast review → merge → delete branch
```

The trade-off: requires a mature CI/CD pipeline with fast tests, and discipline about feature flags.

---

## The Daily Routine of a Developer

Here's a concrete day-to-day workflow:

```bash
# --- MORNING: Sync with the team ---
git switch main
git pull
# Check what came in overnight:
git log --oneline -10

# Switch back to your feature branch
git switch feature/payment

# Rebase onto latest main (bring in any changes from overnight)
git rebase origin/main

# --- DURING THE DAY: Work in commits ---
# After writing a logical chunk of code:
git status               # see what changed
git diff                 # review the actual changes
git add -p src/payment.js  # stage only the parts you want
git commit -m "feat: validate credit card number format"

# Another chunk:
git add src/payment.js tests/payment.test.js
git commit -m "test: add Luhn algorithm validation tests"

# --- END OF DAY: Push your progress ---
git push origin feature/payment

# --- WHEN FEATURE IS DONE: Clean up before PR ---
git log --oneline main..feature/payment   # see all your commits
# If there are messy commits, clean them up:
git rebase -i main
# Squash or reword as needed

# Final push (force push after rebase rewrites history)
git push --force-with-lease origin feature/payment

# Open PR on GitHub
```

---

## Handling the "Oh No" Moments

### "I committed directly to main by accident"

```bash
# Create a new branch to save the commit
git branch feature/accidental-commit

# Move main back one commit (your commit is now only on the feature branch)
git reset --hard HEAD~1

# Now push the feature branch and open a PR properly
git push origin feature/accidental-commit
```

### "I pushed sensitive data (password/API key) to GitHub"

This is serious. Just deleting the file and committing again is NOT enough — the key is still in history.

```bash
# First: rotate the credential immediately (change the password/key)
# The leaked key should be considered permanently compromised.

# Remove the file from ALL of history using git filter-branch (older) or
# BFG Repo Cleaner (faster, recommended):

# Using BFG:
java -jar bfg.jar --delete-files secret.env
git reflog expire --expire=now --all && git gc --prune=now --aggressive
git push --force --all

# Then tell everyone on the team to reclone the repo
# Their local copies still have the old history
```

### "My branch is so far behind main it'll never merge cleanly"

```bash
git switch feature/old-branch
git fetch origin
git rebase origin/main
# Resolve conflicts file by file
# git add each resolved file
# git rebase --continue after each
# If it's too painful: git rebase --abort and do a merge instead
git merge origin/main
```

### "I accidentally deleted a branch"

```bash
# Find the commit the branch pointed to using reflog
git reflog | grep "feature-payment"
# 7f0af4a HEAD@{4}: checkout: moving from feature-payment to main

# Recreate the branch
git branch feature-payment 7f0af4a
```

---

## Commit Message Conventions at a Team Level

Having consistent commit messages across a team makes the history a powerful tool. The most popular standard is **Conventional Commits**:

```
<type>[optional scope]: <description>

[optional body]

[optional footer]
```

Types:
- `feat` — new feature
- `fix` — bug fix
- `docs` — documentation only
- `style` — formatting, missing semicolons (no logic change)
- `refactor` — code change that neither fixes a bug nor adds a feature
- `test` — adding tests
- `chore` — build process, tooling, dependencies
- `perf` — performance improvement
- `ci` — CI/CD configuration
- `revert` — reverting a previous commit

Examples:
```
feat(auth): add JWT-based session management
fix(payment): prevent double-charge on network timeout
docs(readme): add development setup instructions
chore(deps): upgrade eslint to v9.0.0
feat!: change API response format (BREAKING CHANGE)
```

The `!` after the type indicates a breaking change.

---

## Quick Reference Card

```
Daily workflow:
  git pull                      ← sync with remote
  git switch -c feature/name    ← new branch
  git status                    ← check state
  git add -p                    ← stage carefully
  git commit -m "type: msg"     ← commit
  git push                      ← share
  git rebase origin/main        ← stay current

Viewing:
  git log --oneline --graph --all  ← history
  git diff                         ← unstaged changes
  git diff --staged                ← staged changes
  git show <hash>                  ← one commit

Undoing:
  git restore <file>           ← discard working changes
  git restore --staged <file>  ← unstage
  git reset --soft HEAD~1      ← undo commit, keep staged
  git revert <hash>            ← safe undo for pushed commits

Saving work temporarily:
  git stash push -m "reason"   ← save without committing
  git stash pop                ← restore

Cleanup:
  git branch -d feature/done   ← delete local branch
  git push origin --delete feature/done  ← delete remote
  git fetch --prune            ← remove stale remote tracking branches
```

---

## Congratulations

You've completed the full Git guide. Here's what you now know:

| File | What You Learned |
|------|-----------------|
| 00 | Installation and first-time setup |
| 01 | The three-area mental model, commits, branches, HEAD |
| 02 | git init, git clone, git status |
| 03 | git add, git commit, .gitignore |
| 04 | git log, git diff, git show, git blame |
| 05 | git branch, git switch, git merge, merge conflicts |
| 06 | git restore, git reset, git revert, git clean |
| 07 | git remote, git fetch, git pull, git push |
| 08 | git rebase, interactive rebase |
| 09 | git stash |
| 10 | git tag |
| 11 | git cherry-pick, git bisect, git reflog, git worktree |
| 12 | GitHub: PRs, forks, code review, branch protection |
| 13 | Config, aliases, hooks, .gitattributes |
| 14 | Real-world workflows: GitHub Flow, Gitflow, daily routine |

The only thing left is practice. Build real projects, make real mistakes, and use these guides as a reference when you need them.
