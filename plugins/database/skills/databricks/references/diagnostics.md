# Databricks Diagnostics Reference

## Databricks CLI Commands

### Workspace

```bash
# List workspace contents
databricks workspace list /Users/user@company.com

# Export a notebook
databricks workspace export /Users/user@company.com/my_notebook --format SOURCE -o my_notebook.py

# Import a notebook
databricks workspace import my_notebook.py /Users/user@company.com/my_notebook --language PYTHON --overwrite

# Get workspace status (notebook metadata)
databricks workspace get-status /Users/user@company.com/my_notebook
```

### Clusters

```bash
# List all clusters
databricks clusters list --output JSON

# Get cluster details
databricks clusters get --cluster-id 0407-123456-abc123

# Get cluster events (start, terminate, resize, etc.)
databricks clusters events --cluster-id 0407-123456-abc123

# Start a terminated cluster
databricks clusters start --cluster-id 0407-123456-abc123

# Terminate a running cluster
databricks clusters delete --cluster-id 0407-123456-abc123

# Permanently delete a cluster
databricks clusters permanent-delete --cluster-id 0407-123456-abc123

# List available Spark versions
databricks clusters spark-versions

# List available node types
databricks clusters list-node-types

# Get cluster Spark configuration
databricks clusters get --cluster-id 0407-123456-abc123 | jq '.spark_conf'

# Check cluster driver logs (last 1MB)
databricks clusters get --cluster-id 0407-123456-abc123 | jq '.cluster_log_conf'
```

### Jobs and Workflows

```bash
# List all jobs
databricks jobs list --output JSON

# Get job definition
databricks jobs get --job-id 12345

# List runs for a job
databricks jobs list-runs --job-id 12345 --output JSON

# Get a specific run
databricks jobs get-run --run-id 67890

# Get run output
databricks jobs get-run-output --run-id 67890

# Trigger a job run
databricks jobs run-now --job-id 12345

# Trigger a job run with parameters
databricks jobs run-now --job-id 12345 --notebook-params '{"date": "2026-04-07"}'

# Cancel a running job run
databricks jobs cancel-run --run-id 67890

# Repair a failed run (re-run only failed tasks)
databricks jobs repair-run --run-id 67890 --rerun-tasks '["task_name_1", "task_name_2"]'

# Export a job definition
databricks jobs get --job-id 12345 > job_definition.json

# Create a job from definition
databricks jobs create --json @job_definition.json

# Reset (update) a job
databricks jobs reset --job-id 12345 --json @updated_job.json
```

### Unity Catalog

```bash
# List catalogs
databricks unity-catalog catalogs list

# Get catalog details
databricks unity-catalog catalogs get --name my_catalog

# List schemas in a catalog
databricks unity-catalog schemas list --catalog-name my_catalog

# Get schema details
databricks unity-catalog schemas get --full-name my_catalog.my_schema

# List tables in a schema
databricks unity-catalog tables list --catalog-name my_catalog --schema-name my_schema

# Get table details
databricks unity-catalog tables get --full-name my_catalog.my_schema.my_table

# List external locations
databricks unity-catalog external-locations list

# Get external location details
databricks unity-catalog external-locations get --name my_location

# List storage credentials
databricks unity-catalog storage-credentials list

# Get grants on an object
databricks unity-catalog permissions get securable-type TABLE --full-name my_catalog.my_schema.my_table

# List metastore summary
databricks unity-catalog metastores summary
```

### Secrets

```bash
# List secret scopes
databricks secrets list-scopes

# List secrets in a scope (names only -- values are never exposed)
databricks secrets list --scope my_scope

# Put a secret
databricks secrets put --scope my_scope --key my_secret --string-value "secret_value"

# Delete a secret
databricks secrets delete --scope my_scope --key my_secret

# Get secret scope ACLs
databricks secrets get-acl --scope my_scope --principal "user@company.com"

# List all ACLs for a scope
databricks secrets list-acls --scope my_scope
```

### SQL Warehouses

```bash
# List SQL warehouses
databricks warehouses list --output JSON

# Get warehouse details
databricks warehouses get --id abc123def456

# Start a warehouse
databricks warehouses start --id abc123def456

# Stop a warehouse
databricks warehouses stop --id abc123def456

# Get warehouse query history (via REST API)
curl -X GET "https://<workspace>/api/2.0/sql/history/queries" \
  -H "Authorization: Bearer <token>" \
  -d '{"filter_by": {"warehouse_ids": ["abc123def456"]}, "max_results": 50}'
```

## Delta Lake Diagnostic SQL

### DESCRIBE DETAIL -- Table Physical Layout

```sql
-- Get table storage details (file count, size, partition columns, etc.)
DESCRIBE DETAIL my_catalog.my_schema.my_table;
```

Key output fields:
| Field | Meaning | Concerning Values |
|---|---|---|
| `format` | Storage format | Should be `delta` |
| `location` | Cloud storage path | Unexpected path or location |
| `numFiles` | Number of active data files | > 10,000 suggests need for OPTIMIZE |
| `sizeInBytes` | Total data size | Compare against expected |
| `partitionColumns` | Hive partition columns | Non-empty for Hive-partitioned tables |
| `clusteringColumns` | Liquid Clustering columns | Empty if clustering not configured |
| `minReaderVersion` / `minWriterVersion` | Delta protocol version | v3/v7 needed for UniForm and DV |
| `properties` | Table properties | Check for CDF, auto-optimize settings |

### DESCRIBE HISTORY -- Transaction History

```sql
-- Full history (last 30 days by default)
DESCRIBE HISTORY my_catalog.my_schema.my_table;

-- Last N operations
DESCRIBE HISTORY my_catalog.my_schema.my_table LIMIT 20;
```

