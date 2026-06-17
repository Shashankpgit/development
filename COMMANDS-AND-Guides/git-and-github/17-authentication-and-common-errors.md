# Part 17 — Authentication, SSH Setup, and Decoding Common Errors

This file covers the single biggest friction point for beginners: getting Git to talk to GitHub without password prompts, permission errors, and mysterious failures. Then it covers every common error message you'll see and exactly what to do about each one.

---

## The Authentication Problem

GitHub removed password-based authentication for Git operations in August 2021. If you try to push with a username and password, you get:

```
remote: Support for password authentication was removed on August 13, 2021.
remote: Please see https://docs.github.com/get-started/getting-started-with-git/...
fatal: Authentication failed for 'https://github.com/...'
```

There are now two ways to authenticate: **SSH keys** (recommended) and **Personal Access Tokens** (for HTTPS).

---

## Method 1: SSH Keys (The Best Long-Term Solution)

SSH keys are like a padlock + key system. You give GitHub your padlock (public key). When you connect, you prove you have the matching key (private key). No passwords. No tokens to manage. Works silently forever once set up.

### Step 1: Check if you already have SSH keys

```bash
ls -la ~/.ssh
```

If you see files like `id_rsa` and `id_rsa.pub` (or `id_ed25519` and `id_ed25519.pub`), you already have keys. Skip to Step 3.

If the folder doesn't exist or is empty, generate new keys.

### Step 2: Generate a new SSH key pair

```bash
ssh-keygen -t ed25519 -C "your_email@example.com"
```

`ed25519` is the modern, recommended key type (faster and more secure than the older `rsa`).

The `-C` comment is just a label — use your email so you can identify which key is which when you have multiple.

It will ask:
```
Enter file in which to save the key (/home/shashank/.ssh/id_ed25519):
```
Press Enter to accept the default location.

```
Enter passphrase (empty for no passphrase):
```
Press Enter twice for no passphrase (simpler, fine for most personal machines). Or set a passphrase for extra security (you'll type it when SSH first loads the key per session).

Result:
```
Your identification has been saved in /home/shashank/.ssh/id_ed25519
Your public key has been saved in /home/shashank/.ssh/id_ed25519.pub
```

### Step 3: Add your PUBLIC key to GitHub

```bash
# Copy the public key to clipboard
cat ~/.ssh/id_ed25519.pub
# This prints something like:
# ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA... your_email@example.com
```

Copy that entire line. Then:

1. Go to GitHub → Profile picture (top right) → **Settings**
2. Left sidebar → **SSH and GPG keys**
3. Click **New SSH key**
4. Title: give it a name (e.g., "My Laptop", "Work MacBook")
5. Key type: Authentication Key
6. Key: paste the entire public key
7. Click **Add SSH key**

### Step 4: Test the connection

```bash
ssh -T git@github.com
```

If this is your first time connecting to GitHub via SSH, you'll see:
```
The authenticity of host 'github.com (...)' can't be established.
Are you sure you want to continue connecting (yes/no/[fingerprint])? 
```
Type `yes` and press Enter.

Success response:
```
Hi shashank! You've successfully authenticated, but GitHub does not provide shell access.
```

If you see your username, SSH is working.

### Step 5: Switch existing clones from HTTPS to SSH

Any repos you cloned with HTTPS will still use HTTPS. Update them:

```bash
# Check current remote
git remote -v
# origin  https://github.com/username/project.git (fetch)

# Switch to SSH
git remote set-url origin git@github.com:username/project.git

# Verify
git remote -v
# origin  git@github.com:username/project.git (fetch)
```

**For all future clones**, use the SSH URL:
```bash
# Click "Code" on GitHub → SSH tab → copy the git@ URL
git clone git@github.com:username/project.git
```

---

## Method 2: Personal Access Token (PAT) for HTTPS

If you must use HTTPS (some corporate networks block SSH), use a Personal Access Token instead of a password.

### Create a Personal Access Token on GitHub:

1. GitHub → Settings → **Developer settings** (bottom of left sidebar)
2. **Personal access tokens** → **Tokens (classic)**
3. **Generate new token (classic)**
4. Name: "My Laptop Git Access"
5. Expiration: 90 days (or custom — shorter is safer)
6. Scopes: check `repo` (full repository access)
7. Click **Generate token**
8. **Copy the token immediately** — GitHub shows it only once

### Use the token as your password:

When git asks for credentials:
- Username: your GitHub username
- Password: paste the token (not your actual GitHub password)

### Store the token so you don't type it every time:

```bash
# Store credentials in the OS keychain (recommended):
git config --global credential.helper store    # stores in plaintext file ~/.git-credentials
git config --global credential.helper cache    # stores in memory for 15 minutes

# On macOS, use the keychain:
git config --global credential.helper osxkeychain

# On Windows, use the credential manager:
git config --global credential.helper manager-core
```

After configuring, the next time you push/pull Git will ask for credentials once, then remember them.

---

## SSH Agent — Making SSH Work Without Typing Passphrase Repeatedly

If you set a passphrase on your SSH key, you'd have to type it every single push. The SSH agent stores the unlocked key in memory for your session.

```bash
# Start the SSH agent (if not already running)
eval "$(ssh-agent -s)"

# Add your key to the agent
ssh-add ~/.ssh/id_ed25519
# (type your passphrase once — it's now stored for this session)
```

To have this happen automatically every terminal session, add to your `~/.bashrc` or `~/.zshrc`:

```bash
# Auto-start SSH agent and add key if not already added
if [ -z "$SSH_AUTH_SOCK" ]; then
    eval "$(ssh-agent -s)"
    ssh-add ~/.ssh/id_ed25519
fi
```

---

## Decoding Common Error Messages

### Error 1: "Permission denied (publickey)"

```
git@github.com: Permission denied (publickey).
fatal: Could not read from remote repository.
```

**Meaning:** SSH is trying to authenticate but GitHub is rejecting the key.

**Diagnosis:**
```bash
# Test SSH connection
ssh -T git@github.com

# Test with verbose output to see what's happening
ssh -vT git@github.com

# Check which keys SSH is trying
ssh-add -l
# If it says "The agent has no identities", run:
ssh-add ~/.ssh/id_ed25519
```

**Common causes and fixes:**
- Public key not added to GitHub → Go to GitHub Settings → SSH keys and add it
- Using the wrong key → Check `~/.ssh/config` to ensure correct key is mapped
- SSH agent not running → Run `eval "$(ssh-agent -s)" && ssh-add ~/.ssh/id_ed25519`
- Wrong remote URL (using `https://` when you want SSH) → `git remote set-url origin git@github.com:...`

---

### Error 2: "Repository not found"

```
ERROR: Repository not found.
fatal: repository 'https://github.com/org/project.git/' not found
```

**Meaning:** GitHub can't find this repository for you — either it doesn't exist, or you don't have access.

**Important:** GitHub intentionally says "not found" even for private repos you don't have access to (so you can't probe for the existence of private repos).

