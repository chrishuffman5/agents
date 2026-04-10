# REST & HTTP Fundamentals

## HTTP Method Semantics and Idempotency

### Method Definitions

| Method  | Safe | Idempotent | Body   | Primary Use                              |
|---------|------|------------|--------|------------------------------------------|
| GET     | Yes  | Yes        | No*    | Retrieve resource representation         |
| HEAD    | Yes  | Yes        | No     | Same as GET, headers only (no body)      |
| OPTIONS | Yes  | Yes        | No     | Discover allowed methods, preflight      |
| DELETE  | No   | Yes        | Opt.   | Remove resource                          |
| PUT     | No   | Yes        | Yes    | Replace resource (full update)           |
| PATCH   | No   | No*        | Yes    | Partial update                           |
| POST    | No   | No         | Yes    | Create resource, trigger action          |

**Safe**: No observable side effects; caches and proxies may repeat freely.  
**Idempotent**: Repeating N times produces the same result as calling once.

PATCH idempotency nuance: PATCH *can* be designed to be idempotent (e.g., `SET field=value`) but the spec does not require it. A PATCH that says "increment counter by 1" is not idempotent.

PUT requires sending the complete resource representation. Sending a partial PUT is a client bug — the server replaces the resource entirely.

```
# Idempotent DELETE — safe to retry on network failure
DELETE /orders/123
# Second call returns 404 but the outcome (resource gone) is the same

# Non-idempotent POST — retrying creates duplicates
POST /orders
{"item": "widget", "qty": 1}
```

### Method Tunneling Anti-Patterns
Avoid: `POST /deleteUser`, `GET /createOrder`. These destroy cacheability, break HTTP semantics, and confuse proxies. Use proper methods. The one legitimate override is `X-HTTP-Method-Override` header for clients that can only send GET/POST (rare legacy scenarios).

---

## HTTP Status Codes

### 2xx — Success

| Code | Name                | Use Case                                                  |
|------|---------------------|-----------------------------------------------------------|
| 200  | OK                  | Successful GET, PUT, PATCH, DELETE with body              |
| 201  | Created             | Successful POST that created a resource; include Location header |
| 202  | Accepted            | Request accepted, processing async; return task/job URL   |
| 204  | No Content          | Successful DELETE or PUT/PATCH with no response body      |
| 206  | Partial Content     | Range requests (video streaming, large file downloads)    |

```
HTTP/1.1 201 Created
Location: /orders/456
Content-Type: application/json

{"id": "456", "status": "pending"}
```

### 3xx — Redirection

| Code | Name               | Use Case                                                  |
|------|--------------------|-----------------------------------------------------------|
| 301  | Moved Permanently  | Resource permanently at new URL; client should update bookmarks |
| 302  | Found              | Temporary redirect; client should use original URL next time |
| 304  | Not Modified       | Conditional request; cached version is still valid        |
| 307  | Temporary Redirect | Like 302 but method MUST NOT change (POST stays POST)     |
| 308  | Permanent Redirect | Like 301 but method MUST NOT change                       |

301/302 allow browsers to change POST to GET on redirect. Use 307/308 when you need to preserve method.

### 4xx — Client Errors

| Code | Name                  | Use Case                                                       |
|------|-----------------------|----------------------------------------------------------------|
| 400  | Bad Request           | Malformed syntax, invalid payload, failed validation           |
| 401  | Unauthorized          | Missing or invalid authentication (misleadingly named)         |
| 403  | Forbidden             | Authenticated but lacks permission                             |
| 404  | Not Found             | Resource doesn't exist                                         |
| 405  | Method Not Allowed    | HTTP method not supported; include Allow header                |
| 409  | Conflict              | State conflict (duplicate key, optimistic lock failure)        |
| 410  | Gone                  | Resource permanently deleted (stronger than 404)              |
| 412  | Precondition Failed   | If-Match ETag mismatch (optimistic concurrency)                |
| 415  | Unsupported Media     | Content-Type not supported                                     |
| 422  | Unprocessable Entity  | Syntactically valid but semantically invalid (validation errors) |
| 429  | Too Many Requests     | Rate limit exceeded; include Retry-After header                |

401 vs 403: 401 means "authenticate first." 403 means "you're authenticated but not allowed." Never return 404 to hide existence of a forbidden resource from authenticated users — use 403.

### 5xx — Server Errors

