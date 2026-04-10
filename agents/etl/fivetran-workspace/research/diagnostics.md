# Fivetran Diagnostics

## Sync Failures

### Identifying Sync Failures

1. **Dashboard**: Navigate to the connector's Status page. The Sync History chart shows failed syncs in red. Click "View error" for details including error cause and resolution steps.
2. **Notifications**: Email alerts are sent automatically for sync failures to the connector owner's email.
3. **Webhooks**: Configure webhooks to push sync failure events to Slack, PagerDuty, or custom endpoints.
4. **API**: Query the REST API for connector sync status and error details programmatically.

### Automatic Retry Behavior

Fivetran retries failed syncs automatically on a progressive schedule:

| Time Window | Retry Frequency |
|---|---|
| 0-24 hours | At the configured sync frequency |
| 24-72 hours | At the configured sync frequency |
| 72 hours - 14 days | Daily |
| After 14 days | Connection paused automatically |

Investigate failures promptly -- do not rely on auto-retry for persistent issues.

### Common Sync Failure Categories

| Category | Symptoms | Root Cause | Resolution |
|---|---|---|---|
| **Authentication failure** | "Access denied" or "401 Unauthorized" | Expired token, revoked API key, password change | Refresh OAuth token; update API key; re-authenticate connector |
| **Permission failure** | "Insufficient privileges" | Source account lacks required permissions | Grant necessary read permissions on source tables/API scopes |
| **Rate limiting** | "429 Too Many Requests", slow syncs | Sync frequency exceeds source API limits | Reduce sync frequency; contact source vendor for limit increase |
| **Network failure** | "Connection timed out", "Host unreachable" | Firewall blocking, VPN down, DNS issues | Verify network path; check firewall rules; validate SSH tunnel / PrivateLink |
| **Schema error** | "Sync failed due to schema definition changes" | Source schema changed during sync | Re-sync the connector; review schema change handling settings |
| **Destination error** | "Could not write to destination" | Destination warehouse down, out of storage, permission issue | Check destination health; verify Fivetran service account permissions |
| **Data type conflict** | "Cannot cast value" | Source data type incompatible with destination column | Review data type mapping; may require destination column alteration |

### Sync Failure Triage Procedure

1. Check the error message in the Fivetran dashboard (Status > Sync History > View error)
2. Identify the failure phase: Extract, Process, or Load
3. For Extract failures: check source connectivity, credentials, and permissions
4. For Process failures: check for schema conflicts or data type issues
5. For Load failures: check destination connectivity, permissions, and capacity
6. Review Fivetran's connector-specific troubleshooting documentation
7. If unresolved, open a Fivetran support ticket with the connector ID and error details

---

## Connector Issues

### Connector Not Retrieving Data

**Symptoms**: Sync completes successfully but expected data is missing.

**Diagnostic Steps**:

1. Verify the table/column is enabled in the connector schema configuration
2. Check that the source account has data in the expected tables (empty source tables cannot be configured in Fivetran)
3. For API-based connectors, verify the connected account has access to the expected records (e.g., Salesforce user profile permissions)
4. Check if the connector's API scope includes the required data endpoints
5. Review whether data filters or date ranges are configured on the connector

### Connector Paused Unexpectedly

**Possible Causes**:

- 14 consecutive days of sync failures (auto-pause)
- Manual pause by another team member
- Billing issue (MAR overage, expired plan)
- Fivetran platform maintenance (rare)

**Resolution**: Check the connector status page for pause reason. Address the underlying issue. Resume the connector manually.

### Slow Connector Performance

**Diagnostic Steps**:

1. Check sync duration trends in the Sync History chart -- look for gradual or sudden increases
2. Verify source system performance (API response times, database query performance)
3. Check if new tables or columns were recently added to the schema (increases sync scope)
4. For database connectors, confirm that log-based CDC is enabled rather than full table scans
5. Review whether the source API is being throttled
6. For HVA connectors, check agent resource utilization (CPU, memory, disk I/O)

