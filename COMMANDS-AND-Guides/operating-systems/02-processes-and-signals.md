# Operating Systems — 02: Processes and Signals

> **Last updated:** July 6, 2026
> **How processes work, how to inspect and control them, and how to communicate with running processes using signals.**

---

## What Is a Process?

A **process** is a running instance of a program. When you start `nginx`, the OS creates a process. If you start `nginx` again, a second independent process exists.

Every process has:
- **PID (Process ID)**: A unique number assigned by the kernel. Ranges 1–32768 on most systems.
- **PPID (Parent PID)**: The PID of the process that created it.
- **UID/GID**: Which user/group the process runs as.
- **State**: What the process is currently doing.
- **Memory**: Its virtual address space.
- **File descriptors**: Open files/sockets/pipes.
- **Environment variables**: Key=value pairs inherited from the parent.

```bash
# See your own process info:
echo "My PID: $$"          # $$ is a bash special variable = current PID
echo "My parent: $PPID"    # parent (the shell that launched this shell)
```

---

## Process States

A process isn't always "running." The kernel moves it between states:

```
R — Running or Runnable
    The process is on the CPU right now, OR it's ready to run
    and waiting for a CPU core to be available.

S — Sleeping (Interruptible)
    Waiting for something: a file read, network data, a timer.
    Most processes are in this state most of the time.
    Can be woken up by signals.

D — Sleeping (Uninterruptible)
    Waiting for I/O (usually disk).
    Cannot be woken up — not even by SIGKILL.
    High D-state processes = disk I/O bottleneck.

T — Stopped
    Paused. Either by SIGSTOP or by a debugger.
    Not dead, not running.

Z — Zombie
    The process has exited, but its parent hasn't called wait() yet.
    The process is "dead" but its PID entry still exists in the kernel.
    Harmless if brief. Many persistent zombies = parent process bug.
```

```bash
# See process states in ps output (the S column):
ps aux

# Look at the state specifically:
ps -eo pid,stat,comm | head -20
```

### High D-state is a problem

```bash
# Find processes in uninterruptible sleep (D state):
ps aux | awk '$8 == "D"'

# If you have many D-state processes:
# → Disk is overwhelmed (too many I/O requests)
# → NFS mount is hung (network filesystem not responding)
# → EBS volume is experiencing high latency
# These processes cannot be killed — fix the underlying I/O issue
```

---

## Viewing Processes

### `ps` — Process Snapshot

```bash
# All processes, BSD-style format (most common):
ps aux

# Output columns:
# USER     PID  %CPU %MEM    VSZ   RSS TTY   STAT  START   TIME COMMAND
# root       1   0.0  0.1 168396 11400 ?     Ss    Jul04   0:01 /sbin/init
# www-data 1234  0.2  0.5 123456 45000 ?     S     10:00   0:30 nginx: worker

# Columns:
# PID   = process ID
# %CPU  = CPU usage (current)
# %MEM  = RAM usage (% of total RAM)
# VSZ   = virtual memory size (all mapped memory, including not-yet-used)
# RSS   = resident set size (actual physical RAM currently used) ← use this
# STAT  = process state
# TIME  = total CPU time consumed (not wall clock time)

# Find a specific process:
ps aux | grep nginx
pgrep -a nginx    # cleaner: shows PID + full command

# Show process tree (who spawned what):
ps auxf           # forest view
pstree            # tree diagram
pstree -p         # with PIDs
```

### `top` — Live Monitor

```bash
top

# Inside top, press:
# q          → quit
# k          → kill a process (prompts for PID then signal)
# r          → renice (change priority)
# 1          → show per-CPU stats (useful for multi-core)
# M          → sort by memory
# P          → sort by CPU (default)
# f          → add/remove columns
# u <name>   → filter by username
```

Reading the top header:
```
top - 10:35:42 up 5 days,  2:11,  2 users,  load average: 0.15, 0.20, 0.18
Tasks: 192 total,   1 running, 191 sleeping,   0 stopped,   0 zombie
%Cpu(s):  2.3 us,  0.5 sy,  0.0 ni, 96.8 id,  0.3 wa,  0.0 hi,  0.1 si
MiB Mem :  15942.3 total,   8231.5 free,   5102.8 used,   2608.0 buff/cache
MiB Swap:   2048.0 total,   2048.0 free,      0.0 used.  10219.1 avail Mem

us = user space CPU %       ← your apps
sy = kernel/system CPU %    ← kernel work
wa = I/O wait CPU %         ← CPU idle, waiting for disk/network
id = idle CPU %             ← doing nothing
```

