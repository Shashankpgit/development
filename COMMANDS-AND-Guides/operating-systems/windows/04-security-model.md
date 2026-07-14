# Windows — 04: Security Model

> **Last updated:** July 7, 2026
> **UAC, Windows Defender, BitLocker, Windows Firewall, and how Windows handles trust and privileges.**

---

## User Account Control (UAC)

**UAC (User Account Control)** is Windows's privilege escalation system — the equivalent of `sudo` on Linux/macOS. It was introduced in Windows Vista and remains in Windows 10/11.

### How UAC Works

Even when you're logged in as an Administrator, your processes run with **standard user privileges** by default. When something needs elevated access, Windows prompts you:

```
[Windows needs your permission to continue]
[Allow] [Deny]
```

This protects against:
- Malware silently installing itself
- Scripts accidentally modifying system files
- Users accidentally breaking their system

### UAC Levels

```
Highest: Always notify (prompts for every change, including Windows settings)
Default: Notify only when apps try to make changes (not Windows settings)
Lower:   Notify but don't dim the screen (no secure desktop)
Lowest:  Never notify (UAC effectively disabled — NOT recommended)
```

### Running as Administrator

```powershell
# Right-click → "Run as Administrator"
# Or in PowerShell:

# Check if you're currently in an elevated (admin) session
[Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent() |
  % { $_.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) }
# True  → elevated
# False → not elevated

# Start a new elevated PowerShell window
Start-Process powershell -Verb RunAs

# Run a single command elevated (from non-elevated session)
Start-Process powershell -Verb RunAs -ArgumentList "-Command", "Do-Something"

# Check UAC setting
Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" |
  Select-Object ConsentPromptBehaviorAdmin
```

### Built-in Administrator vs Administrator Group

```
Administrator (built-in account)  → Disabled by default, bypasses UAC entirely
Administrators (group)             → Your admin account — still subject to UAC
Standard User                      → Can't install software or modify system
```

---

## Windows Defender — Antivirus and Security

Windows Defender is built into Windows 10/11 and includes:
- **Antivirus/Antimalware** — real-time scanning
- **Windows Defender Firewall** — inbound/outbound rule filtering
- **SmartScreen** — checks downloads and unknown apps
- **Tamper Protection** — prevents malware from disabling Defender itself

```powershell
# Check Defender status
Get-MpComputerStatus

# Run a quick scan
Start-MpScan -ScanType QuickScan

# Run a full scan
Start-MpScan -ScanType FullScan

# Update definitions
Update-MpSignature

# Check threats
Get-MpThreatDetection

# Temporarily disable real-time protection (use for dev/testing, NOT in production)
Set-MpPreference -DisableRealtimeMonitoring $true
# Re-enable:
Set-MpPreference -DisableRealtimeMonitoring $false

# Add a folder exclusion (so Defender doesn't scan your Node.js project repeatedly)
Add-MpPreference -ExclusionPath "C:\projects\myapp"
Add-MpPreference -ExclusionPath "C:\projects\node_modules"

# List current exclusions
Get-MpPreference | Select-Object ExclusionPath
```

### Windows SmartScreen

SmartScreen checks downloaded files and unknown apps against a cloud reputation database. When it blocks a download:

```powershell
# Unblock a file SmartScreen is blocking (you trust this file)
Unblock-File -Path "C:\Downloads\tool.exe"

# Check if a file is blocked
Get-Item "C:\Downloads\tool.exe" -Stream Zone.Identifier
# ZoneId=3 = Internet zone → triggers SmartScreen
```

---

## Windows Firewall

Windows has a **stateful packet filtering firewall** — inbound traffic is blocked by default; outbound is allowed.

```powershell
# Check firewall status for all profiles
Get-NetFirewallProfile | Select-Object Name, Enabled

# Enable/disable firewall (per profile: Domain, Private, Public)
Set-NetFirewallProfile -Profile Domain,Private,Public -Enabled True
Set-NetFirewallProfile -Profile Domain,Private,Public -Enabled False  # dangerous

# List inbound rules
Get-NetFirewallRule -Direction Inbound | Where-Object Enabled -eq True |
  Select-Object DisplayName, Direction, Action | Sort-Object DisplayName

# Allow an app through the firewall (inbound)
New-NetFirewallRule `
  -DisplayName "Allow Node.js" `
  -Direction Inbound `
  -Program "C:\Program Files\nodejs\node.exe" `
  -Action Allow

# Allow a specific port (e.g., open port 8080 TCP)
New-NetFirewallRule `
  -DisplayName "Allow HTTP 8080" `
  -Direction Inbound `
  -Protocol TCP `
  -LocalPort 8080 `
  -Action Allow

