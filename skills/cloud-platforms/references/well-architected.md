# Well-Architected Design Principles (Cross-Cloud)

> Design principles that apply regardless of cloud provider, plus per-cloud framework summaries and organizational structures.

---

## Cross-Cloud Design Principles

### Operational Excellence

- **IaC everywhere** -- Every resource defined in code (Terraform, CloudFormation, Bicep, Pulumi). No manual console changes in production.
- **CI/CD pipelines** -- Automated build, test, deploy. Feature flags for decoupled deployment from release.
- **Observability** -- Three pillars: metrics, logs, traces. Use cloud-native tools or unified platforms (Datadog, Grafana Cloud).
- **Runbooks and playbooks** -- Documented procedures for common operational tasks and incident response. Automate progressively.
- **Post-incident review** -- Blameless retrospectives. Track action items to completion.
- **Deployment strategies** -- Blue/green, canary, rolling updates. Never big-bang in production.

### Security

- **Zero trust architecture** -- Verify every request regardless of network location. Identity-based access, not network-based.
- **Least privilege** -- Every identity gets minimum permissions needed. Review and tighten regularly.
- **Encryption at rest** -- All data stores encrypted with managed keys. Automatic key rotation.
- **Encryption in transit** -- TLS 1.2+ for all communication. Mutual TLS for service-to-service where practical.
- **Managed identities** -- Use IAM roles (AWS), Managed Identities (Azure), Workload Identity (GCP). Eliminate long-lived credentials.
- **Network segmentation** -- Private subnets for workloads, public only for load balancers. Deny-by-default security groups/NSGs.
- **Secrets management** -- Secrets in dedicated services. Never in code, environment variables, or config files.
- **Audit logging** -- CloudTrail / Activity Log / Audit Logs. Immutable, centralized, monitored.

### Reliability

- **Multi-AZ as minimum** -- Every production workload spans at least 2 availability zones. No single-AZ production.
- **Multi-region for critical** -- Business-critical workloads with <4h RTO need multi-region. Adds cost and complexity.
- **Health checks and auto-healing** -- Load balancers check health, auto-scaling replaces unhealthy instances, K8s restarts failed pods.
- **Chaos engineering** -- Regularly inject failures to validate resilience.
- **DR tiers:**
  - Backup & Restore: RPO hours, RTO hours. Cheapest.
  - Pilot Light: RPO minutes, RTO minutes-hours. Core infra always running.
  - Warm Standby: RPO seconds-minutes, RTO minutes. Scaled-down copy.
  - Hot/Active-Active: RPO near-zero, RTO near-zero. Most expensive.
- **Dependency management** -- Circuit breakers, retries with exponential backoff, bulkhead isolation.

### Performance Efficiency

- **Right-sizing** -- Start small, measure, adjust. Use cloud sizing tools (Compute Optimizer, Azure Advisor, GCP Recommender).
- **Caching layers** -- CDN for static content, in-memory cache for hot data, application-level caching.
- **Async processing** -- Decouple with queues. Process asynchronously what doesn't need synchronous response.
- **Auto-scaling** -- Horizontal scaling based on metrics. Target tracking policies as starting point.
- **Database optimization** -- Read replicas for read-heavy workloads, connection pooling, query optimization.
- **Content delivery** -- CDN for global audiences. Edge computing for edge logic.
- **Storage tiering** -- Hot/cool/archive based on access patterns. Lifecycle policies to auto-transition.

### Cost Optimization

- **Right-sizing** -- The single highest-impact cost optimization. Downsize over-provisioned resources.
- **Reserved capacity** -- Commit to steady-state workloads (RIs, Savings Plans, CUDs). 1-year for certain, 3-year when confident.
- **Spot/preemptible for fault-tolerant** -- Batch jobs, CI/CD, stateless workers, dev/test environments.
- **Storage tiering** -- Lifecycle policies: move to infrequent access after 30 days, archive after 90.
- **Eliminate waste** -- Unattached volumes, idle load balancers, unused static IPs, oversized instances, orphaned snapshots.
- **Tagging** -- Every resource tagged. Untagged resources are invisible to cost management.
- **Budgets and alerts** -- Set monthly budgets per team/project. Alert at 50%, 80%, 100% thresholds.

### Sustainability

- **Right-sizing reduces carbon** -- Fewer resources = less energy.
- **Serverless when appropriate** -- Pay-per-use means idle resources don't consume energy.
- **Region selection** -- Choose regions powered by renewable energy when latency allows.
- **ARM instances** -- Graviton/Ampere offer better performance-per-watt.
- **Data lifecycle management** -- Delete data no longer needed. Compress cold storage.

---

## AWS Well-Architected Framework

