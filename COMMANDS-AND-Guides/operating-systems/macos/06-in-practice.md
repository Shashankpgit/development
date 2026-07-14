# macOS — 06: macOS in Practice

> **Last updated:** July 7, 2026
> **Developer machine setup, dotfiles, common admin tasks, and real-world workflows.**

---

## Setting Up a Fresh Mac for Development

This is the complete sequence for a new Mac — start to finish.

### Step 1: Xcode Command Line Tools

```bash
xcode-select --install
# Click Install in the popup — takes 5-10 minutes
```

### Step 2: Install Homebrew

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Apple Silicon only — add to PATH:
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zshrc
source ~/.zshrc
```

### Step 3: Install Core Dev Tools

```bash
brew install \
  git \
  curl \
  wget \
  jq \
  yq \
  fzf \
  ripgrep \
  bat \
  eza \
  tmux \
  htop

# Version managers
brew install pyenv nvm rbenv

# Cloud / DevOps
brew install awscli kubectl helm terraform
```

### Step 4: Install GUI Apps

```bash
brew install --cask \
  iterm2 \
  visual-studio-code \
  docker \
  postman \
  rectangle \
  alt-tab
```

### Step 5: Configure Git

```bash
git config --global user.name "Shashank"
git config --global user.email "shashank@example.com"
git config --global init.defaultBranch main
git config --global core.editor "code --wait"
git config --global pull.rebase false
```

### Step 6: Generate SSH Key

```bash
ssh-keygen -t ed25519 -C "shashank@example.com"
eval "$(ssh-agent -s)"
ssh-add --apple-use-keychain ~/.ssh/id_ed25519

# Add public key to GitHub
cat ~/.ssh/id_ed25519.pub
# Copy and paste into GitHub → Settings → SSH keys
```

---

## .zshrc — Shell Configuration

`~/.zshrc` is the zsh equivalent of `~/.bashrc`. It loads on every new terminal.

```bash
# ~/.zshrc — a practical developer config

# ── Homebrew ──────────────────────────────────────────────────
eval "$(/opt/homebrew/bin/brew shellenv)"   # Apple Silicon

# ── Path ──────────────────────────────────────────────────────
export PATH="$HOME/.local/bin:$PATH"
export PATH="/usr/local/bin:$PATH"

# ── History ───────────────────────────────────────────────────
HISTSIZE=10000
SAVEHIST=10000
HISTFILE=~/.zsh_history
setopt HIST_IGNORE_DUPS
setopt SHARE_HISTORY          # share history across terminal tabs

# ── Aliases ───────────────────────────────────────────────────
alias ls='eza --icons'        # better ls (install: brew install eza)
alias ll='eza -la --icons'
alias cat='bat'               # better cat (install: brew install bat)
alias k='kubectl'
alias tf='terraform'
alias g='git'

# ── Node (nvm) ────────────────────────────────────────────────
export NVM_DIR="$HOME/.nvm"
[ -s "$(brew --prefix nvm)/nvm.sh" ] && . "$(brew --prefix nvm)/nvm.sh"

# ── Python (pyenv) ────────────────────────────────────────────
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

# ── AWS ───────────────────────────────────────────────────────
export AWS_DEFAULT_REGION=ap-south-1

# ── fzf ───────────────────────────────────────────────────────
eval "$(fzf --zsh)"           # Ctrl+R fuzzy history, Ctrl+T fuzzy files

# ── Custom prompt (minimal) ───────────────────────────────────
PROMPT='%F{cyan}%~%f %# '
```

---

## Useful macOS `defaults` Command

macOS stores system and app preferences in `.plist` files. The `defaults` command lets you read and write these from the terminal.

```bash
# Show hidden files in Finder
defaults write com.apple.finder AppleShowAllFiles true
killall Finder   # restart Finder to apply

# Show full path in Finder title bar
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true
killall Finder

# Disable .DS_Store on network volumes
defaults write com.apple.desktopservices DSDontWriteNetworkStores true