Key output fields:
| Field | Meaning | What to Look For |
|---|---|---|
| `version` | Commit version number | Gaps indicate deleted log files (corruption risk) |
| `timestamp` | When the commit happened | Large gaps between commits |
| `operation` | Type of operation (WRITE, MERGE, OPTIMIZE, DELETE, etc.) | Unexpected operations |
| `operationParameters` | Parameters used | Check merge conditions, predicate filters |
| `operationMetrics` | Rows written, files added/removed | Unusually large numbers of files |
| `userIdentity` | Who performed the operation | Unexpected users |
| `isBlindAppend` | Whether the write was append-only | `false` on MERGE/UPDATE/DELETE |

### DESCRIBE EXTENDED -- Full Column and Table Metadata

```sql
-- Full table metadata including column details
DESCRIBE TABLE EXTENDED my_catalog.my_schema.my_table;

-- Specific column detail
DESCRIBE TABLE my_catalog.my_schema.my_table col_name;
```

### SHOW TBLPROPERTIES -- Table Configuration

```sql
-- All properties
SHOW TBLPROPERTIES my_catalog.my_schema.my_table;

-- Specific property
SHOW TBLPROPERTIES my_catalog.my_schema.my_table ('delta.enableChangeDataFeed');
SHOW TBLPROPERTIES my_catalog.my_schema.my_table ('delta.minReaderVersion');
SHOW TBLPROPERTIES my_catalog.my_schema.my_table ('delta.minWriterVersion');
SHOW TBLPROPERTIES my_catalog.my_schema.my_table ('delta.autoOptimize.autoCompact');
SHOW TBLPROPERTIES my_catalog.my_schema.my_table ('delta.autoOptimize.optimizeWrite');
SHOW TBLPROPERTIES my_catalog.my_schema.my_table ('delta.targetFileSize');
SHOW TBLPROPERTIES my_catalog.my_schema.my_table ('delta.deletedFileRetentionDuration');
SHOW TBLPROPERTIES my_catalog.my_schema.my_table ('delta.enableDeletionVectors');
SHOW TBLPROPERTIES my_catalog.my_schema.my_table ('delta.universalFormat.enabledFormats');
SHOW TBLPROPERTIES my_catalog.my_schema.my_table ('delta.columnMapping.mode');
SHOW TBLPROPERTIES my_catalog.my_schema.my_table ('delta.feature.liquidClustering');
```

### Delta Table Health Check

```sql
-- File count and size distribution
SELECT
  COUNT(*) AS num_files,
  SUM(size) / (1024*1024*1024) AS total_size_gb,
  AVG(size) / (1024*1024) AS avg_file_size_mb,
  MIN(size) / (1024*1024) AS min_file_size_mb,
  MAX(size) / (1024*1024) AS max_file_size_mb,
  PERCENTILE(size, 0.5) / (1024*1024) AS median_file_size_mb,
  COUNT(CASE WHEN size < 1048576 THEN 1 END) AS files_under_1mb,
  COUNT(CASE WHEN size < 10485760 THEN 1 END) AS files_under_10mb,
  COUNT(CASE WHEN size > 1073741824 THEN 1 END) AS files_over_1gb
FROM (DESCRIBE DETAIL my_catalog.my_schema.my_table);
```

### OPTIMIZE Monitoring

```sql
-- Run OPTIMIZE and see results
OPTIMIZE my_catalog.my_schema.my_table;

-- OPTIMIZE with Liquid Clustering
OPTIMIZE my_catalog.my_schema.my_table;

-- OPTIMIZE with Z-ORDER (legacy tables)
OPTIMIZE my_catalog.my_schema.my_table ZORDER BY (user_id, event_type);

-- Check last OPTIMIZE operation from history
SELECT version, timestamp, operation, operationMetrics
FROM (DESCRIBE HISTORY my_catalog.my_schema.my_table)
WHERE operation = 'OPTIMIZE'
ORDER BY version DESC
LIMIT 5;

-- OPTIMIZE metrics to look for:
-- operationMetrics.numFilesAdded: new compacted files
-- operationMetrics.numFilesRemoved: old small files removed
-- operationMetrics.numBatches: number of compaction batches
```

### VACUUM Monitoring

```sql
-- Dry run: see which files would be deleted
VACUUM my_catalog.my_schema.my_table DRY RUN;

-- Run VACUUM with default retention (7 days)
VACUUM my_catalog.my_schema.my_table;

-- Run VACUUM with custom retention
VACUUM my_catalog.my_schema.my_table RETAIN 168 HOURS;

-- Check last VACUUM from history
SELECT version, timestamp, operation, operationMetrics
FROM (DESCRIBE HISTORY my_catalog.my_schema.my_table)
WHERE operation = 'VACUUM END' OR operation = 'VACUUM START'
ORDER BY version DESC
LIMIT 10;
```

### Time Travel and RESTORE

```sql
-- Query a specific version
SELECT * FROM my_catalog.my_schema.my_table VERSION AS OF 42;

-- Query by timestamp
SELECT * FROM my_catalog.my_schema.my_table TIMESTAMP AS OF '2026-04-01T00:00:00Z';

-- Compare two versions (row count diff)
SELECT
  (SELECT COUNT(*) FROM my_catalog.my_schema.my_table VERSION AS OF 100) AS count_v100,
  (SELECT COUNT(*) FROM my_catalog.my_schema.my_table VERSION AS OF 110) AS count_v110;

-- Restore to a previous version
RESTORE TABLE my_catalog.my_schema.my_table TO VERSION AS OF 42;

-- Restore to a timestamp
RESTORE TABLE my_catalog.my_schema.my_table TO TIMESTAMP AS OF '2026-04-01T00:00:00Z';
```

### CONVERT and GENERATE

```sql
-- Convert Parquet to Delta
CONVERT TO DELTA parquet.`s3://bucket/path/to/parquet_table`;

-- Convert Parquet with partitioning
CONVERT TO DELTA parquet.`s3://bucket/path/to/parquet_table`
PARTITIONED BY (date STRING, region STRING);

-- Convert Iceberg to Delta (UniForm reverse)
CONVERT TO DELTA iceberg.`s3://bucket/path/to/iceberg_table`;

