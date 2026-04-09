<#
.SYNOPSIS
    WSL - Network Configuration and Connectivity Diagnostics
.DESCRIPTION
    Checks WSL networking mode (NAT vs mirrored), DNS tunneling and
    auto-proxy settings, WSL virtual adapters, internal IP addresses,
    per-distro DNS configuration, port forwarding rules, firewall rules,
    localhost connectivity, internet connectivity, and VPN detection.
.NOTES
    Version : 1.0.0
    Targets : Windows 10/11 with WSL installed
    Safety  : Read-only. No modifications to system configuration.
    Sections:
        1. WSL Networking Mode
        2. WSL Network Adapters (Windows Side)
        3. WSL Internal IP Address
        4. DNS Configuration per Distro
        5. Port Forwarding Rules
        6. Windows Firewall (WSL Rules)
        7. Localhost Connectivity Test
        8. Internet Connectivity from WSL
        9. VPN Detection
#>

#Requires -Version 5.1

Set-StrictMode -Version Latest
$ErrorActionPreference = 'SilentlyContinue'

function Write-Section {
    param([string]$Title)
    Write-Host "`n$('=' * 70)" -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host "$('=' * 70)" -ForegroundColor Cyan
}

function Write-Item {
    param([string]$Label, [string]$Value, [string]$Color = 'White')
    Write-Host ("  {0,-38} {1}" -f "${Label}:", $Value) -ForegroundColor $Color
}

# ── 1. WSL Networking Mode ──────────────────────────────────────────────────
Write-Section "WSL Networking Mode"

$wslConfigPath  = "$env:USERPROFILE\.wslconfig"
$networkingMode = 'nat (default — not explicitly configured)'
$configContent  = $null

if (Test-Path $wslConfigPath) {
    $configContent = Get-Content $wslConfigPath -Raw
    if ($configContent -match 'networkingMode\s*=\s*(\S+)') {
        $networkingMode = $Matches[1]
    }
}

$modeColor = if ($networkingMode -match 'mirrored') { 'Green' } else { 'White' }
Write-Item "Networking mode" $networkingMode $modeColor

$dnsTunneling = if ($configContent -match 'dnsTunneling\s*=\s*true') { 'true' } else { 'false (default)' }
$autoProxy    = if ($configContent -match 'autoProxy\s*=\s*true')    { 'true' } else { 'false (default)' }
Write-Item "DNS tunneling" $dnsTunneling
Write-Item "Auto proxy" $autoProxy

# ── 2. WSL Network Adapters (Windows Side) ──────────────────────────────────
Write-Section "WSL Network Adapters (Windows Side)"

$wslAdapters = Get-NetAdapter | Where-Object { $_.InterfaceDescription -match 'WSL|Hyper-V Virtual' }
if ($wslAdapters) {
    foreach ($adapter in $wslAdapters) {
        Write-Item $adapter.Name ("{0} — {1}" -f $adapter.Status, $adapter.InterfaceDescription)
        $ip = ($adapter | Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue).IPAddress
        if ($ip) { Write-Item "  IP Address" $ip }
    }
} else {
    Write-Host "  No WSL/Hyper-V virtual adapters found" -ForegroundColor Yellow
}

# ── 3. WSL Internal IP Address ──────────────────────────────────────────────
Write-Section "WSL Internal IP Address"

$wslIpRaw = wsl -- ip addr show eth0 2>&1
if ($LASTEXITCODE -eq 0 -and $wslIpRaw -match '(\d+\.\d+\.\d+\.\d+)/') {
    $wslIp = $Matches[1]
    Write-Item "WSL eth0 IP" $wslIp 'Green'
} else {
    $wslIp = $null
    Write-Host "  Could not retrieve WSL IP (no running distro or eth0 not found)" -ForegroundColor Yellow
}

$hostIps = (Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object { $_.InterfaceAlias -notmatch 'Loopback|WSL|vEthernet' }).IPAddress
Write-Item "Windows host IPs" ($hostIps -join ', ')

# ── 4. DNS Configuration per Distro ─────────────────────────────────────────
Write-Section "DNS Configuration (resolv.conf per Distro)"

$distros = wsl --list --quiet 2>&1 | Where-Object { $_ -match '\S' }
foreach ($distro in $distros) {
    $distroName = $distro.Trim() -replace '\(Default\)', '' -replace '\s+', ''
    if (-not $distroName) { continue }

    Write-Host "`n  [$distroName]" -ForegroundColor Yellow
    $resolv = wsl -d $distroName -- cat /etc/resolv.conf 2>&1
    if ($LASTEXITCODE -eq 0) {
        $resolv | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
    } else {
        Write-Host "    Could not read resolv.conf" -ForegroundColor Red
    }

    $wslConf = wsl -d $distroName -- cat /etc/wsl.conf 2>&1
    if ($wslConf -match 'generateResolvConf\s*=\s*false') {
        Write-Host "    [network] generateResolvConf = false (custom DNS)" -ForegroundColor Cyan
    }
}

