# IT Domain Knowledge Skills Library

A comprehensive library of **domain expert knowledge skills** organized by IT domain, technology, and version. Each skill provides deep, version-specific expertise that transforms a general-purpose AI assistant into a genuine specialist.

**1,246+ files | 120+ technologies | 13 domains | 364,000+ lines of expert knowledge**

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
| SQL Server | `database/sql-server` | 2016, 2017, 2019, 2022, 2025 |
| PostgreSQL | `database/postgresql` | 14, 15, 16, 17, 18 |
| Oracle Database | `database/oracle` | 19c, 23ai, 26ai |
| MySQL | `database/mysql` | 8.0, 8.4, 9.x |
| MariaDB | `database/mariadb` | 10.6, 10.11, 11.4, 11.8, 12.x |
| SQLite | `database/sqlite` | 3.51.x |
| **Document** | | |
| MongoDB | `database/mongodb` | 6.0, 7.0, 8.0 |
| Azure Cosmos DB | `database/cosmosdb` | managed |
| Amazon DynamoDB | `database/dynamodb` | managed |
| Couchbase | `database/couchbase` | 7.x |
| **Key-Value / Cache** | | |
| Redis | `database/redis` | 7.2, 7.4, 7.8, 8.0 |
| Memcached | `database/memcached` | 1.6.x |
| Amazon ElastiCache | `database/elasticache` | managed |
| **Search / Analytics** | | |
| Elasticsearch | `database/elasticsearch` | 8.x, 9.x |
| OpenSearch | `database/opensearch` | 2.x |
| **Wide-Column** | | |
| Apache Cassandra | `database/cassandra` | 4.0, 4.1, 5.0 |
| ScyllaDB | `database/scylladb` | 6.x |
| **Graph** | | |
| Neo4j | `database/neo4j` | 5.x, 2026.x |
| Amazon Neptune | `database/neptune` | managed |
| **Time-Series** | | |
| InfluxDB | `database/influxdb` | 2.x, 3.x |
| TimescaleDB | `database/timescaledb` | 2.25+ |
| **Columnar / Analytical** | | |
| ClickHouse | `database/clickhouse` | 25.x, 26.x LTS |
| DuckDB | `database/duckdb` | 1.4, 1.5 |
| Apache Druid | `database/druid` | 31.x |
| **Cloud Data Warehouses** | | |
| Snowflake | `database/snowflake` | managed |
| Google BigQuery | `database/bigquery` | managed |
| Amazon Redshift | `database/redshift` | managed |
| Azure Synapse | `database/synapse` | managed |
| Databricks | `database/databricks` | managed |

**Includes:** SQL diagnostic scripts per version, architecture references, query optimization guides, migration playbooks.

---

### 2. Operating System — 8 Technologies

Expert knowledge for Windows, Linux, and macOS administration.

| Technology | Skill Path | Versions | Feature Sub-Skills |
|---|---|---|---|
| Windows Server | `os/windows-server` | 2016, 2019, 2022, 2025 | Failover Clustering (WSFC), Hyper-V |
| Windows Client | `os/windows-client` | 10, 11 | WSL |
| RHEL | `os/rhel` | 8, 9, 10 | SELinux, Podman |
| Ubuntu | `os/ubuntu` | 20.04, 22.04, 24.04, 26.04 | AppArmor |
| Debian | `os/debian` | 11, 12, 13 | — |
| Rocky / AlmaLinux | `os/rocky-alma` | 8, 9, 10 | — |
| SLES | `os/sles` | 15 SP5, 15 SP6 | Btrfs/Snapper, HA Extension |
| macOS | `os/macos` | 14, 15, 26 | MDM, Platform SSO, Developer Toolchain |

**Includes:** PowerShell diagnostic scripts (Windows), Bash diagnostic scripts (Linux/macOS), edition/licensing matrices, CIS/STIG hardening guides, performance counter references.

---

### 3. Web UI / Frontend — 11 Technologies

Expert knowledge for frontend frameworks, meta-frameworks, and UI paradigms.