# Speed up Dock show/hide animation
defaults write com.apple.dock autohide-time-modifier -float 0.1
killall Dock

# Disable autocorrect (for developers)
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

# Show file extensions in Finder
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
killall Finder

# Require password immediately after screensaver
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 0

# Screenshot: change save location and disable shadow
defaults write com.apple.screencaptureui targetPath ~/Screenshots
defaults write com.apple.screencapture disable-shadow true
```

---

## System Information

```bash
# macOS version
sw_vers
# ProductName:    macOS
# ProductVersion: 15.0
# BuildVersion:   24A335

# Hardware info (CPU, RAM, etc.)
system_profiler SPHardwareDataType

# Disk usage
df -h

# Memory usage
vm_stat          # page statistics from the VM system
memory_pressure  # current memory pressure level

# CPU usage
top -l 1 -s 0   # one snapshot, no updates

# Check all running processes sorted by CPU
ps aux | sort -k3rn | head -20

# macOS Chip (Intel or Apple Silicon)
uname -m
# arm64    → Apple Silicon (M1/M2/M3)
# x86_64   → Intel
```

---

## Common Admin Tasks

### Software Updates

```bash
# Check for updates
softwareupdate --list

# Install all updates
sudo softwareupdate --install --all

# Install specific update
sudo softwareupdate --install "macOS Sequoia 15.1"
```

### User Management

```bash
# List all users
dscl . -list /Users | grep -v '^_'

# Create a new user (admin)
sudo dscl . -create /Users/newuser
sudo dscl . -create /Users/newuser UserShell /bin/zsh
sudo dscl . -create /Users/newuser RealName "New User"
sudo dscl . -create /Users/newuser UniqueID 503
sudo dscl . -create /Users/newuser PrimaryGroupID 20
sudo dscl . -create /Users/newuser NFSHomeDirectory /Users/newuser
sudo dscreategroup -o edit -a newuser -t user admin   # make admin

# Delete a user
sudo dscl . -delete /Users/newuser

# Change password
passwd username
```

### Disk Management

```bash
# Disk space usage
df -h               # filesystem usage
du -sh *            # size of each item in current directory
du -sh ~/Downloads  # size of downloads folder

# Find large files
find / -size +100M -type f 2>/dev/null

# Repair disk permissions (APFS handles this automatically, but for old HFS+)
diskutil verifyPermissions /
diskutil repairPermissions /

# Erase a volume
diskutil eraseVolume APFS "NewVolume" /dev/disk2s1
```

### Logs

```bash
# macOS unified logging system (replaces syslog + Console.app)
log show --last 1h                              # last hour of logs
log show --last 1h --level debug                # include debug
log show --predicate 'process == "nginx"' --last 1h  # filter by process
log stream                                      # live log stream
log stream --predicate 'eventMessage contains "error"'  # filter live

# Traditional log files still exist
tail -f /var/log/system.log     # system log
tail -f /var/log/install.log    # install log

# App-specific logs
ls ~/Library/Logs/              # your apps' logs
ls /var/log/                    # system logs
```

---

## macOS Keyboard Shortcuts (Developer Essentials)

```
Cmd+Space           → Spotlight Search
Cmd+Tab             → Switch apps
Cmd+`               → Switch windows within same app
Cmd+Option+Esc      → Force Quit
Ctrl+Cmd+Space      → Emoji picker
Cmd+Shift+3         → Screenshot entire screen
Cmd+Shift+4         → Screenshot selected area
Cmd+Shift+4+Space   → Screenshot a window
Cmd+Ctrl+F          → Toggle full screen

Terminal:
Ctrl+C              → Kill current process
Ctrl+Z              → Suspend process
Ctrl+D              → EOF / close session
Ctrl+A/E            → Beginning/end of line
Ctrl+R              → Search history
Cmd+T               → New tab (iTerm2/Terminal.app)
Cmd+D               → Split pane (iTerm2)
```

→ You've completed the macOS section. Continue to: `../windows/00-mental-model.md`
