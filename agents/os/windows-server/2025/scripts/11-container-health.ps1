<#
.SYNOPSIS
    Windows Server 2025 - Container Health (containerd)
.DESCRIPTION
    Checks containerd runtime, container images, running containers,
    OS version compatibility, and Kubernetes node readiness.
.NOTES
    Version : 2025.1.0
    Targets : Windows Server 2025+
    Safety  : Read-only. No modifications to system configuration.
    Sections:
        1. containerd Service Status
        2. Container Runtime Version
        3. Running Containers
        4. Container Images and OS Compatibility
        5. Kubernetes Node Status
#>
#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
$sep = '=' * 70
Write-Host "`n$sep`n Windows Server 2025 Container Health`n$sep"

Write-Host "`n--- Section 1: containerd Service ---"
$ctrd = Get-Service containerd -EA SilentlyContinue
$docker = Get-Service docker -EA SilentlyContinue
if ($ctrd) {
    [PSCustomObject]@{ Service=$ctrd.Name; Status=$ctrd.Status; StartType=$ctrd.StartType } | Format-List
    if ($ctrd.Status -eq 'Running') { try { containerd --version 2>&1 | Write-Host } catch {} }
} else { Write-Warning "containerd not found. Install: winget install --id Microsoft.ContainerD" }
if ($docker) { Write-Warning "Legacy Docker detected ($($docker.Status)). Migrate to containerd." }

Write-Host "--- Section 2: Runtime Version ---"
$hostOS = Get-CimInstance Win32_OperatingSystem
Write-Host "Host: $($hostOS.Caption) Build $($hostOS.BuildNumber)"
Write-Host "Build compatible (26100+): $(if([int]$hostOS.BuildNumber -ge 26100){'Yes'}else{'No'})"

Write-Host "`n--- Section 3: Running Containers ---"
if ($ctrd -and $ctrd.Status -eq 'Running') {
    try { ctr containers list 2>&1 | Write-Host } catch { Write-Host "ctr not available." }
}

Write-Host "`n--- Section 4: Container Images ---"
if ($ctrd -and $ctrd.Status -eq 'Running') {
    try { ctr images ls 2>&1 | Write-Host } catch { Write-Host "Cannot list images." }
}

Write-Host "`n--- Section 5: Kubernetes ---"
@('kubelet.exe','kube-proxy.exe','crictl.exe') | ForEach-Object {
    $found = Get-Command $_ -EA SilentlyContinue
    Write-Host "$_ : $(if($found){$found.Source}else{'Not found'})"
}
Write-Host "`n$sep`n Container Health Complete`n$sep"
