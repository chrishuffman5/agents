# BigQuery Best Practices Reference

## Data Modeling

### Denormalization Over Normalization

BigQuery is a columnar analytics engine, not an OLTP database. Denormalized (flat or nested) schemas outperform normalized star/snowflake schemas:

- **Flat tables:** Wide tables with many columns. BigQuery only reads referenced columns, so width is not a concern.
- **Nested and repeated fields (STRUCT/ARRAY):** Preserve relationships without JOINs. BigQuery stores nested fields in columnar format and can push predicates into nested structures.
- **Avoid excessive JOINs:** Each JOIN requires a shuffle. Denormalize dimension data into fact tables when dimensions are small or change infrequently.

**When to use nested/repeated fields:**
```sql
CREATE TABLE project.dataset.orders (
  order_id STRING NOT NULL,
  order_date DATE NOT NULL,
  customer STRUCT<
    id STRING,
    name STRING,
    tier STRING
  >,
  line_items ARRAY<STRUCT<
    product_id STRING,
    product_name STRING,
    quantity INT64,
    unit_price NUMERIC
  >>
)
PARTITION BY order_date
CLUSTER BY customer.id;
```

Benefits:
- Queries on `customer.tier` or `line_items` do not require a JOIN
- BigQuery reads only the nested columns referenced in the query
- Single atomic write for the entire order with its items

**When normalization is still appropriate:**
- Large dimension tables (>1 GB) that change frequently
- Dimensions shared across many fact tables where storage cost of duplication is a concern
- When real-time dimension updates are required (use CDC or materialized views to keep denormalized copies fresh)

### Partitioning Strategy

**Decision framework:**

1. **Identify the primary filter column** -- The column almost always present in WHERE clauses. Usually a date/timestamp for event data, an integer ID for entity data.
2. **Choose granularity** -- Daily partitioning is the most common. Use hourly for high-volume, sub-day query patterns. Monthly/yearly for low-volume, long-retention data.
3. **Set partition expiration** -- Automatically drop partitions older than N days to control storage costs.
4. **Enforce partition filters** -- Set `require_partition_filter = true` to prevent accidental full-table scans.

**Common patterns:**

| Data Type | Partition Column | Granularity | Clustering |
|---|---|---|---|
| Web events | event_timestamp | HOUR or DAY | user_id, event_type |
| Transactions | transaction_date | DAY | customer_id, product_category |
| IoT telemetry | ingestion_time (_PARTITIONTIME) | HOUR | device_id, metric_name |
| User profiles | RANGE_BUCKET(user_id) | Integer range | region, account_type |
| Log data | log_date | DAY | severity, service_name |

**Anti-patterns:**
- Partitioning on a column rarely used in filters -- partitions exist but are never pruned
- Too many small partitions (e.g., hourly partitioning on a low-volume table) -- overhead exceeds benefit
- Not setting `require_partition_filter` on large tables -- one bad query scans all partitions

### Clustering Strategy

**Column selection guidelines:**
1. First clustering column: highest-cardinality column most used in WHERE, JOIN, or GROUP BY
2. Second through fourth: next most-selective filter columns, in order of query frequency
3. Avoid clustering on columns never filtered (it wastes re-clustering effort)

**Clustering + partitioning interaction:**
- Clustering is applied within each partition
- If queries always filter on the partition column AND a clustering column, both pruning mechanisms apply
- For tables under 1 GB, clustering provides minimal benefit (data fits in a few blocks regardless)

**Re-clustering:**
- BigQuery automatically re-clusters in the background, at no cost
- Newly inserted data may not be fully clustered until background re-clustering runs
- For streaming data, re-clustering happens periodically, not immediately
- DML (UPDATE, DELETE, MERGE) does not disrupt clustering

### Primary Keys and Foreign Keys

BigQuery supports primary key and foreign key constraints, but they are NOT ENFORCED:

```sql
CREATE TABLE project.dataset.orders (
  order_id STRING NOT NULL,
  customer_id STRING NOT NULL,
  order_date DATE,
  PRIMARY KEY (order_id) NOT ENFORCED
);

CREATE TABLE project.dataset.order_items (
  item_id STRING NOT NULL,
  order_id STRING NOT NULL,
  product_id STRING NOT NULL,
  quantity INT64,
  PRIMARY KEY (item_id) NOT ENFORCED,
  FOREIGN KEY (order_id) REFERENCES project.dataset.orders(order_id) NOT ENFORCED
);
```

**Why declare non-enforced constraints?**
- The query optimizer uses primary key and foreign key metadata to optimize JOIN elimination and predicate pushdown
- CDC operations (upsert/delete via Storage Write API) require a primary key
- Documentation and data modeling clarity

## Query Optimization

### Column Pruning

Every column in a SELECT list contributes to bytes scanned (and cost in on-demand mode):

```sql
-- Bad: scans all columns
SELECT * FROM project.dataset.wide_table WHERE event_date = '2026-04-01';

-- Good: scan only needed columns
SELECT event_id, user_id, event_type
FROM project.dataset.wide_table
WHERE event_date = '2026-04-01';
```

### Partition and Cluster Pruning

```sql
-- Partition pruning (hard elimination)
SELECT * FROM project.dataset.events
WHERE event_date BETWEEN '2026-01-01' AND '2026-03-31';

-- Cluster pruning (block-level elimination)
SELECT * FROM project.dataset.events
WHERE event_date = '2026-04-01'
  AND user_id = 'user-123';

-- Anti-pattern: function on partition column prevents pruning
SELECT * FROM project.dataset.events
WHERE EXTRACT(YEAR FROM event_date) = 2026;  -- NO pruning

-- Fix: use range predicate
SELECT * FROM project.dataset.events
WHERE event_date >= '2026-01-01' AND event_date < '2027-01-01';  -- Pruning works
```

### JOIN Optimization

**Best practices:**
1. **Place the largest table first** (left side of JOIN). BigQuery uses the right side as the build side for hash joins.
2. **Filter before joining** -- Apply WHERE filters before the JOIN, or use subqueries/CTEs to pre-filter.
3. **Avoid cross-joins** unless intentional and with small tables.
4. **Use broadcast joins** for small-to-large joins. BigQuery automatically broadcasts small tables (<~10 MB), but you can hint with JOIN EACH for hash distribution.
5. **Avoid joining on skewed keys** -- Pre-filter or salt skewed keys.

```sql
-- Good: filter before join
WITH filtered_orders AS (
  SELECT order_id, customer_id, order_date, total
  FROM project.dataset.orders
  WHERE order_date = '2026-04-01'
)
SELECT o.order_id, c.name, o.total
FROM filtered_orders o
JOIN project.dataset.customers c ON o.customer_id = c.customer_id;

-- Anti-pattern: join then filter (shuffles all data before filtering)
SELECT o.order_id, c.name, o.total
FROM project.dataset.orders o
JOIN project.dataset.customers c ON o.customer_id = c.customer_id
WHERE o.order_date = '2026-04-01';
-- Note: the optimizer often pushes predicates down, but writing explicit pre-filters
-- ensures pruning and makes intent clear.
```

### Approximate Aggregation

For exploratory analysis, approximate functions are faster and cheaper:

```sql
-- Exact (expensive for large datasets)
SELECT COUNT(DISTINCT user_id) FROM project.dataset.events;

-- Approximate (uses HyperLogLog++, much faster)
SELECT APPROX_COUNT_DISTINCT(user_id) FROM project.dataset.events;

-- Approximate quantiles
SELECT APPROX_QUANTILES(response_time_ms, 100)[OFFSET(50)] AS p50,
       APPROX_QUANTILES(response_time_ms, 100)[OFFSET(95)] AS p95,
       APPROX_QUANTILES(response_time_ms, 100)[OFFSET(99)] AS p99
FROM project.dataset.events;

-- Approximate top count
SELECT APPROX_TOP_COUNT(event_type, 10) FROM project.dataset.events;
```

### Window Functions Best Practices

Window functions can be expensive because they require sorting:

```sql
-- Efficient: partition by a column with reasonable cardinality
SELECT
  user_id,
  event_date,
  event_type,
  ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY event_date DESC) AS rn
FROM project.dataset.events
QUALIFY rn = 1;  -- BigQuery-specific QUALIFY clause

-- Anti-pattern: window over entire table without PARTITION BY
SELECT
  event_id,
  ROW_NUMBER() OVER (ORDER BY event_date) AS global_row_num  -- single partition, all data in one slot
FROM project.dataset.events;
```

### Temporary Tables and CTEs

**When to use temp tables over CTEs:**
- When the same intermediate result is referenced multiple times (CTEs are re-evaluated each time)
- When intermediate results are large and re-scanning is expensive
- When you need to break a complex query into debuggable stages

```sql
-- Materialized temp table (survives for session duration)
CREATE TEMP TABLE filtered_events AS
SELECT event_id, user_id, event_date, event_type
FROM project.dataset.events
WHERE event_date BETWEEN '2026-01-01' AND '2026-03-31'
  AND event_type IN ('purchase', 'signup');

-- Use temp table in subsequent queries
SELECT user_id, COUNT(*) AS purchase_count
FROM filtered_events
WHERE event_type = 'purchase'
GROUP BY user_id;
```

### MERGE for Upserts

```sql
MERGE project.dataset.target T
USING project.dataset.staging S
ON T.id = S.id
WHEN MATCHED THEN
  UPDATE SET
    T.name = S.name,
    T.updated_at = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN
  INSERT (id, name, created_at, updated_at)
  VALUES (S.id, S.name, CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP());
```

**MERGE best practices:**
- Ensure the staging table is small relative to the target (MERGE scans the full target partition)
- Partition the target table and include partition filters in the ON clause to limit scan scope
- For high-frequency upserts, consider Storage Write API with CDC instead of repeated MERGE

### Scripting and Procedures

BigQuery supports multi-statement SQL scripts and stored procedures:

```sql
-- Scripting with variables and control flow
DECLARE start_date DATE DEFAULT DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY);
DECLARE end_date DATE DEFAULT CURRENT_DATE();

CREATE TEMP TABLE daily_stats AS
SELECT
  event_date,
  COUNT(*) AS event_count,
  COUNT(DISTINCT user_id) AS unique_users
FROM project.dataset.events
WHERE event_date BETWEEN start_date AND end_date
GROUP BY event_date;

IF (SELECT MAX(event_count) FROM daily_stats) > 1000000 THEN
  SELECT 'High volume detected' AS alert, *
  FROM daily_stats
  WHERE event_count > 1000000;
ELSE
  SELECT 'Normal volume' AS status;
END IF;

-- Stored procedure
CREATE OR REPLACE PROCEDURE project.dataset.refresh_summary(target_date DATE)
BEGIN
  DELETE FROM project.dataset.daily_summary WHERE summary_date = target_date;
  INSERT INTO project.dataset.daily_summary
  SELECT
    target_date AS summary_date,
    event_type,
    COUNT(*) AS count,
    COUNT(DISTINCT user_id) AS unique_users
  FROM project.dataset.events
  WHERE event_date = target_date
  GROUP BY event_type;
END;

-- Call the procedure
CALL project.dataset.refresh_summary('2026-04-01');
```

## Cost Management

### On-Demand Cost Controls

```sql
-- Dry run: check bytes before executing
-- (via bq CLI)
-- bq query --dry_run --use_legacy_sql=false 'SELECT ...'

-- Set maximum bytes billed per query
-- In bq CLI:
-- bq query --maximum_bytes_billed=10000000000 'SELECT ...'

-- In SQL (session level):
SET @@dataset_id = 'my_dataset';
```

**Project-level quotas:**
- Set custom quotas in Cloud Console > BigQuery > Quotas
- `Query usage per day per user` -- limits daily bytes scanned per user
- `Query usage per day` -- limits daily bytes scanned for entire project

### Editions Cost Controls

- **Baseline slots:** Set to average steady-state demand. Billed regardless of usage.
- **Autoscale max:** Set to peak demand. Burst slots billed only when used.
- **Idle slot sharing:** Allow idle slots in one reservation to be used by other reservations (prevents waste)
- **Separate reservations for different workloads:** ETL vs interactive analytics vs ML, with different baseline/max configurations
- **Commitment planning:** Analyze historical slot usage (via INFORMATION_SCHEMA.JOBS_TIMELINE) to right-size commitments

