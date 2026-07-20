<#
.SYNOPSIS
    Windows Server 2022 - Container Health (HostProcess + gMSA)
.DESCRIPTION
    Checks Docker/containerd status, HostProcess container support,
    gMSA configuration, container images, and Kubernetes readiness.
.NOTES
    Version : 2022.1.0
    Targets : Windows Server 2022+
    Safety  : Read-only. No modifications to system configuration.
    Sections:
        1. Container Runtime Status
        2. HostProcess Container Support
        3. gMSA Credential Specs
        4. Container Images
        5. Kubernetes Node Status
#>
#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
$sep = '=' * 70
Write-Host "`n$sep`n Windows Server 2022 Container Health`n$sep"

Write-Host "`n--- Section 1: Container Runtime ---"
$docker = Get-Service docker -EA SilentlyContinue
$ctrd = Get-Service containerd -EA SilentlyContinue
if ($docker) { Write-Host "Docker: $($docker.Status)" ; if ($docker.Status -eq 'Running') { docker version 2>&1 | Write-Host } }
if ($ctrd) { Write-Host "containerd: $($ctrd.Status)" ; if ($ctrd.Status -eq 'Running') { try { containerd --version 2>&1 | Write-Host } catch {} } }
if (-not $docker -and -not $ctrd) { Write-Warning "No container runtime found." }

Write-Host "`n--- Section 2: HostProcess Container Support ---"
$feat = Get-WindowsFeature -Name Containers -EA SilentlyContinue
Write-Host "Containers feature: $(if($feat.Installed){'Installed'}else{'Not installed'})"
$hostBuild = (Get-CimInstance Win32_OperatingSystem).BuildNumber
Write-Host "Host build: $hostBuild (HostProcess requires 20348+)"
Write-Host "HostProcess compatible: $(if([int]$hostBuild -ge 20348){'Yes'}else{'No'})"

Write-Host "`n--- Section 3: gMSA Credential Specs ---"
$credSpecPath = 'C:\ProgramData\Docker\CredentialSpecs'
if (Test-Path $credSpecPath) {
    $specs = Get-ChildItem $credSpecPath -Filter '*.json' -EA SilentlyContinue
    if ($specs) { $specs | Select-Object Name, Length, LastWriteTime | Format-Table -AutoSize }
    else { Write-Host "No credential spec files found." }
} else { Write-Host "CredentialSpecs directory not found." }

Write-Host "--- Section 4: Container Images ---"
if ($docker -and $docker.Status -eq 'Running') { docker images 2>&1 | Write-Host }
elseif ($ctrd -and $ctrd.Status -eq 'Running') { try { ctr images ls 2>&1 | Write-Host } catch {} }

Write-Host "`n--- Section 5: Kubernetes Components ---"
@('kubelet.exe', 'kube-proxy.exe') | ForEach-Object {
    $p = "C:\k\$_"
    Write-Host "$_ : $(if(Test-Path $p){'Present'}else{'Not found'})"
}
Write-Host "`n$sep`n Container Health Complete`n$sep"
