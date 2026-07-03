# Purpose:        Enumerate members of high-privilege Entra directory roles - the standing-privilege attack surface
# Applies to:     Microsoft Entra ID (Microsoft Graph PowerShell; read-only scopes)
# Read-only:      yes (only Get-* / directory read scopes)
# Inputs:         none (interactive Connect-MgGraph)
# Prereqs:        Install-Module Microsoft.Graph; scopes RoleManagement.Read.Directory, Directory.Read.All
# Interpretation: Global Administrator count above ~2-4 is a finding - Microsoft's own guidance is fewer than 5.
#                 Permanent (non-PIM-eligible) assignments to Global Admin / Privileged Role Admin / Application Admin
#                 are the highest-value targets; those roles should be PIM-eligible + MFA-gated, activated just in time.
#                 Guest (#EXT#) or unlicensed service accounts in privileged roles are immediate review items.
# Next step:      02-conditional-access-review.ps1 to confirm these admins are MFA-gated; move standing assignments to PIM-eligible

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Connect-MgGraph -Scopes 'RoleManagement.Read.Directory','Directory.Read.All' -NoWelcome

$privileged = 'Global Administrator','Privileged Role Administrator','Privileged Authentication Administrator',
              'Security Administrator','Application Administrator','Cloud Application Administrator',
              'User Administrator','Exchange Administrator','SharePoint Administrator'

Get-MgDirectoryRole -All | Where-Object { $_.DisplayName -in $privileged } | ForEach-Object {
    $role = $_.DisplayName
    Get-MgDirectoryRoleMember -DirectoryRoleId $_.Id -All | ForEach-Object {
        $u = $null
        try { $u = Get-MgUser -UserId $_.Id -Property DisplayName,UserPrincipalName,AccountEnabled -ErrorAction Stop } catch {}
        [pscustomobject]@{
            Role    = $role
            Member  = if ($u) { $u.UserPrincipalName } else { $_.Id }
            Enabled = if ($u) { $u.AccountEnabled } else { 'n/a (non-user principal)' }
            Guest   = if ($u) { $u.UserPrincipalName -like '*#EXT#*' } else { '' }
        }
    }
} | Sort-Object Role, Member | Format-Table -AutoSize