-- Generate a symlink manifest for Presto/Athena compatibility
GENERATE symlink_format_manifest FOR TABLE my_catalog.my_schema.my_table;
```

### Change Data Feed

```sql
-- Read changes between versions
SELECT * FROM table_changes('my_catalog.my_schema.my_table', 5, 10);

-- Read changes by timestamp
SELECT * FROM table_changes('my_catalog.my_schema.my_table', '2026-04-01', '2026-04-07');

-- Summarize changes by type
SELECT
  _change_type,
  COUNT(*) AS row_count,
  MIN(_commit_version) AS min_version,
  MAX(_commit_version) AS max_version
FROM table_changes('my_catalog.my_schema.my_table', 5)
GROUP BY _change_type;

-- Check if CDF is enabled
SHOW TBLPROPERTIES my_catalog.my_schema.my_table ('delta.enableChangeDataFeed');
```

## Unity Catalog Diagnostic Queries

### information_schema -- Metadata Discovery

```sql
-- List all catalogs accessible to current user
SELECT * FROM system.information_schema.catalogs;

-- List all schemas in a catalog
SELECT * FROM my_catalog.information_schema.schemata;

-- List all tables in a catalog with metadata
SELECT
  table_catalog, table_schema, table_name, table_type,
  created, created_by, last_altered, last_altered_by,
  comment
FROM my_catalog.information_schema.tables
ORDER BY table_schema, table_name;

-- List columns for a specific table
SELECT
  column_name, data_type, is_nullable, column_default, comment
FROM my_catalog.information_schema.columns
WHERE table_schema = 'my_schema' AND table_name = 'my_table'
ORDER BY ordinal_position;

-- Find tables by name pattern
SELECT table_catalog, table_schema, table_name
FROM system.information_schema.tables
WHERE table_name LIKE '%events%';

-- List all views
SELECT table_catalog, table_schema, table_name, view_definition
FROM my_catalog.information_schema.views;

-- List all grants (table-level)
SELECT * FROM my_catalog.information_schema.table_privileges
WHERE table_name = 'my_table';

-- List all grants (schema-level)
SELECT * FROM my_catalog.information_schema.schema_privileges
WHERE schema_name = 'my_schema';

-- List all grants (catalog-level)
SELECT * FROM system.information_schema.catalog_privileges
WHERE catalog_name = 'my_catalog';
```

### SHOW GRANTS -- Permission Diagnostics

```sql
-- Show grants on a table
SHOW GRANTS ON TABLE my_catalog.my_schema.my_table;

-- Show grants on a schema
SHOW GRANTS ON SCHEMA my_catalog.my_schema;

-- Show grants on a catalog
SHOW GRANTS ON CATALOG my_catalog;

-- Show grants for a specific principal
SHOW GRANTS `user@company.com` ON TABLE my_catalog.my_schema.my_table;
SHOW GRANTS `data-engineers` ON SCHEMA my_catalog.my_schema;

-- Show grants on an external location
SHOW GRANTS ON EXTERNAL LOCATION my_location;

-- Show grants on a storage credential
SHOW GRANTS ON STORAGE CREDENTIAL my_cred;

-- Show grants on a share
SHOW GRANTS ON SHARE my_share;

-- Show current user's identity
SELECT current_user(), is_account_group_member('admins');
```

### system.access -- Audit and Lineage

```sql
-- Recent audit events (last 24 hours)
SELECT
  event_time, event_type, action_name,
  request_params, response, user_identity.email
FROM system.access.audit
WHERE event_time > DATEADD(HOUR, -24, CURRENT_TIMESTAMP())
ORDER BY event_time DESC
LIMIT 100;

-- Unity Catalog permission changes
SELECT
  event_time, action_name, request_params, user_identity.email
FROM system.access.audit
WHERE action_name IN (
  'grantPermission', 'revokePermission', 'updatePermissions'
)
AND event_time > DATEADD(DAY, -7, CURRENT_TIMESTAMP())
ORDER BY event_time DESC;

-- Table access audit
SELECT
  event_time, action_name, request_params.full_name_arg AS table_name,
  user_identity.email, source_ip_address
FROM system.access.audit
WHERE action_name IN ('getTable', 'createTable', 'deleteTable')
AND event_time > DATEADD(DAY, -7, CURRENT_TIMESTAMP())
ORDER BY event_time DESC;

-- Table-level lineage
SELECT
  source_table_full_name,
  target_table_full_name,
  source_type,
  target_type,
  event_time
FROM system.access.table_lineage
WHERE target_table_full_name = 'my_catalog.my_schema.my_table'
ORDER BY event_time DESC;

-- Column-level lineage
SELECT
  source_table_full_name, source_column_name,
  target_table_full_name, target_column_name,
  event_time
FROM system.access.column_lineage
WHERE target_table_full_name = 'my_catalog.my_schema.my_table'
ORDER BY event_time DESC;

-- Find all tables downstream of a source table
SELECT DISTINCT target_table_full_name
FROM system.access.table_lineage
WHERE source_table_full_name = 'my_catalog.my_schema.source_table';

-- Find all tables upstream of a target table
SELECT DISTINCT source_table_full_name
FROM system.access.table_lineage
WHERE target_table_full_name = 'my_catalog.my_schema.target_table';
```

## System Tables -- Billing and Cost Analysis

### system.billing.usage -- DBU Consumption

```sql
-- Daily DBU usage by SKU (last 30 days)
SELECT
  usage_date,
  sku_name,
  SUM(usage_quantity) AS total_dbus
FROM system.billing.usage
WHERE usage_date >= DATEADD(DAY, -30, CURRENT_DATE())
GROUP BY usage_date, sku_name
ORDER BY usage_date DESC, total_dbus DESC;

-- DBU usage by workspace
SELECT
  workspace_id,
  sku_name,
  SUM(usage_quantity) AS total_dbus
