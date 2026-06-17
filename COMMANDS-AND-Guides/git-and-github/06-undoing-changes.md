# Part 06 — Undoing Changes: restore, reset, revert, clean

This is one of the most important and most feared parts of Git. Beginners worry about "breaking" history. Experienced developers know that Git's undo system is incredibly safe — if you understand the tools.

There are four different undo tools in Git. Each one operates on a different "level" and has a different safety profile.

---

## The Four Undo Tools and When to Use Each

| Situation | Tool |
|-----------|------|
| Discard uncommitted changes in a file | `git restore` |
| Unstage a file (keep changes) | `git restore --staged` |
| Move the current branch pointer back (rearrange commits) | `git reset` |
| Create a new commit that reverses a previous commit | `git revert` |
| Delete untracked files from the working directory | `git clean` |

---

## `git restore` — The Safest Undo Tool

### When do you use this?

When you made changes to a file and want to throw them away (go back to the last committed state). Or when you staged a file and want to unstage it without losing your changes.

This command only affects the working directory and/or the staging area. **It never touches your commit history.** This is the safest undo command.

### Discard all changes in a file (working directory):

```bash
git restore src/login.js
```

This throws away all changes to `src/login.js` and restores it to exactly what it looked like in the last commit. **The changes are gone permanently** — there is no trash bin or undo. This is the one case where `git restore` is irreversible.

Before running this, make sure you really don't want those changes.

### Discard all changes in the entire working directory:

```bash
git restore .
```

Restores all modified files to their last committed state. All unsaved (unstaged) changes are gone.

### Unstage a file (keep the changes, just remove from staging):

```bash
git restore --staged src/login.js
```

This moves the file from "staging area" back to "working directory". Your changes are still there — you just need to `git add` again if you want them staged.

**Scenario:** You ran `git add .` and accidentally staged `config.env` (which contains passwords). You can unstage it:

```bash
git restore --staged config.env
# Now config.env is modified in working directory but NOT staged
# Add it to .gitignore so this doesn't happen again
```

### Restore a file to a specific commit's version:

```bash
# Bring back the version of src/login.js from 3 commits ago
git restore --source HEAD~3 src/login.js

# Bring back from a specific commit hash
git restore --source 5b84053 src/login.js
```

This is how you "time-travel" a single file without changing anything else. The file will show as "modified" in `git status` (because it now differs from the latest commit), but nothing else changed.

---

## `git reset` — Moving the Branch Pointer

### When do you use this?

When you want to undo commits — remove them from the current branch's history. This is more powerful and more dangerous than `git restore`.

**Critical rule:** Only use `git reset` on commits that you have NOT pushed to a shared remote. If other people have already pulled those commits, resetting will rewrite history and cause major problems for them.

### The three modes of git reset:

All three forms of `git reset` move the current branch pointer back to an older commit. They differ in what happens to the changes from the removed commits:

```bash
# Move back 1 commit. Keep the changes staged.
git reset --soft HEAD~1

# Move back 1 commit. Keep the changes in working directory (unstaged).
git reset --mixed HEAD~1    ← this is the DEFAULT if you omit --soft/--mixed/--hard

# Move back 1 commit. DISCARD the changes completely.
git reset --hard HEAD~1
```

#### Visual explanation:

Imagine your history looks like:

```
A ──► B ──► C ──► D (main, HEAD)
```

You run `git reset HEAD~2` (move back 2 commits to B):

After `--soft`:
```
A ──► B (main, HEAD)   ← C and D's changes are in STAGING AREA
C and D are gone from history but their content is staged
```

After `--mixed` (default):
```
A ──► B (main, HEAD)   ← C and D's changes are in WORKING DIRECTORY
C and D are gone from history, content is unstaged but not deleted
```

After `--hard`:
```
A ──► B (main, HEAD)   ← C and D's changes are GONE PERMANENTLY
Nothing remains of C and D's work
```

---

### Practical use cases:

#### "I committed too early — I want to un-commit my last commit but keep the changes":

```bash
git reset --soft HEAD~1
```

Now the changes are back in the staging area. You can modify them further and re-commit.

#### "I staged the wrong files — I want to start the add/commit process over":

```bash
git reset HEAD~1
# (or git reset --mixed HEAD~1)
```

The commit is undone. All the changes are back in your working directory as unstaged modifications.

#### "I made a terrible commit and want it completely gone":

```bash
git reset --hard HEAD~1
```

The commit and all its changes are permanently removed. **Use with extreme caution.** There is no undo for this (unless you find the commit hash in `git reflog` — see the Advanced Commands guide).

#### "I want to go back multiple commits":

