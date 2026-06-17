# Part 16 — Forking: Real-World Scenarios, Struggles, and the Upstream Dance

Forking is where most beginners get genuinely lost — not because the commands are hard, but because the **mental model** is broken. There are suddenly two remotes, two `main` branches, and nothing stays in sync automatically. This file fixes all of that.

---

## The Mental Model You MUST Have Before Starting

When you fork, there are **three copies** of the repository:

```
┌──────────────────────────────────────────────────────────────────┐
│                         GITHUB (online)                          │
│                                                                  │
│   [original/project]         ──fork──►  [your-name/project]     │
│   "upstream"                            "origin"                 │
│   (you can't push here)                 (you own this)           │
└──────────────────────────────────────────────────────────────────┘
                                                │
                                           git clone
                                                │
                                                ▼
┌──────────────────────────────────────────────────────────────────┐
│                       YOUR COMPUTER (local)                      │
│                                                                  │
│   [local copy]                                                   │
│   origin → your-name/project                                     │
│   upstream → original/project  (you add this manually)          │
└──────────────────────────────────────────────────────────────────┘
```

- **upstream** = the original repo (you read from it, never push to it)
- **origin** = YOUR fork on GitHub (you push to this)
- **local** = your machine (you work here)

**The most critical thing to understand:** After forking, the original repo and your fork are completely independent. If the original gets 50 new commits, your fork does NOT automatically get them. You must explicitly sync them.

---

## The Complete Forking Setup — Step by Step

This is the full process from fork to first PR. Do this once for any open-source contribution:

### Step 1: Fork on GitHub

Go to the original repo on GitHub → Click **Fork** (top right) → Choose your account.

GitHub creates `your-name/project` as a copy of `original/project` at that moment in time.

### Step 2: Clone YOUR fork (not the original)

```bash
# Clone YOUR fork — not the original!
git clone git@github.com:your-name/project.git
cd project

# Confirm where origin points
git remote -v
# origin  git@github.com:your-name/project.git (fetch)
# origin  git@github.com:your-name/project.git (push)
```

Notice: `origin` points to YOUR fork. That's correct. This is where you'll push your work.

### Step 3: Add the original as "upstream"

```bash
# Add the ORIGINAL repo as a second remote called "upstream"
git remote add upstream git@github.com:original/project.git

# Confirm both remotes now exist
git remote -v
# origin    git@github.com:your-name/project.git (fetch)
# origin    git@github.com:your-name/project.git (push)
# upstream  git@github.com:original/project.git (fetch)
# upstream  git@github.com:original/project.git (push)
```

You now have two remotes. This is the correct state.

### Step 4: Create a branch for your work

```bash
# NEVER work directly on main in a fork
# Always create a branch
git switch -c fix/typo-in-readme
```

### Step 5: Do your work and push to YOUR fork

```bash
# Make your changes
git add README.md
git commit -m "docs: fix typo 'recieve' → 'receive' in README"

# Push to YOUR fork (origin), NOT upstream
git push origin fix/typo-in-readme
```

### Step 6: Open a Pull Request on GitHub

Go to your fork on GitHub. GitHub will show a banner: "fix/typo-in-readme had recent pushes — Compare & pull request."

Click it. Make sure the base repo is set to `original/project` and base branch is `main` (not your fork — the PR should go TO the original, not to yourself).

---

## Scenario 1: Your Fork Is Out of Date With the Original

The most common ongoing struggle. The original repo has moved forward. Your fork is weeks behind. You need to sync.

```bash
# Fetch the latest commits from the original (upstream)
git fetch upstream

# What you'll see:
# From github.com:original/project
#    5b84053..7f0af4a  main -> upstream/main
# (it tells you what new commits were downloaded)

# Switch to your local main
git switch main

# Merge (or rebase) upstream/main into your local main
git merge upstream/main
# or (cleaner):
git rebase upstream/main

# Now push the updated main to YOUR fork on GitHub
git push origin main
```

**After this, your fork's `main` is identical to the original's `main`.** You can now create a fresh branch for new work and it'll be based on the latest code.

