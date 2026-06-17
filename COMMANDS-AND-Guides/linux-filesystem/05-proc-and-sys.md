# The Linux Filesystem — Part 05: /proc and /sys — The Kernel's Window

`/proc` and `/sys` are among the most fascinating and misunderstood parts of Linux. They are **not real directories** — no data is stored on disk. They are virtual filesystems that the kernel generates on-the-fly to expose internal system state as files. Reading a file here reads live data from the kernel's memory.

---

## `/proc` — Running Processes and Kernel Information

`/proc` is generated entirely in RAM. When you `cat /proc/cpuinfo`, the kernel creates that content on the spot — there's no file on disk.

```bash
ls /proc
```

```
1     562    834    1823    2103    ...   (process PIDs)
buddyinfo    cpuinfo    filesystems    interrupts    meminfo
cmdline      devices    loadavg        modules       net/
sys/         uptime     version        vmstat        mounts
```

---

## Process Directories in /proc

Every running process has a directory named after its PID:

```bash
ls /proc/1823/          # info about process 1823 (your bash shell, for example)
```

```
cmdline    environ    fd/    maps    mem    net/    status    wchan
```

### `/proc/PID/cmdline` — The Command That Started the Process

```bash
cat /proc/1823/cmdline | tr '\0' ' '
# bash
# (the null bytes separate arguments — tr converts them to spaces)

# For a Node.js process:
cat /proc/2103/cmdline | tr '\0' ' '
# node /home/shashank/vault-app/src/index.js
```

### `/proc/PID/environ` — Environment Variables

```bash
cat /proc/1823/environ | tr '\0' '\n'
# TERM=xterm-256color
# HOME=/home/shashank
# USER=shashank
# PATH=/usr/local/sbin:/usr/local/bin...
# NODE_ENV=development
```

**Use case:** If a process is misbehaving, check what environment variables it's running with.

### `/proc/PID/fd/` — Open File Descriptors

```bash
ls -la /proc/2103/fd/
# 0 -> /dev/pts/0          (stdin)
# 1 -> /dev/pts/0          (stdout)
# 2 -> /dev/pts/0          (stderr)
# 3 -> socket:[12345]      (network connection)
# 4 -> /var/log/app.log    (log file opened for writing)
```

**Use case:** Find which files a process has open. Great for debugging "file is locked" issues:

```bash
# What files does nginx have open?
ls -la /proc/834/fd/ | grep -v socket
```

### `/proc/PID/status` — Process Status

```bash
cat /proc/1823/status
# Name: bash
# State: S (sleeping)
# Pid: 1823
# PPid: 1820           ← parent process ID
# VmRSS: 5120 kB       ← actual RAM usage (Resident Set Size)
# VmSize: 23156 kB     ← virtual memory size
# Threads: 1
```

---

## Important /proc Files (Not Process-Specific)

### `/proc/cpuinfo` — CPU Information

```bash
cat /proc/cpuinfo
```

```
processor    : 0
vendor_id    : GenuineIntel
cpu family   : 6
model name   : Intel(R) Core(TM) i7-10700K CPU @ 3.80GHz
cpu MHz      : 3800.000
cache size   : 16384 KB
cpu cores    : 8
flags        : fpu vme de pse ... avx512f ...
```

```bash
# How many CPU cores does this machine have?
grep -c "processor" /proc/cpuinfo
# 8

# Or simpler:
nproc
# 8
```

### `/proc/meminfo` — Memory Information

```bash
cat /proc/meminfo
```

```
MemTotal:        8145792 kB     ← total RAM
MemFree:          524288 kB     ← completely unused RAM
MemAvailable:    4194304 kB     ← RAM available for new apps
Buffers:          204800 kB
Cached:          3670016 kB
SwapTotal:       2097152 kB
SwapFree:        2031616 kB
```

This is the same data that `free -h` displays, just in raw form.

### `/proc/loadavg` — System Load Average

```bash
cat /proc/loadavg
# 0.52 0.48 0.44 2/187 2103
#  │    │    │   │  │    └── most recently created PID
#  │    │    │   │  └── total processes
#  │    │    │   └── running/total threads
#  │    │    └── 15 min load average
#  │    └── 5 min load average
#  └── 1 min load average
```

### `/proc/uptime` — How Long the System Has Been Running

