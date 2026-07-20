# Backend API Foundational Concepts

## REST & HTTP Semantics

### HTTP Methods

| Method | Safe | Idempotent | Body | Use |
|---|---|---|---|---|
| GET | Yes | Yes | No | Retrieve a resource |
| HEAD | Yes | Yes | No | Headers only (existence check, caching) |
| OPTIONS | Yes | Yes | No | Discover allowed methods, CORS preflight |
| POST | No | No | Yes | Create a resource or trigger an action |
| PUT | No | Yes | Yes | Replace a resource entirely |
| PATCH | No | No* | Yes | Partial update |
| DELETE | No | Yes | Optional | Remove a resource |

**Safe**: No side effects. Caches and crawlers can call freely.
**Idempotent**: Calling N times produces the same result as calling once. Critical for retry safety.

*PATCH can be idempotent if designed as "set field to value" but the spec doesn't require it. "Increment counter by 1" is a non-idempotent PATCH.

### Status Codes (When to Use Which)

| Code | Name | When |
|---|---|---|
| **200** | OK | Successful GET, PUT, PATCH, DELETE with body |
| **201** | Created | Successful POST that created a resource. Include `Location` header. |
| **202** | Accepted | Async processing — request queued, return job URL |
| **204** | No Content | Successful DELETE or PUT/PATCH with no response body |
| **301** | Moved Permanently | Resource URL changed permanently (SEO redirect) |
| **304** | Not Modified | Conditional GET — ETag/If-Modified-Since matched |
| **400** | Bad Request | Malformed request (invalid JSON, missing required field) |
| **401** | Unauthorized | No credentials or invalid credentials (misnomer — means "unauthenticated") |
| **403** | Forbidden | Authenticated but not authorized for this resource |
| **404** | Not Found | Resource doesn't exist |
| **409** | Conflict | State conflict (duplicate creation, version mismatch) |
| **422** | Unprocessable Entity | Valid JSON but failed business validation |
| **429** | Too Many Requests | Rate limit exceeded. Include `Retry-After` header. |
| **500** | Internal Server Error | Unhandled server exception |
| **502** | Bad Gateway | Upstream service returned an invalid response |
| **503** | Service Unavailable | Server overloaded or in maintenance. Include `Retry-After`. |
| **504** | Gateway Timeout | Upstream service timed out |

### Error Response Format (RFC 7807 Problem Details)

```json
{
  "type": "https://api.example.com/errors/insufficient-funds",
  "title": "Insufficient funds",
  "status": 422,
  "detail": "Account balance is $30.00, but the transaction requires $50.00",
  "instance": "/transfers/txn-abc123",
  "balance": 30.00,
  "required": 50.00
}
```

Content-Type: `application/problem+json`. Extensible — add custom fields alongside standard ones.

## API Versioning

| Strategy | Example | Pros | Cons |
|---|---|---|---|
| **URL path** | `/v2/users` | Simple, visible, cacheable | URL changes, breaks REST purists |
| **Header** | `Accept: application/vnd.api.v2+json` | Clean URLs, content negotiation | Harder to test (curl), less discoverable |
| **Query param** | `/users?version=2` | Easy to add, optional | Pollutes query string, caching complications |

**Recommendation**: URL path versioning for public APIs (simplest for consumers). Header versioning for internal APIs where you control all clients.

**Deprecation signaling**:
```
Sunset: Sat, 01 Nov 2026 00:00:00 GMT
Deprecation: true
Link: <https://api.example.com/v3/users>; rel="successor-version"
```

## Pagination

### Offset Pagination

```
GET /users?offset=20&limit=10
```

- **Pros**: Simple, supports "jump to page N", familiar UI
- **Cons**: Skips or duplicates when data changes between pages. Slow for large offsets (`OFFSET 100000` scans and discards rows).

### Cursor Pagination

```
GET /users?cursor=eyJpZCI6MTAwfQ&limit=10

Response:
{
  "data": [...],
  "cursors": {
    "next": "eyJpZCI6MTEwfQ",
    "prev": "eyJpZCI6MTAwfQ"
  }
}
```

- **Pros**: Consistent results even with concurrent writes. Efficient for databases (WHERE id > cursor LIMIT N).
- **Cons**: No "jump to page N". Cursor is opaque (base64-encoded query state).

### Keyset Pagination

