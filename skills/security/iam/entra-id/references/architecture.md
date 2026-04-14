# Entra ID Architecture

Deep technical reference for Microsoft Entra ID internals, authentication flows, and integration patterns.

---

## Tenant Model

### Tenant Fundamentals

An Entra ID tenant is an isolated instance of the directory:
- **Isolation boundary** -- Each tenant is fully isolated. No data leakage between tenants.
- **Object limit** -- 50,000 objects by default (extendable to 300,000+ with custom domain verification, or unlimited with P1/P2)
- **Multi-geo** -- Tenant data location determined at creation. Data residency options for EU, US, and other regions.
- **Initial domain** -- `<tenantname>.onmicrosoft.com` (cannot be changed after creation)
- **Tenant ID** -- Immutable GUID assigned at creation

### Object Types

| Object | Description | Key Properties |
|---|---|---|
| User | Human identity or service identity | UPN, mail, displayName, department, manager |
| Group | Security group or Microsoft 365 group | Membership type (assigned, dynamic), mail-enabled |
| Device | Registered, joined, or hybrid-joined device | OS, compliance state, last sign-in |
| Application (registration) | App definition (client ID, permissions) | Redirect URIs, certificates, secrets, API permissions |
| Service Principal | App instance in the tenant | Assigned users/groups, CA policy target |
| Administrative Unit | Delegation boundary | Scoped role assignments |
| Conditional Access Policy | Access policy | Conditions, grant/session controls |

### Administrative Units

Administrative Units (AUs) provide scoped delegation:
- Assign directory roles (User Admin, Helpdesk Admin, etc.) scoped to an AU
- Users and groups can be members of AUs
- AUs support dynamic membership rules (P1 license)
- Restricted management AUs prevent tenant-level admins from managing AU members

---

## Authentication Flows

### Cloud-Only Authentication

```
Client --> Entra ID /authorize
  |-- Entra ID evaluates Conditional Access
  |-- Entra ID checks Identity Protection risk
  |-- MFA challenge if required
  |-- Entra ID issues tokens (ID token, access token, refresh token)
  |-- Client accesses resource with access token
```

### Hybrid Authentication with PHS

```
Client --> Entra ID /authorize
  |-- Entra ID looks up user in directory
  |-- Entra ID validates password against synced hash (hash of hash)
  |-- Conditional Access evaluation
  |-- MFA challenge if required
  |-- Tokens issued
```

Password Hash Sync: Entra Connect syncs a SHA-256 hash of the MD4 hash of the password. The original password never leaves on-premises. Sync interval: every 2 minutes.

### Hybrid Authentication with PTA

```
Client --> Entra ID /authorize
  |-- Entra ID encrypts credentials with PTA agent's public key
  |-- Entra ID queues encrypted credentials for PTA agent
  |-- PTA agent (on-premises) picks up request, decrypts, validates against AD
  |-- PTA agent returns success/failure to Entra ID
  |-- Tokens issued if successful
```

PTA agents maintain persistent outbound connections to Entra ID (no inbound firewall rules needed). Deploy 3+ agents for HA.

### Seamless SSO (Desktop SSO)

For domain-joined devices using PHS or PTA:
1. Entra ID returns a 302 redirect to `https://autologon.microsoftazuread-sso.com`
2. Client's browser sends a Kerberos ticket (obtained from AD via computer account `AZUREADSSOACC$`)
3. Entra ID validates the Kerberos ticket
4. User is silently authenticated (no password prompt)

---

## Token Architecture

### Token Types

| Token | Format | Lifetime | Storage |
|---|---|---|---|
| **ID Token** | JWT | 1 hour (not configurable) | In-memory (SPA) or session cookie (web app) |
| **Access Token** | JWT (v1 or v2) | Default 60-90 min (configurable via token lifetime policy) | In-memory or cache |
| **Refresh Token** | Opaque | 90 days (sliding window, revoked on password change) | Secure storage (MSAL cache) |
| **Primary Refresh Token (PRT)** | Opaque | 14 days | Device-bound, TPM-protected |

### Primary Refresh Token (PRT)

The PRT is a special token for device SSO:
- Obtained during device join/registration or user sign-in on a joined device
- Contains device claims (deviceId, deviceCompliance)
- Enables SSO to all applications without re-authentication
- Protected by TPM when available (device-bound)
- Used by the CloudAP and WAM broker on Windows

**PRT refresh:** The PRT is refreshed every 4 hours during an active session. It contains the user's most recent MFA claim.

### Continuous Access Evaluation (CAE)

