# BigQuery Diagnostics Reference

## bq CLI -- Dataset and Table Operations

### bq ls -- List Datasets and Tables

```bash
# List all datasets in current project
bq ls

# List datasets in a specific project
bq ls --project_id=my-project

# List tables in a dataset
bq ls my_dataset

# List tables with details (type, labels, creation time)
bq ls --format=prettyjson my_dataset

# List tables matching a filter (transfer configs)
bq ls --transfer_config --transfer_location=us

# List all jobs
bq ls --jobs --all --max_results=100

# List reservations
bq ls --reservation --project_id=admin-project --location=us

# List capacity commitments
bq ls --capacity_commitment --project_id=admin-project --location=us

# List reservation assignments
bq ls --reservation_assignment --project_id=admin-project --location=us
```

### bq show -- Resource Details

```bash
# Show dataset details
bq show my_dataset

# Show table schema and metadata
bq show my_dataset.my_table

# Show table with full schema in JSON
bq show --format=prettyjson my_dataset.my_table

# Show table schema only
bq show --schema my_dataset.my_table

# Show job details (execution plan, statistics)
bq show -j job_id_here

# Show job details in JSON (full execution plan)
bq show --format=prettyjson -j job_id_here

# Show reservation details
bq show --reservation --project_id=admin-project --location=us reservation_name

# Show capacity commitment
bq show --capacity_commitment --project_id=admin-project --location=us commitment_id

# Show model details (BigQuery ML)
bq show -m my_dataset.my_model

# Show routine (stored procedure / function)
bq show --routine my_dataset.my_procedure

# Show transfer run details
bq show --transfer_run projects/my-project/locations/us/transferConfigs/config_id/runs/run_id
```

### bq mk -- Create Resources

```bash
# Create a dataset
bq mk --dataset --location=US --description="Analytics data" my_dataset

# Create a dataset with default table expiration
bq mk --dataset --default_table_expiration=86400 my_dataset

# Create a partitioned table
bq mk --table \
  --time_partitioning_type=DAY \
  --time_partitioning_field=event_date \
  --clustering_fields=user_id,event_type \
  --require_partition_filter=true \
  my_dataset.events \
  event_id:STRING,event_date:DATE,user_id:STRING,event_type:STRING

# Create a table from JSON schema file
bq mk --table my_dataset.events ./schema.json

# Create a view
bq mk --view='SELECT user_id, COUNT(*) cnt FROM my_dataset.events GROUP BY user_id' my_dataset.user_counts

# Create a materialized view
bq mk --materialized_view='SELECT event_date, COUNT(*) cnt FROM my_dataset.events GROUP BY event_date' my_dataset.daily_counts

# Create an external table (Cloud Storage)
bq mk --external_table_definition=gs://bucket/path/*.parquet@PARQUET my_dataset.external_events

# Create a reservation
bq mk --reservation --project_id=admin-project --location=us --slots=200 --edition=ENTERPRISE analytics_reservation

# Create a capacity commitment
bq mk --capacity_commitment --project_id=admin-project --location=us --slots=100 --plan=ANNUAL --edition=ENTERPRISE

# Create a reservation assignment
bq mk --reservation_assignment --project_id=admin-project --location=us --reservation_id=analytics_reservation --assignee_id=my-project --job_type=QUERY

# Create a transfer config (scheduled query)
bq mk --transfer_config \
  --target_dataset=my_dataset \
  --display_name='Daily ETL' \
  --schedule='every 24 hours' \
  --data_source=scheduled_query \
  --params='{"query":"SELECT * FROM src WHERE dt = @run_date"}'
```

### bq load -- Load Data

```bash
# Load CSV with autodetect schema
bq load --autodetect --source_format=CSV my_dataset.table gs://bucket/data.csv

# Load Parquet (schema auto-detected from file)
bq load --source_format=PARQUET my_dataset.table gs://bucket/data/*.parquet

# Load JSON (newline-delimited)
bq load --autodetect --source_format=NEWLINE_DELIMITED_JSON my_dataset.table gs://bucket/data.json

# Load Avro
bq load --source_format=AVRO my_dataset.table gs://bucket/data.avro

# Load with specific schema
bq load --source_format=CSV --skip_leading_rows=1 \
  my_dataset.table gs://bucket/data.csv \
  name:STRING,age:INTEGER,email:STRING

# Load with partition decoration
bq load --source_format=PARQUET \
  --time_partitioning_type=DAY \
  --time_partitioning_field=event_date \
  my_dataset.events gs://bucket/events/*.parquet

# Load and replace (truncate + load)
bq load --replace --source_format=PARQUET my_dataset.table gs://bucket/data.parquet

# Load and append
bq load --noreplace --source_format=PARQUET my_dataset.table gs://bucket/data.parquet

# Load with hive partitioning
bq load --source_format=PARQUET \
  --hive_partitioning_mode=AUTO \
  --hive_partitioning_source_uri_prefix=gs://bucket/data/ \
  my_dataset.table gs://bucket/data/*.parquet

# Dry run a load job (check without executing)
bq load --dry_run --source_format=PARQUET my_dataset.table gs://bucket/data.parquet
```

### bq query -- Execute Queries

```bash
# Run a query (standard SQL is default)
bq query 'SELECT COUNT(*) FROM my_dataset.my_table'

# Dry run (show bytes to be scanned without executing)
bq query --dry_run 'SELECT * FROM my_dataset.large_table WHERE event_date = "2026-04-01"'

# Set maximum bytes billed
bq query --maximum_bytes_billed=10000000000 'SELECT * FROM my_dataset.table'

# Run query and write results to a destination table
bq query --destination_table=my_dataset.results \
  --use_legacy_sql=false \
  'SELECT user_id, COUNT(*) AS cnt FROM my_dataset.events GROUP BY user_id'

# Run query with WRITE_TRUNCATE disposition
bq query --destination_table=my_dataset.results \
  --replace \
  'SELECT user_id, COUNT(*) FROM my_dataset.events GROUP BY user_id'

# Run query with WRITE_APPEND disposition
bq query --destination_table=my_dataset.results \
  --append_table \
  'SELECT user_id, COUNT(*) FROM my_dataset.events GROUP BY user_id'

# Run query with parameterized query
bq query --parameter='target_date:DATE:2026-04-01' \
  'SELECT * FROM my_dataset.events WHERE event_date = @target_date'

# Run query and output as JSON
bq query --format=json 'SELECT * FROM my_dataset.table LIMIT 10'

# Run query and output as CSV
bq query --format=csv 'SELECT * FROM my_dataset.table LIMIT 10'

# Run query with a specific project
bq query --project_id=my-project 'SELECT 1'

# Run query in a specific location
bq query --location=EU 'SELECT * FROM my_dataset.table LIMIT 1'
```

### bq extract -- Export Data

```bash
# Extract table to GCS as CSV
bq extract my_dataset.my_table gs://bucket/export/data.csv

# Extract as compressed CSV
bq extract --compression=GZIP my_dataset.my_table gs://bucket/export/data.csv.gz

# Extract as Avro
bq extract --destination_format=AVRO my_dataset.my_table gs://bucket/export/data.avro

# Extract as Parquet
bq extract --destination_format=PARQUET my_dataset.my_table gs://bucket/export/data.parquet

# Extract as newline-delimited JSON
bq extract --destination_format=NEWLINE_DELIMITED_JSON my_dataset.my_table gs://bucket/export/data.json

# Extract with wildcard (sharded output)
bq extract my_dataset.my_table gs://bucket/export/shard_*.parquet

# Extract a model (BigQuery ML)
bq extract -m my_dataset.my_model gs://bucket/models/my_model/
```

### bq cp -- Copy Tables

```bash
# Copy a table within the same dataset
bq cp my_dataset.source_table my_dataset.dest_table

# Copy a table across datasets
bq cp source_dataset.table dest_dataset.table

# Copy a table across projects
bq cp project1:dataset.table project2:dataset.table

# Copy and overwrite destination
bq cp -f my_dataset.source my_dataset.dest

# Copy and append to destination
bq cp -a my_dataset.source my_dataset.dest

# Copy a specific partition
bq cp 'my_dataset.events$20260401' my_dataset.events_backup_20260401
```