| Technology | Skill Path | Versions | Feature Sub-Skills |
|---|---|---|---|
| React | `frontend/react` | 18, 19 | Server Components |
| Next.js | `frontend/nextjs` | 15, 16 | App Router |
| Angular | `frontend/angular` | 19, 20, 21 | Signals |
| Vue.js | `frontend/vue` | 3.5 | — |
| Nuxt | `frontend/nuxt` | 3, 4 | — |
| Svelte / SvelteKit | `frontend/svelte` | 5 / 2.x | — |
| Blazor | `frontend/blazor` | .NET 8, 9, 10 | — |
| HTMX | `frontend/htmx` | 2.0 | — |
| Astro | `frontend/astro` | 5.x | — |
| Remix / React Router v7 | `frontend/remix` | 2.x / v7 | — |
| Gatsby | `frontend/gatsby` | 5.x (maintenance) | — |

**Includes:** Annotated configuration references (tsconfig, vite.config, next.config, etc.), code pattern guides (data fetching, forms, state management, auth), version migration guides.

---

### 4. Security — 14 Technologies

Expert knowledge across identity, endpoint, network, application, and data security.

| Technology | Skill Path | Focus |
|---|---|---|
| IAM | `security/iam` | Active Directory, Entra ID, Okta, SAML, OIDC, RBAC/ABAC |
| EDR | `security/edr` | CrowdStrike, Defender for Endpoint, SentinelOne, Carbon Black |
| SIEM | `security/siem` | Splunk, Sentinel, Elastic Security, QRadar |
| Vulnerability Management | `security/vulnerability-management` | Nessus, Qualys, Rapid7 |
| Secrets Management | `security/secrets` | HashiCorp Vault, Azure Key Vault, AWS Secrets Manager |
| Application Security | `security/appsec` | OWASP, SAST/DAST, dependency scanning, WAF |
| Cloud Security | `security/cloud-security` | CSPM, CWPP, cloud IAM, security benchmarks |
| Network Security | `security/network-security` | Firewall policy, IDS/IPS, segmentation, zero trust networking |
| Zero Trust | `security/zero-trust` | Architecture, implementation, identity-centric security |
| GRC | `security/grc` | Compliance frameworks (SOC 2, ISO 27001, NIST, PCI DSS) |
| Threat Intelligence | `security/threat-intel` | MITRE ATT&CK, IOCs, threat hunting, intelligence platforms |
| Email Security | `security/email-security` | SPF, DKIM, DMARC, phishing defense, email gateways |
| DLP | `security/dlp` | Data classification, prevention policies, monitoring |
| Backup Security | `security/backup-security` | Immutable backups, air-gapped recovery, ransomware resilience |

---

### 5. Networking — 12 Technologies

Expert knowledge for enterprise networking, from routing to SD-WAN.

| Technology | Skill Path | Focus |
|---|---|---|
| Routing & Switching | `networking/routing-switching` | Cisco IOS-XE, NX-OS, Juniper Junos, Arista EOS |
| Firewall | `networking/firewall` | Palo Alto PAN-OS, Fortinet FortiOS, Cisco FTD, pfSense, OPNsense |
| Load Balancing | `networking/load-balancing` | F5 BIG-IP, NGINX, HAProxy, cloud ALB/NLB |
| DNS | `networking/dns` | BIND, PowerDNS, Windows DNS, cloud DNS services |
| SD-WAN | `networking/sd-wan` | Cisco SD-WAN, Fortinet SD-WAN |
| Wireless | `networking/wireless` | Cisco WLC, Aruba AOS |
| VPN | `networking/vpn` | IPsec, SSL VPN, WireGuard |
| DC Fabric | `networking/dc-fabric` | Spine-leaf, VXLAN/EVPN, fabric automation |
| IPAM/DDI | `networking/ipam-ddi` | Infoblox, IP address management |
| Network Automation | `networking/network-automation` | Ansible networking, NAPALM, Netmiko, RESTCONF/NETCONF |
| Network Monitoring | `networking/network-monitoring` | SNMP, NetFlow, sFlow, network observability |
| Cloud Networking | `networking/cloud-networking` | AWS VPC, Azure VNet, GCP VPC, transit gateway, peering |

---

### 6. Containers & Orchestration — 3 Technologies

| Technology | Skill Path | Focus |
|---|---|---|
| Container Runtimes | `containers/runtimes` | Docker, Podman, containerd |
| Orchestration | `containers/orchestration` | Kubernetes, Helm, EKS, AKS, GKE, OpenShift |
| Service Mesh | `containers/service-mesh` | Istio, Linkerd, Consul Connect |

---

