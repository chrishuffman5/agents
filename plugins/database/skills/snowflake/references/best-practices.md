# Snowflake Best Practices Reference

## Warehouse Management

### Warehouse Sizing Strategy

**Start small, scale up based on evidence:**
1. Begin with X-Small or Small for new workloads
2. Monitor query profiles for spilling (local or remote storage)
3. If queries consistently spill, try the next size up
4. Doubling warehouse size roughly halves execution time for scan-heavy queries (linear scaling)
5. For complex queries with many JOINs, scaling up may yield diminishing returns beyond a certain point

**Sizing by workload type:**

| Workload | Start Size | Scale Trigger | Notes |
|----------|-----------|---------------|-------|
| Simple BI dashboards | XS-S | Queueing > 5s | Use multi-cluster for concurrency |
| Complex BI (many joins) | M-L | Spilling, >30s queries | Consider query acceleration |
| ETL/ELT (dbt, Fivetran) | M-XL | Pipeline SLA breach | Suspend immediately after batch |
| Data science (Snowpark) | M-L (Snowpark-optimized) | OOM errors in UDFs | 16x more memory per node |
| Ad-hoc analyst queries | S-M | Varies | Auto-suspend at 60s |
| Large data loads (COPY) | L-XL | File throughput | Parallelism scales with size |

### Auto-Suspend Tuning

```sql
-- Interactive workloads: 60 seconds (balance cost vs. cold-start latency)
ALTER WAREHOUSE bi_wh SET AUTO_SUSPEND = 60;

-- Batch ETL: suspend immediately after pipeline completes (manual control)
ALTER WAREHOUSE etl_wh SET AUTO_SUSPEND = 0;
-- Then in your pipeline orchestrator:
-- 1. ALTER WAREHOUSE etl_wh RESUME;
-- 2. Run all ETL queries
-- 3. ALTER WAREHOUSE etl_wh SUSPEND;

-- Heavy BI with frequent queries: 300 seconds (keep cache warm)
ALTER WAREHOUSE heavy_bi_wh SET AUTO_SUSPEND = 300;

-- Development: 60 seconds (cost-conscious)
ALTER WAREHOUSE dev_wh SET AUTO_SUSPEND = 60;
```

**Auto-suspend economics:**
- A Medium warehouse costs 4 credits/hour = 0.067 credits/minute
- If your BI users query every 2-3 minutes, auto-suspend at 60s wastes 1 minute of idle time per query gap
- If your BI users query every 10+ minutes, auto-suspend at 60s saves significant credits
- For truly sporadic workloads, 60s auto-suspend with auto-resume gives the best cost profile
- For sustained workloads, longer auto-suspend (300s) avoids repeated cold-start cache misses

### Multi-Cluster Warehouse Configuration (Enterprise+)

```sql
-- High-concurrency BI: scale out quickly
CREATE WAREHOUSE bi_wh
  WAREHOUSE_SIZE = 'MEDIUM'
  MIN_CLUSTER_COUNT = 1
  MAX_CLUSTER_COUNT = 5
  SCALING_POLICY = 'STANDARD'
  AUTO_SUSPEND = 300
  AUTO_RESUME = TRUE;

-- Cost-conscious BI: tolerate brief waits
CREATE WAREHOUSE bi_economy_wh
  WAREHOUSE_SIZE = 'MEDIUM'
  MIN_CLUSTER_COUNT = 1
  MAX_CLUSTER_COUNT = 3
  SCALING_POLICY = 'ECONOMY'
  AUTO_SUSPEND = 300
  AUTO_RESUME = TRUE;

-- Always-on minimum capacity (for guaranteed low latency)
CREATE WAREHOUSE critical_bi_wh
  WAREHOUSE_SIZE = 'MEDIUM'
  MIN_CLUSTER_COUNT = 2     -- always 2 clusters running
  MAX_CLUSTER_COUNT = 5
  SCALING_POLICY = 'STANDARD'
  AUTO_SUSPEND = 0          -- never suspend (guaranteed capacity)
  AUTO_RESUME = TRUE;
```

### Workload Isolation