`wa` (I/O wait) being high (>10%) means disk is a bottleneck — processes are waiting for I/O.

### `htop` — Better top (install it)

```bash
sudo apt install htop    # Ubuntu
sudo dnf install htop    # Amazon Linux

htop
# Color-coded, mouse-clickable, much more readable
```

---

## Process Tree — PID 1 Is the Parent of Everything

```
PID 1: systemd (the init system — first process, started by kernel)
  └── sshd (SSH daemon, started by systemd)
        └── bash (your login shell, started by sshd)
              └── top (started by bash — the command you ran)
```

```bash
# See the full tree starting from PID 1:
pstree -p 1

# Or use systemd:
systemd-cgls   # shows the control group hierarchy (systemd's way of organizing processes)
```

When a parent process dies without waiting for its children, the children become **orphans**. The kernel automatically reparents orphans to PID 1 (systemd). Systemd then waits for them.

---

## Signals — Communicating with Running Processes

A **signal** is a notification sent to a process. The kernel delivers it, and the process's signal handler runs.

### The Most Important Signals

```
SIGTERM (15) — "Please stop gracefully"
  The polite request to shut down.
  Process receives it and CAN handle it:
    → Close connections, flush buffers, clean up temp files, then exit
  Default action if not handled: terminate
  Use this first — always.

SIGKILL (9) — "Stop immediately, no exceptions"
  Sent directly by the kernel. Process CANNOT handle, block, or ignore it.
  Kernel tears down the process immediately.
  No cleanup. Open files might be in inconsistent state.
  Use only when SIGTERM failed.

SIGHUP (1) — "Reload configuration"
  Original meaning: "terminal disconnected"
  Convention: Many daemons (nginx, sshd, rsyslog) use SIGHUP as
  "reload your config file without restarting"
  
SIGINT (2) — "Interrupt" (Ctrl+C in the terminal)
  Sent when you press Ctrl+C.
  Most programs treat it like SIGTERM — clean shutdown.
  
SIGSTOP (19) — "Pause"
  Suspends the process. Cannot be caught or ignored.
  Process is frozen — no CPU, no I/O.
  
SIGCONT (18) — "Continue"
  Resumes a stopped process.
  Ctrl+Z sends SIGSTOP, fg/bg sends SIGCONT.

SIGCHLD (17) — "A child process changed state"
  Sent to a parent when a child exits, stops, or resumes.
  Parent handles this to call wait() and reap the zombie.

SIGUSR1/SIGUSR2 (10/12) — "Application-defined"
  No standard meaning. Apps use them for custom purposes.
  Example: nginx uses SIGUSR1 to reopen log files.
```

### Sending Signals

```bash
# By PID:
kill 1234             # sends SIGTERM (default)
kill -15 1234         # explicit SIGTERM
kill -9 1234          # SIGKILL
kill -HUP 1234        # SIGHUP (by name)
kill -s SIGTERM 1234  # also SIGTERM

# By process name (kills all matching):
killall nginx          # SIGTERM to all nginx processes
killall -9 nginx       # SIGKILL to all nginx processes

# Smarter: pkill (supports patterns, -u user filter, etc.):
pkill nginx            # SIGTERM
pkill -9 nginx         # SIGKILL
pkill -u www-data      # kill all processes by user www-data
pkill -HUP nginx       # reload nginx config

# Send SIGSTOP/SIGCONT interactively:
Ctrl+Z                 # suspend current foreground process (SIGSTOP)
fg                     # resume in foreground (SIGCONT)
bg                     # resume in background

# Confirm a process is gone:
kill -0 1234           # exits 0 if PID exists, 1 if not (sends no actual signal)
```

### The Right Way to Stop a Process

```bash
# Step 1: Try SIGTERM first (graceful shutdown)
kill 1234

# Step 2: Wait a few seconds
sleep 5

# Step 3: Check if it's still alive
kill -0 1234 && echo "still alive"

# Step 4: Only if still alive → SIGKILL
kill -9 1234
```

Scripted version:
```bash
stop_process() {
  local pid=$1
  kill -TERM "$pid"
  for i in $(seq 1 10); do
    kill -0 "$pid" 2>/dev/null || return 0  # gone, success
    sleep 1
  done
  kill -KILL "$pid"   # last resort
}
```

---

## Process Priority — nice and renice

