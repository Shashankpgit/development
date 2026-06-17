# Part 12 — GitHub Workflows: Pull Requests, Forks, and Collaboration

GitHub is built on top of Git and adds a collaboration layer: pull requests, code reviews, issue tracking, and project management. This guide explains the human workflows that teams use every day.

---

## The Core Collaboration Model: Feature Branch Workflow

This is the workflow used by most professional teams:

```
1. Start from main (always up to date)
2. Create a feature branch
3. Do your work with commits
4. Push the branch to GitHub
5. Open a Pull Request (PR)
6. Team reviews the code
7. Address review feedback (more commits)
8. PR is approved and merged into main
9. Delete the feature branch
10. Repeat
```

**Main (or master) should always contain working, deployable code.** Feature branches are the experimental space.

---

## Forks vs Clones — Two Different Things

### Clone
When you `git clone` a repository, you get a full local copy of it. You push and pull directly to the original repository. This works when you are a **team member with write access**.

```
[GitHub: org/project]  ─── git clone ──►  [Your Computer: local copy]
                       ◄── git push ───
```

### Fork
When you fork a repository, GitHub creates your own copy of it under your account. You then clone YOUR fork. This is used for:
- Contributing to open source projects (where you don't have write access to the original)
- Making major experimental changes without touching the original

```
[GitHub: original/project]  ─── fork ──►  [GitHub: your-name/project]
                                                    │
                                               git clone
                                                    │
                                                    ▼
                                          [Your Computer: local copy]
```

After making changes, you push to YOUR fork, then open a **Pull Request from your fork to the original**.

### Keeping a fork up to date:

```bash
# Add the original repo as an "upstream" remote
git remote add upstream https://github.com/original-owner/project.git

# Check remotes
git remote -v
# origin    https://github.com/your-name/project.git (fetch)
# origin    https://github.com/your-name/project.git (push)
# upstream  https://github.com/original-owner/project.git (fetch)
# upstream  https://github.com/original-owner/project.git (push)

# Fetch latest changes from the original
git fetch upstream

# Merge the original's main into your local main
git switch main
git merge upstream/main

# Push the updated main to your fork
git push origin main
```

---

## Pull Requests (PRs) — The Heart of GitHub Collaboration

A Pull Request is a request to merge changes from one branch into another. The name comes from "please pull my changes into your branch."

### Opening a PR on GitHub:

1. Push your feature branch: `git push -u origin feature-payment`
2. Go to GitHub — you'll see a banner: "feature-payment had recent pushes — Compare & pull request"
3. Click it, fill in a title and description
4. Click "Create pull request"

### What a good PR description includes:

```markdown
## What this does
Adds payment processing via Stripe. Users can now pay for premium subscriptions.

## Why
Closes #45 — payment functionality was blocking the premium tier launch.

## How to test
1. Create a test account
2. Go to Settings > Upgrade
3. Use test card number: 4242 4242 4242 4242, any future expiry, any CVV
4. Verify subscription status updates to "premium"

## Screenshots
[attach before/after screenshots if UI changed]

## Checklist
- [x] Tests written and passing
- [x] Documentation updated
- [x] No secrets in code
```

### Viewing a PR locally:

Sometimes you need to check out someone else's PR branch to test it:

```bash
# Option 1: Fetch and switch to the PR branch
git fetch origin
git switch feature-payment   # if the branch is in the same repo

# Option 2: GitHub CLI (gh)
gh pr checkout 42   # checkout PR number 42
```

---

## Code Review — Being a Good Reviewer

When reviewing a PR on GitHub:

**Comment on a specific line:** Click the `+` next to a line number → write your comment → "Start a review" (don't submit single comments individually — batch them).

**Comment types:**
- Regular comment — general feedback, doesn't block merge
- Approve — looks good, ready to merge
- Request changes — there are issues that must be fixed before merging

**As the author, responding to review feedback:**

```bash
# Address the feedback in new commits
git add src/payment.js
git commit -m "fix: handle failed payment response as reviewer suggested"

# Push the new commit (it automatically shows up in the open PR)
git push origin feature-payment
```

You don't need to open a new PR. New commits to the same branch automatically appear in the existing PR.

### Resolving review comments:

On GitHub, after fixing an issue, mark the conversation as "Resolved" to show reviewers you addressed it.

---

## Merging a PR

There are three merge options on GitHub:

### 1. Create a merge commit
Creates a merge commit joining the branches. Preserves full history including all individual commits from the feature branch.

```
main: A ──► B ──► M (merge commit, two parents)
                 /
feature:   C ──► D
```

**When to use:** When you want the full commit history visible and the feature is significant enough to warrant seeing it as a distinct unit.

### 2. Squash and merge
Combines all commits from the PR into ONE commit on main. All the "wip", "fix typo" commits disappear — only one clean commit remains.

```
main: A ──► B ──► S (squash commit = all of C+D+E combined)
```

**When to use:** When the feature branch has messy commits (lots of "wip", "fix", "fix again"). Most teams prefer this for cleaner main branch history.

### 3. Rebase and merge
Replays each commit from the PR onto main, one by one. Linear history, no merge commit.

```
main: A ──► B ──► C' ──► D' ──► E' (C, D, E from feature, now on main)
```

**When to use:** When the individual commits are high quality and meaningful, and you want linear history without a merge commit.

---

## Issues — Tracking Work and Bugs

GitHub Issues are tickets for tracking bugs, features, and tasks. They integrate with PRs.

### Linking a PR to an issue:

In your PR description or a commit message, include:
```
Closes #45
Fixes #45
Resolves #45
```

When the PR is merged, GitHub automatically closes issue #45. The issue gets a note saying "This was closed by PR #72."

---

## GitHub CLI (`gh`) — Git Operations from the Terminal

Install the GitHub CLI:
```bash
# Ubuntu/Debian
sudo apt install gh

# After install, authenticate:
gh auth login
```

Useful commands:

```bash
# Create a PR from the current branch
gh pr create --title "feat: add payment" --body "Adds Stripe integration"

# Create PR and open in browser
gh pr create --web

# List open PRs
gh pr list

# Check out PR #42 locally
gh pr checkout 42

# View PR status (checks, reviews)
gh pr status

# View PR #42 details
gh pr view 42

# Merge PR #42
gh pr merge 42

# Create an issue
gh issue create --title "Bug: login fails on mobile" --body "Steps to reproduce..."

# List issues
gh issue list

# View a repo in browser
gh repo view --web
```

---

## Branch Protection Rules

On GitHub, you can protect branches (usually `main`) to enforce rules:

- **Require pull request reviews** — no direct push to main, must go through PR
- **Require status checks** — CI tests must pass before merge is allowed
- **Require branches to be up to date** — feature branch must have the latest main before merging
- **Prevent force push** — no `git push --force` on main

These are configured under: GitHub repo → Settings → Branches → Branch protection rules.

---

## Common Misunderstanding: "A Pull Request merges automatically when approved"

**The misunderstanding:** "Once my PR has enough approvals, it merges on its own."

**The reality:** GitHub PRs do NOT auto-merge (unless you explicitly enable the "Auto-merge" feature on a specific PR). Someone must click the "Merge" button. Even with 10 approvals, the PR sits open until a human (or a bot with the right permissions) merges it.

Approval just means reviewers have said "this is ready" — the actual merge is a separate deliberate action. This prevents accidental merges and gives the author (or release manager) control over timing.

---

## Next Step

You understand GitHub collaboration. Now learn about Git configuration, aliases, and workflow customization to make Git faster to use.

→ Continue to: `13-config-and-aliases.md`