CAE enables near-real-time token revocation:
- Resource providers (Exchange, SharePoint, Teams, Graph) subscribe to critical events from Entra ID
- Events: user disabled, password changed, MFA requirement added, admin revoke
- Resource provider rejects current access tokens when critical events occur
- CAE-capable tokens have a 24-hour lifetime (instead of 60-90 min) but can be revoked instantly

---

## Directory Synchronization

### Entra Connect Architecture

```
On-Premises AD --> Entra Connect Server --> Entra ID
                      |
                      |-- Sync Engine (ADSync)
                      |-- SQL LocalDB (or full SQL)
                      |-- Connectors (AD, Entra ID)
                      |-- Rules Engine (sync rules)
```

**Sync cycle:** Every 30 minutes (default). Delta sync processes only changes. Full sync processes all objects (triggered manually or by rule changes).

### Filtering and Scoping

| Filter Type | Method | Example |
|---|---|---|
| Domain-based | Select specific AD domains | Sync only `corp.example.com`, not `test.example.com` |
| OU-based | Select specific OUs | Sync only `OU=Users,DC=corp,DC=example,DC=com` |
| Attribute-based | Sync rules with conditions | Sync only where `department` is not null |
| Group-based | Pilot sync via group membership | Sync only members of `EntraID-Sync-Pilot` group |

### Source Anchor

The source anchor is the immutable identifier linking on-prem AD objects to Entra ID objects:
- **Default:** `ms-DS-ConsistencyGuid` (populated from `objectGUID` on first sync)
- **Legacy:** `objectGUID` (direct use, older deployments)
- **Cannot be changed** after initial sync without recreating the object

### Cloud Sync vs. Entra Connect

| Capability | Entra Connect | Cloud Sync |
|---|---|---|
| Architecture | On-premises server | Lightweight cloud-managed agent |
| Multi-forest | Supported (complex) | Supported (simplified) |
| Filtering | OU, domain, attribute, group | OU, attribute |
| Password writeback | Supported | Supported |
| Device writeback | Supported | Not supported |
| Exchange hybrid | Supported | Limited |
| Custom sync rules | Full rule editor | Scoping filters, attribute mapping |
| HA | Staging server | Multiple agents (active-active) |

---

## Graph API Patterns

### Key Endpoints for IAM

```
# Users
GET /users/{id}
POST /users (create)
PATCH /users/{id} (update)

# Groups
GET /groups/{id}/members
POST /groups/{id}/members/$ref (add member)

# Applications
GET /applications (app registrations)
GET /servicePrincipals (enterprise apps)

# Conditional Access
GET /identity/conditionalAccess/policies
POST /identity/conditionalAccess/policies

# PIM
POST /roleManagement/directory/roleAssignmentScheduleRequests (activate role)
GET /roleManagement/directory/roleEligibilityScheduleInstances

# Sign-in logs
GET /auditLogs/signIns
GET /auditLogs/directoryAudits

# Identity Protection
GET /identityProtection/riskyUsers
GET /identityProtection/riskDetections
```

### Permissions Model

| Permission | Type | Use Case |
|---|---|---|
| `User.Read.All` | Application | Read all user profiles |
| `Directory.Read.All` | Application | Read directory objects |
| `Policy.Read.All` | Application | Read CA policies |
| `RoleManagement.ReadWrite.Directory` | Application | Manage PIM role assignments |
| `IdentityRiskyUser.Read.All` | Application | Read risky user data |
| `AuditLog.Read.All` | Application | Read sign-in and audit logs |

**Permission types:**
- **Delegated:** Acts on behalf of a signed-in user. User must consent (or admin consent).
- **Application:** Acts as the application itself. Requires admin consent. No user context.

---

## Licensing Tiers

| Feature | Free | P1 | P2 | Governance |
|---|---|---|---|---|
| SSO (unlimited apps) | Yes | Yes | Yes | Yes |
| MFA (security defaults) | Yes | Yes | Yes | Yes |
| Conditional Access | No | Yes | Yes | Yes |
| PIM | No | No | Yes | Yes |
| Identity Protection | No | No | Yes | Yes |
| Access Reviews | No | No | Yes | Yes |
| Entitlement Management | No | No | Yes | Yes |
| Lifecycle Workflows | No | No | No | Yes |
| Dynamic Groups | No | Yes | Yes | Yes |
| Application Proxy | No | Yes | Yes | Yes |
| Entra Connect Health | No | Yes | Yes | Yes |
| Self-Service Password Reset | Limited | Yes | Yes | Yes |
| Password Writeback | No | Yes | Yes | Yes |
