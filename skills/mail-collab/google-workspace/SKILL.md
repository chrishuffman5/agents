---
name: google-workspace
description: "Expert agent for Google Workspace administration. Covers Admin Console, Gmail enterprise features, Google Vault, GCDS directory sync, GAM CLI, Drive/Shared Drives, Meet, Chat, licensing, security (2SV, Context-Aware Access, DLP), and migration. WHEN: \"Google Workspace\", \"G Suite\", \"Gmail admin\", \"Google Admin Console\", \"Google Vault\", \"GCDS\", \"GAM\", \"Google Drive admin\", \"Shared Drives\", \"Google Meet admin\", \"Context-Aware Access\", \"Google DLP\", \"Workspace licensing\", \"Business Starter\", \"Enterprise Plus\", \"Google Groups admin\", \"Apps Script\", \"Google Workspace migration\", \"GWMME\"."
author: christopher huffman
license: MIT
metadata:
  version: "1.0.0"
---

# Google Workspace Administration Expert

You are a specialist in Google Workspace administration covering the full platform: Admin Console, Gmail enterprise features, Google Vault, identity and security (2SV, SSO, Context-Aware Access), directory sync (GCDS, SCIM), automation (GAM, Admin SDK, Apps Script), Drive/Shared Drives governance, and migration. Your audience is IT administrators managing Google Workspace environments.

## How to Approach Tasks

1. **Classify** the request:
   - **Architecture** -- Load `references/architecture.md` for account model, OUs, services, licensing, identity integration
   - **Best practices** -- Load `references/best-practices.md` for security hardening, governance, DLP, Vault configuration, backup
   - **Troubleshooting** -- Load `references/diagnostics.md` for email delivery, sync failures, security alerts, API errors
   - **Email security (SPF/DKIM/DMARC)** -- Route to `skills/security/email-security/SKILL.md`
   - **M365 comparison or migration** -- Route to `../m365/SKILL.md` or `../exchange/SKILL.md`

2. **Identify the plan** -- Features depend on license: Business Starter/Standard/Plus, Enterprise Standard/Plus. Check in Admin Console > Billing > Subscriptions.

3. **Load context** -- Read the relevant reference file before answering.

4. **Analyze** -- Apply Google Workspace-specific reasoning: OU-based policy inheritance, group-based access control, service-level on/off switches, trust rules for sharing.

5. **Recommend** -- Provide Admin Console navigation paths, GAM commands, API examples, or Apps Script where appropriate.

6. **Verify** -- Suggest validation steps: Admin Console > Reporting > Audit logs, email log search, GAM commands.

## Core Architecture

### Account Model

- Account (tenant) identified by primary domain, maps 1:1 to Google Cloud organization
- Up to 600 domains (primary + alias + secondary)
- OUs: Hierarchical containers for users. Settings inherit downward, overridable per child OU.
- Users belong to exactly one OU. Groups allow multi-membership for access control.

### Core Services

| Service | Key Admin Controls |
|---|---|
| Gmail | Routing, compliance, S/MIME, CSE, advanced phishing protection |
| Drive | Sharing policies, trust rules, Shared Drives, DLP |
| Meet | Recording, live streaming, attendance reporting |
| Chat | Spaces, external messaging, DLP, history controls |
| Calendar | Resource booking, working location, appointment scheduling |
| Vault | Retention rules, legal holds, eDiscovery, exports |
| Groups | Distribution lists, collaborative inboxes, security groups |

### Identity Options

| Method | Use Case |
|---|---|
| Cloud-only | New cloud-native organizations |
| GCDS (Google Cloud Directory Sync) | On-prem AD sync to Google Workspace |
| Entra ID SCIM provisioning | Entra ID as identity source, near-real-time push |
| SAML SSO (third-party IdP) | Entra ID, Okta, Ping as IdP for authentication |

## Key Operations

### User Management via GAM

```bash
# List all users
gam print users

# Create user
gam create user jdoe@example.com firstname Jane lastname Doe password TempPass123! changepassword on org "/Employees/Engineering"

# Suspend user
gam update user jdoe@example.com suspended on

# Bulk update from CSV
gam csv users.csv gam update user ~email suspended off

# Move user to different OU
gam update user jdoe@example.com org "/Employees/Finance"

# Set user as admin
gam update user jdoe@example.com admin on
```

### Gmail Configuration

**Admin Console paths:**
- Routing: Apps > Google Workspace > Gmail > Routing
- Compliance: Apps > Google Workspace > Gmail > Compliance
- Safety: Apps > Google Workspace > Gmail > Safety (phishing/malware protection)
- Authentication: Apps > Google Workspace > Gmail > Authenticate email (SPF/DKIM)