# Block outbound traffic to a specific IP
New-NetFirewallRule `
  -DisplayName "Block IP" `
  -Direction Outbound `
  -RemoteAddress 1.2.3.4 `
  -Action Block

# Delete a rule
Remove-NetFirewallRule -DisplayName "Allow HTTP 8080"

# GUI firewall management
wf.msc    # Windows Defender Firewall with Advanced Security
```

---

## BitLocker — Disk Encryption

**BitLocker** encrypts entire drives. It's the Windows equivalent of FileVault on macOS or LUKS on Linux.

```powershell
# Check BitLocker status on all drives
Get-BitLockerVolume

# Enable BitLocker on C: drive
# (uses TPM if available)
Enable-BitLocker -MountPoint "C:" -EncryptionMethod XtsAes256

# Enable with a recovery password (backup key)
$key = Enable-BitLocker -MountPoint "C:" `
  -EncryptionMethod XtsAes256 `
  -RecoveryPasswordProtector
$key.KeyProtector  # save this recovery key somewhere safe!

# Backup BitLocker key to Active Directory
Backup-BitLockerKeyProtector -MountPoint "C:" -KeyProtectorId $keyId

# Suspend BitLocker (for BIOS updates, etc. — re-enables on next boot)
Suspend-BitLocker -MountPoint "C:"

# Disable BitLocker (decrypts the drive — takes a long time)
Disable-BitLocker -MountPoint "C:"

# GUI: Settings → Privacy & Security → Device Encryption
# or: Control Panel → BitLocker Drive Encryption
```

---

## Windows Security Boundaries

### Integrity Levels

Windows assigns an **integrity level** to every process and file:

```
System    → OS processes (ntoskrnl.exe, etc.)
High      → Elevated administrator processes (Run as Admin)
Medium    → Standard user processes (most apps)
Low       → Sandboxed processes (Internet Explorer, browser tabs, downloads)
Untrusted → Very restricted (anonymous tokens)
```

Files downloaded from the internet get "Low integrity" through the Zone.Identifier ADS. Low-integrity processes can't write to Medium-integrity locations.

```powershell
# Check integrity level of a process
whoami /groups | findstr "Mandatory"
# Mandatory Label\High Mandatory Level Label

# Check a file's integrity level
icacls C:\myfile.txt | findstr Integrity
```

### Credential Guard (Windows 11 Pro/Enterprise)

Credential Guard stores password hashes and Kerberos tickets in a secure, isolated VM (virtualization-based security). This prevents pass-the-hash attacks.

```powershell
# Check if Credential Guard is running
Get-ComputerInfo | Select-Object DeviceGuardSecurityServicesRunning
```

---

## User and Group Management

```powershell
# List local users
Get-LocalUser

# List local groups
Get-LocalGroup

# Create a new local user
$password = ConvertTo-SecureString "Str0ngP@ssw0rd!" -AsPlainText -Force
New-LocalUser -Name "devuser" -Password $password -FullName "Dev User"

# Add user to a group
Add-LocalGroupMember -Group "Administrators" -Member "devuser"
Add-LocalGroupMember -Group "Remote Desktop Users" -Member "devuser"

# Disable an account
Disable-LocalUser -Name "devuser"

# Remove a user
Remove-LocalUser -Name "devuser"

# See current user's group memberships
whoami /groups

# net commands (legacy, but still common)
net user                             # list users
net user username *                  # set password interactively
net localgroup Administrators        # list admins
net localgroup Administrators devuser /add   # add to admins
```

---

## Auditing and Security Logs

```powershell
# View security event log
Get-EventLog -LogName Security -Newest 20

# Find failed login attempts (Event ID 4625)
Get-WinEvent -FilterHashtable @{
    LogName = 'Security'
    Id      = 4625
    StartTime = (Get-Date).AddHours(-24)
}

# Find successful logins (Event ID 4624)
Get-WinEvent -FilterHashtable @{
    LogName = 'Security'
    Id      = 4624
    StartTime = (Get-Date).AddHours(-1)
}

# Find account creation events (Event ID 4720)
Get-WinEvent -FilterHashtable @{
    LogName = 'Security'
    Id      = 4720
}

# Enable object auditing (track who accesses a file)
auditpol /set /subcategory:"File System" /success:enable /failure:enable
```

→ Continue to: `05-windows-server.md`
