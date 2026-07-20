# Google Workspace Architecture Deep Reference

## Account and Domain Model

A Google Workspace account is the top-level container for all users, groups, OUs, configuration, and data. Maps 1:1 to a Google Cloud organization resource. Cloud Identity and Google Workspace share the same underlying platform.

**Domain support:** Up to 600 domains (primary + alias + secondary). A secondary domain has its own users; an alias domain maps all addresses to the primary domain's users.

## Organizational Units (OUs)

OUs are hierarchical containers for grouping users and applying policies:
- Every account has a root OU (cannot be deleted)
- Nestable to any depth
- Users belong to exactly one OU (groups allow multi-membership)
- Settings inherit downward; child OUs inherit parent unless explicitly overridden
- Devices can be in separate OUs from users for different MDM policies

**Design best practice:** Separate users and devices into distinct OU branches. Model user OUs around stable attributes (department, employment type, geography), not transient projects. Use groups for dynamic access control; use OUs for persistent policy differences.

```
/ (root)
├── Employees/
│   ├── Engineering/
│   ├── Finance/
│   ├── HR/
│   └── Sales/
├── Contractors/
├── Service Accounts/
└── Devices/
    ├── Managed Laptops/
    └── Mobile/
```

## Cloud Identity Integration

Google Workspace automatically provisions a Cloud Identity Premium account:
- Google Cloud Console access for GCP resources
- Cloud Identity Groups (Security label) for IAM policies
- Workforce Identity Federation for hybrid access
- Context-Aware Access using device and identity signals

---

## Core Services

### Gmail

Enterprise features beyond consumer Gmail:
- **Hosted S/MIME:** Admin uploads certificates; messages auto-encrypt between S/MIME parties. Admin Console > Apps > Gmail > User settings > S/MIME.
- **Client-side encryption (CSE):** Customer-held keys via external KMS. Enterprise Plus only.
- **Advanced Phishing and Malware Protection:** Admin Console > Gmail > Safety. Pre-delivery scanning, unusual attachment quarantine, intra-domain auth checks.
- **Confidential Mode:** Sender-set expiration, disable forwarding/downloading (not true E2EE).
- **GWSMO:** Syncs Gmail/Calendar/Contacts to Outlook desktop.

### Google Drive and Shared Drives

**My Drive:** Personal storage owned by user. Deleted with account unless transferred.

**Shared Drives:** Organizational storage. Files owned by the organization, not individuals.
- Up to 400,000 items per Shared Drive
- Up to 100 members
- Five permission levels: Manager, Content Manager, Contributor, Commenter, Viewer
- Admin can create, manage, delete any Shared Drive regardless of membership

**Sharing controls:** Admin Console > Apps > Drive and Docs > Sharing settings:
- Prevent non-members from requesting access
- Restrict sharing to trusted domains
- Set default link-sharing behavior

**Trust rules (Enterprise):** Granular policies for which users/domains can share with which recipients.

### Google Meet

| Feature | Plan Availability |
|---|---|
| Recording to Drive | Business Standard+ |
| Transcripts | Business Standard+ |
| Noise cancellation | Business Standard+ |
| Breakout rooms | Business Standard+ |
| Live streaming | Enterprise Standard (10k), Plus (100k) |
| In-domain interop (SIP/H.323) | Enterprise |

### Google Chat

- Spaces (persistent group conversations) vs. direct messages
- Threaded conversations within Spaces
- Guest accounts (Enterprise)
- Chat bots and webhooks
- DLP rules apply to Chat (Enterprise)
- External messaging configurable per OU

### Google Calendar

- Resource booking (rooms, equipment)
- Working location feature
- Appointment scheduling with external booking pages
- Calendar API for programmatic management
- Interoperability with Exchange via connectors

### Google Vault

Information governance and eDiscovery. Included with Business Plus, Enterprise.

| Function | Description |
|---|---|
| Retention rules | By OU, service, or search query. 1-36,500 days |
| Legal holds | Preserve indefinitely, override retention |
| Search | By user, OU, date, keyword across Gmail, Drive, Chat, Groups, Voice |
| Export | MBOX, PST, native format |
| Audit trail | All Vault actions logged |

**Services covered:** Gmail (including deleted/spam), Drive, Chat, Groups, Voice, Meet recordings.

