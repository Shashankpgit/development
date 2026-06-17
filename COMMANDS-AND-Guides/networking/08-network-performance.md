# Networking — Part 08: Network Performance — ping, traceroute, mtr, iperf3

**20-minute read. Measure latency, find where packets are lost, and test real throughput.**

---

## ping — Measuring Latency and Packet Loss

`ping` sends ICMP Echo Request packets and measures round-trip time.

```bash
# Basic ping
ping google.com
# PING google.com: 56 bytes of data
# 64 bytes from 142.250.77.14: icmp_seq=1 ttl=118 time=12.3 ms
# 64 bytes from 142.250.77.14: icmp_seq=2 ttl=118 time=11.9 ms
# Statistics: 3 packets transmitted, 3 received, 0% packet loss, avg 12.1ms

# Send N packets then stop (instead of running forever)
ping -c 10 google.com

# Set interval between pings (default is 1 second)
ping -i 0.2 google.com     # ping every 200ms (faster — need root for < 0.2s)

# Ping with larger packet size (test fragmentation or MTU issues)
ping -s 1400 10.0.1.50    # send 1400 byte packets (default is 56)

# Flood ping (as fast as possible — needs root, careful!)
sudo ping -f 10.0.1.50

# Verbose with TTL info
ping -v 10.0.1.50
```

### Reading ping Output

```
64 bytes from 10.0.1.50: icmp_seq=5 ttl=64 time=0.412 ms
                                    └──── └──── └───────
                                    seq# TTL  round-trip time

--- 10.0.1.50 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss
rtt min/avg/max/mdev = 0.389/0.412/0.449/0.025 ms
                       └────────────────────────────
                        min, average, max, standard deviation
```

**What to look for:**
- `packet loss > 0%` → network reliability issue
- `time > 50ms` → noticeable latency for interactive apps
- `time > 200ms` → slow for most applications
- `mdev` (standard deviation) high → inconsistent latency (jitter) — bad for VoIP/video

```bash
# Detect packet loss (run for 100 packets)
ping -c 100 10.0.1.50 | tail -3

# Ping with timestamp (useful for logging)
ping -c 5 10.0.1.50 | while read line; do echo "$(date): $line"; done

# Check if ICMP is blocked (if ping fails but TCP works)
nc -zv 10.0.1.50 22    # if SSH works but ping doesn't → ICMP blocked by firewall
```

---

## traceroute — Find Where Packets Get Stuck

`traceroute` shows the path packets take from your machine to a destination, hop by hop. Each line is one router in the path.

```bash
# Basic traceroute
traceroute google.com

# Example output:
traceroute to google.com (142.250.77.14), 30 hops max
 1  10.0.1.1 (10.0.1.1)          0.5 ms  0.4 ms  0.4 ms    ← your gateway
 2  103.50.100.1 (103.50.100.1)  2.1 ms  2.0 ms  1.9 ms    ← ISP router
 3  * * *                                                    ← hop doesn't respond
 4  72.14.210.1 (72.14.210.1)    5.3 ms  5.2 ms  5.1 ms    ← Google edge
 5  142.250.77.14 (142.250.77.14) 12.1 ms  11.9 ms  12.0 ms ← destination
```

- `* * *` → router exists (packets pass through it) but ICMP responses are blocked — NORMAL
- If the path stops at `* * *` before reaching the destination → the last responding hop is where the problem is
- Increasing latency at each hop → packets traveling far
- Sudden latency jump at one hop → bottleneck at that router or link

```bash
# Faster: use UDP instead of ICMP (avoids ICMP rate limiting)
traceroute -U google.com

# Use ICMP explicitly (like Windows tracert)
traceroute -I google.com

# Use TCP (useful when ICMP and UDP are blocked)
sudo traceroute -T -p 443 vault.example.com

# Don't resolve hostnames (faster output)
traceroute -n google.com

# Set max hops (default 30)
traceroute -m 20 google.com
```

---

## mtr — The Best of ping + traceroute

