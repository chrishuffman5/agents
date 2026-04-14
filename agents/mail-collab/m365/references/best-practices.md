# Microsoft 365 Best Practices

## Tenant Setup Checklist

### Day 1 -- Foundation

- [ ] Verify and add all custom domains
- [ ] Configure SPF, DKIM, and DMARC DNS records for each mail domain
- [ ] Set up at least two break-glass Global Admin accounts: cloud-only, long random passwords, no MFA (or hardware FIDO2 key), excluded from all CA policies
- [ ] Enable Microsoft Authenticator (or FIDO2) as authentication methods; disable SMS OTP as primary
- [ ] Deploy Conditional Access policies (see below) or enable Security Defaults (if no P1)
- [ ] Block legacy authentication (IMAP, POP3, SMTP AUTH) via CA policy
- [ ] Configure admin roles with least-privilege; use PIM for Global Admin (P2)

### Day 1 -- Email Security

- [ ] Enable DKIM signing for all custom domains (Exchange Admin Center > Email Authentication)
- [ ] Configure DMARC policy (`p=quarantine` initially, move to `p=reject`)
- [ ] Apply Standard or Strict preset security policies (anti-spam, anti-phishing, anti-malware)
- [ ] Enable Safe Attachments and Safe Links (if licensed)

### Day 30 -- Governance

- [ ] Configure M365 Group creation policy (restrict to IT or designated groups)
- [ ] Configure Teams external access and guest access policies
- [ ] Configure SharePoint external sharing policy
- [ ] Set up sensitivity labels hierarchy and publish to users
- [ ] Create baseline DLP policy for common sensitive information types
- [ ] Configure retention policies for regulatory compliance

### Day 90 -- Monitoring

- [ ] Subscribe Message Center to email digest for admins
- [ ] Configure Service Health alerts to email/Teams webhook
- [ ] Set up Secure Score baseline and improvement tracking
- [ ] Verify Unified Audit Log is enabled
- [ ] Configure Entra ID Connect Health (if hybrid)

---

## Security Hardening

### Conditional Access Policies

**Essential policies (Entra P1+):**

1. **Require MFA for all administrators:**
```powershell
# Include: Directory roles (Global Admin, User Admin, etc.)
# Grant: Require MFA
```

2. **Require MFA for all users:**
```powershell
$policy = @{
    displayName = "Require MFA for All Users"
    state = "enabled"
    conditions = @{
        users = @{ includeUsers = @("All"); excludeUsers = @("break-glass-1-id","break-glass-2-id") }
        applications = @{ includeApplications = @("All") }
    }
    grantControls = @{ operator = "OR"; builtInControls = @("mfa") }
}
New-MgIdentityConditionalAccessPolicy -BodyParameter $policy
```

3. **Block legacy authentication:**
```powershell
# Conditions: Client apps = Exchange ActiveSync, Other clients
# Grant: Block access
```

4. **Require compliant device for corporate apps:**
```powershell
# Conditions: Cloud apps = Office 365
# Grant: Require device to be marked as compliant
```

5. **Block access from high-risk countries:**
```powershell
# Create Named Location with blocked countries
# Conditions: Locations = selected named location
# Grant: Block access
```

### Break-Glass Accounts

- Minimum two cloud-only Global Admin accounts
- Not synced from on-prem AD
- Long random passwords (20+ characters), stored securely offline
- Excluded from ALL Conditional Access policies
- No phone number (prevents SIM swap attacks on recovery)
- Hardware FIDO2 key or no MFA (emergency access)
- Monitor sign-in activity with alerts

### PIM Configuration (P2)

- Zero standing privilege for Global Administrator
- Require approval for Global Admin activation
- Maximum activation: 1-4 hours for highly privileged roles
- Require justification and MFA for activation
- Monthly access reviews for Privileged Role Administrator

### Security Defaults vs. Conditional Access

| Aspect | Security Defaults | Conditional Access |
|---|---|---|
| License | Free | Entra P1+ |
| MFA | All users/admins | Configurable per user/group/app |
| Legacy auth | Blocked | Configurable |
| Customization | None | Full |
| Break-glass exclusions | No | Yes |
| Risk-based | No | Yes (P2) |

**Recommendation:** Conditional Access for any org with P1 (Business Premium, E3+). Security Defaults only for orgs without P1.

---

## Compliance Configuration

### Sensitivity Labels

**Label taxonomy example:**
```
Public
Internal
  Internal > General
  Internal > HR
Confidential
  Confidential > All Employees
  Confidential > Finance Only
Highly Confidential
  Highly Confidential > C-Suite Only
```

