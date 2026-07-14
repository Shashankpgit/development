# Operating Systems — 10: The Boot Process

> **Last updated:** July 6, 2026
> **What happens from the moment power turns on to when you can log in. BIOS → GRUB → Kernel → systemd → Login.**

---

## Overview: The Boot Sequence

```
1. Power On
   ↓
2. BIOS / UEFI  (firmware on the motherboard)
   → POST (Power On Self Test): check CPU, RAM, devices
   → Find bootable device
   ↓
3. Bootloader (GRUB2)
   → Loaded from the bootable device's boot sector
   → Loads the Linux kernel into memory
   ↓
4. Kernel Initialization
   → Decompresses itself
   → Detects hardware, loads drivers
   → Mounts initramfs (temporary root filesystem)
   ↓
5. initramfs
   → Contains minimal tools to find and mount the real root filesystem
   → Loads storage drivers (nvme, ext4, xfs, etc.)
   → Mounts the real root filesystem
   ↓
6. systemd (PID 1)
   → First process on the real root filesystem
   → Reads unit files, resolves dependencies
   → Starts all services in the right order
   ↓
7. Login Prompt (or SSH daemon accepting connections)
```

On AWS EC2, the BIOS/GRUB steps happen in milliseconds (or are abstracted by the hypervisor). The visible part starts at the kernel.

---

## Stage 1: BIOS vs UEFI

**BIOS** (Basic Input/Output System) — old firmware:
- Runs from read-only chip on the motherboard
- Maximum disk size: 2TB (MBR limitation)
- Slower to initialize
- Boot sector: first 512 bytes of the disk (MBR — Master Boot Record)

**UEFI** (Unified Extensible Firmware Interface) — modern firmware:
- Supports 9ZB disks (GPT partition table)
- Faster boot (can load drivers in parallel)
- Secure Boot (verifies bootloader is signed by a trusted key)
- Boot from a special EFI System Partition (ESP, mounted at /boot/efi)

On EC2, AWS uses UEFI for modern instance types (M6, C6, etc.). You don't interact with it directly.

---

## Stage 2: GRUB2 — The Bootloader

**GRUB** (GNU GRand Unified Bootloader) is the bootloader installed on your disk. Its job: load the kernel.

### Where GRUB Lives

```
MBR systems:  GRUB is in the first 512 bytes of the disk
              (before the first partition)

UEFI systems: GRUB is in /boot/efi/EFI/ubuntu/ or /boot/efi/EFI/amzn/
              as a .efi file

GRUB config:
  /boot/grub/grub.cfg          → Main generated config (don't edit manually)
  /etc/default/grub            → Edit this to change GRUB settings
  /etc/grub.d/                 → Scripts that generate grub.cfg
```

### GRUB Configuration

```bash
# View GRUB settings:
cat /etc/default/grub

# Key settings:
# GRUB_TIMEOUT=5                → show boot menu for 5 seconds
# GRUB_DEFAULT=0                → boot first entry by default
# GRUB_CMDLINE_LINUX="..."      → kernel parameters passed at boot

# After editing /etc/default/grub:
sudo update-grub        # Ubuntu — regenerates /boot/grub/grub.cfg
sudo grub2-mkconfig -o /boot/grub2/grub.cfg  # Amazon Linux

# Common kernel parameters you'll see:
# quiet splash           → minimal boot output
# ro                     → mount root read-only initially
# net.ifnames=0          → use old interface names (eth0 instead of ens5)
# console=ttyS0,115200   → serial console output (AWS uses this for EC2 console)
# selinux=0              → disable SELinux (common on Amazon Linux for some setups)
```

### The GRUB Menu

When you boot, GRUB shows a menu of kernels to boot (if GRUB_TIMEOUT > 0):
```
Ubuntu (kernel 6.5.0-41)
Ubuntu (kernel 6.5.0-35) — previous version
Ubuntu recovery mode
```

