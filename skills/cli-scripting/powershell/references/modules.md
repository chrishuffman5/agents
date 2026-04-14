# PowerShell Modules and Cmdlets Reference

> Module management, common cmdlets by category, remoting.

---

## 1. Module Management

```powershell
# Discovering and loading modules
Get-Module                              # loaded in current session
Get-Module -ListAvailable               # all installed
Get-Module -ListAvailable -Name 'Az*'   # filter by name
Import-Module PSReadLine                # import by name
Import-Module ./MyModule.psm1           # import by path
Import-Module PSReadLine -Force         # reload
Remove-Module PSReadLine                # unload

# PSGallery / PSGet
Find-Module -Name 'Pester'
Find-Module -Tag 'Azure'
Install-Module Pester -Scope CurrentUser
Install-Module Az -Scope AllUsers -Force
Install-Module PSScriptAnalyzer -AllowPrerelease
Update-Module Pester
Uninstall-Module Pester -AllVersions
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted

# Module path
$env:PSModulePath -split [System.IO.Path]::PathSeparator
# Common paths:
#   ~/.local/share/powershell/Modules       (Linux user)
#   ~/Documents/PowerShell/Modules          (Windows user)
#   /usr/local/share/powershell/Modules     (Linux system)
#   C:\Program Files\PowerShell\Modules     (Windows system)

# Creating a script module (.psm1)
# File: MyModule.psm1
function Get-Greeting { param([string]$Name) "Hello, $Name!" }
Export-ModuleMember -Function 'Get-Greeting'

# Module manifest (.psd1)
New-ModuleManifest -Path MyModule.psd1 `
    -RootModule 'MyModule.psm1' `
    -ModuleVersion '1.0.0' `
    -Author 'Your Name' `
    -Description 'My module' `
    -PowerShellVersion '7.0' `
    -FunctionsToExport @('Get-Greeting') `
    -Tags @('utility','greeting')

# Key built-in modules
# Microsoft.PowerShell.Management — filesystem, registry, processes, services
# Microsoft.PowerShell.Utility    — data manipulation, formatting, type conversion
# Microsoft.PowerShell.Core       — core pipeline, session, job management
# PSReadLine                      — enhanced command-line editing
# ThreadJob / Microsoft.PowerShell.ThreadJob (7.6) — lightweight jobs
# CimCmdlets                      — CIM/WMI access
# Microsoft.PowerShell.Archive    — Compress-Archive / Expand-Archive
```

---

## 2. Common Cmdlets by Category

### File System

```powershell
# Get-ChildItem (alias: gci, ls, dir)
Get-ChildItem -Path C:\Logs -Filter '*.log' -Recurse -Force
Get-ChildItem -Recurse | Where-Object { !$_.PSIsContainer }   # files only
Get-ChildItem -Directory                                        # dirs only
Get-ChildItem -File -Recurse | Sort-Object Length -Descending | Select-Object -First 10

# Get-Content / Set-Content / Add-Content
Get-Content app.log                              # read all lines
Get-Content app.log -Raw                         # single string
Get-Content huge.log -Tail 100                   # last 100 lines
Get-Content app.log -Wait                        # follow (like tail -f)
Set-Content output.txt -Value "new content"
Set-Content output.txt -Value $lines -Encoding UTF8
Add-Content log.txt -Value "$(Get-Date) - Event"

# Copy-Item / Move-Item / Remove-Item / New-Item
Copy-Item source.txt -Destination C:\Backup\
Copy-Item C:\Source -Destination C:\Dest -Recurse -Force
Move-Item *.log -Destination C:\Archive\
Remove-Item C:\Temp -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path C:\Reports -Force
New-Item -ItemType File -Path C:\Reports\out.txt -Force

# Test-Path / Resolve-Path / Join-Path
Test-Path C:\Windows                       # $true
Test-Path C:\file.txt -PathType Leaf       # file exists
Test-Path C:\dir -PathType Container       # dir exists
Resolve-Path '.\relative\path'
$full = Join-Path $PSScriptRoot 'config.json'
# PS 7.6+: multiple child paths
$path = Join-Path 'C:\' -ChildPath 'Program Files', 'MyApp', 'config.xml'
```

### Data Conversion

```powershell
# JSON
$obj  = Get-Content data.json | ConvertFrom-Json
$json = $obj | ConvertTo-Json -Depth 10
$json = $obj | ConvertTo-Json -Compress
Get-Content api-response.json | ConvertFrom-Json | Select-Object -ExpandProperty data

