# Part 08 — Networking Commands: ping, curl, ssh, scp, netstat, ss, ip, dig

Networking commands are critical for DevOps work — checking connectivity, transferring files, debugging server issues, and managing remote machines.

---

## `ping` — Test Network Connectivity

```bash
ping google.com          # ping indefinitely (Ctrl+C to stop)
ping -c 4 google.com     # ping exactly 4 times then stop
ping -i 2 google.com     # ping every 2 seconds (default is 1)
ping 192.168.1.1         # ping an IP address (works on LAN too)
```

Output:
```
PING google.com (142.250.182.46): 56 data bytes
64 bytes from 142.250.182.46: icmp_seq=0 ttl=118 time=12.4 ms
64 bytes from 142.250.182.46: icmp_seq=1 ttl=118 time=11.8 ms
```

- `time=12.4 ms` — round-trip time (latency). Lower is better. >200ms is slow.
- If there's no reply — network unreachable, host is down, or firewall blocking ICMP.

**When to use:** First step when something "can't connect" — test basic network reachability.

---

## `curl` — Transfer Data From/To URLs

`curl` is the Swiss Army knife of network requests. It can do HTTP, HTTPS, FTP, and more.

### Basic GET request:

```bash
curl https://api.github.com/users/octocat
# Returns the JSON response body
```

### Save output to a file:

```bash
curl -o output.html https://example.com
curl -O https://example.com/file.tar.gz   # -O saves with the remote filename
```

### Download with progress bar:

```bash
curl -# -O https://example.com/large-file.tar.gz   # -# shows progress bar
```

### Follow redirects:

```bash
curl -L https://github.com/something    # -L follows HTTP 301/302 redirects
```

### POST request with JSON body:

```bash
curl -X POST https://api.example.com/users \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your-token" \
  -d '{"name": "Shashank", "email": "shashank@example.com"}'
```

### See response headers:

```bash
curl -I https://example.com        # -I = head request (headers only, no body)
curl -v https://example.com        # -v = verbose (shows request + response headers + body)
curl -i https://example.com        # -i = include response headers with body
```

### Check response code only:

```bash
curl -o /dev/null -s -w "%{http_code}" https://example.com
# Output: 200  (or 404, 500, etc.)
```

### Download a file using a bearer token:

```bash
curl -H "Authorization: Bearer $TOKEN" \
     -o data.json \
     https://api.service.com/data
```

### Test if a service is up:

```bash
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/health
# 200 = up, 000 = connection refused (service down)
```

---

## `wget` — Download Files

Simpler than curl for just downloading files:

```bash
wget https://example.com/file.tar.gz
wget -O custom-name.tar.gz https://example.com/file.tar.gz
wget -q https://example.com/file.tar.gz    # quiet mode
wget --continue -O file.tar.gz URL         # resume interrupted download
```

---

## `ssh` — Secure Shell: Connect to Remote Machines

```bash
ssh user@hostname
ssh shashank@192.168.1.100
ssh shashank@server.example.com
ssh -p 2222 user@hostname              # connect to non-standard port (default is 22)
ssh -i ~/.ssh/my-key user@hostname     # use specific SSH key
```

### SSH Config File — Shortcuts for Frequent Connections

Instead of typing `ssh -i ~/.ssh/work-key -p 2222 shashank@100.200.30.40` every time, define aliases in `~/.ssh/config`:

```
Host myserver
    HostName 100.200.30.40
    User shashank
    Port 2222
    IdentityFile ~/.ssh/work-key

Host prod-db
    HostName 10.0.0.5
    User ubuntu
    IdentityFile ~/.ssh/prod-key
```

Now you can just type:
```bash
ssh myserver
ssh prod-db
```

### Run a command on a remote machine without interactive session:

```bash
ssh user@server "ls -la /var/log/nginx/"
ssh user@server "sudo systemctl restart nginx"
ssh user@server "df -h; free -m; uptime"   # multiple commands with ;
```

### SSH Tunneling (Port Forwarding):

```bash
# Access a remote service locally — forward local port 8080 to remote port 80
ssh -L 8080:localhost:80 user@remote-server
# Now: http://localhost:8080 in your browser → reaches remote-server:80

# Jump through an intermediate server to reach an internal server
ssh -J user@jump-server user@internal-server
```

---

## `scp` — Secure Copy: Transfer Files Over SSH

