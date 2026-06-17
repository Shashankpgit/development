# Part 13 — Git Config, Aliases, and Customization

---

## Git Config — Three Levels, One System

You've already seen `git config --global` for setting your name and email. Let's go deeper into what you can configure and how the layering works.

### The three config levels (from lowest to highest priority):

```bash
git config --system   # /etc/gitconfig — applies to all users on the computer
git config --global   # ~/.gitconfig — applies to your user account
git config --local    # .git/config inside a project — applies to that project only
```

If the same key is set at multiple levels, the most specific level wins. **Local overrides global overrides system.**

### View settings at a specific level:

```bash
git config --global --list    # global settings only
git config --local --list     # this project's settings only
git config --list             # all settings merged (shows effective values)
```

### Where is my global config file?

```bash
# Open it in your editor
git config --global --edit

# Or just read it
cat ~/.gitconfig
```

---

## Essential Configuration Settings

### Identity (required):

```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

### Default editor:

```bash
git config --global core.editor "code --wait"   # VS Code
git config --global core.editor "nano"           # nano
git config --global core.editor "vim"            # vim
```

### Default branch name:

```bash
git config --global init.defaultBranch main
```

### How Git handles line endings (important for cross-platform teams):

On Windows, line endings are `\r\n` (CRLF). On Mac/Linux, they are `\n` (LF). Mixing these in a team causes noise in diffs.

```bash
# On Windows:
git config --global core.autocrlf true
# Git converts LF→CRLF on checkout, CRLF→LF on commit

# On Mac/Linux:
git config --global core.autocrlf input
# Git converts CRLF→LF on commit but doesn't touch LF files
```

### Default pull behavior:

```bash
# Use rebase instead of merge when pulling (cleaner history)
git config --global pull.rebase true

# Or keep merge (traditional):
git config --global pull.rebase false
```

### Auto-push to matching remote branch:

```bash
# When you run "git push" on a new branch, automatically set upstream
git config --global push.autoSetupRemote true
```

With this, instead of `git push -u origin feature-payment`, you can just run `git push` even on a new branch.

---

## Git Aliases — Your Personal Shortcuts

Aliases let you create short custom names for long commands. They save a huge amount of typing.

### Creating aliases:

```bash
git config --global alias.co checkout
git config --global alias.br branch
git config --global alias.st status
git config --global alias.cm commit
```

Now you can type `git st` instead of `git status`, `git co main` instead of `git checkout main`, etc.

### More powerful aliases:

```bash
# Compact log with graph (run as: git lg)
git config --global alias.lg "log --oneline --graph --all --decorate"

# Undo last commit but keep changes staged (run as: git undo)
git config --global alias.undo "reset --soft HEAD~1"

# Show staged changes (run as: git staged)
git config --global alias.staged "diff --staged"

# List all aliases (run as: git aliases)
git config --global alias.aliases "config --get-regexp alias"

# Amend last commit message without changing files (run as: git reword)
git config --global alias.reword "commit --amend --only"

# Stash only unstaged changes (run as: git stash-unstaged)
git config --global alias.stash-unstaged "stash --keep-index"
```

### Aliases in the config file directly:

You can also edit `~/.gitconfig` directly and add aliases there:

```ini
[alias]
    co  = checkout
    br  = branch
    st  = status
    cm  = commit
    lg  = log --oneline --graph --all --decorate
    undo = reset --soft HEAD~1
    staged = diff --staged
    aliases = config --get-regexp alias
    # Create and switch to a new branch:
    nb  = switch -c
    # Push current branch and set upstream in one command:
    pub = push -u origin HEAD
    # Delete remote branch:
    drb = push origin --delete
```

Now you can do:
```bash
git nb feature-payment    # creates and switches to feature-payment
git pub                   # pushes and sets upstream for current branch
git drb feature-payment   # deletes the remote feature-payment branch
```

---

## `.gitattributes` — Per-Repository File Rules

`.gitattributes` is a file in the root of your project that tells Git how to handle specific file types. Unlike `.gitignore` (which hides files), `.gitattributes` sets behavior rules.

```gitattributes
# Enforce LF line endings for everything
* text=auto eol=lf

# Treat these as binary (don't show diffs, don't convert line endings)
*.png binary
*.jpg binary
*.gif binary
*.pdf binary
*.zip binary
*.exe binary

