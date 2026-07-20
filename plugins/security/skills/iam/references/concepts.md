# IAM Foundational Concepts

Deep technical reference for identity and access management protocols, patterns, and standards that apply across all IAM technologies.

---

## OpenID Connect (OIDC)

OIDC is an identity layer on top of OAuth 2.0. It answers "who is this user?" while OAuth 2.0 answers "what can this client do?"

### Authorization Code Flow with PKCE

The recommended flow for all client types (web apps, SPAs, native apps):

```
1. Client generates code_verifier (random string, 43-128 chars)
2. Client computes code_challenge = BASE64URL(SHA256(code_verifier))
3. Client redirects user to /authorize with:
   - response_type=code
   - client_id
   - redirect_uri
   - scope=openid profile email
   - code_challenge
   - code_challenge_method=S256
   - state (CSRF protection)
   - nonce (replay protection)
4. User authenticates at IdP
5. IdP redirects to redirect_uri with authorization code
6. Client exchanges code + code_verifier at /token endpoint
7. IdP validates code_challenge against code_verifier
8. IdP returns: access_token, id_token, refresh_token
```

### ID Token Structure (JWT)

```json
{
  "iss": "https://idp.example.com",     // Issuer
  "sub": "user123",                       // Subject (unique user ID)
  "aud": "client_app_id",                // Audience (client ID)
  "exp": 1712345678,                     // Expiration
  "iat": 1712342078,                     // Issued at
  "nonce": "abc123",                     // Replay protection
  "auth_time": 1712342000,              // When user authenticated
  "acr": "urn:mace:incommon:iap:silver", // Authentication context class
  "amr": ["pwd", "mfa"],                // Authentication methods
  "azp": "client_app_id",               // Authorized party
  "at_hash": "..."                       // Access token hash
}
```

**Validation checklist:**
1. Verify JWT signature against IdP's JWKS (/.well-known/jwks.json)
2. Check `iss` matches expected IdP
3. Check `aud` contains your client_id
4. Check `exp` > current time
5. Check `nonce` matches what you sent
6. Check `iat` is within acceptable window

### Client Credentials Flow

Machine-to-machine (no user involved):

```
POST /token
  grant_type=client_credentials
  client_id=...
  client_secret=...  (or client assertion JWT for private_key_jwt)
  scope=api://resource/.default
```

Returns access_token only. No id_token (no user). No refresh_token.

### Discovery and JWKS

Every OIDC provider exposes `/.well-known/openid-configuration`:
- `authorization_endpoint` -- where to send users to authenticate
- `token_endpoint` -- where to exchange codes for tokens
- `jwks_uri` -- public keys for verifying token signatures
- `userinfo_endpoint` -- get additional user claims
- `scopes_supported` -- available scopes (openid, profile, email, etc.)
- `response_types_supported` -- supported flows
- `claims_supported` -- available claims

---

## SAML 2.0

Security Assertion Markup Language. XML-based federation protocol for enterprise SSO.

### SP-Initiated Flow

```
1. User visits Service Provider (SP)
2. SP generates AuthnRequest (XML, optionally signed)
3. SP redirects user to IdP SSO URL with AuthnRequest (HTTP-Redirect or HTTP-POST binding)
4. User authenticates at IdP
5. IdP generates SAML Response containing Assertion(s)
6. IdP POST-redirects user to SP's Assertion Consumer Service (ACS) URL
7. SP validates Response signature, Assertion signature, conditions
8. SP creates local session
```

### SAML Assertion Structure

