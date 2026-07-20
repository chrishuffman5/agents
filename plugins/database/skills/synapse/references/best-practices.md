# Azure Synapse Analytics Best Practices Reference

## Dedicated SQL Pool Best Practices

### Table Design

#### Distribution Strategy

The distribution strategy is the single most impactful design decision for dedicated SQL pool performance.

**Hash distribution (large fact tables):**
- Always hash-distribute your largest fact tables on the column most frequently used in JOINs with other large tables
- The hash key must have high cardinality (many distinct values) to spread data evenly across 60 distributions
- Verify distribution quality immediately after loading: check for skew using `DBCC PDW_SHOWSPACEUSED`
- If two large fact tables are frequently joined, distribute both on the same join key to enable co-located joins (no DMS)
- Never hash-distribute on a column with many NULLs -- all NULLs hash to distribution 0
- Never hash-distribute on a date column unless it has very high cardinality and is a primary join key

**Replicated tables (small dimensions):**
- Replicate dimension tables smaller than ~2 GB (approximately 5 million rows or fewer)
- Replicated tables eliminate BroadcastMove operations for dimension lookups
- First query after a data change triggers a rebuild of the replicated cache on all compute nodes -- plan for this
- Monitor replicated table cache status with `sys.dm_pdw_nodes_db_column_store_row_group_physical_stats` and `sys.pdw_replicated_table_cache_state`
- Do not replicate tables that change frequently (high rebuild cost)

**Round-robin (staging, unknown patterns):**
- Use round-robin for staging tables and tables whose join patterns are not yet known
- Round-robin guarantees even distribution but causes ShuffleMove on every join
- Never leave a large fact table as round-robin in production -- always convert to hash once the join pattern is known

#### Partitioning

- Partition tables on date columns for time-range queries and efficient data lifecycle management
- Ensure each partition per distribution has at least 1 million rows: minimum ~60 million total rows per partition value
- Over-partitioning degrades columnstore compression and increases metadata overhead
- Monthly partitioning is appropriate for most tables; weekly or daily only for very large tables (billions of rows per month)
- Use partition switching for zero-downtime data loading and archiving

```sql
-- Monthly partition example
CREATE TABLE dbo.fact_sales (
    sale_id         BIGINT          NOT NULL,
    sale_date       DATE            NOT NULL,
    customer_id     BIGINT          NOT NULL,
    amount          DECIMAL(18,2)   NOT NULL
)
WITH (
    DISTRIBUTION = HASH(customer_id),
    CLUSTERED COLUMNSTORE INDEX,
    PARTITION (sale_date RANGE RIGHT FOR VALUES (
        '2024-01-01', '2024-02-01', '2024-03-01', '2024-04-01',
        '2024-05-01', '2024-06-01', '2024-07-01', '2024-08-01',
        '2024-09-01', '2024-10-01', '2024-11-01', '2024-12-01',
        '2025-01-01', '2025-02-01', '2025-03-01'
    ))
);
```

#### Columnstore Index Management

- Clustered columnstore index (CCI) is the default and recommended index type for all large tables
- Keep row groups close to the maximum of 1,048,576 rows for optimal compression and segment elimination
- Rebuild indexes after large delete operations or many small inserts that create fragmented row groups
- Use ordered CCI (`ORDER BY`) on columns frequently used in range filters (dates, IDs)
- Monitor row group quality: `sys.dm_pdw_nodes_column_store_row_groups`

```sql
-- Rebuild columnstore with ordered CCI
ALTER INDEX cci_fact_sales ON dbo.fact_sales REBUILD;

-- Create ordered CCI
CREATE CLUSTERED COLUMNSTORE INDEX cci_fact_sales
ON dbo.fact_sales
ORDER (sale_date);
```

#### Statistics Management

- Enable auto-create statistics: `ALTER DATABASE mypool SET AUTO_CREATE_STATISTICS ON`
- Create multi-column statistics on frequently joined and filtered column combinations
- Update statistics after every significant data load (> 10% row change)
- Use FULLSCAN for critical tables; sample-based for very large tables
- Statistics are NOT auto-updated -- this is a critical difference from SQL Server
- Include statistics update in every ETL post-load step