# Use a specific diff tool for JSON files
*.json diff=json

# Mark generated files - they show in git diff but are collapsible in GitHub
package-lock.json linguist-generated=true
yarn.lock linguist-generated=true
```

### Why `.gitattributes` matters:

If your team uses both Windows and Mac/Linux, without `.gitattributes` you'll get line ending differences on every single file in every diff — even when the actual content hasn't changed. Setting `* text=auto eol=lf` prevents this.

---

## Git Hooks — Automate Actions at Key Moments

Git hooks are scripts that run automatically at specific events: before committing, after merging, before pushing, etc.

They live in `.git/hooks/`. Git ships with sample hooks (ending in `.sample`) — rename them (remove `.sample`) to activate.

### Common hooks:

| Hook | When it runs | Common use |
|------|-------------|------------|
| `pre-commit` | Before a commit is created | Run linter, format code, check for secrets |
| `commit-msg` | After you write the commit message | Enforce message format (e.g., must start with feat/fix/docs) |
| `pre-push` | Before pushing to remote | Run tests |
| `post-merge` | After a merge completes | Run `npm install` to update dependencies |

### Example — A pre-commit hook that runs a linter:

Create `.git/hooks/pre-commit`:

```bash
#!/bin/sh
# Run ESLint on staged JS files. Abort the commit if there are errors.

STAGED_JS_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep ".js$")

if [ -n "$STAGED_JS_FILES" ]; then
    echo "Running ESLint..."
    npx eslint $STAGED_JS_FILES
    if [ $? -ne 0 ]; then
        echo "ESLint failed. Fix errors before committing."
        exit 1    # exit code 1 aborts the commit
    fi
fi

exit 0    # exit code 0 allows the commit to proceed
```

```bash
chmod +x .git/hooks/pre-commit
```

Now every time you `git commit`, ESLint runs automatically. If it fails, the commit is blocked.

**Problem with hooks:** They live in `.git/hooks/` which is not tracked by Git. Your teammates won't get your hooks when they clone the repo.

**Solution:** Use a tool like [Husky](https://typicode.github.io/husky/) which stores hooks in a tracked folder (`.husky/`) and installs them automatically via `npm install`.

---

## Useful Config You Didn't Know You Needed

### Color output (usually on by default, but useful to know):

```bash
git config --global color.ui auto
```

### Show word-level diffs (better than line-level for prose):

```bash
git diff --word-diff
```

### Rerere — Remember how you resolved a conflict (reuse recorded resolutions):

```bash
git config --global rerere.enabled true
```

With this on, if you resolve a conflict and later encounter the same conflict (after a rebase, for example), Git automatically applies the same resolution. Very useful for long-lived branches.

### Specify a default pager (for `git log` output):

```bash
git config --global core.pager "less -R"
```

---

## A Complete ~/.gitconfig Example

This is a solid starting configuration for a developer:

```ini
[user]
    name = Shashank Patil
    email = shashank@example.com

[core]
    editor = code --wait
    autocrlf = input
    pager = less -R

[init]
    defaultBranch = main

[pull]
    rebase = true

[push]
    autoSetupRemote = true

[rerere]
    enabled = true

[alias]
    co  = checkout
    sw  = switch
    br  = branch
    st  = status
    cm  = commit
    lg  = log --oneline --graph --all --decorate
    undo = reset --soft HEAD~1
    staged = diff --staged
    pub = push -u origin HEAD
    nb  = switch -c
    aliases = config --get-regexp alias

[color]
    ui = auto
```

---

## Common Misunderstanding: "Aliases are saved per project"

**The misunderstanding:** "I set up `git lg` as an alias and now I have to do it again in every new project."

**The reality:** Aliases set with `--global` apply everywhere on your machine, for all repositories. That's the whole point of the global config. You set up aliases once in `~/.gitconfig` and they work in every project forever.

Only aliases set with `--local` (inside a specific repo) are project-specific. You'd use that for project-specific shortcuts that only make sense in that context (like `git deploy` that triggers a project-specific deploy script).

---

## Next Step

You've customized Git for your workflow. The final guide covers real-world workflows — how professional teams structure their Git usage from day to day.

→ Continue to: `14-real-world-workflows.md`