```xml
<saml:Assertion>
  <saml:Issuer>https://idp.example.com</saml:Issuer>
  <ds:Signature>...</ds:Signature>
  <saml:Subject>
    <saml:NameID Format="urn:oasis:names:tc:SAML:2.0:nameid-format:persistent">user@example.com</saml:NameID>
    <saml:SubjectConfirmation Method="urn:oasis:names:tc:SAML:2.0:cm:bearer">
      <saml:SubjectConfirmationData
        NotOnOrAfter="2024-04-01T12:05:00Z"
        Recipient="https://sp.example.com/saml/acs"
        InResponseTo="_request123"/>
    </saml:SubjectConfirmation>
  </saml:Subject>
  <saml:Conditions NotBefore="..." NotOnOrAfter="...">
    <saml:AudienceRestriction>
      <saml:Audience>https://sp.example.com</saml:Audience>
    </saml:AudienceRestriction>
  </saml:Conditions>
  <saml:AuthnStatement AuthnInstant="..." SessionIndex="...">
    <saml:AuthnContext>
      <saml:AuthnContextClassRef>urn:oasis:names:tc:SAML:2.0:ac:classes:PasswordProtectedTransport</saml:AuthnContextClassRef>
    </saml:AuthnContext>
  </saml:AuthnStatement>
  <saml:AttributeStatement>
    <saml:Attribute Name="email"><saml:AttributeValue>user@example.com</saml:AttributeValue></saml:Attribute>
    <saml:Attribute Name="groups"><saml:AttributeValue>Admins</saml:AttributeValue></saml:Attribute>
  </saml:AttributeStatement>
</saml:Assertion>
```

### SAML Validation Checklist

