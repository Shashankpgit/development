# Operating Systems — 04: Filesystem and Inodes

> **Last updated:** July 6, 2026
> **Everything is a file. The Linux filesystem hierarchy, how files are actually stored, and why `df` and `du` sometimes disagree.**

---

## The Linux Filesystem Hierarchy

Every Linux system has a single directory tree rooted at `/`. Unlike Windows (`C:\`, `D:\`), Linux has no drive letters. Everything — including mounted disks, virtual filesystems, and network shares — is at some path under `/`.

```
/
├── bin/       → Essential user binaries (ls, cp, bash). Symlink to /usr/bin on modern systems.
├── boot/      → Kernel, bootloader (GRUB), initramfs
├── dev/       → Device files (disks, TTYs, null, urandom)
├── etc/       → System configuration files (nginx.conf, hosts, fstab, passwd)
├── home/      → User home directories (/home/ubuntu, /home/ec2-user)
├── lib/       → Shared libraries (.so files). Symlink to /usr/lib on modern systems.
├── media/     → Auto-mounted removable media (USB drives)
├── mnt/       → Temporary mount points (you mount things here manually)
├── opt/       → Optional third-party software (/opt/datadog-agent, /opt/myapp)
├── proc/      → Virtual filesystem: kernel process info (see 01-kernel-and-userspace.md)
├── root/      → Root user's home directory
├── run/       → Runtime data: PID files, sockets, since last boot (/run/nginx.pid)
├── srv/       → Service data (websites: /srv/www, FTP files: /srv/ftp)
├── sys/       → Virtual filesystem: kernel hardware/subsystem info
├── tmp/       → Temporary files (cleared on boot, or periodically)
├── usr/       → User programs and data
│   ├── bin/   → User command binaries (nginx, python, git)
│   ├── lib/   → Libraries for /usr/bin programs
│   ├── local/ → Manually installed software (/usr/local/bin, /usr/local/lib)
│   └── share/ → Architecture-independent data (man pages, icons)
└── var/       → Variable data that changes at runtime
    ├── log/   → Log files (/var/log/syslog, /var/log/nginx/access.log)
    ├── lib/   → State data (/var/lib/mysql, /var/lib/docker)
    ├── run/   → PID files, sockets (now usually symlink to /run)
    ├── spool/ → Print queues, mail spools
    └── tmp/   → Temp files that survive reboots (unlike /tmp)
```

### Key Directories for DevOps

```bash
/etc/            → All config. Change configs here.
/var/log/        → All logs. Investigate problems here.
/var/lib/        → All application state. Back this up.
/usr/bin/        → Where installed programs live
/usr/local/bin/  → Where manually installed programs live (higher PATH priority)
/opt/            → Third-party software packages
/tmp/            → Scratch space (don't store important data here)
/run/ or /var/run/ → PID files and sockets for running services
```

---

## What Is an Inode?

A file has two parts:
1. **The data** (the actual bytes of content) — stored in data blocks on disk
2. **The metadata** (name, size, permissions, timestamps, owner) — stored in an **inode**

An **inode** (index node) is a data structure on disk that stores everything about a file EXCEPT its name. The name lives in the directory.

```
Directory entry:
  "nginx.conf" → inode 12345

Inode 12345:
  Type:         regular file
  Permissions:  rw-r--r-- (0644)
  Owner:        root (UID 0)
  Group:        root (GID 0)
  Size:         2347 bytes
  Created:      2026-07-01 10:00:00
  Modified:     2026-07-05 14:22:11
  Accessed:     2026-07-06 08:01:00
  Links:        1
  Data blocks:  [block 4521, block 4522]  → the actual file content
```

```bash
# See inode details:
stat /etc/nginx/nginx.conf

# Output:
#   File: /etc/nginx/nginx.conf
#   Size: 2347            Blocks: 8         IO Block: 4096   regular file
# Device: ca01h/51713d    Inode: 1048598     Links: 1
# Access: (0644/-rw-r--r--)  Uid: (    0/    root)   Gid: (    0/    root)
# Access: 2026-07-06 08:01:00.000000000 +0000
# Modify: 2026-07-05 14:22:11.000000000 +0000
# Change: 2026-07-05 14:22:11.000000000 +0000

# See inode number with ls:
ls -i /etc/nginx/nginx.conf
# 1048598 /etc/nginx/nginx.conf
```

### Inodes and "Disk Full" Without Disk Being Full

A filesystem has a fixed number of inodes (set when it was created). Each file uses one inode.

```bash
# Check inode usage:
df -i

# Output:
# Filesystem     Inodes   IUsed   IFree IUse% Mounted on
# /dev/xvda1    1310720   14521 1296199    2% /
# /dev/xvdf1     655360  655356       4  100% /data

# /dev/xvdf1 has 100% inode usage but still has disk space!
# Creating any new file will fail with "No space left on device"
# even though `df -h` shows free disk space.

# This happens when:
# → Many small files (package repositories, image files, mail spools, log files)
# → The directory contains millions of files
```

Fix: delete files in `/data`, or create a new filesystem with more inodes (`mkfs.ext4 -N <large_number>`).

---

## Hard Links vs Symbolic Links

### Hard Link

A hard link is another name (directory entry) pointing to the same inode.

```bash
# Create a hard link:
ln /etc/nginx/nginx.conf /tmp/nginx-backup.conf

# Both names point to the same inode (same data):
ls -i /etc/nginx/nginx.conf /tmp/nginx-backup.conf
# 1048598 /etc/nginx/nginx.conf
# 1048598 /tmp/nginx-backup.conf  ← same inode number!

stat /etc/nginx/nginx.conf | grep Links
# Links: 2   ← inode link count is now 2
```

**Properties:**
- The file data is deleted only when the link count drops to 0
- If you delete `/etc/nginx/nginx.conf`, the data still exists at `/tmp/nginx-backup.conf`
- Hard links cannot cross filesystem boundaries (must be on the same partition)
- Hard links cannot point to directories (only files)

### Symbolic Link (Symlink)

A symlink is a special file that contains a path to another file. It's a pointer.

```bash
# Create a symlink:
ln -s /etc/nginx/nginx.conf /tmp/nginx-symlink.conf

# The symlink has its own inode:
ls -i /etc/nginx/nginx.conf /tmp/nginx-symlink.conf
# 1048598 /etc/nginx/nginx.conf
# 1048601 /tmp/nginx-symlink.conf  ← different inode!

# The symlink contains the path string:
ls -la /tmp/nginx-symlink.conf
# lrwxrwxrwx 1 root root 24 Jul 06 10:00 /tmp/nginx-symlink.conf -> /etc/nginx/nginx.conf

# If the target is deleted, the symlink becomes "dangling" (broken):
rm /etc/nginx/nginx.conf
cat /tmp/nginx-symlink.conf
# cat: /tmp/nginx-symlink.conf: No such file or directory
```

**Properties:**
- Can cross filesystem boundaries
- Can point to directories
- If target is deleted → symlink is broken
- Common use: `/usr/bin/python3 → /usr/bin/python3.11`

```bash
# Find broken symlinks:
find /usr/bin -xtype l  # finds symlinks whose target doesn't exist
```

---

## File Types in Linux

```bash
# The first character in ls -la shows the type:
ls -la /

# d = directory:        drwxr-xr-x  var/
# - = regular file:     -rw-r--r--  /etc/hostname
# l = symbolic link:    lrwxrwxrwx  /bin -> usr/bin
# c = character device: crw-rw-rw-  /dev/null    (read/write byte streams)
# b = block device:     brw-rw----  /dev/sda     (random access, like disks)
# p = named pipe (FIFO): prw-r--r-- /tmp/mypipe
# s = socket:           srwxrwxrwx  /run/nginx.pid
```

```bash
# Check type without ls:
file /dev/sda          # block special (8/0)
file /dev/null         # character special (1/3)
file /bin/bash         # ELF 64-bit LSB pie executable
file /etc/nginx.conf   # ASCII text
```

---

## Filesystem Types

Different types of filesystems for different purposes:

```
ext4:
  The standard Linux filesystem. Journaling prevents corruption on crashes.
  Used for: EC2 root volumes, general-purpose data volumes
  Max file size: 16TB, Max filesystem: 1EB
  
xfs:
  High-performance, good for large files, parallelism.
  Default on Amazon Linux 2023, RHEL.
  Slightly faster than ext4 for large files and databases.
  
tmpfs:
  RAM-backed filesystem. Disappears on reboot.
  /tmp, /run, /dev/shm are usually tmpfs.
  No disk I/O — very fast.
  
proc / sysfs / devtmpfs:
  Virtual filesystems — no disk storage.
  Generated on the fly by the kernel.
  
vfat/FAT32:
  USB drives, /boot/efi partition.
  No Linux permissions, no symlinks.
  
nfs:
  Network File System — mount a remote directory over the network.
  EFS (AWS Elastic File System) uses NFS.
```

```bash
# See what filesystem type a partition uses:
df -T
# Or:
lsblk -f
# Or:
mount | grep -E "type (ext4|xfs|tmpfs)"
```

---

## Mounting

A **mount** makes a filesystem accessible at a directory path.

```bash
# See all currently mounted filesystems:
mount
# Or cleaner:
findmnt

# Mount an EBS volume (after attaching in AWS console):
sudo mkfs.ext4 /dev/xvdf           # format it first (ONLY if new/empty)
sudo mkdir /data
sudo mount /dev/xvdf /data         # mount it
df -h /data                        # verify

# Mount a specific filesystem type:
sudo mount -t xfs /dev/xvdf /data

# Read-only mount:
sudo mount -o ro /dev/xvdf /data

# Unmount:
sudo umount /data
# (must not be in use — no processes have files open there)

# Force unmount if something is using it:
sudo lsof /data                    # see what's using it
sudo fuser -vm /data               # show processes using it
sudo umount -l /data               # lazy unmount (disconnects when not in use)
```

### /etc/fstab — Persistent Mounts

```bash
cat /etc/fstab

# Format: device  mountpoint  fstype  options  dump  pass
# /dev/xvda1   /       xfs     defaults        0  1
# /dev/xvdf    /data   ext4    defaults,nofail 0  2
# UUID=abc123  /data   ext4    defaults,nofail 0  2  ← better to use UUID

# Options:
# defaults    = rw, suid, dev, exec, auto, nouser, async
# nofail      = boot normally even if this mount fails ← IMPORTANT for external disks
# noatime     = don't update access time on read (performance improvement)
# _netdev     = wait for network before mounting (for NFS, EFS)

# Find the UUID of a device:
sudo blkid /dev/xvdf

# Test fstab without rebooting:
sudo mount -a    # mount everything in fstab that isn't already mounted
```

**Always use `nofail` for non-root volumes** on EC2. If the EBS volume is not attached and you don't have `nofail`, the server won't boot.

---

## File Descriptors

Every open file, socket, or pipe has a **file descriptor** (fd) — an integer that the process uses to refer to it.

```
fd 0 = stdin  (keyboard input, or piped input)
fd 1 = stdout (terminal output, or piped output)
fd 2 = stderr (error messages)
fd 3+ = any file/socket opened by the process
```

```bash
# See open file descriptors for a process:
ls -la /proc/$(pgrep nginx | head -1)/fd

# Output:
# lrwx------ 1 www-data www-data 64 Jul 06 /proc/1234/fd/0 -> /dev/null
# l-wx------ 1 www-data www-data 64 Jul 06 /proc/1234/fd/1 -> /var/log/nginx/access.log
# l-wx------ 1 www-data www-data 64 Jul 06 /proc/1234/fd/2 -> /var/log/nginx/error.log
# lrwx------ 1 www-data www-data 64 Jul 06 /proc/1234/fd/4 -> socket:[12345]  ← listening socket
# lrwx------ 1 www-data www-data 64 Jul 06 /proc/1234/fd/5 -> /etc/nginx/nginx.conf

# Count open file descriptors:
ls /proc/$(pgrep nginx | head -1)/fd | wc -l

# System-wide limit on open file descriptors:
cat /proc/sys/fs/file-max

# Per-process limit:
ulimit -n
# Default: 1024 (often too low for high-concurrency servers)

# Increase for the current session:
ulimit -n 65535

# Permanent increase (in /etc/security/limits.conf):
echo "* soft nofile 65535" | sudo tee -a /etc/security/limits.conf
echo "* hard nofile 65535" | sudo tee -a /etc/security/limits.conf

# For systemd services, in the service unit file:
# [Service]
# LimitNOFILE=65535
```

"Too many open files" errors = hit the file descriptor limit. Increase `ulimit -n`.

---

## Finding Files

```bash
# Find files by name:
find /etc -name "*.conf"
find /var/log -name "*.log" -newer /var/log/syslog   # newer than syslog
find /tmp -name "*.tmp" -mtime +7                     # modified more than 7 days ago

# Find by size:
find /var -size +100M          # files larger than 100MB
find /var -size +100M -type f  # only regular files (not directories)

# Find by owner:
find /home -user ubuntu

# Execute a command on results:
find /tmp -name "*.tmp" -mtime +7 -exec rm {} \;     # delete old tmp files
find /var/log -name "*.log" -size +100M -exec ls -lh {} \;

# Faster than find for name searches (uses a database):
sudo updatedb           # update the locate database
locate nginx.conf       # instant results

# Find which package a file belongs to:
dpkg -S /usr/bin/nginx      # Debian/Ubuntu
rpm -qf /usr/bin/nginx      # Amazon Linux/RHEL
```

---

## Disk Usage — Why df and du Disagree

```bash
# df: shows filesystem-level usage (asks the filesystem)
df -h /var/log
# Filesystem     Size  Used Avail Use% Mounted on
# /dev/xvda1      20G  8.0G  12G  40% /

# du: walks the directory tree and sums file sizes
du -sh /var/log
# 7.6G    /var/log

# 8.0G vs 7.6G — why the difference?

# Reason 1: Deleted files still held open
# A process has a log file open. You deleted the log file.
# The inode is gone (no directory entry), but the file descriptor is still open.
# The disk space isn't freed until the process closes the fd.
# df sees the space as used (inode still holds the blocks)
# du doesn't see the file (directory entry is gone)
```

```bash
# Find deleted files still held open (the infamous "disk full but nothing there" problem):
sudo lsof | grep deleted
# Or more specifically:
sudo lsof | grep "(deleted)"

# Output:
# nginx  1234  www-data  1w  REG  202,1  5368709120  12345  /var/log/nginx/access.log (deleted)
# 5368709120 bytes = 5GB log file, process holds it open, it's "deleted" but space not freed

# Fix: restart the process (it will release the fd and OS frees the disk space)
sudo systemctl restart nginx
# Or if you can't restart:
sudo truncate -s 0 /proc/1234/fd/1   # truncate the open file to 0 bytes (risky)
```

---

## The /dev Directory

Device files are the OS's interface to hardware:

```bash
# Block devices (random access — disks):
/dev/sda        → SATA/SCSI disk (older EC2 instances)
/dev/nvme0n1    → NVMe disk (modern EC2, EBS on newer instances)
/dev/xvda       → Xen virtual disk (older EC2)

# Partitions:
/dev/sda1       → first partition of sda
/dev/nvme0n1p1  → first partition of nvme0n1

# Special devices:
/dev/null       → the void (writes disappear, reads return EOF)
/dev/zero       → returns infinite zero bytes (for initializing storage)
/dev/urandom    → cryptographic random number generator
/dev/stdin      → your standard input
/dev/stdout     → your standard output

# Terminals:
/dev/tty        → your current terminal
/dev/pts/0      → first pseudo-terminal (SSH session)
```

```bash
# Practical uses:
# Wipe a disk (fill with zeros):
sudo dd if=/dev/zero of=/dev/sdb bs=4M

# Generate a random key:
dd if=/dev/urandom bs=32 count=1 2>/dev/null | base64

# Discard output:
some-noisy-command > /dev/null 2>&1
```

---

## Extended Attributes and ACLs

Standard permissions (rwx) are sometimes not enough. Linux also supports extended attributes and Access Control Lists.

```bash
# Extended attributes (arbitrary key-value metadata on files):
setfattr -n user.comment -v "Do not delete" /etc/nginx/nginx.conf
getfattr -n user.comment /etc/nginx/nginx.conf

# ACLs (more fine-grained than standard permissions):
# Grant www-data read access to a file owned by root, without changing ownership:
sudo setfacl -m u:www-data:r /etc/ssl/private/cert.key
getfacl /etc/ssl/private/cert.key
# A '+' in ls -la output means the file has ACL entries:
# -rw-r-----+ 1 root root 1234 Jul 06 /etc/ssl/private/cert.key
```

→ Continue to: `05-users-and-permissions.md`
