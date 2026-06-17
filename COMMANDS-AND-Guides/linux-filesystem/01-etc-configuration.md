# The Linux Filesystem — Part 01: /etc — Where All Configuration Lives

`/etc` is the heart of Linux system configuration. Every service, every daemon, every system setting is controlled by a text file somewhere in `/etc`. Understanding this directory is fundamental for any server administration work.

---

## What Is /etc?

The name historically stands for "etcetera" but is now commonly (and more helpfully) understood as **"Editable Text Configuration."**

**The core rule:** `/etc` contains configuration files only — no binaries, no data. Just text files (and sometimes subdirectories of text files) that control how programs behave.

```bash
ls /etc
```

```
adduser.conf     crontab       hostname     nsswitch.conf   resolv.conf
apt/             default/      hosts        nginx/          shadow
bash.bashrc      environment   hosts.allow  os-release      ssh/
cron.d/          fstab         hosts.deny   passwd          ssl/
cron.daily/      group         locale.conf  profile         sudoers
crontab          gshadow       logrotate.d/ profile.d/      systemd/
```

---

## The Most Important Files in /etc (Real-World Use)

### `/etc/hosts` — Override DNS Locally

```bash
cat /etc/hosts
```

```
127.0.0.1    localhost
127.0.1.1    ubuntu-server
::1          localhost ip6-localhost ip6-loopback

# Custom entries (you add these):
192.168.1.100   db.internal
10.0.0.5        api.internal
```

**What it does:** Before asking DNS, the OS checks this file. If a hostname is listed here, it uses that IP — no DNS lookup happens.

**Real use cases:**
- Map internal server names to IPs on your LAN (no DNS server needed)
- Block websites by pointing their domain to `127.0.0.1`
- Override a DNS entry locally during development (`127.0.0.1 api.myapp.com` so your laptop hits your local API instead of production)
- Test a website before DNS has propagated after a migration

```bash
# To add an entry (opens in editor):
sudo nano /etc/hosts
```

---

### `/etc/hostname` — Your Machine's Name

```bash
cat /etc/hostname
# ubuntu-server
```

This is the machine's hostname — the name it uses to identify itself on the network. Change it with:

```bash
sudo hostnamectl set-hostname new-server-name
```

---

### `/etc/resolv.conf` — DNS Server Configuration

```bash
cat /etc/resolv.conf
```

```
nameserver 8.8.8.8        ← use Google's DNS
nameserver 8.8.4.4        ← fallback DNS
search internal.company.com  ← try adding this suffix to unqualified names
```

When you type `ping db` (without a full domain), the OS tries `db.internal.company.com` because of the `search` line.

**Note on Ubuntu:** In modern Ubuntu, `/etc/resolv.conf` is managed by `systemd-resolved`. Edit `/etc/systemd/resolved.conf` to change DNS settings permanently.

---

### `/etc/passwd` — User Account Database

```bash
cat /etc/passwd
```

```
root:x:0:0:root:/root:/bin/bash
daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin
shashank:x:1000:1000:Shashank Patil:/home/shashank:/bin/bash
www-data:x:33:33:www-data:/var/www:/usr/sbin/nologin
nginx:x:118:128:nginx user:/nonexistent:/bin/false
```

Each line is 7 fields separated by `:`:
```
username : password : UID : GID : comment/full name : home dir : default shell
```

