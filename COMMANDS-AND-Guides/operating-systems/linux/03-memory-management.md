# Operating Systems — 03: Memory Management

> **Last updated:** July 6, 2026
> **How the OS manages RAM, what virtual memory really is, and why the OOM killer terminates your app at 2am.**

---

## The Basic Problem

Your EC2 instance has 8GB of RAM. You're running:
- nginx workers: 4 × 50MB = 200MB
- Node.js app: 1GB
- MySQL: 2GB
- OS and system daemons: ~500MB

Total: ~3.7GB used, 4.3GB free. Fine.

Now your app has a memory leak. Over 6 hours, Node.js grows to 7GB. Total: 9.7GB — more than you have.

What happens? This file explains that.

---

## Virtual Memory

Every process gets its own **virtual address space** — the range of memory addresses it can use. On 64-bit Linux, this is theoretically 128TB.

```
The lie:    "You have 128TB of address space"
The truth:  You have 8GB of physical RAM

How it works:
  Virtual address space is divided into 4KB chunks called "pages"
  Physical RAM is divided into 4KB chunks called "frames"
  
  The kernel maintains a "page table" for each process:
    Virtual page 0x1000 → Physical frame 0x3A2000
    Virtual page 0x2000 → Physical frame 0x7F1000
    Virtual page 0x3000 → NOT IN PHYSICAL RAM (on disk, or not yet allocated)

  When your process accesses address 0x3000:
    CPU checks page table: "this page is NOT in RAM"
    CPU raises a "page fault"
    Kernel handles it: loads the page from disk into a free frame
    Updates page table: virtual page 0x3000 → physical frame 0x1B4000
    CPU retries the instruction
```

This is why a process can use more virtual memory than physical RAM — pages that aren't actively used can be on disk (in the swap space).

---

## Reading Memory Usage

```bash
# Overall memory picture:
free -h

# Output:
#               total        used        free      shared  buff/cache   available
# Mem:           15Gi        4.2Gi       8.1Gi       312Mi       2.7Gi      10.8Gi
# Swap:         2.0Gi          0B       2.0Gi

# Columns explained:
# total     = physical RAM
# used      = RAM in use (by apps + kernel)
# free      = RAM not used by anything
# shared    = RAM used by tmpfs (shared memory)
# buff/cache = RAM used by kernel for disk buffer/cache — THIS IS RECOVERABLE
# available  = free + buff/cache that can be reclaimed ← USE THIS NUMBER
```

**The key insight:** `buff/cache` is NOT wasted memory. The kernel caches disk reads in RAM so future reads are faster. If your app needs more RAM, the kernel will evict the cache. The `available` column is what matters — it's the RAM you can actually use right now.

```bash
# Don't panic when you see this:
# Mem: 16Gi total, 15.8Gi used, 0.2Gi free, 12Gi buff/cache, 12.2Gi available
# → 12GB is cache. You have 12GB+ available. System is fine.
```

```bash
# Detailed breakdown:
cat /proc/meminfo

# Key fields:
# MemTotal:     Total physical RAM
# MemFree:      Truly free RAM
# MemAvailable: Available for new processes (free + recoverable cache)
# Buffers:      Raw block device cache
# Cached:       Filesystem cache
# SwapTotal/SwapFree: Swap space
# Dirty:        Memory that needs to be written to disk
# Shmem:        Shared memory (tmpfs, etc.)
```

---

## Process Memory Usage: VSZ vs RSS

```bash
ps aux
# Output columns:
# VSZ (Virtual Size)  = total virtual address space size (includes not-in-RAM pages)
# RSS (Resident Set Size) = pages actually in physical RAM right now

# Example:
# USER   PID  %CPU %MEM    VSZ    RSS
# www    1234   0.2  1.5  924444  61200 nginx: worker

# nginx worker:
# VSZ = 924MB  (total virtual address space — mostly not in RAM)
# RSS = 61MB   (actually in physical RAM right now)
# %MEM = 1.5%  (RSS as % of total RAM)
```

VSZ will always be much larger than RSS. This is normal. Don't use VSZ to measure memory usage. Use RSS.

```bash
# Better view of per-process memory:
ps -eo pid,comm,rss --sort=-rss | head -20
# Shows top 20 processes by resident memory, sorted highest first

# Even better: smaps
cat /proc/$(pgrep node)/smaps | grep -E "^(Private|Shared)_(Clean|Dirty):" | awk '{sum += $2} END {print sum " kB"}'
# Gives actual private memory used (not shared libraries counted multiple times)
```

---

## Stack vs Heap

Each process has two main memory regions:

