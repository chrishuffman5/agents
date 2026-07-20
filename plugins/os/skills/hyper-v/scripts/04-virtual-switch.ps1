<#
.SYNOPSIS
    Windows Server Hyper-V - Virtual Switch Configuration Audit
.DESCRIPTION
    Enumerates all virtual switches and their configuration including Switch
    Embedded Teaming (SET), SR-IOV capabilities, VLAN policies, bandwidth
    management settings, and per-VM network adapter configuration.
.NOTES
    Version : 1.0.0
    Targets : Windows Server 2016+ with Hyper-V role installed
    Safety  : Read-only. No modifications to system configuration.
    Sections:
        1. Virtual Switch Configuration
        2. Management OS Virtual Adapters
        3. VM Network Adapter Configuration
        4. Virtual Switch Packet Drop Counters
#>

#Requires -Modules Hyper-V
#Requires -RunAsAdministrator

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

# ── 1. Virtual Switch Configuration ──────────────────────────────────────────
Write-Host "=== Virtual Switch Configuration ===" -ForegroundColor Cyan

Get-VMSwitch | ForEach-Object {
    $sw  = $_
    $ext = Get-VMSwitchExtension -VMSwitch $sw -ErrorAction SilentlyContinue

    [PSCustomObject]@{
        Name             = $sw.Name
        SwitchType       = $sw.SwitchType
        EmbeddedTeaming  = $sw.EmbeddedTeamingEnabled
        AllowMgmtOS      = $sw.AllowManagementOS
        PhysicalAdapters  = ($sw.NetAdapterInterfaceDescriptions -join ", ")
        IOV_Enabled      = $sw.IovEnabled
        IOV_Support      = $sw.IovSupport
        PacketDirect     = $sw.PacketDirectEnabled
        Extensions       = ($ext | Where-Object Enabled | Select-Object -ExpandProperty Name) -join ", "
    } | Format-List
    Write-Host ("-" * 60)
}

# ── 2. Management OS Virtual Adapters ────────────────────────────────────────
Write-Host "`n=== Management OS Virtual Adapters ===" -ForegroundColor Cyan
Get-VMNetworkAdapter -ManagementOS | Select-Object Name, SwitchName, MacAddress,
    @{n="IPAddresses";e={$_.IPAddresses -join ", "}} | Format-Table -AutoSize

# ── 3. VM Network Adapter Configuration ──────────────────────────────────────
Write-Host "`n=== VM Network Adapter Configuration ===" -ForegroundColor Cyan
Get-VM | ForEach-Object {
    $vm = $_
    Get-VMNetworkAdapter -VMName $vm.Name | ForEach-Object {
        $nic  = $_
        $vlan = Get-VMNetworkAdapterVlan -VMNetworkAdapter $nic -ErrorAction SilentlyContinue
        [PSCustomObject]@{
            VM         = $vm.Name
            Adapter    = $nic.Name
            Switch     = $nic.SwitchName
            MACType    = if ($nic.DynamicMacAddressEnabled) {"Dynamic"} else {"Static"}
            MACSpoof   = $nic.MacAddressSpoofing
            VlanMode   = $vlan.OperationMode
            VlanId     = if ($vlan.OperationMode -eq 'Access') {$vlan.AccessVlanId} else {"N/A"}
            IOV_Weight = $nic.IovWeight
            IOV_Usage  = $nic.IovUsage
        }
    }
} | Format-Table VM, Adapter, Switch, MACType, MACSpoof, VlanMode, VlanId,
    IOV_Weight -AutoSize

# ── 4. Packet Drop Counters ──────────────────────────────────────────────────
Write-Host "`n=== Virtual Switch Packet Drop Counters ===" -ForegroundColor Cyan
$dropCounters = @(
    '\Hyper-V Virtual Switch(*)\Dropped Packets Outgoing/sec',
    '\Hyper-V Virtual Switch(*)\Dropped Packets Incoming/sec'
)
try {
    Get-Counter -Counter $dropCounters -SampleInterval 1 -MaxSamples 3 -ErrorAction Stop |
        Select-Object -ExpandProperty CounterSamples |
        Where-Object { $_.InstanceName -ne '_total' } |
        Group-Object InstanceName |
        ForEach-Object {
            [PSCustomObject]@{
                Switch     = $_.Name
                DroppedIn  = [math]::Round(($_.Group | Where-Object {$_.Path -match 'Incoming'} |
                    Measure-Object CookedValue -Average).Average, 2)
                DroppedOut = [math]::Round(($_.Group | Where-Object {$_.Path -match 'Outgoing'} |
                    Measure-Object CookedValue -Average).Average, 2)
            }
        } | Format-Table -AutoSize
} catch {
    Write-Warning "Could not collect packet drop counters: $_"
}
