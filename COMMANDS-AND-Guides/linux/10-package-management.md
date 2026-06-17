# Part 10 — Package Management: apt, dpkg, snap

Package management is how you install, update, and remove software on Linux. On Ubuntu/Debian systems, `apt` is the primary tool. Understanding it properly prevents the "why won't this install?" frustration.

---

## What Is a Package?

A package is a pre-compiled program bundled with its metadata: name, version, description, and — crucially — its **dependencies** (other packages it needs to run).

The package manager:
1. Downloads the package from a **repository** (server with thousands of packages)
2. Checks and installs all dependencies automatically
3. Puts files in the right places (`/usr/bin/`, `/etc/`, `/usr/lib/`)
4. Records the installation so it can update or remove cleanly later

Without a package manager, installing software manually means: download, extract, compile, copy files, install dependencies manually — a nightmare.

---

## `apt` — The Package Manager for Ubuntu/Debian

### `apt update` — Refresh the Package List

```bash
sudo apt update
```

This does NOT install or upgrade anything. It downloads the current list of available packages and versions from the configured repositories. **Always run this before installing anything.**

```bash
sudo apt update
# Reading package lists... Done
# Building dependency tree
# 42 packages can be upgraded. Run 'apt list --upgradable' to see them.
```

### `apt upgrade` — Upgrade All Installed Packages

```bash
sudo apt upgrade
```

Downloads and installs newer versions of all installed packages. Shows a list of what will be upgraded and asks for confirmation.

```bash
sudo apt upgrade -y    # -y answers "yes" automatically (use with care in production)
```

### The standard update workflow:

```bash
sudo apt update && sudo apt upgrade
```

Always run `update` first to get the latest package list, then `upgrade` to apply it.

---

### `apt install` — Install a Package

```bash
sudo apt install nginx
sudo apt install git
sudo apt install nodejs npm
sudo apt install -y package-name    # skip confirmation prompt
```

What happens:
1. apt checks the package list (fetched by last `apt update`)
2. Finds the package and all its dependencies
3. Shows you what will be installed and how much disk space
4. Downloads and installs everything

### Install a specific version:

```bash
sudo apt install nginx=1.18.0-6ubuntu14
apt-cache policy nginx    # see available versions first
```

---

### `apt remove` vs `apt purge` — Uninstall a Package

```bash
sudo apt remove nginx        # removes the program but KEEPS config files
sudo apt purge nginx         # removes the program AND all its config files
```

**Which to use:** Use `purge` when you want a clean removal. Use `remove` if you want to reinstall later with your existing configuration intact.

### Remove unused dependencies:

```bash
sudo apt autoremove
```

When you remove a package, its dependencies that were automatically installed may no longer be needed. `autoremove` cleans them up.

```bash
sudo apt autoremove --purge     # also delete their config files
```

---

### `apt search` — Find Packages

```bash
apt search nginx              # search for packages related to nginx
apt search "web server"       # search by description
```

### `apt show` — See Package Details

```bash
apt show nginx
# Name: nginx
# Version: 1.18.0-6ubuntu14
# Installed-Size: 125 kB
# Depends: ...
# Description: small, powerful, scalable web/proxy server
```

### `apt list` — List Installed Packages

```bash
apt list --installed                   # all installed packages
apt list --installed | grep nginx      # check if nginx is installed
apt list --upgradable                  # packages that have updates available
```

---

## `dpkg` — Low-Level Package Management

`apt` uses `dpkg` under the hood. You use `dpkg` directly when installing `.deb` files you downloaded manually.

### Install a downloaded .deb file:

```bash
sudo dpkg -i package.deb
```

If `dpkg` complains about missing dependencies:
```bash
sudo apt install -f    # -f = fix broken dependencies
```

### Check if a package is installed:

```bash
dpkg -l nginx               # check if nginx package is installed
dpkg -l | grep nginx        # more flexible search
dpkg -s nginx               # detailed status
```

### List files installed by a package:

```bash
dpkg -L nginx               # list all files that nginx installed
```

### Find which package installed a file:

```bash
dpkg -S /usr/sbin/nginx     # which package owns this file?
# nginx: /usr/sbin/nginx
```

---

## `snap` — Alternative Package Format

Snap packages are self-contained bundles that include all dependencies. They're isolated from the rest of the system.

```bash
sudo snap install code          # install VS Code
sudo snap install docker        # install Docker
snap list                       # list installed snaps
sudo snap refresh               # update all snaps
sudo snap remove code           # remove a snap
snap find "text editor"         # search for snaps
```

**When to use snap vs apt:**
- `apt` — for system software, servers, dependencies that need to integrate deeply with the OS
- `snap` — for desktop applications, developer tools where isolation is fine

---

## `add-apt-repository` — Add External Repositories

The default Ubuntu repositories don't have every package. For some software, you add a third-party repository:

```bash
# Example: add Docker's official repository
sudo apt-get install ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install docker-ce
```

The repositories are stored in:
- `/etc/apt/sources.list` — main repo list
- `/etc/apt/sources.list.d/` — additional repos (one file per source)

---

## `pip` — Python Package Manager

For Python packages (not system packages):

```bash
pip install requests         # install globally (avoid this)
pip install --user requests  # install for current user only (better)

# Best practice: use virtual environments
python3 -m venv venv
source venv/bin/activate     # activate virtual environment
pip install requests         # now installs into venv, not system
pip freeze > requirements.txt    # save current package list
pip install -r requirements.txt  # install from requirements file
deactivate                       # leave virtual environment
```

---

## `npm` — Node.js Package Manager

```bash
npm install package-name        # install locally (into ./node_modules)
npm install -g package-name     # install globally
npm uninstall package-name
npm update
npm list                        # list locally installed packages
npm list -g --depth=0           # list globally installed packages
```

---

## Real-World Scenario: Package Installation Fails

```bash
sudo apt install some-package
# E: Unable to locate package some-package
```

**Diagnostic steps:**

```bash
# Step 1: Is your package list current?
sudo apt update
sudo apt install some-package   # try again

# Step 2: Did you spell it right?
apt search some-package          # find the exact name

# Step 3: Is it in a different repository you haven't added?
# Check the software's official documentation for installation instructions

# Step 4: Check if there's a snap version
snap find some-package
```

---

## Common Misunderstanding: "`apt update` installs updates"

**The misunderstanding:** "I ran `apt update` and my system is now up to date."

**The reality:** `apt update` only updates the **list** of available packages — it's like refreshing a store catalog. Nothing is actually downloaded or installed.

To install the actual updates, you need to run `apt upgrade` after `apt update`.

```bash
sudo apt update     # refresh the catalog
sudo apt upgrade    # actually install the updates
```

Many beginners run `apt update` repeatedly wondering why their packages aren't updating. The two-step process is intentional: `update` fetches the catalog, `upgrade` applies it. This lets you see what will change before committing.

---

→ Continue to: `11-shell-features.md`
