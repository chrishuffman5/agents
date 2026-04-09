<#
.SYNOPSIS
    Windows Server - Performance Baseline Snapshot
.DESCRIPTION
    Captures key CPU, memory, disk, and network performance counters
    using Get-Counter. Provides a point-in-time baseline with threshold
    assessments for quick identification of resource bottlenecks.
.NOTES
    Version : 1.0.0
    Targets : Windows Server 2016+
    Safety  : Read-only. No modifications to system configuration.
    Sections:
        1. CPU Utilization
        2. Memory Utilization
        3. Disk Latency and Queue Depth
        4. Network Interface Throughput
        5. Top Processes by CPU
        6. Top Processes by Memory
#>
#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
$sep = '=' * 70

Write-Host "`n$sep"
Write-Host " Windows Server Performance Baseline - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "$sep"

#region Section 1: CPU Utilization
Write-Host "`n$sep"
Write-Host " SECTION 1 - CPU Utilization (5 samples, 2s interval)"
Write-Host $sep

$cpuCounters = Get-Counter '\Processor(_Total)\% Processor Time',
                           '\System\Processor Queue Length',
                           '\Processor(_Total)\% Privileged Time' -SampleInterval 2 -MaxSamples 5 -ErrorAction SilentlyContinue

$cpuAvg = ($cpuCounters.CounterSamples | Where-Object Path -like '*% Processor Time' | Measure-Object -Property CookedValue -Average).Average
$queueAvg = ($cpuCounters.CounterSamples | Where-Object Path -like '*Queue Length' | Measure-Object -Property CookedValue -Average).Average
$privAvg = ($cpuCounters.CounterSamples | Where-Object Path -like '*% Privileged*' | Measure-Object -Property CookedValue -Average).Average
$cpuCount = (Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors

[PSCustomObject]@{
    AvgCpuPercent      = [math]::Round($cpuAvg, 1)
    AvgQueueLength     = [math]::Round($queueAvg, 1)
    QueuePerCpu        = [math]::Round($queueAvg / $cpuCount, 2)
    AvgPrivilegedPct   = [math]::Round($privAvg, 1)
    LogicalProcessors  = $cpuCount
    CpuAssessment      = if ($cpuAvg -gt 90) { 'CRITICAL: CPU > 90%' }
                         elseif ($cpuAvg -gt 70) { 'WARNING: CPU > 70%' }
                         else { 'OK' }
    QueueAssessment    = if (($queueAvg / $cpuCount) -gt 4) { 'CRITICAL: Queue > 4x CPU count' }
                         elseif (($queueAvg / $cpuCount) -gt 2) { 'WARNING: Queue > 2x CPU count' }
                         else { 'OK' }
} | Format-List
#endregion

#region Section 2: Memory Utilization
Write-Host "$sep"
Write-Host " SECTION 2 - Memory Utilization"
Write-Host $sep

$memCounters = Get-Counter '\Memory\Available MBytes',
                           '\Memory\Pages/sec',
                           '\Memory\Committed Bytes',
                           '\Memory\Pool Nonpaged Bytes' -SampleInterval 2 -MaxSamples 3 -ErrorAction SilentlyContinue

$availMB = ($memCounters.CounterSamples | Where-Object Path -like '*Available MBytes' | Measure-Object -Property CookedValue -Average).Average
$pagesSec = ($memCounters.CounterSamples | Where-Object Path -like '*Pages/sec' | Measure-Object -Property CookedValue -Average).Average
$totalMB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1MB)
$pctFree = [math]::Round(($availMB / $totalMB) * 100, 1)

[PSCustomObject]@{
    TotalRAM_MB       = $totalMB
    AvailableMB       = [math]::Round($availMB)
    PercentFree       = $pctFree
    PagesPerSec       = [math]::Round($pagesSec, 1)
    MemAssessment     = if ($pctFree -lt 5) { 'CRITICAL: < 5% memory free' }
                        elseif ($pctFree -lt 10) { 'WARNING: < 10% memory free' }
                        else { 'OK' }
    PagingAssessment  = if ($pagesSec -gt 500) { 'CRITICAL: Heavy paging (>500 pages/sec)' }
                        elseif ($pagesSec -gt 100) { 'WARNING: Paging activity (>100 pages/sec)' }
                        else { 'OK' }
} | Format-List
#endregion

