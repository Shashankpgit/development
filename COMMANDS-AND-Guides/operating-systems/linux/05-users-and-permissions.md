# Operating Systems — 05: Users and Permissions

> **Last updated:** July 6, 2026
> **Who can do what to which file. The complete model: users, groups, UIDs, chmod, sudo, and why your app can't read its config.**

---

## Users in Linux

Every process runs as a user. Every file has an owner. The user model controls what processes can access.

```
Every user has:
  - Username (e.g., "ubuntu", "www-data", "root")
  - UID (User ID) — a number the kernel actually uses
  - GID (Primary Group ID)
  - Home directory (/home/ubuntu, /root, /var/www)
  - Login shell (/bin/bash, /usr/sbin/nologin, /bin/false)
```

### The Files That Define Users

```bash
# User accounts:
cat /etc/passwd
# Format: username:x:UID:GID:comment:home:shell
# ubuntu:x:1000:1000:Ubuntu:/home/ubuntu:/bin/bash
# www-data:x:33:33:www-data:/var/www:/usr/sbin/nologin
# root:x:0:0:root:/root:/bin/bash
# nobody:x:65534:65534:nobody:/nonexistent:/usr/sbin/nologin

# The 'x' in the password field means password is in /etc/shadow
sudo cat /etc/shadow
# ubuntu:$6$salt$hashedpassword:19180:0:99999:7:::
# Hashed password, last changed date, min/max age, etc.
# Only root can read this file.

# Groups:
cat /etc/group
# Format: groupname:x:GID:member1,member2
# sudo:x:27:ubuntu
# docker:x:999:ubuntu
# www-data:x:33:
```

### Viewing Your Own Identity

```bash
# Who are you?
whoami         # just the username
id             # UID, GID, and all groups

# Output of id:
# uid=1000(ubuntu) gid=1000(ubuntu) groups=1000(ubuntu),4(adm),27(sudo),999(docker)
# → You're ubuntu (UID 1000), primary group is ubuntu (GID 1000)
# → You're also in: adm (can read logs), sudo (can use sudo), docker (can run docker)
```

### Service Accounts (System Users)

Most services run as their own dedicated user with no login shell:

```bash
# www-data → nginx, Apache
# nobody   → minimal privilege processes
# postgres → PostgreSQL
# mysql    → MySQL
# ec2-user → Amazon Linux default user
# ubuntu   → Ubuntu AMI default user

# Create a service account (no home, no shell):
sudo useradd --system --no-create-home --shell /usr/sbin/nologin myapp

# Why: if an attacker compromises nginx (running as www-data),
# they can only do what www-data can do.
# They can't SSH in, can't read /root, can't write to /home.
```

### Managing Users

```bash
# Add a user:
sudo useradd -m -s /bin/bash newuser    # -m = create home, -s = shell
sudo passwd newuser                      # set password

# Add user to a group:
sudo usermod -aG sudo newuser            # -a = append (don't remove other groups)
sudo usermod -aG docker,nginx newuser    # add to multiple groups at once

# Remove a user:
sudo userdel -r newuser     # -r = also remove home directory

# List groups a user is in:
groups ubuntu
id ubuntu

# Switch to another user:
su - ubuntu     # switch and load their environment (the - matters)
sudo -u www-data bash   # open a shell as www-data

# NOTE: group changes take effect at next login
# If you add yourself to 'docker': log out and back in, or:
newgrp docker   # start a new shell with the new group active
```

---

## File Permissions — The Model

Every file has three sets of permissions: for the **owner**, for the **group**, and for **everyone else**.

```bash
ls -la /etc/nginx/nginx.conf
# -rw-r--r-- 1 root root 2347 Jul 05 14:22 /etc/nginx/nginx.conf

# Breakdown:
# -          = file type (- = regular, d = directory, l = symlink)
# rw-        = owner permissions (root can read+write)
# r--        = group permissions (root group can read)
# r--        = other permissions (everyone else can read)
# 1          = link count
# root       = owner
# root       = group owner
# 2347       = size in bytes
```

### Permission Bits

```
r = read    (4)  → file: read contents;  directory: list contents (ls)
w = write   (2)  → file: modify/delete;  directory: create/delete files in it
x = execute (1)  → file: run as program; directory: enter it (cd) and access files
- = not set (0)
```

