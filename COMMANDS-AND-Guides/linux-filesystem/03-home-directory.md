# The Linux Filesystem — Part 03: /home — Your Personal Space and Dotfiles

`/home` is where every regular user's personal files, configurations, and data live. Understanding its structure — especially the dotfiles — explains how your entire development environment is configured.

---

## The Structure of /home

```bash
ls /home
# shashank    priya    rahul    ubuntu
```

Each user has their own subdirectory. Only that user (and root) can read it by default:

```bash
ls -la /home
# drwx------  15 shashank  shashank  4096 Jun 14 /home/shashank
# drwx------   8 priya     priya     4096 Jun 12 /home/priya
```

`drwx------` — only the owner has any access. Other users can't even list the directory contents.

---

## Inside Your Home Directory

```bash
ls -la ~
```

```
drwxr-xr-x 15 shashank shashank  4096 Jun 14 .
drwxr-xr-x  4 root     root      4096 Jun 10 ..
-rw-------  1 shashank shashank  2048 Jun 14 .bash_history
-rw-r--r--  1 shashank shashank   220 Jun 10 .bash_logout
-rw-r--r--  1 shashank shashank  3526 Jun 10 .bashrc
drwx------  3 shashank shashank  4096 Jun 14 .config/
drwxr-xr-x  3 shashank shashank  4096 Jun 12 .local/
-rw-r--r--  1 shashank shashank   807 Jun 10 .profile
drwx------  2 shashank shashank  4096 Jun 13 .ssh/
-rw-r--r--  1 shashank shashank   242 Jun 11 .gitconfig
drwxr-xr-x  6 shashank shashank  4096 Jun 14 projects/
drwxr-xr-x  3 shashank shashank  4096 Jun 10 Downloads/
```

---

## The Most Important Dotfiles

### `~/.bashrc` — Your Interactive Shell Configuration

Every time you open a new terminal, bash reads this file. It's where you put:
- Aliases
- Environment variables
- PATH additions
- Custom functions
- Prompt customization

```bash
cat ~/.bashrc
```

Common contents:
```bash
# Aliases
alias ll='ls -lah'
alias gs='git status'
alias ..='cd ..'

# PATH additions
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.npm-global/bin:$PATH"

# Environment variables
export EDITOR='nano'
export NODE_ENV='development'
export JAVA_HOME='/usr/lib/jvm/java-17-openjdk'

# Custom function
mkcd() { mkdir -p "$1" && cd "$1"; }
```

### `~/.bash_history` — Your Command History

```bash
wc -l ~/.bash_history    # how many commands are stored
cat ~/.bash_history      # see all past commands
```

This file is appended to as you run commands. It persists across terminal sessions — that's how `history` and Ctrl+R work even after rebooting.

**Security note:** This file contains every command you've typed, including commands with passwords or tokens typed on the command line (always use environment variables instead of inline passwords).

### `~/.profile` — Login Shell Configuration

Runs only on login (SSH, console login), not for every terminal window. Used for environment setup that only needs to happen once per session.

```bash
cat ~/.profile
```

### `~/.ssh/` — SSH Keys and Configuration (Critical!)

```bash
ls -la ~/.ssh/
```

```
-rw-------  1 shashank shashank 411  Jun 10 id_ed25519         ← PRIVATE key (never share!)
-rw-r--r--  1 shashank shashank 101  Jun 10 id_ed25519.pub     ← public key (share this)
-rw-r--r--  1 shashank shashank 1284 Jun 13 known_hosts        ← trusted servers
-rw-r--r--  1 shashank shashank  312 Jun 11 config             ← SSH shortcuts
-rw-------  1 shashank shashank 411  Jun 10 id_rsa_work        ← work private key
-rw-r--r--  1 shashank shashank 101  Jun 10 id_rsa_work.pub    ← work public key
```

**The permissions matter:** SSH REFUSES to use a private key unless it has `600` permissions (`rw-------`). If you copy your key somewhere and permissions change, SSH will reject it:

```
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@         WARNING: UNPROTECTED PRIVATE KEY FILE!          @
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
Permissions 0644 for '/home/shashank/.ssh/id_ed25519' are too open.
```

Fix: `chmod 600 ~/.ssh/id_ed25519`

