# Linux Commands — Complete Learning Guide

A from-scratch, zero-to-productive guide to Linux commands. Each file is a self-contained lesson with real-world scenarios, explicit examples, and "Common Misunderstanding" sections.

---

## Reading Order

| File | Topic | Who it's for |
|------|-------|-------------|
| [00 — Introduction to Linux](00-introduction-to-linux.md) | Terminal vs shell, command anatomy, man pages, sudo | Absolute beginners |
| [01 — Navigation](01-navigation-commands.md) | `pwd`, `ls`, `cd`, `tree`, absolute vs relative paths | Beginners |
| [02 — File & Directory Operations](02-file-and-directory-operations.md) | `touch`, `mkdir`, `cp`, `mv`, `rm`, `ln` | Beginners |
| [03 — Viewing & Editing Files](03-viewing-and-editing-files.md) | `cat`, `less`, `head`, `tail`, `nano`, `vim`, redirection | Beginners |
| [04 — Permissions & Ownership](04-permissions-and-ownership.md) | `chmod`, `chown`, `sudo`, `su`, rwx notation | Beginners → Intermediate |
| [05 — Process Management](05-process-management.md) | `ps`, `top`, `kill`, `jobs`, `nohup`, `systemctl` | Intermediate |
| [06 — Searching & Finding](06-searching-and-finding.md) | `find`, `grep`, `which`, `locate` | Intermediate |
| [07 — Text Processing](07-text-processing.md) | pipes, `sort`, `cut`, `awk`, `sed`, `uniq`, `wc` | Intermediate |
| [08 — Networking Commands](08-networking-commands.md) | `ping`, `curl`, `ssh`, `scp`, `ss`, `ip`, `dig` | Intermediate |
| [09 — Disk & System Monitoring](09-disk-storage-and-system-monitoring.md) | `df`, `du`, `free`, `journalctl`, `vmstat` | Intermediate |
| [10 — Package Management](10-package-management.md) | `apt`, `dpkg`, `snap`, `pip`, `npm` | All levels |
| [11 — Shell Features](11-shell-features-and-shortcuts.md) | Variables, aliases, history, job control, shortcuts | All levels |
| [12 — Compression & Archiving](12-compression-and-archiving.md) | `tar`, `gzip`, `zip`, `unzip` | All levels |

---

## Quick Command Lookup

| I want to... | Command |
|-------------|---------|
| Where am I? | `pwd` |
| List files (detailed + hidden) | `ls -la` |
| Go home | `cd` or `cd ~` |
| Go back to previous directory | `cd -` |
| Go up one level | `cd ..` |
| Create empty file | `touch file.txt` |
| Create directory tree | `mkdir -p a/b/c` |
| Copy recursively | `cp -r source/ dest/` |
| Move/rename | `mv old new` |
| Delete file | `rm file` |
| Delete directory and contents | `rm -rf dir/` |
| Read a file | `cat file` (small) / `less file` (large) |
| Watch a log in real time | `tail -f /var/log/app.log` |
| Make script executable | `chmod +x script.sh` |
| Change file owner | `sudo chown user:group file` |
| See running processes | `ps aux` or `htop` |
| Kill a process | `kill PID` or `kill -9 PID` |
| Find a file by name | `find . -name "filename"` |
| Search text in files | `grep -r "text" .` |
| See disk space | `df -h` |
| See what's taking disk space | `du -h --max-depth=1 /var \| sort -rh` |
| See RAM usage | `free -h` |
| See open ports | `ss -tlnp` |
| Download a file | `curl -O URL` or `wget URL` |
| SSH to server | `ssh user@server` |
| Copy file to server | `scp file user@server:/path/` |
| Install a package | `sudo apt install package` |
| Check service status | `systemctl status nginx` |
| Restart a service | `sudo systemctl restart nginx` |
| See service logs | `journalctl -u nginx -f` |
| Create tar.gz archive | `tar -czf archive.tar.gz directory/` |
| Extract tar.gz | `tar -xzf archive.tar.gz` |
| Add alias permanently | Edit `~/.bashrc`, run `source ~/.bashrc` |
