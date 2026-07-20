# Request/Response API Paradigm Comparison

## When to Use Request/Response APIs

Request/response APIs are the right choice when the client initiates a discrete operation and waits for a result: CRUD operations, queries, commands, and form submissions. The client controls timing, and each interaction is independent.

## REST (Representational State Transfer)

### When REST is the Right Choice

- **Public APIs** consumed by third parties with diverse technology stacks
- **CDN-cacheable data** where HTTP caching provides significant performance benefit
- **Simple CRUD operations** mapping cleanly to resources and HTTP verbs
- **Broad client compatibility** matters more than payload efficiency
- **API-first organizations** using OpenAPI as the contract

### When REST is Not the Right Choice

- Complex client-driven queries requiring multiple round-trips (consider GraphQL)
- High-frequency internal microservice calls where JSON overhead matters (consider gRPC)
- Enterprise analytics tools needing standardized query syntax (consider OData)

### REST Characteristics

- Resources are nouns (`/users`, `/orders`), HTTP verbs are operations
- Stateless -- each request is self-contained, enabling horizontal scaling
- HTTP caching works natively (ETag, Cache-Control, CDN)
- Over-fetching and under-fetching are inherent trade-offs
- OpenAPI provides machine-readable contracts and code generation
- Richardson Maturity Model: most APIs reach Level 2 (HTTP verbs), few reach Level 3 (HATEOAS)

### Key Standards

- **OpenAPI 3.1** -- full JSON Schema 2020-12 alignment, webhooks support
- **RFC 9457** -- Problem Details for HTTP APIs (`application/problem+json`)
- **RFC 9110** -- HTTP Semantics (method definitions, status codes)
- **JSON:API** -- standardized response envelope with sparse fieldsets and includes
- **HAL** -- hypermedia format with `_links` and `_embedded`

## GraphQL

### When GraphQL is the Right Choice

- **BFF (Backend for Frontend)** aggregating data from multiple services
- **Mobile apps** where bandwidth is constrained and precise field selection reduces payload
- **Multiple client types** (web, mobile, partner) with different data shape needs
- **Federated microservice architectures** where teams own independent subgraphs
- **Rapid frontend iteration** without backend changes for each new view

### When GraphQL is Not the Right Choice

- Simple CRUD with 1:1 mapping to database tables (REST is simpler)
- Public APIs for non-technical partners (REST is more universally understood)
- CDN-heavy caching requirements (REST caches more naturally)
- Server-to-server communication (gRPC is more efficient)

### GraphQL Characteristics

- Single endpoint (`/graphql`), client defines exact data shape in query
- Schema is self-documenting and introspectable
- No over-fetching or under-fetching -- client gets exactly what it requests
- Subscriptions enable real-time push (via WebSocket transport)
- Schema evolution is additive -- no versioning needed
- Complex queries can be expensive; depth and complexity limiting are required in production
- POST-by-default makes HTTP-layer caching harder (persisted queries mitigate)

### Key Implementations

| Library | Language | Approach | Performance |
|---|---|---|---|
| Apollo Server 5 | Node.js | Schema-first or code-first | Standard |
| Mercurius | Node.js (Fastify) | Schema-first, JIT compilation | 70,000+ req/s |
| graphql-yoga | Node.js/Deno/Bun | Fetch API, framework-agnostic | ~10,900 req/s |
| Strawberry | Python | Code-first (type hints) | Standard |
| Hot Chocolate | .NET | Code-first (attributes) | High |

### Federation vs Schema Stitching

| Aspect | Apollo Federation | Schema Stitching |
|---|---|---|
| Governance | Each team owns their subgraph | Gateway team owns composition |
| Scale | Many teams, independent deployment | Few services, shared types |
| Tooling | Apollo Router, Rover, GraphOS | graphql-tools, The Guild |

## gRPC

### When gRPC is the Right Choice

- **Internal microservice communication** where performance is critical
- **Polyglot systems** needing generated clients in Go, Java, Python, C#, Rust
- **High-frequency RPC calls** where JSON overhead is unacceptable
- **Streaming large datasets** between services (4 streaming modes)
- **Strict contract enforcement** via `.proto` files and code generation

### When gRPC is Not the Right Choice

- Browser-facing APIs without a proxy layer (browsers cannot make gRPC calls directly)
- Public APIs where developer experience matters (JSON/REST is more accessible)
- Systems where HTTP caching provides significant benefit
- Teams unfamiliar with Protocol Buffers

### gRPC Characteristics

- HTTP/2 exclusively: multiplexing, binary framing, header compression
- Protocol Buffers: 3-10x smaller than JSON, faster serialization
- Four streaming modes: unary, server streaming, client streaming, bidirectional
- Strong contract via `.proto` -- code generation for all major languages
- Schema evolution via field numbers (non-breaking additions)
- gRPC-Web for browser support (requires Envoy or grpc-gateway proxy)
- Connect protocol (Buf) provides browser-native gRPC compatibility

### Streaming Modes

| Mode | Use Case |
|---|---|
| Unary | Standard request/response (like REST) |
| Server streaming | Real-time feeds, log streaming, large result sets |
| Client streaming | File uploads, batch ingestion |
| Bidirectional | Chat, collaborative editing, IoT processing |

## OData

### When OData is the Right Choice

- **Enterprise data APIs** where consumers are analytics tools (Power BI, Excel, SAP)
- **Standardized querying** without implementing custom filter/sort/expand logic
- **Microsoft/SAP ecosystem** integrations (SharePoint, Dynamics, Azure)
- **Self-describing APIs** where the `$metadata` endpoint enables automated client generation
- **Data aggregation** via `$apply` without custom aggregate endpoints

### When OData is Not the Right Choice

- Public APIs targeting web/mobile developers (REST or GraphQL are more familiar)
- Simple CRUD without complex query needs (REST is simpler)
- Non-Microsoft ecosystems with limited OData tooling
- High-performance internal services (gRPC is faster)

### OData Characteristics

- REST superset with standardized query options: `$filter`, `$select`, `$expand`, `$orderby`, `$top`, `$skip`, `$count`, `$search`, `$apply`
- Entity Data Model (EDM) describes the full schema via `$metadata`
- Consumer tooling (Power BI, Excel) connects natively to OData feeds
- Lambda operators (`any`, `all`) for filtering on collections
- Batch requests via `$batch` (multipart or JSON format)
- Functions (side-effect-free, GET) and Actions (side effects, POST)
- Open types allow dynamic properties not defined in schema

## Protocol Selection Matrix

| Factor | REST | GraphQL | gRPC | OData |
|---|---|---|---|---|
| Public API | Best | Good | Poor (proxy needed) | Niche (enterprise) |
| Mobile BFF | Good | Best | Good | Poor |
| Microservice RPC | Good | Poor (overkill) | Best | Poor |
| Enterprise data | Good | Poor | Poor | Best |
| Caching | Best | Hard | None | Good |
| Schema evolution | Manual versioning | Additive | Field numbers | Manual versioning |
| Learning curve | Low | Medium | Medium | Medium |
| Payload size | Large (JSON) | Precise (JSON) | Small (binary) | Large (JSON) |
| Browser support | Universal | Universal | Proxy required | Universal |
| Code generation | openapi-generator | GraphQL Codegen | protoc | OData client gen |
