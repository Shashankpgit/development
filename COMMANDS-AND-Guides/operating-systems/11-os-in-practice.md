# Operating Systems — 11: OS in Practice

> **Last updated:** July 6, 2026
> **Real troubleshooting workflows you'll use on actual production servers. Slow system, disk full, network broken, app crashing.**

---

## The Investigation Mindset

Before touching anything:
1. **Define the symptom** — "API latency > 2s" not "it's slow"
2. **Form a hypothesis** — what resource could cause this?
3. **Test the hypothesis** — one command at a time
4. **Prove causation** — correlation is not enough

The resources that can be bottlenecks: **CPU, Memory, Disk I/O, Network**.

---

## Scenario 1: "The Server Is Slow"

```bash
# 60-second investigation — run these in order:

# 1. How long has this been happening?
uptime
# load average: 3.52, 2.80, 1.45
# Reading: 1min=3.52, 5min=2.80, 15min=1.45
# Load is RISING (3.52 > 1.45). Problem is recent.
# Rule of thumb: load average > number of CPUs = CPU bottleneck

# How many CPUs do you have?
nproc
# 2 CPUs, load average 3.52 = 1.76 per CPU = overloaded

# 2. What's using the CPU?
top
# Look at: us%, sy%, wa%, id%
# us% high → your app is the problem
# sy% high → many syscalls (I/O intensive, lots of small files)
# wa% high → CPU idle, waiting for disk I/O → disk bottleneck
# id% high → CPU is actually fine, problem is elsewhere

# 3. If CPU is the problem: who's using it?
ps aux --sort=-%cpu | head -15
# Find the top CPU consumers

# 4. If I/O wait is high: what's doing disk I/O?
sudo iotop -o
# Shows only processes actively doing I/O
# High disk write by mysql → MySQL is flushing a lot → check slow queries

# 5. Is it memory pressure?
free -h
vmstat 1 5
# si/so columns nonzero → swapping → memory pressure
# If swapping: find the memory hog:
ps aux --sort=-%mem | head -10

# 6. CPU-level detail:
mpstat -P ALL 1
# Shows per-CPU usage — if one CPU is at 100% and others idle:
# → Single-threaded bottleneck (one thread, can't parallelize further)

# 7. Check if there's a runaway process:
ps aux | awk '$3 > 50.0' | sort -k3 -rn
# Processes using >50% CPU
```

---

## Scenario 2: "Disk Is Full"

```bash
# Alert: "No space left on device"

# Step 1: Which filesystem is full?
df -h
# /dev/nvme0n1p1   20G  19.8G  200M  99% /     ← ROOT is 99% full
# /dev/nvme1n1    100G    2G    98G   2% /data  ← /data is fine

# Step 2: Where is the space?
du -sh /* 2>/dev/null | sort -rh | head -10
# 9.8G   /var
# 4.2G   /home
# 3.1G   /opt
# ...

# Step 3: Drill down into /var:
du -sh /var/* 2>/dev/null | sort -rh | head -10
# 8.2G /var/log
# 500M /var/lib

# Step 4: Drill into /var/log:
du -sh /var/log/* 2>/dev/null | sort -rh | head -10
# 7.9G /var/log/nginx
# 200M /var/log/syslog

# Found it: nginx logs are 7.9GB

# Step 5: Check if a process is holding a deleted log file open:
sudo lsof | grep deleted | grep log
# nginx 1234 www-data 1w REG ... /var/log/nginx/access.log (deleted)
# The file was deleted but nginx still has it open → disk space not freed yet

# Fix option A: Rotate the log file, restart nginx to release old fd:
sudo logrotate -f /etc/logrotate.d/nginx
sudo systemctl reload nginx

# Fix option B: Truncate the open file (zero it out without restarting):
sudo truncate -s 0 /proc/1234/fd/1   # fd number from lsof output

# Fix option C: If not deleted yet, just delete old rotated logs:
sudo rm /var/log/nginx/access.log.{2..10}
sudo rm /var/log/nginx/access.log.*.gz

# Step 6: If it's really just the logs — configure logrotate properly:
cat /etc/logrotate.d/nginx
# Add/verify: daily, rotate 7, compress, maxsize 100M
```

---

## Scenario 3: "My Service Won't Start"

```bash
# Service fails to start (or immediately dies after starting)

# Step 1: Status and recent logs:
systemctl status myapp
# Look at the Active line: "failed" and when
# Look at the last few log lines — often the error is right there

# Step 2: Full recent journal:
journalctl -u myapp --since "10 minutes ago"
# Read carefully. Common errors:
# "Permission denied" → wrong user, wrong file permissions
# "Address already in use" → port 8080 is taken by another process
# "No such file or directory" → ExecStart path wrong, or a config file missing
# "Exit code 1" → your app crashed; the actual error is above this line

# Step 3: Run the command manually as the service user:
sudo -u myapp /opt/myapi/venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000
# This shows stdout/stderr directly — easier to debug than journal
# Common findings: missing env var, can't connect to DB, import error

# Step 4: Check dependencies:
systemctl list-dependencies myapp
# If postgresql.service is listed and postgres failed → fix postgres first

# Step 5: Check if port is taken:
ss -tlnp | grep 8000
# If nginx is on 8000 → conflict
sudo lsof -i :8000
```

