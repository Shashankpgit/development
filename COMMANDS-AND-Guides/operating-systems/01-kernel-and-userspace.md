# Operating Systems — 01: Kernel and User Space

> **Last updated:** July 6, 2026
> **How programs actually interact with hardware. System calls, privilege levels, and why a bad app can't crash the whole OS.**

---

## CPU Privilege Rings

Modern CPUs (x86, ARM) have hardware-enforced privilege levels called **rings** (or exception levels on ARM). Linux uses two of them:

```
Ring 0 — Kernel Mode
  Full hardware access.
  Can execute any CPU instruction.
  Can read/write any memory address.
  The Linux kernel runs here.

Ring 3 — User Mode
  Restricted. Cannot directly access hardware.
  Can only access its own memory.
  Cannot execute privileged CPU instructions.
  All user processes (bash, nginx, your app) run here.

Rings 1 and 2 exist but Linux doesn't use them.
```

This is enforced in hardware — not software. If a Ring 3 process tries to execute a privileged instruction (like directly writing to a disk sector), the CPU raises an exception (fault), and the kernel kills that process.

```
What happens when a process tries to access memory it doesn't own:
  Process A tries to read address 0xDEADBEEF (belongs to process B)
  CPU checks: "Is this address in process A's page table?" → No
  CPU raises a "page fault" exception
  Kernel handles the exception: sends SIGSEGV to process A
  Process A crashes with "Segmentation fault"
  Process B is completely unaffected
```

This is why a segfault kills only the misbehaving process — the CPU and kernel stopped it before it could do any damage.

---

## System Calls — The Controlled Gate

User space code that needs hardware access must ask the kernel to do it via a **system call** (syscall). A syscall is the only legitimate way to cross from Ring 3 into Ring 0.

```
User space: "I want to read 100 bytes from file descriptor 3"
              ↓
           [CPU executes SYSCALL instruction]
              ↓
Kernel:   Validates: does this process have permission?
          Reads 100 bytes from the appropriate buffer
          Copies data into the process's memory
              ↓
           [CPU returns to Ring 3]
              ↓
User space: receives the 100 bytes, continues executing
```

### Common Syscalls You Use Every Day

Every function in every programming language that touches the OS eventually calls one of these:

```
File operations:
  open()      → opens a file, returns a file descriptor (integer)
  read()      → reads bytes from a file descriptor
  write()     → writes bytes to a file descriptor
  close()     → closes a file descriptor
  stat()      → gets file metadata (size, permissions, timestamps)
  unlink()    → deletes a file

Process operations:
  fork()      → creates a copy of the current process
  execve()    → replaces current process with a new program
  exit()      → terminates the current process
  wait()      → waits for a child process to finish
  getpid()    → returns the current process's ID

Memory:
  mmap()      → maps a file or device into memory
  brk()       → extends the process's heap
  
Network:
  socket()    → creates a network socket
  bind()      → binds a socket to an address
  listen()    → marks a socket as accepting connections
  accept()    → accepts an incoming connection
  send()/recv() → send/receive data

Signals:
  kill()      → sends a signal to a process (despite the name, can send any signal)
  signal()    → registers a signal handler
```

### Seeing Syscalls Live

```bash
# strace shows every syscall a process makes
# Watch what happens when you run 'ls':
strace ls /tmp

# Output (abbreviated):
execve("/usr/bin/ls", ["ls", "/tmp"], ...)      # load the ls binary
openat(AT_FDCWD, "/etc/ld.so.cache", O_RDONLY)  # load dynamic libraries
mmap(NULL, 4096, ...)                            # allocate memory
openat(AT_FDCWD, "/tmp", O_RDONLY|O_DIRECTORY)   # open the directory
getdents64(3, ...)                               # read directory entries
write(1, "file1  file2  file3\n", 20)            # write to stdout
exit_group(0)                                    # exit

# Count how many syscalls a command makes:
strace -c ls /tmp
# Shows a summary table of syscall counts and time spent

# Attach to a running process (useful for debugging hanging processes):
strace -p <pid>
```

`strace` is invaluable for debugging: "why is my app failing?" → `strace -p <pid>` shows exactly what kernel operations it's stuck on.

---

## How a Program Gets Loaded and Executed

When you type `nginx` at the shell prompt, a lot happens:

### Step 1: Shell forks itself

```
bash (PID 1234) calls fork()
→ Creates a copy of itself: new process (PID 1235), identical to bash
```

### Step 2: Child executes the new program

```
PID 1235 calls execve("/usr/sbin/nginx", ["nginx"], env)
→ Kernel replaces PID 1235's memory with nginx's code
→ PID 1235 is now running nginx (but still has PID 1235)
→ nginx starts executing from its main() function
```

### Step 3: Parent waits (or doesn't)

```
bash (PID 1234) calls wait() or waitpid()
→ Sleeps until PID 1235 finishes
→ When nginx exits, bash wakes up and shows the prompt again

If you run nginx &:
→ bash does NOT call wait()
→ bash immediately shows the prompt
→ nginx runs in the background
```

### Why fork + exec (not just "create process")?

The fork-then-exec model means the child inherits everything from the parent before `execve()` replaces its image:
- Open file descriptors (used for I/O redirection: `nginx 2>&1 /var/log/nginx.log`)
- Environment variables
- Signal handlers
- Working directory

This is how shell pipe works:
```bash
ls | grep txt

# What the shell actually does:
# 1. Create a pipe: an anonymous file descriptor pair (read end, write end)
# 2. fork → child 1 (runs ls, stdout redirected to write end of pipe)
# 3. fork → child 2 (runs grep, stdin redirected to read end of pipe)
# 4. Wait for both children
```

---

