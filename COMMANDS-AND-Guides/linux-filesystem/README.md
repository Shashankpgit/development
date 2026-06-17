# Linux Filesystem — Deep Dive Guide

A directory-by-directory exploration of the Linux filesystem with real-world examples. Explains the WHY behind each directory's purpose, what actually lives there, and how it connects to your daily work.

---

## Reading Order

| File | Topic |
|------|-------|
| [00 — What Is the Linux Filesystem?](00-what-is-the-linux-filesystem.md) | Everything-is-a-file philosophy, one-tree model, mounting, FHS overview |
| [01 — /etc — Configuration](01-etc-configuration.md) | hosts, passwd, ssh, nginx, crontab, fstab — every key config file explained |
| [02 — /var — Variable Data](02-var-variable-data.md) | /var/log (nginx, auth, syslog), /var/lib (postgres, docker), /var/cache, /var/www |
| [03 — /home — User Space](03-home-directory.md) | Dotfiles (.bashrc, .gitconfig, .ssh), ~/.local, ~/.config, dotfile management |
| [04 — /bin, /usr, /opt — Programs](04-bin-usr-opt.md) | Where commands live, /usr/bin vs /usr/local/bin vs /opt, library files |
| [05 — /proc and /sys — The Kernel's Window](05-proc-and-sys.md) | Virtual filesystems, process inspection, cpuinfo, meminfo, sysctl |
| [06 — /dev, /tmp, /run — Devices & Special Dirs](06-dev-devices.md) | /dev/null, /dev/zero, /dev/sda, /tmp sticky bit, /run PID files |
| [07 — Real-World Navigation](07-real-world-navigation.md) | "Where is X?" reference for nginx, postgres, docker, ssh, systemd + full cheat sheet |

---

## Quick "Where Is It?" Reference

| What | Location |
|------|----------|
| **Config files** | `/etc/` |
| Nginx config | `/etc/nginx/nginx.conf`, `/etc/nginx/sites-enabled/` |
| PostgreSQL config | `/etc/postgresql/VERSION/main/` |
| SSH server config | `/etc/ssh/sshd_config` |
| SSH client config | `~/.ssh/config` |
| Cron jobs | `crontab -e`, `/etc/cron.d/` |
| Hosts file | `/etc/hosts` |
| DNS config | `/etc/resolv.conf` |
| **Logs** | `/var/log/` |
| Nginx access log | `/var/log/nginx/access.log` |
| Nginx error log | `/var/log/nginx/error.log` |
| Auth/SSH log | `/var/log/auth.log` |
| System log | `/var/log/syslog` or `journalctl` |
| Any service log | `journalctl -u service-name` |
| **Programs** | `/usr/bin/`, `/usr/local/bin/`, `/opt/` |
| apt-installed commands | `/usr/bin/` |
| Manually installed tools | `/usr/local/bin/` |
| Your personal scripts | `~/.local/bin/` |
| **Data & State** | `/var/lib/` |
| PostgreSQL data | `/var/lib/postgresql/` |
| Docker data | `/var/lib/docker/` |
| Web files | `/var/www/html/` |
| **Your files** | `/home/username/` |
| Your shell config | `~/.bashrc` |
| Your git config | `~/.gitconfig` |
| Your SSH keys | `~/.ssh/` |
| **Kernel/System** | `/proc/`, `/sys/` |
| CPU info | `/proc/cpuinfo` |
| Memory info | `/proc/meminfo` |
| Process info | `/proc/PID/` |
| **Temp/Runtime** | `/tmp/`, `/run/` |
| Temp files | `/tmp/` (cleared on reboot) |
| PID files | `/run/nginx.pid`, etc. |
| **Devices** | `/dev/` |
| Discard output | `/dev/null` |
| Hard drives | `/dev/sda`, `/dev/nvme0n1` |
