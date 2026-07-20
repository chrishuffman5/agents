# Purpose:        Exchange Online mail-flow and auth posture audit - connectors, transport rules, and SPF/DKIM/DMARC health
# Applies to:     Microsoft 365 / Exchange Online (Exchange Online PowerShell V3; read-only cmdlets)
# Read-only:      yes (only Get-* cmdlets)
# Inputs:         none (Connect-ExchangeOnline interactive)
# Prereqs:        Install-Module ExchangeOnlineManagement; a role with view access (View-Only Recipients / Global Reader)
# Interpretation: Inbound connectors from unexpected sources = mail-flow tampering or shadow integrations. Transport
#                 rules that BCC/redirect externally, or 'set SCL -1' (bypass spam) broadly, are exfiltration/abuse
#                 risks - review each. DKIM not enabled per accepted domain = weaker deliverability and DMARC
#                 alignment. This is the standing-config review; message trace (not shown - it's per-incident) is the
#                 live-flow tool.
# Next step:      Disable unrecognized connectors/rules; enable DKIM on domains lacking it; verify DMARC record externally

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Connect-ExchangeOnline -ShowBanner:$false

Write-Host "== Inbound connectors"
Get-InboundConnector | Select-Object Name, Enabled, ConnectorType, SenderDomains, SenderIPAddresses | Format-Table -AutoSize -Wrap

Write-Host "== Transport rules that redirect/bcc externally or bypass spam"
Get-TransportRule | Where-Object {
    $_.BlindCopyTo -or $_.RedirectMessageTo -or $_.SetSCL -eq '-1' -or $_.AddToRecipients
} | Select-Object Name, State, Priority, BlindCopyTo, RedirectMessageTo, SetSCL | Format-Table -AutoSize -Wrap

Write-Host "== DKIM signing per domain"
Get-DkimSigningConfig | Select-Object Domain, Enabled, Status | Format-Table -AutoSize

Write-Host "== Accepted domains (verify DMARC in external DNS for each)"
Get-AcceptedDomain | Select-Object DomainName, DomainType, Default | Format-Table -AutoSize
