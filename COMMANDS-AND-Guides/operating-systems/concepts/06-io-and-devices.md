# I/O and Devices

---

## The Problem

Your computer has dozens of hardware devices: a keyboard, mouse, display, SSD, NVMe, Wi-Fi card, USB controller, GPU, Bluetooth adapter. Each speaks a completely different hardware protocol.

Your programs just call `read()` and `write()`. They don't know or care what hardware is involved.

The OS bridges this gap.

---

## Device Drivers

A **device driver** is a software module that knows how to talk to a specific piece of hardware. It's written by the hardware manufacturer (or OS developers) and follows a standard interface that the OS defines.

```
Your program:     write(fd, data, len)
                          ↓
OS kernel:        which device does this fd refer to?
                  → it's an SSD, call the SSD driver
                          ↓
NVMe SSD driver:  converts "write this data" into NVMe protocol commands
                          ↓
Hardware:         actual electrons moving on the SSD
```

Drivers are the reason you can plug in any keyboard and it just works — all keyboards expose the same standard interface to the OS, even though they're all different hardware internally.

On Linux, most drivers are built into the kernel or loaded as **kernel modules**. On Windows, they're `.sys` files. On macOS, they're **DriverKit extensions**.

---

## Two Types of Devices

### Block Devices

Transfer data in fixed-size **blocks** (e.g., 512 bytes or 4096 bytes). The OS can ask for any block by number, in any order.

Examples: SSD, HDD, USB drive, NVMe.

Block devices support **random access** — you can seek to the middle of a disk and read from there. This is how filesystems work — they're built on top of block devices.

### Character Devices

Transfer data as a **stream of bytes**, one at a time. No random access, no seeking.

Examples: keyboard, mouse, serial port, terminal.

A keyboard doesn't give you a "block of keystrokes" — it sends one character at a time as keys are pressed.

```
/dev/sda   → block device (first hard drive)
/dev/tty0  → character device (first terminal)
/dev/null  → special character device (discards everything written to it)
/dev/random → special character device (produces random bytes)
```

---

## "Everything Is a File" — Unix Philosophy

On Unix-based systems (Linux, macOS), the OS exposes almost everything through the **file interface** — you `open()`, `read()`, `write()`, and `close()` them, just like regular files.

This means:
- A disk device is a file (`/dev/sda`)
- A terminal is a file (`/dev/tty`)
- A network socket is a file (a file descriptor)
- A pipe between two programs is a file (a file descriptor)
- System information is a file (`/proc/cpuinfo` on Linux)
- Even kernel settings are files (`/sys/kernel/...` on Linux)

This uniform interface means the same tools work everywhere. `cat /dev/urandom` reads random bytes from a device, the same way `cat file.txt` reads a file.

Windows does not follow this model — devices are accessed through separate APIs.

---

## Interrupts

Devices communicate with the CPU through **interrupts** — a signal the hardware sends when it needs attention.

Without interrupts, the CPU would have to constantly ask every device "do you have data for me?" — this is called **polling** and wastes CPU cycles.

With interrupts:
1. CPU continues doing useful work (running your program)
2. When the keyboard detects a keypress, it sends an interrupt signal to the CPU
3. The CPU pauses the current program (saves state)
4. The CPU runs the **interrupt handler** — a small kernel function that reads the keystroke and stores it in a buffer
5. The CPU resumes the paused program

```
Program running...
           keyboard pressed
           ↓
[interrupt] → kernel interrupt handler reads keystroke, stores in buffer
           ↑
Program continues (doesn't know the interrupt happened)
```

This is why your computer can do many things "at the same time" even on a single core — the CPU constantly switches between running programs and handling hardware interrupts.

---

## I/O Buffering

Disk and network I/O is much slower than RAM. Waiting for every write to physically complete before continuing would make programs very slow.

The OS uses **buffers** to solve this:

**Write buffering** — when your program writes to disk, the OS stores the data in a RAM buffer and immediately returns to your program. It writes to the actual disk later (in batches — more efficient). This is called "writeback caching."

**Read buffering** — if you read part of a file, the OS reads a larger chunk into a buffer. If you read the next part soon, it's already in the buffer — no disk access needed.

The risk: if the power goes out before a buffered write is flushed to disk, data is lost. This is why:
- Databases call `fsync()` to force a flush before confirming a transaction
- Filesystems use journaling (see `05-filesystem.md`)
- Properly unmounting a USB drive is important — it flushes all pending writes

---

## Direct I/O

Databases and high-performance storage systems sometimes use **direct I/O** — bypassing the OS buffer cache and writing directly to disk. This gives the application full control over caching at the cost of losing OS-managed buffering.

---

## Platform Notes

| | Linux | macOS | Windows |
|--|-------|-------|---------|
| Device model | "Everything is a file" (`/dev/`) | "Everything is a file" (`/dev/`) | Separate device API (Win32) |
| Block devices | `/dev/sda`, `/dev/nvme0n1` | `/dev/disk0` | `\\.\PhysicalDrive0` |
| Character devices | `/dev/tty`, `/dev/null` | `/dev/tty`, `/dev/null` | `CON`, `NUL` |
| Driver format | Kernel modules (`.ko`) | DriverKit extensions | `.sys` files |
| Interrupt handling | Kernel IRQ handlers | Kernel IRQ handlers | Windows interrupt handlers |
| View devices | `lsblk`, `ls /dev/`, `lspci` | `diskutil list`, `ioreg` | Device Manager (`devmgmt.msc`) |

→ Next: `07-users-and-security.md`
