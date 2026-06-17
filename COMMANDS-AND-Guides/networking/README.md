# Networking Commands Guide — DevOps Engineer Edition

**12 files. ~20 minutes each. Zero to production-ready.**

---

## Reading Order

| File | Topic | What you'll be able to do |
|------|--------|--------------------------|
| [00-networking-mental-model.md](00-networking-mental-model.md) | IP, CIDR, TCP/UDP, OSI layers | Read network diagrams, understand failure modes |
| [01-ip-interface-commands.md](01-ip-interface-commands.md) | `ip addr`, `ip route`, `ip link` | Inspect and configure network interfaces |
| [02-dns-commands.md](02-dns-commands.md) | `dig`, `nslookup`, CoreDNS | Debug any DNS problem including Kubernetes |
| [03-connection-and-port-testing.md](03-connection-and-port-testing.md) | `ss`, `nc`, `lsof` | See what's listening, test connectivity |
| [04-curl-http-debugging.md](04-curl-http-debugging.md) | `curl` deep dive | Debug HTTP, TLS, timing, retries |
| [05-tcpdump-traffic-analysis.md](05-tcpdump-traffic-analysis.md) | `tcpdump` | Capture and read real network traffic |
| [06-firewall-iptables-ufw.md](06-firewall-iptables-ufw.md) | `ufw`, `iptables`, Docker firewall | Control traffic, understand K8s DNAT rules |
| [07-tls-ssl-certificates.md](07-tls-ssl-certificates.md) | `openssl`, certbot, cert-manager | Inspect certs, generate keys, fix TLS errors |
| [08-network-performance.md](08-network-performance.md) | `ping`, `traceroute`, `mtr`, `iperf3` | Measure latency, find packet loss, test throughput |
| [09-ssh-tunneling-and-proxying.md](09-ssh-tunneling-and-proxying.md) | SSH tunnels, jump hosts | Access databases and dashboards in private networks |
| [10-container-k8s-networking.md](10-container-k8s-networking.md) | Docker + Kubernetes networking | Debug CNI, Services, NetworkPolicy, Ingress |
| [11-real-world-troubleshooting.md](11-real-world-troubleshooting.md) | 10 complete scenarios | End-to-end diagnosis of production failures |

---

## Quick Command Lookup

### "What is my IP?"
```bash
ip addr show | grep "inet "
curl -s ifconfig.me        # public IP
```

### "What's listening on port X?"
```bash
ss -tlnp | grep :8080
lsof -i :8080
```

### "Can I reach host:port?"
```bash
nc -zv 10.0.1.50 5432      # TCP connect test
curl -v http://host:port/  # HTTP test
```

### "Why can't I resolve this hostname?"
```bash
dig +short vault.example.com
dig +trace vault.example.com    # full resolution path
dig @8.8.8.8 vault.example.com  # bypass local DNS
```

### "Is this a firewall issue?"
```bash
# On client: check if SYN goes out but no SYN-ACK comes back
sudo tcpdump -i eth0 host 10.0.1.50 and port 5432

# On server: check if packet even arrives
sudo tcpdump -i eth0 port 5432
```

### "Which certificate is expiring?"
```bash
echo | openssl s_client -connect vault.example.com:443 2>/dev/null \
  | openssl x509 -noout -dates
```

### "What route does traffic take?"
```bash
traceroute -n vault.example.com
mtr -r -c 50 vault.example.com    # better — shows packet loss per hop
```

### "How fast is the network?"
```bash
iperf3 -c server-ip              # TCP throughput
ping -c 100 server-ip | tail -3  # latency + packet loss
```

### "Forward a remote port to my laptop"
```bash
ssh -L 5432:postgres-host:5432 user@bastion    # local forwarding
kubectl port-forward svc/postgres 5432:5432    # K8s
```

### "Why is this K8s service unreachable?"
```bash
kubectl get endpoints service-name -n namespace    # endpoints exist?
kubectl get pods -l app=your-app -n namespace      # labels match?
kubectl exec -it test-pod -- nc -zv service-name port
```

---

## The 3-Step Network Debug Flow

```
1. CONNECT: Can they reach each other at all?
   ping, traceroute, nc -zv, tcpdump

2. TALK: Is the right service listening?
   ss -tlnp, curl -v, kubectl get endpoints

3. TRUST: Is TLS / auth failing?
   openssl s_client, curl -v (look for SSL errors), dig
```

---

## Production Cheatsheet: Common Error Codes

| Error | What it means | Where to look |
|-------|--------------|---------------|
| `ECONNREFUSED` | Nothing listening at that port | `ss -tlnp` on the destination |
| `ETIMEDOUT` | Packet lost or firewall dropping | `tcpdump` for SYN with no reply |
| `Connection reset by peer` | Remote closed connection abruptly | App logs, TLS mismatch |
| `502 Bad Gateway` | Nginx can't reach its upstream | App process running? `nc -zv localhost PORT` |
| `504 Gateway Timeout` | Upstream too slow to respond | App latency, database slow queries |
| `SSL: certificate verify failed` | Chain incomplete or wrong CA | `openssl s_client -showcerts` |
| `Name or service not known` | DNS failure | `dig hostname`, check `/etc/resolv.conf` |
| `No route to host` | Routing table missing the path | `ip route`, `traceroute` |
