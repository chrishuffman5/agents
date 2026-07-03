# Purpose:        Enumerate members of the tier-0 Active Directory privileged groups - the on-prem crown jewels
# Applies to:     Active Directory Domain Services (RSAT ActiveDirectory module; read-only)
# Read-only:      yes
# Inputs:         none (uses the current domain; add -Server __DC__ for a specific DC)
# Prereqs:        RSAT ActiveDirectory module; a read-capable domain account
# Interpretation: Domain Admins / Enterprise Admins / Schema Admins should be nearly empty (named break-glass only) -
#                 day-to-day admin belongs in delegated, tiered roles. Recursive membership matters: a nested group
#                 can smuggle members in (this uses -Recursive). Enabled service accounts in these groups are a
#                 lateral-movement dream (Kerberoasting a DA-privileged SPN = game over). Stale/disabled members still
#                 count as attack surface until removed.
# Next step:      02-kerberoast-exposure.ps1 for SPN-bearing privileged accounts; empty these groups to break-glass-only

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory

$tier0 = 'Domain Admins','Enterprise Admins','Schema Admins','Administrators','Account Operators','Backup Operators'

foreach ($g in $tier0) {
    try {
        $members = Get-ADGroupMember -Identity $g -Recursive -ErrorAction Stop
        Write-Host "== $g ($($members.Count) recursive members)"
        $members | ForEach-Object {
            $obj = Get-ADObject $_ -Properties objectClass, userAccountControl -ErrorAction SilentlyContinue
            [pscustomobject]@{
                Name    = $_.SamAccountName
                Class   = $_.objectClass
                Enabled = if ($obj.objectClass -eq 'user') { -not [bool]($obj.userAccountControl -band 2) } else { 'n/a' }
            }
        } | Format-Table -AutoSize
    } catch { Write-Host "== $g : not found in this domain" }
}
