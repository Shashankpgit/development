# Networking — Part 02: DNS Commands and Debugging

**20-minute read. DNS failures are the #1 cause of "it works on my machine" problems in production.**

---

## How DNS Works (The 30-Second Version)

```
Your app: "What's the IP of postgres-service.production.svc.cluster.local?"
         ↓
/etc/resolv.conf says: ask 10.96.0.10 (the Kubernetes CoreDNS server)
         ↓
CoreDNS: "postgres-service.production → 10.96.45.23"
         ↓
Your app connects to 10.96.45.23
```

When DNS fails, the error is often misleading:
- "connection refused" instead of "DNS resolution failed"  
- Long timeout (30s) before the error appears
- Works with IP directly, fails with hostname

---

## The Four DNS Files You Must Know

### /etc/resolv.conf — Which DNS Servers to Use

```bash
cat /etc/resolv.conf
```

```
nameserver 10.96.0.10       ← first: Kubernetes CoreDNS (cluster DNS)
nameserver 8.8.8.8          ← fallback: Google DNS
search production.svc.cluster.local svc.cluster.local cluster.local
#      └── search domains: "postgres" automatically becomes
#           "postgres.production.svc.cluster.local" then
#           "postgres.svc.cluster.local" etc.
options ndots:5
#        └── names with < 5 dots are tried with search domains first
```

**On Kubernetes pods:** `/etc/resolv.conf` is injected by kubelet. The nameserver is CoreDNS. If pods can't resolve cluster DNS, check CoreDNS pods.

### /etc/hosts — Static DNS Overrides (Checked First)

```bash
cat /etc/hosts
```

```
127.0.0.1   localhost
::1         localhost ip6-localhost
10.0.1.50   vault-api vault-api.production.example.com
```

`/etc/hosts` is checked BEFORE DNS. Adding an entry here overrides DNS entirely for that name. Useful for testing (point a hostname at a staging server without changing real DNS).

### /etc/nsswitch.conf — Resolution Order

```bash
grep hosts /etc/nsswitch.conf
# hosts: files dns myhostname
#          └──   └── order: files (/etc/hosts) first, then DNS
```

---

## dig — The DNS Debugging Tool

`dig` (Domain Information Groper) is what real DNS debugging looks like. It shows you exactly what the DNS server returned.

### Basic Query

```bash
dig google.com

# Output:
; <<>> DiG 9.16.1 <<>> google.com
;; QUESTION SECTION:
;google.com.                    IN      A

;; ANSWER SECTION:
google.com.             208     IN      A       142.250.195.46
#         └── TTL(s)    └── class  └── type  └── IP address

;; Query time: 12 msec
;; SERVER: 8.8.8.8#53(8.8.8.8)   ← which DNS server answered
;; WHEN: Tue Jun 17 10:00:00 IST 2026
```

### Query Specific Record Types

```bash
# A record (IPv4 address)
dig vault.example.com A

# AAAA record (IPv6 address)
dig vault.example.com AAAA

# MX record (mail servers)
dig example.com MX

# CNAME record (alias to another name)
dig www.example.com CNAME

# NS record (authoritative nameservers for the domain)
dig example.com NS

# TXT record (SPF, DKIM, domain verification)
dig example.com TXT

# SOA record (Start of Authority — who manages this zone)
dig example.com SOA

# ANY (get all records — often blocked by modern DNS servers)
dig example.com ANY

# PTR record (reverse DNS — IP to hostname)
dig -x 8.8.8.8
# Returns: dns.google.
```

### Query a Specific DNS Server

```bash
# Ask Google's DNS (bypass your /etc/resolv.conf)
dig @8.8.8.8 vault.example.com

# Ask Cloudflare's DNS
dig @1.1.1.1 vault.example.com

# Ask your Kubernetes CoreDNS directly
dig @10.96.0.10 postgres-service.production.svc.cluster.local

# Test if DNS works at all (ask directly, not through your resolver)
dig @8.8.8.8 google.com
# If this works but "dig google.com" fails → your /etc/resolv.conf is broken
```

### Short Output (Just the Answer)

```bash
dig +short vault.example.com
# 34.100.200.50

dig +short vault.example.com MX
# 10 mail.vault.example.com.

# No answer = name doesn't exist or DNS server unreachable
```

### Trace DNS Resolution (Full Path)

```bash
dig +trace vault.example.com
# Shows every step: root servers → TLD (.com) nameservers → authoritative NS → answer
# Use this to find exactly where the DNS chain breaks
```

### Check TTL (How Long Until DNS Refreshes)

```bash
dig vault.example.com
# ANSWER SECTION:
# vault.example.com.   300   IN   A   34.100.200.50
#                       └── 300 seconds = 5 minutes until this is refreshed

# If you just changed a DNS record, wait for TTL to expire on your machine:
dig +nocmd +noall +answer vault.example.com
# 300 seconds left → wait 5 minutes, then check again
```

---

## nslookup — The Simple Alternative

`nslookup` is simpler but less powerful. Useful for quick checks:

```bash
nslookup vault.example.com           # basic lookup
nslookup vault.example.com 8.8.8.8   # using Google DNS
nslookup -type=MX example.com        # specific record type
```

Interactive mode:
```bash
nslookup
> server 10.96.0.10     # use CoreDNS
> postgres-service.production.svc.cluster.local
> set type=SRV
> _http._tcp.vault.example.com
> exit
```

---

## host — The Simplest Lookup

