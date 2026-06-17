# The Linux Filesystem — Part 06: /dev, /tmp, /run — Devices and Special Directories

---

## `/dev` — Hardware as Files

`/dev` contains **device files** — the physical manifestation of the "everything is a file" philosophy. Every hardware device you have is represented as a file here.

```bash
ls /dev
```

```
disk/    input/    loop0    null    pts/    random    sda    sdb    tty    urandom    zero
```

---

## Block Devices (Storage)

Block devices handle data in "blocks" (chunks) — your hard drives, SSDs, USB drives.

### Understanding Device Naming

```
/dev/sda          ← first SATA/SCSI/SSD drive ("sd" = SCSI disk, "a" = first)
/dev/sdb          ← second drive
/dev/sdc          ← third drive (or USB drive)
/dev/sda1         ← first PARTITION on the first drive
/dev/sda2         ← second partition on the first drive
/dev/nvme0n1      ← first NVMe drive (newer naming for NVMe SSDs)
/dev/nvme0n1p1    ← first partition on first NVMe drive
```

```bash
# List all block devices in a readable tree:
lsblk

# Output:
# NAME        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
# sda           8:0    0    20G  0 disk
# ├─sda1        8:1    0    19G  0 part /
# └─sda2        8:2    0     1G  0 part [SWAP]
# sdb           8:16   0   500G  0 disk
# └─sdb1        8:17   0   500G  0 part /mnt/data
```

### Reading/Writing to Devices Directly

Because devices are files, you can do extraordinary things:

```bash
# Create an exact bit-for-bit copy of a drive (disk imaging):
sudo dd if=/dev/sda of=/mnt/backup/sda-image.img bs=4M status=progress

# Write zeros to completely erase a drive:
sudo dd if=/dev/zero of=/dev/sdb bs=4M status=progress

# dd is powerful and dangerous — if= is "input file", of= is "output file"
# Reversing them (writing to if= instead of of=) can destroy your OS
```

---

## The Most Important Special Device Files

### `/dev/null` — The Bit Bucket

`/dev/null` is a black hole. Anything written to it disappears. Reading from it gives you nothing (EOF immediately).

```bash
# Suppress all output from a command:
command 2>/dev/null          # suppress error output only
command > /dev/null 2>&1     # suppress ALL output (stdout + stderr)

# Real use: run a cron job silently
*/5 * * * * /usr/local/bin/check-health.sh > /dev/null 2>&1

# Read from /dev/null gives empty/nothing:
cat /dev/null    # immediately exits, no output
```

### `/dev/zero` — Infinite Zeros

Reading `/dev/zero` gives an infinite stream of zero bytes (`\0`). Useful for:
- Wiping drives (overwrite with zeros)
- Creating files of a specific size for testing

```bash
# Create a 1GB file full of zeros (for testing disk space or benchmarking):
dd if=/dev/zero of=test-1gb-file.bin bs=1M count=1024
```

### `/dev/random` and `/dev/urandom` — Random Number Generators

```bash
# Generate random bytes (read exactly 16 bytes, show as hex):
head -c 16 /dev/urandom | xxd -p
# a3f2c891b45e7d20f619a3c8...

# Generate a random password:
head -c 32 /dev/urandom | base64 | head -c 20
# VZN4r2XjkL9Pw8mQnU3s
```

The difference:
- `/dev/random` — truly random, but can "block" (pause) if the system runs low on entropy. Best for key generation.
- `/dev/urandom` — cryptographically secure, never blocks, uses a CSPRNG. Best for almost everything.

### `/dev/stdin`, `/dev/stdout`, `/dev/stderr`

```bash
echo "hello" > /dev/stdout   # write to standard output (same as echo "hello")
cat /dev/stdin               # read from standard input until Ctrl+D
```

### Terminal Devices (`/dev/tty`, `/dev/pts/`)

```bash
ls /dev/pts/
# 0    1    2    ptmx

# Each number is an active terminal session
# Your current terminal:
tty
# /dev/pts/1   (you're terminal session 1)

# Write to another user's terminal (they're on pts/2):
echo "meeting in 10 mins" > /dev/pts/2
```

