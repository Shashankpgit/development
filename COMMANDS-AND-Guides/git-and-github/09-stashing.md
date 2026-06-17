# Part 09 — Stashing: Saving Work Without Committing

---

## What is Stashing and Why Do You Need It?

You're in the middle of building a feature. Your working directory has half-finished changes. Suddenly, your manager says: "There's a critical bug in production — fix it now!"

You can't commit your half-finished work (it doesn't even compile). You can't switch branches with uncommitted changes if those changes conflict with the other branch's files. What do you do?

**`git stash` saves your uncommitted changes to a temporary "stash stack" and clears your working directory.** You can then switch branches, fix the bug, come back, and pop your stash to restore your work-in-progress exactly as you left it.

Think of it like putting your work-in-progress papers in a drawer, cleaning your desk, doing something else, and then taking the papers back out.

---

## `git stash` — Save Changes to the Stash

### Basic stash (most common usage):

```bash
git stash
```

This:
1. Takes all modified tracked files and staged changes
2. Saves them to the stash
3. Clears your working directory to a clean state (matching the last commit)

Output:
```
Saved working directory and index state WIP on main: 5b84053 feat: add login page
```

Your working directory is now clean. You can switch branches freely.

### Stash with a descriptive message:

```bash
git stash push -m "half-finished payment form, need to add validation"
```

The message helps you remember what each stash was about when you have multiple stashes.

### Include untracked files in the stash:

By default, `git stash` does NOT include untracked files (new files that haven't been `git add`-ed):

```bash
git stash -u
# or
git stash --include-untracked
```

### Include everything including ignored files:

```bash
git stash -a
# or
git stash --all
```

---

## `git stash list` — View All Stashes

```bash
git stash list
```

Output:
```
stash@{0}: WIP on feature-payment: 3c4d5e6 half-finished payment form, need to add validation
stash@{1}: WIP on main: 5b84053 feat: add login page
stash@{2}: WIP on feature-profile: 1a2b3c4 profile photo upload
```

Stashes are numbered `{0}`, `{1}`, `{2}` etc. **`stash@{0}` is always the most recent stash.** When you add a new stash, it becomes `{0}` and all others shift up by one.

---

## `git stash pop` — Restore and Remove the Most Recent Stash

```bash
git stash pop
```

This:
1. Takes the most recent stash (`stash@{0}`)
2. Applies those changes back to your working directory
3. Removes it from the stash list

**Use `pop` when you are done with the stash and don't need it anymore.**

### Pop a specific stash (not just the most recent):

```bash
git stash pop stash@{2}
```

---

## `git stash apply` — Restore Without Removing

```bash
git stash apply
```

Same as `pop`, but keeps the stash in the list after applying it. Useful when you want to apply the same stash to multiple branches.

```bash
# Apply the most recent stash (keeps it in the list)
git stash apply

# Apply a specific stash (keeps it in the list)
git stash apply stash@{1}
```

---

## `git stash drop` — Delete a Stash Without Applying It

```bash
# Drop the most recent stash
git stash drop

# Drop a specific stash
git stash drop stash@{1}
```

Use this when you realize you don't need a saved stash anymore.

---

## `git stash clear` — Delete ALL Stashes

```bash
git stash clear
```

Deletes every stash. **This cannot be undone.** Use with caution.

---

## `git stash show` — Preview What's in a Stash

```bash
# Show a summary of what's in the most recent stash
git stash show

# Show the full diff
git stash show -p

# Show a specific stash
git stash show stash@{1}
git stash show -p stash@{1}
```

Output of `git stash show`:
```
 src/payment.js | 23 +++++++++++++++++++++++
 1 file changed, 23 insertions(+)
```

Output of `git stash show -p` (with -p for patch/diff):
```diff
diff --git a/src/payment.js b/src/payment.js
index 3a1b2c3..7d4e5f6 100644
--- a/src/payment.js
+++ b/src/payment.js
@@ -0,0 +1,23 @@
+function processPayment(amount, cardDetails) {
...
```

---

## Creating a Branch From a Stash

Sometimes you realize the work you stashed has grown complex enough to deserve its own branch:

```bash
git stash branch feature-payment stash@{0}
```

This:
1. Creates a new branch called `feature-payment` at the commit where you stashed
2. Applies the stash to the new branch
3. Drops the stash (since it's now on the branch)

---

## A Full Real-World Stash Example

```bash
# You're working on a feature
git switch feature-notifications
# ... editing src/notifications.js ...
# Work is half done, doesn't compile

# Urgent bug reported! Switch to main needed.
git stash push -m "notification service - email template half done"

# Clean working directory now
git status   # nothing to commit, working tree clean

# Fix the bug
git switch main
git switch -c bugfix-login-null-check
# ... fix the bug ...
git add src/login.js
git commit -m "fix: handle null user in login"
git switch main
git merge bugfix-login-null-check
git push origin main

# Done. Go back to your feature work.
git switch feature-notifications
git stash pop   # restore your half-finished notifications work

# Continue where you left off
```

---

## Stash Conflicts

If changes in your stash conflict with changes that happened while you were away (because the branch moved forward), applying the stash can produce conflicts — just like a merge conflict:

```bash
git stash pop
# CONFLICT! Git tells you which files have conflicts

# Open the file, resolve the conflict markers
# Same process as merge conflicts

git add src/notifications.js
git stash drop   # if it was a pop that left the stash, clean it up manually
```

Note: `git stash pop` with a conflict does NOT automatically drop the stash (because the pop partially failed). You need to `git stash drop` manually after resolving the conflicts.

---

## Common Misunderstanding: "Stashed changes are saved permanently like commits"

**The misunderstanding:** "I can stash things and they'll be safe forever, even if I switch computers or reinstall Git."

**The reality:** Stashes are stored in your local `.git` folder, just like commits. They persist across branch switches and reboots — but:

1. They are **local only** — stashes are never pushed to GitHub. They only exist on your machine.
2. `git stash clear` or `git stash drop` permanently deletes them.
3. They can be lost if you do something that corrupts the `.git` folder.

For anything you want to genuinely save and share, commit it (even with a "WIP" message). You can clean up the commit message later with `git commit --amend` or interactive rebase.

A common workflow for "saving" work in progress:

```bash
git add -A
git commit -m "WIP: half-done notification service — NOT for review"
# Now it's in history, safe to push if needed
# Later, clean it up with interactive rebase before code review
```

---

## Next Step

You can save and restore in-progress work. Next: tagging — marking specific commits as releases or important milestones.

→ Continue to: `10-tagging.md`
