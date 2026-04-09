<#
.SYNOPSIS
    Windows Server Hyper-V - Per-VM Performance Metrics
.DESCRIPTION
    Collects real-time performance counters for all running VMs using
    Hyper-V-specific counter categories. Samples CPU, memory pressure,
    disk I/O latency, and network throughput per VM.
.PARAMETER SampleCount
    Number of counter samples to collect (default: 3, interval: 2 seconds).
.NOTES
    Version : 1.0.0
    Targets : Windows Server 2016+ with Hyper-V role installed
    Safety  : Read-only. No modifications to system configuration.
    Sections:
        1. CPU Utilization
        2. Memory Pressure
        3. Disk I/O
        4. Network I/O
#>

#Requires -Modules Hyper-V
#Requires -RunAsAdministrator

param(
    [int]$SampleCount = 3
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

$counters = @(
    '\Hyper-V Hypervisor Virtual Processor(*)\% Total Run Time',
    '\Hyper-V Dynamic Memory VM(*)\Current Pressure',
    '\Hyper-V Virtual Storage Device(*)\Read Bytes/sec',
    '\Hyper-V Virtual Storage Device(*)\Write Bytes/sec',
    '\Hyper-V Virtual Storage Device(*)\Average Read Latency',
    '\Hyper-V Virtual Storage Device(*)\Average Write Latency',
    '\Hyper-V Virtual Network Adapter(*)\Bytes Received/sec',
    '\Hyper-V Virtual Network Adapter(*)\Bytes Sent/sec'
)

Write-Host "Collecting $SampleCount samples (2-second interval)..." -ForegroundColor Cyan

try {
    $samples = Get-Counter -Counter $counters -SampleInterval 2 `
        -MaxSamples $SampleCount -ErrorAction SilentlyContinue
} catch {
    Write-Warning "Counter collection error: $_"
    exit 1
}

$avgSamples = $samples.CounterSamples | Group-Object Path | ForEach-Object {
    [PSCustomObject]@{
        Path     = $_.Name
        Instance = $_.Group[0].InstanceName
        AvgValue = ($_.Group | Measure-Object CookedValue -Average).Average
    }
}

# ── 1. CPU Utilization ───────────────────────────────────────────────────────
Write-Host "`n=== CPU Utilization (% Total Run Time per vCPU) ===" -ForegroundColor Yellow
$avgSamples | Where-Object { $_.Path -match 'Virtual Processor' -and $_.Instance -ne '_total' } |
    Group-Object { $_.Instance -replace ':.*$' } |
    ForEach-Object {
        [PSCustomObject]@{
            VM     = $_.Name
            AvgCPU = [math]::Round(($_.Group | Measure-Object AvgValue -Average).Average, 1)
            MaxvCPU = [math]::Round(($_.Group | Measure-Object AvgValue -Maximum).Maximum, 1)
        }
    } | Sort-Object AvgCPU -Descending | Format-Table -AutoSize

# ── 2. Memory Pressure ───────────────────────────────────────────────────────
Write-Host "`n=== Memory Pressure ===" -ForegroundColor Yellow
$avgSamples | Where-Object { $_.Path -match 'Current Pressure' -and $_.Instance -ne '_total' } |
    ForEach-Object {
        $status = switch ([int]$_.AvgValue) {
            { $_ -le 80  } { "Excess"   }
            { $_ -le 100 } { "Normal"   }
            { $_ -le 150 } { "Pressure" }
            default         { "CRITICAL" }
        }
        [PSCustomObject]@{
            VM       = $_.Instance
            Pressure = [math]::Round($_.AvgValue, 1)
            Status   = $status
        }
    } | Sort-Object Pressure -Descending | Format-Table -AutoSize

# ── 3. Disk I/O ──────────────────────────────────────────────────────────────
Write-Host "`n=== Disk I/O ===" -ForegroundColor Yellow
$readLat  = $avgSamples | Where-Object { $_.Path -match 'Average Read Latency'  -and $_.Instance -ne '_total' }
$writeLat = $avgSamples | Where-Object { $_.Path -match 'Average Write Latency' -and $_.Instance -ne '_total' }
$readBps  = $avgSamples | Where-Object { $_.Path -match 'Read Bytes/sec'        -and $_.Instance -ne '_total' }
$writeBps = $avgSamples | Where-Object { $_.Path -match 'Write Bytes/sec'       -and $_.Instance -ne '_total' }

$readLat | ForEach-Object {
    $inst = $_.Instance
    [PSCustomObject]@{
        Disk           = $inst
        ReadLat_ms     = [math]::Round($_.AvgValue, 2)
        WriteLat_ms    = [math]::Round(($writeLat | Where-Object Instance -eq $inst |
            Select-Object -First 1).AvgValue, 2)
        ReadMBs        = [math]::Round(($readBps | Where-Object Instance -eq $inst |
            Select-Object -First 1).AvgValue / 1MB, 2)
        WriteMBs       = [math]::Round(($writeBps | Where-Object Instance -eq $inst |
            Select-Object -First 1).AvgValue / 1MB, 2)
    }
} | Sort-Object ReadLat_ms -Descending | Format-Table -AutoSize

# ── 4. Network I/O ───────────────────────────────────────────────────────────
Write-Host "`n=== Network I/O ===" -ForegroundColor Yellow
$rxBytes = $avgSamples | Where-Object { $_.Path -match 'Bytes Received' -and $_.Instance -ne '_total' }
$txBytes = $avgSamples | Where-Object { $_.Path -match 'Bytes Sent'     -and $_.Instance -ne '_total' }

$rxBytes | ForEach-Object {
    $inst = $_.Instance
    [PSCustomObject]@{
        Adapter = $inst
        RxMBps  = [math]::Round($_.AvgValue / 1MB, 3)
        TxMBps  = [math]::Round(($txBytes | Where-Object Instance -eq $inst |
            Select-Object -First 1).AvgValue / 1MB, 3)
    }
} | Sort-Object RxMBps -Descending | Format-Table -AutoSize
