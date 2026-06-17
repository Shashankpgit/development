# Part 00 — Introduction to Git & First-Time Setup

---

## What is Version Control and Why Should You Care?

Imagine you are writing an important essay. You save it as `essay.docx`. Then you make changes and save it as `essay_v2.docx`. Then `essay_final.docx`. Then `essay_final_REAL.docx`. Then `essay_final_REAL_v2_USE_THIS.docx`.

Sound familiar? Every developer does this without version control. Now multiply that by an entire codebase with 50 files and 5 developers working at the same time. It becomes an unmanageable disaster.

**Version control solves this.** It keeps a full history of every change ever made to your project — who made it, when, and why — without you managing file copies. You can:

- Go back to any point in time
- Work on new features without breaking the working code
- Collaborate with others without overwriting each other's work
- Understand *why* a line of code exists (not just what it does)

---

## What is Git? (And What It Is NOT)

**Git is a version control system (VCS).** It runs entirely on your computer. It is a program — like `ls` or `node` — that tracks changes in files inside a folder.

**Git is NOT GitHub.** This is the most common confusion for beginners.

| Git | GitHub |
|-----|--------|
| A program installed on your machine | A website on the internet |
| Tracks changes locally | Stores your Git history online |
| Works completely offline | Requires internet |
| Created by Linus Torvalds in 2005 | Created by a company in 2008 |
| Free and open-source | A commercial product (with a free tier) |

Think of it this way: **Git is the technology. GitHub is one place to host your Git repositories online.** There are others: GitLab, Bitbucket, Gitea, etc. They all work with Git.

---

## Installing Git

### On Ubuntu/Debian Linux:
```bash
sudo apt update
sudo apt install git
```

### On macOS:
```bash
brew install git
```

Or install Xcode Command Line Tools (which includes Git):
```bash
xcode-select --install
```

### Verify the installation:
```bash
git --version
```

Expected output:
```
git version 2.43.0
```

If you see a version number, Git is installed correctly.

---

## First-Time Setup — Telling Git Who You Are

Before you use Git for the first time, you must tell it your name and email. This is important because **every commit (save point) you make will be stamped with this information.** When you work in a team, everyone can see who made which change.

### Set your name:
```bash
git config --global user.name "Your Full Name"
```

### Set your email:
```bash
git config --global user.email "you@example.com"
```

**The `--global` flag** means this configuration applies to all Git repositories on your computer. You only need to do this once.

### Example:
```bash
git config --global user.name "Shashank Patil"
git config --global user.email "shashank@example.com"
```

### Set your default text editor (for writing commit messages):
```bash
# For VS Code:
git config --global core.editor "code --wait"

# For nano (simpler, good for beginners):
git config --global core.editor "nano"

# For vim (if you know vim):
git config --global core.editor "vim"
```

### Set the default branch name to "main" (modern standard):
```bash
git config --global init.defaultBranch main
```

Older versions of Git used `master` as the default branch name. The modern convention is `main`. Setting this globally means every new repository you create will start with a branch called `main`.

---

## Viewing Your Configuration

### See all your current settings:
```bash
git config --list
```

Output will look like:
```
user.name=Shashank Patil
user.email=shashank@example.com
core.editor=code --wait
init.defaultbranch=main
```

### See a specific setting:
```bash
git config user.name
```

Output:
```
Shashank Patil
```

---

## Where Are These Configs Stored?

Git has three levels of configuration:

| Level | Flag | File Location | Scope |
|-------|------|---------------|-------|
| System | `--system` | `/etc/gitconfig` | All users on the machine |
| Global | `--global` | `~/.gitconfig` | Your user account only |
| Local | `--local` | `.git/config` inside your project | That one project only |

**Local settings override global, which override system.** So if your global config says your name is "Shashank" but a specific project's local config says "Work Account", Git uses "Work Account" for that project.

You can open your global config file directly:
```bash
cat ~/.gitconfig
```

Output:
```
[user]
    name = Shashank Patil
    email = shashank@example.com
[core]
    editor = code --wait
[init]
    defaultBranch = main
```

---

## Getting Help

Git has built-in help for every command:

```bash
# Full manual page for a command:
git help commit

# Short summary (more practical for quick reference):
git commit --help
git commit -h
```

---

## Common Misunderstanding: "Git saves my files to the internet automatically"

**The misunderstanding:** Many beginners think that using `git commit` sends their code to GitHub.

**The reality:** `git commit` only saves a snapshot of your changes **locally on your computer** inside the `.git` folder. Nothing leaves your machine. To send your code to GitHub, you need a separate command: `git push`. These are two completely different operations.

This means:
- You can use Git entirely offline, forever, with no internet connection.
- You can make hundreds of commits locally before ever "pushing" to GitHub.
- If your hard drive dies and you never pushed, your history is gone — Git is not a backup system by itself.

---

## Next Step

Now that Git is installed and configured, the next file covers the most important concept in all of Git: **the mental model** — how Git actually thinks about your files.

→ Continue to: `01-the-mental-model.md`
