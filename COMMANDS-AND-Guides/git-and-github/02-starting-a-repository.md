# Part 02 — Starting a Repository: init, clone, status

This file covers the three commands you use when beginning any Git work:
- `git init` — turn an existing folder into a Git repository
- `git clone` — download an existing repository from the internet
- `git status` — check what is going on in your repository right now

---

## `git init` — Creating a New Repository

### When do you use this?

Use `git init` when you have a folder (project) on your computer that has no Git history yet, and you want to start tracking it with Git.

### What it does:

Running `git init` creates a hidden `.git` folder inside your project. That folder is the repository — it contains the entire history, configuration, and all Git metadata. **Your actual project files are untouched.**

### How to use it:

```bash
# Navigate to your project folder first
cd my-project

# Initialize Git
git init
```

Output:
```
Initialized empty Git repository in /home/shashank/my-project/.git/
```

### You can also create and init in one step:

```bash
# Create the folder and initialize Git inside it
git init my-new-project
cd my-new-project
```

### What's inside the .git folder?

You'll never need to touch these files directly, but knowing they exist removes the mystery:

```
.git/
├── config          ← repository-specific configuration
├── HEAD            ← which branch you're currently on
├── objects/        ← all your commits, file contents (the actual data)
├── refs/           ← pointers to branches and tags
└── hooks/          ← optional scripts that run at certain events
```

Everything Git knows about your project is in this one folder. **If you delete `.git/`, you destroy all of your history** and the folder becomes a plain, untracked directory again. Your files will still be there, but all commits and history are gone.

### Practical Example — Starting a new project from scratch:

```bash
mkdir vault-app
cd vault-app
git init

# Create your first file
echo "# Vault App" > README.md

git status     # see that README.md is untracked
git add README.md
git commit -m "initial commit: add README"
```

---

## `git clone` — Downloading an Existing Repository

### When do you use this?

Use `git clone` when the repository already exists somewhere (GitHub, GitLab, a coworker's server) and you want to get a full copy of it on your machine.

### What it does:

- Downloads the entire repository — all files, all branches, and the complete commit history
- Creates a local folder with the repository name
- Automatically sets up a "remote" called `origin` pointing to where you cloned from
- Checks out the default branch (usually `main`) so you can start working immediately

### How to use it:

```bash
# Clone using HTTPS (simpler, no SSH key needed):
git clone https://github.com/username/repository-name.git

# Clone using SSH (faster, requires SSH key setup):
git clone git@github.com:username/repository-name.git
```

After running this, a new folder is created:

```bash
git clone https://github.com/username/vault-app.git
# This creates a folder called "vault-app" in your current directory
cd vault-app
```

### Clone into a specific folder name:

```bash
# Instead of creating "repository-name", create "my-local-name"
git clone https://github.com/username/repository-name.git my-local-name
```

### Verify the clone worked:

```bash
cd vault-app
git log --oneline   # see the commit history
git remote -v       # see where "origin" points
```

Output of `git remote -v`:
```
origin  https://github.com/username/vault-app.git (fetch)
origin  https://github.com/username/vault-app.git (push)
```

This tells you that `origin` (the nickname for the remote) points to the GitHub URL — both for fetching (downloading) and pushing (uploading).

### Shallow clone (for large repositories):

If a repository has thousands of commits and you just want to work with it without downloading all of history:

```bash
git clone --depth 1 https://github.com/username/large-repo.git
```

`--depth 1` gives you only the latest commit. Useful for CI/CD pipelines or when the history doesn't matter to you.

---

## `git status` — Your Daily Health Check

### When do you use this?

Constantly. `git status` is the most-run Git command. Use it before `git add`, after `git add`, before `git commit` — basically any time you want to understand the current state of your working directory.

### What it does:

Tells you:
1. Which branch you're on
2. What files have been modified but not staged
3. What files are staged (ready to commit)
4. What files are untracked (Git doesn't know about them)
5. If you're behind or ahead of the remote branch

### How to read the output:

#### Scenario 1 — Clean repository (nothing to do):

```bash
git status
```

```
On branch main
nothing to commit, working tree clean
```

This means your working directory exactly matches the last commit. No changes anywhere.

---

#### Scenario 2 — You modified a file but haven't staged it:

```
On branch main
Changes not staged for commit:
  (use "git add <file>..." to update what will be committed)
  (use "git restore <file>..." to discard changes in working directory)

        modified:   src/login.js

no changes added to commit (use "git add" and/or "git commit -a")
```

"Changes not staged for commit" = **modified in working directory, NOT in staging area.**

The file `src/login.js` has been changed, but you haven't `git add`-ed it yet. If you commit right now, this file's changes will NOT be included.

---

#### Scenario 3 — You ran `git add` (file is staged):

```
On branch main
Changes to be committed:
  (use "git restore --staged <file>..." to unstage)

        modified:   src/login.js
```

"Changes to be committed" = **in the staging area, ready for the next commit.**

If you run `git commit` now, this change will be included.

---

#### Scenario 4 — New file that Git has never seen:

```
On branch main
Untracked files:
  (use "git add <file>..." to include in what will be committed)

        notes.txt
```

"Untracked files" = Git sees the file but is not tracking it at all. It won't appear in any commit unless you `git add` it first.

---

#### Scenario 5 — A mix of all three:

```
On branch main
Changes to be committed:
  (use "git restore --staged <file>..." to unstage)

        modified:   src/login.js

Changes not staged for commit:
  (use "git add <file>..." to update what will be committed)
  (use "git restore <file>..." to discard changes in working directory)

        modified:   src/database.js

Untracked files:
  (use "git add <file>..." to include in what will be committed)

        notes.txt
```

Reading this:
- `login.js` is staged — will be included in the next commit
- `database.js` is modified but NOT staged — will NOT be included in the next commit unless you `git add` it
- `notes.txt` is completely untracked — will never be included unless you `git add` it

---

### Short status format:

When you know Git well and want a compact view:

```bash
git status -s
# or
git status --short
```

Output:
```
M  src/login.js    ← green M on the left: staged modification
 M src/database.js ← red M on the right: unstaged modification
?? notes.txt        ← ??: untracked
A  src/new-file.js ← A: newly added (staged)
```

The two columns:
- **Left column**: status in the staging area
- **Right column**: status in the working directory

---

## Common Misunderstanding: "git init and git clone do the same thing in different ways"

**The misunderstanding:** Both create a repository, so they're basically interchangeable.

**The reality:** They are for completely different situations:

- **`git init`**: You are starting something NEW from scratch. There's no remote yet. Your machine is where the project begins.
- **`git clone`**: The project already EXISTS somewhere. You're getting a copy of it. After cloning, you are automatically connected to the remote (via `origin`).

The practical difference: after `git init`, there is no `origin` remote — you'd have to add it manually with `git remote add`. After `git clone`, the `origin` is already configured and `git push`/`git pull` work immediately.

---

## Next Step

You can create a repository and see its status. Now let's learn how to actually save changes — the core workflow.

→ Continue to: `03-staging-and-committing.md`