### Stack

```
Purpose: Local variables, function call frames
Size:    Fixed (default 8MB per thread on Linux)
Growth:  Automatic — compiler manages it
Free:    Automatic — when function returns, stack frame is gone

void process_request(Request* req) {
    char buffer[1024];    ← on the stack, auto-allocated
    int status = 200;     ← on the stack
    // When this function returns, buffer and status are automatically freed
}

Stack overflow: happens when you call functions too deeply (deep recursion)
or allocate a huge array on the stack (char bigbuffer[100000000])
→ Segmentation fault (accessing beyond the stack limit)
```

### Heap

```
Purpose: Dynamically allocated memory (malloc/new/etc.)
Size:    Grows as needed (up to virtual address space limit)
Growth:  Explicit — you call malloc()/new, kernel expands heap if needed
Free:    Explicit — you call free()/delete

char* data = malloc(50000000);  ← 50MB allocated on heap
// ... use data ...
free(data);                     ← you MUST free it, or it's a memory leak
```

Memory leaks happen when heap memory is allocated but never freed. Over time, RSS grows unboundedly.

```bash
# Detect memory leaks (while the process runs, watch RSS grow):
watch -n 2 'ps -p $(pgrep node) -o rss='
# If RSS grows steadily over hours → likely memory leak
```

---

## Page Faults

A page fault occurs when a process accesses a virtual address whose page isn't currently in physical RAM.

```
Minor page fault (soft):
  Page is in memory somewhere (maybe another process is sharing it,
  or it was swapped but is still in the page cache)
  Kernel resolves it quickly — no disk I/O needed
  Very common, very fast (microseconds)

Major page fault (hard):
  Page must be loaded from disk
  Requires actual disk read
  Much slower (milliseconds)
  High major faults → memory pressure, process is thrashing disk
```

```bash
# See page fault stats for a process:
cat /proc/$(pgrep nginx | head -1)/status | grep -i fault
# VmPeak, VmRSS, voluntary_ctxt_switches, etc.

# Or using ps with custom format:
ps -p 1234 -o minflt,majflt,comm
#  minflt = minor page faults
#  majflt = major page faults (high = bad, app is swapping)
```

---

## Swap Space

When physical RAM is full, the kernel moves some pages to **swap** — a reserved area on disk. This allows processes to continue running, but swap I/O is orders of magnitude slower than RAM.

```
RAM access:  ~100 nanoseconds
SSD swap:    ~100 microseconds  (1,000x slower)
HDD swap:    ~10 milliseconds   (100,000x slower)
```

```bash
# See swap usage:
free -h
swapon --show

# How pages are being swapped:
vmstat 1
# Output (every second):
# procs  memory        swap    io      system   cpu
# r  b   swpd  free    si  so  bi  bo  in  cs  us sy id wa
# 1  0   1024  8192     0   0   0   0 200 400   5  2 90  2
#
# si = swap in (KB/s from swap to RAM) ← ideally 0
# so = swap out (KB/s from RAM to swap) ← ideally 0
# wa = CPU idle waiting for I/O ← high wa + si/so = you're thrashing
```

### swappiness — How Aggressively the Kernel Swaps

```bash
# Current swappiness:
cat /proc/sys/vm/swappiness
# Default: 60 (on Ubuntu) or 30 (on Amazon Linux)
# Range: 0-100
# 0 = only swap when absolutely necessary
# 100 = swap aggressively (keep RAM free)

# For database servers or high-performance apps: lower is better
echo 10 | sudo tee /proc/sys/vm/swappiness   # temporary
# Permanent:
echo "vm.swappiness = 10" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

**For AWS EC2:**
- If you're on an instance with no swap configured (common), when RAM fills up → OOM killer immediately
- For general-purpose instances: add a swap file as a safety net
- For memory-intensive workloads: right-size your instance instead of relying on swap

---

## The OOM Killer

When memory is critically low and swap is full (or doesn't exist), the kernel's **Out Of Memory killer** steps in and kills a process.

```
OOM killer selects the "best" process to kill using a score:
  Higher score = more likely to be killed
  
Score is based on:
  → Amount of memory the process uses (more memory = higher score)
  → Process's "OOM score adjustment" (can be tuned)
  → Child processes' memory
  → Time the process has been running (newer = higher score)
  → Whether it's a root process (root processes get -30 penalty)

The result: your biggest, newest, non-root process gets killed.
Often this is your app. Sometimes it's MySQL. Rarely it's systemd.
```

```bash
# Find what the OOM killer killed:
sudo journalctl -k | grep "Out of memory"
# Or:
sudo dmesg | grep "Out of memory\|oom_kill"