```bash
# Numeric (octal) notation:
# rw-r--r-- = 110 100 100 binary = 6 4 4 octal = 644
# rwxr-xr-x = 111 101 101 binary = 7 5 5 octal = 755
# rw------- = 110 000 000 binary = 6 0 0 octal = 600
# rwx------ = 111 000 000 binary = 7 0 0 octal = 700

# Quick conversion:
# r=4, w=2, x=1, sum them per group:
# rwx = 4+2+1 = 7
# rw- = 4+2+0 = 6
# r-x = 4+0+1 = 5
# r-- = 4+0+0 = 4
# --- = 0+0+0 = 0
```

### Common Permission Patterns

```
644 (-rw-r--r--)  Config files, web content, documents
                  Owner can edit, everyone can read.

755 (drwxr-xr-x) Directories, scripts
                  Owner can do everything, others can enter and read.

600 (-rw-------)  Private keys, password files, .env files
                  ONLY owner can access.

700 (drwx------)  Private directories (ssh key directory: ~/.ssh)
                  Only owner can enter and list.

777 (drwxrwxrwx)  Everyone can do anything — AVOID except for /tmp-like directories.

640 (-rw-r-----)  Files that need to be read by a specific group but not everyone.
                  e.g. /etc/ssl/private/ readable by ssl-cert group
```

### chmod — Changing Permissions

```bash
# Numeric mode:
chmod 644 /etc/nginx/nginx.conf
chmod 755 /usr/local/bin/my-script.sh
chmod 600 ~/.ssh/id_rsa
chmod 700 ~/.ssh

# Symbolic mode (easier to read):
chmod u+x script.sh        # add execute for owner (u=user/owner)
chmod g+w /var/www         # add write for group
chmod o-r secret.txt       # remove read for others
chmod a+x script.sh        # add execute for all (a=all)
chmod ug=rw,o= file.txt    # owner+group: rw, others: nothing

# Recursive (for directories):
chmod -R 755 /var/www/html  # apply to all files and subdirectories

# Fix a common problem: files should be 644 but dirs should be 755:
find /var/www -type f -exec chmod 644 {} \;
find /var/www -type d -exec chmod 755 {} \;
```

### chown — Changing Ownership

```bash
# Change owner:
sudo chown ubuntu /home/ubuntu/file.txt

# Change owner + group:
sudo chown ubuntu:ubuntu /home/ubuntu/file.txt

# Change group only:
sudo chown :nginx /var/www/html

# Recursive:
sudo chown -R www-data:www-data /var/www/html

# Common real-world use:
# App files created by root, need to be readable by www-data:
sudo chown -R root:www-data /var/www/myapp
sudo find /var/www/myapp -type f -exec chmod 640 {} \;
sudo find /var/www/myapp -type d -exec chmod 750 {} \;
```

---

## Special Permission Bits

### setuid (s on user execute bit)

When a file has setuid, it runs as the **file owner** instead of the person who ran it.

```bash
# Classic example: /usr/bin/passwd
ls -la /usr/bin/passwd
# -rwsr-xr-x 1 root root 68208 Jul 01 /usr/bin/passwd
# Note: 's' instead of 'x' for owner execute

# passwd needs to write to /etc/shadow (owned by root, mode 640)
# If it ran as the regular user, it couldn't write there.
# Because of setuid: it temporarily runs as root → can write to /etc/shadow.
# It then validates that you're changing YOUR password, not someone else's.

# Set setuid:
sudo chmod u+s /usr/local/bin/myscript
# Or: chmod 4755 (the 4 at the front = setuid)
```

**Security warning:** Setuid binaries are a significant attack surface. If a setuid program has a vulnerability, an attacker can gain root privileges.

### setgid (s on group execute bit)

On a file: runs as the file's group.
On a directory: new files created inside inherit the directory's group.

```bash
# Useful for shared directories (team collaboration):
sudo mkdir /var/shared
sudo chgrp developers /var/shared
sudo chmod g+s /var/shared        # setgid on directory
# Now any file created in /var/shared will belong to 'developers' group
# regardless of which user created it

# Set setgid: chmod 2755 (the 2 = setgid)
```

### Sticky Bit (t on other execute bit)

On a directory: you can only delete files YOU own.

```bash
# This is why you can't delete other users' files in /tmp:
ls -la /
# drwxrwxrwt 17 root root 4096 Jul 06 /tmp
# Note: 't' at the end — everyone can write, but only owner can delete their files

# Set sticky bit:
sudo chmod +t /shared-dir
# Or: chmod 1777 /tmp (1 = sticky)
```

---

## sudo — Temporary Privilege Escalation

`sudo` (superuser do) lets specified users run commands as root (or another user).

