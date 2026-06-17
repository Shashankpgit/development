# Part 05 — Process Management: ps, top, kill, jobs, systemctl

Every running program is a **process**. Understanding how to see what's running, how to stop things that are misbehaving, and how to run things in the background is essential for working on a server.

---

## What Is a Process?

When you run `nginx` or `node app.js`, the OS creates a **process** — a running instance of a program. Each process gets:

- A unique **PID** (Process ID) — a number like `1423`
- An owner (the user who started it)
- Memory, CPU time, open file handles
- A parent process (every process except PID 1 has a parent)

**PID 1** is special — it's the first process started by the kernel at boot. On modern Linux (Ubuntu 16+), PID 1 is `systemd`, the system manager.

---

## `ps` — Snapshot of Current Processes

### Show processes in the current terminal session:

```bash
ps
```

Output:
```
  PID TTY          TIME CMD
 1823 pts/0    00:00:00 bash
 2041 pts/0    00:00:00 ps
```

Only shows processes attached to your current terminal session. Not very useful on its own.

### Show ALL processes from ALL users — the real command:

```bash
ps aux
```

Output:
```
USER       PID  %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root         1   0.0  0.2 101792  9248 ?        Ss   Jun10   0:03 /sbin/init
root       562   0.0  0.1  28252  4096 ?        Ss   Jun10   0:00 /usr/sbin/sshd
www-data   834   0.1  0.3 155648 12288 ?        S    Jun10   0:14 nginx: worker process
shashank  1823   0.0  0.1  23156  5120 pts/0    Ss   11:00   0:00 bash
node      2103   2.1  5.6 892416 228340 ?       Sl   11:30   1:24 node /app/server.js
```

Reading each column:
- **USER** — who owns the process
- **PID** — process ID (use this to kill/signal the process)
- **%CPU** — CPU usage percentage
- **%MEM** — memory usage percentage
- **VSZ** — virtual memory size (includes memory not yet used)
- **RSS** — actual physical RAM in use (more useful than VSZ)
- **STAT** — process state (S=sleeping, R=running, Z=zombie, D=disk wait)
- **START** — when it started
- **TIME** — total CPU time consumed
- **COMMAND** — the command that started it

### Find a specific process:

```bash
ps aux | grep nginx         # find nginx processes
ps aux | grep node          # find Node.js processes
ps aux | grep -i "java"     # case-insensitive search
```

### Process tree (parent-child relationships):

```bash
ps axjf      # shows tree structure
# or
pstree       # cleaner tree view
pstree -p    # with PIDs shown
```

---

## `top` — Live Process Monitor

```bash
top
```

Shows a continuously updated view of processes, sorted by CPU usage:

```
top - 11:45:23 up 3 days, 14:22,  1 user,  load average: 0.52, 0.48, 0.44
Tasks: 187 total,   1 running, 186 sleeping,   0 stopped,   0 zombie
%Cpu(s):  5.2 us,  1.1 sy,  0.0 ni, 93.3 id,  0.4 wa,  0.0 hi,  0.0 si
MiB Mem :   7949.3 total,   1024.5 free,   4213.8 used,   2711.0 buff/cache
MiB Swap:   2048.0 total,   1987.5 free,     60.5 used.   3123.4 avail Mem

  PID USER      PR  NI    VIRT    RES    SHR S  %CPU  %MEM     TIME+ COMMAND
 2103 node      20   0  871456 223448   8192 R  21.4   2.7   3:41.22 node
  834 www-data  20   0  155648  12288   4096 S   2.1   0.2   0:14.07 nginx
 1823 shashank  20   0   23156   5120   3072 S   0.0   0.1   0:00.12 bash
```

