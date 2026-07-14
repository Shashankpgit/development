# Windows — 02: Filesystem and Registry

> **Last updated:** July 7, 2026
> **NTFS, file permissions (ACLs), and the Windows Registry — how Windows stores everything.**

---

## NTFS — Windows File System

Windows primarily uses **NTFS (New Technology File System)**, introduced with Windows NT in 1993 and still the default today.

Key NTFS features:

```
ACLs (Access Control Lists)  → Fine-grained per-user/group file permissions
Journaling                   → Transaction log prevents corruption on crash
File compression             → Built-in transparent compression
File encryption              → EFS (Encrypting File System) per-file encryption
Symbolic links               → Like Linux symlinks (mklink command)
Hard links                   → Multiple names for the same file
Alternate Data Streams       → Hidden data streams attached to files
Large volume support         → Up to 8 petabytes
```

**Other filesystems you'll encounter:**
- **exFAT** — USB drives, memory cards (compatible with Linux/macOS)
- **FAT32** — Legacy USB drives (max file size 4GB)
- **ReFS** — Windows Server, resilient filesystem for large storage

---

## NTFS File Permissions (ACLs)

Windows permissions are more complex than Linux's rwx model. Each file/folder has an **ACL (Access Control List)** — a list of **ACE (Access Control Entries)**, each granting or denying specific permissions to a user or group.

```
Linux:       owner=rw-, group=r--, others=r--
Windows:     [Allow] Administrators: Full Control
             [Allow] Users: Read & Execute
             [Deny]  Guests: Read
```

### Built-in Permission Levels

| Permission | What it allows |
|-----------|---------------|
| Full Control | Everything — read, write, delete, change permissions |
| Modify | Read, write, delete, execute — but not change permissions |
| Read & Execute | View files and run programs |
| List Folder Contents | See folder contents |
| Read | Read files and view attributes |
| Write | Create files, write data |

### Viewing and Setting Permissions

```powershell
# View permissions on a file or folder (GUI way)
# Right-click → Properties → Security tab

# PowerShell: get ACL
Get-Acl C:\MyApp\config.json

# Detailed view
Get-Acl C:\MyApp\config.json | Format-List

# icacls — traditional command (faster for scripts)
icacls C:\MyApp\config.json
# C:\MyApp\config.json NT AUTHORITY\SYSTEM:(I)(F)
#                      BUILTIN\Administrators:(I)(F)
#                      SHASHANK-PC\Shashank:(I)(M)
# (I) = inherited, (F) = Full Control, (M) = Modify, (R) = Read

# Grant permissions
icacls C:\MyApp\ /grant "Shashank:(OI)(CI)F" /T
# (OI) = Object Inherit (applies to files in folder)
# (CI) = Container Inherit (applies to subfolders)
# F    = Full Control
# /T   = recursive

# Remove permissions
icacls C:\MyApp\ /remove "Shashank" /T

# Reset to inherited permissions
icacls C:\MyApp\ /reset /T

# Take ownership (run as Administrator)
takeown /F C:\MyApp\ /R /D Y
```

### Inherited Permissions

Child files/folders inherit permissions from their parent folder by default. When you see `(I)` in icacls output, it means inherited.

```powershell
# Disable inheritance on a file (make permissions explicit)
$acl = Get-Acl "C:\sensitive-file.txt"
$acl.SetAccessRuleProtection($true, $false)  # true=protect, false=remove inherited
Set-Acl "C:\sensitive-file.txt" $acl
```

---

## Symbolic Links and Junctions

```cmd
# Create a symbolic link (requires admin or Developer Mode)
mklink link.txt C:\original\file.txt          # file symlink
mklink /D C:\mylink C:\original\directory     # directory symlink
mklink /J C:\junction C:\original\directory   # junction (older, local only)

# PowerShell equivalent
New-Item -ItemType SymbolicLink -Path "C:\link" -Target "C:\original"

# List symlinks
ls | Where-Object { $_.LinkType -eq "SymbolicLink" }
```

---

## The Windows Registry

