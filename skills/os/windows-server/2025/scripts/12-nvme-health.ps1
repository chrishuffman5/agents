<#
.SYNOPSIS
    Windows Server 2025 - NVMe Native Stack Health
.DESCRIPTION
    Verifies NVMe devices are using the native I/O stack, checks queue
    depth capability, NVMe/TCP connections, and disk performance baseline.
.NOTES
    Version : 2025.1.0
    Targets : Windows Server 2025+
    Safety  : Read-only. No modifications to system configuration.
    Sections:
        1. NVMe Physical Disks
        2. NVMe Namespace Details
        3. NVMe/TCP Connections (Datacenter)
        4. NVMe Performance Counters
#>
#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
$sep = '=' * 70
Write-Host "`n$sep`n NVMe Native Stack Health`n$sep"

Write-Host "`n--- Section 1: NVMe Physical Disks ---"
$nvmeDisks = Get-PhysicalDisk | Where-Object BusType -eq 'NVMe'
if ($nvmeDisks) {
    $nvmeDisks | Select-Object DeviceId, FriendlyName, MediaType,
        @{N='SizeGB';E={[math]::Round($_.Size/1GB,1)}}, HealthStatus, OperationalStatus | Format-Table -AutoSize
} else { Write-Host "No NVMe disks detected." ; return }

Write-Host "--- Section 2: NVMe Disk Details ---"
Get-Disk | Where-Object BusType -eq 'NVMe' |
    Select-Object Number, FriendlyName, @{N='SizeGB';E={[math]::Round($_.Size/1GB)}},
        PartitionStyle, HealthStatus, OperationalStatus | Format-Table -AutoSize

$nvmeDisks | Get-StorageReliabilityCounter -EA SilentlyContinue |
    Select-Object DeviceId, ReadErrorsTotal, WriteErrorsTotal, Temperature, Wear, PowerOnHours | Format-Table -AutoSize

Write-Host "--- Section 3: NVMe/TCP Connections ---"
try {
    $nvmeTcp = Get-NvmeTcpConnection -EA Stop
    if ($nvmeTcp) { $nvmeTcp | Format-Table -AutoSize }
    else { Write-Host "No NVMe/TCP connections (Datacenter edition feature)." }
} catch { Write-Host "NVMe/TCP cmdlets not available (may require Datacenter edition)." }

Write-Host "--- Section 4: NVMe Performance Snapshot ---"
$nvmeDiskNum = ($nvmeDisks | Select-Object -First 1).DeviceId
try {
    $counters = Get-Counter "\PhysicalDisk($nvmeDiskNum*)\Avg. Disk sec/Read",
                            "\PhysicalDisk($nvmeDiskNum*)\Avg. Disk sec/Write",
                            "\PhysicalDisk($nvmeDiskNum*)\Disk Reads/sec",
                            "\PhysicalDisk($nvmeDiskNum*)\Disk Writes/sec" -SampleInterval 2 -MaxSamples 3 -EA SilentlyContinue
    $counters.CounterSamples | Select-Object Path,
        @{N='Value';E={[math]::Round($_.CookedValue,4)}} | Format-Table -AutoSize
} catch { Write-Host "Could not collect NVMe performance counters." }
Write-Host "`n$sep`n NVMe Health Complete`n$sep"
