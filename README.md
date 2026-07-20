# Domain Expert Marketplace

> **Preview / Beta** — This marketplace is in beta experimentation mode. It is not intended for production use without proper testing and validation. Plugin content and agent behavior may change between releases.

A **Claude Code plugin marketplace** with one plugin per IT domain. Each domain plugin ships:

- **One skill per technology** (`/database:postgresql`, `/security:entra-id`, `/containers:kubernetes`) with deep, version-specific expertise
- **Version references** — `references/versions/<v>.md` files capturing what's new, changed, or deprecated in each release, so answers stay version-accurate
- **Diagnostic scripts** — runnable PowerShell/Bash/CLI diagnostics bundled with the skills that need them
- **A domain-specialist subagent** that navigates its plugin's skill tree deterministically — exact paths, narrowest-file reads, cited sources

Install only the domains you work with. A DBA might install `database` and `os`; a platform team might add `containers`, `devops`, and `monitoring`.

**19 plugins | 18 domains | 420 skills | 190+ version references | ~390 diagnostic scripts | 24 agents**

📊 **[Live Evaluation Dashboard](https://chrishuffman5.github.io/domain-expert/)** — per-domain accuracy, script coverage, and agent-vs-baseline results.

---

## Installation

Register the marketplace once:

```
/plugin marketplace add chrishuffman5/domain-expert
```

Then install the domain plugins you need:

```
/plugin install database@domain-expert
/plugin install security@domain-expert
/plugin install domain-expert-core@domain-expert   # cross-domain task agents
```

Restart Claude Code (or run `/reload-plugins`) after installing.

### Verify

Ask something that should trigger a skill or agent:

```
> Which database should I use for a social app with 10M users?
> Our SQL Server 2022 instance has had CPU at 95% since last night.
> What changed in PostgreSQL 18 that affects our upgrade from 16?
> Harden our Entra ID conditional access policies.
```

### Upgrading from the old monolithic plugin

Before v1.0 this repository was a single `domain-expert` plugin. The marketplace maps that name to `domain-expert-core` automatically (Claude Code v2.1.193+): update the marketplace and your install migrates, then add the domain plugins you want:

```
/plugin marketplace update domain-expert
/plugin install database@domain-expert    # etc.
```

---

## The Plugins

| Plugin | Skills | Covers | Specialist Agent |
|--------|-------:|--------|------------------|
| **database** | 30 | PostgreSQL, SQL Server, Oracle, MySQL, MongoDB, Redis, Snowflake, DuckDB + 21 more engines | database-specialist |
| **security** | 137 | IAM (Entra ID, Okta, AD DS…), EDR (CrowdStrike…), SIEM (Sentinel, Splunk…), secrets (Vault…), AppSec, DLP, GRC, zero trust | security-specialist |
| **networking** | 68 | Routing/switching, firewalls (PAN-OS, FortiOS…), DNS, load balancing, VPN, SD-WAN, wireless, IPAM, automation | networking-specialist |
| **devops** | 22 | GitHub Actions, GitLab CI, Jenkins, Terraform, Bicep, Ansible, ArgoCD, Flux, GitHub | devops-specialist |
| **os** | 20 | Windows Server/Client, RHEL, Ubuntu, Debian, SLES, Rocky/Alma, macOS + Hyper-V, SELinux, WSL, failover clustering | os-specialist |
| **etl** | 19 | Airflow, dbt, Spark, Kafka (pipelines), SSIS, ADF, Glue, Fivetran, NiFi, DuckDB | etl-specialist |
| **containers** | 17 | Kubernetes, EKS/AKS/GKE, Helm, OpenShift, Docker, Podman, containerd, Istio, Linkerd, Consul | containers-specialist |
| **frontend** | 15 | React (+ Server Components), Next.js (+ App Router), Vue, Nuxt, Angular (+ Signals), Svelte, Astro, Blazor | frontend-specialist |
| **storage** | 13 | NetApp ONTAP, Pure, Dell, Ceph, MinIO, GlusterFS, S3, Azure Blob, GCS, Storage Spaces Direct | storage-specialist |
| **analytics** | 12 | Power BI, Tableau, Looker, Qlik, SSAS/SSRS, Superset, Metabase, ThoughtSpot, Grafana (BI), DuckDB (BI) | analytics-specialist |
| **monitoring** | 12 | Prometheus, Grafana, ELK, OpenTelemetry, Datadog, New Relic, Dynatrace, Splunk (observability), PagerDuty | monitoring-specialist |
| **backend** | 12 | ASP.NET Core (+ Minimal APIs), Spring Boot, Django, Rails, Express, FastAPI, NestJS, Flask, Go, Rust | backend-specialist |
| **api-realtime** | 9 | REST, GraphQL, gRPC, OData, WebSocket, SSE, SignalR, Socket.IO | api-realtime-specialist |
| **messaging** | 9 | Kafka (brokers), RabbitMQ, Pulsar, NATS, SQS/SNS, Service Bus, Pub/Sub, Redis Streams | messaging-specialist |
| **cli-scripting** | 8 | PowerShell, Bash, Python, Node.js, AWS CLI, Azure CLI, kubectl | cli-scripting-specialist |
| **virtualization** | 7 | VMware vSphere, Proxmox, KVM/QEMU, Nutanix, Citrix, cloud VMs | virtualization-specialist |
| **mail-collab** | 5 | Exchange, Microsoft 365, Google Workspace, Postfix | mail-collab-specialist |
| **cloud-platforms** | 4 | AWS, Azure, GCP architecture, Well-Architected, migration, FinOps | cloud-platforms-specialist |
| **domain-expert-core** | 1 | Cross-domain task agents (below) + the update-plugin skill | — |

Overlapping technologies are deliberately split by angle, with each skill's description excluding the others — e.g. Kafka broker ops (`messaging`) vs Kafka pipelines (`etl`), Grafana observability (`monitoring`) vs Grafana BI (`analytics`), Splunk platform ops (`monitoring`) vs Splunk SIEM (`security`), DuckDB engine (`database`) vs ETL (`etl`) vs BI (`analytics`).

### Cross-domain task agents (`domain-expert-core`)

| Agent | Triggers On |
|-------|------------|
| **architecture-consultant** | "which database", "recommend", "compare", "what stack for", "capacity planning" |
| **troubleshooting-agent** | "slow", "error", "CPU high", "diagnose", "not working", "outage" |
| **migration-expert** | "migrate from X to Y", "switch from", "feature mapping", "compatibility" |
| **iac-consultant** | "create Terraform", "CloudFormation", "provision", "deploy to cloud" |
| **data-expert** | "data classification", "PII", "GDPR", "data masking", "agent data access" |
| **security-expert** | "harden", "CIS benchmark", "IAM", "agent permissions", "secrets management" |

These orchestrate whichever domain plugins you have installed, delegating depth to the domain specialists and degrading gracefully when a domain isn't installed.

---

## How a Skill Is Structured

```
plugins/database/skills/postgresql/
├── SKILL.md                    # 200–500 lines: core expertise + when-to-read pointers
├── references/
│   ├── versions/14.md … 18.md  # per-version features, deprecations, upgrade nuances
│   └── *.md                    # deep-dive docs, loaded only when needed
├── scripts/                    # runnable diagnostics (scripts/versions/<v>/ when version-specific)
└── assets/                     # config templates used in output
```

Skills follow a strict quality bar (see [CLAUDE.md](CLAUDE.md)): descriptions state what the skill covers, when to use it, and when **not** to (negative triggers against overlapping skills); bodies stay in the 200–500 line sweet spot with detail pushed to references; instructions are directives, not essays. Every plugin ships `evals/trigger-evals.json` — a positive and a hard near-miss prompt per skill — so trigger accuracy is testable.

## Usage

Just describe what you need. Knowledge questions trigger the matching technology skill; single-domain work auto-delegates to that domain's specialist agent; cross-domain tasks go to a task agent from `domain-expert-core`. Advanced users can invoke directly: `/database:postgresql`, `/security:iam`, or `@database-specialist`.

## Keeping Plugins Up to Date

Ask Claude (the `update-plugin` skill in `domain-expert-core` handles it):

```
> Update my domain-expert plugins to the latest version.
```

Or manually:

```bash
claude plugin marketplace update domain-expert
claude plugin update database@domain-expert
```

> Restart Claude Code after updating — the running session keeps the version it started with.

## Other Platforms

The skills are standard `SKILL.md` bundles, so they work anywhere Agent Skills are supported. For GitHub Copilot CLI, OpenAI Codex CLI, or Gemini CLI, copy the skill folders of the domains you want into that tool's skills directory, e.g.:

```bash
git clone https://github.com/chrishuffman5/domain-expert.git
cp -r domain-expert/plugins/database/skills/* ~/.codex/skills/
```

Subagents and the marketplace/update flows are Claude Code-specific.

## Evals

Two layers:

- **Repo-level agent suites** (`evals/`) — measure each domain specialist's accuracy against a no-tools baseline; results feed the [dashboard](https://chrishuffman5.github.io/domain-expert/).
- **Per-plugin trigger evals** (`plugins/<domain>/evals/trigger-evals.json`) — positive + near-miss prompts per skill to catch missed triggers and false fires.

## Contributing / Development

```bash
claude plugin validate .                    # marketplace catalog
claude plugin validate ./plugins/database   # any plugin you touch
claude --plugin-dir ./plugins/database      # test a plugin locally without installing
```

Conventions are enforced per [CLAUDE.md](CLAUDE.md). Each plugin versions independently via its `plugin.json` — bump `version` on every release or users won't receive updates.

## License

MIT — see [LICENSE](LICENSE).
