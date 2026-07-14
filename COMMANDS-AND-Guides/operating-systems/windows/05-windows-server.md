# Windows — 05: Windows Server

> **Last updated:** July 7, 2026
> **Windows Server roles, IIS, Remote Desktop, WinRM, and managing servers remotely — what every DevOps engineer needs to know.**

---

## Windows Server vs Windows Desktop

Windows Server is a separate product line built on the same NT kernel but with:

```
Server: no gaming/media features, optimized for background services
Server: supports more RAM (up to 48TB vs 2TB on desktop)
Server: Active Directory, DNS Server, DHCP, IIS, Hyper-V roles
Server: paid per-core licensing

Desktop: Windows 11 (or 10) — for end users, developers
```

**Current versions:**
- **Windows Server 2025** — latest (as of 2026)
- **Windows Server 2022** — still widely deployed
- **Windows Server 2019** — long-term support until 2029

### Server Core vs Desktop Experience

```
Server with Desktop Experience  → Full GUI (like a desktop)
Server Core                     → No GUI, command-line only (like headless Linux)
                                  Smaller attack surface, less patching
```

Server Core is the modern default for production — you manage it remotely.

---

## Server Manager

**Server Manager** is the GUI dashboard for managing Windows Server roles and features.

```
Open: Start → Server Manager (or: servermanager.exe)

Key views:
  Dashboard         → overview of server health
  Local Server      → this server's settings (hostname, RDP, firewall, etc.)
  All Servers       → manage remote servers from one pane
  Roles and Features → install/remove server roles (IIS, DNS, DHCP, etc.)
```

### Installing Roles via PowerShell

```powershell
# List all installed roles and features
Get-WindowsFeature

# Install the Web Server (IIS) role
Install-WindowsFeature Web-Server -IncludeManagementTools

# Install DNS Server
Install-WindowsFeature DNS -IncludeManagementTools

# Install DHCP Server
Install-WindowsFeature DHCP -IncludeManagementTools

# Install Active Directory Domain Services
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools

# Install File Server with dedup
Install-WindowsFeature FS-FileServer, FS-Data-Deduplication

# Remove a feature
Uninstall-WindowsFeature Web-Server
```

---

## IIS — Internet Information Services

**IIS** is Microsoft's web server — the Windows equivalent of nginx or Apache. It serves ASP.NET apps, static files, and can act as a reverse proxy.

### Installing IIS

```powershell
# Install IIS with common features
Install-WindowsFeature Web-Server,
  Web-Common-Http,
  Web-Static-Content,
  Web-Default-Doc,
  Web-Dir-Browsing,
  Web-Http-Errors,
  Web-App-Dev,
  Web-Asp-Net45,
  Web-Net-Ext45,
  Web-ISAPI-Ext,
  Web-ISAPI-Filter,
  Web-Health,
  Web-Http-Logging,
  Web-Mgmt-Tools -IncludeManagementTools
```

### IIS Key Concepts

```
Web Site       → a website (bound to IP:port:hostname)
Application    → a web app within a site (has its own path and app pool)
Application Pool → isolated process that runs the app (like a container)
Virtual Directory → a folder alias pointing to a path outside the site root
```

### Managing IIS via PowerShell (WebAdministration module)

```powershell
Import-Module WebAdministration

# List all sites
Get-Website

# List all app pools
Get-WebConfiguration system.applicationHost/applicationPools/add

# Create a new website
New-Website -Name "MyApp" -Port 8080 -PhysicalPath "C:\inetpub\myapp" -ApplicationPool "MyAppPool"

# Start/stop a website
Start-Website -Name "MyApp"
Stop-Website -Name "MyApp"
Restart-WebItem -PSPath "IIS:\Sites\MyApp"

# Create an application pool
New-WebAppPool -Name "MyAppPool"
Set-ItemProperty "IIS:\AppPools\MyAppPool" -Name processModel.userName -Value "DOMAIN\svcaccount"
Set-ItemProperty "IIS:\AppPools\MyAppPool" -Name processModel.password -Value "password"
Set-ItemProperty "IIS:\AppPools\MyAppPool" -Name processModel.identityType -Value 3  # 3=SpecificUser

# Recycle an app pool
Restart-WebAppPool -Name "MyAppPool"

# Check IIS logs
Get-Content "C:\inetpub\logs\LogFiles\W3SVC1\u_ex*.log" | tail -50

# IIS Manager GUI
inetmgr
```

### IIS Reverse Proxy (ARR — Application Request Routing)

IIS can proxy to backend apps (Node.js, Python, etc.):

```powershell
# Install URL Rewrite and ARR
# Download from: IIS Extensions (or use Web Platform Installer)

# Basic reverse proxy rule in web.config:
```

```xml
<!-- C:\inetpub\wwwroot\web.config -->
<configuration>
  <system.webServer>
    <rewrite>
      <rules>
        <rule name="Proxy to Node" stopProcessing="true">
          <match url="(.*)" />
          <action type="Rewrite" url="http://localhost:3000/{R:1}" />
        </rule>
      </rules>
    </rewrite>
  </system.webServer>
</configuration>
```

---

## Remote Desktop (RDP)

**RDP (Remote Desktop Protocol)** lets you connect to a Windows Server's GUI from another machine. It runs on port **3389** by default.

```powershell
# Enable Remote Desktop
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" `
  -Name "fDenyTSConnections" -Value 0

# Allow RDP through firewall
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"

# Check RDP status
Get-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" `
  -Name "fDenyTSConnections"
