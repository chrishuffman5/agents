# MCP Authorization — the OAuth 2.1 profile (spec 2025-11-25)

Read this when implementing or reviewing auth on an HTTP MCP server or client: discovery, client registration, scopes, tokens, and step-up.

## Scope and roles

> Source: https://modelcontextprotocol.io/specification/2025-11-25/basic/authorization

- Authorization is **OPTIONAL** for MCP implementations. When supported:
  - **HTTP-based transports SHOULD** conform to this spec.
  - **stdio transports SHOULD NOT** follow this spec — retrieve credentials from the environment instead.
  - Alternative transports **MUST** follow established security best practices for their protocol.
- Roles: the **MCP server** is the OAuth 2.1 **resource server**; the **MCP client** is the OAuth 2.1 **client**; the **authorization server** issues tokens and may be co-hosted with the resource server or separate (that choice is out of scope for the spec).
- Built on a subset of: OAuth 2.1 (`draft-ietf-oauth-v2-1-13`), OAuth 2.0 Authorization Server Metadata (RFC 8414), OAuth 2.0 Dynamic Client Registration (RFC 7591), OAuth 2.0 Protected Resource Metadata (RFC 9728), OAuth Client ID Metadata Documents (`draft-ietf-oauth-client-id-metadata-document-00`).

## Normative requirements

1. Authorization servers **MUST** implement OAuth 2.1 with appropriate security for both confidential and public clients.
2. Authorization servers and MCP clients **SHOULD** support Client ID Metadata Documents (CIMD).
3. Authorization servers and MCP clients **MAY** support Dynamic Client Registration (RFC 7591), for backwards compatibility.
4. MCP servers **MUST** implement OAuth 2.0 Protected Resource Metadata (RFC 9728). MCP clients **MUST** use it for authorization-server discovery.
5. MCP authorization servers **MUST** provide at least one of OAuth 2.0 Authorization Server Metadata (RFC 8414) or OpenID Connect Discovery 1.0. MCP clients **MUST** support both discovery mechanisms.

## Authorization server discovery

> Source: https://modelcontextprotocol.io/specification/2025-11-25/basic/authorization

The MCP server's Protected Resource Metadata document **MUST** include `authorization_servers` (it may list multiple; the client picks per RFC 9728 §7.6).

Two discovery mechanisms — servers **MUST** implement at least one, clients **MUST** support both:

1. **`WWW-Authenticate` header** — the resource metadata URL in the `resource_metadata` parameter on `401` responses (RFC 9728 §5.1).
2. **Well-known URI** — either `https://example.com/.well-known/oauth-protected-resource/<mcp-endpoint-path>` or `https://example.com/.well-known/oauth-protected-resource` (root).

Clients **MUST** prefer the `WWW-Authenticate` header when present, then fall back to the well-known URIs in the order listed.

Servers **SHOULD** include a `scope` parameter in `WWW-Authenticate` (RFC 6750 §3) indicating required scopes:

```http
HTTP/1.1 401 Unauthorized
WWW-Authenticate: Bearer resource_metadata="https://mcp.example.com/.well-known/oauth-protected-resource",
                         scope="files:read"
```

Clients **MUST NOT** assume any set relationship between challenge scopes and `scopes_supported`; challenge scopes are authoritative for the current request.

### Authorization server metadata probing order

For issuer URLs **with** a path (`https://auth.example.com/tenant1`), clients **MUST** try, in order:

1. `https://auth.example.com/.well-known/oauth-authorization-server/tenant1`
2. `https://auth.example.com/.well-known/openid-configuration/tenant1`
3. `https://auth.example.com/tenant1/.well-known/openid-configuration`

For issuer URLs **without** a path:

1. `https://auth.example.com/.well-known/oauth-authorization-server`
2. `https://auth.example.com/.well-known/openid-configuration`

### Discovery sequence

```
Client -> MCP Server: request without token
MCP Server -> Client: 401 (+ WWW-Authenticate maybe)
  if header has resource_metadata: Client GETs it directly
  else: Client probes /.well-known/oauth-protected-resource/<path> then /.well-known/oauth-protected-resource
Client -> Authorization Server: GET metadata endpoint (try OAuth/OIDC discovery in priority order)
AS -> Client: authorization server metadata
... OAuth 2.1 flow happens ...
Client -> AS: token request
AS -> Client: access token
Client -> MCP Server: request with access token
```