**Diagnose:**
```bash
# Check if the URL is correct (spelling matters!)
git remote -v

# Check if you're authenticated
ssh -T git@github.com    # for SSH
# or
git credential reject    # clear cached HTTPS credentials and try again
```

**Common causes:**
- Typo in repo name or org name
- Repo was renamed → update remote URL
- Repo is private and you're not a collaborator → ask the owner to add you
- You're authenticated as the wrong account

---

### Error 3: "Failed to push some refs" / "Updates were rejected"

```
 ! [rejected]        main -> main (fetch first)
error: failed to push some refs to 'github.com:...'
hint: Updates were rejected because the remote contains work that you do
hint: not have locally.
```

**Meaning:** The remote branch has commits that your local branch doesn't. Git refuses to push because doing so would destroy those remote commits.

**Fix:**
```bash
# Pull first (gets the remote commits)
git pull --rebase   # recommended (keeps history clean)
# or
git pull            # creates a merge commit

# Resolve any conflicts, then push
git push
```

**When NOT to just pull:** If you intentionally reset/rewrote your local history and need to push the new version (e.g., after an interactive rebase), use:
```bash
git push --force-with-lease
```
Only do this on branches that ONLY you are working on. Never force-push `main` on a shared repo.

---

### Error 4: "Your branch is ahead of 'origin/main' by N commits"

```
On branch main
Your branch is ahead of 'origin/main' by 3 commits.
  (use "git push" to publish your local commits)
```

**Meaning:** You have made 3 commits locally that haven't been pushed to GitHub yet. This is NOT an error — it's just informational.

**Fix:** Just push when you're ready:
```bash
git push
```

---

### Error 5: "Your branch is behind 'origin/main' by N commits"

```
Your branch is behind 'origin/main' by 5 commits, and can be fast-forwarded.
  (use "git pull" to update your local branch)
```

**Meaning:** Someone pushed 5 new commits to the remote since your last sync. Your local branch is outdated.

**Fix:**
```bash
git pull
```

---

### Error 6: "Merge conflict" During Pull

```
Auto-merging src/app.js
CONFLICT (content): Merge conflict in src/app.js
Automatic merge failed; fix conflicts and then commit the result.
```

**Meaning:** Both you and someone else changed the same part of the same file. Git can't decide which version to keep.

**Fix step by step:**

