# Purpose:        Find Kerberoastable and AS-REP-roastable accounts, weighted by privilege - the credential-attack surface
# Applies to:     Active Directory Domain Services (RSAT ActiveDirectory module; read-only)
# Read-only:      yes (queries only; requests no service tickets)
# Inputs:         none
# Prereqs:        RSAT ActiveDirectory module; a read-capable domain account
# Interpretation: User accounts with an SPN (result set 1) can be Kerberoasted - an attacker requests a service ticket
#                 and cracks it offline for the account's password. Privileged SPN-bearers are critical; the fix is a
#                 30+ char managed password (gMSA) or removing the SPN. Accounts with "do not require Kerberos
#                 preauth" (result set 2) are AS-REP-roastable - crackable WITHOUT any authentication; there is almost
#                 never a legitimate reason, clear the flag. Old pwdLastSet on these = weaker, longer-lived crack target.
# Next step:      Convert privileged SPN accounts to gMSA; clear DONT_REQ_PREAUTH; enforce long passwords on the rest

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory

Write-Host "== Kerberoastable (user accounts with SPNs)"
Get-ADUser -Filter { ServicePrincipalName -like '*' } -Properties ServicePrincipalName, MemberOf, PasswordLastSet, adminCount |
    Select-Object SamAccountName,
        @{n='Privileged';e={[bool]$_.adminCount}},
        PasswordLastSet,
        @{n='SPNs';e={($_.ServicePrincipalName | Select-Object -First 3) -join '; '}} |
    Sort-Object Privileged -Descending | Format-Table -AutoSize

Write-Host "== AS-REP roastable (Kerberos pre-auth NOT required)"
Get-ADUser -Filter 'DoesNotRequirePreAuth -eq $true' -Properties DoesNotRequirePreAuth, adminCount, PasswordLastSet |
    Select-Object SamAccountName, @{n='Privileged';e={[bool]$_.adminCount}}, PasswordLastSet |
    Format-Table -AutoSize
