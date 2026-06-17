# Part 08 — Rebasing: rebase and Interactive Rebase

Rebasing is one of the most powerful Git tools, and also one of the most misunderstood. Once you understand it, it becomes something you reach for daily to keep your commit history clean and readable.

---

## What is Rebasing?

When you merge two branches, Git creates a merge commit that joins two lines of history. The result shows that the branches diverged and came back together.

Rebasing does something different: it **replays your commits on top of another branch's tip**, making it appear as if your work was done after the other branch's latest commit — even if it wasn't.

### Merge vs Rebase — Visual Comparison:

```
STARTING STATE:
main:           A ──► B ──► C
                 \
feature:          ──► D ──► E


AFTER MERGE (git merge main while on feature):
feature:  A ──► B ──► C ──► M (merge commit)
                 \          /
                  ──► D ──► E


AFTER REBASE (git rebase main while on feature):
feature:  A ──► B ──► C ──► D' ──► E'
```

With rebase, `D` and `E` become `D'` and `E'` — they are NEW commits with new hashes. Git took the changes from `D` and `E` and re-applied them on top of `C`. The history is linear.

---

## `git rebase` — Basic Usage

### When do you use this?

When you are working on a feature branch and the main branch has moved forward while you were working. You want to bring your feature branch up to date with the latest main — without creating a merge commit.

### Usage:

```bash
# You are on your feature branch
git switch feature-payment

# Rebase feature-payment on top of main
git rebase main
```

What happens:
1. Git finds the common ancestor of `feature-payment` and `main` (where they diverged)
2. Git temporarily "lifts" your commits off the branch
3. Git moves the branch to point to the tip of `main`
4. Git replays each of your commits one-by-one on top of main

If each replayed commit applies cleanly, the rebase finishes automatically. If a conflict arises during replay, Git pauses and asks you to resolve it.

### Handling conflicts during rebase:

```bash
git rebase main
# Conflict! Git pauses.

# 1. Open the conflicted file(s) and resolve them
# (Same process as merge conflicts — remove the <<<<<<< markers)

# 2. Stage the resolved files
git add src/payment.js

# 3. Continue the rebase
git rebase --continue

# Git replays the next commit...
# If another conflict: resolve, add, continue again
```

### Abort a rebase if you're overwhelmed:

```bash
git rebase --abort
```

Returns everything to exactly how it was before you started the rebase.

---

## Interactive Rebase — Rewriting Your Own History

Interactive rebase is a powerful tool for **cleaning up your commit history before sharing it.** You can reorder, combine, edit, or delete commits.

### When do you use this?

Before pushing a feature branch for review. Your feature branch might have commits like:

```
5f6a7b8  wip
4e5d6c7  fix typo
3d4c5b6  fix typo again
2c3b4a5  almost done
1b2a3c4  feat: add payment form
```

This is messy. Before opening a pull request, you can clean this up into one beautiful commit:

```
7a8b9c0  feat: add payment processing with Stripe integration
```

### How to use interactive rebase:

```bash
# Interactively rebase the last 5 commits
git rebase -i HEAD~5
```

Git opens your editor with a list of commits:

```
pick 1b2a3c4 feat: add payment form
pick 2c3b4a5 almost done
pick 3d4c5b6 fix typo again
pick 4e5d6c7 fix typo
pick 5f6a7b8 wip

# Commands:
# p, pick   = use commit as-is
# r, reword = use commit, but edit its message
# e, edit   = use commit, but stop to amend it
# s, squash = combine this commit with the previous one (keeps both messages)
# f, fixup  = combine with previous, discard THIS commit's message
# d, drop   = remove this commit entirely
```

The commits are listed **oldest first** (top = oldest). You edit this list and save the file. Git executes what you wrote.

### Example — Squashing 5 messy commits into 1 clean one:

Change the file to:

```
pick 1b2a3c4 feat: add payment form
f    2c3b4a5 almost done
f    3d4c5b6 fix typo again
f    4e5d6c7 fix typo
f    5f6a7b8 wip
```

