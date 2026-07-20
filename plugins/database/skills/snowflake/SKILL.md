---
name: snowflake
description: "Snowflake expert. Deep expertise in virtual warehouses, micro-partitions, clustering, Snowpipe, streams/tasks, Time Travel, data sharing, Snowpark, and cost optimization. WHEN: \"Snowflake\", \"SnowSQL\", \"Snowpipe\", \"virtual warehouse\", \"micro-partition\", \"clustering key\", \"Time Travel\", \"data sharing\", \"Snowpark\", \"Snowflake Cortex\", \"ACCOUNT_USAGE\", \"INFORMATION_SCHEMA\", \"warehouse sizing\", \"credit consumption\"."
license: MIT
---

# Snowflake

This skill covers Snowflake's cloud data platform. It covers Snowflake internals -- the multi-cluster shared data architecture, virtual warehouses, micro-partitions, automatic clustering, query optimization, continuous data loading (Snowpipe), change data capture (streams and tasks), Time Travel, Fail-Safe, zero-copy cloning, secure data sharing, Snowpark, Snowflake Cortex AI/ML, and cost optimization strategies. Snowflake is a managed service with continuous weekly releases; there are no user-managed versions.

## How to Approach Tasks

When you receive a request:

1. **Classify** the request:
   - **Architecture/internals** -- Load `references/architecture.md`
   - **Performance diagnostics** -- Load `references/diagnostics.md`
   - **Configuration/operations/cost** -- Load `references/best-practices.md`
   - **Comparison with other databases** -- see the `overview` skill

2. **Determine context** -- Ask about Snowflake edition (Standard, Enterprise, Business Critical, VPS) if relevant. Features like multi-cluster warehouses, materialized views, column-level security, and Time Travel >1 day require Enterprise or higher.

3. **Analyze** -- Apply Snowflake-specific reasoning. Reference micro-partition pruning, warehouse sizing, credit economics, metadata caching, result set caching, and cloud services layer overhead as relevant.

4. **Recommend** -- Provide actionable guidance with specific SQL, warehouse configuration, ACCOUNT_USAGE queries, or SnowSQL commands.

5. **Verify** -- Suggest validation steps (EXPLAIN, QUERY_HISTORY, WAREHOUSE_METERING_HISTORY, GET_QUERY_OPERATOR_STATS, SYSTEM$CLUSTERING_INFORMATION).

## Core Expertise

### Multi-Cluster Shared Data Architecture

Snowflake separates compute, storage, and cloud services into three independent layers:

**Cloud Services Layer** (brain):
- Query parsing, optimization, and compilation
- Metadata management (micro-partition catalog, statistics, access control)
- Authentication, access control, and encryption key management
- Result set cache (24-hour TTL, exact query match including parameter binding)
- Infrastructure management and transaction coordination
- Billed in credits only when exceeding 10% of daily warehouse consumption

**Compute Layer** (virtual warehouses):
- Independently scalable warehouse clusters (XS through 6XL)
- Each warehouse is a cluster of EC2/Azure/GCP compute nodes
- No shared state between warehouses -- complete isolation
- Local SSD cache on warehouse nodes (raw data cache persists across queries while warehouse is running)
- Multi-cluster warehouses (Enterprise+) auto-scale from 1 to N clusters based on concurrency
- Warehouses can be started, suspended, and resized independently

**Storage Layer** (centralized):
- Data stored in cloud object storage (S3, Azure Blob, GCS) in a proprietary columnar format
- Micro-partitions: immutable, compressed columnar files (50-500MB compressed, ~16MB uncompressed target)
- All data encrypted at rest (AES-256) and in transit (TLS 1.2+)
- Shared across all warehouses -- no data copying for concurrent access
- Storage billed by average compressed bytes per month (on-demand or capacity pricing)

**Key implication:** Because storage and compute are decoupled, you can have unlimited concurrent readers on the same data with zero contention, and warehouses can be sized independently per workload.

### Virtual Warehouses

Virtual warehouses are the compute engine. Each warehouse is an independently sized cluster:

| Size | Servers | Credits/Hour | Relative Power | Typical Use |
|------|---------|-------------|----------------|-------------|
| X-Small (XS) | 1 | 1 | 1x | Dev, light queries |
| Small (S) | 2 | 2 | 2x | Light production |
| Medium (M) | 4 | 4 | 4x | General production |
| Large (L) | 8 | 8 | 8x | Heavy analytics |
| X-Large (XL) | 16 | 16 | 16x | Large datasets |
| 2XL | 32 | 32 | 32x | Very large scans |
| 3XL | 64 | 64 | 64x | Massive workloads |
| 4XL | 128 | 128 | 128x | Extreme workloads |
| 5XL | 256 | 256 | 256x | Extreme workloads |
| 6XL | 512 | 512 | 512x | Extreme workloads |

**Credit economics:** Credits are consumed per second (60-second minimum). A Medium warehouse running for 30 minutes = 2 credits. Prices vary by cloud/region (~$2-4/credit on-demand).

**Warehouse configuration:**
```sql
CREATE WAREHOUSE analytics_wh
  WAREHOUSE_SIZE = 'MEDIUM'
  AUTO_SUSPEND = 60               -- suspend after 60 seconds of inactivity
  AUTO_RESUME = TRUE              -- resume on query arrival
  MIN_CLUSTER_COUNT = 1           -- multi-cluster min (Enterprise+)
  MAX_CLUSTER_COUNT = 3           -- multi-cluster max (Enterprise+)
  SCALING_POLICY = 'STANDARD'     -- or 'ECONOMY' (waits longer before scaling out)
  INITIALLY_SUSPENDED = TRUE
  STATEMENT_TIMEOUT_IN_SECONDS = 3600
  STATEMENT_QUEUED_TIMEOUT_IN_SECONDS = 600
  WAREHOUSE_TYPE = 'STANDARD'     -- or 'SNOWPARK-OPTIMIZED' for memory-heavy workloads
  RESOURCE_MONITOR = 'daily_monitor'
  COMMENT = 'Analytics team warehouse';

-- Resize on the fly (no downtime)
ALTER WAREHOUSE analytics_wh SET WAREHOUSE_SIZE = 'LARGE';

-- Suspend and resume
ALTER WAREHOUSE analytics_wh SUSPEND;
ALTER WAREHOUSE analytics_wh RESUME;
```

**Multi-cluster warehouses (Enterprise+):**
- `STANDARD` scaling: Adds clusters as soon as queries queue; removes when load decreases
- `ECONOMY` scaling: Waits ~6 minutes of sustained queueing before adding a cluster; saves credits but tolerates brief latency spikes
- Each cluster is a full copy of the warehouse size -- a 3-cluster Medium = 12 credits/hour at peak

**Warehouse strategy by workload:**

| Workload | Recommended Setup |
|----------|-------------------|
| ETL/ELT batch loads | Dedicated XL-4XL, auto-suspend=0 (manual control), suspend after pipeline completes |
| BI dashboards | Multi-cluster M or L, auto-suspend=300, STANDARD scaling |
| Ad-hoc analyst queries | S or M, auto-suspend=60 |
| Data science / Snowpark | SNOWPARK-OPTIMIZED M-XL for memory-intensive UDFs |
| dbt models | Dedicated M-L, auto-suspend=60 |
| Continuous Snowpipe | Serverless (Snowpipe uses Snowflake-managed compute, no warehouse needed) |

### Micro-Partitions and Clustering

Snowflake automatically partitions all data into **micro-partitions** -- immutable, compressed columnar storage units:

- Each micro-partition: 50-500MB compressed (~16MB per column uncompressed before compression)
- Automatically created during data loading and DML operations
- Columnar storage within each micro-partition (each column stored contiguously)
- Rich metadata per micro-partition: min/max values, distinct count, null count for every column
- Metadata stored in the cloud services layer (not in the micro-partitions themselves)

**Partition pruning** is Snowflake's primary query optimization:
```sql
-- If table is naturally clustered on order_date, this query prunes most micro-partitions
SELECT * FROM orders WHERE order_date BETWEEN '2026-01-01' AND '2026-01-31';
-- Snowflake checks each micro-partition's min/max for order_date
-- Only partitions overlapping [Jan 1, Jan 31] are scanned
```