---

## Scenario 4: "SSH Refuses to Connect"

```bash
# "Connection refused" or "Connection timed out" when SSHing to EC2

# From your laptop:
ssh -v ec2-user@10.0.1.5   # -v = verbose, shows what's happening

# "Connection refused" means:
#   → SSH daemon isn't running on the server
#   → Or it's on a different port

# "Connection timed out" means:
#   → Network is blocking (Security Group, NACL, iptables)
#   → Instance is down

# Step 1: Is the instance running? (AWS Console)
# EC2 → Instances → Check state = "running"

# Step 2: Check Security Group
# Inbound rule for TCP 22 from your IP?

# Step 3: If you can access the instance via AWS Console → get system log
# Actions → Monitor → Get system log
# Look for: "Starting OpenBSD Secure Shell server..."
# If it's there: sshd started, problem is networking
# If missing: sshd failed to start

# Step 4: EC2 Serial Console (if enabled):
# EC2 → Connect → EC2 Serial Console → Connect
# You get a login prompt directly
# sudo systemctl status ssh
# sudo systemctl start ssh

# Step 5: If sshd is running but connection refused:
# Check which port sshd is listening on:
# (from within the instance, via serial console)
ss -tlnp | grep sshd
# LISTEN 0 128 0.0.0.0:22 ...  ← standard

# Step 6: Check sshd_config for any oddities:
cat /etc/ssh/sshd_config | grep -E "^(Port|ListenAddress|PermitRootLogin|PasswordAuthentication)"
```

---

## Scenario 5: "Application Can't Connect to Database"

```bash
# App logs: "connection refused" or "could not connect to server"

# Step 1: Is postgres/mysql running?
systemctl status postgresql
# or
ps aux | grep postgres

# Step 2: Is it listening on the right address?
ss -tlnp | grep 5432
# LISTEN 0 128 127.0.0.1:5432 ... ← listening on localhost only
# If your app is on a different server, it needs 0.0.0.0:5432

# Step 3: Can you connect from the app server?
nc -zv db-server 5432
# "Connection refused" → firewall or postgres not listening
# "Connection timed out" → network/firewall blocking

# Step 4: Check postgres config:
sudo grep listen_addresses /etc/postgresql/*/main/postgresql.conf
# listen_addresses = 'localhost'  ← change to '*' if remote access needed

# Step 5: Check pg_hba.conf (PostgreSQL auth rules):
sudo cat /etc/postgresql/*/main/pg_hba.conf
# Only allows local connections? Add:
# host  mydb  myuser  10.0.1.0/24  md5

# Step 6: Firewall (iptables on the DB server):
sudo iptables -L INPUT -v -n | grep 5432

# Step 7: Security Group (if different EC2 instances):
# DB security group must allow inbound TCP 5432 from App server's security group
```

---

## Scenario 6: High Memory Usage / OOM Kills

```bash
# App is being killed randomly; dmesg shows OOM events

# Step 1: Confirm OOM kills:
sudo dmesg | grep -E "oom_kill|Out of memory"
sudo journalctl -k | grep -i "out of memory"
# Look for: "Kill process 1234 (node) score 842 total-vm:... anon-rss:..."

# Step 2: How much memory does the process use now?
ps -p $(pgrep node) -o pid,rss,vsz,comm
cat /proc/$(pgrep node)/status | grep -E "VmRSS|VmSwap|VmPeak"

# Step 3: Is it growing? (memory leak check)
watch -n 30 'ps -p $(pgrep node) -o rss='
# If RSS grows steadily over 30-60 minutes → memory leak

# Step 4: Is there enough memory?
free -h
# If available < 200MB → too many processes competing

# Step 5: How much swap exists? Is it being used?
swapon --show
vmstat 1 5 | awk '{print $7, $8}'   # si, so columns

# Immediate mitigations:
# - Restart the leaking process (buys time)
# - Add a swap file (if no swap):
sudo dd if=/dev/zero of=/swapfile bs=1G count=4
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
# Add to /etc/fstab for persistence:
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# Long-term fix: find the leak (use memory profiler for your language)
# Or: increase instance size
```

---

## Scenario 7: System Load Is High But CPU Is Idle

