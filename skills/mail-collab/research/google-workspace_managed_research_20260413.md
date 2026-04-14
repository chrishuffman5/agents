# Google Workspace — Comprehensive Research Reference

**Research date:** April 2026  
**Scope:** Architecture, licensing, core services, admin management, security, directory sync, APIs, automation, migration, diagnostics

---

## 1. ARCHITECTURE AND DOMAIN MODEL

### Account Structure

A Google Workspace account is the top-level container for all users, groups, organizational units, configuration, and data. When an organization signs up for Google Workspace, a single account (tenant) is created. This account is identified by a primary domain and maps 1:1 to a Google Cloud organization resource. Cloud Identity and Google Workspace share the same underlying technical platform, APIs, and administrative tooling — Cloud Identity is the identity-only version for organizations that want identity management without Workspace productivity apps.

Each account can support up to 600 domains (primary domain + alias and secondary domains). A secondary domain is a fully separate domain with its own users; an alias domain maps all addresses to the primary domain's users automatically.

### Organizational Units (OUs)

Organizational Units (OUs) are hierarchical containers used to group users and apply different policies and service settings to different populations. Key properties:

- Every account has a root OU (cannot be deleted)
- OUs can be nested to any depth
- A user belongs to exactly one OU (unlike groups, which allow multi-membership)
- Settings inherit downward: child OUs inherit parent settings unless explicitly overridden
- Devices can be placed in separate OUs from users, allowing different MDM policies

**Design best practice:** Separate users and devices into distinct OU branches. Model user OUs around stable organizational attributes (department, employment type, geographic region) rather than transient project membership. Use groups for dynamic access control; use OUs for persistent policy differences.

Example OU tree:
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

### Google Cloud Identity Integration

Google Workspace automatically provisions a Cloud Identity Premium account at the same domain, enabling:

- Google Cloud Console access for GCP resources
- Cloud Identity Groups (with Security label) for IAM policies
- Workforce Identity Federation for hybrid access scenarios
- Context-Aware Access policies using device and identity signals

The Google Cloud organization resource is linked to the primary domain and is required before GCP projects can be assigned to a folder hierarchy.

### Data Regions

Admins can pin covered data (Gmail, Drive, Docs, Sheets, Slides, Meet recordings, Chat messages) to either the United States or the European Union. Data region settings apply at the OU level. Configuration path: Admin console > Account > Data regions.

**Covered data:** Primary data at rest and some processing operations  
**Not covered:** Metadata, indexing infrastructure, some backup replicas

Data regions require a Business or Enterprise plan. Detailed reporting on where data is currently stored is available in Admin console > Reports > Data regions.

### Google Vault (Archiving and eDiscovery)

Google Vault is the information governance and eDiscovery service included with Business Plus and Enterprise plans (add-on available for Business Standard).

**Vault capabilities:**

| Function | Description |
|---|---|
| Retention rules | Set data retention by OU, service, or search query. Duration: 1–36,500 days |
| Legal holds | Preserve data indefinitely for specific users/OUs regardless of retention rules |
| Search | Query by user, OU, date range, keyword, labels across Gmail, Drive, Chat, Groups, Voice |
| Export | Export to MBOX (mail), PST, or native format for legal review |
| Audit trail | All Vault actions are logged for chain-of-custody documentation |

**Services covered by Vault:** Gmail (including sent, deleted, spam), Google Drive, Google Chat, Google Groups, Google Voice, Google Meet recordings

**Important:** Vault preserves data but does not replace backup. Data in Vault is still hosted in Google infrastructure.

---

## 2. LICENSING

### Business Plans (up to 300 users)

| Feature | Business Starter | Business Standard | Business Plus | Enterprise Starter |
|---|---|---|---|---|
| Price (per user/month) | $7 | $14 | $22 | Contact sales |
| Pooled storage | 30 GB/user | 2 TB/user | 5 TB/user | 1 TB/user |
| Meet participants | 100 | 150 | 500 | 150 |
| Meet recording | No | Yes | Yes | Yes |
| Noise cancellation | No | Yes | Yes | Yes |
| Google Vault | No | Add-on | Included | No |
| eDiscovery/audit | No | No | Yes | No |
| Advanced DLP | No | No | No | No |
| Endpoint management | Basic | Basic | Advanced | Advanced |
| Security dashboard | No | No | Yes | No |
| Gemini AI features | Yes | Yes | Yes | Yes |
| User cap | 300 | 300 | 300 | 300 |

### Enterprise Plans (no user cap)

| Feature | Enterprise Starter | Enterprise Standard | Enterprise Plus |
|---|---|---|---|
| Pooled storage | 1 TB/user | 5 TB/user | 5 TB/user |
| Meet participants | 500 | 1,000 | 1,000 |
| Meet live streaming | No | Yes (10k viewers) | Yes (100k viewers) |
| Vault | Add-on | Yes | Yes |
| Advanced DLP | Yes | Yes | Yes |
| Context-Aware Access | Yes | Yes | Yes |
| Security investigation | Yes | Yes | Yes |
| S/MIME encryption | No | No | Yes |
| Client-side encryption | No | No | Yes |
| Data regions | Yes | Yes | Yes |
| Assured Controls | No | No | Yes |
| CASB integration | No | Yes | Yes |
| Enterprise Support | No | Yes | Yes |

### Frontline Plans

Designed for deskless/frontline workers (retail, manufacturing, field service). Frontline Starter and Frontline Standard provide mobile-first access to Gmail, Chat, Meet, and Drive at reduced per-user pricing. No desktop productivity suite licensing required.

### Education Plans

