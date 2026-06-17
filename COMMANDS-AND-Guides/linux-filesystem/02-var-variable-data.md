# The Linux Filesystem — Part 02: /var — Variable Data (Logs, Databases, Caches)

If `/etc` is the configuration heart of Linux, `/var` is the operational heart. It contains all data that **changes during normal system operation** — logs, databases, mail queues, package caches, and runtime state.

The name literally means "variable" — as opposed to `/etc` which is relatively static.

---

## The Structure of /var

```bash
ls /var
```

```
backups/     cache/    lib/     lock/    log/     mail/    opt/
run/         spool/    tmp/     www/
```

---

## `/var/log` — The Single Most Important Directory for Debugging

Every log file on a Linux system lives here. When something breaks, you come here.

```bash
ls /var/log
```

```
auth.log         kern.log        nginx/         syslog
apt/             lastlog         postgresql/    ubuntu-advantage.log
dpkg.log         mail.log        samba/         wtmp
faillog          mysql/          secure         Xorg.0.log
```

### The Most Critical Log Files

#### `/var/log/syslog` — The General System Journal

```bash
tail -f /var/log/syslog
# or (modern systemd systems)
journalctl -f
```

Contains messages from the kernel, system daemons, and most services. When something unusual happens and you don't know where to look, start here.

```bash
# Find errors in the last hour:
grep "error\|failed\|denied" /var/log/syslog | grep "$(date '+%b %e')"
```

#### `/var/log/auth.log` — Authentication Events

```bash
cat /var/log/auth.log | grep "Failed password"
```

```
Jun 14 03:22:14 server sshd[1234]: Failed password for invalid user admin from 123.45.67.89 port 52341 ssh2
Jun 14 03:22:16 server sshd[1234]: Failed password for root from 123.45.67.89 port 52342 ssh2
```

This is where you see SSH login attempts, `sudo` usage, and authentication failures.

**Real use — detect brute force attacks:**
```bash
grep "Failed password" /var/log/auth.log | awk '{print $11}' | sort | uniq -c | sort -rn | head -10
# Shows which IPs are attempting the most logins
```

**Real use — see all successful sudo commands:**
```bash
grep "sudo" /var/log/auth.log | grep "COMMAND"
```

#### `/var/log/nginx/` — Web Server Logs

```bash
ls /var/log/nginx/
# access.log  error.log
```

**access.log** — every HTTP request to your server:
```
192.168.1.50 - - [14/Jun/2026:12:30:45 +0530] "GET /api/users HTTP/1.1" 200 1234 "-" "Mozilla/5.0..."
│              │                                  │                        │    │
│              │                                  │                        │    └── response size (bytes)
│              │                                  │                        └── HTTP status code
│              │                                  └── request line (method, URL, protocol)
│              └── timestamp
└── client IP address
```

```bash
# Watch in real-time
tail -f /var/log/nginx/access.log

# Count requests per status code
awk '{print $9}' /var/log/nginx/access.log | sort | uniq -c | sort -rn
# Output:
# 15234  200
#   823  304
#   142  404
#    12  500

# Find all 500 errors
grep " 500 " /var/log/nginx/access.log | tail -50
```

**error.log** — errors nginx encountered:
```bash
tail -f /var/log/nginx/error.log

# Common errors to search for:
grep "connect() failed" /var/log/nginx/error.log   # upstream (your app) is down
grep "permission denied" /var/log/nginx/error.log  # file permission issue
grep "no live upstreams" /var/log/nginx/error.log  # all backend servers are down
```

#### `/var/log/postgresql/` or `/var/log/mysql/` — Database Logs

```bash
# PostgreSQL:
tail -f /var/log/postgresql/postgresql-14-main.log

# MySQL/MariaDB:
tail -f /var/log/mysql/error.log
```

---

## `/var/lib` — Application State and Persistent Data

Programs store their data here — data that needs to survive reboots but isn't configuration (that's `/etc`).

```bash
ls /var/lib
```

```
apt/              dpkg/         nginx/        postgresql/
docker/           mysql/        systemd/      ufw/
```

### `/var/lib/postgresql/` — PostgreSQL Data

The actual database files. Never touch these directly — always use PostgreSQL tools.

```bash
ls /var/lib/postgresql/14/main/
# base/    pg_commit_ts/    pg_hba.conf    pg_wal/
# (the actual database files)
```

### `/var/lib/docker/` — Docker's Storage

All Docker images, containers, volumes, and networks are stored here.

```bash
du -sh /var/lib/docker/
# 45G     /var/lib/docker/
```