**Separate warehouses per workload class:**
```sql
-- ETL/ELT loads (batch, can be large, auto-suspend aggressively)
CREATE WAREHOUSE etl_wh WAREHOUSE_SIZE = 'XLARGE' AUTO_SUSPEND = 60 AUTO_RESUME = TRUE;

-- BI dashboards (multi-cluster for concurrency)
CREATE WAREHOUSE bi_wh WAREHOUSE_SIZE = 'MEDIUM' MIN_CLUSTER_COUNT = 1 MAX_CLUSTER_COUNT = 4
  SCALING_POLICY = 'STANDARD' AUTO_SUSPEND = 300 AUTO_RESUME = TRUE;

-- Ad-hoc analyst queries (cost-conscious)
CREATE WAREHOUSE analyst_wh WAREHOUSE_SIZE = 'SMALL' AUTO_SUSPEND = 60 AUTO_RESUME = TRUE;

-- dbt models (dedicated, match to model complexity)
CREATE WAREHOUSE dbt_wh WAREHOUSE_SIZE = 'LARGE' AUTO_SUSPEND = 60 AUTO_RESUME = TRUE;

-- Data science / Snowpark
CREATE WAREHOUSE ds_wh WAREHOUSE_SIZE = 'MEDIUM' WAREHOUSE_TYPE = 'SNOWPARK-OPTIMIZED'
  AUTO_SUSPEND = 120 AUTO_RESUME = TRUE;
```

**Benefits of workload isolation:**
- No ETL jobs blocking BI queries
- Independent sizing and scaling per workload
- Clear cost attribution (credits per warehouse)
- Different auto-suspend/resume policies per workload
- Independent resource monitors per warehouse

## Cost Optimization

### Resource Monitors

```sql
-- Account-level monitor
CREATE RESOURCE MONITOR account_monthly
  WITH CREDIT_QUOTA = 5000
  FREQUENCY = MONTHLY
  START_TIMESTAMP = IMMEDIATELY
  TRIGGERS
    ON 50 PERCENT DO NOTIFY
    ON 75 PERCENT DO NOTIFY
    ON 90 PERCENT DO NOTIFY
    ON 100 PERCENT DO SUSPEND
    ON 110 PERCENT DO SUSPEND_IMMEDIATE;

ALTER ACCOUNT SET RESOURCE_MONITOR = account_monthly;

-- Warehouse-level monitor
CREATE RESOURCE MONITOR etl_daily
  WITH CREDIT_QUOTA = 200
  FREQUENCY = DAILY
  START_TIMESTAMP = IMMEDIATELY
  TRIGGERS
    ON 75 PERCENT DO NOTIFY
    ON 100 PERCENT DO SUSPEND;

ALTER WAREHOUSE etl_wh SET RESOURCE_MONITOR = etl_daily;
```

**Trigger actions:**
- `NOTIFY`: Sends notification to account admins (email, Snowsight)
- `SUSPEND`: Allows currently running queries to finish, then suspends the warehouse
- `SUSPEND_IMMEDIATE`: Immediately cancels all running queries and suspends

### Credit Consumption Monitoring

```sql
-- Daily credit consumption trend (last 30 days)
SELECT DATE_TRUNC('day', start_time) AS day,
       warehouse_name,
       SUM(credits_used) AS credits
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE start_time > DATEADD(day, -30, CURRENT_TIMESTAMP())
GROUP BY day, warehouse_name
ORDER BY day DESC, credits DESC;

-- Serverless feature credit consumption
SELECT DATE_TRUNC('day', start_time) AS day,
       service_type,
       SUM(credits_used) AS credits
FROM SNOWFLAKE.ACCOUNT_USAGE.SERVERLESS_TASK_HISTORY  -- for serverless tasks
WHERE start_time > DATEADD(day, -30, CURRENT_TIMESTAMP())
GROUP BY day, service_type
ORDER BY day DESC;

-- Automatic clustering credits
SELECT DATE_TRUNC('day', start_time) AS day,
       table_name,
       SUM(credits_used) AS credits
FROM SNOWFLAKE.ACCOUNT_USAGE.AUTOMATIC_CLUSTERING_HISTORY
WHERE start_time > DATEADD(day, -30, CURRENT_TIMESTAMP())
GROUP BY day, table_name
ORDER BY credits DESC;

-- Materialized view maintenance credits
SELECT DATE_TRUNC('day', start_time) AS day,
       table_name,
       SUM(credits_used) AS credits
FROM SNOWFLAKE.ACCOUNT_USAGE.MATERIALIZED_VIEW_REFRESH_HISTORY
WHERE start_time > DATEADD(day, -30, CURRENT_TIMESTAMP())
GROUP BY day, table_name
ORDER BY credits DESC;

-- Search optimization credits
SELECT DATE_TRUNC('day', start_time) AS day,
       table_name,
       SUM(credits_used) AS credits
FROM SNOWFLAKE.ACCOUNT_USAGE.SEARCH_OPTIMIZATION_HISTORY
WHERE start_time > DATEADD(day, -30, CURRENT_TIMESTAMP())
GROUP BY day, table_name
ORDER BY credits DESC;
```