| Edition | Cost | Key Features |
|---|---|---|
| Education Fundamentals | Free (qualified institutions) | Gmail, Docs, Meet (100 pax), Classroom, Vault, 100 TB pooled storage |
| Education Standard | $3/student/year | + Security investigation, advanced audit, enhanced admin controls |
| Teaching & Learning Upgrade | $4/license/year | + Meet (250 pax), recordings, practice sets, originality reports |
| Education Plus | $5/student/year | All of the above + Meet (500 pax), live streaming, SIS integration, CSE |

### Nonprofit Plans

Eligible 501(c)(3) nonprofits receive Google Workspace Business Starter at no cost. Upgrades to Standard and Plus are available at 70%+ discount. Enterprise Plus is available at reduced pricing through the Google for Nonprofits program.

---

## 3. CORE SERVICES

### Gmail

Gmail is the email service in Google Workspace. Enterprise features beyond consumer Gmail:

- **Hosted S/MIME:** Admin uploads certificates; messages auto-encrypt when both parties have certificates. Enable at: Admin console > Apps > Google Workspace > Gmail > User settings > S/MIME
- **Client-side encryption (CSE):** End-to-end encryption where keys are held by the customer's external KMS (not Google). Available on Enterprise Plus, Education Plus, Frontline Plus. Uses S/MIME 3.2 standard.
- **Advanced Phishing and Malware Protection:** Admin console > Gmail > Safety. Options include quarantining emails with unusual attachment types, enhanced pre-delivery message scanning, intra-domain authentication checks.
- **Email routing:** See Section 8 for routing configurations.
- **Confidential Mode:** Allows sender to set expiration and disable forwarding/downloading/printing. Does not provide true E2EE.
- **GWSMO (Google Workspace Sync for Microsoft Outlook):** Syncs Gmail, Calendar, Contacts to Outlook. Requires installation on each machine.

### Google Drive and Shared Drives

**My Drive** is personal storage tied to a user account. Files in My Drive are owned by the user — if the account is deleted, files are deleted unless transferred.

**Shared Drives** (formerly Team Drives) are organizational storage containers where files are owned by the organization, not by individuals. Key characteristics:

- Up to 400,000 items per Shared Drive
- Up to 100 members per Shared Drive
- Five permission levels: Manager, Content Manager, Contributor, Commenter, Viewer
- Inheritance: members inherit the Shared Drive-level permission unless overridden at folder/file level
- Admin can create, manage, and delete any Shared Drive regardless of membership

**Shared Drive admin controls** (Admin console > Apps > Google Workspace > Drive and Docs > Sharing settings):

- Prevent users from creating new Shared Drives
- Prevent non-members from requesting access
- Restrict sharing to trusted domains only
- Set default link-sharing behavior (restricted, anyone in domain, anyone with link)

**Trust rules** (Enterprise): Define granular policies for which users and domains can share Drive files with which recipients. More precise than the organization-wide sharing setting.

**Drive API error codes:**
- `403 userRateLimitExceeded` — Per-user quota exceeded; implement exponential backoff
- `403 storageQuotaExceeded` — User or Shared Drive is full
- `404 notFound` — File ID invalid or caller lacks access
- `429 rateLimitExceeded` — Domain-wide quota exceeded
- `500 backendError` — Transient Google error; retry with backoff

### Google Meet

Video conferencing service. Key enterprise features:

| Feature | Availability |
|---|---|
| Recording to Drive | Business Standard and above |
| Transcripts | Business Standard and above |
| Noise cancellation | Business Standard and above |
| Breakout rooms | Business Standard and above |
| Polls and Q&A | All plans |
| Attendance reporting | Business Plus and above |
| Live streaming | Enterprise Standard (10k viewers), Enterprise Plus (100k viewers) |
| In-domain interop (SIP/H.323) | Enterprise |
| Continuous meeting chat | Enterprise Starter and above |
| Ask Gemini in Meet | Business Standard and above (expanded 2026) |

**New in 2026:** In-meeting chat is now powered by Google Chat, making meeting messages persistently available in a linked Chat conversation after the meeting ends. Each Meet call is tied to the originating Calendar event for traceability.

**Meet audit logging:** Includes permission type used to join a meeting (domain, link, invited). Available in Admin console > Reporting > Audit > Meet.

### Google Chat

Messaging platform integrated with Meet and Calendar.

- Spaces (persistent group conversations) vs. direct messages
- Threaded conversations within Spaces
- Guest accounts: External users can be invited to Spaces as guests (Enterprise)
- Chat bots and app integrations via Google Workspace Marketplace or custom webhooks
- Admin controls: Admin console > Apps > Google Workspace > Google Chat
  - DLP rules can apply to Chat messages (Enterprise)
  - External messaging can be disabled per OU
  - Chat history on/off policy per OU

**New in 2026:** Dedicated Meetings section in Chat sidebar to organize meeting-related conversations. Post-meeting follow-up integration with Calendar events.

### Google Calendar

- Resource booking (conference rooms, equipment) via resource calendars
- Working location feature (office, remote, unspecified)
- Appointment scheduling (replaces Appointment Slots) with external booking pages
- Up to 20 co-hosts per appointment booking page (2026)
- Interoperability with Exchange via Exchange Server sync or third-party connectors
- Calendar API supports creating, updating, querying events and resources programmatically

### Google Docs, Sheets, Slides

- Real-time collaborative editing with version history
- Offline editing via Chrome browser or Drive for Desktop
- Import/export: DOCX, XLSX, PPTX, PDF, ODS, CSV, and more
- Linked objects: Embed Sheets charts and tables in Docs/Slides with live refresh
- Gemini AI: Drafting, summarization, formula assistance, image generation (all Business/Enterprise)
- Macro recording in Sheets (records Apps Script)
- Named ranges, protected ranges, and data validation in Sheets
- AppSheet no-code app builder can use Sheets as a data source