FROM system.billing.usage
WHERE usage_date >= DATEADD(DAY, -30, CURRENT_DATE())
GROUP BY workspace_id, sku_name
ORDER BY total_dbus DESC;

-- DBU usage by cluster (top consumers)
SELECT
  usage_metadata.cluster_id,
  sku_name,
  SUM(usage_quantity) AS total_dbus
FROM system.billing.usage
WHERE usage_date >= DATEADD(DAY, -7, CURRENT_DATE())
AND usage_metadata.cluster_id IS NOT NULL
GROUP BY usage_metadata.cluster_id, sku_name
ORDER BY total_dbus DESC
LIMIT 20;

-- DBU usage by job (top consumers)
SELECT
  usage_metadata.job_id,
  sku_name,
  SUM(usage_quantity) AS total_dbus
FROM system.billing.usage
WHERE usage_date >= DATEADD(DAY, -7, CURRENT_DATE())
AND usage_metadata.job_id IS NOT NULL
GROUP BY usage_metadata.job_id, sku_name
ORDER BY total_dbus DESC
LIMIT 20;

-- Estimated cost (join with list prices)
SELECT
  u.usage_date,
  u.sku_name,
  SUM(u.usage_quantity) AS total_dbus,
  SUM(u.usage_quantity * p.pricing.default) AS estimated_list_cost
FROM system.billing.usage u
JOIN system.billing.list_prices p
  ON u.cloud = p.cloud
  AND u.sku_name = p.sku_name
  AND u.usage_unit = p.usage_unit
  AND u.usage_date BETWEEN p.price_start_time AND COALESCE(p.price_end_time, '2099-12-31')
WHERE u.usage_date >= DATEADD(DAY, -30, CURRENT_DATE())
GROUP BY u.usage_date, u.sku_name
ORDER BY u.usage_date DESC, estimated_list_cost DESC;

-- Week-over-week cost comparison
WITH weekly AS (
  SELECT
    DATE_TRUNC('WEEK', usage_date) AS week_start,
    sku_name,
    SUM(usage_quantity) AS total_dbus
  FROM system.billing.usage
  WHERE usage_date >= DATEADD(WEEK, -8, CURRENT_DATE())
  GROUP BY DATE_TRUNC('WEEK', usage_date), sku_name
)
SELECT
  w1.week_start AS current_week,
  w1.sku_name,
  w1.total_dbus AS current_dbus,
  w2.total_dbus AS prev_week_dbus,
  ROUND((w1.total_dbus - w2.total_dbus) / w2.total_dbus * 100, 1) AS pct_change
FROM weekly w1
LEFT JOIN weekly w2
  ON w1.sku_name = w2.sku_name
  AND w2.week_start = DATEADD(WEEK, -1, w1.week_start)
WHERE w1.week_start = DATE_TRUNC('WEEK', CURRENT_DATE())
ORDER BY w1.total_dbus DESC;

-- Serverless SQL warehouse usage
SELECT
  usage_date,
  usage_metadata.warehouse_id,
  SUM(usage_quantity) AS total_dbus
FROM system.billing.usage
WHERE sku_name LIKE '%SQL%SERVERLESS%'
AND usage_date >= DATEADD(DAY, -7, CURRENT_DATE())
GROUP BY usage_date, usage_metadata.warehouse_id
ORDER BY usage_date DESC, total_dbus DESC;
```

### system.billing.list_prices -- Pricing Reference

```sql
-- All current list prices
SELECT
  sku_name, cloud, currency_code, usage_unit,
  pricing.default AS list_price_per_dbu
FROM system.billing.list_prices
WHERE price_end_time IS NULL
ORDER BY sku_name;

-- Compare serverless vs classic pricing
SELECT
  sku_name,
  pricing.default AS list_price
FROM system.billing.list_prices
WHERE price_end_time IS NULL
AND (sku_name LIKE '%SERVERLESS%' OR sku_name LIKE '%ALL_PURPOSE%' OR sku_name LIKE '%JOBS%')
ORDER BY sku_name;
```

## System Tables -- Compute Monitoring

### system.compute.clusters

```sql
-- All clusters with metadata
SELECT
  cluster_id, cluster_name, cluster_source,
  creator, single_user_name,
  driver_node_type, worker_node_type,
  autoscale_min_workers, autoscale_max_workers,
  num_workers,
  autotermination_minutes,
  spark_version,
  state, state_message,
  start_time, terminated_time
FROM system.compute.clusters
ORDER BY start_time DESC
LIMIT 50;

-- Long-running interactive clusters (cost concern)
SELECT
  cluster_id, cluster_name, creator,
  start_time,
  TIMESTAMPDIFF(HOUR, start_time, COALESCE(terminated_time, CURRENT_TIMESTAMP())) AS hours_running,
  autotermination_minutes
FROM system.compute.clusters
WHERE cluster_source = 'UI' OR cluster_source = 'API'
AND (terminated_time IS NULL OR TIMESTAMPDIFF(HOUR, start_time, terminated_time) > 8)
AND start_time >= DATEADD(DAY, -7, CURRENT_TIMESTAMP())
ORDER BY hours_running DESC;

-- Clusters without auto-termination
SELECT cluster_id, cluster_name, creator, autotermination_minutes
FROM system.compute.clusters
WHERE autotermination_minutes IS NULL OR autotermination_minutes = 0;

-- Cluster configurations using expensive instance types
SELECT cluster_id, cluster_name, driver_node_type, worker_node_type, num_workers
FROM system.compute.clusters
WHERE worker_node_type LIKE '%gpu%' OR worker_node_type LIKE '%metal%'
ORDER BY start_time DESC;
```

### system.compute.warehouse_events

```sql
-- SQL warehouse scaling events (last 7 days)
SELECT
  warehouse_id, event_type, event_time,
  cluster_count
FROM system.compute.warehouse_events
WHERE event_time >= DATEADD(DAY, -7, CURRENT_TIMESTAMP())
ORDER BY event_time DESC;

