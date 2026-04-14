# Fivetran Architecture Deep Dive

## Platform Architecture

### Control Plane

The Fivetran SaaS control plane is the central orchestration layer. It manages:

- **Connector scheduling and execution**: Determines when each connector syncs, dispatches extraction jobs, and monitors completion
- **Schema detection and propagation**: Detects source schema changes during each sync and applies them to the destination according to configured policies
- **Credential management**: Stores OAuth tokens, API keys, and database credentials encrypted at rest with AES-256 and per-tenant isolation
- **Dashboard and API**: Web UI for visual management, REST API for programmatic control, Terraform provider for IaC
- **Webhook delivery**: Pushes real-time events (sync completion, failure, schema change) to configured endpoints

The control plane runs in Fivetran's cloud infrastructure and is the same regardless of data plane deployment model.

### Data Plane Options

The data plane determines where data extraction and processing occurs:

**Fully Managed SaaS** (default): All data processing happens in Fivetran's cloud. Data flows from source through Fivetran's infrastructure to the destination. Simplest deployment with zero infrastructure management.

**Hybrid Deployment**: A local agent container runs in the customer's environment (Kubernetes, Docker, or Podman on Linux). The agent creates a secure outbound mTLS connection to the Fivetran control plane. Data extracted by the agent is sent directly to the destination -- it never passes through Fivetran's cloud. Use when data residency, compliance, or on-premises source access requires data to remain within the customer's network.

**High-Volume Agent (HVA)**: A dedicated agent for enterprise database connectors. Uses the HVR-derived log-based CDC engine with data compression before transmission. Designed for high-throughput database replication where data volumes or change rates exceed SaaS connector capacity.

### Private Networking

For securing connections between Fivetran and cloud resources:

| Method | Cloud Provider | Use Case |
|---|---|---|
| **AWS PrivateLink** | AWS | Private connectivity to Redshift, RDS, S3 |
| **Azure Private Link** | Azure | Private connectivity to Synapse, Azure SQL, ADLS |
| **Google Private Service Connect** | GCP | Private connectivity to BigQuery, Cloud SQL |
| **SSH Tunnel** | Any | Encrypted tunnel through a bastion host to databases |
| **VPN** | Any | Site-to-site VPN for on-premises or private network sources |

Private networking eliminates public internet exposure for data movement.

## Connector Deep Dive

### Standard Connectors

Full-featured connectors built, tested, and maintained by Fivetran engineering. Characteristics:

- Complete schema coverage for the source system's API
- Support for all sync frequencies (down to 1-minute on Enterprise/Business Critical plans)
- Automatic handling of API pagination, rate limiting, and retry
- Schema change detection and propagation
- Full Fivetran support SLA

### Lite Connectors

Faster-to-build connectors for SaaS sources with non-dynamic schemas:

- Cover fewer API endpoints than Standard connectors
- Do not support 1-minute sync frequency on any plan
- Available for sources where the core data tables are well-defined
- Check connector documentation for specific table and field coverage before relying on a Lite connector

### High-Volume Agent (HVA) Connectors

Enterprise database connectors running the HVR-derived CDC engine:

- Deploy as an agent within the customer's network
- Read database transaction logs directly for log-based CDC
- Compress data before network transmission for efficiency
- Support Oracle, SQL Server, PostgreSQL, MySQL, SAP HANA, and other enterprise databases
- Handle high change rates and large table volumes that exceed SaaS connector capacity
- Fivetran acquired HVR in October 2021 (~$700M) to build this capability

### Connector SDK (Custom Connectors)

Build custom connectors in Python for proprietary or niche sources:

- Define source schema, extraction logic, and state management
- Deploy to Fivetran infrastructure (managed) or customer infrastructure (self-hosted)
- Fivetran handles scheduling, retry, and state persistence
- Private to the account that created them
- Useful for internal APIs, proprietary databases, or sources with no pre-built connector

### Partner-Built Connectors

Third-party connectors built using the Fivetran Partner SDK. Available to all Fivetran customers. The Partner-Built program is currently closed to new partners.

## Destinations

### Cloud Data Warehouses

- **Snowflake**: Primary destination for many Fivetran customers. Full support for Snowflake features including stages, roles, and warehouses.
- **Google BigQuery**: Native integration with BigQuery datasets and tables.
- **Amazon Redshift**: Support for Redshift clusters and Redshift Serverless.
- **Azure Synapse Analytics**: Integration with dedicated SQL pools.

### Lakehouses

- **Databricks**: Write directly to Delta Lake tables via Unity Catalog or legacy HMS.

### Databases

- PostgreSQL, MySQL, SQL Server as destinations (less common than warehouse destinations).

### Data Lakes / Object Storage

- Amazon S3 (Parquet/CSV)
- Azure Data Lake Storage Gen2
- Google Cloud Storage

## Sync Execution Model

### Initial Sync (Historical Load)

When a connector is first configured:

1. Fivetran connects to the source and discovers the schema
2. All selected tables are fully extracted (all historical data)
3. Data is processed in batches and loaded incrementally into the destination during extraction
4. Initial sync can take hours to days for large databases (millions of rows)
5. After initial sync completes successfully, the connector switches to incremental mode

### Incremental Sync

After the initial sync, each scheduled sync:

1. Fivetran queries the source for changes since the last sync checkpoint
2. Detection method depends on connector type (cursor, API diffing, log-based CDC)
3. Only new, updated, or deleted rows are extracted
4. Changes are applied to the destination (INSERT, UPDATE, or soft delete)
5. Sync checkpoint is advanced