### Google Sites

Modern Sites is a drag-and-drop intranet builder. Embeds Google Drive files, Docs, Sheets, Slides, Forms, Maps, YouTube, and Calendar. Access control mirrors Drive sharing (can be shared internally, with specific users, or publicly). Classic Sites is deprecated.

### Google Groups

Google Groups serves two distinct functions in Workspace:

1. **Email distribution list:** Messages to the group address are delivered to all members
2. **Access control group:** Used to grant access to Drive files, Shared Drives, Calendars, Sites, and other resources

**Group types:**
- Email list (one-way delivery)
- Forum (members reply to group; discussions archived)
- Collaborative inbox (shared queue with assignment/resolution tracking)
- Announcement-only (only managers can post)

**Security groups:** Groups with the Security label can be used in Cloud IAM policies. Security groups cannot have external members. Created via Admin console or Cloud Identity Groups API.

**Admin controls:** Admin console > Directory > Groups. Admins can set who can create groups (all users vs. admins only), view group membership, and manage group settings.

---

## 4. ADMIN CONSOLE

### User Management

Navigation: Admin console > Directory > Users

**Creating users:**
- Individual: Fill first name, last name, email, org unit, password
- Bulk: Upload CSV (Admin console > Bulk update users) or use GAM/API
- Automated: GCDS sync from Active Directory, or SCIM provisioning from Entra ID

**User account states:**
- Active
- Suspended (retains data, blocks sign-in, does not consume a paid license after 30 days)
- Deleted (data retained for 20 days in Admin console for recovery; then permanent)

