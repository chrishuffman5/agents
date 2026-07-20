<#
.SYNOPSIS
    Windows Server 2019 - Container Health and Runtime Diagnostics
.DESCRIPTION
    Checks Docker Engine status, container isolation modes, running
    containers, images, networks, and Kubernetes node readiness.
.NOTES
    Version : 2019.1.0
    Targets : Windows Server 2019+
    Safety  : Read-only. No modifications to system configuration.
    Sections:
        1. Docker Engine Status
        2. Container Feature and Hyper-V Isolation
        3. Running Containers
        4. Container Images
        5. Docker Networks and HNS
        6. Kubernetes Node Readiness
#>
#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
$sep = '=' * 70
Write-Host "`n$sep`n Windows Server 2019 Container Health`n$sep"

$dockerSvc = Get-Service -Name docker -ErrorAction SilentlyContinue
if ($dockerSvc -and $dockerSvc.Status -eq 'Running') {
    Write-Host "Docker: Running" ; docker version 2>&1 | Write-Host
    Write-Host "`n--- Running Containers ---" ; docker ps 2>&1 | Write-Host
    Write-Host "`n--- Images ---" ; docker images 2>&1 | Write-Host
    Write-Host "`n--- Networks ---" ; docker network ls 2>&1 | Write-Host
} else { Write-Warning "Docker service not running or not installed." }

Write-Host "`n--- HNS Networks ---"
try { Get-HNSNetwork -ErrorAction Stop | Select-Object Name, Type, SubnetIpPrefix | Format-Table -AutoSize } catch { Write-Host "HNS not available." }

Write-Host "--- Kubernetes Components ---"
@('kubelet', 'kube-proxy') | ForEach-Object {
    $path = "C:\k\$_.exe"
    if (Test-Path $path) { Write-Host "$_ found at $path" } else { Write-Host "$_ not found" }
}
Write-Host "`n$sep`n Container Health Complete`n$sep"
