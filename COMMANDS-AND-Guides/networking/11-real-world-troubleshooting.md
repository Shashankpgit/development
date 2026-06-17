# Networking — Part 11: Real-World Troubleshooting Playbook

**20-minute read. 10 complete scenarios you'll actually face as a DevOps engineer. Work through them.**

---

## The Systematic Debugging Framework

Before any scenario, apply this mental model. Networking problems always fit one of these:

```
1. Can they reach each other at Layer 3 (IP)?
   → ping, traceroute, mtr, ip route

2. Can they connect at Layer 4 (TCP/UDP)?
   → nc, ss, telnet, tcpdump

3. Is the application listening correctly?
   → ss -tlnp, docker exec ss -tlnp, kubectl exec

4. Is DNS resolving correctly?
   → dig, nslookup, dig @specific-server

5. Is TLS/authentication failing?
   → curl -v, openssl s_client, certificate dates

6. Is the firewall blocking it?
   → iptables -L, ufw status, cloud security groups, tcpdump (SYN without SYN-ACK)
```

Always go bottom-up (IP → TCP → App → DNS → TLS → Firewall). Don't jump straight to "check the app logs" — you'll miss firewall issues entirely.

---

## Scenario 1: "Pod can't connect to the database"

```
Error: "FATAL: password authentication failed" in pod logs
```

Wait — authentication failed is NOT a networking problem. You can connect; the credentials are wrong. But let's do it right anyway.

```bash
# Step 1: Verify it's connectivity (not auth)
kubectl exec -it vault-api-7d4b9c -n production -- \
  nc -zv postgres-service.production.svc.cluster.local 5432
# If "Connection refused" → service/pod isn't running
# If "Connection timed out" → NetworkPolicy blocking
# If "succeeded" → connectivity fine, it IS an auth issue

# Step 2: Check if the service exists
kubectl get service postgres-service -n production

# Step 3: Check if the service has endpoints (pods behind it)
kubectl get endpoints postgres-service -n production

# Step 4: Check what address the app is using
kubectl exec -it vault-api -n production -- env | grep -E "DB|DATABASE|POSTGRES"
# DATABASE_URL=postgresql://vaultadmin:password@postgres-service:5432/vault

# Step 5: Check if the Secret has the right password
kubectl get secret postgres-secret -n production \
  -o jsonpath='{.data.password}' | base64 -d

# Step 6: Test the connection manually from the pod
kubectl exec -it vault-api -n production -- \
  psql "postgresql://vaultadmin:$(kubectl get secret postgres-secret -n production -o jsonpath='{.data.password}' | base64 -d)@postgres-service:5432/vault" -c "SELECT 1"
```

---

## Scenario 2: "Nginx returns 502 Bad Gateway"

502 means Nginx is running and received your request, but the backend it tried to forward to is unavailable.

```bash
# Step 1: Check nginx error log
tail -50 /var/log/nginx/error.log
# or in Docker:
docker logs nginx | tail -50
# or in Kubernetes:
kubectl logs -n production deployment/nginx | tail -50
# Look for: "connect() failed (111: Connection refused)"
#            "no live upstreams while connecting to upstream"

# Step 2: Find what upstream nginx is trying to reach
cat /etc/nginx/sites-enabled/vault.conf | grep proxy_pass
# proxy_pass http://localhost:3000;
# proxy_pass http://vault-api-service:80;

# Step 3: Test if the upstream is actually listening
nc -zv localhost 3000
# or (from nginx container):
docker exec nginx nc -zv vault-api 3000

# Step 4: Check upstream process
ss -tlnp | grep 3000
# If nothing → app not running
# If 127.0.0.1:3000 → app running but nginx tries to reach it differently

# Step 5: Check app logs for crashes
journalctl -u vault-api --since "10 minutes ago"
# or:
kubectl logs -n production deployment/vault-api --tail=100
```

---

## Scenario 3: "Intermittent 504 Gateway Timeout"

504 means Nginx sent the request to the backend but the backend took too long to respond.