### Google Groups

Two functions:
1. **Email distribution list:** Messages delivered to all members
2. **Access control group:** Grant access to Drive, Shared Drives, Calendar, Sites

**Group types:** Email list, Forum, Collaborative inbox, Announcement-only.

**Security groups:** Groups with Security label for Cloud IAM policies. No external members.

---

## Licensing

### Business Plans (up to 300 users)

| Feature | Starter | Standard | Plus |
|---|---|---|---|
| Storage/user | 30 GB | 2 TB | 5 TB |
| Meet recording | No | Yes | Yes |
| Vault | No | Add-on | Included |
| Advanced endpoint mgmt | No | No | Yes |

### Enterprise Plans (no user cap)

| Feature | Starter | Standard | Plus |
|---|---|---|---|
| Storage/user | 1 TB | 5 TB | 5 TB |
| Vault | Add-on | Yes | Yes |
| Advanced DLP | Yes | Yes | Yes |
| Context-Aware Access | Yes | Yes | Yes |
| S/MIME | No | No | Yes |
| Client-side encryption | No | No | Yes |
| Data regions | Yes | Yes | Yes |

### Education Plans

Education Fundamentals free for qualified institutions (100 TB pooled). Standard, Plus available at low per-student pricing.

---

## Identity Integration

### GCDS (Google Cloud Directory Sync)

Reads from on-prem AD/LDAP and syncs to Google Workspace. Does NOT sync passwords (use SAML SSO).

**Syncs:** Users, OU assignments, group memberships, shared contacts, aliases.

**Does not sync:** Passwords, Workspace-specific settings, calendar resources.

**Architecture:**
1. Install on Windows server with AD read access
2. Configure LDAP connection
3. Map AD attributes to Workspace fields
4. Define exclusion rules
5. Dry run, then schedule (every 4 hours recommended)

**Common issues:**
- `LDAP search returned too many results` -- Add pagination or refine filter
- `User suspend conflict` -- Check deletion rules
- `Group member does not exist` -- External email in AD group; configure external member handling

### Entra ID SCIM Provisioning

Alternative to GCDS for Entra ID-sourced identity:

| Factor | GCDS | Entra SCIM |
|---|---|---|
| Source | AD/LDAP (on-prem) | Entra ID (cloud) |
| Sync direction | Pull from AD | Push from Entra |
| Latency | Scheduled (4 hours) | Near-real-time |
| OU mapping | Yes (LDAP attribute) | Limited (group assignment) |
| Hosted | On-prem server | Entra cloud service |

### SAML SSO

Google as SAML SP (third-party IdP authenticates):
1. Admin Console > Security > Authentication > SSO with third-party IdP
2. Create SAML SSO profile with IdP metadata
3. Assign to OUs or groups
4. Test with non-admin account before enforcing

**Entra ID as IdP:** Enterprise app gallery > "Google Cloud / G Suite Connector". Entity ID: `google.com/a/yourdomain.com`.

---

## APIs and Automation

### Admin SDK

| Sub-API | Key Operations |
|---|---|
| Directory API | CRUD users, groups, OUs, devices |
| Reports API | Audit logs, usage reports |
| License Manager API | Assign/revoke SKU licenses |
| Groups Settings API | Configure group policies |

**Authentication:** Service account with domain-wide delegation (DWD) or admin OAuth flow.

### GAM (Google Workspace Admin Manager)

Open-source CLI for bulk administration:

```bash
gam print users                              # List all users
gam create user jdoe@example.com ...         # Create user
gam update user jdoe@example.com org /Sales  # Move OU
gam print teamdrives                         # List Shared Drives
gam csv users.csv gam update user ~email ... # Bulk operations
```

### Apps Script

JavaScript-based scripting in Google Workspace:
- Time-driven triggers (daily, hourly)
- Event-driven (form submit, sheet edit, calendar event)
- Web app endpoints (HTTP GET/POST)
- Full access to Gmail, Drive, Calendar, Sheets, Admin SDK

### Data Regions

Pin covered data to US or EU at the OU level. Business or Enterprise required.

**Covered:** Primary data at rest and some processing.
**Not covered:** Metadata, indexing, some backup replicas.

Admin Console > Account > Data regions.
