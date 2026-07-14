# Windows — 00: Mental Model

> **Last updated:** July 7, 2026
> **How Windows works under the hood, how it differs from Linux/macOS, and the key concepts every developer needs to know.**

---

## What Windows Actually Is

Windows is the oldest major OS line still in active use — Windows NT 1.0 was released in 1993. The kernel at the core of modern Windows 10/11 and Windows Server is the **NT kernel**, which has been continuously improved since then.

Unlike Linux and macOS (which are Unix-based), **Windows is NOT Unix**. It was designed with different goals:
- Strong GUI focus from the start
- Enterprise integration (Active Directory, Group Policy)
- Backward compatibility above all else (32-bit apps from 2001 still run on Windows 11)
- COM/DCOM object model for inter-process communication

Despite not being Unix, Windows has gradually added Unix-compatible layers (WSL, PowerShell POSIX cmdlets, OpenSSH) to close the gap for developers.

---

## The NT Kernel Architecture

```
User Mode
  ├── Win32 Subsystem  → Traditional Windows GUI APIs (CreateWindow, etc.)
  ├── .NET CLR         → Managed code runtime (C#, VB.NET)
  ├── WSL              → Linux kernel running inside a lightweight VM
  └── User applications

────────────────────────────────────────────────
Kernel Mode
  ├── NT Kernel (ntoskrnl.exe)
  │     ├── Process/Thread Manager
  │     ├── Memory Manager
  │     ├── I/O Manager
  │     └── Security Reference Monitor
  ├── HAL (Hardware Abstraction Layer)
  └── Device Drivers
```

