# ==============================================================================
# PowerCLI VM/Host/Datastore Inventory Report
# ==============================================================================
# Connects to vCenter and generates a comprehensive inventory report covering
# hosts, VMs, datastores, networks, and clusters.
#
# Prerequisites: VMware.PowerCLI module installed
#   Install-Module -Name VMware.PowerCLI -Scope CurrentUser
#
# Usage:
#   .\02-powercli-inventory.ps1 -VCenterServer "vcenter.corp.local"
#   .\02-powercli-inventory.ps1 -VCenterServer "vcenter.corp.local" -ExportPath "C:\Reports"
# ==============================================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$VCenterServer,

    [Parameter(Mandatory = $false)]
    [string]$ExportPath
)

# --- Connect to vCenter ---
Write-Host "Connecting to vCenter: $VCenterServer" -ForegroundColor Cyan
try {
    Connect-VIServer -Server $VCenterServer -ErrorAction Stop | Out-Null
    Write-Host "Connected successfully." -ForegroundColor Green
} catch {
    Write-Error "Failed to connect to vCenter: $_"
    exit 1
}

$divider = "=" * 72

# --- Cluster Inventory ---
Write-Host "`n$divider" -ForegroundColor Yellow
Write-Host "CLUSTER INVENTORY" -ForegroundColor Yellow
Write-Host $divider -ForegroundColor Yellow

$clusters = Get-Cluster | Select-Object Name,
    @{N="Hosts"; E={($_ | Get-VMHost).Count}},
    @{N="VMs"; E={($_ | Get-VM).Count}},
    HAEnabled,
    DrsEnabled,
    DrsAutomationLevel,
    VsanEnabled

$clusters | Format-Table -AutoSize

# --- Host Inventory ---
Write-Host "$divider" -ForegroundColor Yellow
Write-Host "HOST INVENTORY" -ForegroundColor Yellow
Write-Host $divider -ForegroundColor Yellow

$hosts = Get-VMHost | Select-Object Name,
    ConnectionState,
    PowerState,
    @{N="Cluster"; E={$_.Parent.Name}},
    Version,
    Build,
    NumCpu,
    @{N="MemoryTotalGB"; E={[math]::Round($_.MemoryTotalGB, 1)}},
    @{N="MemoryUsedGB"; E={[math]::Round($_.MemoryUsageGB, 1)}},
    @{N="MemoryPct"; E={[math]::Round(($_.MemoryUsageGB / $_.MemoryTotalGB) * 100, 1)}},
    @{N="VMs"; E={($_ | Get-VM).Count}}

$hosts | Format-Table -AutoSize

# --- VM Inventory ---
Write-Host "$divider" -ForegroundColor Yellow
Write-Host "VIRTUAL MACHINE INVENTORY" -ForegroundColor Yellow
Write-Host $divider -ForegroundColor Yellow

$vms = Get-VM | Select-Object Name,
    PowerState,
    NumCpu,
    @{N="MemoryGB"; E={$_.MemoryGB}},
    @{N="ProvisionedGB"; E={[math]::Round($_.ProvisionedSpaceGB, 1)}},
    @{N="UsedGB"; E={[math]::Round($_.UsedSpaceGB, 1)}},
    @{N="HWVersion"; E={$_.ExtensionData.Config.Version}},
    @{N="ToolsStatus"; E={$_.ExtensionData.Guest.ToolsVersionStatus}},
    @{N="GuestOS"; E={$_.ExtensionData.Config.GuestFullName}},
    VMHost,
    Folder

Write-Host "Total VMs: $($vms.Count)"
Write-Host "  Powered On:  $(($vms | Where-Object PowerState -eq 'PoweredOn').Count)"
Write-Host "  Powered Off: $(($vms | Where-Object PowerState -eq 'PoweredOff').Count)"
Write-Host "  Suspended:   $(($vms | Where-Object PowerState -eq 'Suspended').Count)"
Write-Host ""

$vms | Sort-Object VMHost, Name | Format-Table Name, PowerState, NumCpu, MemoryGB,
    ProvisionedGB, UsedGB, HWVersion, ToolsStatus -AutoSize