### bq rm -- Delete Resources

```bash
# Delete a table
bq rm my_dataset.my_table

# Force delete (no confirmation)
bq rm -f my_dataset.my_table

# Delete a dataset (must be empty)
bq rm -d my_dataset

# Delete a dataset and all contents (recursive)
bq rm -r -d my_dataset

# Delete a model
bq rm -m my_dataset.my_model

# Delete a routine
bq rm --routine my_dataset.my_procedure

# Delete a reservation
bq rm --reservation --project_id=admin-project --location=us reservation_name

# Delete a capacity commitment
bq rm --capacity_commitment --project_id=admin-project --location=us commitment_id
```

### bq update -- Modify Resources

```bash
# Update table description
bq update --description="Updated description" my_dataset.my_table

# Add labels to a table
bq update --set_label=env:production --set_label=team:analytics my_dataset.my_table

# Set table expiration
bq update --expiration=86400 my_dataset.staging_table

# Set partition expiration
bq update --time_partitioning_expiration=31536000 my_dataset.events

# Enable require_partition_filter
bq update --require_partition_filter=true my_dataset.events

# Update table schema (add columns)
bq update my_dataset.my_table new_schema.json

# Update reservation slots
bq update --reservation --project_id=admin-project --location=us --slots=300 analytics_reservation

# Update dataset default table expiration
bq update --default_table_expiration=2592000 my_dataset

# Authorize a view on a source dataset
bq update --source_dataset=raw_dataset --view=project:shared_dataset.my_view my_dataset
```

### bq head -- Preview Table Data

```bash
# Preview first 100 rows (no bytes billed)
bq head my_dataset.my_table

# Preview specific number of rows
bq head -n 20 my_dataset.my_table

# Preview selected columns
bq head -s "name,email,created_at" my_dataset.my_table

# Preview a specific partition
bq head 'my_dataset.events$20260401'
```

## INFORMATION_SCHEMA -- Job Analysis

### JOBS -- Query Job History

```sql
-- 1. All jobs in the last 24 hours
SELECT
  job_id,
  user_email,
  job_type,
  state,
  error_result.reason AS error_reason,
  creation_time,
  start_time,
  end_time,
  TIMESTAMP_DIFF(end_time, start_time, SECOND) AS duration_seconds,
  total_bytes_processed,
  total_bytes_billed,
  total_slot_ms,
  query
FROM `region-us`.INFORMATION_SCHEMA.JOBS
WHERE creation_time > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
ORDER BY creation_time DESC;

-- 2. Failed jobs with error details
SELECT
  job_id,
  user_email,
  creation_time,
  error_result.reason AS error_reason,
  error_result.message AS error_message,
  SUBSTR(query, 1, 200) AS query_prefix
FROM `region-us`.INFORMATION_SCHEMA.JOBS
WHERE creation_time > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
  AND error_result IS NOT NULL
ORDER BY creation_time DESC;

-- 3. Top 20 most expensive queries (by bytes billed)
SELECT
  job_id,
  user_email,
  ROUND(total_bytes_billed / POW(2,40), 4) AS tb_billed,
  ROUND(total_bytes_billed / POW(2,40) * 6.25, 2) AS est_cost_usd,
  TIMESTAMP_DIFF(end_time, start_time, SECOND) AS duration_sec,
  total_slot_ms,
  SUBSTR(query, 1, 300) AS query_prefix,
  creation_time
FROM `region-us`.INFORMATION_SCHEMA.JOBS
WHERE creation_time > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
  AND job_type = 'QUERY'
  AND state = 'DONE'
  AND error_result IS NULL
ORDER BY total_bytes_billed DESC
LIMIT 20;

-- 4. Top 20 slowest queries
SELECT
  job_id,
  user_email,
  TIMESTAMP_DIFF(end_time, start_time, SECOND) AS duration_sec,
  total_bytes_processed,
  total_slot_ms,
  ROUND(total_slot_ms / 1000 / NULLIF(TIMESTAMP_DIFF(end_time, start_time, SECOND), 0), 1) AS avg_slots,
  SUBSTR(query, 1, 300) AS query_prefix,
  creation_time
FROM `region-us`.INFORMATION_SCHEMA.JOBS
WHERE creation_time > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
  AND job_type = 'QUERY'
  AND state = 'DONE'
  AND error_result IS NULL
ORDER BY TIMESTAMP_DIFF(end_time, start_time, SECOND) DESC
LIMIT 20;

-- 5. Top 20 queries by slot consumption
SELECT
  job_id,
  user_email,
  total_slot_ms,
  ROUND(total_slot_ms / 1000.0, 1) AS total_slot_seconds,
  TIMESTAMP_DIFF(end_time, start_time, SECOND) AS wall_clock_sec,
  ROUND(total_slot_ms / 1000 / NULLIF(TIMESTAMP_DIFF(end_time, start_time, SECOND), 0), 1) AS avg_slots_used,
  ROUND(total_bytes_billed / POW(2,30), 2) AS gb_billed,
  SUBSTR(query, 1, 300) AS query_prefix
FROM `region-us`.INFORMATION_SCHEMA.JOBS
WHERE creation_time > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
  AND job_type = 'QUERY'
  AND state = 'DONE'
ORDER BY total_slot_ms DESC
LIMIT 20;

-- 6. Query volume and cost by user (last 30 days)
SELECT
  user_email,
  COUNT(*) AS query_count,
  ROUND(SUM(total_bytes_billed) / POW(2,40), 4) AS total_tb_billed,
  ROUND(SUM(total_bytes_billed) / POW(2,40) * 6.25, 2) AS total_est_cost_usd,
  ROUND(AVG(total_bytes_billed) / POW(2,30), 2) AS avg_gb_per_query,
  ROUND(SUM(total_slot_ms) / 1000 / 3600, 1) AS total_slot_hours,
  AVG(TIMESTAMP_DIFF(end_time, start_time, SECOND)) AS avg_duration_sec
FROM `region-us`.INFORMATION_SCHEMA.JOBS
WHERE creation_time > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
  AND job_type = 'QUERY'
  AND state = 'DONE'
GROUP BY user_email
ORDER BY total_est_cost_usd DESC;

-- 7. Query volume by hour of day (identify peak hours)
SELECT
  EXTRACT(HOUR FROM creation_time) AS hour_of_day,
  COUNT(*) AS query_count,
  ROUND(SUM(total_bytes_billed) / POW(2,40) * 6.25, 2) AS est_cost_usd,
  ROUND(SUM(total_slot_ms) / 1000 / 3600, 1) AS slot_hours,
  AVG(TIMESTAMP_DIFF(end_time, start_time, SECOND)) AS avg_duration_sec
FROM `region-us`.INFORMATION_SCHEMA.JOBS
WHERE creation_time > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
  AND job_type = 'QUERY'
  AND state = 'DONE'
GROUP BY hour_of_day
ORDER BY hour_of_day;

-- 8. Daily query volume and cost trend
SELECT
  DATE(creation_time) AS query_date,
  COUNT(*) AS query_count,
  COUNTIF(error_result IS NOT NULL) AS failed_count,
  ROUND(SUM(total_bytes_billed) / POW(2,40) * 6.25, 2) AS est_cost_usd,
  ROUND(SUM(total_slot_ms) / 1000 / 3600, 1) AS slot_hours
FROM `region-us`.INFORMATION_SCHEMA.JOBS
WHERE creation_time > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
  AND job_type = 'QUERY'
GROUP BY query_date
ORDER BY query_date;

-- 9. Queries without partition filters (scan whole table)
SELECT
  job_id,
  user_email,
  ROUND(total_bytes_billed / POW(2,30), 2) AS gb_billed,
  SUBSTR(query, 1, 300) AS query_prefix,
  referenced_tables,
  creation_time
FROM `region-us`.INFORMATION_SCHEMA.JOBS
WHERE creation_time > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
  AND job_type = 'QUERY'
  AND state = 'DONE'
  AND total_bytes_billed > 10737418240  -- > 10 GB
  AND ARRAY_LENGTH(
    ARRAY(SELECT t FROM UNNEST(referenced_tables) t WHERE t.table_id LIKE '%')
  ) > 0
ORDER BY total_bytes_billed DESC
LIMIT 20;

-- 10. Jobs by type and state
SELECT
  job_type,
  state,
  COUNT(*) AS job_count,
  AVG(TIMESTAMP_DIFF(end_time, start_time, SECOND)) AS avg_duration_sec
FROM `region-us`.INFORMATION_SCHEMA.JOBS
WHERE creation_time > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
GROUP BY job_type, state
ORDER BY job_type, state;

-- 11. Identify repeated/duplicate queries (candidates for materialized views)
SELECT
  FARM_FINGERPRINT(query) AS query_fingerprint,
  COUNT(*) AS execution_count,
  ROUND(SUM(total_bytes_billed) / POW(2,40) * 6.25, 2) AS total_est_cost_usd,
  ROUND(SUM(total_slot_ms) / 1000 / 3600, 1) AS total_slot_hours,
  MIN(SUBSTR(query, 1, 300)) AS query_sample
FROM `region-us`.INFORMATION_SCHEMA.JOBS
WHERE creation_time > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
  AND job_type = 'QUERY'
  AND state = 'DONE'
  AND error_result IS NULL
GROUP BY query_fingerprint
HAVING COUNT(*) > 5
ORDER BY total_est_cost_usd DESC
LIMIT 20;

-- 12. Queries with high shuffle bytes (expensive joins/aggregations)
SELECT
  job_id,
  user_email,
  ROUND(total_bytes_processed / POW(2,30), 2) AS gb_processed,
  total_slot_ms,
  TIMESTAMP_DIFF(end_time, start_time, SECOND) AS duration_sec,
  SUBSTR(query, 1, 300) AS query_prefix
FROM `region-us`.INFORMATION_SCHEMA.JOBS
WHERE creation_time > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
  AND job_type = 'QUERY'
  AND state = 'DONE'
  AND total_slot_ms > 3600000  -- more than 1 slot-hour
ORDER BY total_slot_ms DESC
LIMIT 20;

-- 13. Load job statistics
SELECT
  job_id,
  user_email,
  creation_time,
  TIMESTAMP_DIFF(end_time, start_time, SECOND) AS duration_sec,
  destination_table.project_id,
  destination_table.dataset_id,
  destination_table.table_id,
  total_bytes_processed,
  state,
  error_result.message AS error_message
FROM `region-us`.INFORMATION_SCHEMA.JOBS
WHERE creation_time > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
  AND job_type = 'LOAD'
ORDER BY creation_time DESC;

-- 14. Jobs exceeding resource limits
SELECT
  job_id,
  user_email,
  error_result.reason AS error_reason,
  error_result.message AS error_message,
  total_bytes_processed,
  total_slot_ms,
  SUBSTR(query, 1, 300) AS query_prefix,
  creation_time
FROM `region-us`.INFORMATION_SCHEMA.JOBS
WHERE creation_time > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
  AND error_result.reason IN ('resourcesExceeded', 'quotaExceeded', 'rateLimitExceeded', 'billingTierLimitExceeded')
ORDER BY creation_time DESC;
```

