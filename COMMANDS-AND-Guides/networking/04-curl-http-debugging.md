# Networking — Part 04: curl — The HTTP Swiss Army Knife

**20-minute read. curl is the most-used tool in a DevOps engineer's daily workflow. Master it.**

---

## curl Fundamentals

`curl` sends HTTP (and other protocol) requests from the command line. It's your primary tool for:
- Testing APIs and health endpoints
- Debugging HTTP headers, redirects, TLS issues
- Uploading files and data
- Automating HTTP interactions in scripts

```bash
# Basic GET request
curl https://vault.example.com/api/health

# Verbose output (-v) — shows headers, TLS handshake, timing
curl -v https://vault.example.com/api/health

# Even more verbose (shows TLS details)
curl -vvv https://vault.example.com/api/health

# Silent mode (no progress bar) — useful in scripts
curl -s https://vault.example.com/api/health

# Silent + show errors (suppress progress but show errors)
curl -sS https://vault.example.com/api/health

# Save output to a file
curl -o response.json https://vault.example.com/api/users
curl -O https://files.example.com/app-v1.0.tar.gz  # saves with original filename
```

---

## Understanding curl -v Output

```bash
curl -v https://vault.example.com/health
```

```
*   Trying 34.100.200.50:443...          ← TCP: trying to connect
* Connected to vault.example.com (34.100.200.50) port 443  ← TCP: connected
* ALPN, offering h2                       ← TLS: negotiating HTTP version
* TLSv1.3 (OUT), TLS handshake, Client hello   ← TLS handshake starts
* TLSv1.3 (IN), TLS handshake, Server hello    ← server responds
* SSL certificate verify ok               ← certificate is valid and trusted
> GET /health HTTP/2                      ← → = request sent by you
> Host: vault.example.com
> User-Agent: curl/7.81.0
> Accept: */*
>
< HTTP/2 200                              ← ← = response received
< content-type: application/json
< date: Tue, 17 Jun 2026 10:00:00 GMT
<
{"status":"ok","version":"1.5.0"}        ← response body
```

Lines prefixed with `*` = informational (TCP/TLS events)
Lines prefixed with `>` = request headers you sent
Lines prefixed with `<` = response headers from server

---

## HTTP Methods

```bash
# GET (default)
curl https://api.example.com/users

# POST with JSON body
curl -X POST https://api.example.com/users \
  -H "Content-Type: application/json" \
  -d '{"name": "Shashank", "email": "shashank@example.com"}'

# POST with form data (like an HTML form)
curl -X POST https://example.com/login \
  -d "username=shashank&password=secret"

# POST a file as body
curl -X POST https://api.example.com/upload \
  -H "Content-Type: application/octet-stream" \
  --data-binary @myfile.bin

# PUT (update resource)
curl -X PUT https://api.example.com/users/123 \
  -H "Content-Type: application/json" \
  -d '{"name": "Shashank Updated"}'

# PATCH (partial update)
curl -X PATCH https://api.example.com/users/123 \
  -H "Content-Type: application/json" \
  -d '{"email": "newemail@example.com"}'

# DELETE
curl -X DELETE https://api.example.com/users/123

# HEAD (get headers only, no body)
curl -I https://vault.example.com/health
```

---

## Headers

```bash
# Send custom headers
curl -H "Authorization: Bearer eyJhbGci..." \
     -H "Content-Type: application/json" \
     -H "X-Request-ID: abc-123" \
     https://api.example.com/data

# Show response headers only (no body)
curl -I https://vault.example.com

# Show BOTH request and response headers (verbose but no body)
curl -sv https://vault.example.com -o /dev/null

# Common authentication headers:
# Bearer token:
curl -H "Authorization: Bearer $TOKEN" https://api.example.com/protected

# Basic auth:
curl -u username:password https://api.example.com/protected
curl -H "Authorization: Basic $(echo -n 'user:pass' | base64)" https://api.example.com/protected

# API key:
curl -H "X-API-Key: your-api-key-here" https://api.example.com/data
```

---

## Handling Responses

```bash
# Show HTTP status code only
curl -s -o /dev/null -w "%{http_code}" https://vault.example.com/health
# Output: 200

# Show status code + headers + body
curl -w "\nHTTP Status: %{http_code}\n" https://api.example.com/users

# All timing info (great for debugging slow APIs)
curl -w "
DNS lookup:     %{time_namelookup}s
TCP connect:    %{time_connect}s
TLS handshake:  %{time_appconnect}s
TTFB:           %{time_starttransfer}s
Total:          %{time_total}s
" -s -o /dev/null https://vault.example.com/api/users
```

This timing output is gold for diagnosing where slowness comes from:
- High `time_namelookup` → DNS is slow
- High `time_connect` → network latency (or firewall adding delay)
- High `time_appconnect` → TLS handshake is slow
- High `time_starttransfer` → app processing is slow

```bash
# Save this as a script: ~/bin/curl-timing
curl -w "
    DNS:        %{time_namelookup}s
    Connect:    %{time_connect}s
    TLS:        %{time_appconnect}s
    Redirect:   %{time_redirect}s
    TTFB:       %{time_starttransfer}s
    ─────────────────────
    Total:      %{time_total}s
    HTTP:       %{http_code}
" -s -o /dev/null "$@"
```

---

## Following Redirects