The **Windows Registry** is a hierarchical database that stores configuration for the OS, hardware, and applications. There is no equivalent on Linux (Linux uses flat config files in `/etc`). macOS uses `.plist` files instead.

Think of the registry as a giant key-value store, organized in a tree:

```
Registry Hive (root key)
  └── Key (like a folder)
        └── Subkey
              └── Value (like a file) = Data
```

### The Five Registry Hives

```
HKEY_LOCAL_MACHINE (HKLM)
  → System-wide settings, hardware, installed software
  → Requires admin to modify
  → Example: HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run
             (programs that start with Windows for all users)

HKEY_CURRENT_USER (HKCU)
  → Settings for the currently logged-in user
  → User can modify without admin
  → Example: HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run
             (programs that start for YOUR user only)

HKEY_CLASSES_ROOT (HKCR)
  → File extension associations (.txt opens in Notepad)
  → COM class registrations

HKEY_USERS (HKU)
  → All user profiles loaded (HKCU is a subset of this)

HKEY_CURRENT_CONFIG (HKCC)
  → Current hardware profile
```

### Browsing the Registry

**GUI:** Run `regedit` (Registry Editor)

```powershell
# PowerShell: navigate registry like a filesystem
cd HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion
ls                         # list subkeys and values

# Get a registry value
Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" `
  -Name "ProductName"
# ProductName : Windows 11 Pro

# Get all values at a key
Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"

# Set a registry value
Set-ItemProperty -Path "HKCU:\Software\MyApp" -Name "Theme" -Value "Dark"

# Create a new registry key
New-Item -Path "HKCU:\Software\MyApp" -Force

# Delete a registry key
Remove-Item -Path "HKCU:\Software\MyApp" -Recurse

# cmd.exe / reg.exe commands (useful in scripts)
reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v ProductName
reg add "HKCU\Software\MyApp" /v Theme /t REG_SZ /d "Dark" /f
reg delete "HKCU\Software\MyApp" /f
```

### Important Registry Locations

```powershell
# Programs that auto-start (per user)
Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"

# Programs that auto-start (all users, requires admin)
Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"

# Installed programs
Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" |
  Select-Object DisplayName, DisplayVersion | Sort-Object DisplayName

# File extension associations
Get-ItemProperty "HKCR:\.txt"

# Environment variables (the real storage location)
Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment"
```

### Registry Value Types

```
REG_SZ        → String ("Hello World")
REG_DWORD     → 32-bit integer (0x00000001)
REG_QWORD     → 64-bit integer
REG_BINARY    → Raw binary data
REG_MULTI_SZ  → Array of strings
REG_EXPAND_SZ → String with expandable env vars ("%SystemRoot%\system32")
```

---

## Alternate Data Streams (ADS)

NTFS supports **Alternate Data Streams** — hidden data attached to a file without changing its visible size. Windows uses this for things like the Zone.Identifier (where a file was downloaded from).

```powershell
# See if a file has streams
Get-Item file.exe -Stream *
# PSPath     : Microsoft.PowerShell.Core\FileSystem::file.exe::$DATA
# PSPath     : Microsoft.PowerShell.Core\FileSystem::file.exe:Zone.Identifier

# Read the Zone.Identifier stream (marks internet downloads)
Get-Content file.exe -Stream Zone.Identifier
# [ZoneTransfer]
# ZoneId=3      ← 3 = Internet zone (triggers SmartScreen warning)

# Remove the stream (unblock the file)
Unblock-File file.exe
# or:
Remove-Item file.exe -Stream Zone.Identifier
```

---

## Disk Management

```powershell
# List disks
Get-Disk

# List volumes/partitions
Get-Volume
Get-Partition

# Disk space usage
Get-PSDrive -PSProvider FileSystem

# Check disk for errors (like fsck on Linux)
Repair-Volume -DriveLetter C -Scan     # scan only
Repair-Volume -DriveLetter C -OfflineScanAndFix  # fix (requires unmount)

# GUI disk management
diskmgmt.msc    # Disk Management console
```

→ Continue to: `03-processes-and-services.md`