### JOBS_TIMELINE -- Slot Usage Over Time

```sql
-- 15. Slot utilization per second (last 1 hour)
SELECT
  period_start,
  SUM(period_slot_ms) / 1000 AS slots_used,
  SUM(period_shuffle_ram_usage_ratio) AS shuffle_ratio
FROM `region-us`.INFORMATION_SCHEMA.JOBS_TIMELINE
WHERE period_start > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)
  AND job_type = 'QUERY'
  AND state = 'DONE'
GROUP BY period_start
ORDER BY period_start;

-- 16. Concurrent slot usage by reservation (editions)
SELECT
  period_start,
  reservation_id,
  SUM(period_slot_ms) / 1000 AS slots_used
FROM `region-us`.INFORMATION_SCHEMA.JOBS_TIMELINE
WHERE period_start > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 6 HOUR)
GROUP BY period_start, reservation_id
ORDER BY period_start, reservation_id;

-- 17. Peak slot demand by hour
SELECT
  TIMESTAMP_TRUNC(period_start, HOUR) AS hour,
  MAX(slots_in_period) AS peak_slots
FROM (
  SELECT
    period_start,
    SUM(period_slot_ms) / 1000 AS slots_in_period
  FROM `region-us`.INFORMATION_SCHEMA.JOBS_TIMELINE
  WHERE period_start > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
  GROUP BY period_start
)
GROUP BY hour
ORDER BY hour;

-- 18. Slot contention analysis -- queries waiting vs executing
SELECT
  period_start,
  job_id,
  state,
  period_slot_ms,
  TIMESTAMP_DIFF(period_start, job_creation_time, SECOND) AS wait_from_creation_sec
FROM `region-us`.INFORMATION_SCHEMA.JOBS_TIMELINE
WHERE period_start > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)
  AND state IN ('PENDING', 'RUNNING')
ORDER BY period_start;

-- 19. Slot usage per project (multi-project environment)
SELECT
  project_id,
  DATE(period_start) AS day,
  ROUND(SUM(period_slot_ms) / 1000 / 3600, 1) AS slot_hours
FROM `region-us`.INFORMATION_SCHEMA.JOBS_TIMELINE
WHERE period_start > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
GROUP BY project_id, day
ORDER BY day, slot_hours DESC;
```

## INFORMATION_SCHEMA -- Streaming Diagnostics

### STREAMING_TIMELINE

```sql
-- 20. Streaming throughput over time
SELECT
  start_timestamp,
  SUM(total_rows) AS rows_ingested,
  SUM(total_input_bytes) AS bytes_ingested,
  SUM(error_count) AS errors
FROM `region-us`.INFORMATION_SCHEMA.STREAMING_TIMELINE
WHERE start_timestamp > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
GROUP BY start_timestamp
ORDER BY start_timestamp;

-- 21. Streaming errors by table
SELECT
  table_schema,
  table_name,
  SUM(total_rows) AS total_rows,
  SUM(error_count) AS total_errors,
  SAFE_DIVIDE(SUM(error_count), SUM(total_rows)) AS error_rate
FROM `region-us`.INFORMATION_SCHEMA.STREAMING_TIMELINE
WHERE start_timestamp > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
GROUP BY table_schema, table_name
HAVING SUM(error_count) > 0
ORDER BY total_errors DESC;

-- 22. Streaming bytes ingested per hour
SELECT
  TIMESTAMP_TRUNC(start_timestamp, HOUR) AS hour,
  SUM(total_rows) AS total_rows,
  ROUND(SUM(total_input_bytes) / POW(2,30), 2) AS gb_ingested
FROM `region-us`.INFORMATION_SCHEMA.STREAMING_TIMELINE
WHERE start_timestamp > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
GROUP BY hour
ORDER BY hour;

-- 23. Active streaming tables
SELECT
  table_schema,
  table_name,
  SUM(total_rows) AS rows_last_24h,
  ROUND(SUM(total_input_bytes) / POW(2,30), 2) AS gb_last_24h,
  MAX(start_timestamp) AS last_activity
FROM `region-us`.INFORMATION_SCHEMA.STREAMING_TIMELINE
WHERE start_timestamp > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
GROUP BY table_schema, table_name
ORDER BY rows_last_24h DESC;
```

## INFORMATION_SCHEMA -- Storage Analysis

### TABLE_STORAGE