## Kernel Modules

The Linux kernel doesn't have all drivers compiled in — that would be enormous. Instead, device drivers can be loaded as **kernel modules** at runtime.

```bash
# List loaded kernel modules:
lsmod

# Output:
Module                  Size  Used by
xt_conntrack           16384  1
nf_conntrack          172032  2 xt_conntrack...
ip_tables              32768  1 iptables
...

# Load a module:
sudo modprobe nvidia       # load NVIDIA GPU driver

# Remove a module:
sudo modprobe -r nvidia

# Info about a module:
modinfo nvidia
```

On EC2, AWS automatically loads the right kernel modules for EBS volumes (nvme driver), enhanced networking (ena driver), etc. You don't need to manage this manually — but knowing it exists helps when troubleshooting "why isn't my disk detected?"

---

## The /proc Filesystem — A Window Into the Kernel

`/proc` is a **virtual filesystem** — it has no files on disk. The kernel generates its contents dynamically when you read from it. It's the kernel exposing its internal state as files.

```bash
# Info about a specific process (replace 1234 with a real PID):
ls /proc/1234/
# cmdline      → the command line used to start it
# environ      → environment variables
# fd/          → directory of open file descriptors
# maps         → memory map (what memory regions it has)
# status       → CPU state, memory usage, parent PID
# exe          → symlink to the executable file

# Read the command line of process 1234:
cat /proc/1234/cmdline | tr '\0' ' '

# See all open files for process 1234:
ls -la /proc/1234/fd

# System-wide info:
cat /proc/cpuinfo      # CPU model, cores, features
cat /proc/meminfo      # Detailed memory statistics
cat /proc/loadavg      # Load average (1min, 5min, 15min, running/total threads, last PID)
cat /proc/uptime       # Seconds since boot
cat /proc/version      # Kernel version
cat /proc/net/tcp      # Active TCP connections (raw numbers, use ss instead)
```

```bash
# Practical use: find what files a process has open
# (useful for debugging "file descriptor leak"):
ls -la /proc/$(pgrep nginx)/fd
```

---

## The /sys Filesystem

Similar to `/proc` but specifically for hardware and kernel subsystem configuration. More structured than `/proc`.

```bash
# Network interface info:
ls /sys/class/net/
# eth0  lo  docker0

cat /sys/class/net/eth0/speed        # link speed in Mbps
cat /sys/class/net/eth0/operstate    # "up" or "down"

# CPU info:
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq  # current CPU frequency

# Block device info:
ls /sys/block/
# nvme0n1  xvda  (your disks)

cat /sys/block/nvme0n1/size          # size in 512-byte sectors
```

---

## Virtual Memory — The Abstraction That Makes Everything Possible

Every process gets its own **virtual address space** — a range of addresses it thinks it exclusively owns. The kernel + CPU hardware translates these virtual addresses to physical RAM addresses.

```
Process A's view:            Physical RAM (8GB):
  0x0000 → my code            0x0000 → Process A's code
  0x1000 → my data            0x1000 → Process B's code
  0x2000 → my heap            0x2000 → Process A's data
  ...                         0x3000 → kernel
  0x7FFF → (unmapped)         ...

Process B's view:
  0x0000 → my code   ─────→   same 0x1000 physical address as B's code
  0x1000 → my data
  ...
```

Benefits:
- **Isolation**: Process A can't access Process B's memory (different page tables)
- **More memory than you have**: Memory-mapped files appear as memory even though they're on disk; pages are loaded on demand
- **Consistent addresses**: Every process can use address 0x400000 for its code without conflicts

This is a preview — memory management gets its own deep-dive in `03-memory-management.md`.

---

## Dynamic Linking — Why Your Binary Needs Other Files

Most programs don't include all their code. They link dynamically against shared libraries.

```bash
# See what shared libraries nginx needs:
ldd /usr/sbin/nginx

# Output:
linux-vdso.so.1 (0x...)               # Virtual Dynamic Shared Object (kernel provides this)
libdl.so.2 => /lib/x86_64-linux-gnu/libdl.so.2
libpthread.so.0 => /lib/x86_64-linux-gnu/libpthread.so.0
libc.so.6 => /lib/x86_64-linux-gnu/libc.so.6  # The C standard library
/lib64/ld-linux-x86-64.so.2          # The dynamic linker itself
```

When nginx starts:
1. Kernel loads the nginx binary
2. Kernel sees the "I need dynamic linking" flag in the binary
3. Kernel runs `/lib64/ld-linux-x86-64.so.2` (the dynamic linker)
4. The dynamic linker loads all `.so` files into the process's address space
5. nginx's `main()` starts executing

This is why you sometimes see "error while loading shared libraries" — the `.so` file the program needs isn't where the system expects it.

```bash
# If a binary can't find a .so file:
export LD_LIBRARY_PATH=/path/to/custom/libs:$LD_LIBRARY_PATH
# Or:
sudo ldconfig    # refresh the system's shared library cache
```

---

## Kernel Version and Your AWS Instances

```bash
# What kernel is running:
uname -r
# 6.1.79-99.167.amzn2023.x86_64   (Amazon Linux 2023)
# 5.15.0-1057-aws                   (Ubuntu 22.04 on EC2)

# Full system info:
uname -a

# Kernel version + distro:
cat /etc/os-release
```

The kernel version matters for:
- **Security patches**: Older kernels have CVEs. AWS updates the kernel in new AMIs.
- **Features**: Newer kernels have better io_uring, eBPF, cgroup v2 support (Kubernetes uses these)
- **Drivers**: ENA (enhanced networking) and NVMe drivers are in recent kernels — needed for high-performance EC2

→ Continue to: `02-processes-and-signals.md`
