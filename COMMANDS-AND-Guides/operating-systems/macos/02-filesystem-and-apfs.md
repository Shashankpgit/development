# macOS — 02: Filesystem and APFS

> **Last updated:** July 7, 2026
> **APFS, Spotlight, SIP, extended attributes, and how macOS handles files differently from Linux.**

---

## APFS — Apple File System

macOS uses **APFS (Apple File System)**, introduced in 2017 to replace the aging HFS+.

Key APFS features:

```
Space Sharing     → Multiple volumes share a pool of storage
                    (no fixed partitions — each volume grows as needed)

Cloning           → Instant file/directory copies (zero additional space used at first)
                    cp uses copy-on-write — clones share blocks until one changes

Snapshots         → Point-in-time read-only snapshots of a volume
                    Time Machine uses APFS snapshots

Encryption        → Native per-file or full-disk encryption
                    FileVault 2 is built on APFS encryption

Case sensitivity  → APFS can be case-sensitive or case-insensitive
                    Default macOS: case-INSENSITIVE (File.txt = file.txt = FILE.TXT)
```

**Case insensitivity is a major gotcha for developers:**

```bash
# On macOS (default):
touch hello.txt
ls HELLO.TXT        # finds it! case doesn't matter
cat Hello.TXT       # works

# On Linux (ext4):
touch hello.txt
ls HELLO.TXT        # No such file
```

This causes "works on Mac, breaks in production (Linux)" bugs when filenames differ only in case.

---

## Disk Utility and diskutil

```bash
# List all disks and volumes
diskutil list

# Output:
# /dev/disk0 (internal):
#    1: GUID_partition_scheme  *500.1 GB  disk0
#    2: Apple_APFS_ISC          524.3 MB  disk0s1
#    3: Apple_APFS              494.4 GB  disk0s2    (your macOS volume)
#    4: Apple_APFS_Recovery     5.4 GB    disk0s3

# Get APFS container info
diskutil apfs list

# Show disk info
diskutil info /dev/disk0s2

# Mount/unmount volumes
diskutil mount /dev/disk2s1
diskutil unmount /Volumes/MyDisk

# Check and repair disk (run from Recovery Mode for system disk)
diskutil verifyVolume /
diskutil repairVolume /Volumes/MyDisk
```

---

## Spotlight — macOS Search Index

**Spotlight** is a system-wide search engine that indexes file contents, metadata, emails, contacts, apps, and more.

```bash
# Search from command line using mdfind (Spotlight's CLI)
mdfind "error 503"              # search file contents
mdfind -name "server.log"       # search by filename
mdfind -onlyin ~/Downloads .zip # search only in a directory
mdfind "kMDItemKind == 'PDF Document'"  # search by type

# Get file metadata (what Spotlight indexed)
mdls ~/Documents/report.pdf
# kMDItemDisplayName     = "report.pdf"
# kMDItemFSSize          = 245760
# kMDItemContentCreationDate = 2026-07-01T10:00:00Z
# kMDItemAuthors         = ("Shashank")

# Rebuild Spotlight index (fix slow/broken search)
sudo mdutil -E /       # erase and rebuild index for root volume
sudo mdutil -a -i on   # enable indexing on all volumes
mdutil -s /            # check indexing status
```

---

## .DS_Store Files

**.DS_Store** is a hidden file macOS creates in every folder you open in Finder. It stores folder view settings (icon positions, column widths, background image).

```bash
# .DS_Store shows up everywhere — inside git repos, on USB drives, etc.

# Remove all .DS_Store files recursively
find . -name ".DS_Store" -delete

# Prevent .DS_Store on network drives (not local drives)
defaults write com.apple.desktopservices DSDontWriteNetworkStores true

# Add to .gitignore so they're never committed
echo ".DS_Store" >> ~/.gitignore_global
git config --global core.excludesfile ~/.gitignore_global
```

---

## SIP — System Integrity Protection

**SIP (System Integrity Protection)** was introduced in OS X El Capitan (2015). It prevents even the root user from modifying certain protected system files and directories.

Protected locations (even root can't write here):
```
/System/
/sbin/
/usr/ (except /usr/local/)
/bin/
```

```bash
# Check SIP status
csrutil status
# System Integrity Protection status: enabled.

# Disable SIP (requires Recovery Mode — rare, not recommended)
# Boot into Recovery Mode: hold Cmd+R on Intel / hold power on Apple Silicon
# Open Terminal in Recovery Mode:
# csrutil disable

# Re-enable SIP
# csrutil enable
```

**You almost never need to disable SIP.** If a tutorial tells you to disable SIP, find a better tutorial.

---

## Extended Attributes

macOS adds **extended attributes** (xattr) to files — extra metadata beyond the standard owner/group/permissions.

```bash
# See extended attributes on a file
xattr /path/to/file
# com.apple.quarantine

# Quarantine attribute — set when you download a file from the internet
# macOS shows "This app was downloaded from the internet" warning
# Gatekeeper checks this attribute

# Remove quarantine attribute (when you're sure the file is safe)
xattr -d com.apple.quarantine /path/to/app.dmg
# or remove all extended attributes:
xattr -c /path/to/file

# List all attributes with values
xattr -l /path/to/file

# Common extended attributes:
# com.apple.quarantine    → downloaded from internet
# com.apple.FinderInfo    → Finder display settings
# com.apple.ResourceFork  → legacy resource fork data
```

---

## macOS Permissions vs Linux

The core Unix permissions work the same (owner/group/others, rwx, chmod, chown). macOS adds two things:

### ACLs (Access Control Lists)

More fine-grained permissions than owner/group/others:

```bash
# See ACLs on a file
ls -le /path/to/file
# -rw-r--r--+ 1 shashank staff 1234 Jul 7 10:00 file.txt
#             ↑ the + means ACLs are present

# View the ACL
ls -le file.txt
# 0: user:shashank allow read,write,execute,delete

# Add an ACL entry
chmod +a "jane allow read" file.txt

# Remove an ACL
chmod -a "jane allow read" file.txt

# Remove all ACLs
chmod -N file.txt
```

### Flags

Files can have flags in addition to permissions:

```bash
# View flags
ls -lO file.txt
# -rw-r--r-- 1 shashank staff uchg 1234 file.txt
#                                  ↑ "uchg" = user immutable

# Common flags:
# uchg (user immutable)   → user can't change even with write permission
# schg (system immutable) → only root can change (requires SIP disabled)
# hidden                  → hidden from Finder/ls

# Set a flag
chflags uchg file.txt     # make immutable
chflags nouchg file.txt   # remove immutable flag
chflags hidden file.txt   # hide from Finder
```

---

## Useful File Commands (macOS-specific)

```bash
# Open a file with its default app (like double-clicking in Finder)
open file.pdf
open https://example.com    # opens in default browser
open -a "Safari" file.html  # open with specific app
open .                      # open current directory in Finder

# Reveal a file in Finder
open -R /path/to/file

# Quick Look preview (space bar preview)
qlmanage -p file.pdf

# Get/set file metadata
GetFileInfo file.txt        # creation date, type, creator
SetFile -d "07/07/2026 10:00:00" file.txt  # set creation date

# Compress/archive
zip -r archive.zip folder/
unzip archive.zip
tar -czf archive.tar.gz folder/    # same as Linux

# Securely empty trash (old HFS+ — APFS handles this at hardware level)
rm -P sensitive-file.txt    # overwrite before deleting
```

→ Continue to: `03-processes-and-launchd.md`
