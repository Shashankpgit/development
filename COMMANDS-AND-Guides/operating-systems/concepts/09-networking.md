# Networking

---

## The OS's Role in Networking

When your app opens a connection to a server, you might think the app does the networking. It doesn't. The OS does almost all of it.

Your application makes a single system call: `connect(sockfd, server_address)`. Everything else — building TCP packets, handling retransmissions, managing IP routing, talking to the network card — is handled entirely by the kernel's **network stack**.

```
Your app:         connect("api.example.com", port 443)
                          ↓
OS kernel:
  - DNS lookup: resolve "api.example.com" to 93.184.216.34
  - Create a TCP connection (3-way handshake)
  - Encrypt with TLS (in kernel or via library)
  - Fragment data into IP packets
  - Route packets to the right network interface
  - Pass packets to the network driver
                          ↓
Network card:     transmits the actual electrical signals / Wi-Fi frames
```

---

## The Networking Stack

The OS implements networking as a layered stack. Each layer handles a specific job and talks to the layers above and below it.

```
Application layer   →  your app (HTTP, WebSocket, gRPC)
Transport layer     →  TCP / UDP (in the kernel)
Network layer       →  IP routing (in the kernel)
Link layer          →  Ethernet / Wi-Fi (network card driver)
Physical layer      →  actual cable / radio signals (hardware)
```

### Transport Layer: TCP vs UDP

**TCP (Transmission Control Protocol):**
- Connection-oriented: must establish a connection before sending data (3-way handshake)
- Reliable: guarantees delivery and order — retransmits lost packets
- Slower: overhead from connection setup, acknowledgments, flow control
- Use for: HTTP, HTTPS, SSH, databases, anything that needs reliability

**UDP (User Datagram Protocol):**
- Connectionless: fire and forget — send packets, no setup needed
- Unreliable: packets can be lost, duplicated, or arrive out of order
- Faster: no handshake, no retransmission overhead
- Use for: video streaming, games, DNS, VoIP — where speed matters more than perfect reliability

### Network Layer: IP

IP (Internet Protocol) handles **addressing and routing** — how a packet gets from your computer to a server on the other side of the world.

Every device has an **IP address**:
- IPv4: 32-bit number written as `192.168.1.10`
- IPv6: 128-bit number written as `2001:db8::1`

The OS kernel maintains a **routing table** — a list of rules for "if the destination is in this IP range, send the packet to this next hop."

```
Routing table (simplified):
  192.168.1.0/24  →  send directly on eth0 (local network)
  0.0.0.0/0       →  send to 192.168.1.1 (the default gateway = your router)
```

---

## Sockets — How Apps Access Networking

The OS exposes networking to applications through **sockets** — an abstraction that looks like a file. You get a file descriptor, and you read/write to it just like a file.

```
server:
  socket()       → create a socket (get a file descriptor)
  bind()         → attach to a specific IP:port (e.g., 0.0.0.0:8080)
  listen()       → mark as accepting incoming connections
  accept()       → wait for a client to connect (blocks)
  read()/write() → exchange data with the client
  close()        → done

client:
  socket()           → create a socket
  connect(host, port) → connect to the server
  write()            → send data
  read()             → receive response
  close()            → done
```

This same socket API is used in every language — Python's `socket`, Node.js's `net`, Java's `Socket`, Go's `net.Dial`. They all ultimately call these same OS system calls.

---

## Ports

A **port** is a 16-bit number (0–65535) that multiplexes network connections. Your computer has one IP address but can have many programs all using the network at once — ports distinguish between them.

```
Incoming packet: destination 192.168.1.10:443
→ OS looks up: which process is listening on port 443?
→ Routes the packet to that process
```

Well-known ports (0–1023) are reserved for standard services:
```
22    SSH
80    HTTP
443   HTTPS
3306  MySQL
5432  PostgreSQL
6379  Redis
27017 MongoDB
```

On Linux/macOS, only root can bind to ports below 1024. On Windows, this restriction is less strict but standard ports still have assigned meanings.

---

## DNS — Name to Address

`"api.example.com"` is a domain name — humans find them easier to remember than IP addresses. The **Domain Name System (DNS)** translates names to IP addresses.

When your app connects to `"api.example.com"`:
1. OS checks local cache (was this resolved recently?)
2. OS checks `/etc/hosts` file (are there manual overrides?)
3. OS asks the configured DNS server (usually your router or `8.8.8.8`)
4. DNS server returns `93.184.216.34`
5. OS caches the result for a while (TTL — Time to Live)
6. Connection proceeds to that IP

This is why changing your DNS server affects which IP addresses you get for domain names — useful for split-horizon DNS, private networks, and blocking ad/malware domains.

---

## Network Interfaces

A **network interface** is a connection point — a physical or virtual device the OS uses to send and receive network traffic.

```
eth0      → wired Ethernet interface
wlan0     → Wi-Fi interface
lo        → loopback (127.0.0.1 — your own machine)
docker0   → virtual interface for Docker networking
tun0      → virtual interface for a VPN tunnel
```

The OS assigns an IP address to each interface. Traffic is routed to the correct interface based on the destination IP and the routing table.

The **loopback** (`127.0.0.1` or `localhost`) is special — traffic sent to it never leaves the machine. It's used when your app needs to talk to another app on the same machine (e.g., app → database on the same server).

---

## Firewalls

The OS's network stack includes a **firewall** — rules that decide which incoming and outgoing packets are allowed.

```
Incoming packet →  firewall checks rules → drop or allow → reaches the app
```

Firewalls protect servers by blocking traffic to ports that aren't supposed to be public. For example: your database might be listening on port 5432, but the firewall drops all incoming connections to that port from the internet — only the app server on the local network can reach it.

```
Firewall rule examples:
  ALLOW   incoming TCP port 443  (HTTPS — public)
  ALLOW   incoming TCP port 22   (SSH — only from specific IPs)
  DROP    incoming TCP port 5432 (PostgreSQL — internal only)
  ALLOW   all outgoing traffic
```

---

## Platform Notes

| | Linux | macOS | Windows |
|--|-------|-------|---------|
| Firewall | iptables / nftables / ufw | pf (Packet Filter) | Windows Defender Firewall |
| DNS config | `/etc/resolv.conf` | System Preferences / `/etc/resolv.conf` | Network adapter settings |
| `/etc/hosts` | `/etc/hosts` | `/etc/hosts` | `C:\Windows\System32\drivers\etc\hosts` |
| View interfaces | `ip addr`, `ifconfig` | `ifconfig`, `networksetup` | `Get-NetIPAddress`, `ipconfig` |
| View connections | `ss -tulpn`, `netstat` | `netstat`, `lsof -i` | `netstat -ano`, `Get-NetTCPConnection` |
| Routing table | `ip route` | `netstat -rn` | `Get-NetRoute`, `route print` |

Deep dives:
- Linux networking from the OS perspective → `../linux/06-networking-from-os.md`
- macOS networking → `../macos/05-networking.md`
- Windows networking (PowerShell) → `../windows/01-powershell.md` (networking section)

→ You've completed the OS concepts guide.  
→ For the full picture: `../README.md`  
→ For platform-specific details: `../linux/`, `../macos/`, `../windows/`
