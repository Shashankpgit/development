# Part 12 — Compression and Archiving: tar, gzip, zip

Archiving bundles multiple files/directories into one file. Compression reduces file size. These two operations are often combined. This file demystifies `tar`, which has a notoriously cryptic syntax.

---

## The Difference: Archive vs Compression

- **Archive (tar)** — combines multiple files into ONE file. Does not compress. Like putting files in a box.
- **Compression (gzip, bzip2, xz)** — reduces file size. Works on one file. Like vacuum-sealing the box.
- **Archive + Compress (tar.gz)** — bundles files AND compresses. What you almost always want.

Common formats:
- `.tar` — archive only, no compression
- `.tar.gz` or `.tgz` — tar + gzip compression (most common on Linux)
- `.tar.bz2` — tar + bzip2 (better compression, slower)
- `.tar.xz` — tar + xz (best compression, slowest)
- `.zip` — Windows/cross-platform format (archive + compress in one)

---

## `tar` — The Archiving Tool

The flags for tar are confusing because they don't use dashes by default. Here's the key to understanding them:

```
c = Create   (make a new archive)
x = eXtract  (unpack an archive)
t = lisT     (show archive contents without extracting)
v = Verbose  (show each file being processed)
f = File     (the next argument is the archive filename — ALWAYS use this)
z = gZip     (compress/decompress with gzip)
j = bzip2    (compress/decompress with bzip2)
J = xz       (compress/decompress with xz)
```

### Creating archives:

```bash
# Create a .tar.gz archive (most common)
tar -czf archive.tar.gz directory/
tar -czf archive.tar.gz file1.txt file2.txt directory/

# Create with a specific compression level
tar -czf backup.tar.gz --use-compress-program="gzip -9" directory/

# Create without compression (just archiving)
tar -cf archive.tar directory/

# Create .tar.bz2 (better compression)
tar -cjf archive.tar.bz2 directory/
```

### Extracting archives:

```bash
# Extract .tar.gz to current directory
tar -xzf archive.tar.gz

# Extract to a specific directory
tar -xzf archive.tar.gz -C /destination/path/

# Extract .tar.bz2
tar -xjf archive.tar.bz2

# Extract .tar.xz
tar -xJf archive.tar.xz

# Extract a plain .tar (no compression)
tar -xf archive.tar
```

### List archive contents (without extracting):

```bash
tar -tzf archive.tar.gz           # list .tar.gz contents
tar -tjf archive.tar.bz2          # list .tar.bz2 contents
tar -tf archive.tar               # list .tar contents
```

### Extract a specific file from an archive:

```bash
tar -xzf archive.tar.gz path/to/specific/file.txt
```

---

## The `tar` Command Memory Trick

**Extract:** `tar -xzf file.tar.gz` — "eXtract Ze File"
**Create:** `tar -czf file.tar.gz dir/` — "Create Ze File"

Always end with `f` and then the filename. Always put `f` last in the flags.

---

## `gzip` / `gunzip` — Compress/Decompress Single Files

```bash
gzip file.txt              # compresses file.txt → file.txt.gz (original deleted)
gzip -k file.txt           # -k = keep original (don't delete it)
gzip -9 file.txt           # maximum compression (slowest)
gzip -1 file.txt           # minimum compression (fastest)

gunzip file.txt.gz         # decompress → file.txt (file.txt.gz deleted)
gzip -d file.txt.gz        # same as gunzip
```

`gzip` only works on a single file. For multiple files or directories, use `tar -czf`.

---

## `zip` / `unzip` — Cross-Platform Archives

Use `.zip` when you need to share files with Windows users or when the recipient may not have `tar`.

```bash
# Create a zip archive
zip archive.zip file1.txt file2.txt
zip -r archive.zip directory/        # -r = recursive (include directories)

# Add to an existing zip
zip archive.zip newfile.txt

# List contents
unzip -l archive.zip

# Extract
unzip archive.zip                    # extract to current directory
unzip archive.zip -d /destination/   # extract to specific directory
unzip archive.zip specific-file.txt  # extract one file

# Extract with password
unzip -P secretpassword archive.zip
```

---

## Real-World Scenarios

### Backup a project directory with a timestamp:

```bash
tar -czf "vault-app-backup-$(date +%Y-%m-%d).tar.gz" vault-app/
# Creates: vault-app-backup-2026-06-14.tar.gz
```

### Transfer a directory to a server (compress, transfer, extract):

```bash
# On local machine: create the archive
tar -czf project.tar.gz my-project/

# Transfer to server
scp project.tar.gz user@server:/home/user/

# On server: extract it
ssh user@server "tar -xzf /home/user/project.tar.gz -C /home/user/"
```

### Compress log files to save disk space:

```bash
gzip /var/log/nginx/access.log.1
# Creates access.log.1.gz

# Or with tar (combine and compress multiple old logs):
tar -czf logs-archive-2026-05.tar.gz /var/log/nginx/*.log.* && rm /var/log/nginx/*.log.*
```

---

## Common Misunderstanding: "`tar -czf` and `gzip` are the same"

**The misunderstanding:** "Both compress files, so they're interchangeable."

**The reality:**
- `gzip file.txt` — compresses ONE file, cannot handle directories
- `tar -czf archive.tar.gz dir/` — bundles MULTIPLE files/directories into one package AND compresses it

For a single file: `gzip` is simpler.
For a directory or multiple files: you MUST use `tar` (with `z` for gzip compression).

This is why almost everyone uses `tar -czf` — it works for both files and directories and is the standard "bundle and compress" tool.

---

→ Continue to: `13-user-management.md`
