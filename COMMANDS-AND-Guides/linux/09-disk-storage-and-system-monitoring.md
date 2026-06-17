# Part 09 — Disk, Storage, and System Monitoring: df, du, free, top, journalctl

Running out of disk space or memory on a server can be catastrophic. Knowing how to check these metrics and interpret the output is a daily operational skill.

---

## `df` — Disk Free Space (Filesystem Level)

### When do you use this?

When you want to see how much space is available on each mounted filesystem/disk.

```bash
df -h        # -h = human readable (shows KB, MB, GB instead of blocks)
```

Output:
```
Filesystem      Size  Used Avail Use% Mounted on
/dev/sda1        20G   14G  4.8G  75% /
/dev/sda2       100G   32G   63G  34% /data
tmpfs           3.9G     0  3.9G   0% /dev/shm
/dev/sdb1       500G  180G  295G  37% /mnt/backup
```

Reading each column:
- **Filesystem** — the actual disk partition or special filesystem
- **Size** — total capacity
- **Used** — space currently used
- **Avail** — space available (note: total - used ≠ avail, because Linux reserves ~5% for root)
- **Use%** — percentage used
- **Mounted on** — where in the directory tree this filesystem is attached

**What to watch:** `Use%` above 85–90% is a warning. Above 95% is critical — system instability can occur.

```bash
df -h /                  # show only the root filesystem
df -h /var/log           # show the filesystem containing /var/log
df -i                    # show inode usage (running out of inodes is also a problem)
```

**Inodes:** Every file uses one inode (a metadata slot). Some filesystems can run out of inodes even when disk space is available. `df -i` shows inode usage. If `IUse%` is near 100%, you have too many small files.

---

## `du` — Disk Usage (Directory Level)

`df` shows filesystem-level usage. `du` shows how much space specific directories and files are using — helping you find what's eating your disk.

```bash
du -h /var/log            # human-readable sizes of all files under /var/log
du -sh /var/log           # -s = summary (just the total for the directory)
du -sh *                  # summary for each item in current directory
du -sh /home/*            # how much each user's home dir uses
```

### Find the largest directories — the most useful command:

```bash
du -h --max-depth=1 /var/ | sort -h
```

Output:
```
4.0K    /var/backups
128K    /var/cache
1.2G    /var/lib
8.5G    /var/log
```

This shows the size of each immediate subdirectory. Great for narrowing down what's taking space.

### Find the top 10 largest files/directories anywhere:

```bash
du -ah / 2>/dev/null | sort -rh | head -20
```

### Find large files specifically (combines find + du):

```bash
find / -type f -size +100M 2>/dev/null -exec ls -lh {} \; | sort -k5 -rh
```

---

## `free` — Memory Usage

```bash
free -h         # human-readable memory statistics
```

Output:
```
               total        used        free      shared  buff/cache   available
Mem:            7.8G        3.2G        512M        256M       4.1G        4.1G
Swap:           2.0G        128M        1.9G
```

Understanding each column for RAM:
- **total** — total physical RAM installed
- **used** — RAM actively in use by processes
- **free** — RAM completely unused (usually very small)
- **shared** — RAM used by tmpfs (shared memory)
- **buff/cache** — RAM used by the OS for disk caching (this is GOOD — it speeds up disk reads)
- **available** — RAM available for new applications (free + buff/cache that can be released)

**The important column is `available`, not `free`.** Linux aggressively uses free RAM as disk cache. This is normal and beneficial — the cache is immediately released when an application needs RAM. Looking at `free` and thinking "I only have 512M left!" is wrong — look at `available`.

```bash
free -h -s 2        # update every 2 seconds (like top for memory)
```

---

## `uptime` and System Load

```bash
uptime
# 12:30:01 up 45 days,  3:22,  2 users,  load average: 0.52, 0.48, 0.44
```

- `up 45 days` — system hasn't been rebooted in 45 days
- `load average: 0.52, 0.48, 0.44` — system load over last 1, 5, 15 minutes

**Load average explained:** On a 4-core machine, a load of 4.0 means 100% CPU utilization. Load of 1.0 on a 4-core = 25% usage. Load consistently above your CPU count means processes are waiting for CPU time (overloaded).

```bash
nproc            # how many CPU cores do you have?
# 4
# So a load average > 4 means overloaded
```

