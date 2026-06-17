# Part 07 — Working with Remotes: remote, fetch, pull, push

This is where Git meets the outside world. Remote repositories are copies of your project stored on a server (like GitHub) that you and your team can all access. Understanding how local and remote repositories relate to each other is essential for team collaboration.

---

## What is a Remote?

A remote is just a **name** that points to a URL where another copy of your repository lives.

```
Your Computer          GitHub Server
──────────────         ──────────────
Local Repository  ◄──► Remote Repository
(origin/main)          (main)
```

The word **`origin`** is just the conventional default name for the remote you cloned from. It is not special — you could name it anything. But convention is to call it `origin`.

---

## `git remote` — Managing Remote Connections

### List all remotes:

```bash
git remote
```

Output (if you cloned a repo):
```
origin
```

### List remotes with their URLs:

```bash
git remote -v
```

Output:
```
origin  https://github.com/username/vault-app.git (fetch)
origin  https://github.com/username/vault-app.git (push)
```

You see each remote twice — once for fetching (downloading) and once for pushing (uploading). Usually they're the same URL.

### Add a new remote:

```bash
git remote add <name> <url>

# Example:
git remote add origin https://github.com/shashank/vault-app.git
```

This is what you do after `git init` when you've created a repo on GitHub and want to connect it:

```bash
# Standard workflow: create repo on GitHub, then connect local to it
git init
git add .
git commit -m "initial commit"
git remote add origin https://github.com/shashank/vault-app.git
git push -u origin main
```

### Remove a remote:

```bash
git remote remove origin
```

### Rename a remote:

```bash
git remote rename origin upstream
```

### Change a remote's URL (e.g., switching from HTTPS to SSH):

```bash
git remote set-url origin git@github.com:username/vault-app.git
```

---

## Remote Tracking Branches

When you clone a repository, Git creates special "remote tracking branches" — read-only copies of the remote's branches, stored locally. They look like `origin/main`, `origin/feature-login`, etc.

```
Local branches:          Remote tracking branches:
main                     origin/main
feature-login            origin/feature-login
```

The remote tracking branches are updated only when you `git fetch` or `git pull`. They show you the last known state of the remote — like a cached snapshot.

```bash
# See all remote tracking branches
git branch -r
```

Output:
```
  origin/HEAD -> origin/main
  origin/main
  origin/feature-login
  origin/bugfix-timeout
```

---

## `git fetch` — Download Without Merging

### When do you use this?

When you want to download all new commits and branches from the remote, but NOT automatically merge them into your current branch. You want to look first, then decide what to do.

### Usage:

```bash
# Fetch from origin (the default remote)
git fetch

# Fetch from a specific remote
git fetch origin

# Fetch a specific branch
git fetch origin feature-login
```

After fetching, your local remote tracking branches are updated (`origin/main`, etc.), but your local `main` branch is unchanged.

### Why is this useful?

```bash
# Fetch what others have done
git fetch origin

# See what's different between your local main and the remote main
git log main..origin/main --oneline
# This shows commits that are on origin/main but NOT on your local main

# See the actual code changes
git diff main origin/main

# Now you're informed and can merge manually
git merge origin/main
```

`git fetch` is the "safe" way to sync — it never modifies your working directory or current branch. You look at the incoming changes first, then decide.

---

## `git pull` — Download AND Merge

### When do you use this?

When you want to update your current branch with the latest code from the remote. This is `git fetch` + `git merge` combined in one command.

### Usage:

```bash
# Pull changes for the current branch
git pull

# Pull from a specific remote and branch
git pull origin main
```

What happens:
1. Downloads all new commits from `origin/main`
2. Merges them into your current local branch

If you have local commits that others don't have, this creates a merge commit (3-way merge). If only the remote has new commits, it fast-forwards.

### Pull with rebase instead of merge:

```bash
git pull --rebase
```

Instead of creating a merge commit, this "replays" your local commits on top of the fetched commits. The result is a cleaner, linear history. Many teams prefer this.

```
BEFORE:
remote main:    A ──► B ──► C
local main:     A ──► B ──► D (your commit)

AFTER git pull (merge):
local main:     A ──► B ──► C ──► M (merge commit, two parents: C and D)
                                ► D

AFTER git pull --rebase:
local main:     A ──► B ──► C ──► D' (D replayed on top of C, new hash)
```

