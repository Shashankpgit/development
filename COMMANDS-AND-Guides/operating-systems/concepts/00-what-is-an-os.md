# What Is an Operating System?

---

## The Problem It Solves

Imagine you're writing a program that needs to save a file. Your program doesn't know:
- What kind of storage the computer has (SSD, HDD, NVMe, USB)
- Where free space is on the disk
- How to talk to the storage hardware at the electrical level
- What other programs are also trying to write to disk at the same time

If every programmer had to solve all of this from scratch, writing software would be nearly impossible. And every program would break when run on a different computer.

The **Operating System (OS)** solves this. It sits between your hardware and your applications, providing a clean, consistent interface that hides hardware complexity.

---

## The Layers

Think of a computer as a stack of layers. Each layer only talks to the layer directly above and below it:

```
┌─────────────────────────────────┐
│      Your Application           │  ← "Save this file"
├─────────────────────────────────┤
│      Operating System           │  ← figures out how to do it
│   (kernel + system libraries)   │
├─────────────────────────────────┤
│          Hardware               │  ← actually does it
│  (CPU, RAM, Disk, Network card) │
└─────────────────────────────────┘
```

Your app never talks to hardware directly. It asks the OS. The OS figures out the hardware details and does it.

---

## What the OS Is Responsible For

An OS has six core responsibilities:

### 1. Process Management
Running multiple programs "at the same time."

Your CPU can only execute one instruction at a time per core. But you have a browser, a code editor, Slack, and Spotify all open simultaneously. The OS rapidly switches between them — so fast (thousands of times per second) that it feels simultaneous.

### 2. Memory Management
Giving each program its own private memory space.

When Chrome opens, it gets some RAM. When VS Code opens, it gets some more. They never accidentally read or overwrite each other's memory — the OS enforces this isolation. If a program tries to access memory it wasn't given, the OS kills it (that's a "segmentation fault" or "access violation").

### 3. Filesystem
Organizing data on storage into files and directories.

The physical disk just stores ones and zeros at addresses. The OS adds the concept of "files" and "folders" on top. It tracks where each file's data lives on the physical disk, handles free space, and manages file metadata (name, size, permissions, timestamps).

### 4. Device Management
Providing a uniform interface to hardware through drivers.

Your program just calls `write()`. The OS figures out whether it's writing to an SSD, an HDD, a USB drive, or a network share — and uses the correct hardware-specific code (the **driver**) to do it.

### 5. Security and Access Control
Deciding who can do what.

The OS knows which user is logged in and which programs are running. It enforces rules: this user can read this file but not that one; this program can use the network but not write to disk.

### 6. Networking
Managing how data flows in and out of the computer.

When your app opens a connection to a server, it doesn't send packets itself. It asks the OS. The OS maintains the networking stack — protocols, connections, buffers — and hands your app a simple interface (a "socket") to use.

---

## Kernel vs Userspace

The OS is split into two zones:

```
┌─────────────────────────────────────┐
│            User Space               │
│  (your apps, browsers, editors)     │  ← limited privileges
│  (system libraries: libc, etc.)     │
├─────────────────────────────────────┤  ← the boundary (system call interface)
│            Kernel Space             │
│  (the actual OS core)               │  ← full hardware access
│  (process scheduler, memory mgr,    │
│   filesystem, network stack,        │
│   device drivers)                   │
└─────────────────────────────────────┘
```

**Kernel space** has complete, unrestricted access to hardware. Code here runs in "privileged mode."

**User space** is restricted. Your app cannot directly touch hardware, other apps' memory, or the kernel's data structures. It must ask the kernel for help — via a **system call**.

This separation is what keeps one misbehaving app from crashing the whole computer.

---

## System Calls — How Apps Talk to the OS

When your program needs something from the OS, it makes a **system call** — a controlled jump from user space into kernel space.

```
Your code:         open("data.txt", "r")
      ↓
System call:       sys_open(filename, flags, mode)   ← crosses into kernel
      ↓
Kernel:            looks up file, checks permissions, returns a file descriptor
      ↓
Your code:         gets back fd = 3   (a file descriptor to use for reads)
```

You don't usually call system calls directly. Programming languages wrap them in libraries:
- In C: `fopen()` wraps `open()`
- In Python: `open()` wraps `open()`
- In Node.js: `fs.readFile()` wraps `read()`

The syscall interface is the real API of the operating system — everything else is built on top of it.

---

## How This Fits Together

```
You write:    file = open("data.txt")

Your language's standard library wraps this into a system call

The OS kernel:
  1. Checks if the file exists in its filesystem table
  2. Checks if your user has permission to read it
  3. Finds where the file's data is on the physical disk
  4. Asks the storage driver to read those disk sectors
  5. Copies the data into a kernel buffer
  6. Copies the data into your program's memory
  7. Returns a file descriptor to your program

Your program reads the bytes.
```

All of that complexity — hidden behind one line of code.

---

## Platform Notes

| | Linux | macOS | Windows |
|--|-------|-------|---------|
| Kernel | Linux kernel (monolithic) | XNU (hybrid) | NT kernel (hybrid) |
| System call interface | POSIX (`open`, `read`, `write`) | POSIX (same names) | Win32 API (`CreateFile`, `ReadFile`) |
| Userspace / Kernel boundary | Ring 0/3 (CPU protection rings) | Ring 0/3 | Ring 0/3 |
| Apps can bypass OS? | No (hardware enforced) | No | No |

→ Next: `01-kernel.md`
