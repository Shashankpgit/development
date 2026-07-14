# Operating Systems — What Are They?

## How to Use This Guide

**Start here** — this file gives you the big picture.  
**Then go to `concepts/`** — learn how an OS actually works (kernel, processes, memory, filesystem, etc.) — platform-independent.  
**Then pick a platform** — once you understand the concepts, go deep on the specific OS you need:
- `linux/` — servers, cloud, Docker
- `macos/` — Mac developer machine
- `windows/` — Windows desktop/server

---

## What Is an Operating System?

Your computer has hardware — a CPU, RAM, storage, a keyboard, a screen. None of that hardware knows how to talk to your Python script or your browser.

An **Operating System (OS)** sits between your hardware and your applications. Its job is to:

- **Manage hardware** — give programs access to CPU, memory, disk, and network without them needing to know the specifics of the hardware
- **Run multiple programs at once** — switching between them so fast it feels simultaneous
- **Manage files** — organize data on disk into files and folders
- **Handle security** — decide which programs and users can access what

Without an OS, you'd have to write your program to talk to hardware directly — which changes for every computer model. The OS abstracts that away.

```
Your App  →  Operating System  →  Hardware
           (the middleman)
```

---

## The Three Major Operating Systems

| | Linux | macOS | Windows |
|--|-------|-------|---------|
| **Made by** | Community (Linus Torvalds started it) | Apple | Microsoft |
| **First release** | 1991 | 1984 (as Mac OS), 2001 (as macOS) | 1985 |
| **Kernel** | Linux kernel | XNU (Darwin) | NT kernel |
| **Based on** | Unix principles | Unix (BSD) | Original design (not Unix) |
| **Primary use** | Servers, cloud, embedded | Developer machines | Desktops, enterprise |
| **Free?** | Yes | Comes with Mac hardware | Paid |

---

## Linux

### What Is It?

Linux is not a full OS by itself — it's technically just the **kernel** (the core part that talks to hardware). The full OS you actually use is called a **Linux distribution** (distro), which bundles the Linux kernel with tools, a package manager, and sometimes a desktop GUI.

```
Linux kernel  +  GNU tools  +  Package manager  +  Desktop  =  Linux distribution
```

### Popular Distributions

```
Ubuntu     → Most popular for beginners and servers. "apt" package manager.
Debian     → Stable, minimal. Ubuntu is based on this.
Fedora     → Cutting-edge, sponsored by Red Hat. "dnf" package manager.
CentOS/RHEL → Enterprise standard. Common in corporate servers.
Alpine     → Tiny (5MB). Used heavily in Docker containers.
Arch Linux → DIY, you build it from scratch. For advanced users.
```

### Where Is Linux Used?

- **Almost every web server and cloud VM** — when you deploy to AWS, GCP, Azure, you're on Linux
- **Android phones** — Android runs on the Linux kernel
- **Docker containers** — containers use the Linux kernel
- **Supercomputers** — 100% of the world's top 500 supercomputers run Linux
- **Embedded systems** — routers, smart TVs, cars

### Why Developers Love It

- Free and open source — you can read and modify the source code
- Built for the command line — very powerful shell scripting
- Stable and lightweight — runs efficiently on minimal hardware
- Standard in cloud — if your app runs in production, it's almost certainly on Linux

### The Shell

Linux's primary interface is the **terminal** (command line). The default shell is usually **bash** or **zsh**.

```bash
ls            # list files
cd /etc       # change directory
cat file.txt  # read a file
ps aux        # list running processes
```

---

## macOS

### What Is It?

macOS is Apple's operating system for Mac computers. Under the hood, it's built on **Darwin** — which is based on BSD Unix. So macOS is a proper Unix system, just with Apple's graphical interface on top.

The kernel is called **XNU** ("X is Not Unix" — a bit of a joke name).

### macOS vs Linux

Both macOS and Linux trace their roots back to Unix, so they share a lot:
- Same basic shell commands (`ls`, `cd`, `grep`, `ssh`)
- Same file structure (`/etc`, `/usr`, `/var`)
- Same permission model (`chmod`, `chown`)

