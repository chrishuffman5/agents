# Agent Library — Domain / Technology / Version Inventory

Complete inventory of IT domains, technologies, and currently supported versions (as of April 2026). Use this to plan the agent hierarchy.

---

## 1. Database

### Relational (RDBMS)

- **SQL Server**
  - 2016 (Extended Support — ends Jul 2026)
  - 2017 (Extended Support)
  - 2019 (Mainstream → Extended)
  - 2022 (Mainstream — ends Jan 2028)
  - 2025 (Current)

- **PostgreSQL**
  - 14 (supported — EOL Nov 2026)
  - 15 (supported)
  - 16 (supported)
  - 17 (supported)
  - 18 (current)

- **Oracle Database**
  - 19c (Premier Support ends Apr 2026, Extended until Apr 2027)
  - 23ai (LTS — 5yr Premier + 3yr Extended)
  - 26ai (Innovation release — Jan 2026)

- **MySQL**
  - 8.4 LTS (5-year support)
  - 9.x Innovation (short-term)
  - 8.0 (EOL Jul 2026)

- **MariaDB**
  - 10.6 (maintenance)
  - 10.11 (maintenance)
  - 11.4 (maintenance)
  - 11.8 LTS (3-year support)
  - 12.x (rolling GA releases)

### Document

- **MongoDB**
  - 6.0 (supported — 30-month lifecycle)
  - 7.0 (supported)
  - 8.0 (current)

- **Azure Cosmos DB** — managed (multi-model: document, graph, key-value, column-family)

- **Amazon DynamoDB** — managed (key-value + document)

- **Couchbase**
  - 7.x (current)

### Key-Value / Cache

- **Redis**
  - 7.2 (EOL Feb 2026)
  - 7.4 (EOL Nov 2026)
  - 7.8 (EOL May 2027)
  - 8.0 (current)

- **Memcached** — stable (1.6.x)

- **Amazon ElastiCache / MemoryDB** — managed

### Search / Analytics Engine

- **Elasticsearch**
  - 8.x (supported — 30-month window)
  - 9.x (current)

- **OpenSearch**
  - 2.x (current — 12+ month extended support per minor)

### Wide-Column

- **Apache Cassandra**
  - 4.0, 4.1 (supported)
  - 5.0 (current)

- **ScyllaDB**
  - 6.x (current)

### Graph

- **Neo4j**
  - 5.x LTS (supported until Nov 2028)
  - 2026.x (current — CalVer format)

- **Amazon Neptune** — managed

### Time-Series

- **InfluxDB**
  - 2.x (supported)
  - 3.x (current)

- **TimescaleDB**
  - 2.25+ (current — requires PostgreSQL 16+)

### Columnar / Analytical

- **ClickHouse**
  - 25.x, 26.x LTS (current)

- **DuckDB**
  - 1.4 LTS (until Sep 2026)
  - 1.5 (current)

- **Apache Druid**
  - 31.x (current)

### Cloud-Managed Data Warehouses

- **Snowflake** — managed (weekly releases, v10.x)
- **Google BigQuery** — managed
- **Amazon Redshift** — managed
- **Azure Synapse Analytics** — managed
- **Databricks** — managed (lakehouse)

### Embedded

- **SQLite** — 3.51.x (current)

---

## 2. Operating System

### Windows Server

- 2016 (Extended Support — ends Jan 2027)
- 2019 (Extended Support)
- 2022 (Mainstream — ends Oct 2026, Extended until Oct 2031)
- 2025 (Current — General Support ends Oct 2029)

### Windows Client

- Windows 10 (ESU ends Oct 2026)
- Windows 11 23H2, 24H2 (supported)

### Linux — Enterprise

- **Red Hat Enterprise Linux (RHEL)**
  - 8 (supported — 10yr lifecycle)
  - 9 (supported)
  - 10 (current)

- **Ubuntu Server LTS**
  - 20.04 (ESM until Apr 2030)
  - 22.04 (supported until Apr 2027)
  - 24.04 (supported until Apr 2029)
  - 26.04 (current — released Apr 2026)

- **Debian**
  - 11 Bullseye (LTS — EOL Jun 2026)
  - 12 Bookworm (supported — EOL Jun 2026 for old-stable)
  - 13 Trixie (current stable)

- **Rocky Linux / AlmaLinux**
  - 8 (security support until May 2029)
  - 9 (active support until May 2027)
  - 10 (current — active until May 2030)

- **SUSE Linux Enterprise Server (SLES)**
  - 15 SP5, SP6 (supported)

### macOS

- macOS 14 Sonoma (security updates)
- macOS 15 Sequoia (security updates)
- macOS 16 Tahoe (current)

