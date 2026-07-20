<#
.SYNOPSIS
    Windows Server Hyper-V - Integration Services Health Audit
.DESCRIPTION
    Reports the status of all Integration Services components for each VM.
    Flags disabled or degraded services. For Linux VMs, attempts to identify
    the guest OS via KVP (Key-Value Pair) data exchange.
.NOTES
    Version : 1.0.0
    Targets : Windows Server 2016+ with Hyper-V role installed
    Safety  : Read-only. No modifications to system configuration.
    Sections:
        1. Per-VM IS Component Status
        2. VMs with Integration Service Issues
        3. KVP Data Exchange (Guest Information)
#>

#Requires -Modules Hyper-V
#Requires -RunAsAdministrator

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

Write-Host "=== Integration Services Audit ===" -ForegroundColor Cyan
Write-Host "Host: $env:COMPUTERNAME  |  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"

# ── 1. Per-VM IS Component Status ────────────────────────────────────────────
$isReport = Get-VM | ForEach-Object {
    $vm       = $_
    $services = Get-VMIntegrationService -VMName $vm.Name -ErrorAction SilentlyContinue

    $heartbeat = $services | Where-Object Name -eq 'Heartbeat'
    $shutdown  = $services | Where-Object Name -eq 'Operating System Shutdown'
    $timeSync  = $services | Where-Object Name -eq 'Time Synchronization'
    $dataEx    = $services | Where-Object Name -eq 'Data Exchange'
    $vss       = $services | Where-Object Name -eq 'Volume Shadow Copy'
    $guestSvc  = $services | Where-Object Name -eq 'Guest Service Interface'

    [PSCustomObject]@{
        VM           = $vm.Name
        State        = $vm.State
        ISVersion    = $vm.IntegrationServicesVersion
        Heartbeat    = if ($heartbeat) { $heartbeat.PrimaryStatusDescription } else { "N/A" }
        Shutdown     = if ($shutdown)  { if ($shutdown.Enabled)  {"OK"} else {"Disabled"} } else { "N/A" }
        TimeSync     = if ($timeSync)  { if ($timeSync.Enabled)  {"OK"} else {"Disabled"} } else { "N/A" }
        DataExchange = if ($dataEx)    { if ($dataEx.Enabled)    {"OK"} else {"Disabled"} } else { "N/A" }
        VSS          = if ($vss)       { $vss.PrimaryStatusDescription } else { "N/A" }
        GuestSvc     = if ($guestSvc)  { if ($guestSvc.Enabled)  {"OK"} else {"Disabled"} } else { "N/A" }
        IssueCount   = ($services | Where-Object {
            -not $_.Enabled -or $_.PrimaryStatusDescription -notin 'OK','No Contact'
        }).Count
    }
}

$isReport | Format-Table VM, State, ISVersion, Heartbeat, Shutdown,
    TimeSync, DataExchange, VSS, GuestSvc -AutoSize

# ── 2. VMs with IS Issues ────────────────────────────────────────────────────
Write-Host "`n=== VMs with Integration Service Issues ===" -ForegroundColor Yellow
$issues = $isReport | Where-Object {
    $_.IssueCount -gt 0 -or
    $_.Heartbeat -notin 'OK','No Contact','Not Applicable'
}
if ($issues) {
    $issues | Select-Object VM, ISVersion, Heartbeat, Shutdown,
        TimeSync, DataExchange, VSS | Format-Table -AutoSize
} else {
    Write-Host "All VMs have healthy Integration Services." -ForegroundColor Green
}

# ── 3. KVP Data Exchange (Guest Information) ──────────────────────────────────
Write-Host "`n=== KVP Data Exchange (Guest Information) ===" -ForegroundColor Cyan
Get-VM | Where-Object State -eq 'Running' | ForEach-Object {
    $vm = $_
    try {
        $kvpData = Get-CimInstance -Namespace root\virtualization\v2 `
            -ClassName Msvm_KvpExchangeComponent -ErrorAction Stop |
            Where-Object { $_.SystemName -eq $vm.Id }

        if ($kvpData -and $kvpData.GuestIntrinsicExchangeItems) {
            $guestProps = [xml]("<root>" +
                ($kvpData.GuestIntrinsicExchangeItems -join "") + "</root>")
            $osName = $guestProps.root.INSTANCE |
                Where-Object {
                    ($_.PROPERTY | Where-Object Name -eq 'Name' |
                        Select-Object -ExpandProperty VALUE) -eq 'OSName'
                } | ForEach-Object {
                    $_.PROPERTY | Where-Object Name -eq 'Data' |
                        Select-Object -ExpandProperty VALUE
                }
            if ($osName) {
                Write-Host "  $($vm.Name): $($osName | Select-Object -First 1)"
            }
        }
    } catch {
        # KVP query failure is non-critical
    }
}
