# API Design Patterns

## Resource Modeling

### Nouns, Not Verbs
Resources are things; actions are expressed through HTTP methods on those things.

```
# Wrong — RPC-style
POST /createUser
POST /deleteUser
POST /getUserById
GET  /getAllActiveOrders
POST /cancelOrder

# Right — REST-style
POST   /users              # create user
DELETE /users/123          # delete user
GET    /users/123          # get user by ID
GET    /orders?status=active  # get active orders
POST   /orders/456/cancellation  # cancel order (noun for action)
```

When you genuinely need an action (not a CRUD operation), use a noun for the action itself:
- `/orders/456/cancellation` (POST to create a cancellation)
- `/payments/789/refunds` (POST to create a refund)
- `/users/123/password-reset` (POST to initiate reset)

### Resource Hierarchy and Nesting

Nest sub-resources when they only exist in context of parent:
```
GET    /users/123/orders          # orders belonging to user 123
POST   /users/123/orders          # create order for user 123
GET    /users/123/orders/456      # specific order for user 123
DELETE /users/123/orders/456      # delete specific order

GET    /repos/octocat/hello-world/issues/42  # GitHub pattern
```

**Limit nesting depth to 2 levels**. Deeper nesting is a smell — consider whether the sub-resource can stand alone:
```
# Problematic deep nesting
GET /companies/1/departments/2/teams/3/members/4/tasks/5

# Better — treat tasks as top-level with filters
GET /tasks/5
GET /tasks?team_id=3&member_id=4
```

### Singleton Sub-Resources
When a user has exactly one of something:
```
GET    /users/123/profile     # user's profile (one-to-one)
PUT    /users/123/profile     # replace profile
PATCH  /users/123/profile     # update profile fields
GET    /users/123/preferences
PATCH  /users/123/preferences
```

### Canonical URLs vs Alias URLs
Every resource should have one canonical URL. Aliases are acceptable but should redirect to canonical:
```
GET /users/123              # canonical
GET /users/alice@example.com  # alias — 301 redirect to canonical, or respond with Link: </users/123>; rel="canonical"
```

### URI Conventions
- Lowercase, hyphen-separated: `/order-items` not `/orderItems` or `/order_items`
- Plural nouns for collections: `/users` not `/user`
- No trailing slash (or consistently with — pick one)
- No file extensions: `/users.json` is wrong; use `Accept: application/json`
- No CRUD in URL: `/users/123/delete` is wrong

---

## Request/Response Patterns

### Envelope vs Flat Responses

**Flat Response**:
```json
{
  "id": "123",
  "name": "Alice",
  "email": "alice@example.com"
}
```
Pros: Simpler, more aligned with REST resource principle.  
Cons: No standardized place for metadata (pagination, status).

**Envelope Response**:
```json
{
  "data": {
    "id": "123",
    "name": "Alice"
  },
  "meta": {
    "request_id": "req_xyz789",
    "timestamp": "2024-01-15T10:00:00Z"
  }
}
```
Pros: Consistent structure, metadata slot, easier to evolve.  
Cons: Extra nesting, more verbose.

**Collection Envelope**:
```json
{
  "data": [...],
  "pagination": {
    "total": 253,
    "page": 2,
    "per_page": 20,
    "next": "/users?page=3",
    "prev": "/users?page=1"
  },
  "meta": {
    "request_id": "req_abc123"
  }
}
```

**Recommendation**: Use envelope for collections (need pagination metadata); flat or light envelope for single resources. Be consistent across the entire API.

### Error Response Formats

**RFC 7807 Problem Details** (strongly recommended):
```json
{
  "type": "https://api.example.com/errors/validation-failed",
  "title": "Validation Failed",
  "status": 422,
  "detail": "The request body contains invalid fields.",
  "instance": "/orders/failed-request-xyz",
  "errors": [
    {
      "field": "email",
      "code": "invalid_format",
      "message": "Must be a valid email address"
    },
    {
      "field": "quantity",
      "code": "out_of_range",
      "message": "Must be between 1 and 100"
    }
  ],
  "request_id": "req_xyz789"
}
```
Content-Type: `application/problem+json`  
`type` URI should be a URL that documents the error type (or a URN).  
`instance` identifies this specific occurrence.

**Fields**:
- `type`: URI identifying error type (REQUIRED)
- `title`: Human-readable summary (REQUIRED)
- `status`: HTTP status code (SHOULD)
- `detail`: Human-readable explanation of this occurrence (SHOULD)
- `instance`: URI for this occurrence (MAY)
- Extension members: `errors`, `request_id`, `docs_url` — any additional fields