-- Warehouse uptime analysis
SELECT
  warehouse_id,
  COUNT(CASE WHEN event_type = 'STARTING' THEN 1 END) AS start_count,
  COUNT(CASE WHEN event_type = 'STOPPED' THEN 1 END) AS stop_count,
  COUNT(CASE WHEN event_type = 'SCALING_UP' THEN 1 END) AS scale_up_count,
  COUNT(CASE WHEN event_type = 'SCALING_DOWN' THEN 1 END) AS scale_down_count
FROM system.compute.warehouse_events
WHERE event_time >= DATEADD(DAY, -7, CURRENT_TIMESTAMP())
GROUP BY warehouse_id;
```

## System Tables -- Query Performance

### system.query.history

```sql
-- Slowest queries (last 24 hours)
SELECT
  query_id, query_text, user_name,
  warehouse_id,
  execution_status,
  total_duration_ms,
  rows_produced,
  bytes_read,
  bytes_written
FROM system.query.history
WHERE start_time >= DATEADD(HOUR, -24, CURRENT_TIMESTAMP())
AND execution_status = 'FINISHED'
ORDER BY total_duration_ms DESC
LIMIT 20;

-- Failed queries (last 24 hours)
SELECT
  query_id, query_text, user_name,
  error_message,
  start_time
FROM system.query.history
WHERE start_time >= DATEADD(HOUR, -24, CURRENT_TIMESTAMP())
AND execution_status = 'FAILED'
ORDER BY start_time DESC
LIMIT 20;

-- Query volume by user
SELECT
  user_name,
  COUNT(*) AS query_count,
  AVG(total_duration_ms) AS avg_duration_ms,
  SUM(bytes_read) / (1024*1024*1024) AS total_gb_read
FROM system.query.history
WHERE start_time >= DATEADD(DAY, -7, CURRENT_TIMESTAMP())
GROUP BY user_name
ORDER BY query_count DESC;

-- Query volume by warehouse
SELECT
  warehouse_id,
  COUNT(*) AS query_count,
  AVG(total_duration_ms) AS avg_duration_ms,
  PERCENTILE(total_duration_ms, 0.95) AS p95_duration_ms,
  SUM(bytes_read) / (1024*1024*1024) AS total_gb_read
FROM system.query.history
WHERE start_time >= DATEADD(DAY, -7, CURRENT_TIMESTAMP())
AND execution_status = 'FINISHED'
GROUP BY warehouse_id
ORDER BY query_count DESC;
```

## Workflow Monitoring

### system.lakeflow.job_run_timeline

```sql
-- Recent job runs
SELECT
  job_id, run_id, run_name,
  result_state, start_time, end_time,
  TIMESTAMPDIFF(SECOND, start_time, end_time) AS duration_seconds
FROM system.lakeflow.job_run_timeline
WHERE start_time >= DATEADD(DAY, -1, CURRENT_TIMESTAMP())
ORDER BY start_time DESC
LIMIT 50;

-- Failed job runs (last 7 days)
SELECT
  job_id, run_id, run_name,
  result_state, start_time,
  TIMESTAMPDIFF(SECOND, start_time, end_time) AS duration_seconds
FROM system.lakeflow.job_run_timeline
WHERE result_state IN ('FAILED', 'TIMED_OUT', 'CANCELED')
AND start_time >= DATEADD(DAY, -7, CURRENT_TIMESTAMP())
ORDER BY start_time DESC;

-- Job duration trends (avg duration over time)
SELECT
  job_id,
  DATE(start_time) AS run_date,
  COUNT(*) AS run_count,
  AVG(TIMESTAMPDIFF(SECOND, start_time, end_time)) AS avg_duration_sec,
  MAX(TIMESTAMPDIFF(SECOND, start_time, end_time)) AS max_duration_sec
FROM system.lakeflow.job_run_timeline
WHERE result_state = 'SUCCESS'
AND start_time >= DATEADD(DAY, -30, CURRENT_TIMESTAMP())
GROUP BY job_id, DATE(start_time)
ORDER BY job_id, run_date DESC;

-- Most frequently failing jobs
SELECT
  job_id,
  COUNT(*) AS total_runs,
  COUNT(CASE WHEN result_state = 'FAILED' THEN 1 END) AS failed_runs,
  ROUND(COUNT(CASE WHEN result_state = 'FAILED' THEN 1 END) * 100.0 / COUNT(*), 1) AS failure_rate_pct
FROM system.lakeflow.job_run_timeline
WHERE start_time >= DATEADD(DAY, -7, CURRENT_TIMESTAMP())
GROUP BY job_id
HAVING COUNT(CASE WHEN result_state = 'FAILED' THEN 1 END) > 0
ORDER BY failure_rate_pct DESC;
```

### Delta Live Tables Pipeline Events

```sql
-- DLT pipeline events (last 24 hours)
SELECT
  id, event_type, timestamp, message, level,
  maturity_level, error
FROM system.lakeflow.pipeline_event_log
WHERE timestamp >= DATEADD(HOUR, -24, CURRENT_TIMESTAMP())
ORDER BY timestamp DESC
LIMIT 100;

-- DLT data quality expectation results
SELECT
  timestamp, dataset, name AS expectation_name,
  passed_records, failed_records,
  ROUND(failed_records * 100.0 / (passed_records + failed_records), 2) AS failure_rate_pct
FROM system.lakeflow.pipeline_event_log
WHERE event_type = 'flow_progress'
AND timestamp >= DATEADD(DAY, -7, CURRENT_TIMESTAMP())
ORDER BY timestamp DESC;
```

## Performance Tuning Queries

### Explain Plans

```sql
-- Basic explain
EXPLAIN SELECT * FROM my_catalog.my_schema.orders WHERE region = 'US';

-- Extended explain (includes physical and logical plans)
EXPLAIN EXTENDED SELECT * FROM my_catalog.my_schema.orders WHERE region = 'US';

