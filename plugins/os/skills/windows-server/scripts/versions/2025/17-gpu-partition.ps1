<#
.SYNOPSIS
    Windows Server 2025 - GPU Partitioning (GPU-P) Status
.DESCRIPTION
    Checks GPU partitioning availability, assigned GPU adapters,
    VM GPU assignments, and VRAM allocation for Hyper-V GPU-P.
.NOTES
    Version : 2025.1.0
    Targets : Windows Server 2025 with Hyper-V
    Safety  : Read-only. No modifications to system configuration.
    Sections:
        1. Partitionable GPU Detection
        2. GPU Partition Configuration
        3. VMs with GPU Assignments
        4. GPU Driver Information
#>
#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
$sep = '=' * 70
Write-Host "`n$sep`n GPU Partitioning Status (Server 2025)`n$sep"

Write-Host "`n--- Section 1: Partitionable GPUs ---"
try {
    $gpus = Get-VMHostPartitionableGpu -EA Stop
    if ($gpus) {
        $gpus | ForEach-Object {
            [PSCustomObject]@{
                Name               = $_.Name
                ValidPartitions    = $_.ValidPartitionCounts -join ', '
                CurrentPartitions  = $_.CurrentPartitionCount
                TotalVRAM_MB       = [math]::Round($_.TotalVRAM / 1MB)
                TotalEncode        = $_.TotalEncode
                TotalDecode        = $_.TotalDecode
                TotalCompute       = $_.TotalCompute
            }
        } | Format-List
    } else {
        Write-Host "No partitionable GPUs detected."
        Write-Host "Requirements: SR-IOV capable GPU, IOMMU enabled, supported GPU model."
        return
    }
} catch {
    Write-Warning "Get-VMHostPartitionableGpu not available. Ensure Hyper-V role is installed."
    return
}

Write-Host "--- Section 2: GPU Partition Configuration ---"
$gpus | ForEach-Object {
    Write-Host "GPU: $($_.Name)"
    Write-Host "  Valid partition counts: $($_.ValidPartitionCounts -join ', ')"
    Write-Host "  Current partitions: $($_.CurrentPartitionCount)"
}

Write-Host "`n--- Section 3: VMs with GPU Assignments ---"
$vms = Get-VM -EA SilentlyContinue
if ($vms) {
    foreach ($vm in $vms) {
        $gpuAdapters = Get-VMGpuPartitionAdapter -VMName $vm.Name -EA SilentlyContinue
        if ($gpuAdapters) {
            Write-Host "`n  VM: $($vm.Name) [State: $($vm.State)]"
            $gpuAdapters | ForEach-Object {
                [PSCustomObject]@{
                    MinCompute    = $_.MinPartitionCompute
                    MaxCompute    = $_.MaxPartitionCompute
                    OptCompute    = $_.OptimalPartitionCompute
                    MinVRAM_MB    = [math]::Round($_.MinPartitionVRAM / 1MB)
                    MaxVRAM_MB    = [math]::Round($_.MaxPartitionVRAM / 1MB)
                    OptVRAM_MB    = [math]::Round($_.OptimalPartitionVRAM / 1MB)
                }
            } | Format-Table -AutoSize
        }
    }
    $gpuVMs = $vms | Where-Object { Get-VMGpuPartitionAdapter -VMName $_.Name -EA SilentlyContinue }
    if (-not $gpuVMs) { Write-Host "No VMs have GPU-P adapters assigned." }
} else { Write-Host "No VMs found on this host." }

Write-Host "--- Section 4: GPU Driver Information ---"
Get-CimInstance Win32_VideoController | Select-Object Name, DriverVersion, DriverDate,
    @{N='VRAM_MB';E={[math]::Round($_.AdapterRAM/1MB)}} | Format-Table -AutoSize

$edition = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -EA SilentlyContinue).EditionID
if ($edition -match 'Standard') {
    Write-Host "`nNote: Standard edition supports GPU-P for standalone servers only."
    Write-Host "Clustering for unplanned failover requires Datacenter edition."
}
Write-Host "`n$sep`n GPU-P Check Complete`n$sep"