#region Section 3: Disk Latency and Queue Depth
Write-Host "$sep"
Write-Host " SECTION 3 - Disk Latency and Queue Depth"
Write-Host $sep

$diskCounters = Get-Counter '\PhysicalDisk(*)\Avg. Disk sec/Read',
                            '\PhysicalDisk(*)\Avg. Disk sec/Write',
                            '\PhysicalDisk(*)\Current Disk Queue Length' -SampleInterval 2 -MaxSamples 3 -ErrorAction SilentlyContinue

$diskCounters.CounterSamples | Where-Object { $_.InstanceName -ne '_total' -and $_.InstanceName -ne '' } |
    Group-Object InstanceName | ForEach-Object {
        $samples = $_.Group
        $readMs = ($samples | Where-Object Path -like '*sec/Read' | Measure-Object -Property CookedValue -Average).Average * 1000
        $writeMs = ($samples | Where-Object Path -like '*sec/Write' | Measure-Object -Property CookedValue -Average).Average * 1000
        $queue = ($samples | Where-Object Path -like '*Queue Length' | Measure-Object -Property CookedValue -Average).Average

        [PSCustomObject]@{
            Disk           = $_.Name
            AvgReadMs      = [math]::Round($readMs, 2)
            AvgWriteMs     = [math]::Round($writeMs, 2)
            AvgQueueDepth  = [math]::Round($queue, 1)
            Assessment     = if ($readMs -gt 50 -or $writeMs -gt 50) { 'CRITICAL: >50ms latency' }
                             elseif ($readMs -gt 20 -or $writeMs -gt 20) { 'WARNING: >20ms latency' }
                             else { 'OK' }
        }
    } | Format-Table -AutoSize
#endregion

#region Section 4: Network Interface Throughput
Write-Host "$sep"
Write-Host " SECTION 4 - Network Interface Throughput"
Write-Host $sep

Get-NetAdapter | Where-Object Status -eq 'Up' | ForEach-Object {
    $adapter = $_
    $counterPath = "\Network Interface($($adapter.InterfaceDescription))\Bytes Total/sec"
    try {
        $sample = (Get-Counter $counterPath -SampleInterval 2 -MaxSamples 2 -ErrorAction SilentlyContinue).CounterSamples |
                  Measure-Object -Property CookedValue -Average
        $bytesPerSec = $sample.Average
        $linkSpeedBytes = $adapter.LinkSpeed -replace '[^0-9]','' | ForEach-Object { [long]$_ * 1000000 / 8 }
        $pctUsed = if ($linkSpeedBytes -gt 0) { [math]::Round(($bytesPerSec / $linkSpeedBytes) * 100, 1) } else { 0 }

        [PSCustomObject]@{
            Adapter    = $adapter.Name
            LinkSpeed  = $adapter.LinkSpeed
            AvgMBps    = [math]::Round($bytesPerSec / 1MB, 2)
            PctUsed    = $pctUsed
            Assessment = if ($pctUsed -gt 80) { 'CRITICAL' } elseif ($pctUsed -gt 60) { 'WARNING' } else { 'OK' }
        }
    } catch { }
} | Format-Table -AutoSize
#endregion

#region Section 5: Top Processes by CPU
Write-Host "$sep"
Write-Host " SECTION 5 - Top 10 Processes by CPU Time"
Write-Host $sep

Get-Process | Sort-Object CPU -Descending | Select-Object -First 10 `
    Name, Id, @{N='CPU_Sec';E={[math]::Round($_.CPU,1)}}, Handles,
    @{N='WS_MB';E={[math]::Round($_.WorkingSet64/1MB,1)}} | Format-Table -AutoSize
#endregion

#region Section 6: Top Processes by Memory
Write-Host "$sep"
Write-Host " SECTION 6 - Top 10 Processes by Working Set"
Write-Host $sep

Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 10 `
    Name, Id, @{N='WS_MB';E={[math]::Round($_.WorkingSet64/1MB,1)}},
    @{N='PM_MB';E={[math]::Round($_.PagedMemorySize64/1MB,1)}}, Handles | Format-Table -AutoSize
#endregion

Write-Host "`n$sep"
Write-Host " Performance Baseline Complete - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "$sep`n"
