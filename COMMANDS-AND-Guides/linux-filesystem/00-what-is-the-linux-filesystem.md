# The Linux Filesystem — Part 00: What Is It and How Does It Think?

Before you learn what `/etc` or `/var` means, you need to understand the philosophy behind the Linux filesystem. It is completely different from Windows, and trying to understand Linux with a Windows mental model leads to constant confusion.

---

## "Everything Is a File"

This is the most important phrase in Linux. In Linux, the operating system represents almost **everything** as a file — not just documents and folders, but:

- Your keyboard → a file (`/dev/input/event0`)
- Your hard drive → a file (`/dev/sda`)
- Your network interface → a file
- Running processes → files in `/proc/`
- System settings → files in `/sys/`
- A random number generator → a file (`/dev/random`)
- A black hole that discards everything → a file (`/dev/null`)

This philosophy has a powerful consequence: **every tool that works with files can work with all of these things.** You can read your CPU temperature by reading a file. You can write to a device by writing to a file. One set of tools rules everything.

---

## One Tree, Many Branches

Windows has multiple roots: `C:\`, `D:\`, `E:\`. Each drive is its own separate tree.

Linux has **exactly one root**: `/` (a single forward slash). Everything — every drive, every USB stick, every network share — is attached somewhere inside this single tree.

```
/                    ← the root of everything
├── etc/             ← configuration files
├── home/            ← user home directories
│   └── shashank/    ← your personal files
├── var/             ← variable data (logs, databases)
├── tmp/             ← temporary files
├── usr/             ← user-installed programs
├── bin/             ← essential system commands
├── mnt/             ← where extra drives are "mounted"
│   └── usb/         ← your USB drive might appear here
└── proc/            ← virtual: running processes
```

When you plug in a USB drive, Linux **mounts** it somewhere in this tree — like attaching a branch. The USB's filesystem becomes accessible at something like `/mnt/usb/` or `/media/shashank/DRIVE_NAME/`. When you eject it, that branch is removed.

---

## The Filesystem Hierarchy Standard (FHS)

The Linux community standardized what goes where in the **Filesystem Hierarchy Standard (FHS)**. This means:

- Config files for any program go in `/etc/`
- Log files always go in `/var/log/`
- User-installed commands go in `/usr/local/bin/`
- Temporary files go in `/tmp/`

Because of this standard, a sysadmin who has never seen your specific system can still find the config file for nginx, the logs for PostgreSQL, and your SSH keys — because they're always in the same place.

---

## The Home Directory

Every user has a **home directory** — a private space where their personal files, configurations, and data live.

- Regular users: `/home/username/`
- Root user: `/root/`

The `~` (tilde) in the terminal is a shortcut that always expands to your home directory:

```bash
cd ~              # same as cd /home/shashank
ls ~/.ssh         # same as ls /home/shashank/.ssh
```

---

## Dot Files (Hidden Configuration Files)

Files and directories starting with `.` are hidden from normal `ls` output. In your home directory, these store your personal settings for every program:

```bash
ls -la ~
# .bashrc        ← bash configuration (aliases, PATH, etc.)
# .gitconfig     ← git global configuration
# .ssh/          ← SSH keys and known hosts
# .config/       ← configuration for many apps
# .local/        ← user-specific data and installations
# .vimrc         ← vim configuration
# .npmrc         ← npm configuration
```

These hidden files/dirs are what make your terminal "feel like yours" — your aliases, your git identity, your SSH keys. When developers talk about "dotfiles", they mean these files, and many people store them in a Git repo to reproduce their setup on any new machine.

---

## Mounting — How Storage Gets Attached to the Tree

A **mount** is the act of attaching a filesystem to a directory (called a "mount point") in the tree.

```bash
# See what is currently mounted
mount | column -t
# or more clearly:
df -h
```

```
Filesystem      Size  Used Avail Use% Mounted on
/dev/sda1        20G   14G  4.8G  75% /             ← main disk, mounted at root
tmpfs           3.9G     0  3.9G   0% /dev/shm       ← RAM-based filesystem
/dev/sdb1       500G  180G  295G  37% /mnt/backup    ← second drive, mounted at /mnt/backup
```

When you access `/mnt/backup/`, the OS transparently reads from the second disk `/dev/sdb1`. From a user's perspective, it's just a folder.

---

## Absolute vs Relative Paths — The Navigation Contract

Any path starting with `/` is absolute — it describes the full location from the root:
```
/home/shashank/projects/vault-app/src/index.js
```

Any path NOT starting with `/` is relative — it starts from your current location:
```
projects/vault-app/src/index.js    (if you're currently in /home/shashank/)
./src/index.js                     (if you're in /home/shashank/projects/vault-app/)
```

---

## The Directory Tree at a Glance

Here is the full top-level structure with a one-line explanation of each:

```
/
├── bin/         System binaries (commands) needed for single-user mode
├── sbin/        System administration binaries (root-only commands)
├── lib/         Libraries needed by /bin and /sbin
├── lib64/       64-bit libraries
├── etc/         ← CONFIGURATION FILES for all programs
├── home/        ← USER HOME DIRECTORIES
├── root/        Root user's home directory
├── var/         ← VARIABLE DATA: logs, databases, mail, caches
├── tmp/         ← TEMPORARY FILES (cleared on reboot)
├── usr/         ← USER-INSTALLED PROGRAMS and their data
│   ├── bin/     Non-essential user commands (most of what you use)
│   ├── sbin/    Non-essential system admin commands
│   ├── lib/     Libraries for /usr/bin and /usr/sbin
│   ├── local/   Locally compiled/installed software (NOT from apt)
│   └── share/   Architecture-independent data (man pages, icons, docs)
├── opt/         Optional third-party software packages
├── dev/         ← DEVICE FILES (hardware as files)
├── proc/        ← VIRTUAL: Running processes and kernel info
├── sys/         ← VIRTUAL: Kernel and hardware configuration
├── mnt/         Manual mount points (for drives you mount yourself)
├── media/       Auto-mount points (USB drives, CDs — mounted by OS)
├── srv/         Data served by this system (websites, FTP)
├── run/         Runtime data (PIDs, sockets — cleared on reboot)
└── boot/        Bootloader and kernel files
```

---

## Common Misunderstanding: "Linux directories are like Windows folders"

**The misunderstanding:** "C:\Program Files is like /usr, C:\Users is like /home, C:\Windows\System32 is like /bin."

**The reality:** While there are rough analogies, the purpose and organization is fundamentally different:

| Windows | Linux | Key Difference |
|---------|-------|---------------|
| `C:\Program Files` | `/usr/bin`, `/opt` | Linux separates config (`/etc`), data (`/var`), and binaries |
| `C:\Users` | `/home` | Similar |
| `C:\Windows\System32` | `/usr/lib`, `/lib` | Linux splits by purpose, not program |
| `C:\Windows\Temp` | `/tmp` | Similar, but `/tmp` always clears on reboot |
| `C:\ProgramData` | `/var/lib` | Similar |
| Registry | `/etc/*.conf` | Linux uses plain text files — no registry |

The biggest difference: **no registry.** In Linux, every application's configuration is a plain text file in `/etc/` or `~/.config/`. You can read it, edit it, back it up, and diff it with Git. This makes Linux systems vastly more transparent and debuggable than Windows.

---

→ Continue to: `01-etc-configuration.md`
