# Fivetran Best Practices

## Connector Selection

### Choose the Right Connector Type

- **Standard connectors** for core business data sources (CRM, ERP, databases, marketing platforms). These have the broadest schema coverage and full Fivetran support.
- **Lite connectors** for secondary SaaS tools where limited endpoint coverage is acceptable. Understand that Lite connectors cover fewer API endpoints and do not support 1-minute sync frequencies.
- **HVA connectors** for large enterprise databases (Oracle, SQL Server, SAP HANA) where log-based CDC with local processing is required for performance or compliance.
- **Connector SDK** for proprietary or niche data sources with no pre-built connector. Build in Python; deploy to Fivetran infrastructure or self-host.

### Connector Evaluation Checklist

1. Verify that the connector covers the specific tables and fields your analytics require
2. Check sync mode support (incremental vs. full refresh) for each table
3. Review API rate limit documentation for the source system
4. Confirm authentication method compatibility (OAuth, API key, service account)
5. Check the connector's release notes for known limitations or recent changes
6. Test with a non-production source before deploying to production

### Connector Tiering

Assign a tier to each connector based on business criticality:

| Tier | Description | Monitoring Level | Example |
|---|---|---|---|
| **Tier 1** | Revenue-critical, regulatory | Real-time alerts, SLA tracking | Salesforce, ERP, billing |
| **Tier 2** | Important but not critical | Daily review, email alerts | Marketing platforms, support tools |
| **Tier 3** | Nice-to-have, exploratory | Weekly review | Social media, secondary analytics |

Focus optimization and monitoring effort on Tier 1 connectors.

---

## Sync Frequency

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

- Avoid scheduling all connectors to sync at the same time
- Staggering prevents destination warehouse contention and API rate limit collisions
- Use Fivetran's scheduling options to offset connector start times

### Source API Rate Limits

- Understand the API rate limits for each SaaS source
- High-frequency syncs on rate-limited APIs cause throttling, slower syncs, and potential failures
- Configure sync frequency to stay within source API limits with headroom

---

## Schema Mapping

### Schema Change Handling Strategy

| Strategy | When to Use |
|---|---|
| **Allow all new data** | Development/exploration environments where you want automatic discovery |
| **Allow new columns** | Production environments where new tables should be reviewed but column additions are safe |
| **Block all new data** | Highly regulated environments where any schema change requires approval |

### Column Selection

- **Sync only what you need** -- Deselecting unnecessary tables and columns is the single highest-impact cost optimization
- Review each connector's schema and disable tables/columns that are not used in analytics
- Revisit schema selections quarterly as requirements evolve

### Schema Naming Conventions

- Fivetran creates schemas in the destination using the connector name (configurable)
- Establish a naming convention before deploying connectors: e.g., `fivetran_salesforce`, `raw_hubspot`
- Keep raw/staging schemas separate from transformed/analytics schemas
- Document schema ownership and purpose

### Handling Schema Drift

- Enable schema change notifications to stay aware of source changes
- Use the net-additive strategy (default) for stability -- old columns are never removed
- Only use live updating when the destination must exactly mirror the source
- Monitor `_fivetran_synced` metadata columns for data freshness

---

## Cost Optimization

### MAR Management

Monthly Active Rows (MAR) is the primary cost driver. Strategies to control MAR:

1. **Sync only required tables and columns** -- The most impactful optimization. Each disabled table eliminates its MAR entirely.
2. **Reduce sync frequency for low-priority data** -- Fewer syncs can reduce MAR if change rates are low relative to sync intervals.
3. **Understand per-connection MAR** -- Since March 2025, MAR is calculated per connection. A row synced in two different connectors counts twice.
4. **Audit MAR consumption regularly** -- Use the Fivetran dashboard to identify connectors consuming the most MAR. Investigate outliers.
5. **Use incremental sync wherever possible** -- Full refresh tables re-sync all rows every cycle, dramatically inflating MAR compared to incremental.

### Historical Sync Management

- Historical syncs (initial syncs) can generate very high MAR in the first month
- Plan historical syncs at the beginning of a billing period to maximize the month's MAR allowance
- Consider syncing large historical tables in phases if budget is constrained

### Connector Consolidation

- Avoid duplicate connectors to the same source
- Consolidate schemas where possible to reduce the number of connections (and $5/connection base charges)
- Remove or pause connectors that are no longer needed

### Annual Contracts

