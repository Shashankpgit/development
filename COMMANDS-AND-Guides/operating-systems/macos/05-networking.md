# macOS — 05: Networking

> **Last updated:** July 7, 2026
> **Network configuration, DNS, diagnostics, and common networking tasks on macOS.**

---

## Network Interfaces

```bash
# List all network interfaces
ifconfig
# or the newer way:
networksetup -listallhardwareports

# Common interfaces:
# en0   → Wi-Fi (or Ethernet on older Macs)
# en1   → Ethernet / second interface
# lo0   → Loopback (127.0.0.1)
# utun0 → VPN tunnel

# Get your current IP address
ipconfig getifaddr en0    # Wi-Fi IP
ipconfig getifaddr en1    # Ethernet IP

# All IPs at once
ifconfig | grep "inet " | grep -v 127.0.0.1
```

---

## networksetup — Network Configuration CLI

`networksetup` is the macOS CLI for network configuration (equivalent to `nmcli` on Linux).

```bash
# List all network services
networksetup -listallnetworkservices
# An asterisk (*) means the service is disabled.
# Wi-Fi
# Ethernet
# Thunderbolt Bridge

# Get IP config for a service
networksetup -getinfo Wi-Fi
# DHCP Configuration
# IP address: 192.168.1.10
# Subnet mask: 255.255.255.0
# Router: 192.168.1.1
# DNS: 192.168.1.1

# Set a static IP
networksetup -setmanual Wi-Fi 192.168.1.50 255.255.255.0 192.168.1.1

# Switch back to DHCP
networksetup -setdhcp Wi-Fi

# Get DNS servers
networksetup -getdnsservers Wi-Fi

# Set DNS servers
networksetup -setdnsservers Wi-Fi 8.8.8.8 8.8.4.4

# Reset to DHCP-provided DNS
networksetup -setdnsservers Wi-Fi "Empty"

# Turn Wi-Fi on/off
networksetup -setairportpower en0 on
networksetup -setairportpower en0 off
```

---

## DNS on macOS

macOS uses its own DNS caching daemon (`mDNSResponder`). When DNS seems broken, flushing the cache often fixes it.

```bash
# Flush DNS cache
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder

# Check current DNS servers
scutil --dns
# Shows all resolvers — system DNS, search domains, VPN-injected DNS

# Query DNS (same as Linux)
dig google.com
dig @8.8.8.8 google.com       # query specific DNS server
nslookup google.com
host google.com

# Check /etc/hosts (same as Linux)
cat /etc/hosts
sudo nano /etc/hosts            # edit to add custom entries
```

---

## Network Diagnostics

```bash
# Test connectivity
ping google.com
ping -c 5 google.com      # 5 pings then stop

# Traceroute (macOS uses UDP by default, unlike Linux which uses ICMP)
traceroute google.com
traceroute -I google.com   # use ICMP (same as Linux's traceroute)

# Network statistics
netstat -an                # all connections
netstat -an | grep LISTEN  # listening ports
netstat -rn                # routing table

# Faster port check with lsof
lsof -i :3000              # what's using port 3000
lsof -i -P | grep LISTEN   # all listening ports

# Check a specific port
lsof -i tcp:80
lsof -i tcp:443

# Test if a port is open on a remote host
nc -zv google.com 443      # -z = scan only, -v = verbose
nc -zv 192.168.1.1 22      # check SSH on router

# Check network speed/bandwidth between machines
brew install iperf3
# On server: iperf3 -s
# On client: iperf3 -c SERVER_IP

# Current connections
ss -tulnp   # not available by default — use netstat or lsof on macOS
```

---

## Wi-Fi Management

```bash
# Connect to a Wi-Fi network
networksetup -setairportnetwork en0 "NetworkName" "password"

# List available Wi-Fi networks
/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -s

# Get info about current Wi-Fi connection
/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I

# Create an alias for the long airport command
alias airport='/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport'
airport -s    # scan for networks
airport -I    # current network info (SSID, BSSID, RSSI, channel)

# Get Wi-Fi password for a saved network (stored in Keychain)
security find-generic-password -D "AirPort network password" -a "NetworkName" -w
```

---

## SSH Configuration

macOS has SSH built in (same OpenSSH as Linux).

```bash
# Generate a new SSH key
ssh-keygen -t ed25519 -C "shashank@vault.example.com"

# Add to SSH agent
eval "$(ssh-agent -s)"
ssh-add --apple-use-keychain ~/.ssh/id_ed25519

# ~/.ssh/config for saved connections
cat ~/.ssh/config
# Host vault-prod
#   HostName 52.66.100.50
#   User ec2-user
#   IdentityFile ~/.ssh/vault-key.pem
#   StrictHostKeyChecking no

# Connect using config alias
ssh vault-prod

# macOS-specific: sharing the SSH agent with tmux/screen
# Add to ~/.zshrc:
# export SSH_AUTH_SOCK="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
# (or the default launchd socket)
```

---

## hosts File and /etc/resolver

```bash
# /etc/hosts — same as Linux, for local hostname overrides
sudo nano /etc/hosts
# 127.0.0.1   dev.vault.local
# 192.168.1.10  db.internal

# /etc/resolver/ — macOS-specific DNS routing
# Route specific domains to different DNS servers
# Useful when corporate VPN injects private DNS for internal domains
sudo mkdir -p /etc/resolver
echo "nameserver 10.0.0.1" | sudo tee /etc/resolver/internal.company.com
# Now: *.internal.company.com resolves via 10.0.0.1 (VPN DNS)
# Everything else: normal DNS
```

---

## Proxy Configuration

```bash
# Set HTTP proxy
networksetup -setwebproxy Wi-Fi proxy.company.com 8080
networksetup -setwebproxystate Wi-Fi on

# Set HTTPS proxy
networksetup -setsecurewebproxy Wi-Fi proxy.company.com 8080

# Disable proxy
networksetup -setwebproxystate Wi-Fi off

# For CLI tools: export HTTP_PROXY for the session
export http_proxy="http://proxy.company.com:8080"
export https_proxy="http://proxy.company.com:8080"
export no_proxy="localhost,127.0.0.1,*.internal"
```

---

## Quick Network Troubleshooting

```bash
# Step 1: Can you ping your router?
ping -c 3 $(networksetup -getinfo Wi-Fi | grep Router | awk '{print $2}')

# Step 2: Can you reach DNS?
ping -c 3 8.8.8.8

# Step 3: Can you resolve DNS?
dig google.com +short

# Step 4: Can you reach a web server?
curl -I https://google.com

# Step 5: Something listening on that port?
lsof -i :PORT

# Nuclear option: flush DNS and reset network
sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder
# Then: System Settings → Network → turn Wi-Fi off and on
```

→ Continue to: `06-in-practice.md`