- **UID** — User ID number. Root is always 0. System users: 1-999. Regular users: 1000+.
- **password** — Shows `x`, meaning the actual password hash is in `/etc/shadow` (for security)
- **home dir** — `/var/www` for www-data (it doesn't have a real home), `/home/shashank` for you
- **shell** — `/usr/sbin/nologin` means this account CANNOT be used for interactive login (security measure for service accounts)

This file is readable by everyone because programs need to look up usernames. But the passwords are in `/etc/shadow`, which only root can read.

---

### `/etc/shadow` — Password Hashes (Root Access Only)

```bash
sudo cat /etc/shadow
```

```
shashank:$6$salt$hashedpassword...:19155:0:99999:7:::
```

The actual password hashes (not plaintext passwords) are here. Only root can read it. When you change your password with `passwd`, it updates this file.

---

### `/etc/group` — Group Definitions

```bash
cat /etc/group
```

```
root:x:0:
sudo:x:27:shashank
docker:x:998:shashank,priya
developers:x:1001:shashank,rahul,priya
```

Format: `group_name:password:GID:member1,member2,...`

Checking which groups you belong to:
```bash
groups                    # your groups
groups shashank           # specific user's groups
id                        # detailed: uid, gid, all groups
```

---

### `/etc/fstab` — Filesystem Mount Configuration

This file tells Linux which filesystems to mount at boot and where.

```bash
cat /etc/fstab
```

```
# <device>         <mount point>   <type>   <options>           <dump> <pass>
UUID=abc123-...    /               ext4     errors=remount-ro   0      1
UUID=def456-...    /data           ext4     defaults            0      2
UUID=ghi789-...    /mnt/backup     ext4     defaults,nofail     0      2
tmpfs              /tmp            tmpfs    defaults,size=2G    0      0
```

When you want a drive to auto-mount at boot (e.g., your second data disk), you add an entry here.

---

### `/etc/ssh/sshd_config` — SSH Server Configuration

```bash
cat /etc/ssh/sshd_config | grep -v "^#" | grep -v "^$"
```

Key settings:
```
Port 22                          ← SSH listens on this port
PermitRootLogin prohibit-password ← don't allow root login with password
PasswordAuthentication no        ← force SSH key auth (more secure)
PubkeyAuthentication yes         ← allow SSH key login
AllowUsers shashank ubuntu       ← only these users can SSH
MaxAuthTries 3                   ← lock out after 3 failed attempts
```

After changing `/etc/ssh/sshd_config`:
```bash
sudo systemctl restart sshd   # restart SSH to apply changes
```

**Critical:** Always test your new SSH config in a SECOND session before closing the first. If you misconfigure it and lock yourself out, you'll lose access.

---

### `/etc/nginx/` — Nginx Web Server Configuration

```bash
ls /etc/nginx/
```

```
conf.d/             ← additional config files included by nginx.conf
nginx.conf          ← main nginx configuration
sites-available/    ← virtual host config files (available but not active)
sites-enabled/      ← symlinks to configs in sites-available (these are active)
snippets/           ← reusable config fragments
```

**The sites-available / sites-enabled pattern:**

```bash
# 1. Create a virtual host config
sudo nano /etc/nginx/sites-available/vault-app

# 2. Enable it by creating a symlink
sudo ln -s /etc/nginx/sites-available/vault-app /etc/nginx/sites-enabled/vault-app

# 3. Test config before reloading
sudo nginx -t

# 4. Apply
sudo systemctl reload nginx

# 5. To disable: remove the symlink (doesn't delete the config)
sudo rm /etc/nginx/sites-enabled/vault-app
```

This pattern lets you have many site configs and activate/deactivate them without deleting anything.

---

### `/etc/cron.d/` and `/etc/crontab` — Scheduled Tasks

```bash
cat /etc/crontab
```

```
# m  h  dom mon dow  user    command
17  *   *   *   *   root    cd / && run-parts --report /etc/cron.hourly
25  6   *   *   *   root    test -x /usr/sbin/anacron || run-parts --report /etc/cron.daily
47  6   *   1   *   root    test -x /usr/sbin/anacron || run-parts --report /etc/cron.weekly
```

Cron fields: `minute hour day-of-month month day-of-week`

```
*    = any value
*/5  = every 5 units
1-5  = range from 1 to 5
1,3,5 = specific values
```

---

### `/etc/environment` — System-Wide Environment Variables

```bash
cat /etc/environment
```

```
PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
JAVA_HOME="/usr/lib/jvm/java-17-openjdk"
NODE_ENV="production"
```

Variables here are available to ALL users and ALL processes at login.

---

### `/etc/profile` and `/etc/profile.d/` — System-Wide Shell Config

`/etc/profile` runs for all users at login. Put system-wide shell configuration here.

`/etc/profile.d/` contains `.sh` files that are all sourced by `/etc/profile`. This is where packages drop their environment setup:

```bash
ls /etc/profile.d/
# apps.sh  bash_completion.sh  java.sh  nodejs.sh
```

---

## Real-World Scenario: "Configure a New Server"

Here's the actual sequence for setting up a fresh Ubuntu server:

```bash
# 1. Update hostname
sudo hostnamectl set-hostname prod-web-01

# 2. Update /etc/hosts to know itself
sudo nano /etc/hosts
# Add: 127.0.1.1 prod-web-01

# 3. Secure SSH (no password auth, no root login)
sudo nano /etc/ssh/sshd_config
# Set: PasswordAuthentication no
# Set: PermitRootLogin no
sudo systemctl restart sshd

# 4. Create application user
sudo useradd -m -s /bin/bash appuser
sudo usermod -aG sudo appuser

# 5. Set up nginx
sudo apt install nginx
sudo nano /etc/nginx/sites-available/myapp
sudo ln -s /etc/nginx/sites-available/myapp /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx

# 6. Set timezone
sudo timedatectl set-timezone Asia/Kolkata
ls -la /etc/localtime   # it's a symlink to the timezone file
# /etc/localtime -> ../usr/share/zoneinfo/Asia/Kolkata
```

---

## Common Misunderstanding: "Editing /etc files is dangerous"

**The misunderstanding:** "I shouldn't touch files in /etc — they're system files."

**The reality:** `/etc` files are MEANT to be edited by administrators. That's their entire purpose. The key practices:

1. **Always make a backup before editing:** `sudo cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak`
2. **Validate config before applying:** `sudo nginx -t`, `sudo sshd -t`
3. **Test in a second terminal before closing your SSH session** (for SSH config changes)
4. **Use version control:** Many sysadmins keep `/etc` in a git repo (using tools like etckeeper)

The config files being plain text is what makes them safe — you can always `cat` them, `diff` them, and restore from backup. No binary formats, no registries.

---

→ Continue to: `02-var-variable-data.md`
