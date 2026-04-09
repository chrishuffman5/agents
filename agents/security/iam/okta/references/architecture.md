# Okta Architecture

Deep technical reference for Okta platform internals, integration patterns, and infrastructure.

---

## Platform Architecture

### Multi-Tenant Cloud Service

Okta operates as a multi-tenant SaaS platform:
- **Cell architecture** -- Each Okta org is assigned to a cell (isolated infrastructure cluster)
- **Org URL** -- `https://<subdomain>.okta.com` or custom domain `https://id.company.com`
- **Data isolation** -- Each org's data is logically isolated within the cell
- **High availability** -- Active-active across multiple data centers within a cell
- **Preview/Production** -- Preview cells (`*.oktapreview.com`) receive features before production cells

### Agent Architecture

Okta agents enable hybrid connectivity between Okta cloud and on-premises infrastructure:

| Agent | Purpose | Protocol | Deployment |
|---|---|---|---|
| **AD Agent** | Sync AD users/groups to Okta, delegated authentication | Outbound HTTPS (443) | On-premises, 2+ for HA |
| **LDAP Agent** | Sync LDAP directories to Okta | Outbound HTTPS (443) | On-premises, 2+ for HA |
| **RADIUS Agent** | RADIUS authentication (VPN, Wi-Fi, network access) | Inbound UDP (1812/1813) + Outbound HTTPS | On-premises or DMZ |
| **IWA Agent** | Integrated Windows Authentication (desktop SSO) | Inbound HTTP + Outbound HTTPS | On-premises, domain-joined |
| **Okta On-Prem MFA Agent** | MFA for on-premises apps (RADIUS/IWA) | Outbound HTTPS | On-premises |

**AD Agent details:**
- Communicates with Okta cloud via outbound HTTPS only (no inbound firewall rules)
- Polls Okta for authentication requests (delegated auth mode) or imports users (sync mode)
- Supports multiple AD forests/domains per Okta org
- Service account needs only read access (plus password reset if using password sync)
- Install 2+ agents per domain for high availability (active-passive)

---

## Universal Directory Data Model

### User Profile

Okta's user profile has two layers:
- **Okta user profile** -- Base profile with standard and custom attributes
- **Application user profiles** -- Per-app profiles with app-specific attributes

**Standard attributes:**
- `login` (unique, typically email)
- `email`, `firstName`, `lastName`, `displayName`
- `mobilePhone`, `primaryPhone`
- `department`, `title`, `manager`, `organization`
- `status` (STAGED, PROVISIONED, ACTIVE, PASSWORD_EXPIRED, LOCKED_OUT, RECOVERY, SUSPENDED, DEPROVISIONED)

**Custom attributes:**
- Added via Admin Console or API
- Types: string, number, boolean, array of strings, integer
- Can be used in group rules, profile mappings, and Workflows

### Profile Mastering

Profile mastering defines the authoritative source for each attribute:

```
Attribute: department
  Master: Workday (HR system)
  
Attribute: phoneNumber
  Master: Okta (self-service update)
  
Attribute: samAccountName
  Master: Active Directory
```

**Master priority (when multiple sources):**
1. Application masters (HR, AD, LDAP) take priority over Okta
2. Among application masters, priority is configurable
3. Okta-mastered attributes can be edited by users (self-service) or admins

### Group Types

| Group Type | Source | Use Case |
|---|---|---|
| Okta group | Manually managed in Okta | Static group assignments |
| Dynamic (Okta rule) | Automated via expression rules | Auto-membership based on profile attributes |
| AD group | Synced from Active Directory | Mirror AD group structure |
| LDAP group | Synced from LDAP directory | Mirror LDAP groups |
| App group | Pushed from application | Application-defined groups |

---

## OIN Integration Patterns

### SAML 2.0 Integration

Most OIN apps use SAML 2.0:

**Okta as IdP (SP-initiated):**
```
User clicks app in Okta dashboard or navigates to app URL
  --> SP redirects to Okta SAML endpoint
  --> Okta authenticates user (if not already)
  --> Okta generates SAML Assertion with configured attributes
  --> User is POST-redirected to SP's ACS URL
  --> SP validates assertion, creates session
```

**Key SAML configuration:**
- **Entity ID** -- Unique identifier for the SP (typically a URL)
- **ACS URL** -- Where Okta sends the SAML response
- **Name ID** -- User identifier in the assertion (email, Okta username, custom)
- **Attribute statements** -- Additional claims (groups, department, custom attributes)
- **Signing** -- Assertions signed with Okta's app-specific certificate

### OIDC Integration

Modern apps typically use OIDC:

**Configuration:**
- **Client ID / Client Secret** -- Application credentials
- **Redirect URIs** -- Allowed callback URLs
- **Grant types** -- Authorization code (with PKCE), client credentials, device code, implicit (deprecated)
- **Scopes** -- openid, profile, email, address, phone, offline_access, custom scopes
- **Token configuration** -- Access token lifetime, refresh token rotation

