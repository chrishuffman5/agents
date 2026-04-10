# Section 9: REST API / Backend Frameworks — Agent Team Plan

## Context

Section 9 of PLAN.md covers 10 backend framework technologies with 15+ versions. We need to create a full agent hierarchy using the established team pattern from PLAN-FRONTEND.md: **Sonnet agents for parallel research by specialty, Opus agents for planning/writing the final agents**.

The domain name will be `backend` (parallel to `frontend`, `database`, `devops`, etc.).

---

## Domain Structure

```
agents/backend/
├── SKILL.md                              # Backend domain router
├── references/
│   ├── concepts.md                       # REST principles, HTTP semantics, API design, auth paradigms
│   ├── paradigm-traditional.md           # Request/response MVC (Express, Flask, Django, Rails, Spring)
│   ├── paradigm-async.md                 # Async-first (FastAPI, Actix, Axum, NestJS, Go net/http)
│   └── paradigm-fullstack.md             # Full-stack frameworks (Django, Rails, Spring Boot, .NET)
│
├── aspnet-core/                          # .NET Web API
├── express/                              # Express.js (Node.js)
├── fastapi/                              # FastAPI (Python)
├── spring-boot/                          # Spring Boot (Java/Kotlin)
├── django/                               # Django (Python)
├── flask/                                # Flask (Python)
├── nestjs/                               # NestJS (Node.js/TypeScript)
├── rails/                                # Ruby on Rails
├── go-web/                               # Go web frameworks (net/http, Gin, Fiber)
└── rust-web/                             # Rust web frameworks (Actix, Axum)
```

### Paradigm Classification

| Paradigm | Technologies | Philosophy |
|---|---|---|
| **Batteries-Included** | Django, Rails, Spring Boot, ASP.NET Core | Full-stack: ORM, auth, admin, templating, migrations — opinionated |
| **Micro-Framework** | Express, Flask, Gin, Fiber | Minimal core + middleware/plugins — compose your own stack |
| **Async-First** | FastAPI, NestJS, Actix, Axum | Built on async runtimes — high concurrency by default |
| **Multi-Paradigm** | Go net/http | Standard library HTTP — no framework needed, but frameworks add convenience |

---

## Technology Inventory & Version Agents

| Technology | Version Agents | Feature Sub-Agents |
|---|---|---|
| **ASP.NET Core** | .NET 8 LTS, .NET 9, .NET 10 LTS | Minimal APIs (spans versions) |
| **Express.js** | 5.x | — |
| **FastAPI** | — (single rolling version) | — |
| **Spring Boot** | 3.x, 4.0 | — |
| **Django** | 4.2 LTS, 5.2 LTS, 6.0 | — |
| **Flask** | — (single version 3.1) | — |
| **NestJS** | — (single version 11.x) | — |
| **Ruby on Rails** | 7.2, 8.0, 8.1 | — |
| **Go Web** | — (tied to Go 1.23/1.24) | — |
| **Rust Web** | — (rolling toolchain) | — |

**Total**: 10 technologies, ~11 version agents, 1 feature sub-agent

---

## Research & Writer Teams

### Tier 1 — Heavy (3+ research agents, dedicated writer)

#### ASP.NET Core (4 research + 1 writer)

| # | Research Agent (Sonnet) | Focus Area |
|---|---|---|
| R1 | AspNet-Architecture | Middleware pipeline, DI, Kestrel, routing, model binding, filters, configuration |
| R2 | AspNet-DotNet8 | .NET 8 LTS features, Native AOT, identity API endpoints, output caching |
| R3 | AspNet-DotNet10 | .NET 10 LTS current features, OpenAPI improvements, Blazor unification |
| R4 | AspNet-MinimalAPIs | Minimal API model vs controllers, route groups, filters, validation, OpenAPI |

| # | Writer Agent (Opus) | Produces |
|---|---|---|
| W1 | AspNet-Writer | All SKILL.md, references, version agents (8, 9, 10), Minimal APIs sub-agent |

#### Spring Boot (3 research + 1 writer)

| # | Research Agent (Sonnet) | Focus Area |
|---|---|---|
| R1 | Spring-Architecture | DI/IoC, auto-configuration, actuator, Spring MVC vs WebFlux, embedded servers |
| R2 | Spring-3x | Spring Boot 3.x features, Jakarta EE migration, GraalVM native, observability |
| R3 | Spring-4 | Spring Boot 4.0 features, baseline changes, deprecation removals, virtual threads |