```sql
-- Post-load statistics update script
DECLARE @sql NVARCHAR(MAX) = '';
SELECT @sql = @sql + 'UPDATE STATISTICS ' + QUOTENAME(s.name) + '.' + QUOTENAME(t.name) + ';' + CHAR(10)
FROM sys.tables t
JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE t.type = 'U';
EXEC sp_executesql @sql;
```

### Data Loading Best Practices

#### COPY INTO (Preferred Method)

COPY INTO is the recommended bulk loading method for dedicated SQL pools:

```sql
COPY INTO dbo.fact_sales
FROM 'https://mydatalake.dfs.core.windows.net/raw/sales/2025/01/*.parquet'
WITH (
    FILE_TYPE = 'PARQUET',
    CREDENTIAL = (IDENTITY = 'Managed Identity'),
    MAXERRORS = 0,
    AUTO_CREATE_TABLE = 'OFF'
);
```

**Loading best practices:**
1. Use Parquet files for loading (best compression, schema preservation)
2. Size files between 256 MB and 1 GB for optimal parallelism
3. Use file counts that are a multiple of 60 (one file per distribution) for even distribution during loading
4. Use managed identity authentication (avoid SAS tokens when possible)
5. Disable result set caching before large loads: `SET RESULT_SET_CACHING OFF`
6. Load into staging tables (round-robin, heap) then INSERT...SELECT into production tables for complex transformations
7. Use partition switching for zero-downtime loading of partitioned tables

#### ELT Pattern (Recommended over ETL)

Synapse dedicated pools are optimized for ELT -- load raw data first, then transform in-pool:

1. **Extract** -- Copy raw data from source systems to ADLS Gen2 (Parquet format)
2. **Load** -- Use COPY INTO to bulk-load into staging tables (round-robin, heap/CCI)
3. **Transform** -- Run T-SQL INSERT...SELECT, CTAS, or stored procedures to transform and load production tables
4. Update statistics on all modified tables
5. Rebuild any degraded columnstore indexes

#### Partition Switching Load Pattern

```sql
-- Step 1: Create staging table matching target schema and distribution
CREATE TABLE dbo.stg_fact_sales
WITH (
    DISTRIBUTION = HASH(customer_id),
    CLUSTERED COLUMNSTORE INDEX,
    PARTITION (sale_date RANGE RIGHT FOR VALUES ('2025-03-01', '2025-04-01'))
)
AS SELECT * FROM dbo.fact_sales WHERE 1 = 0;

-- Step 2: Load data into staging table
COPY INTO dbo.stg_fact_sales
FROM 'https://mydatalake.dfs.core.windows.net/raw/sales/2025/03/*.parquet'
WITH (FILE_TYPE = 'PARQUET', CREDENTIAL = (IDENTITY = 'Managed Identity'));

-- Step 3: Switch partition
ALTER TABLE dbo.stg_fact_sales SWITCH PARTITION 2 TO dbo.fact_sales PARTITION 15;

-- Step 4: Update statistics
UPDATE STATISTICS dbo.fact_sales;
```

### Workload Management

#### Workload Groups

Replace legacy resource classes with workload groups for fine-grained resource control:

```sql
-- High-priority analytics group
CREATE WORKLOAD GROUP wg_analytics
WITH (
    MIN_PERCENTAGE_RESOURCE = 30,
    MAX_PERCENTAGE_RESOURCE = 60,
    REQUEST_MIN_RESOURCE_GRANT_PERCENT = 5,
    REQUEST_MAX_RESOURCE_GRANT_PERCENT = 15,
    CAP_PERCENTAGE_RESOURCE = 60,
    QUERY_EXECUTION_TIMEOUT_SEC = 3600
);

-- Background ETL group
CREATE WORKLOAD GROUP wg_etl
WITH (
    MIN_PERCENTAGE_RESOURCE = 20,
    MAX_PERCENTAGE_RESOURCE = 40,
    REQUEST_MIN_RESOURCE_GRANT_PERCENT = 10,
    REQUEST_MAX_RESOURCE_GRANT_PERCENT = 20,
    CAP_PERCENTAGE_RESOURCE = 40,
    QUERY_EXECUTION_TIMEOUT_SEC = 7200
);

-- Classifiers
CREATE WORKLOAD CLASSIFIER cls_analytics
WITH (
    WORKLOAD_GROUP = 'wg_analytics',
    MEMBERNAME = 'analytics_role',
    IMPORTANCE = HIGH
);

CREATE WORKLOAD CLASSIFIER cls_etl
WITH (
    WORKLOAD_GROUP = 'wg_etl',
    MEMBERNAME = 'etl_user',
    IMPORTANCE = NORMAL,
    START_TIME = '00:00',
    END_TIME = '06:00'
);
```