### Storage Cost Optimization

```sql
-- Storage breakdown by table (identify largest consumers)
SELECT TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME,
       ACTIVE_BYTES / POWER(1024, 3) AS active_gb,
       TIME_TRAVEL_BYTES / POWER(1024, 3) AS time_travel_gb,
       FAILSAFE_BYTES / POWER(1024, 3) AS failsafe_gb,
       (ACTIVE_BYTES + TIME_TRAVEL_BYTES + FAILSAFE_BYTES) / POWER(1024, 3) AS total_gb
FROM SNOWFLAKE.ACCOUNT_USAGE.TABLE_STORAGE_METRICS
WHERE ACTIVE_BYTES > 0
ORDER BY total_gb DESC
LIMIT 50;

-- Tables with disproportionate Time Travel storage (high churn)
SELECT TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME,
       ACTIVE_BYTES / POWER(1024, 3) AS active_gb,
       TIME_TRAVEL_BYTES / POWER(1024, 3) AS time_travel_gb,
       CASE WHEN ACTIVE_BYTES > 0
            THEN ROUND(TIME_TRAVEL_BYTES::FLOAT / ACTIVE_BYTES, 2)
            ELSE 0 END AS tt_to_active_ratio
FROM SNOWFLAKE.ACCOUNT_USAGE.TABLE_STORAGE_METRICS
WHERE ACTIVE_BYTES > 1073741824  -- >1GB active
ORDER BY tt_to_active_ratio DESC
LIMIT 20;
```

**Storage reduction strategies:**
1. **Use transient tables for staging data:** `CREATE TRANSIENT TABLE` -- no Fail-Safe, 0-1 day Time Travel
2. **Reduce Time Travel for non-critical tables:** `ALTER TABLE t SET DATA_RETENTION_TIME_IN_DAYS = 1;`
3. **Drop unused tables/clones:** Each clone's divergent data consumes storage
4. **Use external tables for cold/archived data:** Query in-place from S3/Blob/GCS without Snowflake storage
5. **Compress semi-structured data:** Store normalized relational data instead of large JSON blobs when possible
6. **Monitor stage storage:** Files in internal stages consume storage; clean up after loading

### Query Cost Optimization

```sql
-- Most expensive queries by total execution time (last 7 days)
SELECT query_id, query_text, user_name, warehouse_name, warehouse_size,
       execution_time / 1000 AS exec_sec,
       bytes_scanned / POWER(1024, 3) AS gb_scanned,
       partitions_scanned, partitions_total,
       ROUND(partitions_scanned::FLOAT / NULLIF(partitions_total, 0) * 100, 2) AS pct_scanned
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time > DATEADD(day, -7, CURRENT_TIMESTAMP())
  AND execution_time > 30000
  AND warehouse_size IS NOT NULL
ORDER BY execution_time DESC
LIMIT 50;

-- Queries with poor partition pruning (scanning >50% of partitions)
SELECT query_id, SUBSTR(query_text, 1, 200) AS query_preview,
       partitions_scanned, partitions_total,
       ROUND(partitions_scanned::FLOAT / NULLIF(partitions_total, 0) * 100, 2) AS pct_scanned
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time > DATEADD(day, -7, CURRENT_TIMESTAMP())
  AND partitions_total > 100
  AND partitions_scanned::FLOAT / NULLIF(partitions_total, 0) > 0.5
  AND query_type = 'SELECT'
ORDER BY partitions_scanned DESC
LIMIT 50;

-- Queries that spill to storage (need larger warehouse or optimization)
SELECT query_id, SUBSTR(query_text, 1, 200) AS query_preview,
       warehouse_name, warehouse_size,
       bytes_spilled_to_local_storage / POWER(1024, 3) AS local_spill_gb,
       bytes_spilled_to_remote_storage / POWER(1024, 3) AS remote_spill_gb
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time > DATEADD(day, -7, CURRENT_TIMESTAMP())
  AND (bytes_spilled_to_local_storage > 0 OR bytes_spilled_to_remote_storage > 0)
ORDER BY (bytes_spilled_to_local_storage + bytes_spilled_to_remote_storage) DESC
LIMIT 50;
```

