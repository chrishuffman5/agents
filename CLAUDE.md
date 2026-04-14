# Domain Expert Plugin

Expert knowledge across 18 IT domains (186+ technologies) with task-oriented subagents that orchestrate that knowledge for complex workflows.

## Skills (Knowledge Library)

Ask technology-specific questions and get deep, version-specific expertise from `skills/`.

- **Database** (29 technologies) — SQL Server, PostgreSQL, Oracle, MySQL, MongoDB, Redis, Snowflake, and more
- **DevOps** (16) — Terraform, GitHub Actions, Ansible, ArgoCD, Jenkins, and more
- **Security** (14) — Active Directory, Entra ID, CrowdStrike, and more
- **Operating Systems** (8) — Windows Server, RHEL, Ubuntu, macOS, and more
- **Frontend** (11) — React, Vue, Angular, Next.js, and more
- **Backend** (10) — ASP.NET Core, Express, FastAPI, Django, Spring Boot, and more
- **Networking** (12) — Cisco IOS, Palo Alto, Fortinet, and more
- **Monitoring** (11) — Prometheus, Grafana, ELK Stack, Datadog, and more
- **Containers** (3) — Docker, Kubernetes, Podman
- **Cloud Platforms** (3) — AWS, Azure, GCP
- **ETL** (14), **Analytics** (11), **Storage** (12), **Virtualization** (5), **CLI/Scripting** (7), **API/Real-Time** (8), **Messaging** (6), **Mail/Collaboration** (4)

## Agents (Task Specialists)

Describe a task and Claude auto-delegates to the right specialist from `agents/`.

| Agent | Triggers On |
|-------|------------|
| **architecture-consultant** | "which database", "recommend", "compare", "what stack for", "capacity planning" |
| **troubleshooting-agent** | "slow", "error", "CPU high", "diagnose", "not working", "outage" |
| **migration-expert** | "migrate from X to Y", "switch from", "feature mapping", "compatibility" |
| **iac-consultant** | "create Terraform", "CloudFormation", "provision", "deploy to cloud" |
| **data-expert** | "data classification", "PII", "GDPR", "data masking", "agent data access" |
| **security-expert** | "harden", "CIS benchmark", "IAM", "agent permissions", "secrets management" |

## Usage

Just describe what you need. Knowledge questions load skills directly. Task-oriented prompts auto-delegate to the right agent. Advanced users can invoke directly with `@agent-name`.