-- Formatted explain (tree format, easier to read)
EXPLAIN FORMATTED SELECT * FROM my_catalog.my_schema.orders WHERE region = 'US';

-- Cost-based explain
EXPLAIN COST SELECT * FROM my_catalog.my_schema.orders o
JOIN my_catalog.my_schema.customers c ON o.customer_id = c.customer_id
WHERE o.order_date > '2026-01-01';
```

### Statistics Management

```sql
-- Collect table statistics
ANALYZE TABLE my_catalog.my_schema.orders COMPUTE STATISTICS;

-- Collect column-level statistics
ANALYZE TABLE my_catalog.my_schema.orders COMPUTE STATISTICS FOR COLUMNS
  order_id, customer_id, order_date, region, total_amount;

-- Collect statistics for all columns
ANALYZE TABLE my_catalog.my_schema.orders COMPUTE STATISTICS FOR ALL COLUMNS;

-- View table statistics
DESCRIBE TABLE EXTENDED my_catalog.my_schema.orders;

-- Check if statistics are up to date (compare numRows in stats vs actual)
SELECT
  (SELECT COUNT(*) FROM my_catalog.my_schema.orders) AS actual_rows;
-- Compare with numRows in DESCRIBE EXTENDED output
```

### AQE and Shuffle Diagnostics

```sql
-- Check AQE settings (run in notebook)
SET spark.sql.adaptive.enabled;
SET spark.sql.adaptive.coalescePartitions.enabled;
SET spark.sql.adaptive.skewJoin.enabled;
SET spark.sql.adaptive.skewJoin.skewedPartitionFactor;
SET spark.sql.adaptive.skewJoin.skewedPartitionThresholdInBytes;
SET spark.sql.shuffle.partitions;
SET spark.sql.autoBroadcastJoinThreshold;

-- Check Photon status
SET spark.databricks.photon.enabled;

-- Check data skipping stats indexed columns
SET spark.databricks.delta.properties.defaults.dataSkippingNumIndexedCols;
```

### Spark Configuration Diagnostics

```sql
-- View all Spark SQL configuration
SET -v;

-- View all spark.databricks.* configurations
SET spark.databricks;

-- Check Delta Lake specific settings
SET spark.databricks.delta;

-- Key settings to check
SET spark.sql.files.maxPartitionBytes;
SET spark.sql.files.openCostInBytes;
SET spark.databricks.delta.optimizeWrite.enabled;
SET spark.databricks.delta.autoCompact.enabled;
SET spark.sql.adaptive.advisoryPartitionSizeInBytes;
```

## Cluster and Spark UI Diagnostics

### Spark UI Metrics (via UI or REST API)

```python
# Access Spark UI metrics programmatically from a notebook
spark_ui_url = spark.sparkContext.uiWebUrl

# Active jobs
spark.sparkContext.statusTracker.getActiveJobIds()

# Active stages
spark.sparkContext.statusTracker.getActiveStageIds()

# Executor info
print(f"Executors: {spark.sparkContext._jsc.sc().getExecutorMemoryStatus().size()}")

# Configuration dump
for k, v in sorted(spark.sparkContext.getConf().getAll()):
    print(f"{k} = {v}")
```

### Driver Log Analysis

```python
# Check driver memory usage
import os
import psutil

process = psutil.Process(os.getpid())
print(f"Driver RSS: {process.memory_info().rss / 1024 / 1024:.0f} MB")
print(f"Driver VMS: {process.memory_info().vms / 1024 / 1024:.0f} MB")

# Check JVM memory (via py4j)
runtime = spark.sparkContext._jvm.Runtime.getRuntime()
print(f"JVM Total: {runtime.totalMemory() / 1024 / 1024:.0f} MB")
print(f"JVM Free:  {runtime.freeMemory() / 1024 / 1024:.0f} MB")
print(f"JVM Max:   {runtime.maxMemory() / 1024 / 1024:.0f} MB")
print(f"JVM Used:  {(runtime.totalMemory() - runtime.freeMemory()) / 1024 / 1024:.0f} MB")
```

### Ganglia Metrics

Ganglia is available on classic clusters (non-serverless) via the cluster UI > Metrics tab:

Key metrics to monitor:
| Metric | What It Shows | Concerning Values |
|---|---|---|
| CPU usage (%) | Overall CPU utilization across all nodes | Sustained > 90% (compute-bound), < 10% (idle/IO-bound) |
| Memory usage | JVM heap and off-heap usage | Near max (OOM risk), consistently low (over-provisioned) |
| Network I/O | Bytes sent/received per node | Spikes during shuffle; sustained high = shuffle bottleneck |
| Disk I/O | Read/write throughput per node | High write = shuffle spill to disk (needs more memory) |
| GC time | JVM garbage collection time | > 10% of total time = memory pressure |
| Shuffle read/write | Bytes shuffled | Large shuffle = consider repartitioning or broadcast joins |

## REST API Diagnostic Endpoints

### Clusters API

```bash
# Get cluster details
curl -X GET "https://<workspace>/api/2.0/clusters/get" \
  -H "Authorization: Bearer <token>" \
  -d '{"cluster_id": "0407-123456-abc123"}'

# List cluster events
curl -X POST "https://<workspace>/api/2.0/clusters/events" \
  -H "Authorization: Bearer <token>" \
  -d '{"cluster_id": "0407-123456-abc123", "limit": 50}'

# Get cluster Spark logs
curl -X GET "https://<workspace>/api/2.0/clusters/get" \
  -H "Authorization: Bearer <token>" \
  -d '{"cluster_id": "0407-123456-abc123"}' | jq '.driver_logs'
```

### Jobs API

```bash
# List all runs for a job
curl -X GET "https://<workspace>/api/2.1/jobs/runs/list" \
  -H "Authorization: Bearer <token>" \
  -d '{"job_id": 12345, "limit": 25}'