## Data Loading Best Practices

### COPY INTO Optimization

```sql
-- Optimal file sizing: 100-250MB compressed per file
-- Too many small files: high overhead per file
-- Too few large files: less parallelism

-- Parallel loading: Snowflake loads files in parallel across warehouse nodes
-- A Medium warehouse (4 nodes) can load 4+ files simultaneously
-- Maximize parallelism by splitting large datasets into many appropriately-sized files

-- Use Parquet or ORC for structured data (columnar, schema in file, compressed)
COPY INTO target_table
FROM @my_stage/data/
FILE_FORMAT = (TYPE = 'PARQUET')
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE  -- map by column name, not position
PATTERN = '.*[.]parquet';

-- CSV loading with options
COPY INTO target_table
FROM @my_stage/data/
FILE_FORMAT = (
    TYPE = 'CSV'
    FIELD_DELIMITER = ','
    RECORD_DELIMITER = '\n'
    SKIP_HEADER = 1
    NULL_IF = ('NULL', 'null', '')
    EMPTY_FIELD_AS_NULL = TRUE
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE
    ENCODING = 'UTF8'
)
ON_ERROR = 'CONTINUE'       -- or SKIP_FILE, ABORT_STATEMENT, SKIP_FILE_<num>
PURGE = TRUE                 -- delete files after successful load
SIZE_LIMIT = 10737418240;    -- stop after loading 10GB
```

### File Format Best Practices

```sql
-- Create reusable file formats
CREATE FILE FORMAT parquet_format TYPE = 'PARQUET' COMPRESSION = 'SNAPPY';

CREATE FILE FORMAT csv_format
  TYPE = 'CSV'
  FIELD_DELIMITER = ','
  SKIP_HEADER = 1
  NULL_IF = ('NULL', '')
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  COMPRESSION = 'GZIP';

CREATE FILE FORMAT json_format
  TYPE = 'JSON'
  STRIP_OUTER_ARRAY = TRUE     -- for JSON arrays: [{...}, {...}]
  STRIP_NULL_VALUES = TRUE
  COMPRESSION = 'GZIP';
```

### Snowpipe Best Practices

**File sizing for Snowpipe:**
- Ideal: 100-250MB compressed per file
- Minimum practical: 10MB (files smaller than this incur disproportionate overhead)
- If source produces tiny files, use a pre-aggregation step (e.g., S3 Lambda to batch files)

**Monitoring Snowpipe:**
```sql
-- Check pipe status
SELECT SYSTEM$PIPE_STATUS('my_pipe');
-- Returns JSON: executionState, pendingFileCount, lastIngestedTimestamp, etc.

-- Check copy history for errors
SELECT *
FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
    TABLE_NAME => 'target_table',
    START_TIME => DATEADD(hours, -24, CURRENT_TIMESTAMP())
))
WHERE status != 'LOADED'
ORDER BY last_load_time DESC;

-- Validate files before loading
COPY INTO target_table FROM @my_stage
  VALIDATION_MODE = 'RETURN_ERRORS';

COPY INTO target_table FROM @my_stage
  VALIDATION_MODE = 'RETURN_ALL_ERRORS';

COPY INTO target_table FROM @my_stage
  VALIDATION_MODE = 'RETURN_10_ROWS';
```

### Data Unloading

```sql
-- Unload to Parquet (preferred for downstream analytics)
COPY INTO @my_stage/export/
FROM (SELECT * FROM orders WHERE order_date > '2026-01-01')
FILE_FORMAT = (TYPE = 'PARQUET')
HEADER = TRUE
MAX_FILE_SIZE = 268435456   -- 256MB per file
OVERWRITE = TRUE;

-- Unload to CSV
COPY INTO @my_stage/export/
FROM orders
FILE_FORMAT = (TYPE = 'CSV' COMPRESSION = 'GZIP')
HEADER = TRUE
SINGLE = FALSE              -- multiple files for parallelism
MAX_FILE_SIZE = 268435456;

-- GET command to download from internal stage to local filesystem
GET @my_stage/export/ file:///tmp/export/;
```

## Schema Design

### Table Types and When to Use Them

| Table Type | Time Travel | Fail-Safe | Use Case |
|------------|-------------|-----------|----------|
| Permanent (default) | 0-90 days (edition-dependent) | 7 days | Production data, critical tables |
| Transient | 0-1 day | None | Staging, ETL intermediates, temp data |
| Temporary | 0-1 day | None | Session-scoped scratch tables |
| External | N/A | N/A | Query data in cloud storage (S3/Blob/GCS) |
| Iceberg | N/A | N/A | Open format interoperability |
| Dynamic | Inherited | Inherited | Declarative transformation pipelines |

