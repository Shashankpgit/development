# macOS — 00: Mental Model

> **Last updated:** July 7, 2026
> **What macOS actually is under the hood, how it relates to Linux, and why it behaves the way it does.**

---

## What macOS Actually Is

macOS is **not Linux**. But it's also not unrelated to Linux.

Both Linux and macOS are **Unix-like** operating systems — they share the same ideas: everything is a file, processes, users, permissions, pipes, shells. But they come from different branches of the Unix family tree.

```
AT&T Unix (1969)
  │
  ├── BSD (Berkeley Software Distribution, 1977)
  │     └── FreeBSD / NetBSD / OpenBSD
  │           └── Darwin (Apple's open-source OS core, 2000)
  │                 └── macOS (Darwin + Apple's proprietary GUI + apps)
  │
  └── System V Unix
        └── (influenced Linux design)

Linux (1991) — written from scratch, Unix-compatible but not Unix-derived
```

**macOS = Darwin (BSD kernel + XNU kernel) + Apple frameworks + GUI (Aqua)**

Darwin is open source. The GUI and frameworks (AppKit, SwiftUI, Metal, etc.) are closed source.

---

## The Darwin / XNU Kernel

The kernel inside macOS is called **XNU** (X is Not Unix). It is a hybrid kernel combining:

```
Mach microkernel    → Low-level services: threads, IPC, virtual memory
BSD layer           → POSIX APIs, filesystem, networking, process management
I/O Kit             → Device drivers framework (object-oriented, C++)
```

This is why macOS has both `mach_msg` (Mach IPC) and `fork()` (POSIX) — two different subsystems in the same kernel.

**Practical implication:** Most Linux commands work on macOS because both implement POSIX. But macOS versions of tools are often **older or slightly different** from GNU/Linux versions.

```bash
# macOS ships with BSD versions of common tools:
ls --color=auto        # GNU ls (Linux) — works
ls --color=auto        # BSD ls (macOS) — doesn't understand --color flag

date --iso-8601        # GNU date (Linux) — works
date -u +%Y-%m-%d      # BSD date (macOS) — different flags

sed -i 's/a/b/' file   # GNU sed (Linux) — in-place edit, no backup
sed -i '' 's/a/b/' file  # BSD sed (macOS) — requires '' argument for no backup
```

This is the most common source of "works on my Mac but breaks in CI (Linux)" bugs.

---

## macOS Directory Structure

macOS uses a single root `/` tree (like Linux), but the locations are different:

```
/
├── Applications/      ← Installed apps (.app bundles) — macOS-specific
├── Library/           ← System-wide settings, frameworks, preferences
├── System/            ← Apple's OS files — protected by SIP, do not touch
│   └── Library/
├── Users/             ← Home directories (like /home/ on Linux)
│   └── shashank/
│       ├── Desktop/
│       ├── Documents/
│       ├── Downloads/
│       └── Library/   ← User-specific app data, preferences, caches
│           ├── Application Support/   ← App data (like ~/.local/share on Linux)
│           ├── Preferences/           ← .plist files (like dotfiles on Linux)
│           ├── Caches/                ← App caches (safe to delete)
│           └── Logs/                  ← App logs
├── bin/               ← Essential binaries (ls, cp, mv — BSD versions)
├── sbin/              ← System binaries
├── usr/               ← Unix standard (like Linux's /usr)
│   ├── bin/           ← More binaries
│   ├── lib/           ← Libraries
│   └── local/         ← Homebrew installs here
├── etc/               ← System config files (symlinked from /private/etc)
├── tmp/               ← Temp files (symlinked from /private/tmp)
├── var/               ← Variable data, logs (symlinked from /private/var)
├── opt/               ← Homebrew (Apple Silicon) installs here
└── Volumes/           ← Mounted disks (like /mnt on Linux)
```

**Key macOS-only things:**
- `.app` bundles — a "folder" that looks like a single file in Finder
- `~/Library/` — hidden in Finder by default, where apps store user data
- `/System/` — protected, read-only in newer macOS (SIP)
- `/Volumes/` — external drives, disk images mount here

---

## macOS vs Linux — The Key Differences

| Concept | Linux | macOS |
|---------|-------|-------|
| Kernel | Linux kernel | XNU (Darwin) |
| Init system | systemd | launchd |
| Package manager | apt / dnf / pacman | Homebrew (third-party) |
| Default shell | bash | zsh (since macOS Catalina 2019) |
| File permissions | chmod/chown (same) | chmod/chown (same) + extended attrs |
| Graphical apps | X11 / Wayland | Cocoa / AppKit / SwiftUI |
| App distribution | .deb / .rpm / AUR | .app / .dmg / Mac App Store |
| Default tools | GNU coreutils | BSD coreutils (older, different flags) |
| System integrity | AppArmor / SELinux | SIP (System Integrity Protection) |
| Disk format | ext4 / btrfs / xfs | APFS / HFS+ |
| Log system | journald / syslog | Unified Logging System (log, Console.app) |
| Service config | .service files | .plist files |

---

## What Carries Over from Linux

Since macOS implements POSIX, most of what you know from Linux applies:

```bash
# These all work the same on macOS:
ls -la
cd, pwd, mkdir, rm, cp, mv
cat, head, tail, grep, find
ssh, scp, rsync
curl, wget (if installed)
ps, top, kill
chmod, chown
pipe |, redirect >, >>
environment variables ($HOME, $PATH, $USER)
.bashrc / .zshrc for shell config
```

The tools exist but may have slightly different flags (BSD vs GNU).

---

## The Shell on macOS

Since **macOS Catalina (2019)**, the default shell is **zsh** (Z shell), not bash.

```bash
# Check your current shell
echo $SHELL
# /bin/zsh

# Switch to bash if you prefer (not recommended — Apple deprecated it)
chsh -s /bin/bash

# Check shell version
zsh --version
bash --version
```

zsh is largely bash-compatible. The main differences you'll notice:
- Config file: `~/.zshrc` (not `~/.bashrc`)
- Better tab completion and globbing
- Better plugin ecosystem (Oh My Zsh)
- Array handling is slightly different

---

## What's Next

| File | What It Covers |
|------|---------------|
| `01-homebrew.md` | Package management — installing and managing software on macOS |
| `02-filesystem-and-apfs.md` | APFS, Spotlight, .DS_Store, permissions, SIP |
| `03-processes-and-launchd.md` | Activity Monitor, launchd vs systemd, managing services |
| `04-security-model.md` | Gatekeeper, SIP, FileVault, Keychain, privacy permissions |
| `05-networking.md` | macOS network config, networksetup, pf firewall, VPN |
| `06-in-practice.md` | Developer machine setup, dotfiles, common admin tasks |

→ Continue to: `01-homebrew.md`