### Storage Cost Optimization

1. **Partition expiration:** Automatically drop old partitions
   ```sql
   ALTER TABLE project.dataset.events
   SET OPTIONS (partition_expiration_days = 365);
   ```

2. **Table expiration:** Automatically drop temporary or staging tables
   ```sql
   ALTER TABLE project.dataset.staging
   SET OPTIONS (expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY));
   ```

3. **Time travel window reduction:** Reduce from 7 days to 2 days for tables that do not need long recovery
   ```sql
   ALTER TABLE project.dataset.events
   SET OPTIONS (max_time_travel_hours = 48);
   ```

4. **Identify unused tables:**
   ```sql
   SELECT
     table_schema,
     table_name,
     TIMESTAMP_MILLIS(last_modified_time) AS last_modified,
     ROUND(size_bytes / POW(10,9), 2) AS size_gb
   FROM project.dataset.__TABLES__
   WHERE TIMESTAMP_MILLIS(last_modified_time) < TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 180 DAY)
   ORDER BY size_bytes DESC;
   ```

5. **Monitor storage by type:**
   ```sql
   SELECT
     table_schema,
     table_name,
     ROUND(active_logical_bytes / POW(2,30), 2) AS active_gb,
     ROUND(long_term_logical_bytes / POW(2,30), 2) AS long_term_gb,
     ROUND(time_travel_physical_bytes / POW(2,30), 2) AS time_travel_gb
   FROM `region-us`.INFORMATION_SCHEMA.TABLE_STORAGE
   ORDER BY total_logical_bytes DESC
   LIMIT 50;
   ```

### Cost Monitoring Queries

```sql
-- Top 20 most expensive queries in last 7 days
SELECT
  user_email,
  job_id,
  query,
  total_bytes_billed,
  ROUND(total_bytes_billed / POW(2,40) * 6.25, 2) AS estimated_cost_usd,
  total_slot_ms,
  creation_time
FROM `region-us`.INFORMATION_SCHEMA.JOBS
WHERE creation_time > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
  AND job_type = 'QUERY'
  AND state = 'DONE'
ORDER BY total_bytes_billed DESC
LIMIT 20;

-- Daily cost trend
SELECT
  DATE(creation_time) AS query_date,
  COUNT(*) AS query_count,
  ROUND(SUM(total_bytes_billed) / POW(2,40) * 6.25, 2) AS estimated_cost_usd,
  ROUND(SUM(total_bytes_billed) / POW(2,40), 2) AS tb_scanned
FROM `region-us`.INFORMATION_SCHEMA.JOBS
WHERE creation_time > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
  AND job_type = 'QUERY'
  AND state = 'DONE'
GROUP BY query_date
ORDER BY query_date;

-- Cost by user
SELECT
  user_email,
  COUNT(*) AS query_count,
  ROUND(SUM(total_bytes_billed) / POW(2,40) * 6.25, 2) AS estimated_cost_usd
FROM `region-us`.INFORMATION_SCHEMA.JOBS
WHERE creation_time > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
  AND job_type = 'QUERY'
  AND state = 'DONE'
GROUP BY user_email
ORDER BY estimated_cost_usd DESC;
```

## Data Ingestion Best Practices

### Batch Loading

| Method | Format | Best For | Key Options |
|---|---|---|---|
| `bq load` | CSV, JSON, Avro, Parquet, ORC | Ad hoc loads, small-to-medium files | `--autodetect`, `--schema`, `--source_format` |
| Load job (API) | Same as above | Programmatic ETL pipelines | Supports job configuration, notification |
| BigQuery Data Transfer Service | Varies | Scheduled, recurring loads from SaaS/cloud sources | Managed, automatic retry |
| Dataflow | Any | Complex transformations during load | Streaming or batch, Apache Beam SDK |
| Cloud Storage transfer | Parquet, Avro preferred | Large-scale migration from other clouds | Parallel, resumable |