```bash
# Follow redirects (HTTP 301/302)
curl -L https://vault.example.com/old-path

# Show the redirect chain
curl -Lv https://vault.example.com/old-path 2>&1 | grep -E "Location:|< HTTP"

# Don't follow redirects (see the 301/302 response)
curl https://vault.example.com/old-path    # default: no follow
curl -v https://vault.example.com/old-path 2>&1 | grep Location
```

---

## TLS / SSL Options

```bash
# Skip TLS certificate verification (TESTING ONLY — never in production scripts)
curl -k https://self-signed.example.com
curl --insecure https://self-signed.example.com

# Specify which CA bundle to trust
curl --cacert /path/to/ca.pem https://internal.example.com

# Use a client certificate (mutual TLS / mTLS)
curl --cert client.pem --key client-key.pem https://mtls.example.com

# Force specific TLS version
curl --tlsv1.3 https://vault.example.com

# Show certificate details (without connecting to the app)
curl -vvI https://vault.example.com 2>&1 | grep -A 20 "Server certificate"
```

---

## Connection Options

```bash
# Set timeout (fail if no response in N seconds)
curl --connect-timeout 5 https://api.example.com       # TCP connect timeout
curl --max-time 30 https://api.example.com             # total request timeout

# Retry failed requests
curl --retry 3 --retry-delay 2 https://api.example.com

# Retry on network failures only (not 4xx/5xx errors)
curl --retry 3 --retry-connrefused https://api.example.com

# Connect to specific IP (override DNS — for testing)
curl --resolve vault.example.com:443:10.0.1.50 https://vault.example.com
# Forces curl to connect to 10.0.1.50 but send Host: vault.example.com
# Use this to test a specific backend without changing DNS

# Use a specific network interface
curl --interface eth1 https://api.example.com

# Limit bandwidth (throttle for testing)
curl --limit-rate 100K https://files.example.com/bigfile.tar.gz
```

---

## Proxy Settings

```bash
# Use HTTP proxy
curl -x http://proxy.company.com:8080 https://api.example.com
curl --proxy http://proxy.company.com:8080 https://api.example.com

# Use SOCKS5 proxy (SSH tunnel)
curl --socks5 localhost:1080 https://api.example.com

# Set proxy in environment (affects all curl calls)
export HTTP_PROXY=http://proxy.company.com:8080
export HTTPS_PROXY=http://proxy.company.com:8080
export NO_PROXY=localhost,127.0.0.1,10.0.0.0/8,*.internal.example.com
```

---

## Real-World Recipes

### Health Check Loop

```bash
# Keep checking an endpoint until it returns 200
while true; do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/health)
  echo "$(date): HTTP $STATUS"
  [ "$STATUS" = "200" ] && echo "Service is healthy!" && break
  sleep 5
done
```

### Wait for a Service to Be Ready (CI/CD use)

```bash
# Wait up to 60 seconds for service to be healthy
for i in $(seq 1 12); do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/health 2>/dev/null)
  if [ "$STATUS" = "200" ]; then
    echo "Service ready after ${i}*5 seconds"
    exit 0
  fi
  echo "Waiting... ($i/12) HTTP: $STATUS"
  sleep 5
done
echo "Service did not become healthy in 60 seconds"
exit 1
```

### Test Kubernetes Service From Outside

```bash
# Get the NodePort
NODE_PORT=$(kubectl get service vault-api-service -n production \
  -o jsonpath='{.spec.ports[0].nodePort}')
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}')

curl http://$NODE_IP:$NODE_PORT/health
```

### Authenticate to AWS ECR

```bash
# Get ECR auth token
TOKEN=$(aws ecr get-authorization-token \
  --region ap-south-1 \
  --query 'authorizationData[0].authorizationToken' \
  --output text | base64 -d | cut -d: -f2)

# Use it with curl to list tags
curl -u AWS:$TOKEN \
  https://123456789.dkr.ecr.ap-south-1.amazonaws.com/v2/vault-app/tags/list
```

### Check Prometheus Metrics via HTTP

```bash
# Get all metrics from an app
curl http://vault-api:3000/metrics

# Query PromQL via Prometheus HTTP API
curl "http://prometheus:9090/api/v1/query?query=up{job='vault-api'}"

# Range query
curl "http://prometheus:9090/api/v1/query_range?\
query=rate(http_requests_total[5m])\
&start=$(date -d '1 hour ago' +%s)\
&end=$(date +%s)\
&step=60"
```

---

## Common Misunderstanding: "curl -k is fine for internal services"

**The misunderstanding:** "We're internal — no one can MitM us — so `-k` is fine for our scripts."

**The reality:** `-k` (skip certificate verification) is dangerous even internally because:

1. **Internal attackers**: someone on your internal network can still MitM unverified connections
2. **Misconfiguration catches nothing**: if your cert expires or the wrong cert is served, `-k` hides it silently
3. **Habit formation**: scripts with `-k` get copied to external services accidentally
4. **Compliance**: any security audit will flag `-k` in production scripts

The right way:
```bash
# For internal CA: specify your CA certificate
curl --cacert /etc/ssl/company-ca.pem https://internal-service.company.com

# In Kubernetes: trust the cluster CA
curl --cacert /var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
  https://kubernetes.default.svc.cluster.local/api/v1/namespaces
```

Use `-k` ONLY for one-off manual tests during initial setup. Never in scripts, CI/CD, or production code.

→ Continue to: `05-tcpdump-traffic-analysis.md`
