# Part 02 — File & Directory Operations: touch, mkdir, cp, mv, rm, ln

These are the commands you use to create, copy, move, and delete files and directories. They seem simple but have important edge cases that trip people up constantly.

---

## `touch` — Create an Empty File (or Update Timestamps)

### Primary use — create a new empty file:

```bash
touch notes.txt
touch config.json
touch src/app.js
```

If the file already exists, `touch` updates its "last accessed" and "last modified" timestamps to right now — but does NOT change its content. If the file doesn't exist, `touch` creates it empty.

### Create multiple files at once:

```bash
touch index.html style.css app.js
touch file{1,2,3}.txt    # creates file1.txt, file2.txt, file3.txt (brace expansion)
```

### When do you use touch?

- Creating placeholder files before writing content
- Creating `.gitkeep` files in empty directories (Git ignores empty dirs)
- Making your Makefile think files were just updated (for build systems)

---

## `mkdir` — Create Directories

### Basic usage:

```bash
mkdir projects
mkdir /home/shashank/work/reports
```

### Create a full path at once (-p flag):

```bash
mkdir -p projects/vault-app/src/controllers
```

Without `-p`, if `projects/` doesn't already exist, this fails with "No such file or directory."
With `-p`, it creates every directory in the chain that doesn't exist yet. **Always use `-p` when creating nested paths.**

### Create multiple directories at once:

```bash
mkdir src tests docs
mkdir -p src/{controllers,models,middleware,routes}
# Creates:
# src/controllers/
# src/models/
# src/middleware/
# src/routes/
```

The `{a,b,c}` syntax (brace expansion) is a shell feature that expands into multiple values.

### Set permissions at creation time:

```bash
mkdir -m 755 public-folder     # creates with specific permissions
mkdir -m 700 private-folder    # owner-only access
```

---

## `cp` — Copy Files and Directories

### Copy a file:

```bash
cp source.txt destination.txt       # copy file, new name
cp config.json backup/config.json   # copy to different directory, same name
cp /etc/nginx/nginx.conf ~/nginx.conf.backup   # copy from system path to home
```

### Copy and keep filename, just change directory:

```bash
cp config.json /tmp/
# Result: /tmp/config.json
```

### Copy multiple files to a directory:

```bash
cp file1.txt file2.txt file3.txt /tmp/
cp *.txt /backup/            # copy all .txt files
```

### Copy a directory recursively (-r flag):

```bash
cp -r projects/ backup/projects/
```

Without `-r`, `cp` refuses to copy directories:
```
cp: -r not specified; omitting directory 'projects/'
```

With `-r`, it copies the entire directory tree.

### Preserve file attributes (-p flag):

```bash
cp -p important.conf backup/important.conf
```

`-p` preserves: timestamps, permissions, and ownership. Without it, the copy gets new timestamps and your current user as owner.

### Combine flags:

```bash
cp -rp source-dir/ destination-dir/    # recursive + preserve attributes
cp -rv source/ dest/    # -v shows each file as it's copied (verbose)
```

### Interactive mode — ask before overwriting:

```bash
cp -i source.txt destination.txt
# Asks: "overwrite destination.txt?" before replacing it
```

---

## `mv` — Move or Rename Files and Directories

`mv` does two things with one command: **move** (change location) and **rename** (same location, different name). Internally they're the same operation.

### Rename a file:

```bash
mv old-name.txt new-name.txt
mv app.js index.js
```

### Move a file to a different directory:

```bash
mv report.pdf ~/Documents/
mv temp-config.json /etc/myapp/config.json
```

### Move a directory:

```bash
mv old-folder/ new-folder/         # rename a directory
mv my-project/ ~/projects/         # move directory into another
```

Unlike `cp`, `mv` does NOT need `-r` for directories. It works on directories naturally.

### Move multiple files at once:

```bash
mv file1.txt file2.txt file3.txt /destination/
mv *.log /var/log/archive/
```

### Interactive mode — ask before overwriting:

```bash
mv -i source.txt destination.txt
# Asks before overwriting
```

### What mv actually does internally:

On the SAME filesystem (e.g., moving within `/home/`):
- `mv` just renames the directory entry — the actual file data doesn't move on disk
- This is why moving a 10GB file within the same disk is **instantaneous**

Across filesystems (e.g., `/home/` to `/mnt/usb/`):
- `mv` copies the data to the new location, then deletes the original
- Moving a 10GB file to a USB drive takes time proportional to file size

---

## `rm` — Remove Files and Directories

### Remove a file:

```bash
rm file.txt
rm /tmp/temp-output.json
```

**There is no Trash/Recycle Bin in Linux.** `rm` deletes permanently. The file is not recoverable from a bin. Once you run `rm`, the data is gone (technically still on disk until overwritten, but not accessible without forensic tools).

### Remove multiple files:

```bash
rm file1.txt file2.txt file3.txt
rm *.log              # remove all .log files in current dir
```

### Remove a directory and everything inside it:

```bash
rm -r old-project/
```

`-r` (recursive) is required for directories. Without it:
```
rm: cannot remove 'old-project/': Is a directory
```

### The infamous `rm -rf`:

```bash
rm -rf directory/
```

- `-r` = recursive (directories and their contents)
- `-f` = force (don't ask for confirmation, ignore errors about non-existent files)

This is the most dangerous command in Linux. There is no undo. Common accidental disasters:

```bash
# DISASTER: accidentally delete system root
rm -rf /         # Linux now protects this with --no-preserve-root guard
rm -rf / home/shashank/  # space before 'home' means: delete / AND delete home/shashank

# DISASTER: wrong directory
rm -rf ./           # delete EVERYTHING in current dir (if you're in / or /home)
```

**Always double-check with `ls` or `pwd` before `rm -rf`.**

### Interactive mode — ask before each deletion:

```bash
rm -ri directory/   # asks "remove file?" for each file
rm -i *.log         # asks before each
```

### Safe delete alternative — move to /tmp instead:

```bash
mv important-but-unsure/ /tmp/backup-important/
# If you need it back, it's in /tmp (cleared on reboot)
# If you don't, it auto-disappears on next reboot
```

---

## `rmdir` — Remove EMPTY Directories

```bash
rmdir empty-folder/
```

Only works on empty directories. If the directory has anything in it:
```
rmdir: failed to remove 'folder/': Directory not empty
```

This is actually useful as a safety check — `rmdir` can't accidentally delete your project. Use `rm -r` only when you're sure you want to delete the contents.

---

## `ln` — Create Links (Shortcuts)

Links are pointers to files. There are two types.

### Hard Link

A hard link is a second name for the same file data on disk. Both names point to exactly the same content.

```bash
ln original.txt hardlink.txt
```

```bash
ls -li      # -i shows inode number
# 1234567 -rw-r--r-- 2 shashank shashank 1024 Jun 14 original.txt
# 1234567 -rw-r--r-- 2 shashank shashank 1024 Jun 14 hardlink.txt
```

Same inode number (1234567) means they're the SAME file. The `2` in the third column means this inode has 2 hard links pointing to it.

If you delete `original.txt`, the data still exists and is accessible via `hardlink.txt` — the data is only deleted when the last hard link is removed.

**Limitation:** Hard links cannot span across filesystems or link to directories.

### Symbolic Link (Symlink) — The Commonly Used One

A symlink is like a shortcut. It contains a path pointing to another file or directory. It CAN cross filesystems and CAN link to directories.

```bash
ln -s /etc/nginx/nginx.conf ~/nginx-config    # creates a symlink in home dir
ln -s /var/www/html /home/shashank/web        # symlink to a directory
```

```bash
ls -la ~/nginx-config
# lrwxrwxrwx 1 shashank shashank 22 Jun 14 nginx-config -> /etc/nginx/nginx.conf
```

The `l` at the start and the `->` show it's a symlink pointing to the target.

**When you edit `nginx-config`, you're actually editing `/etc/nginx/nginx.conf`.** The symlink is transparent — reading/writing it reads/writes the target.

**Real use case:** Applications installed in `/usr/local/bin/myapp-v2.1.0` might have a symlink `/usr/local/bin/myapp -> /usr/local/bin/myapp-v2.1.0`. To upgrade, you just change where the symlink points — no need to update every script that calls `myapp`.

---

## Real-World Scenario: Setting Up a New Project Directory

```bash
# 1. Create the project structure
mkdir -p vault-app/{src/{controllers,models,routes,middleware},tests,docs,config}

# 2. Create initial files
touch vault-app/README.md
touch vault-app/src/app.js
touch vault-app/.gitignore
touch vault-app/config/default.json

# 3. Verify the structure
tree vault-app -L 3

# 4. Copy an existing config as starting template
cp /home/shashank/templates/node-gitignore vault-app/.gitignore

# 5. Rename a misnamed file
mv vault-app/src/app.js vault-app/src/index.js
```

---

## Common Misunderstanding: "`cp dir/` and `cp dir` behave the same"

**The misunderstanding:** "The trailing slash doesn't matter when copying directories."

**The reality:** With `cp -r`, the trailing slash changes what gets copied:

```bash
cp -r source/ destination/
# Copies the CONTENTS of source/ into destination/
# Result: destination/file1, destination/file2 ...

cp -r source destination/
# Copies the source DIRECTORY itself into destination/
# Result: destination/source/file1, destination/source/file2 ...
```

This is a frequent source of "why is there an extra directory?" confusion. The same applies to `rsync`. When in doubt, check with `ls` after copying.

---

→ Continue to: `03-viewing-and-editing-files.md`