```sql
-- 24. Storage usage by table (top 50 largest)
SELECT
  table_schema,
  table_name,
  ROUND(total_rows, 0) AS total_rows,
  ROUND(total_logical_bytes / POW(2,30), 2) AS logical_gb,
  ROUND(total_physical_bytes / POW(2,30), 2) AS physical_gb,
  ROUND(active_logical_bytes / POW(2,30), 2) AS active_gb,
  ROUND(long_term_logical_bytes / POW(2,30), 2) AS long_term_gb,
  ROUND(time_travel_physical_bytes / POW(2,30), 2) AS time_travel_gb
FROM `region-us`.INFORMATION_SCHEMA.TABLE_STORAGE
ORDER BY total_logical_bytes DESC
LIMIT 50;

-- 25. Storage cost estimate by table
SELECT
  table_schema,
  table_name,
  ROUND(active_logical_bytes / POW(2,30) * 0.02, 2) AS active_monthly_cost_usd,
  ROUND(long_term_logical_bytes / POW(2,30) * 0.01, 2) AS long_term_monthly_cost_usd,
  ROUND(
    (active_logical_bytes / POW(2,30) * 0.02) +
    (long_term_logical_bytes / POW(2,30) * 0.01),
    2
  ) AS total_monthly_cost_usd
FROM `region-us`.INFORMATION_SCHEMA.TABLE_STORAGE
ORDER BY total_monthly_cost_usd DESC
LIMIT 50;

-- 26. Total storage by dataset
SELECT
  table_schema AS dataset,
  COUNT(*) AS table_count,
  ROUND(SUM(total_logical_bytes) / POW(2,40), 4) AS total_tb,
  ROUND(SUM(active_logical_bytes) / POW(2,30), 2) AS active_gb,
  ROUND(SUM(long_term_logical_bytes) / POW(2,30), 2) AS long_term_gb,
  ROUND(SUM(time_travel_physical_bytes) / POW(2,30), 2) AS time_travel_gb
FROM `region-us`.INFORMATION_SCHEMA.TABLE_STORAGE
GROUP BY dataset
ORDER BY total_tb DESC;

-- 27. Tables with high time travel storage (candidates for reducing max_time_travel_hours)
SELECT
  table_schema,
  table_name,
  ROUND(total_logical_bytes / POW(2,30), 2) AS logical_gb,
  ROUND(time_travel_physical_bytes / POW(2,30), 2) AS time_travel_gb,
  ROUND(SAFE_DIVIDE(time_travel_physical_bytes, total_physical_bytes) * 100, 1) AS time_travel_pct
FROM `region-us`.INFORMATION_SCHEMA.TABLE_STORAGE
WHERE time_travel_physical_bytes > 1073741824  -- > 1 GB
ORDER BY time_travel_physical_bytes DESC
LIMIT 20;

-- 28. Compression ratio analysis
SELECT
  table_schema,
  table_name,
  ROUND(total_logical_bytes / POW(2,30), 2) AS logical_gb,
  ROUND(total_physical_bytes / POW(2,30), 2) AS physical_gb,
  ROUND(SAFE_DIVIDE(total_logical_bytes, total_physical_bytes), 2) AS compression_ratio
FROM `region-us`.INFORMATION_SCHEMA.TABLE_STORAGE
WHERE total_physical_bytes > 0
ORDER BY total_logical_bytes DESC
LIMIT 30;

-- 29. Storage growth over recent period (compare to __TABLES__ metadata)
SELECT
  table_id,
  ROUND(size_bytes / POW(2,30), 2) AS current_gb,
  row_count,
  TIMESTAMP_MILLIS(creation_time) AS created,
  TIMESTAMP_MILLIS(last_modified_time) AS last_modified,
  type  -- 1=TABLE, 2=VIEW, 3=EXTERNAL
FROM `my_dataset.__TABLES__`
ORDER BY size_bytes DESC;
```

### PARTITIONS

```sql
-- 30. Partition details for a table
SELECT
  table_catalog,
  table_schema,
  table_name,
  partition_id,
  total_rows,
  ROUND(total_logical_bytes / POW(2,30), 4) AS logical_gb,
  last_modified_time
FROM `region-us`.INFORMATION_SCHEMA.PARTITIONS
WHERE table_name = 'events'
ORDER BY partition_id DESC;

-- 31. Partition size distribution (detect skew)
SELECT
  partition_id,
  total_rows,
  ROUND(total_logical_bytes / POW(2,20), 2) AS mb,
  ROUND(total_logical_bytes * 100.0 / SUM(total_logical_bytes) OVER(), 2) AS pct_of_total
FROM `region-us`.INFORMATION_SCHEMA.PARTITIONS
WHERE table_name = 'events'
  AND partition_id IS NOT NULL
  AND partition_id != '__NULL__'
ORDER BY partition_id DESC
LIMIT 50;

-- 32. Partitions that haven't been modified (candidates for long-term storage)
SELECT
  table_name,
  partition_id,
  total_rows,
  ROUND(total_logical_bytes / POW(2,30), 4) AS gb,
  last_modified_time,
  TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), last_modified_time, DAY) AS days_since_modified
FROM `region-us`.INFORMATION_SCHEMA.PARTITIONS
WHERE table_name = 'events'
  AND TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), last_modified_time, DAY) > 90
ORDER BY partition_id;

-- 33. Empty or near-empty partitions
SELECT
  table_name,
  partition_id,
  total_rows,
  ROUND(total_logical_bytes / POW(2,20), 2) AS mb
FROM `region-us`.INFORMATION_SCHEMA.PARTITIONS
WHERE table_name = 'events'
  AND total_rows < 100
  AND partition_id IS NOT NULL
  AND partition_id != '__NULL__'
ORDER BY partition_id;

-- 34. Partition count per table
SELECT
  table_schema,
  table_name,
  COUNT(*) AS partition_count,
  SUM(total_rows) AS total_rows,
  ROUND(SUM(total_logical_bytes) / POW(2,30), 2) AS total_gb
FROM `region-us`.INFORMATION_SCHEMA.PARTITIONS
WHERE partition_id IS NOT NULL
GROUP BY table_schema, table_name
ORDER BY partition_count DESC;
```

## INFORMATION_SCHEMA -- Schema and Metadata

### COLUMNS

```sql
-- 35. All columns for a table
SELECT
  column_name,
  ordinal_position,
  is_nullable,
  data_type,
  is_partitioning_column,
  clustering_ordinal_position
FROM `region-us`.INFORMATION_SCHEMA.COLUMNS
WHERE table_name = 'events'
ORDER BY ordinal_position;

-- 36. Find columns by name across all tables in a dataset
SELECT
  table_name,
  column_name,
  data_type,
  is_nullable
FROM `my_dataset`.INFORMATION_SCHEMA.COLUMNS
WHERE LOWER(column_name) LIKE '%email%'
ORDER BY table_name;

-- 37. Find all partitioning and clustering columns
SELECT
  table_name,
  column_name,
  data_type,
  is_partitioning_column,
  clustering_ordinal_position
FROM `region-us`.INFORMATION_SCHEMA.COLUMNS
WHERE is_partitioning_column = 'YES' OR clustering_ordinal_position IS NOT NULL
ORDER BY table_name, clustering_ordinal_position;

-- 38. Tables with JSON or STRUCT columns
SELECT
  table_name,
  column_name,
  data_type
FROM `my_dataset`.INFORMATION_SCHEMA.COLUMNS
WHERE data_type LIKE 'STRUCT%' OR data_type = 'JSON' OR data_type LIKE 'ARRAY%'
ORDER BY table_name, column_name;
```

### TABLES and TABLE_OPTIONS

```sql
-- 39. All tables with creation time and type
SELECT
  table_schema,
  table_name,
  table_type,
  creation_time,
  ddl
FROM `region-us`.INFORMATION_SCHEMA.TABLES
WHERE table_schema = 'my_dataset'
ORDER BY creation_time DESC;

-- 40. Table options (partitioning, clustering, expiration, labels)
SELECT
  table_name,
  option_name,
  option_value
FROM `my_dataset`.INFORMATION_SCHEMA.TABLE_OPTIONS
WHERE table_name = 'events'
ORDER BY option_name;

-- 41. Tables with expiration set
SELECT
  table_name,
  option_name,
  option_value
FROM `my_dataset`.INFORMATION_SCHEMA.TABLE_OPTIONS
WHERE option_name IN ('expiration_timestamp', 'partition_expiration_days')
ORDER BY table_name;

-- 42. Tables without partition filter requirement (risk of full scans)
SELECT
  t.table_name,
  t.table_type,
  IFNULL(
    (SELECT option_value FROM `my_dataset`.INFORMATION_SCHEMA.TABLE_OPTIONS o
     WHERE o.table_name = t.table_name AND o.option_name = 'require_partition_filter'),
    'false'
  ) AS require_partition_filter
FROM `my_dataset`.INFORMATION_SCHEMA.TABLES t
WHERE t.table_type = 'BASE TABLE';

-- 43. Get DDL for a table (full CREATE statement)
SELECT ddl FROM `region-us`.INFORMATION_SCHEMA.TABLES
WHERE table_name = 'events' AND table_schema = 'my_dataset';
```