`f` (fixup) means: combine this commit with the one above it and use the ABOVE commit's message (discard this commit's message).

Save and close. Git creates one new commit containing all the changes but using only the message from `1b2a3c4`.

### Example — Rewrite a commit message:

```
r 1b2a3c4 feat: add payment form
pick 2c3b4a5 ...
```

Change `pick` to `r` (reword) for any commit whose message you want to change. Git will pause and open an editor for you to rewrite that message.

### Example — Reorder commits:

Just move the lines around! The order you list them is the order Git replays them.

```
pick 3d4c5b6 feat: add database migration
pick 1b2a3c4 feat: add payment form    ← moved to second position
pick 2c3b4a5 feat: add payment tests   ← moved to third
```

### Example — Delete a commit entirely:

Change `pick` to `d` (drop) or simply delete the line:

```
pick 1b2a3c4 feat: add payment form
d    2c3b4a5 wip - accidentally committed debug logs
pick 3d4c5b6 feat: add payment tests
```

---

## The Golden Rule of Rebasing

**Never rebase commits that exist on a public/shared branch.**

Rebasing rewrites commit history — it creates new commits with new hashes. If you rebase commits that others have already pulled, their copy of history will conflict with yours. This causes serious problems for the entire team.

**Safe to rebase:**
- Your local feature branch that hasn't been pushed yet
- Your local feature branch that YOU pushed but no one else has pulled yet (e.g., a branch you created just for a PR)

**Never rebase:**
- `main` branch (shared by everyone)
- Any branch that multiple people are collaborating on
- Commits that have already been incorporated into others' work

A simple test: **"Has anyone else pulled these commits?"** If yes → use `git revert`. If no → `git rebase` is fine.

---

## `git pull --rebase` — Keep Clean History When Syncing

```bash
git pull --rebase
```

This is equivalent to:
```bash
git fetch origin
git rebase origin/main
```

Instead of creating a merge commit when you pull new changes, it replays your local commits on top of the incoming commits. The result is a clean, linear history without "merge branch 'main' of github.com/..." clutter.

Many teams configure this as the default pull behavior:

```bash
git config --global pull.rebase true
```

Now every `git pull` uses rebase by default.

---

## Rebase vs Merge — When to Use Which

| Situation | Use |
|-----------|-----|
| Updating your feature branch with the latest main (before pushing) | `git rebase main` |
| Cleaning up messy commits before code review | `git rebase -i HEAD~N` |
| Integrating a completed feature into main (for clean history) | `git rebase` then fast-forward merge |
| Integrating a completed feature into main (to preserve the merge point) | `git merge --no-ff` |
| Undoing commits that others have already pulled | `git revert` (never rebase) |

---

## Common Misunderstanding: "Rebase and merge do the same thing, rebase is just cleaner"

**The misunderstanding:** "Both rebase and merge bring the code together, so they're interchangeable. Rebase is the modern, cleaner way."

**The reality:** They differ in two important ways beyond aesthetics:

1. **Rebase rewrites commit hashes.** When you rebase, your commits get NEW hash IDs (`D'` and `E'` instead of `D` and `E`). They look like the same commits but they're technically different objects. This matters for `git bisect`, `git cherry-pick`, and anyone who has referenced those original hashes.

2. **Rebase replays each commit independently.** If a conflict exists, you might need to resolve it multiple times (once per commit that conflicts). With merge, you resolve all conflicts once in the merge commit.

3. **Merge preserves the true history.** If three developers each worked on a branch for two weeks and the work was merged, the merge commit shows exactly when and where that happened. Rebase makes it look like everyone worked sequentially, which can be misleading for very large team projects.

Neither is universally "better." Most teams choose rebase for feature branch cleanup and merge for integrating large features into main.

---

## Next Step

You've mastered the core workflow. Next: stashing — saving unfinished work temporarily without committing it.

→ Continue to: `09-stashing.md`