# Get run details including task outputs
curl -X GET "https://<workspace>/api/2.1/jobs/runs/get" \
  -H "Authorization: Bearer <token>" \
  -d '{"run_id": 67890}'

# Get run output (for notebook tasks)
curl -X GET "https://<workspace>/api/2.1/jobs/runs/get-output" \
  -H "Authorization: Bearer <token>" \
  -d '{"run_id": 67890}'

# Export run (get the full run with all task results)
curl -X GET "https://<workspace>/api/2.1/jobs/runs/export" \
  -H "Authorization: Bearer <token>" \
  -d '{"run_id": 67890}'
```

### SQL Statement Execution API

```bash
# Execute a SQL statement
curl -X POST "https://<workspace>/api/2.0/sql/statements" \
  -H "Authorization: Bearer <token>" \
  -d '{
    "warehouse_id": "abc123def456",
    "statement": "SELECT COUNT(*) FROM my_catalog.my_schema.my_table",
    "wait_timeout": "30s"
  }'

# Get statement execution status
curl -X GET "https://<workspace>/api/2.0/sql/statements/<statement_id>" \
  -H "Authorization: Bearer <token>"

# Cancel a running statement
curl -X POST "https://<workspace>/api/2.0/sql/statements/<statement_id>/cancel" \
  -H "Authorization: Bearer <token>"
```

### Unity Catalog API

```bash
# List catalogs
curl -X GET "https://<workspace>/api/2.1/unity-catalog/catalogs" \
  -H "Authorization: Bearer <token>"

# Get table metadata
curl -X GET "https://<workspace>/api/2.1/unity-catalog/tables/my_catalog.my_schema.my_table" \
  -H "Authorization: Bearer <token>"

# List grants on a table
curl -X GET "https://<workspace>/api/2.1/unity-catalog/permissions/table/my_catalog.my_schema.my_table" \
  -H "Authorization: Bearer <token>"

# Get lineage for a table
curl -X GET "https://<workspace>/api/2.0/lineage-tracking/table-lineage" \
  -H "Authorization: Bearer <token>" \
  -d '{"table_name": "my_catalog.my_schema.my_table"}'
```

### Serving Endpoints API

```bash
# List model serving endpoints
curl -X GET "https://<workspace>/api/2.0/serving-endpoints" \
  -H "Authorization: Bearer <token>"

# Get endpoint details (includes config, state, traffic)
curl -X GET "https://<workspace>/api/2.0/serving-endpoints/<endpoint_name>" \
  -H "Authorization: Bearer <token>"

# Query a serving endpoint
curl -X POST "https://<workspace>/serving-endpoints/<endpoint_name>/invocations" \
  -H "Authorization: Bearer <token>" \
  -d '{"dataframe_records": [{"feature1": 1.0, "feature2": "value"}]}'
```

## Troubleshooting Playbooks

### Playbook: Slow Query Investigation

```
1. EXPLAIN EXTENDED <query>
   -> Check for full table scans (FileScan with no pushed filters)
   -> Check join strategies (BroadcastHashJoin vs SortMergeJoin)
   -> Check for skew warnings

2. DESCRIBE DETAIL <table>
   -> Check numFiles (too many? run OPTIMIZE)
   -> Check sizeInBytes (table size reasonable?)
   -> Check clusteringColumns (is clustering configured?)

3. DESCRIBE HISTORY <table> LIMIT 10
   -> When was last OPTIMIZE? Last VACUUM?
   -> Any recent schema changes?

4. Check Spark UI
   -> Stages tab: look for skewed tasks (one task taking 10x longer)
   -> SQL tab: look for data-skipping effectiveness (files pruned vs scanned)
   -> Storage tab: check cached data

5. Remediation:
   a. Run OPTIMIZE if file count is high
   b. Add/change Liquid Clustering columns for better data-skipping
   c. Collect statistics: ANALYZE TABLE ... COMPUTE STATISTICS FOR ALL COLUMNS
   d. Enable Photon if not already enabled
   e. Consider broadcasting small dimension tables
   f. Check AQE settings
```

### Playbook: Cluster OOM Investigation

```
1. Check Spark UI -> Stages -> Failed stage
   -> Find the task that failed with OOM
   -> Check input data size for that task vs others (data skew?)

2. Check Ganglia metrics
   -> Memory usage trend: gradual increase = memory leak / unbounded state
   -> GC time: high GC = heap too small

3. Check for common OOM causes:
   a. collect() or toPandas() on large DataFrame -> switch to distributed write
   b. Broadcast join on large table -> increase threshold or force sort-merge
   c. Shuffle partition skew -> enable AQE skew join
   d. Window function over unbounded partition -> add partition key
   e. PySpark UDF accumulating data -> use pandas_udf with Arrow
   f. Driver OOM -> increase spark.driver.memory

4. Check executor memory settings:
   SET spark.executor.memory;
   SET spark.executor.memoryOverhead;
   SET spark.memory.fraction;

5. Remediation:
   a. Increase worker memory (larger instance type)
   b. Increase shuffle partitions: SET spark.sql.shuffle.partitions = 1000
   c. Enable AQE skew join
   d. Repartition data before expensive operations
   e. Use salting for skew joins
   f. Increase driver memory for driver OOM
```

### Playbook: Streaming Lag Investigation

```
1. Check streaming query progress (in notebook):
   for q in spark.streams.active:
       print(q.name, q.lastProgress)

   -> Compare inputRowsPerSecond vs processedRowsPerSecond
   -> Check triggerExecution time breakdown

2. Check checkpoint directory for backlog:
   dbutils.fs.ls("/checkpoints/<query>/offsets/")
   dbutils.fs.ls("/checkpoints/<query>/commits/")
   -> Gap between latest offset and latest commit = unprocessed batches

3. Check for stateful operation issues:
   -> State store size growing unboundedly (missing watermark?)
   -> State store GC not keeping up

4. Check source throughput:
   -> Kafka: consumer lag via Kafka admin tools
   -> Auto Loader: file notification backlog
   -> Delta CDF: check source table commit rate

