# Authentication & Authorization Patterns

## Session-Based vs Token-Based Auth

### Session-Based Authentication
Server creates session after login, stores it (memory, Redis, DB), sends session ID as cookie.

```
# Login
POST /auth/login
{"username": "alice", "password": "secret"}

# Server creates session, responds:
Set-Cookie: session_id=abc123xyz; HttpOnly; Secure; SameSite=Lax; Path=/

# Client sends cookie automatically on every request
GET /profile
Cookie: session_id=abc123xyz
```

**Storage options**:
- In-memory: fast, lost on restart, not horizontally scalable without sticky sessions
- Redis: fast, survives restarts, scales horizontally (all nodes share Redis)
- Database: durable, slowest

**Trade-offs**:
| Aspect        | Session                             | Token (JWT)                        |
|---------------|-------------------------------------|------------------------------------|
| Revocation    | Instant (delete session)            | Hard (wait for expiry or maintain blocklist) |
| Scalability   | Requires shared state               | Stateless, scales easily           |
| Storage       | Server-side                         | Client-side                        |
| Payload size  | Tiny (session ID only)              | Larger (self-contained claims)     |
| CSRF risk     | High (cookies sent automatically)  | Low (explicit header required)     |
| Suited for    | Traditional web apps, SSR           | APIs, SPAs, microservices          |

**CSRF Protection for sessions**: Double submit cookie, CSRF token in meta tag, SameSite=Lax (partial), Origin header check.

---

## JWT (JSON Web Tokens)

### Structure
Three base64url-encoded parts separated by dots:
```
header.payload.signature

# Header
{"alg": "HS256", "typ": "JWT"}

# Payload (claims)
{
  "sub": "user_123",          # subject (user ID)
  "iss": "https://api.example.com",   # issuer
  "aud": "https://api.example.com",   # audience
  "exp": 1704153600,          # expiration (Unix timestamp)
  "iat": 1704067200,          # issued at
  "nbf": 1704067200,          # not before
  "jti": "unique-jwt-id",     # JWT ID (for revocation tracking)
  "role": "admin",            # custom claim
  "scope": "read:users write:orders"  # OAuth-style scopes
}

# Signature (for HS256)
HMACSHA256(base64url(header) + "." + base64url(payload), secret)
```

### Signing Algorithms

**Symmetric (HMAC)**:
- `HS256`: HMAC-SHA256 — single shared secret, fast
- `HS384`, `HS512`: longer digest, marginal security improvement
- Problem: secret must be shared between issuer and validator — doesn't scale across services

**Asymmetric (RSA)**:
- `RS256`: RSA PKCS#1 v1.5 with SHA-256 — private key signs, public key verifies
- `RS384`, `RS512`
- Key size: minimum 2048-bit, prefer 4096-bit for long-lived keys

**Asymmetric (ECDSA)**:
- `ES256`: ECDSA with P-256 curve — smaller keys, faster than RSA, same security level
- `ES384` (P-384), `ES512` (P-521)
- Preferred for performance-critical systems

**EdDSA**:
- `EdDSA` with Ed25519 curve — fastest, smallest, modern; not universally supported yet

**Recommendation**: Use `RS256` or `ES256` for service-to-service; `ES256` preferred for new systems. Never use `none` algorithm — explicitly reject it server-side.

### Access Tokens + Refresh Tokens Pattern
```
# Login response
{
  "access_token": "eyJ...",     # Short-lived: 5-15 minutes
  "refresh_token": "eyJ...",    # Long-lived: 7-30 days, stored HttpOnly cookie
  "token_type": "Bearer",
  "expires_in": 900
}

# Using access token
GET /api/data
Authorization: Bearer eyJ...

# Refreshing
POST /auth/refresh
Cookie: refresh_token=eyJ...   # Or in body

Response:
{
  "access_token": "eyJ...",     # New access token
  "expires_in": 900
}
```

**Refresh token rotation**: Issue new refresh token on each use, invalidate old one. Detect reuse (compromise indicator).