---

## 3. Active Directory / Identity / Security

### Identity & Access Management

- **Windows Active Directory (AD DS)** — tied to Windows Server versions (2016, 2019, 2022, 2025)
- **Active Directory Federation Services (ADFS)** — tied to Windows Server versions
- **Active Directory Certificate Services (AD CS)** — tied to Windows Server versions
- **Microsoft Entra ID (Azure AD)** — managed (continuous updates)
- **Okta** — managed
- **Auth0** — managed
- **Keycloak** — 26.x (current, 2-3yr support cycles)
- **Ping Identity** — managed

### Endpoint Security / EDR

- **CrowdStrike Falcon** — managed
- **Microsoft Defender for Endpoint** — managed
- **SentinelOne** — managed
- **Carbon Black** — managed

### SIEM / Security Analytics

- **Splunk Enterprise** — 9.x (supported)
- **Microsoft Sentinel** — managed
- **Elastic Security** — tied to Elasticsearch versions (8.x, 9.x)
- **IBM QRadar** — 7.5.x (current)

### Vulnerability Management

- **Tenable Nessus** — managed/current
- **Qualys** — managed
- **Rapid7 InsightVM** — managed

### Secrets / Certificates

- **HashiCorp Vault** — 1.x (current)
- **Azure Key Vault** — managed
- **AWS Secrets Manager / KMS** — managed
- **CyberArk** — managed

---

## 4. Networking

### Routing / Switching

- **Cisco IOS-XE** — 17.x (17.18 LTS current), 26.x (newer major)
- **Cisco NX-OS** — 10.5, 10.6 (current)
- **Juniper Junos** — 25.x (current; even = 3yr support, odd = 2yr)
- **Arista EOS** — 4.35.x (current; 36-month support per train)

### Firewall / Next-Gen

- **Palo Alto PAN-OS** — 10.2, 11.1, 11.2 (check model compatibility)
- **Fortinet FortiOS** — 7.2, 7.4, 7.6 (current recommended)
- **Cisco Firepower / FTD** — 7.x (current)
- **pfSense** — current (Plus edition)
- **OPNsense** — 26.1 (current)

### Load Balancing / ADC

- **F5 BIG-IP** — 17.5 (current recommended), 17.1 (minimum)
- **NGINX** — 1.27.x (current), Plus R33+
- **HAProxy** — 3.1, 3.0 LTS (current)
- **AWS ALB/NLB** — managed
- **Azure Application Gateway** — managed

### SD-WAN

- **Cisco SD-WAN (Viptela)** — tied to IOS-XE versions
- **Fortinet SD-WAN** — tied to FortiOS versions
- **VMware VeloCloud** — managed

### Wireless

- **Cisco Wireless (WLC)** — 17.x (tied to IOS-XE)
- **Aruba** — AOS 10.x (current)

---

## 5. DNS

- **Windows DNS Server** — tied to Windows Server versions (2016, 2019, 2022, 2025)
- **BIND** — 9.18 (production), 9.20 (current production)
- **PowerDNS Authoritative** — 4.9, 5.0 (current)
- **PowerDNS Recursor** — 5.4 (current)
- **Azure DNS** — managed
- **AWS Route 53** — managed
- **Cloudflare DNS** — managed
- **Infoblox** — NIOS 9.x (current)

---

## 6. Virtualization / Virtual Servers

- **VMware vSphere / ESXi** — 8.x (supported), 9.0 (current)
- **Microsoft Hyper-V** — tied to Windows Server (2019, 2022, 2025)
- **Proxmox VE** — 8.4 (EOL Aug 2026), 9.0, 9.1 (current)
- **KVM/QEMU** — tied to Linux kernel/distro (no standalone version)
- **Citrix Hypervisor / XenServer** — 8.x (current)
- **Amazon EC2** — managed
- **Azure Virtual Machines** — managed
- **Google Compute Engine** — managed
- **Nutanix AHV** — tied to Nutanix AOS version

---

## 7. Containers & Orchestration

### Container Runtimes

- **Docker Engine** — 25+, 29.x (current)
- **Podman** — 5.8 (current), 6.0 (planned May 2026)
- **containerd** — 1.7 (extended until Sep 2026), 2.1, 2.2 (current)

### Orchestration

- **Kubernetes** — 1.33 (EOL Jun 2026), 1.34 (EOL Oct 2026), 1.35 (current), 1.36 (arriving Apr 2026)
- **Helm** — 4.1 (current)
- **Amazon ECS** — managed
- **Amazon EKS** — K8s 1.30–1.35 (supported)
- **Azure AKS** — K8s 1.32–1.35 (supported), 24-month LTS available
- **Google GKE** — K8s (rapid/regular/stable channels), 24-month total support
- **Red Hat OpenShift** — 4.x (tied to K8s versions)
- **Rancher** — 2.x (current)

