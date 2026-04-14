# Google Workspace Best Practices

## Security Hardening

### 2-Step Verification (2SV)

2SV is the highest-impact single security control. Admin Console > Security > 2-step verification.

**Enforcement options:**
- Off (not enforced, users can opt in)
- On (enforced; new users have grace period to enroll)
- Mandatory for admins only

**Method strength ranking:**
1. Hardware security keys (FIDO2/WebAuthn) -- phishing-resistant
2. Passkeys -- phishing-resistant, device biometrics
3. Google Authenticator / TOTP -- not phishing-resistant but strong
4. Google prompts -- not phishing-resistant
5. SMS/voice codes -- weakest, vulnerable to SIM swap

**Recommendation:** Enforce 2SV with security keys or passkeys for all users. Super admins must enroll in Advanced Protection Program (APP).

### Advanced Protection Program (APP)

Highest security level for high-value accounts:
- Security key or passkey as only 2SV method
- Stricter OAuth app approval (only Google-approved apps)
- Enhanced Gmail phishing/malware scanning
- Restricted data access during suspicious sign-in

Admin Console > Security > Advanced Protection Program.

### SAML SSO Security

- Test SSO with non-admin account before enforcing
- Maintain at least one super admin that bypasses SSO (for IdP outages)
- Set session duration to 8-24 hours (Admin Console > Security > Session controls)
- Legacy SSO profiles (pre-2023) should be migrated to named SAML profiles

### API Controls

Admin Console > Security > API controls > App access control:
- Require admin approval for all third-party OAuth apps
- Maintain explicit allowlist of approved apps
- Block known-risky app IDs
- Audit connected apps regularly

### Password Policy

Admin Console > Security > Password management:
- Minimum 12 characters
- Enable password strength enforcement
- Disable "less secure app access" (forces OAuth)

---

## Governance

### Sharing Controls

**Tenant-wide:** Admin Console > Apps > Drive and Docs > Sharing settings:
- Restrict external sharing to trusted domains
- Disable anonymous ("Anyone with the link") sharing
- Set default link sharing to "Restricted" (only named recipients)

**Shared Drive controls:**
- Prevent users from creating Shared Drives (if centralized management)
- Restrict non-members from requesting access
- Require Manager approval for external access

**Trust rules (Enterprise):** More granular than org-wide settings. Define which user groups can share with which external domains. Admin Console > Apps > Drive and Docs > Trust rules.

### Group Management

- Restrict group creation to admins only (if governance requires)
- Use Security groups (not regular groups) for Cloud IAM policies
- External members cannot be added to Security groups
- Configure group owner permissions per OU

Admin Console > Apps > Google Workspace > Groups for Business:
- Set who can create groups (all users vs. admins only)
- Set default group permissions for external sharing

### DLP Configuration (Enterprise)

Admin Console > Security > Access and data control > Data protection:

**Gmail DLP actions:**
- Quarantine for admin review
- Block delivery and bounce
- Warn sender before sending
- Add headers or modify routing
- BCC to audit address

**Drive DLP actions:**
- Block external sharing
- Warn user before sharing
- Revoke existing shares
- Audit log entry

**Best practices:**
- Start with detect-only mode (audit log entries without blocking)
- Use built-in detectors for common patterns (credit cards, SSNs)
- Add custom regex detectors for domain-specific data
- Require multiple pattern matches to reduce false positives
- Review trigger reports weekly, tune policies monthly

---

## Google Vault Configuration

### Retention Rules

**Default retention:** Set a default retention rule per service to prevent accidental data loss:
- Gmail: 7 years (or per regulatory requirement)
- Drive: 7 years
- Chat: 1-7 years depending on compliance needs

**Custom retention:** Create rules by OU, group, or search query for targeted retention.

**Key principle:** Retention rules delete data after the period expires. Legal holds override retention. Configure holds BEFORE enabling retention rules.

### Legal Hold Management

