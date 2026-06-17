# Part 00 — Introduction to Linux: Terminal, Shell, and How Commands Work

Before typing a single command, you need to understand the environment you're operating in. This mental model prevents confusion that trips up beginners for months.

---

## What Is Linux?

Linux is an **operating system kernel** — the core software that manages your computer's hardware (CPU, memory, disks, network) and lets other programs run on top of it.

When people say "Linux," they usually mean a **Linux distribution** (distro) — a complete operating system bundled with the Linux kernel plus software:

| Distro | Best For |
|--------|----------|
| Ubuntu | Beginners, development, servers |
| Debian | Stability, servers |
| CentOS/RHEL | Enterprise servers |
| Arch Linux | Power users who want full control |
| Alpine | Minimal containers (Docker) |

Most DevOps, cloud servers, and containers run Ubuntu or Debian. That's what this guide uses.

---

## The Terminal, the Shell, and the Difference Between Them

These three terms get mixed up constantly:

**The Terminal (Terminal Emulator):** A window that displays text. It's just the screen. Programs: `gnome-terminal`, `iTerm2`, `xterm`, VS Code's integrated terminal, your SSH session window.

**The Shell:** The actual program running inside the terminal that interprets your commands. It reads what you type, executes it, and shows output. Programs: `bash` (default on most Linux), `zsh` (default on macOS), `fish`, `sh`.

**The Command:** The actual program being run. When you type `ls`, you're asking the shell to run the program `ls` which is a binary sitting at `/bin/ls`.

```
You type "ls -la"
      │
      ▼
Terminal (displays what you type and output)
      │
      ▼
Shell (bash) — interprets "ls -la", finds the program ls, runs it with flag -la
      │
      ▼
/bin/ls (the actual program executes, generates output)
      │
      ▼
Shell (receives the output, sends it back to terminal)
      │
      ▼
Terminal (displays the output for you to read)
```

---

## Anatomy of a Linux Command

Every command follows the same pattern:

```
command   [options/flags]   [arguments]
  │              │               │
  │              │               └── What to operate on (files, paths, text)
  │              └── How to modify behavior (-l, --all, -r)
  └── The program to run (ls, cd, grep, cp...)
```

**Examples broken down:**

```bash
ls    -la         /home/shashank
│      │           │
│      │           └── argument: which directory to list
│      └── options: -l (long format) + -a (show hidden files)
└── command: list directory contents

grep   -r   -i   "password"   /etc/
│       │    │       │          │
│       │    │       │          └── argument: directory to search in
│       │    │       └── argument: what text to search for
│       │    └── option: case-insensitive
│       └── option: recursive (search subdirectories)
└── command: search for text in files
```

---

## Short Options vs Long Options

Most commands support two forms for their flags:

```bash
# Short form (single dash, single letter) — faster to type
ls -a
ls -l
ls -la    # can combine multiple short flags

# Long form (double dash, full word) — more readable
ls --all
ls --long   # (not all commands support all long forms)

# Both do the same thing:
grep -i "text" file.txt
grep --ignore-case "text" file.txt
```

Long forms are better for scripts (more readable). Short forms are better for interactive terminal use (faster).

---

## The Manual: `man` — Your Best Friend

Every standard Linux command has a manual page. When you're confused about a command or flag:

```bash
man ls
man grep
man chmod
```

The manual opens in a pager (usually `less`). Navigation:
- `Space` or `f` — next page
- `b` — previous page
- `/searchterm` — search within the manual
- `n` — next search match
- `q` — quit

**Quick help without the full manual:**

```bash
ls --help       # short help summary
grep --help
```

**Find what command does something:**

```bash
man -k "compress"    # search all manuals for commands related to "compress"
apropos "compress"   # same thing
```

---

## The Prompt

The prompt is what you see before you type. It tells you useful information:

```
shashank@ubuntu-server:~$
│         │             │ │
│         │             │ └── $ = regular user, # = root user
│         │             └── ~ = current directory (~ means home)
│         └── hostname (name of the computer)
└── username
```

When the prompt ends with `$` you are a normal user. When it ends with `#` you are the root (superuser) — full power, no restrictions, very dangerous.

---

## Case Sensitivity

Linux is **completely case-sensitive**. This is different from Windows.

```bash
ls Documents      # correct
ls documents      # DIFFERENT directory (or "No such file or directory")
ls DOCUMENTS      # also different

cat README.md     # correct
cat readme.md     # "No such file or directory" if file is named README.md
```

Commands are also case sensitive — `LS` is not a command. Only `ls` works.

---

## Running Multiple Commands

```bash
# Run command2 only if command1 succeeded (exit code 0)
git add . && git commit -m "update"

# Run command2 only if command1 FAILED
mkdir new-dir || echo "Directory already exists"

# Run commands sequentially regardless of outcome
apt update ; apt upgrade

# Run a command in the background (returns prompt immediately)
long-running-script.sh &
```

---

## Exit Codes — How Programs Report Success or Failure

Every command exits with a number:
- **0** = success
- **Non-zero (1, 2, 127...)** = failure or error

```bash
ls /home
echo $?     # print last exit code
# 0 (success)

ls /nonexistent-directory
echo $?
# 2 (failure — "No such file or directory")
```

This matters in scripts when you use `&&` and `||` — they check the exit code.

---

## sudo — Running Commands as Root

Some commands require administrator (root) privileges. `sudo` (SuperUser DO) temporarily runs a command as root.

```bash
sudo apt install nginx      # installs nginx as root
sudo systemctl restart nginx
sudo nano /etc/nginx/nginx.conf   # edit a system config file
```

After running `sudo`, it remembers your authentication for 15 minutes (by default) so you don't have to keep entering the password.

```bash
# Run ALL subsequent commands as root (be careful!)
sudo -i    # opens a root shell

# Back to normal user
exit
```

**Golden rule:** Never run something with `sudo` unless you understand what it does. Root has no restrictions — it can delete the entire operating system with one command.

---

## Tab Completion — Essential Habit

Press `Tab` while typing a command or path to auto-complete:

```bash
cd /home/sha[TAB]    → cd /home/shashank/
ls Doc[TAB]          → ls Documents/
sudo sys[TAB][TAB]   → shows all commands starting with "sys"
```

Double-tap `Tab` to see all possibilities when there are multiple matches.

This is not just a convenience — it's how professionals work. If the tab completion doesn't complete, you likely have a typo or the path doesn't exist.

---

## Command History

```bash
history            # show last 1000 commands
history 20         # show last 20 commands

# Press UP arrow to cycle through previous commands
# Press DOWN arrow to go forward

# Search history interactively:
# Press Ctrl+R, then type part of the command
# Keep pressing Ctrl+R to cycle through matches

# Re-run the last command:
!!

# Re-run the last command with sudo:
sudo !!

# Run command number 42 from history:
!42
```

---

## Common Misunderstanding: "The terminal and the shell are the same thing"

**The misunderstanding:** "Terminal, shell, bash, command line — it's all the same."

**The reality:** They are layers:
- **Terminal** = the window (a display)
- **Shell** = the interpreter running inside (bash/zsh)
- **Command** = the program the shell runs

It matters because:
- You can change your shell without changing your terminal (switch from bash to zsh)
- Shell scripts written for `bash` won't work in `sh` (a simpler shell)
- SSH gives you a shell on a remote machine through the network — no visible "terminal" on the remote machine's monitor

When a script starts with `#!/bin/bash` or `#!/bin/sh`, that's telling Linux which shell to use to run the script — not which terminal.

---

→ Continue to: `01-navigation-commands.md`