### Initial Sync Taking Too Long

**Expectations**: Historical syncs for large tables can take hours to days. This is normal for multi-million-row tables.

**Optimization**:

- Deselect unnecessary tables and columns before starting the initial sync
- For databases, ensure primary keys are defined on all synced tables
- Consider HVA connectors for very large databases (compression reduces transfer time)
- Monitor the sync progress in the dashboard -- Fivetran loads batches incrementally during historical sync

---

## Data Discrepancies

### Types of Data Discrepancies

| Type | Description | Detection Method |
|---|---|---|
| **Missing rows** | Rows exist in source but not in destination | Row count comparison between source and destination |
| **Extra rows** | Rows in destination that no longer exist in source | Compare primary keys between source and destination |
| **Stale data** | Data in destination is outdated | Check `_fivetran_synced` timestamp against source `updated_at` |
| **Wrong values** | Column values differ between source and destination | Sample-based value comparison |
| **Missing columns** | Columns exist in source but not in destination | Schema comparison |

### Root Causes

1. **Soft deletes vs. hard deletes**: In soft delete mode, deleted rows remain in the destination with `_fivetran_deleted = TRUE`. This causes the destination to have more rows than the source. This is expected behavior.
2. **In-flight data**: During active syncing, there will always be a brief period where source and destination differ. Compare only after sync completion.
3. **Schema change not propagated**: If schema change handling is set to "Block all new data," new columns will not appear in the destination until manually approved.
4. **API pagination issues**: Some SaaS APIs have pagination quirks that can cause data gaps. Report to Fivetran support if suspected.
5. **Data type promotion**: When Fivetran promotes a column type (e.g., integer to double), existing values may display differently (e.g., `42` vs. `42.0`).
6. **Timezone differences**: Timestamp columns may differ if source and destination use different timezone conventions.
7. **Connector-specific limitations**: Some connectors do not sync all record types or have documented data coverage gaps.

### Discrepancy Investigation Procedure

1. Confirm the sync completed successfully (no errors in sync history)
2. Check the `_fivetran_synced` column to confirm the data was recently synced
3. For missing rows: verify the rows exist in the source and are not filtered by connector configuration
4. For extra rows: check if `_fivetran_deleted = TRUE` -- these are soft-deleted rows (expected)
5. For value mismatches: check for data type differences, timezone handling, or rounding
6. Compare at a time when no sync is actively running to avoid in-flight differences
7. For database sources with HVR: run HVR Compare (row-by-row) to identify persistent mismatches vs. in-flight differences
8. If discrepancy persists, contact Fivetran support with source and destination row samples

### Fivetran Metadata Columns

Use these system columns for diagnostics:

| Column | Purpose |
|---|---|
| `_fivetran_synced` | Timestamp when the row was last synced to the destination |
| `_fivetran_deleted` | Boolean indicating the row was deleted at the source (soft delete mode) |
| `_fivetran_id` | System-generated unique identifier (when source has no primary key) |
| `_fivetran_start` | History mode: timestamp when this version of the row became active |
| `_fivetran_end` | History mode: timestamp when this version of the row was superseded |
| `_fivetran_active` | History mode: boolean indicating whether this is the current version |

---

## Schema Drift

### What Is Schema Drift

Schema drift occurs when the source system's schema changes -- tables added/removed, columns added/removed/renamed, or data types changed. Fivetran automatically detects and handles most schema drift, but some scenarios require attention.

### Schema Drift Detection

- **Automatic detection**: Fivetran detects schema changes during each sync and applies them according to the configured schema change handling setting
- **Notifications**: Enable schema change notifications to receive alerts when new tables or columns are detected
- **Logging**: Schema changes are logged in Fivetran's platform connector logs and can be queried via the `fivetran_log` schema in the destination
- **API tracking**: Use the REST API to query current schema configuration and compare against expected schema

### Common Schema Drift Scenarios

