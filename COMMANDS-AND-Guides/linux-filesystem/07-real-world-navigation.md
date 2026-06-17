# The Linux Filesystem — Part 07: Real-World "Where Is X?" Reference

This is a practical reference for the questions you'll actually ask: "Where is the config for X?", "Where does X store its logs?", "How do I find where a program is installed?" Use this as a lookup table.

---

## The "Where Is?" Answers for Common Services

### Where Is Nginx?

```
Executable:     /usr/sbin/nginx
Main config:    /etc/nginx/nginx.conf
Site configs:   /etc/nginx/sites-available/   (available, not necessarily active)
Active sites:   /etc/nginx/sites-enabled/      (symlinks to sites-available)
Extra configs:  /etc/nginx/conf.d/
Access logs:    /var/log/nginx/access.log
Error logs:     /var/log/nginx/error.log
PID file:       /run/nginx.pid
Web root:       /var/www/html/                 (default, your app goes here)
```

```bash
# Verify nginx config before reloading:
sudo nginx -t

# Reload config without restart (active connections not interrupted):
sudo nginx -s reload

# Full restart:
sudo systemctl restart nginx
```

---

### Where Is PostgreSQL?

```
Executable:     /usr/bin/psql  (client), /usr/lib/postgresql/14/bin/postgres (server)
Main config:    /etc/postgresql/14/main/postgresql.conf
Auth config:    /etc/postgresql/14/main/pg_hba.conf    ← CRITICAL: who can connect
Logs:           /var/log/postgresql/postgresql-14-main.log
Data directory: /var/lib/postgresql/14/main/           ← never touch directly
Socket:         /var/run/postgresql/.s.PGSQL.5432       ← for local connections
```

```bash
# Connect locally (as postgres user):
sudo -u postgres psql

# Check logs:
sudo tail -50 /var/log/postgresql/postgresql-14-main.log

# The most common issue — pg_hba.conf authentication:
sudo cat /etc/postgresql/14/main/pg_hba.conf | grep -v "^#" | grep -v "^$"
# TYPE   DATABASE  USER  ADDRESS     METHOD
# local  all       all               peer       ← local socket: match OS user
# host   all       all  127.0.0.1/32 scram-sha-256  ← TCP from localhost: password
```

---

### Where Is Docker?

```
Executable:     /usr/bin/docker
Daemon config:  /etc/docker/daemon.json
All data:       /var/lib/docker/
  Images:       /var/lib/docker/image/
  Containers:   /var/lib/docker/containers/
  Volumes:      /var/lib/docker/volumes/
Logs:           journalctl -u docker
Socket:         /var/run/docker.sock    ← unix socket that Docker CLI talks to
```

```bash
# Check daemon status:
systemctl status docker

# The docker socket is the daemon's API endpoint
# Any user in the 'docker' group can use it (equivalent to root access):
ls -la /var/run/docker.sock
# srw-rw---- 1 root docker 0 Jun 14 docker.sock
# Group 'docker' has rw access
```

---

### Where Is SSH?

```
Client config:  ~/.ssh/config          (your shortcuts)
Your keys:      ~/.ssh/id_ed25519      (private — never share)
                ~/.ssh/id_ed25519.pub  (public — share this)
Trusted servers:~/.ssh/known_hosts     (servers you've connected to)
Authorized keys:~/.ssh/authorized_keys (keys that can log in AS YOU)

Server daemon:  /usr/sbin/sshd
Server config:  /etc/ssh/sshd_config
Host keys:      /etc/ssh/ssh_host_*   (server's identity keys)
Auth logs:      /var/log/auth.log
```

```bash
# Who is logged into this server right now?
w
# or
who

# See recent SSH logins:
last | head -20

# See failed login attempts:
grep "Failed password" /var/log/auth.log | tail -20
```

---

### Where Is systemd / Services?

```
System services:    /lib/systemd/system/       (installed by packages)
Custom services:    /etc/systemd/system/       (your own services go here)
User services:      ~/.config/systemd/user/
Service logs:       journalctl -u service-name
Service overrides:  /etc/systemd/system/nginx.service.d/override.conf
```

```bash
# List all services and their status:
systemctl list-units --type=service

# List only failed services:
systemctl list-units --type=service --state=failed

# See what a service unit file looks like:
cat /lib/systemd/system/nginx.service

# Create your own service for an app:
sudo nano /etc/systemd/system/vault-app.service
```

Example service file for your Node.js app:
```ini
[Unit]
Description=Vault App Node.js Server
After=network.target postgresql.service

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/vault-app
ExecStart=/usr/bin/node src/index.js
Restart=always
RestartSec=10
Environment=NODE_ENV=production
Environment=PORT=3000
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now vault-app
journalctl -u vault-app -f   # watch its logs
```

---

### Where Is Your Application?

There is no single standard, but common conventions:

```
/home/ubuntu/myapp/         ← deployed to home dir of deploy user (simplest)
/var/www/myapp/             ← web applications (beside HTML/static sites)
/opt/myapp/                 ← self-contained, commercial-style
/srv/myapp/                 ← sites being served (FTP, web, etc.)
```

The pattern most teams use:

```
/home/ubuntu/vault-app/     ← application code
/etc/vault-app/             ← configuration (passwords, env vars)
/var/log/vault-app/         ← application logs
/var/lib/vault-app/         ← application data (uploads, cache)
```

