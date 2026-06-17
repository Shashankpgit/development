# Part 04 — Permissions and Ownership: chmod, chown, sudo, su

Permissions are where most beginners get completely lost. The `rwxr-xr-x` strings look like noise at first. But the system is logical and elegant once you understand it. This file explains it from first principles.

---

## The Core Idea: Three Actors, Three Actions

Every file and directory in Linux has a permission system with two components:

**Three actors (WHO):**
- **User (u)** — the owner of the file (usually whoever created it)
- **Group (g)** — a group of users (e.g., the `developers` group)
- **Others (o)** — everyone else on the system

**Three actions (WHAT):**
- **Read (r)** — view the contents
- **Write (w)** — modify/delete the file (or add/remove files in a directory)
- **Execute (x)** — run the file as a program (or enter the directory with `cd`)

---

## Reading the Permission String

```bash
ls -la
```

```
-rwxr-xr--  1  shashank  developers  4096  Jun 14  deploy.sh
│││││││││
│││││││└└─ Others: r-- (read only, can't write or execute)
│││││└└─── Group: r-x (read and execute, can't write)
│││└└───── User: rwx (read, write, execute — full access)
││└──────── special permission bits (advanced, not covered here)
│└───────── file type (- = file, d = directory, l = symlink)
└────────── file type (first character)
```

Reading in groups of 3:
```
- | rwx | r-x | r--
│    │     │     │
│    │     │     └── others: read only
│    │     └──────── group: read + execute
│    └────────────── user: read + write + execute
└─────────────────── file type
```

A `-` in a permission position means that permission is NOT granted.

---

## What Permissions Mean for Files vs Directories

This trips people up constantly because the same letters mean different things:

| Permission | On a FILE | On a DIRECTORY |
|-----------|-----------|----------------|
| `r` (read) | Read the file contents (`cat`, `less`) | List what's inside (`ls`) |
| `w` (write) | Modify the file contents | Add/remove files inside it |
| `x` (execute) | Run it as a program/script | Enter the directory (`cd` into it) |

**Key insight for directories:** You need `x` (execute) on a directory to `cd` into it. You need `r` on a directory to `ls` it. You need BOTH `r` and `x` to navigate AND list. This is why directories almost always have execute permission.

---

## The Numeric (Octal) Permission System

Each permission has a numeric value:
- `r` = 4
- `w` = 2
- `x` = 1
- `-` = 0

Each group (user/group/others) is the SUM of its permissions:

```
rwx = 4+2+1 = 7
r-x = 4+0+1 = 5
r-- = 4+0+0 = 4
---  = 0+0+0 = 0
rw- = 4+2+0 = 6
```

So `rwxr-xr--` = **7** (user) **5** (group) **4** (others) = **754**

### Common permission values you'll see all the time:

| Numeric | Symbolic | Meaning | Use for |
|---------|----------|---------|---------|
| `644` | `rw-r--r--` | Owner reads/writes, others read-only | Regular files, config files |
| `755` | `rwxr-xr-x` | Owner full, others read+execute | Scripts, executables, directories |
| `700` | `rwx------` | Owner only, nobody else | Private keys, secret configs |
| `600` | `rw-------` | Owner reads/writes only | SSH private key (`~/.ssh/id_ed25519`) |
| `777` | `rwxrwxrwx` | Everyone has full access | Never use this in production |
| `666` | `rw-rw-rw-` | Everyone reads/writes | Rarely needed |

---

## `chmod` — Change File Permissions

### Numeric mode (most common in practice):

```bash
chmod 755 deploy.sh       # make a script executable
chmod 644 config.json     # regular file permissions
chmod 600 ~/.ssh/id_ed25519   # SSH key must be 600 or SSH refuses to use it
chmod -R 755 /var/www/html/   # -R = recursive (apply to all files/dirs inside)
```

### Symbolic mode (more readable when making targeted changes):

```bash
chmod +x script.sh        # add execute for user+group+others
chmod -x script.sh        # remove execute for everyone
chmod u+x script.sh       # add execute for user only
chmod g+w shared-file     # add write for group
chmod o-r private.txt     # remove read from others
chmod u=rwx,g=rx,o=r file # set exact permissions explicitly
```

Symbolic mode operators:
- `+` — add permission
- `-` — remove permission
- `=` — set exact permission (overwriting what was there)

### The most common real scenarios:

```bash
# A script you created isn't running:
chmod +x myscript.sh
./myscript.sh   # now works

# SSH key permissions too open (SSH will refuse to use it):
chmod 600 ~/.ssh/id_ed25519

# Web server can't read uploaded files:
chmod 644 /var/www/html/uploaded-image.png

# Give a directory proper web permissions:
chmod -R 755 /var/www/html/

# Lock down a sensitive config file:
chmod 600 /etc/myapp/.env
```

---

## `chown` — Change File Ownership

### Change the owner of a file:

```bash
chown shashank file.txt
chown root /etc/nginx/nginx.conf     # give ownership to root
```

### Change owner AND group at once:

```bash
chown shashank:developers file.txt
# Format: chown user:group file
```

### Change group only:

```bash
chown :developers file.txt     # empty user means "don't change user"
# or equivalently:
chgrp developers file.txt
```

### Recursive ownership change:

```bash
chown -R shashank:shashank /home/shashank/projects/
chown -R www-data:www-data /var/www/html/    # give nginx user ownership of web files
```

### Who is `www-data`?

Web servers like Nginx and Apache run as a special system user called `www-data` (on Ubuntu/Debian). This user needs to read your web files. If your files are owned by `shashank` and `www-data` can't read them, nginx throws 403 Forbidden.

```bash
# Fix: give www-data ownership (or make files world-readable)
sudo chown -R www-data:www-data /var/www/html/
# or
sudo chmod -R 644 /var/www/html/*.html
```

---

## `sudo` — Run Commands as Root

You've seen `sudo` throughout this guide. Let's understand it properly.

```bash
sudo command            # run one command as root
sudo -u otheruser cmd   # run as a specific user (not root)
sudo -i                 # open a root shell session
sudo !!                 # re-run the last command with sudo
```

### The sudoers file — who can use sudo:

Not every user can run `sudo`. Authorized users are listed in `/etc/sudoers`. On Ubuntu, adding a user to the `sudo` group grants sudo access:

```bash
sudo usermod -aG sudo newuser    # add user to sudo group
```

### Check if your user can sudo:

```bash
sudo -l
# Lists what commands your user is allowed to run with sudo
```

---

## `su` — Switch User

```bash
su username        # switch to another user (need their password)
su -               # switch to root (need root password)
su - shashank      # switch to shashank with their full login environment
```

The difference between `su` and `sudo`:
- `su` switches your identity to another user — you ARE that user until you type `exit`
- `sudo` runs ONE command as another user, then returns to your normal identity

Modern Ubuntu disables the root account password by default. Use `sudo -i` or `sudo su` to get a root shell instead of `su -`.

---

## Real-World Scenario: "Permission Denied" Diagnosis

This is the most common problem you'll hit:

```bash
./start-server.sh
# bash: ./start-server.sh: Permission Denied
```

**Diagnosis:**
```bash
ls -la start-server.sh
# -rw-r--r-- 1 shashank shashank 512 Jun 14 start-server.sh
#   ^^^
#   No execute permission for anyone!
```

**Fix:**
```bash
chmod +x start-server.sh
./start-server.sh    # works now
```

Another common scenario:
```bash
cat /etc/shadow
# cat: /etc/shadow: Permission denied
```

```bash
ls -la /etc/shadow
# -rw-r----- 1 root shadow 1234 Jun 14 /etc/shadow
#             ^^^^
#             root owns it, group 'shadow' can read it — others (you) cannot
```

```bash
sudo cat /etc/shadow    # now works because sudo runs as root
```

---

## Common Misunderstanding: "chmod 777 fixes all permission problems"

**The misunderstanding:** "If I get Permission Denied, I'll just `chmod 777` the file/directory and it'll work."

**The reality:** `chmod 777` gives EVERY user on the system full read, write, and execute access. On a multi-user server or production system, this is a serious security vulnerability — any user, any script, any process can now modify that file.

The correct approach is to give the minimum permissions needed:

```bash
# Web server needs to read your files → 644 for files, 755 for directories
chmod -R 644 /var/www/html/
find /var/www/html -type d -exec chmod 755 {} \;

# Or: give the web server user ownership instead of opening permissions
sudo chown -R www-data:www-data /var/www/html/
```

`chmod 777` is sometimes used as a quick test to confirm that permissions are the problem. But it should be immediately followed by setting proper permissions once the issue is identified.

---

→ Continue to: `05-process-management.md`