### SCHEMATA

```sql
-- 44. All datasets in the project
SELECT
  catalog_name AS project,
  schema_name AS dataset,
  location,
  creation_time,
  last_modified_time
FROM INFORMATION_SCHEMA.SCHEMATA
ORDER BY schema_name;

-- 45. Dataset options (labels, default expiration, etc.)
SELECT
  schema_name,
  option_name,
  option_value
FROM INFORMATION_SCHEMA.SCHEMATA_OPTIONS
ORDER BY schema_name, option_name;

-- 46. Datasets with default table expiration
SELECT
  schema_name,
  option_value AS default_expiration
FROM INFORMATION_SCHEMA.SCHEMATA_OPTIONS
WHERE option_name = 'default_table_expiration_days';
```

### ROUTINES

```sql
-- 47. All stored procedures and functions
SELECT
  routine_schema,
  routine_name,
  routine_type,
  data_type AS return_type,
  created,
  last_altered,
  ddl
FROM `region-us`.INFORMATION_SCHEMA.ROUTINES
WHERE routine_schema = 'my_dataset'
ORDER BY routine_name;

-- 48. Routine parameters
SELECT
  specific_schema,
  specific_name,
  parameter_name,
  ordinal_position,
  data_type,
  parameter_mode
FROM `my_dataset`.INFORMATION_SCHEMA.PARAMETERS
ORDER BY specific_name, ordinal_position;
```

## INFORMATION_SCHEMA -- Reservations and Capacity

### RESERVATIONS

```sql
-- 49. All reservations
SELECT
  reservation_name,
  slot_capacity,
  target_job_concurrency,
  ignore_idle_slots,
  edition,
  autoscale.max_slots AS autoscale_max_slots,
  autoscale.current_slots AS autoscale_current_slots
FROM `region-us`.INFORMATION_SCHEMA.RESERVATIONS;

-- 50. Current slot utilization per reservation
SELECT
  r.reservation_name,
  r.slot_capacity AS baseline_slots,
  r.autoscale.max_slots AS max_slots,
  r.autoscale.current_slots AS current_autoscale_slots,
  r.edition
FROM `region-us`.INFORMATION_SCHEMA.RESERVATIONS r;
```

### CAPACITY_COMMITMENTS

```sql
-- 51. All capacity commitments
SELECT
  capacity_commitment_id,
  commitment_plan,
  slot_count,
  state,
  edition,
  is_flat_rate,
  renewal_plan,
  commitment_start_time,
  commitment_end_time
FROM `region-us`.INFORMATION_SCHEMA.CAPACITY_COMMITMENTS;

-- 52. Commitments expiring soon
SELECT
  capacity_commitment_id,
  commitment_plan,
  slot_count,
  edition,
  commitment_end_time,
  TIMESTAMP_DIFF(commitment_end_time, CURRENT_TIMESTAMP(), DAY) AS days_until_expiry
FROM `region-us`.INFORMATION_SCHEMA.CAPACITY_COMMITMENTS
WHERE commitment_end_time IS NOT NULL
  AND TIMESTAMP_DIFF(commitment_end_time, CURRENT_TIMESTAMP(), DAY) < 90
ORDER BY commitment_end_time;
```

### ASSIGNMENTS

```sql
-- 53. All reservation assignments
SELECT
  reservation_name,
  assignee_id,
  assignee_type,
  job_type
FROM `region-us`.INFORMATION_SCHEMA.ASSIGNMENTS;

-- 54. Check if a project has a reservation assignment
SELECT
  reservation_name,
  assignee_id,
  job_type
FROM `region-us`.INFORMATION_SCHEMA.ASSIGNMENTS
WHERE assignee_id = 'projects/my-project';
```

## Execution Plan Analysis

### Reading Query Execution Plans

```sql
-- 55. Get execution plan stages for a specific job
SELECT
  job_id,
  creation_time,
  total_bytes_processed,
  total_slot_ms,
  ARRAY(
    SELECT AS STRUCT
      s.name,
      s.id,
      s.status,
      s.slot_ms,
      s.shuffle_output_bytes,
      s.shuffle_output_bytes_spilled,
      s.records_read,
      s.records_written,
      s.parallel_inputs,
      s.compute_ms_avg,
      s.compute_ms_max,
      s.wait_ms_avg,
      s.wait_ms_max,
      s.read_ms_avg,
      s.read_ms_max,
      s.write_ms_avg,
      s.write_ms_max,
      s.compute_ratio_avg,
      s.compute_ratio_max,
      s.wait_ratio_avg,
      s.wait_ratio_max
    FROM UNNEST(job_stages) s
  ) AS stages
FROM `region-us`.INFORMATION_SCHEMA.JOBS
WHERE job_id = 'your-job-id-here';

-- 56. Identify stages with data skew (max >> avg)
SELECT
  job_id,
  s.name AS stage_name,
  s.id AS stage_id,
  s.parallel_inputs,
  s.compute_ms_avg,
  s.compute_ms_max,
  ROUND(s.compute_ms_max / NULLIF(s.compute_ms_avg, 0), 1) AS compute_skew_ratio,
  s.records_read,
  s.records_written,
  s.shuffle_output_bytes,
  s.shuffle_output_bytes_spilled
FROM `region-us`.INFORMATION_SCHEMA.JOBS,
UNNEST(job_stages) s
WHERE job_id = 'your-job-id-here'
ORDER BY compute_skew_ratio DESC;

-- 57. Stages with spill to disk (memory pressure)
SELECT
  job_id,
  s.name AS stage_name,
  s.slot_ms,
  ROUND(s.shuffle_output_bytes / POW(2,30), 2) AS shuffle_gb,
  ROUND(s.shuffle_output_bytes_spilled / POW(2,30), 2) AS spilled_gb,
  ROUND(SAFE_DIVIDE(s.shuffle_output_bytes_spilled, s.shuffle_output_bytes) * 100, 1) AS spill_pct
FROM `region-us`.INFORMATION_SCHEMA.JOBS,
UNNEST(job_stages) s
WHERE job_id = 'your-job-id-here'
  AND s.shuffle_output_bytes_spilled > 0
ORDER BY spill_pct DESC;

-- 58. Stages with high wait time (slot contention)
SELECT
  job_id,
  s.name AS stage_name,
  s.wait_ms_avg,
  s.wait_ms_max,
  s.compute_ms_avg,
  s.compute_ms_max,
  ROUND(s.wait_ms_avg / NULLIF(s.compute_ms_avg + s.wait_ms_avg, 0) * 100, 1) AS wait_pct
FROM `region-us`.INFORMATION_SCHEMA.JOBS,
UNNEST(job_stages) s
WHERE job_id = 'your-job-id-here'
ORDER BY wait_pct DESC;

-- 59. Read-heavy stages (I/O bound)
SELECT
  job_id,
  s.name AS stage_name,
  s.read_ms_avg,
  s.read_ms_max,
  s.compute_ms_avg,
  ROUND(s.read_ms_avg / NULLIF(s.read_ms_avg + s.compute_ms_avg + s.wait_ms_avg, 0) * 100, 1) AS read_pct,
  s.records_read
FROM `region-us`.INFORMATION_SCHEMA.JOBS,
UNNEST(job_stages) s
WHERE job_id = 'your-job-id-here'
ORDER BY read_pct DESC;
```

### Execution Plan via bq CLI