```bash
# Step 1: Find if it's app slowness or network drops
# Check how long requests take
curl -w "TTFB: %{time_starttransfer}s, Total: %{time_total}s\n" \
  -s -o /dev/null https://vault.example.com/api/users
# Run this 20 times:
for i in $(seq 1 20); do
  curl -w "$i: %{time_total}s %{http_code}\n" -s -o /dev/null https://vault.example.com/api/users
done
# Look for occasional 60s+ responses → nginx timeout

# Step 2: Check nginx timeout config
grep -E "proxy_read_timeout|proxy_connect_timeout|proxy_send_timeout" /etc/nginx/nginx.conf

# Step 3: Check if app is actually slow (database slow?)
kubectl logs deployment/vault-api -n production | grep -E "slow|timeout|duration"

# Step 4: Check database slow query log
kubectl exec postgres-0 -n production -- \
  psql -U postgres -c "SELECT pid, now() - pg_stat_activity.query_start AS duration, query FROM pg_stat_activity WHERE (now() - pg_stat_activity.query_start) > interval '5 seconds'"

# Step 5: Check if pod is being killed and restarted during requests
kubectl get pods -n production vault-api-7d4b9c-xyz -w
# RESTARTS column increasing → pod crashes → in-flight requests fail with 504
```

---

## Scenario 4: "After deploying, health checks fail for 30 seconds"

```bash
# This is a missing/misconfigured readinessProbe

# Step 1: Check if pod has a readiness probe
kubectl describe pod vault-api-7d4b9c -n production | grep -A 10 Readiness

# Step 2: Check if the health endpoint works during startup
kubectl logs vault-api-7d4b9c -n production | head -20
# Look for: when does "Server started, listening on port 3000" appear?

# The problem: K8s sends traffic before the app is ready

# Fix: add a readinessProbe with initialDelaySeconds
spec:
  containers:
    - name: vault-api
      readinessProbe:
        httpGet:
          path: /health
          port: 3000
        initialDelaySeconds: 10   # don't check for 10s after container starts
        periodSeconds: 5
        failureThreshold: 3

# Step 3: Check if there's a service endpoint during rollout
kubectl get endpoints vault-api-service -n production -w
# Watch: during rolling update, old pod is removed BEFORE new pod is ready → 502s
# Fix: maxUnavailable: 0, maxSurge: 1 in deployment strategy
```

---

## Scenario 5: "External Traffic Can't Reach the Kubernetes Service"

```bash
# The service is running. kubectl port-forward works. External IP times out.

# Step 1: Check if Ingress has an external IP
kubectl get ingress -n production
# If ADDRESS is empty → Ingress controller or cloud LB not provisioned

# Step 2: Check Ingress controller
kubectl get pods -n ingress-nginx
kubectl describe service ingress-nginx-controller -n ingress-nginx
# If EXTERNAL-IP is <pending> → cloud LB not assigned yet (wait 2 minutes)

# Step 3: DNS pointing to the right IP?
dig vault.example.com
# Compare the IP with the Ingress ADDRESS

# Step 4: Test bypassing DNS
curl -H "Host: vault.example.com" http://INGRESS-IP/health

# Step 5: Check Ingress rules
kubectl describe ingress vault-ingress -n production
# Events section shows if there are configuration errors

# Step 6: Ingress controller logs
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller | tail -50
# Look for errors routing to vault-api-service
```

---

## Scenario 6: "VPN connected but internal services still unreachable"

```bash
# VPN says connected. Still can't reach 10.0.1.50.

# Step 1: Check routing table after VPN connection
ip route show
# Should have: 10.0.0.0/8 dev tun0  or  10.0.1.0/24 dev utun3
# If 10.0.1.0/24 is missing → VPN not setting up routes

# Step 2: Verify the VPN interface exists
ip addr show | grep tun
# Should show: tun0 or utun or wg0

# Step 3: Try to reach the VPN gateway itself
ping 10.10.0.1   # your VPN gateway's internal IP (from VPN client settings)

# Step 4: Trace the route to internal host
traceroute -n 10.0.1.50
# Should go through VPN gateway (10.10.0.1)
# If goes via home router → split tunnel not routing to 10.0.1.0/24

# Step 5: Check DNS inside VPN (can VPN provide resolution?)
dig @10.10.0.1 internal-server.company.com
# If fails → VPN's DNS not reachable

# Step 6: Force traffic through VPN for the specific subnet
sudo ip route add 10.0.1.0/24 via 10.10.0.1 dev tun0
```

