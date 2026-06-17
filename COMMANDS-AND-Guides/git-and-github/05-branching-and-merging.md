# Part 05 — Branching and Merging

Branching is what makes Git so powerful for real-world development. It lets you work on a new feature, a bug fix, or an experiment completely in isolation — without disturbing the working code. Then when you're done, you merge it back.

This is the workflow every professional team uses.

---

## Why You Need Branches

Imagine your codebase is working perfectly. A user reports a critical bug. At the same time, you're halfway through building a new feature that's not ready.

Without branches: You either stop the feature work to fix the bug (losing your in-progress state), or you ship the half-finished feature with the bug fix (dangerous).

With branches:
1. Create a `bugfix` branch from the working main code
2. Fix the bug on the `bugfix` branch
3. Merge the fix into main and ship it
4. Switch back to your feature branch — it's exactly where you left it

---

## `git branch` — Managing Branches

### List all branches:

```bash
git branch
```

Output:
```
  feature-login
* main
  bugfix-timeout
```

The `*` shows which branch you're currently on (the "active" branch). In this case, you're on `main`.

```bash
# List remote branches too
git branch -a

# List only remote branches
git branch -r
```

### Create a new branch:

```bash
git branch feature-payment
```

This creates the branch but does NOT switch to it. You're still on your current branch.

### Delete a branch:

```bash
# Delete a branch (only works if it's been merged)
git branch -d feature-payment

# Force delete (even if not merged — be careful, this loses unmerged work)
git branch -D feature-payment
```

### Rename a branch:

```bash
# Rename the current branch
git branch -m new-name

# Rename a specific branch
git branch -m old-name new-name
```

---

## `git switch` — Changing Branches (Modern Command)

### When do you use this?

Every time you want to move to a different branch. This updates all the files in your working directory to match the state of that branch.

```bash
# Switch to an existing branch
git switch feature-login
```

Output:
```
Switched to branch 'feature-login'
```

Your working directory now reflects the code on `feature-login`. Files that are different between branches will be updated.

### Create a new branch AND switch to it:

```bash
git switch -c feature-signup
# -c means --create
```

This is the single most-used branching command. It combines "create" and "switch" in one step.

Output:
```
Switched to a new branch 'feature-signup'
```

### Create a branch starting from a specific commit (not the current one):

```bash
# Create feature-hotfix starting from the main branch tip (not wherever I am)
git switch -c feature-hotfix main

# Create a branch starting from a specific commit hash
git switch -c bugfix-rollback 5b84053
```

This is useful when you need to branch off from main but you're currently on a feature branch.

---

## `git checkout` — The Older, More Powerful Switch Command

`git switch` was introduced in Git 2.23 (2019) to be clearer and safer. But you'll see `git checkout` everywhere in documentation, StackOverflow, and older tutorials. It does the same thing for branch switching but can also do many other things.

```bash
# Old way (same as git switch)
git checkout feature-login

# Old way to create and switch (same as git switch -c)
git checkout -b feature-signup
```

Both commands work. `git switch` is recommended for switching branches because it's explicit. `git checkout` is still needed for other things (like restoring files).

---

## A Full Branching Workflow Example

```bash
# You're on main, everything is working
git switch main
git status   # clean working tree

# Step 1: Create a branch for your new feature
git switch -c feature-user-profiles

# Step 2: Do your work
# edit files...
git add src/profile.js
git commit -m "feat: add basic user profile page"

# edit more files...
git add src/profile.js src/css/profile.css
git commit -m "feat: add profile photo upload"

# Step 3: Meanwhile, an urgent bug is reported on main!
# Switch back to main first
git switch main
# main is clean — your feature work is safe on feature-user-profiles

# Step 4: Fix the bug
git switch -c bugfix-login-crash
# fix the bug...
git add src/login.js
git commit -m "fix: prevent null pointer crash when user session expires"

# Step 5: Merge the bug fix into main
git switch main
git merge bugfix-login-crash
# Bug is now in main. Delete the fix branch (it's been merged)
git branch -d bugfix-login-crash

# Step 6: Go back and finish your feature
git switch feature-user-profiles
# All your previous work is here, exactly where you left it
```

---

## `git merge` — Combining Branches

### When do you use this?

When your feature/bugfix work is complete and you want to bring those commits into another branch (usually `main`).

**Important:** You merge FROM somewhere INTO the current branch. The current branch is the "receiving" branch.

