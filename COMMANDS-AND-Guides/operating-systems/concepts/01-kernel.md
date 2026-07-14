# The Kernel

---

## What Is the Kernel?

The **kernel** is the core of the operating system — the part that runs at all times, has full control of the hardware, and manages everything else.

Think of it like the manager of a restaurant. Customers (your apps) don't walk into the kitchen and cook their own food — they talk to the manager, who coordinates everything behind the scenes. The manager (kernel) has access to the full kitchen (hardware); customers don't.

When you install Ubuntu or Windows, the thing that actually boots and runs from power-on is the kernel. The desktop, the file explorer, the terminal — those are all user-space programs that run *on top of* the kernel.

---

## What the Kernel Actually Does

The kernel has these core jobs:

**1. Manages the CPU**
The kernel decides which program runs on the CPU at any given moment. It switches between programs so rapidly that they appear to run simultaneously. This is called **scheduling**.

**2. Manages Memory**
The kernel controls all of RAM. It assigns memory regions to programs, protects them from each other, and handles "virtual memory" — making programs think they have more RAM than physically exists.

**3. Manages the Filesystem**
The kernel translates "open this file" into actual read operations on the physical storage device. It maintains the directory tree, tracks where each file's data is stored, and handles permissions.

**4. Manages Devices**
The kernel communicates with hardware — the disk, network card, keyboard, screen — through **device drivers**. Drivers are code that knows how to speak to specific hardware models.

**5. Provides System Calls**
The kernel exposes a set of functions (system calls) that user-space programs can use to request services. This is the OS's actual public interface.

---

## Kernel Space vs User Space

Every modern CPU supports at least two privilege levels, often called **rings**:

```
Ring 0 — Kernel Mode (highest privilege)
  → Can execute any CPU instruction
  → Can access any memory address
  → Can talk directly to hardware
  → Kernel runs here

Ring 3 — User Mode (restricted)
  → Cannot execute privileged CPU instructions
  → Cannot access hardware directly
  → Cannot access other processes' memory
  → Your applications run here
```

This hardware enforcement is what makes the separation real — it's not just a software convention. If a user-space program tries to execute a privileged instruction, the CPU raises a hardware exception and the kernel kills the program.

When your program makes a system call, the CPU switches from Ring 3 to Ring 0, runs the kernel code, and switches back. This "mode switch" is intentional, controlled, and fast (microseconds).

---

## Types of Kernels

Different operating systems structure their kernels differently:

### Monolithic Kernel

Everything runs in kernel space — the scheduler, memory manager, filesystem, network stack, device drivers — all in one large program sharing the same memory.

```
Kernel Space:  [ Scheduler | Memory | Filesystem | Network | Drivers | ... ]
```

**Pro:** Fast — no overhead switching between components.  
**Con:** A bug in a driver can crash the entire OS.  
**Example:** Linux kernel.

### Microkernel

Only the absolute minimum runs in kernel space. Everything else (filesystems, drivers, networking) runs as separate user-space processes.

```
Kernel Space:  [ IPC | Basic memory | Process scheduler ]
User Space:    [ Filesystem server | Driver server | Network server ]
```

**Pro:** More stable — a crashed driver doesn't take down the kernel.  
**Con:** Slower — everything has to communicate via message passing.  
**Example:** QNX (used in cars, medical devices), MINIX.

### Hybrid Kernel

A pragmatic middle ground — starts with a microkernel design but moves performance-critical parts into kernel space.

```
Kernel Space:  [ Core kernel + some drivers + some subsystems ]
User Space:    [ Other services ]
```

**Example:** macOS's XNU kernel, Windows NT kernel.

In practice, Linux (monolithic) and modern hybrid kernels perform similarly — Linux has loadable kernel modules that help modularize the kernel without a strict microkernel design.

---

## The Linux Kernel Specifically

The Linux kernel is monolithic but modular. You can load and unload **kernel modules** at runtime — adding driver support for a new device without rebooting.

```
Linux kernel core  +  loadable modules (drivers, filesystems, etc.)
```

This is why when you plug in a USB WiFi adapter, Linux loads the driver module for it automatically.

The Linux kernel is also open source — anyone can read, modify, and contribute to it. This is why Linux runs on everything from the tiniest embedded microcontroller to the world's largest supercomputers.

---

## Platform Notes

| | Linux | macOS | Windows |
|--|-------|-------|---------|
| Kernel name | Linux | XNU (Darwin) | NT Kernel (ntoskrnl.exe) |
| Architecture | Monolithic + loadable modules | Hybrid (Mach + BSD) | Hybrid |
| Source | Open source | Partially open (Darwin is open) | Closed source |
| Drivers | Kernel modules (.ko files) | KEXTs / DriverKit extensions | .sys files |
| System call standard | POSIX | POSIX | Win32 API |

→ Next: `02-processes-and-threads.md`