**Revocation challenge**: 
- Short access token TTL limits exposure window
- Maintain blocklist (Redis SET) for compromised JTIs
- Trade-off: blocklist lookup re-introduces state, but only for revocation not validation

### JWT Validation Checklist
Server MUST validate:
1. Signature (using correct algorithm — reject `alg: none`)
2. `exp` — not expired
3. `nbf` — if present, current time >= nbf
4. `iss` — matches expected issuer
5. `aud` — includes this service's identifier
6. Algorithm matches expected (allowlist algorithms explicitly)

---

## OAuth 2.0 Flows

### Authorization Code Flow (Web Apps with Backend)
```
1. Client → User browser → Auth Server
GET /authorize?
  response_type=code&
  client_id=myapp&
  redirect_uri=https://myapp.com/callback&
  scope=openid+profile+email&
  state=random_csrf_token

2. User authenticates, Auth Server → redirect
GET https://myapp.com/callback?
  code=AUTH_CODE&
  state=random_csrf_token

3. Backend exchanges code for tokens (server-to-server, client_secret included)
POST /token
  grant_type=authorization_code&
  code=AUTH_CODE&
  redirect_uri=https://myapp.com/callback&
  client_id=myapp&
  client_secret=SECRET

Response: { access_token, refresh_token, expires_in, ... }
```

**State parameter**: CSRF protection — must verify state matches what client sent.  
**Code is single-use and short-lived**: Typically 10 minutes.

