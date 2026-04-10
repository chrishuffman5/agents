# Fivetran Features and Capabilities

## Connector Ecosystem

### Scale

- **700+ pre-built connectors** as of 2026, covering SaaS applications, databases, ERPs, file systems, event streams, and cloud platforms
- Largest connector catalog in the managed data integration market
- Connectors are developed, tested, and maintained by Fivetran engineering -- customers do not maintain connector code

### Connector Categories

| Category | Count (approx.) | Examples |
|---|---|---|
| SaaS Applications | 400+ | Salesforce, HubSpot, Marketo, Zendesk, Jira, ServiceNow, Workday |
| Databases | 30+ | PostgreSQL, MySQL, SQL Server, Oracle, MongoDB, DynamoDB, Cosmos DB |
| ERP / Finance | 20+ | SAP, NetSuite, QuickBooks, Xero, Sage |
| Advertising | 30+ | Google Ads, Facebook Ads, LinkedIn Ads, TikTok Ads, Bing Ads |
| Files & Storage | 15+ | S3, GCS, Azure Blob, SFTP, Google Sheets, Box, Dropbox |
| Events & Streaming | 10+ | Webhooks, Kafka, Kinesis, Google Pub/Sub |
| Analytics | 15+ | Google Analytics 4, Mixpanel, Amplitude, Segment |

### Connector Types

1. **Standard** -- Full-featured, fully managed connectors with complete schema support
2. **Lite** -- Faster-to-build connectors for sources with non-dynamic schemas; cover fewer endpoints
3. **Partner-Built** -- Third-party built connectors available to all Fivetran customers
4. **Custom (Connector SDK)** -- Python-based custom connectors built by customers for proprietary sources
5. **High-Volume Agent (HVA)** -- Enterprise database connectors with log-based CDC, running as agents in customer infrastructure

### Connector SDK

- Build custom connectors in Python
- Deploy to Fivetran infrastructure or self-hosted
- Handles authentication, pagination, error handling, and state management
- Private to the account that created them
- Example connectors and code patterns provided in documentation

---

## dbt Integration

### Native dbt Core Orchestration

- Fivetran orchestrates dbt Core projects directly (supports v1.9.10+ and v1.10.11+)
- Models triggered automatically after connector syncs complete
- Full pipeline visibility in Fivetran dashboard -- no need to switch between tools
- Model run status, logs, and lineage visible in a single pane

### dbt Cloud Integration

- Trigger dbt Cloud jobs from Fivetran
- View dbt Cloud run status within Fivetran UI
- End-to-end ELT pipeline management from a single platform

### Fivetran + dbt Labs Merger

- October 2025: Definitive merger agreement (all-stock deal)
- Combined entity approaching $600M ARR
- Vision: unified open data infrastructure for analytics and AI
- Joint product roadmap for tighter ELT integration

---

## Fivetran Transformations

### Quickstart Data Models

Pre-built, Fivetran-maintained dbt models that convert raw connector output into analytics-ready tables:

- **Zero-code setup** -- Configure and run from the Fivetran dashboard without writing SQL or building a dbt project
- **Connector-specific** -- Models tailored to each connector's schema (e.g., Salesforce opportunity pipeline, Stripe revenue metrics, Google Ads campaign performance)
- **Immediate insights** -- Production-ready tables available within minutes of first sync
- **Customizable** -- Select which output models to generate; configure scheduling
- **Maintained by Fivetran** -- Model updates shipped automatically when connector schemas evolve

Available Quickstart models include connectors such as:
- Salesforce, HubSpot, Marketo, Zendesk
- Stripe, Shopify, QuickBooks
- Google Ads, Facebook Ads, LinkedIn Ads
- Jira, GitHub, GitLab
- Google Analytics 4, Mixpanel

### SQL Transformations

- Write custom SQL queries that execute in the destination warehouse
- Triggered after syncs or on a fixed schedule
- Useful for lightweight transformations without a full dbt project

### Pricing for Transformations

- **5,000 model runs free per month** (all plans)
- Additional model runs charged per the pricing plan

---

## Sync Capabilities

### Sync Frequencies

| Plan | Minimum Sync Frequency |
|---|---|
| Free | 5 minutes (standard connectors) |
| Standard | 5 minutes |
| Enterprise | 1 minute |
| Business Critical | 1 minute |

