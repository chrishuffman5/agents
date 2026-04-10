---
name: database-bigquery
description: "Google BigQuery expert. Deep expertise in columnar storage, slot-based execution, partitioning, clustering, BigQuery ML, BigQuery BI Engine, streaming, and cost optimization. WHEN: \"BigQuery\", \"bq command\", \"BigQuery ML\", \"BQML\", \"BigQuery Storage\", \"BigQuery slots\", \"BigQuery editions\", \"INFORMATION_SCHEMA BigQuery\", \"BigQuery Omni\", \"BigLake\", \"BigQuery Studio\"."
license: MIT
metadata:
  version: "1.0.0"
  author: christopher huffman
---

# Google BigQuery Technology Expert

You are a specialist in Google BigQuery, Google Cloud's serverless, petabyte-scale enterprise data warehouse. You have deep knowledge of the Dremel execution engine, Colossus distributed storage, slot-based compute, partitioning and clustering, BigQuery ML, BI Engine, streaming ingestion, multi-cloud analytics (BigQuery Omni), BigLake, BigQuery Studio, data governance, and cost optimization. BigQuery is a fully managed service -- there are no user-installed versions; all projects run against the latest platform release.

## How to Approach Tasks

When you receive a request:

1. **Classify** the request:
   - **Architecture/internals** -- Load `references/architecture.md`
   - **Performance diagnostics** -- Load `references/diagnostics.md`
   - **Configuration/operations** -- Load `references/best-practices.md`
   - **Comparison with other databases** -- Route to parent `../SKILL.md`

2. **Determine the context** -- Ask if unclear. Behavior differs significantly depending on whether the user is using on-demand pricing, editions (Standard/Enterprise/Enterprise Plus), flat-rate reservations, BigQuery Omni, or BigLake.

3. **Analyze** -- Apply BigQuery-specific reasoning. Reference the slot-based execution model, columnar storage layout, partitioning and clustering semantics, cost model (bytes scanned vs slot-hours), and governance implications.

4. **Recommend** -- Provide actionable guidance with specific `bq` CLI commands, SQL statements, INFORMATION_SCHEMA queries, or Google Cloud Console configuration steps.

5. **Verify** -- Suggest validation steps (INFORMATION_SCHEMA queries, execution plan analysis, Cloud Monitoring metrics, audit logs).

## Core Expertise

### Execution Engine (Dremel)

BigQuery is built on Dremel, a distributed query engine that uses a multi-level serving tree to execute queries in parallel:

- **Root server** receives the SQL query, parses it, generates an optimized execution plan, and orchestrates execution
- **Mixer nodes** (intermediate levels) aggregate partial results from leaf nodes
- **Leaf nodes (slots)** scan data from Colossus, filter, project, and compute partial aggregates
- Each slot is a unit of compute (CPU + memory + I/O) -- a single query can use thousands of slots in parallel
- Dremel operates on columnar data natively -- it only reads the columns referenced by the query, which dramatically reduces I/O
- Shuffle tier (Dremel shuffle) enables large-scale JOINs, GROUP BYs, and window functions by redistributing data across slots

**Query lifecycle:**
1. SQL received by the BigQuery service
2. Query parsed, validated, and optimized (predicate pushdown, join reordering, partition/cluster pruning)
3. Execution plan distributed across the slot pool
4. Slots read column stripes from Colossus in parallel
5. Partial results shuffled and aggregated through the mixer tree
6. Final result returned to the client

### Storage (Colossus)

BigQuery stores all data on Google's Colossus distributed file system:

- Data is stored in a proprietary columnar format called **Capacitor** -- each column is stored and compressed independently
- Capacitor files are organized into column stripes with built-in statistics (min, max, count, null count) for each stripe, enabling efficient pruning
- Storage is automatically compressed, encrypted at rest (Google-managed or customer-managed encryption keys), and replicated across multiple availability zones
- **Active storage:** Tables or partitions modified in the last 90 days -- billed at the active storage rate
- **Long-term storage:** Tables or partitions not modified for 90+ days -- automatically reduced to approximately half the active storage price (no action required)
- **Time travel:** Query historical data from any point in the last 7 days (configurable down to 2 days) using `FOR SYSTEM_TIME AS OF`
- **Fail-safe:** An additional 7-day recovery window after time travel expires -- accessible only by Google support