| # | Writer Agent (Opus) | Produces |
|---|---|---|
| W2 | Spring-Writer | All SKILL.md, references, version agents (3.x, 4.0) |

#### Django (3 research + 1 writer)

| # | Research Agent (Sonnet) | Focus Area |
|---|---|---|
| R1 | Django-Architecture | ORM, middleware, URL routing, template engine, admin, auth, migrations, signals |
| R2 | Django-4.2-5.2 | 4.2 LTS features, 5.x async views/ORM, generated fields, composite PKs |
| R3 | Django-6 | Django 6.0 current features, new deprecations, migration from 5.2 |

| # | Writer Agent (Opus) | Produces |
|---|---|---|
| W3 | Django-Writer | All SKILL.md, references, version agents (4.2, 5.2, 6.0) |

#### Ruby on Rails (3 research + 1 writer)

| # | Research Agent (Sonnet) | Focus Area |
|---|---|---|
| R1 | Rails-Architecture | MVC, ActiveRecord, Action Pack, Action Cable, Active Job, Turbo/Hotwire |
| R2 | Rails-7.2-8.0 | 7.2 features, 8.0 features, Kamal deployment, Solid Queue/Cache/Cable |
| R3 | Rails-8.1 | 8.1 current features, new defaults, migration path |

| # | Writer Agent (Opus) | Produces |
|---|---|---|
| W4 | Rails-Writer | All SKILL.md, references, version agents (7.2, 8.0, 8.1) |

### Tier 2 — Medium (2 research, combined writer)

#### Express.js (2 research)

| # | Research Agent (Sonnet) | Focus Area |
|---|---|---|
| R1 | Express-Architecture | Middleware chain, routing, error handling, template engines, Express 5 changes |
| R2 | Express-Ecosystem | Popular middleware (passport, helmet, cors, morgan, multer), testing patterns |

#### FastAPI (2 research)

| # | Research Agent (Sonnet) | Focus Area |
|---|---|---|
| R1 | FastAPI-Architecture | ASGI/Starlette, Pydantic v2, dependency injection, async, OpenAPI generation |
| R2 | FastAPI-Patterns | Authentication, database integration (SQLAlchemy/SQLModel), testing, deployment |

#### NestJS (2 research)

| # | Research Agent (Sonnet) | Focus Area |
|---|---|---|
| R1 | NestJS-Architecture | Modules, providers, DI, decorators, guards, interceptors, pipes, middleware |
| R2 | NestJS-Patterns | GraphQL, WebSockets, microservices, CQRS, event sourcing, testing |

| # | Writer Agent (Opus) | Produces |
|---|---|---|
| W5 | Node-Frameworks-Writer | Express SKILL.md + refs + version agent, NestJS SKILL.md + refs |
| W6 | Python-Frameworks-Writer | FastAPI SKILL.md + refs, Flask SKILL.md + refs |

### Tier 3 — Light (1 research, combined writer)

#### Flask (1 research)

| # | Research Agent (Sonnet) | Focus Area |
|---|---|---|
| R1 | Flask-Full | Application factory, blueprints, extensions, Jinja2, SQLAlchemy integration, testing |

#### Go Web (1 research)

| # | Research Agent (Sonnet) | Focus Area |
|---|---|---|
| R1 | Go-Web-Full | net/http (1.22+ routing), Gin (middleware, binding), Fiber (fasthttp), chi, Echo |

#### Rust Web (1 research)

| # | Research Agent (Sonnet) | Focus Area |
|---|---|---|
| R1 | Rust-Web-Full | Actix-web (actors, extractors), Axum (Tower, extractors, state), tokio runtime, Serde |

| # | Writer Agent (Opus) | Produces |
|---|---|---|
| W7 | Systems-Frameworks-Writer | Go web SKILL.md + refs, Rust web SKILL.md + refs |

---

## Execution Waves

| Wave | Technologies | Research Agents | Writer Agents | Rationale |
|---|---|:---:|:---:|---|
| 0 | Domain-level agent | 1 (concepts research) | 1 (domain writer) | Create routing agent + paradigm references first |
| 1 | ASP.NET Core + Spring Boot | 7 | 2 | Heaviest — both have multiple versions and sub-frameworks |
| 2 | Django + Rails | 6 | 2 | Batteries-included frameworks with multiple versions |
| 3 | Express + FastAPI + NestJS + Flask | 7 | 2 | Grouped by runtime (Node.js + Python) |
| 4 | Go Web + Rust Web | 2 | 1 | Systems languages, lighter scope |