```bash
# 60. Show job details with execution plan
bq show -j --format=prettyjson JOB_ID

# Key fields to examine in the output:
# - statistics.query.queryPlan[].name         -- stage name
# - statistics.query.queryPlan[].status       -- COMPLETE, RUNNING, PENDING
# - statistics.query.queryPlan[].slotMs       -- CPU time consumed
# - statistics.query.queryPlan[].recordsRead  -- input rows
# - statistics.query.queryPlan[].recordsWritten -- output rows
# - statistics.query.queryPlan[].shuffleOutputBytes -- data shuffled
# - statistics.query.queryPlan[].shuffleOutputBytesSpilled -- spill to disk
# - statistics.query.queryPlan[].computeMsAvg/Max -- compute time avg/max per worker
# - statistics.query.queryPlan[].waitMsAvg/Max   -- wait time avg/max per worker
# - statistics.query.totalBytesBilled
# - statistics.query.totalSlotMs
# - statistics.query.timeline[].elapsedMs
# - statistics.query.timeline[].totalSlotMs
# - statistics.query.timeline[].pendingUnits
# - statistics.query.timeline[].activeUnits
# - statistics.query.timeline[].completedUnits

# 61. Get bytes estimate without running
bq query --dry_run 'SELECT col1, col2 FROM dataset.table WHERE dt = "2026-04-01"'

# Output: Query successfully validated. Estimated bytes processed: 12345678
```

## BigQuery ML Diagnostics

```sql
-- 62. List all models in a dataset
SELECT
  model_name,
  model_type,
  creation_time,
  last_modified_time
FROM `my_dataset`.INFORMATION_SCHEMA.MODELS
ORDER BY creation_time DESC;

-- 63. Model details via bq CLI
-- bq show -m my_dataset.my_model

-- 64. Model training info (iterations, loss)
SELECT * FROM ML.TRAINING_INFO(MODEL my_dataset.my_model);

-- 65. Model evaluation metrics
SELECT * FROM ML.EVALUATE(MODEL my_dataset.my_model);

-- 66. Model evaluation on a holdout set
SELECT * FROM ML.EVALUATE(MODEL my_dataset.my_model,
  (SELECT * FROM my_dataset.test_data));

-- 67. Feature importance (for tree-based and linear models)
SELECT * FROM ML.FEATURE_IMPORTANCE(MODEL my_dataset.my_model);

-- 68. Model weights (linear/logistic regression)
SELECT * FROM ML.WEIGHTS(MODEL my_dataset.my_model);

-- 69. Global explain (feature attributions)
SELECT * FROM ML.GLOBAL_EXPLAIN(MODEL my_dataset.my_model);

-- 70. Confusion matrix (classification models)
SELECT * FROM ML.CONFUSION_MATRIX(MODEL my_dataset.my_model);

-- 71. ROC curve data (binary classification)
SELECT * FROM ML.ROC_CURVE(MODEL my_dataset.my_model);

-- 72. Predict with explanation (row-level feature attributions)
SELECT * FROM ML.EXPLAIN_PREDICT(MODEL my_dataset.my_model,
  (SELECT * FROM my_dataset.predict_data),
  STRUCT(3 AS top_k_features));

-- 73. Forecast with ARIMA_PLUS
SELECT * FROM ML.FORECAST(MODEL my_dataset.time_series_model,
  STRUCT(30 AS horizon, 0.9 AS confidence_level));

-- 74. ARIMA model coefficients
SELECT * FROM ML.ARIMA_COEFFICIENTS(MODEL my_dataset.time_series_model);

-- 75. Export model to Cloud Storage
-- bq extract -m my_dataset.my_model gs://bucket/exported_model/

-- 76. Model trial info (hyperparameter tuning)
SELECT * FROM ML.TRIAL_INFO(MODEL my_dataset.tuned_model);

-- 77. Reconstruct TRANSFORM pipeline
SELECT * FROM ML.RECONSTRUCT_TABLE(MODEL my_dataset.my_model,
  (SELECT * FROM my_dataset.sample_data));
```

## Data Governance Diagnostics

```sql
-- 78. Column-level security: find policy tags on columns
SELECT
  table_schema,
  table_name,
  column_name,
  data_type,
  policy_tags
FROM `region-us`.INFORMATION_SCHEMA.COLUMN_FIELD_PATHS
WHERE policy_tags IS NOT NULL
  AND policy_tags.names IS NOT NULL
  AND ARRAY_LENGTH(policy_tags.names) > 0
ORDER BY table_schema, table_name, column_name;

-- 79. Row-level access policies
SELECT
  table_schema,
  table_name,
  row_access_policy_id AS policy_id,
  filter_predicate,
  creation_time,
  last_modified_time
FROM `region-us`.INFORMATION_SCHEMA.ROW_ACCESS_POLICIES
ORDER BY table_schema, table_name;

-- 80. Check who has access to specific tables via audit log query
-- (requires audit logs exported to BigQuery)
SELECT
  protopayload_auditlog.methodName,
  protopayload_auditlog.authenticationInfo.principalEmail AS user_email,
  protopayload_auditlog.resourceName,
  timestamp
FROM `project.dataset.cloudaudit_googleapis_com_data_access`
WHERE protopayload_auditlog.resourceName LIKE '%my_sensitive_table%'
  AND timestamp > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
ORDER BY timestamp DESC;

-- 81. Authorized views and datasets
-- Check authorized views via bq CLI:
-- bq show --format=prettyjson my_dataset
-- Look for "access" array with "view" entries

-- 82. Data masking policies (via policy tags)
SELECT
  table_schema,
  table_name,
  column_name,
  policy_tags
FROM `region-us`.INFORMATION_SCHEMA.COLUMN_FIELD_PATHS
WHERE policy_tags IS NOT NULL
ORDER BY table_schema, table_name;
```

## Search Index and Vector Index Diagnostics

```sql
-- 83. List search indexes
SELECT
  table_schema,
  table_name,
  index_name,
  index_status,
  creation_time,
  last_modification_time,
  coverage_percentage,
  total_logical_bytes,
  total_physical_bytes
FROM `region-us`.INFORMATION_SCHEMA.SEARCH_INDEXES
ORDER BY table_schema, table_name;

-- 84. Search index coverage and health
SELECT
  index_name,
  table_name,
  index_status,
  coverage_percentage,
  ROUND(total_logical_bytes / POW(2,30), 2) AS logical_gb,
  ROUND(total_physical_bytes / POW(2,30), 2) AS physical_gb,
  ROUND(SAFE_DIVIDE(total_physical_bytes, total_logical_bytes) * 100, 1) AS index_overhead_pct
FROM `region-us`.INFORMATION_SCHEMA.SEARCH_INDEXES
WHERE coverage_percentage < 100;

-- 85. List vector indexes
SELECT
  table_schema,
  table_name,
  index_name,
  index_status,
  creation_time,
  last_modification_time,
  coverage_percentage
FROM `region-us`.INFORMATION_SCHEMA.VECTOR_INDEXES
ORDER BY table_schema, table_name;

-- 86. Search index columns
SELECT
  index_name,
  table_name,
  index_column_name,
  index_field_path
FROM `region-us`.INFORMATION_SCHEMA.SEARCH_INDEX_COLUMNS
ORDER BY index_name, index_column_name;
```

## Monitoring and Audit Queries

```sql
-- 87. Recent DML operations (INSERT, UPDATE, DELETE, MERGE)
SELECT
  job_id,
  user_email,
  statement_type,
  destination_table.dataset_id,
  destination_table.table_id,
  dml_statistics.inserted_row_count,
  dml_statistics.updated_row_count,
  dml_statistics.deleted_row_count,
  creation_time,
  TIMESTAMP_DIFF(end_time, start_time, SECOND) AS duration_sec
FROM `region-us`.INFORMATION_SCHEMA.JOBS
WHERE creation_time > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
  AND statement_type IN ('INSERT', 'UPDATE', 'DELETE', 'MERGE')
ORDER BY creation_time DESC;

-- 88. DDL operations (CREATE, DROP, ALTER)
SELECT
  job_id,
  user_email,
  statement_type,
  SUBSTR(query, 1, 300) AS query_prefix,
  creation_time
FROM `region-us`.INFORMATION_SCHEMA.JOBS
WHERE creation_time > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
  AND statement_type IN (
    'CREATE_TABLE', 'CREATE_TABLE_AS_SELECT', 'CREATE_VIEW',
    'CREATE_MATERIALIZED_VIEW', 'CREATE_FUNCTION', 'CREATE_PROCEDURE',
    'DROP_TABLE', 'DROP_VIEW', 'ALTER_TABLE'
  )
ORDER BY creation_time DESC;

-- 89. Scheduled query history
SELECT
  job_id,
  user_email,
  creation_time,
  state,
  error_result.message AS error_message,
  total_bytes_billed,
  TIMESTAMP_DIFF(end_time, start_time, SECOND) AS duration_sec,
  SUBSTR(query, 1, 200) AS query_prefix
FROM `region-us`.INFORMATION_SCHEMA.JOBS
WHERE creation_time > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
  AND job_type = 'QUERY'
  AND REGEXP_CONTAINS(job_id, r'scheduled_query')
ORDER BY creation_time DESC;

-- 90. Copy job history
SELECT
  job_id,
  user_email,
  creation_time,
  state,
  destination_table.dataset_id AS dest_dataset,
  destination_table.table_id AS dest_table,
  TIMESTAMP_DIFF(end_time, start_time, SECOND) AS duration_sec,
  error_result.message AS error_message
FROM `region-us`.INFORMATION_SCHEMA.JOBS
WHERE creation_time > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
  AND job_type = 'COPY'
ORDER BY creation_time DESC;

-- 91. Export job history
SELECT
  job_id,
  user_email,
  creation_time,
  state,
  total_bytes_processed,
  TIMESTAMP_DIFF(end_time, start_time, SECOND) AS duration_sec,
  error_result.message AS error_message
FROM `region-us`.INFORMATION_SCHEMA.JOBS
WHERE creation_time > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
  AND job_type = 'EXTRACT'
ORDER BY creation_time DESC;
```

