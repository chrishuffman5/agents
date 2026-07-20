# Purpose:        Refresh history for a dataset (status, duration, failure detail) - first stop for "my data is stale" tickets
# Applies to:     Power BI Service datasets with scheduled/API refresh (member access to the workspace, or admin)
# Read-only:      yes
# Inputs:         __WORKSPACE_ID__ and __DATASET_ID__ (find both via 01-workspace-inventory.ps1 or the dataset URL)
# Prereqs:        Install-Module MicrosoftPowerBIMgmt; Connect-PowerBIServiceAccount
# Interpretation: status Failed with serviceExceptionJson naming credentials = expired data source auth; gateway errors
#                 name the gateway - check it with the gateway admin. Durations trending up toward the capacity's
#                 refresh timeout (2h shared / 5h Premium) predict imminent timeout failures - consider incremental refresh.
# Next step:      Fix the named cause; for chronic slowness see references/diagnostics.md refresh section

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$workspaceId = '__WORKSPACE_ID__'
$datasetId   = '__DATASET_ID__'

Connect-PowerBIServiceAccount | Out-Null

$resp = Invoke-PowerBIRestMethod -Method Get `
    -Url "groups/$workspaceId/datasets/$datasetId/refreshes?`$top=50" | ConvertFrom-Json

$resp.value |
    ForEach-Object {
        [pscustomobject]@{
            StartTime  = $_.startTime
            EndTime    = $_.endTime
            Minutes    = if ($_.endTime) { [math]::Round(([datetime]$_.endTime - [datetime]$_.startTime).TotalMinutes, 1) } else { $null }
            Type       = $_.refreshType
            Status     = $_.status
            Error      = if ($_.serviceExceptionJson) { ($_.serviceExceptionJson | ConvertFrom-Json).errorCode } else { '' }
        }
    } |
    Format-Table -AutoSize