`mtr` (Matt's Traceroute) combines traceroute and ping — it continuously pings every hop and shows real-time statistics. This is your go-to tool for diagnosing network path issues.

```bash
# Interactive mode (updates in real time)
mtr google.com

# Report mode (run for N packets, print report, exit)
mtr -r -c 100 google.com

# Report mode, no hostname resolution (faster)
mtr -r -c 100 -n google.com

# TCP mode (useful when ICMP is blocked)
mtr -T -P 443 vault.example.com

# Wide report (shows all columns including packet counts)
mtr -r -c 100 -w google.com
```

### Reading mtr Output

```
                              My traceroute  [v0.95]
Host                    Loss%   Snt   Last   Avg  Best  Wrst StDev
 1. 10.0.1.1            0.0%   100    0.5   0.5   0.4   0.8   0.1
 2. 103.50.100.1        0.0%   100    2.1   2.0   1.8   3.2   0.2
 3. ???                                                           ← ICMP blocked, normal
 4. 72.14.210.1         0.0%   100    5.3   5.3   4.9   6.2   0.3
 5. 142.250.77.14       0.0%   100   12.1  12.0  11.8  13.1   0.3
     │                   │      │     │      │     │     │     └── standard deviation
     │                   │      │     │      │     └──── └── best and worst RTT
     │                   │      │     │      └── average RTT
     │                   │      │     └── last RTT
     │                   │      └── total packets sent
     │                   └── packet loss percentage
     └── hostname/IP
```

**Key things to look for:**
- `Loss% > 0` at a hop that's NOT the last responding one → packet loss AT that router
- `Loss% > 0` at the FINAL destination → real packet loss
- `Loss% > 0` only at intermediate hop but not at later hops → that hop rate-limits ICMP (false alarm)
- Large `StDev` → jitter (inconsistent latency)

---

## iperf3 — Measure Real Network Throughput

`ping` measures latency. `iperf3` measures actual throughput (bandwidth). It tells you how many MB/s you can actually transfer between two machines.

```bash
# Install on both machines
sudo apt install iperf3

# Terminal on SERVER machine:
iperf3 -s                           # listen on default port 5201
iperf3 -s -p 9999                   # custom port

# Terminal on CLIENT machine:
iperf3 -c server-ip                 # basic throughput test
iperf3 -c server-ip -p 9999        # custom port
iperf3 -c server-ip -t 30          # run for 30 seconds (default is 10)
iperf3 -c server-ip -P 4           # 4 parallel streams (simulates concurrent connections)
iperf3 -c server-ip -u             # UDP test (bandwidth + packet loss)
iperf3 -c server-ip -R             # reverse direction (server sends, client receives)
iperf3 -c server-ip -b 100M        # limit test to 100Mbps (don't saturate the link)
```

### Reading iperf3 Output

```
Connecting to host server-ip, port 5201
[  5] local 10.0.1.15 port 52341 connected to 10.0.1.50 port 5201
[ ID] Interval         Transfer     Bitrate
[  5]  0.0-10.0 sec    1.09 GBytes  936 Mbits/sec      sender
[  5]  0.0-10.0 sec    1.09 GBytes  935 Mbits/sec      receiver
```

936 Mbps out of a theoretical 1Gbps link = ~94% efficiency (excellent).

### DevOps Use Cases

```bash
# Test bandwidth between Kubernetes nodes
# (are nodes getting full bandwidth they should have?)
iperf3 -c worker-node-2-ip -P 8 -t 30

# Test to verify NIC isn't throttled after VM migration
iperf3 -c 10.0.1.50 -t 60 -b 500M   # test 500Mbps sustained

# Test Docker network performance (container-to-container)
# Terminal 1: run server container
docker run --rm -p 5201:5201 networkstatic/iperf3 -s

# Terminal 2: run client container
docker run --rm networkstatic/iperf3 -c host-ip

# Test across a VPN (compare with local)
iperf3 -c vpn-server-ip -t 60
# Compare result with direct LAN test to see VPN overhead
```

---

## hping3 — Advanced Ping (TCP/UDP/Custom Packets)

`hping3` is like ping but works with TCP and UDP. Useful when ICMP is blocked.

```bash
# TCP ping (SYN packet to port 80)
sudo hping3 -S -p 80 vault.example.com
# If you get RST back → port is closed (but machine is reachable)
# If you get SYN-ACK → port is open and listening

# Count to 5 then stop
sudo hping3 -S -p 443 -c 5 vault.example.com

# Traceroute-mode with TCP
sudo hping3 -S -p 443 --traceroute vault.example.com

# Test UDP
sudo hping3 -2 -p 53 8.8.8.8 -c 3   # UDP to DNS port
```

---

## ss with Socket Statistics (Detailed Network Stats)

```bash
# See TCP retransmissions (indicates congestion or packet loss)
ss -tiE state established | grep "retrans"

# Detailed TCP socket info (congestion window, RTT)
ss -ti dst 10.0.1.50
# cwnd: 10    ← congestion window size
# rtt: 0.412/0.025  ← RTT avg/variance
# retrans: 0/0   ← retransmissions (non-zero = packet loss)

# Watch retransmissions in real time
watch -n 1 "ss -s"
# Retransmits: increasing count = congestion
```

---

## Real-World Scenario: "API latency jumped from 50ms to 500ms overnight"

```bash
# Step 1: Is the app slow or is the NETWORK slow?
# Time a simple curl
curl -w "Connect: %{time_connect}s | TTFB: %{time_starttransfer}s | Total: %{time_total}s\n" \
  -s -o /dev/null https://vault.example.com/api/users

# If Connect time is high (> 50ms) → network issue
# If TTFB is high but Connect is normal → app is slow (database, CPU)

# Step 2: Check latency to the server
mtr -r -c 50 -n vault.example.com
# Look for packet loss or latency spike at any hop

# Step 3: Check if it's DNS adding latency
time dig vault.example.com
# If > 100ms → DNS is the problem

# Step 4: Test TCP connect time only (no TLS, no HTTP)
time nc -zv vault.example.com 443
# If > 50ms → network issue between you and the server

# Step 5: Test throughput to the server
iperf3 -c vault.example.com -p 5201 -t 20
# If significantly lower than expected → network congestion or throttling

# Step 6: Look for retransmissions from the app server
ssh app-server
ss -s
# Retransmits: 47823   ← high → packet loss on this server's connections
```

---

## Common Misunderstanding: "ping blocking means the server is down"

**The misunderstanding:** "I can't ping the server — it must be unreachable or down."

**The reality:** Most cloud providers (AWS, GCP, Azure) and corporate firewalls block ICMP by default. A server can be fully operational and serving HTTP traffic on port 443 while refusing all ping requests.

```bash
# Server "doesn't respond to ping" but is perfectly healthy:
ping vault.example.com       # Request timeout — looks dead
curl https://vault.example.com/health   # {"status":"ok"} — perfectly fine

# Better check than ping:
nc -zv vault.example.com 443   # test actual TCP port
curl -s -o /dev/null -w "%{http_code}" https://vault.example.com/health
```

In AWS: security groups block ICMP by default. You must explicitly add an inbound rule for `ICMP` to allow ping. But you almost never should — just test the actual TCP ports your service uses.

→ Continue to: `09-ssh-tunneling.md`