### Within Each Wave

```
Phase 1: Research (Sonnet agents, parallel)
   ├── R1, R2, R3... run simultaneously
   ├── Each writes to: agents/backend/{tech}-workspace/research/
   └── Output: architecture.md, features.md, diagnostics.md, best-practices.md, research-summary.md

Phase 2: Write (Opus agent, sequential per technology)
   ├── W1 reads all research from {tech}-workspace/research/
   ├── Writes: SKILL.md, references/, version agents
   └── Output: Production-ready agent files

Phase 3: Review (optional, Sonnet agent)
   ├── Runs agent-reviewer against each produced agent
   └── Output: review.json with scores and improvement suggestions
```

---

## Total Inventory

| Component | Count |
|---|---|
| **Technologies** | 10 |
| **Version agents** | 11 (3 ASP.NET + 2 Spring + 3 Django + 3 Rails) |
| **Feature sub-agents** | 1 (ASP.NET Minimal APIs) |
| **Reference files** | ~35 (3 per tech + domain-level) |
| **Research agents (Sonnet)** | ~24 |
| **Writer agents (Opus)** | ~8 |

---

## Cross-References (avoid duplication)

| Topic | Primary Location | Referenced From |
|---|---|---|
| REST/HTTP principles | `backend/references/concepts.md` | All technology agents |
| Authentication (OAuth2, JWT) | `backend/references/concepts.md` | All technology agents |
| Python async/ASGI | `backend/fastapi/references/architecture.md` | Flask (comparison) |
| Node.js event loop | `backend/express/references/architecture.md` | NestJS (shared runtime) |
| .NET middleware pipeline | `backend/aspnet-core/references/architecture.md` | — |
| ORM patterns | `backend/references/paradigm-fullstack.md` | Django, Rails, Spring |

---

## Implementation Notes

- **Domain name**: `backend` (not `rest-api` — covers more than REST; GraphQL, WebSocket, gRPC endpoints built with these frameworks)
- **No configs/ or patterns/ directories** — backend agents use `references/` only (matching the devops pattern, not frontend). The frontend pattern added configs/patterns because UI frameworks have complex build tooling; backend frameworks don't need annotated config files.
- **Go and Rust are multi-framework agents** — `go-web` covers net/http + Gin + Fiber; `rust-web` covers Actix + Axum. One SKILL.md with routing to framework-specific sections, not separate directories per micro-framework.
- **Flask has no version agents** — single version (3.1), no major version changes pending
- **FastAPI has no version agents** — continuous releases (0.x), no discrete version boundaries worth tracking
- **NestJS has no version agents** — single major version (11.x)
- **Express version agent** — Express 5 is a significant rewrite (removed deprecated middleware, new router, path-to-regexp v8). Warrants a version agent.

---

## How to Execute

To kick off Wave 0 (domain-level), then Wave 1:

```
# Wave 0: Domain agent
1. Launch 1 Sonnet researcher: REST/HTTP/API concepts
2. Launch 1 Opus writer: domain SKILL.md + references/

# Wave 1: ASP.NET + Spring Boot (7 researchers in parallel)
1. Launch 4 Sonnet researchers for ASP.NET (architecture, .NET 8, .NET 10, Minimal APIs)
2. Launch 3 Sonnet researchers for Spring Boot (architecture, 3.x, 4.0)
3. Wait for all 7 to complete
4. Launch 1 Opus writer for ASP.NET (reads research, writes all files)
5. Launch 1 Opus writer for Spring Boot (reads research, writes all files)
```

Each researcher gets a prompt like:
```
You are a domain research specialist. Research {Technology} focusing on {Focus Area}.
Save your findings to: agents/backend/{tech}-workspace/research/{focus}.md
Follow the research standards in .claude/skills/agent-creator/agents/domain-researcher.md
```

Each writer gets a prompt like:
```
You are creating a production-grade IT domain agent for {Technology}.
Read all research files in: agents/backend/{tech}-workspace/research/
Follow the agent creation standards in .claude/skills/agent-creator/SKILL.md
Write the agent hierarchy to: agents/backend/{tech}/
Existing agents to reference for style: agents/devops/cicd/github-actions/, agents/database/postgresql/
```
