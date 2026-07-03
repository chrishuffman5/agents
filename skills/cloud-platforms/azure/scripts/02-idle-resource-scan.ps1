# Purpose:        Sweep a subscription for idle/orphaned resources - unattached disks, stopped-not-deallocated VMs, empty groups
# Applies to:     Azure via Az PowerShell (read-only: Reader on the subscription)
# Read-only:      yes
# Inputs:         __SUBSCRIPTION_ID__
# Prereqs:        Install-Module Az.Compute, Az.Resources; Connect-AzAccount
# Interpretation: Unattached managed disks bill full price for nothing - the #1 Azure waste. VMs in 'stopped' (NOT
#                 'deallocated') state STILL BILL for compute - the classic Azure surprise; they must be deallocated
#                 to stop charges (see the virtualization skill's az vm deallocate note). Empty resource groups are
#                 harmless but signal abandoned projects worth cleaning. Confirm ownership before deleting disks.
# Next step:      Delete unattached disks (snapshot first if unsure); deallocate the stopped VMs; re-run 01 next cycle

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Set-AzContext -Subscription '__SUBSCRIPTION_ID__' | Out-Null

Write-Host "== Unattached managed disks (billing for nothing)"
Get-AzDisk | Where-Object { $_.DiskState -eq 'Unattached' } |
    Select-Object Name, ResourceGroupName, @{n='SizeGB';e={$_.DiskSizeGB}}, @{n='SKU';e={$_.Sku.Name}}, TimeCreated |
    Sort-Object TimeCreated | Format-Table -AutoSize

Write-Host "== VMs stopped but NOT deallocated (STILL BILLING compute)"
Get-AzVM -Status | Where-Object { $_.PowerState -eq 'VM stopped' } |
    Select-Object Name, ResourceGroupName, PowerState | Format-Table -AutoSize

Write-Host "== Empty resource groups"
Get-AzResourceGroup | Where-Object {
    (Get-AzResource -ResourceGroupName $_.ResourceGroupName).Count -eq 0
} | Select-Object ResourceGroupName, Location | Format-Table -AutoSize