## BigLake and External Table Diagnostics

```sql
-- 92. List external tables
SELECT
  table_schema,
  table_name,
  table_type
FROM `region-us`.INFORMATION_SCHEMA.TABLES
WHERE table_type = 'EXTERNAL';

-- 93. External table options (source URI, format, connection)
SELECT
  table_name,
  option_name,
  option_value
FROM `my_dataset`.INFORMATION_SCHEMA.TABLE_OPTIONS
WHERE table_name IN (
  SELECT table_name FROM `my_dataset`.INFORMATION_SCHEMA.TABLES
  WHERE table_type = 'EXTERNAL'
)
ORDER BY table_name, option_name;
```

## Performance Troubleshooting Playbooks

### Playbook: Slow Query Investigation

```sql
-- 94. Step 1: Get job details
SELECT
  job_id,
  total_bytes_processed,
  total_bytes_billed,
  total_slot_ms,
  TIMESTAMP_DIFF(end_time, start_time, SECOND) AS duration_sec,
  ROUND(total_slot_ms / 1000 / NULLIF(TIMESTAMP_DIFF(end_time, start_time, SECOND), 0), 1) AS avg_slots,
  cache_hit,
  query
FROM `region-us`.INFORMATION_SCHEMA.JOBS
WHERE job_id = 'your-job-id-here';

-- 95. Step 2: Check for data skew in stages
SELECT
  s.name,
  s.parallel_inputs,
  s.compute_ms_avg,
  s.compute_ms_max,
  ROUND(s.compute_ms_max / NULLIF(s.compute_ms_avg, 0), 1) AS skew_ratio,
  s.shuffle_output_bytes_spilled,
  s.records_read,
  s.records_written
FROM `region-us`.INFORMATION_SCHEMA.JOBS,
UNNEST(job_stages) s
WHERE job_id = 'your-job-id-here'
ORDER BY s.slot_ms DESC;

-- 96. Step 3: Check if partition pruning occurred
-- Look at bytes processed vs total table size
SELECT
  ROUND(total_bytes_processed / POW(2,30), 2) AS gb_processed,
  ROUND(
    (SELECT SUM(total_logical_bytes) FROM `region-us`.INFORMATION_SCHEMA.TABLE_STORAGE
     WHERE table_name = 'events') / POW(2,30),
    2
  ) AS total_table_gb
FROM `region-us`.INFORMATION_SCHEMA.JOBS
WHERE job_id = 'your-job-id-here';
-- If gb_processed is close to total_table_gb, partition pruning is NOT working

-- 97. Step 4: Check concurrent load during the query
SELECT
  period_start,
  COUNT(DISTINCT job_id) AS concurrent_jobs,
  SUM(period_slot_ms) / 1000 AS total_slots
FROM `region-us`.INFORMATION_SCHEMA.JOBS_TIMELINE
WHERE period_start BETWEEN
  (SELECT start_time FROM `region-us`.INFORMATION_SCHEMA.JOBS WHERE job_id = 'your-job-id-here')
  AND
  (SELECT end_time FROM `region-us`.INFORMATION_SCHEMA.JOBS WHERE job_id = 'your-job-id-here')
GROUP BY period_start
ORDER BY period_start;
```

### Playbook: Cost Spike Investigation

```sql
-- 98. Step 1: Compare daily cost to baseline
SELECT
  DATE(creation_time) AS day,
  ROUND(SUM(total_bytes_billed) / POW(2,40) * 6.25, 2) AS est_cost_usd,
  COUNT(*) AS query_count
FROM `region-us`.INFORMATION_SCHEMA.JOBS
WHERE creation_time > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 14 DAY)
  AND job_type = 'QUERY'
  AND state = 'DONE'
GROUP BY day
ORDER BY day;

-- 99. Step 2: Identify top cost contributors on the spike day
SELECT
  user_email,
  ROUND(SUM(total_bytes_billed) / POW(2,40) * 6.25, 2) AS est_cost_usd,
  COUNT(*) AS query_count,
  MAX(SUBSTR(query, 1, 200)) AS sample_query
FROM `region-us`.INFORMATION_SCHEMA.JOBS
WHERE DATE(creation_time) = '2026-04-07'  -- the spike date
  AND job_type = 'QUERY'
  AND state = 'DONE'
GROUP BY user_email
ORDER BY est_cost_usd DESC
LIMIT 10;

-- 100. Step 3: Check for new or changed queries
SELECT
  FARM_FINGERPRINT(query) AS qfp,
  MIN(creation_time) AS first_seen,
  COUNT(*) AS exec_count,
  ROUND(SUM(total_bytes_billed) / POW(2,40) * 6.25, 2) AS total_cost_usd,
  MIN(SUBSTR(query, 1, 200)) AS sample
FROM `region-us`.INFORMATION_SCHEMA.JOBS
WHERE DATE(creation_time) = '2026-04-07'
  AND job_type = 'QUERY'
  AND state = 'DONE'
GROUP BY qfp
HAVING first_seen > TIMESTAMP('2026-04-06')  -- new queries
ORDER BY total_cost_usd DESC;

-- 101. Step 4: Check streaming cost contribution
SELECT
  TIMESTAMP_TRUNC(start_timestamp, HOUR) AS hour,
  SUM(total_rows) AS rows,
  ROUND(SUM(total_input_bytes) / POW(2,30), 2) AS gb_ingested,
  ROUND(SUM(total_input_bytes) / POW(2,30) * 0.05, 4) AS streaming_cost_usd
FROM `region-us`.INFORMATION_SCHEMA.STREAMING_TIMELINE
WHERE DATE(start_timestamp) = '2026-04-07'
GROUP BY hour
ORDER BY hour;
```

### Playbook: Slot Contention Resolution

```sql
-- 102. Step 1: Check overall slot utilization
SELECT
  TIMESTAMP_TRUNC(period_start, MINUTE) AS minute,
  SUM(period_slot_ms) / 1000 AS slots_used,
  COUNT(DISTINCT job_id) AS concurrent_jobs
FROM `region-us`.INFORMATION_SCHEMA.JOBS_TIMELINE
WHERE period_start > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 2 HOUR)
GROUP BY minute
ORDER BY minute;

-- 103. Step 2: Identify slot-heavy queries
SELECT
  job_id,
  user_email,
  total_slot_ms,
  ROUND(total_slot_ms / 1000 / 3600, 2) AS slot_hours,
  TIMESTAMP_DIFF(end_time, start_time, SECOND) AS wall_clock_sec,
  SUBSTR(query, 1, 200) AS query_prefix,
  reservation_id
FROM `region-us`.INFORMATION_SCHEMA.JOBS
WHERE creation_time > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 2 HOUR)
  AND job_type = 'QUERY'
  AND state = 'DONE'
ORDER BY total_slot_ms DESC
LIMIT 20;

-- 104. Step 3: Reservation utilization breakdown
SELECT
  reservation_id,
  TIMESTAMP_TRUNC(period_start, MINUTE) AS minute,
  SUM(period_slot_ms) / 1000 AS slots_used
FROM `region-us`.INFORMATION_SCHEMA.JOBS_TIMELINE
WHERE period_start > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 2 HOUR)
GROUP BY reservation_id, minute
ORDER BY minute, reservation_id;

-- 105. Step 4: Jobs queued (waiting for slots)
SELECT
  job_id,
  user_email,
  creation_time,
  start_time,
  TIMESTAMP_DIFF(start_time, creation_time, SECOND) AS queue_time_sec,
  SUBSTR(query, 1, 200) AS query_prefix
FROM `region-us`.INFORMATION_SCHEMA.JOBS
WHERE creation_time > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 2 HOUR)
  AND TIMESTAMP_DIFF(start_time, creation_time, SECOND) > 5
ORDER BY queue_time_sec DESC;
```

