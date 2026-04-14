# Fivetran Diagnostics

## Sync Failures

### Identifying Sync Failures

1. **Dashboard**: Navigate to the connector's Status page. The Sync History chart shows failed syncs in red. Click "View error" for details including error cause and resolution steps.
2. **Email notifications**: Automatic alerts sent to the connector owner on sync failure.
3. **Webhooks**: Configure webhook events for sync completions, failures, and schema changes. Integrate with Slack, PagerDuty, or custom endpoints.
4. **REST API**: Query connector sync status and error details programmatically:

```bash
curl https://api.fivetran.com/v1/connectors/{connector_id} \
  -H "Authorization: Bearer $FIVETRAN_API_KEY" \
  | jq '.data.status'
```

### Common Sync Failure Categories

| Category | Symptoms | Root Cause | Resolution |
|---|---|---|---|
| **Authentication failure** | "Access denied", "401 Unauthorized" | Expired token, revoked API key, password change | Refresh OAuth token; update API key; re-authenticate connector |
| **Permission failure** | "Insufficient privileges" | Source account lacks required permissions | Grant necessary read permissions on source tables/API scopes |
| **Rate limiting** | "429 Too Many Requests", slow syncs | Sync frequency exceeds source API limits | Reduce sync frequency; contact source vendor for limit increase |
| **Network failure** | "Connection timed out", "Host unreachable" | Firewall blocking, VPN down, DNS issues | Verify network path; check firewall rules; validate SSH tunnel / PrivateLink |
| **Schema error** | "Sync failed due to schema definition changes" | Source schema changed during sync | Re-sync the connector; review schema change handling settings |
| **Destination error** | "Could not write to destination" | Warehouse down, out of storage, permission issue | Check destination health; verify Fivetran service account permissions |
| **Data type conflict** | "Cannot cast value" | Source type incompatible with destination column | Review data type mapping; may require destination column alteration |

### Sync Failure Triage Procedure

1. Check the error message in the Fivetran dashboard (Status > Sync History > View error)
2. Identify the failure phase: **Extract**, **Process**, or **Load**
3. For Extract failures: check source connectivity, credentials, and permissions
4. For Process failures: check for schema conflicts or data type issues
5. For Load failures: check destination connectivity, permissions, and capacity
6. Review Fivetran's connector-specific troubleshooting documentation
7. If unresolved, open a Fivetran support ticket with the connector ID and error details

### Automatic Retry Behavior

Fivetran retries failed syncs automatically on a progressive schedule:

| Time Window | Retry Frequency |
|---|---|
| 0-24 hours | At the configured sync frequency |
| 24-72 hours | At the configured sync frequency |
| 72 hours - 14 days | Daily |
| After 14 days | Connection paused automatically |

Investigate failures promptly -- do not rely on auto-retry for persistent issues. A connector paused after 14 days of failures requires manual intervention and re-sync.

## Connector Issues

### Connector Not Retrieving Data

**Symptoms**: Sync completes successfully but expected data is missing.

**Diagnostic steps**:

1. Verify the table/column is enabled in the connector schema configuration
2. Check that the source account has data in the expected tables (empty source tables cannot be configured in Fivetran)
3. For API-based connectors, verify the connected account has access to the expected records (e.g., Salesforce user profile permissions)
4. Check if the connector's API scope includes the required data endpoints
5. Review whether data filters or date ranges are configured on the connector

### Connector Paused Unexpectedly

**Possible causes**:

- 14 consecutive days of sync failures (auto-pause)
- Manual pause by another team member
- Billing issue (MAR overage, expired plan)
- Fivetran platform maintenance (rare)

**Resolution**: Check the connector status page for pause reason. Address the underlying issue. Resume the connector manually.

### Slow Connector Performance

**Diagnostic steps**:

1. Check sync duration trends in the Sync History chart -- look for gradual or sudden increases
2. Verify source system performance (API response times, database query performance)
3. Check if new tables or columns were recently added to the schema (increases sync scope)
4. For database connectors, confirm that log-based CDC is enabled rather than full table scans
5. Review whether the source API is being throttled (check for 429 responses)
6. For HVA connectors, check agent resource utilization (CPU, memory, disk I/O)

