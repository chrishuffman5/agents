# IT Domain Taxonomy

Reference catalog of IT domains, their common technologies, and version examples. Use this when scoping new agents or planning which agents to build.

## Database

Covers data storage, retrieval, query optimization, administration, and data integrity.

### Relational Databases (RDBMS)

| Technology | Common Versions | Key Differentiators |
|-----------|----------------|---------------------|
| SQL Server | 2016, 2017, 2019, 2022, 2025 | T-SQL, SSMS, Always On, ColumnStore indexes |
| PostgreSQL | 14, 15, 16, 17, 18 | Extensions ecosystem, MVCC, logical replication |
| Oracle Database | 19c, 21c, 23ai | PL/SQL, RAC, Exadata optimization, Autonomous DB |
| MySQL | 8.0, 8.4, 9.0 | InnoDB, replication, MySQL Shell |
| MariaDB | 10.11, 11.x | Galera Cluster, ColumnStore, MySQL compatibility |

### NoSQL Databases

| Technology | Common Versions | Key Differentiators |
|-----------|----------------|---------------------|
| MongoDB | 6.0, 7.0, 8.0 | Document model, aggregation pipeline, Atlas |
| Redis | 7.x, 8.x | In-memory, data structures, Redis Stack |
| Cassandra | 4.x, 5.x | Wide-column, distributed, tunable consistency |
| DynamoDB | (managed) | Serverless, single-digit ms latency, GSI/LSI |
| Elasticsearch | 8.x | Full-text search, analytics, vector search |

## Networking

Covers network infrastructure, routing, switching, firewalls, and connectivity.

| Technology | Common Versions | Key Differentiators |
|-----------|----------------|---------------------|
| Cisco IOS/IOS-XE | 15.x, 17.x | Enterprise routing/switching, EIGRP, SD-WAN |
| Juniper Junos | 21.x, 22.x, 23.x | Routing, MPLS, Junos automation |
| Palo Alto PAN-OS | 10.x, 11.x | Next-gen firewall, Panorama, GlobalProtect |
| Fortinet FortiOS | 7.x | FortiGate, SD-WAN, Security Fabric |
| Arista EOS | 4.x | Data center switching, CloudVision |

## Cloud Platforms

Covers cloud services, infrastructure as code, and cloud-native architectures.

| Technology | Key Services | Key Differentiators |
|-----------|-------------|---------------------|
| AWS | EC2, RDS, Lambda, EKS, S3 | Broadest service catalog, regions |
| Azure | VMs, SQL DB, Functions, AKS | Enterprise integration, hybrid cloud |
| GCP | Compute, Cloud SQL, GKE | Data/ML services, BigQuery |

## Security

Covers identity, access management, threat detection, and compliance.

| Technology | Common Versions | Key Differentiators |
|-----------|----------------|---------------------|
| Active Directory | 2016, 2019, 2022, 2025 | Kerberos, Group Policy, LDAP |
| Entra ID (Azure AD) | (managed) | Cloud identity, Conditional Access |
| CrowdStrike Falcon | (managed) | EDR, threat intelligence |
| Splunk | 9.x | SIEM, SPL query language |

## DevOps / Platform Engineering

Covers CI/CD, containers, orchestration, and infrastructure management.

| Technology | Common Versions | Key Differentiators |
|-----------|----------------|---------------------|
| Kubernetes | 1.28, 1.29, 1.30, 1.31, 1.32 | Container orchestration, operators |
| Docker | 24.x, 25.x, 26.x, 27.x | Container runtime, Compose |
| Terraform | 1.6, 1.7, 1.8, 1.9, 1.10 | IaC, providers, state management |
| Ansible | 2.15, 2.16, 2.17 | Configuration management, playbooks |
| GitHub Actions | (managed) | CI/CD, workflow automation |

## Monitoring & Observability

Covers metrics, logging, tracing, and alerting.

| Technology | Common Versions | Key Differentiators |
|-----------|----------------|---------------------|
| Prometheus | 2.x | Metrics, PromQL, alerting |
| Grafana | 10.x, 11.x | Visualization, dashboards |
| Datadog | (managed) | Full-stack observability |
| New Relic | (managed) | APM, distributed tracing |
| ELK Stack | 8.x | Log aggregation, Kibana |

## How to Use This Taxonomy

When creating a new agent:

1. **Find the domain** — Identifies the foundational concepts to include
2. **Find the technology** — Identifies the specific implementation details needed
3. **Find the version** — Identifies what's unique about this exact release

When a technology or version isn't listed here, it's still valid — this is a starting point, not an exhaustive list. Research the technology using web search and official documentation to fill in the details.