1. Verify XML signature on Response and/or Assertion (use IdP's X.509 certificate)
2. Check `Issuer` matches expected IdP
3. Check `Audience` matches your SP entity ID
4. Check `NotBefore` and `NotOnOrAfter` timestamps (clock skew tolerance: 2-5 minutes)
5. Check `Recipient` matches your ACS URL
6. Check `InResponseTo` matches your original AuthnRequest ID (prevents replay)
7. Verify no XML wrapping attacks (canonicalize before signature verification)

### Common SAML Attacks

- **XML Signature Wrapping (XSW)** -- Attacker moves signed assertion and injects malicious one. Mitigation: strict signature reference validation.
- **Assertion Replay** -- Resubmit captured assertion. Mitigation: track consumed AssertionIDs, enforce NotOnOrAfter.
- **IdP-initiated flow abuse** -- No InResponseTo to validate. Mitigation: prefer SP-initiated flow.

---

## SCIM 2.0 (System for Cross-domain Identity Management)

REST API standard for automating user and group provisioning.

### Core Endpoints

| Method | Endpoint | Purpose |
|---|---|---|
| POST | /Users | Create user |
| GET | /Users/{id} | Read user |
| GET | /Users?filter=... | Search users |
| PUT | /Users/{id} | Full replace |
| PATCH | /Users/{id} | Partial update |
| DELETE | /Users/{id} | Delete/deactivate user |
| POST | /Groups | Create group |
| PATCH | /Groups/{id} | Update group membership |

### SCIM User Schema

```json
{
  "schemas": ["urn:ietf:params:scim:schemas:core:2.0:User"],
  "userName": "jdoe@example.com",
  "name": { "givenName": "John", "familyName": "Doe" },
  "emails": [{ "value": "jdoe@example.com", "type": "work", "primary": true }],
  "active": true,
  "groups": [{ "value": "group-id", "display": "Engineering" }],
  "externalId": "HR-12345"
}
```

### SCIM Operational Patterns

- **Full sync** -- Periodic GET /Users with pagination, compare with IdP, reconcile differences. Use for initial load and drift detection.
- **Incremental push** -- IdP pushes changes as they happen via POST/PATCH/DELETE. Real-time but requires reliable event delivery.
- **Filter-based pull** -- SP pulls changes using `filter=meta.lastModified gt "2024-01-01T00:00:00Z"`. Polling-based.

**Common issues:**
- Vendors implement SCIM inconsistently (attribute naming, error codes, filtering support)
- Group membership updates via PATCH can be expensive for large groups
- Soft delete (active=false) vs. hard delete (HTTP DELETE) semantics vary by vendor

---

## Kerberos Protocol

Ticket-based authentication used by Active Directory. All operations use symmetric key cryptography.

### Authentication Flow

```
Client                     KDC (DC)                    Service
  |                          |                            |
  |--- AS-REQ (username) --->|                            |
  |    (encrypted with       |                            |
  |     user's password hash)|                            |
  |                          |                            |
  |<-- AS-REP (TGT) --------|                            |
  |    (TGT encrypted with   |                            |
  |     KRBTGT hash)         |                            |
  |                          |                            |
  |--- TGS-REQ (TGT+SPN) -->|                            |
  |                          |                            |
  |<-- TGS-REP (ST) --------|                            |
  |    (ST encrypted with    |                            |
  |     service account hash)|                            |
  |                          |                            |
  |--- AP-REQ (ST) ---------------------------------->   |
  |                          |                            |
  |<-- AP-REP (optional mutual auth) -----------------   |
```

### Key Kerberos Concepts

- **TGT (Ticket Granting Ticket)** -- Proves user identity to KDC. Default lifetime: 10 hours. Renewable for 7 days.
- **Service Ticket (ST)** -- Proves user identity to a specific service. Contains PAC (Privilege Attribute Certificate) with group memberships.
- **SPN (Service Principal Name)** -- Identifies a service (e.g., `HTTP/web.example.com`, `MSSQLSvc/sql01.example.com:1433`).
- **KRBTGT account** -- The KDC's own account. Its password hash encrypts all TGTs. Compromise = Golden Ticket.
- **PAC (Privilege Attribute Certificate)** -- Embedded in tickets, contains user SID, group SIDs, used for authorization.

### Kerberos Attacks

| Attack | Mechanism | Detection | Mitigation |
|---|---|---|---|
| **Kerberoasting** | Request ST for service with SPN, crack offline | Event 4769 with RC4 encryption | Use AES, long service account passwords, gMSA |
| **AS-REP Roasting** | Request TGT for accounts without pre-auth, crack offline | Event 4768 with RC4 | Require pre-auth for all accounts |
| **Golden Ticket** | Forge TGT with compromised KRBTGT hash | Impossible to detect without PAC validation | Rotate KRBTGT password twice, deploy ATA/Defender for Identity |
| **Silver Ticket** | Forge ST with compromised service account hash | Service-side PAC validation (rare) | Use gMSA, enable PAC validation |
| **Pass-the-Ticket** | Steal and reuse Kerberos tickets from memory | Anomalous ticket use patterns | Credential Guard, Protected Users group |
| **Delegation abuse** | Abuse unconstrained/constrained delegation | Event 4624 with delegation flags | Use resource-based constrained delegation, avoid unconstrained |

---

## Access Control Models

### RBAC (Role-Based Access Control)

Users are assigned to roles. Roles have permissions. Users inherit permissions through role membership.

```
User --> Role --> Permission
         |
         +--> Permission
         |
         +--> Permission
```

**RBAC best practices:**
- Keep roles coarse-grained (10-30 roles for most organizations)
- Use role hierarchy (Manager inherits from Employee)
- Avoid user-specific permission overrides (defeats the purpose of RBAC)
- Enforce separation of duties through mutually exclusive roles
- Certify role assignments quarterly

### ABAC (Attribute-Based Access Control)

Policies evaluate attributes at decision time:

```
Subject attributes: department=Engineering, clearance=Secret, location=US
Resource attributes: classification=Secret, owner=Engineering
Environment attributes: time=business_hours, network=corporate
Action: read

Policy: PERMIT if subject.clearance >= resource.classification
            AND subject.department = resource.owner
            AND environment.network = corporate
```

**ABAC components (XACML architecture):**
- **PEP (Policy Enforcement Point)** -- Intercepts requests, asks PDP
- **PDP (Policy Decision Point)** -- Evaluates policies, returns permit/deny
- **PAP (Policy Administration Point)** -- Where policies are authored
- **PIP (Policy Information Point)** -- Retrieves attributes from external sources

### JIT/JEA (Just-In-Time / Just-Enough-Access)

**JIT access:** Elevated privileges granted temporarily, auto-revoked.
- Request privileged role --> approval workflow --> time-limited activation (1-8 hours) --> automatic revocation
- Implementations: Entra PIM, CyberArk, BeyondTrust

**JEA (Just Enough Administration):** Constrained PowerShell endpoints that limit which commands an admin can run.
- Define role capabilities (allowed cmdlets, parameters, visible functions)
- User connects via PowerShell remoting to JEA endpoint
- Session runs under a virtual account or gMSA with only the permitted commands

---

## Token Security

### JWT (JSON Web Token) Best Practices

**Signing:**
- Use RS256 or ES256 for asymmetric signing (allows public key verification)
- Never use `alg: none` or allow algorithm switching
- Rotate signing keys periodically (90 days recommended)

**Claims:**
- Set short expiration (`exp`): 5-15 minutes for access tokens
- Include `iss`, `aud`, `iat`, `exp` at minimum
- Use `jti` (JWT ID) for token revocation tracking
- Never put secrets or PII in tokens (JWTs are base64-encoded, not encrypted)

**Storage (client-side):**
- Web apps: HTTP-only, Secure, SameSite=Lax cookies (not localStorage)
- SPAs: In-memory only (not localStorage or sessionStorage)
- Mobile: OS-level secure storage (Keychain/Keystore)

### Token Revocation Strategies

| Strategy | Latency | Complexity | Use Case |
|---|---|---|---|
| **Short-lived tokens** | Token lifetime | Low | Default approach, 5-15 min access tokens |
| **Token introspection** | Real-time | Medium | OAuth 2.0 introspection endpoint, per-request check |
| **Blocklist** | Near real-time | Medium | Track revoked `jti` values in fast store (Redis) |
| **Refresh token rotation** | Next refresh | Low | Detect stolen refresh tokens by reuse detection |

---

## Session Management

### Session Lifecycle

1. **Creation** -- After successful authentication, create server-side session or issue tokens
2. **Validation** -- On each request, validate session (expiration, binding, revocation)
3. **Renewal** -- Extend session on activity (sliding expiration) or require re-authentication (absolute expiration)
4. **Termination** -- Explicit logout, timeout, or revocation

### Session Security Controls

- **Absolute timeout** -- Maximum session lifetime regardless of activity (8-12 hours typical)
- **Idle timeout** -- Session expires after period of inactivity (15-30 minutes for sensitive apps)
- **Session binding** -- Bind session to client IP, user agent, or device fingerprint
- **Secure cookie attributes** -- HttpOnly, Secure, SameSite=Lax, appropriate Domain/Path
- **Session fixation prevention** -- Regenerate session ID after authentication
- **Concurrent session limits** -- Limit number of active sessions per user

---

## Directory Services Concepts

### LDAP (Lightweight Directory Access Protocol)

Hierarchical directory protocol. Tree structure with Distinguished Names (DNs):

```
dc=example,dc=com
  |-- ou=Users
  |     |-- cn=John Doe
  |     |-- cn=Jane Smith
  |-- ou=Groups
  |     |-- cn=Engineering
  |     |-- cn=Admins
  |-- ou=Service Accounts
        |-- cn=svc-app1
```

**LDAP operations:** Bind (authenticate), Search (find entries), Add, Delete, Modify, Compare

**Search filters:** `(&(objectClass=user)(department=Engineering)(!(disabled=TRUE)))`

**Security concerns:**
- Use LDAPS (LDAP over TLS, port 636) or StartTLS. Never plain LDAP (port 389) for authentication.
- Simple bind sends credentials in cleartext without TLS
- Anonymous bind should be disabled
- LDAP channel binding and signing required for modern AD security

### Schema and Object Classes

- **objectClass** -- Defines required and optional attributes (e.g., `user`, `group`, `organizationalUnit`)
- **Attribute syntax** -- Data type of each attribute (string, integer, DN, octet string)
- **Auxiliary classes** -- Extend objects with additional attributes without changing structural class

---

## Zero Trust Identity Principles

Identity is the control plane in zero trust architecture:

1. **Continuous verification** -- Every access request is authenticated and authorized, regardless of network location
2. **Device trust** -- Device health (patched, compliant, managed) is a signal in access decisions
3. **Least privilege** -- Grant minimum access, use JIT elevation for privileged operations
4. **Assume breach** -- Segment access so that a compromised identity has minimal blast radius
5. **Continuous evaluation** -- Re-evaluate access during a session, not just at login (Continuous Access Evaluation Protocol -- CAEP)

**Implementation signals for access decisions:**
- User identity (who)
- Device health (what)
- Location (where)
- Application sensitivity (to what)
- Risk score (how risky)
- Time and behavior (when and how)
