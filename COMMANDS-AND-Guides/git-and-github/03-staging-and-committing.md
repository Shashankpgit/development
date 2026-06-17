# Part 03 — Staging and Committing: add, commit, .gitignore

This is the core loop you'll repeat hundreds of times every day:
1. Make changes to your files
2. `git add` — choose which changes to stage
3. `git commit` — permanently save the staged changes

---

## `git add` — Staging Changes

### When do you use this?

Every time you want to include a file's changes in your next commit. Think of `git add` as saying: "I'm happy with these changes. Add them to my next save point."

### The basic usage:

```bash
# Stage a specific file
git add filename.txt

# Stage a file in a subdirectory
git add src/login.js

# Stage multiple files at once
git add src/login.js src/signup.js
```

### Staging all changes at once:

```bash
# Stage ALL modified and new files in the current directory and below
git add .

# Stage ALL changes in the entire repository (no matter where you are)
git add --all
# or
git add -A
```

**Warning about `git add .`:** The `.` means "current directory and everything inside it." If you run this from the root of your project, it stages everything. If you run it from inside a subfolder, it only stages changes in that subfolder and below. This is a common source of confusion.

**`git add -A`** is safer — it always stages everything in the entire repo regardless of where your terminal is.

### Staging parts of a file (patch mode):

This is a powerful but underused feature. What if you changed 5 things in one file but only want to stage 2 of those changes?

```bash
git add -p src/login.js
# or
git add --patch src/login.js
```

Git will show you each "hunk" (chunk of change) one by one and ask what to do:

```
@@ -10,7 +10,10 @@ function login(user, password) {
   const user = findUser(user);
-  if (user.password === password) {
+  if (bcrypt.compare(password, user.passwordHash)) {
     return createSession(user);
   }

Stage this hunk [y,n,q,a,d,/,e,?]?
```

