# Operating Systems — Complete Guide

> **Focus:** Linux. Because Linux runs 90%+ of cloud infrastructure, every AWS EC2 instance, every Docker container, and every Kubernetes node. Understanding the OS deeply makes you a better DevOps engineer — you stop treating servers as black boxes.

---

## Reading Order

| File | Topic | Why It Matters |
|------|-------|----------------|
| `00-mental-model.md` | What an OS is, kernel vs user space | The foundation everything else builds on |
| `01-kernel-and-userspace.md` | How programs talk to hardware | Why processes can't just "read a disk" |
| `02-processes-and-signals.md` | Processes, threads, signals | Debugging hangs, killing processes correctly |
| `03-memory-management.md` | Virtual memory, swap, OOM killer | Why your app dies at 2am |
| `04-filesystem-and-inodes.md` | Everything is a file, FHS, inodes | Why `df` shows space but `du` doesn't agree |
| `05-users-and-permissions.md` | Users, groups, chmod, sudo | Why your app can't read its config file |
| `06-networking-from-os.md` | Interfaces, routing, DNS from the OS | Why `curl` fails even though the URL is right |
| `07-storage-and-disks.md` | Block devices, partitions, mount | How EBS volumes actually appear in Linux |
| `08-package-management.md` | apt, yum/dnf, repositories | Installing and managing software correctly |
| `09-systemd-and-services.md` | Services, timers, logs | Running your app as a service that survives reboots |
| `10-boot-process.md` | BIOS→GRUB→Kernel→systemd | What actually happens when a machine starts |
| `11-os-in-practice.md` | Troubleshooting: slow, full disk, network | The workflows you'll use on broken production servers |

---

## Quick Reference

```bash
# Processes
ps aux                      # all running processes
top / htop                  # live process monitor
kill -15 <pid>              # graceful stop (SIGTERM)
kill -9 <pid>               # force kill (SIGKILL)

# Memory
free -h                     # memory summary
cat /proc/meminfo           # detailed memory info

# Disk
df -h                       # disk space per filesystem
du -sh /var/log/*           # space used by each subdirectory
lsblk                       # block devices and partitions

# Networking
ip addr show                # network interfaces and IPs
ip route show               # routing table
ss -tlnp                    # listening TCP sockets with process names

# Services (systemd)
systemctl status nginx      # check service status
systemctl start/stop/restart nginx
journalctl -u nginx -f      # follow service logs

# Users
whoami                      # current user
id                          # UID, GID, groups
sudo -l                     # what sudo commands you can run

# Files
find /etc -name "*.conf"    # find files by name
ls -la                      # list with permissions
stat filename               # inode details
```

---

## Linux Distributions in AWS

| Distro | AWS AMI | Package Manager | Init System |
|--------|---------|-----------------|-------------|
| Amazon Linux 2023 | Default AWS | dnf (yum-compatible) | systemd |
| Ubuntu 22.04 LTS | Popular choice | apt | systemd |
| Ubuntu 20.04 LTS | Older workloads | apt | systemd |
| RHEL 9 | Enterprise | dnf | systemd |
| Debian 12 | Minimal | apt | systemd |

All of them: Linux kernel, systemd, bash, same core tools.
