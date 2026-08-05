---
name: ultimate-tech-stack
description: "The curated default open-source technology stack — one best-in-class, OSI-licensed pick per IT domain (PostgreSQL, FastAPI, Next.js, Kubernetes, RabbitMQ, Airflow + dbt, Superset, Prometheus/Grafana, Keycloak, GitLab + OpenTofu + Argo CD, Nginx, Ceph, Proxmox, Ubuntu, Python, Postfix). Use at the start of any new app or greenfield build to make each domain decision instantly instead of re-running a bake-off. WHEN: \"new app idea\", \"what stack should we use\", \"default tech stack\", \"our usual stack\", \"open-source stack\", \"greenfield project\", \"just pick a database / framework / broker / orchestrator for me\", \"set up the standard stack\". Do NOT use for implementation depth on an already-chosen technology (use the matching domain skill, e.g. /database:postgresql), for bespoke multi-candidate trade-off analysis or proprietary/managed-service evaluation (use the architecture-consultant agent or a domain overview skill), or for replatforming an existing production stack (use the migration-expert agent)."
license: MIT
---

# The Ultimate Open-Source Tech Stack

One default pick per domain of the domain-expert marketplace, selected from each domain's own technology catalog. **Rule zero: every pick carries an OSI-approved license.** Source-available licenses (BSL, SSPL, ELv2, Commons Clause, "fair-code") do not qualify — that rule alone rewrote several "obvious" answers (Terraform, Vault, MinIO, Linkerd).

When an app idea shows up and a domain decision is needed, use that domain's default and move on. The value of a default is not that it wins every comparison — it is that the comparison no longer has to happen.

## How to Apply These Defaults