| Code | Name                  | Use Case                                                  |
|------|-----------------------|-----------------------------------------------------------|
| 500  | Internal Server Error | Unexpected server failure; don't leak stack traces        |
| 501  | Not Implemented       | Method recognized but not implemented                     |
| 502  | Bad Gateway           | Upstream server returned invalid response                 |
| 503  | Service Unavailable   | Server overloaded or in maintenance; include Retry-After  |
| 504  | Gateway Timeout       | Upstream server timed out                                 |

---

## Content Negotiation

### Request Headers
```
Accept: application/json, application/xml;q=0.9, */*;q=0.8
Accept-Encoding: gzip, br, deflate
Accept-Language: en-US, en;q=0.9
Accept-Charset: utf-8 (obsolete; assume UTF-8)
```

`q` values (quality factors) range 0–1. Default is 1.0. Server picks highest-quality format it supports.

### Response Headers
```
Content-Type: application/json; charset=utf-8
Content-Encoding: gzip
Content-Language: en
Vary: Accept, Accept-Encoding
```

`Vary` is critical for caching — tells CDNs/proxies which request headers affect the response. Missing `Vary: Accept` on a content-negotiated endpoint causes caches to serve wrong format.

### Media Types of Note
- `application/json` — standard JSON
- `application/problem+json` — RFC 7807 error responses
- `application/merge-patch+json` — RFC 7396 merge patch (PATCH body format)
- `application/json-patch+json` — RFC 6902 JSON Patch operations
- `multipart/form-data` — file uploads
- `application/x-www-form-urlencoded` — legacy form data
- `application/octet-stream` — binary/arbitrary bytes

---

## REST Constraints (Fielding's Dissertation)

### 1. Client-Server
Separation of concerns: client manages UI/user state; server manages data/business logic. They evolve independently.

### 2. Statelessness
Each request must contain all information to process it. **No session state on the server.** Authentication token, pagination cursor, tenant ID — all must travel in the request.

Trade-off: Increases per-request overhead (token validation on every call) but enables horizontal scaling without sticky sessions.

### 3. Cacheability
Responses must declare themselves cacheable or not. Cacheable responses reduce load and latency.

### 4. Uniform Interface
Four constraints:
- **Resource identification**: URIs identify resources; representation may differ from storage form
- **Manipulation through representations**: client holds enough info to modify/delete via representation
- **Self-descriptive messages**: each message includes enough info to describe how to process it (Content-Type, etc.)
- **HATEOAS**: responses include links to related actions (see Hypermedia section in design-patterns.md)

### 5. Layered System
Client cannot tell if it's talking directly to origin or a proxy/CDN/load balancer.

### 6. Code on Demand (optional)
Server can extend client functionality by sending executable code (JavaScript). Rarely used in API design.

### Practical REST vs. "REST-ish"
Most real-world "REST APIs" are actually REST-ish (Level 2 on Richardson Maturity Model):
- Level 0: Single endpoint, POST everything (XML-RPC style)
- Level 1: Multiple resources (separate URIs)
- Level 2: HTTP verbs + status codes (most APIs)
- Level 3: Hypermedia controls (HATEOAS) — rare, but adopted by some (GitHub, Stripe partial)

---

## API Versioning Strategies

### URL Path Versioning
```
GET /v1/users/123
GET /v2/users/123
```
**Pros**: Explicit, easy to route in reverse proxy, easy to test/bookmark, shows up in logs/analytics unambiguously.  
**Cons**: Not "pure REST" (version is not a resource property), forces URL changes on clients, encourages parallel codebases.

**Best for**: Public APIs, APIs with long-term support requirements, when different versions are genuinely different APIs.

### Header Versioning
```
GET /users/123
API-Version: 2024-01-15
Accept: application/vnd.myapi.v2+json
```
**Pros**: Clean URLs, version doesn't pollute URI space.  
**Cons**: Not cacheable by default (need `Vary: API-Version`), harder to test in browser, less visible in logs.

Date-based versioning (used by Stripe, Anthropic): `API-Version: 2024-11-01`. Version header picks the behavior snapshot. Easier to deprecate incrementally.

### Query Parameter Versioning
```
GET /users/123?version=2
GET /users/123?api-version=2024-01-15
```
**Pros**: Works everywhere, easy to test.  
**Cons**: Pollutes query strings, easy to forget, caching issues.