### 7. DevOps / CI-CD / IaC — 4 Technologies

| Technology | Skill Path | Focus |
|---|---|---|
| Infrastructure as Code | `devops/iac` | Terraform, OpenTofu, Pulumi, CloudFormation, Bicep, Ansible |
| CI/CD | `devops/cicd` | GitHub Actions, GitLab CI, Azure DevOps, Jenkins, ArgoCD |
| GitOps | `devops/gitops` | ArgoCD, Flux, GitOps patterns |
| Config Management | `devops/config-mgmt` | Chef, Puppet, SaltStack |

---

### 8. Backend Frameworks — 10 Technologies

Expert knowledge for REST API and web backend frameworks across all major languages.

| Technology | Skill Path | Versions |
|---|---|---|
| ASP.NET Core | `backend/aspnet-core` | .NET 8, 9, 10 + Minimal APIs |
| Spring Boot | `backend/spring-boot` | 3.x, 4.0 |
| Django | `backend/django` | 4.2 LTS, 5.2 LTS, 6.0 |
| Ruby on Rails | `backend/rails` | 7.2, 8.0, 8.1 |
| Express.js | `backend/express` | 5.x |
| FastAPI | `backend/fastapi` | current |
| NestJS | `backend/nestjs` | 11.x |
| Flask | `backend/flask` | 3.1 |
| Go Web (net/http, Gin, Fiber) | `backend/go-web` | Go 1.23/1.24 |
| Rust Web (Actix, Axum) | `backend/rust-web` | stable toolchain |

**Includes:** API design patterns, REST/HTTP semantics, authentication paradigms, async runtime models, framework comparison guides, version migration references.

---

### 9. Virtualization — 5 Technologies

| Technology | Skill Path | Versions |
|---|---|---|
| VMware vSphere / ESXi | `virtualization/vmware` | 8.x, 9.0 |
| Proxmox VE | `virtualization/proxmox` | 8.4, 9.0, 9.1 |
| KVM/QEMU | `virtualization/kvm` | kernel-tied |
| Citrix Hypervisor | `virtualization/citrix` | 8.x |
| Nutanix AHV | `virtualization/nutanix` | AOS-tied |

---

### 10. CLI / Scripting — 7 Technologies

| Technology | Skill Path | Versions |
|---|---|---|
| PowerShell | `cli-scripting/powershell` | 7.4 LTS, 7.6 LTS |
| Bash | `cli-scripting/bash` | 5.x |
| Python | `cli-scripting/python` | 3.10–3.14 |
| Node.js | `cli-scripting/nodejs` | 20 LTS, 22 LTS, 24 |
| Azure CLI | `cli-scripting/azure-cli` | rolling |
| AWS CLI | `cli-scripting/aws-cli` | v2 |
| kubectl | `cli-scripting/kubectl` | 1.33–1.35 |

---

### 11. ETL / Data Integration — 14 Technologies

Expert knowledge for data pipeline orchestration, transformation, integration, and streaming.

| Sub-domain | Technology | Skill Path | Versions |
|---|---|---|---|
| **Orchestration** | | | |
| | Apache Airflow | `etl/orchestration/airflow` | 2.x (EOL), 3.x |
| | SSIS | `etl/orchestration/ssis` | 2019, 2022, 2025 |
| **Transformation** | | | |
| | Apache Spark | `etl/transformation/spark` | 3.5, 4.0, 4.2 |
| | dbt Core | `etl/transformation/dbt-core` | 1.11 (pending) |
| | dbt Cloud | `etl/transformation/dbt-cloud` | managed (pending) |
| **Integration** | | | |
| | Azure Data Factory | `etl/integration/adf` | managed |
| | Apache NiFi | `etl/integration/nifi` | 2.8 (pending) |
| | Informatica IDMC | `etl/integration/informatica` | managed (pending) |
| | Talend | `etl/integration/talend` | 8.0 (pending) |
| | Fivetran | `etl/integration/fivetran` | managed (pending) |
| | AWS Glue | `etl/integration/aws-glue` | managed (pending) |
| | Synapse Pipelines | `etl/integration/synapse-pipelines` | managed (pending) |
| **Streaming** | | | |
| | Apache Kafka | `etl/streaming/kafka` | 3.9, 4.0, 4.1, 4.2 |