```bash
# Copy FROM local TO remote
scp file.txt user@server:/home/user/
scp -r local-dir/ user@server:/home/user/remote-dir/   # -r for directories

# Copy FROM remote TO local
scp user@server:/var/log/nginx/error.log ./error.log
scp -r user@server:/home/user/project/ ./local-project/

# Copy between two remote servers
scp user1@server1:/path/file user2@server2:/path/file
```

---

## `ss` — Socket Statistics (Modern netstat Replacement)

`ss` shows network connections, listening ports, and socket statistics.

### See all listening ports (what services are running):

```bash
ss -tlnp
```

Output:
```
State    Recv-Q Send-Q Local Address:Port  Peer Address:Port  Process
LISTEN   0      128    0.0.0.0:80          0.0.0.0:*          users:(("nginx",pid=834))
LISTEN   0      128    0.0.0.0:22          0.0.0.0:*          users:(("sshd",pid=562))
LISTEN   0      511    127.0.0.1:5432      0.0.0.0:*          users:(("postgres",pid=902))
LISTEN   0      511    0.0.0.0:3000        0.0.0.0:*          users:(("node",pid=1823))
```

Flags breakdown:
- `-t` — TCP connections only
- `-l` — listening sockets only
- `-n` — show port numbers, not service names (faster)
- `-p` — show which process owns each socket

Reading the output:
- `0.0.0.0:80` — listening on ALL interfaces on port 80 (public)
- `127.0.0.1:5432` — listening ONLY on localhost (not accessible from outside)
- The process column shows what's using each port

### Check if a specific port is in use:

```bash
ss -tlnp | grep :3000        # check port 3000
ss -tlnp | grep :5432        # check postgres port
```

### See established connections:

```bash
ss -tnp                      # all established TCP connections
ss -tnp | grep ESTABLISHED   # only active connections
```

---

## `ip` — Modern Network Interface Management

```bash
ip addr                    # show all network interfaces and their IPs
ip addr show eth0          # show specific interface
ip route                   # show routing table
ip route show              # same
```

Output of `ip addr`:
```
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 ...
    inet 127.0.0.1/8 scope host lo
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 ...
    inet 192.168.1.100/24 brd 192.168.1.255 scope global eth0
```

- `lo` — loopback interface (127.0.0.1, always localhost)
- `eth0` — ethernet interface (your LAN/server IP)
- `inet 192.168.1.100/24` — your IP address and subnet mask

---

## `dig` and `nslookup` — DNS Lookups

### `dig` — Query DNS records:

```bash
dig google.com              # A record (IPv4 address)
dig google.com MX           # Mail exchange records
dig google.com AAAA         # IPv6 address
dig google.com NS           # Name server records
dig +short google.com       # clean output (just the IP)
dig @8.8.8.8 google.com     # query Google's DNS server specifically
```

```bash
dig +short google.com
# 142.250.182.46
```

Use when: debugging DNS issues ("is this domain resolving correctly?")

### `nslookup` — Simpler DNS lookup:

```bash
nslookup google.com
nslookup 142.250.182.46    # reverse lookup: IP → domain name
```

---

## Real-World Scenario: "My Application Can't Connect to the Database"

```bash
# Step 1: Is the database server reachable at all?
ping db.example.com

# Step 2: Is anything listening on the database port?
ssh user@db.example.com "ss -tlnp | grep :5432"

# Step 3: Can you connect to the port from the app server?
# (telnet or nc to test TCP connectivity)
nc -zv db.example.com 5432
# Connection to db.example.com 5432 port [tcp/postgresql] succeeded!
# (if it fails: firewall or service not running)

# Step 4: Is the database service running?
ssh user@db.example.com "systemctl status postgresql"

# Step 5: Check database server's own logs
ssh user@db.example.com "sudo tail -50 /var/log/postgresql/postgresql-14-main.log"
```

---

## Common Misunderstanding: "`netstat` is the command to see open ports"

**The misunderstanding:** "I need to use `netstat` to see what ports are open."

**The reality:** `netstat` is older and deprecated on modern Linux. It's not installed by default on Ubuntu 20+ and later versions. The modern replacement is `ss`, which is faster and more detailed.

```bash
# Old way (may not even be installed):
netstat -tlnp

# Modern way (always available):
ss -tlnp
```

Both show the same information. `ss` is faster and shows more detail. If you see tutorials using `netstat`, mentally replace it with `ss`.

If you really need netstat: `sudo apt install net-tools`

---

→ Continue to: `09-disk-and-storage.md`
