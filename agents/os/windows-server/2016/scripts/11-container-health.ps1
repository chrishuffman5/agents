<#
.SYNOPSIS
    Windows Server 2016 - Container Health Diagnostics
.DESCRIPTION
    Checks Docker Engine status, container runtime, running containers,
    images, and network configuration for Windows Server 2016 container hosts.
.NOTES
    Version : 2016.1.0
    Targets : Windows Server 2016+
    Safety  : Read-only. No modifications to system configuration.
    Sections:
        1. Docker Engine Status
        2. Container Feature Status
        3. Running Containers
        4. Container Images
        5. Docker Networks
#>
#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
$sep = '=' * 70

Write-Host "`n$sep"
Write-Host " Windows Server 2016 Container Health - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host $sep

#region Section 1: Docker Engine Status
Write-Host "`n--- Section 1: Docker Engine Status ---"
$dockerSvc = Get-Service -Name docker -ErrorAction SilentlyContinue
if ($dockerSvc) {
    [PSCustomObject]@{
        Service = $dockerSvc.Name; Status = $dockerSvc.Status; StartType = $dockerSvc.StartType
        Assessment = if ($dockerSvc.Status -eq 'Running') { 'OK' } else { 'WARNING: Docker not running' }
    } | Format-List
    if ($dockerSvc.Status -eq 'Running') {
        Write-Host "Docker version:" ; docker version 2>&1 | Write-Host
    }
} else { Write-Warning "Docker service not found." }
#endregion

#region Section 2: Container Feature
Write-Host "`n--- Section 2: Container Feature Status ---"
$feat = Get-WindowsFeature -Name Containers -ErrorAction SilentlyContinue
[PSCustomObject]@{ Feature = 'Containers'; Installed = $feat.Installed } | Format-List
#endregion

#region Section 3: Running Containers
Write-Host "--- Section 3: Running Containers ---"
if ($dockerSvc -and $dockerSvc.Status -eq 'Running') {
    docker ps --format "table {{.ID}}\t{{.Image}}\t{{.Status}}\t{{.Names}}" 2>&1 | Write-Host
} else { Write-Host "Docker not running -- skipping." }
#endregion

#region Section 4: Container Images
Write-Host "`n--- Section 4: Container Images ---"
if ($dockerSvc -and $dockerSvc.Status -eq 'Running') {
    docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" 2>&1 | Write-Host
} else { Write-Host "Docker not running -- skipping." }
#endregion

#region Section 5: Docker Networks
Write-Host "`n--- Section 5: Docker Networks ---"
if ($dockerSvc -and $dockerSvc.Status -eq 'Running') {
    docker network ls 2>&1 | Write-Host
} else { Write-Host "Docker not running -- skipping." }
#endregion

Write-Host "`n$sep"
Write-Host " Container Health Check Complete"
Write-Host "$sep`n"
