# Fivetran Architecture

## Platform Overview

Fivetran is a fully managed EL (Extract and Load) platform that automates data movement from sources to destinations. The platform follows the modern ELT paradigm: extract data from sources, load it into a cloud destination, then transform it in the destination using SQL or dbt. Fivetran handles connector maintenance, schema management, and infrastructure so data teams focus on analysis rather than pipeline plumbing.

## Core Architecture Components

### Control Plane

The Fivetran SaaS control plane orchestrates all data movement. It manages:

- Connector scheduling and execution
- Schema detection and propagation
- Credential and secret management (encrypted at rest with AES-256)
- Dashboard UI, REST API, and Terraform provider for configuration
- Webhook and notification delivery

### Data Plane Options

Fivetran offers multiple deployment models for the data processing layer:

| Model | Data Processing | Orchestration | Use Case |
|---|---|---|---|
| **SaaS (Fully Managed)** | Fivetran cloud | Fivetran cloud | Default for most customers |
| **Hybrid Deployment** | Customer network (Docker/K8s agent) | Fivetran cloud | Data residency, compliance, on-prem sources |
| **High-Volume Agent (HVA)** | Customer network (dedicated agent) | Fivetran cloud | Large enterprise databases, high-throughput CDC |

In the Hybrid Deployment model, a local agent container runs in the customer's environment (Kubernetes, Docker, or Podman on Linux). The agent creates a secure outbound mTLS connection to the Fivetran control plane. Data never leaves the customer's network except to the designated destination.

### Private Networking

Connections can be secured via:

- AWS PrivateLink
- Azure Private Link
- Google Private Service Connect
- SSH tunnels
- Site-to-site VPN tunnels

---

## Connectors

### Connector Ecosystem

Fivetran offers **700+ pre-built connectors** (as of 2026), the largest catalog in the managed data integration market. Connector categories include:

| Category | Examples |
|---|---|
| **SaaS Applications** | Salesforce, HubSpot, Marketo, Zendesk, Jira, Stripe, Shopify |
| **Databases** | PostgreSQL, MySQL, SQL Server, Oracle, MongoDB, DynamoDB |
| **Cloud Platforms** | Snowflake (as source), BigQuery, AWS S3, Azure Blob |
| **ERP Systems** | SAP, NetSuite, Oracle EBS, Workday |
| **Files & Events** | SFTP, Google Sheets, Webhooks, Kafka, Kinesis |
| **Advertising & Analytics** | Google Ads, Facebook Ads, Google Analytics 4, LinkedIn Ads |

### Connector Types

1. **Standard Connectors** -- Fully managed, in-house built and maintained. Cover the most common sources with full schema support.
2. **Lite Connectors** -- Built via the "By Request" program for SaaS sources with non-dynamic schemas. Cover fewer endpoints than Standard connectors. Cannot use 1-minute sync frequency.
3. **Partner-Built Connectors** -- Built by Fivetran partners using the Partner SDK. Available to all customers. (Program currently closed to new partners.)
4. **Custom Connectors (Connector SDK)** -- Customer-built connectors using the Fivetran Connector SDK (Python). Can run on Fivetran infrastructure or customer infrastructure. Only available to the account that created them.
5. **High-Volume Agent (HVA) Connectors** -- Specialized database connectors for enterprise-scale CDC. Run as agents within the customer's network. Use log-based CDC with data compression before transmission.

---

## Destinations

Fivetran loads data into the following destination categories:

### Cloud Data Warehouses
- Snowflake
- Google BigQuery
- Amazon Redshift
- Azure Synapse Analytics

### Lakehouses
- Databricks (Delta Lake / Unity Catalog)

### Databases
- PostgreSQL
- MySQL
- SQL Server

### Data Lakes / Object Storage
- Amazon S3 (Parquet/CSV)
- Azure Data Lake Storage (ADLS Gen2)
- Google Cloud Storage

### Other Platforms
- Firebolt, ClickHouse, and other emerging destinations

---

## Sync Modes

### Full Sync (Historical / Initial Sync)

When a connector is first set up, Fivetran performs a **full historical sync**. It extracts all historical data from selected tables, processes it, and loads it into the destination. This can take hours or days depending on data volume. During the historical sync, Fivetran periodically loads batches into the destination rather than waiting for the full extraction to complete.

### Incremental Sync

After the initial sync succeeds, the connector switches to **incremental mode**. Only new or modified data since the last successful sync is extracted, processed, and loaded. Incremental syncs dramatically reduce data volume and execution time.

Incremental sync detection methods vary by source:

| Method | How It Works | Source Types |
|---|---|---|
| **Cursor-based** | Tracks a timestamp or sequence column to find new/changed rows | SaaS APIs, some databases |
| **API-based diffing** | Uses source API change detection (e.g., updated_at endpoints) | SaaS connectors |
| **Log-based CDC** | Reads database transaction logs for inserts, updates, deletes | Databases (preferred) |
| **Change Tracking (CT)** | Uses database built-in change tracking features | SQL Server |