**Machine-readable error codes**:
```json
{
  "type": "https://api.example.com/errors/rate-limit-exceeded",
  "title": "Rate Limit Exceeded",
  "status": 429,
  "detail": "You have exceeded the 1000 requests/hour limit.",
  "retry_after": 3600,
  "limit": 1000,
  "reset_at": "2024-01-15T11:00:00Z"
}
```

Never return: stack traces, internal error messages, SQL errors, or file paths in production error responses.

---

## Bulk Operations

### Batch Endpoints
```
# Create multiple resources in one request
POST /orders/batch
{
  "operations": [
    {"action": "create", "data": {"item": "widget", "qty": 1}},
    {"action": "create", "data": {"item": "gadget", "qty": 2}},
    {"action": "update", "id": "123", "data": {"status": "shipped"}}
  ]
}

# Response with per-operation results
{
  "results": [
    {"index": 0, "status": 201, "data": {"id": "456"}},
    {"index": 1, "status": 201, "data": {"id": "457"}},
    {"index": 2, "status": 200, "data": {"id": "123", "status": "shipped"}}
  ],
  "summary": {
    "total": 3,
    "succeeded": 3,
    "failed": 0
  }
}
```

**Partial success**: Return 207 Multi-Status when some operations succeed and some fail. Each result has its own status code.

```json
{
  "results": [
    {"index": 0, "status": 201, "data": {"id": "456"}},
    {"index": 1, "status": 422, "error": {"code": "invalid_email", "message": "..."}}
  ]
}
```

**Atomicity decision**: Clearly document whether batch is all-or-nothing (transactional) or best-effort (partial success). All-or-nothing is safer but may not scale; partial success is more resilient.

### Async Processing for Long Operations
```
# Submit job
POST /reports/generate
{"type": "monthly_revenue", "month": "2024-01"}

# Accepted response
HTTP/1.1 202 Accepted
Location: /jobs/job_abc123

{
  "job_id": "job_abc123",
  "status": "queued",
  "created_at": "2024-01-15T10:00:00Z",
  "estimated_completion": "2024-01-15T10:05:00Z",
  "status_url": "/jobs/job_abc123",
  "cancel_url": "/jobs/job_abc123"
}

# Poll for status
GET /jobs/job_abc123
{
  "job_id": "job_abc123",
  "status": "processing",  # queued | processing | completed | failed | cancelled
  "progress": 0.45,
  "created_at": "2024-01-15T10:00:00Z"
}

# Completed
GET /jobs/job_abc123
{
  "job_id": "job_abc123",
  "status": "completed",
  "result_url": "/reports/report_xyz",
  "completed_at": "2024-01-15T10:04:30Z"
}

GET /reports/report_xyz   # Retrieve result
```

**Polling vs Webhooks**: Prefer webhooks for completion notification; provide polling as fallback. Include `Retry-After` hint in 202 response.

---

## Idempotency Keys

For non-idempotent operations (POST) that should be safe to retry:

```
# Client generates unique key for each logical operation
POST /payments
Idempotency-Key: a8098c1a-f86e-11da-bd1a-00112444be1e
{
  "amount": 100,
  "currency": "USD",
  "recipient": "user_456"
}

# First call: processes payment, returns 201
# Subsequent calls with same key: returns same 201 response, no duplicate charge

# After TTL (e.g., 24 hours): key expires, same key treated as new request
```

**Server implementation**:
1. Hash Idempotency-Key + request path (not body — body may legitimately vary)
2. Check cache/DB for existing response
3. If found: return cached response with same status code
4. If not found: process, store (key, response, timestamp), return result
5. If concurrent: use distributed lock, return 409 or 503 while processing

**Key format**: UUID v4 (client-generated), ULID, or any unique string. Server should accept any opaque string.

**Storage TTL**: 24 hours is common (Stripe uses 24h). Match to retry window expectations.

**Header name**: `Idempotency-Key` (preferred, per IETF draft-ietf-httpapi-idempotency-key-header)

---

## Webhooks

### Design Principles
```
# Event payload
POST https://customer-app.com/webhooks/myapi
Content-Type: application/json
X-Webhook-ID: wh_123
X-Webhook-Timestamp: 1704067200
X-Webhook-Signature: v1=abc123def456...

{
  "id": "evt_abc123",
  "type": "payment.completed",
  "created": 1704067200,
  "api_version": "2024-01-15",
  "data": {
    "object": {
      "id": "pay_xyz789",
      "amount": 1000,
      "currency": "usd",
      "status": "succeeded"
    }
  }
}
```

### Delivery Guarantees
- **At-least-once**: Retry on failure. Consumer must be idempotent (use `event.id`).
- **At-most-once**: No retry. Risk of loss on consumer failure.
- **Exactly-once**: Very hard; requires distributed consensus. At-least-once + idempotent consumer is the practical approach.

