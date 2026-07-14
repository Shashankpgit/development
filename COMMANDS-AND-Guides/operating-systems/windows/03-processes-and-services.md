# Windows — 03: Processes and Services

> **Last updated:** July 7, 2026
> **Task Manager, Windows Services, and managing background processes — the Windows equivalent of systemd.**

---

## Processes on Windows

Every running program is a process. Windows processes have:
- A **PID** (Process ID) — same concept as Linux
- A **parent process** — which process spawned it
- **Handles** — open files, registry keys, network sockets
- **Threads** — units of execution within a process
- **Working Set** — RAM currently in use

---

## Task Manager — The GUI Tool

**Task Manager** is the primary GUI for process management.

```
Open Task Manager:
  Ctrl+Shift+Esc  → Opens directly (fastest)
  Ctrl+Alt+Delete → Opens security screen → Task Manager
  Right-click Taskbar → Task Manager
```

**Tabs:**
- **Processes** — running apps and background processes
- **Performance** — CPU, memory, disk, network real-time graphs
- **App history** — resource usage over time (per app)
- **Startup** — programs that auto-start at login (manage them here)
- **Users** — processes per logged-in user
- **Details** — low-level process list (PID, CPU, memory — like `ps aux`)
- **Services** — Windows services (same as the Services console)

**Common Task Manager actions:**
- Right-click a process → **End Task** = graceful termination
- Right-click a process → **End Process Tree** = kill it and all children
- Right-click a process → **Open file location** = where is this exe?
- Right-click a process → **Go to details** = see PID and detailed info

---

## PowerShell Process Management

```powershell
# List all running processes
Get-Process

# Filter by name
Get-Process -Name "chrome"
Get-Process -Name "node*"     # wildcard

# Sort by CPU (descending)
Get-Process | Sort-Object CPU -Descending | Select-Object -First 10

# Sort by memory
Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 10

# Get process details
Get-Process -Name "node" | Select-Object Id, Name, CPU, WorkingSet64, StartTime

# Find a process by port (which process is using port 3000?)
Get-NetTCPConnection -LocalPort 3000 | ForEach-Object {
    Get-Process -Id $_.OwningProcess
}

# Kill a process
Stop-Process -Name "notepad"         # graceful (SIGTERM equivalent)
Stop-Process -Id 1234
Stop-Process -Name "hung-app" -Force  # force kill (SIGKILL equivalent)

# Kill all instances of a process
Get-Process -Name "chrome" | Stop-Process

# Wait for a process to finish
$proc = Start-Process -FilePath "setup.exe" -PassThru
Wait-Process -Id $proc.Id
Write-Output "Setup finished with exit code: $($proc.ExitCode)"

# Check if a process is running
if (Get-Process -Name "nginx" -ErrorAction SilentlyContinue) {
    Write-Output "nginx is running"
}
```

---

## Windows Services

**Windows Services** are long-running background processes managed by the **Service Control Manager (SCM)**. They're the Windows equivalent of Linux daemons managed by systemd.

Services can:
- Start automatically at boot (before any user logs in)
- Run under a specific user account (LocalSystem, NetworkService, or a custom account)
- Restart automatically if they crash
- Run without a GUI

### Common Built-in Services

```
wuauserv        → Windows Update
Spooler         → Print Spooler
MSSQLSERVER     → SQL Server
W32Time         → Windows Time (NTP)
WinRM           → Windows Remote Management (PowerShell remoting)
ssh-agent       → SSH Agent (if OpenSSH is installed)
sshd            → SSH Server (if enabled)
nginx           → Nginx (if installed as a service)
```

### Managing Services — PowerShell

```powershell
# List all services
Get-Service

# Filter by status
Get-Service | Where-Object { $_.Status -eq "Running" }
Get-Service | Where-Object { $_.Status -eq "Stopped" }
Get-Service | Where-Object { $_.StartType -eq "Automatic" }

# Get a specific service
Get-Service -Name "nginx"
Get-Service -DisplayName "*IIS*"    # wildcard search

# Start / Stop / Restart
Start-Service -Name "nginx"
Stop-Service -Name "nginx"
Restart-Service -Name "nginx"
Suspend-Service -Name "nginx"       # pause (not all services support)
Resume-Service -Name "nginx"

# Change startup type
Set-Service -Name "nginx" -StartupType Automatic  # auto-start at boot
Set-Service -Name "nginx" -StartupType Manual     # start manually only
Set-Service -Name "nginx" -StartupType Disabled   # prevent starting

# Equivalent systemctl commands:
# systemctl start nginx   → Start-Service nginx
# systemctl stop nginx    → Stop-Service nginx
# systemctl enable nginx  → Set-Service nginx -StartupType Automatic
# systemctl disable nginx → Set-Service nginx -StartupType Disabled
# systemctl status nginx  → Get-Service nginx
```