### Sync Frequencies

| Plan | Minimum Frequency |
|---|---|
| Free / Standard | 5 minutes (standard connectors) |
| Enterprise | 1 minute |
| Business Critical | 1 minute |

Lite connectors do not support 1-minute sync frequency on any plan.

---

## Change Data Capture (CDC)

### CDC Architecture

Fivetran's CDC replication is **exclusively log-based** for all major databases. Log-based CDC reads the database transaction log asynchronously, which:

- Captures all changes (inserts, updates, deletes) with no risk of missing data
- Imposes near-zero performance impact on the source database
- Works for mission-critical, high-transaction systems

### Database-Specific CDC Methods

| Database | CDC Methods Supported |
|---|---|
| **SQL Server** | Change Data Capture (system capture tables), Change Tracking (CT), Binary Log Reader (Fivetran DLL) |
| **PostgreSQL** | Logical replication (pgoutput / wal2json) |
| **MySQL** | Binary log (binlog) replication |
| **Oracle** | LogMiner, Oracle GoldenGate integration (via HVA) |
| **MongoDB** | Change streams |

### CDC Sync Modes (Row-Level Behavior)

| Mode | Behavior | Use Case |
|---|---|---|
| **Soft Delete** | Deleted rows remain in destination; `_fivetran_deleted = TRUE` column is set | Default for CDC tables. Preserves audit trail. |
| **History Mode** | All versions of every row are retained using SCD Type 2 format (`_fivetran_start`, `_fivetran_end`, `_fivetran_active`) | Full change history / audit requirements |
| **Live Mode** | Hard deletes propagated; destination mirrors source exactly | When destination must match source schema and data 1:1 |

When CDC is enabled and a new table is added, Fivetran defaults to **soft delete** mode.

---

## HVR Acquisition

### Background

Fivetran acquired **HVR** (founded 2012) in October 2021 for approximately $700 million, alongside a $565 million Series D funding round.

### What HVR Brought

HVR specialized in **high-volume, real-time data replication** for enterprise databases. Core capabilities included:

- Log-based CDC with minimal source impact
- Heterogeneous replication (cross-platform, cross-database)
- Data validation and comparison tools
- On-premise deployment for legacy and regulated environments
- Deep support for Oracle, SAP, IBM DB2, Teradata, and mainframe systems

### Integration into Fivetran

The HVR technology was integrated into Fivetran as:

1. **High-Volume Agent (HVA) Connectors** -- Enterprise-grade database connectors that run as agents in the customer's network, using HVR's log-based CDC engine with data compression.
2. **Hybrid Deployment Model** -- The on-premise processing capability became Fivetran's Hybrid Deployment, allowing data to remain within the customer's network.
3. **HVR 5 and HVR 6** -- Existing HVR products continue to be supported and documented under the Fivetran umbrella for customers with active HVR deployments.

### Strategic Impact

The acquisition expanded Fivetran from primarily SaaS-connector-focused into the enterprise database replication market, directly competing with Informatica, Attunity, and Oracle GoldenGate for large-scale operational data movement.

---

## Transformations

Fivetran supports in-warehouse transformations through multiple mechanisms:

### Fivetran Transformations (Native)

- **Quickstart Data Models**: Pre-built dbt models that transform Fivetran's normalized connector output into analytics-ready tables. No SQL or dbt knowledge required. Managed entirely in the Fivetran dashboard.
- **SQL-based Transformations**: Write custom SQL transformations that run in the destination warehouse after syncs complete.

### dbt Integration

- **dbt Core**: Fivetran orchestrates dbt Core projects (v1.9.10+ and v1.10.11+ as of 2026). Models can be triggered after connector syncs complete.
- **dbt Cloud**: Direct integration allows triggering dbt Cloud jobs from Fivetran and viewing status in the Fivetran dashboard.

### Scheduling

Transformations can be triggered:
- **After sync completion** -- Runs automatically when new data arrives
- **On a fixed schedule** -- Runs at defined intervals regardless of sync status

### Fivetran + dbt Labs Merger (2025-2026)

In October 2025, Fivetran and dbt Labs announced a merger (all-stock deal). The combined entity approaches $600M in annual recurring revenue and aims to create an open, end-to-end data integration and transformation platform.

---

## Management and IaC

### REST API

Fivetran provides a comprehensive REST API for programmatic management of connectors, destinations, users, groups, schemas, and transformations. Postman collections are available for all endpoints.

### Terraform Provider

The official `fivetran/terraform-provider-fivetran` (HashiCorp-verified) enables infrastructure-as-code management:

- Provision and manage connectors, destinations, users, and groups
- Version control configurations in Git
- Replicate configurations across environments (dev/staging/prod)
- Integrate into CI/CD pipelines
- Multi-region support (US, EU, AU)

### Dashboard

The Fivetran web dashboard provides visual management of all platform resources including connector status, sync history, schema configuration, transformation management, and user/team administration.