```bash
# Run a command as root:
sudo apt update
sudo systemctl restart nginx
sudo rm /var/log/large.log

# Run as a different user:
sudo -u www-data ls /var/www

# Open a root shell:
sudo -i     # login shell (loads root's environment)
sudo -s     # non-login shell (keeps current environment)

# Run the last command as root:
sudo !!

# See what you're allowed to sudo:
sudo -l

# Output:
# Matching Defaults entries for ubuntu on ip-10-0-1-5:
#     env_reset, mail_badpass, secure_path=/usr/local/sbin:/usr/local/bin:...
# User ubuntu may run the following commands:
#     (ALL : ALL) ALL     ← ubuntu can run any command as any user
# Or:
#     (root) NOPASSWD: /usr/bin/systemctl restart nginx  ← specific command, no password
```

### /etc/sudoers — The sudo Configuration

```bash
# NEVER edit /etc/sudoers directly — use visudo (it validates before saving):
sudo visudo

# Key entries:
# root    ALL=(ALL:ALL) ALL
# %sudo   ALL=(ALL:ALL) ALL    ← everyone in sudo group can sudo everything
# %admin  ALL=(ALL) ALL

# Give a user specific commands without password:
ubuntu  ALL=(root) NOPASSWD: /usr/bin/systemctl restart nginx, /usr/bin/systemctl restart mysql

# Drop-in files (better than editing sudoers directly):
sudo visudo -f /etc/sudoers.d/myapp
# Contents:
# deploy  ALL=(root) NOPASSWD: /usr/bin/systemctl restart myapp

# Check sudoers syntax:
sudo visudo -c
```

---

## SSH Keys and Authentication

On EC2, you authenticate with SSH keys (not passwords by default).

```bash
# Your SSH key files:
~/.ssh/
  id_rsa          ← private key (chmod 600 — NEVER share)
  id_rsa.pub      ← public key (safe to share)
  authorized_keys ← public keys that can log in as YOU
  known_hosts     ← fingerprints of servers you've connected to

# The server's authorized_keys for ec2-user (Amazon Linux):
cat /home/ec2-user/.ssh/authorized_keys

# Add a new public key to allow another person to log in:
echo "ssh-rsa AAAA...pubkey... username@machine" >> ~/.ssh/authorized_keys

# Correct permissions (SSH won't work if wrong):
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
chmod 600 ~/.ssh/id_rsa
chmod 644 ~/.ssh/id_rsa.pub
```

---

## umask — Default Permissions for New Files

When a file is created, the OS applies `umask` to subtract permissions from the default.

```bash
# Default file creation mode: 666 (rw-rw-rw-)
# Default directory creation mode: 777 (rwxrwxrwx)
# umask is subtracted: default umask is 022

# 666 - 022 = 644 (rw-r--r--)  → new files get 644
# 777 - 022 = 755 (rwxr-xr-x)  → new directories get 755

umask           # see current umask (022 is typical)
umask 027       # stricter: new files = 640, new dirs = 750
                # Others can't read at all

# Set permanent umask in ~/.bashrc or /etc/profile:
echo "umask 027" >> ~/.bashrc

# Why it matters for services:
# A web server creating log files with umask 022 → world-readable logs
# Better: run the service with umask 027 (logs readable by group only)
# In systemd service: UMask=0027
```

---

## Practical: Debugging Permission Denied

```bash
# "Permission denied" — systematic investigation:

# Step 1: Who is the process running as?
ps aux | grep nginx
# www-data 1234 ...

# Step 2: What does the file/directory look like?
ls -la /etc/ssl/private/cert.pem
# -rw-r----- 1 root ssl-cert 1234 Jul 06 /etc/ssl/private/cert.pem
# Permissions: owner=root (rw), group=ssl-cert (r), others (none)

# Step 3: Is www-data in the ssl-cert group?
id www-data
# uid=33(www-data) gid=33(www-data) groups=33(www-data)
# → NOT in ssl-cert group!

# Step 4: Fix by adding to group:
sudo usermod -aG ssl-cert www-data
# Then restart nginx (to pick up new group membership)
sudo systemctl restart nginx

# Alternative fix: setfacl (don't change the group, add explicit ACL):
sudo setfacl -m u:www-data:r /etc/ssl/private/cert.pem

# Step 5: Trace what's happening with strace:
sudo strace -p $(pgrep nginx | head -1) 2>&1 | grep -E "open|EACCES|EPERM"
# Shows exact syscall and EACCES error when permission is denied
```

→ Continue to: `06-networking-from-os.md`
