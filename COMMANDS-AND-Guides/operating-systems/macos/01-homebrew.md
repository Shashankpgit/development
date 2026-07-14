# macOS — 01: Homebrew (Package Management)

> **Last updated:** July 7, 2026
> **How to install and manage software on macOS — Homebrew is the missing package manager.**

---

## Why macOS Needs Homebrew

Linux distros come with a package manager built in (`apt`, `dnf`, `pacman`). macOS does not.

The Mac App Store exists, but it's for GUI apps only — it doesn't manage CLI tools, developer libraries, or system utilities.

**Homebrew** fills this gap. It's the unofficial-but-universal package manager for macOS. Almost every developer tool you need (`git`, `node`, `python`, `kubectl`, `terraform`, `postgresql`) is available through Homebrew.

---

## Installing Homebrew

```bash
# Install Homebrew (from their official installer script)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# The installer will:
# 1. Install Xcode Command Line Tools (if not present)
# 2. Install Homebrew itself
# 3. Tell you to add Homebrew to your PATH (Apple Silicon Macs)

# On Apple Silicon (M1/M2/M3), add this to ~/.zshrc:
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zshrc
source ~/.zshrc

# On Intel Macs, Homebrew installs to /usr/local (already in PATH)

# Verify
brew --version
# Homebrew 4.x.x
```

---

## Where Homebrew Installs Things

```
Apple Silicon (M1/M2/M3):   /opt/homebrew/
Intel Mac:                  /usr/local/

Inside that:
  bin/        ← Executables (symlinked from Cellar)
  Cellar/     ← Actual installed packages (versioned)
  Caskroom/   ← GUI apps installed via casks
  etc/        ← Config files
  lib/        ← Libraries
```

```bash
# See where a package was installed
brew --prefix node
# /opt/homebrew/opt/node

# See all files a package installed
brew list node
```

---

## Formulae vs Casks

Homebrew has two types of packages:

```
Formula (brew install)
  → CLI tools and libraries
  → Examples: git, node, python, postgresql, redis, ffmpeg

Cask (brew install --cask)
  → GUI applications (.app bundles)
  → Examples: google-chrome, visual-studio-code, iterm2, docker, slack
```

```bash
# Install a CLI tool (formula)
brew install git
brew install node
brew install python@3.12
brew install postgresql@16
brew install kubectl
brew install helm
brew install terraform
brew install awscli

# Install a GUI app (cask)
brew install --cask google-chrome
brew install --cask visual-studio-code
brew install --cask iterm2
brew install --cask docker

# You can mix both in one command
brew install git node python && brew install --cask iterm2
```

---

## Core Homebrew Commands

```bash
# ── SEARCH ────────────────────────────────────────────────────
brew search git              # find packages matching "git"
brew search --cask chrome    # find casks matching "chrome"

# ── INFO ──────────────────────────────────────────────────────
brew info node               # version, dependencies, caveats
brew info --cask iterm2      # info about a cask

# ── INSTALL ───────────────────────────────────────────────────
brew install node            # install latest version
brew install node@20         # install specific version
brew install --cask iterm2   # install GUI app

# ── UNINSTALL ─────────────────────────────────────────────────
brew uninstall node          # remove package
brew uninstall --cask iterm2 # remove GUI app
brew autoremove              # remove packages installed as dependencies, no longer needed

# ── UPDATE / UPGRADE ──────────────────────────────────────────
brew update                  # update Homebrew itself and formulae list
brew upgrade                 # upgrade all outdated packages
brew upgrade node            # upgrade one specific package
brew upgrade --cask          # upgrade all GUI apps
brew upgrade --cask iterm2   # upgrade one GUI app

# ── CHECK WHAT'S OUTDATED ─────────────────────────────────────
brew outdated                # list packages with newer versions available
brew outdated --cask         # list outdated casks

# ── LIST INSTALLED ────────────────────────────────────────────
brew list                    # all installed formulae
brew list --cask             # all installed casks
brew list --versions         # show version numbers

# ── HEALTH CHECK ──────────────────────────────────────────────
brew doctor                  # diagnose potential problems
brew cleanup                 # delete old versions to free disk space
brew cleanup -n              # dry run — show what would be deleted
```

---

## Managing Multiple Versions

Some tools need multiple versions (e.g., Node 18 and Node 20 on the same machine). Use version managers alongside Homebrew:

```bash
# nvm for Node.js versions (not from Homebrew)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.0/install.sh | bash
nvm install 20
nvm install 18
nvm use 20

# pyenv for Python versions
brew install pyenv
pyenv install 3.12.0
pyenv install 3.11.0
pyenv global 3.12.0

# rbenv for Ruby versions
brew install rbenv
rbenv install 3.3.0
rbenv global 3.3.0

# For Go, just install specific version via Homebrew
brew install go@1.22
```

---

## Taps — Third-Party Repositories

A **tap** is an additional Homebrew repository. Many tools (Kubernetes ecosystem, HashiCorp, etc.) publish their own taps:

```bash
# Add a tap
brew tap hashicorp/tap
brew install hashicorp/tap/terraform

# AWS tap
brew tap aws/tap
brew install aws/tap/eks-node-viewer

# List taps
brew tap

# Remove a tap
brew untap hashicorp/tap
```

Popular taps:
```
homebrew/cask-fonts     → developer fonts (JetBrains Mono, Fira Code)
hashicorp/tap           → Terraform, Vault, Nomad
aws/tap                 → AWS CLI tools
azure/azure             → Azure CLI
jenkins-infra/jenkins   → Jenkins
```

---

## Brewfile — Reproducible Setup

A `Brewfile` lists all your packages so you can reproduce your setup on a new Mac:

```ruby
# ~/Brewfile

# Taps
tap "hashicorp/tap"

# CLI tools
brew "git"
brew "node"
brew "python@3.12"
brew "awscli"
brew "kubectl"
brew "helm"
brew "terraform"
brew "jq"
brew "ripgrep"
brew "fzf"

# GUI apps
cask "iterm2"
cask "visual-studio-code"
cask "docker"
cask "google-chrome"
cask "rectangle"     # window manager

# Mac App Store apps
mas "Slack", id: 803453959
```

```bash
# Install everything in Brewfile (on new Mac)
brew bundle

# Install from a specific file
brew bundle --file=~/dotfiles/Brewfile

# Check which Brewfile items are not installed
brew bundle check

# Generate Brewfile from currently installed packages
brew bundle dump
```

---

## Homebrew Services

Homebrew can manage background services (databases, web servers) using `launchd`:

```bash
# Start a service (and auto-start on login)
brew services start postgresql@16
brew services start redis

# Stop a service
brew services stop postgresql@16

# Restart a service
brew services restart nginx

# List all services and their status
brew services list

# Stop all running services
brew services stop --all
```

Homebrew services is the macOS equivalent of `systemctl enable/start` on Linux.

---

## Xcode Command Line Tools

Many developer tools (git, make, clang, python) require **Xcode Command Line Tools** — Apple's lightweight developer toolkit (without the full Xcode IDE).

```bash
# Install CLT
xcode-select --install
# A popup appears — click Install

# Verify
xcode-select -p
# /Library/Developer/CommandLineTools

# Check version
pkgutil --pkg-info=com.apple.pkg.CLTools_Executables

# Reinstall if broken
sudo rm -rf /Library/Developer/CommandLineTools
xcode-select --install
```

Homebrew installs CLT automatically if missing.

→ Continue to: `02-filesystem-and-apfs.md`
