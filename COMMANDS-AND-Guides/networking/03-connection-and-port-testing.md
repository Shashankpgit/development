# Networking — Part 03: Connection Testing — ss, netstat, nc, telnet

**20-minute read. The commands that answer "is anything listening on this port?" and "can I connect?"**

---

## ss — The Modern Socket Statistics Tool

`ss` replaced `netstat`. It's faster and more informative. Use `ss` always.

### Basic Usage

```bash
ss -tlnp
# -t = TCP only
# -l = listening sockets only
# -n = show port numbers, not service names (don't resolve ports)
# -p = show process using the socket

# Output:
State   Recv-Q Send-Q  Local Address:Port   Peer Address:Port  Process
LISTEN  0      128     0.0.0.0:22            0.0.0.0:*         users:(("sshd",pid=1234,fd=3))
LISTEN  0      128     0.0.0.0:80            0.0.0.0:*         users:(("nginx",pid=5678,fd=6))
LISTEN  0      128     127.0.0.1:5432        0.0.0.0:*         users:(("postgres",pid=9012,fd=7))
LISTEN  0      128     0.0.0.0:3000          0.0.0.0:*         users:(("node",pid=3456,fd=18))
```

Reading the output:
- `State: LISTEN` — waiting for connections
- `Local Address: 0.0.0.0:80` — listening on ALL interfaces, port 80
- `Local Address: 127.0.0.1:5432` — listening on LOCALHOST ONLY (not reachable externally!)
- `Process` — which program owns this socket (requires `sudo` for other users' processes)

```bash
# All TCP sockets (including established connections)
ss -tnp

# All UDP sockets
ss -unp

# Both TCP and UDP
ss -tunp

# All sockets (TCP + UDP + Unix domain)
ss -atunp

# Show connected sockets (not listening)
ss -tnp state established

# Count total connections
ss -t state established | wc -l
```

### Filter by Port

```bash
# Who is listening on port 8080?
ss -tlnp sport = :8080

# Connections to a specific remote port
ss -tnp dport = :443

# Connections FROM a specific source port
ss -tnp sport = :3000

# Show sockets for a specific IP
ss -tnp dst 10.0.1.5
```

### Connection States

```bash
ss -tn state established    # active connections
ss -tn state time-wait      # connections being closed (normal, transient)
ss -tn state close-wait     # remote closed, waiting for local app to close
ss -tn state syn-sent        # connection attempts in progress
```

**`TIME_WAIT` connections:** completely normal. After a TCP connection closes, the kernel keeps the entry for ~60s (2×MSL) to absorb any delayed packets. A large number of TIME_WAIT is normal for a high-traffic server.

**`CLOSE_WAIT` accumulating:** your app is not closing connections properly. It received a FIN from the remote but never sent FIN back. Usually a bug in connection pool management.

### Connection Count Per Remote IP (Spot DDoS/Connection Leaks)

```bash
# Count connections per source IP
ss -tn state established | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -rn | head

# Count connections per destination port
ss -tn state established | awk '{print $4}' | cut -d: -f2 | sort | uniq -c | sort -rn
```

---

## netstat — The Old Tool (Know It for Older Systems)

`netstat` still appears in old scripts and servers without `iproute2`. Know the equivalents:

```bash
netstat -tlnp              # same as: ss -tlnp
netstat -tunlp             # same as: ss -tunlp
netstat -rn                # routing table: same as: ip route show
netstat -i                 # interface stats: same as: ip -s link
netstat -s                 # protocol statistics
netstat -an | grep LISTEN  # all listening sockets
```

---

## nc (netcat) — The Swiss Army Knife

`nc` (netcat) is the most versatile networking tool for DevOps. It can:
- Test if a TCP/UDP port is open
- Send and receive data over TCP/UDP
- Act as a simple server for testing
- Transfer files between machines
- Debug application protocols

### Test If a Port Is Open

```bash
# Test TCP connection (timeout 5 seconds)
nc -zv -w 5 hostname 80
# -z = don't send data, just check if port is open
# -v = verbose (show connection result)
# -w 5 = timeout after 5 seconds

# Output if open:
# Connection to hostname 80 port [tcp/http] succeeded!

# Output if refused:
# nc: connect to hostname port 80 (tcp) failed: Connection refused

# Output if timeout:
# (hangs for 5s then) nc: connect to hostname port 80 (tcp) failed: Operation timed out
```

```bash
# Test multiple ports quickly
for port in 22 80 443 5432 3000; do
  nc -zv -w 2 10.0.1.50 $port 2>&1 | grep -E "succeeded|refused|timed"
done

# Test UDP port (DNS example)
nc -zuv -w 2 8.8.8.8 53
```

### Test Raw Protocol Communication

```bash
# HTTP request manually (see exact response including headers)
nc -v vault.example.com 80
# (after connecting, type:)
GET / HTTP/1.0
Host: vault.example.com
[press Enter twice]
# Server responds with full HTTP response

# SMTP test (check if mail server is working)
nc -v mail.example.com 25
# Connected → EHLO yourdomain.com → see what the server supports
```

### Simple Server for Testing

```bash
# Terminal 1: start a listener on port 9999
nc -l -p 9999

# Terminal 2: connect to it
nc localhost 9999
# Now type in either terminal — text appears in the other
# This is how you test if port 9999 is reachable

# In one-liner: listen and echo response
while true; do echo "HTTP/1.0 200 OK\r\n\r\nServer is alive" | nc -l -p 8080; done
```

### File Transfer With nc

```bash
# Receiving side (start first):
nc -l -p 9999 > received-file.tar.gz

# Sending side:
tar czf - /path/to/dir | nc receiving-host 9999
# Fast, no SSH overhead. Useful for internal transfers on trusted networks.
```

---

## telnet — Quick Connectivity Check

`telnet` is older than `nc` but still found everywhere. Good for quick port tests:

```bash
# Test if HTTP port is open
telnet vault.example.com 80
# Connected to vault.example.com.   ← port is open
# Escape character is '^]'.

# Test if it's closed
# telnet: connect to address: Connection refused

# Manually send HTTP (old-school debugging)
telnet vault.example.com 80
GET / HTTP/1.0
Host: vault.example.com
[Enter]
[Enter]
```

**Note:** `telnet` is not available on minimal containers. Use `nc` or install `telnet` with `apt install telnet`.

---

## lsof — What Process Owns This Port

`lsof` (List Open Files) shows which processes have which files/sockets open:

```bash
# What's using port 8080?
sudo lsof -i :8080
# COMMAND   PID   USER   FD   TYPE  DEVICE SIZE/OFF NODE NAME
# node     3456  ubuntu  18u  IPv4  123456      0t0  TCP  *:8080 (LISTEN)

# All network connections by a specific process
sudo lsof -i -p 3456

# All connections to a specific host
sudo lsof -i @10.0.1.50

# All TCP connections
sudo lsof -i TCP

# All UDP connections
sudo lsof -i UDP

# Find what process is using a file (or socket file)
sudo lsof /var/run/docker.sock
```

---

## Real-World Scenario 1: "Service is down but container is running"

```bash
# Docker says the container is running. curl says connection refused.

# Step 1: Is the app actually listening inside the container?
docker exec vault-api ss -tlnp
# LISTEN 0 128 127.0.0.1:3000   ← PROBLEM: listening on localhost only!
# The app listens on 127.0.0.1, not 0.0.0.0 → not reachable even from host

# Fix: change your app's config to listen on 0.0.0.0
# e.g., in Node.js: app.listen(3000, '0.0.0.0')
# In Python: app.run(host='0.0.0.0')
# In Spring: server.address=0.0.0.0

# Step 2: Did Docker expose the port?
docker ps
# PORTS: 0.0.0.0:8080->3000/tcp  ← good
# PORTS: (empty)                  ← you forgot -p flag when starting

# Step 3: Is there a firewall on the host?
sudo iptables -L INPUT -n | grep 8080
sudo ufw status
```

---

## Real-World Scenario 2: "PostgreSQL Won't Start — Port Already in Use"

```bash
# Error: "could not bind IPv4 address '0.0.0.0': Address already in use"

# Find what's using port 5432
sudo ss -tlnp sport = :5432
# LISTEN 0 128 127.0.0.1:5432   users:(("postgres", pid=1234, fd=5))
# There's already a PostgreSQL running!

# Or use lsof
sudo lsof -i :5432

# Kill it (if it's stuck)
sudo kill -9 1234
# Or gracefully stop the existing postgres
sudo systemctl stop postgresql

# If it's Docker:
docker ps | grep 5432
docker stop old-postgres-container
```

---

## Real-World Scenario 3: Checking Kubernetes Pod Connectivity

```bash
# Can pod A reach pod B?

# Get pod B's IP
kubectl get pod vault-db-0 -n production -o jsonpath='{.status.podIP}'
# 10.244.2.5

# Run nc from pod A
kubectl exec -it vault-api-7d4b9c -n production -- nc -zv 10.244.2.5 5432
# Connection to 10.244.2.5 5432 port [tcp/postgresql] succeeded!
# → pod-level connectivity works

# If nc isn't available, use /dev/tcp (bash built-in, always available)
kubectl exec -it vault-api-7d4b9c -n production -- bash -c \
  "timeout 3 bash -c 'cat < /dev/null > /dev/tcp/10.244.2.5/5432' && echo 'port open' || echo 'port closed'"
```

---

## Common Misunderstanding: "If the container port is mapped, the app is accessible"

**The misunderstanding:** "`docker run -p 8080:3000` — now my app is accessible on port 8080."

**The reality:** `-p 8080:3000` creates a NAT rule: traffic to host port 8080 is forwarded to container port 3000. But this only works if:

1. The app inside the container is actually listening on port 3000 (not 3001 or 127.0.0.1:3000)
2. The host's firewall allows port 8080

The NAT rule (`-p`) only handles host→container forwarding. If the app inside isn't listening correctly, traffic arrives at the container but gets refused.

Debugging checklist:
```bash
# 1. Is the app listening inside the container?
docker exec mycontainer ss -tlnp

# 2. Is Docker's NAT rule in place?
sudo iptables -t nat -L DOCKER -n | grep 8080

# 3. Is the host firewall allowing it?
sudo ufw status
sudo iptables -L INPUT -n | grep 8080

# 4. Are you testing from the right machine?
curl http://localhost:8080          # from the Docker host
curl http://10.0.1.50:8080          # from another machine
```

→ Continue to: `04-curl-http-debugging.md`
