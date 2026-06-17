# Part 11 — Advanced Commands: cherry-pick, bisect, reflog, worktree

These commands are not needed every day, but when you need them, nothing else can replace them. Each solves a specific, precise problem.

---

## `git cherry-pick` — Apply a Specific Commit to Another Branch

### When do you use this?

When you want to take ONE specific commit from one branch and apply it to another branch — without merging the entire branch.

**Real scenario:** You have a `development` branch with 30 commits. One of those commits is a critical bug fix. You need that fix on `main` right now — but the other 29 commits aren't ready to be released yet.

```bash
# You're on main
git switch main

# Find the commit hash of the bug fix on development
git log development --oneline
# 7f0af4a fix: prevent memory leak in session handler  ← you want this one
# 5b84053 feat: half-finished dashboard redesign       ← not ready
# 3c4d5e6 feat: experimental new authentication flow   ← definitely not ready

# Cherry-pick just that one commit
git cherry-pick 7f0af4a
```

Git applies the changes from commit `7f0af4a` to your current branch (`main`) as a new commit. The new commit has a different hash but the same code changes and message.

### Cherry-pick with a custom message:

```bash
git cherry-pick 7f0af4a -e
```

The `-e` opens your editor to modify the commit message before applying.

### Cherry-pick multiple commits:

```bash
# Cherry-pick three specific commits
git cherry-pick abc123 def456 ghi789

# Cherry-pick a range of commits (from 5b84053 up to and including 7f0af4a)
git cherry-pick 5b84053..7f0af4a
```

### Cherry-pick without committing (stage the changes only):

```bash
git cherry-pick 7f0af4a --no-commit
```

Applies the changes to your staging area but doesn't commit. Useful when you want to combine multiple cherry-picks into one commit.

### Handling cherry-pick conflicts:

If the picked commit conflicts with the current branch:

```bash
git cherry-pick 7f0af4a
# CONFLICT!

# Resolve the conflict in the file
git add src/session.js

# Continue the cherry-pick
git cherry-pick --continue

# Or abort it
git cherry-pick --abort
```

---

## `git bisect` — Binary Search Through History to Find a Bug

### When do you use this?

When you know your code worked 100 commits ago and it's broken now, but you don't know WHICH commit introduced the bug. `git bisect` automates a binary search through your history — you just tell it "good" or "bad" at each step, and it finds the culprit in O(log n) steps.

For 1000 commits, you'll find the bad commit in about 10 steps instead of checking all 1000.

### Step-by-step usage:

```bash
# 1. Start bisect
git bisect start

# 2. Tell Git the current commit is "bad" (has the bug)
git bisect bad

# 3. Tell Git a known-good commit (use a tag, hash, or relative ref)
git bisect good v2.0.0
# or
git bisect good 5b84053
```

Git now checks out a commit in the middle of that range and says:

```
Bisecting: 499 revisions left to test after this (roughly 9 steps)
[3c4d5e6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e] feat: add user dashboard
```

You are now at a commit in the middle of the history. Test if the bug exists here:

```bash
# Run your test or manually check if the bug is present
npm test    # or whatever tests the bug

# If the bug IS present (this commit is bad):
git bisect bad

# If the bug is NOT present (this commit is good):
git bisect good
```

Git picks the next midpoint. Repeat. After ~10 steps:

```
7f0af4a3b2c1d4e5f6a7b8c9d0e1f2a3b4c5d6e7 is the first bad commit
commit 7f0af4a3b2c1d4e5f6a7b8c9d0e1f2a3b4c5d6e7
Author: Shashank Patil <shashank@example.com>
Date:   Sat Jun 14 10:30:00 2026 +0530

    feat: add connection pooling to database layer
```

Git found the exact commit that introduced the bug!

```bash
# When done, reset back to the original branch
git bisect reset
```

### Automated bisect with a test script:

If you have a script that returns exit code 0 for "good" and non-zero for "bad":

```bash
git bisect start
git bisect bad HEAD
git bisect good v2.0.0
git bisect run npm test    # runs npm test at each step automatically
```

Git runs your script at each midpoint and uses the exit code to decide good/bad automatically. No manual intervention needed.

---

## `git reflog` — Git's "Undo Everything" Safety Net

### When do you use this?

When you've made a mistake that you think is irreversible — `git reset --hard`, deleted a branch, an interrupted rebase. The reflog is Git's emergency recovery tool.