```bash
cat /proc/uptime
# 3982320.45  15821234.20
#     │             └── total idle time across all CPUs (seconds)
#     └── seconds since boot

# Human readable:
uptime
# 12:30:01 up 46 days, 3:22, 2 users, load average: 0.52, 0.48, 0.44
```

### `/proc/mounts` — Currently Mounted Filesystems

```bash
cat /proc/mounts
# /dev/sda1 / ext4 rw,relatime,errors=remount-ro 0 0
# tmpfs /dev/shm tmpfs rw,nosuid,nodev 0 0
# /dev/sdb1 /mnt/backup ext4 rw,relatime 0 0
```

Same as `mount` command output.

### `/proc/net/` — Network Statistics

```bash
cat /proc/net/tcp          # active TCP connections (raw format)
cat /proc/net/tcp6         # IPv6 TCP connections
```

This is what `ss` and `netstat` read internally.

---

## `/sys` — Kernel Hardware Configuration

`/sys` (the sysfs filesystem) exposes hardware device information and allows runtime configuration of kernel parameters.

```bash
ls /sys/
# block/    bus/    class/    dev/    devices/    firmware/    fs/    kernel/
```

### `/sys/class/` — Device Classes

```bash
ls /sys/class/
# block/    input/    net/    power/    thermal/    tty/
```

### Network Interface Information

```bash
ls /sys/class/net/
# eth0    lo    wlan0

# Get the MAC address of eth0:
cat /sys/class/net/eth0/address
# 00:1a:2b:3c:4d:5e

# Check if eth0 is up:
cat /sys/class/net/eth0/operstate
# up

# Get interface speed:
cat /sys/class/net/eth0/speed
# 1000    (Mbps)
```

### CPU Temperature and Thermal Sensors

```bash
# Find thermal zones:
for f in /sys/class/thermal/thermal_zone*/temp; do
    echo "$f: $(cat $f)"
done
# /sys/class/thermal/thermal_zone0/temp: 45000
# (divide by 1000 to get Celsius: 45°C)
```

### Disk/Block Device Information

```bash
ls /sys/block/
# sda    sdb    sr0

# Disk size:
cat /sys/block/sda/size
# 419430400    (sectors × 512 bytes = total bytes)

# Disk model:
cat /sys/block/sda/device/model
# Samsung SSD 870 QVO
```

### `/proc/sys/` — Kernel Tunable Parameters

```bash
ls /proc/sys/
# fs/    kernel/    net/    vm/
```

These files can be read AND written — writing to them changes kernel behavior at runtime:

```bash
# Check current IP forwarding setting (important for Docker):
cat /proc/sys/net/ipv4/ip_forward
# 1  (enabled)

# Enable IP forwarding:
echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward

# Check maximum number of open file descriptors:
cat /proc/sys/fs/file-max
# 9223372036854775807
```

**Permanent kernel parameter changes** go in `/etc/sysctl.conf` or `/etc/sysctl.d/`:

```bash
# Make IP forwarding permanent:
echo "net.ipv4.ip_forward=1" | sudo tee /etc/sysctl.d/99-ip-forward.conf
sudo sysctl --system   # reload all sysctl configs
```

---

## Real-World Scenario: "Why Is My Disk I/O So Slow?"

```bash
# 1. Check which process is doing heavy disk I/O
sudo iotop     # like top but for disk I/O (install: sudo apt install iotop)

# 2. How many total I/O operations per second?
cat /proc/diskstats
# 8   0  sda  reads  merged  read_sectors  ...  writes  merged  write_sectors  ...

# 3. What files does the heavy process have open?
# (say the heavy process is PID 2345)
ls -la /proc/2345/fd/  | grep -v "^total"
# Identify which open files are on disk (vs sockets/pipes)
```

---

## Common Misunderstanding: "The files in /proc are real files I should back up"

**The misunderstanding:** "I see thousands of files in /proc — are these part of my system's data? Should I include /proc in backups?"

**The reality:** `/proc` and `/sys` contain NO persistent data whatsoever. They exist only in RAM and are regenerated from scratch at every boot. Their content changes every millisecond as processes start, stop, and use resources.

Backing them up would be:
- Useless (the content is meaningless out of context)
- Potentially harmful (backing up `/proc` could cause the backup tool to hang on certain virtual files)

Backup tools always explicitly exclude `/proc`, `/sys`, `/dev`, and `/run`.

---

→ Continue to: `06-dev-devices.md`