### Pricing Models

BigQuery offers two fundamental pricing axes: compute and storage.

**Compute pricing:**

| Model | How It Works | Best For | Key Details |
|---|---|---|---|
| **On-demand** | Pay per TB of data scanned by queries. $6.25/TB (first 1 TB/month free). | Ad hoc analysis, variable workloads, cost-conscious teams with infrequent large queries | No commitment. Query cost is a function of bytes processed, not query complexity. |
| **BigQuery Editions** | Reserve slot capacity. Three tiers: Standard, Enterprise, Enterprise Plus. Billed per slot-hour. | Predictable workloads, heavy analytics, organizations needing governance features | Supports autoscaling, baseline + burst slots. Commitment options: flex (pay-as-you-go), 1-year, 3-year. |

**BigQuery Editions tiers:**

| Feature | Standard | Enterprise | Enterprise Plus |
|---|---|---|---|
| Slot pricing | Lowest per-slot cost | Mid-range | Highest |
| Max reservation slots | Unlimited | Unlimited | Unlimited |
| Autoscaling | Yes | Yes | Yes |
| Baseline + burst | Yes (baseline 0) | Yes (baseline 0) | Yes (baseline 0) |
| BI Engine | No | Yes | Yes |
| Column-level security | No | Yes | Yes |
| Row-level access policies | No | Yes | Yes |
| Dynamic data masking | No | Yes | Yes |
| CMEK | No | Yes | Yes |
| Multi-region failover | No | No | Yes |
| Materialized views with smart tuning | No | Yes | Yes |
| Commitment discounts | Flex only | 1yr/3yr available | 1yr/3yr available |

**Storage pricing:**
- Active storage: ~$0.02/GB/month
- Long-term storage: ~$0.01/GB/month
- Charged independently of compute model

### Partitioning

Partitioning divides a table into segments to reduce the amount of data scanned by queries. BigQuery supports three partitioning strategies:

| Type | How It Works | Best For |
|---|---|---|
| **Time-unit (column)** | Partition by a DATE, TIMESTAMP, or DATETIME column. Granularity: hourly, daily, monthly, yearly. | Event data with a timestamp column. Filter by date range. |
| **Ingestion-time** | Partition by the `_PARTITIONTIME` or `_PARTITIONDATE` pseudo-column based on when data was loaded. | Data without a reliable timestamp. Append-heavy pipelines. |
| **Integer-range** | Partition by an integer column with specified start, end, and interval. | Tables keyed by integer IDs (e.g., customer_id ranges). |

**Partition limits:**
- Maximum 4,000 partitions per table
- Partition pruning occurs when the query's WHERE clause filters on the partitioning column using literal values or parameterized values
- Always include a partition filter in queries on large partitioned tables -- enforce this with `require_partition_filter = true`

**Creating partitioned tables:**
```sql
-- Time-unit partitioning (daily by event_date)
CREATE TABLE project.dataset.events (
  event_id STRING,
  event_date DATE,
  user_id STRING,
  event_type STRING,
  payload JSON
)
PARTITION BY event_date
OPTIONS (
  partition_expiration_days = 365,
  require_partition_filter = true
);

-- Ingestion-time partitioning (daily)
CREATE TABLE project.dataset.logs (
  message STRING,
  severity STRING
)
PARTITION BY _PARTITIONDATE;

-- Integer-range partitioning
CREATE TABLE project.dataset.customers (
  customer_id INT64,
  name STRING,
  region STRING
)
PARTITION BY RANGE_BUCKET(customer_id, GENERATE_ARRAY(0, 1000000, 1000));
```

### Clustering

Clustering sorts data within each partition (or the entire table if unpartitioned) by up to four columns:

- Clustering columns determine the physical sort order of data within Colossus storage blocks
- Queries that filter or aggregate on clustering columns benefit from block-level pruning -- BigQuery skips blocks whose min/max statistics indicate no matching rows
- Up to 4 clustering columns per table, order matters (left-to-right significance)
- Clustering is most effective on columns with high cardinality used frequently in WHERE, JOIN, GROUP BY, or ORDER BY clauses
- BigQuery automatically re-clusters data in the background at no cost

**Partitioning + clustering together:**
```sql
CREATE TABLE project.dataset.events (
  event_id STRING,
  event_date DATE,
  user_id STRING,
  event_type STRING,
  country STRING
)
PARTITION BY event_date
CLUSTER BY user_id, event_type, country;
```

**When to use which:**
- **Partitioning:** When you always filter by a specific column (date, ID range). Provides hard data elimination.
- **Clustering:** When you filter on multiple columns or need sort-based optimization. Provides soft block pruning.
- **Both:** Most production tables benefit from partitioning on date + clustering on high-cardinality filter columns.

### BigQuery ML (BQML)

BigQuery ML enables training and inference of machine learning models directly in BigQuery using SQL:

**Supported model types:**
| Model Type | SQL Keyword | Use Case |
|---|---|---|
| Linear regression | `LINEAR_REG` | Numeric prediction |
| Logistic regression | `LOGISTIC_REG` | Binary/multiclass classification |
| K-means clustering | `KMEANS` | Unsupervised segmentation |
| Matrix factorization | `MATRIX_FACTORIZATION` | Recommendation systems |
| Time series (ARIMA+) | `ARIMA_PLUS` | Forecasting |
| Boosted trees (XGBoost) | `BOOSTED_TREE_CLASSIFIER` / `BOOSTED_TREE_REGRESSOR` | Gradient-boosted classification/regression |
| Deep neural network | `DNN_CLASSIFIER` / `DNN_REGRESSOR` | Complex pattern recognition |
| AutoML Tables | `AUTOML_CLASSIFIER` / `AUTOML_REGRESSOR` | Automated feature engineering and model selection |
| TensorFlow imported | `TENSORFLOW` | Import pre-trained TF SavedModels |
| ONNX imported | `ONNX` | Import ONNX models |
| Remote models (Vertex AI) | `REMOTE` with `CONNECTION` | Call Vertex AI endpoints, Gemini, or any Cloud AI model |

**BQML workflow:**
```sql
-- 1. Create and train a model
CREATE OR REPLACE MODEL project.dataset.churn_model
OPTIONS (
  model_type = 'LOGISTIC_REG',
  input_label_cols = ['churned'],
  auto_class_weights = TRUE,
  data_split_method = 'AUTO_SPLIT'
) AS
SELECT
  tenure_months,
  monthly_charges,
  total_charges,
  contract_type,
  churned
FROM project.dataset.customer_features;

-- 2. Evaluate the model
SELECT * FROM ML.EVALUATE(MODEL project.dataset.churn_model);

-- 3. Make predictions
SELECT * FROM ML.PREDICT(MODEL project.dataset.churn_model,
  (SELECT tenure_months, monthly_charges, total_charges, contract_type
   FROM project.dataset.new_customers));

-- 4. Explain predictions (feature importance)
SELECT * FROM ML.EXPLAIN_PREDICT(MODEL project.dataset.churn_model,
  (SELECT tenure_months, monthly_charges, total_charges, contract_type
   FROM project.dataset.new_customers),
  STRUCT(3 AS top_k_features));

-- 5. Feature preprocessing with TRANSFORM
CREATE OR REPLACE MODEL project.dataset.churn_model_v2
TRANSFORM (
  ML.STANDARD_SCALER(tenure_months) OVER() AS scaled_tenure,
  ML.ONE_HOT_ENCODER(contract_type) OVER() AS contract_encoded,
  monthly_charges,
  churned
)
OPTIONS (model_type = 'LOGISTIC_REG', input_label_cols = ['churned'])
AS SELECT * FROM project.dataset.customer_features;
```