But there are differences:
- macOS is **closed source** — you can't modify the OS itself
- macOS is **case-insensitive** by default (`File.txt` = `file.txt`) — Linux is case-sensitive
- macOS uses **Homebrew** for installing tools (Linux uses apt/dnf/etc.)
- macOS has **launchd** for managing background services — Linux uses systemd
- macOS has **Keychain** for storing secrets — macOS-specific
- macOS desktop apps are `.app` bundles — different from Linux's package-based apps

### Where Is macOS Used?

- Developer machines — especially for web/mobile/cloud development
- Design and creative work (Adobe apps, Final Cut Pro, etc.)
- iOS/macOS app development — Xcode only runs on Mac

### Why Developers Use It

- Unix underneath — all your Linux skills transfer, same shell commands work
- Great hardware (MacBook Pro, Mac Mini)
- Native Docker, SSH, and terminal tools work out of the box
- Required for iOS app development

### The Shell

macOS comes with **zsh** as the default shell (changed from bash in macOS Catalina, 2019).

```bash
# macOS-specific commands
brew install node       # install packages (Homebrew)
open .                  # open current folder in Finder
pbcopy < file.txt       # copy file content to clipboard
mdfind "query"          # Spotlight search from terminal
```

---

## Windows

### What Is It?

Windows is Microsoft's OS, built on the **NT kernel** — first released in 1993. It is **not Unix**. It was designed separately, with different goals: strong GUI from day one, enterprise integration, and backward compatibility (apps from 2005 still run on Windows 11).

Because Windows is not Unix, a lot of standard Linux/macOS commands don't exist by default — though this has improved a lot with PowerShell and WSL.

### Key Windows Concepts That Are Different

**Drive Letters**
Instead of one `/` root like Linux/macOS, Windows gives each drive its own letter:
```
C:\  → main drive (your Windows installation)
D:\  → second drive or DVD
```

**The Registry**
Windows stores system and app configuration in a database called the **Windows Registry** — not in plain text files like Linux's `/etc`. This is why Windows apps often leave traces when uninstalled.

**PowerShell**
Windows's modern shell. Unlike bash (which works with text), PowerShell works with **.NET objects** — you can pipe rich data between commands instead of just text strings.

```powershell
Get-Process | Sort-Object CPU -Descending | Select-Object -First 5
```

**WSL (Windows Subsystem for Linux)**
Microsoft built a way to run a real Linux environment inside Windows. With WSL2, you get a genuine Linux kernel running inside a lightweight VM. Developers on Windows use this heavily.

```powershell
wsl --install          # installs Ubuntu
wsl                    # opens a Linux terminal
```

### Where Is Windows Used?

- Personal desktop computers — by far the most common desktop OS (~70% market share)
- Enterprise environments — Active Directory, Group Policy, Microsoft 365
- .NET and C# development
- Gaming — most games are Windows-first
- Windows Server — still common in enterprises, especially those deep in the Microsoft ecosystem

### Why Some Developers Use It

- It's what they grew up with
- .NET / C# development
- Enterprise environment forces it
- WSL2 solves most "I need Linux" problems now

---

## How They Relate

```
Unix (1969, AT&T Bell Labs)
  ├── BSD Unix
  │     └── macOS (Darwin/XNU kernel)
  │
  └── Unix principles
        └── Linux (1991, Linus Torvalds reimplemented from scratch)

Windows NT (1993, Microsoft) — completely separate, not Unix-based
```

macOS and Linux share Unix DNA — they behave similarly in the terminal. Windows is a different lineage entirely, though it has been adding Unix compatibility layers over the years.

---

## Choosing an OS for Development

| You're doing... | Recommended OS |
|----------------|---------------|
| Web dev / cloud / DevOps | Linux (as server), macOS or Linux (as dev machine) |
| iOS / macOS app development | macOS (required — Xcode only runs on Mac) |
| Android development | Any OS |
| .NET / C# / Azure | Windows or macOS |
| Enterprise IT / Windows administration | Windows |
| Learning Linux / servers | Linux (or macOS — they're similar) |
| Game development | Windows (most engine/tooling support) |

---

## Summary

- **OS** = software that sits between your hardware and your apps
- **Linux** = open source, powers almost all servers and cloud — learn this if you do anything with servers or Docker
- **macOS** = Unix-based, Apple hardware, great developer machine — your Linux skills transfer almost entirely
- **Windows** = not Unix, different architecture, dominant on desktops — has WSL2 now for Linux compatibility
