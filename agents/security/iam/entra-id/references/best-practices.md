# Entra ID Best Practices and Hardening

Operational guidance, security hardening, and best practices for Microsoft Entra ID.

---

## Conditional Access Policy Framework

### Baseline Policies (Apply to All Users)

| Policy | Conditions | Controls | Purpose |
|---|---|---|---|
| **Block legacy auth** | All users, all apps, client apps = Exchange ActiveSync + Other clients | Block | Eliminate protocols that cannot do MFA |
| **Require MFA for all** | All users (exclude break-glass), all apps | Grant: MFA | Foundation security policy |
| **Block high-risk sign-ins** | All users, sign-in risk = High | Block | Automated threat response |
| **Require password change for high-risk users** | All users, user risk = High | Grant: password change + MFA | Automated compromise response |
| **Require compliant device for Office 365** | All users, Office 365 apps | Grant: compliant device OR MFA | Device trust for productivity apps |

### Targeted Policies (Specific Scenarios)

| Policy | Conditions | Controls | Purpose |
|---|---|---|---|
| **Require phishing-resistant MFA for admins** | Directory roles (Global Admin, etc.), all apps | Grant: authentication strength (phishing-resistant) | Protect privileged access |
| **Block access from untrusted countries** | All users, excluded locations = allowed countries | Block | Reduce attack surface |
| **Require compliant device for sensitive apps** | All users, specific apps | Grant: compliant device (required, not OR) | Strict access for sensitive data |
| **Session controls for unmanaged devices** | All users, device state != compliant | Session: sign-in frequency = 1 hour, no persistent browser | Limit session on personal devices |
| **Require terms of use for guests** | Guest users, all apps | Grant: terms of use | Legal compliance for B2B |

### CA Policy Design Principles

1. **Name policies descriptively** -- `CA001-BaseProtection-AllUsers-AllApps-RequireMFA`
2. **Use Report-Only first** -- Test for 2-4 weeks before enabling
3. **Check the "What If" tool** -- Simulate policy impact before deployment
4. **Never target "All users" without exclusions** -- Always exclude break-glass accounts
5. **Prefer "Require" over "Block"** -- Requiring MFA is better than blocking; it gives users a path to comply
6. **Use authentication strength** -- Instead of generic MFA, specify which methods are acceptable
7. **Document exclusions** -- Every exclusion is a potential gap. Document why and set review dates.

---

## Emergency Access (Break-Glass) Accounts

### Configuration Requirements

- **At least 2 accounts** -- Survive if one is compromised or locked out
- **Cloud-only** -- Not synced from on-premises (survive AD outage)
- **Excluded from ALL Conditional Access policies** -- Including MFA requirements
- **Strong, unique passwords** -- 24+ characters, stored in physical safe (not digital)
- **Permanent Global Admin role** -- Not eligible via PIM (needs immediate access)
- **No phone number or email for SSPR** -- Prevent social engineering
- **MFA with FIDO2 key** -- Store key in physical safe alongside password

### Monitoring

```kusto
// Azure Monitor / Sentinel KQL query
// Alert on ANY sign-in by break-glass accounts
SigninLogs
| where UserPrincipalName in ("breakglass1@tenant.onmicrosoft.com", "breakglass2@tenant.onmicrosoft.com")
| project TimeGenerated, UserPrincipalName, IPAddress, Location, ResultType, AppDisplayName
```

Every break-glass sign-in should trigger an immediate investigation. These accounts should never be used during normal operations.

---

## PIM Configuration

### Role Settings Best Practices

| Setting | Recommended Value | Rationale |
|---|---|---|
| Maximum activation duration | 4 hours (8 for complex tasks) | Minimize window of elevated access |
| Require MFA on activation | Yes | Verify identity before granting privileges |
| Require justification | Yes | Audit trail for every activation |
| Require approval | Yes (for Global Admin, Privileged Role Admin) | Human verification for highest-impact roles |
| Require ticket info | Yes | Link to change management |
| Eligible assignment duration | 6 months (with access review) | Prevent stale eligible assignments |
| Active assignment duration | Never permanent (except break-glass) | All active assignments should be time-bound |
| Notification on activation | Send to Security Operations | Alert SOC to every privileged role activation |

### Access Reviews for PIM

- Review eligible assignments quarterly
- Reviewer: manager + security team
- Auto-apply results (remove if not approved)
- Send reminders 3 days before review ends

---

## App Registration Security

### Best Practices

