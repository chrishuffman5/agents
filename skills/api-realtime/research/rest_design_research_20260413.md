# REST API Design — Comprehensive Research

## 1. Architecture and Constraints

### Fielding's Six Constraints

REST (Representational State Transfer) was defined by Roy Fielding in his 2000 doctoral dissertation. A system is RESTful only when all six constraints are satisfied:

1. **Client-Server**: The UI is decoupled from data storage. The client is not concerned with data storage; the server is not concerned with UI state.
2. **Stateless**: Each request from the client must contain all information needed to service the request. Session state is held entirely on the client. This enables horizontal scaling without session affinity.
3. **Cacheable**: Responses must label themselves as cacheable or non-cacheable. If cacheable, the client cache may reuse response data for equivalent requests.
4. **Uniform Interface**: The central feature distinguishing REST. Four sub-constraints:
   - Resource identification in requests (URI)
   - Manipulation of resources through representations
   - Self-descriptive messages (each message includes enough information to process it — Content-Type, etc.)
   - HATEOAS (see below)
5. **Layered System**: Clients cannot tell whether they're connected directly to an end server or an intermediary. Enables load balancers, CDNs, gateways, caches.
6. **Code on Demand (optional)**: Servers can extend client functionality by sending executable code (e.g., JavaScript).

### HATEOAS

HATEOAS (Hypermedia as the Engine of Application State) means the server drives application state transitions by including links in responses. A client starts at a well-known URI and discovers all available actions from the response itself — no out-of-band documentation needed for navigation.

Example HAL-style response showing HATEOAS links:
```json
{
  "id": "order-123",
  "status": "pending",
  "total": 99.99,
  "_links": {
    "self": { "href": "/orders/123" },
    "cancel": { "href": "/orders/123/cancel", "method": "DELETE" },
    "pay": { "href": "/orders/123/payment", "method": "POST" },
    "customer": { "href": "/customers/456" }
  }
}
```

### Richardson Maturity Model (RMM)

Proposed by Leonard Richardson in 2008. Classifies REST API quality in four levels:

| Level | Name | Description |
|-------|------|-------------|
| 0 | The Swamp of POX | Single URI, single HTTP method (POST everything). SOAP-style. |
| 1 | Resources | Multiple URIs representing different resources. Still POSTing everything. |
| 2 | HTTP Verbs | Using GET, POST, PUT, DELETE with correct semantics. Most "REST" APIs reach here. |
| 3 | Hypermedia Controls | HATEOAS links included in responses. True REST. |

Most production APIs operate at Level 2. Level 3 (HATEOAS) is theoretically ideal but rarely implemented in practice due to client complexity.

### Resource-Oriented Design

Resources are nouns, not verbs. Design around entities:
- **Collections**: `/orders`, `/users`, `/products`
- **Items**: `/orders/{id}`, `/users/{id}`
- **Sub-resources**: `/orders/{id}/items`, `/users/{id}/addresses`
- **Singletons**: `/me`, `/config` (when there is exactly one)

Anti-patterns to avoid:
- Verb URLs: `/getUser`, `/createOrder`, `/deleteItem`
- Mixed plural/singular: `/user/123` vs `/orders`
- Deep nesting beyond two levels: `/a/{id}/b/{id}/c/{id}/d` — flatten using references

---

## 2. Standards and Specifications

### OpenAPI 3.1 (OAS 3.1)

Released February 2021. The most significant update since OAS 2.0 (Swagger).

**Key changes from 3.0:**
- Full JSON Schema 2020-12 alignment — the `Schema Object` is now a proper JSON Schema dialect. No more OAS-specific divergences.
- `nullable: true` replaced by `type: ["string", "null"]` or using JSON Schema `anyOf`
- `webhooks` top-level field (alongside `paths`) for describing incoming callbacks
- `$ref` sibling properties now allowed (previously forbidden)
- New `summary` field on `$ref` objects