### Initial Sync Taking Too Long

**Expectations**: Historical syncs for large tables can take hours to days. This is normal for multi-million-row tables.

**Optimization**:

- Deselect unnecessary tables and columns before starting the initial sync
- For databases, ensure primary keys are defined on all synced tables
- Consider HVA connectors for very large databases (compression reduces transfer time)
- Monitor sync progress in the dashboard -- Fivetran loads batches incrementally during historical sync

## Data Discrepancies

### Types of Data Discrepancies

| Type | Description | Detection Method |
|---|---|---|
| **Missing rows** | Rows in source but not destination | Row count comparison |
| **Extra rows** | Rows in destination not in source | Primary key comparison |
| **Stale data** | Destination data is outdated | Check `_fivetran_synced` vs source `updated_at` |
| **Wrong values** | Column values differ | Sample-based value comparison |
| **Missing columns** | Columns in source not in destination | Schema comparison |

### Common Root Causes

1. **Soft deletes vs hard deletes**: In soft delete mode, deleted rows remain with `_fivetran_deleted = TRUE`. Destination will have more rows than source. This is expected behavior.
2. **In-flight data**: During active syncing, source and destination will differ briefly. Compare only after sync completion.
3. **Schema change not propagated**: If schema handling is "Block all new data," new columns won't appear until manually approved.
4. **API pagination issues**: Some SaaS APIs have pagination quirks that can cause data gaps. Report to Fivetran support.
5. **Data type promotion**: When Fivetran promotes column types (e.g., integer to double), values may display differently (`42` vs `42.0`).
6. **Timezone differences**: Timestamp columns may differ if source and destination use different timezone conventions.

### Discrepancy Investigation Procedure

1. Confirm the sync completed successfully (no errors in sync history)
2. Check `_fivetran_synced` to confirm recent sync
3. For missing rows: verify rows exist in source and are not filtered by connector config
4. For extra rows: check `_fivetran_deleted = TRUE` -- these are soft-deleted (expected)
5. For value mismatches: check data type differences, timezone handling, or rounding
6. Compare at a time when no sync is actively running
7. For database sources with HVA: run HVR Compare for row-by-row validation
8. If discrepancy persists, contact Fivetran support with source and destination row samples

### Fivetran Metadata Columns for Diagnostics

| Column | Diagnostic Use |
|---|---|
| `_fivetran_synced` | When was this row last synced? Is data stale? |
| `_fivetran_deleted` | Was this row deleted at source? (soft delete mode) |
| `_fivetran_id` | System-generated PK -- used when source lacks a natural primary key |
| `_fivetran_start` | History mode: when did this version become active? |
| `_fivetran_end` | History mode: when was this version superseded? |
| `_fivetran_active` | History mode: is this the current version? |

```sql
-- Check data freshness per table
SELECT '_fivetran_synced' AS check_type,
       MIN(_fivetran_synced) AS oldest_sync,
       MAX(_fivetran_synced) AS newest_sync,
       DATEDIFF('hour', MIN(_fivetran_synced), MAX(_fivetran_synced)) AS sync_spread_hours
FROM raw_salesforce.opportunity;

-- Count soft-deleted rows
SELECT COUNT(*) AS total_rows,
       SUM(CASE WHEN _fivetran_deleted THEN 1 ELSE 0 END) AS deleted_rows,
       ROUND(100.0 * SUM(CASE WHEN _fivetran_deleted THEN 1 ELSE 0 END) / COUNT(*), 2) AS deleted_pct
FROM raw_salesforce.account;
```

## Schema Drift

### What Is Schema Drift

Schema drift occurs when the source system's schema changes -- tables added/removed, columns added/removed/renamed, or data types changed. Fivetran detects and handles most schema drift automatically, but some scenarios require attention.

### Schema Drift Detection

- **Automatic**: Fivetran detects changes during each sync and applies them per configured policy
- **Notifications**: Enable schema change alerts (email/webhook) for new tables or columns
- **Fivetran log**: Schema changes logged in the `fivetran_log` schema in the destination
- **API**: Query current schema configuration via REST API and compare against expected schema

