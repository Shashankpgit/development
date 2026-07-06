# Operating Systems — 07: Storage and Disks

> **Last updated:** July 6, 2026
> **Block devices, partitions, mount, and how AWS EBS volumes actually appear in Linux.**

---

## The Storage Stack

From physical disk to a file you can open, there are several layers:

```
Your App
    ↓
File (open("/data/db.sqlite"))
    ↓
Filesystem (ext4, xfs — manages files, directories, permissions)
    ↓
Block Device (/dev/nvme0n1p1 — a partition)
    ↓
Block Device (/dev/nvme0n1 — the whole disk)
    ↓
Storage driver (NVMe driver in the kernel)
    ↓
Physical or virtual disk (EBS volume, NVMe SSD, HDD)
```

Each layer provides an abstraction. You can swap them out (different filesystems, different disks) without changing your app.

---

## Block Devices

A block device is a file in `/dev/` that represents a storage device. It exposes a fixed-size, random-access byte array.

```bash
# List all block devices:
lsblk

# Output on a typical EC2 instance:
# NAME        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS
# nvme0n1     259:0    0    20G  0 disk
# └─nvme0n1p1 259:1    0    20G  0 part /         ← root partition, mounted at /
# nvme1n1     259:2    0   100G  0 disk            ← attached EBS, not partitioned yet
# xvda          8:0    0    20G  0 disk            ← older EC2 uses this naming

# With filesystem type:
lsblk -f

# NAME        FSTYPE FSVER LABEL UUID                                 MOUNTPOINTS
# nvme0n1
# └─nvme0n1p1 xfs          /     abc-123-...                          /
# nvme1n1                                                              (no filesystem yet)
```

### Device Naming

```
NVMe (modern EC2, m5, c5, r5, etc.):
  nvme0n1    → first NVMe device
  nvme0n1p1  → first partition of nvme0n1
  nvme1n1    → second NVMe device (second EBS volume)

Xen virtual disk (older EC2 instance types like m3):
  xvda       → first virtual disk
  xvda1      → first partition
  xvdb, xvdc → additional EBS volumes

SATA/SCSI (physical servers, not EC2):
  sda        → first disk
  sda1       → first partition
  sdb        → second disk
```

---

## Partitions

A **partition** divides a disk into independent regions. Each partition can have its own filesystem.

```bash
# View partition table:
sudo fdisk -l /dev/nvme1n1
# Disk /dev/nvme1n1: 100 GiB, 107374182400 bytes, 209715200 sectors
# Disk model: Amazon Elastic Block Store
# Disklabel type: gpt
# ... (no partitions if brand new)

# Create a partition (interactive):
sudo fdisk /dev/nvme1n1
# Commands:
# n → new partition
# p → primary
# 1 → partition number 1
# (accept defaults for start/end to use whole disk)
# w → write and exit

# Or non-interactive with parted:
sudo parted /dev/nvme1n1 --script mklabel gpt mkpart primary xfs 0% 100%
```

**For a single-purpose EBS volume, skip partitioning.** Create the filesystem directly on `/dev/nvme1n1` (not on a partition). It's simpler:

```bash
# Format the whole disk directly (no partition):
sudo mkfs.xfs /dev/nvme1n1

# Mount it:
sudo mkdir /data
sudo mount /dev/nvme1n1 /data
```

---

## Formatting and Mounting a New EBS Volume

This is the complete workflow for adding an EBS volume to EC2:

```bash
# Step 1: Attach the EBS volume in AWS Console
# (or via CLI: aws ec2 attach-volume --volume-id vol-xxx --instance-id i-xxx --device /dev/sdf)

# Step 2: Find the device name (may differ from what AWS shows):
lsblk
# Look for the new device — usually nvme1n1 for the second volume

# Step 3: Check if it has a filesystem already:
sudo file -s /dev/nvme1n1
# If output is just "data" → no filesystem, proceed to format
# If output shows "XFS filesystem" → already formatted, just mount

# Step 4: Format (ONLY if new/empty — this DESTROYS existing data):
sudo mkfs.xfs /dev/nvme1n1      # use xfs for Amazon Linux (default)
sudo mkfs.ext4 /dev/nvme1n1     # use ext4 for Ubuntu

# Step 5: Create mount point:
sudo mkdir -p /data

# Step 6: Get the UUID (stable identifier, better than /dev/nvme1n1):
sudo blkid /dev/nvme1n1
# /dev/nvme1n1: UUID="a1b2c3d4-e5f6-..." TYPE="xfs"

# Step 7: Mount:
sudo mount /dev/nvme1n1 /data
# Or by UUID:
sudo mount UUID="a1b2c3d4-e5f6-..." /data

# Step 8: Make it survive reboots — add to /etc/fstab:
sudo nano /etc/fstab
# Add:
UUID=a1b2c3d4-e5f6-...  /data  xfs  defaults,nofail  0  2

# Step 9: Verify:
df -h /data
# /dev/nvme1n1  100G  1.5G  99G  2% /data

# Step 10: Set ownership (if needed):
sudo chown -R ubuntu:ubuntu /data
```

---

## Checking Disk Space

```bash
# Disk space by filesystem:
df -h
# Filesystem      Size  Used Avail Use% Mounted on
# /dev/nvme0n1p1   20G   12G  7.7G  61% /
# /dev/nvme1n1    100G  1.2G   99G   2% /data
# tmpfs           7.7G     0  7.7G   0% /dev/shm

# Disk space usage by directory:
du -sh /var/log/         # total size of /var/log
du -sh /var/log/*        # size of each item in /var/log
du -sh /* 2>/dev/null    # size of each top-level dir

# Find the largest directories (top 10):
du -h / 2>/dev/null | sort -rh | head -10

# Find large files:
find / -type f -size +100M 2>/dev/null -exec ls -lh {} \;
# Or:
find / -type f -size +100M -printf '%s %p\n' 2>/dev/null | sort -rn | head -20
```

---

## LVM — Logical Volume Manager

LVM adds a layer of abstraction between physical disks and filesystems, enabling resizing, snapshots, and combining multiple disks.

```
Physical disks (PV):   /dev/nvme1n1  /dev/nvme2n1
                              ↓
Volume Group (VG):          my-vg         (pool of all physical storage)
                              ↓
Logical Volumes (LV):  /dev/my-vg/data    (flexible partitions)
                        /dev/my-vg/logs
                              ↓
Filesystems:            ext4 on /data, xfs on /logs
```

```bash
# Is LVM in use?
sudo pvdisplay    # physical volumes
sudo vgdisplay    # volume groups
sudo lvdisplay    # logical volumes

# Create an LVM setup:
sudo pvcreate /dev/nvme1n1              # mark as PV
sudo vgcreate my-vg /dev/nvme1n1       # create VG
sudo lvcreate -L 80G -n data my-vg     # create 80GB LV
sudo mkfs.xfs /dev/my-vg/data          # format
sudo mount /dev/my-vg/data /data       # mount

# Extend an LV when you add more disks:
sudo pvcreate /dev/nvme2n1              # add new disk as PV
sudo vgextend my-vg /dev/nvme2n1        # add to VG
sudo lvextend -L +50G /dev/my-vg/data   # extend LV by 50GB
sudo xfs_growfs /data                   # expand filesystem to fill LV
# (for ext4: sudo resize2fs /dev/my-vg/data)
```

**When LVM is worth it:**
- You have multiple physical disks to combine
- You need online resize (expanding without unmounting)
- You want filesystem snapshots for backups

**When it's not worth it:**
- Single EBS volume on EC2 — you can just resize the EBS volume and grow the filesystem directly (simpler)

---

## Resizing an EBS Volume (Without LVM)

AWS lets you resize an EBS volume while the instance is running.