# Output:
# Jul 06 02:33:15 kernel: Out of memory: Kill process 1234 (node) score 842 or sacrifice child
# Jul 06 02:33:15 kernel: Killed process 1234 (node) total-vm:4096000kB, anon-rss:3891200kB

# Check current OOM score for a process (higher = more killable):
cat /proc/$(pgrep node)/oom_score

# Adjust OOM score (lower = less likely to be killed):
# Range: -1000 to 1000
# -1000 = kernel will never kill this process (use with care)
echo -500 | sudo tee /proc/$(pgrep mysqld)/oom_score_adj
# Make it permanent in systemd service: OOMScoreAdjust=-500
```

### Protecting Critical Processes from OOM

```bash
# In a systemd service unit file:
[Service]
OOMScoreAdjust=-500    # makes this process harder to kill
# or
OOMPolicy=kill         # kill this service if OOM (default)
OOMPolicy=stop         # stop (SIGTERM) instead of kill
OOMPolicy=continue     # leave it alone during OOM (risky)
```

---

## Memory-Mapped Files (mmap)

Instead of using `read()`/`write()` syscalls, a process can map a file directly into its virtual address space. Reading/writing memory = reading/writing the file.

```
Traditional I/O:                     Memory-mapped I/O:
  read(fd, buf, 4096)                  ptr = mmap(file, length)
  → kernel reads file to kernel buf    → kernel maps file into process memory
  → kernel copies from kernel to buf   → process accesses ptr[0], ptr[1], ...
  → process uses buf                   → kernel loads pages on demand
  Two copies of data                   Zero copies, very fast
```

Used by:
- Databases (PostgreSQL, SQLite map their data files)
- Shared memory between processes (map the same file → shared region)
- Executable loading (code is mmap'd, pages loaded on demand)

```bash
# See mmap'd regions for a process:
cat /proc/$(pgrep postgres | head -1)/maps | head -30

# Each line: address-range permissions offset device inode path
# 7f8a00000000-7f8a00001000 r-xp 0 sda1 1234 /usr/lib/libpthread.so
#   r-x = readable + executable (code/text segment)
#   rw- = readable + writable (data segment)
#   rwx = readable + writable + executable (unusual, potential security issue)
```

---

## Shared Memory Between Processes

Processes can share memory regions — useful for high-performance IPC (inter-process communication).

```bash
# See current shared memory segments:
ipcs -m

# Modern approach: POSIX shared memory via files in /dev/shm
ls /dev/shm/
# /dev/shm is a tmpfs (RAM-backed filesystem)
# Writing here doesn't touch disk — it's RAM

# Create a shared memory file:
dd if=/dev/zero of=/dev/shm/my-shared-region bs=1M count=100
# Now any process can mmap /dev/shm/my-shared-region and share the same memory
```

---

## Practical Memory Investigation

```bash
# Scenario: "The server is running slow and free shows low memory"

# Step 1: See actual available memory
free -h
# If "available" > 1GB: memory is NOT the problem, look elsewhere

# Step 2: Find memory hogs
ps -eo pid,comm,rss --sort=-rss | head -15
# Biggest RSS processes at the top

# Step 3: Is it growing? (watch for 5 minutes)
watch -n 30 'ps -eo comm,rss --sort=-rss | head -10'

# Step 4: Check swap activity
vmstat 1 10
# Look at si/so columns — if they're nonzero, you're swapping

# Step 5: Check OOM events
sudo dmesg | grep -i "out of memory\|oom"
sudo journalctl -k --since "1 hour ago" | grep -i oom

# Step 6: Per-process memory breakdown
cat /proc/$(pgrep node)/status | grep -E "VmRSS|VmSwap|VmPeak"
```

---

## cgroups — Memory Limits for Containers

Linux **control groups** (cgroups) let you limit how much memory a process (or group of processes) can use. Docker and Kubernetes use this to enforce container memory limits.

```bash
# When you run: docker run -m 512m nginx
# Docker creates a cgroup with:
#   memory.limit_in_bytes = 536870912 (512MB)

# If the container tries to use more than 512MB:
#   → OOM killer fires within the cgroup
#   → Only the container is affected, not the host

# See cgroup memory limits:
cat /sys/fs/cgroup/memory/memory.limit_in_bytes

# In a Kubernetes pod:
kubectl exec my-pod -- cat /sys/fs/cgroup/memory/memory.limit_in_bytes
# This is the container's memory limit from the Pod spec
```

→ Continue to: `04-filesystem-and-inodes.md`
