# Microsoft 365 Diagnostics

## Sign-In Failures

### Diagnostic Approach

1. Check Entra ID sign-in logs: `entra.microsoft.com > Monitoring > Sign-in logs`
2. Filter by user, application, status, Conditional Access result
3. Look at the **Failure reason** and **Error code** columns

```powershell
# Get sign-in failures for a user
Connect-MgGraph -Scopes "AuditLog.Read.All"
Get-MgAuditLogSignIn -Filter "userPrincipalName eq 'user@contoso.com' and status/errorCode ne 0" -Top 20 | Select CreatedDateTime, AppDisplayName, Status, ConditionalAccessStatus
```

### Common Sign-In Errors

| Error Code | Message | Common Fix |
|---|---|---|
| `AADSTS50126` | Invalid username or password | Reset password, check UPN matches |
| `AADSTS50076` | MFA required but not completed | User must complete MFA enrollment |
| `AADSTS53003` | Blocked by Conditional Access | Review CA policy; check user/device/location against policy conditions |
| `AADSTS50105` | User not assigned to application | Assign user to the enterprise app |
| `AADSTS700016` | Application not found in tenant | Verify app registration exists |
| `AADSTS50058` | Silent sign-in failed | User must sign in interactively |
| `AADSTS50140` | Keep Me Signed In (KMSI) interrupted | User must re-authenticate |
| `AADSTS90072` | External tenant not allowed | Check external collaboration settings |

### Conditional Access Debugging

```powershell
# Check which CA policies applied to a sign-in
Get-MgAuditLogSignIn -Filter "userPrincipalName eq 'user@contoso.com'" -Top 1 | Select -ExpandProperty ConditionalAccessPolicies | Select DisplayName, Result

# Result values:
# Success -- Policy conditions met, controls satisfied
# Failure -- Policy conditions met, controls NOT satisfied (access blocked)
# NotApplied -- Policy conditions did not match
```

**Common CA issues:**
- User excluded from policy but should be included (check group membership)
- Legacy auth client not caught by "block legacy auth" policy (verify client apps condition)
- Named location not matching (verify IP ranges in named location definition)
- Device compliance check failing (verify Intune enrollment and compliance status)

### MFA Troubleshooting

```powershell
# Check user's registered auth methods
Get-MgUserAuthenticationMethod -UserId "user@contoso.com" | Select @{N='Method';E={$_.AdditionalProperties.'@odata.type'}}

# Check if user is registered for MFA
Get-MgReportAuthenticationMethodUserRegistrationDetail -Filter "userPrincipalName eq 'user@contoso.com'" | Select MethodsRegistered, IsMfaRegistered
```

**Common MFA issues:**
- User not registered (provide TAP for initial enrollment)
- Authenticator app not receiving push (check phone connectivity, reinstall app)
- FIDO2 key not working (verify browser support, USB/NFC connectivity)

---

## License Assignment Issues

### License Assignment Failures

```powershell
# Check license assignment errors
Get-MgUser -UserId "user@contoso.com" -Property AssignedLicenses, LicenseAssignmentStates | Select -ExpandProperty LicenseAssignmentStates

# Common errors:
# MutuallyExclusiveViolation -- Conflicting license plans assigned (e.g., E3 + standalone Exchange Plan 1)
# CountViolation -- No available licenses in the subscription
# DependencyViolation -- Required service plan disabled or missing prerequisite license
```

**Fixing MutuallyExclusiveViolation:**
```powershell
# Remove conflicting license, then assign correct one
Set-MgUserLicense -UserId "user@contoso.com" -RemoveLicenses @("conflicting-sku-id") -AddLicenses @(@{SkuId="correct-sku-id"})
```

### Group-Based Licensing Errors

Navigate to: Entra ID > Groups > [group] > Licenses > Error tab

| Error | Meaning | Fix |
|---|---|---|
| `CountViolation` | Not enough licenses | Purchase more or remove unlicensed users |
| `MutuallyExclusiveViolation` | User has conflicting direct assignment | Remove direct license assignment |
| `DependencyViolation` | Disabled sub-service is required by another | Enable required service plan |
| `ProhibitedInUsageLocationViolation` | Service not available in user's UsageLocation | Set valid UsageLocation |

```powershell
# Check users with license processing errors in a group
Get-MgGroupMemberWithLicenseError -GroupId $groupId | Select Id, DisplayName
```

---

## Entra ID Connect Sync Issues

### Sync Not Running

```powershell
# Check scheduler (on Entra Connect server)
Import-Module ADSync
Get-ADSyncScheduler

# If SyncCycleEnabled is False:
Set-ADSyncScheduler -SyncCycleEnabled $true

# Force delta sync
Start-ADSyncSyncCycle -PolicyType Delta
```

### Common Sync Errors

| Error | Cause | Fix |
|---|---|---|
| `AttributeValueMustBeUnique` | Duplicate proxyAddress or UPN | Remove duplicate in AD or exclude conflicting object |
| `InvalidSoftMatch` | Object cannot be matched between AD and Entra | Verify immutableId / sourceAnchor matches |
| `DataValidationFailed` | Invalid characters in attribute | Clean attribute value in AD |
| `LargeObject` | Object exceeds attribute size limits | Reduce group membership or proxy addresses |
| `FederatedDomainChangeError` | UPN domain changed to federated domain | Update UPN in AD before sync |

