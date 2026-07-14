# Windows — 01: PowerShell

> **Last updated:** July 7, 2026
> **The modern Windows shell — cmdlets, pipeline, scripting, and essential commands for developers and sysadmins.**

---

## PowerShell vs cmd.exe

Windows has two shells:

```
cmd.exe (Command Prompt)
  → Legacy shell from MS-DOS era
  → Limited scripting, old batch files (.bat, .cmd)
  → Still exists for backward compatibility
  → Use only when specifically required by old scripts

PowerShell
  → Modern shell built on .NET
  → Works with objects (not just text)
  → Full scripting language (variables, functions, loops, classes)
  → Comes with Windows, also available on Linux/macOS (PowerShell Core)
  → Use this for everything
```

**PowerShell versions:**
- **Windows PowerShell 5.1** — built into Windows, Windows-only
- **PowerShell 7+** — cross-platform (Windows/macOS/Linux), install separately, preferred

```powershell
# Check your PowerShell version
$PSVersionTable.PSVersion
# Major Minor Build Revision
# ----- ----- ----- --------
#   7     4     5     0

# Install PowerShell 7 on Windows (via winget)
winget install Microsoft.PowerShell
```

---

## The Core Concept: Cmdlets Work with Objects

This is what makes PowerShell fundamentally different from bash.

**In bash:** Commands output text, and you parse that text.
**In PowerShell:** Commands output .NET objects with properties and methods.

```powershell
# bash approach: parse text
ps aux | grep nginx | awk '{print $2}'   # extract PID as text

# PowerShell approach: work with objects
Get-Process nginx | Select-Object Id     # Id is an integer property

# The difference matters:
Get-Process nginx | Where-Object {$_.CPU -gt 10} | Stop-Process
# This: gets process objects → filters by CPU property → stops them
# Bash equivalent requires text parsing: kill $(ps aux | grep nginx | awk '{$3>10}{print $2}')
```

---

## Verb-Noun Naming Convention

PowerShell cmdlets follow a strict `Verb-Noun` naming pattern:

```
Get-     → retrieve something
Set-     → change/configure something
New-     → create something
Remove-  → delete something
Start-   → start a process/service
Stop-    → stop a process/service
Restart- → restart something
Test-    → test/check something
Invoke-  → run/call something
```

```powershell
# Consistent naming makes PowerShell guessable:
Get-Process          # list processes
Stop-Process         # kill a process
Get-Service          # list services
Start-Service        # start a service
Stop-Service         # stop a service
Get-Item             # get a file/directory object
Remove-Item          # delete file/directory
New-Item             # create file/directory
Get-Content          # read file (like cat)
Set-Content          # write file (like echo > file)
```

---

## Essential Commands — Linux Equivalent

| Linux/macOS | PowerShell | What it does |
|------------|-----------|-------------|
| `ls` | `Get-ChildItem` / `ls` / `dir` | List directory contents |
| `cd` | `Set-Location` / `cd` | Change directory |
| `pwd` | `Get-Location` / `pwd` | Print working directory |
| `cat` | `Get-Content` / `cat` | Read file |
| `echo` | `Write-Output` / `echo` | Print text |
| `cp` | `Copy-Item` / `cp` | Copy file |
| `mv` | `Move-Item` / `mv` | Move/rename file |
| `rm` | `Remove-Item` / `rm` | Delete file |
| `mkdir` | `New-Item -Type Directory` / `mkdir` | Create directory |
| `grep` | `Select-String` | Search in files |
| `find` | `Get-ChildItem -Recurse` | Find files |
| `ps aux` | `Get-Process` | List processes |
| `kill` | `Stop-Process` | Kill process |
| `top` | `Get-Process \| Sort CPU -Desc` | Top processes |
| `env` | `Get-ChildItem Env:` | List env vars |
| `export X=Y` | `$env:X = "Y"` | Set env var |
| `curl` | `Invoke-WebRequest` / `curl` | HTTP requests |
| `wget` | `Invoke-WebRequest` | Download file |
| `which` | `Get-Command` | Find command location |
| `man` | `Get-Help` | Help/documentation |
| `history` | `Get-History` | Command history |
| `clear` | `Clear-Host` / `cls` | Clear terminal |

---

## PowerShell Commands in Practice

