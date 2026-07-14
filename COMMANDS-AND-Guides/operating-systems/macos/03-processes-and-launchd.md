# macOS — 03: Processes and launchd

> **Last updated:** July 7, 2026
> **How macOS manages processes and services — launchd vs systemd, Activity Monitor, and background jobs.**

---

## Processes on macOS

macOS process management is largely the same as Linux at the POSIX level — you have `ps`, `kill`, `top`, and process signals work the same way.

```bash
# List all running processes
ps aux

# List processes for current user
ps -u $USER

# Find a specific process
ps aux | grep nginx

# Top — interactive process viewer
top
# Press 'q' to quit, 'o' to sort by different columns

# Htop — better version (install via Homebrew)
brew install htop
htop

# Kill a process by PID
kill 12345           # SIGTERM (graceful)
kill -9 12345        # SIGKILL (force — use only if SIGTERM doesn't work)

# Kill by name
killall node         # kills all processes named "node"
pkill -f "server.js" # kills processes matching "server.js" in command
```

---

## Activity Monitor — GUI Process Viewer

**Activity Monitor** is macOS's Task Manager equivalent.

```
Location: Applications → Utilities → Activity Monitor
Shortcut:  Cmd+Space → type "Activity Monitor"
```

Tabs:
- **CPU** — which processes are using CPU, sorted by %
- **Memory** — RAM usage, memory pressure gauge
- **Energy** — battery impact per app (important on laptops)
- **Disk** — read/write per process
- **Network** — bytes sent/received per process

**Useful in Activity Monitor:**
- Force Quit: select a process → click ✕ → Force Quit (same as `kill -9`)
- See all processes: View → All Processes (not just the current user's)
- Memory Pressure: green = healthy, yellow = moderate, red = memory exhausted

---

## launchd — macOS Init System

**launchd** is the init system on macOS — the first process (PID 1) that starts everything else. It replaces systemd (which is Linux-only).

```
macOS:  PID 1 = launchd
Linux:  PID 1 = systemd (or SysV init on older systems)
```

launchd manages:
- System services (daemons) that start at boot
- User services that start at login
- Scheduled jobs (replacement for cron)
- One-time jobs on demand

---

## LaunchDaemons vs LaunchAgents

This is the most important launchd concept:

```
LaunchDaemon   → System-wide service, runs as root, starts at BOOT
                  (regardless of whether any user is logged in)
                  Location: /Library/LaunchDaemons/
                           /System/Library/LaunchDaemons/

LaunchAgent    → User-level service, runs as the logged-in user, starts at LOGIN
                  (only when a user is logged in)
                  Locations:
                    ~/Library/LaunchAgents/          ← your personal agents
                    /Library/LaunchAgents/           ← all users (admin installs)
                    /System/Library/LaunchAgents/    ← Apple's agents
```

**Real examples:**
- `sshd` (SSH server) → LaunchDaemon (runs as root, needs port 22, starts at boot)
- Dropbox → LaunchAgent (your personal app, only when you're logged in)
- `com.apple.Spotlight` → Apple LaunchDaemon

---

## Plist Files — Service Configuration

launchd services are configured in **plist files** (Property List — XML format).

This is the macOS equivalent of a systemd `.service` file.

```xml
<!-- ~/Library/LaunchAgents/com.myapp.server.plist -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Unique identifier for this service -->
    <key>Label</key>
    <string>com.myapp.server</string>

    <!-- Command to run -->
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/node</string>
        <string>/Users/shashank/projects/myapp/server.js</string>
    </array>

    <!-- Start automatically when loaded -->
    <key>RunAtLoad</key>
    <true/>

    <!-- Restart if it crashes -->
    <key>KeepAlive</key>
    <true/>

    <!-- Working directory -->
    <key>WorkingDirectory</key>
    <string>/Users/shashank/projects/myapp</string>

    <!-- Environment variables -->
    <key>EnvironmentVariables</key>
    <dict>
        <key>NODE_ENV</key>
        <string>production</string>
        <key>PORT</key>
        <string>3000</string>
    </dict>

    <!-- Log output -->
    <key>StandardOutPath</key>
    <string>/tmp/myapp.stdout.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/myapp.stderr.log</string>
</dict>
</plist>
```

---

## launchctl — Managing Services

**launchctl** is the command-line tool for managing launchd, equivalent to `systemctl` on Linux.

```bash
# Load (register) a service — reads the plist and starts if RunAtLoad=true
launchctl load ~/Library/LaunchAgents/com.myapp.server.plist

# Load and start immediately (even if RunAtLoad is false)
launchctl load -w ~/Library/LaunchAgents/com.myapp.server.plist

# Unload (deregister) a service — stops it and removes from launchd
launchctl unload ~/Library/LaunchAgents/com.myapp.server.plist

# Start a loaded service manually
launchctl start com.myapp.server

# Stop a running service
launchctl stop com.myapp.server

# List all loaded services and their PIDs/status
launchctl list

# Find a specific service
launchctl list | grep myapp

# See why a service failed (exit code)
launchctl list com.myapp.server
# {
#   "LimitLoadToSessionType" = "Aqua";
#   "Label" = "com.myapp.server";
#   "OnDemand" = false;
#   "LastExitStatus" = 0;     ← 0 means success; non-zero = crashed
#   "PID" = 1234;             ← if running; missing if stopped
# }
```

**systemd vs launchctl comparison:**

| systemd (Linux) | launchctl (macOS) |
|-----------------|------------------|
| `systemctl start nginx` | `launchctl start com.nginx` |
| `systemctl stop nginx` | `launchctl stop com.nginx` |
| `systemctl enable nginx` | `launchctl load -w ...plist` |
| `systemctl disable nginx` | `launchctl unload -w ...plist` |
| `systemctl status nginx` | `launchctl list com.nginx` |
| `journalctl -u nginx -f` | `tail -f /tmp/nginx.stderr.log` |
| `systemctl list-units` | `launchctl list` |

---

## Scheduled Jobs with launchd

launchd replaces `cron` on macOS (though cron still works). Use `StartCalendarInterval` in your plist:

```xml
<!-- Run every day at 9am -->
<key>StartCalendarInterval</key>
<dict>
    <key>Hour</key>
    <integer>9</integer>
    <key>Minute</key>
    <integer>0</integer>
</dict>

<!-- Run every Monday at 10:30am -->
<key>StartCalendarInterval</key>
<dict>
    <key>Weekday</key>
    <integer>1</integer>   <!-- 0=Sunday, 1=Monday -->
    <key>Hour</key>
    <integer>10</integer>
    <key>Minute</key>
    <integer>30</integer>
</dict>

<!-- Run every 5 minutes -->
<key>StartInterval</key>
<integer>300</integer>   <!-- seconds -->
```

Cron still works on macOS if you prefer:
```bash
crontab -e       # edit your crontab
crontab -l       # list current crontab
# same cron syntax as Linux: MIN HOUR DOM MON DOW command
```

---

## Force Quit Apps (macOS-style kill)

```bash
# GUI: Cmd+Option+Esc → opens Force Quit dialog

# Command line:
killall "Google Chrome"    # kill by app name
killall -9 Finder          # force kill Finder (it restarts automatically)

# If an app is completely frozen:
kill -9 $(pgrep "Frozen App")
```

→ Continue to: `04-security-model.md`
