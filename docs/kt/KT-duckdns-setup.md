# KT — DuckDNS Domain Setup

## What is DuckDNS

DuckDNS is a free dynamic DNS service. It gives you a subdomain under `*.duckdns.org` that you can point to any IP address. You manage the IP via their website or API.

It's called "dynamic" DNS because it's designed for IPs that change (like home routers). We're using it because it's free and works perfectly for a learning deployment.

---

## Step 1 — Create a DuckDNS account

1. Go to **duckdns.org**
2. Sign in with Google, GitHub, Reddit, or Twitter (any one)
3. You'll land on your dashboard

---

## Step 2 — Create a subdomain

On the dashboard:

1. In the **"sub domain"** field, type a name — for example: `vault-shashank`
   - Pick something unique. It will become `vault-shashank.duckdns.org`
   - Only lowercase letters, numbers, hyphens allowed
2. In the **"current ip"** field, type your VM's IP: `8.231.93.159`
3. Click **"add domain"**

You should see your new subdomain listed with IP `8.231.93.159`.

---

## Step 3 — Verify DNS is working

Wait 1–2 minutes (DNS propagation), then run this from your local machine:

```bash
ping vault-shashank.duckdns.org
```

Expected output:
```
PING vault-shashank.duckdns.org (8.231.93.159) ...
```

The IP in brackets must match `8.231.93.159`. If it doesn't resolve yet, wait another minute and try again.

You can also verify with:
```bash
nslookup vault-shashank.duckdns.org
```

---

## What just happened

```
vault-shashank.duckdns.org
        │
        ▼  DNS lookup
   8.231.93.159   ← your GCP VM
```

Any browser that visits `http://vault-shashank.duckdns.org` will now reach your VM on port 80. HTTPS (port 443) comes in the next step when we set up Let's Encrypt.

---

## Note your domain name

Write it down — this exact string will be used in every config file we update:

```
YOUR_DOMAIN = vault-shashank.duckdns.org
```

Replace `vault-shashank` with whatever subdomain you chose.