1. **Avoid client secrets** -- Use certificates or managed identities instead. Secrets are easily leaked.
2. **Minimum permissions** -- Request only the Graph permissions the app actually needs. Avoid `Directory.ReadWrite.All`.
3. **Prefer delegated over application permissions** -- Delegated permissions act in the user's context (bounded by user's permissions).
4. **Set credential expiration** -- Certificates: 1-2 years. Secrets (if unavoidable): 6 months maximum.
5. **Restrict who can create app registrations** -- Default allows all users to register apps. Restrict to developers/admins.
6. **Admin consent workflow** -- Enable so users can request permissions that require admin consent instead of getting stuck.
7. **Monitor app consent grants** -- Alert on new `oauth2PermissionGrant` for sensitive permissions.

### Application Credential Monitoring

```kusto
// Find apps with expiring credentials
// Microsoft Graph PowerShell
Get-MgApplication -All | ForEach-Object {
    $app = $_
    $app.KeyCredentials + $app.PasswordCredentials | Where-Object {
        $_.EndDateTime -lt (Get-Date).AddDays(30)
    } | ForEach-Object {
        [PSCustomObject]@{
            AppName = $app.DisplayName
            AppId = $app.AppId
            CredentialType = if ($_.SecretText) { "Secret" } else { "Certificate" }
            ExpiryDate = $_.EndDateTime
        }
    }
}
```

---

## B2B Governance

### Cross-Tenant Access Settings

Configure per-organization inbound/outbound policies:
- **Inbound:** Which external users can access your tenant, and under what conditions
- **Outbound:** Which of your users can access external tenants
- **Trust settings:** Whether to trust MFA and device compliance from external tenants

### Guest Lifecycle Management

1. **Access reviews for all guest users** -- Quarterly, reviewed by sponsor
2. **Guest invitation restrictions** -- Restrict who can invite guests (admins only, or specific groups)
3. **Guest access expiration** -- Set expiration on B2B invitations and access packages
4. **Audit guest access** -- Regular review of what resources guests can access
5. **External collaboration settings** -- Configure allowed domains or blocked domains

---

## Monitoring and Alerting

### Critical Sign-In Events

| Event | Alert Priority | Action |
|---|---|---|
| Break-glass account sign-in | Critical (P1) | Immediate investigation |
| Global Admin role activation | High (P2) | Verify with activating user |
| Sign-in from new country for admin | High | Verify legitimacy |
| Multiple failed sign-ins (password spray) | High | Check Identity Protection, block IP |
| Consent grant for high-privilege app | High | Review the application and permissions |
| Conditional Access policy change | Medium | Verify authorized change |
| MFA registration by admin | Medium | Verify admin initiated the change |
| Bulk user creation | Medium | Verify expected provisioning |
| Service principal sign-in failure spike | Medium | Investigate app credential issue or attack |

### Key Logs

| Log | Location | Retention |
|---|---|---|
| Sign-in logs | Entra ID > Monitoring > Sign-in logs | 30 days (free), 30 days (P1/P2), extended via Diagnostic Settings |
| Audit logs | Entra ID > Monitoring > Audit logs | 30 days, extend via export |
| Provisioning logs | Entra ID > Monitoring > Provisioning logs | 30 days |
| Identity Protection | Entra ID > Security > Risky users / Risk detections | 90 days for risk detections |

**Export to SIEM:** Configure Diagnostic Settings to stream logs to Log Analytics, Event Hub, or Storage Account. Integrate with Microsoft Sentinel or third-party SIEM for long-term retention and correlation.

---

## Entra Connect Security

### Hardening the Entra Connect Server

- **Tier 0 asset** -- The Entra Connect server has full sync access to AD AND Entra ID. Treat it as a domain controller.
- **Dedicated server** -- No other applications or roles
- **No internet browsing** -- Only outbound HTTPS to Entra ID endpoints
- **Credential Guard** -- Enable on the Entra Connect server
- **Limit admin access** -- Only Entra Connect admins (separate accounts)
- **Monitor** -- All sign-ins and changes to the sync configuration
- **Update regularly** -- Entra Connect is frequently updated for security fixes

### Entra Connect Accounts

| Account | Purpose | Security |
|---|---|---|
| AD Connector account | Reads/writes AD objects | Least privilege (only required AD permissions), not Domain Admin |
| Entra ID Connector account | Syncs to Entra ID | Auto-created during setup, Global Admin or Hybrid Identity Admin |
| ADSync service account | Runs the sync engine | Local service account or gMSA |

**Never use Domain Admin for the AD Connector account.** Grant only the specific permissions needed (replicate directory changes, password hash sync permissions, etc.).
