# Google Workspace Diagnostics

## Email Delivery Issues

### Email Log Search

Admin Console > Reporting > Email log search. Traces message delivery for the past 30 days.

**Search fields:** Sender, recipient, subject, date range, message ID.

**Delivery status values:**

| Status | Meaning | Investigation |
|---|---|---|
| Delivered | Message delivered to recipient's inbox/label | No issue |
| Queued | Message awaiting delivery | Check if destination is available |
| Bounced | Permanent delivery failure (5xx) | Check bounce reason, recipient validity |
| Rejected | Rejected by Google (policy, spam, DLP) | Check DLP rules, compliance settings |
| Spam | Classified as spam by Gmail | Check sender authentication (SPF/DKIM/DMARC) |
| Dropped | Silently discarded (DLP, compliance filter) | Check DLP rules, content compliance |

### Inbound Mail Not Arriving

1. **Check MX records:** Verify MX points to Google Workspace servers:
```dns
aspmx.l.google.com. (priority 1)
alt1.aspmx.l.google.com. (priority 5)
alt2.aspmx.l.google.com. (priority 5)
```

2. **Check SPF/DKIM/DMARC of sender:** If sender's authentication fails, Gmail may reject or spam-classify.

3. **Check routing rules:** Admin Console > Apps > Gmail > Routing. Look for rules that may redirect, reject, or quarantine.

4. **Check compliance rules:** Admin Console > Apps > Gmail > Compliance. Content compliance and objectionable content rules can silently drop messages.

5. **Check email log search** for delivery status and reason code.

6. **Check user's spam folder** -- Gmail's aggressive spam filtering can catch legitimate mail.

### Outbound Mail Bouncing

Common bounce reasons:

| Bounce Code | Meaning | Fix |
|---|---|---|
| `550 5.1.1` | Recipient not found | Verify recipient address |
| `550 5.7.1` | Sender not authorized | Check SPF record includes `_spf.google.com` |
| `550 5.7.26` | DMARC failure | Ensure DKIM is enabled and SPF aligned |
| `421 4.7.0` | Rate limited by recipient server | Reduce send rate, check for compromise |
| `452 4.5.3` | Too many recipients | Split into multiple messages |
| `550 5.7.350` | Blocked by recipient org | Contact recipient admin, check reputation |

### Gmail Routing Configuration Issues

Common routing misconfigurations:

| Symptom | Likely Cause | Fix |
|---|---|---|
| External mail loops | Routing rule sends back to original sender's domain | Add exception for sender domain |
| Duplicate messages | Multiple routing rules match same message | Review rule priority and conditions |
| Internal mail not delivered | `mydestination` or default routing overridden | Check default routing and inbound gateway settings |
| Disclaimer not applied | Content compliance rule conditions too narrow | Broaden matching criteria |
| Mail forwarded to wrong address | Catch-all or default routing misconfigured | Check default routing in Admin Console |

---

## GCDS Sync Failures

### Sync Not Running