This is why you keep the previous kernel: if a new kernel breaks something, you can boot the old one.

```bash
# List installed kernels:
ls /boot/vmlinuz*
# vmlinuz-5.15.0-1057-aws
# vmlinuz-5.15.0-1056-aws

# After a kernel update on Ubuntu, old kernels are kept but can be cleaned:
sudo apt autoremove   # removes old kernel packages
```

---

## Stage 3: Kernel Initialization

After GRUB loads the kernel into memory:

```
1. Kernel decompresses itself (vmlinuz is compressed)

2. Architecture-specific initialization:
   - Set up CPU registers
   - Enable virtual memory (MMU)
   - Initialize the interrupt table (IDT)

3. Hardware detection:
   - Walk the ACPI tables (hardware descriptor tables from BIOS/UEFI)
   - Initialize detected devices
   - Load built-in device drivers

4. Memory setup:
   - Identify all RAM regions
   - Set up the physical memory allocator
   - Set up virtual memory

5. Mount initramfs as root filesystem:
   - initramfs is a compressed cpio archive embedded in the kernel image
   - or passed separately by GRUB as initrd
   - This becomes the temporary root /
```

```bash
# See kernel messages from boot:
dmesg
dmesg | grep -i error
dmesg | head -50         # early boot messages

# Or from the journal:
journalctl -k            # kernel messages
journalctl -k -b         # kernel messages from current boot
journalctl -b -1 -k      # kernel messages from previous boot (good for crash debugging)
```

---

## Stage 4: initramfs (Initial RAM Filesystem)

The problem: to mount the root filesystem (ext4 on an NVMe disk), the kernel needs the NVMe driver and the ext4 driver. But those drivers are on the root filesystem. Chicken-and-egg problem.

**Solution:** initramfs — a small, temporary root filesystem (stored in RAM) that contains just enough to:
1. Load the necessary storage drivers
2. Find the real root partition
3. Mount it
4. Pivot root (switch from initramfs to real root)
5. Hand off to the real `/sbin/init` (systemd)

```bash
# View initramfs contents:
lsinitramfs /boot/initrd.img-$(uname -r) | head -30

# Update initramfs (needed after driver changes):
sudo update-initramfs -u         # Ubuntu
sudo dracut --force              # Amazon Linux / RHEL

# When is this needed?
# - You add a new storage driver (rare)
# - You change root filesystem encryption
# - Kernel update automatically handles this
```

---

## Stage 5: systemd as PID 1

After initramfs mounts the real root and executes `/sbin/init` (which is systemd):

```bash
# Verify systemd is PID 1:
ps -p 1 -o comm=
# systemd

cat /proc/1/cmdline | tr '\0' ' '
# /sbin/init  (which is /lib/systemd/systemd)

ls -la /sbin/init
# lrwxrwxrwx 1 root root 20 /sbin/init -> /lib/systemd/systemd
```

### systemd Boot Sequence

```
systemd starts
  ↓
Reads /etc/systemd/system/default.target (usually multi-user.target)
  ↓
Resolves dependency graph for that target
  ↓
Starts all required units in correct order:
  local-fs.target     → all local filesystems mounted
  network.target      → basic network configured
  network-online.target → network fully up (includes DHCP, DNS)
  syslog.service      → logging started
  ssh.service         → SSH daemon started
  nginx.service       → your web server started
  ... etc.
```

```bash
# See what systemd started and in what order:
systemd-analyze plot > /tmp/boot.svg   # visual timeline (open in browser)
systemd-analyze                        # just the timings
# Startup finished in 2.015s (kernel) + 4.321s (userspace) = 6.337s

systemd-analyze blame                  # which unit took the most time
# 3.200s cloud-init.service
# 1.100s apt-daily-upgrade.service
# 0.500s ssh.service

systemd-analyze critical-chain         # the critical path to reach default target
```

---

## What You'll See on EC2 After Boot

On an EC2 instance, the typical boot sequence outputs to the serial console, visible in the AWS console (Actions → Monitor → Get System Log):

