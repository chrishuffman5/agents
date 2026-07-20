# Purpose:        Azure month-to-date cost by service plus Advisor cost recommendations - the FinOps opener for Azure
# Applies to:     Azure via Az PowerShell (read-only: Cost Management Reader / Reader on the scope)
# Read-only:      yes
# Inputs:         __SUBSCRIPTION_ID__
# Prereqs:        Install-Module Az.CostManagement, Az.Advisor; Connect-AzAccount
# Interpretation: Top services by MTD cost are the optimization targets. Advisor's Cost category recommendations are
#                 Azure telling you directly where the waste is - right-size/shutdown recommendations on VMs, and
#                 Reserved Instance / Savings Plan suggestions for steady compute. Treat RI/SP suggestions as leads
#                 needing break-even math, not auto-buys. Idle resources Advisor flags are the delete-waste lever.
# Next step:      02-idle-resource-scan.ps1 for a direct idle sweep; act on Advisor shutdown/right-size items first

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$sub = '__SUBSCRIPTION_ID__'
Set-AzContext -Subscription $sub | Out-Null

$start = (Get-Date -Day 1).ToString('yyyy-MM-dd')
$end   = (Get-Date).ToString('yyyy-MM-dd')

Write-Host "== Month-to-date cost by service ($start .. $end)"
try {
    $q = @{ Type='Usage'; Timeframe='Custom'; TimePeriod=@{ From=$start; To=$end }
            Dataset=@{ Granularity='None'; Aggregation=@{ totalCost=@{ name='Cost'; function='Sum' } }
            Grouping=@(@{ type='Dimension'; name='ServiceName' }) } }
    Invoke-AzCostManagementQuery -Scope "/subscriptions/$sub" -Definition $q |
        Select-Object -ExpandProperty Row |
        Sort-Object { $_[0] } -Descending | Select-Object -First 15 |
        ForEach-Object { '{0,-45} {1:C2}' -f $_[1], $_[0] }
} catch { Write-Warning "Cost query needs Cost Management Reader: $_" }

Write-Host "`n== Advisor cost recommendations"
Get-AzAdvisorRecommendation -Category Cost 2>$null |
    Select-Object @{n='Impact';e={$_.Impact}}, @{n='Problem';e={$_.ShortDescriptionProblem}} |
    Sort-Object Impact | Format-Table -AutoSize -Wrap