```bash
git reset --hard HEAD~3    # Go back 3 commits
git reset --hard 5b84053   # Go back to a specific commit hash
```

---

## `git revert` — The Safe Way to Undo Shared Commits

### When do you use this?

When you need to undo a commit that has **already been pushed to a shared repository** (GitHub, etc.) and other people may have already pulled it.

`git reset` rewrites history — it removes commits. If you do this on shared history, you cause problems for everyone who has already pulled those commits.

`git revert` works differently: **it creates a NEW commit that does the opposite of the commit you want to undo.** History is not rewritten — the bad commit still exists, but a new commit after it cancels out its changes.

```
BEFORE:
A ──► B ──► C ──► D (bad commit)

AFTER git revert D:
A ──► B ──► C ──► D ──► E (revert of D)
```

Commit `E` contains the exact opposite changes of commit `D`. The net result is as if `D` never happened, but the history shows both `D` and the revert.

### Usage:

```bash
# Revert the most recent commit
git revert HEAD

# Revert a specific commit by hash
git revert 7f0af4a
```

Git opens your editor with a default message like "Revert 'feat: add user registration endpoint'". Save and close to complete the revert commit.

### Revert without opening the editor:

```bash
git revert HEAD --no-edit
```

### Revert multiple commits:

```bash
# Revert a range of commits (from 3 commits ago to 1 commit ago)
git revert HEAD~3..HEAD~1
```

---

## `git clean` — Removing Untracked Files

### When do you use this?

When your working directory has untracked files (files Git doesn't know about) that you want to delete — generated files, build artifacts, temp files you created while experimenting.

**This permanently deletes files from your filesystem.** There is no undo.

### See what would be deleted (dry run, no actual deletion):

```bash
git clean -n
# or
git clean --dry-run
```

Output:
```
Would remove notes.txt
Would remove temp-output.json
```

This is safe to run. It only shows what WOULD be deleted without actually deleting anything. Always run this first.

### Actually delete untracked files:

```bash
git clean -f
# or
git clean --force
```

### Delete untracked files AND untracked directories:

```bash
git clean -fd
```

The `-d` flag includes untracked directories (which would be skipped by default).

### Delete ignored files too (use with extreme caution):

```bash
git clean -fdx
```

The `-x` flag also deletes files that are in `.gitignore`. This would delete your `node_modules/`, `.env`, and other ignored files. Only do this when you want a completely clean slate (like you just cloned fresh).

---

## Decision Tree: Which Undo Tool to Use?

```
Did you make a commit?
│
├── NO: Changes are only in working directory or staging area
│   │
│   ├── Changes are STAGED but you want to UNSTAGE (keep changes):
│   │   └── git restore --staged <file>
│   │
│   └── Changes are in working directory and you want to DISCARD them:
│       └── git restore <file>
│
└── YES: You made one or more commits
    │
    ├── Have you PUSHED these commits to a shared remote?
    │   │
    │   ├── NO: You can safely rewrite history
    │   │   ├── Keep changes (undo commit only): git reset --soft HEAD~N
    │   │   ├── Unstage changes (undo commit + unstage): git reset HEAD~N
    │   │   └── Discard changes completely: git reset --hard HEAD~N
    │   │
    │   └── YES: Don't rewrite history — create a revert commit
    │       └── git revert <commit-hash>
    │
    └── Untracked files you want to delete:
        └── git clean -fd (after git clean -n to preview)
```

---

## Common Misunderstanding: "`git reset --hard` will destroy my project"

**The misunderstanding:** "If I use `git reset --hard` I might lose everything and there's no way back."

**The reality:** `git reset --hard` only destroys changes that were never committed. Any change you DID commit (even if you reset past it) can be recovered using `git reflog` for about 30-90 days. The reflog is Git's safety net — it records every position HEAD has ever been at, including commits that are no longer reachable from any branch.

```bash
# See the reflog — a list of where HEAD has been
git reflog

# Output:
# 7f0af4a HEAD@{0}: reset: moving to HEAD~3
# 5b84053 HEAD@{1}: commit: feat: user profile
# 3c4d5e6 HEAD@{2}: commit: fix: validation bug
# 1a2b3c4 HEAD@{3}: commit: feat: initial setup

# You just reset --hard and regret it? Recover:
git reset --hard 5b84053   # go back to the commit you want
```

So `git reset --hard` is destructive for uncommitted changes, but for committed work, `git reflog` is your safety net.

---

## Next Step

You can now undo mistakes at every level. Next: working with remote repositories — pushing and pulling code with GitHub.

→ Continue to: `07-working-with-remotes.md`
