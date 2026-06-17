# The Linux Filesystem — Part 04: /bin, /usr, /opt — Where Programs Live

This is one of the most confusing parts of the Linux filesystem for beginners: there seem to be multiple places where commands and programs live. `/bin`, `/usr/bin`, `/usr/local/bin`, `/opt`... why so many? This file explains the logic.

---

## The "Why" — Historical Origins and Modern Reality

Linux's multi-directory structure for binaries comes from the early Unix days when disk space was scarce. The root disk (`/`) was small, so only the absolute minimum required for the system to boot lived there. Everything else was on a separate `/usr` disk.

**Modern reality (Ubuntu 20.04+):**

`/bin`, `/sbin`, `/lib`, and `/lib64` are now **symlinks** to their counterparts under `/usr/`:

```bash
ls -la /
# lrwxrwxrwx  1 root root     7 Jun 10 /bin -> usr/bin
# lrwxrwxrwx  1 root root    14 Jun 10 /lib -> usr/lib
# lrwxrwxrwx  1 root root    14 Jun 10 /lib64 -> usr/lib64
# lrwxrwxrwx  1 root root     8 Jun 10 /sbin -> usr/sbin
```

They point to the same place. The split was merged in Ubuntu 20.04+ (called "UsrMerge"). On older or other distros, they may be separate.

---

## The Four Program Directories — What Goes Where

### `/usr/bin` — The Main Bin (Most Commands You Use)

This is where the vast majority of commands you type every day live:

```bash
ls /usr/bin | head -30
# bash    cat    chmod    cp    curl    git    grep    ls    mv    nano    python3    ssh    tar    wget
```

These are programs installed by `apt` (or your package manager). Any program you install with `sudo apt install` gets its binary in `/usr/bin` (or `/usr/sbin`).

```bash
which git
# /usr/bin/git

which python3
# /usr/bin/python3

which ls
# /bin/ls  (symlinked to /usr/bin/ls)
```

### `/usr/local/bin` — Locally Compiled/Installed Programs

Programs you compile from source or install manually (NOT via `apt`) go here. This directory takes priority over `/usr/bin` in the PATH.

```bash
# When PATH is:
# /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
# The shell checks /usr/local/bin BEFORE /usr/bin

ls /usr/local/bin/
# node      npm       npx       docker-compose    kubectl
```

The typical programs in `/usr/local/bin`:
- Node.js and npm (installed via nvm or directly, not apt)
- kubectl, terraform, helm (cloud/DevOps tools that you install from official releases)
- Custom scripts you wrote and installed system-wide

**Why "local"?** In a large organization, `/usr` might be on a network filesystem shared across many machines. `/usr/local` is for things specific to this one machine.

### `/usr/sbin` — System Administration Commands

System administration commands that only root (or sudo users) typically run:

```bash
ls /usr/sbin | head -10
# nginx    sshd    useradd    usermod    fdisk    iptables    apache2
```

```bash
which nginx
# /usr/sbin/nginx

sudo nginx -t    # test nginx config
```

### `~/.local/bin` — Your Personal Commands (No sudo Needed)

Scripts and programs you want available as commands just for yourself:

```bash
ls ~/.local/bin/
# my-deploy-script    my-backup    pyenv
```

Add to PATH in `~/.bashrc` if not already there:
```bash
export PATH="$HOME/.local/bin:$PATH"
```

---

## `/usr/lib` — Libraries (The Supporting Cast)

Libraries are shared code that multiple programs use. Like a shared utility module.

```bash
ls /usr/lib/ | head -10
# python3/        nodejs/         ssl/            x86_64-linux-gnu/
```

You almost never touch this directly. Package managers manage it. But you'll encounter it when:

- A program fails with "error while loading shared libraries: libXXX.so not found"
- You're compiling software from source and it can't find dependencies

```bash
# Find which package provides a library:
dpkg -S libssl.so.1.1
# libssl1.1:amd64: /usr/lib/x86_64-linux-gnu/libssl.so.1.1

# Check what libraries a binary needs:
ldd /usr/bin/curl
```

---

## `/opt` — Optional Third-Party Software

Large, self-contained applications that don't follow the standard Linux directory structure install here. The entire application lives in its own subdirectory.

```bash
ls /opt/
# google/         jetbrains/      google-chrome/
```

```bash
ls /opt/google/chrome/
# chrome    chrome.1  chrome-sandbox   locales/   resources/
# (the entire Chrome browser installation)
```

Compare this to a typical `apt`-installed program:
- Binary → `/usr/bin/nginx`
- Config → `/etc/nginx/`
- Logs → `/var/log/nginx/`
- Data → `/var/lib/nginx/`

An `opt` program is self-contained:
- Everything → `/opt/my-commercial-app/` (with its own bin/, lib/, config/ inside)

This is common for:
- Commercial software with its own installer
- Cloud vendor tools (AWS CLI, Google Cloud SDK)
- Applications not in Linux repositories

---

## `/usr/share` — Architecture-Independent Data

```bash
ls /usr/share/ | head -10
# applications/    doc/    fonts/    icons/    locale/    man/    pixmaps/
```

- `/usr/share/man/` — manual pages (the `man` command reads from here)
- `/usr/share/doc/` — documentation for installed packages
- `/usr/share/fonts/` — system fonts
- `/usr/share/applications/` — `.desktop` files (GUI app launchers)

---

## Decision Guide: Where Should I Install Software?

| Software | Install Method | Location |
|----------|---------------|----------|
| System utility (nginx, git, curl) | `sudo apt install` | `/usr/bin/` |
| Cloud/DevOps tools (kubectl, terraform) | Official installer script | `/usr/local/bin/` |
| Node.js (latest version) | `nvm` or official | `/usr/local/bin/` |
| Python package (for everyone) | `pip install` | `/usr/local/lib/python3.x/` |
| Python package (for you only) | `pip install --user` | `~/.local/lib/python3.x/` |
| Your own script (system-wide) | Manual copy | `/usr/local/bin/` |
| Your own script (just for you) | Manual copy | `~/.local/bin/` |
| Large commercial app | Vendor installer | `/opt/vendor-name/` |

---

## Real-World Scenario: "I installed node but the command isn't found"

```bash
node --version
# bash: node: command not found
```

Diagnosis:
```bash
# Where is node?
find / -name "node" -type f 2>/dev/null
# /home/shashank/.nvm/versions/node/v20.0.0/bin/node

# Is that in your PATH?
echo $PATH
# /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
# .nvm path is NOT there!

# Fix: add to ~/.bashrc
nano ~/.bashrc
# Add: export PATH="$HOME/.nvm/versions/node/v20.0.0/bin:$PATH"

source ~/.bashrc
node --version
# v20.0.0
```

---

## Common Misunderstanding: "There is one place where Linux programs are installed"

**The misunderstanding:** "Like Windows 'Program Files', Linux has one place where everything goes."

**The reality:** Linux intentionally splits a program's components across multiple directories based on type:

```
nginx program    → /usr/sbin/nginx
nginx config     → /etc/nginx/nginx.conf
nginx logs       → /var/log/nginx/
nginx state      → /var/lib/nginx/
nginx docs       → /usr/share/doc/nginx/
```

This design means:
- You can backup `/etc` to save all configurations (without backing up the programs)
- You can backup `/var` to save all data (without backing up configs or programs)
- Upgrading a program (new binary in `/usr/sbin/`) doesn't touch your config in `/etc/`
- Multiple programs can share libraries in `/usr/lib/` without duplication

The split is confusing at first but enormously practical for server administration.

---

→ Continue to: `05-proc-and-sys.md`
