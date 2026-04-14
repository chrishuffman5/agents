# Fivetran Best Practices

## Connector Selection and Tiering

### Choose the Right Connector Type

- **Standard connectors** for core business data (CRM, ERP, databases, marketing). Broadest schema coverage, full Fivetran support, all sync frequencies.
- **Lite connectors** for secondary SaaS tools where limited endpoint coverage is acceptable. Verify table/field coverage before relying on a Lite connector. No 1-minute sync support.
- **HVA connectors** for large enterprise databases (Oracle, SQL Server, SAP HANA) where log-based CDC with local processing is required for performance, compliance, or data volume.
- **Connector SDK** for proprietary or niche sources with no pre-built connector. Build in Python; deploy to Fivetran infrastructure or self-host.

### Connector Evaluation Checklist

1. Verify the connector covers the specific tables and fields your analytics require
2. Check sync mode support (incremental vs full refresh) for each table
3. Review API rate limit documentation for the source system
4. Confirm authentication method compatibility (OAuth, API key, service account)
5. Check the connector's release notes for known limitations or recent changes
6. Test with a non-production source before deploying to production

### Connector Tiering

Assign tiers based on business criticality to focus monitoring effort:

| Tier | Description | Monitoring | Example |
|---|---|---|---|
| **Tier 1** | Revenue-critical, regulatory | Real-time alerts, SLA tracking | Salesforce, ERP, billing |
| **Tier 2** | Important but not critical | Daily review, email alerts | Marketing platforms, support tools |
| **Tier 3** | Nice-to-have, exploratory | Weekly review | Social media, secondary analytics |

## Sync Frequency Tuning

### Align Frequency to Business Need

Not all data requires real-time freshness. Over-syncing wastes MAR credits and can strain source APIs.

| Data Type | Recommended Frequency | Rationale |
|---|---|---|
| Product events / clickstream | 1-5 minutes | Near-real-time user behavior |
| Sales pipeline / CRM | 15-30 minutes | Adequate for pipeline reporting |
| Financial / accounting | 1-6 hours | Batch-oriented source systems |
| HR / employee data | 6-24 hours | Low change velocity |
| Historical / archival | Daily or manual | Rarely changes |

### Stagger Sync Schedules

- Avoid scheduling all connectors to sync simultaneously
- Staggering prevents destination warehouse contention and API rate limit collisions
- Use Fivetran's scheduling options to offset connector start times

### Source API Rate Limits

- Understand the rate limits for each SaaS source
- High-frequency syncs on rate-limited APIs cause throttling, slower syncs, and potential failures
- Configure sync frequency to stay within source limits with headroom for other API consumers

## Schema Mapping Strategy

### Schema Change Handling

| Strategy | When to Use |
|---|---|
| **Allow all new data** | Development and exploration environments |
| **Allow new columns** | Production -- safe column additions without unexpected new tables |
| **Block all new data** | Highly regulated environments where every change requires approval |

### Column Selection

- **Sync only what you need** -- Deselecting unnecessary tables and columns is the single highest-impact cost optimization
- Review each connector's schema and disable unused tables/columns
- Revisit schema selections quarterly as analytics requirements evolve

### Schema Naming Conventions

- Establish naming conventions before deploying connectors: e.g., `raw_salesforce`, `raw_hubspot`
- Keep Fivetran raw schemas separate from transformed/analytics schemas
- Document schema ownership, purpose, and business owner

### Handling Schema Drift

- Enable schema change notifications to stay aware of upstream changes
- Use net-additive mode (default) in production to prevent accidental data loss
- Only use live updating when the destination must exactly mirror the source
- Monitor `_fivetran_synced` for data freshness after schema changes

## Cost Optimization

### MAR Management

Monthly Active Rows (MAR) is the primary cost driver. Key strategies:

1. **Sync only required tables and columns** -- The most impactful optimization. Each disabled table eliminates its MAR entirely.
2. **Reduce sync frequency for low-priority data** -- Fewer syncs can reduce MAR if change rates are low relative to sync intervals.
3. **Understand per-connection MAR** -- Since March 2025, MAR is calculated per connection. A row synced in two different connectors counts twice.
4. **Audit MAR consumption regularly** -- Use the Fivetran dashboard to identify connectors consuming the most MAR. Investigate outliers.
5. **Use incremental sync wherever possible** -- Full-refresh tables re-sync all rows every cycle, dramatically inflating MAR.

### Historical Sync Management

- Historical syncs (initial syncs) generate high MAR in the first month
- Plan large historical syncs at the beginning of a billing period
- Consider syncing large tables in phases if budget is constrained
- Monitor progress in the dashboard -- Fivetran loads batches incrementally

### Connector Consolidation