**Label actions:** Encryption (AIP/OME), content marking (headers/footers/watermarks), auto-labeling, container labeling (Teams, SharePoint), meeting labeling.

```powershell
Connect-IPPSSession -UserPrincipalName admin@contoso.com

# Create label
New-Label -Name "Confidential-Finance" -DisplayName "Confidential - Finance" `
    -Tooltip "Finance team only" -EncryptionEnabled $true -EncryptionProtectionType Template

# Get all labels
Get-Label | Select DisplayName, Priority, ContentType
```

### DLP Policies

```powershell
# Create DLP policy for PCI-DSS
New-DlpCompliancePolicy -Name "PCI-DSS Protection" -ExchangeLocation All -SharePointLocation All -Mode Enable
New-DlpComplianceRule -Name "Credit Card Rule" -Policy "PCI-DSS Protection" `
    -ContentContainsSensitiveInformation @(@{Name="Credit Card Number"; minCount=1}) `
    -BlockAccess $true -NotifyUser "SiteAdmin","LastModifier"
```

**False positive management:**
- Use confidence levels (medium vs. high)
- Combine patterns: SSN + proximity to "social security" keyword
- User override with justification and audit trail

### Retention Policies

```powershell
# Create 7-year retention
New-RetentionCompliancePolicy -Name "7-Year Financial Records" -ExchangeLocation All -SharePointLocation All
New-RetentionComplianceRule -Name "7-Year Rule" -Policy "7-Year Financial Records" `
    -RetentionDuration 2556 -RetentionComplianceAction Keep
```

**Retention priority rules:**
1. Retention preventing deletion overrides retention allowing deletion
2. Longer retention wins over shorter
3. Explicit item-level label wins over location-level policy

### eDiscovery

```powershell
# Standard eDiscovery
New-ComplianceCase -Name "Investigation-2026-001"
New-ComplianceSearch -Name "HR Search" -ExchangeLocation "user@contoso.com" `
    -ContentMatchQuery "keyword1 OR keyword2" -Case "Investigation-2026-001"
Start-ComplianceSearch -Identity "HR Search"

# Premium eDiscovery (E5)
New-ComplianceCase -Name "Litigation-2026-001" -CaseType AdvancedEdiscovery
```

### Audit Logging

```powershell
# Verify audit is enabled
Get-AdminAuditLogConfig | Select UnifiedAuditLogIngestionEnabled

# Search audit log
Search-UnifiedAuditLog -StartDate (Get-Date).AddDays(-7) -EndDate (Get-Date) `
    -RecordType ExchangeItem -Operations "MailItemsAccessed" -ResultSize 5000
```

**Standard Audit (E1/E3):** 180-day retention
**Premium Audit (E5):** 1-year default (extendable to 10 years), high-value events (MailItemsAccessed, Send)

---

## Backup Strategy

Microsoft 365 is NOT a backup solution. Native capabilities protect against accidental deletion but not ransomware, admin error, or mass deletion.

**Native capabilities:**
- SharePoint/OneDrive: 93-day recycle bin
- Exchange: Deleted items 14-30 days, Recoverable Items 14-30 days
- Litigation Hold: Extends preservation indefinitely

**Microsoft 365 Backup (native, GA):** Point-in-time restore for 30-day window. SharePoint, OneDrive, Exchange. Pay per GB/month.

**Third-party backup (recommended):**
- Veeam Backup for Microsoft 365
- Acronis Cyber Protect Cloud
- Druva inSync
- Commvault Cloud

**Best practice:**
- Third-party backup for Exchange, SharePoint, OneDrive, Teams
- Daily backup minimum; test restore monthly
- Store backup data outside the M365 tenant
- Include Entra ID config export (use `Microsoft365DSC` for drift detection)

---

## Monitoring and Change Management

### Service Health

```powershell
Connect-MgGraph -Scopes "ServiceHealth.Read.All"
Get-MgServiceAnnouncementHealthOverview | Select Service, Status
Get-MgServiceAnnouncementIssue -Filter "status ne 'resolved'" | Select Title, Service, Status
```

**First response:** Check `admin.microsoft.com > Health > Service health`, then `status.cloud.microsoft`, then `@MSFT365Status` on X.

### Message Center

Subscribe to weekly digest. Route to Teams/Slack via `Get-MgServiceAnnouncementMessage`.

### Secure Score

Baseline at deployment. Review monthly. Track improvement actions. Available at `security.microsoft.com > Secure Score`.

### Configuration Drift

Use `Microsoft365DSC` PowerShell module:
- Export current tenant configuration as code
- Detect drift from desired state
- Apply configuration as Infrastructure as Code