**Includes:** ETL/ELT patterns, CDC, SCD types, data quality, paradigm references (orchestration, transformation, integration, streaming). Research complete for all pending technologies.

---

### 12. Data Analytics / BI — 11 Technologies

Expert knowledge for business intelligence, reporting, and analytics platforms.

| Technology | Skill Path | Versions |
|---|---|---|
| Power BI | `analytics/power-bi` | managed (monthly) |
| Tableau | `analytics/tableau` | 2025.x, 2026.1 |
| SSAS | `analytics/ssas` | 2019, 2022, 2025 |
| SSRS | `analytics/ssrs` | 2019, 2022, 2025 |
| Looker | `analytics/looker` | managed (pending) |
| Apache Superset | `analytics/superset` | 6.x (pending) |
| Metabase | `analytics/metabase` | v59, v60 (pending) |
| Grafana | `analytics/grafana` | 12.x (pending) |
| Qlik Sense | `analytics/qlik-sense` | managed (pending) |
| ThoughtSpot | `analytics/thoughtspot` | managed (pending) |
| DuckDB | `analytics/duckdb-analytics` | cross-ref (pending) |

**Includes:** Dimensional modeling, OLAP concepts, visualization theory, semantic layers, paradigm references (enterprise BI, SQL analytics, reporting, operational). Research complete for all pending technologies.

---

### 13. Storage — 12 Technologies

Expert knowledge for enterprise, software-defined, and cloud storage platforms.

| Category | Technology | Skill Path | Versions |
|---|---|---|---|
| **Enterprise SAN/NAS** | | | |
| | NetApp ONTAP | `storage/netapp-ontap` | 9.14, 9.15, 9.16, 9.17, 9.18 |
| | Dell PowerStore | `storage/dell-powerstore` | 4.0 |
| | Dell Unity | `storage/dell-unity` | OE 5.5 |
| | Pure Storage FlashArray | `storage/pure-storage` | current |
| | HPE Alletra | `storage/hpe-alletra` | current |
| **Software-Defined** | | | |
| | Ceph | `storage/ceph` | 19.2 Squid, 20.2 Tentacle |
| | MinIO | `storage/minio` | current |
| | GlusterFS | `storage/glusterfs` | 11.x |
| **Cloud Object** | | | |
| | AWS S3 | `storage/aws-s3` | managed |
| | Azure Blob Storage | `storage/azure-blob` | managed |
| | Google Cloud Storage | `storage/gcs` | managed |
| **Windows** | | | |
| | Storage Spaces Direct | `storage/storage-spaces-direct` | WS 2019/2022/2025 |

**Includes:** Block/file/object fundamentals, RAID/erasure coding, replication patterns, data reduction, storage networking, paradigm references (enterprise, SDS, cloud).

---

## Planned Domains (from PLAN.md)

The following domains are inventoried in PLAN.md but not yet built:

| # | Domain | Technologies |
|---|---|---|
| 10 | WebSockets / Real-Time | SignalR, Socket.IO, gRPC, GraphQL, SSE |
| 14 | Monitoring / Observability | Prometheus, Grafana, ELK, OpenTelemetry, Datadog |
| 17 | Messaging / Event Streaming | Kafka, RabbitMQ, NATS, Service Bus, Pulsar |
| 18 | Cloud Platforms | AWS, Azure, GCP (comprehensive) |
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
| Database | 29 | 172 | 101,594 |
| Security | 14 | 227 | 77,043 |
| Networking | 12 | 192 | 42,609 |
| Operating System | 8 | 104 | 27,746 |
| Backend | 10 | 54 | 26,770 |
| Frontend | 11 | 98 | 24,315 |
| DevOps | 16 | 77 | 13,639 |
| Containers | 3 | 45 | 13,539 |
| ETL / Data Integration | 14 | 42 | 9,011 |
| CLI / Scripting | 7 | 36 | 8,579 |
| Virtualization | 5 | 29 | 7,041 |
| Storage | 12 | 60 | 6,497 |
| Data Analytics / BI | 11 | 30 | 6,181 |
| **Total** | **152** | **1,166** | **364,564** |

---

## Version Currency

All skills reflect technology versions current as of **April 2026**. Each skill notes:
- Support status (Active, LTS, Maintenance, EOL)
- End-of-life dates where applicable
- Migration guidance for nearing-EOL versions

---

## License

MIT
