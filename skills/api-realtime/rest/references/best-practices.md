# REST Best Practices

## Pagination Patterns

### Offset Pagination

Simplest approach. `?limit=20&offset=40` or `?page=3&per_page=20`.

```json
{
  "data": [...],
  "pagination": { "total": 1543, "page": 3, "per_page": 20, "pages": 78 }
}
```

**Drawbacks:** Page drift on inserts/deletes during traversal. Poor performance on large offsets (database scans and discards rows). Not suitable for frequently-updated data.

### Cursor Pagination

Server returns opaque cursor. Client passes it for next page:
```json
{
  "data": [...],
  "pagination": { "next_cursor": "eyJpZCI6MTIzfQ==", "has_more": true }
}
```

Request: `GET /orders?limit=20&cursor=eyJpZCI6MTIzfQ==`

**Advantages:** Stable during mutations, consistent performance. **Drawbacks:** Cannot jump to arbitrary page.

### Keyset Pagination (Seek Method)

Uses indexed column values as starting point:
```
GET /orders?limit=20&after_id=500&after_created_at=2024-01-15T10:00:00Z
```

Server generates: `WHERE (created_at, id) > (...) ORDER BY created_at, id LIMIT 20`

**Best for:** Large datasets with stable sort order. Requires composite index.

### Link Header Pagination (RFC 5988)

```http
Link: </orders?page=2>; rel="next", </orders?page=78>; rel="last"
```

Used by GitHub API. RESTful approach with pagination links in headers.

## Caching

### ETag and Conditional Requests

Server generates hash/version token. Client stores it and sends on subsequent requests:

```http
GET /users/123
HTTP/1.1 200 OK
ETag: "33a64df551425fcc55e4d42a148795d9f25f89d4"
Cache-Control: max-age=3600

GET /users/123
If-None-Match: "33a64df551425fcc55e4d42a148795d9f25f89d4"

HTTP/1.1 304 Not Modified
```

### Optimistic Concurrency

Prevent lost updates with ETag:
```http
PATCH /users/123
If-Match: "33a64df551425fcc55e4d42a148795d9f25f89d4"
Content-Type: application/json
{"email": "new@example.com"}

HTTP/1.1 412 Precondition Failed
```

### Cache-Control Directives

- `no-store` -- never cache (sensitive data)
- `no-cache` -- always revalidate before serving
- `max-age=3600` -- cache for 1 hour
- `private` -- browser cache only, not CDN
- `public, max-age=86400` -- cacheable by anyone for 1 day

### CDN Caching

CDNs cache REST GET responses at the edge:
- `Cache-Control` headers determine TTL
- `Vary` header for content negotiation
- Purge API for cache invalidation on writes
- Configure: `Vary: Accept, Authorization` when responses differ by these headers

## Versioning Strategies

### URL Path (Most Common)
```
GET /v1/orders
GET /v2/orders
```
**Used by:** Stripe, GitHub, Google. **Pros:** Explicit, cacheable, visible. **Cons:** URL pollution.

### Header
```
API-Version: 2024-11-01
```
**Used by:** Stripe (date-based), Anthropic. **Pros:** Clean URLs. **Cons:** Hidden, harder to test.

### Content Negotiation
```
Accept: application/vnd.myapi.v2+json
```
**Pros:** True REST. **Cons:** Complex for clients.

### Best Practices

- Version from day one
- Avoid breaking changes -- add fields, do not remove or rename
- Maintain old versions for 12-24 months minimum
- Use deprecation headers: `Deprecation: true`, `Sunset: Sat, 31 Dec 2025 23:59:59 GMT`
- Semantic versioning: major for breaking changes

## Error Handling

### RFC 9457 Problem Details

```json
HTTP/1.1 422 Unprocessable Entity
Content-Type: application/problem+json

{
  "type": "https://api.example.com/problems/validation-error",
  "title": "Validation Error",
  "status": 422,
  "detail": "Request body failed validation",
  "instance": "/errors/req-abc-123",
  "errors": [
    { "field": "email", "code": "INVALID_FORMAT", "message": "Must be a valid email" },
    { "field": "age", "code": "OUT_OF_RANGE", "message": "Must be between 0 and 120" }
  ]
}
```

### Error Design Principles

