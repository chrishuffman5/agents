# Purpose:        Show running storage repair/rebalance jobs and their progress - the gate before any S2D maintenance
# Applies to:     Storage Spaces Direct on Windows Server 2019/2022/2025 (run on any cluster node, elevated)
# Read-only:      yes
# Inputs:         none
# Interpretation: Any Repair/Regeneration job below 100% means resiliency is still being restored - taking another node
#                 or disk down now risks data unavailability or loss. After node maintenance, repair jobs draining the
#                 dirty region log are NORMAL; wait for completion before the next node (Cluster-Aware Updating does
#                 this for you - manual patching must too). Jobs stuck at a percentage for hours = check the physical
#                 disks feeding that repair (01-pool-and-disk-health.ps1).
# Next step:      Proceed with maintenance ONLY when no repair jobs remain and all virtual disks are Healthy

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host "== Storage jobs"
$jobs = Get-StorageJob
if (-not $jobs) {
    Write-Host "No storage jobs running - repair state clean."
} else {
    $jobs | Select-Object Name, JobState, PercentComplete, IsBackgroundTask, ElapsedTime | Format-Table -AutoSize
}

Write-Host "== Virtual disk health (must all be Healthy before maintenance)"
Get-VirtualDisk | Select-Object FriendlyName, HealthStatus, OperationalStatus | Format-Table -AutoSize