The key concept: **Ring 0 (kernel mode) and Ring 3 (user mode)** — same as Linux. Apps run in Ring 3, kernel in Ring 0. Unlike Linux which uses a monolithic kernel, Windows NT uses a hybrid kernel (similar concept to macOS's XNU).

---

## Windows vs Linux/macOS — Key Differences

| Concept | Linux | macOS | Windows |
|---------|-------|-------|---------|
| Kernel | Linux | XNU (Darwin) | NT Kernel |
| Default shell | bash | zsh | PowerShell / cmd.exe |
| Package manager | apt / dnf | Homebrew | winget / Chocolatey |
| Init system | systemd | launchd | Windows Service Manager / SCM |
| File separator | `/` (forward slash) | `/` | `\` (backslash) |
| Paths | `/home/user/file` | `/Users/user/file` | `C:\Users\user\file` |
| Config storage | dotfiles, /etc | .plist, /etc | Windows Registry |
| Process list | ps, top | ps, Activity Monitor | Task Manager, Get-Process |
| Root equivalent | root | root | Administrator |
| Privilege escalation | sudo | sudo | UAC (User Account Control) |
| Executable extension | no extension (ELF) | no extension (Mach-O) | .exe, .dll, .bat |
| Line endings | `\n` (LF) | `\n` (LF) | `\r\n` (CRLF) |

---

## The Drive Letter System

Linux and macOS use a single root `/` tree. Windows uses **drive letters** — each storage volume gets its own root:

```
C:\   → Primary drive (usually where Windows is installed)
D:\   → Secondary drive or DVD
E:\   → External drive or partition
Z:\   → Often a network share
```

This is historical — it comes from MS-DOS's floppy drive naming (`A:` and `B:` were floppy drives).

```powershell
# List all drives
Get-PSDrive -PSProvider FileSystem
# Name  Used (GB) Free (GB) Provider Root
# C     87.43     412.57    FileSystem C:\
# D     0         931.51    FileSystem D:\

# Change drive in cmd.exe
C:\> D:
D:\>

# In PowerShell, use Set-Location
Set-Location D:\
cd D:\   # cd is an alias for Set-Location in PowerShell
```

---

## Windows Directory Structure

```
C:\
├── Windows\                → OS files (like /System on macOS, /usr on Linux)
│   ├── System32\           → 64-bit system DLLs and executables
│   ├── SysWOW64\           → 32-bit system DLLs (on 64-bit Windows)
│   └── Temp\               → Temporary files
│
├── Program Files\          → 64-bit installed applications
├── Program Files (x86)\    → 32-bit installed applications
│
├── Users\                  → User home directories (like /home on Linux)
│   └── Shashank\
│       ├── Desktop\
│       ├── Documents\
│       ├── Downloads\
│       ├── AppData\
│       │   ├── Local\      → App data, not synced (like ~/.cache on Linux)
│       │   ├── LocalLow\   → Low-integrity app data (browser sandboxes)
│       │   └── Roaming\    → App data that syncs in domain environments
│       └── .ssh\           → SSH keys (same as ~/.ssh on Linux)
│
└── ProgramData\            → System-wide app data (hidden, like /var on Linux)
```

**Environment variables for paths (use these instead of hardcoded paths):**

```powershell
$env:USERPROFILE     # C:\Users\Shashank  (like $HOME on Linux)
$env:APPDATA         # C:\Users\Shashank\AppData\Roaming
$env:LOCALAPPDATA    # C:\Users\Shashank\AppData\Local
$env:TEMP            # C:\Users\Shashank\AppData\Local\Temp
$env:WINDIR          # C:\Windows
$env:PROGRAMFILES    # C:\Program Files
$env:SYSTEMROOT      # C:\Windows
```

---

## Line Endings — The Developer Gotcha

Windows uses `\r\n` (CRLF — Carriage Return + Line Feed) as line endings.
Linux/macOS use `\n` (LF — Line Feed only).

This causes problems:
- Shell scripts from Windows won't run on Linux (`\r` causes "bad interpreter" errors)
- Git diffs show every line changed when line endings differ

```bash
# Git: configure line ending handling
git config --global core.autocrlf input  # On Linux/macOS: convert CRLF to LF on commit
git config --global core.autocrlf true   # On Windows: convert LF to CRLF on checkout

# Check/fix line endings in a file
file myfile.sh              # "with CRLF line terminators" = bad for Linux
dos2unix myfile.sh          # convert CRLF to LF
unix2dos myfile.sh          # convert LF to CRLF

# In VS Code: click the "LF" or "CRLF" indicator bottom-right to change
```

---

## WSL — Windows Subsystem for Linux

**WSL (Windows Subsystem for Linux)** lets you run a real Linux distribution inside Windows. Introduced in 2016 (WSL1 — translation layer), WSL2 (2019) runs a real Linux kernel in a lightweight VM.

```powershell
# Install WSL2
wsl --install
# Installs Ubuntu by default

# Install a specific distro
wsl --install -d Ubuntu-24.04
wsl --install -d Debian

# List available distros
wsl --list --online

# List installed distros
wsl --list --verbose

# Launch WSL
wsl            # opens default distro
ubuntu         # opens Ubuntu specifically

# Run a command in WSL from PowerShell
wsl ls -la /home/

# Update WSL
wsl --update
```

Inside WSL, you have a full Linux environment. Windows drives are mounted at `/mnt/c/`, `/mnt/d/`, etc.

WSL is the recommended development environment for Windows developers working on Linux-targeting projects.

---

## What's Next

| File | What It Covers |
|------|---------------|
| `01-powershell.md` | PowerShell — the modern Windows shell and scripting language |
| `02-filesystem-and-registry.md` | NTFS, the Windows Registry, file permissions (ACLs) |
| `03-processes-and-services.md` | Task Manager, Windows Services, managing background processes |
| `04-security-model.md` | UAC, Windows Defender, BitLocker, NTFS ACLs, Windows Firewall |
| `05-windows-server.md` | Windows Server roles, IIS, Remote Desktop, PowerShell remoting |
| `06-in-practice.md` | Developer setup (winget, WSL, VS Code), common admin tasks |

→ Continue to: `01-powershell.md`