```bash
# top shows: %wa (I/O wait) = 70%, %id (idle) = 25%
# load average: 15.0 on a 4-core machine

# High wa means CPU is waiting for I/O. Investigate:

# Step 1: What device is busy?
iostat -xz 1
# Look for: util% near 100% on any device

# Step 2: What processes are doing the I/O?
sudo iotop -o
# Find the top I/O consumers

# Step 3: What are they reading/writing?
sudo strace -p <pid> -e trace=read,write,open -f 2>&1 | head -50
# Shows which files are being accessed

# Step 4: Is it a specific file pattern?
# Lots of small random reads/writes → random I/O (databases, RocksDB, etc.)
# Large sequential writes → log writing, backups
# Lots of reads to same file → file being read repeatedly (caching issue)

# Mitigations:
# - Upgrade EBS from gp2 to gp3 (higher baseline IOPS)
# - Enable EBS I/O optimization on the instance
# - Add more RAM to increase page cache (less disk reads)
# - Move database to io2 EBS for more IOPS
# - Enable application-level caching (Redis, Memcached)
```

---

## Scenario 8: Log Investigation

```bash
# Something went wrong. Where to look:

# System-wide:
sudo journalctl --since "30 minutes ago"
sudo journalctl -p err --since "1 hour ago"   # only errors

# Kernel messages:
sudo dmesg --since "1 hour ago"   # recent dmesg (requires newer util-linux)
sudo dmesg | tail -50

# Auth/login failures:
sudo journalctl -u ssh
sudo grep "Failed password\|Invalid user" /var/log/auth.log   # Ubuntu
sudo grep "Failed password\|Invalid user" /var/log/secure     # Amazon Linux

# Cron job failures:
sudo journalctl | grep CRON
sudo grep CRON /var/log/syslog

# App-specific (check the service log):
journalctl -u nginx --since "1 hour ago"
journalctl -u myapp --since "1 hour ago"

# Traditional log files (some apps write here directly):
ls /var/log/
sudo tail -f /var/log/syslog        # Ubuntu
sudo tail -f /var/log/messages      # Amazon Linux
```

---

## Useful One-Liners

```bash
# Top 10 CPU-consuming processes:
ps aux --sort=-%cpu | head -11

# Top 10 memory-consuming processes:
ps aux --sort=-%mem | head -11

# Top 10 largest files in /var (2+ levels deep):
find /var -type f -printf '%s %p\n' 2>/dev/null | sort -rn | head -10 | awk '{printf "%.1fM %s\n", $1/1048576, $2}'

# Check all listening ports with process names:
sudo ss -tlnp

# What opened a specific port 5 minutes ago:
sudo journalctl --since "5 minutes ago" | grep -i "listen\|port"

# Find recently modified files (last 30 minutes):
find /etc /opt /var/www -newer /tmp -type f 2>/dev/null
# (Create /tmp with touch -d '30 minutes ago' /tmp/ref first)

# See all current network connections by state:
ss -tan | awk 'NR>1 {print $1}' | sort | uniq -c | sort -rn

# Check if there's been any hardware error:
sudo dmesg | grep -iE "error|fail|warn|critical" | tail -20

# List all services and their status:
systemctl list-units --type=service --state=running

# Who is logged in right now:
who
w      # includes what they're doing

# Last logins:
last | head -20

# Find which process is using a specific file:
sudo fuser /var/log/nginx/access.log
sudo lsof /var/log/nginx/access.log
```

---

## The "USE Method" — Systematic Performance Analysis

For any resource, check:
- **U**tilization: how busy is it? (CPU: %us, Disk: %util, Network: bytes/s)
- **S**aturation: is work queued waiting? (CPU: load avg, Disk: await time, RAM: swap)
- **E**rrors: are there errors? (dmesg, /var/log/kern.log, network errors in `ip -s link`)

```bash
# CPU
top                          # U: %us, S: load avg
dmesg | grep -i "cpu\|mce"  # E: CPU errors

# Memory
free -h                       # U: used/total
vmstat 1 | awk '{print $7,$8}' # S: si/so (swap in/out)
dmesg | grep -i "memory\|edac" # E: memory errors

# Disk
iostat -xz 1                  # U: %util, S: await
dmesg | grep -i "ata\|nvme\|scsi\|error" # E: disk errors

# Network
ip -s link show eth0          # U: bytes, S: drops, E: errors
ss -s                         # connection state summary
```

---

## Cheat Sheet: What Command for What Problem

| Symptom | First Command | Follow-up |
|---------|--------------|-----------|
| "Server slow" | `top` | `iostat` if wa% high, `ps --sort=-%cpu` if us% high |
| "Disk full" | `df -h` | `du -sh /* \| sort -rh` |
| "App won't start" | `systemctl status myapp` | `journalctl -u myapp -n 50` |
| "SSH broken" | Check Security Group | `systemctl status ssh` via console |
| "DB connection refused" | `ss -tlnp \| grep 5432` | Check pg_hba.conf |
| "OOM kills" | `dmesg \| grep oom` | `ps --sort=-%mem` |
| "High I/O wait" | `iostat -xz 1` | `iotop -o` |
| "Process hung" | `ps aux \| grep D` | `strace -p <pid>` |
| "Port in use" | `ss -tlnp \| grep :8080` | `sudo lsof -i :8080` |
| "Permission denied" | `ls -la <file>` | `id <user>` |

→ You've completed the Operating Systems guide. Start with `00-mental-model.md` if you want to review, or jump to any specific file when you need it on the job.
