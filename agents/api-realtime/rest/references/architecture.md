# REST Architecture Deep Dive

## Fielding's Six Constraints

REST (Representational State Transfer) was defined by Roy Fielding in his 2000 doctoral dissertation. A system is RESTful only when all six constraints are satisfied:

1. **Client-Server**: UI decoupled from data storage. Client handles UI; server handles data.
2. **Stateless**: Each request contains all information needed to service it. No server-side session state. Enables horizontal scaling without session affinity.
3. **Cacheable**: Responses label themselves as cacheable or non-cacheable. Clients and intermediaries may reuse cached responses.
4. **Uniform Interface**: Resource identification in URIs, manipulation through representations, self-descriptive messages, HATEOAS.
5. **Layered System**: Client cannot tell if connected directly to the server or through intermediaries (load balancers, CDNs, proxies).
6. **Code on Demand (optional)**: Server can extend client functionality by sending executable code.

## Richardson Maturity Model

| Level | Name | Description |
|---|---|---|
| 0 | Swamp of POX | Single URI, single HTTP method (POST everything) |
| 1 | Resources | Multiple URIs representing resources, still POSTing |
| 2 | HTTP Verbs | GET, POST, PUT, DELETE with correct semantics |
| 3 | Hypermedia | HATEOAS links in responses. True REST. |

Most production APIs operate at Level 2. Level 3 is theoretically ideal but rarely implemented due to client complexity.

## Resource Design

### URL Conventions

- Nouns for resource names: `/users` not `/getUsers`
- Plural for collections: `/articles`, `/orders`
- Lowercase, kebab-case for compound words: `/blog-posts` not `/blogPosts`
- Hierarchical relationships with `/`: `/users/{id}/orders`
- No CRUD verbs in URL -- HTTP methods handle that
- Avoid `.json` extensions; use `Accept` header

### Query Parameters

- Filtering: `?status=active` or `?filter[status]=active`
- Sorting: `?sort=-created_at,name` (prefix `-` for descending)
- Pagination: `?page=2&limit=20` or `?cursor=eyJpZCI6MTIzfQ==`
- Field selection: `?fields=id,name,email`
- Includes: `?include=author,comments`
- Search: `?q=search+term`

## HTTP Method Semantics (RFC 9110)

### Method Properties

| Method | Safe | Idempotent | Request Body | Response Body |
|---|---|---|---|---|
| GET | Yes | Yes | No | Yes |
| HEAD | Yes | Yes | No | No |
| POST | No | No | Yes | Yes |
| PUT | No | Yes | Yes | Optional |
| PATCH | No | No* | Yes | Optional |
| DELETE | No | Yes | Optional | Optional |
| OPTIONS | Yes | Yes | No | Yes |

### PUT vs PATCH

PUT replaces the entire resource. PATCH applies a partial modification.

**JSON Patch (RFC 6902):**
```json
PATCH /users/123
Content-Type: application/json-patch+json

[
  { "op": "replace", "path": "/email", "value": "new@example.com" },
  { "op": "remove", "path": "/middleName" }
]
```

**Merge Patch (RFC 7396):**
```json
PATCH /users/123
Content-Type: application/merge-patch+json

{
  "email": "new@example.com",
  "middleName": null
}
```

Merge Patch is simpler but cannot distinguish between "set to null" and "don't change."

## Status Codes

### 2xx Success

- `200 OK` -- Successful GET, PUT, PATCH (with body)
- `201 Created` -- Successful POST; include `Location` header pointing to new resource
- `202 Accepted` -- Async processing; return status URL in body or `Location`
- `204 No Content` -- Successful DELETE, PUT, PATCH (no body)
- `206 Partial Content` -- Range request served (file downloads)

### 4xx Client Error

- `400 Bad Request` -- Malformed syntax, invalid parameters
- `401 Unauthorized` -- Not authenticated (despite name, means "unauthenticated")
- `403 Forbidden` -- Authenticated but not authorized
- `404 Not Found` -- Resource does not exist
- `405 Method Not Allowed` -- HTTP method not supported
- `409 Conflict` -- State conflict (duplicate create, version mismatch)
- `410 Gone` -- Permanently deleted (more specific than 404)
- `422 Unprocessable Entity` -- Semantically invalid (validation errors)
- `429 Too Many Requests` -- Rate limited; include `Retry-After`

### 5xx Server Error

- `500 Internal Server Error` -- Generic failure
- `502 Bad Gateway` -- Upstream failure
- `503 Service Unavailable` -- Temporarily down; include `Retry-After`
- `504 Gateway Timeout` -- Upstream timeout

## Content Negotiation

Clients specify format via `Accept` header. Server responds with `Content-Type` and `Vary: Accept`:

```http
GET /orders/123
Accept: application/json, application/vnd.api+json;q=0.9

HTTP/1.1 200 OK
Content-Type: application/json
Vary: Accept
```

If the server cannot satisfy `Accept`, respond `406 Not Acceptable`.

## Hypermedia Formats

### HATEOAS

Server drives state transitions by including links in responses:
```json
{
  "id": "order-123",
  "status": "pending",
  "_links": {
    "self": { "href": "/orders/123" },
    "cancel": { "href": "/orders/123/cancel", "method": "DELETE" },
    "pay": { "href": "/orders/123/payment", "method": "POST" }
  }
}
```

### JSON:API

Standardized envelope with `data`, `errors`, `included`, `links`:
```json
{
  "data": {
    "type": "articles",
    "id": "1",
    "attributes": { "title": "JSON:API" },
    "relationships": {
      "author": { "data": { "type": "people", "id": "9" } }
    }
  },
  "included": [
    { "type": "people", "id": "9", "attributes": { "name": "Dan" } }
  ]
}
```

Sparse fieldsets: `?fields[articles]=title,body&fields[people]=name`

### HAL

Minimal hypermedia with `_links` and `_embedded`:
```json
{
  "id": 42,
  "name": "Widget",
  "_links": { "self": { "href": "/widgets/42" } },
  "_embedded": {
    "category": { "id": 5, "name": "Gadgets", "_links": { "self": { "href": "/categories/5" } } }
  }
}
```

## OpenAPI 3.1

### Key Changes from 3.0

- Full JSON Schema 2020-12 alignment
- `nullable: true` replaced by `type: ["string", "null"]`
- `webhooks` top-level field for callback descriptions
- `$ref` sibling properties allowed
- New `summary` field on `$ref` objects

### Minimal Document

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
components:
  schemas:
    Order:
      type: object
      properties:
        id:
          type: string
        status:
          type: ["string", "null"]
```

### Tooling

- **Swagger UI / Swagger Editor** -- Interactive docs and editing
- **Redoc** -- Read-only documentation
- **Scalar** -- Modern alternative to Swagger UI
- **Stoplight Studio** -- Visual design-first editor
- **Spectral** -- Rule-based linting and validation
- **openapi-generator** -- Code generation (50+ languages)
- **oapi-codegen** -- Go-specific code generation
- **kiota** -- Microsoft's generator for complex APIs
