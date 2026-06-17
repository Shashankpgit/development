# Part 06 — Searching and Finding: find, grep, which, locate

These are among the most powerful and most used Linux commands. `find` locates files by attributes. `grep` searches inside file contents. Together they can answer almost any "where is X?" question.

---

## `grep` — Search for Text Inside Files

### When do you use this?

When you know what text you're looking for but not where it is. Also for filtering the output of other commands through a pipe.

### Basic usage:

```bash
grep "search term" filename.txt
grep "ERROR" /var/log/app.log
grep "database" config.json
```

Output shows every line in the file that contains the search term, with the matching text highlighted.

### The flags you'll use constantly:

```bash
grep -i "error" app.log           # case-insensitive (Error, ERROR, error all match)
grep -r "password" /etc/          # recursive: search in all files under /etc/
grep -n "function login" app.js   # show line numbers with results
grep -v "DEBUG" app.log           # invert: show lines that do NOT match
grep -c "ERROR" app.log           # count of matching lines (not the lines themselves)
grep -l "database" /etc/**        # only show filenames, not the matching lines
grep -w "log" file.txt            # whole word match ("log" but not "login" or "blog")
grep -A 3 "ERROR" app.log         # show 3 lines After each match (context)
grep -B 3 "ERROR" app.log         # show 3 lines Before each match
grep -C 3 "ERROR" app.log         # show 3 lines before AND after (Context)
```

### Using grep with pipes — the most common pattern:

```bash
# Find all ERROR lines in a log
cat /var/log/app.log | grep "ERROR"

# More directly:
grep "ERROR" /var/log/app.log

# Find all running nginx processes
ps aux | grep nginx

# Find which line in config file sets the port
cat config.json | grep "port"

# Find all JavaScript files containing the word "fetch"
grep -r "fetch" src/ --include="*.js"

# Count how many 404 errors in nginx log today
grep " 404 " /var/log/nginx/access.log | wc -l
```

### Search with regex (regular expressions):

```bash
# Lines that start with "ERROR"
grep "^ERROR" app.log

# Lines that end with a number
grep "[0-9]$" data.txt

# Lines containing either "warn" or "error" (extended regex)
grep -E "warn|error" app.log
grep -E "^[0-9]{4}-[0-9]{2}-[0-9]{2}" app.log   # lines starting with a date like 2026-06-14
```

`-E` enables extended regex. `-P` enables Perl-compatible regex (more powerful but less portable).

### Search for whole string matches across multiple files:

```bash
# Recursively search all Python files for the function definition
grep -rn "def connect_to_db" --include="*.py" .

# Find all files that import a specific module
grep -rl "import requests" .
```

---

## `find` — Locate Files by Name, Type, Size, Date, and More

`find` searches for files based on their properties (name, type, size, modification time) — NOT content. For content, use `grep`.

### Basic usage:

```bash
find /path/to/search -name "filename"
```

### Find by name:

```bash
find . -name "config.json"           # exact name in current dir and below
find / -name "nginx.conf"            # search from root (entire system)
find /etc -name "*.conf"             # all .conf files under /etc
find . -name "*.log"                 # all .log files under current dir
find . -iname "readme.md"           # case-insensitive name match
```

### Find by type:

```bash
find . -type f                       # files only (not directories)
find . -type d                       # directories only
find . -type l                       # symbolic links only
```

### Find by size:

```bash
find . -size +100M                   # files LARGER than 100MB
find . -size -1k                     # files SMALLER than 1KB
find /var/log -size +50M             # large log files
find . -empty                        # find empty files and directories
```

Size units: `c` = bytes, `k` = kilobytes, `M` = megabytes, `G` = gigabytes

### Find by modification time:

```bash
find . -mtime -7                     # modified in the last 7 days
find . -mtime +30                    # modified MORE than 30 days ago
find . -mmin -60                     # modified in the last 60 minutes
find /tmp -mtime +3                  # files in /tmp older than 3 days
```

### Find by permissions:

```bash
find . -perm 777                     # files with exact 777 permissions
find . -perm /u+x                    # files that have execute for owner
find . -perm -644                    # files with AT LEAST these permissions
```

### Find by owner:

```bash
find /home -user shashank            # files owned by shashank
find /var/www -user www-data         # files owned by www-data
find . -group developers             # files owned by group developers
```

### Execute a command on each found file — the `-exec` flag:

This is where `find` becomes truly powerful:

```bash
# Delete all .log files older than 30 days
find /var/log -name "*.log" -mtime +30 -exec rm {} \;

# The {} is replaced by each found filename
# The \; ends the -exec command

# Show details of all .sh files
find . -name "*.sh" -exec ls -la {} \;

# Make all .sh files executable
find . -name "*.sh" -exec chmod +x {} \;

# Change ownership of all files in web root
find /var/www/html -exec chown www-data:www-data {} \;
```

### Using `+` instead of `\;` (more efficient — runs one command with all files):

```bash
find . -name "*.py" -exec chmod 644 {} +
# Runs: chmod 644 file1.py file2.py file3.py ...
# Instead of: chmod 644 file1.py; chmod 644 file2.py; ...
# More efficient for large numbers of files
```

### Find then pipe to xargs (alternative to -exec):

```bash
find . -name "*.log" | xargs rm
find . -name "*.sh" | xargs chmod +x
find /var/log -name "*.log" -mtime +7 | xargs ls -lh
```

`xargs` takes input from a pipe and uses it as arguments to a command. More flexible than `-exec` for complex cases.

### Combining multiple conditions:

```bash
# Files modified in last 7 days AND larger than 1MB
find /var/log -mtime -7 -size +1M

# Files that are EITHER .log OR .tmp
find . -name "*.log" -o -name "*.tmp"

# Files NOT named .gitkeep
find . -not -name ".gitkeep" -type f
```

---

## `which` — Find Where a Command Lives

```bash
which python3
# /usr/bin/python3

which nginx
# /usr/sbin/nginx

which git
# /usr/bin/git

which node
# /usr/local/bin/node  ← installed locally, not system-wide
```

Use this when you have multiple versions of something installed and need to know which one is being run.

```bash
which python
which python3
# If they return different paths, you have two different Python installations
```

### `type` — More thorough than which:

```bash
type ls
# ls is aliased to `ls --color=auto`

type cd
# cd is a shell builtin

type python3
# python3 is /usr/bin/python3
```

---

## `locate` — Fast System-Wide File Search

`locate` uses a pre-built index database to search instantly across the entire system. Much faster than `find` for simple name searches, but the database is only updated once a day by default.

```bash
locate nginx.conf
locate "*.service"
locate -i readme    # case-insensitive
```

**Update the database manually (to find recently created files):**

```bash
sudo updatedb
```

After `updatedb`, `locate` will find files created since the last auto-update.

**When to use locate vs find:**
- `locate` — fast search by name across the whole system. Might miss very recently created files.
- `find` — slower but always current, can search by any attribute (size, time, permissions), can run commands on results.

---

## Real-World Scenario: "Where Is That Config File?"

```bash
# You know it's an nginx config but don't know the exact path
find / -name "nginx.conf" 2>/dev/null
# 2>/dev/null silences "Permission denied" errors for dirs you can't read

# Faster option:
locate nginx.conf

# Possible output:
# /etc/nginx/nginx.conf
# /usr/share/doc/nginx/examples/nginx.conf
```

---

## Real-World Scenario: "Find All Files Larger Than 100MB Taking Up Disk Space"

```bash
find / -type f -size +100M 2>/dev/null | sort -h

# Show with sizes
find / -type f -size +100M 2>/dev/null -exec ls -lh {} \; | sort -k5 -h

# Just in /var (common location for large logs)
find /var -type f -size +50M 2>/dev/null
```

---

## Real-World Scenario: "Find All Files Containing a Hardcoded Password"

```bash
# Security audit: search your codebase for hardcoded credentials
grep -rn "password\s*=" --include="*.js" .
grep -rn "api_key\s*=" --include="*.py" .
grep -rn "SECRET" --include="*.env" .
grep -rEr "(password|secret|api.?key)\s*[:=]\s*['\"][^'\"]{3}" --include="*.js" .
```

---

## Common Misunderstanding: "grep searches for files, find searches inside files"

**The misunderstanding:** People mix up which command does what.

**The reality is the exact opposite:**
- `grep` — searches for **text patterns INSIDE files**. You tell it a file, it reads the contents.
- `find` — searches for **files themselves** by their properties (name, size, date). It doesn't read file contents.

```bash
# "Find the file named config.json" → use find
find . -name "config.json"

# "Find which files contain the word 'database'" → use grep
grep -rl "database" .

# "Find config.json files that contain the word 'database'" → use both
find . -name "config.json" -exec grep -l "database" {} \;
```

---

→ Continue to: `07-text-processing.md`