```bash
# See which files have conflicts
git status
# (look for "both modified" entries)

# Open each conflicted file
# Find and resolve the <<< === >>> markers:
#
# <<<<<<< HEAD
# your version of the code
# =======
# their version of the code
# >>>>>>> origin/main
#
# Delete the markers, keep what the final code should be.

# After fixing each file:
git add src/app.js

# Once ALL conflicts are resolved:
git commit    # Git pre-fills a merge commit message, save it
```

---

### Error 7: "Detached HEAD state"

```
You are in 'detached HEAD' state. You can look around, make experimental
changes and commit them, and you can discard any commits you make in this
state without impacting any branches by switching back to a branch.
```

**Meaning:** `HEAD` is pointing directly at a commit instead of pointing at a branch. You're in "time travel" mode — you've checked out an old commit or a tag.

**It's NOT dangerous to be here.** You can look around freely.

**The danger:** If you make NEW commits here, they have no branch to attach to. If you switch away without creating a branch, those commits become orphaned and can be lost.

**Fix — create a branch here if you want to keep any commits you make:**
```bash
git switch -c my-experiment-branch
# Now you're on a proper branch. Any new commits are safe.
```

**Fix — if you just want to go back to where you were:**
```bash
git switch main   # or whatever branch you want
```

---

### Error 8: "Cannot lock ref" or "Unable to update local ref"

```
error: cannot lock ref 'refs/remotes/origin/main': is at abc123 but expected xyz789
fatal: failed to update HEAD
```

**Meaning:** A stale lock file or corrupted reference is blocking Git.

**Fix:**
```bash
# Remove stale lock files
find .git -name "*.lock" -delete

# Or clean up packed refs
git remote prune origin
git gc --prune=now
```

---

### Error 9: "SSL certificate problem" Behind a Corporate Proxy

```
fatal: unable to access 'https://github.com/...':
SSL certificate problem: unable to get local issuer certificate
```

**Meaning:** Your corporate network intercepts HTTPS traffic and replaces SSL certificates. Git doesn't trust the proxy's certificate.

**Fix (temporary — use with caution, only on trusted corporate networks):**
```bash
git config --global http.sslVerify false
```

**Better fix:** Get the corporate root certificate from your IT team and add it to Git's trust store:
```bash
git config --global http.sslCAInfo /path/to/corporate-cert.crt
```

**Best fix:** Use SSH instead of HTTPS — SSH is usually not intercepted by corporate proxies.

---

### Error 10: "Everything up-to-date" When You Know There Are Changes

```
git push
# Everything up-to-date
# But you see new commits on GitHub...
```

**Meaning:** You're pushing a branch that's already up to date on the remote. You might be on the wrong branch, or your local tracking is wrong.

**Diagnosis:**
```bash
git status              # which branch are you on?
git branch -a           # see all branches
git log --oneline -5    # see recent commits on current branch
git fetch origin        # refresh your view of the remote
git log origin/main --oneline -5  # see what's on origin
```

---

## Quick Authentication Status Check

Run this checklist whenever Git operations fail mysteriously:

```bash
# 1. What is your current remote setup?
git remote -v

# 2. Can you reach GitHub via SSH?
ssh -T git@github.com

# 3. Which branch are you on and what is its upstream?
git status

# 4. Is your local branch tracking a remote branch?
git branch -vv
# Output like:
# * main  5b84053 [origin/main] feat: add auth
# If no [origin/...] shown, the branch has no upstream set

# 5. Set upstream if missing:
git push -u origin main
```

---

## Best Practices for Authentication

1. **Always use SSH** for personal machines. Set it up once and forget about it.
2. **Use PAT with credential store** for shared machines or CI/CD where SSH keys are impractical.
3. **Set PAT expiration** — 90 days is a good balance. Calendar-remind yourself to rotate.
4. **Never paste your SSH private key anywhere** — only the `.pub` file goes to GitHub.
5. **Never commit credentials** — API keys, passwords, tokens. Use `.gitignore` and environment variables.
6. **For CI/CD pipelines** (GitHub Actions, Jenkins), use deploy keys or machine tokens — never your personal SSH key.

---

## Common Misunderstanding: "SSH is complicated, HTTPS is simpler"

**The misunderstanding:** "HTTPS is simpler because I just type my username and password."

**The reality:** GitHub removed password authentication in 2021. HTTPS now requires a Personal Access Token — which means:
- Generating a token on GitHub
- Copying and storing it somewhere safe
- Entering it when prompted (or configuring a credential manager)
- Rotating it when it expires

SSH requires more setup upfront (generate key pair, add public key to GitHub), but after that it works silently forever — no prompts, no tokens to manage, no expiration. In the long run, SSH is far simpler.

The common beginner experience: Start with HTTPS, hit the "password auth removed" error, panic, generate a PAT, forget where they stored it, it expires, repeat. Switch to SSH once and never deal with it again.

---

→ This completes the Git & GitHub guide series. For quick reference, see `README.md`.