**Minimal OAS 3.1 document:**
```yaml
openapi: "3.1.0"
info:
  title: Orders API
  version: "1.0.0"
paths:
  /orders:
    get:
      summary: List all orders
      responses:
        "200":
          description: Successful response
          content:
            application/json:
              schema:
                type: array
                items:
                  $ref: "#/components/schemas/Order"
  /orders/{orderId}:
    get:
      parameters:
        - name: orderId
          in: path
          required: true
          schema:
            type: string
      responses:
        "200":
          description: Single order
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/Order"
        "404":
          $ref: "#/components/responses/NotFound"
components:
  schemas:
    Order:
      type: object
      properties:
        id:
          type: string
        status:
          type: ["string", "null"]
          enum: ["pending", "paid", "shipped", null]
  responses:
    NotFound:
      description: Resource not found
      content:
        application/problem+json:
          schema:
            $ref: "#/components/schemas/ProblemDetail"
```

**Tooling ecosystem:**
- Swagger UI / Swagger Editor — browser-based editing and interactive docs
- Redoc — read-only documentation generation
- Stoplight Studio — visual design-first editor
- Spectral — OpenAPI linting/validation (rule-based)
- oapi-codegen (Go), openapi-generator (multi-language) — code generation from spec

### JSON:API

Specification at https://jsonapi.org (current: 1.1). Defines media type `application/vnd.api+json`.

**Key features:**
- Standardized envelope: `data`, `errors`, `meta`, `included`, `links`
- Sparse fieldsets via `?fields[type]=attr1,attr2`
- Compound documents — related resources included in `included` array to avoid N+1
- Relationships object with `data`, `links`, `meta`
- PATCH for partial updates using resource identifier

```json
{
  "data": {
    "type": "articles",
    "id": "1",
    "attributes": {
      "title": "JSON:API paints my house!"
    },
    "relationships": {
      "author": {
        "links": { "related": "/articles/1/author" },
        "data": { "type": "people", "id": "9" }
      }
    }
  },
  "included": [
    {
      "type": "people",
      "id": "9",
      "attributes": { "firstName": "Dan", "lastName": "Gebhardt" }
    }
  ]
}
```

### HAL (Hypertext Application Language)

Media type: `application/hal+json`. Minimal hypermedia format.

Structure: two reserved keywords — `_links` (map of link relations to link objects or arrays) and `_embedded` (map of embedded resources). Everything else is your data.

```json
{
  "id": 42,
  "name": "Widget",
  "price": 9.99,
  "_links": {
    "self": { "href": "/widgets/42" },
    "collection": { "href": "/widgets" }
  },
  "_embedded": {
    "category": {
      "id": 5,
      "name": "Gadgets",
      "_links": { "self": { "href": "/categories/5" } }
    }
  }
}
```

### JSON-LD

JSON-LD (JSON for Linked Data) adds semantic context using `@context`, `@type`, `@id` keywords. Used by Schema.org, Google Structured Data, Activity Streams. Allows machine-readable semantic meaning. More complex than HAL but enables linked data across domains.

### RFC 9457 — Problem Details for HTTP APIs

Defines `application/problem+json` media type for machine-readable error responses. Replaces RFC 7807.

**Mandatory fields:**
- `type` — URI reference identifying the error type (should be resolvable documentation URL)
- `title` — Short human-readable summary of problem type (should not change per occurrence)
- `status` — HTTP status code (integer, must match actual response status)
- `detail` — Human-readable explanation specific to this occurrence
- `instance` — URI reference identifying this specific occurrence

**Extensions:** Any additional members are allowed. Standardized extension registry introduced in RFC 9457.

```json
{
  "type": "https://api.example.com/errors/validation-error",
  "title": "Validation Error",
  "status": 422,
  "detail": "The 'email' field must be a valid email address.",
  "instance": "/errors/abc-123-def",
  "errors": [
    {
      "field": "email",
      "message": "Invalid email format",
      "value": "not-an-email"
    }
  ]
}
```

### RFC 9110 — HTTP Semantics

Defines the meaning of HTTP methods, status codes, headers. Key clarifications relevant to API design:

- `GET` is safe and idempotent
- `PUT` replaces the full resource (idempotent)
- `PATCH` applies partial modification (not guaranteed idempotent)
- `DELETE` removes resource (idempotent)
- `POST` creates or processes (not safe, not idempotent)
- `HEAD` identical to GET but no body — use for checking resource existence
- `OPTIONS` describes communication options — used by CORS preflight

---

## 3. URL Design

### Conventions

- Use nouns for resource names, not verbs: `/users` not `/getUsers`
- Use plural for collections: `/articles`, `/orders`
- Lowercase, hyphen-separated (kebab-case) for compound words: `/blog-posts` not `/blogPosts`
- Hierarchical relationships with `/`: `/users/{id}/orders`
- Never put CRUD verb in URL — that's what HTTP methods are for
- Extensions like `.json` should be avoided; use `Accept` header instead

### Query Parameters

- `?filter[status]=active` or `?status=active` for filtering
- `?sort=-created_at,name` (prefix `-` for descending)
- `?page[number]=2&page[size]=20` (JSON:API style) or `?page=2&limit=20`
- `?fields=id,name,email` for field selection
- `?include=author,comments` for related resources
- `?q=search+term` or `?search=term` for full-text search

### Anti-patterns

```
# Bad
GET /api/v1/getUserById?id=123
POST /api/v1/createNewOrder
DELETE /api/v1/deleteUser/456

# Good
GET /api/v1/users/123
POST /api/v1/orders
DELETE /api/v1/users/456
```

---

## 4. HTTP Method Semantics

| Method | Safe | Idempotent | Common Use |
|--------|------|------------|------------|
| GET | Yes | Yes | Retrieve resource or collection |
| HEAD | Yes | Yes | Check existence, get headers only |
| OPTIONS | Yes | Yes | CORS preflight, capability discovery |
| POST | No | No | Create resource, trigger action |
| PUT | No | Yes | Full resource replacement |
| PATCH | No | No* | Partial update |
| DELETE | No | Yes | Remove resource |

*PATCH can be made idempotent with careful design (e.g., JSON Patch operations).

### PUT vs PATCH

PUT requires sending the full resource representation. PATCH sends only changes. For large resources, PATCH is preferred.

**JSON Patch (RFC 6902)** — structured PATCH format:
```json
PATCH /users/123
Content-Type: application/json-patch+json

[
  { "op": "replace", "path": "/email", "value": "new@example.com" },
  { "op": "remove", "path": "/middleName" },
  { "op": "add", "path": "/nickname", "value": "JD" }
]
```

**Merge Patch (RFC 7396)** — simpler format, null removes field:
```json
PATCH /users/123
Content-Type: application/merge-patch+json

{
  "email": "new@example.com",
  "middleName": null
}
```

---

## 5. Status Code Selection

### 2xx Success

- `200 OK` — Successful GET, PUT, PATCH (with body)
- `201 Created` — Successful POST that creates a resource; include `Location` header
- `202 Accepted` — Request accepted for async processing; return status URL
- `204 No Content` — Successful DELETE, PUT, PATCH (no body to return)
- `206 Partial Content` — Range request served (file downloads, chunked responses)

### 3xx Redirect

- `301 Moved Permanently` — Resource moved, update bookmarks
- `304 Not Modified` — Conditional GET, ETag match, use cached response

### 4xx Client Error

- `400 Bad Request` — Malformed request syntax, invalid parameters
- `401 Unauthorized` — Not authenticated (despite name, means unauthenticated)
- `403 Forbidden` — Authenticated but not authorized for this resource
- `404 Not Found` — Resource does not exist
- `405 Method Not Allowed` — HTTP method not supported for this endpoint
- `409 Conflict` — State conflict (e.g., duplicate create, version mismatch)
- `410 Gone` — Resource permanently deleted (more specific than 404)
- `422 Unprocessable Entity` — Semantically invalid request (validation errors)
- `429 Too Many Requests` — Rate limited; include `Retry-After` header

### 5xx Server Error

- `500 Internal Server Error` — Generic server failure
- `502 Bad Gateway` — Upstream service failure
- `503 Service Unavailable` — Temporarily down; include `Retry-After`
- `504 Gateway Timeout` — Upstream timeout

