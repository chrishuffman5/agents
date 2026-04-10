# IT Domain Knowledge Skills Library

A comprehensive library of **domain expert knowledge skills** organized by IT domain, technology, and version. Each skill provides deep, version-specific expertise that transforms a general-purpose AI assistant into a genuine specialist.

**1,578+ files | 165+ technologies | 15 domains | 443,000+ lines of expert knowledge**

---

## What Are These Skills?

Each skill is a structured knowledge package that gives an AI assistant deep expertise in a specific technology and version. Rather than one monolithic "IT expert" that knows a little about everything, this library provides narrowly focused specialists that know the exact quirks, features, and pitfalls of their specific domain.

A **SQL Server 2025 skill** knows about native vector types, DiskANN indexes, and optimized locking. A **React 19 skill** knows about Actions, the React Compiler, and `useActionState`. A **Windows Server 2025 skill** knows about DTrace, dMSA, NVMe/TCP, and GPU partitioning.

### Three-Layer Hierarchy

```
Domain                     (database, os, frontend, security, networking...)
  Technology               (sql-server, postgresql, react, angular, rhel, ubuntu...)
    Version                  (2022, 2025, v18, v19, 15 SP6...)
```

Each layer inherits from its parent:
- **Domain** provides foundational concepts (ACID theory, component models, kernel architectures)
- **Technology** provides implementation-specific expertise (T-SQL patterns, hooks system, systemd)
- **Version** provides release-specific features and migration guidance

### Skill Contents

Each technology skill includes:

| Component | Description |
|---|---|
| **SKILL.md** | Core expertise, routing logic, common pitfalls, version routing |
| **references/** | Deep knowledge (architecture, best practices, diagnostics) |
| **scripts/** or **configs/** | Diagnostic scripts (PowerShell/Bash) or configuration references |
| **patterns/** | Code recipes and implementation patterns (frontend) |

---

## Domains

### 1. Database — 29 Technologies

Expert knowledge for relational, NoSQL, analytical, and cloud-managed databases.

| Category | Skills | Versions |
|---|---|---|
| **Relational (RDBMS)** | | |
| SQL Server | [`database/sql-server`](agents/database/sql-server/SKILL.md) | 2016, 2017, 2019, 2022, 2025 |
| PostgreSQL | [`database/postgresql`](agents/database/postgresql/SKILL.md) | 14, 15, 16, 17, 18 |
| Oracle Database | [`database/oracle`](agents/database/oracle/SKILL.md) | 19c, 23ai, 26ai |
| MySQL | [`database/mysql`](agents/database/mysql/SKILL.md) | 8.0, 8.4, 9.x |
| MariaDB | [`database/mariadb`](agents/database/mariadb/SKILL.md) | 10.6, 10.11, 11.4, 11.8, 12.x |
| SQLite | [`database/sqlite`](agents/database/sqlite/SKILL.md) | 3.51.x |
| **Document** | | |
| MongoDB | [`database/mongodb`](agents/database/mongodb/SKILL.md) | 6.0, 7.0, 8.0 |
| Azure Cosmos DB | [`database/cosmosdb`](agents/database/cosmosdb/SKILL.md) | managed |
| Amazon DynamoDB | [`database/dynamodb`](agents/database/dynamodb/SKILL.md) | managed |
| Couchbase | [`database/couchbase`](agents/database/couchbase/SKILL.md) | 7.x |
| **Key-Value / Cache** | | |
| Redis | [`database/redis`](agents/database/redis/SKILL.md) | 7.2, 7.4, 7.8, 8.0 |
| Memcached | [`database/memcached`](agents/database/memcached/SKILL.md) | 1.6.x |
| Amazon ElastiCache | [`database/elasticache`](agents/database/elasticache/SKILL.md) | managed |
| **Search / Analytics** | | |
| Elasticsearch | [`database/elasticsearch`](agents/database/elasticsearch/SKILL.md) | 8.x, 9.x |
| OpenSearch | [`database/opensearch`](agents/database/opensearch/SKILL.md) | 2.x |
| **Wide-Column** | | |
| Apache Cassandra | [`database/cassandra`](agents/database/cassandra/SKILL.md) | 4.0, 4.1, 5.0 |
| ScyllaDB | [`database/scylladb`](agents/database/scylladb/SKILL.md) | 6.x |
| **Graph** | | |
| Neo4j | [`database/neo4j`](agents/database/neo4j/SKILL.md) | 5.x, 2026.x |
| Amazon Neptune | [`database/neptune`](agents/database/neptune/SKILL.md) | managed |
| **Time-Series** | | |
| InfluxDB | [`database/influxdb`](agents/database/influxdb/SKILL.md) | 2.x, 3.x |
| TimescaleDB | [`database/timescaledb`](agents/database/timescaledb/SKILL.md) | 2.25+ |
| **Columnar / Analytical** | | |
| ClickHouse | [`database/clickhouse`](agents/database/clickhouse/SKILL.md) | 25.x, 26.x LTS |
| DuckDB | [`database/duckdb`](agents/database/duckdb/SKILL.md) | 1.4, 1.5 |
| Apache Druid | [`database/druid`](agents/database/druid/SKILL.md) | 31.x |
| **Cloud Data Warehouses** | | |
| Snowflake | [`database/snowflake`](agents/database/snowflake/SKILL.md) | managed |
| Google BigQuery | [`database/bigquery`](agents/database/bigquery/SKILL.md) | managed |
| Amazon Redshift | [`database/redshift`](agents/database/redshift/SKILL.md) | managed |
| Azure Synapse | [`database/synapse`](agents/database/synapse/SKILL.md) | managed |
| Databricks | [`database/databricks`](agents/database/databricks/SKILL.md) | managed |

**Includes:** SQL diagnostic scripts per version, architecture references, query optimization guides, migration playbooks.

---

### 2. Operating System — 8 Technologies

Expert knowledge for Windows, Linux, and macOS administration.

| Technology | Skill Path | Versions | Feature Sub-Skills |
|---|---|---|---|
| Windows Server | [`os/windows-server`](agents/os/windows-server/SKILL.md) | 2016, 2019, 2022, 2025 | Failover Clustering (WSFC), Hyper-V |
| Windows Client | [`os/windows-client`](agents/os/windows-client/SKILL.md) | 10, 11 | WSL |
| RHEL | [`os/rhel`](agents/os/rhel/SKILL.md) | 8, 9, 10 | SELinux, Podman |
| Ubuntu | [`os/ubuntu`](agents/os/ubuntu/SKILL.md) | 20.04, 22.04, 24.04, 26.04 | AppArmor |
| Debian | [`os/debian`](agents/os/debian/SKILL.md) | 11, 12, 13 | — |
| Rocky / AlmaLinux | [`os/rocky-alma`](agents/os/rocky-alma/SKILL.md) | 8, 9, 10 | — |
| SLES | [`os/sles`](agents/os/sles/SKILL.md) | 15 SP5, 15 SP6 | Btrfs/Snapper, HA Extension |
| macOS | [`os/macos`](agents/os/macos/SKILL.md) | 14, 15, 26 | MDM, Platform SSO, Developer Toolchain |

**Includes:** PowerShell diagnostic scripts (Windows), Bash diagnostic scripts (Linux/macOS), edition/licensing matrices, CIS/STIG hardening guides, performance counter references.

---

### 3. Web UI / Frontend — 11 Technologies

Expert knowledge for frontend frameworks, meta-frameworks, and UI paradigms.

| Technology | Skill Path | Versions | Feature Sub-Skills |
|---|---|---|---|
| React | [`frontend/react`](agents/frontend/react/SKILL.md) | 18, 19 | Server Components |
| Next.js | [`frontend/nextjs`](agents/frontend/nextjs/SKILL.md) | 15, 16 | App Router |
| Angular | [`frontend/angular`](agents/frontend/angular/SKILL.md) | 19, 20, 21 | Signals |
| Vue.js | [`frontend/vue`](agents/frontend/vue/SKILL.md) | 3.5 | — |
| Nuxt | [`frontend/nuxt`](agents/frontend/nuxt/SKILL.md) | 3, 4 | — |
| Svelte / SvelteKit | [`frontend/svelte`](agents/frontend/svelte/SKILL.md) | 5 / 2.x | — |
| Blazor | [`frontend/blazor`](agents/frontend/blazor/SKILL.md) | .NET 8, 9, 10 | — |
| HTMX | [`frontend/htmx`](agents/frontend/htmx/SKILL.md) | 2.0 | — |
| Astro | [`frontend/astro`](agents/frontend/astro/SKILL.md) | 5.x | — |
| Remix / React Router v7 | [`frontend/remix`](agents/frontend/remix/SKILL.md) | 2.x / v7 | — |
| Gatsby | [`frontend/gatsby`](agents/frontend/gatsby/SKILL.md) | 5.x (maintenance) | — |

**Includes:** Annotated configuration references (tsconfig, vite.config, next.config, etc.), code pattern guides (data fetching, forms, state management, auth), version migration guides.

---

### 4. Security — 14 Technologies

Expert knowledge across identity, endpoint, network, application, and data security.

| Technology | Skill Path | Focus |
|---|---|---|
| IAM | [`security/iam`](agents/security/iam/SKILL.md) | Active Directory, Entra ID, Okta, SAML, OIDC, RBAC/ABAC |
| EDR | [`security/edr`](agents/security/edr/SKILL.md) | CrowdStrike, Defender for Endpoint, SentinelOne, Carbon Black |
| SIEM | [`security/siem`](agents/security/siem/SKILL.md) | Splunk, Sentinel, Elastic Security, QRadar |
| Vulnerability Management | [`security/vulnerability-management`](agents/security/vulnerability-management/SKILL.md) | Nessus, Qualys, Rapid7 |
| Secrets Management | [`security/secrets`](agents/security/secrets/SKILL.md) | HashiCorp Vault, Azure Key Vault, AWS Secrets Manager |
| Application Security | [`security/appsec`](agents/security/appsec/SKILL.md) | OWASP, SAST/DAST, dependency scanning, WAF |
| Cloud Security | [`security/cloud-security`](agents/security/cloud-security/SKILL.md) | CSPM, CWPP, cloud IAM, security benchmarks |
| Network Security | [`security/network-security`](agents/security/network-security/SKILL.md) | Firewall policy, IDS/IPS, segmentation, zero trust networking |
| Zero Trust | [`security/zero-trust`](agents/security/zero-trust/SKILL.md) | Architecture, implementation, identity-centric security |
| GRC | [`security/grc`](agents/security/grc/SKILL.md) | Compliance frameworks (SOC 2, ISO 27001, NIST, PCI DSS) |
| Threat Intelligence | [`security/threat-intel`](agents/security/threat-intel/SKILL.md) | MITRE ATT&CK, IOCs, threat hunting, intelligence platforms |
| Email Security | [`security/email-security`](agents/security/email-security/SKILL.md) | SPF, DKIM, DMARC, phishing defense, email gateways |
| DLP | [`security/dlp`](agents/security/dlp/SKILL.md) | Data classification, prevention policies, monitoring |
| Backup Security | [`security/backup-security`](agents/security/backup-security/SKILL.md) | Immutable backups, air-gapped recovery, ransomware resilience |

---

### 5. Networking — 12 Technologies

Expert knowledge for enterprise networking, from routing to SD-WAN.

| Technology | Skill Path | Focus |
|---|---|---|
| Routing & Switching | [`networking/routing-switching`](agents/networking/routing-switching/SKILL.md) | Cisco IOS-XE, NX-OS, Juniper Junos, Arista EOS |
| Firewall | [`networking/firewall`](agents/networking/firewall/SKILL.md) | Palo Alto PAN-OS, Fortinet FortiOS, Cisco FTD, pfSense, OPNsense |
| Load Balancing | [`networking/load-balancing`](agents/networking/load-balancing/SKILL.md) | F5 BIG-IP, NGINX, HAProxy, cloud ALB/NLB |
| DNS | [`networking/dns`](agents/networking/dns/SKILL.md) | BIND, PowerDNS, Windows DNS, cloud DNS services |
| SD-WAN | [`networking/sd-wan`](agents/networking/sd-wan/SKILL.md) | Cisco SD-WAN, Fortinet SD-WAN |
| Wireless | [`networking/wireless`](agents/networking/wireless/SKILL.md) | Cisco WLC, Aruba AOS |
| VPN | [`networking/vpn`](agents/networking/vpn/SKILL.md) | IPsec, SSL VPN, WireGuard |
| DC Fabric | [`networking/dc-fabric`](agents/networking/dc-fabric/SKILL.md) | Spine-leaf, VXLAN/EVPN, fabric automation |
| IPAM/DDI | [`networking/ipam-ddi`](agents/networking/ipam-ddi/SKILL.md) | Infoblox, IP address management |
| Network Automation | [`networking/network-automation`](agents/networking/network-automation/SKILL.md) | Ansible networking, NAPALM, Netmiko, RESTCONF/NETCONF |
| Network Monitoring | [`networking/network-monitoring`](agents/networking/network-monitoring/SKILL.md) | SNMP, NetFlow, sFlow, network observability |
| Cloud Networking | [`networking/cloud-networking`](agents/networking/cloud-networking/SKILL.md) | AWS VPC, Azure VNet, GCP VPC, transit gateway, peering |

---

### 6. Containers & Orchestration — 3 Technologies

| Technology | Skill Path | Focus |
|---|---|---|
| Container Runtimes | [`containers/runtimes`](agents/containers/runtimes/SKILL.md) | Docker, Podman, containerd |
| Orchestration | [`containers/orchestration`](agents/containers/orchestration/SKILL.md) | Kubernetes, Helm, EKS, AKS, GKE, OpenShift |
| Service Mesh | [`containers/service-mesh`](agents/containers/service-mesh/SKILL.md) | Istio, Linkerd, Consul Connect |

---

### 7. DevOps / CI-CD / IaC — 4 Technologies

| Technology | Skill Path | Focus |
|---|---|---|
| Infrastructure as Code | [`devops/iac`](agents/devops/iac/SKILL.md) | Terraform, OpenTofu, Pulumi, CloudFormation, Bicep, Ansible |
| CI/CD | [`devops/cicd`](agents/devops/cicd/SKILL.md) | GitHub Actions, GitLab CI, Azure DevOps, Jenkins, ArgoCD |
| GitOps | [`devops/gitops`](agents/devops/gitops/SKILL.md) | ArgoCD, Flux, GitOps patterns |
| Config Management | [`devops/config-mgmt`](agents/devops/config-mgmt/SKILL.md) | Chef, Puppet, SaltStack |

---

### 8. Backend Frameworks — 10 Technologies

Expert knowledge for REST API and web backend frameworks across all major languages.

| Technology | Skill Path | Versions |
|---|---|---|
| ASP.NET Core | [`backend/aspnet-core`](agents/backend/aspnet-core/SKILL.md) | .NET 8, 9, 10 + Minimal APIs |
| Spring Boot | [`backend/spring-boot`](agents/backend/spring-boot/SKILL.md) | 3.x, 4.0 |
| Django | [`backend/django`](agents/backend/django/SKILL.md) | 4.2 LTS, 5.2 LTS, 6.0 |
| Ruby on Rails | [`backend/rails`](agents/backend/rails/SKILL.md) | 7.2, 8.0, 8.1 |
| Express.js | [`backend/express`](agents/backend/express/SKILL.md) | 5.x |
| FastAPI | [`backend/fastapi`](agents/backend/fastapi/SKILL.md) | current |
| NestJS | [`backend/nestjs`](agents/backend/nestjs/SKILL.md) | 11.x |
| Flask | [`backend/flask`](agents/backend/flask/SKILL.md) | 3.1 |
| Go Web (net/http, Gin, Fiber) | [`backend/go-web`](agents/backend/go-web/SKILL.md) | Go 1.23/1.24 |
| Rust Web (Actix, Axum) | [`backend/rust-web`](agents/backend/rust-web/SKILL.md) | stable toolchain |

**Includes:** API design patterns, REST/HTTP semantics, authentication paradigms, async runtime models, framework comparison guides, version migration references.

---

### 9. Virtualization — 5 Technologies

| Technology | Skill Path | Versions |
|---|---|---|
| VMware vSphere / ESXi | [`virtualization/vmware`](agents/virtualization/vmware/SKILL.md) | 8.x, 9.0 |
| Proxmox VE | [`virtualization/proxmox`](agents/virtualization/proxmox/SKILL.md) | 8.4, 9.0, 9.1 |
| KVM/QEMU | [`virtualization/kvm`](agents/virtualization/kvm/SKILL.md) | kernel-tied |
| Citrix Hypervisor | [`virtualization/citrix`](agents/virtualization/citrix/SKILL.md) | 8.x |
| Nutanix AHV | [`virtualization/nutanix`](agents/virtualization/nutanix/SKILL.md) | AOS-tied |

---

### 10. CLI / Scripting — 7 Technologies

| Technology | Skill Path | Versions |
|---|---|---|
| PowerShell | [`cli-scripting/powershell`](agents/cli-scripting/powershell/SKILL.md) | 7.4 LTS, 7.6 LTS |
| Bash | [`cli-scripting/bash`](agents/cli-scripting/bash/SKILL.md) | 5.x |
| Python | [`cli-scripting/python`](agents/cli-scripting/python/SKILL.md) | 3.10–3.14 |
| Node.js | [`cli-scripting/nodejs`](agents/cli-scripting/nodejs/SKILL.md) | 20 LTS, 22 LTS, 24 |
| Azure CLI | [`cli-scripting/azure-cli`](agents/cli-scripting/azure-cli/SKILL.md) | rolling |
| AWS CLI | [`cli-scripting/aws-cli`](agents/cli-scripting/aws-cli/SKILL.md) | v2 |
| kubectl | [`cli-scripting/kubectl`](agents/cli-scripting/kubectl/SKILL.md) | 1.33–1.35 |

---

### 11. ETL / Data Integration — 14 Technologies

Expert knowledge for data pipeline orchestration, transformation, integration, and streaming.

| Sub-domain | Technology | Skill Path | Versions |
|---|---|---|---|
| **Orchestration** | | | |
| | Apache Airflow | [`etl/orchestration/airflow`](agents/etl/orchestration/airflow/SKILL.md) | 2.x (EOL), 3.x |
| | SSIS | [`etl/orchestration/ssis`](agents/etl/orchestration/ssis/SKILL.md) | 2019, 2022, 2025 |
| **Transformation** | | | |
| | Apache Spark | [`etl/transformation/spark`](agents/etl/transformation/spark/SKILL.md) | 3.5, 4.0, 4.2 |
| | dbt Core | [`etl/transformation/dbt-core`](agents/etl/transformation/dbt-core/SKILL.md) | 1.11 |
| | dbt Cloud | [`etl/transformation/dbt-cloud`](agents/etl/transformation/dbt-cloud/SKILL.md) | managed |
| **Integration** | | | |
| | Azure Data Factory | [`etl/integration/adf`](agents/etl/integration/adf/SKILL.md) | managed |
| | Apache NiFi | [`etl/integration/nifi`](agents/etl/integration/nifi/SKILL.md) | 2.8 |
| | Informatica IDMC | [`etl/integration/informatica`](agents/etl/integration/informatica/SKILL.md) | managed |
| | Talend | [`etl/integration/talend`](agents/etl/integration/talend/SKILL.md) | 8.0 |
| | Fivetran | [`etl/integration/fivetran`](agents/etl/integration/fivetran/SKILL.md) | managed |
| | AWS Glue | [`etl/integration/aws-glue`](agents/etl/integration/aws-glue/SKILL.md) | managed |
| | Synapse Pipelines | [`etl/integration/synapse-pipelines`](agents/etl/integration/synapse-pipelines/SKILL.md) | managed |
| **Streaming** | | | |
| | Apache Kafka | [`etl/streaming/kafka`](agents/etl/streaming/kafka/SKILL.md) | 3.9, 4.0, 4.1, 4.2 |

**Includes:** ETL/ELT patterns, CDC, SCD types, data quality, paradigm references (orchestration, transformation, integration, streaming).

---

### 12. Data Analytics / BI — 11 Technologies

Expert knowledge for business intelligence, reporting, and analytics platforms.

| Technology | Skill Path | Versions |
|---|---|---|
| Power BI | [`analytics/power-bi`](agents/analytics/power-bi/SKILL.md) | managed (monthly) |
| Tableau | [`analytics/tableau`](agents/analytics/tableau/SKILL.md) | 2025.x, 2026.1 |
| SSAS | [`analytics/ssas`](agents/analytics/ssas/SKILL.md) | 2019, 2022, 2025 |
| SSRS | [`analytics/ssrs`](agents/analytics/ssrs/SKILL.md) | 2019, 2022, 2025 |
| Looker | [`analytics/looker`](agents/analytics/looker/SKILL.md) | managed |
| Apache Superset | [`analytics/superset`](agents/analytics/superset/SKILL.md) | 6.x |
| Metabase | [`analytics/metabase`](agents/analytics/metabase/SKILL.md) | v59, v60 |
| Grafana | [`analytics/grafana`](agents/analytics/grafana/SKILL.md) | 12.x |
| Qlik Sense | [`analytics/qlik-sense`](agents/analytics/qlik-sense/SKILL.md) | managed |
| ThoughtSpot | [`analytics/thoughtspot`](agents/analytics/thoughtspot/SKILL.md) | managed |
| DuckDB | [`analytics/duckdb-analytics`](agents/analytics/duckdb-analytics/SKILL.md) | cross-ref |

**Includes:** Dimensional modeling, OLAP concepts, visualization theory, semantic layers, paradigm references (enterprise BI, SQL analytics, reporting, operational).

---

### 13. Storage — 12 Technologies

Expert knowledge for enterprise, software-defined, and cloud storage platforms.

| Category | Technology | Skill Path | Versions |
|---|---|---|---|
| **Enterprise SAN/NAS** | | | |
| | NetApp ONTAP | [`storage/netapp-ontap`](agents/storage/netapp-ontap/SKILL.md) | 9.14, 9.15, 9.16, 9.17, 9.18 |
| | Dell PowerStore | [`storage/dell-powerstore`](agents/storage/dell-powerstore/SKILL.md) | 4.0 |
| | Dell Unity | [`storage/dell-unity`](agents/storage/dell-unity/SKILL.md) | OE 5.5 |
| | Pure Storage FlashArray | [`storage/pure-storage`](agents/storage/pure-storage/SKILL.md) | current |
| | HPE Alletra | [`storage/hpe-alletra`](agents/storage/hpe-alletra/SKILL.md) | current |
| **Software-Defined** | | | |
| | Ceph | [`storage/ceph`](agents/storage/ceph/SKILL.md) | 19.2 Squid, 20.2 Tentacle |
| | MinIO | [`storage/minio`](agents/storage/minio/SKILL.md) | current |
| | GlusterFS | [`storage/glusterfs`](agents/storage/glusterfs/SKILL.md) | 11.x |
| **Cloud Object** | | | |
| | AWS S3 | [`storage/aws-s3`](agents/storage/aws-s3/SKILL.md) | managed |
| | Azure Blob Storage | [`storage/azure-blob`](agents/storage/azure-blob/SKILL.md) | managed |
| | Google Cloud Storage | [`storage/gcs`](agents/storage/gcs/SKILL.md) | managed |
| **Windows** | | | |
| | Storage Spaces Direct | [`storage/storage-spaces-direct`](agents/storage/storage-spaces-direct/SKILL.md) | WS 2019/2022/2025 |

**Includes:** Block/file/object fundamentals, RAID/erasure coding, replication patterns, data reduction, storage networking, paradigm references (enterprise, SDS, cloud).

---

### 14. Monitoring / Observability — 11 Technologies

Expert knowledge for metrics, logs, traces, alerting, and full-stack observability platforms.

| Technology | Skill Path | Focus |
|---|---|---|
| Prometheus | [`monitoring/prometheus`](agents/monitoring/prometheus/SKILL.md) | Pull-based metrics, PromQL, 3.x LTS |
| Grafana | [`monitoring/grafana`](agents/monitoring/grafana/SKILL.md) | Dashboards, Loki, Tempo, alerting, 12.x |
| ELK (Elasticsearch + Kibana) | [`monitoring/elk`](agents/monitoring/elk/SKILL.md) | Log management, APM, 8.x/9.x |
| OpenTelemetry | [`monitoring/opentelemetry`](agents/monitoring/opentelemetry/SKILL.md) | Vendor-neutral instrumentation, Collector 0.149+ |
| Datadog | [`monitoring/datadog`](agents/monitoring/datadog/SKILL.md) | Managed full-stack observability |
| New Relic | [`monitoring/newrelic`](agents/monitoring/newrelic/SKILL.md) | Managed APM and observability |
| Splunk | [`monitoring/splunk`](agents/monitoring/splunk/SKILL.md) | Enterprise log analytics, 9.x |
| Zabbix | [`monitoring/zabbix`](agents/monitoring/zabbix/SKILL.md) | Infrastructure monitoring, 7.4 |
| Nagios | [`monitoring/nagios`](agents/monitoring/nagios/SKILL.md) | Legacy infrastructure monitoring, XI/Core |
| PagerDuty | [`monitoring/pagerduty`](agents/monitoring/pagerduty/SKILL.md) | Incident management, on-call automation |
| Dynatrace | [`monitoring/dynatrace`](agents/monitoring/dynatrace/SKILL.md) | AI-powered full-stack observability |

**Includes:** Three pillars of observability (metrics, logs, traces), monitoring strategy (USE/RED/4 Golden Signals), SLI/SLO/SLA design, alerting philosophy, cardinality management, cost control, tool selection frameworks.

---

### 15. Cloud Platforms — 3 Technologies

Expert knowledge for comprehensive cloud architecture across all three major providers.

| Technology | Skill Path | Focus |
|---|---|---|
| AWS | [`cloud-platforms/aws`](agents/cloud-platforms/aws/SKILL.md) | Compute, storage, database, networking, security, serverless |
| Azure | [`cloud-platforms/azure`](agents/cloud-platforms/azure/SKILL.md) | Compute, identity, hybrid, data platform, networking, security |
| GCP | [`cloud-platforms/gcp`](agents/cloud-platforms/gcp/SKILL.md) | Compute, data/analytics, AI/ML, Kubernetes, networking, security |

**Includes:** Cloud selection frameworks, cross-cloud service mapping, Well-Architected design principles, migration strategy (7 Rs), FinOps cost management, vendor-neutral strategic guidance.

---

## Planned Domains (from PLAN.md)

The following domains are inventoried in PLAN.md but not yet built:

| # | Domain | Technologies |
|---|---|---|
| 10 | WebSockets / Real-Time | SignalR, Socket.IO, gRPC, GraphQL, SSE |
| 17 | Messaging / Event Streaming | Kafka, RabbitMQ, NATS, Service Bus, Pulsar |
| 19 | Data APIs / Data Access | GraphQL, OData, gRPC, SignalR |
| 20 | Mail / Collaboration | Exchange, M365, Google Workspace |

---

## How to Use

### With Claude Code

Skills in this library are designed as Claude Code skills. Each `SKILL.md` file can be loaded as a skill to give Claude deep expertise in that domain.

### Skill Structure

Every technology follows the same pattern:

```
technology/
├── SKILL.md              # Core expertise and routing logic
├── references/
│   ├── architecture.md   # How the technology works internally
│   ├── best-practices.md # Operational best practices
│   └── diagnostics.md    # Troubleshooting guides
├── scripts/              # Diagnostic scripts (OS domain — PowerShell/Bash)
│   └── 01-health.ps1
├── configs/              # Configuration references (Frontend domain)
│   └── tsconfig.json
├── patterns/             # Code patterns (Frontend domain)
│   └── data-fetching.md
└── version/              # Version-specific knowledge
    └── SKILL.md
```

### Cross-References

Technologies that span multiple domains use cross-references instead of duplication:
- **Hyper-V** lives in `os/windows-server/hyper-v/` and is cross-referenced from virtualization
- **Podman** lives in `os/rhel/podman/` and is cross-referenced from containers
- **SELinux** lives in `os/rhel/selinux/` and is cross-referenced from security
- **Redis** covers database use cases in `database/redis/` and messaging patterns are cross-referenced

---

## Repository Statistics

| Domain | Technologies | Files | Lines |
|---|---|---|---|
| Database | 29 | 238 | 119,694 |
| Security | 14 | 227 | 77,043 |
| Operating System | 8 | 261 | 49,452 |
| Networking | 12 | 192 | 42,609 |
| Backend | 10 | 54 | 26,770 |
| Frontend | 11 | 116 | 25,844 |
| DevOps | 16 | 77 | 13,639 |
| Containers | 3 | 45 | 13,539 |
| CLI / Scripting | 7 | 57 | 12,153 |
| Monitoring | 11 | 50 | 9,882 |
| ETL / Data Integration | 14 | 75 | 17,596 |
| Virtualization | 5 | 41 | 8,997 |
| Storage | 12 | 60 | 6,497 |
| Data Analytics / BI | 11 | 55 | 14,271 |
| Cloud Platforms | 3 | 30 | 5,797 |
| **Total** | **166** | **1,578** | **443,783** |

---

## Version Currency

All skills reflect technology versions current as of **April 2026**. Each skill notes:
- Support status (Active, LTS, Maintenance, EOL)
- End-of-life dates where applicable
- Migration guidance for nearing-EOL versions

---

## License

MIT
