# Purpose:        Tenant-wide inventory of workspaces with dataset/report counts - the starting map for any governance or capacity review
# Applies to:     Power BI Service (requires Power BI Administrator or Fabric Administrator role)
# Read-only:      yes
# Inputs:         none (interactive login prompt)
# Prereqs:        Install-Module MicrosoftPowerBIMgmt; Connect-PowerBIServiceAccount is called below
# Interpretation: Workspaces with many datasets and no recent activity are cleanup candidates. IsOnDedicatedCapacity
#                 tells you which workspaces ride Premium/Fabric capacity - the ones that matter for capacity planning.
# Next step:      03-dataset-refresh-history.ps1 for the refresh health of the workspaces that matter

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Connect-PowerBIServiceAccount | Out-Null

$workspaces = Get-PowerBIWorkspace -Scope Organization -All -Include All

$workspaces |
    Where-Object { $_.Type -eq 'Workspace' -and $_.State -eq 'Active' } |
    ForEach-Object {
        [pscustomobject]@{
            Workspace             = $_.Name
            Id                    = $_.Id
            OnDedicatedCapacity   = $_.IsOnDedicatedCapacity
            Datasets              = @($_.Datasets).Count
            Reports               = @($_.Reports).Count
            Dashboards            = @($_.Dashboards).Count
            Users                 = @($_.Users).Count
        }
    } |
    Sort-Object Datasets -Descending |
    Format-Table -AutoSize

# Export for records:
# ... | Export-Csv workspace-inventory.csv -NoTypeInformation