---

## Scenario 7: "New Node Added to Kubernetes — Pods Not Scheduling on It"

```bash
# kubectl scale deployment vault-api --replicas=10
# All new pods go to old nodes, never to the new node

# Step 1: Check new node status
kubectl get nodes
# NAME          STATUS   ROLES   AGE
# new-worker    NotReady  <none>  5m   ← NotReady → can't schedule

# Step 2: Check what's wrong
kubectl describe node new-worker | tail -30
# Conditions section:
# NetworkPluginNotReady: "network plugin is not ready: cni config uninitialized"
# → CNI plugin (Flannel/Calico) hasn't started on this node yet

# Wait for it:
kubectl get pods -n kube-flannel --field-selector spec.nodeName=new-worker
# If no pod → DaemonSet not deployed (node might have a taint)

# Step 3: Check for taints
kubectl describe node new-worker | grep Taints
# node.kubernetes.io/not-ready:NoSchedule  ← kubelet adds this when NotReady

# Step 4: Check CNI pod logs
kubectl logs -n kube-flannel daemonset/kube-flannel-ds \
  --field-selector spec.nodeName=new-worker

# Step 5: Manually check routes on new node
ssh new-worker
ip route show
# Is there a route for the pod CIDR (10.244.0.0/16)?
```

---

## Scenario 8: "High Latency to S3 from EC2 Despite Being in Same Region"

```bash
# App uploads to S3. Latency is 200ms. Should be < 5ms in same region.

# Step 1: Check if you're using the right endpoint
curl -w "Total: %{time_total}s\n" -s -o /dev/null \
  https://s3.ap-south-1.amazonaws.com/

# Step 2: Are you hitting the correct regional endpoint?
curl -v https://my-bucket.s3.amazonaws.com/ 2>&1 | grep -E "Trying|Location"
# If redirecting to another region → requests are crossing regions

# Step 3: Check if traffic is going through a proxy
env | grep -i proxy
# HTTP_PROXY=http://corporate-proxy:8080
# → All S3 traffic goes through the proxy (huge latency)
# unset HTTP_PROXY HTTPS_PROXY and test again

# Step 4: Check VPC Endpoint (traffic should stay in AWS network)
aws ec2 describe-vpc-endpoints --region ap-south-1
# If no S3 endpoint → traffic leaves AWS to public internet and back
# Fix: create a VPC Endpoint for S3 (free, keeps traffic private)
aws ec2 create-vpc-endpoint \
  --vpc-id vpc-12345 \
  --service-name com.amazonaws.ap-south-1.s3 \
  --route-table-ids rtb-12345

# Step 5: Verify you're using the right DNS name
nslookup my-bucket.s3.ap-south-1.amazonaws.com
# Should resolve to a 10.x.x.x IP (VPC endpoint, stays internal)
# If resolves to 52.x.x.x (public IP) → VPC endpoint not working
```

---

## Scenario 9: "Certificate Expired — Everything Is Down"

