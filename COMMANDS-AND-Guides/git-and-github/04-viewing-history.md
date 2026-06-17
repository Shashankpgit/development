# Part 04 — Viewing History: log, diff, show, blame

You've been making commits. Now you need to look at them — to understand what changed, when, and why. This is something you'll do constantly: investigating bugs, understanding why code was written a certain way, or just reviewing your own work.

---

## `git log` — Viewing the Commit History

### When do you use this?

When you want to see the history of your project: what commits were made, by whom, and when.

### Basic usage:

```bash
git log
```

Output:
```
commit 7f0af4a3b2c1d4e5f6a7b8c9d0e1f2a3b4c5d6e7
Author: Shashank Patil <shashank@example.com>
Date:   Sat Jun 14 10:30:00 2026 +0530

    feat: add user registration endpoint

commit 5b84053f1e2d3c4b5a6f7e8d9c0b1a2f3e4d5c6b
Author: Shashank Patil <shashank@example.com>
Date:   Fri Jun 13 16:45:00 2026 +0530

    fix: prevent duplicate email registration

commit 067906b7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3
Author: Shashank Patil <shashank@example.com>
Date:   Thu Jun 12 09:15:00 2026 +0530

    feat: initial project setup with database connection
```

Press `q` to exit (it opens in a pager program by default).

---

### Compact one-line format:

```bash
git log --oneline
```

Output:
```
7f0af4a feat: add user registration endpoint
5b84053 fix: prevent duplicate email registration
067906b feat: initial project setup with database connection
```

Much more readable. Each commit is one line: short hash + message.

---

### See the actual changes in each commit:

```bash
git log -p
# or
git log --patch
```

This shows the full diff (what lines were added/removed) for every commit. Very detailed — useful when investigating a specific change.

---

### Limit the number of commits shown:

```bash
git log -5          # Show only the last 5 commits
git log -1          # Show only the most recent commit
```

---

### See a visual graph of branches:

```bash
git log --oneline --graph --all
```

Output:
```
* 7f0af4a (HEAD -> main) feat: add user registration endpoint
* 5b84053 fix: prevent duplicate email registration
| * 3c4d5e6 (feature-login) feat: add remember-me checkbox
|/
* 067906b feat: initial project setup with database connection
```

The `*` and lines show how branches diverged and where they are now. `--all` shows commits from all branches, not just the current one.

---

### Filter commits by author:

```bash
git log --author="Shashank"
```

---

### Filter commits by date:

```bash
git log --since="2026-01-01"
git log --until="2026-06-01"
git log --since="2 weeks ago"
git log --since="yesterday"
```

---

### Filter commits by message keyword:

```bash
git log --grep="login"
```

Shows all commits whose message contains the word "login".

---

### See which files were changed in each commit:

```bash
git log --stat
```

Output:
```
commit 7f0af4a
Author: Shashank Patil <shashank@example.com>
Date:   Sat Jun 14 10:30:00 2026 +0530

    feat: add user registration endpoint

 src/routes/auth.js | 42 ++++++++++++++++++++++++++++++
 src/models/user.js | 15 +++++++++++
 2 files changed, 57 insertions(+)
```

`--stat` shows filename + how many lines were added/removed, without showing the actual code.

---

### The most useful combination for daily use:

```bash
git log --oneline --graph --all --decorate
```

- `--oneline` — compact view
- `--graph` — visual branch structure
- `--all` — all branches, not just current
- `--decorate` — shows branch names and tags on commits

---

## `git diff` — Seeing Exactly What Changed

### When do you use this?

When you want to see the actual line-by-line changes in your files — before staging, after staging, or between commits.

### Understanding diff output:

```bash
git diff
```

Output:
```diff
diff --git a/src/login.js b/src/login.js
index 3a1b2c3..7d4e5f6 100644
--- a/src/login.js
+++ b/src/login.js
@@ -15,7 +15,10 @@ function login(user, password) {
   const user = findUser(user);
-  if (user.password === password) {
+  if (!user) {
+    return { error: 'User not found' };
+  }
+  if (bcrypt.compare(password, user.passwordHash)) {
     return createSession(user);
   }
```

Reading the output:
- `--- a/src/login.js` — the old version of the file
- `+++ b/src/login.js` — the new version
- `@@ -15,7 +15,10 @@` — which lines this chunk covers (old file line 15, new file line 15)
- Lines starting with `-` (red) — removed lines
- Lines starting with `+` (green) — added lines
- Lines with neither — unchanged context lines

---

### Three different ways to use git diff:

```bash
# 1. Show changes in working directory NOT yet staged
git diff

# 2. Show changes that ARE staged (what would be committed right now)
git diff --staged
# or
git diff --cached    (same thing, older syntax)

# 3. Show all changes (staged + unstaged) compared to last commit
git diff HEAD
```

This distinction is critical:
- `git diff` — compares working directory to staging area
- `git diff --staged` — compares staging area to last commit
- `git diff HEAD` — compares working directory to last commit

---

### Diff between two commits:

```bash
git diff 5b84053 7f0af4a
```

Shows what changed between commit `5b84053` and commit `7f0af4a`.

```bash
# Shorthand: compare current state to 3 commits ago
git diff HEAD~3
```

`HEAD~3` means "3 commits before HEAD". `HEAD~1` is one commit ago.

---

### Diff between two branches:

```bash
# What changed in feature-login compared to main?
git diff main..feature-login

# What will be new in feature-login when we merge into main?
git diff main...feature-login
```

`..` (two dots) — difference between the tips of both branches
`...` (three dots) — changes in feature-login that are NOT in main (what would be new in a merge)

---

### See only the file names that changed (not the content):

```bash
git diff --name-only
git diff --name-status   # also shows if file was Added, Modified, Deleted
```

Output of `--name-status`:
```
M    src/login.js
A    src/signup.js
D    src/old-auth.js
```

---

## `git show` — Inspect a Single Commit

### When do you use this?

When you want to see everything about one specific commit: the message, who made it, when, and the exact changes.

### Usage:

```bash
# Show the most recent commit
git show

# Show a specific commit by its hash
git show 7f0af4a

# Show a specific commit by relative reference
git show HEAD~2      # 2 commits before current HEAD
```

Output:
```
commit 7f0af4a3b2c1d4e5f6a7b8c9d0e1f2a3b4c5d6e7
Author: Shashank Patil <shashank@example.com>
Date:   Sat Jun 14 10:30:00 2026 +0530

    feat: add user registration endpoint

    Users can now register with email and password. Password is hashed
    with bcrypt before storage. Duplicate emails are rejected.

diff --git a/src/routes/auth.js b/src/routes/auth.js
...
```

### Show just one file from a past commit:

```bash
# Show how src/login.js looked in a specific commit
git show 7f0af4a:src/login.js
```

This is very useful when you want to retrieve an old version of a file without changing your current working directory.

---

## `git blame` — Who Wrote This Line?

### When do you use this?

When you find a suspicious or confusing line of code and need to know who wrote it, when, and in which commit — so you can look at the full context of that change.

### Usage:

```bash
git blame src/login.js
```

Output:
```
7f0af4a3 (Shashank Patil 2026-06-14 10:30:00 +0530 15) function login(user, password) {
5b840537 (Priya Kumar   2026-05-20 14:15:00 +0530 16)   const user = findUser(user);
7f0af4a3 (Shashank Patil 2026-06-14 10:30:00 +0530 17)   if (!user) {
7f0af4a3 (Shashank Patil 2026-06-14 10:30:00 +0530 18)     return { error: 'User not found' };
067906b7 (Shashank Patil 2026-06-12 09:15:00 +0530 19)   }
```

Every line of the file is annotated with:
- The commit hash where it was last changed
- Who changed it
- When
- The line number and content

### Limit to specific lines:

```bash
git blame -L 10,25 src/login.js
```

Shows blame for lines 10 through 25 only.

### Ignore whitespace changes:

```bash
git blame -w src/login.js
```

Whitespace-only changes (like reformatting) won't be attributed — you'll see the original author.

---

## Searching Through Commits

### Find which commit introduced a specific string:

```bash
git log -S "passwordHash"
```

Shows all commits that added or removed the string `passwordHash`. Very useful for finding when a particular piece of code was introduced.

### Find commits that changed a specific function:

```bash
git log -L :login:src/login.js
```

Shows every commit that touched the `login` function in `src/login.js`. This is called a "log -L" (line range) search by function name.

---

## Common Misunderstanding: "`git log` shows me all changes"

**The misunderstanding:** Beginners often think `git log` shows what the code changes were.

**The reality:** By default, `git log` only shows the commit metadata (hash, author, date, message). It does NOT show what code changed. To see the actual code changes you need to add flags:

- `git log -p` — shows the full diff for each commit
- `git log --stat` — shows which files changed and how many lines
- `git show <hash>` — shows the diff for a specific commit

Running plain `git log` and not seeing code changes is the expected behavior — you asked for the history, not the changes. Ask for the changes explicitly with these flags.

---

## Next Step

You can read history and understand what changed. Now learn the most critical skill: **branching** — working on features in isolation without affecting the main code.

→ Continue to: `05-branching-and-merging.md`