## Client registration — three mechanisms, in priority order

> Source: https://modelcontextprotocol.io/specification/2025-11-25/basic/authorization

1. **Pre-registered** client information, if available.
2. **Client ID Metadata Documents (CIMD)** — if the AS advertises `client_id_metadata_document_supported: true`.
3. **Dynamic Client Registration (DCR)** — if the AS exposes a `registration_endpoint`.
4. Prompt the user to enter client information manually.

### Client ID Metadata Documents

The `client_id` **is** an HTTPS URL pointing at a JSON document.

- **Clients**: host the metadata at an HTTPS URL with a path (`https://example.com/client.json`); the document **MUST** include at least `client_id`, `client_name`, and `redirect_uris`; the `client_id` inside the document **MUST** match the URL exactly; clients **MAY** use `private_key_jwt` client authentication.
- **Authorization servers**: **SHOULD** fetch the document when they encounter a URL-formatted `client_id`; **MUST** validate that `client_id` matches the URL exactly; **SHOULD** cache respecting HTTP cache headers; **MUST** validate `redirect_uri` against the document's list; **MUST** validate JSON structure and required fields.

```json
{
  "client_id": "https://app.example.com/oauth/client-metadata.json",
  "client_name": "Example MCP Client",
  "client_uri": "https://app.example.com",
  "logo_uri": "https://app.example.com/logo.png",
  "redirect_uris": ["http://127.0.0.1:3000/callback", "http://localhost:3000/callback"],
  "grant_types": ["authorization_code"],
  "response_types": ["code"],
  "token_endpoint_auth_method": "none"
}
```

The AS advertises support with `{ "client_id_metadata_document_supported": true }`.

### Dynamic Client Registration

RFC 7591, retained for backwards compatibility with earlier MCP auth spec versions.

## Scope selection strategy

> Source: https://modelcontextprotocol.io/specification/2025-11-25/basic/authorization

1. Use `scope` from the initial `WWW-Authenticate` `401` challenge, if present.
2. Otherwise use all `scopes_supported` from Protected Resource Metadata, omitting the `scope` parameter entirely if `scopes_supported` is undefined.

Rationale: general-purpose MCP clients typically lack the domain knowledge to pick individual scopes, so requesting-all-then-letting-the-user-consent minimizes friction while least-privilege is still enforced at the level where the server defines scopes. See Scope Minimization in `security.md` for the server-side obligation.

## Full authorization flow

> Source: https://modelcontextprotocol.io/specification/2025-11-25/basic/authorization

```
Client -> MCP Server: request without token
MCP Server -> Client: 401 + WWW-Authenticate
Client -> MCP Server: GET resource metadata
MCP Server -> Client: metadata (extract AS list, client picks one)
Client -> AS: GET AS metadata endpoint (OAuth/OIDC discovery priority order)
AS -> Client: AS metadata
  [CIMD]: client uses HTTPS URL as client_id; AS fetches + validates it
  [DCR]:  Client POST /register -> AS returns client credentials
  [Pre-registered]: use existing client_id
Client: generate PKCE params, include resource param, apply scope-selection strategy
Client -> Browser: open authorization URL (+ code_challenge + resource)
Browser -> AS: authorization request
AS -> Browser: redirect w/ authorization code (after user approves)
Browser -> Client: authorization code callback
Client -> AS: token request (+ code_verifier + resource)
AS -> Client: access token (+ refresh token)
Client -> MCP Server: request with access token
```

## Resource parameter (RFC 8707) — mandatory audience binding

> Source: https://modelcontextprotocol.io/specification/2025-11-25/basic/authorization