### Sync Phases

Each sync execution has three phases visible in the dashboard:

| Phase | What Happens | Common Bottleneck |
|---|---|---|
| **Extract** | Data pulled from source | API rate limits, slow database queries, network latency |
| **Process** | Data transformed and prepared | Large data volumes, complex schema, type conversions |
| **Load** | Data written to destination | Warehouse performance, concurrent load contention |

### Automatic Retry

When a sync fails, Fivetran retries on a progressive schedule:

| Window | Retry Frequency |
|---|---|
| 0-24 hours | At the configured sync frequency |
| 24-72 hours | At the configured sync frequency |
| 72 hours - 14 days | Daily |
| After 14 days | Connection paused automatically |

### Automatic Re-Sync Detection

Introduced March 2026: automatically detects data consistency issues after connection drops or schema changes and triggers re-synchronization to restore integrity.

## CDC Architecture

### Log-Based CDC

Fivetran exclusively uses log-based CDC for database connectors. The engine reads database transaction logs asynchronously:

- Captures all changes (inserts, updates, deletes) with no risk of missing data
- Near-zero performance impact on the source database (reads logs, not tables)
- Works for mission-critical, high-transaction production systems
- Maintains a position marker in the transaction log for incremental reads

### CDC Row-Level Behavior

| Mode | Deletes | Row Retention | Metadata Columns |
|---|---|---|---|
| **Soft Delete** | `_fivetran_deleted = TRUE` | All rows retained | `_fivetran_deleted`, `_fivetran_synced` |
| **History Mode** | Versioned with end timestamp | All versions retained (SCD2) | `_fivetran_start`, `_fivetran_end`, `_fivetran_active` |
| **Live Mode** | Hard delete at destination | Only current rows | `_fivetran_synced` |

Soft delete is the default for CDC tables. History mode provides a complete audit trail of all changes.

### HVR Acquisition Context

Fivetran acquired HVR in October 2021 for ~$700M alongside a $565M Series D round. HVR specialized in high-volume, real-time data replication for enterprise databases with deep support for Oracle, SAP, DB2, Teradata, and mainframe systems. The HVR technology became:

1. **HVA connectors** -- Enterprise CDC at scale
2. **Hybrid Deployment** -- On-premises processing capability
3. **HVR 5/6** -- Legacy products still supported for existing HVR customers

## Schema Management Architecture

### Detection Flow

1. During each sync, Fivetran compares the current source schema against the last known schema
2. Changes are classified: new table, new column, removed column, renamed column, type change
3. Changes are applied according to the configured schema change handling policy
4. Notifications sent if configured (email, webhook)
5. Changes logged in the `fivetran_log` schema in the destination

### Schema Evolution Strategies

**Net-Additive** (default, recommended for production):
- New columns added to destination when added at source
- Removed columns retained at destination (values become NULL for new rows)
- Renamed columns: old column retained (NULLs), new column added
- Tables never removed from destination
- Safe for downstream consumers -- nothing breaks

**Live Updating**:
- Destination mirrors source exactly
- Removed columns and tables propagated (deleted from destination)
- Renames propagated
- Can break downstream consumers if they reference removed columns

### Data Type Promotion

When source data types change, Fivetran promotes the destination column to a more inclusive type:

- Integer to Double (numeric widening)
- String widening (increased length)
- Prevents data loss from type narrowing
- May cause display differences (e.g., `42` becomes `42.0`)

## Transformations Architecture

### Quickstart Data Models

Pre-built, Fivetran-maintained dbt packages that transform raw connector output into analytics-ready tables:

- Zero-code setup via the Fivetran dashboard
- Connector-specific models (e.g., Salesforce opportunity pipeline, Stripe revenue metrics)
- Automatically updated when connector schemas evolve
- 5,000 model runs free per month; additional runs charged per plan

### dbt Core Orchestration

Fivetran orchestrates dbt Core projects directly (supports v1.9.10+ and v1.10.11+):

- Connect a Git repository containing the dbt project
- Models triggered automatically after connector syncs complete
- Full pipeline visibility in the Fivetran dashboard
- Model run status, logs, and lineage in a single pane

### dbt Cloud Integration

Trigger dbt Cloud jobs from Fivetran and view run status within the Fivetran UI. End-to-end ELT pipeline management from Fivetran.

## IaC and API Architecture

### REST API

Comprehensive API covering all platform resources:
- Connectors: CRUD, sync trigger, status, schema configuration
- Destinations: CRUD, connection testing
- Users and Groups: CRUD, role assignment
- Transformations: CRUD, run history
- Webhooks: CRUD, event subscription

Base URL: `https://api.fivetran.com/v1/`
Authentication: API key + API secret (Basic Auth) or Bearer token

### Terraform Provider

Official HashiCorp-verified provider (`fivetran/terraform-provider-fivetran`):
- Manage all Fivetran resources as code
- Multi-region support (US, EU, AU)
- CI/CD pipeline integration
- State management and drift detection
- Import existing resources into Terraform state

## Security Architecture

### Encryption

- **In transit**: TLS for all connections between sources, Fivetran, and destinations
- **At rest**: AES-256 encryption for all stored data and credentials
- **Customer-managed KMS**: Business Critical plan allows customers to manage their own encryption keys

### Compliance

SOC 2 Type 2, HIPAA, HITRUST i1 Certified, GDPR, CCPA, EU-US Data Privacy Framework, ISO 27001.

### Credential Isolation

- Per-tenant credential isolation
- OAuth token refresh handled automatically
- Credentials never logged or exposed in API responses
