# Operating Systems — 08: Package Management

> **Last updated:** July 6, 2026
> **Installing, updating, and removing software on Linux. apt for Ubuntu/Debian, dnf/yum for Amazon Linux/RHEL.**

---

## What Is a Package?

A **package** is a bundle of:
- The compiled binary (program files)
- Configuration files
- Man pages / documentation
- Dependency metadata ("I need libssl >= 1.1")
- Pre/post install scripts

When you install a package, the package manager:
1. Checks dependencies — installs anything your package needs
2. Copies files to the right locations (`/usr/bin`, `/etc`, `/usr/lib`)
3. Runs post-install scripts (create user accounts, run `systemctl enable`)
4. Records what was installed so it can be removed cleanly later

---

## apt — Debian/Ubuntu Package Manager

### Basic Operations

```bash
# Update the package list (what's available in repos):
sudo apt update
# ALWAYS run this before installing anything

# Upgrade installed packages:
sudo apt upgrade             # upgrade packages, never remove
sudo apt full-upgrade        # upgrade, remove obsolete packages if needed
sudo apt dist-upgrade        # old name for full-upgrade

# Install a package:
sudo apt install nginx
sudo apt install nginx curl git vim htop   # multiple at once

# Remove a package (keeps config files):
sudo apt remove nginx

# Remove + delete config files:
sudo apt purge nginx

# Remove unused dependencies:
sudo apt autoremove

# All together (clean up fully):
sudo apt purge nginx && sudo apt autoremove

# Search for packages:
apt search "web server"
apt-cache search nginx         # old but works

# Show package info:
apt show nginx
# Depends, recommends, description, installed version, etc.
```

### Querying What's Installed

```bash
# List all installed packages:
dpkg -l
dpkg -l | grep nginx          # find specific packages
dpkg -l | grep "^ii"          # only fully installed

# Find what package a file belongs to:
dpkg -S /usr/sbin/nginx
# nginx: /usr/sbin/nginx

# List all files installed by a package:
dpkg -L nginx

# Check if a package is installed:
dpkg -l nginx
# ii  nginx  1.18.0  amd64  high performance web server
# If not installed: no output or "dpkg-query: no packages found"
```

### Pinning — Holding Packages at a Version

```bash
# Prevent a package from being upgraded:
sudo apt-mark hold nginx
# (useful: you're on a specific nginx version for a reason)

# Release the hold:
sudo apt-mark unhold nginx

# See held packages:
apt-mark showhold
```

### Managing Repositories

```bash
# View configured repos:
cat /etc/apt/sources.list
ls /etc/apt/sources.list.d/

# Add a repo (example: Docker's official repo):
# Step 1: Add the GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker.gpg

# Step 2: Add the repo
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list

# Step 3: Update and install
sudo apt update
sudo apt install docker-ce

# Remove a repo:
sudo rm /etc/apt/sources.list.d/docker.list
sudo apt update   # refresh
```

### Non-Interactive Installation (for Scripts)

```bash
# Avoid prompts (for automation/CI/CD):
DEBIAN_FRONTEND=noninteractive sudo apt install -y nginx

# Or set globally:
export DEBIAN_FRONTEND=noninteractive
sudo apt install -y nginx curl git
```

---

## dnf / yum — Amazon Linux 2023 / RHEL / Fedora Package Manager

`dnf` is the modern replacement for `yum`. On Amazon Linux 2023, both commands work (yum is an alias for dnf).

### Basic Operations

```bash
# Update package list AND upgrade (unlike apt, dnf does both):
sudo dnf update               # update all packages
sudo dnf update nginx         # update specific package

# Install:
sudo dnf install nginx
sudo dnf install -y nginx curl git vim htop   # -y = say yes to all prompts

# Remove:
sudo dnf remove nginx

# Remove + orphaned dependencies:
sudo dnf autoremove

# Search:
dnf search nginx
dnf search "web server"

# Package info:
dnf info nginx
```

### Querying What's Installed

```bash
# List installed packages:
dnf list installed
dnf list installed | grep nginx

# Find what package a file belongs to:
rpm -qf /usr/sbin/nginx
# nginx-1.20.0-1.amzn2023.x86_64

# List files installed by a package:
rpm -ql nginx

# Check if installed:
rpm -q nginx
# nginx-1.20.0-1.amzn2023.x86_64  (if installed)
# package nginx is not installed  (if not)
```

### Managing Repositories

```bash
# View configured repos:
dnf repolist
dnf repolist all              # include disabled repos

# Repo files live in:
ls /etc/yum.repos.d/

# Enable/disable a repo:
sudo dnf config-manager --enable epel
sudo dnf config-manager --disable epel

# Add EPEL (Extra Packages for Enterprise Linux) on Amazon Linux 2023:
sudo dnf install epel-release   # or:
sudo dnf install https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm

# Install from a specific repo:
sudo dnf install --enablerepo=epel htop
```

### Version Locking

```bash
# Lock a package to its current version:
sudo dnf install 'dnf-command(versionlock)'
sudo dnf versionlock add nginx

# Remove the lock:
sudo dnf versionlock delete nginx

# List locked packages:
sudo dnf versionlock list
```