---

## Scenario 2: You Made Commits on `main` in Your Fork (The Big Mistake)

You were supposed to create a branch first. Instead, you made commits directly on your fork's `main`. Now main has diverged from upstream and you can't open a clean PR.

```
upstream/main:  A ──► B ──► C ──► D
your fork main: A ──► B ──► X ──► Y  (X and Y are your commits on main)
```

**Fix — salvage your work to a proper branch:**

```bash
# 1. Create a branch where your commits currently are
git branch fix/my-actual-fix     # this preserves X and Y on a new branch

# 2. Reset YOUR main back to match upstream
git fetch upstream
git switch main
git reset --hard upstream/main
# Your main is now identical to upstream: A → B → C → D

# 3. Push the corrected main to your fork (force required because history changed)
git push origin main --force-with-lease

# 4. Now switch to your branch (which still has X and Y)
git switch fix/my-actual-fix

# 5. Rebase it onto the updated main
git rebase main

# 6. Push the branch
git push origin fix/my-actual-fix

# 7. Open a PR from this branch
```

**Why `--force-with-lease` and not `--force`?**
`--force` overwrites the remote no matter what. `--force-with-lease` only overwrites if the remote hasn't been updated by someone else since your last fetch. It's the safer force push — it won't clobber changes you don't know about.

---

## Scenario 3: The Original Repo Got Updates While Your PR Is Still Open

You opened a PR. It's been under review for a week. The original repo merged other PRs. Now your PR shows "This branch is out of date with the base branch."

GitHub will sometimes show a "Update branch" button. But here's how to do it properly from the terminal:

```bash
# Fetch the latest from upstream
git fetch upstream

# Switch to your PR branch
git switch fix/payment-validation

# Rebase your work on top of the latest upstream main
git rebase upstream/main

# If conflicts arise:
# 1. Open the conflicted files
# 2. Resolve the <<< === >>> markers
# 3. git add <resolved-file>
# 4. git rebase --continue
# (Repeat for each commit that conflicts)

# Push the updated branch to your fork
# (Force push is required because rebase rewrites history)
git push origin fix/payment-validation --force-with-lease
```

The PR on GitHub automatically updates. Reviewers will see the updated, conflict-free branch.

---

## Scenario 4: You Opened a PR to the Wrong Target

You meant to open a PR from `your-fork/fix-login` → `original/main`, but you accidentally opened it as `your-fork/fix-login` → `your-fork/main` (contributing to yourself).

**Fix:** GitHub lets you change the base of an open PR.

On the PR page:
- Click **Edit** next to the PR title
- Change the **base repository** to `original/project`
- Change the **base branch** to `main`
- Save

If GitHub doesn't let you change it (sometimes it doesn't for cross-repo PRs), close this PR and open a new one with the correct base.

---

## Scenario 5: You Want to Contribute Multiple Independent Features

Never put two unrelated features on the same branch (and therefore the same PR). Reviewers hate it and it makes merging harder.

**Correct approach: one branch per feature, each from a fresh main:**

```bash
# Feature 1: fix a bug
git switch main
git fetch upstream && git rebase upstream/main   # make sure main is current
git switch -c fix/login-null-check
# ... work and commit ...
git push origin fix/login-null-check
# Open PR for this one

# Feature 2: add a new endpoint (independent work)
git switch main        # go back to clean main
git switch -c feat/user-profile-endpoint
# ... work and commit ...
git push origin feat/user-profile-endpoint
# Open SECOND PR for this one
```

Two PRs. Each can be reviewed and merged independently. If one has problems, it doesn't block the other.

---

## Scenario 6: Upstream Merged Your PR — Now What?

Your PR was accepted and merged into the original repo. Now your fork still has the branch. Here's the full cleanup:

```bash
# 1. Sync your fork's main with upstream (your PR commit is now in upstream/main)
git fetch upstream
git switch main
git merge upstream/main
git push origin main

# 2. Delete the merged branch locally
git branch -d fix/login-null-check

# 3. Delete the branch from your fork on GitHub
git push origin --delete fix/login-null-check

# 4. Your fork is now clean and up to date. Ready for next contribution.
```

