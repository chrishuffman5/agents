<#
.SYNOPSIS
    Windows Server - Storage Health Assessment
.DESCRIPTION
    Evaluates disk health, volume status, file system type, free space,
    SMART reliability data, and Storage Spaces health. Identifies degraded
    disks, low-space volumes, and active repair jobs.
.NOTES
    Version : 1.0.0
    Targets : Windows Server 2016+
    Safety  : Read-only. No modifications to system configuration.
    Sections:
        1. Physical Disk Health
        2. Volume Status and Free Space
        3. SMART Reliability Counters
        4. Storage Pools and Virtual Disks
        5. Active Storage Jobs
#>
#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
$sep = '=' * 70

Write-Host "`n$sep"
Write-Host " Storage Health Assessment - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host $sep

#region Section 1: Physical Disk Health
Write-Host "`n$sep"
Write-Host " SECTION 1 - Physical Disk Health"
Write-Host $sep

Get-PhysicalDisk | ForEach-Object {
    [PSCustomObject]@{
        DeviceId          = $_.DeviceId
        FriendlyName      = $_.FriendlyName
        MediaType         = $_.MediaType
        BusType           = $_.BusType
        SizeGB            = [math]::Round($_.Size / 1GB, 1)
        HealthStatus      = $_.HealthStatus
        OperationalStatus = $_.OperationalStatus
        Assessment        = if ($_.HealthStatus -ne 'Healthy') { "WARNING: $($_.HealthStatus)" }
                            elseif ($_.OperationalStatus -ne 'OK') { "WARNING: $($_.OperationalStatus)" }
                            else { 'OK' }
    }
} | Format-Table -AutoSize
#endregion

#region Section 2: Volume Status and Free Space
Write-Host "$sep"
Write-Host " SECTION 2 - Volume Status and Free Space"
Write-Host $sep

Get-Volume | Where-Object { $_.DriveLetter -or $_.FileSystemLabel } | ForEach-Object {
    $pctFree = if ($_.Size -gt 0) { [math]::Round(($_.SizeRemaining / $_.Size) * 100, 1) } else { 0 }
    [PSCustomObject]@{
        DriveLetter   = $_.DriveLetter
        Label         = $_.FileSystemLabel
        FileSystem    = $_.FileSystem
        SizeGB        = [math]::Round($_.Size / 1GB, 1)
        FreeGB        = [math]::Round($_.SizeRemaining / 1GB, 1)
        PercentFree   = $pctFree
        HealthStatus  = $_.HealthStatus
        DriveType     = $_.DriveType
        Assessment    = if ($_.HealthStatus -ne 'Healthy') { "WARNING: $($_.HealthStatus)" }
                        elseif ($pctFree -lt 10) { 'CRITICAL: <10% free space' }
                        elseif ($pctFree -lt 20) { 'WARNING: <20% free space' }
                        else { 'OK' }
    }
} | Format-Table -AutoSize
#endregion

#region Section 3: SMART Reliability Counters
Write-Host "$sep"
Write-Host " SECTION 3 - SMART Reliability Counters"
Write-Host $sep

$reliability = Get-PhysicalDisk | Get-StorageReliabilityCounter -ErrorAction SilentlyContinue
if ($reliability) {
    $reliability | ForEach-Object {
        [PSCustomObject]@{
            DeviceId        = $_.DeviceId
            ReadErrors      = $_.ReadErrorsTotal
            WriteErrors     = $_.WriteErrorsTotal
            Temperature     = $_.Temperature
            Wear            = $_.Wear
            PowerOnHours    = $_.PowerOnHours
            Assessment      = if ($_.ReadErrorsTotal -gt 0 -or $_.WriteErrorsTotal -gt 0) { 'WARNING: Disk errors detected' }
                              elseif ($_.Wear -and $_.Wear -gt 90) { 'WARNING: SSD wear > 90%' }
                              elseif ($_.Temperature -and $_.Temperature -gt 60) { 'WARNING: High temperature' }
                              else { 'OK' }
        }
    } | Format-Table -AutoSize
} else {
    Write-Host "SMART data not available (may require direct-attached or Storage Spaces disks)."
}
#endregion

#region Section 4: Storage Pools and Virtual Disks
Write-Host "$sep"
Write-Host " SECTION 4 - Storage Pools and Virtual Disks"
Write-Host $sep

$pools = Get-StoragePool -ErrorAction SilentlyContinue | Where-Object IsPrimordial -eq $false
if ($pools) {
    $pools | Select-Object FriendlyName, OperationalStatus, HealthStatus,
        @{N='SizeGB';E={[math]::Round($_.Size/1GB,1)}},
        @{N='AllocatedGB';E={[math]::Round($_.AllocatedSize/1GB,1)}} | Format-Table -AutoSize

    Write-Host "Virtual Disks:"
    Get-VirtualDisk -ErrorAction SilentlyContinue |
        Select-Object FriendlyName, OperationalStatus, HealthStatus,
            ResiliencySettingName, @{N='SizeGB';E={[math]::Round($_.Size/1GB,1)}} | Format-Table -AutoSize
} else {
    Write-Host "No Storage Pools configured (standalone disks or no Storage Spaces)."
}
#endregion

#region Section 5: Active Storage Jobs
Write-Host "$sep"
Write-Host " SECTION 5 - Active Storage Jobs"
Write-Host $sep

$jobs = Get-StorageJob -ErrorAction SilentlyContinue
if ($jobs) {
    Write-Warning "Active storage repair/rebuild jobs detected:"
    $jobs | Select-Object Name, JobState, PercentComplete, ElapsedTime,
        @{N='EstTimeRemaining';E={$_.EstimatedRemainingTime}} | Format-Table -AutoSize
} else {
    Write-Host "No active storage repair jobs. OK."
}
#endregion

Write-Host "`n$sep"
Write-Host " Storage Health Assessment Complete - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "$sep`n"
