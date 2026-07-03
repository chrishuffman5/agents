# Domain Expert Plugin

Expert knowledge across 18 IT domains (186+ technologies) with domain-specialist subagents (one per domain) and task-oriented subagents that orchestrate that knowledge for complex workflows.

## Skills (Knowledge Library)

Ask technology-specific questions and get deep, version-specific expertise from `skills/`.

- **Database** (29 technologies) — SQL Server, PostgreSQL, Oracle, MySQL, MongoDB, Redis, Snowflake, and more
- **DevOps** (17) — Terraform, GitHub Actions, Ansible, ArgoCD, Jenkins, GitHub repo management, and more
- **Security** (14) — Active Directory, Entra ID, CrowdStrike, and more
- **Operating Systems** (8) — Windows Server, RHEL, Ubuntu, macOS, and more
- **Frontend** (11) — React, Vue, Angular, Next.js, and more
- **Backend** (10) — ASP.NET Core, Express, FastAPI, Django, Spring Boot, and more
- **Networking** (12) — Cisco IOS, Palo Alto, Fortinet, and more
- **Monitoring** (11) — Prometheus, Grafana, ELK Stack, Datadog, and more
- **Containers** (3) — Docker, Kubernetes, Podman
- **Cloud Platforms** (3) — AWS, Azure, GCP
- **ETL** (14), **Analytics** (11), **Storage** (12), **Virtualization** (5), **CLI/Scripting** (7), **API/Real-Time** (8), **Messaging** (6), **Mail/Collaboration** (4)

## Domain Specialists (One Agent per Domain)

Each of the 18 domains has a dedicated specialist agent in `agents/` that runs in its own context with a precise knowledge map of its skill tree — it resolves exact file paths instead of searching, reads the narrowest file that answers, and cites every claim with a skill path.

| Agent | Domain | Example Triggers |
|-------|--------|------------------|
| **database-specialist** | 29 engines (SQL Server, PostgreSQL, MongoDB, Redis…) | "query tuning", "replication", "which database" |
| **os-specialist** | Windows Server/Client, RHEL, Ubuntu, Debian, SLES, macOS | "SELinux", "GPO", "kernel tuning", "patching" |
| **networking-specialist** | Routing, firewalls, DNS, LB, VPN, SD-WAN, wireless | "BGP", "firewall rule", "packet loss", "VLAN" |
| **security-specialist** | IAM, EDR, SIEM, secrets, cloud/app/network security | "Entra ID", "CrowdStrike", "detection rule", "Vault" |
| **devops-specialist** | CI/CD, IaC, config mgmt, GitOps, version control | "GitHub Actions", "Terraform", "ArgoCD", "pipeline" |
| **containers-specialist** | Kubernetes, EKS/AKS/GKE, Helm, Docker, service mesh | "CrashLoopBackOff", "Helm chart", "Istio" |
| **cloud-platforms-specialist** | AWS, Azure, GCP strategy and architecture | "which cloud", "migration", "FinOps", "landing zone" |
| **frontend-specialist** | React, Next.js, Vue, Angular, Svelte, Astro, Blazor… | "hydration", "server components", "signals" |
| **backend-specialist** | ASP.NET Core, Spring Boot, Django, Rails, Express… | "REST endpoint", "middleware", "ORM", "JWT" |
| **monitoring-specialist** | Prometheus, Grafana, ELK, OTel, Datadog, PagerDuty | "PromQL", "SLO", "alert fatigue", "tracing" |
| **storage-specialist** | ONTAP, Pure, Ceph, MinIO, S3, Azure Blob, GCS | "SAN", "erasure coding", "IOPS", "lifecycle" |
| **virtualization-specialist** | VMware, Proxmox, KVM, Nutanix, Citrix, cloud VMs | "vMotion", "CPU ready", "VMware exit", "P2V" |
| **cli-scripting-specialist** | PowerShell, Bash, Python, Node, AWS/Azure CLI, kubectl | "script", "one-liner", "cron", "exit code" |
| **etl-specialist** | Airflow, dbt, Spark, SSIS, ADF, Glue, Fivetran, NiFi | "data pipeline", "DAG", "CDC", "backfill" |
| **analytics-specialist** | Power BI, Tableau, Looker, Qlik, SSAS/SSRS, Superset | "DAX", "semantic model", "dashboard", "RLS" |
| **api-realtime-specialist** | REST, GraphQL, gRPC, OData, WebSocket, SSE, SignalR | "API versioning", "resolver", "reconnect" |
| **messaging-specialist** | Kafka, RabbitMQ, Pulsar, NATS, SQS/SNS, Service Bus | "consumer lag", "DLQ", "exactly-once", "outbox" |
| **mail-collab-specialist** | Exchange, M365, Google Workspace, Postfix | "mail flow", "SPF/DKIM/DMARC", "hybrid", "NDR" |

## Agents (Task Specialists)

Cross-domain task agents orchestrate multiple domains for complex workflows.

| Agent | Triggers On |
|-------|------------|
| **architecture-consultant** | "which database", "recommend", "compare", "what stack for", "capacity planning" |
| **troubleshooting-agent** | "slow", "error", "CPU high", "diagnose", "not working", "outage" |
| **migration-expert** | "migrate from X to Y", "switch from", "feature mapping", "compatibility" |
| **iac-consultant** | "create Terraform", "CloudFormation", "provision", "deploy to cloud" |
| **data-expert** | "data classification", "PII", "GDPR", "data masking", "agent data access" |
| **security-expert** | "harden", "CIS benchmark", "IAM", "agent permissions", "secrets management" |

## Usage

Just describe what you need. Knowledge questions load skills directly. Single-domain work auto-delegates to the matching domain specialist; cross-domain tasks go to a task specialist. Advanced users can invoke directly with `@agent-name`.
