# Purpose:        Audit all triggers' runtime state - stopped triggers are the silent cause of "the data just stopped updating"
# Applies to:     Azure Data Factory V2 (Az.DataFactory module)
# Read-only:      yes
# Inputs:         __RESOURCE_GROUP__ and __FACTORY_NAME__
# Prereqs:        Install-Module Az.DataFactory; Connect-AzAccount
# Interpretation: RuntimeState Stopped on a production schedule/tumbling-window trigger means nothing runs and nothing
#                 alerts - the most common post-deployment mistake (CI/CD deploys triggers in Stopped state unless the
#                 pipeline explicitly starts them). Tumbling-window triggers in Stopped state also accumulate backfill
#                 debt: starting them re-runs missed windows - plan for that load.
# Next step:      Start intended triggers (Start-AzDataFactoryV2Trigger); add trigger-state checks to the deployment pipeline

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$rg      = '__RESOURCE_GROUP__'
$factory = '__FACTORY_NAME__'

Get-AzDataFactoryV2Trigger -ResourceGroupName $rg -DataFactoryName $factory |
    ForEach-Object {
        [pscustomobject]@{
            Trigger      = $_.Name
            Type         = $_.Properties.GetType().Name
            RuntimeState = $_.RuntimeState
            Pipelines    = ($_.Properties.Pipelines.PipelineReference.ReferenceName -join ', ')
        }
    } |
    Sort-Object RuntimeState, Trigger |
    Format-Table -AutoSize
