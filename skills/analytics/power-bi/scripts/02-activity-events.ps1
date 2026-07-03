# Purpose:        Pull tenant activity events for one day (views, edits, exports, shares) for usage auditing and incident forensics
# Applies to:     Power BI Service (requires Power BI Administrator role; activity log retains 30 days)
# Read-only:      yes
# Inputs:         __DATE__ - the day to audit, yyyy-MM-dd
# Prereqs:        Install-Module MicrosoftPowerBIMgmt; Connect-PowerBIServiceAccount
# Interpretation: Filter Activity values of interest: ViewReport (usage), ExportReport / ExportArtifact (data egress),
#                 ShareReport / AddGroupMembers (access changes), DeleteReport (destructive). A spike in exports by a
#                 single UserId is a data-exfiltration review trigger.
# Next step:      Pipe suspicious users/artifacts into a scoped review; schedule this daily into a log store for >30d retention

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$day = '__DATE__'   # e.g. 2026-07-01

Connect-PowerBIServiceAccount | Out-Null

$events = Get-PowerBIActivityEvent `
    -StartDateTime "${day}T00:00:00" `
    -EndDateTime   "${day}T23:59:59" | ConvertFrom-Json

$events |
    Group-Object Activity |
    Sort-Object Count -Descending |
    Select-Object Count, Name |
    Format-Table -AutoSize

# Detail view of the sensitive ones:
$events |
    Where-Object { $_.Activity -in 'ExportReport','ExportArtifact','ShareReport','DeleteReport' } |
    Select-Object CreationTime, Activity, UserId, ItemName, WorkspaceName |
    Sort-Object CreationTime |
    Format-Table -AutoSize