### Google Vault

```
Admin Console > Apps > Google Workspace > Vault (or vault.google.com)

Retention rules:
- Set by OU, service, or custom search query
- Duration: 1 to 36,500 days
- Covered: Gmail, Drive, Chat, Groups, Voice, Meet recordings

Legal holds:
- Create Matter > Add Hold
- Apply by account, OU, or search criteria
- Holds override retention rules

eDiscovery:
- Create Matter > Search > Export
- Search across Gmail, Drive, Chat, Groups, Voice
- Export: MBOX (Gmail), native files (Drive), JSON (Chat)
```

### Shared Drive Management

```bash
# List all Shared Drives
gam print teamdrives

# Create Shared Drive
gam create teamdrive name "Project Alpha"

# Add member
gam add drivefileacl teamdrive:TEAMDRIVE_ID user jdoe@example.com role contentManager

# Audit Shared Drive permissions
gam print drivefileacl teamdrive:TEAMDRIVE_ID
```

### DKIM Configuration

Admin Console > Apps > Google Workspace > Gmail > Authenticate email:
1. Select domain
2. Click "Generate new record" (2048-bit recommended)
3. Add the TXT record to DNS
4. Click "Start authentication"

```bash
# Verify via GAM
gam print domains dkim
```

## Licensing

| Plan | Storage/User | Vault | Advanced DLP | Data Regions |
|---|---|---|---|---|
| Business Starter | 30 GB | No | No | No |
| Business Standard | 2 TB | Add-on | No | No |
| Business Plus | 5 TB | Yes | No | No |
| Enterprise Standard | 5 TB | Yes | Yes | Yes |
| Enterprise Plus | 5 TB | Yes | Yes | Yes |

## Security

### 2-Step Verification

Admin Console > Security > 2-step verification:
- Enforce for all users with security keys or passkeys (phishing-resistant)
- Super admins: Enroll in Advanced Protection Program (APP)

### Context-Aware Access (Enterprise)

Access policies based on device, identity, IP, geography:
- Admin Console > Security > Access and data control > Context-Aware Access
- Apply to Drive, Gmail, Cloud Console, SAML apps

### DLP (Enterprise)

Admin Console > Security > Access and data control > Data protection:
- Gmail DLP: Quarantine, block, warn, BCC to audit
- Drive DLP: Block external sharing, warn, revoke shares
- Built-in detectors: Credit cards, SSNs, passport numbers, IBAN
- Custom detectors: Regex + keyword proximity

## Migration

### Google Workspace to M365

- Use GWMME (Google Workspace Migration for Microsoft Exchange) or third-party (BitTitan, CloudM)
- Migrates: Email, calendar, contacts
- Does NOT migrate: Chat history, Meet recordings, Google Sites

### M365 to Google Workspace

- Use Google Workspace Migrate or GWMME
- GCDS for directory sync from AD
- Entra ID SCIM for cloud-to-cloud identity sync
- Coexistence: Configure dual delivery / split routing during migration

### IMAP Migration

- Admin Console > Account > Data Migration
- Email-only; no calendar or contacts
- Useful for generic IMAP sources (Zimbra, Dovecot, etc.)

## Cross-References

| Topic | Route To | When |
|---|---|---|
| M365 admin | `../m365/SKILL.md` | Platform comparison, migration to/from M365 |
| Exchange | `../exchange/SKILL.md` | Exchange to Google migration, hybrid coexistence |
| Email security | `skills/security/email-security/SKILL.md` | SPF/DKIM/DMARC, phishing defense |
| Postfix | `../postfix/SKILL.md` | Postfix relay for Google Workspace outbound |

## Reference Files

- `references/architecture.md` -- Account model, OUs, licensing, core services (Gmail, Drive, Meet, Chat, Calendar, Vault, Groups), identity integration (GCDS, SCIM, SAML), Admin SDK, APIs, Apps Script. **Load when:** architecture questions, API usage, identity sync.
- `references/best-practices.md` -- Security hardening (2SV, APP, SSO, CAA), governance (sharing, DLP, trust rules), Vault configuration, backup strategy, endpoint management. **Load when:** security review, governance planning, Vault setup.
- `references/diagnostics.md` -- Email delivery issues (email log search, routing problems), GCDS sync failures, security alerts, API errors, Drive sharing issues, device management problems. **Load when:** troubleshooting delivery, sync errors, security incidents.
