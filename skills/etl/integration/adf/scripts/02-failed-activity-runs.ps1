# Purpose:        Activity-level errors for a failed pipeline run - the actual failing activity and its error message
# Applies to:     Azure Data Factory V2 (Az.DataFactory module)
# Read-only:      yes
# Inputs:         __RESOURCE_GROUP__, __FACTORY_NAME__, __PIPELINE_RUN_ID__ (from 01-pipeline-runs-summary.ps1 or the ADF monitor)
# Prereqs:        Install-Module Az.DataFactory; Connect-AzAccount
# Interpretation: The first failed activity is the root cause; downstream failures are cascade. Error codes:
#                 2200-series = source/sink data or connectivity (check linked service + firewall); UserErrorThrottled /
#                 429 = capacity throttling (stagger triggers, raise limits); timeout on Copy = raise DIUs or fix the
#                 source query. Self-hosted IR errors name the IR node - check its health next.
# Next step:      Fix the named cause; 03-trigger-status.ps1 to confirm schedules are still active after incidents

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$rg      = '__RESOURCE_GROUP__'
$factory = '__FACTORY_NAME__'
$runId   = '__PIPELINE_RUN_ID__'

$run = Get-AzDataFactoryV2PipelineRun -ResourceGroupName $rg -DataFactoryName $factory -PipelineRunId $runId

Get-AzDataFactoryV2ActivityRun -ResourceGroupName $rg -DataFactoryName $factory `
    -PipelineRunId $runId `
    -RunStartedAfter $run.RunStart.AddMinutes(-5) -RunStartedBefore (Get-Date) |
    Sort-Object ActivityRunStart |
    ForEach-Object {
        [pscustomobject]@{
            Activity  = $_.ActivityName
            Type      = $_.ActivityType
            Status    = $_.Status
            Start     = $_.ActivityRunStart
            Minutes   = if ($_.DurationInMs) { [math]::Round($_.DurationInMs / 60000, 1) } else { $null }
            Error     = if ($_.Error) { ($_.Error | ConvertTo-Json -Compress -Depth 3).Substring(0, [Math]::Min(300, ($_.Error | ConvertTo-Json -Compress -Depth 3).Length)) } else { '' }
        }
    } |
    Format-Table -Wrap
