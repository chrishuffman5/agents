# Purpose:        Pipeline-run status summary for the last 7 days - failure hotspots and duration profile per pipeline
# Applies to:     Azure Data Factory V2 (Az.DataFactory module; Reader role on the factory suffices)
# Read-only:      yes
# Inputs:         __RESOURCE_GROUP__ and __FACTORY_NAME__
# Prereqs:        Install-Module Az.DataFactory; Connect-AzAccount
# Interpretation: Pipelines with mixed Succeeded/Failed = flaky sources or throttling; 100% failed since a date = a
#                 change that day (linked service credential, schema, firewall). Long durations on copy-heavy pipelines
#                 point at DIU/parallelism settings or source bottlenecks - drill in with 02-failed-activity-runs.ps1.
# Next step:      02-failed-activity-runs.ps1 with a failing __PIPELINE_RUN_ID__ for the actual error

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$rg      = '__RESOURCE_GROUP__'
$factory = '__FACTORY_NAME__'

$runs = Get-AzDataFactoryV2PipelineRun -ResourceGroupName $rg -DataFactoryName $factory `
    -LastUpdatedAfter (Get-Date).AddDays(-7) -LastUpdatedBefore (Get-Date)

$runs |
    Group-Object PipelineName |
    ForEach-Object {
        $g = $_.Group
        [pscustomobject]@{
            Pipeline    = $_.Name
            Runs7d      = $g.Count
            Succeeded   = @($g | Where-Object Status -eq 'Succeeded').Count
            Failed      = @($g | Where-Object Status -eq 'Failed').Count
            InProgress  = @($g | Where-Object Status -eq 'InProgress').Count
            AvgMinutes  = [math]::Round(($g | Where-Object DurationInMs | Measure-Object DurationInMs -Average).Average / 60000, 1)
            LastRun     = ($g | Measure-Object RunStart -Maximum).Maximum
        }
    } |
    Sort-Object Failed -Descending |
    Format-Table -AutoSize
