# Purpose:        Query a Premium/Fabric workspace's semantic model over XMLA for table sizes (rows/bytes) - VertiPaq sizing without Desktop
# Applies to:     Power BI Premium / Fabric capacities with the XMLA endpoint enabled (read); PPU also works
# Read-only:      yes
# Inputs:         __WORKSPACE_NAME__ and __DATASET_NAME__ (the semantic model name)
# Prereqs:        Install-Module SqlServer (provides Invoke-ASCmd); account needs Build/Read on the model
# Interpretation: Same DMV as SSAS: USED_SIZE ranks table storage cost. One table dominating = column pruning target.
#                 If the connection fails with "endpoint not enabled", the capacity admin must set XMLA endpoint = Read.
# Next step:      skills/analytics/ssas/scripts/ 01-06 all work against this same endpoint for deeper diagnostics

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$workspace = '__WORKSPACE_NAME__'
$dataset   = '__DATASET_NAME__'

$dmv = @'
SELECT DIMENSION_NAME, TABLE_ID, ROWS_COUNT, USED_SIZE
FROM $SYSTEM.DISCOVER_STORAGE_TABLES
ORDER BY USED_SIZE DESC
'@

[xml]$result = Invoke-ASCmd `
    -Server "powerbi://api.powerbi.com/v1.0/myorg/$workspace" `
    -Database $dataset `
    -Query $dmv

$result.return.root.row |
    Select-Object DIMENSION_NAME, ROWS_COUNT, USED_SIZE |
    Format-Table -AutoSize