1. Check GCDS service is running on the host server
2. Check sync log: `C:\Program Files\Google\Google Apps Directory Sync\logs\`
3. Verify LDAP connectivity to AD
4. Verify Google API credentials (OAuth token may have expired)
5. Check network connectivity from GCDS server to `googleapis.com`

### Common GCDS Errors

| Error | Cause | Fix |
|---|---|---|
| `LDAP search returned too many results` | Query too broad | Add pagination or refine base DN/filter |
| `User suspend conflict` | User exists in Google but not in AD | Check deletion policy; configure suspend vs. delete behavior |
| `Group member does not exist in Google` | External email in AD group | Enable "ignore external members" or provision external contacts |
| `Cannot create user: email already exists` | Email conflict with existing Google account | Delete or rename conflicting account, or merge |
| `Token expired or revoked` | OAuth token invalid | Re-authorize GCDS with a super admin account |
| `SSL handshake failure` | TLS version mismatch or proxy interference | Update Java trust store, check proxy settings |

### SCIM Provisioning Issues (Entra ID)

| Issue | Cause | Fix |
|---|---|---|
| Users not provisioning | Scope set to "Sync assigned users" but user not assigned | Assign user to enterprise app or change scope to "All users" |
| Attribute mapping wrong | OU or email mapped incorrectly | Review attribute mapping in Entra > Enterprise Apps > Provisioning |
| Provisioning delays | Entra incremental cycle is 40 minutes | Wait for cycle; force manual sync if urgent |
| Duplicate users | SCIM and GCDS both running | Use only one provisioning method per user population |

---

## Security Alerts

### Alerts Center

Admin Console > Reporting > Alerts. Pre-built alert types:

| Alert | Response |
|---|---|
| Suspicious login detected | Check sign-in logs, verify with user, reset password if compromised |
| Government-backed attack warning | Enroll user in APP, force password reset, review account activity |
| Phishing email reported by user | Check email log, add sender to blocked list if confirmed |
| DLP rule triggered | Review the triggering content, adjust rule if false positive |
| User suspended (by system) | Check reason (brute force, spam sending), remediate root cause |
| Domain-wide delegation granted | Verify the service account and scopes are authorized |
| 2SV disabled for user | Re-enforce 2SV, investigate why it was disabled |
| Mobile device compromised | Remote wipe the device, suspend user account |

### Compromised Account Investigation

1. **Check login activity:** Admin Console > Directory > Users > [user] > Security > Login activity
2. **Check for suspicious sign-ins:** Unfamiliar IP, device, or location
3. **Check for mail forwarding:** Admin Console > Directory > Users > [user] > Email forwarding
4. **Check for filter/forwarding rules:** Users can create filters that auto-forward; check via Gmail API or GAM
5. **Check OAuth app grants:** Admin Console > Security > API controls > App access control > Manage third-party app access

```bash
# GAM: Check user's forwarding
gam user compromised@example.com show forward

# GAM: Check user's filters
gam user compromised@example.com show filters

# GAM: Revoke all OAuth tokens
gam user compromised@example.com deprovision

# GAM: Force password change
gam update user compromised@example.com password NewSecurePass123! changepassword on
```

**Remediation steps:**
1. Suspend account immediately if active compromise
2. Reset password
3. Revoke all OAuth tokens and app passwords
4. Remove suspicious mail filters and forwarding
5. Check for unauthorized delegate access
6. Re-enable 2SV / force re-enrollment
7. Review audit logs for data exfiltration

---

## Drive and Sharing Issues

### External Sharing Not Working

1. Check tenant-level sharing: Admin Console > Apps > Drive and Docs > Sharing settings
2. Check OU-level override (child OU may restrict further)
3. Check trust rules (Enterprise) for domain-specific restrictions
4. Check Context-Aware Access policies blocking unmanaged devices

### Shared Drive Access Denied

1. Verify user is a member of the Shared Drive
2. Check permission level (Viewer cannot upload, Commenter cannot edit)
3. Check if Shared Drive has reached 400,000 item limit
4. Verify user's account is active (not suspended)

### Drive API Errors

| Error | Meaning | Fix |
|---|---|---|
| `403 userRateLimitExceeded` | Per-user quota exceeded | Implement exponential backoff |
| `403 storageQuotaExceeded` | User or Shared Drive is full | Clean up or request quota increase |
| `404 notFound` | File ID invalid or no access | Verify file ID and caller permissions |
| `429 rateLimitExceeded` | Domain-wide quota exceeded | Reduce request rate, batch operations |
| `500 backendError` | Transient Google error | Retry with exponential backoff |

---

## Meet and Chat Issues

### Meet Recording Not Working

1. Verify plan includes recording (Business Standard+)
2. Check Meet admin settings: Admin Console > Apps > Meet > Recording
3. Verify Drive has sufficient storage for the recording
4. Check if the meeting organizer has the correct license

### Chat External Messaging

1. Check Chat settings: Admin Console > Apps > Chat > External chat settings
2. Verify OU-level settings allow external messaging
3. Check if the external user's domain is trusted

---

## Device Management Issues

### Device Not Enrolling

1. Verify device enrollment is required: Admin Console > Devices > Mobile & endpoints > Settings
2. Check that the user's OU has the correct management tier (Basic vs. Advanced)
3. For Android: Ensure Google Device Policy app is installed
4. For iOS: Ensure MDM profile is installed
5. For Windows: Check Windows device management is enabled for the OU

### Device Compliance Failures

1. Check compliance settings: Admin Console > Devices > Mobile & endpoints > Settings
2. Verify device meets minimum OS version
3. Check if screen lock is enabled on device
4. Verify encryption is enabled
5. Check if device is rooted/jailbroken (auto-blocked in Advanced MDM)