**Clustering keys (Enterprise+):**
```sql
-- Define a clustering key on frequently filtered columns
ALTER TABLE orders CLUSTER BY (order_date, region);

-- Check clustering quality
SELECT SYSTEM$CLUSTERING_INFORMATION('orders', '(order_date, region)');
-- Returns: average_overlaps, average_depth, total_partition_count, etc.
-- average_depth close to 1.0 = well-clustered; >5 = poorly clustered

-- Compound expressions supported
ALTER TABLE events CLUSTER BY (TO_DATE(event_timestamp), event_type);

-- Drop clustering key
ALTER TABLE events DROP CLUSTERING KEY;
```

**Clustering key design rules:**
1. Choose columns that appear most frequently in WHERE clauses and JOIN conditions
2. Prefer columns with moderate cardinality (dates, regions, categories) -- not unique IDs
3. Place the most selective filter column first in the clustering key
4. Limit to 3-4 columns maximum -- more columns dilute effectiveness
5. Clustering is automatic and continuous (Automatic Clustering service runs in background)
6. Clustering costs credits -- monitor with AUTOMATIC_CLUSTERING_HISTORY

**When NOT to cluster:**
- Tables under ~1GB (too small to benefit)
- Tables that are loaded once and rarely queried
- Tables already naturally clustered by load order (e.g., append-only time-series data)

### Query Optimization

**Three-tier caching model:**

1. **Result cache** (cloud services layer): Returns identical results for exact same query within 24 hours. Free. Invalidated when underlying data changes.
2. **Local disk cache** (warehouse SSD): Raw micro-partition data cached on warehouse local SSDs. Persists while warehouse is running. Avoids cloud storage reads.
3. **Remote disk** (cloud object storage): Original micro-partitions read from S3/Blob/GCS.

**Query profile analysis:**
```sql
-- Get query ID from history
SELECT query_id, query_text, execution_time, bytes_scanned, partitions_scanned, partitions_total
FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY_BY_USER(
    USER_NAME => CURRENT_USER(),
    RESULT_LIMIT => 20
));

-- Detailed operator-level stats
SELECT * FROM TABLE(GET_QUERY_OPERATOR_STATS('query-id-here'));
```

**Key optimization patterns:**
```sql
-- 1. Predicate pushdown: filter early
SELECT * FROM large_table WHERE status = 'active' AND created_date > '2026-01-01';
-- NOT: SELECT * FROM large_table WHERE UPPER(status) = 'ACTIVE';  -- function on column prevents pruning

-- 2. Projection pushdown: select only needed columns
SELECT order_id, total FROM orders;  -- NOT: SELECT * FROM orders;

-- 3. JOIN optimization: filter before joining
SELECT o.order_id, c.name
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_date > '2026-01-01';  -- filter on the larger table

-- 4. Use LIMIT for exploratory queries
SELECT * FROM large_table LIMIT 100;

-- 5. Avoid ORDER BY on large result sets without LIMIT
SELECT * FROM events ORDER BY event_time DESC LIMIT 1000;
```

**Spilling to disk/remote storage:**
Spilling indicates insufficient warehouse memory. Check the query profile for `Bytes spilled to local storage` and `Bytes spilled to remote storage`. Resolution: use a larger warehouse or optimize the query to reduce intermediate data.

### Snowpipe (Continuous Data Loading)

Snowpipe enables continuous, serverless micro-batch loading:

```sql
-- Create a stage (external location for files)
CREATE OR REPLACE STAGE my_s3_stage
  URL = 's3://my-bucket/data/'
  STORAGE_INTEGRATION = my_s3_integration
  FILE_FORMAT = (TYPE = 'PARQUET');

-- Create target table
CREATE TABLE raw_events (
    event_data VARIANT,
    loaded_at TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Create pipe
CREATE OR REPLACE PIPE my_pipe
  AUTO_INGEST = TRUE
  AS
  COPY INTO raw_events(event_data, loaded_at)
  FROM (SELECT $1, CURRENT_TIMESTAMP() FROM @my_s3_stage)
  FILE_FORMAT = (TYPE = 'PARQUET');

-- Check pipe status
SELECT SYSTEM$PIPE_STATUS('my_pipe');

-- Check copy history
SELECT * FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
    TABLE_NAME => 'raw_events',
    START_TIME => DATEADD(hours, -24, CURRENT_TIMESTAMP())
));
```