### Managing Services — sc.exe (Command Prompt)

`sc.exe` is the traditional service management tool, available in cmd and PowerShell:

```cmd
:: List services
sc query

:: Get service status
sc query nginx

:: Start / stop
sc start nginx
sc stop nginx

:: Set startup type
sc config nginx start=auto         :: Automatic
sc config nginx start=demand       :: Manual
sc config nginx start=disabled     :: Disabled

:: Create a new service
sc create MyService binPath="C:\MyApp\myapp.exe" start=auto

:: Delete a service
sc delete MyService
```

### Creating a Windows Service from Your App

To run your application as a Windows Service (so it starts at boot, restarts on crash):

**Option 1: NSSM (Non-Sucking Service Manager)**

```powershell
# Install NSSM
winget install NSSM.NSSM
# or
choco install nssm

# Create a service
nssm install MyNodeApp "C:\Program Files\nodejs\node.exe"
nssm set MyNodeApp AppParameters "C:\myapp\server.js"
nssm set MyNodeApp AppDirectory "C:\myapp"
nssm set MyNodeApp AppStdout "C:\logs\myapp.stdout.log"
nssm set MyNodeApp AppStderr "C:\logs\myapp.stderr.log"
nssm set MyNodeApp Start SERVICE_AUTO_START
nssm start MyNodeApp
```

**Option 2: Task Scheduler** (for simpler startup tasks)

```powershell
# Create a scheduled task that runs at startup
$action = New-ScheduledTaskAction -Execute "node.exe" -Argument "C:\myapp\server.js" -WorkingDirectory "C:\myapp"
$trigger = New-ScheduledTaskTrigger -AtStartup
$settings = New-ScheduledTaskSettingsSet -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
Register-ScheduledTask -TaskName "MyNodeApp" -Action $action -Trigger $trigger -Settings $settings -RunLevel Highest -Force
```

---

## Task Scheduler — Scheduled Jobs

Windows Task Scheduler is the equivalent of `cron` on Linux.

```powershell
# List all scheduled tasks
Get-ScheduledTask

# Run a task immediately
Start-ScheduledTask -TaskName "MyBackup"

# Disable a task
Disable-ScheduledTask -TaskName "MyBackup"

# Delete a task
Unregister-ScheduledTask -TaskName "MyBackup" -Confirm:$false

# Create a task that runs daily at 9am
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
  -Argument "-File C:\scripts\backup.ps1"
$trigger = New-ScheduledTaskTrigger -Daily -At 9am
Register-ScheduledTask -TaskName "DailyBackup" -Action $action -Trigger $trigger

# Create a task that runs every 5 minutes
$trigger = New-ScheduledTaskTrigger -RepetitionInterval (New-TimeSpan -Minutes 5) -Once -At (Get-Date)
```

**GUI Task Scheduler:** `taskschd.msc`

---

## Event Viewer — Windows Logs

**Event Viewer** is the Windows log system — equivalent to `journalctl` on Linux.

```powershell
# View recent system errors
Get-EventLog -LogName System -EntryType Error -Newest 20

# View application errors
Get-EventLog -LogName Application -EntryType Error -Newest 20

# Filter by source
Get-EventLog -LogName System -Source "Service Control Manager" -Newest 10

# Get-WinEvent (newer, more powerful)
Get-WinEvent -LogName System -MaxEvents 20

# Filter by event ID
Get-WinEvent -FilterHashtable @{
    LogName = 'System'
    Id      = 7036      # Service started/stopped events
    StartTime = (Get-Date).AddHours(-1)
}

# Search for errors in the last hour
Get-WinEvent -FilterHashtable @{
    LogName   = 'Application'
    Level     = 2         # 2=Error, 3=Warning, 4=Information
    StartTime = (Get-Date).AddHours(-1)
} | Select-Object TimeCreated, Message
```

**GUI Event Viewer:** `eventvwr.msc`

---

## Common Process Troubleshooting

```powershell
# What process is listening on port 8080?
netstat -ano | findstr :8080
# Then look up the PID:
Get-Process -Id PID_FROM_ABOVE

# Or one-liner:
Get-Process -Id (Get-NetTCPConnection -LocalPort 8080).OwningProcess

# What's using all the CPU?
Get-Process | Sort-Object CPU -Descending | Select-Object -First 5 | Format-Table Name, Id, CPU, WorkingSet64

# What's using all the memory?
Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 5

# Find all processes spawned by a specific parent
$parentPid = (Get-Process -Name "node").Id
Get-Process | Where-Object { $_.Parent.Id -eq $parentPid }
```

→ Continue to: `04-security-model.md`