**User detail settings per account:**
- Org unit assignment
- License assignment (per SKU)
- Recovery email and phone
- 2-Step Verification status and enforcement bypass
- Application-specific passwords (if 2SV is enforced but app doesn't support OAuth)
- Active sessions (view and revoke)
- Security events (recent sign-ins, suspicious activity)

### OU Management

Navigation: Admin console > Directory > Organizational units

- Add OU: Click "+" on parent OU, enter name and description
- Move users between OUs: Individual (user profile > Org unit) or bulk via CSV
- OU-level service configuration overrides parent settings

### App Access Control

Navigation: Admin console > Security > API controls > App access control

- **Trust level settings:** Trust internal apps, trust domain-installed apps, or require admin approval for all third-party OAuth apps
- **OAuth app allowlist:** Explicitly approved apps that can access Workspace data
- **Block apps:** Prevent specific app IDs from accessing domain data
- **Connected apps audit:** View which apps have OAuth tokens issued

### Security Settings

Navigation: Admin console > Security

Key settings:

| Setting | Recommended Configuration |
|---|---|
| 2-Step Verification enforcement | Enforce for all users; allow security keys/passkeys |
| Password policy | Min 12 characters; no maximum limit; strength enforcement on |
| Login challenges | Allow suspicious login challenges |
| Session controls | Set Google session duration (1 hour to Never; 8–24 hours recommended) |
| Less secure app access | Disabled (forces OAuth) |
| API access | Restrict based on allowlist |
| External sharing | Restrict to trusted domains |

### Device Management (Endpoint Management)

Navigation: Admin console > Devices

**Management tiers:**

| Tier | Mobile Platforms | Windows | What It Provides |
|---|---|---|---|
| Basic (Agentless) | Android, iOS | No | Device inventory, remote wipe (account data only) |
| Advanced (MDM) | Android, iOS | No | Policy enforcement, certificate push, remote lock/wipe (full) |
| Windows Device Management | N/A | Yes | Windows 10/11 management via Workspace MDM, policy enforcement |
| Chrome management | ChromeOS | N/A | Full enterprise Chrome policy, kiosk mode, extension management |

**2026 update:** Google updated local administrative access controls for Windows device management, giving admins more granular control over whether managed Windows devices have local admin rights.

**Require admin approval for device enrollment:** Admin console > Devices > Mobile & endpoints > Settings > General > Device approvals. When enabled, users cannot access work data until an admin approves the device.

### Reporting

Navigation: Admin console > Reporting

- **Audit logs:** Admin actions, Drive activity, Gmail actions, Login events, Token events, Groups events, Meet events, Chat events, Rules (DLP triggers)
- **Reports:** App usage, user activity, security highlights, storage usage, Vault access
- **Email log search:** Trace delivery path for individual messages (see Section 10)
- **Alerts center:** Proactive notifications for security events

**2026 Audit Log Enhancement:** Google is introducing enhanced audit log events with expanded fields across Gmail, Drive, account security, and app access controls. Transition period: February 17 – August 17, 2026. Enhanced logging becomes standard August 18, 2026.

### Alerts Center

Navigation: Admin console > Reporting > Alerts

Pre-built alert types:
- Suspicious login detected
- Government-backed attack warning
- Phishing email reported by user
- DLP rule triggered
- User suspended (by system)
- Domain-wide delegation granted
- 2-Step Verification disabled for user
- Mobile device compromised

Alerts can be configured to send email notifications to specific admin recipients. Custom alerts can be created via reporting rules (Admin console > Reporting > Rules).

---

## 5. IDENTITY AND SECURITY

### 2-Step Verification (2SV)

2SV is the highest-impact single security control available. Configuration path: Admin console > Security > 2-step verification.

**Enforcement options:**
- Off (not enforced, users can opt in)
- On (enforced; new users have a grace period to enroll)
- Mandatory for admins only

**2SV methods (strongest to weakest):**
1. Hardware security keys (FIDO2/WebAuthn) — phishing-resistant
2. Passkeys — phishing-resistant, tied to device biometrics
3. Google Authenticator / TOTP apps — not phishing-resistant but strong
4. Google prompts (push notification to phone) — not phishing-resistant
5. SMS/voice codes — weakest; vulnerable to SIM swap

**Recommendation:** Enforce 2SV with security keys or passkeys for all users. For privileged accounts (super admins, admin roles), require enrollment in the Advanced Protection Program (APP).

### Advanced Protection Program (APP)

APP provides the highest level of account security for high-value targets. It enforces:
- Security key or passkey as the only 2SV method
- Stricter scrutiny of OAuth app approvals (only Google-approved apps allowed)
- Enhanced Gmail phishing and malware scanning
- Restricted data access in the event of suspicious sign-in

Admin can enroll users in APP: Admin console > Security > Advanced Protection Program.

### SSO with SAML (Identity Federation)

Google Workspace supports acting as either a SAML SP (service provider) or SAML IdP.

**Google as SP (third-party IdP like Entra ID or Okta authenticates users):**
1. Admin console > Security > Authentication > SSO with third-party IdP
2. Create a SAML SSO profile with the IdP's metadata URL or upload metadata XML
3. Configure the sign-on URL, sign-out URL, and verification certificate
4. Assign the profile to specific OUs or groups (multiple profiles supported — Enterprise)
5. Test with a non-admin account before enforcing

**Entra ID as IdP for Google Workspace:**
- In Entra ID: Add "Google Cloud / G Suite Connector" from the Enterprise app gallery
- Configure SAML attributes: Primary email → `user.mail`, First name → `user.givenname`, Last name → `user.surname`
- Entity ID: `google.com/a/yourdomain.com`
- ACS URL: `https://www.google.com/a/yourdomain.com/acs`

**Legacy SSO profiles are deprecated** (configured prior to 2023). Migrate to named SAML SSO profiles.

### Context-Aware Access (CAA)

CAA allows access policies based on device context, user identity, IP address, and geographic location. Requires Enterprise or Business Plus plan.

**Access levels define conditions:**
- Device is managed/enrolled
- Device is encrypted
- Operating system version minimum
- IP address is in corporate range
- User is in specific OU or group

**Apply to services:** Drive, Gmail, Google Cloud console, third-party SAML apps

**Combined with DLP (Enterprise):** A DLP rule can include a CAA condition so that, for example, Drive files containing PII can only be downloaded from managed, encrypted devices on the corporate network.

Configuration: Admin console > Security > Access and data control > Context-Aware Access

### Data Loss Prevention (DLP)

DLP rules scan content in Gmail and Drive for sensitive data patterns and trigger automated actions.

**Gmail DLP actions:**
- Quarantine message for admin review
- Block delivery and bounce to sender
- Warn sender before sending
- Add headers or modify routing
- BCC to audit address

**Drive DLP actions:**
- Block external sharing
- Warn user before sharing
- Revoke existing shares
- Audit log entry

**Built-in detectors (examples):**
- Credit card numbers (Visa, MasterCard, Amex, Discover)
- US Social Security Numbers
- US/UK passport numbers
- IBAN numbers
- HIPAA-related clinical terms
- Driver's license numbers (by state)

**Custom detectors:** Regular expressions with optional keyword proximity matching. Word lists for domain-specific terminology.

Configuration: Admin console > Security > Access and data control > Data protection

### Security Investigation Tool

Available on Enterprise Starter and above. Allows security admins to:
- Search across all audit log types with complex conditions
- Take bulk remedial actions (delete messages, revoke Drive access, suspend users)
- Build investigation workflows saved as named investigations
- Export investigation results

Configuration: Admin console > Security > Security center > Investigation tool

### BeyondCorp Enterprise Integration

BeyondCorp Enterprise (Chrome Enterprise Premium) extends CAA with:
- Browser-based device posture checks without MDM enrollment required
- Integration with third-party security vendors (CrowdStrike, Palo Alto Networks, etc.) for real-time device risk scoring
- URL filtering and malware protection in Chrome
- Data controls in Chrome (block copy/paste, print, screenshot for specific sites)

Google Workspace CAA and BeyondCorp CAA are distinct but complementary. BeyondCorp provides richer device signals via Chrome and can integrate with partner signals not available through basic MDM enrollment.

---

## 6. DIRECTORY SYNC

### Google Cloud Directory Sync (GCDS)

GCDS is a free tool from Google that reads from an on-premises Active Directory or LDAP directory and syncs user, group, and contact data to Google Workspace. GCDS does not sync passwords — authentication flows to AD/LDAP via SAML SSO.

**What GCDS syncs:**
- User accounts (create, update, suspend, delete)
- OU assignments (mapped from AD OU or attribute)
- Group memberships and email distribution lists
- Shared contacts (organization-wide directory entries)
- Nicknames and email aliases

**What GCDS does not sync:**
- Passwords (use SAML SSO for authentication)
- Google Workspace-specific settings per user
- Calendar resources

**GCDS architecture:**
1. Install GCDS on a Windows server with AD read access
2. Configure LDAP connection (server, port, bind credentials)
3. Map AD attributes to Google Workspace fields
4. Define exclusion rules (filter out service accounts, machine accounts)
5. Run a simulation (dry run) to preview changes
6. Schedule sync via Windows Task Scheduler (recommend: every 4 hours)

**Common GCDS issues:**
- `LDAP search returned too many results` — Add pagination or refine search filter
- `User suspend conflict` — User exists in Google but not in AD; check deletion rules
- `Group member does not exist in Google` — External email in AD group; configure "ignore external members" setting
- Sync log location: `C:\Program Files\Google\Google Apps Directory Sync\logs\`

### Entra ID (Azure AD) SCIM Provisioning

For organizations using Entra ID as the identity source, SCIM provisioning is an alternative to GCDS that pushes users from Entra to Google Workspace in near-real-time.

**Setup flow:**
1. In Google Admin console: Enable SCIM provisioning — Admin console > Security > Set up single sign-on (SSO) with a third-party IdP > User provisioning
2. Generate SCIM API token from Google Admin console
3. In Entra ID: Enterprise Applications > Google Cloud / G Suite Connector > Provisioning
4. Enter SCIM endpoint: `https://www.googleapis.com/auth/cloud-platform`
5. Configure attribute mapping (Entra user attributes → Google Workspace fields)
6. Enable provisioning; set scope (all users vs. assigned users)

**SCIM vs. GCDS comparison:**

| Factor | GCDS | Entra ID SCIM |
|---|---|---|
| Source | Active Directory / LDAP (on-prem) | Entra ID (cloud) |
| Sync direction | Pull from AD, push to Google | Push from Entra to Google |
| Latency | Scheduled (e.g., every 4 hours) | Near-real-time (within minutes) |
| OU mapping | Yes (via LDAP attribute) | Limited (via group assignment) |
| Tool hosted | On-premises server required | Entra cloud service |
| Password sync | Not supported (use SAML) | Not supported (use SAML) |

### Google Workspace Migrate

Google Workspace Migrate is a server-based migration tool for large-scale migrations. It can migrate:
- Email from Exchange, Office 365, IMAP servers, and other sources
- Calendar and contacts from Exchange / Office 365
- Files from OneDrive and SharePoint (unique capability vs. other tools)
- Google Drive to Google Drive migrations (e.g., reorganizing between accounts)

Workspace Migrate requires a dedicated Windows Server VM (8 vCPU, 32 GB RAM recommended for large migrations).

---

## 7. APIS AND AUTOMATION

### Admin SDK

The Admin SDK is the primary API for programmatic Google Workspace administration. Key sub-APIs:

| Sub-API | Scope | Key Operations |
|---|---|---|
| Directory API | Users, groups, OUs, devices | CRUD users, group membership, device management |
| Reports API | Audit logs, usage reports | Pull login events, Drive events, admin actions |
| Reseller API | Reseller operations | Manage customer subscriptions |
| License Manager API | License assignment | Assign/revoke SKU licenses per user |
| Groups Settings API | Group configuration | Configure group policies beyond basic Admin SDK |

**Authentication:** Admin SDK requires a service account with domain-wide delegation (DWD) or an admin OAuth flow. Service accounts use JSON key files and impersonate an admin account.

**Directory API example — list users:**
```
GET https://admin.googleapis.com/admin/directory/v1/users?domain=example.com&maxResults=500&orderBy=email
Authorization: Bearer {access_token}
```

**Directory API example — create user:**
```json
POST https://admin.googleapis.com/admin/directory/v1/users
{
  "primaryEmail": "jdoe@example.com",
  "name": { "givenName": "Jane", "familyName": "Doe" },
  "password": "TempPass123!",
  "changePasswordAtNextLogin": true,
  "orgUnitPath": "/Employees/Engineering"
}
```

### Gmail API

The Gmail API provides access to individual mailboxes with user-level OAuth or service account DWD.

**Common operations:**
- `users.messages.list` — List messages matching a query
- `users.messages.get` — Retrieve full message with headers and body
- `users.messages.send` — Send email on behalf of user
- `users.messages.modify` — Add/remove labels
- `users.labels.list` — List all labels
- `users.settings.filters.create` — Create filter rules

**Gmail API example — search messages:**
```
GET https://gmail.googleapis.com/gmail/v1/users/jdoe@example.com/messages?q=from:external@partner.com+after:2026/01/01
Authorization: Bearer {user_access_token}
```

### Drive API

Provides file, folder, and permission management.

**Common operations:**
- `files.list` — Search files with query syntax
- `files.create` — Upload or create files/folders
- `files.get` — Retrieve file metadata
- `permissions.create` — Share file with a user or group
- `drives.list` — List Shared Drives (requires `drive` scope)

**Drive API file search example:**
```
GET https://www.googleapis.com/drive/v3/files?q=mimeType='application/vnd.google-apps.spreadsheet'+and+trashed=false&fields=files(id,name,owners)
Authorization: Bearer {access_token}
```

### Google Apps Script

Apps Script is a JavaScript-based scripting platform embedded in Google Workspace services. It runs in Google's cloud and does not require local infrastructure.

**Triggers:**
- Time-driven (e.g., run daily at 9 AM)
- Event-driven (e.g., on form submit, on spreadsheet edit, on calendar event creation)
- Web app triggers (HTTP GET/POST endpoint)

**Apps Script example — send weekly report from Sheet:**
```javascript
function sendWeeklyReport() {
  const sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName("Report");
  const data = sheet.getDataRange().getValues();
  const body = data.map(row => row.join("\t")).join("\n");
  GmailApp.sendEmail(
    "manager@example.com",
    "Weekly Report - " + new Date().toDateString(),
    body
  );
}
```

**Apps Script example — provision users from a Sheet:**
```javascript
function provisionUsers() {
  const sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName("New Users");
  const rows = sheet.getDataRange().getValues().slice(1); // skip header
  rows.forEach(row => {
    const [email, firstName, lastName, orgUnit] = row;
    AdminDirectory.Users.insert({
      primaryEmail: email,
      name: { givenName: firstName, familyName: lastName },
      password: "WelcomeTemp2026!",
      changePasswordAtNextLogin: true,
      orgUnitPath: orgUnit
    });
  });
}
```

### GAM (Google Apps Manager)

GAM is the most widely used open-source command-line tool for Google Workspace admins. Available at https://github.com/GAM-team/GAM. GAMADV-XTD3 (community fork) provides extended functionality; it has been superseded by GAM7 which merges both codebases.

**Setup requirements:**
1. Python 3.x (for older GAM) or precompiled binary (GAM7)
2. Google Cloud project with Admin SDK enabled
3. OAuth credentials (installed app) or service account with DWD

**User management commands:**
```bash
# Create a user
gam create user jdoe@example.com firstname Jane lastname Doe \
    password TempPass123 changepassword on org "/Employees/Engineering"

# Update user OU
gam update user jdoe@example.com org "/Contractors"

# Suspend user
gam update user jdoe@example.com suspended on

# Restore deleted user (within 20 days)
gam undelete user jdoe@example.com

# List all users with OU and last login
gam print users allfields todrive

# Bulk create from CSV
gam csv new_users.csv gam create user ~primaryEmail firstname ~givenName \
    lastname ~familyName password ~password org ~orgUnitPath changepassword on
```

**License management:**
```bash
# List all license assignments
gam print licenses

# Assign Business Standard license to user
gam user jdoe@example.com add license Google-Apps-For-Business

# Remove license (returns to unlicensed state)
gam user jdoe@example.com delete license Google-Apps-For-Business

# Bulk assign licenses from CSV
gam csv users.csv gam user ~email add license Google-Apps-Standard
```

**Group management:**
```bash
# Create group
gam create group engineering@example.com name "Engineering Team" description "All engineering staff"

# Add member
gam update group engineering@example.com add member jdoe@example.com

# List group members
gam print group-members group engineering@example.com

# Export all groups and members to Drive
gam print groups allfields members owners managers todrive
```

**Drive management:**
```bash
# List Shared Drives
gam print teamdrives

# Add member to Shared Drive
gam add drivefileacl teamdrive "Marketing" user jdoe@example.com role organizer

# Transfer file ownership (My Drive)
gam user old@example.com transfer drive new@example.com

# Search files owned by specific user
gam user jdoe@example.com print filelist query "trashed=false" fields id,name,mimeType todrive
```

**Audit and reporting:**
```bash
# Show user login activity
gam user jdoe@example.com show events admin

# Export admin audit log
gam report admin start 2026-01-01 todrive

# Show 2SV enrollment status for all users
gam print users fields primaryEmail,isEnrolledIn2Sv,isEnforcedIn2Sv todrive

# Show OAuth token grants
gam print tokens todrive
```

### Google Workspace Terraform Provider

The `hashicorp/googleworkspace` Terraform provider manages users, groups, and OUs as infrastructure as code.

**Example: manage users and group membership:**
```hcl
resource "googleworkspace_user" "jane_doe" {
  primary_email = "jdoe@example.com"
  name {
    given_name  = "Jane"
    family_name = "Doe"
  }
  org_unit_path = "/Employees/Engineering"
  password      = var.temp_password
  change_password_at_next_login = true
}

resource "googleworkspace_group" "engineering" {
  email       = "engineering@example.com"
  name        = "Engineering Team"
  description = "All engineers"
}

resource "googleworkspace_group_member" "jane_engineering" {
  group_id = googleworkspace_group.engineering.id
  email    = googleworkspace_user.jane_doe.primary_email
  role     = "MEMBER"
}
```

**Benefits:** Version-controlled identity management, peer-reviewed changes via pull requests, audit trail via git history, reproducible environments, SOC 2 / ISO 27001 aligned change management.

### Google Workspace Studio (Workspace Flows)

Launched at Google Next 2025, generally available in 2026 with all Business and Enterprise plans. A no-code/low-code workflow automation builder powered by Gemini AI.

**Built-in integrations at launch:** Slack, Salesforce, Jira, HubSpot, and Google Workspace apps  
**Example workflows:** Create Jira issue from Gmail bug report, add Salesforce lead from Google Form response, summarize Drive document and send via Chat.

---

## 8. EMAIL ROUTING

### Delivery Models

**Direct delivery (standard):** MX records point to Google. All inbound mail delivered directly to Gmail.

**Split delivery:** MX records point to Google. Gmail routes messages for specific users/domains to an external mail system. Used during migrations or when some users remain on legacy systems.

- Configuration: Admin console > Apps > Google Workspace > Gmail > Advanced settings > Routing > Configure split delivery
- Specify the non-Gmail mail server hostname and which users route to it (by OU or user list)
- All inbound mail hits Google first for scanning before forwarding

**Dual delivery:** Each message delivered to two inboxes simultaneously — Gmail and a secondary server.

- Primary server (Google) delivers to Gmail; copies forwarded to secondary
- Useful for compliance monitoring or migration validation
- Configure via Default routing in Gmail advanced settings

### MX Record Configuration (2026)

**Simplified single-record setup (new domains/migrations since 2023):**
```
@ MX 1 smtp.google.com
```

**Traditional multi-record setup (legacy, still supported):**
```
@ MX 1  aspmx.l.google.com
@ MX 5  alt1.aspmx.l.google.com
@ MX 5  alt2.aspmx.l.google.com
@ MX 10 alt3.aspmx.l.google.com
@ MX 10 alt4.aspmx.l.google.com
```

Both configurations route to the same Gmail infrastructure. New setups should use the single-record format.

### Email Authentication (SPF, DKIM, DMARC)

**SPF:** Add Google's mail servers to your domain's SPF record:
```
v=spf1 include:_spf.google.com ~all
```

**DKIM:** Generate 2048-bit key in Admin console > Apps > Gmail > Authenticate email. Publish the provided TXT record. Key rotation recommended annually.

**DMARC:** Publish policy after SPF and DKIM are validated:
```
v=DMARC1; p=quarantine; rua=mailto:dmarc-reports@example.com; pct=100
```

Progression: p=none (monitoring) → p=quarantine → p=reject

### Inbound Gateway and Email Routing Rules

**Inbound gateway:** If a third-party spam filter sits in front of Google (pre-filtering), register its IP ranges as an inbound gateway so Google doesn't re-score it: Admin console > Gmail > Advanced settings > Inbound gateway.

**Routing rules (Admin console > Gmail > Routing):**
- Add header to messages from specific senders
- Route by sender domain to specific internal users
- Reject messages from specific senders
- Strip attachments and replace with Drive links (requires Enterprise with DLP)

---

## 9. MIGRATION

### M365 / Exchange to Google Workspace Migration

**Tool selection:**

| Scenario | Recommended Tool |
|---|---|
| 1-20 users, self-service | GWMMO (Google Workspace Migration for Microsoft Outlook) |
| 21-200 users, admin-driven, mail/calendar/contacts only | GWMME (Google Workspace Migration for Microsoft Exchange) |
| Any size, includes OneDrive/SharePoint/files | Google Workspace Migrate |
| Large enterprise, complex cutover | Third-party: CloudM, BitTitan MigrationWiz, Quest On Demand |

**Migration phases:**
1. **Assess:** Inventory mailbox sizes, permissions, distribution lists, public folders
2. **Provision:** Create Google Workspace accounts, configure OUs, set up SSO
3. **Pre-migration:** Sync historical data (email older than 30 days) while users still on M365
4. **Cutover planning:** Change MX records, set GWSMO for any Outlook users
5. **Cutover:** Switch MX, redirect Autodiscover, migrate recent data delta
6. **Post-migration:** Monitor, support, decommission legacy infrastructure

**Coexistence during migration:**
- Split delivery routes specific users to M365 while others are on Gmail
- Calendar sharing via CalDAV federation or meeting migration scripts
- Maintain dual SMTP send-as during transition

**Timeline estimates:**
- 1-10 users: Weekend
- 10-50 users: 1-2 weeks (run in parallel)
- 50-200 users: 2-4 weeks (phased by department)
- 200+ users: 1-6 months (enterprise cutover planning)

### On-Prem to Google Workspace (Non-Exchange)

**IMAP migration:** Admin console > Data migration > Email. Supports IMAP servers (Dovecot, Postfix, Zimbra, Lotus Notes via IMAP bridge). Migrates inbox and folders; calendar and contacts require separate tools.

**PST import:** GWMMO can import PST files directly into Gmail. No server required but must run on each user's workstation.

### Google Workspace Migrate — Key Details

- Deployed as Windows Server VM (recommended: Windows Server 2019, 8 vCPU, 32 GB RAM)
- Requires a service account with delegated access to both source and destination
- Supports incremental sync (run migration, update deltas until cutover)
- Can migrate Drive file sharing permissions (ACLs) — critical for Shared Drive migrations
- Post-migration: Users' Google Drive files appear in "My Drive" or Shared Drives as configured

---

## 10. DIAGNOSTICS AND TROUBLESHOOTING

### Email Log Search (ELS)

The primary tool for tracing email delivery problems.

Navigation: Admin console > Reporting > Email log search

**Search parameters:** Sender, recipient, subject, date range, message ID

**ELS results show:** Each SMTP hop, delivery status, spam classification, policy checks applied

**Common delivery issues diagnosed via ELS:**

| Symptom | What to Look For in ELS |
|---|---|
| Email not received | Check if delivered to spam/quarantine; check if DLP rule triggered |
| Delayed email | Check queued status; note timestamps between hops |
| Email bounced to sender | Look for `550 5.1.1 user unknown` or policy bounce |
| Email stuck in outbound queue | Check for SPF/DKIM failures; check recipient MX records |
| Email marked spam incorrectly | Note spam score; use "Report as not spam" to train filter |

**Common SMTP error codes in ELS:**
- `421 4.7.0` — Temporary service unavailable; retry expected
- `450 4.2.1` — Mailbox temporarily unavailable
- `550 5.1.1` — Recipient does not exist
- `550 5.7.1` — Policy rejection (e.g., spam, DMARC failure)
- `552 5.3.4` — Message too large (Gmail limit: 25 MB per message)

### Login and Authentication Issues

**User cannot sign in:**
1. Check if account is suspended: Admin console > Directory > Users > user status
2. Check if 2SV is required but not enrolled: Security > 2-step verification > enrolled status
3. Check if SSO is misconfigured: Test IdP-initiated and SP-initiated flows separately
4. Check login audit log for specific error: Admin console > Reporting > Audit > Login

**Login audit log error codes:**
- `LOGIN_FAILURE` — Incorrect password
- `LOGIN_CHALLENGE` — 2SV required but not provided
- `SUSPICIOUS_LOGIN_BLOCKED` — Google blocked login as suspicious
- `ACCOUNT_DISABLED` — Account suspended
- `REAUTH_REQUIRED` — Session expired; re-authentication needed

**Google Workspace Sync for Outlook (GWSMO) issues:**
- Verify GWSMO is enabled: Admin console > Apps > Google Workspace > Google Workspace Sync
- Clear Windows Credential Manager entries for Google
- Reinstall latest GWSMO version
- Check proxy/firewall allows access to `oauth2.googleapis.com`, `clients4.google.com`

### Drive Sharing Issues

**User cannot share a file:**
- Check OU-level sharing settings: Admin console > Apps > Drive and Docs > Sharing settings
- Check if trust rules restrict the intended recipient domain
- Check if DLP rule is blocking the share action (look in Reports > Rules audit)

**User cannot access Shared Drive:**
- Verify membership: Shared Drive > Manage members
- Check if Shared Drive sharing is restricted by admin policy
- Check if user's OU has Shared Drive access enabled

**Common Drive error messages:**
- `You don't have permission to access this item` — Not shared with user; no organization access
- `You can't share this item. It's in a shared drive with restricted sharing` — Shared Drive-level policy blocks external sharing
- `Item can't be uploaded: Storage quota exceeded` — Shared Drive or user quota full
- `Shared drive membership limit reached` — Shared Drive has 100 members; remove someone first

### Drive for Desktop Sync Problems

**Sync not working:**
1. Check application is running (system tray icon)
2. Sign out and sign back in within Drive for Desktop
3. Check available local disk space (low disk space pauses sync)
4. Check firewall allows `*.googleapis.com` and `commondatastorage.googleapis.com`
5. Review sync errors in: Drive for Desktop > gear icon > View sync issues
6. Check application log: `%LOCALAPPDATA%\Google\DriveFS\Logs\` (Windows)

**Files stuck in "Lost and Found" folder:** Drive for Desktop cannot upload due to permissions, network error, or filename incompatibility. Resolve the issue and manually re-upload from Lost and Found.

**Conflict files:** If a file is edited on multiple devices while offline, Drive creates conflict copies named `filename (1).ext`. Review and consolidate manually.

### Admin Audit Log Investigation

Navigation: Admin console > Reporting > Audit

**Useful audit searches:**

| Investigation | Audit Log Type | Filter |
|---|---|---|
| Who deleted a user? | Admin | Event: Delete User |
| Who granted super admin? | Admin | Event: Assign Role |
| Who changed sharing policy? | Admin | Event: Change Application Setting |
| Who accessed a Drive file? | Drive | Event: View |
| What apps have OAuth access? | Token | Event: Authorize |
| Failed logins for a user | Login | Event: Login Failure |

**Cloud Logging integration:** Google Workspace audit logs can be exported to Cloud Logging for long-term retention (beyond the 6-month Admin console retention window), SIEM integration, and custom alerting via Cloud Monitoring.

```
gcloud logging sinks create workspace-audit-sink \
  storage.googleapis.com/my-audit-bucket \
  --log-filter='logName:"cloudaudit.googleapis.com"'
```

### GCDS Sync Troubleshooting

**Check sync log:** `C:\Program Files\Google\Google Apps Directory Sync\logs\sync_log.0`

**Common GCDS errors:**

| Error Message | Likely Cause | Resolution |
|---|---|---|
| `javax.naming.CommunicationException` | Cannot connect to LDAP server | Check hostname, port 389/636, firewall rules |
| `LDAP: error code 49` | LDAP bind failed | Wrong username or password for bind account |
| `Error: user not found in Google` | OU exclusion rule filtering out user | Review exclusion rules in GCDS config |
| `Conflict: primary email already exists` | Email address conflict between AD accounts | Deduplicate in AD or add exclusion for the conflicting account |
| `Dry run completed with 0 changes` | Mapping not matching any AD objects | Verify LDAP search base and filter |

---

## 11. BEST PRACTICES SUMMARY

### OU Structure Design

1. Mirror stable organizational attributes (department, employment type), not projects
2. Separate user OUs and device OUs at the root level
3. Keep the OU hierarchy no deeper than 4-5 levels to reduce management complexity
4. Use groups for dynamic, cross-OU access control
5. Apply the most permissive settings at the root; restrict in child OUs

### Shared Drive Governance

1. One Shared Drive per team or functional area; avoid mega-drives with thousands of items
2. Manage Shared Drive membership via Google Groups (add/remove the group, not individuals)
3. Apply Shared Drive creation restrictions: Admin console > Drive and Docs > Sharing settings > Shared drive creation (restrict to specific OUs or disable for end users)
4. Name convention: `[Department] - [Team/Purpose]` (e.g., `Finance - AP AR`, `Engineering - Platform`)
5. Audit Shared Drive membership quarterly using: `gam print teamdrives fields id,name,members todrive`
6. Set "Prevent people outside [domain] from accessing files in shared drives" for all internal Shared Drives

### DLP Policy Design

1. Start in audit mode (log only, no block) to understand the data landscape before enforcing
2. Progress: audit → warn → block, validating false positive rates at each stage
3. Use specific detectors with proximity keywords to reduce false positives (e.g., SSN pattern + "social security" keyword within 50 characters)
4. Scope DLP rules to the most restrictive set of users who handle the data type
5. Test rules with sample content before production deployment
6. Review DLP trigger logs monthly: Admin console > Reporting > Audit > Rules

### Security Hardening Checklist

- [ ] Enforce 2SV with security key or passkey for all users
- [ ] Enroll super admins and privileged accounts in Advanced Protection Program
- [ ] Disable legacy app access (Admin console > Security > Less secure apps)
- [ ] Configure SPF, DKIM (2048-bit), and DMARC (p=reject goal)
- [ ] Enable advanced phishing and malware protection in Gmail safety settings
- [ ] Restrict OAuth app access to admin-approved apps only
- [ ] Set external Drive sharing to trusted domains only (or off)
- [ ] Enable security alert emails for all critical alert types
- [ ] Review super admin accounts quarterly; minimize count to 3-5
- [ ] Set session duration policy (8-24 hours for most users)
- [ ] Export audit logs to Cloud Logging or SIEM for retention beyond 6 months

### Vault and Retention Policy Design

1. Create a default retention rule that covers all users for regulatory minimums (e.g., 7 years for financial records)
2. Create OU-specific rules for departments with different requirements (e.g., HR: 10 years, Sales: 5 years)
3. Place legal holds on specific custodians immediately upon litigation hold notice
4. Test Vault search and export quarterly to validate coverage
5. Assign dedicated Vault administrator role (not super admin) to limit access
6. Document retention schedule and tie rules to legal/compliance requirements

---

*Research compiled April 2026 from Google Workspace Help Center, Google Cloud documentation, GAM GitHub wiki, and current practitioner sources.*