**Snowpipe characteristics:**
- Serverless -- uses Snowflake-managed compute (billed per file loaded, ~0.06 credits per 1000 files)
- Triggered by cloud event notifications (S3 SQS, Azure Event Grid, GCS Pub/Sub) or REST API
- Typically loads files within 1-2 minutes of arrival
- Best for continuous streams of small-to-medium files (100MB-250MB compressed ideal)
- Exactly-once loading semantics (deduplication by file name within 14 days)

**Snowpipe Streaming** (for sub-second latency):
```sql
-- Snowpipe Streaming uses the Snowflake Ingest SDK (Java)
-- Rows are streamed directly without staging files
-- Latency: seconds rather than minutes
-- Use case: real-time IoT, clickstream, CDC from Kafka
```

### Streams and Tasks (Change Data Capture)

**Streams** capture row-level changes (inserts, updates, deletes) on a table:

```sql
-- Create a stream on a source table
CREATE STREAM orders_stream ON TABLE orders;

-- Check if stream has data
SELECT SYSTEM$STREAM_HAS_DATA('orders_stream');

-- Query the stream (shows change records)
SELECT * FROM orders_stream;
-- Columns: all source columns + METADATA$ACTION, METADATA$ISUPDATE, METADATA$ROW_ID

-- Consume the stream in a DML (advances the stream offset)
INSERT INTO orders_history
SELECT *, CURRENT_TIMESTAMP() AS captured_at
FROM orders_stream
WHERE METADATA$ACTION = 'INSERT';

-- Append-only stream (captures inserts only, more efficient for append-heavy tables)
CREATE STREAM events_stream ON TABLE events APPEND_ONLY = TRUE;
```

**Tasks** automate SQL execution on a schedule:

```sql
-- Create a task that processes stream data every 5 minutes
CREATE TASK process_orders_task
  WAREHOUSE = etl_wh
  SCHEDULE = '5 MINUTE'
  WHEN SYSTEM$STREAM_HAS_DATA('orders_stream')
AS
  MERGE INTO orders_dim d
  USING orders_stream s ON d.order_id = s.order_id
  WHEN MATCHED AND s.METADATA$ACTION = 'DELETE' THEN DELETE
  WHEN MATCHED AND s.METADATA$ACTION = 'INSERT' AND s.METADATA$ISUPDATE = TRUE
    THEN UPDATE SET d.status = s.status, d.updated_at = s.updated_at
  WHEN NOT MATCHED AND s.METADATA$ACTION = 'INSERT'
    THEN INSERT (order_id, status, created_at, updated_at)
         VALUES (s.order_id, s.status, s.created_at, s.updated_at);

-- Task tree (DAG) -- child tasks run after parent completes
CREATE TASK child_task
  WAREHOUSE = etl_wh
  AFTER process_orders_task
AS
  CALL refresh_aggregates();

-- Enable tasks (tasks are created in suspended state)
ALTER TASK child_task RESUME;        -- enable children first
ALTER TASK process_orders_task RESUME; -- then enable root

-- Serverless tasks (no warehouse needed, Enterprise+)
CREATE TASK serverless_task
  USER_TASK_MANAGED_INITIAL_WAREHOUSE_SIZE = 'XSMALL'
  SCHEDULE = '60 MINUTE'
AS
  DELETE FROM staging WHERE loaded_at < DATEADD(day, -7, CURRENT_TIMESTAMP());
```

### Time Travel and Fail-Safe

**Time Travel** allows querying and restoring historical data:

```sql
-- Query data as of a specific timestamp
SELECT * FROM orders AT(TIMESTAMP => '2026-04-06 10:00:00'::TIMESTAMP_LTZ);

-- Query data as of a specific offset
SELECT * FROM orders AT(OFFSET => -3600);  -- 1 hour ago

-- Query data before a specific statement
SELECT * FROM orders BEFORE(STATEMENT => '01a6b3c7-0000-1234-0000-000500000000');

-- Restore a dropped table
DROP TABLE orders;
UNDROP TABLE orders;

-- Restore a dropped schema or database
DROP SCHEMA analytics;
UNDROP SCHEMA analytics;

-- Clone a table at a historical point
CREATE TABLE orders_restored CLONE orders AT(TIMESTAMP => '2026-04-06 10:00:00'::TIMESTAMP_LTZ);
```

**Time Travel retention:**

| Edition | Default | Maximum |
|---------|---------|---------|
| Standard | 1 day | 1 day |
| Enterprise+ | 1 day | 90 days |

```sql
-- Set retention per table
ALTER TABLE orders SET DATA_RETENTION_TIME_IN_DAYS = 30;

-- Transient tables: 0 or 1 day retention, no Fail-Safe
CREATE TRANSIENT TABLE staging_data (...) DATA_RETENTION_TIME_IN_DAYS = 0;

-- Temporary tables: session-scoped, 0 or 1 day retention, no Fail-Safe
CREATE TEMPORARY TABLE session_temp (...);
```

**Fail-Safe:** Additional 7-day recovery period after Time Travel expires. Not user-accessible -- requires Snowflake Support. Only for permanent tables (not transient or temporary).

**Storage cost impact:** Time Travel and Fail-Safe store changed micro-partitions. High-churn tables (frequent updates/deletes) can have significant Time Travel storage. Monitor with:
```sql
SELECT TABLE_NAME, ACTIVE_BYTES, TIME_TRAVEL_BYTES, FAILSAFE_BYTES,
       ACTIVE_BYTES + TIME_TRAVEL_BYTES + FAILSAFE_BYTES AS TOTAL_BYTES
FROM SNOWFLAKE.ACCOUNT_USAGE.TABLE_STORAGE_METRICS
WHERE TABLE_CATALOG = 'MY_DB'
ORDER BY TOTAL_BYTES DESC;
```

### Zero-Copy Cloning

Cloning creates an instant, metadata-only copy that shares underlying micro-partitions:

```sql
-- Clone a table (instant, zero storage cost initially)
CREATE TABLE orders_dev CLONE orders;

-- Clone an entire database
CREATE DATABASE analytics_dev CLONE analytics;

-- Clone a schema
CREATE SCHEMA staging_clone CLONE staging;

-- Clone at a historical point (combines cloning + Time Travel)
CREATE TABLE orders_snapshot CLONE orders AT(TIMESTAMP => '2026-04-01 00:00:00'::TIMESTAMP_LTZ);
```

**Clone behavior:** The clone initially shares all micro-partitions with the source. As either the source or clone is modified, new micro-partitions are created independently. Storage cost grows only as data diverges.

**Common use cases:**
- Development/test environments from production (instant, no storage until data changes)
- Point-in-time snapshots for compliance or auditing
- Safe experimentation before production changes
- Rapid disaster recovery

### Data Sharing and Marketplace

See `references/advanced-features.md#data-sharing-and-marketplace` — Secure Data Sharing setup (provider/consumer SQL), secure views for per-consumer row filtering, and Snowflake Marketplace.

### Snowpark (Python, Java, Scala)

See `references/advanced-features.md#snowpark-python-java-scala` — DataFrame operations, UDF and stored procedure registration in Python, and Snowpark-optimized warehouses.

### Snowflake Cortex (AI/ML)

See `references/advanced-features.md#snowflake-cortex-aiml` — built-in LLM functions (COMPLETE, SENTIMENT, SUMMARIZE, TRANSLATE, EMBED_TEXT_768), Cortex Search, Cortex Fine-tuning, and Cortex Analyst.

### Security Model

**Role-Based Access Control (RBAC):**
```sql
-- Hierarchy: ACCOUNTADMIN > SECURITYADMIN > SYSADMIN > custom roles > PUBLIC
CREATE ROLE analyst_role;
GRANT USAGE ON DATABASE analytics TO ROLE analyst_role;
GRANT USAGE ON SCHEMA analytics.public TO ROLE analyst_role;
GRANT SELECT ON ALL TABLES IN SCHEMA analytics.public TO ROLE analyst_role;
GRANT USAGE ON WAREHOUSE analyst_wh TO ROLE analyst_role;
GRANT ROLE analyst_role TO USER jane;
```