**Important**: Never return `200 OK` with an error body. Status code must reflect success or failure.

---

## 6. Content Negotiation

Clients specify desired format via `Accept` header. Server specifies response format via `Content-Type`.

```http
GET /orders/123
Accept: application/json, application/vnd.api+json;q=0.9

HTTP/1.1 200 OK
Content-Type: application/json
Vary: Accept
```

The `Vary: Accept` response header tells caches that responses vary by `Accept` header.

If the server cannot satisfy the `Accept` header, respond with `406 Not Acceptable`.

**Practical content types:**
- `application/json` — standard JSON
- `application/vnd.api+json` — JSON:API
- `application/hal+json` — HAL
- `application/problem+json` — RFC 9457 errors
- `application/json-patch+json` — JSON Patch
- `application/merge-patch+json` — Merge Patch
- `multipart/form-data` — file uploads

---

## 7. Caching: ETags and Conditional Requests

### ETag

Server generates a hash/version token for a resource. Client stores it and sends on subsequent requests.

```http
# Server sends ETag
GET /users/123
HTTP/1.1 200 OK
ETag: "33a64df551425fcc55e4d42a148795d9f25f89d4"
Cache-Control: max-age=3600

# Client sends conditional GET
GET /users/123
If-None-Match: "33a64df551425fcc55e4d42a148795d9f25f89d4"

# If unchanged, server responds:
HTTP/1.1 304 Not Modified
```

### Optimistic Concurrency with ETag

Prevent lost updates — client must include current ETag when modifying:
```http
PATCH /users/123
If-Match: "33a64df551425fcc55e4d42a148795d9f25f89d4"
Content-Type: application/json

{"email": "new@example.com"}

# If ETag doesn't match (resource changed):
HTTP/1.1 412 Precondition Failed
```

### Last-Modified

Alternative to ETag using timestamps. Less precise (1-second resolution). Use `Last-Modified` / `If-Modified-Since` and `If-Unmodified-Since` headers.

### Cache-Control Directives

- `Cache-Control: no-store` — never cache (sensitive data)
- `Cache-Control: no-cache` — always revalidate before serving
- `Cache-Control: max-age=3600` — cache for 1 hour
- `Cache-Control: private` — only browser cache, not shared CDN
- `Cache-Control: public, max-age=86400` — cacheable by anyone for 1 day

---

## 8. Pagination Patterns

### Offset Pagination

Simplest approach. `?limit=20&offset=40` or `?page=3&per_page=20`.

```json
{
  "data": [...],
  "pagination": {
    "total": 1543,
    "page": 3,
    "per_page": 20,
    "pages": 78
  }
}
```

**Drawbacks**: Page drift on inserts/deletes during traversal. Poor performance on large offsets (database must scan and discard rows). Not suitable for real-time or frequently-updated data.

### Cursor Pagination

Server returns an opaque cursor pointing to position in dataset. Client passes cursor to get next page.

```json
{
  "data": [...],
  "pagination": {
    "next_cursor": "eyJpZCI6MTIzfQ==",
    "has_more": true
  }
}
```

Request: `GET /orders?limit=20&cursor=eyJpZCI6MTIzfQ==`

**Advantages**: Stable during mutations, consistent performance. **Drawbacks**: Cannot jump to arbitrary page. Common in Twitter/Instagram-style feeds.

### Keyset Pagination (Seek Method)

Uses a specific indexed column's value as the starting point. More explicit than cursor.

```
GET /orders?limit=20&after_id=500&after_created_at=2024-01-15T10:00:00Z
```

Server generates: `WHERE (created_at, id) > ('2024-01-15T10:00:00Z', 500) ORDER BY created_at, id LIMIT 20`

**Best for**: Large datasets with stable sort order. Requires composite index on sort columns.

### Link Header Pagination (RFC 5988)

RESTful approach — embed pagination links in response `Link` header:
```http
Link: </orders?page=2>; rel="next",
      </orders?page=1>; rel="prev",
      </orders?page=78>; rel="last",
      </orders?page=1>; rel="first"
```

Used by GitHub API.