**Workload management rules:**
- Total `MIN_PERCENTAGE_RESOURCE` across all groups must not exceed 100%
- Leave at least 10-20% unallocated for system operations
- Use `IMPORTANCE` (low, below_normal, normal, above_normal, high) for queue priority
- Monitor with `sys.dm_pdw_exec_requests` (workload group, classifier, queued time)

### Performance Optimization

#### Result Set Caching

```sql
-- Enable at database level
ALTER DATABASE mypool SET RESULT_SET_CACHING ON;

-- Disable for a specific session (before loading data)
SET RESULT_SET_CACHING OFF;

-- Check cache utilization
SELECT
    result_cache_hit,
    COUNT(*) AS query_count,
    AVG(total_elapsed_time) AS avg_elapsed_ms
FROM sys.dm_pdw_exec_requests
WHERE status = 'Completed'
    AND start_time > DATEADD(hour, -24, GETDATE())
GROUP BY result_cache_hit;
```

#### Materialized Views

```sql
-- Create materialized view for common aggregation
CREATE MATERIALIZED VIEW dbo.mv_sales_daily
WITH (DISTRIBUTION = HASH(product_id))
AS
SELECT
    product_id,
    CAST(sale_date AS DATE) AS sale_date,
    COUNT_BIG(*) AS row_count,
    SUM(quantity) AS total_qty,
    SUM(amount) AS total_amount
FROM dbo.fact_sales
GROUP BY product_id, CAST(sale_date AS DATE);

-- Check if optimizer is using materialized views
EXPLAIN
SELECT product_id, SUM(amount)
FROM dbo.fact_sales
GROUP BY product_id;
-- Look for "MaterializedViewRewrite" in the plan
```

**Materialized view guidelines:**
- Use `COUNT_BIG(*)` instead of `COUNT(*)` (required by Synapse)
- Distribution of the MV should match common query patterns
- Only aggregate functions supported: SUM, COUNT_BIG, MIN, MAX, AVG
- Cannot include: DISTINCT, HAVING, TOP, subqueries, outer joins, CUBE/ROLLUP
- Monitor overhead: `DBCC PDW_SHOWMATERIALIZEDVIEWOVERHEAD('dbo.mv_sales_daily')`

### Scaling Best Practices

- Start at DW100c for development and testing
- Production workloads typically start at DW1000c
- Scale up before peak query periods; scale down during quiet periods
- Scaling takes 3-6 minutes; plan for brief connection disruption
- Pause the pool during non-business hours for cost savings
- Use Azure Automation or Logic Apps to schedule pause/resume and scaling

```bash
# Scale dedicated SQL pool
az synapse sql pool update \
  --name mypool \
  --workspace-name myworkspace \
  --resource-group myrg \
  --performance-level DW1000c

# Pause dedicated SQL pool
az synapse sql pool pause \
  --name mypool \
  --workspace-name myworkspace \
  --resource-group myrg

# Resume dedicated SQL pool
az synapse sql pool resume \
  --name mypool \
  --workspace-name myworkspace \
  --resource-group myrg
```

## Serverless SQL Pool Best Practices

### File Organization

#### File Format

- **Always use Parquet or Delta Lake** -- columnar formats enable column pruning and predicate pushdown, reducing data scanned (and cost) by 10-100x compared to CSV
- Convert CSV/JSON to Parquet as early as possible in your pipeline
- Use CETAS to transform raw files into optimized Parquet

#### File Sizing

- Target 128 MB - 1 GB per file (compressed Parquet)
- Too many small files (< 1 MB) causes high metadata overhead and slow listing
- Too few large files reduces parallelism
- Use Spark or CETAS to compact small files

#### Partitioning

Partition data lake files by commonly filtered columns:

```
/data/
  /year=2025/
    /month=01/
      /part-00000.parquet
      /part-00001.parquet
    /month=02/
      /...
```

Query with partition elimination:

```sql
SELECT *
FROM OPENROWSET(
    BULK 'https://datalake.dfs.core.windows.net/data/year=*/month=*/*.parquet',
    FORMAT = 'PARQUET'
) WITH (
    year INT,
    month INT,
    -- other columns
    [year] INT '$.year',
    [month] INT '$.month'
) AS r
WHERE r.filepath(1) = '2025' AND r.filepath(2) = '01';
```

### Cost Control

```sql
-- Set daily cost limit (in bytes)
EXEC sp_set_data_processed_limit
    @type = N'daily',
    @limit_tb = 1;  -- 1 TB per day = $5/day max

-- Check current usage
SELECT * FROM sys.dm_external_data_processed;
```

**Cost optimization checklist:**
1. Always use Parquet/Delta Lake (never CSV for analytics)
2. SELECT only needed columns (never SELECT *)
3. Partition data by date or other common filter columns
4. Use filepath() for partition elimination
5. Create views to encapsulate efficient query patterns for business users
6. Set data processed limits to prevent cost overruns
7. Use CETAS to pre-materialize frequently queried aggregations

### Schema Design (Logical Data Warehouse)

Build a metadata layer over the data lake using databases, schemas, views, and external tables:

```sql
-- Create database for logical data warehouse
CREATE DATABASE analytics;
GO
USE analytics;
GO

-- External data source
CREATE EXTERNAL DATA SOURCE adls
WITH (LOCATION = 'https://mydatalake.dfs.core.windows.net/curated');

-- External file format
CREATE EXTERNAL FILE FORMAT parquet_format
WITH (FORMAT_TYPE = PARQUET);

-- View for business users (recommended over external tables for flexibility)
CREATE VIEW dbo.v_sales AS
SELECT
    sale_id, sale_date, customer_id, product_id, quantity, amount
FROM OPENROWSET(
    BULK 'sales/year=*/month=*/*.parquet',
    DATA_SOURCE = 'adls',
    FORMAT = 'PARQUET'
) WITH (
    sale_id     BIGINT,
    sale_date   DATE,
    customer_id BIGINT,
    product_id  BIGINT,
    quantity    INT,
    amount      DECIMAL(18,2)
) AS r;
```

### CETAS Best Practices

```sql
-- Transform and materialize aggregated data
CREATE EXTERNAL TABLE dbo.agg_monthly_sales
WITH (
    LOCATION = 'curated/agg_monthly_sales/',
    DATA_SOURCE = adls,
    FILE_FORMAT = parquet_format
)
AS
SELECT
    YEAR(sale_date) AS sale_year,
    MONTH(sale_date) AS sale_month,
    product_id,
    SUM(amount) AS total_amount,
    COUNT(*) AS row_count
FROM OPENROWSET(
    BULK 'raw/sales/*.parquet',
    DATA_SOURCE = 'adls',
    FORMAT = 'PARQUET'
) AS s
GROUP BY YEAR(sale_date), MONTH(sale_date), product_id;
```

**CETAS guidelines:**
- Output is always new files in the data lake (cannot append)
- Drop the external table first if re-running (or use a new location)
- Use CETAS to build curated/gold-layer datasets from raw data
- Files created by CETAS are Parquet by default and well-sized for subsequent queries

## Spark Pool Best Practices

### Configuration

- Use auto-pause with minimum idle timeout (5 minutes) to control costs
- Enable auto-scale with a reasonable range (e.g., 3-10 nodes) to handle variable workloads
- Choose Medium nodes (8 vCores, 64 GB) for general workloads; Large for memory-intensive ML/graph
- Pin the Spark runtime version for production pipelines to avoid unexpected behavior changes
- Use requirements.txt or environment.yml for Python package management

### Delta Lake

Delta Lake is the recommended table format for all Spark workloads in Synapse:

```python
# Write Delta table
df.write.format("delta").mode("overwrite").partitionBy("year", "month") \
    .save("abfss://container@account.dfs.core.windows.net/delta/sales")

# Read Delta table
df = spark.read.format("delta").load("abfss://container@account.dfs.core.windows.net/delta/sales")

# Merge (upsert) pattern
from delta.tables import DeltaTable

target = DeltaTable.forPath(spark, "abfss://container@account.dfs.core.windows.net/delta/customers")
target.alias("t").merge(
    source_df.alias("s"),
    "t.customer_id = s.customer_id"
).whenMatchedUpdateAll().whenNotMatchedInsertAll().execute()

# Optimize (compact small files)
spark.sql("OPTIMIZE delta.`abfss://container@account.dfs.core.windows.net/delta/sales`")

