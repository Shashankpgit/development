# Windows — 06: Windows in Practice

> **Last updated:** July 7, 2026
> **Developer environment setup, package managers, WSL, and real-world workflows on Windows.**

---

## Setting Up a Fresh Windows Machine for Development

### Step 1: Enable Developer Mode

```
Settings → System → For developers → Developer Mode: ON
```

This enables:
- Creating symbolic links without admin rights
- Sideloading apps
- Improved WSL file access performance

### Step 2: Install winget (Windows Package Manager)

winget comes pre-installed on Windows 11. On Windows 10:

```powershell
# Check if winget is available
winget --version

# If not: install "App Installer" from Microsoft Store
# Or download from: https://github.com/microsoft/winget-cli/releases
```

### Step 3: Install Core Tools

```powershell
# Developer essentials
winget install Git.Git
winget install Microsoft.PowerShell
winget install Microsoft.WindowsTerminal
winget install Microsoft.VisualStudioCode
winget install JetBrains.Toolbox     # if using JetBrains IDEs

# Runtimes
winget install OpenJS.NodeJS.LTS
winget install Python.Python.3.12
winget install Microsoft.DotNet.SDK.8

# Cloud / DevOps
winget install Amazon.AWSCLI
winget install Kubernetes.kubectl
winget install Helm.Helm
winget install Hashicorp.Terraform
winget install Docker.DockerDesktop

# Utilities
winget install jqlang.jq
winget install sharkdp.bat        # better cat
winget install BurntSushi.ripgrep # better grep
winget install junegunn.fzf       # fuzzy finder
winget install Git.GitLFS

# Search for a package
winget search "node"

# Show package info
winget show Git.Git

# List installed packages
winget list

# Upgrade all packages
winget upgrade --all
```

### Step 4: Install WSL2

```powershell
# Install WSL2 with Ubuntu (recommended for dev)
wsl --install
# Restart when prompted, then Ubuntu setup runs automatically

# Or pick a specific distro
wsl --install -d Ubuntu-24.04
wsl --install -d Debian

# Set WSL2 as default (important for performance)
wsl --set-default-version 2
```

### Step 5: Configure Git

```powershell
git config --global user.name "Shashank"
git config --global user.email "shashank@example.com"
git config --global init.defaultBranch main
git config --global core.editor "code --wait"
git config --global pull.rebase false

# Critical for Windows — handle line endings correctly
git config --global core.autocrlf input   # store LF, checkout LF (if working cross-platform)
# or:
git config --global core.autocrlf true    # store LF, checkout CRLF (Windows-only projects)
```

### Step 6: Generate SSH Key

```powershell
# Generate key
ssh-keygen -t ed25519 -C "shashank@example.com"

# Start SSH agent
Get-Service ssh-agent | Set-Service -StartupType Automatic
Start-Service ssh-agent

# Add key
ssh-add $HOME\.ssh\id_ed25519

# Copy public key for GitHub
Get-Content $HOME\.ssh\id_ed25519.pub | clip
# Paste into GitHub → Settings → SSH keys

# Test
ssh -T git@github.com
```

---

## Windows Terminal Configuration

Windows Terminal is the modern multi-tab terminal for Windows. Config file is JSON:

```powershell
# Open settings
# Windows Terminal → Ctrl+, (comma)
# Or manually:
code $HOME\AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json
```

Useful settings snippet:

```json
{
  "defaultProfile": "{574e775e-4f2a-5b96-ac1e-a2962a402336}",
  "profiles": {
    "defaults": {
      "font": { "face": "Cascadia Code PL", "size": 13 },
      "colorScheme": "One Half Dark",
      "opacity": 95,
      "useAcrylic": true
    },
    "list": [
      {
        "name": "PowerShell",
        "commandline": "pwsh.exe",
        "startingDirectory": "%USERPROFILE%"
      },
      {
        "name": "Ubuntu (WSL)",
        "source": "Windows.Terminal.Wsl"
      }
    ]
  },
  "keybindings": [
    { "command": "newTab",         "keys": "ctrl+t" },
    { "command": "closeTab",       "keys": "ctrl+w" },
    { "command": "splitPane",      "keys": "ctrl+shift+d" },
    { "command": "moveFocusPaneUp","keys": "ctrl+alt+up" }
  ]
}
```

---

## Chocolatey — Alternative Package Manager

Chocolatey is an older, community-driven package manager with a larger package repository than winget:

```powershell
# Install Chocolatey (run in elevated PowerShell)
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Install packages
choco install nssm
choco install sysinternals
choco install 7zip
choco install vlc

# Upgrade all
choco upgrade all -y

# List installed
choco list

# Search
choco search nodejs
```

**winget vs Chocolatey:**
```
winget         → Microsoft-maintained, uses official app sources, newer
Chocolatey     → Community-maintained, larger package library, older
Use winget first, fall back to Chocolatey if package not found
```

---

## PowerShell Profile (~/.bashrc equivalent)

```powershell
# Profile location
$PROFILE
# C:\Users\Shashank\Documents\PowerShell\Microsoft.PowerShell_profile.ps1

# Create if missing
New-Item -Path $PROFILE -Force

# Edit
code $PROFILE
```

Practical profile contents:

```powershell
# ~/.config/powershell/Microsoft.PowerShell_profile.ps1

# ── Aliases ──────────────────────────────────────────────────────
Set-Alias k kubectl
Set-Alias tf terraform
Set-Alias g git
Set-Alias cat bat         # install: winget install sharkdp.bat

# ── Functions ────────────────────────────────────────────────────
function ll { Get-ChildItem -Force $args }
function which ($command) { (Get-Command $command).Source }
function mkcd ($path) { New-Item -Type Directory $path; Set-Location $path }

# ── Git shortcuts ────────────────────────────────────────────────
function gs  { git status }
function gp  { git pull }
function gc  { param([string]$msg) git commit -m $msg }
function gco { param([string]$branch) git checkout $branch }

# ── Environment ──────────────────────────────────────────────────
$env:AWS_DEFAULT_REGION = "ap-south-1"

# ── Prompt (git branch + current path) ──────────────────────────
function prompt {
    $branch = git rev-parse --abbrev-ref HEAD 2>$null
    $path = (Get-Location).Path.Replace($HOME, "~")
    if ($branch) {
        "PS $path [$branch] > "
    } else {
        "PS $path > "
    }
}

# Reload profile
function reload { . $PROFILE }
```

---

## WSL2 — Working Across Windows and Linux

```bash
# Inside WSL, access Windows files
ls /mnt/c/Users/Shashank/

# Run a Windows program from WSL
/mnt/c/Windows/system32/notepad.exe
# or just:
notepad.exe /mnt/c/path/to/file.txt

# Run a Linux command from Windows PowerShell
wsl ls -la /home/
wsl grep -r "TODO" /home/user/projects/

# Access WSL files from Windows
# In File Explorer address bar: \\wsl$\Ubuntu\home\user\
# Or: \\wsl.localhost\Ubuntu\home\user\
```

**Recommended workflow for developers on Windows:**
- Store your code in WSL (`~/projects/`) — NOT on `/mnt/c/`
  - Reason: filesystem performance is ~10x better inside WSL than on `/mnt/c/`
- Open VS Code from WSL: `code .` in WSL terminal — VS Code Remote WSL extension handles it
- Use Windows Terminal to launch WSL

---

## Common Troubleshooting

### Port Already in Use

```powershell
# Find what's using port 3000
netstat -ano | findstr :3000
# Then:
Get-Process -Id <PID from above>
# Kill it:
Stop-Process -Id <PID>

# One-liner:
Get-Process -Id (Get-NetTCPConnection -LocalPort 3000 -ErrorAction SilentlyContinue).OwningProcess
```

### PATH Not Updating

```powershell
# After installing something, refresh PATH without restarting terminal:
$env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" +
            [System.Environment]::GetEnvironmentVariable("PATH","User")
```

### PowerShell Script Won't Run (Execution Policy)

```powershell
# Check current policy
Get-ExecutionPolicy

# Allow local scripts + signed remote scripts (recommended for dev)
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser

# Run a single blocked script without changing policy
Unblock-File .\myscript.ps1
.\myscript.ps1
```

### Git Line Ending Problems

```powershell
# Script created on Windows won't run in Linux ("bad interpreter"):
# Fix: convert CRLF to LF
(Get-Content script.sh -Raw) -replace "`r`n","`n" | Set-Content script.sh -NoNewline
# Or in WSL: dos2unix script.sh
```

### Slow File Operations in WSL on /mnt/c

```bash
# BAD — working on Windows drive from WSL is slow:
cd /mnt/c/projects/myapp
npm install   # takes forever

# GOOD — work inside WSL filesystem:
cd ~/projects/myapp
npm install   # much faster
```

---

## Useful System Tools (GUI)

```
msconfig       → Startup programs, boot options
regedit        → Windows Registry
eventvwr.msc   → Event Viewer (logs)
services.msc   → Windows Services
taskmgr        → Task Manager
devmgmt.msc    → Device Manager
diskmgmt.msc   → Disk Management
wf.msc         → Windows Firewall Advanced
gpedit.msc     → Group Policy Editor (Pro/Enterprise)
sysdm.cpl      → System Properties (environment variables, remote)
ncpa.cpl       → Network Connections
control        → Control Panel
```

---

## Sysinternals — Advanced Diagnostic Tools

**Sysinternals** is a free Microsoft toolkit for advanced Windows diagnostics:

```powershell
# Install all Sysinternals tools
winget install Microsoft.Sysinternals

# Or install individual tools:
# Process Explorer (better Task Manager)
winget install Microsoft.Sysinternals.ProcessExplorer

# Process Monitor (see every file/registry/network operation in real time)
winget install Microsoft.Sysinternals.ProcessMonitor

# Autoruns (see everything that starts automatically)
winget install Microsoft.Sysinternals.Autoruns
```

**Key Sysinternals tools:**

```
Process Explorer  → advanced Task Manager, shows DLLs, handles, parent-child tree
Process Monitor   → real-time file/registry/network activity per process
Autoruns          → shows ALL auto-start locations (more thorough than Task Manager)
TCPView           → shows all open connections with process names
Handle            → find which process has a file locked
Strings           → extract readable strings from binaries
PsExec            → run commands on remote machines (like SSH for cmd.exe)
```

→ You've completed the Windows section. Continue to: `../README.md`