---

## `journalctl` — System Logs (systemd)

On modern Ubuntu/Debian, all system and service logs go through `journald` (part of systemd). `journalctl` queries these logs.

```bash
journalctl                        # all logs (huge — use with caution)
journalctl -n 50                  # last 50 log entries
journalctl -f                     # follow (like tail -f) — real time
journalctl --since today          # logs from today
journalctl --since "1 hour ago"
journalctl --since "2026-06-14 09:00" --until "2026-06-14 10:00"
```

### Filter by service:

```bash
journalctl -u nginx               # nginx logs only
journalctl -u nginx -n 100        # last 100 nginx log entries
journalctl -u nginx -f            # follow nginx logs in real time
journalctl -u postgresql -u nginx # logs for multiple services
```

### Filter by priority (severity):

```bash
journalctl -p err                 # errors and above
journalctl -p warning             # warnings and above
journalctl -u nginx -p err        # nginx errors only
```

Priority levels: `emerg`, `alert`, `crit`, `err`, `warning`, `notice`, `info`, `debug`

### Filter by boot:

```bash
journalctl -b                     # logs from current boot only
journalctl -b -1                  # logs from previous boot
journalctl --list-boots           # list all recorded boots
```

---

## `vmstat` — Virtual Memory Statistics (Quick Snapshot)

```bash
vmstat 2 5       # update every 2 seconds, 5 times
```

Output:
```
procs -----------memory---------- ---swap-- -----io---- -system-- ------cpu-----
 r  b   swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa st
 1  0 131072 524288 204800 4194304   0    0     5    12  200  350  5  1 93  1  0
```

Key columns:
- **r** — processes waiting for CPU (if consistently > number of cores, you're overloaded)
- **b** — processes blocked waiting for I/O
- **si/so** — swap in/out (pages per second). Non-zero means heavy swapping = RAM issue
- **us/sy/id/wa** — CPU: user, system, idle, wait. `id` should be high. `wa` high = slow disk
- **bi/bo** — blocks in/out (disk reads/writes per second)

---

## `iostat` — Disk I/O Statistics

```bash
sudo apt install sysstat     # install if not present
iostat -x 2                  # extended stats, update every 2 seconds
```

Key column: `%util` — disk utilization. If consistently near 100%, disk is a bottleneck.

---

## Real-World Scenario: "Disk Is 95% Full — Find What to Delete"

```bash
# Step 1: Confirm the problem
df -h

# Step 2: Find which directory is biggest under /
du -h --max-depth=1 / 2>/dev/null | sort -rh | head -10

# Step 3: Drill down into the problem directory
du -h --max-depth=1 /var | sort -rh | head -10

# Likely culprits:
# /var/log — old log files
# /var/lib/docker — Docker images/containers
# /home/user — someone uploaded large files
# /tmp — accumulated temp files

# Step 4: Clean old logs
sudo journalctl --vacuum-size=500M   # keep only 500MB of journal logs
sudo journalctl --vacuum-time=7d     # keep only 7 days of logs

# Step 5: Find and remove large old log files
find /var/log -name "*.log" -mtime +30 -exec rm {} \;
find /var/log -name "*.gz" -mtime +7 -exec rm {} \;

# Step 6: Clear apt cache
sudo apt clean                       # remove downloaded .deb packages
```

---

## Common Misunderstanding: "Low 'free' memory means the server is running out of RAM"

**The misunderstanding:** "I ran `free -h` and it shows only 200MB free. My server is about to crash!"

**The reality:** Linux deliberately uses all available RAM as disk cache (`buff/cache`). RAM sitting unused is wasted. The `free` column will almost always look low on a healthy, active server.

The metric to actually watch is `available` — RAM that can immediately be given to new processes. On a healthy system:

```
               total   used   free   shared  buff/cache  available
Mem:            8.0G   2.5G   200M    128M       5.2G       5.0G
```

Here, `free = 200MB` looks alarming but `available = 5.0GB` means the system has plenty. The OS will immediately release the `buff/cache` if any application needs that memory.

Actual memory pressure signals:
- `available` approaching zero
- `swap` `si`/`so` (swap in/out) are non-zero and rising
- Processes dying with "Out of Memory" errors in `journalctl`

---

→ Continue to: `10-package-management.md`