# ── 5. Port Forwarding Rules ────────────────────────────────────────────────
Write-Section "Portproxy Rules (netsh interface portproxy)"

$portProxyRules = netsh interface portproxy show all 2>&1
if ($portProxyRules -match 'Listen on') {
    $portProxyRules | ForEach-Object { Write-Host "  $_" }
} else {
    Write-Host "  No portproxy rules configured" -ForegroundColor Gray
}

# ── 6. Windows Firewall (WSL Rules) ─────────────────────────────────────────
Write-Section "Windows Firewall Rules Referencing WSL"

$wslFirewallRules = Get-NetFirewallRule -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -match 'WSL|wsl' -or $_.Description -match 'WSL|wsl' }

if ($wslFirewallRules) {
    foreach ($rule in $wslFirewallRules) {
        $color = if ($rule.Enabled -eq 'True') { 'White' } else { 'Gray' }
        Write-Host ("  [{0}] {1} — {2}" -f $rule.Direction, $rule.DisplayName, $rule.Action) -ForegroundColor $color
    }
} else {
    Write-Host "  No firewall rules explicitly named/described 'WSL'" -ForegroundColor Gray
}

# ── 7. Localhost Connectivity Test ──────────────────────────────────────────
Write-Section "Localhost Connectivity Test"

Write-Host "  Testing localhost forwarding from Windows to WSL..." -ForegroundColor Gray

$ncAvailable = wsl -- which nc 2>&1
if ($LASTEXITCODE -eq 0) {
    $job = Start-Job {
        wsl -- sh -c 'echo "WSL_OK" | nc -l -p 19876 -q 1' 2>&1
    }
    Start-Sleep -Milliseconds 800

    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $tcp.ConnectAsync('127.0.0.1', 19876).Wait(1000) | Out-Null
        if ($tcp.Connected) {
            $stream = $tcp.GetStream()
            $reader = New-Object System.IO.StreamReader($stream)
            $response = $reader.ReadLine()
            $tcp.Close()
            if ($response -match 'WSL_OK') {
                Write-Item "localhost:19876 -> WSL" "REACHABLE" 'Green'
            } else {
                Write-Item "localhost:19876 -> WSL" "Connected but unexpected response: $response" 'Yellow'
            }
        } else {
            Write-Item "localhost:19876 -> WSL" "Connection failed" 'Red'
        }
    } catch {
        Write-Item "localhost:19876 -> WSL" "Test failed: $_" 'Red'
    }
    Stop-Job $job -ErrorAction SilentlyContinue
    Remove-Job $job -ErrorAction SilentlyContinue
} else {
    Write-Host "  nc (netcat) not available in default distro — skipping connectivity test" -ForegroundColor Yellow
    Write-Host "  Install with: sudo apt install netcat-openbsd" -ForegroundColor Gray
}

# ── 8. Internet Connectivity from WSL ───────────────────────────────────────
Write-Section "Internet Connectivity from WSL"

$pingResult = wsl -- ping -c 2 -W 3 8.8.8.8 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Item "Ping 8.8.8.8 from WSL" "SUCCESS" 'Green'
} else {
    Write-Item "Ping 8.8.8.8 from WSL" "FAILED" 'Red'
    Write-Host "  $pingResult" -ForegroundColor Gray
}

$dnsResult = wsl -- sh -c 'nslookup microsoft.com 2>&1 | head -5' 2>&1
if ($dnsResult -match 'Address') {
    Write-Item "DNS resolution from WSL" "SUCCESS" 'Green'
} else {
    Write-Item "DNS resolution from WSL" "FAILED or inconclusive" 'Yellow'
}

# ── 9. VPN Detection ────────────────────────────────────────────────────────
Write-Section "VPN Detection"

$vpnAdapters = Get-NetAdapter | Where-Object {
    $_.InterfaceDescription -match 'VPN|Tunnel|TAP|WireGuard|OpenVPN|Cisco|Pulse|GlobalProtect|Zscaler|FortiClient'
}

if ($vpnAdapters) {
    Write-Host "  VPN adapter(s) detected — may affect WSL networking:" -ForegroundColor Yellow
    foreach ($vpn in $vpnAdapters) {
        Write-Host ("  [{0}] {1}" -f $vpn.Status, $vpn.InterfaceDescription) -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "  Recommendations:" -ForegroundColor Cyan
    Write-Host "    - Use networkingMode=mirrored in ~/.wslconfig (Win11 22H2+)" -ForegroundColor Gray
    Write-Host "    - Enable dnsTunneling=true in ~/.wslconfig" -ForegroundColor Gray
    Write-Host "    - Run 'wsl --shutdown' then relaunch WSL after connecting VPN" -ForegroundColor Gray
} else {
    Write-Item "VPN adapters" "None detected" 'Green'
}

Write-Host "`nWSL network diagnostics complete." -ForegroundColor Green