If Docker is eating your disk, this is why. Clean it with:
```bash
docker system prune -a   # remove unused images, containers, volumes
```

### `/var/lib/apt/` — APT Package Manager State

```bash
ls /var/lib/apt/
# lists/   (package lists from repositories)
# lock     (prevents concurrent apt operations)
```

If `apt` hangs because of a lock file:
```bash
# Check what holds the lock:
sudo lsof /var/lib/apt/lists/lock
# If nothing is using it (previous apt crashed):
sudo rm /var/lib/apt/lists/lock
sudo rm /var/cache/apt/archives/lock
```

---

## `/var/cache` — Cached Data That Can Be Deleted

Caches speed things up but can be safely deleted to free disk space.

```bash
ls /var/cache
# apt/       fontconfig/    man/        nginx/
```

### `/var/cache/apt/archives/` — Downloaded .deb packages

```bash
du -sh /var/cache/apt/archives/
# 1.2G   /var/cache/apt/archives/

# Clear it safely (packages can be re-downloaded if needed):
sudo apt clean              # delete all downloaded .deb files
sudo apt autoclean          # delete only outdated .deb files
```

---

## `/var/www` — Web Server Files

The default root for web content served by nginx/apache.

```bash
ls /var/www/html/
# index.html  (the default "Welcome to nginx!" page)
```

Your web application files go here:
```bash
ls /var/www/
# html/          ← default nginx web root
# vault-app/     ← your app
# api/           ← your API
```

Ownership should be `www-data` (nginx's user):
```bash
sudo chown -R www-data:www-data /var/www/html/
sudo chmod -R 755 /var/www/html/
```

---

## `/var/run` (symlink to `/run`) — Runtime PID Files

Programs write their **PID files** here — small files containing the process ID of a running daemon. This allows system tools to find and control them.

```bash
ls /var/run/
# nginx.pid      sshd.pid      postgresql.pid    docker.pid
```

```bash
cat /var/run/nginx.pid
# 834
# This means nginx's master process is PID 834

# Verify:
ps aux | grep 834
```

PID files also serve as locks — if the PID file exists, the program is (probably) running. Scripts check for PID files before starting a second instance.

---

## `/var/spool` — Jobs Waiting to Be Processed

The word "spool" comes from printer spooling — jobs lined up waiting to be processed.

```bash
ls /var/spool/
# cron/     mail/    printer/
```

### `/var/spool/cron/crontabs/` — Per-User Crontabs

```bash
sudo ls /var/spool/cron/crontabs/
# shashank    root

# This is the actual crontab for user shashank:
sudo cat /var/spool/cron/crontabs/shashank
```

You edit crontabs using `crontab -e` (not directly editing these files).

---

## Real-World Scenario: "The Server Is Slow — What's Happening?"

```bash
# 1. Check system load
uptime
# load average: 8.5, 7.2, 6.1 ← high on a 4-core server

# 2. What processes are consuming CPU?
top   # or htop

# 3. Check for disk I/O issues
iostat -x 2

# 4. Check if it's a database problem
tail -50 /var/log/postgresql/postgresql-14-main.log | grep "slow query"

# 5. Check nginx for a spike in traffic
awk '{print $4}' /var/log/nginx/access.log | \
  sed 's/\[//' | cut -d: -f2 | \
  sort | uniq -c | sort -rn | head -10
# Shows requests per hour — a sudden spike means traffic surge or attack

# 6. Check for errors
grep "ERROR\|FATAL\|CRITICAL" /var/log/syslog | tail -50
```

---

## Common Misunderstanding: "Log files grow forever and eventually fill the disk"

**The misunderstanding:** "I need to manually delete log files regularly."

**The reality:** Linux has `logrotate` — a system that automatically rotates, compresses, and deletes old log files. It's configured in `/etc/logrotate.conf` and `/etc/logrotate.d/`.

```bash
cat /etc/logrotate.d/nginx
```

```
/var/log/nginx/*.log {
    daily                 ← rotate every day
    missingok             ← don't error if log file is missing
    rotate 52             ← keep 52 rotated files (52 days of daily logs)
    compress              ← compress old logs with gzip
    delaycompress         ← don't compress the most recent rotated file
    notifempty            ← don't rotate if file is empty
    sharedscripts
    postrotate
        nginx -s reopen   ← tell nginx to start writing to new log file
    endscript
}
```

So `/var/log/nginx/access.log` stays manageable, and old logs become `access.log.1`, `access.log.2.gz`, etc.

You only need to manually intervene if logrotate hasn't been running or if a runaway process is generating huge logs faster than logrotate can rotate them.

---

→ Continue to: `03-home-directory.md`
