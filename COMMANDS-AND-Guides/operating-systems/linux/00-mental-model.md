# Operating Systems — 00: Mental Model

> **Last updated:** July 6, 2026
> **What an OS actually is, why Linux is everywhere, and the core idea you need before everything else.**

---

## The Problem an OS Solves

Imagine you're writing an application. Your app needs to:
- Read a file from disk
- Send data over the network
- Show output to the terminal
- Use 512MB of RAM

Now imagine there are 50 other apps running on the same machine at the same time, all wanting to do the same things. How do you:
- Make sure two apps don't write to the same disk sectors simultaneously?
- Ensure app A can't read app B's memory?
- Share the single CPU fairly among all 50 apps?
- Let each app use the network without interfering with each other?

**The operating system solves all of this.** It's the software layer between your application code and the physical hardware.

```
Your Application (Python, Node.js, Java, etc.)
         ↓
   Operating System (Linux)
         ↓
   Physical Hardware (CPU, RAM, Disk, Network card)
```

Without an OS, you'd need every application to include its own disk driver, network driver, memory manager — and they'd all conflict with each other. The OS does this once and provides a clean interface for all apps.

---

## What an OS Actually Does

Four core responsibilities:

### 1. Process Management
The OS creates, schedules, and kills processes. It gives each process the illusion that it has the whole CPU to itself.

```
Reality:   CPU executes one process at a time (per core)
Illusion:  Your app feels like it's running continuously

How: The OS switches between processes thousands of times per second.
     Each switch is so fast (microseconds) that you don't notice.
     This is called "time-slicing" or "preemptive multitasking."
```

### 2. Memory Management
The OS gives each process its own isolated memory space. Process A can't touch Process B's memory.

```
Physical RAM: 8GB total, shared across all processes

Process A thinks it has: addresses 0x0000 to 0xFFFF
Process B thinks it has: addresses 0x0000 to 0xFFFF

Same virtual addresses, different physical locations.
The OS (with hardware help) translates virtual → physical addresses.
```

### 3. File System
The OS abstracts disk storage into files and directories. You don't need to know where on the disk your data is — the OS tracks it.

```
You write:   open("/etc/nginx/nginx.conf", "r")
OS does:     Looks up the inode for that path
             Finds the physical disk sectors
             Reads them into memory
             Returns data to your process
```

### 4. Device Management
The OS provides drivers — code that translates generic operations ("read 512 bytes from disk") into hardware-specific commands for your specific disk, network card, GPU, etc.

---

## Kernel vs User Space — The Most Important Distinction

This is the core concept. Everything in Linux exists in one of two spaces:

```
┌─────────────────────────────────────────────────────┐
│                   USER SPACE                         │
│   bash, nginx, python, your-app, ls, curl, vim...   │
│   (your code runs here)                              │
├─────────────────────────────────────────────────────┤
│              SYSTEM CALL INTERFACE                   │
│   (the controlled border between the two)           │
├─────────────────────────────────────────────────────┤
│                  KERNEL SPACE                        │
│   Process scheduler, memory manager, filesystem     │
│   drivers, network stack, device drivers...         │
│   (Linux kernel code runs here)                     │
├─────────────────────────────────────────────────────┤
│                   HARDWARE                           │
│   CPU, RAM, Disk, Network Card, USB...               │
└─────────────────────────────────────────────────────┘
```

### Why the separation exists

User space code can only access its own memory. It **cannot** directly:
- Read/write to disk hardware
- Access other processes' memory
- Configure the network interface
- Manage physical memory allocation

If it could, a buggy program could corrupt the entire system. A bug in user space = that process crashes, nothing else affected.

Kernel space code CAN do all of the above — it runs with full hardware privileges. A bug in kernel space = the entire system crashes (kernel panic).

### How user space code talks to hardware

Through **system calls** (syscalls). When your Python script does `open("file.txt")`, Python calls the C library, which calls the `open` syscall, which crosses into kernel space, which interacts with the filesystem driver, which talks to the disk.

```
Python:    open("file.txt")
    ↓
libc:      int fd = syscall(SYS_open, "file.txt", O_RDONLY, 0)
    ↓
Kernel:    [crosses the user/kernel boundary]
           Checks permissions, finds the inode, returns file descriptor
    ↓
Python:    gets back a file object (fd = 5)
```

This is why you'll sometimes see "syscall" in performance profiling — every I/O operation involves crossing this boundary.

---

## Why Linux?

Linux is the OS of the cloud. Understanding why helps you understand what you're working with.

### The Numbers