---

## Disk Information Commands

```bash
# List all disks and partitions:
lsblk -f      # -f shows filesystem type and UUIDs

# Output:
# NAME        FSTYPE LABEL UUID                                 MOUNTPOINT
# sda
# ├─sda1      ext4         abc123-...                           /
# └─sda2      swap         def456-...                           [SWAP]

# Show disk model, size, serial number:
sudo fdisk -l /dev/sda
sudo hdparm -I /dev/sda    # detailed drive information
```

---

## `/tmp` — Temporary Files

`/tmp` is for temporary files that programs create during their operation. It's cleared on every reboot.

```bash
ls /tmp/
# systemd-private-xxx/    snap.firefox/    random-temp-files...
```

### Who uses /tmp?

- Programs creating temporary work files (downloads in progress, extracted archives)
- Compilers storing intermediate files
- Package managers during installation
- Your scripts and pipelines

### The Important Properties of /tmp

**1. Cleared on reboot** — never put anything in `/tmp` that you need to keep across reboots.

**2. World-writable with sticky bit:**

```bash
ls -la / | grep tmp
# drwxrwxrwt  ...  tmp
#         ^
#         t = sticky bit
```

The `t` (sticky bit) on `/tmp` means: anyone can create files here, but **you can only delete your own files**. Even though the directory is world-writable, user A can't delete user B's files. Without the sticky bit, any user could delete any other user's temp files.

**3. tmpfs — may live in RAM:**

```bash
df -h /tmp
# tmpfs    3.9G  128M  3.7G   4%  /tmp
```

On many Linux systems, `/tmp` is a `tmpfs` — it actually lives in RAM, not on disk. This makes it very fast but means it counts against your RAM.

---

## `/run` — Runtime Data

`/run` (mounted as tmpfs, exists in RAM) holds data that processes need while running — PID files, sockets, and other runtime state. It's cleared at boot, unlike `/var/run` (historical).

```bash
ls /run/
# docker/    lock/    nginx.pid    postgresql/    sshd.pid    systemd/    user/
```

```bash
cat /run/nginx.pid
# 834

cat /run/sshd.pid
# 562
```

Programs write their PID here so other processes can find them. When you run `sudo systemctl stop nginx`, systemd reads `/run/nginx.pid` to know which process to signal.

---

## Real-World Scenario: "How Do I Know Which Drive Is My USB?"

You plug in a USB drive. How do you find it?

```bash
# Method 1: Watch for new devices
sudo dmesg | tail -20
# [1234.567] usb 1-1: new high-speed USB device
# [1234.890] scsi host3: usb-storage
# [1235.234] sd 3:0:0:0: [sdc] 62557184 512-byte logical blocks: (32.0 GB/29.8 GiB)
# → It's /dev/sdc

# Method 2: lsblk before and after plugging in (compare output)
lsblk
# Before: sda, sdb
# After:  sda, sdb, sdc  ← this is the USB

# Method 3: Check dmesg
dmesg | grep "sd[a-z]:" | tail -5

# Mount it:
sudo mkdir -p /mnt/usb
sudo mount /dev/sdc1 /mnt/usb
ls /mnt/usb/

# When done, unmount:
sudo umount /mnt/usb
```

---

## Common Misunderstanding: "/dev/null deletes files like rm"

**The misunderstanding:** "I can use `/dev/null` to delete files — just redirect the file to /dev/null."

**The reality:** Redirecting TO `/dev/null` (`> /dev/null`) discards the OUTPUT of a command. It does not delete files.

```bash
cat secret.txt > /dev/null    # reads secret.txt and discards the output
                               # secret.txt STILL EXISTS on disk!

rm secret.txt                 # THIS deletes the file
```

`/dev/null` is a trash can for command output (text, bytes being processed through a pipeline). It has nothing to do with file deletion on disk.

---

→ Continue to: `07-real-world-navigation.md`