---

## The "Find Anything" Toolkit

### Find where a command is installed:

```bash
which nginx
# /usr/sbin/nginx

type python3
# python3 is /usr/bin/python3

whereis nginx
# nginx: /usr/sbin/nginx /etc/nginx /usr/share/man/man8/nginx.8.gz
# (shows binary, config dir, and man page)
```

### Find config file for a package:

```bash
dpkg -L nginx | grep "\.conf"
# /etc/nginx/nginx.conf
# /etc/nginx/fastcgi.conf
# ...
```

### Find all files belonging to an installed package:

```bash
dpkg -L nginx
# Lists EVERY file that the nginx package installed
```

### Find what package owns a file:

```bash
dpkg -S /usr/sbin/nginx
# nginx: /usr/sbin/nginx
```

---

## Common Real-World File Locations Cheat Sheet

| What You're Looking For | Where to Find It |
|------------------------|-----------------|
| Application logs | `/var/log/app-name/` or `journalctl -u service` |
| Nginx config | `/etc/nginx/nginx.conf`, `/etc/nginx/sites-enabled/` |
| Nginx logs | `/var/log/nginx/` |
| PostgreSQL config | `/etc/postgresql/VERSION/main/` |
| PostgreSQL data | `/var/lib/postgresql/VERSION/main/` |
| MySQL/MariaDB config | `/etc/mysql/mysql.conf.d/mysqld.cnf` |
| MySQL data | `/var/lib/mysql/` |
| SSH config (server) | `/etc/ssh/sshd_config` |
| SSH config (client) | `~/.ssh/config` |
| SSH authorized keys | `~/.ssh/authorized_keys` |
| System logs | `/var/log/syslog` or `journalctl` |
| Auth logs | `/var/log/auth.log` |
| Cron jobs (user) | `crontab -e` (stored in `/var/spool/cron/crontabs/`) |
| Cron jobs (system) | `/etc/cron.d/`, `/etc/crontab` |
| Environment variables | `/etc/environment` (system), `~/.bashrc` (user) |
| Network interfaces | `/etc/netplan/` (Ubuntu 18+) or `/etc/network/interfaces` |
| Firewall rules | `/etc/ufw/` (UFW), or `iptables -L` |
| Timezone | `/etc/localtime` (symlink), `/etc/timezone` |
| System hostname | `/etc/hostname` |
| DNS servers | `/etc/resolv.conf` |
| Hosts file | `/etc/hosts` |
| Sudo configuration | `/etc/sudoers` (edit with `visudo`) |
| User accounts | `/etc/passwd`, `/etc/shadow` |
| Groups | `/etc/group` |
| Filesystem mount table | `/etc/fstab` |
| Installed packages list | `dpkg -l` |
| Package download cache | `/var/cache/apt/archives/` |
| Docker images/containers | `/var/lib/docker/` |
| Python packages (system) | `/usr/lib/python3/dist-packages/` |
| Python packages (user) | `~/.local/lib/python3.x/site-packages/` |
| npm global packages | `/usr/local/lib/node_modules/` or `~/.npm-global/` |
| Temporary files | `/tmp/` (cleared on reboot) |
| Running process info | `/proc/PID/` |
| CPU/memory info | `/proc/cpuinfo`, `/proc/meminfo` |
| Hardware devices | `/dev/` |
| Sound card | `/dev/snd/` |
| Serial ports | `/dev/ttyS0`, `/dev/ttyUSB0` |

---

## The 5-Minute "I Just SSH'd Into an Unknown Server" Checklist

```bash
# 1. What OS and version?
cat /etc/os-release
lsb_release -a

# 2. What hardware?
uname -r              # kernel version
nproc                 # CPU cores
free -h               # RAM
df -h                 # disk space

# 3. How long has it been running?
uptime

# 4. What services are running?
systemctl list-units --type=service --state=active

# 5. What's listening on network ports?
ss -tlnp

# 6. Who is logged in?
w

# 7. Any recent system changes?
tail -50 /var/log/syslog
journalctl -n 50

# 8. Any cron jobs?
crontab -l
ls /etc/cron.d/
cat /etc/crontab
```

---

## Common Misunderstanding: "Config files are only in /etc"

**The misunderstanding:** "If I want to configure something, I look in /etc."

**The reality:** Configuration lives in two places:

1. **`/etc/`** — system-wide configuration (for all users, requires root to edit)
2. **`~/.config/`** or dotfiles in `~` — per-user configuration (each user's personal settings)

For example, git has BOTH:
- `/etc/gitconfig` — system-wide (rarely used)
- `~/.gitconfig` — your personal settings (what `git config --global` sets)
- `.git/config` in each repo — per-repository settings

When you `git config --global user.name "Shashank"`, it writes to `~/.gitconfig`, NOT `/etc/gitconfig`.

So when something doesn't behave as expected, check both the system config in `/etc/` AND the user config in `~/.` and `~/.config/`.

---

## End of Linux Filesystem Guide

The filesystem is now navigable to you. The key mental maps to remember:

```
/etc    → WHERE things are configured
/var    → WHERE things store data and logs
/home   → WHERE users live
/usr    → WHERE programs are installed
/proc   → HOW to inspect the running kernel and processes
/dev    → HOW hardware appears as files
/tmp    → WHERE temporary scratch space lives
```

Everything else in Linux flows from these seven locations.