# Z-ORDER for multi-dimensional query performance
spark.sql("""
    OPTIMIZE delta.`abfss://container@account.dfs.core.windows.net/delta/sales`
    ZORDER BY (customer_id, product_id)
""")

# Vacuum old files (retain 7 days by default)
spark.sql("VACUUM delta.`abfss://container@account.dfs.core.windows.net/delta/sales` RETAIN 168 HOURS")
```

### Performance Tips

- Broadcast small DataFrames in joins: `df_large.join(broadcast(df_small), "key")`
- Cache intermediate results for iterative processing: `df.cache()` or `.persist(StorageLevel.MEMORY_AND_DISK)`
- Repartition DataFrames before writing to control output file count: `df.repartition(60)`
- Use Delta Lake Z-ORDER for columns frequently used in filters
- Avoid UDFs when possible -- use built-in Spark functions for vectorized execution
- Monitor Spark UI in Synapse Studio for stage-level performance analysis

## Synapse Pipelines Best Practices

### Loading Dedicated SQL Pool

- Use **Copy activity** with PolyBase or COPY command as the copy method
- Staging: Always use a staging ADLS Gen2 location for best performance
- Pre-copy script: Use to truncate staging tables before loading
- Parallelism: Set degree of copy parallelism based on source throughput

### Orchestration Patterns

- Use **Lookup + ForEach** for dynamic pipeline execution (iterate over a list of tables to load)
- Use **Get Metadata** activity to check file existence before processing
- Use **tumbling window triggers** for incremental processing with retry
- Use **event-based triggers** to process files as they arrive in the data lake
- Implement **checkpoint/watermark** patterns for incremental loads

### Error Handling

- Set activity retry policies (count + interval) on all copy and data flow activities
- Use **pipeline-level failure handling** with dependency conditions (on failure/skip/completion)
- Log errors to a metadata database for monitoring and alerting
- Set pipeline timeout at both the activity and pipeline level

## Security Best Practices

### Authentication

- Use **Managed Identity** for all service-to-service authentication (data lake, Key Vault, linked services)
- Disable SQL authentication in production if possible -- use Microsoft Entra ID exclusively
- Use **database-scoped credentials** referencing managed identity for OPENROWSET and external tables
- Store connection strings and secrets in **Azure Key Vault** with linked service

### Authorization

- Implement **row-level security (RLS)** for multi-tenant or restricted data access
- Implement **column-level security (CLS)** to restrict sensitive columns (SSN, salary, PII)
- Use **dynamic data masking (DDM)** for non-privileged users viewing sensitive data
- Grant minimum necessary permissions -- use database roles, not direct user grants
- Use **workspace-level RBAC** to separate Synapse Administrator, SQL Administrator, and Spark Administrator roles

```sql
-- Row-Level Security
CREATE SCHEMA rls;
GO

CREATE FUNCTION rls.fn_region_filter(@region NVARCHAR(50))
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN SELECT 1 AS result
WHERE @region = USER_NAME()
    OR USER_NAME() = 'admin_user';
GO

CREATE SECURITY POLICY rls.RegionFilter
ADD FILTER PREDICATE rls.fn_region_filter(region)
ON dbo.fact_sales
WITH (STATE = ON);

-- Column-Level Security
GRANT SELECT ON dbo.customers (customer_id, name, email) TO analyst_role;
DENY SELECT ON dbo.customers (ssn, credit_card) TO analyst_role;

-- Dynamic Data Masking
ALTER TABLE dbo.customers
ALTER COLUMN email ADD MASKED WITH (FUNCTION = 'email()');

