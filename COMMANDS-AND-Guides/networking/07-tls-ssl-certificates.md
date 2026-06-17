# Networking — Part 07: TLS/SSL Certificates — Inspect, Debug, Generate

**20-minute read. Certificate issues cause confusing errors. These commands give you X-ray vision into TLS.**

---

## Why TLS Breaks in DevOps Contexts

Common TLS failure scenarios:
- "certificate has expired" (cert expired, needs renewal)
- "certificate verify failed" (wrong CA, self-signed, dev cert in prod)
- "certificate name mismatch" (cert is for `example.com` but you're hitting `api.example.com`)
- "certificate chain incomplete" (intermediate cert not served)
- Internal services can't talk because they don't trust your internal CA
- Kubernetes pods can't talk to the API server (expired cluster certs)

---

## openssl — The TLS Swiss Army Knife

### Inspect a Remote Certificate

```bash
# View the certificate of a running server
openssl s_client -connect vault.example.com:443 -servername vault.example.com < /dev/null
# -servername: sets SNI (Server Name Indication) — needed for servers hosting multiple certs

# Cleaner output (just the certificate)
openssl s_client -connect vault.example.com:443 -servername vault.example.com < /dev/null \
  | openssl x509 -text -noout

# Just the key dates (expiry check)
echo | openssl s_client -connect vault.example.com:443 -servername vault.example.com 2>/dev/null \
  | openssl x509 -noout -dates
# notBefore=Jun  1 00:00:00 2026 GMT
# notAfter=Aug 30 23:59:59 2026 GMT

# Just the Subject and Issuer
echo | openssl s_client -connect vault.example.com:443 2>/dev/null \
  | openssl x509 -noout -subject -issuer
# subject=CN=vault.example.com
# issuer=C=US, O=Let's Encrypt, CN=R3

# Check if cert expires in < 30 days (for alerting scripts)
echo | openssl s_client -connect vault.example.com:443 2>/dev/null \
  | openssl x509 -noout -checkend $((30*24*3600))
# "Certificate will expire" → cert expires within 30 days
# "Certificate will not expire" → still valid for 30+ days
```

### Inspect a Certificate File

```bash
# View certificate from a .crt/.pem file
openssl x509 -in vault.example.com.crt -text -noout

# View just the dates
openssl x509 -in vault.example.com.crt -noout -dates

# View the subject (who this cert is for)
openssl x509 -in vault.example.com.crt -noout -subject

# View Subject Alternative Names (all domains covered by this cert)
openssl x509 -in vault.example.com.crt -noout -ext subjectAltName
# X509v3 Subject Alternative Names:
#     DNS:vault.example.com, DNS:api.vault.example.com, DNS:*.vault.example.com

# View the issuer (who signed this cert)
openssl x509 -in vault.example.com.crt -noout -issuer

# View the fingerprint (unique identifier for the cert)
openssl x509 -in vault.example.com.crt -noout -fingerprint -sha256

# Convert DER format to PEM
openssl x509 -inform DER -in cert.der -out cert.pem

# Convert PEM to DER
openssl x509 -outform DER -in cert.pem -out cert.der
```

### Inspect a Private Key

```bash
# Check if a key file is valid
openssl rsa -in private.key -check

# View key details
openssl rsa -in private.key -text -noout

# Verify a certificate and key match (they must share the same public key)
openssl x509 -in cert.pem -noout -modulus | openssl md5
openssl rsa -in private.key -noout -modulus | openssl md5
# Both must produce the same MD5 hash — if different, they DON'T match
```

---

## Generating Certificates

### Self-Signed Certificate (For Internal/Dev Use)

```bash
# Generate a self-signed cert in one command
openssl req -x509 -newkey rsa:4096 \
  -keyout private.key \
  -out cert.pem \
  -days 365 \
  -nodes \
  -subj "/C=IN/ST=Karnataka/L=Bangalore/O=Sanketika/CN=vault.internal.example.com"
# -nodes = no password on the private key (for automated use)
# -x509 = output a self-signed certificate, not a CSR
# -days 365 = valid for 1 year

# Generate with Subject Alternative Names (SANs) — required by modern browsers
openssl req -x509 -newkey rsa:4096 \
  -keyout private.key -out cert.pem \
  -days 365 -nodes \
  -subj "/CN=vault.internal" \
  -addext "subjectAltName=DNS:vault.internal,DNS:*.vault.internal,IP:10.0.1.50"
```

### Generate a Certificate Signing Request (CSR)

A CSR is what you send to a Certificate Authority (Let's Encrypt, DigiCert, etc.) to get a signed certificate.

```bash
# Step 1: Generate a private key
openssl genrsa -out private.key 4096

# Step 2: Generate the CSR
openssl req -new \
  -key private.key \
  -out vault.csr \
  -subj "/CN=vault.example.com/O=MyCompany/C=IN"

# With SANs (create a config file):
cat > san.conf << EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name

[req_distinguished_name]

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = vault.example.com
DNS.2 = api.vault.example.com
DNS.3 = *.vault.example.com
EOF

openssl req -new -key private.key -out vault.csr \
  -subj "/CN=vault.example.com" \
  -config san.conf

# Verify the CSR
openssl req -in vault.csr -noout -text
```

---

## Let's Encrypt with Certbot

```bash
# Install Certbot
sudo apt install certbot python3-certbot-nginx

# Issue a certificate (nginx plugin — automatically configures nginx)
sudo certbot --nginx -d vault.example.com -d api.vault.example.com

# Issue without web server (standalone — temporarily uses port 80)
sudo certbot certonly --standalone -d vault.example.com

# Issue using DNS challenge (for wildcard certs)
sudo certbot certonly --manual --preferred-challenges dns \
  -d "*.vault.example.com"
# Certbot tells you: add this TXT record to your DNS
# _acme-challenge.vault.example.com → <token>

# Renew all certificates
sudo certbot renew

# Dry run renewal (test without actually renewing)
sudo certbot renew --dry-run

# Certificates are stored in:
ls /etc/letsencrypt/live/vault.example.com/
# cert.pem      → your certificate
# chain.pem     → intermediate CA certificates
# fullchain.pem → cert + chain (use this in nginx)
# privkey.pem   → your private key
```

---

## Kubernetes Certificate Management

```bash
# Check Kubernetes cluster certificates expiry
sudo kubeadm certs check-expiration
# CERTIFICATE                EXPIRES                  RESIDUAL TIME   
# admin.conf                 Jun 17, 2027 10:00 UTC   364d            
# apiserver                  Jun 17, 2027 10:00 UTC   364d            
# etcd-ca                    Jun 13, 2036 10:00 UTC   9y              
# WARNING: some certs expire soon or are already expired

# Renew all certificates (on control plane node, run annually)
sudo kubeadm certs renew all
# Then restart API server, controller, scheduler, etcd

# View the cluster CA cert
cat /etc/kubernetes/pki/ca.crt | openssl x509 -noout -dates

# Check cert used by a pod's service account
kubectl get secret vault-api-sa-token -n production \
  -o jsonpath='{.data.ca\.crt}' | base64 -d | openssl x509 -noout -dates
```

### cert-manager — Automatic Certificate Management in Kubernetes

```bash
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Wait for it to be ready
kubectl wait --for=condition=ready pod -l app=cert-manager -n cert-manager

# Create a Let's Encrypt ClusterIssuer
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: shashank@sanketika.in
    privateKeySecretRef:
      name: letsencrypt-prod-key
    solvers:
      - http01:
          ingress:
            class: nginx
EOF

# Request a certificate (cert-manager handles it automatically)
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: vault-tls
  namespace: production
spec:
  secretName: vault-tls-secret
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
    - vault.example.com
    - api.vault.example.com
EOF

# Check certificate status
kubectl get certificate -n production
kubectl describe certificate vault-tls -n production

# Certificate automatically renews 30 days before expiry
```

---

## Debugging TLS Issues

### "Certificate verify failed"

```bash
# What CA is the cert signed by?
echo | openssl s_client -connect vault.example.com:443 2>/dev/null \
  | openssl x509 -noout -issuer
# issuer=CN=R3, O=Let's Encrypt, C=US

# Can your system verify the chain?
echo | openssl s_client -connect vault.example.com:443 -verify_return_error 2>&1 | grep "Verify"
# Verify return code: 0 (ok)  → working
# Verify return code: 20 (unable to get local issuer certificate) → CA not trusted

# Add a CA to your system trust store
sudo cp company-ca.crt /usr/local/share/ca-certificates/
sudo update-ca-certificates
```

### "Certificate name mismatch"

```bash
# What names does the cert cover?
echo | openssl s_client -connect vault.example.com:443 2>/dev/null \
  | openssl x509 -noout -ext subjectAltName
# If "api.vault.example.com" is NOT in the SANs → name mismatch
```

### "Certificate has expired"

```bash
# Quick expiry check
echo | openssl s_client -connect vault.example.com:443 2>/dev/null \
  | openssl x509 -noout -dates

# Check days remaining
EXPIRY=$(echo | openssl s_client -connect vault.example.com:443 2>/dev/null \
  | openssl x509 -noout -enddate | cut -d= -f2)
EXPIRY_EPOCH=$(date -d "$EXPIRY" +%s)
NOW_EPOCH=$(date +%s)
DAYS_LEFT=$(( ($EXPIRY_EPOCH - $NOW_EPOCH) / 86400 ))
echo "Days until expiry: $DAYS_LEFT"
```

---

## Common Misunderstanding: "My cert is valid but curl still fails with 'certificate verify failed'"

**The misunderstanding:** "The certificate expires in 6 months — it can't be a cert issue."

**The reality:** "Certificate verify failed" rarely means the cert has expired. It usually means:

1. **Incomplete chain**: the server is only serving its leaf cert but not the intermediate CAs. The browser auto-downloads intermediates; curl does not.
   ```bash
   # Check what the server is sending
   echo | openssl s_client -connect vault.example.com:443 -showcerts 2>/dev/null \
     | grep -c "BEGIN CERTIFICATE"
   # 1 → only the leaf cert (missing intermediate) → PROBLEM
   # 2 or 3 → full chain is being served → OK
   
   # Fix: in nginx, use fullchain.pem (not just cert.pem)
   ssl_certificate /etc/letsencrypt/live/vault.example.com/fullchain.pem;
   ```

2. **Self-signed cert**: the CA that signed it isn't trusted by the client.
   ```bash
   curl --cacert /path/to/custom-ca.pem https://internal-service
   ```

3. **Wrong SNI**: you're hitting an IP or load balancer that serves a different cert.
   ```bash
   # Force a specific SNI
   curl --resolve vault.example.com:443:10.0.1.50 https://vault.example.com
   ```

→ Continue to: `08-network-performance-ping-traceroute.md`