---

## 9. Filtering, Sorting, and Field Selection

### Filtering

**Simple equality**: `GET /orders?status=paid&customer_id=123`

**Range**: `GET /products?price_min=10&price_max=100`

**Array values**: `GET /orders?status[]=pending&status[]=paid` or `?status=pending,paid`

**Complex filters** (consider RQL or FIQL):
- FIQL: `?filter=status==paid;total=gt=100` (semicolon = AND, comma = OR)
- LHS Bracket: `?filter[status][eq]=paid&filter[total][gt]=100`

### Sorting

Convention: field name, prefix `-` for descending:
```
GET /orders?sort=-created_at,customer_name
```

Multiple fields: secondary sort after primary.

### Field Selection (Sparse Fieldsets)

Reduces payload size. Client specifies which fields to return:
```
GET /users?fields=id,name,email
GET /articles?fields[articles]=title,body&fields[people]=name
```

Server returns only requested fields. Reduces bandwidth and processing overhead.

---

## 10. Bulk Operations

### Batch Requests

Not natively in HTTP REST. Common patterns:

**1. POST to collection with array:**
```json
POST /orders/batch
Content-Type: application/json

{
  "operations": [
    { "method": "CREATE", "data": {...} },
    { "method": "UPDATE", "id": "123", "data": {...} }
  ]
}
```

**2. JSON Patch on collection:**
```json
PATCH /orders
Content-Type: application/json-patch+json

[
  { "op": "add", "path": "/-", "value": {...} },
  { "op": "replace", "path": "/123/status", "value": "shipped" }
]
```

**3. Partial success handling**: Return `207 Multi-Status` with per-operation results:
```json
HTTP/1.1 207 Multi-Status
[
  { "id": "op1", "status": 201, "data": {...} },
  { "id": "op2", "status": 422, "error": "Validation failed" }
]
```

---

## 11. Async Patterns for Long-Running Operations

### 202 Accepted + Polling

```http
POST /reports/generate
HTTP/1.1 202 Accepted
Location: /jobs/abc-123
Retry-After: 30
Content-Type: application/json

{
  "jobId": "abc-123",
  "status": "processing",
  "statusUrl": "/jobs/abc-123",
  "estimatedDuration": "PT2M"
}
```

Client polls the status URL:
```http
GET /jobs/abc-123
HTTP/1.1 200 OK
{
  "jobId": "abc-123",
  "status": "completed",
  "resultUrl": "/reports/xyz-789"
}
```

### Webhook Callbacks

Client registers a callback URL when initiating the operation:
```json
POST /imports
{
  "file": "...",
  "callbackUrl": "https://myapp.com/webhooks/import-complete"
}
```

Server POSTs to callback URL when done. Client should validate webhook signatures (HMAC-SHA256 typically).

---

## 12. Rate Limiting Headers

Standard headers (IETF draft `ratelimit-headers`):

```http
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 847
X-RateLimit-Reset: 1714320000
Retry-After: 60
```

- `X-RateLimit-Limit` — requests allowed per window
- `X-RateLimit-Remaining` — requests remaining in current window
- `X-RateLimit-Reset` — Unix timestamp when window resets
- `Retry-After` — seconds to wait before retrying (also used with 503)

On rate limit: return `429 Too Many Requests` with `Retry-After`.

IETF Draft (draft-ietf-httpapi-ratelimit-headers) proposes standardizing as `RateLimit-Limit`, `RateLimit-Remaining`, `RateLimit-Reset`.

---

## 13. Versioning Strategies

### URL Path Versioning (Most Common)

```
GET /v1/orders
GET /v2/orders
```

**Pros**: Explicit, easy to route, cacheable, easy to test in browser, visible in logs.
**Cons**: Violates REST (URI should identify resource, not version), requires updating all client URLs.

Used by: Stripe, GitHub, Google APIs.

### Header Versioning

```http
GET /orders
API-Version: 2024-01-01
```

**Pros**: Clean URLs, resource identity preserved.
**Cons**: Hidden from URL, harder to test, must be documented carefully.