```
GET /users?after_id=100&limit=10
-- WHERE id > 100 ORDER BY id LIMIT 10
```

- **Pros**: Most efficient. No OFFSET scan. Consistent.
- **Cons**: Requires a unique, ordered column. Complex for multi-column sorts.

**Recommendation**: Cursor/keyset for infinite scroll and APIs. Offset only when "page N" navigation is a hard requirement.

## Authentication Paradigms

### Session vs JWT

| Aspect | Session-Based | JWT (Token-Based) |
|---|---|---|
| **State** | Server stores session (Redis, DB) | Stateless — token contains claims |
| **Revocation** | Instant (delete session) | Hard (wait for expiry or maintain blocklist) |
| **Scalability** | Requires shared session store | Scales horizontally — no shared state |
| **CSRF** | Vulnerable (cookie-based) | Not vulnerable (token in header) |
| **XSS** | Cookie HTTPOnly protects session ID | Token in localStorage is XSS-vulnerable |
| **Best for** | Server-rendered web apps, same-origin | SPAs, mobile apps, cross-origin APIs |

### JWT Structure

```
Header.Payload.Signature

Header:  {"alg": "RS256", "typ": "JWT"}
Payload: {"sub": "user123", "exp": 1700000000, "roles": ["admin"]}
Signature: RSA-SHA256(base64(header) + "." + base64(payload), private_key)
```

**Access + Refresh token pattern**:
- Access token: Short-lived (15 min). Sent with every request.
- Refresh token: Long-lived (7 days). Stored securely. Used to get new access tokens.
- Revocation: Revoke the refresh token. Access token expires naturally.

### OAuth 2.0 Flows

| Flow | For | How |
|---|---|---|
| **Authorization Code + PKCE** | Web apps, mobile, SPAs | Redirect to IdP → auth code → exchange for tokens. **Use PKCE for ALL clients** (RFC 9700). |
| **Client Credentials** | Service-to-service (machine) | Client sends client_id + client_secret → gets token. No user involved. |
| **Device Code** | TVs, CLI tools, IoT | Device shows code → user enters on another device → device polls for token. |

### CORS

```
# Preflight request (browser sends automatically for non-simple requests)
OPTIONS /api/users
Origin: https://app.example.com
Access-Control-Request-Method: POST
Access-Control-Request-Headers: Content-Type, Authorization

# Server response
Access-Control-Allow-Origin: https://app.example.com
Access-Control-Allow-Methods: GET, POST, PUT, DELETE
Access-Control-Allow-Headers: Content-Type, Authorization
Access-Control-Max-Age: 86400
Access-Control-Allow-Credentials: true
```

**Rules**:
- `Access-Control-Allow-Origin: *` cannot be used with `Allow-Credentials: true`
- Preflight is cached per `Max-Age` — keep it high (86400s = 24h) to reduce OPTIONS requests
- Simple requests (GET/POST with standard headers) skip preflight

## Rate Limiting

### Algorithms

| Algorithm | How | Trade-offs |
|---|---|---|
| **Token Bucket** | Bucket fills at steady rate, each request drains a token | Allows bursts up to bucket size. Most common. |
| **Sliding Window** | Count requests in a rolling time window | No burst, smooth limiting. More memory. |
| **Fixed Window** | Count requests per calendar window (per minute) | Simple but allows 2x burst at window boundary. |
| **Leaky Bucket** | Requests queue and drain at fixed rate | Smoothest output but adds latency. |

**Response headers** (draft standard):
```
RateLimit-Limit: 100
RateLimit-Remaining: 42
RateLimit-Reset: 1700000060
Retry-After: 30
```

## Caching

### HTTP Caching Headers

```
# Server response — cacheable for 5 minutes, revalidate after
Cache-Control: max-age=300, must-revalidate
ETag: "abc123"

# Client conditional request
If-None-Match: "abc123"
# Server returns 304 Not Modified if ETag matches (no body transfer)

# Time-based
Last-Modified: Wed, 01 Apr 2026 12:00:00 GMT
If-Modified-Since: Wed, 01 Apr 2026 12:00:00 GMT
```

### Cache-Control Directives

| Directive | Meaning |
|---|---|
| `public` | Any cache (CDN, proxy, browser) can store |
| `private` | Only the browser can cache (user-specific data) |
| `no-cache` | Cache but revalidate before every use |
| `no-store` | Never cache (sensitive data) |
| `max-age=N` | Fresh for N seconds |
| `stale-while-revalidate=N` | Serve stale while fetching fresh in background |