```powershell
# ── FILES AND DIRECTORIES ──────────────────────────────────────
ls                              # list current directory
ls C:\Users\Shashank\           # list specific path
ls -Recurse                     # recursive (like find)
ls -Recurse -Filter "*.log"     # find all .log files
ls | Sort-Object LastWriteTime  # sort by date modified

cd C:\Users\Shashank\Documents  # change directory
cd ..                           # go up one level
pwd                             # current path

New-Item -Type File notes.txt   # create empty file
New-Item -Type Directory backup # create directory
mkdir backup                    # shortcut

Copy-Item source.txt dest.txt               # copy file
Copy-Item -Recurse folder\ backup\          # copy folder
Move-Item oldname.txt newname.txt           # rename
Remove-Item file.txt                        # delete file
Remove-Item -Recurse -Force folder\         # delete folder (force)

Get-Content file.txt                        # read file (like cat)
Get-Content file.txt | Select-Object -First 10   # head
Get-Content file.txt | Select-Object -Last  10   # tail
Get-Content C:\logs\app.log -Wait           # tail -f (live follow)

Set-Content output.txt "Hello World"        # write to file (overwrites)
Add-Content output.txt "Another line"       # append to file

# ── SEARCHING ─────────────────────────────────────────────────
Select-String "error" *.log              # grep equivalent
Select-String -Pattern "ERROR|WARN" app.log  # regex
Select-String -Recurse "password" .      # recursive grep

# ── PROCESSES ─────────────────────────────────────────────────
Get-Process                              # list all processes
Get-Process -Name "chrome"               # filter by name
Get-Process | Sort-Object CPU -Descending | Select-Object -First 10

Stop-Process -Name "notepad"             # kill by name
Stop-Process -Id 1234                    # kill by PID
Stop-Process -Name "app" -Force          # force kill

Start-Process notepad.exe                # launch an app
Start-Process notepad.exe -Wait          # wait until it closes

# ── ENVIRONMENT VARIABLES ─────────────────────────────────────
$env:PATH                                # read PATH
$env:USERPROFILE                         # user home
$env:X = "hello"                         # set for current session

# Set permanently (for current user):
[System.Environment]::SetEnvironmentVariable("X", "hello", "User")

# Set system-wide (requires admin):
[System.Environment]::SetEnvironmentVariable("X", "hello", "Machine")

Get-ChildItem Env:                       # list all env vars
Remove-Item Env:X                        # delete env var

# ── NETWORK ───────────────────────────────────────────────────
Test-NetConnection google.com             # ping + port test
Test-NetConnection google.com -Port 443   # test specific port
Resolve-DnsName google.com               # DNS lookup
Get-NetIPAddress                         # list IP addresses
Get-NetRoute                             # routing table
netstat -ano                             # connections (old but works)

# ── WEB REQUESTS ──────────────────────────────────────────────
Invoke-WebRequest https://api.example.com/health
curl https://api.example.com/health       # curl is an alias for IWR

# Download a file
Invoke-WebRequest -Uri "https://example.com/file.zip" -OutFile "file.zip"
# or:
curl -o file.zip https://example.com/file.zip
```

---

## PowerShell Pipeline

The pipeline `|` in PowerShell passes **objects** (not text):

```powershell
# Get top 5 processes by CPU
Get-Process | Sort-Object CPU -Descending | Select-Object -First 5

# Find processes using more than 500MB memory
Get-Process | Where-Object { $_.WorkingSet64 -gt 500MB }

# Kill all processes named "chrome"
Get-Process -Name chrome | Stop-Process

# Find large files over 100MB
Get-ChildItem -Recurse | Where-Object { $_.Length -gt 100MB }

# Export to CSV
Get-Process | Export-Csv processes.csv -NoTypeInformation

# Export to JSON
Get-Process | Select-Object Name, CPU, Id | ConvertTo-Json | Out-File procs.json
```

---

## PowerShell Scripting Basics

```powershell
# Variables
$name = "Shashank"
$number = 42
$array = @(1, 2, 3, 4, 5)
$hash = @{ name="Shashank"; age=30 }

# Strings
"Hello $name"                # double quotes: variables expanded
'Hello $name'                # single quotes: literal (no expansion)
"Path: $($env:USERPROFILE)"  # complex expressions need $()

# Conditionals
if ($number -gt 10) {
    Write-Output "Big number"
} elseif ($number -eq 10) {
    Write-Output "Exactly 10"
} else {
    Write-Output "Small number"
}

# Comparison operators (different from bash!)
-eq   # equal
-ne   # not equal
-gt   # greater than
-lt   # less than
-ge   # greater or equal
-le   # less or equal
-like # wildcard match: "hello" -like "hel*"
-match # regex match: "hello" -match "^h"

# Loops
foreach ($item in $array) {
    Write-Output $item
}

for ($i = 0; $i -lt 5; $i++) {
    Write-Output $i
}

1..10 | ForEach-Object { Write-Output $_ }   # 1 to 10

# Functions
function Say-Hello {
    param (
        [string]$Name = "World",
        [int]$Times = 1
    )
    for ($i = 0; $i -lt $Times; $i++) {
        Write-Output "Hello, $Name!"
    }
}
Say-Hello -Name "Shashank" -Times 3

# Error handling
try {
    Get-Content "nonexistent.txt" -ErrorAction Stop
} catch {
    Write-Error "File not found: $_"
} finally {
    Write-Output "Always runs"
}
```

---

## PowerShell Profile

`$PROFILE` is your PowerShell startup script — like `.bashrc` or `.zshrc`.

```powershell
# See your profile path
$PROFILE
# C:\Users\Shashank\Documents\PowerShell\Microsoft.PowerShell_profile.ps1

# Create it (if it doesn't exist)
New-Item -Path $PROFILE -Force

# Edit it
code $PROFILE    # VS Code
notepad $PROFILE

# Example profile content:
Set-Alias k kubectl
Set-Alias tf terraform
Set-Alias g git

function ll { Get-ChildItem -Force $args }
function which ($command) { Get-Command $command | Select-Object Source }

$env:AWS_DEFAULT_REGION = "ap-south-1"
```

```powershell
# Reload profile without restarting PowerShell
. $PROFILE
```

→ Continue to: `02-filesystem-and-registry.md`