### Service Mesh

- **Istio** — 1.24, 1.25 (current)
- **Linkerd** — 2.x (current)
- **Consul Connect** — tied to Consul version

---

## 8. Web UI / Frontend

- **React** — 18 (LTS), 19 (current)
- **Angular** — 19 (LTS, EOL May 2026), 20 (LTS, EOL Nov 2026), 21 (current)
- **Vue.js** — 3.5+ (current)
- **Next.js** — 15 (maintenance LTS), 16 LTS (current)
- **Nuxt** — 4.x (current), 3.x (EOL Jul 2026)
- **Svelte / SvelteKit** — 2.x (current)
- **Blazor** — tied to .NET (8 LTS, 9 STS, 10 LTS)
- **HTMX** — 2.0 (current)
- **Astro** — 5.x (current)
- **Remix** — 2.x (current)
- **Gatsby** — 5.x (maintenance mode)

---

## 9. REST API / Backend Frameworks

- **ASP.NET Core (Web API)** — .NET 8 LTS (until Nov 2026), .NET 9 STS (until May 2027), .NET 10 LTS (current)
- **Express.js** — 5.2 (current, requires Node 18+)
- **FastAPI** — 0.135+ (current, requires Python 3.10+)
- **Spring Boot** — 3.x (support until Jun 2026), 4.0 (current)
- **Django** — 4.2 LTS (EOL Apr 2026), 5.2 LTS (3yr support), 6.0 (current)
- **Flask** — 3.1 (current)
- **NestJS** — 11.x (current)
- **Ruby on Rails** — 7.2 (until Aug 2026), 8.0 (until May 2026 bug-fix), 8.1 (current)
- **Go (net/http, Gin, Fiber)** — Go 1.23, 1.24 (supported)
- **Rust (Actix, Axum)** — stable toolchain (rolling)

---

## 10. WebSockets / Real-Time APIs

- **SignalR** — tied to .NET versions (8, 9, 10)
- **Socket.IO** — 4.x (current)
- **Native WebSocket API** — browser spec (no version)
- **gRPC** — 1.x (current)
- **GraphQL** — spec-level (libraries: Apollo, Relay, Strawberry)
- **Server-Sent Events (SSE)** — browser spec

---

## 11. CLI / Scripting

- **PowerShell** — 7.4 (LTS, until Nov 2026), 7.6 LTS (current)
- **Bash** — 5.x (tied to OS/distro)
- **Python** — 3.10 (EOL Oct 2026), 3.11, 3.12, 3.13, 3.14 (current)
- **Node.js** — 20 LTS (EOL Apr 2026), 22 LTS (until Apr 2027), 24 (current)
- **Azure CLI** — rolling releases (managed)
- **AWS CLI** — v2 (rolling)
- **kubectl** — tied to K8s versions (1.33–1.35)
- **Terraform CLI** — see IaC section

---

## 12. ETL / Data Integration

- **SSIS (SQL Server Integration Services)** — tied to SQL Server (2019, 2022, 2025)
- **Azure Data Factory** — managed
- **Apache Airflow** — 2.x (EOL Apr 2026), 3.x (current)
- **dbt Core** — 1.11 (current, 1yr support per minor)
- **dbt Cloud** — managed
- **Apache Spark** — 3.5 LTS (EOL Apr 2026), 4.0, 4.2 (current)
- **Apache Kafka** — 3.9, 4.0, 4.1, 4.2 (current)
- **Apache NiFi** — 2.8 (current; 1.x EOL)
- **Informatica IDMC** — managed (quarterly releases)
- **Talend** — 8.0 (current, monthly releases)
- **Fivetran** — managed
- **AWS Glue** — managed
- **Azure Synapse Pipelines** — managed

---

## 13. Data Analytics / BI

- **Power BI** — Desktop/Service (monthly releases, managed)
- **Tableau** — 2025.x, 2026.1 (current; tiered support)
- **SSAS (Analysis Services)** — tied to SQL Server (2019, 2022, 2025)
- **SSRS (Reporting Services)** — tied to SQL Server (2019, 2022, 2025)
- **Looker** — managed (Google Cloud)
- **Apache Superset** — 6.x (current)
- **Metabase** — v59, v60 (current)
- **Grafana** — 12.x (current; rolling 2-version support)
- **Qlik Sense** — managed / Enterprise
- **ThoughtSpot** — managed

---

## 14. Monitoring / Observability