- Avoid duplicate connectors to the same source
- Consolidate schemas to reduce connection count (and $5/connection base charges)
- Remove or pause connectors that are no longer needed

### Annual Contracts

- Annual subscriptions provide discounts starting at 5%
- Higher annual commitments unlock deeper discounts
- Evaluate annual vs. monthly based on expected usage stability

## Alerting and Monitoring

### Notification Configuration

- Enable email notifications for all Tier 1 connectors
- Configure webhook integrations for automated incident response
- Set up Slack notifications via channel email or webhook-to-Slack bridges

### Webhook Integration Patterns

| Integration | Method | Use Case |
|---|---|---|
| **Slack** | Webhook to Slack incoming webhook | Team-wide sync failure alerts |
| **PagerDuty** | Webhook to PagerDuty Events API | On-call escalation for critical failures |
| **Custom automation** | Webhook to Lambda / Cloud Function | Auto-remediation, ticket creation |

### Monitoring Cadence

| Activity | Frequency | Owner |
|---|---|---|
| Review sync failures | Daily (Tier 1), Weekly (Tier 2-3) | Data engineer on rotation |
| Audit MAR consumption | Monthly | Data platform lead |
| Review schema changes | Weekly | Data engineer |
| Connector health check | Quarterly | Data platform team |
| Credential rotation | Per security policy | Data engineer + source admin |

### Proactive Freshness Monitoring

- Monitor `_fivetran_synced` in destination tables to detect stale data
- Set up destination-side queries alerting when `_fivetran_synced` falls behind thresholds:

```sql
-- Snowflake example: detect stale Salesforce data
SELECT MAX(_fivetran_synced) AS last_sync,
       DATEDIFF('minute', MAX(_fivetran_synced), CURRENT_TIMESTAMP()) AS minutes_behind
FROM raw_salesforce.opportunity
HAVING minutes_behind > 60;
```

- Track sync duration trends -- gradual increases indicate growing source volumes or degradation

## dbt Integration Patterns

### Pattern 1: Quickstart Data Models (Zero-Code)

**When**: Need standard analytics tables for a supported connector without a dbt project.

- Enable from the Fivetran dashboard
- Select desired output models
- Schedule to run after sync completion
- No Git repository or SQL required

### Pattern 2: Fivetran-Orchestrated dbt Core

**When**: Custom dbt project with Fivetran-managed scheduling.

- Connect Git repository to Fivetran
- Configure connectors to trigger dbt runs after sync
- Monitor dbt status in Fivetran dashboard
- Supports dbt Core v1.9.10+ and v1.10.11+

### Pattern 3: dbt Cloud Trigger

**When**: Team uses dbt Cloud and wants Fivetran to trigger on sync completion.

- Link Fivetran to dbt Cloud account
- Configure per-connector job triggers
- View dbt Cloud run status in Fivetran UI

### Pattern 4: External Orchestration

**When**: Using Airflow, Dagster, or another orchestrator for full pipeline control.

- Trigger syncs via Fivetran REST API or Terraform
- Poll for sync completion via API
- Trigger dbt runs from orchestrator after confirmation
- Fivetran provides Airflow and Dagster operators

### dbt Project Structure Best Practices

```
models/
  staging/           -- 1:1 with Fivetran raw tables
    stg_salesforce/
    stg_hubspot/
  intermediate/      -- Business logic joins and transformations
  marts/             -- Final analytics tables
    marketing/
    finance/
    product/
```

- Keep staging models thin: rename columns, cast types, filter test rows
- Never modify Fivetran raw tables directly -- always transform via dbt
- Use `_fivetran_deleted` in staging models: `WHERE NOT _fivetran_deleted`
- Use `_fivetran_synced` for freshness tracking and dbt source freshness tests
- Pin dbt model versions to connector schema versions to avoid breakage

## Operational Best Practices

### Credential Management

- Use service accounts rather than personal credentials for authentication
- Store API keys in a vault; reference during connector setup
- Rotate credentials on a regular schedule and update connectors promptly
- Monitor for authentication failures indicating expired or revoked credentials

### Environment Strategy

- Maintain separate Fivetran accounts or destinations for dev, staging, and production
- Use Terraform to replicate connector configurations across environments
- Test schema changes and new connectors in dev before promoting to production

### Change Management

- Treat Fivetran configuration as code (Terraform or API-driven)
- Require pull request review for connector configuration changes
- Log all schema and frequency changes in a change log
- Document each connector's purpose, owner, tier, and schema in a data catalog

### Security Best Practices

- Use private networking (PrivateLink, Private Service Connect) for all production connections
- Enable Business Critical plan for HIPAA workloads
- Review and restrict user permissions in the Fivetran dashboard
- Audit API key usage and rotate on a regular cadence
