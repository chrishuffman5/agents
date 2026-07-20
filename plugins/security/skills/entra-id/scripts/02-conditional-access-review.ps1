# Purpose:        Inventory Conditional Access policies with state and MFA-grant coverage - find the gaps attackers use
# Applies to:     Microsoft Entra ID (Microsoft Graph PowerShell; read-only)
# Read-only:      yes
# Inputs:         none (interactive Connect-MgGraph)
# Prereqs:        Install-Module Microsoft.Graph; scope Policy.Read.All
# Interpretation: Policies in 'enabledForReportingButNotEnforced' are NOT protecting anything - report-only is a
#                 staging state, not a control. No enabled policy requiring MFA for all users (or at least admins) is
#                 the #1 gap. Legacy-auth-block absence lets attackers bypass MFA via IMAP/POP/SMTP. Broad exclusions
#                 (whole groups, 'all guests') quietly gut a policy - enumerate them. A break-glass account excluded
#                 from MFA is correct IF it is monitored and alerting.
# Next step:      Enforce report-only policies that test clean; block legacy auth; verify break-glass exclusions are alerted

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Connect-MgGraph -Scopes 'Policy.Read.All' -NoWelcome

Get-MgIdentityConditionalAccessPolicy -All | ForEach-Object {
    $grants = $_.GrantControls.BuiltInControls -join ','
    [pscustomobject]@{
        Policy       = $_.DisplayName
        State        = $_.State
        RequiresMfa  = ($grants -match 'mfa')
        Grants       = $grants
        UsersInclude = ($_.Conditions.Users.IncludeUsers -join ',')
        UsersExclude = ($_.Conditions.Users.ExcludeUsers.Count)
        Apps         = ($_.Conditions.Applications.IncludeApplications -join ',')
    }
} | Sort-Object State, Policy | Format-Table -AutoSize -Wrap

Write-Host "`nReminder: 'enabledForReportingButNotEnforced' policies enforce NOTHING - they are report-only."