- MCP clients **MUST** implement Resource Indicators. The `resource` parameter **MUST** appear in both the authorization and token requests, **MUST** identify the target MCP server, and **MUST** use its canonical URI.
- Canonical URI: lowercase scheme and host preferred (implementations should accept uppercase for robustness), no fragment.
  - Valid: `https://mcp.example.com/mcp`, `https://mcp.example.com`, `https://mcp.example.com:8443`, `https://mcp.example.com/server/mcp`.
  - Invalid: `mcp.example.com` (no scheme), `https://mcp.example.com#fragment` (fragment present).
  - Prefer no trailing slash unless semantically significant.
- Example: `&resource=https%3A%2F%2Fmcp.example.com`
- Clients **MUST** send `resource` regardless of whether the AS advertises support for it.

## Access token usage

> Source: https://modelcontextprotocol.io/specification/2025-11-25/basic/authorization

- **MUST** use the `Authorization: Bearer <access-token>` header (OAuth 2.1 §5.1.1) on **every** HTTP request, even within the same logical session.
- Access tokens **MUST NOT** appear in the URI query string.

```http
GET /mcp HTTP/1.1
Host: mcp.example.com
Authorization: Bearer eyJhbGciOiJIUzI1NiIs...
```

- MCP servers **MUST** validate tokens (OAuth 2.1 §5.2), including audience per RFC 8707 §2; invalid or expired tokens **MUST** receive `401`.
- MCP clients **MUST NOT** send the MCP server any token other than one issued by that server's own authorization server.
- MCP servers **MUST** only accept tokens valid for their own resources and **MUST NOT** accept or transmit any other tokens — see the token passthrough prohibition in `security.md`.

## Error handling

> Source: https://modelcontextprotocol.io/specification/2025-11-25/basic/authorization

| Status | Meaning | Usage |
|---|---|---|
| 401 | Unauthorized | Authorization required or token invalid |
| 403 | Forbidden | Invalid scopes / insufficient permissions |
| 400 | Bad Request | Malformed authorization request |

### Step-up authorization

On a request with insufficient scope the server **SHOULD** respond:

```http
HTTP/1.1 403 Forbidden
WWW-Authenticate: Bearer error="insufficient_scope",
                         scope="files:read files:write user:profile",
                         resource_metadata="https://mcp.example.com/.well-known/oauth-protected-resource",
                         error_description="Additional file write permission required"
```

Flow: client parses the error → determines required scopes per the scope selection strategy → re-initiates authorization with those scopes → retries the original request "no more than a few times", then treats it as a permanent failure. User-delegated clients **SHOULD** attempt step-up; `client_credentials`-only clients **MAY** attempt it or abort immediately.

## Security considerations

> Source: https://modelcontextprotocol.io/specification/2025-11-25/basic/authorization

- **Token theft** — use secure storage; the AS **SHOULD** issue short-lived access tokens and **MUST** rotate refresh tokens for public clients.
- **Communication security** — all AS endpoints **MUST** be HTTPS; redirect URIs **MUST** be `localhost` or HTTPS.
- **Authorization code protection** — clients **MUST** implement PKCE (S256 when technically capable) and **MUST** refuse to proceed if the AS does not advertise `code_challenge_methods_supported`. For OIDC discovery, clients **MUST** require this field too, even though the OIDC spec does not mandate it.
- **Open redirection** — client redirect URIs **MUST** be pre-registered; the AS **MUST** exact-match them; clients **SHOULD** use and verify `state`.
- **CIMD-specific risks** — SSRF (the AS fetching arbitrary `client_id` URLs) and localhost-redirect impersonation. The AS **SHOULD** warn on localhost-only redirects and **MUST** clearly display the redirect hostname during authorization.
- **Confused deputy** and **token passthrough** — full attack narratives and required mitigations are in `security.md`.

## Authorization extensions

> Source: https://modelcontextprotocol.io/specification/2025-11-25/basic/authorization

Optional, additive, composable, independently-versioned extensions to core auth live in the MCP Authorization Extensions repo (https://github.com/modelcontextprotocol/ext-auth) — for example Enterprise-Managed Authorization for zero-touch OAuth provisioning via an organization's IdP.

## Sources

- https://modelcontextprotocol.io/specification/2025-11-25/basic/authorization
- https://github.com/modelcontextprotocol/ext-auth

Fetched: 2026-08-05
