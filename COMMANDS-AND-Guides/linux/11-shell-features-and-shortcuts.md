# Part 11 — Shell Features: Variables, Aliases, History, Redirection, Shortcuts

The shell is not just a way to type commands — it has its own features that make you dramatically more productive. This file covers the features that professionals use every day.

---

## Environment Variables

Variables store values you can use in commands and scripts.

### Setting and using variables:

```bash
# Set a variable (no spaces around =)
NAME="Shashank"
PORT=3000
DB_URL="postgresql://localhost/mydb"

# Use a variable with $
echo $NAME
# Shashank

echo "Server running on port $PORT"
# Server running on port 3000

# In commands:
mkdir /home/$NAME/projects
node --port $PORT server.js
```

### Variable scope — local vs exported:

```bash
MY_VAR="hello"
bash                    # open a new shell (child process)
echo $MY_VAR            # empty! Not visible to child shell
exit

export MY_VAR="hello"   # export makes it visible to child processes
bash
echo $MY_VAR            # hello — now it works
exit
```

### Important built-in environment variables:

```bash
echo $PATH         # directories where shell looks for commands
echo $HOME         # your home directory (/home/shashank)
echo $USER         # current username
echo $SHELL        # which shell you're running (/bin/bash)
echo $PWD          # current directory (same as pwd command)
echo $HOSTNAME     # machine hostname
echo $?            # exit code of last command (0=success)
echo $$            # PID of current shell
```

### `PATH` — How the Shell Finds Commands:

When you type `nginx`, the shell searches every directory in `$PATH` for a file called `nginx`. The first match wins.

```bash
echo $PATH
# /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/home/shashank/.local/bin
```

### Add a directory to PATH:

```bash
# Temporary (only this session):
export PATH=$PATH:/opt/myapp/bin

# Permanent (add to ~/.bashrc):
echo 'export PATH=$PATH:/opt/myapp/bin' >> ~/.bashrc
source ~/.bashrc    # reload to take effect
```

---

## `.bashrc` and `.bash_profile` — Your Shell Config

- `~/.bashrc` — runs every time you open an **interactive terminal** (not login shells)
- `~/.bash_profile` — runs on **login** (SSH, console login)
- `~/.profile` — runs on login if `.bash_profile` doesn't exist

Most customization goes in `~/.bashrc`.

```bash
# Edit your bashrc
nano ~/.bashrc

# Reload after editing (without opening a new terminal):
source ~/.bashrc
# or
. ~/.bashrc   # same thing (. is shorthand for source)
```

---

## Aliases — Create Your Own Commands

An alias is a shortcut for a longer command. Add these to `~/.bashrc` to make them permanent.

```bash
# Temporarily (this session only):
alias ll='ls -lah'
alias gs='git status'

# Permanently (add to ~/.bashrc):
nano ~/.bashrc
```

Example aliases to add to `~/.bashrc`:

```bash
# Navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ll='ls -lah'
alias la='ls -A'

# Git shortcuts
alias gs='git status'
alias ga='git add'
alias gc='git commit -m'
alias gp='git push'
alias gl='git log --oneline --graph --all'

# Safety aliases
alias rm='rm -i'         # always ask before deleting
alias cp='cp -i'         # always ask before overwriting
alias mv='mv -i'         # always ask before overwriting

# System shortcuts
alias ports='ss -tlnp'
alias myip='curl -s https://ifconfig.me'
alias update='sudo apt update && sudo apt upgrade -y'
alias df='df -h'
alias du='du -h'
alias free='free -h'

# Reload bashrc
alias reload='source ~/.bashrc'
```

### View all active aliases:

```bash
alias            # list all aliases
alias ll         # see what a specific alias expands to
```

### Temporarily bypass an alias:

```bash
\rm file.txt     # the backslash bypasses the alias (runs real rm without -i prompt)
```

---

## Command History Mastery

Your shell remembers every command you've typed.

```bash
history          # show all history
history 20       # show last 20
history | grep "git"   # find git commands in history
```

### Keyboard shortcuts for history navigation:

```
Up/Down arrow   → cycle through previous commands
Ctrl+R          → reverse search (type to find a past command)
Ctrl+R again    → cycle through more matches
Ctrl+G          → cancel reverse search
!!              → repeat the last command
!$              → last argument of the previous command
!^              → first argument of the previous command
!42             → run command number 42 from history
!git            → run the most recent command starting with "git"
Alt+.           → paste the last argument of the previous command
```

**The most useful:** `Ctrl+R` for interactive history search.

```bash
# Press Ctrl+R and type "nginx" to find:
(reverse-i-search)`nginx': sudo systemctl restart nginx
# Press Enter to run, or Ctrl+R again to find older matches
```

### Configure history size in `~/.bashrc`:

```bash
HISTSIZE=10000        # remember last 10,000 commands in memory
HISTFILESIZE=20000    # store last 20,000 commands in history file
HISTCONTROL=ignoredups:erasedups  # don't store duplicate commands
```

---

## Job Control

```bash
# While a command is running:
Ctrl+C          → terminate the process (sends SIGINT)
Ctrl+Z          → pause (suspend) the process (sends SIGSTOP)
Ctrl+D          → send end-of-input (closes shell or program waiting for input)

# After Ctrl+Z:
bg              → continue the suspended process in the background
fg              → bring the process back to the foreground
jobs            → list all background/suspended jobs

# Run a command in background from the start:
long-command &
```

---

## Useful Keyboard Shortcuts (Readline)

These work in bash, and any program that uses readline (like Python REPL, psql, etc.):

```
Ctrl+A          → move cursor to beginning of line
Ctrl+E          → move cursor to end of line
Ctrl+W          → delete word before cursor
Ctrl+U          → delete from cursor to beginning of line
Ctrl+K          → delete from cursor to end of line
Ctrl+Y          → paste (yank) what was deleted by Ctrl+U or Ctrl+W
Alt+F           → move cursor forward one word
Alt+B           → move cursor backward one word
Ctrl+L          → clear the screen (same as 'clear' command)
Ctrl+C          → cancel current command
Ctrl+D          → logout/exit (when line is empty) or send EOF
```

---

## Brace Expansion — Creating Many Things at Once

```bash
mkdir -p project/{src,tests,docs,config}
# Creates: project/src, project/tests, project/docs, project/config

touch file{1,2,3,4,5}.txt
# Creates: file1.txt file2.txt file3.txt file4.txt file5.txt

cp config.json config.json.backup.{monday,tuesday}
# Creates two backups

echo {a..z}         # a b c d ... z
echo {1..10}        # 1 2 3 4 5 6 7 8 9 10
echo {01..05}       # 01 02 03 04 05 (zero-padded)
```

---

## Command Substitution — Use Command Output in Another Command

```bash
echo "Today is $(date)"
# Today is Sat Jun 14 12:00:00 IST 2026

# Create a directory named after today's date
mkdir backup-$(date +%Y-%m-%d)
# Creates: backup-2026-06-14

# Find and count files
echo "Found $(find . -name '*.js' | wc -l) JavaScript files"

# Use in a variable
CURRENT_DIR=$(pwd)
echo "Working in: $CURRENT_DIR"
```

---

## Here Documents — Multi-Line Input

```bash
# Create a file with content in one command
cat > config.json << 'EOF'
{
  "database": "myapp",
  "port": 5432,
  "host": "localhost"
}
EOF
```

The `<<'EOF'` starts a "here document" — everything between `EOF` and the closing `EOF` is treated as input. The single quotes prevent variable expansion inside.

---

## Common Misunderstanding: "I need to restart my terminal for `.bashrc` changes to take effect"

**The misunderstanding:** "I added an alias to `.bashrc`. Now I need to close and reopen the terminal."

**The reality:** You can reload `.bashrc` without closing the terminal:

```bash
source ~/.bashrc
# or
. ~/.bashrc
```

`source` executes the file in the current shell (instead of in a new child process), so all the changes take effect immediately in your current session.

Closing and reopening works too, but `source ~/.bashrc` takes 0.1 seconds and keeps your terminal open.

---

→ Continue to: `12-compression-and-archiving.md`
