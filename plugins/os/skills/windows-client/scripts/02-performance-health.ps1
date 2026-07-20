<#
.SYNOPSIS
    Windows Client - Performance and Health Snapshot
.DESCRIPTION
    Captures CPU utilization, memory pressure, disk latency and usage,
    startup impact items, top resource-heavy processes, and page file
    configuration. Provides actionable assessments for each metric.
.NOTES
    Version : 1.0.0
    Targets : Windows 10/11
    Safety  : Read-only. No modifications to system configuration.
    Sections:
        1. CPU Utilization
        2. Memory Pressure
        3. Disk Usage and Health
        4. Startup Impact Items
        5. Resource-Heavy Processes
        6. Page File Configuration
#>
#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
$sep = '=' * 70

#region Section 1: CPU Utilization
Write-Host "`n$sep`n SECTION 1 - CPU Utilization`n$sep"

$cpuLoad = (Get-Counter '\Processor(_Total)\% Processor Time' -SampleInterval 2 -MaxSamples 5).CounterSamples |
    Measure-Object CookedValue -Average
$cpuPriv = (Get-Counter '\Processor(_Total)\% Privileged Time' -SampleInterval 2 -MaxSamples 3).CounterSamples |
    Measure-Object CookedValue -Average
$procQ   = (Get-Counter '\System\Processor Queue Length' -SampleInterval 2 -MaxSamples 3).CounterSamples |
    Measure-Object CookedValue -Average

[PSCustomObject]@{
    CPU_Avg_Pct        = [math]::Round($cpuLoad.Average, 1)
    Privileged_Pct     = [math]::Round($cpuPriv.Average, 1)
    ProcessorQueueLen  = [math]::Round($procQ.Average, 1)
    CPU_Assessment     = if ($cpuLoad.Average -gt 90) { 'CRITICAL: CPU saturated' }
                         elseif ($cpuLoad.Average -gt 70) { 'WARNING: High CPU' }
                         elseif ($cpuPriv.Average -gt 20) { 'INFO: High kernel/privileged time -- possible driver issue' }
                         else { 'OK' }
} | Format-List
#endregion

#region Section 2: Memory Pressure
Write-Host "$sep`n SECTION 2 - Memory Pressure`n$sep"

$os        = Get-CimInstance Win32_OperatingSystem
$availMB   = [math]::Round($os.FreePhysicalMemory / 1KB, 0)
$totalGB   = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
$usedGB    = [math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / 1MB, 1)
$freePct   = [math]::Round($os.FreePhysicalMemory / $os.TotalVisibleMemorySize * 100, 1)
$pagesSec  = (Get-Counter '\Memory\Pages/sec' -MaxSamples 5 -SampleInterval 2).CounterSamples |
    Measure-Object CookedValue -Average

[PSCustomObject]@{
    Total_RAM_GB       = $totalGB
    Used_GB            = $usedGB
    Available_MB       = $availMB
    Free_Pct           = $freePct
    Pages_Per_Sec_Avg  = [math]::Round($pagesSec.Average, 1)
    Assessment         = if ($freePct -lt 5) { 'CRITICAL: Very low memory' }
                         elseif ($freePct -lt 10) { 'WARNING: Low memory' }
                         elseif ($pagesSec.Average -gt 100) { 'WARNING: Heavy paging detected' }
                         else { 'OK' }
} | Format-List
#endregion

#region Section 3: Disk Usage and Health
Write-Host "$sep`n SECTION 3 - Disk Usage and Health`n$sep"

Write-Host "Volume Free Space:"
Get-Volume | Where-Object DriveLetter | Select-Object DriveLetter, FileSystemLabel,
    @{N='Size_GB';E={[math]::Round($_.Size/1GB,1)}},
    @{N='Free_GB';E={[math]::Round($_.SizeRemaining/1GB,1)}},
    @{N='Free_Pct';E={[math]::Round($_.SizeRemaining/$_.Size*100,0)}},
    HealthStatus |
    Format-Table -AutoSize

Write-Host "`nDisk Latency (5-sample average):"
$readLat  = (Get-Counter '\PhysicalDisk(_Total)\Avg. Disk sec/Read' -MaxSamples 5 -SampleInterval 2 -ErrorAction SilentlyContinue).CounterSamples |
    Measure-Object CookedValue -Average
$writeLat = (Get-Counter '\PhysicalDisk(_Total)\Avg. Disk sec/Write' -MaxSamples 5 -SampleInterval 2 -ErrorAction SilentlyContinue).CounterSamples |
    Measure-Object CookedValue -Average

[PSCustomObject]@{
    ReadLatency_ms  = [math]::Round($readLat.Average * 1000, 2)
    WriteLatency_ms = [math]::Round($writeLat.Average * 1000, 2)
    Assessment      = if ($readLat.Average * 1000 -gt 50 -or $writeLat.Average * 1000 -gt 50) {
                          'WARNING: High disk latency (>50ms)' }
                      elseif ($readLat.Average * 1000 -gt 20) { 'INFO: Elevated read latency' }
                      else { 'OK' }
} | Format-List
#endregion

#region Section 4: Startup Impact Items
Write-Host "$sep`n SECTION 4 - Startup Impact Items`n$sep"

$startupItems = Get-CimInstance Win32_StartupCommand |
    Select-Object Name, Command, Location, User
$startupItems | Format-Table -AutoSize

Write-Host "Startup count: $($startupItems.Count)"
if ($startupItems.Count -gt 15) {
    Write-Warning "Large number of startup items ($($startupItems.Count)) -- may impact boot/logon time."
}
#endregion

#region Section 5: Resource-Heavy Processes
Write-Host "$sep`n SECTION 5 - Top Resource-Heavy Processes`n$sep"

Write-Host "Top 10 by CPU:"
Get-Process | Sort-Object CPU -Descending | Select-Object -First 10 Name, Id,
    @{N='CPU_s';E={[math]::Round($_.CPU,1)}},
    @{N='WS_MB';E={[math]::Round($_.WorkingSet64/1MB,1)}},
    @{N='Handles';E={$_.HandleCount}} | Format-Table -AutoSize

Write-Host "`nTop 10 by Working Set (RAM):"
Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 10 Name, Id,
    @{N='WS_MB';E={[math]::Round($_.WorkingSet64/1MB,1)}},
    @{N='PM_MB';E={[math]::Round($_.PagedMemorySize64/1MB,1)}} | Format-Table -AutoSize
#endregion

#region Section 6: Page File Configuration
Write-Host "$sep`n SECTION 6 - Page File Configuration`n$sep"

Get-CimInstance Win32_PageFileUsage | Select-Object Name,
    @{N='AllocatedBase_MB';E={$_.AllocatedBaseSize}},
    @{N='CurrentUsage_MB';E={$_.CurrentUsage}},
    @{N='PeakUsage_MB';E={$_.PeakUsage}} | Format-Table -AutoSize

$autoMgd = (Get-CimInstance Win32_ComputerSystem).AutomaticManagedPagefile
Write-Host "System-managed page file: $autoMgd"
if ($autoMgd) { Write-Host "INFO: Windows manages page file size automatically." }
#endregion

Write-Host "`n$sep`n Performance Health Complete - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n$sep`n"