Used by: Stripe (also supports date-based: `Stripe-Version: 2023-10-16`).

### Content Negotiation (Media Type Versioning)

```http
GET /orders
Accept: application/vnd.myapi.v2+json
```

**Pros**: True REST — same URI, negotiated representation.
**Cons**: Complex to implement, hard to test, poor browser support.

Used by: GitHub (for some resources).

### Query Parameter Versioning

```
GET /orders?version=2
```

**Pros**: Easy to test.
**Cons**: Pollutes query params, caching issues, often considered poor practice.

### Versioning Best Practices

- Avoid breaking changes — add fields, don't remove or rename
- Use semantic versioning: major version in URL for breaking changes
- Date-based versioning (Stripe model) with changelogs
- Maintain old versions for at least 12-24 months
- Deprecation headers: `Deprecation: true`, `Sunset: Sat, 31 Dec 2025 23:59:59 GMT`

---

## 14. Authentication

### API Keys

Simple. Key in header is preferred over query parameter (query params appear in logs):
```http
GET /orders
X-API-Key: sk_live_abc123def456
```

Or Authorization header:
```http
Authorization: ApiKey sk_live_abc123def456
```

**Best practices**: Prefix to identify type (`sk_live_`, `pk_test_`), allow rotation, log usage, rate limit per key.

### OAuth 2.0

Authorization framework (RFC 6749). Four grant types:

- **Authorization Code** — for user-delegated access, web/mobile apps. Supports PKCE for public clients.
- **Client Credentials** — service-to-service, no user involved
- **Implicit** — deprecated; use Authorization Code + PKCE instead
- **Resource Owner Password** — deprecated; only for migration scenarios

Tokens use `Authorization: Bearer <token>` header.

### JWT (JSON Web Token)

JWTs are stateless tokens encoding claims as JSON, signed with HMAC-SHA256 or RS256. Used as OAuth 2.0 access tokens (RFC 9068 defines JWT Profile for OAuth 2.0 Access Tokens).

Structure: `header.payload.signature` (base64url encoded)

Payload example:
```json
{
  "iss": "https://auth.example.com",
  "sub": "user-123",
  "aud": "https://api.example.com",
  "exp": 1714320000,
  "iat": 1714316400,
  "scope": "orders:read orders:write"
}
```

**Validation checklist**:
1. Verify signature using public key
2. Check `exp` not in past
3. Check `iss` matches expected issuer
4. Check `aud` includes your API
5. Check `scope` contains required permissions

---

## 15. CORS (Cross-Origin Resource Sharing)

Browsers block cross-origin XHR/fetch unless server sends proper CORS headers. APIs must handle this.

### Simple Requests

GET/POST with simple headers (no custom headers, Content-Type limited to form types) — no preflight, server just needs:
```http
Access-Control-Allow-Origin: https://app.example.com
```

### Preflight Requests

Triggered by: custom headers, PUT/PATCH/DELETE, Content-Type: application/json.

Browser sends OPTIONS request:
```http
OPTIONS /orders
Origin: https://app.example.com
Access-Control-Request-Method: POST
Access-Control-Request-Headers: Content-Type, Authorization
```

Server must respond:
```http
HTTP/1.1 204 No Content
Access-Control-Allow-Origin: https://app.example.com
Access-Control-Allow-Methods: GET, POST, PUT, PATCH, DELETE, OPTIONS
Access-Control-Allow-Headers: Content-Type, Authorization, X-Request-ID
Access-Control-Max-Age: 86400
```

`Access-Control-Max-Age` caches preflight for 86400 seconds (24h). Chrome caps at 2h, Firefox at 24h.

### Common CORS Errors

- `Access-Control-Allow-Origin` missing — server not configured for CORS
- `null` origin — file:// protocol or opaque origin; never use `*` for credentialed requests
- `Access-Control-Allow-Credentials: true` requires explicit non-wildcard origin
- Missing header in `Access-Control-Allow-Headers` — add custom header to allowlist
- Credentials not sent — client must set `credentials: 'include'` in fetch

---

## 16. Idempotency Keys

For non-idempotent POST requests (create operations, payments), clients generate a unique key to safely retry:

```http
POST /payments
Idempotency-Key: a1b2c3d4-e5f6-7890-abcd-ef1234567890
Content-Type: application/json

{ "amount": 100, "currency": "USD" }
```

Server stores result keyed by `Idempotency-Key` + endpoint + user. On duplicate, returns cached response without re-executing.

- Key format: UUID v4 recommended
- TTL: 24-48 hours typical (Stripe uses 24h)
- Scope: per user + per endpoint
- Response on duplicate: same body + `200 OK` (not 201)

---

## 17. Error Response Design

### Principles

- Always use correct HTTP status code
- Include machine-readable error type
- Include human-readable message for developers
- Include request identifier for support tracing
- Never expose stack traces or internal details in production

### RFC 9457 Problem Details (Recommended)

```json
HTTP/1.1 422 Unprocessable Entity
Content-Type: application/problem+json

{
  "type": "https://api.example.com/problems/validation-error",
  "title": "Validation Error",
  "status": 422,
  "detail": "Request body failed validation",
  "instance": "/errors/req-abc-123",
  "requestId": "req-abc-123",
  "errors": [
    {
      "field": "email",
      "code": "INVALID_FORMAT",
      "message": "Must be a valid email address"
    },
    {
      "field": "age",
      "code": "OUT_OF_RANGE",
      "message": "Must be between 0 and 120"
    }
  ]
}
```

---

## 18. API Gateways

### Kong

Open-source, plugin-based API gateway built on NGINX/OpenResty. Self-hosted or Kong Konnect (managed).

**Key features:**
- Plugin ecosystem (rate limiting, authentication, logging, transformation)
- Declarative configuration (deck CLI)
- Multi-cloud, multi-datacenter
- gRPC, WebSocket, REST support

**Rate limiting plugin config:**
```yaml
plugins:
  - name: rate-limiting
    config:
      minute: 100
      hour: 1000
      policy: redis
      redis_host: redis-host
      redis_port: 6379
```

Kong shares rate limit counters across nodes via Redis. Does not natively synchronize across geographic regions without cross-region Redis replication.

### Apigee (Google Cloud)

Enterprise API management platform. Strong analytics, developer portal, monetization.

**SpikeArrest policy** — smooths traffic spikes (per instance, not globally synchronized by default):
```xml
<SpikeArrest name="Spike-Arrest-1">
  <Rate>30pm</Rate>
  <Identifier ref="request.header.Authorization" />
</SpikeArrest>
```

**Quota policy** — enforces hard limits (can be globally synchronized):
```xml
<Quota name="Quota-1">
  <Allow countRef="verifyapikey.VerifyAPIKey-1.apiproduct.developer.quota.limit"/>
  <Interval ref="verifyapikey.VerifyAPIKey-1.apiproduct.developer.quota.interval"/>
  <TimeUnit ref="verifyapikey.VerifyAPIKey-1.apiproduct.developer.quota.timeunit"/>
  <Distributed>true</Distributed>
  <Synchronous>false</Synchronous>
</Quota>
```

### AWS API Gateway

Managed service tightly integrated with AWS ecosystem. Two types:
- **REST API** — full features (caching, API keys, usage plans, request validation, throttling)
- **HTTP API** — lower latency, lower cost, less features

**Throttling**: Account-level default 10,000 req/s burst, 5,000 req/s steady-state. Per-stage and per-route overrides via usage plans.

**Request transformation (VTL mapping templates):**
```json
#set($inputRoot = $input.path('$'))
{
  "userId": "$inputRoot.user_id",
  "timestamp": "$context.requestTime"
}
```

### Azure API Management (APIM)

Enterprise gateway with developer portal, analytics, policy pipeline.

**Rate limit policy:**
```xml
<rate-limit calls="20" renewal-period="90" retry-after-header-name="retry-after" />
<quota calls="10000" bandwidth="40000" renewal-period="3600" />
```

Supports inbound/outbound/backend/error policy sections. Caching, JWT validation, IP filtering, transformation all via XML policies.

---

## 19. API Testing Tools

### curl