# 0 = enabled, 1 = disabled

# Add user to Remote Desktop Users group
Add-LocalGroupMember -Group "Remote Desktop Users" -Member "devuser"
```

**Connecting via RDP:**
```
Windows:  mstsc.exe
          Start → "Remote Desktop Connection"
          or: mstsc /v:server-ip-or-hostname

macOS:    Microsoft Remote Desktop (App Store)
Linux:    Remmina, xfreerdp
```

```bash
# RDP from Linux/macOS CLI
xfreerdp /v:192.168.1.100 /u:Administrator /p:Password /cert:ignore
```

---

## PowerShell Remoting (WinRM)

**WinRM (Windows Remote Management)** lets you run PowerShell commands on remote Windows machines. It's the Windows equivalent of SSH for remote admin.

### Setting Up WinRM

**On the server (target machine):**

```powershell
# Enable PowerShell remoting (run as Administrator)
Enable-PSRemoting -Force

# Check WinRM status
Get-Service WinRM
winrm enumerate winrm/config/listener

# Allow connections from specific hosts only
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "192.168.1.*"
# Or allow all (use only in trusted networks):
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*"
```

**On the client (machine you're connecting from):**

```powershell
# Test connection
Test-WSMan 192.168.1.100

# Open an interactive remote session (like SSH)
Enter-PSSession -ComputerName 192.168.1.100 -Credential (Get-Credential)
# You get a prompt like: [192.168.1.100]: PS C:\>
# Type Exit-PSSession to disconnect

# Run a command remotely (no interactive session)
Invoke-Command -ComputerName 192.168.1.100 -Credential (Get-Credential) -ScriptBlock {
    Get-Service nginx
}

# Run on multiple servers at once
$servers = @("web01", "web02", "web03")
Invoke-Command -ComputerName $servers -Credential (Get-Credential) -ScriptBlock {
    Restart-Service nginx
}

# Copy files to/from remote machine
Copy-Item -Path "C:\app\config.json" `
  -Destination "C:\app\config.json" `
  -ToSession (New-PSSession -ComputerName "web01")
```

### WinRM over HTTPS (Production)

```powershell
# Create HTTPS listener with a certificate
$cert = New-SelfSignedCertificate -DnsName "myserver.domain.com" -CertStoreLocation cert:\LocalMachine\My
$thumbprint = $cert.Thumbprint

New-Item -Path WSMan:\localhost\Listener -Transport HTTPS -Address * -CertificateThumbPrint $thumbprint -Force

# Open port 5986 (HTTPS WinRM)
New-NetFirewallRule -DisplayName "WinRM HTTPS" -Direction Inbound -Protocol TCP -LocalPort 5986 -Action Allow

# Connect securely
Enter-PSSession -ComputerName "myserver.domain.com" -UseSSL -Credential (Get-Credential)
```

---

## Active Directory Basics

**Active Directory (AD)** is the centralized identity and access management system for Windows networks. Common in enterprise environments.

```
Domain       → a group of computers sharing the same AD database (company.com)
Domain Controller (DC) → the server running AD, stores all users/groups/policies
Group Policy (GPO)     → rules pushed to all machines in the domain
OU (Organizational Unit) → a folder for organizing users/computers in AD
LDAP         → the protocol AD uses underneath (port 389/636)
Kerberos     → the authentication protocol AD uses (port 88)
```

```powershell
# Install AD Domain Services
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools

# Promote server to Domain Controller (creates new forest)
Install-ADDSForest `
  -DomainName "mycompany.local" `
  -DomainNetbiosName "MYCOMPANY" `
  -ForestMode "WinThreshold" `
  -DomainMode "WinThreshold" `
  -InstallDns `
  -Force

# After reboot — manage AD:
# Create a user
New-ADUser -Name "Shashank P" -GivenName "Shashank" -Surname "P" `
  -SamAccountName "shashankp" -UserPrincipalName "shashankp@mycompany.local" `
  -AccountPassword (ConvertTo-SecureString "Str0ng!" -AsPlainText -Force) `
  -Enabled $true

# Create a group
New-ADGroup -Name "Developers" -GroupScope Global -GroupCategory Security

# Add user to group
Add-ADGroupMember -Identity "Developers" -Members "shashankp"

# List users
Get-ADUser -Filter * | Select-Object Name, SamAccountName, Enabled

# List computers joined to domain
Get-ADComputer -Filter * | Select-Object Name, DNSHostName
```

---

## Common Server Admin Tasks

```powershell
# Check Windows Server version
Get-ComputerInfo | Select-Object OsName, OsVersion, WindowsVersion

# Check disk space
Get-Volume | Select-Object DriveLetter, FileSystemLabel, Size, SizeRemaining

# Check memory
Get-CimInstance Win32_OperatingSystem |
  Select-Object TotalVisibleMemorySize, FreePhysicalMemory

# Check CPU
Get-CimInstance Win32_Processor | Select-Object Name, NumberOfCores, MaxClockSpeed

# Last boot time
(Get-CimInstance Win32_OperatingSystem).LastBootUpTime

# Check for pending Windows updates
Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 10

# Install updates via PowerShell
Install-Module PSWindowsUpdate -Force
Get-WindowsUpdate
Install-WindowsUpdate -AcceptAll -AutoReboot

# Remote shutdown/restart
Restart-Computer -ComputerName "web01" -Force
Stop-Computer -ComputerName "web01" -Force
```

→ Continue to: `06-in-practice.md`
