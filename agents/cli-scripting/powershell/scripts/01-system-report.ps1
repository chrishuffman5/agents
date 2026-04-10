#!/usr/bin/env pwsh
# ============================================================================
# PowerShell - Cross-Platform System Report
#
# Purpose : Collect OS, CPU, memory, disk, and network information across
#           Windows, Linux, and macOS using platform-specific APIs.
# Version : 1.0.0
# Targets : PowerShell 7.0+
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. Platform and OS Identity
#   2. CPU Information
#   3. Memory Usage
#   4. Disk Usage
#   5. Network Interfaces
# ============================================================================
#Requires -Version 7.0

[CmdletBinding()]
param(
    [ValidateSet('Console','JSON','CSV','All')]
    [string]$Format = 'Console',
    [string]$OutputPath = $PSScriptRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-PlatformInfo {
    [PSCustomObject]@{
        Hostname    = [System.Net.Dns]::GetHostName()
        OSName      = if ($IsWindows) { (Get-CimInstance Win32_OperatingSystem).Caption }
                      elseif ($IsLinux) { (Get-Content /etc/os-release | Where-Object { $_ -match '^PRETTY_NAME' }) -replace 'PRETTY_NAME="(.*)"','$1' }
                      else { $PSVersionTable.OS }
        PSEdition   = $PSVersionTable.PSEdition
        PSVersion   = $PSVersionTable.PSVersion.ToString()
        Platform    = $PSVersionTable.Platform ?? [System.Environment]::OSVersion.Platform
        CurrentTime = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        TimeZone    = [System.TimeZoneInfo]::Local.Id
    }
}

function Get-CpuInfo {
    if ($IsWindows) {
        $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
        [PSCustomObject]@{
            Name        = $cpu.Name.Trim()
            Cores       = $cpu.NumberOfCores
            LogicalCPUs = $cpu.NumberOfLogicalProcessors
            MaxSpeedMHz = $cpu.MaxClockSpeed
            LoadPercent = $cpu.LoadPercentage
        }
    } elseif ($IsLinux) {
        $cpuinfo = Get-Content /proc/cpuinfo
        $model   = ($cpuinfo | Where-Object { $_ -match '^model name' } | Select-Object -First 1) -replace '.*:\s*',''
        $cores   = ($cpuinfo | Where-Object { $_ -match '^processor' }).Count
        $loadavg = (Get-Content /proc/loadavg) -split '\s+'
        [PSCustomObject]@{
            Name       = $model
            Cores      = $cores
            LogicalCPUs = $cores
            LoadAvg1m  = [double]$loadavg[0]
            LoadAvg5m  = [double]$loadavg[1]
            LoadAvg15m = [double]$loadavg[2]
        }
    } else {
        [PSCustomObject]@{ Name = 'Unknown'; Cores = [System.Environment]::ProcessorCount }
    }
}

function Get-MemoryInfo {
    if ($IsWindows) {
        $os = Get-CimInstance Win32_OperatingSystem
        [PSCustomObject]@{
            TotalGB     = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
            FreeGB      = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
            UsedGB      = [math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / 1MB, 2)
            UsedPercent = [math]::Round((($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / $os.TotalVisibleMemorySize) * 100, 1)
        }
    } elseif ($IsLinux) {
        $meminfo = Get-Content /proc/meminfo
        $total   = [long](($meminfo | Where-Object { $_ -match '^MemTotal:' }) -replace '\D+','')
        $avail   = [long](($meminfo | Where-Object { $_ -match '^MemAvailable:' }) -replace '\D+','')
        $used    = $total - $avail
        [PSCustomObject]@{
            TotalGB     = [math]::Round($total / 1MB, 2)
            FreeGB      = [math]::Round($avail / 1MB, 2)
            UsedGB      = [math]::Round($used / 1MB, 2)
            UsedPercent = [math]::Round(($used / $total) * 100, 1)
        }
    } else {
        [PSCustomObject]@{ TotalGB = 'N/A'; FreeGB = 'N/A' }
    }
}

function Get-DiskInfo {
    if ($IsWindows) {
        Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
            [PSCustomObject]@{
                Drive       = $_.DeviceID
                TotalGB     = [math]::Round($_.Size / 1GB, 2)
                FreeGB      = [math]::Round($_.FreeSpace / 1GB, 2)
                UsedGB      = [math]::Round(($_.Size - $_.FreeSpace) / 1GB, 2)
                UsedPercent = [math]::Round((($_.Size - $_.FreeSpace) / $_.Size) * 100, 1)
            }
        }
    } elseif ($IsLinux) {
        $df = bash -c "df -B1 --output=source,size,used,avail,pcent,target 2>/dev/null | tail -n +2"
        $df | Where-Object { $_ -match '^/dev/' } | ForEach-Object {
            $f = $_ -split '\s+'
            [PSCustomObject]@{
                Drive       = $f[5]
                TotalGB     = [math]::Round([long]$f[1] / 1GB, 2)
                FreeGB      = [math]::Round([long]$f[3] / 1GB, 2)
                UsedGB      = [math]::Round([long]$f[2] / 1GB, 2)
                UsedPercent = ($f[4] -replace '%','') -as [int]
            }
        }
    }
}

function Get-NetworkInfo {
    if ($IsWindows) {
        Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | ForEach-Object {
            $ip = Get-NetIPAddress -InterfaceIndex $_.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object -First 1
            [PSCustomObject]@{
                Name       = $_.Name
                Status     = $_.Status
                IPv4       = $ip?.IPAddress ?? 'N/A'
                MacAddress = $_.MacAddress
            }
        }
    } elseif ($IsLinux) {
        $interfaces = bash -c "ip -o addr show 2>/dev/null"
        $interfaces | Where-Object { $_ -match 'inet ' -and $_ -notmatch 'lo ' } | ForEach-Object {
            if ($_ -match '(\d+):\s+(\S+)\s+inet\s+([\d.]+/\d+)') {
                [PSCustomObject]@{
                    Name   = $Matches[2]
                    IPv4   = $Matches[3]
                    Status = 'Up'
                }
            }
        }
    }
}

# ── Collect ──────────────────────────────────────────────────────────────────
Write-Verbose "Collecting system information..."
$report = [PSCustomObject]@{
    Platform  = Get-PlatformInfo
    CPU       = Get-CpuInfo
    Memory    = Get-MemoryInfo
    Disks     = @(Get-DiskInfo)
    Network   = @(Get-NetworkInfo)
    Timestamp = Get-Date -Format 'o'
}

# ── Output ───────────────────────────────────────────────────────────────────
switch ($Format) {
    'Console' {
        Write-Host "`n=== SYSTEM REPORT ===" -ForegroundColor Cyan
        Write-Host "Host: $($report.Platform.Hostname)  |  OS: $($report.Platform.OSName)"
        Write-Host "`n--- CPU ---"
        $report.CPU | Format-List
        Write-Host "--- MEMORY ---"
        $report.Memory | Format-Table -AutoSize
        Write-Host "--- DISKS ---"
        $report.Disks | Format-Table Drive, TotalGB, UsedGB, FreeGB, UsedPercent -AutoSize
        Write-Host "--- NETWORK ---"
        $report.Network | Format-Table -AutoSize
    }
    'JSON' {
        $path = Join-Path $OutputPath 'system-report.json'
        $report | ConvertTo-Json -Depth 5 | Set-Content $path -Encoding UTF8
        Write-Host "Report saved: $path"
    }
    'CSV' {
        $path = Join-Path $OutputPath 'system-report-disks.csv'
        $report.Disks | Export-Csv $path -NoTypeInformation
        Write-Host "Disk report saved: $path"
    }
    'All' {
        $json = Join-Path $OutputPath 'system-report.json'
        $csv  = Join-Path $OutputPath 'system-report-disks.csv'
        $report | ConvertTo-Json -Depth 5 | Set-Content $json -Encoding UTF8
        $report.Disks | Export-Csv $csv -NoTypeInformation
        Write-Host "Reports saved: $json, $csv"
        $report
    }
}