---

## Scenario 7: Stale Remote Tracking Branches Cluttering Your List

After months of contributing, `git branch -a` shows dozens of old `remotes/origin/...` branches that no longer exist on GitHub (they were deleted after merging).

```bash
# Remove all remote tracking branches that no longer exist on the remote
git fetch --prune

# Or configure git to prune automatically on every fetch
git config --global fetch.prune true
# Now every git fetch / git pull automatically cleans up stale tracking branches
```

---

## Scenario 8: Understanding What "Syncing From GitHub UI" Actually Does

GitHub has a "Sync fork" button that appeared in 2022. Many people use it without understanding what it does.

**When you click "Sync fork" on GitHub:**
- It merges (or rebases) `upstream/main` into your fork's `main` on GitHub
- Your LOCAL main is NOT updated — you still need to `git pull` locally

```bash
# After using the GitHub "Sync fork" button:
git switch main
git pull   # pulls from origin/main (your fork) which GitHub just updated
```

The GitHub button updates your fork on the server. Your local machine is always separate and needs a separate `git pull`.

---

## Scenario 9: Forking a Private Repository

You can fork private repos within the same organization if your org settings allow it. The workflow is the same. The difference:
- Both the original and your fork are private
- SSH keys or personal access tokens must have repo access
- The fork is also private (defaults to matching the original's visibility)

---

## Scenario 10: The Fork vs Clone Decision — When to Use Which

This decision confuses beginners because both give you a local copy.

| Situation | Use |
|-----------|-----|
| You are a team member with write access to the repo | **Clone** directly. No fork needed. |
| You are contributing to an open-source project you don't own | **Fork**, then clone your fork |
| You are a contractor working on a client's private repo (invited as collaborator) | **Clone** directly |
| You want to experiment with someone else's project without PRs | **Fork** (or just clone if you never plan to push) |
| Your organization uses an "inner source" model with PR reviews | **Fork** if you don't have direct push rights, otherwise **clone** |

**The golden rule:** If you can push directly to the repo, clone it. If you can't, fork it first.

---

## The Upstream Dance — A Quick Daily Reference

This is the routine for any open-source contributor:

```bash
# ─── ONCE (when setting up the repo) ─────────────────────────────
git clone git@github.com:your-name/project.git
cd project
git remote add upstream git@github.com:original/project.git

# ─── BEFORE STARTING ANY NEW FEATURE ────────────────────────────
git fetch upstream                    # get latest from original
git switch main                       # go to your main
git rebase upstream/main              # bring your main current
git push origin main                  # update your fork on GitHub too
git switch -c feature/your-feature    # start a fresh branch

# ─── DAILY (while feature is in progress) ────────────────────────
git fetch upstream
git rebase upstream/main              # keep your branch current

# ─── WHEN FEATURE IS DONE ────────────────────────────────────────
git push origin feature/your-feature
# Open PR on GitHub → original/project ← your-name/project

# ─── AFTER PR IS MERGED ──────────────────────────────────────────
git fetch upstream
git switch main
git rebase upstream/main
git push origin main
git branch -d feature/your-feature
git push origin --delete feature/your-feature
```

---

## Common Misunderstanding: "`origin` is always the original repo"

**The misunderstanding:** "The remote named `origin` points to the original (upstream) repository that I forked from."

**The reality:** `origin` is just a name. By Git convention, `origin` refers to **where you cloned from** — which in a fork workflow is YOUR fork on GitHub, NOT the original.

```
original/project  ← this is "upstream" (name you add manually)
your-name/project ← this is "origin" (added automatically at clone time)
```

This is WHY you get confused when you do `git push origin main` and it goes to your fork, not the original. That is correct behavior. To push to the original, you'd need to be a collaborator AND do `git push upstream main` — which you'd almost never do directly. You push to `origin` and open a PR to `upstream`.

---

→ Continue to: `17-authentication-and-common-errors.md`