Reply with:
- `y` — yes, stage this chunk
- `n` — no, skip this chunk (don't stage it)
- `s` — split into smaller chunks
- `q` — quit (stop asking, don't stage the rest)
- `?` — show help

This lets you make one commit with the security fix and a separate commit with the refactoring change, even though both edits are in the same file.

### Staging a new (untracked) file:

`git add` also works for brand new files that Git hasn't seen before:

```bash
touch config.js
git add config.js
```

Before running `git add`, `git status` would show `config.js` as "Untracked". After, it shows "Changes to be committed: new file: config.js".

---

## `git commit` — Saving Your Staged Changes

### When do you use this?

After you've staged everything you want in this save point. A commit is permanent — once you make one, it stays in history forever (unless you deliberately remove it later).

### The basic usage:

```bash
git commit -m "your commit message here"
```

The `-m` flag means "message". The text in quotes is your commit message.

### What makes a good commit message?

A commit message should explain **WHY** you made the change, not WHAT you changed. The code shows what changed. The message should give the reason.

**Bad commit messages:**
```
fixed stuff
changes
update
wip
asdfgh
```

**Good commit messages:**
```
fix: prevent login timeout for users on slow connections
feat: add password strength indicator to signup form
refactor: extract database connection logic into its own module
docs: update README with deployment instructions
```

A common convention is `type: short description`:
- `feat:` — new feature
- `fix:` — bug fix
- `docs:` — documentation only
- `refactor:` — code reorganization (no new feature or bug fix)
- `chore:` — maintenance tasks (updating dependencies, etc.)
- `test:` — adding or fixing tests

### Writing a multi-line commit message:

For complex commits, a short title and a longer description is better:

```bash
git commit
```

(Without `-m`, Git opens your configured text editor. Write your message, save and close the file, and Git uses it as the commit message.)

Or write it directly in the terminal:

```bash
git commit -m "fix: resolve login timeout for slow connections

The previous implementation used a hard 5-second timeout which was
causing failures for users in regions with high latency. Changed to
a configurable timeout that defaults to 30 seconds and can be set
via the LOGIN_TIMEOUT environment variable.

Fixes issue #42"
```

The first line is the "subject" (shown in compact log views). The blank line separates it from the "body" (detailed explanation).

### Committing without separate staging step:

```bash
git commit -am "your message here"
```

The `-a` flag automatically stages all **modified** tracked files before committing. This skips the `git add` step.

**Important limitation:** `-a` does NOT stage new (untracked) files. You still need `git add` for files Git has never seen before.

```bash
# This only works for files git already knows about:
echo "some change" >> existing-file.txt
git commit -am "update existing file"

# This would NOT include new-file.txt in the commit:
touch new-file.txt
git commit -am "this commit does NOT include new-file.txt"
```

### Amending the last commit:

What if you made a commit and immediately realized you forgot to include a file, or you made a typo in the message?

```bash
# Add the forgotten file to staging
git add forgotten-file.js

# Amend the last commit (modifies it instead of creating a new one)
git commit --amend
```

This opens the editor with the previous commit message so you can change it too. To keep the same message:

```bash
git commit --amend --no-edit
```

**Warning:** Only amend commits that you have NOT pushed to a shared remote yet. If others have already pulled your commit, amending it will cause problems for them. (This is explained in detail in the Undoing Changes guide.)

### Viewing your commit:

After committing, Git shows a summary:

```
[main 7f0af4a] fix: prevent login timeout for slow connections
 1 file changed, 3 insertions(+), 1 deletion(-)
```

- `main` — the branch you committed to
- `7f0af4a` — the short version of the commit's unique ID (SHA)
- `1 file changed, 3 insertions(+), 1 deletion(-)` — what changed

---

## `.gitignore` — Telling Git to Ignore Certain Files

### When do you need this?

Almost immediately. Every project has files that should NOT be tracked by Git:

- **Dependencies**: `node_modules/`, `.venv/`, `vendor/` — these are downloaded from the internet, not written by you. They can be hundreds of megabytes and regenerated any time with `npm install` or `pip install`. Committing them is wasteful.
- **Secrets**: `.env` files with database passwords, API keys, tokens. Never commit these — they'd be visible to anyone with access to your repo.
- **Build outputs**: `dist/`, `build/`, `*.class`, `*.pyc` — these are generated from your source code. Commit the source, not the outputs.
- **Editor files**: `.DS_Store` (macOS), `.idea/` (IntelliJ), `.vscode/` (VS Code settings you don't want to share)
- **Log files**: `*.log`, `logs/`

### How .gitignore works:

Create a file named exactly `.gitignore` in your project root:

```bash
touch .gitignore
```

Inside it, put patterns — one per line. Any file matching a pattern is completely ignored by Git (won't show up in `git status` as untracked):

```gitignore
# Dependencies
node_modules/
.venv/
vendor/

# Environment variables and secrets
.env
.env.local
.env.production
*.pem
*.key

# Build outputs
dist/
build/
*.class
*.pyc
__pycache__/

# OS files
.DS_Store
Thumbs.db

# Editor files
.idea/
.vscode/
*.swp
*.swo

# Logs
*.log
logs/
```

### Pattern syntax:

```gitignore
# Comment lines start with #

*.log           # Ignore all files ending in .log
!important.log  # EXCEPTION: do NOT ignore important.log specifically

build/          # Ignore the entire build/ directory (the trailing slash ensures it's a dir)
/config.js      # Only ignore config.js in the root, not src/config.js
src/            # Ignore src/ directory anywhere

**/*.tmp        # Ignore .tmp files anywhere in any subdirectory
docs/**/*.pdf   # Ignore PDFs anywhere inside docs/
```

### .gitignore only works for untracked files:

If you already committed a file and then add it to `.gitignore`, Git will continue tracking it. `.gitignore` only prevents tracking of files that haven't been added yet.

To stop tracking an already-committed file:

```bash
# Remove from git's index (stops tracking) but keep the file on disk
git rm --cached secret.env

# Now add it to .gitignore
echo "secret.env" >> .gitignore

# Commit the removal
git commit -m "chore: stop tracking secret.env"
```

After this, `secret.env` still exists on your machine but Git will no longer include it in commits.

### Global .gitignore (for files you always want to ignore):

You can create a global ignore file that applies to all repositories on your machine:

```bash
git config --global core.excludesfile ~/.gitignore_global
```

Then put your personal patterns in `~/.gitignore_global`:

```gitignore
.DS_Store
.idea/
*.swp
```

This is useful for editor files and OS-specific files that are personal to you but not relevant for your team.

---

## A Complete Real-World Example

Let's walk through creating a Node.js project from scratch:

```bash
# 1. Create the project
mkdir my-app
cd my-app
git init
npm init -y

# 2. Create .gitignore immediately (before installing anything)
cat > .gitignore << 'EOF'
node_modules/
.env
dist/
*.log
EOF

# 3. Install a dependency
npm install express

# 4. Create your first file
cat > index.js << 'EOF'
const express = require('express');
const app = express();
app.listen(3000, () => console.log('running'));
EOF

# 5. Check what git sees
git status
# Shows: .gitignore and index.js as untracked
# node_modules/ does NOT appear because it's ignored

# 6. Stage everything (safely — node_modules is ignored)
git add .

# 7. Check staging area before committing
git status
# Shows: both files as "Changes to be committed"

# 8. Commit
git commit -m "feat: initial express server setup"

# 9. See your commit in history
git log --oneline
# Output: 3a1b2c3 feat: initial express server setup
```

---

## Common Misunderstanding: "`git add .` and `git commit -am` are the same thing"

**The misunderstanding:** Both seem to "add everything," so beginners use them interchangeably.

**The reality:** They are different in a critical way:

| | `git add .` then `git commit -m` | `git commit -am` |
|---|---|---|
| Stages new untracked files | ✅ Yes | ❌ No |
| Stages modified tracked files | ✅ Yes | ✅ Yes |
| Stages deleted tracked files | ✅ Yes | ✅ Yes |

The `-a` flag in `git commit -am` only works with files Git already knows about. If you created a new file and run `git commit -am`, that new file will NOT be in the commit. This is a silent omission — Git won't warn you.

---

## Next Step

You can now create commits. Next, learn how to view and explore those commits — your project's history.

→ Continue to: `04-viewing-history.md`