**Rule of thumb:** Use transient tables for anything that is reloadable or recreatable. This saves Fail-Safe storage costs (7 days of storage for every byte of changed data).

### Clustering Key Design

**When to cluster:**
- Table is large (>1TB or billions of rows)
- Queries consistently filter on specific columns
- Partition pruning ratio is poor (>50% of partitions scanned for selective queries)
- Table receives ongoing DML that degrades natural clustering

**Clustering key selection:**
```sql
-- Check current clustering quality
SELECT SYSTEM$CLUSTERING_INFORMATION('orders', '(order_date, region)');
-- Key metrics:
--   average_overlaps: number of overlapping micro-partitions per value range (lower = better)
--   average_depth: average number of micro-partitions a single value spans (1.0 = perfect)
--   partition_count: total micro-partitions

-- Good clustering key candidates:
ALTER TABLE orders CLUSTER BY (order_date);                        -- time-series filtering
ALTER TABLE orders CLUSTER BY (order_date, region);                -- compound filter
ALTER TABLE events CLUSTER BY (TO_DATE(event_timestamp), event_type); -- expression-based

-- Bad clustering key choices:
-- CLUSTER BY (order_id)            -- too high cardinality (unique values)
-- CLUSTER BY (a, b, c, d, e)      -- too many columns (diminishing returns)
-- CLUSTER BY (status)              -- too low cardinality (only a few values)
```

### Naming Conventions

```sql
-- Databases: uppercase, descriptive
CREATE DATABASE RAW;          -- raw/landing data
CREATE DATABASE ANALYTICS;    -- transformed analytics data
CREATE DATABASE SANDBOX;      -- development/experimentation

-- Schemas: uppercase, functional grouping
CREATE SCHEMA RAW.SALESFORCE;
CREATE SCHEMA RAW.STRIPE;
CREATE SCHEMA ANALYTICS.FINANCE;
CREATE SCHEMA ANALYTICS.MARKETING;

-- Tables: uppercase, singular nouns
CREATE TABLE ANALYTICS.FINANCE.ORDER (...);
CREATE TABLE ANALYTICS.FINANCE.CUSTOMER (...);

-- Views: prefix with V_ or suffix with _VW for clarity
CREATE VIEW ANALYTICS.FINANCE.V_ACTIVE_CUSTOMERS AS ...;

-- Staging: prefix with STG_
CREATE TRANSIENT TABLE RAW.SALESFORCE.STG_ACCOUNTS (...);
```

### Semi-Structured Data Strategy

**Option 1: Raw VARIANT with typed views (flexible schema-on-read):**
```sql
-- Landing table
CREATE TABLE raw_events (
    src VARIANT,
    _loaded_at TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(),
    _file_name STRING DEFAULT METADATA$FILENAME
);

-- Typed view for analysis
CREATE VIEW v_events AS
SELECT
    src:event_id::STRING AS event_id,
    src:user_id::INTEGER AS user_id,
    src:event_type::STRING AS event_type,
    src:timestamp::TIMESTAMP_NTZ AS event_time,
    src:properties AS properties  -- keep nested data as VARIANT
FROM raw_events;
```

**Option 2: FLATTEN into relational tables (better performance for frequent queries):**
```sql
-- Transform JSON arrays into relational rows
INSERT INTO order_items
SELECT
    r.src:order_id::STRING AS order_id,
    f.value:item_id::STRING AS item_id,
    f.value:quantity::INTEGER AS quantity,
    f.value:price::DECIMAL(10,2) AS price
FROM raw_orders r,
LATERAL FLATTEN(input => r.src:items) f;
```

**When to choose each:**
- VARIANT + views: Schema evolves frequently, exploratory analysis, many optional fields
- Relational transformation: Stable schema, high-frequency queries, JOIN performance critical

## Security Best Practices

### Role Hierarchy Design