5. Remediation:
   a. Increase cluster size (more executors/cores)
   b. Increase trigger interval to process larger batches
   c. Use trigger(availableNow=True) for catch-up
   d. Add watermarks for stateful operations
   e. Set maxFilesPerTrigger or maxOffsetsPerTrigger to control batch size
   f. Optimize downstream Delta write (enable optimized writes)
   g. Check for repartitioning/shuffle in stream -- minimize shuffles
```

### Playbook: Unity Catalog Permission Denied

```
1. Identify the error:
   -> "User does not have USAGE on catalog X" -> missing USAGE grant
   -> "User does not have SELECT on table X" -> missing SELECT grant
   -> "ACCESS_DENIED on external location" -> missing storage permission

2. Check the full privilege chain:
   SHOW GRANTS `user@company.com` ON CATALOG my_catalog;
   SHOW GRANTS `user@company.com` ON SCHEMA my_catalog.my_schema;
   SHOW GRANTS `user@company.com` ON TABLE my_catalog.my_schema.my_table;

3. Check group membership:
   SELECT * FROM system.information_schema.catalog_privileges
   WHERE grantee = 'user@company.com' OR grantee IN (SELECT group_name FROM ...);

4. Check external location and storage credential (for external tables):
   SHOW GRANTS ON EXTERNAL LOCATION my_location;
   SHOW GRANTS ON STORAGE CREDENTIAL my_cred;

5. Check row filter and column mask (for partial access):
   DESCRIBE TABLE EXTENDED my_catalog.my_schema.my_table;
   -> Look for row_filter and column_mask in output

6. Remediation:
   a. Grant USAGE on each level: GRANT USAGE ON CATALOG ... TO ...
   b. Grant specific privilege: GRANT SELECT ON TABLE ... TO ...
   c. Grant external location access: GRANT READ FILES ON EXTERNAL LOCATION ... TO ...
   d. Add user to appropriate group: databricks groups add-member ...
```

### Playbook: Cost Spike Investigation

```
1. Identify the cost driver:
   SELECT usage_date, sku_name, SUM(usage_quantity) AS dbus
   FROM system.billing.usage
   WHERE usage_date >= DATEADD(DAY, -14, CURRENT_DATE())
   GROUP BY usage_date, sku_name
   ORDER BY usage_date DESC, dbus DESC;

2. Drill into the spike date:
   SELECT usage_metadata.cluster_id, usage_metadata.job_id,
          SUM(usage_quantity) AS dbus
   FROM system.billing.usage
   WHERE usage_date = '<spike_date>'
   GROUP BY usage_metadata.cluster_id, usage_metadata.job_id
   ORDER BY dbus DESC
   LIMIT 20;

3. Check for idle interactive clusters:
   SELECT cluster_id, cluster_name, creator,
          TIMESTAMPDIFF(HOUR, start_time, COALESCE(terminated_time, CURRENT_TIMESTAMP())) AS hours
   FROM system.compute.clusters
   WHERE start_time >= DATEADD(DAY, -14, CURRENT_TIMESTAMP())
   AND cluster_source IN ('UI', 'API')
   ORDER BY hours DESC;

4. Check for jobs on expensive compute:
   SELECT job_id, run_id, cluster_type, compute_type
   FROM system.lakeflow.job_run_timeline
   WHERE start_time >= '<spike_date>'
   AND compute_type = 'ALL_PURPOSE';

5. Remediation:
   a. Enforce auto-termination via cluster policies
   b. Migrate jobs from all-purpose to job compute
   c. Enable spot instances for batch workloads
   d. Switch to serverless SQL warehouses
   e. Set custom tags for cost attribution and alerting
   f. Create budget alerts in cloud provider billing
```

## Storage Diagnostics

### system.storage -- Predictive Optimization

```sql
-- Predictive optimization history
SELECT
  catalog_name, schema_name, table_name,
  operation_type, operation_status,
  start_time, end_time,
  metrics
FROM system.storage.predictive_optimization_operations_history
WHERE start_time >= DATEADD(DAY, -7, CURRENT_TIMESTAMP())
ORDER BY start_time DESC;

-- Tables that haven't been optimized recently
SELECT
  t.table_catalog, t.table_schema, t.table_name
FROM system.information_schema.tables t
LEFT JOIN (
  SELECT catalog_name, schema_name, table_name, MAX(start_time) AS last_optimize
  FROM system.storage.predictive_optimization_operations_history
  WHERE operation_type = 'OPTIMIZE'
  GROUP BY catalog_name, schema_name, table_name
) o ON t.table_catalog = o.catalog_name
  AND t.table_schema = o.schema_name
  AND t.table_name = o.table_name
WHERE t.table_type = 'MANAGED'
AND (o.last_optimize IS NULL OR o.last_optimize < DATEADD(DAY, -7, CURRENT_TIMESTAMP()));
```

### dbutils File System Diagnostics

```python
# List files in a Delta table directory
dbutils.fs.ls("s3://bucket/path/to/table/")

# List Delta log files
dbutils.fs.ls("s3://bucket/path/to/table/_delta_log/")

# Check table size on storage
total_size = sum(f.size for f in dbutils.fs.ls("s3://bucket/path/to/table/") if not f.name.startswith("_"))
print(f"Table data size: {total_size / 1024 / 1024 / 1024:.2f} GB")

# Check Delta log size
log_size = sum(f.size for f in dbutils.fs.ls("s3://bucket/path/to/table/_delta_log/"))
print(f"Delta log size: {log_size / 1024 / 1024:.2f} MB")

# Count data files
data_files = [f for f in dbutils.fs.ls("s3://bucket/path/to/table/") if f.name.endswith(".parquet")]
print(f"Data files: {len(data_files)}")

# List Unity Catalog volumes
dbutils.fs.ls("/Volumes/my_catalog/my_schema/my_volume/")
```
