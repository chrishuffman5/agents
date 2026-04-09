<#
.SYNOPSIS
    Windows Server 2025 - Delegated MSA (dMSA) Status
.DESCRIPTION
    Checks Domain Functional Level for dMSA support, enumerates existing
    dMSA accounts, and validates service account health.
.NOTES
    Version : 2025.1.0
    Targets : Windows Server 2025 (DFL 10 required)
    Safety  : Read-only. No modifications to system configuration.
    Sections:
        1. Domain Functional Level Check
        2. dMSA Accounts
        3. gMSA Accounts (Legacy)
        4. Service Account Migration Status
#>
#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
$sep = '=' * 70
Write-Host "`n$sep`n dMSA Status (Server 2025)`n$sep"

Write-Host "`n--- Section 1: Domain Functional Level ---"
try {
    Import-Module ActiveDirectory -EA Stop
    $domain = Get-ADDomain
    Write-Host "Domain: $($domain.DNSRoot)"
    Write-Host "Domain Mode: $($domain.DomainMode)"
    $dflOk = $domain.DomainMode -match '2025|Windows2025'
    Write-Host "DFL 10 (required for dMSA): $(if($dflOk){'Yes'}else{'No -- raise DFL after all DCs are on 2025'})"
    $forest = Get-ADForest
    Write-Host "Forest Mode: $($forest.ForestMode)"
} catch {
    Write-Warning "Active Directory module not available. This server may not be domain-joined or lacks RSAT."
    return
}

Write-Host "`n--- Section 2: dMSA Accounts ---"
try {
    $dmsas = Get-ADServiceAccount -Filter { DelegatedManagedServiceAccount -eq $true } -EA SilentlyContinue
    if ($dmsas) {
        $dmsas | Select-Object Name, DNSHostName, Enabled, WhenCreated | Format-Table -AutoSize
    } else { Write-Host "No dMSA accounts found (DFL 10 required to create)." }
} catch { Write-Host "Cannot query dMSA accounts (may require DFL 10)." }

Write-Host "--- Section 3: gMSA Accounts (Legacy) ---"
try {
    $gmsas = Get-ADServiceAccount -Filter { ObjectClass -eq 'msDS-GroupManagedServiceAccount' } -EA SilentlyContinue
    if ($gmsas) {
        Write-Host "gMSA accounts found (consider migrating to dMSA):"
        $gmsas | Select-Object Name, DNSHostName, Enabled | Format-Table -AutoSize
    } else { Write-Host "No gMSA accounts found." }
} catch { Write-Host "Cannot query gMSA accounts." }

Write-Host "--- Section 4: Service Account Health ---"
try {
    $allMSA = Get-ADServiceAccount -Filter * -EA SilentlyContinue
    if ($allMSA) {
        foreach ($msa in $allMSA) {
            $testResult = Test-ADServiceAccount -Identity $msa.Name -EA SilentlyContinue
            Write-Host "  $($msa.Name): $(if($testResult){'OK'}else{'FAILED -- password retrieval issue'})"
        }
    }
} catch { Write-Host "Cannot test service accounts." }
Write-Host "`n$sep`n dMSA Check Complete`n$sep"
