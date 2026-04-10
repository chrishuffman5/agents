# Research Summary: Backend / REST API Domain

## Overview
This research covers the foundational concepts for the Backend/REST API domain, targeting the cross-framework knowledge that senior backend engineers need regardless of specific technology choices. The goal is to give an Opus writer agent solid grounding to produce production-quality domain agents.

---

## Files Produced

| File | Lines | Focus |
|------|-------|-------|
| `rest-http.md` | ~280 | HTTP semantics, status codes, content negotiation, REST constraints, versioning, pagination, filtering, rate limiting, caching |
| `auth-patterns.md` | ~290 | Session vs token, JWT, OAuth 2.0 flows, OIDC, API keys, mTLS, RBAC/ABAC/ReBAC, CORS |
| `design-patterns.md` | ~310 | Resource modeling, request/response patterns, RFC 7807, bulk operations, idempotency keys, webhooks, GraphQL vs REST vs gRPC, documentation, HATEOAS, BFF |
| `paradigm-comparison.md` | ~280 | Batteries-included, micro-framework, async-first paradigms with concrete framework examples |
| `performance.md` | ~300 | Connection pooling, middleware overhead, serialization, async vs sync models, background jobs, horizontal scaling, load testing |

---

## Key Findings

### Recurring Themes Across Topics
1. **There are no universally correct answers** — every pattern has trade-offs documented explicitly
2. **Statelessness is the single biggest enabler of horizontal scale** — appears in caching, auth, session design, and scaling sections
3. **The database is almost always the bottleneck** — not the framework, not JSON parsing, not middleware
4. **At-least-once delivery with idempotent consumers** is the practical answer to distributed systems delivery guarantees — true exactly-once is nearly impossible
5. **Async helps I/O-bound, hurts CPU-bound** — often misunderstood; explicitly documented in performance and paradigm sections

### Decisions Senior Engineers Actually Debate
- URL versioning vs header versioning (both defensible; depends on audience)
- Offset vs cursor pagination (cursor wins on correctness; offset wins on user experience)
- JWT revocation (blocklist re-introduces state; short TTL is the pragmatic answer)
- OAuth PKCE: should be used for all clients now (RFC 9700), not just public clients
- Pool size: smaller than intuition; right-size beats large, based on DB server cores
- Batteries-included vs micro: team structure and project type matter more than performance

---

## Confidence Levels

| Topic | Confidence | Notes |
|-------|------------|-------|
| HTTP method semantics and status codes | High | Well-standardized; RFC-based |
| JWT structure and validation | High | RFC 7519; widely implemented |
| OAuth 2.0 flows | High | RFC 6749 + RFC 7636 (PKCE) + RFC 9700 |
| Rate limiting algorithms | High | Token bucket, sliding window well-documented |
| REST constraints | High | Fielding's dissertation + Richardson Maturity Model |
| CORS mechanics | High | Living Standard + MDN documentation |
| Framework performance benchmarks | Medium | Benchmarks are notoriously context-dependent; relative ordering reliable, specific numbers indicative only |
| ReBAC / Zanzibar | Medium | Zanzibar paper is authoritative; implementation details vary |
| Webhook retry strategies | Medium | No single standard; Stripe, GitHub, Shopify patterns synthesized |
| Pool size recommendations | Medium | General guidelines; actual optimum depends on workload characteristics |

---

## Known Gaps and Limitations

### Not Covered (Out of Scope by Design)
- Framework-specific APIs (Express routing syntax, Django ORM QuerySet API, etc.) — covered by per-technology agents
- Database-specific topics (query optimization, index design) — separate domain
- Infrastructure (Kubernetes, Docker, Nginx config) — separate domain
- WebSocket protocol details — only mentioned in context
- Server-Sent Events — mentioned briefly, not deeply covered
- gRPC streaming patterns — mentioned as capability, not detailed
- Kafka/message queue internals — background jobs covered conceptually
- GraphQL schema design, resolver patterns, DataLoader — mentioned N+1 problem, not full GraphQL guide

### Areas Where Guidance May Evolve
- **HTTP/3 (QUIC)**: Not covered; most frameworks don't natively support yet. Will matter for latency-sensitive public APIs.
- **OpenTelemetry**: Mentioned briefly; deserves deeper treatment as observability becomes standardized
- **AI/LLM integration patterns**: Not a traditional REST API concern but increasingly relevant (streaming responses, token-based pricing, API design for AI endpoints)
- **WebAuthn/Passkeys**: Emerging auth pattern not covered; JWT/session focus remains accurate for current production systems
- **FIDO2**: Not covered; relevant for passwordless auth at enterprise scale

### Intentional Trade-offs in Coverage
- **HATEOAS implementation depth**: Covered conceptually but noted as rarely implemented in practice. Full treatment would require coverage of HAL, JSON:API, Siren — valuable but deep rabbit hole for most teams.
- **OAuth security considerations**: Covered main flows and PKCE. Full security coverage (token binding, DPoP, JAR, PAR) would require a dedicated security research file.
- **Multi-tenancy patterns**: Not covered. Important for SaaS APIs but intersects heavily with authorization and data architecture.

---

## Source Quality Assessment

All content synthesized from established technical specifications and widely-validated engineering practices:

- **RFCs**: 7807 (Problem Details), 7519 (JWT), 6749 (OAuth 2.0), 7636 (PKCE), 9700 (Security BCP), 5988 (Web Linking), 8594 (Sunset header), 7396 (Merge Patch), 6902 (JSON Patch)
- **Industry patterns**: Stripe API design, GitHub API design, Google Zanzibar paper, Fielding's REST dissertation
- **Framework documentation**: FastAPI, Django REST Framework, Express, NestJS, Spring Boot, ASP.NET Core, Gin, Axum, Actix-web
- **Testing tools**: k6, Locust, wrk, hey — all widely used and well-documented

No experimental or cutting-edge-only patterns included. All patterns have production validation at significant scale.

---

## Recommendations for Opus Writer Agent

### Tone and Level
Target content is aimed at **senior engineers** who know what a REST API is. Skip "what is REST" explanations. Start from "here's when you'd choose cursor vs offset pagination and why."

### High-Value Angles
1. **Trade-off articulation**: Every pattern has a cost. Engineers reading domain agent content want to make informed decisions, not follow rules.
2. **Concrete examples**: Header names, status codes, curl commands, JSON payloads. Vagueness is useless here.
3. **Anti-patterns**: What NOT to do is as valuable as what to do. Include `# Wrong / # Right` patterns.
4. **Cross-framework transferability**: Concepts in these files apply whether the target agent is writing for FastAPI, Express, or Spring Boot. Keep framework-specific syntax in examples but framework-agnostic in recommendations.

### Suggested Agent Structure
Given the breadth of this domain, consider agents at multiple specificity levels:
- **Cross-cutting**: Auth patterns, REST fundamentals (this research) — always relevant
- **Framework-specific**: Express, FastAPI, Django REST, Spring Boot — paradigm-comparison.md informs the framework agent persona
- **Pattern-specific**: Webhook implementation, pagination patterns, rate limiting — these are small enough to inline

### The One Non-Obvious Point
The most common senior engineer mistake in API design isn't technical — it's **versioning too late and not thinking about backward compatibility from day one**. The Sunset header, deprecation headers, and version lifecycle section in rest-http.md is specifically useful because most teams only think about it after they already have a version problem.