```bash
# GET with auth
curl -H "Authorization: Bearer $TOKEN" https://api.example.com/orders

# POST with JSON body
curl -X POST https://api.example.com/orders \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: $(uuidgen)" \
  -d '{"customerId": "123", "items": [{"productId": "abc", "qty": 2}]}'

# PATCH with ETag conditional
curl -X PATCH https://api.example.com/users/123 \
  -H "If-Match: \"etag-value\"" \
  -H "Content-Type: application/merge-patch+json" \
  -d '{"email": "new@example.com"}'

# Verbose output for debugging
curl -v -o /dev/null -w "%{http_code}" https://api.example.com/health
```

### HTTPie

More readable CLI alternative to curl:
```bash
http GET https://api.example.com/orders \
  Authorization:"Bearer $TOKEN" \
  Accept:application/json

http POST https://api.example.com/orders \
  customerId=123 items:='[{"productId":"abc","qty":2}]'
```

### Postman

GUI tool. Features: Collections, environments, automated tests (JavaScript), Newman CLI runner, Mock Servers, Documentation generation. Can import/export OpenAPI specs.

**Pre-request script example:**
```javascript
pm.environment.set("timestamp", new Date().toISOString());
```

**Test script example:**
```javascript
pm.test("Status is 201", () => pm.response.to.have.status(201));
pm.test("Location header present", () => pm.response.to.have.header("Location"));
const body = pm.response.json();
pm.environment.set("orderId", body.id);
```

---

## 20. Common Diagnostics

### CORS Errors

```
Access to fetch at 'https://api.example.com' from origin 'https://app.example.com' has been blocked by CORS policy: No 'Access-Control-Allow-Origin' header is present.
```
Fix: Add CORS middleware/headers. Ensure OPTIONS handler returns correct headers.

```
The value of the 'Access-Control-Allow-Origin' header must not be the wildcard '*' when the request's credentials mode is 'include'.
```
Fix: Set explicit origin, not `*`, when using credentials.

### Content-Type Errors

```
415 Unsupported Media Type
```
Fix: Set `Content-Type: application/json` on requests with body. Check API expects the media type you send.

### Pagination Edge Cases

- **Empty page**: Return `data: []`, not 404
- **Over-limit page**: Return empty, not error (unless you validate page number)
- **Cursor invalidation**: Cursors can expire; client should handle 400/422 with "CURSOR_EXPIRED" error code and restart from beginning

### 401 vs 403

- `401` — No valid credentials provided (add/fix `Authorization` header)
- `403` — Valid credentials but insufficient permissions (different resource or role required)

### Debug Headers

Add `X-Request-ID` to every request. Server echoes it in response. Enables log correlation:
```http
X-Request-ID: req-abc-123-def-456
X-Correlation-ID: correlation-xyz-789
```

---

## 21. Documentation Generation

- **Swagger UI**: Interactive docs from OpenAPI spec. Self-hosted or via SwaggerHub.
- **Redoc**: Read-only docs, three-panel layout. Better for public-facing documentation.
- **Stoplight Elements**: Component-based, embeddable in any framework.
- **Scalar**: Modern, clean alternative to Swagger UI. Fast growing in 2024-2026.
- **Postman**: Auto-generates docs from collections. Hosted on Postman's servers.

For code generation from OpenAPI:
- `openapi-generator-cli` — 50+ languages/frameworks
- `oapi-codegen` — Go specific, high quality
- `kiota` — Microsoft's generator, good for complex APIs

---

## Key References

- REST Dissertation: Roy Fielding, Chapter 5 (2000)
- OpenAPI 3.1.2 spec: https://spec.openapis.org/oas/v3.1.2.html
- RFC 9457 Problem Details: https://www.rfc-editor.org/rfc/rfc9457.html
- RFC 9110 HTTP Semantics: https://www.rfc-editor.org/rfc/rfc9110.html
- JSON:API 1.1: https://jsonapi.org/format/
- HAL Specification: https://stateless.group/hal_specification.html
- Richardson Maturity Model: https://martinfowler.com/articles/richardsonMaturityModel.html