```bash
# HTTP 525 or "SSL certificate expired" — production is down

# Step 1: Confirm expiry
echo | openssl s_client -connect vault.example.com:443 2>/dev/null \
  | openssl x509 -noout -dates
# notAfter=Jun 16 00:00:00 2026 GMT  ← yesterday!

# Step 2: Immediate temporary fix (if using nginx)
# If Let's Encrypt: force renew
sudo certbot renew --force-renewal

# If using cert-manager in K8s: delete and re-create the certificate
kubectl delete certificate vault-tls -n production
kubectl apply -f vault-certificate.yaml
kubectl get certificate vault-tls -n production -w
# Wait for READY=True

# Step 3: Reload nginx to pick up new cert
sudo nginx -t && sudo nginx -s reload
# or in K8s:
kubectl rollout restart deployment/nginx -n production

# Step 4: Verify cert is now valid
echo | openssl s_client -connect vault.example.com:443 2>/dev/null \
  | openssl x509 -noout -dates

# Step 5: Set up monitoring to prevent recurrence
# Alert when cert expires in < 30 days:
while read domain; do
  DAYS=$(echo | openssl s_client -connect $domain:443 -servername $domain 2>/dev/null \
    | openssl x509 -noout -enddate | cut -d= -f2 \
    | awk '{print (mktime(sprintf("%s %02d %02d %02d %02d %02d", $4, \
      (match("JanFebMarAprMayJunJulAugSepOctNovDec",$1)+2)/3, $2, \
      substr($3,1,2), substr($3,4,2), substr($3,7,2))) - systime()) / 86400}')
  echo "$domain: $DAYS days remaining"
done <<< "vault.example.com
api.vault.example.com
admin.vault.example.com"
```

---

## Scenario 10: "Service is Slow Only for Some Users"

```bash
# 10% of users report 5-10 second page loads. 90% are fine.

# Step 1: Is it location-based? (different regions, CDN issue)
curl -w "Total: %{time_total}s\n" -s -o /dev/null https://vault.example.com/   # your location
# Ask colleagues in different regions to run the same

# Step 2: Is it specific pods? (one pod is unhealthy)
# Make multiple requests and see which pod handles them
for i in $(seq 1 20); do
  curl -s https://vault.example.com/api/debug/instance
  # Your app should return its pod name/IP
done | sort | uniq -c
# 18 vault-api-7d4b9c-xyz
#  1 vault-api-8e5c1d-abc  ← this pod handles rarely → and is slow

# Check that specific pod
kubectl top pod vault-api-8e5c1d-abc -n production
kubectl describe pod vault-api-8e5c1d-abc -n production
kubectl logs vault-api-8e5c1d-abc -n production | tail -100

# Step 3: Is it IPv4 vs IPv6 connectivity?
# Some users connect via IPv6, others via IPv4 → different paths
curl -6 https://vault.example.com  # force IPv6
curl -4 https://vault.example.com  # force IPv4

# Step 4: Is the load balancer health check working?
# If one node is marked unhealthy by LB but NOT removed → it still gets ~1/N traffic
kubectl get pods -n production -o wide | grep NotReady

# Step 5: Traces or slow query logs
# Check if database queries are slow for specific users
kubectl logs vault-api-7d4b9c -n production | grep "took [0-9]" | sort -t= -k2 -rn | head
```

---

## The 5-Minute Network Debug Checklist

Keep this as a reference when something's broken:

```bash
#!/bin/bash
# Quick network debug — run this first

echo "=== IP Addresses ==="
ip addr show | grep inet

echo "=== Routing Table ==="
ip route show

echo "=== Listening Ports ==="
ss -tlnp

echo "=== DNS Resolution ==="
dig +short google.com @8.8.8.8      # external DNS
dig +short kubernetes.default        # cluster DNS (if on K8s)

echo "=== Connectivity Tests ==="
ping -c 3 8.8.8.8                   # IP connectivity
nc -zv 8.8.8.8 443 2>&1 | head -1  # TCP connectivity

echo "=== Active Connections ==="
ss -tn state established | head -20

echo "=== Recent Network Errors ==="
dmesg | grep -i "eth\|net\|link" | tail -10
```

---

## Common Misunderstanding: "Networking fixed itself — must have been a fluke"

**The misunderstanding:** "The issue went away after a few minutes — must have been transient."

**The reality:** Most "transient" networking issues have an exact cause:
- "Worked after restart" → a pod was stuck in NotReady, restart triggered scheduler to use another pod
- "Worked after 5 minutes" → DNS TTL expired and now resolves to correct IP
- "Works sometimes" → load balancer has one unhealthy backend it sometimes routes to
- "Worked after retrying" → TCP retransmission succeeded after a congested window

When something "heals itself," dig in before moving on — capture what changed with `ip route`, `kubectl get pods`, `ss -tn`. Transient issues recur. Understanding WHY they healed tells you what the root cause was.

→ Continue to: `README.md`
