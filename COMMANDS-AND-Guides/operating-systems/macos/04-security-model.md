# macOS — 04: Security Model

> **Last updated:** July 7, 2026
> **Gatekeeper, SIP, FileVault, Keychain, privacy permissions — how macOS protects itself and you.**

---

## The macOS Security Layers

macOS has multiple overlapping security systems:

```
Layer 1: Gatekeeper        → Prevents running untrusted apps
Layer 2: SIP               → Prevents modifying protected system files (even as root)
Layer 3: Sandboxing        → App Store apps run in isolated sandboxes
Layer 4: Privacy controls  → Apps must request permission for camera, mic, files, etc.
Layer 5: FileVault         → Full-disk encryption
Layer 6: Keychain          → Encrypted credential storage
Layer 7: XProtect          → Built-in malware scanner
```

---

## Gatekeeper

**Gatekeeper** checks apps before they run for the first time. If an app isn't from Apple or a registered developer, macOS blocks it.

**How apps get their trust level:**

```
Mac App Store          → Fully trusted (Apple reviewed it)
Developer-signed       → Trusted if notarized with Apple Developer account
Unsigned               → Blocked by default — "cannot be opened because developer cannot be verified"
```

**The "cannot be opened" error:**

```bash
# Problem: You downloaded an app and see:
# "app.app cannot be opened because the developer cannot be verified"

# Fix 1: Right-click the app → Open → click Open anyway (for first run only)

# Fix 2: Remove quarantine attribute
xattr -d com.apple.quarantine /Applications/MyApp.app

# Fix 3: Allow apps from "Anywhere" (not recommended)
# System Settings → Privacy & Security → Security → Allow apps from: Anywhere
# (This option hidden by default — run to reveal:)
sudo spctl --master-disable

# Re-enable Gatekeeper
sudo spctl --master-enable

# Check Gatekeeper status
spctl --status
# assessments enabled   (Gatekeeper on)
# assessments disabled  (Gatekeeper off)
```

---

## SIP — System Integrity Protection

Covered in the filesystem file, but key points:

```bash
# SIP prevents root from modifying:
/System/
/usr/ (except /usr/local and /usr/libexec/cups)
/bin/
/sbin/

# Even with sudo, you CANNOT:
sudo rm /System/Library/CoreServices/Finder.app    # blocked
sudo chmod 777 /bin/ls                             # blocked

# Check SIP status
csrutil status
```

Disabling SIP requires booting into Recovery Mode — this is intentional friction to prevent malware from disabling it.

---

## FileVault — Full-Disk Encryption

**FileVault** encrypts your entire startup disk. If your Mac is stolen, the data is unreadable without your login password or recovery key.

```bash
# Check FileVault status
fdesetup status
# FileVault is On.

# Enable FileVault (prompts for setup)
sudo fdesetup enable

# Create a recovery key (generates a 24-char key — store it somewhere safe)
# Done during setup or:
sudo fdesetup changerecovery -personal

# Verify encryption is complete
diskutil apfs list | grep "FileVault"
```

**FileVault in the GUI:** System Settings → Privacy & Security → FileVault

**On Apple Silicon (M1+):** Encryption is always on — the T2/M-chip handles it at hardware level. FileVault adds password-based key protection on top.

---

## Keychain — Credential Storage

**Keychain** is macOS's built-in password manager. Apps store passwords, tokens, certificates, and SSH keys here.

```
System Keychain  → Machine-level credentials, network passwords
Login Keychain   → Your personal credentials, app passwords (unlocks at login)
iCloud Keychain  → Synced across your Apple devices
```

```bash
# Store a password in Keychain (from CLI)
security add-generic-password \
  -a "myapp" \
  -s "database" \
  -w "supersecret123"

# Retrieve a password from Keychain
security find-generic-password \
  -a "myapp" \
  -s "database" \
  -w           # -w prints only the password

# Find an internet password (stored when you log into websites in Safari)
security find-internet-password \
  -s "github.com" \
  -w

# List all keychain items (verbose)
security dump-keychain ~/Library/Keychains/login.keychain-db

# Delete a Keychain item
security delete-generic-password \
  -a "myapp" \
  -s "database"
```

**Keychain Access app:** GUI browser for all your keychain items. Location: `/Applications/Utilities/Keychain Access.app`

**SSH keys in Keychain:**

```bash
# Add SSH key to keychain (persists across reboots)
ssh-add --apple-use-keychain ~/.ssh/id_ed25519

# Configure SSH to always use keychain (~/.ssh/config)
cat >> ~/.ssh/config << 'EOF'
Host *
  AddKeysToAgent yes
  UseKeychain yes
  IdentityFile ~/.ssh/id_ed25519
EOF
```

---

## Privacy Permissions — TCC (Transparency, Consent, and Control)

macOS requires apps to ask permission before accessing sensitive resources. This is managed by the **TCC** system.

Apps must request permission for:
```
Camera              → any app using your webcam
Microphone          → audio recording
Location            → GPS
Contacts            → address book
Calendar            → calendar data
Photos              → photo library
Files               → specific folder access (Downloads, Desktop, Documents)
Screen Recording    → capturing screen
Accessibility       → controlling other apps (keyboard macros, automation)
Full Disk Access    → reading any file (Terminal, backup apps need this)
```

**Where to manage permissions:** System Settings → Privacy & Security

```bash
# Command-line: reset TCC permissions for an app (testing/debugging)
tccutil reset Camera com.apple.Terminal

# Reset all permissions for an app
tccutil reset All com.example.myapp

# List TCC database (requires Full Disk Access for Terminal)
sqlite3 ~/Library/Application\ Support/com.apple.TCC/TCC.db \
  "SELECT service, client, allowed FROM access"
```

---

## XProtect and MRT — Built-in Malware Protection

macOS ships with:
- **XProtect** — signature-based malware scanner (checks downloads)
- **MRT (Malware Removal Tool)** — removes known malware
- **Gatekeeper** — blocks untrusted code from running

These update automatically in the background via Software Update.

```bash
# Check XProtect version
system_profiler SPInstallHistoryDataType | grep XProtect

# XProtect definitions location
ls /System/Library/CoreServices/XProtect.bundle/Contents/Resources/
```

---

## sudo on macOS

`sudo` works the same as Linux — you need admin privileges for system changes.

```bash
# Check if you're an admin
groups $(whoami) | grep admin
# should see "admin" in the output

# Add a user to the admin group
sudo dseditgroup -o edit -a username -t user admin

# Remove from admin group (to reduce privileges)
sudo dseditgroup -o edit -d username -t user admin

# List admin users
dscl . -read /Groups/admin GroupMembership
```

**sudoers on macOS:** Same file, same format as Linux: `/etc/sudoers` (edit with `sudo visudo`).

---

## Firewall

macOS has an application-level firewall (not a packet filter by default):

```bash
# Check firewall status
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate

# Enable/disable
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate off

# Block all incoming connections (stealth mode)
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on

# GUI: System Settings → Network → Firewall
```

For advanced packet filtering (like iptables on Linux), macOS uses **pf** (Packet Filter, from BSD):

```bash
# pf configuration
sudo pfctl -s rules   # show current rules
sudo pfctl -e         # enable pf
sudo pfctl -d         # disable pf

# pf rules file
cat /etc/pf.conf
```

→ Continue to: `05-networking.md`