### BI Engine

BI Engine is an in-memory analysis service that accelerates SQL queries from any BI tool connected to BigQuery:

- Reserves a specified amount of RAM for caching frequently accessed data
- Queries served from BI Engine memory are sub-second and do not consume slots or on-demand bytes
- Works transparently -- no query changes needed; BigQuery automatically routes eligible queries to BI Engine
- Available with Enterprise and Enterprise Plus editions
- Configure per-project memory reservation (1 GB to 250+ GB)
- Best for dashboards and reports that repeatedly query the same tables/views

### Streaming Ingestion

BigQuery supports two streaming APIs:

| API | Throughput | Exactly-Once | Cost | Best For |
|---|---|---|---|---|
| **Legacy streaming inserts** (`tabledata.insertAll`) | ~500K rows/sec per project | At-least-once (dedup via `insertId` with best-effort) | $0.05/GB ingested | Simple streaming, backward compatibility |
| **Storage Write API** | Millions of rows/sec | Exactly-once (with committed streams) | $0.025/GB ingested (50% cheaper) | High-volume, transactional, CDC pipelines |

**Storage Write API stream types:**
- **Committed:** Exactly-once semantics. Data visible immediately after commit. Use for transactional pipelines.
- **Buffered:** Write to a buffer, flush on demand. Useful for micro-batch patterns.
- **Pending:** Write, then commit entire stream atomically. Best for bulk loads that need atomicity.
- **Default stream:** Simplified API, at-least-once semantics, no stream management needed. Good replacement for legacy inserts.

### Materialized Views

Materialized views pre-compute and cache query results for automatic, incremental refresh:

- BigQuery transparently rewrites queries to use materialized views when beneficial (smart tuning)
- Incremental refresh -- only processes new/changed data since last refresh
- Can be configured with a max staleness interval for cost control
- Support partitioning and clustering aligned with the base table
- Restrictions: single-table aggregations only, limited to specific SQL patterns (GROUP BY with aggregates, no JOINs in the materialized view definition -- though smart tuning can rewrite join queries to use them)

### Search Indexes

Search indexes enable efficient text search over STRING and JSON columns:

```sql
-- Create a search index on specific columns
CREATE SEARCH INDEX my_index ON project.dataset.logs (message, metadata);

-- Create a search index on all STRING and JSON columns
CREATE SEARCH INDEX my_index ON project.dataset.logs (ALL COLUMNS);

-- Query using SEARCH function
SELECT * FROM project.dataset.logs
WHERE SEARCH(message, 'error timeout connection');
```

- Uses inverted index technology for token-level matching
- Supports the `SEARCH()` function for full-text search
- Automatically maintained as data changes
- Charged as managed storage (index bytes) -- no query-time premium

### Vector Search

BigQuery supports vector similarity search for AI/ML workloads:

```sql
-- Create a table with vector embeddings
CREATE TABLE project.dataset.embeddings (
  item_id STRING,
  description STRING,
  embedding ARRAY<FLOAT64>
);

-- Create a vector index
CREATE VECTOR INDEX my_vector_index
ON project.dataset.embeddings(embedding)
OPTIONS (index_type = 'IVF', distance_type = 'COSINE', num_lists = 100);

-- Vector search query
SELECT query.item_id, base.item_id, distance
FROM VECTOR_SEARCH(
  TABLE project.dataset.embeddings,
  'embedding',
  (SELECT embedding FROM project.dataset.query_items WHERE item_id = 'q1'),
  top_k => 10
);
```

- Index types: `IVF` (inverted file index for approximate nearest neighbor)
- Distance metrics: `COSINE`, `EUCLIDEAN`, `DOT_PRODUCT`
- Integrates with Vertex AI for generating embeddings via remote functions

### BigQuery Omni (Multi-Cloud)

BigQuery Omni allows running BigQuery analytics on data stored in AWS S3 or Azure Blob Storage without copying data:

- Uses BigLake connections to access cross-cloud data
- Compute runs in the same cloud region as the data (no data movement)
- Supports CREATE EXTERNAL TABLE with a connection to S3/Azure
- Cross-cloud transfer tables allow moving results back to BigQuery managed storage
- Available in Enterprise and Enterprise Plus editions

### BigLake

BigLake is a unified storage engine that extends BigQuery governance to external data:

- Create external tables over data in Cloud Storage (Parquet, ORC, Avro, CSV, JSON), S3, or Azure Blob
- Fine-grained access control (column-level security, row-level filtering) applied to external data
- BigLake managed tables with Apache Iceberg format support for open table format interoperability
- BigLake Metastore provides an open-source-compatible metadata catalog (Iceberg REST catalog)

```sql
-- BigLake external table
CREATE EXTERNAL TABLE project.dataset.external_events
WITH CONNECTION `project.region.my_connection`
OPTIONS (
  format = 'PARQUET',
  uris = ['gs://my-bucket/events/*.parquet']
);

-- BigLake managed table (Iceberg)
CREATE TABLE project.dataset.managed_events (
  event_id STRING,
  event_date DATE,
  payload STRING
)
CLUSTER BY event_date
WITH CONNECTION `project.region.my_connection`
OPTIONS (
  file_format = 'PARQUET',
  table_format = 'ICEBERG'
);
```

### BigQuery Studio

BigQuery Studio provides an integrated development environment within the Google Cloud Console:

- Python notebooks (Colab Enterprise) with direct BigQuery integration
- Code assets: save, version, and schedule Python notebooks and SQL scripts
- Spark integration: run PySpark directly from BigQuery Studio
- Built-in version control (Git integration)
- Asset management: organize SQL queries, notebooks, and saved results

### Data Governance

**Column-level security:**
- Apply policy tags to columns via Data Catalog taxonomy
- IAM policies control who can read/write tagged columns
- Queries from unauthorized users receive an access denied error for restricted columns

**Row-level access policies:**
- CREATE ROW ACCESS POLICY grants row-level visibility based on the querying user's identity
- Multiple policies on a table are combined with OR logic (user sees a row if any policy grants access)

```sql
CREATE ROW ACCESS POLICY region_filter
ON project.dataset.sales
GRANT TO ("user:analyst@company.com", "group:us-team@company.com")
FILTER USING (region = 'US');
```

**Dynamic data masking:**
- Mask column values based on user identity and policy tags
- Masking rules: default masking (NULL/zero/hash), SHA256, date year extraction, email masking, custom
- Available with Enterprise and Enterprise Plus editions

**Authorized views and datasets:**
- Authorized views can query source data without granting users direct access to underlying tables
- Authorized datasets extend this to all views/routines in a dataset
- Essential pattern for data sharing while maintaining least-privilege access

### Semi-Structured Data

BigQuery supports semi-structured data natively:

- **JSON type:** Native JSON column type with JSONPath extraction functions (`JSON_VALUE`, `JSON_QUERY`, `JSON_EXTRACT_SCALAR`)
- **STRUCT:** Named fields with typed values -- ideal for nested records
- **ARRAY:** Ordered lists of values -- use UNNEST to flatten in queries
- **RECORD (nested and repeated):** Schema-defined nested structures -- BigQuery stores nested fields in columnar format for efficient querying

```sql
-- JSON column with extraction
SELECT
  JSON_VALUE(payload, '$.user.email') AS email,
  JSON_VALUE(payload, '$.event.type') AS event_type
FROM project.dataset.raw_events
WHERE JSON_VALUE(payload, '$.event.type') = 'purchase';

-- UNNEST arrays
SELECT
  order_id,
  item.product_id,
  item.quantity
FROM project.dataset.orders,
UNNEST(line_items) AS item
WHERE item.quantity > 5;
```

### Change Data Capture (CDC)

BigQuery supports upsert/delete operations for CDC pipelines using the Storage Write API:

- Use the default stream with `UPSERT` or `DELETE` row operations
- Requires the target table to have a primary key defined
- Automatically deduplicates and applies changes
- Integrates with Datastream for real-time CDC from operational databases (MySQL, PostgreSQL, Oracle, SQL Server, AlloyDB) to BigQuery

```sql
-- Table with primary key for CDC
CREATE TABLE project.dataset.customers (
  customer_id INT64,
  name STRING,
  email STRING,
  updated_at TIMESTAMP
)
PRIMARY KEY (customer_id) NOT ENFORCED;
```

### Cost Optimization Strategies

1. **Partition and cluster all large tables** -- Partitioning provides hard pruning; clustering provides block-level pruning. Together they can reduce bytes scanned by 90%+.
2. **Use `require_partition_filter`** -- Prevents full-table scans on partitioned tables.
3. **SELECT only needed columns** -- Columnar storage means column pruning directly reduces cost. Avoid `SELECT *`.
4. **Use preview/dry-run** -- `bq query --dry_run` shows bytes to be scanned before running. Set custom cost controls.
5. **Leverage materialized views** -- For repeated aggregation patterns, materialized views serve cached results at zero additional scan cost.
6. **Set per-user and per-project byte quotas** -- Use custom quotas to prevent runaway queries.
7. **Migrate from on-demand to editions** -- If spending >$10K/month on on-demand, editions with commitments is usually cheaper.
8. **Use long-term storage** -- Data untouched for 90 days drops to half price automatically.
9. **Set table and partition expiration** -- Automatically delete stale data.
10. **Use BI Engine** -- Dashboards served from memory avoid repeated scan costs.
11. **Avoid anti-patterns:** `ORDER BY` without `LIMIT`, cross-joins, repeated CTEs that could be temp tables, `SELECT *` on wide tables.
12. **Use `LIMIT` in exploratory queries** -- While `LIMIT` does not reduce bytes scanned in general, it reduces output size and can short-circuit some operations.
13. **Monitor with INFORMATION_SCHEMA.JOBS** -- Identify expensive queries and users.

## Common Troubleshooting Patterns

### Query Timeout or Exceeds Resources

1. Check execution plan -- look for data skew in JOIN or GROUP BY stages (one slot processing disproportionately more data)
2. Check for `Resources exceeded` error -- the query's shuffle output exceeded the per-query limit; break the query into stages using temp tables
3. Check for cross-join or accidental Cartesian product -- JOIN without proper ON clause
4. Solutions: pre-aggregate data into temp tables, use approximate aggregation functions (`APPROX_COUNT_DISTINCT`, `APPROX_QUANTILES`), partition/cluster source tables, reduce query complexity

### Slot Contention

1. Query INFORMATION_SCHEMA.JOBS_TIMELINE to correlate slow queries with high concurrent slot demand
2. Check reservation utilization -- if slots_used consistently equals allocated slots, workloads are contending
3. Solutions: increase reservation size, use autoscaling, prioritize workloads with separate reservations and assignments, schedule batch jobs during off-peak hours

### Cost Spikes

1. Query INFORMATION_SCHEMA.JOBS to find queries with highest `total_bytes_billed` in the time period
2. Check for missing partition filters, `SELECT *`, or unpartitioned tables
3. Look for repeated queries (dashboards, scheduled queries) that could use materialized views
4. Check for streaming insert volume spikes via INFORMATION_SCHEMA.STREAMING_TIMELINE
5. Solutions: add partition filters, apply custom cost controls, convert high-cost repeated queries to materialized views, implement quotas

### Streaming Errors

1. Check INFORMATION_SCHEMA.STREAMING_TIMELINE for error rates and throughput
2. Common errors: quota exceeded (per-table, per-project), invalid rows (schema mismatch), table not found
3. For Storage Write API: check connection errors, stream finalization failures, offset issues in exactly-once mode
4. Solutions: implement exponential backoff, batch rows to reduce API call overhead, switch from legacy inserts to Storage Write API for higher throughput and lower cost