**`~/.ssh/known_hosts`** — When you first SSH to a server, it asks "are you sure you want to connect?" and stores the server's fingerprint here. Future connections verify the fingerprint. If you see "WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED", the server's identity changed — either it was rebuilt (common) or you're being attacked (rare).

```bash
# Remove a stale known_hosts entry for a server you rebuilt:
ssh-keygen -R hostname-or-ip
```

**`~/.ssh/config`** — SSH shortcut definitions (covered in Part 08 Networking):
```
Host prod-server
    HostName 10.0.0.50
    User ubuntu
    IdentityFile ~/.ssh/id_ed25519
    Port 22
```

### `~/.gitconfig` — Git Identity and Settings

```bash
cat ~/.gitconfig
```

```ini
[user]
    name = Shashank Patil
    email = shashank@example.com
[core]
    editor = code --wait
[alias]
    lg = log --oneline --graph --all
    st = status
```

This is set by `git config --global` commands — they write to this file.

### `~/.config/` — XDG Config Directory

Modern applications follow the **XDG Base Directory Specification** and store their configs here:

```bash
ls ~/.config/
# Code/         ← VS Code settings
# htop/         ← htop preferences
# gh/           ← GitHub CLI config
# npm/          ← npm configuration
```

VS Code settings location:
```bash
cat ~/.config/Code/User/settings.json
```

### `~/.local/` — User-Specific Programs and Data

```bash
ls ~/.local/
# bin/     ← user-installed executables (in PATH)
# lib/     ← user-specific libraries
# share/   ← user-specific data files
```

`~/.local/bin/` is commonly added to `$PATH`. Programs installed with `pip install --user` go here, as do custom scripts you want available as commands without `sudo`.

```bash
# Check if it's in your PATH:
echo $PATH | tr ':' '\n' | grep local
# /home/shashank/.local/bin

# Add a script to your personal commands:
cp my-script.sh ~/.local/bin/my-script
chmod +x ~/.local/bin/my-script
my-script   # works from anywhere (because ~/.local/bin is in PATH)
```

---

## Dotfiles — The Developer's Portable Setup

The entire set of dotfiles in your home directory represents your complete development environment setup. Smart developers keep these in a Git repository so they can:
- Reproduce their exact environment on any new machine
- Track changes to their configuration over time
- Share their setup with others

A typical "dotfiles" repository contains:
```
~/.bashrc
~/.gitconfig
~/.ssh/config
~/.vimrc or ~/.config/nvim/
~/.tmux.conf
~/.config/gh/
```

Setting up a new machine with dotfiles:
```bash
git clone https://github.com/shashank/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh    # script that symlinks all dotfiles to the right places
```

---

## Real-World Scenario: "New Developer Joined the Team — Set Up Their Access"

```bash
# 1. Create the user account
sudo useradd -m -s /bin/bash newdev
sudo passwd newdev

# 2. Add to necessary groups
sudo usermod -aG sudo newdev         # allow sudo
sudo usermod -aG docker newdev       # allow docker commands
sudo usermod -aG developers newdev   # add to dev team group

# 3. Set up their SSH key access
sudo mkdir -p /home/newdev/.ssh
sudo chmod 700 /home/newdev/.ssh

# They send you their public key (id_ed25519.pub content)
# Add it to their authorized_keys:
echo "ssh-ed25519 AAAAC3Nz... newdev@laptop" | sudo tee -a /home/newdev/.ssh/authorized_keys
sudo chmod 600 /home/newdev/.ssh/authorized_keys
sudo chown -R newdev:newdev /home/newdev/.ssh

# 4. They can now SSH with their private key:
# ssh newdev@server
```

---

## Common Misunderstanding: "Dotfiles are just configuration — I don't need to back them up"

**The misunderstanding:** "These are just settings. If I lose them, I'll just set them up again."

**The reality:** Your dotfiles represent hours or years of accumulated customization:
- Every alias you've added over the years
- Your carefully tuned git configuration
- SSH configs for dozens of servers
- Custom shell functions
- Your exact editor settings

Losing them to a disk failure or accidentally running `rm -rf ~` is painful. A Git repository for dotfiles is the standard practice — it takes 30 minutes to set up and saves significant pain later.

---

→ Continue to: `04-bin-usr-opt.md`