- Annual subscriptions provide discounts starting at 5%
- Higher annual commitments unlock deeper discounts
- Evaluate annual vs. monthly based on expected usage stability

---

## Alerting

### Notification Configuration

- Enable email notifications for all Tier 1 connectors
- Configure webhook integrations for automated incident response
- Set up Slack notifications via channel email addresses or webhook-to-Slack bridges

### Webhook Integration Patterns

| Integration | Method | Use Case |
|---|---|---|
| **Slack** | Webhook to Slack incoming webhook or channel email | Team-wide sync failure alerts |
| **PagerDuty** | Webhook to PagerDuty Events API | On-call escalation for critical failures |
| **Custom automation** | Webhook to AWS Lambda / Cloud Function | Auto-remediation, ticket creation |

### Monitoring Cadence

| Activity | Frequency | Owner |
|---|---|---|
| Review sync failures | Daily (Tier 1), Weekly (Tier 2-3) | Data engineer on rotation |
| Audit MAR consumption | Monthly | Data platform lead |
| Review schema changes | Weekly | Data engineer |
| Connector health check | Quarterly | Data platform team |
| Credential rotation | Per security policy | Data engineer + source admin |

### Proactive Monitoring

- Monitor the `_fivetran_synced` timestamp column in destination tables to detect stale data
- Set up destination-side queries that alert when `_fivetran_synced` falls behind expected thresholds
- Track sync duration trends -- gradual increases may indicate growing source volumes or performance degradation

---

## dbt Integration Patterns

### Pattern 1: Quickstart Data Models (Zero-Code)

**When to use**: You need standard analytics tables for a supported connector and do not have a dbt project.

- Enable Quickstart models from the Fivetran dashboard
- Select desired output models
- Schedule to run after sync completion
- No dbt project, Git repository, or SQL required

### Pattern 2: Fivetran-Orchestrated dbt Core

**When to use**: You have a custom dbt project and want Fivetran to manage scheduling and execution.

- Connect your Git repository containing the dbt project to Fivetran
- Configure Fivetran to trigger dbt runs after connector syncs complete
- Monitor dbt run status directly in the Fivetran dashboard
- Supports dbt Core v1.9.10+ and v1.10.11+

### Pattern 3: dbt Cloud Trigger

**When to use**: Your team already uses dbt Cloud and wants Fivetran to trigger jobs on sync completion.

- Link Fivetran to your dbt Cloud account
- Configure connectors to trigger specific dbt Cloud jobs after sync
- View dbt Cloud run status in Fivetran UI

### Pattern 4: External Orchestration

**When to use**: You use Airflow, Dagster, Prefect, or another orchestrator and want full control over the pipeline.

- Use Fivetran's REST API or Terraform provider to trigger syncs
- Poll for sync completion via API
- Trigger dbt runs from your orchestrator after sync confirmation
- Fivetran provides Airflow and Dagster operators/integrations

### dbt Project Structure Best Practices

```
models/
  staging/           -- 1:1 with Fivetran raw tables, light renaming/casting
    stg_salesforce/
    stg_hubspot/
  intermediate/      -- Business logic joins and transformations
  marts/             -- Final analytics tables for BI consumption
    marketing/
    finance/
    product/
```

- Keep staging models thin: rename columns, cast types, filter test rows
- Never modify Fivetran raw tables directly -- always transform via dbt
- Use `_fivetran_deleted` and `_fivetran_synced` columns in staging models for soft-delete handling and freshness tracking
- Pin dbt model versions to Fivetran's connector schema versions to avoid breakage on schema changes

---

## Operational Best Practices

### Credential Management

- Use service accounts rather than personal credentials for connector authentication
- Store API keys and secrets in a vault; reference them during connector setup
- Rotate credentials on a regular schedule and update connectors promptly
- Monitor for authentication failures that indicate expired or revoked credentials

### Environment Strategy

- Maintain separate Fivetran accounts or destinations for dev, staging, and production
- Use Terraform to replicate connector configurations across environments
- Test schema changes and new connectors in dev before promoting to production

### Documentation

- Maintain a data catalog or wiki documenting each connector's purpose, owner, tier, and schema
- Document any manual schema selections or configuration choices
- Record the business justification for sync frequency settings

### Change Management

- Treat Fivetran configuration as code (Terraform or API-driven)
- Require pull request review for connector configuration changes
- Log all schema and frequency changes in a change log
