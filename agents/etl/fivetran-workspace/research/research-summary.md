# Fivetran Research Summary

## What Fivetran Is

Fivetran is a fully managed Extract and Load (EL) platform that automates data movement from source systems to cloud destinations. It follows the modern ELT paradigm: data is extracted from sources and loaded into a cloud data warehouse or lakehouse in raw form, then transformed in-place using SQL or dbt. Fivetran handles all connector development, maintenance, schema management, and pipeline infrastructure.

## Platform Architecture

- **Control plane**: Fivetran SaaS manages orchestration, scheduling, credential storage, dashboard, REST API, and Terraform provider
- **Data plane options**: Fully managed SaaS (default), Hybrid Deployment (customer-network agent with Fivetran orchestration), or High-Volume Agent (HVA) for enterprise database CDC
- **Private networking**: AWS PrivateLink, Azure Private Link, Google Private Service Connect, SSH tunnels, VPN
- **Security**: SOC 2 Type 2, HIPAA, HITRUST, GDPR, CCPA compliant; AES-256 encryption at rest; TLS in transit; customer-managed KMS on Business Critical plan

## Key Capabilities

| Capability | Details |
|---|---|
| **Connectors** | 700+ pre-built (Standard, Lite, Partner-Built); Connector SDK for custom Python connectors; HVA for enterprise databases |
| **Destinations** | Snowflake, BigQuery, Redshift, Databricks, Azure Synapse, PostgreSQL, MySQL, SQL Server, S3, ADLS, GCS |
| **Sync modes** | Full (historical), Incremental (cursor/API/CDC), with soft delete, history (SCD Type 2), and live modes |
| **CDC** | Log-based CDC for all major databases; near-zero source impact; HVR-derived HVA engine for high-volume scenarios |
| **Transformations** | Quickstart data models (zero-code, pre-built dbt models), SQL transformations, dbt Core orchestration, dbt Cloud integration |
| **Sync frequency** | 5-minute minimum (Standard), 1-minute minimum (Enterprise/Business Critical) |
| **Schema management** | Automatic detection and propagation; configurable handling (allow all / allow columns / block all); net-additive or live updating |
| **Alerting** | Email notifications, webhooks (Slack, PagerDuty, custom), dashboard alerts |
| **IaC** | REST API, official Terraform provider (HashiCorp-verified), Postman collections |

## HVR Acquisition (October 2021)

Fivetran acquired HVR for ~$700M alongside a $565M Series D round. HVR's high-volume log-based CDC engine became the foundation for Fivetran's HVA connectors and Hybrid Deployment model. This moved Fivetran from a primarily SaaS-connector platform into direct competition with Informatica and Oracle GoldenGate for enterprise database replication.

## Fivetran + dbt Labs Merger (October 2025)

Fivetran and dbt Labs announced an all-stock merger in October 2025. The combined entity approaches $600M ARR and aims to build a unified open data infrastructure platform spanning extraction, loading, and transformation.

## Pricing Model

- **Monthly Active Rows (MAR)**: Distinct primary keys synced per connector per month; a row counted once regardless of sync frequency
- **Per-connection MAR** (since March 2025): MAR calculated per connection, not across the account
- **Plans**: Free (500K MAR), Standard, Enterprise (1-min sync, private networking), Business Critical (customer KMS, HIPAA)
- **Base charge**: $5/connection/month for connections with 1 to 1M MAR
- **Transformations**: 5,000 model runs free/month; additional charged per plan

## Competitive Position

| Strength | Detail |
|---|---|
| Largest connector library | 700+ managed connectors; no other vendor matches breadth |
| True zero-maintenance EL | Fivetran builds, tests, and maintains all connectors |
| Enterprise CDC | HVR-derived engine handles high-volume database replication |
| dbt-native transformation | Post-merger with dbt Labs, deepest ELT integration in market |
| Multi-deployment | SaaS, Hybrid, HVA options for different compliance requirements |

| Limitation | Detail |
|---|---|
| Cost at scale | MAR-based pricing can be expensive for high-volume, high-change-rate tables |
| No real-time streaming | Minimum 1-minute sync; not a replacement for Kafka/Flink for sub-second latency |
| Lite connector gaps | Lite connectors cover fewer endpoints and have restrictions |
| Vendor lock-in | Proprietary connector code; migration requires rebuilding pipelines |
| Limited transformation | EL-focused; complex transformation logic requires dbt or external tools |

## Research File Index

| File | Contents |
|---|---|
| `architecture.md` | Platform architecture, connectors, destinations, sync modes, CDC methods, HVR acquisition, transformations, IaC |
| `features.md` | Detailed current capabilities: connector ecosystem, dbt integration, Quickstart models, sync features, security, pricing |
| `best-practices.md` | Connector selection, sync frequency tuning, schema mapping, cost optimization, alerting, dbt integration patterns |
| `diagnostics.md` | Sync failure triage, connector issues, data discrepancies, schema drift detection/mitigation, performance diagnostics |
| `research-summary.md` | This file -- executive summary of all findings |

## Sources Consulted

- Fivetran official documentation (fivetran.com/docs)
- Fivetran blog and press releases
- Fivetran REST API and Terraform provider documentation
- dbt Labs merger announcements
- Third-party reviews and analysis (Integrate.io, TechTarget, VentureBeat, phData)
- Fivetran support community posts