```bash
# Step 1: Resize the EBS volume in AWS Console (or CLI)
# aws ec2 modify-volume --volume-id vol-xxx --size 200

# Step 2: After AWS reports resize complete, check in the OS:
lsblk
# nvme0n1: shows new size (200GB)
# nvme0n1p1: still shows old size (20GB) — partition hasn't grown yet

# Step 3: Grow the partition (if using partition + filesystem):
sudo growpart /dev/nvme0n1 1    # grow partition 1 to fill the disk

# Step 4: Grow the filesystem to fill the partition:
sudo xfs_growfs /               # for XFS (can be done while mounted!)
# or for ext4:
sudo resize2fs /dev/nvme0n1p1   # for ext4

# If the filesystem is directly on the disk (no partition):
sudo xfs_growfs /data           # just grow the filesystem
```

This is live, zero-downtime — no unmounting required (for XFS and ext4 online resize).

---

## RAID (Brief Overview)

**RAID** (Redundant Array of Independent Disks) combines multiple disks for redundancy or performance.

```
RAID 0: Striping — data spread across disks for speed. No redundancy.
        2× 500GB → 1TB usable, 2× read/write speed
        One disk fails → all data lost

RAID 1: Mirroring — identical copies on all disks.
        2× 500GB → 500GB usable, writes to both
        One disk fails → still works

RAID 5: Striping + parity — N disks, N-1 usable, 1 can fail.
        4× 500GB → 1.5TB usable, survives 1 disk failure

RAID 10: Mirroring + Striping. Performance + redundancy.
         4× 500GB → 1TB usable, survives 1+ disk failure
```

**On AWS:** EBS already handles redundancy internally — you don't need RAID for data safety. RAID 0 is sometimes used on EC2 with multiple EBS volumes for maximum IOPS.

---

## Performance Monitoring for Disk

```bash
# Live I/O stats (1 second interval):
iostat -xz 1

# Output:
# Device   r/s    w/s   rMB/s wMB/s  await r_await w_await  util
# nvme0n1  5.00  20.00   0.04  0.31   0.60    0.50    0.63   2.0%

# Key columns:
# r/s, w/s     = reads/writes per second
# rMB/s, wMB/s = throughput in MB/s
# await        = average I/O time (ms) — should be < 10ms for SSD
# r_await/w_await = separate read/write latency
# util%        = how busy the device is (100% = saturated → bottleneck)

# Check EBS volume type limits:
# gp3: 125 MB/s base, 3000 IOPS base (can configure higher)
# io2: up to 64,000 IOPS (for high-performance databases)

# Watch disk I/O in real time:
iotop -o     # only show processes doing I/O
# (sudo apt install iotop  or  sudo dnf install iotop)
```

---

## /proc/mounts and /proc/diskstats

```bash
# All current mounts (kernel view, more accurate than /etc/fstab):
cat /proc/mounts

# Disk I/O statistics (what iostat reads from):
cat /proc/diskstats
# 259  0 nvme0n1 12345 678 1234567 45678 ...
# Fields: major minor name reads_completed reads_merged sectors_read time_reading ...
```

---

## tmpfs — RAM as a Filesystem

`tmpfs` is a filesystem stored in RAM. Reading/writing it is as fast as RAM (not disk).

```bash
# /tmp and /run are usually tmpfs:
mount | grep tmpfs
# tmpfs on /tmp type tmpfs (rw,nosuid,nodev,size=7901740k)
# tmpfs on /run type tmpfs (rw,nosuid,nodev,size=1580348k,mode=755)

# Create your own tmpfs (useful for temp data in high-performance scenarios):
sudo mount -t tmpfs -o size=2G tmpfs /mnt/fast-scratch
df -h /mnt/fast-scratch
# tmpfs           2.0G     0  2.0G   0% /mnt/fast-scratch

# WARNING: All data in tmpfs is lost on reboot or unmount.
# Use for: build artifacts, temporary processing files, test databases
```

---

## Disk I/O Scheduler

The I/O scheduler decides the order in which I/O requests are sent to the disk.

```bash
# See current scheduler:
cat /sys/block/nvme0n1/queue/scheduler
# [none] mq-deadline kyber bfq

# For NVMe SSDs on EC2: "none" is usually optimal
# (NVMe SSDs have their own internal queue management)

# For HDDs: "mq-deadline" or "bfq" can improve performance
echo "mq-deadline" | sudo tee /sys/block/sda/queue/scheduler
```

→ Continue to: `08-package-management.md`