### What is the reflog?

Git secretly records every position your `HEAD` has ever been at — every checkout, commit, reset, merge, rebase. This log is called the **reflog** (reference log). It exists only locally and entries expire after 90 days by default.

```bash
git reflog
```

Output:
```
7f0af4a (HEAD -> main) HEAD@{0}: commit: feat: add user registration
5b84053 HEAD@{1}: reset: moving to HEAD~1
3c4d5e6 HEAD@{2}: commit: feat: half-finished dashboard  ← we reset away from this!
1a2b3c4 HEAD@{3}: checkout: moving from feature to main
9b8a7c6 HEAD@{4}: commit: fix: typo in README
```

Notice `HEAD@{2}` — a commit we deleted with `git reset --hard`! It still exists in the reflog.

### Recovering a deleted commit:

```bash
# Find the hash of the commit you want to recover
git reflog
# 3c4d5e6 HEAD@{2}: commit: feat: half-finished dashboard

# Option 1: Create a branch at that commit
git switch -c recovery-branch 3c4d5e6

# Option 2: Move the current branch back to it (with hard reset)
git reset --hard 3c4d5e6
```

### Recovering a deleted branch:

```bash
# You accidentally deleted your feature branch
git branch -D feature-payment  # oops!

# Check reflog to find where the branch tip was
git reflog
# 7f0af4a HEAD@{3}: checkout: moving from feature-payment to main

# Recreate the branch at that commit
git branch feature-payment 7f0af4a
```

### Recovering from a botched rebase:

```bash
# Rebase went wrong
git rebase main    # terrible conflicts, everything is broken

# Find the pre-rebase state in reflog
git reflog
# 5b84053 HEAD@{1}: rebase (start): checkout main   ← the state before

# Go back to before the rebase
git reset --hard 5b84053
```

---

## `git worktree` — Multiple Working Directories Simultaneously

### When do you use this?

When you need to look at or work in two different branches at the same time — without constantly switching back and forth. Each `worktree` is a separate folder on disk that is checked out to a different branch, all sharing the same `.git` repository.

**Scenario:** You're deep in a feature. Your manager asks you to review another developer's PR (on a different branch). You don't want to stash your work and switch. Solution: create a second working directory checked out to the review branch.

```bash
# Add a new worktree for the PR branch
git worktree add ../review-branch feature-payment-review

# Now open ../review-branch in another terminal or editor
# It has the feature-payment-review branch checked out
# Your main directory is still on your feature branch

cd ../review-branch
# Review the code, run tests, etc.

# When done, remove the worktree
git worktree remove ../review-branch
```

### List all worktrees:

```bash
git worktree list
```

Output:
```
/home/shashank/vault-app           7f0af4a [main]
/home/shashank/review-branch       5b84053 [feature-payment-review]
```

---

## `git shortlog` — Summarized Contribution Statistics

```bash
# Show how many commits each author has made
git shortlog -s -n

# Output:
#    42  Shashank Patil
#    28  Priya Kumar
#    15  Rahul Singh
```

Useful for understanding contribution distribution on a project.

---

## Common Misunderstanding: "`git reset --hard` is permanent and unrecoverable"

**The misunderstanding:** "If I run `git reset --hard HEAD~5` by accident, my last 5 commits are gone forever."

**The reality:** As long as those commits happened within the last 90 days (or whatever `gc.reflogExpire` is set to), they are in the **reflog** and completely recoverable.

```bash
# Oops — ran git reset --hard HEAD~5 accidentally
git reset --hard HEAD~5

# Recovery:
git reflog
# 7f0af4a HEAD@{0}: reset: moving to HEAD~5    ← the reset we just did
# 3c4d5e6 HEAD@{1}: commit: feat: that thing   ← this is where we were BEFORE
# ... more commits listed as {2}, {3}, {4}, {5} ...

# Go back to where we were
git reset --hard 3c4d5e6
# All 5 commits restored!
```

The reflog is the reason experienced Git users say: "In Git, almost nothing is permanent." The main exceptions:
- Changes to your working directory that were never committed (no reflog entry exists for uncommitted changes)
- Anything that has been garbage collected (after 90 days by default)

---

## Next Step

You're comfortable with advanced Git commands. Now learn about GitHub-specific workflows: pull requests, forks, and collaborating on open-source.

→ Continue to: `12-github-workflows.md`