The CPU scheduler decides which runnable process gets to run next. **Priority** (also called niceness) influences this.

```
Nice value range: -20 to +19
  -20 = highest priority (CPU hog)
    0 = default (all processes start here)
  +19 = lowest priority (background tasks, be nice to others)
```

```bash
# Start a process with lower priority (won't compete with important services):
nice -n 10 my-batch-job.sh

# Change priority of a running process:
renice +15 1234          # lower priority of PID 1234
renice -5 1234           # raise priority (requires root)

# See priorities in top:
# PR = scheduling priority (kernel's internal value)
# NI = nice value (what you set)

# Run a CPU-intensive task in the background without starving other processes:
nice -n 19 gzip -r /big/directory &
```

---

## Threads vs Processes

A **thread** is like a process but shares memory with its siblings.

```
Process: independent memory space, independent file descriptors
Thread:  shared memory with sibling threads, but separate CPU register state

Process A (memory space A):
  Thread 1 (handles request 1)
  Thread 2 (handles request 2)
  Thread 3 (handles request 3)

All three threads can read/write the same variables — fast communication.
But a crash in one thread can corrupt the shared memory and kill all threads.
```

In Linux, threads are created with `clone()` (a variant of `fork()`). They appear as separate entries in `/proc` and in `ps`.

```bash
# See threads of a process:
ps -eLf | grep nginx
# -L shows threads; each thread has its own LWP (Light Weight Process) number

# Or:
ps -p 1234 -L
```

Most modern web servers use multiple threads or processes:
- **nginx**: multi-process (one master + N worker processes = one per CPU core)
- **Apache**: can use threads or processes
- **Node.js**: single-threaded event loop (but can spawn worker threads)

---

## The /proc View of a Process

```bash
# Pick a running nginx worker PID:
nginx_pid=$(pgrep nginx | tail -1)

# Everything about this process:
ls /proc/$nginx_pid/

# The exact command that started it:
cat /proc/$nginx_pid/cmdline | tr '\0' ' '

# Open file descriptors (files, sockets, pipes it has open):
ls -la /proc/$nginx_pid/fd

# Memory map:
cat /proc/$nginx_pid/maps

# CPU and memory stats:
cat /proc/$nginx_pid/status

# Environment variables:
strings /proc/$nginx_pid/environ

# If it's stuck: what syscall is it blocked on?
cat /proc/$nginx_pid/wchan     # shows the kernel function it's sleeping in
# "poll_schedule_timeout" → waiting for network I/O (normal for nginx)
# "wait_for_completion"   → waiting for disk I/O
```

---

## Zombie Processes

A zombie is a process that has exited but whose parent hasn't called `wait()` to collect its exit status. The process is dead (uses no CPU, no memory) but still holds a PID.

```bash
# Find zombies (state = Z in ps):
ps aux | awk '$8 ~ /Z/'

# Or look for <defunct> in the name:
ps aux | grep defunct
```

**How to deal with them:**
- Find the parent: `ps -o ppid= -p <zombie_pid>` → get the PPID
- Send SIGCHLD to the parent: `kill -CHLD <parent_pid>` → this may trigger the parent to call `wait()`
- Or wait — if the parent is well-written, it will eventually collect the zombie
- If the parent is dead: zombie goes away when the parent dies
- If the parent is a bug: restart the parent process

A few zombies are fine. Hundreds = there's a parent process not collecting its children = a code bug.

---

## Background Jobs in bash

```bash
# Run in background (detached from terminal):
nginx &                  # runs nginx in background, shows PID
jobs                     # show background jobs in this shell session

# If the shell exits, background processes receive SIGHUP and die.
# To prevent this:
nohup nginx &            # nohup makes it ignore SIGHUP
# Or:
disown %1               # remove from shell's job list (won't get SIGHUP)

# Better: use systemd to manage long-running services (see 09-systemd-and-services.md)
```

---

## Process Groups and Sessions

Processes are organized into:
- **Process group**: A set of related processes (e.g., all processes in a pipeline `cmd1 | cmd2 | cmd3`)
- **Session**: A set of process groups (e.g., everything in one terminal window)

```bash
# Send a signal to an entire process group (negative PID = process group):
kill -TERM -1234    # kills all processes in group 1234

# This is how Ctrl+C works: sends SIGINT to the entire foreground process group
# If you have: cat /dev/urandom | grep "xyz"
# Ctrl+C kills BOTH cat and grep (they're in the same foreground process group)
```

→ Continue to: `03-memory-management.md`