### Authorization Code + PKCE (Public Clients: SPAs, Mobile)
Eliminates client_secret requirement (public clients can't keep secrets).

```
1. Generate code_verifier (cryptographically random, 43-128 chars)
code_verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"

2. Compute code_challenge
code_challenge = base64url(SHA256(code_verifier))

3. Send challenge in authorization request
GET /authorize?
  ...&
  code_challenge=E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM&
  code_challenge_method=S256

4. Exchange code for token — send verifier, server validates
POST /token
  grant_type=authorization_code&
  code=AUTH_CODE&
  code_verifier=dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk&
  client_id=myapp&
  redirect_uri=...
```

PKCE mitigates authorization code interception attacks. Use PKCE for all new OAuth 2.0 implementations regardless of client type (RFC 9700).

### Client Credentials Flow (Machine-to-Machine)
No user involvement. Service authenticates directly with client_id + client_secret.
```
POST /token
  grant_type=client_credentials&
  client_id=service_a&
  client_secret=SECRET&
  scope=orders:read payments:write

Response: { access_token, expires_in, token_type }
```

Use for: microservice-to-microservice auth, CI/CD pipelines, server-side batch jobs.  
Never embed client_secret in mobile/browser apps.

### Device Code Flow (Input-Constrained Devices)
For smart TVs, CLI tools, IoT devices without browser.
```
1. Device requests device code
POST /device/code
  client_id=myapp&
  scope=profile

Response:
{
  "device_code": "GmRhmhcxhwAzkoEqiMEg_DnyEysNkuNhszIySk9eS",
  "user_code": "WDJB-MJHT",
  "verification_uri": "https://auth.example.com/device",
  "expires_in": 1800,
  "interval": 5
}

2. Device shows user_code to user, polls token endpoint
POST /token
  grant_type=urn:ietf:params:oauth:grant-type:device_code&
  device_code=GmRhmhcxhwAzkoEqiMEg_DnyEysNkuNhszIySk9eS&
  client_id=myapp

# Returns authorization_pending until user completes flow
```

---

## OpenID Connect (OIDC)

Layer on top of OAuth 2.0 that adds identity. OAuth gives you an access token (authorization). OIDC adds an ID token (authentication/identity).

### ID Token
JWT containing user identity claims:
```json
{
  "iss": "https://accounts.google.com",
  "sub": "10769150350006150715113082367",
  "aud": "1234987819200.apps.googleusercontent.com",
  "exp": 1704153600,
  "iat": 1704067200,
  "email": "alice@example.com",
  "email_verified": true,
  "name": "Alice Smith",
  "picture": "https://...",
  "locale": "en"
}
```

ID token is for the client to read. Access token is for calling APIs. Don't use the access token as identity proof.

### UserInfo Endpoint
```
GET /userinfo
Authorization: Bearer access_token

Response:
{
  "sub": "10769150350006150715113082367",
  "name": "Alice Smith",
  "email": "alice@example.com",
  "email_verified": true
}
```

### Discovery
```
GET /.well-known/openid-configuration

Response includes: authorization_endpoint, token_endpoint, userinfo_endpoint, 
jwks_uri, scopes_supported, response_types_supported, ...
```

JWKS URI provides public keys for ID token validation — fetch and cache these, don't hardcode.

---

## API Keys

### When Appropriate
- Server-to-server communication where OAuth complexity is unwarranted
- Developer API access (early-stage, webhooks, simple integrations)
- Per-application rate limiting (not per-user)
- Long-lived automation without interactive user

### Security Considerations
```
# Transmission: Header preferred over query string
Authorization: Bearer sk_live_abc123
X-API-Key: sk_live_abc123

# NEVER: Query string (appears in logs, browser history, CDN logs)
GET /api/data?api_key=sk_live_abc123
```

**Storage**:
- Store hash of API key, not plaintext (use scrypt/argon2 or SHA-256 with salt)
- Show full key only once on creation; thereafter show only prefix (`sk_live_abc...`)
- Associate with: user/org, created date, last-used date, scopes, IP allowlist

**Key format best practices**:
- Include prefix indicating environment: `sk_live_`, `sk_test_`, `pk_live_`
- Use cryptographically random bytes (32+ bytes, base64url encoded)
- Total length: 32-64 characters
- Include checksum or CRC for early validation

**Rotation**: Support multiple active keys; allow rotation without downtime.

---

## mTLS (Mutual TLS)

Both client and server present X.509 certificates. Server authenticates client by validating certificate against trusted CA.

```
# Standard TLS: client validates server cert
# mTLS: both sides validate each other's cert

# Client-side certificate in curl
curl --cert client.crt --key client.key --cacert server-ca.crt \
  https://api.example.com/data

# Nginx config for mTLS
ssl_client_certificate /etc/nginx/client-ca.crt;
ssl_verify_client on;
ssl_verify_depth 2;
```

**Use cases**:
- Service mesh (Istio, Linkerd) — automatic mTLS between microservices
- B2B APIs where clients can manage certificates
- Highly regulated industries (banking, healthcare)

**Trade-offs**:
- Strong authentication without secret management (no passwords/tokens to rotate)
- Certificate lifecycle management is complex (issuance, rotation, revocation via CRL/OCSP)
- Difficult to debug (TLS errors are opaque)
- Service mesh handles complexity automatically (Envoy proxy terminates mTLS)

---

## RBAC vs ABAC vs ReBAC

### RBAC (Role-Based Access Control)
Assign roles to users; roles have permissions.
```
User Alice → Role: admin
Role admin → Permissions: [read:users, write:users, delete:users]

Authorization check:
if (user.roles.includes('admin') || user.roles.includes('editor')) {
  allow()
}
```
**Pros**: Simple, performant, auditable.  
**Cons**: Role explosion (hundreds of fine-grained roles), poor at context-sensitive decisions.

### ABAC (Attribute-Based Access Control)
Policy engine evaluates attributes of user, resource, environment.
```
Policy: ALLOW IF
  user.department == resource.department AND
  user.clearance_level >= resource.sensitivity_level AND
  request.time BETWEEN 09:00 AND 17:00 AND
  request.ip IN user.allowed_ips

# XACML / OPA (Open Policy Agent) policy
package authz

allow {
  input.user.role == "editor"
  input.resource.owner == input.user.id
  input.action == "update"
}
```
**Pros**: Fine-grained, flexible, handles complex scenarios.  
**Cons**: Policy complexity, harder to audit ("why was this denied?"), performance (policy evaluation overhead).

**OPA (Open Policy Agent)**: Decoupled policy engine. Write policies in Rego, evaluate via sidecar or API call.

### ReBAC (Relationship-Based Access Control)
Access determined by graph relationships between users and resources.
```
# Google Zanzibar model
document:budget_2024#viewer@user:alice    # alice is a viewer of budget_2024
document:budget_2024#viewer@group:finance # finance group are viewers
group:finance#member@user:bob             # bob is member of finance

# Check: can bob view budget_2024?
# → bob ∈ group:finance ∈ document:budget_2024#viewer → YES
```
**Implementations**: Google Zanzibar, Ory Keto, SpiceDB, OpenFGA (by Auth0/Okta)

**Pros**: Natural for social/collaborative apps (Google Drive, GitHub), handles inheritance cleanly.  
**Cons**: Complex to implement from scratch, relationship graph management, performance at scale requires caching.

**When to use each**:
- RBAC: Internal tools, simple SaaS with clear user tiers
- ABAC: Enterprise, compliance-heavy, multi-tenant with complex policies
- ReBAC: Collaborative apps, resource ownership hierarchies, org-based permissions

---

## CORS (Cross-Origin Resource Sharing)

### The Problem
Browser blocks cross-origin requests by default (Same-Origin Policy). CORS allows servers to declare which origins are permitted.

### Simple Requests
No preflight. Triggered when method is GET/POST/HEAD AND headers are only simple headers AND Content-Type is one of: `application/x-www-form-urlencoded`, `multipart/form-data`, `text/plain`.

```
# Browser adds:
Origin: https://app.example.com

# Server must respond:
Access-Control-Allow-Origin: https://app.example.com
# OR for public APIs:
Access-Control-Allow-Origin: *
```

### Preflight Requests
For non-simple requests (DELETE, PUT, PATCH, custom headers, JSON Content-Type):

```
# Browser sends OPTIONS first
OPTIONS /api/data
Origin: https://app.example.com
Access-Control-Request-Method: DELETE
Access-Control-Request-Headers: Content-Type, Authorization

# Server responds (204 or 200)
Access-Control-Allow-Origin: https://app.example.com
Access-Control-Allow-Methods: GET, POST, PUT, DELETE, PATCH
Access-Control-Allow-Headers: Content-Type, Authorization, X-Request-ID
Access-Control-Max-Age: 86400           # Cache preflight for 24h
Access-Control-Allow-Credentials: true  # Only if using cookies/credentials
```

### Credentials (Cookies + Auth Headers)
When sending cookies or Authorization headers cross-origin:
- Client must set `credentials: 'include'` (fetch) or `withCredentials: true` (XHR)
- Server must set `Access-Control-Allow-Credentials: true`
- Server CANNOT use `Access-Control-Allow-Origin: *` with credentials — must be specific origin

```javascript
// Client
fetch('https://api.example.com/data', {
  credentials: 'include',  // Send cookies
  headers: { 'Authorization': 'Bearer token' }
});

// Server response headers
Access-Control-Allow-Origin: https://app.example.com  // Must be specific
Access-Control-Allow-Credentials: true
```

### Exposed Headers
By default, only simple response headers are accessible to browser JS. To expose custom headers:
```
Access-Control-Expose-Headers: X-Request-ID, X-Rate-Limit-Remaining
```

### Security Pitfalls
- **Reflecting Origin**: `Access-Control-Allow-Origin: <value-of-Origin-header>` without validation allows any origin — validate against allowlist first
- **Null origin**: Never allow `Origin: null` (local files, redirects; can be spoofed in some contexts)
- **Credential + wildcard**: Server error; browser will block response
- **Overly broad `Access-Control-Allow-Headers: *`**: Not universally supported; list explicitly

```python
# Safe origin validation
ALLOWED_ORIGINS = {
    "https://app.example.com",
    "https://admin.example.com",
}

def get_cors_origin(request_origin):
    if request_origin in ALLOWED_ORIGINS:
        return request_origin
    return None  # Don't reflect unknown origins
```