# CSV
Import-Csv data.csv
Import-Csv data.csv -Delimiter ';'
Import-Csv data.csv | Where-Object { $_.Status -eq 'Active' }
Export-Csv output.csv -NoTypeInformation
Export-Csv output.csv -Append -NoTypeInformation

# XML
[xml]$doc = Get-Content config.xml
$doc.configuration.appSettings.add
Select-Xml -Path config.xml -XPath '//add[@key="dbConn"]' | Select-Object -Expand Node
$doc.Save('output.xml')

# HTML
Get-Process | ConvertTo-Html -Title 'Processes' -Property Name,CPU,Id | Set-Content report.html
```

### Process Management

```powershell
Get-Process
Get-Process -Name 'notepad'
Get-Process | Sort-Object CPU -Descending | Select-Object -First 10
Stop-Process -Name 'notepad' -Force
Stop-Process -Id 1234 -Confirm
Start-Process 'notepad.exe'
Start-Process 'notepad.exe' -ArgumentList 'file.txt'
Start-Process 'cmd.exe' -ArgumentList '/c dir' -NoNewWindow -Wait -PassThru
Wait-Process -Name 'notepad' -Timeout 30
```

### Networking

```powershell
# Test-NetConnection — ping + port test
Test-NetConnection google.com
Test-NetConnection -ComputerName db01 -Port 5432
Test-NetConnection -ComputerName api.example.com -Port 443 -InformationLevel Detailed

# Resolve-DnsName
Resolve-DnsName google.com
Resolve-DnsName google.com -Type MX

# Invoke-RestMethod — returns parsed objects
$response = Invoke-RestMethod -Uri 'https://api.github.com/repos/PowerShell/PowerShell'
$response.stargazers_count

# Invoke-WebRequest — returns raw response with headers
$r = Invoke-WebRequest -Uri 'https://example.com'
$r.StatusCode
$r.Headers
$r.Content
```

### Registry (Windows Only)

```powershell
Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name ProductName
Set-ItemProperty 'HKCU:\Software\MyApp' -Name Theme -Value 'Dark'
New-ItemProperty 'HKCU:\Software\MyApp' -Name Version -Value '1.0' -PropertyType String
Remove-ItemProperty 'HKCU:\Software\MyApp' -Name OldSetting
Test-Path 'HKLM:\SOFTWARE\MyApp'
New-Item 'HKCU:\Software\MyApp' -Force
```

---

## 3. Remoting

### WinRM-Based Remoting (Windows Default)

```powershell
# Enable remoting on target (run as admin)
Enable-PSRemoting -Force

# One-to-one interactive session
Enter-PSSession -ComputerName server01
Exit-PSSession

# One-to-many: Invoke-Command
Invoke-Command -ComputerName server01,server02 -ScriptBlock {
    Get-Service -Name 'Spooler' | Select-Object Status
}

# $using: scope — access outer variables
$svcName = 'Spooler'
Invoke-Command -ComputerName server01 -ScriptBlock {
    Get-Service -Name $using:svcName
}

# Persistent sessions
$session = New-PSSession -ComputerName server01
Invoke-Command -Session $session -ScriptBlock { $x = 42 }
Invoke-Command -Session $session -ScriptBlock { $x }   # persists: 42
Remove-PSSession $session
```

### SSH-Based Remoting (PS 7.x, Cross-Platform)

```powershell
# No WinRM needed — uses SSH subsystem
Enter-PSSession -HostName user@linuxserver -SSHTransport
Invoke-Command -HostName user@linuxserver -ScriptBlock { uname -a }

$sshSession = New-PSSession -HostName user@192.168.1.10 -SSHTransport
Invoke-Command -Session $sshSession -ScriptBlock { Get-Process | Measure-Object }
Remove-PSSession $sshSession

# SSH with key file
Enter-PSSession -HostName linuxserver -UserName admin -KeyFilePath ~/.ssh/id_rsa
```

### Implicit Remoting

```powershell
$session = New-PSSession -ComputerName server01
Import-PSSession -Session $session -Module ActiveDirectory -Prefix 'Remote'
Get-RemoteADUser -Identity 'alice'    # runs on server01, results local
```

### WinRM Configuration

```powershell
Test-WSMan -ComputerName server01
Set-Item WSMan:\localhost\Client\TrustedHosts -Value 'server01,server02' -Force
```
