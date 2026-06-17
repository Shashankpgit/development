# Part 01 — Navigation: pwd, ls, cd, tree

These are the commands you'll use every single minute in a terminal. Mastering them — especially understanding relative vs absolute paths — removes the single biggest confusion for beginners.

---

## Paths: Absolute vs Relative (The Most Important Concept)

Before any navigation command makes sense, you must understand paths.

### Absolute Path

An absolute path starts from the root of the filesystem (`/`). It describes the exact location of a file regardless of where you currently are.

```
/home/shashank/projects/vault-app/src/index.js
│
└── starts with / (root) — this is always absolute
```

An absolute path works from ANYWHERE. It's like a full home address — it works no matter where the postman is starting from.

### Relative Path

A relative path describes location relative to your CURRENT directory. It does NOT start with `/`.

```
# If you are currently in /home/shashank/projects/vault-app/
src/index.js          ← relative to current dir
./src/index.js        ← same (. means "current directory")
../other-app/         ← go up one level, then into other-app
../../                ← go up two levels
```

Special shortcuts:
- `.` (single dot) — current directory
- `..` (double dot) — parent directory (one level up)
- `~` (tilde) — your home directory (`/home/shashank`)
- `-` (dash in cd) — previous directory you were in

---

## `pwd` — Print Working Directory

### When do you use this?

When you're disoriented in the terminal and need to know exactly where you are.

```bash
pwd
```

Output:
```
/home/shashank/projects/vault-app
```

This is your current location — every relative path is calculated from here. Get in the habit of running `pwd` when something isn't working — you're probably not where you think you are.

---

## `ls` — List Directory Contents

### Basic usage:

```bash
ls              # list files in current directory
ls /etc         # list files in /etc
ls /home/shashank/projects   # list files in a specific path
```

Output (basic):
```
docs  node_modules  package.json  README.md  src
```

Just names. Not very informative. Almost everyone uses flags.

---

### The flags you'll use 90% of the time:

```bash
ls -l           # long format (detailed)
ls -a           # show ALL files including hidden (starting with .)
ls -la          # long format + hidden files (most common combination)
ls -lh          # long format + human-readable file sizes (KB, MB not bytes)
ls -lt          # long format + sorted by modification time (newest first)
ls -ltr         # long format + sorted by time, reversed (oldest first)
ls -R           # recursive — list all subdirectories too
```

### Reading `ls -la` output:

```bash
ls -la /home/shashank
```

Output:
```
total 48
drwxr-xr-x  8 shashank shashank 4096 Jun 14 09:00 .
drwxr-xr-x  3 root     root     4096 Jun 10 14:23 ..
-rw-------  1 shashank shashank  612 Jun 13 11:00 .bash_history
-rw-r--r--  1 shashank shashank  220 Jun 10 14:23 .bash_logout
-rw-r--r--  1 shashank shashank 3526 Jun 10 14:23 .bashrc
drwxr-xr-x  5 shashank shashank 4096 Jun 14 08:45 .config
drwxr-xr-x  3 shashank shashank 4096 Jun 12 15:30 .ssh
-rw-r--r--  1 shashank shashank  807 Jun 10 14:23 .profile
drwxr-xr-x  6 shashank shashank 4096 Jun 14 09:15 projects
```

Reading each column left to right:

```
drwxr-xr-x   8   shashank   shashank   4096   Jun 14 09:00   projects
│             │       │          │        │         │              │
│             │       │          │        │         │              └── name
│             │       │          │        │         └── last modified date
│             │       │          │        └── size in bytes
│             │       │          └── group owner
│             │       └── user owner
│             └── number of hard links
└── permissions (explained in detail in Part 04)
```

**The first character:**
- `d` = directory
- `-` = regular file
- `l` = symbolic link (shortcut)
- `b` = block device (hard drive, etc.)
- `c` = character device (keyboard, terminal)

**Hidden files** (starting with `.`): `.bash_history`, `.bashrc`, `.ssh` etc. Hidden files are just files whose names start with a dot. Linux treats them as hidden by convention — they don't appear in regular `ls` but ARE there on disk. `ls -a` reveals them.

### List only directories:

```bash
ls -d */           # list only directories in current location
ls -la | grep "^d" # same using grep
```

