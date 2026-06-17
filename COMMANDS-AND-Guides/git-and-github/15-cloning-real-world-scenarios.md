# Part 15 — Cloning: Real-World Scenarios, Struggles, and Fixes

`git clone` looks simple. One command and you have the code. But the moment you try to actually work with a cloned repo — push, pull, switch branches, work across teams — the confusion starts. This file covers every real situation you'll face.

---

## What Actually Happens When You Clone (The Full Picture)

When you run `git clone https://github.com/org/project.git`, Git does **six things** silently:

```
1. Creates a folder called "project" on your machine
2. Runs "git init" inside that folder
3. Downloads the ENTIRE repository — every commit, every branch, every tag
4. Creates remote tracking branches: origin/main, origin/feature-xyz, etc.
5. Adds a remote called "origin" pointing to the URL you cloned from
6. Checks out the default branch (usually main) in your working directory
```

This is important because most clone-related confusion comes from not knowing that steps 3–5 happened silently.

---

## Scenario 1: You Cloned, But Now `git push` Is Rejected With "Permission Denied"

**What happened:** You cloned a public repository that you do NOT have write access to.

```bash
git clone https://github.com/some-org/project.git
# Works fine! Cloning is always allowed for public repos.

# You make some changes and try to push...
git push origin main
```

```
ERROR: Permission to some-org/project.git denied to your-username.
fatal: Could not read from remote repository.
```

**Why this happens:** Anyone can clone (read) a public repo. But pushing (writing) requires you to be a collaborator or organization member. Cloning gives you no write access by default.

**Fixes depending on your situation:**

**If you are a collaborator on this repo and just forgot to set up SSH:**
```bash
# Check if your remote is HTTPS (which requires credentials)
git remote -v
# origin  https://github.com/some-org/project.git (fetch)

# Switch to SSH (requires SSH key setup — see file 17)
git remote set-url origin git@github.com:some-org/project.git
git push origin main
```