```
ACCOUNTADMIN (break-glass only)
├── SECURITYADMIN (manages roles and grants)
│   ├── USERADMIN (manages users)
│   └── [custom admin roles]
├── SYSADMIN (manages all databases and warehouses)
│   ├── ETL_ADMIN (manages ETL databases and warehouses)
│   │   └── ETL_ROLE (runs ETL jobs)
│   ├── ANALYTICS_ADMIN (manages analytics databases and warehouses)
│   │   ├── ANALYST_ROLE (reads analytics data)
│   │   └── DS_ROLE (reads analytics data + runs Snowpark)
│   └── RAW_ADMIN (manages raw/landing databases)
│       └── RAW_LOADER_ROLE (writes to raw tables)
└── PUBLIC (default, minimal permissions)
```

```sql
-- Create the hierarchy
CREATE ROLE etl_admin;
CREATE ROLE etl_role;
CREATE ROLE analytics_admin;
CREATE ROLE analyst_role;
CREATE ROLE ds_role;

GRANT ROLE etl_role TO ROLE etl_admin;
GRANT ROLE analyst_role TO ROLE analytics_admin;
GRANT ROLE ds_role TO ROLE analytics_admin;
GRANT ROLE etl_admin TO ROLE sysadmin;
GRANT ROLE analytics_admin TO ROLE sysadmin;

-- Grant object privileges
GRANT USAGE ON DATABASE analytics TO ROLE analyst_role;
GRANT USAGE ON ALL SCHEMAS IN DATABASE analytics TO ROLE analyst_role;
GRANT SELECT ON ALL TABLES IN DATABASE analytics TO ROLE analyst_role;
GRANT SELECT ON FUTURE TABLES IN DATABASE analytics TO ROLE analyst_role;
GRANT USAGE ON WAREHOUSE analyst_wh TO ROLE analyst_role;
```

### Principle of Least Privilege

```sql
-- NEVER use ACCOUNTADMIN for routine operations
-- NEVER grant ACCOUNTADMIN to service accounts
-- Use SECURITYADMIN only for role/user management
-- Use SYSADMIN as the top of the object-access hierarchy
-- Grant roles to users, not direct privileges

-- Service account pattern
CREATE USER svc_dbt
  LOGIN_NAME = 'svc_dbt'
  DEFAULT_WAREHOUSE = 'dbt_wh'
  DEFAULT_ROLE = 'dbt_role'
  MUST_CHANGE_PASSWORD = FALSE;

-- Key-pair authentication for service accounts (no passwords)
ALTER USER svc_dbt SET RSA_PUBLIC_KEY = 'MIIBIjANBg...';
```

### Data Masking Patterns

```sql
-- Dynamic masking policy: show full value to authorized roles, mask for others
CREATE MASKING POLICY email_mask AS (val STRING) RETURNS STRING ->
  CASE
    WHEN CURRENT_ROLE() IN ('PII_ADMIN', 'COMPLIANCE_ROLE') THEN val
    WHEN CURRENT_ROLE() IN ('ANALYST_ROLE') THEN REGEXP_REPLACE(val, '.+@', '***@')
    ELSE '***MASKED***'
  END;

-- Numeric masking (show to PII roles, zero for others)
CREATE MASKING POLICY salary_mask AS (val NUMBER) RETURNS NUMBER ->
  CASE
    WHEN CURRENT_ROLE() IN ('HR_ADMIN') THEN val
    ELSE 0
  END;

-- Apply to columns
ALTER TABLE employees MODIFY COLUMN email SET MASKING POLICY email_mask;
ALTER TABLE employees MODIFY COLUMN salary SET MASKING POLICY salary_mask;

-- Row-level security policy
CREATE ROW ACCESS POLICY region_filter AS (region STRING) RETURNS BOOLEAN ->
  CURRENT_ROLE() IN ('ADMIN') OR
  EXISTS (
    SELECT 1 FROM user_region_mapping
    WHERE user_name = CURRENT_USER()
      AND allowed_region = region
  );

ALTER TABLE sales ADD ROW ACCESS POLICY region_filter ON (region);
```

## Performance Optimization

### Query Writing Best Practices