## API Design Patterns

### Resource Modeling

```
# Resources are nouns, not verbs
GET    /users           # List users
POST   /users           # Create user
GET    /users/123       # Get user 123
PUT    /users/123       # Replace user 123
PATCH  /users/123       # Partial update user 123
DELETE /users/123       # Delete user 123

# Sub-resources
GET    /users/123/orders         # User 123's orders
POST   /users/123/orders         # Create order for user 123
GET    /users/123/orders/456     # Specific order

# Actions (when CRUD doesn't fit)
POST   /orders/456/cancel        # Trigger action
POST   /users/123/reset-password # Trigger action
```

### Idempotency Keys

For non-idempotent operations (POST), let clients retry safely:

```
POST /payments
Idempotency-Key: 7a3f-4b2c-8d1e
Content-Type: application/json

{"amount": 100, "currency": "USD", "recipient": "user456"}
```

Server stores the idempotency key + response for 24h. Duplicate requests return the stored response without re-executing.

### Webhooks

```json
POST https://client.example.com/webhooks/orders
Content-Type: application/json
X-Webhook-Signature: sha256=abc123...
X-Webhook-ID: evt_12345
X-Webhook-Timestamp: 1700000000

{
  "event": "order.completed",
  "data": { "order_id": "456", "total": 99.99 }
}
```

**Delivery guarantees**: At-least-once with exponential backoff retry (1min, 5min, 30min, 2h, 24h). Consumers must be idempotent — use `X-Webhook-ID` for deduplication.

### GraphQL vs REST vs gRPC

| Dimension | REST | GraphQL | gRPC |
|---|---|---|---|
| **Protocol** | HTTP/1.1 or 2 | HTTP (single POST endpoint) | HTTP/2 (binary, streaming) |
| **Data format** | JSON | JSON | Protocol Buffers (binary) |
| **Schema** | OpenAPI (optional) | Schema Definition Language (required) | .proto files (required) |
| **Over-fetching** | Common (fixed response shape) | Eliminated (client specifies fields) | Eliminated (defined messages) |
| **Best for** | Public APIs, CRUD, simple | Complex client-driven queries, mobile | Internal services, streaming, performance |
| **Caching** | HTTP caching works natively | Harder (POST-only, custom caching) | No HTTP caching (binary) |
| **Tooling** | Mature, universal | Specialized (Apollo, Relay) | Code generation required |

## Performance Patterns

### Connection Pooling

Every backend framework needs database connection pooling. Creating a connection per request is catastrophically slow.

| Framework | Default Pool |
|---|---|
| Django | `CONN_MAX_AGE` (per-thread, not a pool by default — use `django-db-connection-pool`) |
| Rails | `pool: 5` in `database.yml` (connection pool per process) |
| Spring Boot | HikariCP (10 connections default, excellent defaults) |
| ASP.NET Core | ADO.NET built-in pool (100 max default) |
| Express | Depends on driver (pg pool, mongoose) |
| FastAPI | SQLAlchemy pool or async driver pool |

**Pool sizing rule**: `pool_size = (core_count * 2) + effective_spindle_count`. For SSDs, 10-20 connections handles more load than most people expect. Larger pools increase lock contention.

### Async vs Sync

| Workload | Better Model | Why |
|---|---|---|
| **I/O-bound** (DB calls, HTTP calls, file reads) | Async | Release the thread while waiting, handle more concurrent requests |
| **CPU-bound** (image processing, ML inference) | Sync + worker processes | Async doesn't help — the CPU is busy regardless |
| **Mixed** | Async with CPU work offloaded to thread pool | Best of both worlds |

**The async trap**: Making a synchronous ORM call inside an async handler blocks the event loop. Either use async drivers or offload to a thread pool.

### Background Job Patterns

For work that doesn't need to complete during the HTTP request:

```
Client → API → Queue (Redis, RabbitMQ, SQS) → Worker → Result

Response: 202 Accepted
{
  "job_id": "job_abc123",
  "status_url": "/jobs/job_abc123"
}
```

Frameworks with built-in job support: Rails (Active Job + Solid Queue), Django (Celery, django-q2, Huey), Spring Boot (Spring Batch, `@Async`), ASP.NET Core (Hangfire, hosted services).