```bash
# First, switch to the branch you want to merge INTO
git switch main

# Then merge the other branch INTO it
git merge feature-login
```

### Type 1: Fast-Forward Merge

This is the simplest case. It happens when the branch you're merging has a linear history from where main currently is — meaning main hasn't received any new commits since you branched off.

```
BEFORE MERGE:
main:           A ──► B
                       ▲
feature-login:          ──► C ──► D
                                   ▲

AFTER FAST-FORWARD MERGE:
main:           A ──► B ──► C ──► D
                                   ▲
feature-login: (same, still exists as a label)
```

Git simply moves the `main` pointer forward to `D`. No new commit is created.

Output:
```
Updating 5b84053..7f0af4a
Fast-forward
 src/login.js | 15 +++++++++++++++
 1 file changed, 15 insertions(+)
```

### Type 2: Three-Way Merge (Merge Commit)

This happens when both branches have new commits since they diverged. Git needs to combine two different lines of history.

```
BEFORE MERGE:
main:           A ──► B ──► E
                 \
feature-login:    ──► C ──► D

AFTER THREE-WAY MERGE:
main:           A ──► B ──► E ──► M (merge commit)
                 \               /
feature-login:    ──► C ──► D ──
```

Git creates a new "merge commit" `M` that has two parents: `E` (from main) and `D` (from feature-login). It combines the changes from both.

```bash
git merge feature-login
```

Git opens your editor to write a merge commit message (or uses the default "Merge branch 'feature-login'"). Save and close to complete the merge.

### Forcing a merge commit even when fast-forward is possible:

```bash
git merge --no-ff feature-login
```

`--no-ff` (no fast forward) always creates a merge commit. Some teams prefer this because it preserves the record that "these commits were part of feature-login" even after the branch is deleted.

---

## Merge Conflicts — When Two Changes Collide

A merge conflict happens when two branches both modified the same part of the same file. Git doesn't know which version to keep, so it asks you to decide.

### What a conflict looks like:

After running `git merge feature-login`, you might see:

```
Auto-merging src/login.js
CONFLICT (content): Merge conflict in src/login.js
Automatic merge failed; fix conflicts and then commit the result.
```

When you open `src/login.js`, you'll see conflict markers:

```javascript
function login(user, password) {
  const user = findUser(user);

<<<<<<< HEAD
  // main branch version:
  if (user.password === password) {
    return createSession(user);
=======
  // feature-login branch version:
  if (!user) return null;
  if (bcrypt.compare(password, user.passwordHash)) {
    return { session: createSession(user), user };
>>>>>>> feature-login
  }
}
```

Reading the markers:
- `<<<<<<< HEAD` — start of your current branch's version
- `=======` — separator
- `>>>>>>> feature-login` — end of the incoming branch's version

### How to resolve conflicts:

1. **Edit the file** — delete the conflict markers and decide what the final code should look like:

```javascript
function login(user, password) {
  const user = findUser(user);

  // Combined: null check from feature-login + bcrypt from feature-login
  if (!user) return null;
  if (bcrypt.compare(password, user.passwordHash)) {
    return { session: createSession(user), user };
  }
}
```

2. **Stage the resolved file:**
```bash
git add src/login.js
```

3. **Complete the merge:**
```bash
git commit
```

Git will have a default merge commit message ready.

### Abort a merge if you're overwhelmed:

```bash
git merge --abort
```

This cancels the merge entirely and returns you to the state before you started. Use this if you got into a conflict and want to think before continuing.

### Check which files have conflicts:

```bash
git status
```

Files with conflicts show as "both modified" in the status output.

---

## Common Misunderstanding: "I need to be on the branch I'm merging FROM"

**The misunderstanding:** "I want to merge feature-login into main, so I should be on feature-login when I run `git merge`."

**The reality:** You merge INTO the current branch. To merge feature-login into main, you must first:

```bash
git switch main        # ← switch to the DESTINATION branch
git merge feature-login  # ← bring feature-login's work INTO main
```

If you run `git merge main` while on `feature-login`, you bring main INTO feature-login — the opposite of what you wanted. This is a very common mistake.

A helpful mental model: "The current branch receives. The named branch is the donor."

---

## Next Step

Branches and merging are working. Now learn about undoing mistakes — one of the most important Git skills.

→ Continue to: `06-undoing-changes.md`