```sql
-- 1. Filter early, filter on clustered columns
-- GOOD: pushes filter to scan time
SELECT * FROM orders WHERE order_date > '2026-01-01' AND status = 'active';
-- BAD: function on column prevents pruning
SELECT * FROM orders WHERE YEAR(order_date) = 2026;
-- BETTER: rewrite to range predicate
SELECT * FROM orders WHERE order_date >= '2026-01-01' AND order_date < '2027-01-01';

-- 2. Avoid SELECT * in production queries
SELECT order_id, customer_id, total FROM orders;  -- only needed columns

-- 3. Use approximate functions for large datasets
SELECT APPROX_COUNT_DISTINCT(user_id) FROM events;   -- much faster than COUNT(DISTINCT user_id)
SELECT APPROX_PERCENTILE(response_time, 0.95) FROM requests;

-- 4. Prefer UNION ALL over UNION (avoids deduplication overhead)
SELECT id FROM table_a
UNION ALL
SELECT id FROM table_b;

-- 5. Use EXISTS instead of IN for subqueries (often more efficient)
SELECT * FROM orders o
WHERE EXISTS (SELECT 1 FROM vip_customers v WHERE v.customer_id = o.customer_id);

-- 6. Avoid correlated subqueries when possible
-- BAD (correlated subquery runs per row)
SELECT *, (SELECT MAX(amount) FROM orders o2 WHERE o2.customer_id = o.customer_id) AS max_amount
FROM orders o;
-- BETTER (window function)
SELECT *, MAX(amount) OVER (PARTITION BY customer_id) AS max_amount
FROM orders;

-- 7. QUALIFY for window function filtering (Snowflake extension)
SELECT customer_id, order_date, amount
FROM orders
QUALIFY ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date DESC) = 1;
```

### JOIN Optimization

```sql
-- 1. Place the larger table on the LEFT side of the JOIN
-- Snowflake builds the hash table from the RIGHT (smaller) side
SELECT l.*, r.category
FROM large_fact_table l
JOIN small_dim_table r ON l.dim_key = r.dim_key;

-- 2. Filter before joining
SELECT o.order_id, c.name
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_date > '2026-01-01';  -- applied before JOIN if optimizer pushes down

-- 3. Use CTE to pre-filter for clarity
WITH recent_orders AS (
    SELECT * FROM orders WHERE order_date > '2026-01-01'
)
SELECT ro.order_id, c.name
FROM recent_orders ro
JOIN customers c ON ro.customer_id = c.customer_id;
```

### Materialized View vs. Dynamic Table Decision

| Criteria | Materialized View | Dynamic Table |
|----------|-------------------|---------------|
| Single-table aggregation | Yes (ideal use case) | Yes |
| Multi-table JOINs | No (not supported) | Yes |
| Incremental refresh | Automatic | Automatic |
| Declarative SQL | Yes | Yes |
| Freshness control | Automatic (near-real-time) | TARGET_LAG parameter |
| Chaining pipelines | Not natively | Yes (DT -> DT -> DT) |
| Complex transformations | Limited | Full SQL support |
| Enterprise+ required | Yes | No (available on Standard) |

**Recommendation:** Use dynamic tables for most transformation pipelines. Use materialized views only for simple single-table aggregations where near-instant freshness matters and you have Enterprise edition.

### Common Anti-Patterns to Avoid

1. **Using a single large warehouse for all workloads** -- Separate warehouses per workload for isolation and cost attribution
2. **Setting AUTO_SUSPEND = 0 for interactive warehouses** -- Wastes credits during idle periods
3. **Using ACCOUNTADMIN for daily operations** -- Security risk; use least-privilege roles
4. **Clustering on high-cardinality columns** -- UUID, timestamp with nanoseconds, etc. provide minimal pruning benefit
5. **Excessive use of Nullable columns** -- Snowflake handles NULLs well, but avoid Nullable when a default value is meaningful
6. **Loading many tiny files (<1MB)** -- Combine files to 100-250MB before loading
7. **Running SELECT * on large tables** -- Project only needed columns to reduce I/O
8. **Not setting resource monitors** -- Uncontrolled warehouse usage leads to bill shock
9. **Keeping default 90-day Time Travel on all tables** -- Reduce for non-critical tables
10. **Ignoring query profile spill metrics** -- Spilling is the top indicator that a warehouse is undersized for the workload

## Monitoring and Alerting

### Key Metrics to Monitor