**If you are NOT a collaborator (contributing to someone else's open-source):**
You need to FORK the repo first, then clone YOUR fork. Then push to your fork and open a PR. You cannot push directly to a repo you don't own. See Part 16 for the full forking workflow.

---

## Scenario 2: You Cloned, But You Only See the `main` Branch

This confuses almost every beginner.

```bash
git clone https://github.com/org/project.git
cd project

git branch
# * main
# That's it? The repo has 10 branches on GitHub but I only see 1?
```

**Why this happens:** When you clone, Git downloads ALL the remote branch data, but it only checks out one local branch (`main`). The other branches exist as **remote tracking branches** — they are there, just not as local branches you can commit to yet.

```bash
# See ALL branches including remote ones
git branch -a

# Output:
# * main
#   remotes/origin/HEAD -> origin/main
#   remotes/origin/main
#   remotes/origin/feature-payment
#   remotes/origin/feature-auth
#   remotes/origin/develop
```

The `remotes/origin/feature-payment` etc. are tracking branches — snapshots of the remote. To actually work on one:

```bash
# Switch to it — Git automatically creates a local branch tracking the remote one
git switch feature-payment

# Output:
# Branch 'feature-payment' set up to track remote branch 'feature-payment' from 'origin'.
# Switched to a new branch 'feature-payment'
```

Now `git branch` shows `feature-payment` as a real local branch.

---

## Scenario 3: Cloning a Specific Branch (Not the Default)

The default clone gives you the default branch (usually `main`). What if you only care about a specific branch?

```bash
# Clone only the 'develop' branch
git clone --branch develop https://github.com/org/project.git

# Clone only the 'develop' branch AND name the folder something specific
git clone --branch develop https://github.com/org/project.git my-local-folder
```

**Note:** Even with `--branch`, Git still downloads all the branch data. The flag only controls which branch is checked out initially.

---

## Scenario 4: "I Cloned but the Repo Is Huge and It's Taking Forever"

Some repositories are massive — thousands of commits over many years. You may not need all that history.

**Shallow clone — only the latest commit:**
```bash
git clone --depth 1 https://github.com/org/huge-project.git
```

This downloads only the most recent snapshot. Clone time goes from minutes to seconds. Great for:
- CI/CD pipelines (you only need the latest code to build/test)
- Just trying out a project
- Deploying code to a server

**Shallow clone with some history:**
```bash
git clone --depth 50 https://github.com/org/huge-project.git
```

Gets the last 50 commits. Useful when you need some history for `git log` and `git blame` but not all 10 years of it.

**The trade-off:** A shallow clone has limited history. `git log` shows only the commits you downloaded. `git blame` may show "Not Committed Yet" for old lines. `git bisect` across the full history won't work.

**Convert a shallow clone to full later:**
```bash
git fetch --unshallow
```

---

## Scenario 5: Cloning Into the Current Directory (Not a Subfolder)

By default, `git clone` creates a new subfolder. What if you want to clone INTO the directory you're already in?

```bash
# You're in /home/shashank/my-project (folder already exists and is empty)
git clone https://github.com/org/project.git .
#                                             ^ the dot means "here"
```

The `.` means "clone into the current directory." The directory must be **empty** for this to work.

---

## Scenario 6: Cloning From a Specific Commit or Tag

You want to start from a known release, not the latest commit:

```bash
# There's no direct "clone at commit X" flag, but you can do this:
git clone https://github.com/org/project.git
cd project

# Now check out the specific version
git checkout v2.1.0          # a tag
git checkout 5b84053         # a specific commit hash
```

Or more cleanly — clone and immediately branch off a specific tag:

```bash
git clone --branch v2.1.0 https://github.com/org/project.git
```

---

## Scenario 7: You Cloned, Made Changes, and Now `git pull` Has Conflicts

```bash
git clone https://github.com/org/project.git
# ... make changes and commit locally ...
git pull
```

```
Auto-merging src/config.js
CONFLICT (content): Merge conflict in src/config.js
Automatic merge failed; fix conflicts and then commit the result.
```

**What happened:** While you were making commits on your local `main`, someone else also pushed commits to `origin/main`. Now both histories have diverged and `git pull` (which runs `git merge` by default) produced a conflict.

**Fix:**

Option A — Merge approach (creates a merge commit):
```bash
# Open the conflicted file, find and resolve the <<< === >>> markers
# Then:
git add src/config.js
git commit   # Git pre-fills a merge commit message
git push
```

Option B — Rebase approach (cleaner history):
```bash
# Undo the pull (which left us in conflict state)
git merge --abort

# Pull using rebase instead
git pull --rebase

# Resolve any conflicts file by file, then:
git add src/config.js
git rebase --continue

# Push
git push
```

**Prevention:** Never commit directly to `main` on a shared repository. Use feature branches. Your local `main` should always mirror `origin/main` (pull without conflicts every time).

---

## Scenario 8: The Remote URL Changed (Repo Renamed or Transferred)

You cloned 6 months ago. The repo was renamed or moved to a different organization. Now `git pull` and `git push` fail.

```
fatal: repository 'https://github.com/old-org/old-name.git/' not found
```

**Fix:**
```bash
# Check your current remote
git remote -v
# origin  https://github.com/old-org/old-name.git (fetch)

# Update to the new URL
git remote set-url origin https://github.com/new-org/new-name.git

# Verify
git remote -v
# origin  https://github.com/new-org/new-name.git (fetch)

# Resume working
git pull
```

---

## Scenario 9: You Want to Clone a Private Repo but Keep Getting "Repository Not Found"

GitHub shows "repository not found" (not "permission denied") even for private repos when you lack access. This is intentional — GitHub doesn't confirm the repo exists to unauthorized users.

**Diagnosis checklist:**

```bash
# 1. Check if you're authenticated via SSH
ssh -T git@github.com
# Should say: Hi username! You've successfully authenticated

# 2. Check if your remote URL matches your actual account/org
git remote -v
# Make sure the org name and repo name are spelled correctly

# 3. If using HTTPS, check if your personal access token is current
# GitHub removed password auth in 2021 — you must use a token
# (See Part 17 for full authentication setup)
```

---

## Scenario 10: Cloning with Multiple GitHub Accounts on One Machine

You have a personal GitHub (`personal-user`) and a work GitHub (`work-user`). Cloning the work repo authenticates as your personal user.

**The problem:** SSH uses one key by default. Git doesn't know which account to use for which repo.

**Solution — SSH config file:**

```bash
# Edit or create ~/.ssh/config
nano ~/.ssh/config
```

```
# Personal GitHub account
Host github.com-personal
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_rsa_personal

# Work GitHub account
Host github.com-work
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_rsa_work
```

Now when cloning, use the Host alias instead of `github.com`:

```bash
# Clone personal repo
git clone git@github.com-personal:personal-user/my-project.git

# Clone work repo
git clone git@github.com-work:work-org/work-project.git
```

Git will use the correct SSH key for each.

**For already-cloned repos with the wrong remote:**
```bash
git remote set-url origin git@github.com-work:work-org/work-project.git
```

---

## Scenario 11: After Clone, `git status` Shows Files as Modified Even Though You Didn't Touch Them

```bash
git clone https://github.com/org/project.git
cd project
git status

# Shows 50 files as modified even though you just cloned!
```

**Most likely cause:** Line ending mismatch. The repo was committed with LF (Linux/Mac) endings but you're on Windows (which uses CRLF). Git sees this as modifications.

**Fix:**
```bash
# Configure git to handle line endings
git config --global core.autocrlf true   # on Windows
git config --global core.autocrlf input  # on Mac/Linux

# Re-clone to get a fresh checkout with the correct settings
```

Or, if the repo has a `.gitattributes` file specifying `* text=auto eol=lf`, the problem should self-resolve. The root cause is usually that the repo itself doesn't enforce line endings.

---

## Best Practices for Cloning

**1. Always clone with SSH, not HTTPS (for repos you'll push to)**

HTTPS requires typing credentials or setting up a credential manager. SSH, once set up, works silently forever.

```bash
# HTTPS (fine for read-only, annoying for pushing):
git clone https://github.com/org/project.git

# SSH (best for repos you'll commit to):
git clone git@github.com:org/project.git
```

**2. After cloning, immediately check the remote**

```bash
git remote -v   # confirm origin points where you expect
git branch -a   # see all available branches
git log --oneline -5   # see the last few commits (sanity check)
```

**3. Never commit directly to `main` in a shared repo**

```bash
git clone https://github.com/org/shared-project.git
cd shared-project
git switch -c your-name/feature-name   # immediately create a branch
```

**4. Set up your identity before committing (if not done globally)**

```bash
git config user.name "Shashank Patil"
git config user.email "shashank@company.com"
# (leave out --global if this should only apply to this project)
```

**5. Delete local branches you're done with**

After your PR is merged, clean up:
```bash
git switch main
git pull
git branch -d feature/payment   # delete local branch
```

---

## Common Misunderstanding: "Cloning creates a live connection that syncs automatically"

**The misunderstanding:** "My local clone will automatically stay in sync with GitHub. If someone pushes, I'll automatically get it."

**The reality:** After cloning, your local repo is a completely independent copy. It does NOT sync automatically with any remote. Changes on GitHub do NOT appear locally until you explicitly run `git fetch` or `git pull`.

The remote tracking branches (`origin/main`, etc.) are updated only when YOU run a fetch or pull. Until then, they show the state of the remote at the last time you synced — they could be days or weeks out of date.

This is why the first thing you should do every morning is `git pull` — to get the latest changes from your team.

---

→ Continue to: `16-forking-real-world-scenarios.md`