```
Cloud servers:        ~96% run Linux (AWS, GCP, Azure)
Docker containers:    100% run on Linux kernel
Kubernetes nodes:     100% Linux (worker nodes)
Android phones:       Linux kernel
Raspberry Pi:         Linux
Supercomputers:       ~100% Linux
```

### Why Linux Won the Server World

1. **Open source** — anyone can read the code, audit it, contribute to it, customize it
2. **Stability** — runs for years without a reboot (AWS instances with 500+ day uptime are normal)
3. **Performance** — kernel is highly optimized for server workloads
4. **Flexibility** — can be stripped down to run in containers with <10MB footprint
5. **Tooling** — decades of battle-tested tools: grep, awk, sed, cron, curl, etc.
6. **Cost** — free. No per-VM license fees.

Windows Server runs well on AWS too — but at a cost premium (Windows license included), and it's less common for DevOps/backend workloads.

---

## Linux Distributions

The **Linux kernel** is just the kernel (process management, memory, device drivers). A **Linux distribution** (distro) bundles the kernel with:
- A package manager (apt, yum/dnf, pacman...)
- System utilities (GNU coreutils: ls, cp, mv, cat...)
- An init system (systemd)
- Default configuration

```
Linux Kernel (same core)
      +
Package manager + System utilities + Init system + Default config
      =
Ubuntu 22.04 / Amazon Linux 2023 / Debian 12 / RHEL 9 / Alpine...
```

All distros run the same applications. `nginx` on Ubuntu is the same `nginx` binary as on Amazon Linux. The differences are mainly:
- How you install software (apt vs dnf)
- Default file locations (minor differences)
- Which version of packages is in the default repo
- Commercial support (RHEL has it, Ubuntu LTS has it, others don't)

### Which One to Know for AWS

**Amazon Linux 2023** — AWS's own distro, based on Fedora/RHEL lineage, uses `dnf`.
**Ubuntu 22.04 LTS** — Most popular non-Amazon distro on EC2, uses `apt`.

Know both. Most commands are identical. Package management differs.

---

## The Shell — Your Interface to the OS

The **shell** is a user-space program that reads commands you type and executes them. It's just another process, like any other.

```
You type:   ls -la /etc
Shell does: Calls the execve() syscall with the path to /usr/bin/ls
            Creates a new process running /usr/bin/ls
            Waits for ls to finish
            Prints the prompt again
```

Popular shells:
- **bash** — Bourne Again Shell. Default on most Linux distros.
- **zsh** — Extended bash with better completions. Default on macOS.
- **sh** — The original POSIX shell. Minimal. Used in shell scripts for portability.

When you SSH into an EC2 instance, you're connecting to bash running on that machine. Every command you type is a process the shell launches.

---

## Everything Is a File

This is Linux's most important design principle. Almost everything in the system is represented as a file:

```
Regular files:    /etc/nginx/nginx.conf
Directories:      /var/log/
Devices:          /dev/sda   (your disk)
                  /dev/null  (the void — writes disappear, reads return empty)
                  /dev/urandom (random number generator)
Processes:        /proc/1234/   (info about process 1234)
                  /proc/meminfo (current memory stats)
Network sockets:  /proc/net/tcp
Hardware:         /sys/class/net/eth0/ (network interface config)
```

This means you can use the same tools on all of them. `cat /dev/urandom | head -c 16 | xxd` reads random bytes. `cat /proc/cpuinfo` shows CPU info. Same command, different "files."

---

## A Day in the Life of a Request on Linux

When a user's HTTP request hits your EC2 instance and your app responds, here's what the OS does:

```
1. Network card receives the packet (hardware interrupt)
2. Kernel's network driver processes it (kernel space)
3. Kernel's TCP/IP stack routes it to the right socket (kernel space)
4. Your app (nginx) is woken up — it was sleeping waiting for the socket (user space)
5. nginx calls read() syscall → kernel copies data from socket buffer to app memory
6. nginx reads the request, decides what to do
7. nginx opens a file: open() syscall → kernel finds the file on disk
8. nginx reads the file: read() syscall → kernel reads from disk, returns data
9. nginx calls write() on the socket → kernel copies data to network buffer
10. Kernel's network stack packages and sends the response
11. nginx calls epoll_wait() → goes back to sleep, waiting for the next request
```

Steps 1-4, 5 (half), 7, 8, 9, 10 are kernel space. Steps 4 (waking up), 6, 9 (calling write) are user space.

This is why understanding the OS boundary matters — when your app is "slow," the bottleneck is often in the kernel (disk I/O wait, network buffer pressure, process scheduling delay), not in your app code.

→ Continue to: `01-kernel-and-userspace.md`