```sql
-- 1. Credit consumption trend (daily, by warehouse)
SELECT DATE_TRUNC('day', start_time) AS day, warehouse_name, SUM(credits_used) AS credits
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE start_time > DATEADD(day, -30, CURRENT_TIMESTAMP())
GROUP BY day, warehouse_name
ORDER BY day DESC, credits DESC;

-- 2. Storage growth trend
SELECT DATE_TRUNC('day', USAGE_DATE) AS day,
       SUM(AVERAGE_STAGE_BYTES + AVERAGE_DATABASE_BYTES) / POWER(1024, 4) AS total_tb
FROM SNOWFLAKE.ACCOUNT_USAGE.STORAGE_USAGE
WHERE USAGE_DATE > DATEADD(day, -30, CURRENT_DATE())
GROUP BY day
ORDER BY day DESC;

-- 3. Failed login attempts (security)
SELECT DATE_TRUNC('hour', event_timestamp) AS hour,
       user_name, reported_client_type, error_message, COUNT(*) AS failures
FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
WHERE is_success = 'NO'
  AND event_timestamp > DATEADD(day, -7, CURRENT_TIMESTAMP())
GROUP BY hour, user_name, reported_client_type, error_message
ORDER BY hour DESC, failures DESC;

-- 4. Long-running queries
SELECT query_id, user_name, warehouse_name,
       execution_time / 1000 AS exec_sec,
       SUBSTR(query_text, 1, 200) AS query_preview
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE execution_time > 300000  -- >5 minutes
  AND start_time > DATEADD(day, -1, CURRENT_TIMESTAMP())
ORDER BY execution_time DESC;

-- 5. Warehouse queue times
SELECT DATE_TRUNC('hour', start_time) AS hour, warehouse_name,
       AVG(queued_overload_time) / 1000 AS avg_queue_sec,
       MAX(queued_overload_time) / 1000 AS max_queue_sec,
       COUNT(*) AS query_count
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time > DATEADD(day, -7, CURRENT_TIMESTAMP())
  AND warehouse_name IS NOT NULL
GROUP BY hour, warehouse_name
HAVING avg_queue_sec > 1
ORDER BY hour DESC, avg_queue_sec DESC;
```

### Snowflake Alerts (Native Alerting)

```sql
-- Create an alert for high credit consumption
CREATE ALERT high_credit_alert
  WAREHOUSE = monitor_wh
  SCHEDULE = '60 MINUTE'
  IF (EXISTS (
    SELECT 1 FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
    WHERE start_time > DATEADD(hour, -1, CURRENT_TIMESTAMP())
    GROUP BY warehouse_name
    HAVING SUM(credits_used) > 50  -- alert if any warehouse uses >50 credits in an hour
  ))
  THEN
    CALL SYSTEM$SEND_EMAIL(
      'my_notification_integration',
      'team@company.com',
      'High Credit Alert',
      'A warehouse consumed >50 credits in the last hour.'
    );

ALTER ALERT high_credit_alert RESUME;

-- Create an alert for failed tasks
CREATE ALERT failed_task_alert
  WAREHOUSE = monitor_wh
  SCHEDULE = '30 MINUTE'
  IF (EXISTS (
    SELECT 1 FROM SNOWFLAKE.ACCOUNT_USAGE.TASK_HISTORY
    WHERE state = 'FAILED'
      AND scheduled_time > DATEADD(minute, -30, CURRENT_TIMESTAMP())
  ))
  THEN
    CALL SYSTEM$SEND_EMAIL(
      'my_notification_integration',
      'data-eng@company.com',
      'Task Failure Alert',
      'One or more tasks have failed in the last 30 minutes.'
    );

ALTER ALERT failed_task_alert RESUME;
```

## dbt with Snowflake Best Practices

### Connection Configuration (profiles.yml)

```yaml
my_project:
  target: prod
  outputs:
    prod:
      type: snowflake
      account: myaccount
      user: svc_dbt
      authenticator: externalbrowser  # or key-pair
      private_key_path: /path/to/rsa_key.p8
      role: dbt_role
      database: analytics
      warehouse: dbt_wh
      schema: public
      threads: 8
      query_tag: 'dbt_prod'
```

### dbt Model Strategy

```sql
-- models/staging/stg_orders.sql (ephemeral or view -- no credit cost)
{{ config(materialized='view') }}
SELECT
    order_id,
    customer_id,
    order_date::DATE AS order_date,
    amount::DECIMAL(10,2) AS amount,
    status
FROM {{ source('raw', 'orders') }}
WHERE order_date IS NOT NULL

-- models/marts/fct_orders.sql (incremental -- minimize processing)
{{ config(
    materialized='incremental',
    unique_key='order_id',
    cluster_by=['order_date'],
    incremental_strategy='merge',
    transient=false
) }}
SELECT
    order_id,
    customer_id,
    order_date,
    amount,
    status,
    CURRENT_TIMESTAMP() AS _loaded_at
FROM {{ ref('stg_orders') }}
{% if is_incremental() %}
WHERE order_date > (SELECT MAX(order_date) FROM {{ this }})
{% endif %}
```
