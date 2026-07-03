# Purpose:        Find stale guest accounts and risky app credential expiry - the identity-hygiene sweep
# Applies to:     Microsoft Entra ID (Microsoft Graph PowerShell; read-only)
# Read-only:      yes
# Inputs:         none (interactive Connect-MgGraph)
# Prereqs:        Install-Module Microsoft.Graph; scopes User.Read.All, Application.Read.All, AuditLog.Read.All
# Interpretation: Guests who never signed in or are dormant 90+ days are dead access paths - remove them (access
#                 reviews should automate this). App registrations with secrets/certs expiring soon cause outages;
#                 those with NO expiry (or 2-year secrets) are the credential-theft prize - prefer certificates or
#                 workload identity federation. Apps with expired creds still present are leftover risk.
# Next step:      Trigger access reviews for stale guests; rotate expiring app creds to certs/federated identity

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Connect-MgGraph -Scopes 'User.Read.All','Application.Read.All','AuditLog.Read.All' -NoWelcome

Write-Host "== Stale guests (no sign-in in 90+ days or never)"
$cutoff = (Get-Date).AddDays(-90)
Get-MgUser -Filter "userType eq 'Guest'" -All -Property DisplayName,UserPrincipalName,SignInActivity,CreatedDateTime |
    Where-Object { -not $_.SignInActivity -or $_.SignInActivity.LastSignInDateTime -lt $cutoff } |
    Select-Object UserPrincipalName, CreatedDateTime, @{n='LastSignIn';e={$_.SignInActivity.LastSignInDateTime}} |
    Sort-Object LastSignIn | Format-Table -AutoSize

Write-Host "== App credentials expiring within 30 days or already expired"
$soon = (Get-Date).AddDays(30)
Get-MgApplication -All -Property DisplayName,PasswordCredentials,KeyCredentials | ForEach-Object {
    $app = $_.DisplayName
    @($_.PasswordCredentials) + @($_.KeyCredentials) | Where-Object { $_ -and $_.EndDateTime -lt $soon } | ForEach-Object {
        [pscustomobject]@{ App = $app; Type = $_.GetType().Name -replace 'MicrosoftGraph','' ; Expires = $_.EndDateTime }
    }
} | Sort-Object Expires | Format-Table -AutoSize