### Playbook: Streaming Troubleshooting

```sql
-- 106. Step 1: Current streaming health
SELECT
  table_schema,
  table_name,
  start_timestamp,
  total_rows,
  total_input_bytes,
  error_count
FROM `region-us`.INFORMATION_SCHEMA.STREAMING_TIMELINE
WHERE start_timestamp > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)
  AND error_count > 0
ORDER BY start_timestamp DESC;

-- 107. Step 2: Error rate trend
SELECT
  TIMESTAMP_TRUNC(start_timestamp, MINUTE) AS minute,
  SUM(total_rows) AS rows_attempted,
  SUM(error_count) AS errors,
  ROUND(SAFE_DIVIDE(SUM(error_count), SUM(total_rows)) * 100, 2) AS error_pct
FROM `region-us`.INFORMATION_SCHEMA.STREAMING_TIMELINE
WHERE start_timestamp > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 6 HOUR)
GROUP BY minute
ORDER BY minute;

-- 108. Step 3: Per-table streaming volume
SELECT
  table_schema,
  table_name,
  SUM(total_rows) AS total_rows,
  ROUND(SUM(total_input_bytes) / POW(2,30), 2) AS gb_ingested,
  SUM(error_count) AS total_errors,
  MIN(start_timestamp) AS first_activity,
  MAX(start_timestamp) AS last_activity
FROM `region-us`.INFORMATION_SCHEMA.STREAMING_TIMELINE
WHERE start_timestamp > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
GROUP BY table_schema, table_name
ORDER BY total_rows DESC;
```

## Additional Diagnostic Queries

```sql
-- 109. Tables with no partitioning or clustering (optimization candidates)
SELECT
  t.table_schema,
  t.table_name,
  ts.total_rows,
  ROUND(ts.total_logical_bytes / POW(2,30), 2) AS logical_gb,
  IFNULL(
    (SELECT 'YES' FROM `region-us`.INFORMATION_SCHEMA.COLUMNS c
     WHERE c.table_name = t.table_name
       AND c.table_schema = t.table_schema
       AND c.is_partitioning_column = 'YES'
     LIMIT 1),
    'NO'
  ) AS is_partitioned,
  IFNULL(
    (SELECT 'YES' FROM `region-us`.INFORMATION_SCHEMA.COLUMNS c
     WHERE c.table_name = t.table_name
       AND c.table_schema = t.table_schema
       AND c.clustering_ordinal_position IS NOT NULL
     LIMIT 1),
    'NO'
  ) AS is_clustered
FROM `region-us`.INFORMATION_SCHEMA.TABLES t
JOIN `region-us`.INFORMATION_SCHEMA.TABLE_STORAGE ts
  ON t.table_schema = ts.table_schema AND t.table_name = ts.table_name
WHERE t.table_type = 'BASE TABLE'
  AND ts.total_logical_bytes > 1073741824  -- > 1 GB
ORDER BY ts.total_logical_bytes DESC;

-- 110. Query cache hit rate
SELECT
  DATE(creation_time) AS day,
  COUNTIF(cache_hit) AS cache_hits,
  COUNT(*) AS total_queries,
  ROUND(COUNTIF(cache_hit) / COUNT(*) * 100, 1) AS cache_hit_pct
FROM `region-us`.INFORMATION_SCHEMA.JOBS
WHERE creation_time > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
  AND job_type = 'QUERY'
  AND state = 'DONE'
GROUP BY day
ORDER BY day;

-- 111. BI Engine statistics (if BI Engine is enabled)
SELECT
  project_id,
  project_number,
  bi_engine_mode,
  bi_engine_reasons
FROM `region-us`.INFORMATION_SCHEMA.JOBS
WHERE creation_time > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
  AND bi_engine_statistics IS NOT NULL
LIMIT 20;

-- 112. Materialized view refresh jobs
SELECT
  job_id,
  creation_time,
  destination_table.table_id AS mv_name,
  total_bytes_billed,
  total_slot_ms,
  TIMESTAMP_DIFF(end_time, start_time, SECOND) AS duration_sec,
  state,
  error_result.message AS error_message
FROM `region-us`.INFORMATION_SCHEMA.JOBS
WHERE creation_time > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
  AND job_type = 'QUERY'
  AND statement_type = 'CREATE_TABLE_AS_SELECT'
  AND destination_table.table_id LIKE '%_mv%'
ORDER BY creation_time DESC;

-- 113. Long-running jobs (currently executing)
SELECT
  job_id,
  user_email,
  creation_time,
  TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), creation_time, SECOND) AS running_seconds,
  total_bytes_processed,
  state,
  SUBSTR(query, 1, 300) AS query_prefix
FROM `region-us`.INFORMATION_SCHEMA.JOBS
WHERE state IN ('RUNNING', 'PENDING')
ORDER BY creation_time;

-- 114. Project-level quota usage estimate (on-demand bytes per day)
SELECT
  DATE(creation_time) AS day,
  ROUND(SUM(total_bytes_billed) / POW(2,40), 4) AS tb_billed
FROM `region-us`.INFORMATION_SCHEMA.JOBS
WHERE creation_time > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
  AND job_type = 'QUERY'
  AND state = 'DONE'
GROUP BY day
ORDER BY day;

-- 115. Tables referenced most frequently (candidates for optimization)
SELECT
  ref.project_id,
  ref.dataset_id,
  ref.table_id,
  COUNT(*) AS reference_count,
  ROUND(SUM(j.total_bytes_billed) / POW(2,40) * 6.25, 2) AS total_cost_usd
FROM `region-us`.INFORMATION_SCHEMA.JOBS j,
UNNEST(referenced_tables) ref
WHERE j.creation_time > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
  AND j.job_type = 'QUERY'
  AND j.state = 'DONE'
GROUP BY ref.project_id, ref.dataset_id, ref.table_id
ORDER BY reference_count DESC
LIMIT 20;
```

## gcloud and bq CLI Configuration

```bash
# 116. Check current gcloud configuration
gcloud config list

# 117. Set default project
gcloud config set project my-project

# 118. Set default BigQuery location
bq --location=US query 'SELECT 1'

# 119. Authenticate with service account
gcloud auth activate-service-account --key-file=key.json

# 120. List BigQuery datasets via gcloud (alternative to bq ls)
gcloud alpha bq datasets list

# 121. Get IAM policy for a dataset
bq show --format=prettyjson my_dataset | python3 -c "import json,sys; d=json.load(sys.stdin); print(json.dumps(d.get('access',[]),indent=2))"

# 122. Describe a table with gcloud
gcloud alpha bq tables describe my_table --dataset=my_dataset

# 123. Cancel a running job
bq cancel job_id_here

# 124. Cancel all running jobs for current project
bq ls --jobs --all --max_results=100 --format=json | python3 -c "
import json, sys, subprocess
jobs = json.load(sys.stdin)
for j in jobs:
    if j.get('status',{}).get('state') == 'RUNNING':
        subprocess.run(['bq','cancel',j['jobReference']['jobId']])
"

# 125. Check BigQuery API quota usage
gcloud services list --enabled --filter="bigquery"
gcloud alpha services quota list --service=bigquery.googleapis.com --consumer=projects/my-project
```