| Scenario | Fivetran Behavior (Net-Additive) | Fivetran Behavior (Live Updating) | Action Required |
|---|---|---|---|
| **Column added at source** | Column added at destination | Column added at destination | Update dbt models if needed |
| **Column removed at source** | Column retained at destination (NULL values) | Column removed at destination | Update dbt models; check dependencies |
| **Column renamed at source** | Old column retained (NULLs), new column added | Old column removed, new column added | Update references to use new column name |
| **Table added at source** | Depends on schema change setting | Depends on schema change setting | Review and enable if needed |
| **Table removed at source** | Table retained at destination | Table removed at destination | Update downstream dependencies |
| **Data type changed at source** | Column promoted to more inclusive type | Column promoted to more inclusive type | Verify downstream type expectations |

### Schema Drift Mitigation

1. **Use net-additive mode** in production to prevent accidental data loss from upstream schema changes
2. **Set schema change handling to "Allow new columns"** for production connectors -- this prevents unexpected new tables while allowing column additions
3. **Monitor schema change notifications** and review new tables/columns before enabling them
4. **Version your dbt models** and test against schema changes in a staging environment before promoting to production
5. **Document expected schemas** and set up automated schema comparison tests (e.g., dbt schema tests)
6. **Use `_fivetran_synced`** to detect when schema changes take effect

### Schema Drift in Downstream Systems

Schema drift impacts downstream consumers (dbt models, BI dashboards, ML pipelines):

- **dbt models**: Column renames or removals can break model compilation. Use `dbt test` to catch issues early.
- **BI dashboards**: New columns may not auto-appear; removed columns can break visualizations. Establish a review process for schema changes.
- **Data contracts**: If your organization uses data contracts, incorporate Fivetran schema change alerts into the contract validation pipeline.

---

## Performance Diagnostics

### Slow Sync Diagnosis

**Step 1: Identify the bottleneck phase**

The Fivetran sync history chart breaks each sync into three phases:

| Phase | What Happens | Common Bottleneck Causes |
|---|---|---|
| **Extract** | Data pulled from source | Source API rate limits, slow database queries, network latency |
| **Process** | Data transformed and prepared | Large data volumes, complex schema, data type conversions |
| **Load** | Data written to destination | Destination warehouse performance, concurrent load contention |

**Step 2: Source-side diagnostics**

- Check source API response times or database query performance
- Verify that log-based CDC is enabled for database connectors (avoids full table scans)
- Check if source system is under heavy load during sync windows
- Review API rate limit headers to confirm Fivetran is not being throttled

**Step 3: Destination-side diagnostics**

- Check destination warehouse compute capacity during load windows
- Verify that warehouse auto-scaling is enabled (Snowflake, BigQuery)
- For row-based destinations (PostgreSQL, MySQL), ensure adequate indexing and vacuum scheduling
- Check for lock contention from concurrent writes or queries

### Teleport Sync

Fivetran Teleport Sync is an alternative incremental sync method for databases:

- Recommended when log-based CDC is slow or resource-intensive due to high update volumes
- Faster than full table snapshot syncing
- Limitations by database:
  - **Oracle**: Max 400 tables, max 15 million rows per table
  - **SQL Server**: Max 800 tables, max 75 million rows per table

### Performance Optimization Checklist

- [ ] Sync only required tables and columns (reduce data volume)
- [ ] Ensure primary keys are defined on all synced tables
- [ ] Use log-based CDC for database connectors where available
- [ ] Separate very large tables into dedicated connections
- [ ] Stagger sync schedules to avoid destination contention
- [ ] Monitor sync duration trends for gradual degradation
- [ ] For HVA connectors: verify agent has adequate CPU, memory, and disk I/O
- [ ] For HVA connectors: confirm data compression is active before network transmission
- [ ] Ensure destination warehouse has adequate compute resources during load windows
- [ ] Review and optimize destination-side merge/upsert operations

### When to Escalate to Fivetran Support

- Sync duration has increased by more than 50% with no change in source data volume
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
