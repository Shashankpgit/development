# The Boot Process

---

## What Happens When You Press Power?

Booting is the sequence of events that takes a computer from "powered off" to "running OS with a usable shell or desktop." It happens in stages, each stage handing off control to the next.

Understanding the boot process helps you debug systems that won't start — knowing which stage failed tells you where to look.

---

## Stage 1: Firmware (BIOS / UEFI)

The moment power is applied, the CPU doesn't know anything. It starts executing code from a fixed, pre-set memory address — this address points to the **firmware** stored in a chip on the motherboard.

```
Power on → CPU jumps to firmware address (hardwired in CPU)
```

**BIOS (Basic Input/Output System)** — the old standard (1981). 16-bit, limited to 1MB of addressable memory, can only boot from the first 512 bytes of a disk (MBR).

**UEFI (Unified Extensible Firmware Interface)** — the modern replacement. 64-bit, supports large disks (GPT partition tables), has a proper GUI, can boot from a special partition (EFI System Partition), faster.

The firmware does:
1. **POST (Power-On Self Test)** — checks that CPU, RAM, and storage are functional
2. **Finds a bootable device** — checks the configured boot order (SSD, USB, network)
3. **Loads the bootloader** — reads the first stage of the bootloader from that device and hands control to it

If POST fails, you hear beep codes or see an error. If no bootable device is found, you see "No boot device found."

---

## Stage 2: Bootloader

The **bootloader** is a small program whose only job is to load the OS kernel into RAM and start it.

Why not just load the kernel directly from firmware? Because the kernel is large, complex, and the firmware doesn't know which filesystem it's stored on. The bootloader knows how to read the filesystem and find the kernel.

```
Firmware → reads bootloader from disk → bootloader runs
```

Common bootloaders:
- **GRUB2** (Linux) — Grand Unified Bootloader. Shows the OS selection menu. Knows how to read ext4, XFS, Btrfs, etc.
- **Windows Boot Manager** — reads from the BCD (Boot Configuration Data) store
- **macOS Boot ROM** — Apple Silicon Macs have a secure boot process that loads the macOS bootloader

The bootloader:
1. Reads its configuration (which kernel to load, which arguments to pass)
2. Loads the kernel image into RAM
3. Loads an **initrd/initramfs** — a temporary RAM-based filesystem the kernel uses during early boot
4. Jumps to the kernel's entry point

On GRUB: you can press `e` to edit boot parameters, or `c` to get a GRUB shell. This is useful for recovery — you can pass `single` to boot into single-user mode.

---

## Stage 3: Kernel Initialization

The kernel takes over. It starts in a minimal state — no filesystem mounted, no processes running, just raw hardware access.

```
Kernel starts:
  1. Detects and initializes hardware (CPU, memory, devices)
  2. Sets up memory management (virtual memory, page tables)
  3. Mounts the initramfs (temporary root filesystem)
  4. Loads essential drivers needed to access the real root filesystem
  5. Mounts the real root filesystem (your actual / partition)
  6. Starts the first user-space process
```

The **initramfs** (initial RAM filesystem) is a temporary filesystem packed into a compressed archive that the bootloader places in RAM. It contains just enough drivers and tools to find and mount the real root filesystem (which might be on a special device like LVM, RAID, or an encrypted disk).

Once the real root filesystem is mounted, the kernel discards the initramfs and pivots to the real filesystem.

---

## Stage 4: init / systemd (The First Process)

The very last thing the kernel does is start **the first user-space process** — traditionally called `init`. It always gets **PID 1**.

PID 1 is special: it's the ancestor of every other process on the system. If PID 1 dies, the kernel panics and the system crashes.

**Modern Linux: systemd**
```
kernel starts → /sbin/init (which is systemd) → PID 1

systemd:
  - reads unit files from /etc/systemd/system/
  - starts services in the right order (dependency-aware)
  - mounts filesystems (/etc/fstab)
  - sets hostname, timezone, locale
  - starts network, SSH, cron, logging, etc.
  - eventually starts the display manager or getty (login prompt)
```

**macOS: launchd**
```
kernel starts → /sbin/launchd → PID 1

launchd:
  - reads plist files from /Library/LaunchDaemons/
  - starts system services
  - eventually starts the WindowServer (the GUI)
  - starts loginwindow
```

**Windows:**
```
ntoskrnl.exe (kernel) → smss.exe (Session Manager) → winlogon.exe, csrss.exe
→ services.exe (Service Control Manager) starts Windows services
→ winlogon.exe shows the login screen
→ explorer.exe starts after login (the desktop)
```

---

## Stage 5: Login

After the init system has started everything, you're presented with a way to log in:
- **TTY / getty** — text-mode login prompt in a terminal
- **Display manager** — graphical login screen (GDM on Linux, loginwindow on macOS, winlogon on Windows)

After a successful login, the OS starts a session for you — your shell (bash/zsh/PowerShell), your desktop environment, and eventually your applications.

---

## The Full Picture

```
Power on
  ↓
Firmware (BIOS/UEFI)       — hardware init, POST, find boot device
  ↓
Bootloader (GRUB/WBM)      — load kernel into RAM
  ↓
Kernel                     — initialize hardware, mount root filesystem
  ↓
PID 1 (systemd/launchd)    — start all system services
  ↓
Login prompt               — authenticate user
  ↓
Shell / Desktop            — ready to use
```

---

## Why This Matters

**"Why won't it boot?"** — knowing the stages tells you where to look:
- Beep codes / no video → firmware/POST stage
- "No bootable device" → firmware can't find bootloader
- "GRUB rescue" → bootloader can't find kernel
- Kernel panic → kernel initialization failure
- Stuck at loading screen → service startup failure (check systemd logs)

**Recovery mode** — most OSes can boot into a minimal mode by changing bootloader parameters:
- Linux: `single` or `rescue` at GRUB
- macOS: hold Cmd+R at startup (Recovery mode)
- Windows: F8 for Advanced Boot Options → Safe Mode

---

## Platform Notes

| | Linux | macOS | Windows |
|--|-------|-------|---------|
| Firmware | BIOS or UEFI | Apple Silicon Boot ROM / T2 chip | BIOS or UEFI |
| Bootloader | GRUB2 | Apple bootloader (no user interaction) | Windows Boot Manager |
| PID 1 | systemd (or SysV init, OpenRC) | launchd | smss.exe |
| Service config | Unit files in `/etc/systemd/system/` | Plist files in `/Library/LaunchDaemons/` | Registry + Services |
| Boot log | `journalctl -b` | `log show --last boot` | Event Viewer → System |

Deep dive:
- Linux boot process → `../linux/10-boot-process.md`

→ Next: `09-networking.md`