- Always use correct HTTP status code
- Include machine-readable error type (`type` field)
- Include human-readable message for developers
- Include request identifier for support tracing
- Never expose stack traces in production
- Use extensions for domain-specific error details

## Rate Limiting

### Headers

```http
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 847
X-RateLimit-Reset: 1714320000
Retry-After: 60
```

On rate limit: return `429 Too Many Requests` with `Retry-After`.

### Gateway Configuration

**Kong:**
```yaml
plugins:
  - name: rate-limiting
    config:
      minute: 100
      hour: 1000
      policy: redis
      redis_host: redis-host
```

**Azure APIM:**
```xml
<rate-limit calls="20" renewal-period="90" />
<quota calls="10000" renewal-period="3600" />
```

**AWS API Gateway:** Account-level default 10,000 req/s burst, 5,000 steady-state. Per-stage and per-route overrides via usage plans.

## Idempotency Keys

For non-idempotent POST operations (payments, creates):
```http
POST /payments
Idempotency-Key: a1b2c3d4-e5f6-7890-abcd-ef1234567890
Content-Type: application/json
{"amount": 100, "currency": "USD"}
```

- Key format: UUID v4
- TTL: 24-48 hours (Stripe uses 24h)
- Scope: per user + per endpoint
- On duplicate: return cached response with `200 OK` (not 201)

## CORS Configuration

### Preflight Requests

Browser sends OPTIONS before PUT/PATCH/DELETE or requests with custom headers:
```http
OPTIONS /orders
Origin: https://app.example.com
Access-Control-Request-Method: POST
Access-Control-Request-Headers: Content-Type, Authorization
```

Server responds:
```http
HTTP/1.1 204 No Content
Access-Control-Allow-Origin: https://app.example.com
Access-Control-Allow-Methods: GET, POST, PUT, PATCH, DELETE
Access-Control-Allow-Headers: Content-Type, Authorization, X-Request-ID
Access-Control-Max-Age: 86400
```

### Key Rules

- `Access-Control-Allow-Origin: *` is incompatible with `Access-Control-Allow-Credentials: true`
- `Access-Control-Max-Age` caches preflight (Chrome caps at 2h, Firefox at 24h)
- Credentials require explicit non-wildcard origin
- Client must set `credentials: 'include'` in fetch

## Bulk Operations

**POST with array:**
```json
POST /orders/batch
{"operations": [
  {"method": "CREATE", "data": {...}},
  {"method": "UPDATE", "id": "123", "data": {...}}
]}
```

**Partial success:** Return `207 Multi-Status`:
```json
[
  {"id": "op1", "status": 201, "data": {...}},
  {"id": "op2", "status": 422, "error": "Validation failed"}
]
```

## Async Patterns

### 202 Accepted + Polling

```http
POST /reports/generate
HTTP/1.1 202 Accepted
Location: /jobs/abc-123
Retry-After: 30

{"jobId": "abc-123", "status": "processing", "statusUrl": "/jobs/abc-123"}
```

### Webhook Callbacks

Client registers callback URL. Server POSTs when done. Validate webhook signatures (HMAC-SHA256).

## Authentication Best Practices

### API Keys
- Prefix to identify type: `sk_live_`, `pk_test_`
- Header preferred over query param (query params in logs)
- Allow rotation, log usage, rate limit per key

### OAuth 2.0
- Authorization Code + PKCE for browser/mobile
- Client Credentials for service-to-service
- Tokens via `Authorization: Bearer <token>`

### JWT Validation Checklist
1. Verify signature using public key
2. Check `exp` not in past
3. Check `iss` matches expected issuer
4. Check `aud` includes your API
5. Check `scope` contains required permissions

## Testing

### curl Examples
```bash
# GET with auth
curl -H "Authorization: Bearer $TOKEN" https://api.example.com/orders

# POST with JSON
curl -X POST https://api.example.com/orders \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: $(uuidgen)" \
  -d '{"customerId": "123"}'

# Conditional PATCH
curl -X PATCH https://api.example.com/users/123 \
  -H "If-Match: \"etag-value\"" \
  -H "Content-Type: application/merge-patch+json" \
  -d '{"email": "new@example.com"}'
```

### Postman Test Scripts
```javascript
pm.test("Status is 201", () => pm.response.to.have.status(201));
pm.test("Location header", () => pm.response.to.have.header("Location"));
pm.environment.set("orderId", pm.response.json().id);
```