**Format recommendations:**
- **Parquet or Avro** for production pipelines -- columnar/binary formats load faster and support schema evolution
- **CSV** only for simple, ad hoc loads -- requires schema specification, no nested type support, escaping issues
- **JSONL (newline-delimited JSON)** for semi-structured data with nested/repeated fields
- **ORC** when migrating from Hadoop/Hive ecosystems

**Loading best practices:**
1. Load into partitioned tables using `--time_partitioning_field` or hive-partitioned URIs
2. Use `WRITE_APPEND` for incremental loads, `WRITE_TRUNCATE` for full refreshes
3. For large loads (>1 TB), split into multiple files and load in parallel -- BigQuery parallelizes across files
4. Use Avro or Parquet to avoid schema declaration -- BigQuery auto-detects from the file format
5. Validate with `--dry_run` before large production loads

### Streaming Best Practices

**Storage Write API (recommended):**
1. Use the default stream for simplicity (at-least-once) or committed streams for exactly-once
2. Batch rows into larger requests (100-500 rows per append) to reduce RPC overhead
3. Implement exponential backoff for transient errors
4. Use connection pooling for high-throughput pipelines
5. Monitor with INFORMATION_SCHEMA.STREAMING_TIMELINE

**Legacy streaming inserts:**
1. Batch up to 500 rows per insertAll request (max 10 MB per request)
2. Use `insertId` for best-effort deduplication (dedup window is a few minutes)
3. Implement exponential backoff for 429 (quota exceeded) and 500/503 (server errors)
4. Data is available for querying within seconds but may not be immediately available for DML or export (streaming buffer)

## Materialized View Best Practices

```sql
-- Create a materialized view for a common aggregation
CREATE MATERIALIZED VIEW project.dataset.daily_sales_mv
PARTITION BY sale_date
CLUSTER BY product_category
AS
SELECT
  DATE(sale_timestamp) AS sale_date,
  product_category,
  COUNT(*) AS sale_count,
  SUM(amount) AS total_amount,
  AVG(amount) AS avg_amount
FROM project.dataset.sales
GROUP BY sale_date, product_category;

-- With max staleness (reduces refresh frequency)
CREATE MATERIALIZED VIEW project.dataset.hourly_metrics_mv
OPTIONS (enable_refresh = true, refresh_interval_minutes = 30, max_staleness = INTERVAL 4 HOUR)
AS
SELECT
  TIMESTAMP_TRUNC(event_time, HOUR) AS hour,
  event_type,
  COUNT(*) AS event_count
FROM project.dataset.events
GROUP BY hour, event_type;
```

**Guidelines:**
- Materialized views are most effective for aggregations over large tables that are queried frequently
- Align partitioning and clustering with the base table for efficient incremental refresh
- Use `max_staleness` to accept slightly stale results in exchange for lower refresh cost
- BigQuery smart tuning automatically rewrites qualifying queries to use materialized views, even if the query does not reference the view directly
- Monitor refresh cost and frequency via INFORMATION_SCHEMA.JOBS (look for job_type = 'QUERY' with materialized view refresh labels)

## Security Best Practices

### Principle of Least Privilege

1. Grant `roles/bigquery.dataViewer` for read-only access to specific datasets
2. Use authorized views to share computed results without exposing source tables
3. Use column-level security to mask sensitive columns (PII, financial data)
4. Use row-level access policies to limit data visibility by user/group
5. Avoid granting `roles/bigquery.admin` broadly -- use targeted roles

### Authorized Views Pattern

```sql
-- 1. Create a view in a separate dataset
CREATE VIEW project.shared_dataset.customer_summary AS
SELECT
  customer_id,
  region,
  total_orders,
  total_revenue
FROM project.raw_dataset.customers;

-- 2. Authorize the view to access the source dataset
-- (via bq CLI)
-- bq update --view_uris=project:shared_dataset.customer_summary project:raw_dataset

-- 3. Grant users access to the shared_dataset only
-- They can query the view but cannot access raw_dataset directly
```

### Column-Level Security

1. Create a Data Catalog taxonomy and policy tags (via Console or API)
2. Assign policy tags to sensitive columns
3. Grant `roles/datacatalog.categoryFineGrainedReader` to users who should see the data
4. Users without the role receive masked or null values (with data masking) or an access denied error