**Six pillars:** Operational Excellence, Security, Reliability, Performance Efficiency, Cost Optimization, Sustainability.

**Key tools:**
- **Well-Architected Tool** -- In-console assessment against six pillars with improvement plan
- **Lens catalog** -- Domain-specific: SaaS, Serverless, ML, Data Analytics, IoT, Financial Services, Container Build
- **Trusted Advisor** -- Automated checks for cost, performance, security, fault tolerance, service limits
- **Compute Optimizer** -- ML-based right-sizing for EC2, EBS, Lambda, ECS on Fargate

**AWS-specific patterns:**
- Landing Zone (Control Tower) for multi-account governance
- Service Control Policies (SCPs) for organizational guardrails
- AWS Organizations for multi-account structure
- CloudTrail Organization trail for centralized audit
- GuardDuty delegated administrator for centralized threat detection

**Recommended multi-account structure:**
- Management account (Organizations root, billing, no workloads)
- Security account (GuardDuty admin, Security Hub, CloudTrail archive)
- Log archive account (immutable CloudTrail, VPC flow logs, Config logs)
- Shared services account (CI/CD, container registry, shared tooling)
- Network account (Transit Gateway, Direct Connect, shared DNS)
- Workload accounts (one per application or team per environment)
- Sandbox accounts (experimentation, isolated, limited budget)

---

## Azure Well-Architected Framework

**Five pillars:** Reliability, Security, Cost Optimization, Operational Excellence, Performance Efficiency.

**Key tools:**
- **Azure Advisor** -- Recommendations across reliability, security, performance, cost, operational excellence
- **WAF assessments** -- In-portal assessments with prioritized action items
- **Azure Monitor** -- Metrics, logs, alerts, dashboards, Application Insights for APM
- **Microsoft Defender for Cloud** -- Security posture management and threat protection

**Azure-specific patterns:**
- Landing Zone (Azure Landing Zones / Enterprise Scale) for subscription governance
- Management Groups for hierarchical policy and RBAC
- Azure Policy for resource compliance enforcement
- Entra ID for centralized identity across Azure + O365 + third-party SaaS
- Hub-spoke or Virtual WAN for network topology

**Recommended subscription structure:**
- Management Group hierarchy: Root > Platform + Workloads + Sandbox
- Platform subscriptions: Identity, Management, Connectivity
- Workload subscriptions: one per application or team per environment
- Connectivity subscription: hub VNet, ExpressRoute, Azure Firewall
- Management subscription: Log Analytics workspace, Automation, Monitor

---

## GCP Cloud Architecture Framework

**Five focus areas:** System Design, Operational Excellence, Security/Privacy/Compliance, Reliability, Cost Optimization.

**Key tools:**
- **Active Assist** -- ML-powered recommendations for right-sizing, idle resources, security, networking
- **Recommender** -- API for programmatic access to recommendations
- **Cloud Monitoring + Logging** -- Integrated observability with uptime checks and alerting
- **Security Command Center** -- Security posture management, vulnerability scanning, threat detection

**GCP-specific patterns:**
- Landing Zone (Cloud Foundation Toolkit / Fabric FAST)
- Organization Policies for constraint enforcement
- Shared VPC for centralized network management
- VPC Service Controls for data exfiltration prevention
- Workload Identity Federation for keyless authentication
- Project-based isolation (each workload in its own project)

**Recommended resource hierarchy:**
- Organization node (domain-level policies)
- Folders: Platform, Production, Non-Production, Sandbox, Shared Services
- Projects: one per service per environment (fine-grained isolation)
- Shared VPC: host project in Platform folder, service projects attached
- Billing account linked to Organization with budget alerts per folder/project

---

## Anti-Patterns to Avoid (All Clouds)

1. **Treating cloud like a data center** -- Lifting VMs without adopting elasticity, managed services, or automation. Higher costs with none of the benefits.
2. **Over-engineering for scale** -- Building for 10M users when you have 10K. Start simple, design for evolution.
3. **Ignoring data gravity** -- Data is expensive to move. Place compute near data. Egress costs compound.
4. **Single AZ in production** -- One AZ failure takes down the entire application.
5. **No resource tagging** -- Makes cost allocation, automation, and security impossible at scale.
6. **Hardcoded configuration** -- Region, account ID, resource names in code. Use service discovery and parameter stores.
7. **Overly permissive IAM** -- `*:*` policies, admin access for services, shared credentials.
8. **No backup testing** -- A backup you can't restore is not a backup.
9. **Ignoring limits and quotas** -- Every cloud service has limits. Know them before production surprises.
10. **Monolithic IaC** -- One state file for everything. Break into layers: networking, compute, data, application.
