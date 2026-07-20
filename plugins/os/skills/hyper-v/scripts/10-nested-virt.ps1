<#
.SYNOPSIS
    Windows Server Hyper-V - Nested Virtualization Configuration Audit
.DESCRIPTION
    Validates nested virtualization prerequisites and reports which VMs have
    ExposeVirtualizationExtensions enabled. Checks host CPU support (Intel
    VT-x 2016+ or AMD-V 2022+), VM generation, MAC spoofing, and Dynamic
    Memory compatibility with nested Hyper-V.
.NOTES
    Version : 1.0.0
    Targets : Windows Server 2016+ with Hyper-V role installed
    Safety  : Read-only. No modifications to system configuration.
    Sections:
        1. Host CPU Capabilities
        2. Per-VM Nested Virtualization Status
        3. VMs with Nested Virtualization Enabled
        4. Configuration Issues
#>

#Requires -Modules Hyper-V
#Requires -RunAsAdministrator

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

Write-Host "=== Nested Virtualization Audit ===" -ForegroundColor Cyan
Write-Host "Host: $env:COMPUTERNAME  |  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"

# ── 1. Host CPU Capabilities ─────────────────────────────────────────────────
Write-Host "=== Host CPU Capabilities ===" -ForegroundColor Cyan
$cpu     = Get-CimInstance Win32_Processor | Select-Object -First 1
$cpuName = $cpu.Name
$isIntel = $cpuName -match 'Intel'
$isAMD   = $cpuName -match 'AMD'
$osBuild = [System.Environment]::OSVersion.Version.Build

Write-Host "CPU: $cpuName"
Write-Host "Architecture: $(
    if ($isIntel) {'Intel (nested virt: WS2016+)'}
    elseif ($isAMD) {'AMD (nested virt: WS2022+)'}
    else {'Unknown'})"
Write-Host "Host OS Build: $osBuild"

if ($isAMD -and $osBuild -lt 20348) {
    Write-Warning "AMD nested virtualization requires Windows Server 2022 (build 20348+)."
}

$hypervisorPresent = (Get-CimInstance Win32_ComputerSystem).HypervisorPresent
Write-Host "Running as guest (nested already): $hypervisorPresent"

# ── 2. Per-VM Nested Virtualization Status ────────────────────────────────────
Write-Host "`n=== VM Nested Virtualization Status ===" -ForegroundColor Cyan
$nestedReport = Get-VM | ForEach-Object {
    $vm   = $_
    $proc = Get-VMProcessor -VMName $vm.Name
    $mem  = Get-VMMemory -VMName $vm.Name
    $nics = Get-VMNetworkAdapter -VMName $vm.Name

    $issues = @()
    if ($vm.Generation -ne 2)                     { $issues += "Gen1 (Gen2 preferred)" }
    if ($mem.DynamicMemoryEnabled)                { $issues += "DynamicMem ON (disable for nested)" }
    if ($mem.Startup -lt 4GB)                     { $issues += "RAM < 4 GB" }
    if ($proc.Count -lt 2)                        { $issues += "vCPU < 2" }
    if ($proc.ExposeVirtualizationExtensions) {
        $noSpoof = $nics | Where-Object MacAddressSpoofing -ne 'On'
        if ($noSpoof) { $issues += "MACSpoof OFF on $($noSpoof.Count) NIC(s)" }
    }

    [PSCustomObject]@{
        VM                = $vm.Name
        State             = $vm.State
        Generation        = $vm.Generation
        NestedVirtEnabled = $proc.ExposeVirtualizationExtensions
        vCPUs             = $proc.Count
        AssignedMem_GB    = [math]::Round($vm.MemoryAssigned / 1GB, 1)
        DynamicMemory     = $mem.DynamicMemoryEnabled
        MacSpoofing       = ($nics | Select-Object -First 1 -ExpandProperty MacAddressSpoofing)
        Issues            = ($issues -join "; ")
        Prerequisites     = if ($issues.Count -eq 0 -or
            ($issues.Count -eq 1 -and $issues[0] -match 'Gen1')) {"READY"} else {"ISSUES"}
    }
}

$nestedReport | Format-Table VM, State, Generation, NestedVirtEnabled,
    vCPUs, AssignedMem_GB, DynamicMemory, MacSpoofing, Prerequisites -AutoSize

# ── 3. VMs with Nested Virtualization Enabled ─────────────────────────────────
Write-Host "`n=== VMs with Nested Virtualization Enabled ===" -ForegroundColor Cyan
$enabledVMs = $nestedReport | Where-Object NestedVirtEnabled -eq $true
if ($enabledVMs) {
    $enabledVMs | Select-Object VM, State, Generation, vCPUs,
        AssignedMem_GB, DynamicMemory, MacSpoofing, Issues | Format-Table -AutoSize
} else {
    Write-Host "No VMs have nested virtualization enabled." -ForegroundColor Gray
}

# ── 4. Configuration Issues ──────────────────────────────────────────────────
Write-Host "`n=== Configuration Issues ===" -ForegroundColor Yellow
$withIssues = $nestedReport | Where-Object { $_.NestedVirtEnabled -and $_.Issues -ne "" }
if ($withIssues) {
    $withIssues | Select-Object VM, Issues | Format-Table -AutoSize -Wrap
} else {
    Write-Host "No configuration issues on nested-virt-enabled VMs." -ForegroundColor Green
}

Write-Host "`nTo enable nested virtualization on a stopped VM:"
Write-Host '  Set-VMProcessor -VMName "VM" -ExposeVirtualizationExtensions $true' -ForegroundColor DarkGray
Write-Host "To enable MAC spoofing (required for nested VM networking):"
Write-Host '  Set-VMNetworkAdapter -VMName "VM" -MacAddressSpoofing On' -ForegroundColor DarkGray
