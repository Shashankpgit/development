# Git & GitHub — Complete Learning Guide

A from-scratch, zero-to-master guide to Git. Each file is a self-contained lesson. Read them in order if you're a beginner. Jump to any file as a reference once you know the basics.

Every file includes:
- Deep explanation of WHAT a command does and WHY you'd use it
- Real, explicit, practical examples
- "Common Misunderstanding" section correcting things beginners and mid-level devs get wrong

---

## Reading Order

| File | Topic | Who it's for |
|------|-------|-------------|
| [00 — Introduction & Setup](00-introduction-and-setup.md) | What Git is, installation, `git config` | Absolute beginners |
| [01 — The Mental Model](01-the-mental-model.md) | Working directory, staging area, commits, branches, HEAD | **Read this before anything else** |
| [02 — Starting a Repository](02-starting-a-repository.md) | `git init`, `git clone`, `git status` | Beginners |
| [03 — Staging & Committing](03-staging-and-committing.md) | `git add`, `git commit`, `.gitignore` | Beginners |
| [04 — Viewing History](04-viewing-history.md) | `git log`, `git diff`, `git show`, `git blame` | Beginners |
| [05 — Branching & Merging](05-branching-and-merging.md) | `git branch`, `git switch`, `git merge`, conflicts | Beginners → Intermediate |
| [06 — Undoing Changes](06-undoing-changes.md) | `git restore`, `git reset`, `git revert`, `git clean` | Intermediate |
| [07 — Working with Remotes](07-working-with-remotes.md) | `git remote`, `git fetch`, `git pull`, `git push` | Intermediate |
| [08 — Rebasing](08-rebasing.md) | `git rebase`, interactive rebase, golden rule | Intermediate |
| [09 — Stashing](09-stashing.md) | `git stash` | Intermediate |
| [10 — Tagging](10-tagging.md) | `git tag`, semantic versioning | Intermediate |
| [11 — Advanced Commands](11-advanced-commands.md) | `cherry-pick`, `bisect`, `reflog`, `worktree` | Advanced |
| [12 — GitHub Workflows](12-github-workflows.md) | PRs, forks, code review, `gh` CLI | Intermediate |
| [13 — Config & Aliases](13-config-and-aliases.md) | `.gitconfig`, aliases, hooks, `.gitattributes` | All levels |
| [14 — Real-World Workflows](14-real-world-workflows.md) | GitHub Flow, Gitflow, daily routine, emergency fixes | All levels |
| [15 — Cloning: Real-World Scenarios](15-cloning-real-world-scenarios.md) | Permission errors, shallow clone, multiple accounts, line endings | Beginner → Intermediate |
| [16 — Forking: Real-World Scenarios](16-forking-real-world-scenarios.md) | The 3-copy model, upstream sync, stale forks, PR to wrong target | Intermediate |
| [17 — Authentication & Common Errors](17-authentication-and-common-errors.md) | SSH key setup, PAT, decoding every error message you'll see | All levels |

---

## Quick Command Lookup

| I want to... | Command |
|-------------|---------|
| Start tracking a folder | `git init` |
| Download a repo from GitHub | `git clone <url>` |
| See what's changed | `git status` |
| Stage changes | `git add <file>` or `git add .` |
| Save a snapshot | `git commit -m "message"` |
| See history | `git log --oneline --graph --all` |
| Create a branch | `git switch -c branch-name` |
| Switch branches | `git switch branch-name` |
| Merge a branch | `git merge branch-name` (while on the destination) |
| Discard file changes | `git restore <file>` |
| Unstage a file | `git restore --staged <file>` |
| Undo last commit (keep changes) | `git reset --soft HEAD~1` |
| Undo a pushed commit safely | `git revert <hash>` |
| Save work in progress | `git stash push -m "reason"` |
| Restore stashed work | `git stash pop` |
| Download from remote | `git fetch` or `git pull` |
| Upload to remote | `git push` |
| Clean up commits before PR | `git rebase -i HEAD~N` |
| Find who wrote a line | `git blame <file>` |
| Find which commit broke something | `git bisect start` |
| Recover a deleted commit | `git reflog` |