---

## apt vs dnf — The Differences

| Task | apt (Ubuntu/Debian) | dnf (Amazon Linux/RHEL) |
|------|--------------------|-----------------------|
| Update package list | `apt update` | `dnf check-update` (automatic) |
| Install | `apt install pkg` | `dnf install pkg` |
| Remove | `apt remove pkg` | `dnf remove pkg` |
| Remove + config | `apt purge pkg` | `dnf remove pkg` (config in /etc stays) |
| Search | `apt search term` | `dnf search term` |
| List installed | `dpkg -l` | `rpm -qa` or `dnf list installed` |
| Which package owns file | `dpkg -S /path` | `rpm -qf /path` |
| Files in package | `dpkg -L pkg` | `rpm -ql pkg` |
| Package format | `.deb` | `.rpm` |
| Repo config | `/etc/apt/sources.list.d/` | `/etc/yum.repos.d/` |

---

## Package Caches and Cleanup

```bash
# apt: Clean downloaded packages (frees disk space):
sudo apt clean             # remove all cached .deb files
sudo apt autoclean         # remove only obsolete cached .debs

# dnf: Clean caches:
sudo dnf clean all
sudo dnf clean packages
```

---

## Installing Software Not in a Repo

### Direct Download (Manual Binary)

```bash
# Download and install a .deb manually:
wget https://releases.example.com/app_1.0.0_amd64.deb
sudo dpkg -i app_1.0.0_amd64.deb
sudo apt install -f    # install missing dependencies if dpkg complains

# Download and install an .rpm manually:
wget https://releases.example.com/app-1.0.0.x86_64.rpm
sudo rpm -ivh app-1.0.0.x86_64.rpm
# Or with dependency handling:
sudo dnf localinstall app-1.0.0.x86_64.rpm

# Download and use a binary directly:
curl -LO https://releases.example.com/app-linux-amd64
chmod +x app-linux-amd64
sudo mv app-linux-amd64 /usr/local/bin/app
```

### Building From Source

```bash
# The classic:
wget https://example.com/app-1.0.tar.gz
tar -xzf app-1.0.tar.gz
cd app-1.0/

./configure --prefix=/usr/local   # detect system, generate Makefile
make                               # compile
sudo make install                  # copy binaries to /usr/local/bin

# Install build tools first:
sudo apt install build-essential   # Ubuntu
sudo dnf groupinstall "Development Tools"  # Amazon Linux

# Uninstall: often:
sudo make uninstall
# Or just delete: sudo rm -rf /usr/local/bin/app /usr/local/share/app/
# (this is the pain point — no clean uninstall tracking, unlike package managers)
```

---

## snap — Universal Packages (Ubuntu)

Snap packages run in isolation and work across distros. AWS EC2 instances often don't have snapd installed (and it's not recommended for servers).

```bash
# Install snapd:
sudo apt install snapd

# Install an app:
sudo snap install code --classic    # VS Code

# List installed snaps:
snap list

# Remove:
sudo snap remove code
```

---

## Understanding Package Dependencies

```bash
# Why does installing nginx install 10 other packages?
sudo apt install --dry-run nginx  # shows what would be installed without doing it
sudo apt install -s nginx         # simulate

# See what a package depends on:
apt-cache depends nginx
# nginx
#   Depends: nginx-common (= 1.18.0-6ubuntu14)
#   Depends: libc6 (>= 2.28)
#   Depends: libpcre3
#   ...

# See what packages depend on this one (reverse depends):
apt-cache rdepends nginx
```

---

## Security Updates

```bash
# List only security updates available:
sudo apt list --upgradable 2>/dev/null | grep -i security
# Ubuntu-specific:
sudo apt install unattended-upgrades
sudo dpkg-reconfigure unattended-upgrades   # configure auto-install security updates

# Amazon Linux — security updates:
sudo dnf check-update --security
sudo dnf upgrade --security   # install only security updates
```

---

## Anatomy of a .deb Package (FYI)

```bash
# A .deb is an AR archive containing:
ar x nginx_1.18.0-1_amd64.deb
ls
# control.tar.xz   → package metadata, dependency info, install scripts
# data.tar.xz      → actual files to be installed
# debian-binary    → package format version

# You can inspect them:
dpkg-deb --info nginx_1.18.0-1_amd64.deb      # metadata
dpkg-deb --contents nginx_1.18.0-1_amd64.deb  # file list
```

---

## Practical: Setting Up a Fresh EC2 Instance

```bash
# ── Amazon Linux 2023 ──────────────────────────────────────────────
sudo dnf update -y
sudo dnf install -y \
  git curl wget vim htop \
  python3 python3-pip \
  nginx \
  unzip jq

# ── Ubuntu 22.04 ───────────────────────────────────────────────────
sudo apt update && sudo apt upgrade -y
sudo apt install -y \
  git curl wget vim htop \
  python3 python3-pip \
  nginx \
  unzip jq \
  build-essential
```

→ Continue to: `09-systemd-and-services.md`