### Automatic Re-Sync Detection

Introduced in March 2026, this feature automatically detects data consistency issues after connection drops or schema changes and triggers re-synchronization to restore data integrity.

### Sync History and Observability

- Visual sync history chart on connector status page
- Breakdown by phase: Extract, Process, Load
- Duration and data volume per sync segment
- Failed sync details with error descriptions and resolution guidance

### Automated Retry Logic

When a sync fails, Fivetran retries automatically:
1. First retry within 24 hours
2. Retries at the configured sync frequency for up to 72 hours
3. Daily retries until 14 days
4. Connection automatically paused after 14 days of failures

---

## Schema Management

### Automatic Schema Detection

Fivetran automatically detects source schemas and propagates them to the destination, including new tables, columns, and data type changes.

### Schema Change Handling Options

| Setting | Behavior |
|---|---|
| **Allow all new data** | New schemas, tables, and columns are automatically synced |
| **Allow new columns** | Only new columns on existing tables are synced; new tables/schemas blocked |
| **Block all new data** | No new schemas, tables, or columns synced without manual approval |

### Schema Evolution Strategies

1. **Net-Additive** (default) -- Columns/tables added at destination when added at source. Renames create duplicates under new names. Columns/tables never removed. Safe for downstream consumers.
2. **Live Updating** -- Destination mirrors source exactly. Renames propagated. Removals propagated. Destination always matches current source schema.

### Data Type Promotion

When source data types change, Fivetran promotes the destination column to a more inclusive type (e.g., integer to double, string widening). This prevents data loss from type narrowing.

---

## Security and Compliance

### Certifications and Compliance

- SOC 2 Type 2
- HIPAA
- HITRUST i1 Certified
- GDPR
- CCPA
- EU-US Data Privacy Framework
- ISO 27001

### Encryption

- Data encrypted in transit (TLS) and at rest (AES-256)
- Business Critical plan: Customer-managed KMS for encryption keys
- Credentials stored encrypted with per-tenant isolation

### Deployment Models

| Model | Description |
|---|---|
| **Fully Managed SaaS** | All processing in Fivetran cloud |
| **Hybrid Deployment** | Data processing in customer network; orchestration in Fivetran cloud |
| **Private Deployment** | Dedicated infrastructure (deprecated for new customers as of March 2025) |

### Network Security

- AWS PrivateLink, Azure Private Link, Google Private Service Connect
- SSH tunnel support
- Site-to-site VPN
- IP whitelisting

---

## Alerting and Notifications

### Built-In Notifications

- Automatic email alerts for connection failures, sync errors, and schema changes
- Configurable per user and per connector
- Alert details include error cause and resolution steps

### Webhooks

- Real-time webhook events for sync completions, failures, and schema changes
- Integrate with Slack, PagerDuty, Opsgenie, or custom endpoints
- Webhook failure notifications available

### Integration Patterns

- Slack notifications via channel email addresses or webhook-to-Slack integrations
- PagerDuty integration for on-call alerting
- Custom automation via webhook payloads

---

## API and Infrastructure as Code

### REST API

- Full CRUD for connectors, destinations, users, groups, schemas, and transformations
- Sync triggering and status querying
- Schema configuration and column-level control
- Postman collections available

### Terraform Provider

- Official HashiCorp-verified provider: `fivetran/terraform-provider-fivetran`
- Manage connectors, destinations, users, groups as code
- Multi-region support (US, EU, AU)
- CI/CD pipeline integration
- Git-based version control for configurations

---

## Pricing Model

### Monthly Active Rows (MAR)

- Usage measured by distinct primary keys synced per connector per month
- A row counted only once per month regardless of how many times it syncs
- Since March 2025: MAR calculated per connection (not across the account)

### Plans (as of March 2025)

| Plan | MAR Included | Key Features |
|---|---|---|
| **Free** | 500,000 | All Standard plan features; 5,000 model runs/month |
| **Standard** | Pay-as-you-go | Core features, 5-min sync frequency |
| **Enterprise** | Pay-as-you-go | 1-min sync, private networking, advanced security |
| **Business Critical** | Pay-as-you-go | Customer-managed KMS, dedicated support, HIPAA |

- $5 base charge per standard connection with 1 to 1M MAR per month
- Annual subscription discounts starting at 5%
- Starter and Private Deployment plans discontinued (March 2025)
