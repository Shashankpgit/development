# Filesystems

---

## The Problem

A storage device (SSD, HDD) is just a large array of bytes at numbered addresses. There are no "files" or "folders" at the hardware level — just raw blocks of data.

A **filesystem** is the layer the OS adds on top to give that raw storage the concept of files, directories, names, and metadata.

Different filesystems organize this data differently — that's why you have ext4 (Linux), APFS (macOS), NTFS (Windows), and others.

---

## What a Filesystem Stores

For every file, a filesystem needs to track:

```
Data:      the actual bytes of the file
Metadata:
  - Name
  - Size
  - Type (file vs directory)
  - Permissions (who can read/write/execute)
  - Owner (which user owns it)
  - Timestamps (created, modified, accessed)
  - Location (where on disk are the data blocks?)
```

The key insight: **the file name and the file data are stored separately**. A file's name lives in a directory entry. The file's actual data and metadata live in a separate structure.

On Unix-based systems (Linux, macOS), this separate structure is called an **inode**.

---

## Inodes

An **inode** (index node) is a data structure that stores everything about a file *except its name*.

```
Directory entry:    "README.md"  →  inode #4827
                                          ↓
inode #4827:    size: 2048 bytes
                owner: shashank
                permissions: rw-r--r--
                modified: 2026-07-04
                data blocks: [block 1081, block 1082]
                                          ↓
block 1081:     # README.md\nThis is the content...
block 1082:     ...rest of content
```

The directory doesn't store the file data — it just maps names to inode numbers. The inode points to the actual data blocks on disk.

This separation enables two interesting features:

**Hard links** — two directory entries pointing to the same inode. The file has two names but one set of data. The inode stores a reference count — the data is only deleted when all names are removed.

```
"file.txt"   →  inode #4827
"backup.txt" →  inode #4827  (same inode, same data)
```

**Symbolic links** — a file that contains a path to another file (like a shortcut or alias). Different from a hard link — it's its own inode pointing to a path string, not directly to another inode.

---

## Directory Tree

The filesystem organizes everything into a tree. There is one root, and every file and directory is reachable from it.

```
/ (root)
├── etc/         (configuration files)
│   └── nginx/
│       └── nginx.conf
├── home/
│   └── shashank/
│       └── projects/
│           └── myapp/
└── var/
    └── log/
        └── syslog
```

On Linux/macOS, there is exactly one root: `/`.  
On Windows, each drive has its own root: `C:\`, `D:\`, etc.

A **path** is how you describe a file's location in this tree:
- **Absolute path**: starts from root — `/home/shashank/projects/myapp/server.js`
- **Relative path**: starts from current location — `../config/settings.json`

---

## Mounting

On Linux/macOS, additional storage devices don't get a new letter — they get **mounted** into the existing tree.

```
Main disk:            /
USB drive mounted at: /mnt/usb

/mnt/usb/photos/  → the photos folder on the USB drive
```

When you mount a filesystem, its root becomes reachable at the mount point. When you unmount it, it disappears from the tree. This is why you should unmount a USB drive before physically removing it — the OS may have cached writes that haven't been flushed yet.

---

## Journaling

Filesystems face a reliability problem: what if the power goes out mid-write? You might end up with half-written data — corrupting the filesystem.

**Journaling** solves this. Before making changes to the filesystem, the OS writes a description of the intended change to a **journal** (a special area on disk). Then it makes the actual change. If power cuts out mid-change, on next boot the OS reads the journal and either completes or rolls back the incomplete operation.

This is why modern filesystems (ext4, NTFS, APFS, XFS) survive power failures cleanly.

---

## Common Filesystems

| Filesystem | Used on | Key feature |
|-----------|---------|-------------|
| ext4 | Linux | Reliable, journaled, default on most Linux distros |
| XFS | Linux (RHEL/CentOS default) | High performance for large files |
| Btrfs | Linux | Snapshots, copy-on-write, checksumming |
| APFS | macOS | Copy-on-write, snapshots, optimized for SSDs |
| HFS+ | Older macOS | Legacy (pre-2017 Macs) |
| NTFS | Windows | ACL permissions, journaling, large file support |
| exFAT | USB drives | Cross-platform compatible (Linux/macOS/Windows) |
| FAT32 | Old USB drives | Universal but max 4GB file size |
| tmpfs | Linux | RAM-backed filesystem (very fast, lost on reboot) |

---

## File Permissions

Every file has an owner and a set of permissions controlling who can read, write, or execute it.

On Linux/macOS (Unix permission model):

```
-rw-r--r--  1  shashank  staff  2048  Jul 4  server.js

 ↑           ↑  ↑         ↑
 │           │  Owner     Group
 │           Link count
 │
 rw-r--r--:
   rw-  → owner (shashank) can read and write
   r--  → group (staff) can only read
   r--  → everyone else can only read
```

On Windows, permissions are more complex — each file has an ACL (Access Control List) with explicit allow/deny entries per user or group.

---

## Platform Notes

| | Linux | macOS | Windows |
|--|-------|-------|---------|
| Default filesystem | ext4 | APFS | NTFS |
| Root | `/` single root | `/` single root | `C:\`, `D:\` per drive |
| Metadata structure | inode | inode (APFS) | MFT record (NTFS) |
| Permissions model | rwx (owner/group/others) | rwx + ACLs | NTFS ACLs |
| Mounting | `mount` command, `/etc/fstab` | Automount + `diskutil` | Drive letters, automatic |
| Case sensitivity | Case-sensitive | Case-insensitive by default | Case-insensitive |

Deep dives:
- Linux filesystem and inodes → `../linux/04-filesystem-and-inodes.md`
- macOS APFS and filesystem quirks → `../macos/02-filesystem-and-apfs.md`
- Windows NTFS and permissions → `../windows/02-filesystem-and-registry.md`

→ Next: `06-io-and-devices.md`