**Recommendation for new APIs**: URL path (`/v1/`) for major breaking changes; header-based date versioning for incremental changes within a major version (Stripe's hybrid model).

### Version Lifecycle Management
- Announce deprecation at least 6 months in advance for public APIs
- Include `Deprecation: true` and `Sunset: Sat, 01 Jan 2026 00:00:00 GMT` headers (RFC 8594)
- Maintain old version in read-only/frozen state before sunset
- Monitor version usage before turning off

---

## Pagination Patterns

### Offset/Limit Pagination
```
GET /users?offset=20&limit=10
GET /users?page=3&per_page=10

{
  "data": [...],
  "pagination": {
    "total": 253,
    "offset": 20,
    "limit": 10,
    "next": "/users?offset=30&limit=10",
    "prev": "/users?offset=10&limit=10"
  }
}
```
**Pros**: Random access, easy to jump to page N, familiar to users.  
**Cons**: Drifts on inserts/deletes (items can appear twice or be skipped), expensive COUNT(*) on large datasets, N+offset DB scan.

**Use when**: Data is relatively stable, users need random page access, dataset is small-medium.

### Cursor-Based Pagination
```
GET /posts?cursor=eyJpZCI6MTAwfQ&limit=20

{
  "data": [...],
  "pagination": {
    "next_cursor": "eyJpZCI6MTIwfQ",
    "has_more": true
  }
}
```
Cursor encodes position (often base64 of `{"id": 100, "created_at": "2024-01-15T10:00:00Z"}`). Server decodes cursor to reconstruct WHERE clause.

**Pros**: Stable during concurrent writes, efficient (no COUNT, index seek), consistent results.  
**Cons**: No random access, can't jump to page N, cursor must be opaque to clients (change freely server-side).

**Use when**: Real-time feeds, large datasets, frequent inserts/deletes, infinite scroll UIs.

### Keyset Pagination
```
GET /orders?after_id=1234&limit=20
GET /orders?after_created_at=2024-01-15T10:00:00Z&limit=20
```
Keyset is cursor pagination where the cursor values are exposed directly. Simpler but ties API to DB schema.

**Pros**: Highly efficient (uses index), stable results.  
**Cons**: Exposes internal identifiers, breaks if sort key has duplicates (use composite key).

### Link Header vs Body Pagination
RFC 5988 Web Linking — include pagination links in `Link` header:
```
Link: </users?offset=30&limit=10>; rel="next",
      </users?offset=10&limit=10>; rel="prev",
      </users?offset=0&limit=10>; rel="first",
      </users?offset=240&limit=10>; rel="last"
```
GitHub uses this pattern. Body pagination (JSON envelope) is more common for REST APIs.

---

## Filtering, Sorting, Field Selection

### Filtering
```
# Simple equality
GET /users?status=active&role=admin

# Range (various conventions)
GET /orders?created_after=2024-01-01&created_before=2024-03-31
GET /products?price[gte]=10&price[lte]=100    # bracket notation
GET /products?price_min=10&price_max=100       # explicit params

# Complex: avoid ad-hoc query languages, use FIQL or structured params
GET /users?filter=status==active,age=gt=18
```

**Security**: Always whitelist filterable fields. Never pass filter values directly to SQL. Validate field names against allowlist.

### Sorting
```
GET /users?sort=created_at&order=desc
GET /users?sort=-created_at              # minus prefix = descending
GET /users?sort=last_name,first_name     # multi-field
GET /users?sort=-score,+name             # mixed directions
```

Always define a stable default sort (usually by ID or created_at) to ensure deterministic pagination.

### Sparse Fieldsets / Field Selection
```
GET /users?fields=id,name,email
GET /users?include=profile&exclude=password_hash

Response:
{
  "id": 123,
  "name": "Alice",
  "email": "alice@example.com"
}
```
**Pros**: Reduces payload size, useful for mobile clients, avoids over-fetching.  
**Cons**: Increases server complexity, caching becomes harder (field sets vary).

---

## Rate Limiting and Throttling

### Algorithms

**Token Bucket**: Bucket has capacity N, refills at rate R tokens/second. Each request consumes tokens. Allows bursting up to capacity.
- Best for: APIs that should allow occasional bursts but maintain average rate.

**Leaky Bucket**: Requests enter queue at any rate, processed at fixed rate. Smooths traffic.
- Best for: upstream protection, preventing thundering herd.

**Fixed Window**: Count requests per fixed time window (e.g., 1000 req/minute). Resets at window boundary.
- Weakness: burst at window boundary (1000 at :59 + 1000 at :01 = 2000 in 2 seconds).

**Sliding Window Log**: Track timestamp of each request, count in rolling window.
- Most accurate, but memory-intensive (stores all request timestamps).

**Sliding Window Counter**: Approximate sliding window using weighted blend of current and previous window counts.
- Good balance of accuracy and memory efficiency.

### Headers
```
# Standard (RateLimit header, RFC draft)
RateLimit-Limit: 1000
RateLimit-Remaining: 847
RateLimit-Reset: 1704067200      # Unix timestamp when window resets

# Alternative (GitHub-style)
X-RateLimit-Limit: 5000
X-RateLimit-Remaining: 4847
X-RateLimit-Reset: 1704067200
X-RateLimit-Used: 153

# On 429 response
Retry-After: 30    # seconds to wait, OR
Retry-After: Thu, 01 Jan 2026 12:00:00 GMT
```

### Rate Limit Scopes
- Per API key / per user: most common
- Per IP: fallback for unauthenticated endpoints
- Per endpoint: different limits for expensive vs cheap operations
- Global: system-wide circuit breaker

### Client Identification for Rate Limiting
Priority order for identifying clients:
1. API key (most reliable)
2. Authenticated user ID (JWT sub claim)
3. X-Forwarded-For (spoofable — validate against known proxy IPs)
4. Remote IP (last resort)

---

## HTTP Caching

### Cache-Control Directives
```
# Response directives
Cache-Control: max-age=3600           # cache for 1 hour
Cache-Control: no-cache               # revalidate before using cached copy
Cache-Control: no-store               # never cache (sensitive data)
Cache-Control: private                # browser-only, not CDN/proxy
Cache-Control: public                 # shareable by CDN/proxy
Cache-Control: s-maxage=3600          # CDN override for max-age
Cache-Control: stale-while-revalidate=60  # serve stale while fetching fresh
Cache-Control: must-revalidate        # don't serve stale even on error
Cache-Control: immutable              # never revalidate (for versioned assets)

# Request directives
Cache-Control: no-cache               # force revalidation
Cache-Control: no-store               # don't cache response
Cache-Control: max-age=0              # equivalent to no-cache for most purposes
```

### Conditional Requests (Validation Caching)

**ETag** (content-based hash or opaque version string):
```
# Server response
ETag: "686897696a7c876b7e"
ETag: W/"weakversion"    # weak ETag (semantically equivalent, not byte-identical)

# Client sends on subsequent request
If-None-Match: "686897696a7c876b7e"

# Server responds 304 if unchanged, 200 with new body+ETag if changed
```

**Last-Modified** (timestamp-based):
```
# Server response
Last-Modified: Wed, 15 Jan 2024 10:00:00 GMT

# Client sends on subsequent request
If-Modified-Since: Wed, 15 Jan 2024 10:00:00 GMT

# Server responds 304 if not modified since that time
```

**Conditional Updates** (optimistic concurrency):
```
# Fetch resource, note ETag
GET /users/123
ETag: "abc123"

# Update only if not changed since fetch (prevents lost updates)
PUT /users/123
If-Match: "abc123"
# Server returns 412 Precondition Failed if ETag no longer matches
```

### What to Cache vs. Not Cache
| Endpoint Type            | Strategy                               |
|--------------------------|----------------------------------------|
| GET /products (catalog)  | `public, max-age=300, s-maxage=3600`   |
| GET /users/me (profile)  | `private, max-age=60, no-store`        |
| GET /orders/123 (user)   | `private, max-age=30`                  |
| POST /orders (create)    | `no-store` (mutations never cache)     |
| GET /health              | `no-store`                             |
| Static assets (hashed)   | `public, max-age=31536000, immutable`  |

### Cache Invalidation Strategies
- **Versioned URLs** (`/assets/app.v2.js`): no invalidation needed, deploy new URL
- **Surrogate keys / cache tags** (CDN): tag responses, purge by tag on write (Fastly, Cloudflare)
- **Short TTLs**: let content expire naturally (simple but stale window)
- **Event-driven purge**: on data change, call CDN purge API

Cache invalidation is one of the two hardest problems in computer science. Design for stale-tolerance or short TTLs on dynamic content; rely on ETags for accuracy.