ALTER TABLE dbo.customers
ALTER COLUMN ssn ADD MASKED WITH (FUNCTION = 'partial(0,"XXX-XX-",4)');
```

### Network Security

- Deploy with **Managed VNet** enabled for production workspaces
- Use **private endpoints** for all three workspace sub-resources (SQL, SqlOnDemand, Dev)
- Enable **data exfiltration protection** to prevent unauthorized data movement
- Use **managed private endpoints** for all outbound connections from the workspace
- Disable public network access when private endpoints are configured

## Monitoring and Alerting

### Key Metrics to Monitor

**Dedicated SQL pool:**
- DWU utilization percentage (target < 80% sustained)
- Active queries and queued queries
- Tempdb utilization percentage (alert at > 70%)
- Adaptive cache hit percentage (target > 80%)
- Data IO percentage

**Serverless SQL pool:**
- Data processed (daily/weekly for cost tracking)
- Query duration and failures
- Concurrent query count

**Spark pool:**
- Active applications and pending applications
- Executor count and utilization
- Shuffle read/write bytes

**Pipelines:**
- Pipeline run success/failure rates
- Activity duration trends
- Integration runtime utilization

### Azure Monitor Alerts

Set up alerts for critical conditions:
- Dedicated SQL pool DWU utilization > 90% for 15 minutes
- Tempdb utilization > 80%
- Serverless SQL pool data processed approaching daily limit
- Pipeline failures
- Spark application failures

## Troubleshooting Playbooks

### Data Skew

**Symptoms:** One or more distributions take much longer than others; DMS operations are slow; tempdb fills up.

**Diagnosis:**
1. Run `DBCC PDW_SHOWSPACEUSED('dbo.fact_sales')` to check rows per distribution
2. Calculate skew factor: `MAX(rows) / AVG(rows)` -- should be < 1.05 (5% skew)
3. Check distribution column cardinality and NULL count

**Resolution:**
1. Choose a different distribution key with higher cardinality and fewer NULLs
2. Use CTAS to rebuild the table with the new distribution: `CREATE TABLE dbo.fact_sales_new WITH (DISTRIBUTION = HASH(new_key)) AS SELECT * FROM dbo.fact_sales`
3. Rename tables to swap

### Tempdb Full

**Symptoms:** Queries fail with "tempdb out of space" errors; overall performance degrades.

**Diagnosis:**
1. Check tempdb usage: `SELECT * FROM sys.dm_pdw_nodes_os_performance_counters WHERE counter_name LIKE '%tempdb%'`
2. Find queries using most tempdb: Sort `sys.dm_pdw_exec_requests` by `total_elapsed_time` with active status
3. Check for hash joins and sorts on very large datasets in the query plan

**Resolution:**
1. Kill long-running queries consuming excessive tempdb
2. Scale up DWU to get more tempdb space
3. Optimize queries: reduce data movement, add statistics, improve distribution
4. Reduce concurrency with workload groups

### Query Failures (Dedicated Pool)

**Symptoms:** Queries fail with error codes, timeout, or crash.

**Diagnosis:**
1. Check `sys.dm_pdw_exec_requests` for error_id and status
2. Check `sys.dm_pdw_errors` for detailed error messages
3. Check `sys.dm_pdw_request_steps` to identify which step failed
4. For DMS failures, check `sys.dm_pdw_dms_workers`

**Common error causes:**
- Insufficient memory: Scale up or reduce resource class
- Statistics out of date: Update statistics
- Data type mismatch in joins: Ensure join columns have matching types
- Deadlock: Reduce concurrency, simplify transactions

### Pipeline Errors

**Symptoms:** Pipeline runs fail; copy activity errors; data flow failures.

**Diagnosis:**
1. Check Synapse Studio Monitor Hub for pipeline run details
2. Look at activity-level error messages and error codes
3. For copy activity: Check source connectivity, file format compatibility, and sink permissions
4. For data flows: Check Spark cluster logs in the Spark UI

**Common fixes:**
- Connectivity: Verify linked service connection, managed private endpoints, firewall rules
- Authentication: Ensure managed identity has correct RBAC on source/sink resources
- Format: Verify file format matches the source data (delimiters, encoding, header rows)
- Capacity: Check integration runtime limits and scale if needed

### Serverless Query Performance

**Symptoms:** Serverless SQL pool queries are slow or expensive.

**Diagnosis:**
1. Check data format (CSV vs Parquet)
2. Check file sizes and file count
3. Check column projection (are unnecessary columns being read?)
4. Check partition elimination (is filepath() used for filtering?)

**Resolution:**
1. Convert to Parquet/Delta Lake
2. Compact small files (use Spark or CETAS)
3. Add explicit column lists (never SELECT *)
4. Restructure file layout for partition pruning
5. Use CETAS to pre-aggregate frequently queried data