### Data Masking

```sql
-- Dynamic data masking is configured via Data Catalog policy tags
-- Example masking rules:
-- - Email: user@example.com -> u***@example.com
-- - Phone: 555-123-4567 -> XXX-XXX-4567
-- - SSN: fully masked to NULL or constant
-- - SHA256: deterministic hash for joining without exposing raw values
-- - Date: extract year only
```

## Scheduling and Orchestration

### Scheduled Queries

```sql
-- Create a scheduled query (via bq CLI)
-- bq mk --transfer_config \
--   --target_dataset=my_dataset \
--   --display_name='Daily Summary' \
--   --schedule='every 24 hours' \
--   --params='{"query":"SELECT ...","destination_table_name_template":"daily_summary_{run_date}","write_disposition":"WRITE_TRUNCATE"}'
```

**Parameters:**
- `@run_time` -- the scheduled execution time (TIMESTAMP)
- `@run_date` -- the scheduled execution date (DATE)
- Use in queries for dynamic date filtering: `WHERE event_date = @run_date`

### Orchestration with Cloud Composer (Airflow)

- Use `BigQueryInsertJobOperator` for load, query, copy, and extract jobs
- Use `BigQueryCheckOperator` for data quality checks
- Use `BigQueryValueCheckOperator` for threshold validation
- Chain operators for complex ETL DAGs with dependency management

### Orchestration with Dataform

Dataform (integrated into BigQuery Studio) provides SQL-based transformation pipelines:

- SQLX files define transformations with `config` blocks for materialization type (table, view, incremental)
- Dependency management via `ref()` function
- Built-in assertions for data quality
- Git-based version control
- Scheduled execution from BigQuery Studio

## Disaster Recovery

### Backup Strategies

1. **Time travel (built-in):** 2-7 day recovery window. Automatic, no configuration needed.
2. **Table snapshots:** Point-in-time read-only copies. Lightweight (shared storage).
3. **Dataset copies:** Full copy to another region. Use BigQuery Data Transfer Service for automated cross-region copies.
4. **Export to Cloud Storage:** `bq extract` to Avro/Parquet in GCS. Use for long-term archival or cross-cloud backup.
5. **Enterprise Plus cross-region replication:** Automatic, managed disaster recovery with failover.

### Recovery Procedures

```sql
-- Recover from accidental DELETE using time travel
CREATE OR REPLACE TABLE project.dataset.my_table AS
SELECT * FROM project.dataset.my_table
FOR SYSTEM_TIME AS OF TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR);

-- Recover from accidental DROP using fail-safe
-- Contact Google Cloud support within the 7-day fail-safe window

-- Recover a specific partition
INSERT INTO project.dataset.events
SELECT * FROM project.dataset.events
FOR SYSTEM_TIME AS OF TIMESTAMP('2026-04-06 10:00:00 UTC')
WHERE event_date = '2026-04-06';
```

## Monitoring and Alerting

### Key Metrics to Monitor

| Metric | Source | Alert Threshold |
|---|---|---|
| Slot utilization | INFORMATION_SCHEMA.JOBS_TIMELINE | >90% sustained for 15+ minutes |
| Query failure rate | INFORMATION_SCHEMA.JOBS | >5% of queries failing |
| Bytes scanned per day | INFORMATION_SCHEMA.JOBS | >2x normal daily average |
| Streaming error rate | INFORMATION_SCHEMA.STREAMING_TIMELINE | Any sustained errors |
| Reservation utilization | Cloud Monitoring | >85% baseline utilization |
| Storage growth rate | INFORMATION_SCHEMA.TABLE_STORAGE | Unexpected spikes |

### Cloud Monitoring Integration

- BigQuery exports metrics to Cloud Monitoring automatically
- Key metric paths: `bigquery.googleapis.com/query/count`, `bigquery.googleapis.com/slots/total_available`, `bigquery.googleapis.com/storage/stored_bytes`
- Create alerting policies for slot saturation, error spikes, and cost anomalies
- Use Cloud Monitoring dashboards for real-time visibility