```bash
host vault.example.com           # quick lookup
host 34.100.200.50               # reverse lookup
host -t MX example.com           # specific type
host -v vault.example.com        # verbose (like dig but friendlier)
```

---

## Kubernetes DNS Deep Dive

In Kubernetes, CoreDNS handles DNS for all pods. Understanding Kubernetes DNS patterns is critical for DevOps.

### DNS Name Formats

```
<service>.<namespace>.svc.cluster.local    ← full name, always works
<service>.<namespace>                       ← works within any namespace
<service>                                   ← works within SAME namespace only
```

```bash
# From a pod in the "production" namespace:
curl http://vault-api-service             # works (same namespace)
curl http://vault-api-service.production  # works (any namespace)
curl http://vault-api-service.production.svc.cluster.local  # always works

# From a pod in the "monitoring" namespace:
curl http://vault-api-service             # FAILS (different namespace)
curl http://vault-api-service.production  # works
```

### Debug DNS in Kubernetes

```bash
# Run a temporary pod to debug DNS
kubectl run dns-debug \
  --image=busybox:1.28 \
  --rm -it \
  --restart=Never \
  -- sh

# Inside the debug pod:
nslookup kubernetes.default           # test basic cluster DNS
nslookup vault-api-service.production # test cross-namespace service
cat /etc/resolv.conf                  # see what DNS server the pod uses
wget -qO- http://vault-api-service.production/health  # test actual connectivity

# Check CoreDNS is running
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl logs -n kube-system -l k8s-app=kube-dns

# Check CoreDNS config
kubectl get configmap coredns -n kube-system -o yaml
```

### CoreDNS Config (What It Looks Like)

```
# CoreDNS Corefile (in the coredns ConfigMap)
.:53 {
    errors
    health
    ready
    kubernetes cluster.local in-addr.arpa ip6.arpa {
       pods insecure
       fallthrough in-addr.arpa ip6.arpa
    }
    prometheus :9153         ← CoreDNS exposes Prometheus metrics here
    forward . /etc/resolv.conf   ← external names go to the node's resolver
    cache 30
    loop
    reload
    loadbalance
}
```

### CoreDNS Metrics (Prometheus)

```promql
# DNS query rate
rate(coredns_dns_requests_total[5m])

# DNS error rate (SERVFAIL, NXDOMAIN)
rate(coredns_dns_responses_total{rcode!="NOERROR"}[5m])

# DNS latency P99
histogram_quantile(0.99, rate(coredns_dns_request_duration_seconds_bucket[5m]))
```

---

## Real-World Scenario 1: "App can't connect to the database"

```bash
# Error: "could not translate host name 'postgres-service' to address"
# → This is a DNS failure, not a database failure!

# Step 1: Check from inside the app's pod
kubectl exec -it vault-api-7d4b9c-xyz -n production -- sh

# Step 2: Test DNS resolution
nslookup postgres-service
# If NXDOMAIN → service name is wrong, or you're in the wrong namespace

nslookup postgres-service.production.svc.cluster.local
# If this works → your app code uses the short name, which fails cross-namespace

# Step 3: Verify the service exists
kubectl get service postgres-service -n production
# If "not found" → service doesn't exist (wrong name, wrong namespace)

# Step 4: Check the service has endpoints (pods)
kubectl get endpoints postgres-service -n production
# If ENDPOINTS is <none> → no pods match the service selector

# Step 5: From outside the cluster, use port-forward to test
kubectl port-forward service/postgres-service 5432:5432 -n production
psql -h localhost -p 5432 -U vaultuser -d vault
```

---

## Real-World Scenario 2: External DNS Is Broken on a Server

```bash
# "curl google.com" hangs or fails

# Step 1: Can you reach any IP directly?
ping 8.8.8.8    # if this fails → no internet, not DNS

# Step 2: Can you query DNS at all?
dig @8.8.8.8 google.com
# If ANSWER SECTION has an IP → DNS server is reachable, it's a local config issue

# Step 3: Check what DNS server you're using
cat /etc/resolv.conf
# nameserver 127.0.0.53 → systemd-resolved is your resolver
# nameserver 10.0.1.1   → your DHCP-provided DNS

# Step 4: Check if systemd-resolved is working
systemd-resolve --status
systemd-resolve google.com
resolvectl query google.com  # newer name for systemd-resolve

# Step 5: Check if the DNS server is reachable
nc -u -w 2 8.8.8.8 53    # -u = UDP, -w 2 = timeout 2s
# No error + "nc: idle timeout expired" = port is reachable

# Step 6: Quick fix if DNS server is broken
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf
# Warning: this may be overwritten by NetworkManager/DHCP on next update
```

---

## Common Misunderstanding: "DNS TTL is how long the record is cached globally"

**The misunderstanding:** "I set TTL to 300 seconds — the change will propagate in 5 minutes worldwide."

**The reality:** TTL is how long each resolver is *allowed* to cache the answer. The propagation time depends on:
1. How long YOUR old record was cached at each resolver (the previous TTL)
2. How quickly each resolver refreshes after expiry
3. Some resolvers ignore TTL and have minimum cache times (often 5 minutes)

Best practice before a DNS-involved migration:
```
1 week before: lower TTL from 3600 → 60 seconds
   (wait for old 3600s TTL caches to expire everywhere)
During migration: change the A record
   (now all caches expire in ≤ 60 seconds)
After stable: raise TTL back to 3600
   (reduces load on your DNS servers)
```

If you change a DNS record with TTL=3600 and wonder why it's taking an hour to propagate — that's exactly why.

→ Continue to: `03-connection-and-port-testing.md`