- **Always start from the default.** State the pick and its one-line rationale; do not re-run a bake-off per project. Consistency compounds: shared runbooks, shared expertise, one upgrade treadmill per domain.
- **Never present the default as a mandate when real constraints exist.** An existing estate, a vendor mandate, deep team expertise elsewhere, or a compliance regime overrides a default. That conversation belongs to the `architecture-consultant` agent (Steps 1–5, decision matrix), not to this table.
- **Never adopt a component before a concrete pain names it.** Every running component is an operational liability. Start from the [Minimum Viable Stack](#minimum-viable-stack) and grow domain by domain.
- **Always re-verify the license before a new adoption.** Relicensing is now routine (Terraform 2023, Redis 2024, MinIO 2025). If a pick has left its OSI license since this file was written, promote its listed fallback to default and update this skill.
- **Route depth to the domain plugins.** Every pick maps to a skill in its domain plugin (`/plugin install <domain>@domain-expert`, then `/<domain>:<skill>`). If the plugin is not installed, continue from general knowledge and say the recommendation is not grounded in the skills library.

## The Stack at a Glance

| Domain | Default | License | Why it wins |
|---|---|---|---|
| **frontend** | Next.js (React) | MIT | Largest ecosystem and hiring pool; routing/SSR/RSC full-stack in one framework |
| **backend** | FastAPI | MIT | Typed async Python, OpenAPI docs for free, best AI/ML library adjacency |
| **database** | PostgreSQL | PostgreSQL | Relational + JSONB + pgvector + PostGIS + full-text — one engine covers most needs |
| **api-realtime** | REST + OpenAPI | Open standards | Universally consumable, contract-first tooling everywhere; per-interface escalations below |
| **messaging** | RabbitMQ | MPL-2.0 | Queues, pub/sub, DLQs, streams — right-sized for application messaging |
| **etl** | Apache Airflow + dbt Core | Apache-2.0 | The orchestration standard plus the SQL transformation standard |
| **analytics** | Apache Superset | Apache-2.0 | Most capable open-source BI, neutral ASF governance |
| **monitoring** | Prometheus + Grafana, via OpenTelemetry | Apache-2.0 / AGPLv3 | CNCF-graduated metrics standard + the de-facto dashboard layer |
| **containers** | Kubernetes | Apache-2.0 | The orchestration standard; every vendor and tool meets you there |
| **devops** | GitLab CE + OpenTofu + Argo CD + Ansible | MIT / MPL-2.0 / Apache-2.0 / GPLv3 | Self-hostable VCS+CI/CD platform with open IaC, GitOps, and config management |
| **security** | Keycloak | Apache-2.0 | Full OIDC/OAuth2/SAML identity provider — never roll your own auth |
| **networking** | Nginx | BSD-2 | Battle-tested edge: reverse proxy, TLS termination, load balancing, static serving |
| **storage** | Ceph | LGPL-2.1/3.0 | Unified block, file, and S3-compatible object storage at any scale |
| **virtualization** | Proxmox VE | AGPLv3 | KVM + LXC + HA + backups behind one UI; the post-VMware default |
| **os** | Ubuntu Server LTS | GPL + FOSS | Free 5-year LTS, broadest package/tooling/documentation coverage |
| **cli-scripting** | Python (+ Bash for glue) | PSF / GPLv3 | Readable automation with the deepest library bench |
| **mail-collab** | Postfix | EPL-2.0 / IPL-1.0 | The proven open-source MTA; the domain's only qualifying technology |
| **cloud-platforms** | — no qualifying pick | — | AWS/Azure/GCP are proprietary services; the stack stays provider-agnostic |

## Application Layer

### frontend → Next.js (React)

- **Why:** React remains the largest frontend ecosystem by components, tooling, and hiring pool; Next.js turns it into a full framework (file routing, SSR/SSG, React Server Components, API routes) without leaving MIT-licensed ground.
- **Self-host by default:** build with `output: 'standalone'` into a container. Never assume Vercel — the framework is open source; the hosting platform is not.
- **Runners-up:** Svelte/SvelteKit when bundle size and simplicity dominate; Astro for content-heavy, mostly-static sites; htmx when the backend renders HTML and a SPA is overkill.
- **Walk away when:** an established .NET team ships faster in Blazor — also open source, also in the catalog.
- **Deeper:** `frontend` plugin — `nextjs`, `nextjs-app-router`, `react`, `react-server-components` skills.

### backend → FastAPI

- **Why:** typed Python with Pydantic validation, async-first, OpenAPI schema and docs generated from the code, and first-class adjacency to the Python AI/ML ecosystem — the most likely integration any new app will need.
- **Runners-up:** NestJS for a single-language TypeScript stack with the Next.js frontend; Django when admin/ORM/auth batteries beat micro-flexibility; Go (`go-web`) for small, high-throughput services.
- **Walk away when:** the org is a JVM or .NET shop — Spring Boot and ASP.NET Core are both open source and both fine defaults there.
- **The framework is rarely the bottleneck.** The database is. Do not pick a backend for hello-world benchmarks.
- **Deeper:** `backend` plugin — `fastapi` skill (`overview` for cross-framework comparisons).

### api-realtime → REST + OpenAPI

Defaults are per interface type, not one global transport:

| Interface | Default | Why |
|---|---|---|
| Public / partner API | REST + OpenAPI contract | Universally consumable; generators and gateways everywhere |
| Internal service-to-service | gRPC | Typed contracts, streaming, an order of magnitude less serialization overhead |
| Server push (feeds, notifications, LLM token streams) | SSE | Plain HTTP, auto-reconnect, no upgrade dance — most "we need WebSockets" cases are SSE |
| True bidirectional (chat, collaborative editing, games) | WebSocket | The only default that earns full duplex |
| Many heterogeneous clients shaping divergent queries | GraphQL | Only then — it imports resolver and caching complexity |

- **Never expose gRPC publicly by default** — browser and tooling friction outweighs the win; front it with REST or gRPC-gateway.
- **Deeper:** `api-realtime` plugin — `rest`, `grpc`, `sse`, `websocket`, `graphql` skills.

### cli-scripting → Python

- **Why:** the default for any script beyond ~50 lines, all tooling, and all automation — readable, testable, batteries included, PSF-licensed.
- **Bash for glue:** one-liners, pipelines, CI steps. **Always rewrite Bash in Python once it grows data structures, error handling, or exceeds ~50 lines** — that script is now software.
- **PowerShell (MIT — genuinely open source) when driving Windows estates; Node.js when the repo is already TypeScript end-to-end.**
- **Deeper:** `cli-scripting` plugin — `python`, `bash`, `powershell` skills.

## Data Layer

### database → PostgreSQL

- **Why:** the most capable general-purpose open-source database, under a permissive license and community governance no single vendor can relicense. JSONB covers document workloads, `pgvector` covers embeddings/AI, PostGIS covers geospatial, built-in full-text covers basic search.
- **PostgreSQL until it hurts.** Default every new persistence need to Postgres first; reach for a specialist only when a measured limit names it:

| Need (measured, not imagined) | Specialist default | License |
|---|---|---|
| Hot cache / sessions / rate limits | Redis (AGPLv3 since 8.0 — open source again; Valkey BSD-3 is the drop-in if AGPL is banned) | AGPLv3 |
| Search / log analytics | OpenSearch (Apache-2.0, Linux Foundation; Elasticsearch is AGPL-licensed again and also qualifies) | Apache-2.0 |
| OLAP at scale (columnar, sub-second aggregates over billions of rows) | ClickHouse | Apache-2.0 |
| Embedded / single-node analytics | DuckDB | MIT |

- **Never use Redis as a durable message broker or primary store** — that job belongs to the messaging domain or Postgres.
- **Deeper:** `database` plugin — `postgresql`, `redis`, `opensearch`, `clickhouse`, `duckdb` skills.

### messaging → RabbitMQ

- **Why:** the right-sized default for application messaging — work queues, RPC, pub/sub, dead-letter handling, and (since 4.x) streams, with mature client libraries in every language.
- **Escalate to Kafka (Apache-2.0)** when the need is genuinely event streaming: replayable retained logs, multiple independent consumer groups, or six-figure messages/second pipelines feeding the data platform.
- **NATS (Apache-2.0)** when a single-binary, edge/IoT-weight bus fits better than a broker cluster.
- **Start with a Postgres job table** (`SKIP LOCKED`) for low-volume background jobs — a broker is not a day-one component.
- **Deeper:** `messaging` plugin — `rabbitmq`, `kafka`, `nats` skills (`overview` for the queue-vs-stream decision).

### etl → Apache Airflow + dbt Core

- **Why:** Airflow is the de-facto orchestration standard (ASF-governed, huge operator ecosystem); dbt Core is the SQL transformation standard — both Apache-2.0. dbt Core remains Apache-2.0 after the Fivetran/dbt Labs merger, and the new Fusion engine was open-sourced with dbt Core v2.
- **Processing engines:** DuckDB first for single-node transformation (most "big data" is not); Spark (Apache-2.0) when data genuinely exceeds one machine.
- **ELT over ETL:** land raw data, transform in the warehouse with dbt — pipelines stay debuggable and replayable.
- **Deeper:** `etl` plugin — `airflow`, `dbt-core`, `spark`, `duckdb` skills.

### analytics → Apache Superset

- **Why:** the most capable open-source BI platform (SQL Lab, 40+ chart types, dashboards, row-level security), governed by the ASF — no open-core feature ransom.
- **Runner-up:** Metabase (AGPLv3) when non-technical self-serve simplicity matters more than power — setup-to-first-dashboard is minutes.
- **Grafana is not the BI answer** — it is the operational dashboard default in monitoring. Keep business analytics in Superset.
- **Deeper:** `analytics` plugin — `superset`, `metabase` skills.

## Delivery and Operations

### devops → GitLab CE + OpenTofu + Argo CD + Ansible

One platform plus three category standards:

| Category | Default | License | Note |
|---|---|---|---|
| VCS hosting + CI/CD + registry | GitLab CE | MIT (open core) | The full loop, self-hostable; the CE core passes the gate |
| Infrastructure as Code | OpenTofu | MPL-2.0 | Terraform has been BSL since 1.6 — not open source. OpenTofu: Linux Foundation, state encryption, drop-in |
| GitOps delivery | Argo CD | Apache-2.0 | CNCF-graduated; the cluster pulls from git — CI never holds prod credentials |
| Config management / ad-hoc automation | Ansible | GPLv3 | Agentless, readable YAML, unmatched module breadth |

- **Always deliver to Kubernetes via GitOps (Argo CD), not CI push.** Auditability and rollback come free.
- **Jenkins (MIT)** only for existing estates — the controller/agent model and plugin treadmill are legacy weight, not a greenfield choice.
- **Deeper:** `devops` plugin — `gitlab-ci`, `opentofu`, `argocd`, `ansible` skills (`gitops`, `iac` for concepts).

### containers → Kubernetes

- **Why:** the orchestration standard, CNCF-graduated, with the entire cloud-native ecosystem built against its API. Portability across providers is the stack's cloud strategy.
- **Supporting picks:** containerd (runtime), Helm (packaging), Podman (local dev — Docker Engine is Apache-2.0 but Docker Desktop is proprietary; Podman Desktop is not), k3s (Apache-2.0) for edge, homelab, and small on-prem clusters.
- **Never add a service mesh until mTLS or traffic-policy requirements are written down.** Then: Istio (Apache-2.0, Ambient mode) — Linkerd's stable releases moved behind Buoyant's paywall in 2024.
- **Compose (Podman or Docker) is the correct dev-loop and single-host default** — Kubernetes is not a day-one requirement.
- **Deeper:** `containers` plugin — `kubernetes`, `helm`, `podman`, `containerd`, `istio`, `rancher` skills.

### monitoring → Prometheus + Grafana, instrumented via OpenTelemetry

- **Why:** Prometheus (Apache-2.0, CNCF-graduated) is the metrics and alerting standard; Grafana (AGPLv3 — open source, fine to run) is the visualization layer everything integrates with.
- **Always instrument application code with OpenTelemetry SDKs, never a vendor SDK.** OTLP keeps every backend — including future proprietary ones — a config change, not a code change.
- **Logs:** ship to OpenSearch (Apache-2.0). **Alerting:** Prometheus Alertmanager. Start with the RED metrics per service; dashboards grow from incidents, not upfront.
- **Deeper:** `monitoring` plugin — `prometheus`, `grafana`, `opentelemetry`, `elk` skills.

### security → Keycloak

Identity first — it is the security decision every app hits in week one:

- **Never roll your own auth.** Keycloak (Apache-2.0, CNCF) gives OIDC, OAuth2, SAML, MFA, and user federation self-hosted. Framework session auth is acceptable only until the second client or the first SSO request.

| Category | Default | License |
|---|---|---|
| Runtime secrets management | Infisical (Vault has been BSL since 2023 — disqualified; OpenBao is the off-catalog fork) | MIT |
| Secrets in git | sops (+ age) | MPL-2.0 |
| TLS certificates | cert-manager + Let's Encrypt | Apache-2.0 |
| SAST / code scanning | Semgrep CE | LGPL-2.1 engine |
| DAST | OWASP ZAP | Apache-2.0 |
| Runtime / container threat detection | Falco | Apache-2.0 |
| Host security + SIEM/XDR | Wazuh | GPLv2 |
| Network IDS | Suricata | GPLv2 |

- **Never commit a plaintext secret; never bake one into an image.** Runtime injection from Infisical, or sops-encrypted files in git — nothing else.
- **Deeper:** `security` plugin — `keycloak`, `infisical`, `sops`, `cert-manager`, `semgrep`, `zap`, `falco`, `wazuh`, `suricata` skills.

## Infrastructure Layer

### networking → Nginx

- **Why:** the default edge for any app — reverse proxy, TLS termination, load balancing, static serving — BSD-licensed, boring, and everywhere.

| Category | Default | License |
|---|---|---|
| Edge / reverse proxy / LB | Nginx (HAProxy GPLv2 for dedicated L4/L7 balancing) | BSD-2 |
| Service proxy (gRPC-aware, mesh data plane) | Envoy | Apache-2.0 |
| DNS in-cluster | CoreDNS | Apache-2.0 |
| DNS authoritative / recursive | PowerDNS / Unbound | GPLv2 / BSD-3 |
| VPN | WireGuard | GPLv2 |
| Firewall / edge router | OPNsense (preferred over stagnant pfSense CE) | BSD-2 |
| Network source of truth / IPAM | NetBox | Apache-2.0 |

- **Deeper:** `networking` plugin — `nginx`, `haproxy`, `envoy`, `coredns`, `powerdns`, `unbound`, `wireguard`, `opnsense`, `netbox` skills.

### storage → Ceph

- **Why:** one LGPL-licensed system for block (RBD), file (CephFS), and S3-compatible object (RGW) storage, proven at exabyte scale, deployed on Kubernetes via Rook.
- **MinIO is no longer eligible:** its Community Edition was feature-stripped in 2025 and archived in April 2026 — AGPL source remains, maintenance does not. Migrate existing installs to Ceph RGW; the S3 API makes that a data move, not a rewrite.
- **In cloud, use the provider's object store** (S3/Blob/GCS) as a conscious managed-service exception — portability lives in the S3 API and open data formats, not in self-hosting object storage you don't operate at scale.
- **Deeper:** `storage` plugin — `ceph` skill (`overview` for SAN/NAS/object selection).

### virtualization → Proxmox VE

- **Why:** KVM/QEMU and LXC with clustering, HA, live migration, integrated Ceph, and Proxmox Backup Server behind one web UI — AGPLv3, no license keys, the industry's post-Broadcom VMware exit ramp.
- **Runners-up:** plain KVM/QEMU + libvirt when a platform is unwanted; cloud VMs when workloads already live in a provider.
- **Deeper:** `virtualization` plugin — `proxmox`, `kvm` skills.

### os → Ubuntu Server LTS

- **Why:** free five-year LTS, the broadest package/driver/documentation coverage, and the default target for nearly every tool in this stack. Standardize on one distro family — heterogeneous fleets multiply patching and automation cost.
- **Runners-up:** Debian when purist community governance and stability outweigh cadence; Rocky/Alma when RHEL compatibility is contractual.
- **Containers shrink this decision** to the base-image line of a Dockerfile — which is where it belongs.
- **Deeper:** `os` plugin — `ubuntu`, `debian`, `rocky-alma` skills.

### mail-collab → Postfix

- **Why:** the proven, secure open-source MTA — and the only technology in this domain's catalog that passes the license gate (Exchange, M365, Google Workspace are proprietary).
- **The real work is authentication:** SPF, DKIM, and DMARC records before the first message, or nothing lands in an inbox.
- **High-volume transactional delivery** usually justifies a managed sending service — a conscious proprietary exception, flagged as such, with Postfix still owning internal relay.
- **Deeper:** `mail-collab` plugin — `postfix` skill.

### cloud-platforms → no qualifying pick

- AWS, Azure, and GCP are proprietary service platforms; nothing in this domain passes the open-source gate — so the domain gets **no default, by design**.
- **The stack is provider-agnostic by construction:** Kubernetes + OpenTofu + containerized open-source components make the provider (or bare metal via Proxmox) an implementation detail.
- Choosing a provider anyway is a cost/region/compliance decision — run it through the `architecture-consultant` agent, not this table.
- **Deeper:** `cloud-platforms` plugin — `overview` skill for provider selection when that conversation happens.

## Minimum Viable Stack

Defaults say what to use — not that you need it yet. Day one for a new app:

| Layer | Start with | Add later, when |
|---|---|---|
| App | Next.js + FastAPI + PostgreSQL | — |
| Auth | Framework sessions | Keycloak at the second client or first SSO ask |
| Background jobs | Postgres job table (`SKIP LOCKED`) | RabbitMQ when queue depth or fan-out is real |
| Dev/run | Podman/Docker Compose on Ubuntu, Nginx at the edge | Kubernetes (k3s first) past a handful of services |
| CI/CD | GitLab CE pipeline building one image | Argo CD when Kubernetes arrives |
| Observability | Structured logs + `/metrics` endpoint | Prometheus + Grafana at the second service or first SLO |
| Data platform | Nightly `pg_dump` + SQL | Airflow + dbt + Superset when someone asks for reports weekly |

**Never deploy Kafka, Kubernetes, Istio, or Airflow on day one of an MVP.** Each earns its way in by a named, measured pain.

## The Open-Source Gate

Every current and future pick must clear all six. This is how the stack was chosen and how challengers get evaluated:

1. **OSI-approved license** on every component you run in production. Apache-2.0, MIT, BSD, MPL, LGPL, GPL, AGPL all qualify. BSL, SSPL, ELv2, Commons Clause, and "source-available" do not — regardless of marketing.
2. **AGPL is open source.** Running it is fine; obligations trigger only when you modify the component and serve *it* to others. Flag it, don't fear it — unless org counsel bans it (then use the listed fallback, e.g. Valkey for Redis).
3. **No feature-gated operational core.** If HA, SSO, backups, or the admin UI live only in the paid tier, treat the product as proprietary in practice (the "SSO tax" test — MinIO CE failed exactly this way before it was archived).
4. **Governance you can trust:** foundation-hosted (CNCF, ASF, Linux Foundation) or genuinely multi-vendor preferred. Single-vendor open source carries relicensing risk — every disqualification below started there. A credible fork exit (OpenTofu, OpenBao, Valkey) is the insurance policy.
5. **Active health:** releases within six months, a security-response process, a documented upgrade path.
6. **Exit path via open interfaces:** SQL, S3 API, AMQP, OTLP, OCI, OpenAPI. Any component you can only leave by rewrite was never a safe default.

## Disqualified and Replaced

The license events that shaped this stack — treat this table as precedent when a vendor announces a "license evolution":

| Ruled out | Event | Default instead |
|---|---|---|
| Terraform | BSL 1.1 since Aug 2023 (now IBM-owned) | OpenTofu (MPL-2.0, Linux Foundation) |
| HashiCorp Vault | BSL 1.1 since Aug 2023 | Infisical (MIT); sops for git-encrypted secrets |
| MinIO Community Edition | Admin UI stripped 2025; repo archived Apr 2026 | Ceph RGW |
| Linkerd | Stable release binaries paywalled since 2024 | Istio (Apache-2.0) |
| Elasticsearch | SSPL era 2021–2024 (AGPL option restored — eligible again) | OpenSearch stays default: Apache-2.0 + neutral foundation |
| Redis | RSAL/SSPL Mar 2024 → **AGPLv3 restored with 8.0** | Redis stays in; Valkey (BSD-3) if AGPL is banned |
| Docker Desktop | Proprietary (Engine remains Apache-2.0) | Podman + Podman Desktop |
| GitHub Actions / Azure DevOps | Proprietary services (fine, but not open source) | GitLab CE |
| AWS / Azure / GCP | Proprietary platforms | No default — provider-agnostic stack |

## Keeping This Current

- **Re-verify the license of any single-vendor pick before each new adoption**, and sweep the whole table roughly quarterly — this file records the state as of August 2026.
- When a catalog technology overtakes a default (or a default is relicensed), update the pick here, keep the old one in [Disqualified and Replaced](#disqualified-and-replaced), and bump the `domain-expert-core` plugin version — unreleased updates never reach users.
- A challenger enters only through the [Open-Source Gate](#the-open-source-gate), and only with a reason a default stopped being one.