### List sorted by file size:

```bash
ls -lhS    # sorted by size, largest first
ls -lhSr   # sorted by size, smallest first (r = reverse)
```

---

## `cd` — Change Directory

### Basic usage:

```bash
cd /etc                         # go to absolute path
cd projects                     # go to relative path (projects inside current dir)
cd /home/shashank/projects      # full path
```

### Special cd shortcuts:

```bash
cd          # go to your home directory (same as cd ~)
cd ~        # go to home directory
cd ..       # go up one level (parent directory)
cd ../..    # go up two levels
cd -        # go back to the PREVIOUS directory you were in
```

`cd -` is extremely useful. If you were in `/home/shashank/projects` and `cd` to `/etc/nginx` to check a config, `cd -` takes you right back to `/home/shashank/projects`. Like a "back" button.

### Practical navigation example:

```bash
# Start from home
pwd
# /home/shashank

cd projects/vault-app
pwd
# /home/shashank/projects/vault-app

cd src
pwd
# /home/shashank/projects/vault-app/src

# Go up two levels
cd ../..
pwd
# /home/shashank/projects

# Go back to where you just were
cd -
pwd
# /home/shashank/projects/vault-app/src

# Jump to home no matter where you are
cd
pwd
# /home/shashank
```

### The ~ (tilde) expansion:

`~` is always your home directory. You can use it in paths:

```bash
cd ~/projects           # same as cd /home/shashank/projects
cat ~/.bashrc           # read /home/shashank/.bashrc
nano ~/.ssh/config      # edit /home/shashank/.ssh/config
ls ~/Downloads
```

---

## `tree` — Visual Directory Structure

`tree` is not installed by default on most systems but is invaluable.

```bash
# Install it:
sudo apt install tree

# Basic usage:
tree
```

Output:
```
.
├── README.md
├── package.json
├── src
│   ├── app.js
│   ├── controllers
│   │   ├── auth.js
│   │   └── user.js
│   └── models
│       └── user.js
└── tests
    └── auth.test.js

4 directories, 6 files
```

### Useful tree flags:

```bash
tree -L 2              # only show 2 levels deep (prevents overwhelming output)
tree -a                # show hidden files too
tree -d                # show directories only (no files)
tree -f                # show full path for each entry
tree -h                # show file sizes in human-readable format
tree /etc -L 1         # show top level of /etc directory
tree --prune           # don't show empty directories
```

### Limit depth on large projects:

```bash
# A Node.js project has thousands of files in node_modules
# Without limit:
tree    # shows 50,000 lines of output — useless

# With depth limit:
tree -L 2   # shows a useful overview
```

---

## Real-World Scenario: "I'm Lost in the Terminal"

You were running commands, cd-ing around, and now you have no idea where you are:

```bash
# Step 1: Find out where you are
pwd
# /home/shashank/projects/vault-app/src/controllers/auth

# Step 2: See what's in the current directory
ls -la

# Step 3: Quickly go home and start over
cd

# Step 4: Navigate to where you want to be
cd ~/projects/vault-app
```

---

## Real-World Scenario: "I Want to See All Config Files in a Directory Without Entering It"

```bash
# See the top-level contents of /etc without leaving your current directory
ls /etc

# See deeply nested structure
tree /etc/nginx -L 3

# See only configuration files (ending in .conf)
ls /etc/nginx/*.conf
```

---

## Common Misunderstanding: "`cd` alone does different things"

**The misunderstanding:** "Typing just `cd` with no arguments does nothing."

**The reality:** `cd` with no arguments takes you to your **home directory**. It's equivalent to `cd ~` or `cd /home/yourusername`.

Also confused: `cd .` (goes nowhere — stays in current directory) vs `cd ..` (goes UP one level). The single dot and double dot are easy to mix up when you're new.

And the most frustrating one: `cd` into a directory that doesn't exist.

```bash
cd projetcs       # typo! 
# bash: cd: projetcs: No such file or directory

# pwd still shows you where you WERE
pwd
# /home/shashank    (you didn't move — cd failed)
```

When `cd` fails, you stay where you are. Always check `pwd` if you're unsure whether a `cd` worked.

---

→ Continue to: `02-file-and-directory-operations.md`