```powershell
# Check connector space for errors
Get-ADSyncConnectorRunStatus

# View specific object sync status
Search-ADSyncConnectorSpace -ConnectorName "contoso.com" -Filter {cn -eq "user"}
```

### Password Hash Sync Issues

```powershell
# Check PHS status
Get-ADSyncAADPasswordSyncConfiguration -SourceConnector "contoso.com"

# If not syncing, restart PHS
Set-ADSyncAADPasswordSyncConfiguration -SourceConnector "contoso.com" -TargetConnector "your-tenant.onmicrosoft.com - AAD" -Enable $true
```

---

## Service Health Troubleshooting

### First Response Protocol

1. Check `admin.microsoft.com > Health > Service health` for active incidents
2. Check `https://status.cloud.microsoft` (public status page)
3. Check `@MSFT365Status` on X for real-time updates
4. If no known issue, proceed with tenant-specific troubleshooting

### Exchange Online Issues

```powershell
# Message trace (last 10 days)
Get-MessageTrace -SenderAddress sender@contoso.com -RecipientAddress recipient@contoso.com `
    -StartDate (Get-Date).AddDays(-2) -EndDate (Get-Date)

# Check mail flow rules affecting delivery
Get-TransportRule | Where {$_.State -eq "Enabled"} | Select Name, Priority, Conditions, Actions

# Check connectors
Get-InboundConnector | Select Name, Enabled, SenderDomains, RequireTls
Get-OutboundConnector | Select Name, Enabled, RecipientDomains, SmartHosts
```

### SharePoint/OneDrive Issues

```powershell
Connect-SPOService -Url https://contoso-admin.sharepoint.com

# Check site health
Get-SPOSite -Identity "https://contoso.sharepoint.com/sites/Problem" | Select Status, SharingCapability, StorageUsageCurrent

# Check tenant sharing settings
Get-SPOTenant | Select SharingCapability, ExternalUserExpireInDays
```

### Teams Issues

Common troubleshooting areas:
- **Meeting quality:** Teams Admin Center > Analytics & reports > Call quality dashboard
- **Policy not applying:** Verify policy assignment: `Get-CsOnlineUser -Identity user@contoso.com | Select TeamsMeetingPolicy, TeamsMessagingPolicy`
- **External access:** Check Teams Admin Center > External access settings
- **Guest access:** Check Teams Admin Center > Guest access

---

## Audit and Investigation

### Unified Audit Log Search

```powershell
# Search for mailbox access events
Search-UnifiedAuditLog -StartDate (Get-Date).AddDays(-7) -EndDate (Get-Date) `
    -RecordType ExchangeItem -Operations "MailItemsAccessed" `
    -UserIds "user@contoso.com" -ResultSize 5000

# Search for admin actions
Search-UnifiedAuditLog -StartDate (Get-Date).AddDays(-30) -EndDate (Get-Date) `
    -RecordType AzureActiveDirectory -Operations "Add member to role" `
    -ResultSize 1000

# Search for file sharing
Search-UnifiedAuditLog -StartDate (Get-Date).AddDays(-7) -EndDate (Get-Date) `
    -RecordType SharePointFileOperation -Operations "SharingSet" `
    -ResultSize 5000
```

### Compromised Account Investigation

1. **Check sign-in logs** for impossible travel, unfamiliar locations, anonymous IP addresses
2. **Check audit log** for inbox rule creation (`New-InboxRule`), mail forwarding changes
3. **Check mailbox forwarding:**
```powershell
Get-Mailbox -Identity user@contoso.com | Select ForwardingSmtpAddress, ForwardingAddress, DeliverToMailboxAndForward
Get-InboxRule -Mailbox user@contoso.com | Where {$_.ForwardTo -or $_.RedirectTo} | Select Name, ForwardTo, RedirectTo
```
4. **Check OAuth app consent:** Entra ID > Enterprise Applications > filter by recent consent
5. **Remediate:** Reset password, revoke sessions, remove suspicious inbox rules, disable forwarding

```powershell
# Revoke all sessions
Revoke-MgUserSignInSession -UserId "user@contoso.com"

# Remove suspicious inbox rules
Remove-InboxRule -Mailbox user@contoso.com -Identity "SuspiciousRule"

# Disable forwarding
Set-Mailbox -Identity user@contoso.com -ForwardingSmtpAddress $null -DeliverToMailboxAndForward $false
```

---

## Intune / Endpoint Issues

### Device Compliance

```powershell
Connect-MgGraph -Scopes "DeviceManagementManagedDevices.Read.All"

# Get non-compliant devices
Get-MgDeviceManagementManagedDevice -Filter "complianceState eq 'noncompliant'" -All | Select DeviceName, OperatingSystem, ComplianceState, LastSyncDateTime

# Common compliance failures:
# BitLocker not enabled -- Check if policy is deployed, TPM available
# OS version too old -- User must update Windows
# Not enrolled -- User must enroll via Company Portal
```

### Policy Not Applying

1. Verify device is enrolled and syncing (check `LastSyncDateTime`)
2. Verify user is in the correct group targeted by the policy
3. Check for conflicting policies (higher priority policy may override)
4. Force device sync: Intune Admin Center > Devices > [device] > Sync
