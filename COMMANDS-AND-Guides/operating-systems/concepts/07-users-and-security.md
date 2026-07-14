# Users and Security

---

## Why the OS Needs a Security Model

Without security, any program could:
- Read any file on disk (passwords, private keys, other users' data)
- Kill any other process
- Modify the OS itself
- Listen on any network port

The OS prevents this by enforcing rules about **who** can do **what**.

---

## Users and the Identity System

Every process runs under a **user identity**. The OS uses this identity to decide what the process is allowed to do.

```
User:     shashank  (UID 1000)
Process:  python server.py  running as shashank
→ can access files owned by shashank
→ cannot access /root (owned by root)
→ cannot bind to port 80 (only root can bind ports below 1024)
```

On Unix systems (Linux, macOS), each user has:
- A **UID** (User ID) — a number the kernel uses internally
- A **username** — the human-readable name
- A **primary group** (GID)
- Membership in additional groups

On Windows, users have a **SID** (Security Identifier) — a long unique identifier.

The kernel doesn't actually care about names — it tracks UIDs/GIDs internally. When you log in as `shashank`, the OS looks up your UID and attaches it to every process you start.

---

## Root / Administrator — The Superuser

Every OS has a special privileged user that the kernel treats differently:

- **Linux/macOS:** `root` (UID 0)
- **Windows:** `Administrator` (or the Administrators group)

Root/Administrator bypasses most permission checks. Root can:
- Read any file
- Kill any process
- Modify system configuration
- Load kernel modules / drivers

Running as root is dangerous — a bug or exploit in any program you run gives an attacker full system control. Best practice: never run as root normally. Use `sudo` / UAC only when needed.

---

## File Permissions

The most visible part of OS security is file permissions — controlling who can read, write, or execute a file.

### Unix Permission Model (Linux / macOS)

Every file has three sets of permissions: **owner**, **group**, **others**.

```
-rw-r--r--  shashank  staff  secrets.txt

 Type: - (regular file), d (directory), l (symlink)
 Owner permissions: rw-  (read + write, no execute)
 Group permissions: r--  (read only)
 Others:            r--  (read only)
```

Permission bits:
- `r` (read) — can read the file's contents
- `w` (write) — can modify the file
- `x` (execute) — can run the file as a program (for directories: can enter and list)

For a process to access a file:
1. If the process's UID matches the file's owner → apply owner permissions
2. Else if the process's GID matches the file's group → apply group permissions
3. Else → apply other permissions

**Executable permission on directories** is special: without `x`, you can't `cd` into a directory or access files within it — even if you know their names.

### Windows NTFS ACL Model

Windows uses a richer model: each file has an **Access Control List (ACL)** — a list of entries, each explicitly granting or denying specific permissions to a specific user or group.

```
config.json:
  [Allow]  SYSTEM:          Full Control
  [Allow]  Administrators:  Full Control
  [Allow]  shashank:        Modify
  [Deny]   Everyone:        Write
```

More expressive than Unix's model, but also more complex to reason about.

---

## Privilege Levels — Kernel vs User Mode

The OS enforces a hard boundary between code running with kernel privileges and user code:

```
Kernel mode (Ring 0):  full hardware access, no restrictions
User mode  (Ring 3):  restricted — cannot touch hardware directly, cannot access other processes
```

This boundary is enforced by the CPU itself, not just software. Even `root` on Linux runs in user mode — it can make powerful system calls, but the kernel still validates every request.

The only way to gain kernel-level access is to load a **kernel module** (Linux) or a **driver** (Windows). This is why malware that loads drivers is particularly dangerous.

---

## Privilege Escalation

Users can temporarily gain higher privileges to perform administrative tasks:

### sudo (Linux / macOS)
```
shashank (regular user) runs: sudo apt install nginx
→ OS prompts for shashank's password
→ OS checks /etc/sudoers: is shashank allowed to run apt as root?
→ If yes: runs apt with UID 0 (root)
→ When apt exits: back to shashank's privileges
```

`sudo` grants root-level privileges for one command. The kernel still tracks who actually ran it (audit logging).

### UAC — User Account Control (Windows)
```
User clicks "Install nginx"
→ Windows shows a UAC prompt: "Allow this app to make changes?"
→ User clicks Yes
→ Windows grants the installer admin privileges
→ Installer exits: privileges drop back to standard user
```

### setuid Bit (Linux / macOS)
Some programs need root access without the user having to `sudo`. The **setuid bit** makes a program run as its file owner (often root), regardless of who launches it.

```
/usr/bin/passwd  → setuid root
  You (user) run passwd to change your password
  → it runs as root, so it can write /etc/shadow
  → but it's carefully written to only change your own password
```

This is a powerful mechanism but also a security risk if the setuid program has bugs.

---

## What Happens When Security Is Violated?

If a process tries to access something it's not allowed to:
- Reading a file without permission → `Permission denied` (errno EACCES)
- Accessing another process's memory → Segfault / Access Violation (process killed)
- Binding a privileged port (< 1024) as non-root → `Permission denied`
- Calling a restricted syscall → the kernel blocks it and returns an error

The kernel never lets a violation silently succeed — it always either denies or kills the process.

---

## Platform Notes

| | Linux | macOS | Windows |
|--|-------|-------|---------|
| Superuser | `root` (UID 0) | `root` (UID 0) | Administrator |
| Privilege escalation | `sudo` | `sudo` | UAC prompt |
| Permission model | rwx (owner/group/other) | rwx + ACLs | NTFS ACLs |
| File permission check | `ls -l`, `stat` | `ls -l`, `stat` | `icacls`, `Get-Acl` |
| Privilege config | `/etc/sudoers` | `/etc/sudoers` | Local Security Policy |

Deep dives:
- Linux users and permissions → `../linux/05-users-and-permissions.md`
- macOS security model → `../macos/04-security-model.md`
- Windows security model → `../windows/04-security-model.md`

→ Next: `08-boot-process.md`