`git pull --rebase` keeps history linear (no merge commits for trivial syncs).

---

## `git push` — Upload Your Commits to the Remote

### When do you use this?

After making local commits that you want to share with your team or back up to GitHub.

### Basic usage:

```bash
# Push current branch to the remote it tracks
git push

# Push a specific branch to origin
git push origin main

# Push a specific local branch to a remote branch with a different name
git push origin local-branch-name:remote-branch-name
```

### First-time push of a new branch — setting the upstream:

When you create a local branch and push it for the first time, you need to tell Git where it should push to:

```bash
git switch -c feature-payment
# ... make commits ...
git push -u origin feature-payment
```

The `-u` flag sets the "upstream" — it links your local `feature-payment` with `origin/feature-payment`. After this, plain `git push` and `git pull` know where to go without you specifying the remote and branch every time.

```bash
# After -u is set, you can just use:
git push
git pull
```

### See what would be pushed (dry run):

```bash
git push --dry-run
```

### Push all branches:

```bash
git push --all origin
```

### Push tags (tags are not pushed by default):

```bash
git push --tags
```

---

## Understanding Behind/Ahead Status

When you run `git status`, you might see:

```
On branch main
Your branch is ahead of 'origin/main' by 2 commits.
  (use "git push" to publish your local commits)
```

This means: you have 2 local commits that haven't been pushed yet.

Or:

```
Your branch is behind 'origin/main' by 3 commits, and can be fast-forwarded.
  (use "git pull" to update your local branch)
```

This means: there are 3 commits on the remote that you haven't downloaded yet.

Or:

```
Your branch and 'origin/main' have diverged,
and have 1 and 2 different commits each, respectively.
```

This means: both you and the remote have new commits since the last sync — you'll need a merge or rebase when you pull.

---

## A Real Team Collaboration Workflow

Here's the full day-to-day flow when working with a team:

```bash
# Morning: get the latest code before starting work
git switch main
git pull

# Create a branch for your work
git switch -c feature-notifications

# Work all day, make commits
git add src/notifications.js
git commit -m "feat: add email notification service"
git add tests/notifications.test.js
git commit -m "test: add unit tests for notification service"

# Before pushing, make sure you're up to date with main
git fetch origin
git log origin/main..main --oneline   # see if main got new commits

# If main moved forward, rebase your work on top of it
git rebase origin/main

# Push your branch
git push -u origin feature-notifications

# Now go to GitHub and open a Pull Request
# (covered in the GitHub Workflow guide)
```

---

## The Push Rejection Problem

The most common error beginners see:

```
 ! [rejected]        main -> main (fetch first)
error: failed to push some refs to 'https://github.com/...'
hint: Updates were rejected because the remote contains work that you do
hint: not have locally. Integrate the remote changes (e.g.
hint: 'git pull ...') before pushing again.
```

**What happened:** Someone else pushed new commits to the remote after your last pull. The remote is ahead of your local branch.

**Fix:** Pull first, then push.

```bash
git pull origin main    # or git pull --rebase origin main
git push origin main
```

**Never do this unless you are 100% sure:** `git push --force`. Force-pushing overwrites the remote with your local version, destroying the other person's commits. This is a serious mistake in team settings.

---

## Common Misunderstanding: "`git push` saves my work"

**The misunderstanding:** "I should push frequently to make sure my work is saved."

**The reality:** Your work is "saved" (to local history) the moment you `git commit`. Pushing sends those already-saved commits to GitHub. The two operations are independent.

The consequences:
- If you commit but never push, your history is on your machine only. If your laptop dies, you lose everything.
- If you push without committing, you push nothing — there's nothing to push.
- `git push` does not save uncommitted changes (working directory modifications). Only `git commit` does that.

So the habit to build is: commit early and often (saves locally), push at logical checkpoints (shares with team / backs up remotely).

---

## Next Step

You're collaborating with a remote. Now learn about rebasing — the cleaner alternative to merging for keeping history tidy.

→ Continue to: `08-rebasing.md`