- **Prometheus** — 3.x LTS (current; 1yr LTS support)
- **Grafana** — 12.x (current)
- **Elasticsearch + Kibana (ELK)** — 8.x, 9.x
- **OpenTelemetry Collector** — 0.149+ (current)
- **Datadog** — managed
- **New Relic** — managed
- **Splunk** — 9.x (Enterprise)
- **Zabbix** — 7.4 (current; LTS releases every 1.5yr with 3+2yr support)
- **Nagios** — XI (current), Core (open source)
- **PagerDuty** — managed
- **Dynatrace** — managed

---

## 15. DevOps / CI-CD / IaC

### Infrastructure as Code

- **Terraform** — 1.14, 1.15 (current; 2yr support window)
- **OpenTofu** — 1.x (OSS fork of Terraform)
- **Pulumi** — 3.x (current)
- **AWS CloudFormation** — managed
- **Azure Bicep / ARM** — managed
- **Ansible** — 2.18, 2.19, 2.20 (last 3 majors supported)

### CI/CD

- **GitHub Actions** — managed
- **GitLab CI** — 18.7, 18.8, 18.9 (last 3 supported)
- **Azure DevOps** — Services (managed), Server (modern lifecycle)
- **Jenkins** — 2.541 LTS (current)
- **CircleCI** — managed
- **ArgoCD** — 3.1, 3.2, 3.3 (last 3 minors)
- **Flux** — 2.x (current)

### GitOps / Config Management

- **Chef** — 18.x (current)
- **Puppet** — 8.x (current)
- **SaltStack** — 3007.x (current)

---

## 16. Storage

### On-Premises / SAN / NAS

- **NetApp ONTAP** — 9.14, 9.15, 9.16, 9.17, 9.18 (3yr full + 2yr limited)
- **Dell PowerStore** — 4.0 (current)
- **Dell Unity** — OE 5.5 (current)
- **Pure Storage FlashArray** — Purity current
- **HPE Nimble / Alletra** — current

### Software-Defined / Distributed

- **Ceph** — 19.2 Squid (EOL Sep 2026), 20.2 Tentacle (current)
- **MinIO** — current (commercial licensing since Feb 2026)
- **GlusterFS** — 11.x (current)

### Cloud Object Storage

- **AWS S3** — managed
- **Azure Blob Storage** — managed
- **Google Cloud Storage** — managed

### Windows Storage

- **Windows Storage Server / Storage Spaces Direct** — tied to Windows Server versions

---

## 17. Messaging / Event Streaming

- **Apache Kafka** — 3.9, 4.0, 4.1, 4.2 (current)
- **RabbitMQ** — 4.2 (current)
- **NATS** — 2.12 (current; last 2 minors supported)
- **Azure Service Bus** — managed
- **AWS SQS / SNS** — managed
- **Google Cloud Pub/Sub** — managed
- **Redis Streams** — tied to Redis versions
- **Apache Pulsar** — 4.x (current)

---

## 18. Cloud Platforms

### AWS

- EC2, Lambda, RDS, Aurora, DynamoDB, S3, EKS, ECS, CloudFormation, IAM, VPC, Route 53, CloudFront, SQS/SNS, Glue, Redshift, SageMaker
- (Managed — no traditional versioning)

### Microsoft Azure

- Virtual Machines, App Service, Azure SQL, Cosmos DB, AKS, Functions, Blob Storage, Entra ID, DevOps, Synapse, Data Factory, Key Vault, Service Bus
- (Managed — no traditional versioning)

### Google Cloud Platform

- Compute Engine, GKE, Cloud SQL, BigQuery, Cloud Run, Cloud Functions, Pub/Sub, Spanner, Vertex AI
- (Managed — no traditional versioning)

---

## 19. Data APIs / Data Access

- **GraphQL** — spec-based (Apollo Server, Strawberry, Hot Chocolate)
- **OData** — 4.x (protocol version)
- **gRPC** — 1.x (current)
- **SignalR** — tied to .NET (8, 9, 10)
- **REST** — architectural style (no version)

---

## 20. Mail / Collaboration (potential future domain)

- **Microsoft Exchange** — 2019, Exchange Online (managed)
- **Microsoft 365** — managed
- **Google Workspace** — managed
- **Postfix** — 3.9, 3.10 (current)

---

## Notes

- **Managed** = cloud service with no user-facing version selection
- **EOL** = End of Life / End of Support
- **LTS** = Long Term Support
- **STS** = Short Term Support / Standard Term Support
- Versions marked current as of April 2026; verify before implementation
- Some technologies appear in multiple domains (Redis in Database + Messaging, Grafana in Analytics + Monitoring) — plan for cross-references, not duplication