### Retry Strategy
```
Attempt 1: Immediately
Attempt 2: 5 seconds later
Attempt 3: 30 seconds later
Attempt 4: 5 minutes later
Attempt 5: 30 minutes later
Attempt 6: 2 hours later
Attempt 7: 12 hours later
# After 7 attempts (or ~24 hours): mark as failed, alert, allow manual replay
```

Exponential backoff with jitter prevents thundering herd on consumer recovery.

**Success criteria**: HTTP 2xx within timeout (e.g., 30 seconds). Consumer should respond immediately and process async.

### Signature Verification
```
# Stripe-style signature (HMAC-SHA256)
X-Webhook-Signature: t=1704067200,v1=abc123def456

# Validation
timestamp = extract_timestamp(header)   # t= value
signature = extract_signature(header)   # v1= value

# Reject if timestamp > 5 minutes old (replay attack prevention)
if abs(current_time - timestamp) > 300:
    reject()

# Compute expected signature
payload = f"{timestamp}.{raw_body}"
expected = hmac_sha256(webhook_secret, payload)

# Compare with constant-time comparison (prevent timing attacks)
if not hmac.compare_digest(expected, signature):
    reject()
```

### Webhook Management API
```
POST /webhooks                     # Register endpoint
GET  /webhooks                     # List registered endpoints  
GET  /webhooks/wh_123              # Get webhook details
PUT  /webhooks/wh_123              # Update endpoint URL/events
DELETE /webhooks/wh_123            # Unregister

GET  /webhooks/wh_123/deliveries   # Delivery history
POST /webhooks/wh_123/deliveries/del_456/retry  # Manual retry
POST /webhooks/wh_123/test         # Send test event
```

---

## GraphQL vs REST vs gRPC

### REST
Best for:
- CRUD-heavy APIs with clear resource semantics
- Public APIs (widest client support, human-readable)
- When caching is important (HTTP caching layer)
- Long-term backward-compatible APIs

Limitations: Over/under fetching, multiple round-trips for related data, typed schema not enforced.

### GraphQL
Best for:
- APIs consumed by multiple clients with different data needs (mobile vs web vs partner)
- Aggregation layer over multiple services (BFF pattern)
- Rapidly evolving schemas during active product development
- When frontend teams need autonomy over data requirements

```graphql
# Single request for exactly what's needed
query {
  user(id: "123") {
    name
    email
    recentOrders(limit: 3) {
      id
      total
      items {
        name
        quantity
      }
    }
  }
}
```

Limitations:
- Complexity: schema definition, resolvers, N+1 query problem (need DataLoader)
- Caching: HTTP caching doesn't work naturally (all POST to /graphql); need persisted queries or CDN-layer solutions
- File uploads: not standardized
- Over-exposure: clients can ask for anything allowed by schema; requires query complexity limits
- Learning curve for teams unfamiliar with it

### gRPC
Best for:
- Internal service-to-service communication (microservices)
- High-throughput, low-latency requirements
- When strong contracts are essential (Protobuf schema)
- Streaming (bidirectional, server-side, client-side)
- Polyglot environments (code generation for 10+ languages)

```protobuf
service OrderService {
  rpc GetOrder (GetOrderRequest) returns (Order);
  rpc ListOrders (ListOrdersRequest) returns (stream Order);
  rpc CreateOrder (CreateOrderRequest) returns (Order);
  rpc UpdateOrder (UpdateOrderRequest) returns (Order);
}
```

Limitations:
- Not human-readable (binary Protobuf)
- Browser support requires gRPC-Web proxy
- Harder to debug than REST (need gRPC tools)
- Schema evolution discipline required (field numbers must never change)

**Decision matrix**:
| Criterion           | REST           | GraphQL      | gRPC        |
|---------------------|----------------|--------------|-------------|
| Client variety      | Good           | Best         | Poor        |
| Performance         | Good           | Good         | Best        |
| Cacheability        | Best           | Poor         | Poor        |
| Browser support     | Best           | Good         | Limited     |
| Streaming           | Limited (SSE)  | Subscription | Best        |
| Type safety         | Optional       | Yes (schema) | Yes (proto) |
| Tooling maturity    | Best           | Good         | Good        |
| Public API          | Best           | Possible     | Rare        |

---

## API Documentation