1. Create a Matter (case) in Vault
2. Add relevant custodians (users) to the Matter
3. Create Hold within the Matter
4. Scope: Specific accounts, OUs, or search criteria
5. Holds prevent deletion regardless of retention rules
6. Document hold creation for chain-of-custody

**Hold best practices:**
- Create holds before retention rules go live
- Use descriptive Matter names for audit clarity
- Review and release holds when litigation concludes
- Maintain a hold register outside of Vault

### eDiscovery Workflow

1. Create Matter in Vault
2. Add accounts or OUs to scope
3. Search across Gmail, Drive, Chat, Groups, Voice
4. Use boolean operators and date ranges
5. Export: MBOX (Gmail), native files (Drive), JSON (Chat)
6. All search and export actions are logged for audit

---

## Backup Strategy

Google Vault is NOT a backup. It preserves data within Google infrastructure but does not protect against:
- Google service disruptions (rare but possible)
- Admin account compromise deleting data before hold
- Accidental admin action deleting users or OUs

**Third-party backup recommended:**
- Spanning Backup for Google Workspace (Kaseya)
- Acronis Cyber Protect Cloud
- Backupify (Datto)
- AFI Backup

**Backup scope:** Gmail, Drive (My Drive + Shared Drives), Calendar, Contacts, Sites.

**Best practice:** Daily backup minimum, store outside Google infrastructure, test restore quarterly.

---

## Endpoint Management

### Mobile Device Management

Admin Console > Devices:

| Tier | What It Provides |
|---|---|
| Basic (Agentless) | Device inventory, remote account wipe |
| Advanced (MDM) | Policy enforcement, cert push, full remote wipe |
| Windows Management | Windows 10/11 policy enforcement |
| Chrome Management | ChromeOS enterprise policies, kiosk mode |

**Recommended:** Advanced MDM for all corporate mobile devices. Require admin approval for device enrollment in regulated environments.

### App Management

- Approve/block specific apps from Google Workspace Marketplace
- Set OAuth app allowlist to prevent unauthorized data access
- Block personal account sign-in on managed devices

---

## Migration Best Practices

### Pre-Migration Checklist

- [ ] Inventory all users, groups, Shared Drives, and licenses
- [ ] Configure GCDS or SCIM for identity sync before mail migration
- [ ] Enable IMAP access for source accounts (if IMAP migration)
- [ ] Create Google service account with domain-wide delegation (for API migration)
- [ ] Lower DNS TTL to 300 seconds at least 48 hours before MX cutover
- [ ] Communicate timeline and expectations to users

### Coexistence During Migration

- Configure dual delivery or split routing
- Maintain both platforms during transition (30+ days recommended)
- Keep source licenses active as safety net
- Run incremental/delta syncs after MX cutover to capture stragglers

### Post-Migration

- [ ] Verify MX records point to Google (`aspmx.l.google.com` and alternates)
- [ ] Enable DKIM signing for all domains
- [ ] Configure DMARC policy
- [ ] Disable IMAP access if no longer needed
- [ ] Set up Vault retention rules
- [ ] Configure DLP policies
- [ ] Train users on Google Workspace differences (labels vs. folders, Shared Drives vs. personal Drive)

---

## Admin Console Navigation Quick Reference

| Task | Path |
|---|---|
| Create user | Directory > Users > Add new user |
| Manage OUs | Directory > Organizational units |
| Gmail routing | Apps > Gmail > Routing |
| Gmail safety | Apps > Gmail > Safety |
| DKIM setup | Apps > Gmail > Authenticate email |
| Drive sharing | Apps > Drive and Docs > Sharing settings |
| 2SV enforcement | Security > 2-step verification |
| SSO setup | Security > Authentication > SSO with third-party IdP |
| Context-Aware Access | Security > Access and data control > Context-Aware Access |
| DLP | Security > Access and data control > Data protection |
| API controls | Security > API controls |
| Vault | Apps > Google Workspace > Vault |
| Audit logs | Reporting > Audit and investigation |
| Email log search | Reporting > Email log search |
| Alerts | Reporting > Alerts |
| Device management | Devices |
| Billing/licenses | Billing > Subscriptions |