```
[    0.000000] Linux version 5.15.0-1057-aws ...
[    0.000000] Command line: BOOT_IMAGE=/boot/vmlinuz-5.15.0-1057-aws ...
[    0.xxx] Initializing cgroup subsys cpuset
...
[    2.xxx] cloud-init[1234]: Cloud-init v. 23.x starting ...
[    3.xxx] Starting OpenBSD Secure Shell server...
[    4.xxx] Started OpenBSD Secure Shell server.
[    4.xxx] cloud-init[1234]: Setting up the instance hostname
...
[   10.xxx] cloud-init[1234]: Cloud-init finished
```

---

## cloud-init — EC2's First-Boot Magic

`cloud-init` is a service that runs on EC2 instances at first boot to configure the instance:
- Set hostname
- Create the default user (ubuntu, ec2-user)
- Install your SSH public key (`~/.ssh/authorized_keys`)
- Execute User Data scripts (your startup scripts)
- Configure networking, locale, etc.

```bash
# cloud-init logs:
sudo cat /var/log/cloud-init.log
sudo cat /var/log/cloud-init-output.log   # output from your User Data script

# Cloud-init status:
cloud-init status
# status: done  (all phases completed successfully)

# Force cloud-init to re-run (e.g., to re-run User Data):
sudo cloud-init clean
sudo cloud-init init
# WARNING: this will re-create the ubuntu user, re-run all setup — careful!

# Cloud-init configuration:
cat /etc/cloud/cloud.cfg
```

---

## Kernel Parameters That Matter on EC2

These appear in `/proc/cmdline` (what the kernel was booted with):

```bash
cat /proc/cmdline
# BOOT_IMAGE=/boot/vmlinuz-5.15.0-1057-aws root=UUID=abc123 ro console=tty1 console=ttyS0,115200 nvme_core.io_timeout=4294967295

# Key parameters:
# root=UUID=abc123          → which partition is root
# ro                        → mount root read-only initially (systemd remounts rw)
# console=ttyS0,115200      → serial console output (EC2 console uses this)
# nvme_core.io_timeout=4294967295  → NVMe timeout (AWS sets this for EBS reliability)
```

---

## Debugging a Machine That Won't Boot

On EC2, if an instance won't boot:

```bash
# Step 1: Check the system log in AWS Console
# EC2 → Instance → Actions → Monitor and troubleshoot → Get system log
# Read the last few hundred lines — the error is usually there

# Step 2: Use EC2 Serial Console (newer instances):
# EC2 → Instance → Connect → EC2 Serial Console
# You get a root shell before the system fully boots

# Step 3: Stop the instance, detach the root EBS volume
# Attach it to a working instance as a data volume (/dev/sdf)
# Mount it: sudo mount /dev/nvme1n1p1 /mnt/recovery
# Inspect logs: cat /mnt/recovery/var/log/...
# Fix the issue (wrong fstab entry, broken config, etc.)
# Unmount, detach, reattach as root, start instance

# Common boot failures:
# /etc/fstab error     → system can't mount filesystems → emergency mode
# Bad kernel parameter → kernel panics
# Missing /sbin/init   → kernel panics "No init found"
# Filesystem corruption → fsck runs at boot, may require manual intervention
```

---

## Quick Reference: Boot Commands

```bash
# Check last boot time:
who -b
systemctl show --property=KernelBoot

# Uptime:
uptime
# 10:35:42 up 5 days, 2:11, 1 user, load average: 0.15, 0.20, 0.18

# Reboot:
sudo reboot
sudo systemctl reboot

# Shutdown:
sudo shutdown -h now     # halt immediately
sudo shutdown -h +10     # halt in 10 minutes
sudo shutdown -r now     # reboot immediately

# Boot into recovery mode (next boot only):
sudo systemctl reboot --boot-loader-entry=recovery
```

→ Continue to: `11-os-in-practice.md`