### OpenAPI / Swagger (REST)
```yaml
openapi: "3.1.0"
info:
  title: Orders API
  version: "1.0.0"
  
paths:
  /orders:
    post:
      operationId: createOrder
      summary: Create a new order
      tags: [Orders]
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/CreateOrderRequest'
            example:
              item_id: "item_123"
              quantity: 2
      responses:
        '201':
          description: Order created
          headers:
            Location:
              schema:
                type: string
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Order'
        '422':
          $ref: '#/components/responses/ValidationError'
      security:
        - BearerAuth: []
```

**Generate from code vs write first**:
- Code-first: FastAPI (auto-generates), Spring Boot + SpringDoc, NestJS + Swagger
- Design-first: Write OpenAPI spec, generate stubs and clients

Design-first is recommended for teams — contract is agreed before implementation, enables parallel client/server development.

### AsyncAPI (Event-Driven APIs)
For documenting WebSockets, MQTT, Kafka, webhook events:
```yaml
asyncapi: "3.0.0"
info:
  title: Order Events
  version: "1.0.0"

channels:
  order/created:
    publish:
      message:
        payload:
          type: object
          properties:
            order_id:
              type: string
            timestamp:
              type: string
              format: date-time
```

---

## Hypermedia (HATEOAS)

### What HATEOAS Means
Responses include links to valid next actions, allowing clients to navigate the API without out-of-band documentation.

```json
{
  "id": "order_123",
  "status": "pending",
  "total": 49.99,
  "_links": {
    "self": {"href": "/orders/order_123"},
    "cancel": {"href": "/orders/order_123/cancellation", "method": "POST"},
    "payment": {"href": "/orders/order_123/payment", "method": "POST"},
    "customer": {"href": "/users/user_456"}
  }
}
```

Links are conditional based on current state — `cancel` link only present if order is cancellable. Clients don't hardcode URLs; they follow links.

### HAL (Hypertext Application Language)
```json
{
  "id": "order_123",
  "status": "pending",
  "_links": {
    "self": {"href": "/orders/order_123"},
    "customer": {"href": "/users/456"}
  },
  "_embedded": {
    "items": [
      {
        "id": "item_789",
        "quantity": 2,
        "_links": {"product": {"href": "/products/prod_001"}}
      }
    ]
  }
}
```

### JSON:API
Strict specification for API structure with standardized resource identification, relationships, sparse fieldsets, and sorting:
```json
{
  "data": {
    "type": "orders",
    "id": "123",
    "attributes": {
      "status": "pending",
      "total": 49.99
    },
    "relationships": {
      "customer": {
        "data": {"type": "users", "id": "456"}
      }
    },
    "links": {
      "self": "/orders/123"
    }
  },
  "included": [
    {
      "type": "users",
      "id": "456",
      "attributes": {"name": "Alice", "email": "alice@example.com"}
    }
  ]
}
```

**Reality**: HATEOAS is theoretically ideal but rarely implemented in practice. JSON:API adoption is moderate. HAL is niche. Most production APIs are "REST-ish" (Level 2 Richardson). Only invest in full HATEOAS if your clients are truly generic hypermedia agents.

---

## Backend-for-Frontend (BFF) Pattern

### Problem
Multiple client types (iOS, Android, Web SPA, third-party partners) have different data needs. A single general-purpose API must either over-fetch (return all data) or under-fetch (require multiple requests).

### Solution
Dedicated API layer per client type, co-owned by the frontend team:
```
iOS App → iOS BFF → [User Service, Order Service, Product Service]
Web App → Web BFF → [User Service, Order Service, Product Service]
3rd Party → Public API → [User Service, Order Service, Product Service]
```

### What BFF Does
```
# Web BFF request (aggregates data for dashboard)
GET /bff/web/dashboard

# BFF internally:
user = await userService.getUser(userId)
orders = await orderService.getRecentOrders(userId, limit=5)
notifications = await notificationService.getUnread(userId)

# Returns exactly what the dashboard needs
{
  "user": { "name": "Alice", "avatar_url": "..." },
  "recent_orders": [...],
  "unread_count": 3,
  "metrics": { "total_spent": 249.99 }
}
```

### Trade-offs
**Pros**:
- Frontend teams control their API contract
- Optimized payload per client (no over-fetching)
- Can evolve per-client without affecting others
- Natural place for client-specific auth/session logic

**Cons**:
- More services to maintain (one BFF per client type)
- Code duplication across BFFs
- Another network hop
- Versioning and deployment complexity

**BFF vs GraphQL**: GraphQL is sometimes presented as an alternative to BFF (clients specify what they need). In practice, GraphQL often *is* the BFF — a GraphQL layer that aggregates downstream services. The concepts are complementary.

**When to use**: When you have 3+ distinct client types with meaningfully different data needs, or when mobile performance requires reduced payload size and round trips. Overkill for simple CRUD APIs with one client.