### SCIM 2.0 Provisioning

**Supported SCIM operations:**

| Operation | Okta Action | SCIM Request |
|---|---|---|
| User create | User assigned to app | POST /Users |
| User update | Profile attribute changes | PATCH /Users/{id} |
| User deactivate | User unassigned from app | PATCH /Users/{id} (active: false) |
| Group push | Okta group pushed to app | POST /Groups |
| Group membership | User added/removed from pushed group | PATCH /Groups/{id} |
| Import users | Pull users from app to Okta | GET /Users (with pagination) |

---

## Event Hooks and Inline Hooks

### Event Hooks

Asynchronous webhooks triggered by Okta events:
- Fire-and-forget (Okta does not wait for response)
- Use for notifications, logging, external system updates
- Events: user.lifecycle.create, user.session.start, etc.
- Delivery guarantee: at-least-once (idempotent handling required)

### Inline Hooks

Synchronous hooks that modify Okta's behavior in real-time:

| Hook Type | Trigger | Use Case |
|---|---|---|
| Token Inline Hook | Token issuance | Add custom claims to tokens based on external data |
| SAML Assertion Inline Hook | SAML assertion generation | Modify SAML attributes from external source |
| Import Inline Hook | User import from app/directory | Filter or transform imported users |
| Registration Inline Hook | Self-service registration | Custom validation during sign-up |
| Password Import Inline Hook | First login after migration | Validate password against legacy system |
| Telephony Inline Hook | SMS/voice MFA delivery | Use custom SMS/voice provider |

**Inline hook performance:**
- 3-second timeout (Okta cancels if hook does not respond)
- Fallback behavior configurable (proceed without hook or fail)
- Do not use for heavy processing -- respond quickly

---

## Rate Limits Reference

### Endpoint Categories

| Category | Rate Limit | Key Endpoints |
|---|---|---|
| Authentication | 600/minute | `/api/v1/authn`, `/api/v1/sessions` |
| User Management | 600/minute | `/api/v1/users` (CRUD operations) |
| App Management | 600/minute | `/api/v1/apps` |
| Group Management | 600/minute | `/api/v1/groups` |
| Token Issuance | 2400/minute | `/oauth2/*/v1/token` |
| System Log | 120/minute | `/api/v1/logs` |
| Event Hooks | 100,000/day | Outbound webhook delivery |

### Rate Limit Headers

```
X-Rate-Limit-Limit: 600          # Maximum requests per window
X-Rate-Limit-Remaining: 450      # Remaining requests in current window
X-Rate-Limit-Reset: 1712345678   # Unix timestamp when window resets
```

### Rate Limit Best Practices

- Implement exponential backoff with jitter on 429 responses
- Cache frequently accessed data (user profiles, group memberships)
- Use delta APIs (`/api/v1/logs?since=...`) instead of full scans
- Batch operations where possible (bulk user import)
- Monitor rate limit consumption in Okta System Log

---

## Okta Expression Language (OEL) Reference

### Common Expressions

```javascript
// String operations
String.len(source.login)
String.substringBefore(source.email, "@")
String.substringAfter(source.email, "@")
String.toUpperCase(source.department)
String.replace(source.login, " ", ".")

// Conditional logic
source.department == "Engineering" ? "eng-access" : "default-access"
source.userType == "Employee" ? true : false

// Array/group operations
Arrays.contains(source.groups, "Admins")
Arrays.toCsvString(source.groups)
Arrays.size(source.groups)

// Date operations
Time.now()
Time.fromWindowsToUnix(source.lastPasswordChange)

// Null handling
source.department != null ? source.department : "Unassigned"
```

### Group Rule Expressions

```javascript
// All users in Engineering department
user.department == "Engineering"

// Users in specific AD groups
isMemberOfGroupName("Domain Users")

// Combine conditions
user.department == "Engineering" AND user.office == "NYC"

// Regular expression matching
String.stringContains(user.email, "@company.com")
```

---

## Security Architecture

### Data Protection

- **Encryption at rest** -- AES-256 for all stored data
- **Encryption in transit** -- TLS 1.2+ for all communications
- **Key management** -- Okta-managed HSM for signing keys
- **Data residency** -- US, EU, Australia, Japan cell options
- **SOC 2 Type 2, ISO 27001, FedRAMP High** certified

### Session Security

- **Session cookie** -- HTTPOnly, Secure, SameSite attributes
- **Session binding** -- Optionally bind to client IP
- **Session revocation** -- Admin can revoke all sessions for a user
- **Idle timeout** -- Configurable per global session policy
- **Max session lifetime** -- Configurable (default: 1 day)

### Network Zones

Define trusted and untrusted networks:
- **IP zones** -- Specific IP ranges (corporate network, VPN egress)
- **Dynamic zones** -- Based on ASN, geolocation, or IP type (proxy, Tor)
- **Block list zones** -- Known malicious IPs
- Use in authentication policies: trusted zones may have relaxed MFA requirements