**Column-level security (Enterprise+):**
```sql
-- Masking policy
CREATE MASKING POLICY pii_mask AS (val STRING)
  RETURNS STRING ->
  CASE
    WHEN CURRENT_ROLE() IN ('PII_ADMIN') THEN val
    ELSE '***MASKED***'
  END;

ALTER TABLE customers MODIFY COLUMN email SET MASKING POLICY pii_mask;

-- Row access policy (Enterprise+)
CREATE ROW ACCESS POLICY region_policy AS (region_val VARCHAR)
  RETURNS BOOLEAN ->
  CURRENT_ROLE() = 'ADMIN' OR region_val = CURRENT_SESSION()::VARCHAR;

ALTER TABLE orders ADD ROW ACCESS POLICY region_policy ON (region);
```

**Network policies and private connectivity:**
```sql
CREATE NETWORK POLICY office_only
  ALLOWED_IP_LIST = ('203.0.113.0/24', '198.51.100.0/24')
  BLOCKED_IP_LIST = ();

ALTER ACCOUNT SET NETWORK_POLICY = office_only;
```

### Semi-Structured Data

Snowflake natively handles JSON, Avro, Parquet, and ORC via the VARIANT type:

```sql
-- Load JSON into VARIANT
CREATE TABLE raw_events (
    src VARIANT,
    loaded_at TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Query nested JSON
SELECT
    src:user_id::INTEGER AS user_id,
    src:event_type::STRING AS event_type,
    src:properties:page_url::STRING AS page_url,
    src:timestamp::TIMESTAMP_NTZ AS event_time
FROM raw_events;

-- FLATTEN for arrays
SELECT
    r.src:user_id::INTEGER AS user_id,
    f.value:item_id::STRING AS item_id,
    f.value:quantity::INTEGER AS quantity
FROM raw_events r,
LATERAL FLATTEN(input => r.src:items) f;

-- OBJECT_CONSTRUCT and ARRAY_AGG for building JSON
SELECT OBJECT_CONSTRUCT(
    'user_id', user_id,
    'total_orders', count(*),
    'regions', ARRAY_AGG(DISTINCT region)
) AS user_summary
FROM orders GROUP BY user_id;
```

### Dynamic Tables

See `references/advanced-features.md#dynamic-tables` — declarative incremental pipeline definition with TARGET_LAG, chaining dynamic tables, and when to prefer them over streams/tasks.

### Materialized Views (Enterprise+)

See `references/advanced-features.md#materialized-views-enterprise` — creation syntax, auto-refresh behavior, and the single-table-aggregation limitation.

### External Tables and Iceberg Tables

See `references/advanced-features.md#external-tables-and-iceberg-tables` — querying cloud storage without loading, Snowflake-managed vs. externally managed Iceberg tables, and lakehouse interoperability use cases.

### Cost Optimization

See `references/advanced-features.md#cost-optimization` — credit consumption hierarchy, resource monitors for budget enforcement, and warehouse/storage optimization strategies.

## Troubleshooting Playbooks

See `references/troubleshooting.md` — diagnostic sequences and fixes for slow queries, warehouse queueing, credit spikes, and data loading failures.

## Edition Feature Matrix

| Feature | Standard | Enterprise | Business Critical |
|---------|----------|------------|-------------------|
| Time Travel | 1 day | Up to 90 days | Up to 90 days |
| Multi-cluster warehouses | No | Yes | Yes |
| Materialized views | No | Yes | Yes |
| Column/row masking | No | Yes | Yes |
| Dynamic data masking | No | Yes | Yes |
| Search optimization | No | Yes | Yes |
| Clustering keys | No | Yes | Yes |
| Database failover/failback | No | Yes | Yes |
| HIPAA/PCI/SOC2/FedRAMP | No | No | Yes |
| Customer-managed keys (CMK) | No | No | Yes |
| Private connectivity (AWS PrivateLink, Azure Private Link) | No | No | Yes |