**Reading the header:**
- **load average: 0.52, 0.48, 0.44** — average CPU load over last 1, 5, and 15 minutes. On a 4-core machine, 4.0 = 100% usage. Values above your core count mean the system is overloaded.
- **%Cpu: 93.3 id** — 93.3% idle (good). If idle is low, something is eating CPU.
- **buff/cache** — memory used by OS for caching disk reads (this memory is "available" for processes when needed — don't count it as "used")

**Interactive keys inside top:**
```
q       → quit
k       → kill a process (type the PID)
M       → sort by memory usage
P       → sort by CPU usage (default)
1       → show each CPU core separately
h       → help
```

### `htop` — Better top (install separately):

```bash
sudo apt install htop
htop
```

`htop` has color, mouse support, and a much cleaner interface. Use it when you want to explore what's running interactively.

---

## `kill` — Send Signals to Processes

### The basics:

```bash
kill PID             # send the default SIGTERM (graceful shutdown request)
kill -9 PID          # send SIGKILL (immediate forced termination)
kill -SIGTERM PID    # same as kill PID (graceful)
```

### Getting the PID:

```bash
# Method 1: ps + grep
ps aux | grep nginx
# 834   ... nginx: master process

# Method 2: pgrep (cleaner)
pgrep nginx         # returns just the PID(s)
# 834
# 835

# Method 3: pidof
pidof nginx
```

### Kill by name instead of PID:

```bash
pkill nginx         # kills all processes named nginx
pkill -9 node       # force-kill all node processes
killall nginx       # similar to pkill
```

### Understanding signals:

| Signal | Number | Meaning |
|--------|--------|---------|
| SIGTERM | 15 | "Please stop" — graceful shutdown request, program can clean up |
| SIGKILL | 9 | "Stop NOW" — immediate forced kill, no cleanup possible |
| SIGHUP | 1 | "Reload config" — many daemons use this to reload without restarting |
| SIGINT | 2 | Ctrl+C — interrupt from keyboard |
| SIGSTOP | 19 | Pause the process (like Ctrl+Z) |
| SIGCONT | 18 | Resume a paused process |

**Always try SIGTERM before SIGKILL.** SIGKILL is a last resort because the program can't clean up (close files, save state, release locks).

```bash
kill 1234           # try graceful shutdown first
sleep 5             # wait a few seconds
kill -9 1234        # if still running, force kill
```

---

## Background Processes: `&`, `jobs`, `fg`, `bg`, `nohup`

### Run a command in the background:

```bash
./long-running-script.sh &
# [1] 2345
# [1] = job number, 2345 = PID
# Prompt returns immediately — you can run other commands
```

### See background jobs in this terminal session:

```bash
jobs
# [1]+  Running    ./long-running-script.sh &
# [2]-  Stopped    nano config.txt
```

### Bring a background job to the foreground:

```bash
fg          # bring the most recent background job to foreground
fg %1       # bring job number 1 to foreground
fg %2       # bring job number 2
```

### Send a foreground job to the background:

```bash
# While a command is running, press Ctrl+Z to pause it
# Then:
bg          # resume it in the background
bg %1       # resume job 1 in background
```

### `nohup` — Keep Running After You Disconnect

When you close an SSH connection, all processes started in that session get SIGHUP (hangup signal) and die. `nohup` ("no hangup") makes a process ignore SIGHUP.

```bash
nohup ./deploy.sh &
# Output goes to nohup.out by default

nohup ./server.sh > server.log 2>&1 &
# Redirect both stdout and stderr to server.log
```

**Even if you disconnect via SSH, the process keeps running.**

---

## `systemctl` — Manage System Services

`systemctl` manages **services** (long-running programs managed by systemd) — things like nginx, postgresql, docker, ssh.

### Start, stop, restart a service:

```bash
sudo systemctl start nginx        # start nginx
sudo systemctl stop nginx         # stop nginx
sudo systemctl restart nginx      # stop then start (for major config changes)
sudo systemctl reload nginx       # reload config without full restart (when nginx supports it)
```

### Enable/disable service at boot:

```bash
sudo systemctl enable nginx       # start nginx automatically when system boots
sudo systemctl disable nginx      # don't start at boot
sudo systemctl enable --now nginx # enable AND start right now in one command
```

### Check service status:

```bash
systemctl status nginx
```

Output:
```
● nginx.service - A high performance web server
     Loaded: loaded (/lib/systemd/system/nginx.service; enabled; vendor preset: enabled)
     Active: active (running) since Sat 2026-06-14 09:00:00 IST; 2h 45min ago
       Docs: man:nginx(8)
    Process: 832 ExecStartPre=/usr/sbin/nginx -t (code=exited, status=0/SUCCESS)
   Main PID: 834 (nginx)
     Tasks: 3 (limit: 4915)
     Memory: 12.3M
        CPU: 14.073s
     CGroup: /system.slice/nginx.service
             ├─834 nginx: master process /usr/sbin/nginx -g daemon on; master_process on;
             └─835 nginx: worker process

Jun 14 09:00:01 server nginx[832]: nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
Jun 14 09:00:01 server nginx[834]: nginx: start worker process 835
```

The `Active: active (running)` line is what you're looking for. Also check the logs at the bottom for errors.

### View service logs:

```bash
journalctl -u nginx              # all logs for nginx service
journalctl -u nginx --since today
journalctl -u nginx -n 50        # last 50 lines
journalctl -u nginx -f           # follow in real time (like tail -f)
```

---

## Real-World Scenario: "The Port Is Already In Use"

```bash
node server.js
# Error: listen EADDRINUSE: address already in use :::3000
```

Something else is using port 3000. Find it and kill it:

```bash
# Find what's using port 3000
sudo ss -tlnp | grep :3000
# or
sudo lsof -i :3000
# Output: node 2103 shashank ... (PID 2103)

# Kill it
kill 2103

# Verify it's gone
sudo ss -tlnp | grep :3000   # should show nothing now

# Start your server
node server.js
```

---

## Common Misunderstanding: "`kill -9` is the right way to stop a process"

**The misunderstanding:** "`kill -9` guarantees the process stops, so I should use it by default."

**The reality:** `kill -9` (SIGKILL) bypasses the program's shutdown code entirely. This means:

- A database process killed with -9 might leave its data files in an inconsistent state, requiring a recovery process on next startup
- A web server killed with -9 might leave active connections in a broken state
- An application using file locks might leave the lock behind, preventing future starts

Always try `kill` (SIGTERM) first and give the process 5-10 seconds to shut down gracefully. Use `-9` only if the process doesn't respond to SIGTERM.

```bash
kill 1234          # graceful — wait a few seconds
# if still running:
kill -9 1234       # last resort
```

---

→ Continue to: `06-searching-and-finding.md`