# --- Datastore Inventory ---
Write-Host "$divider" -ForegroundColor Yellow
Write-Host "DATASTORE INVENTORY" -ForegroundColor Yellow
Write-Host $divider -ForegroundColor Yellow

$datastores = Get-Datastore | Select-Object Name,
    Type,
    @{N="CapacityGB"; E={[math]::Round($_.CapacityGB, 1)}},
    @{N="FreeSpaceGB"; E={[math]::Round($_.FreeSpaceGB, 1)}},
    @{N="UsedPct"; E={[math]::Round((1 - ($_.FreeSpaceGB / $_.CapacityGB)) * 100, 1)}},
    @{N="VMs"; E={($_ | Get-VM).Count}},
    State

$datastores | Sort-Object UsedPct -Descending | Format-Table -AutoSize

# Flag datastores over 80% used
$overused = $datastores | Where-Object { $_.UsedPct -gt 80 }
if ($overused) {
    Write-Host "[WARNING] Datastores over 80% utilized:" -ForegroundColor Red
    $overused | Format-Table Name, UsedPct, FreeSpaceGB -AutoSize
}

# --- Network Inventory ---
Write-Host "$divider" -ForegroundColor Yellow
Write-Host "NETWORK INVENTORY" -ForegroundColor Yellow
Write-Host $divider -ForegroundColor Yellow

Write-Host "Distributed Switches:"
Get-VDSwitch -ErrorAction SilentlyContinue | Select-Object Name, NumPorts, Version,
    @{N="Hosts"; E={($_ | Get-VMHost).Count}} | Format-Table -AutoSize

Write-Host "Port Groups:"
Get-VirtualPortGroup | Select-Object Name, VLanId,
    @{N="Switch"; E={$_.VirtualSwitchName}},
    @{N="Type"; E={if ($_.ExtensionData -is [VMware.Vim.DistributedVirtualPortgroup]) {"Distributed"} else {"Standard"}}} |
    Sort-Object Name | Format-Table -AutoSize

# --- Snapshot Report ---
Write-Host "$divider" -ForegroundColor Yellow
Write-Host "SNAPSHOT REPORT" -ForegroundColor Yellow
Write-Host $divider -ForegroundColor Yellow

$snapshots = Get-VM | Get-Snapshot -ErrorAction SilentlyContinue | Select-Object VM, Name, Created,
    @{N="AgeDays"; E={[math]::Round(((Get-Date) - $_.Created).TotalDays, 1)}},
    @{N="SizeGB"; E={[math]::Round($_.SizeGB, 2)}}

if ($snapshots) {
    Write-Host "[WARNING] VMs with active snapshots:" -ForegroundColor Red
    $snapshots | Sort-Object AgeDays -Descending | Format-Table -AutoSize
} else {
    Write-Host "No active snapshots found." -ForegroundColor Green
}

# --- Export to CSV ---
if ($ExportPath) {
    if (-not (Test-Path $ExportPath)) {
        New-Item -ItemType Directory -Path $ExportPath -Force | Out-Null
    }
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

    $vms | Export-Csv -Path "$ExportPath\vm-inventory-$timestamp.csv" -NoTypeInformation
    $hosts | Export-Csv -Path "$ExportPath\host-inventory-$timestamp.csv" -NoTypeInformation
    $datastores | Export-Csv -Path "$ExportPath\datastore-inventory-$timestamp.csv" -NoTypeInformation

    Write-Host "`nReports exported to: $ExportPath" -ForegroundColor Green
}

# --- Summary ---
Write-Host "`n$divider" -ForegroundColor Yellow
Write-Host "INVENTORY SUMMARY" -ForegroundColor Yellow
Write-Host $divider -ForegroundColor Yellow
Write-Host "  Clusters:   $($clusters.Count)"
Write-Host "  Hosts:      $($hosts.Count)"
Write-Host "  VMs:        $($vms.Count)"
Write-Host "  Datastores: $($datastores.Count)"
Write-Host "  Snapshots:  $($snapshots.Count)"
Write-Host ""

# Disconnect
Disconnect-VIServer -Server * -Confirm:$false
Write-Host "Disconnected from vCenter." -ForegroundColor Cyan