### Common Schema Drift Scenarios

| Scenario | Net-Additive Behavior | Live Updating Behavior | Action Required |
|---|---|---|---|
| **Column added** | Added to destination | Added to destination | Update dbt models if needed |
| **Column removed** | Retained (NULL values) | Removed from destination | Update dbt models; check dependencies |
| **Column renamed** | Old retained (NULLs), new added | Old removed, new added | Update column references |
| **Table added** | Depends on change handling setting | Depends on change handling setting | Review and enable if needed |
| **Table removed** | Retained at destination | Removed from destination | Update downstream dependencies |
| **Type changed** | Promoted to inclusive type | Promoted to inclusive type | Verify downstream type expectations |

### Schema Drift Mitigation

1. **Use net-additive mode** in production to prevent accidental data loss
2. **Set schema handling to "Allow new columns"** for production -- prevents unexpected new tables while allowing safe additions
3. **Monitor schema change notifications** and review before enabling
4. **Version dbt models** and test against schema changes in staging
5. **Document expected schemas** and set up automated schema comparison tests (dbt schema tests)
6. **Use `_fivetran_synced`** to detect when schema changes take effect

### Downstream Impact

Schema drift affects dbt models, BI dashboards, and ML pipelines:

- **dbt models**: Column renames or removals break compilation. Use `dbt test` to catch issues.
- **BI dashboards**: Removed columns break visualizations. Review schema changes before they reach BI.
- **Data contracts**: Incorporate Fivetran schema change alerts into contract validation pipelines.

## Performance Diagnostics

### Slow Sync Diagnosis

**Step 1: Identify the bottleneck phase**

Review the Sync History chart -- each sync is broken into Extract, Process, and Load phases:

| Phase | What Happens | Common Bottleneck Causes |
|---|---|---|
| **Extract** | Data pulled from source | Source API rate limits, slow queries, network latency |
| **Process** | Data transformed and prepared | Large volumes, complex schema, type conversions |
| **Load** | Data written to destination | Warehouse performance, concurrent load contention |

**Step 2: Source-side diagnostics**

- Check source API response times or database query performance
- Verify log-based CDC is enabled for database connectors (avoids full table scans)
- Check if source system is under heavy load during sync windows
- Review API rate limit headers to confirm Fivetran is not being throttled

**Step 3: Destination-side diagnostics**

- Check destination warehouse compute capacity during load windows
- Verify warehouse auto-scaling is enabled (Snowflake, BigQuery)
- For row-based destinations (PostgreSQL, MySQL), ensure adequate indexing and vacuum scheduling
- Check for lock contention from concurrent writes or queries

### Teleport Sync

Alternative incremental sync method for databases when log-based CDC is slow due to high update volumes:

- Faster than full table snapshot syncing
- Limitations by database:
  - Oracle: Max 400 tables, max 15M rows per table
  - SQL Server: Max 800 tables, max 75M rows per table

### Performance Optimization Checklist

- [ ] Sync only required tables and columns (reduce data volume)
- [ ] Ensure primary keys are defined on all synced tables
- [ ] Use log-based CDC for database connectors where available
- [ ] Separate very large tables into dedicated connections
- [ ] Stagger sync schedules to avoid destination contention
- [ ] Monitor sync duration trends for gradual degradation
- [ ] For HVA: verify agent has adequate CPU, memory, and disk I/O
- [ ] For HVA: confirm data compression is active before transmission
- [ ] Ensure destination warehouse has adequate compute during load windows
- [ ] Review and optimize destination-side merge/upsert operations

### When to Escalate to Fivetran Support

- Sync duration increased >50% with no change in source data volume
- Syncs consistently fail at the same phase with non-actionable error messages
- Data discrepancies persist after re-sync
- HVA agent crashes or becomes unresponsive
- Connector behavior does not match documentation

Open a support ticket via the Fivetran dashboard with:
- Connector ID and destination ID
- Time range of the issue
- Error messages (exact text)
- Steps already taken to troubleshoot
- Source and destination types/versions
