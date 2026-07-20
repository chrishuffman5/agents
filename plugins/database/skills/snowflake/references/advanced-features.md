# Snowflake Advanced Features

## Data Sharing and Marketplace

**Secure Data Sharing** enables real-time, zero-copy sharing across Snowflake accounts:

```sql
-- Provider: Create a share
CREATE SHARE revenue_share;
GRANT USAGE ON DATABASE analytics TO SHARE revenue_share;
GRANT USAGE ON SCHEMA analytics.public TO SHARE revenue_share;
GRANT SELECT ON TABLE analytics.public.revenue_summary TO SHARE revenue_share;

-- Provider: Add consumer accounts
ALTER SHARE revenue_share ADD ACCOUNTS = org1.consumer_account;

-- Consumer: Create a database from the share
CREATE DATABASE shared_revenue FROM SHARE provider_org.provider_account.revenue_share;

-- Secure views for row-level filtering per consumer
CREATE SECURE VIEW shared_orders AS
SELECT * FROM orders WHERE tenant_id = CURRENT_ACCOUNT();
```

**Snowflake Marketplace:** Publish datasets for discovery by any Snowflake customer. Supports free and paid listings.

**Key characteristics:**
- No data copying -- consumers query the provider's live data
- Provider controls access and can revoke at any time
- Cross-cloud and cross-region sharing supported (via replication)
- Reader accounts allow sharing with non-Snowflake customers (provider pays compute)

## Snowpark (Python, Java, Scala)

Snowpark enables programmatic data processing using DataFrames that execute in Snowflake:

```python
from snowflake.snowpark import Session
from snowflake.snowpark.functions import col, sum as sum_, avg, count

# Create session
session = Session.builder.configs({
    "account": "myaccount",
    "user": "myuser",
    "password": "mypassword",
    "warehouse": "compute_wh",
    "database": "analytics",
    "schema": "public"
}).create()

# DataFrame operations (lazy evaluation, pushdown to Snowflake)
df = session.table("orders")
result = (df
    .filter(col("order_date") > "2026-01-01")
    .group_by("region")
    .agg(
        sum_("amount").alias("total_revenue"),
        avg("amount").alias("avg_order_value"),
        count("*").alias("order_count")
    )
    .sort(col("total_revenue").desc())
)
result.show()

# Register a UDF
from snowflake.snowpark.functions import udf

@udf(name="categorize_amount", is_permanent=True, stage_location="@my_stage",
     replace=True, packages=["snowflake-snowpark-python"])
def categorize_amount(amount: float) -> str:
    if amount > 1000: return "high"
    elif amount > 100: return "medium"
    else: return "low"

# Stored procedures in Python
from snowflake.snowpark.functions import sproc

@sproc(name="daily_aggregation", is_permanent=True, stage_location="@my_stage",
       replace=True, packages=["snowflake-snowpark-python"])
def daily_aggregation(session: Session, target_date: str) -> str:
    df = session.table("raw_events").filter(col("event_date") == target_date)
    agg = df.group_by("event_type").agg(count("*").alias("cnt"))
    agg.write.mode("overwrite").save_as_table("daily_event_counts")
    return f"Processed {agg.count()} event types for {target_date}"
```

**Snowpark-optimized warehouses:** Use `WAREHOUSE_TYPE = 'SNOWPARK-OPTIMIZED'` for workloads that need more memory per node (ML training, large UDFs). These warehouses have 16x memory per node compared to standard warehouses.

## Snowflake Cortex (AI/ML)

Snowflake Cortex provides built-in AI/ML functions that run directly on your data:

```sql
-- LLM functions (no model deployment needed)
SELECT SNOWFLAKE.CORTEX.COMPLETE('mistral-large2', 'Summarize this text: ' || review_text) AS summary
FROM product_reviews LIMIT 10;

-- Sentiment analysis
SELECT review_text,
       SNOWFLAKE.CORTEX.SENTIMENT(review_text) AS sentiment_score
FROM product_reviews;

-- Text summarization
SELECT SNOWFLAKE.CORTEX.SUMMARIZE(article_body) AS summary
FROM news_articles;

-- Translation
SELECT SNOWFLAKE.CORTEX.TRANSLATE(description, 'en', 'es') AS spanish_desc
FROM products;

-- Embeddings for semantic search
SELECT SNOWFLAKE.CORTEX.EMBED_TEXT_768('snowflake-arctic-embed-m-v1.5', description)
FROM products;

-- Cortex Search (RAG-based search over your data)
CREATE CORTEX SEARCH SERVICE product_search
  ON description
  WAREHOUSE = search_wh
  TARGET_LAG = '1 hour'
  AS (SELECT product_id, name, description FROM products);

-- Cortex Fine-tuning
SELECT SNOWFLAKE.CORTEX.FINETUNE(
    'CREATE',
    'mistral-7b',
    '@training_data_stage/train.jsonl',
    '@training_data_stage/val.jsonl'
);

-- Cortex Analyst (natural language to SQL)
-- Configured via semantic model YAML, queried through Streamlit or API
```

## Dynamic Tables

Dynamic tables provide declarative, incremental pipelines:

```sql
-- Define a dynamic table with a target lag
CREATE DYNAMIC TABLE customer_orders_summary
  TARGET_LAG = '10 minutes'
  WAREHOUSE = transform_wh
AS
  SELECT
      c.customer_id,
      c.name,
      COUNT(o.order_id) AS order_count,
      SUM(o.amount) AS total_spent,
      MAX(o.order_date) AS last_order_date
  FROM customers c
  JOIN orders o ON c.customer_id = o.customer_id
  GROUP BY c.customer_id, c.name;

-- Chain dynamic tables for multi-step pipelines
CREATE DYNAMIC TABLE high_value_customers
  TARGET_LAG = '10 minutes'
  WAREHOUSE = transform_wh
AS
  SELECT * FROM customer_orders_summary WHERE total_spent > 10000;
```

**Dynamic tables vs. streams/tasks:** Dynamic tables are simpler for declarative transformation pipelines. Snowflake automatically manages incremental refresh. Use streams/tasks when you need procedural logic, conditional execution, or complex error handling.

## Materialized Views (Enterprise+)

```sql
CREATE MATERIALIZED VIEW daily_revenue_mv AS
SELECT
    order_date,
    region,
    SUM(amount) AS total_revenue,
    COUNT(*) AS order_count
FROM orders
GROUP BY order_date, region;

-- Snowflake auto-refreshes when base table changes
-- Query the MV directly (optimizer may auto-redirect base table queries to MV)
SELECT * FROM daily_revenue_mv WHERE order_date > '2026-01-01';
```

**Limitations:** No JOINs in materialized view definitions. Single-table aggregations only. For multi-table transformations, use dynamic tables instead.

## External Tables and Iceberg Tables

**External tables** query data in cloud storage without loading:
```sql
CREATE EXTERNAL TABLE ext_logs (
    log_time TIMESTAMP AS (VALUE:log_time::TIMESTAMP),
    level STRING AS (VALUE:level::STRING),
    message STRING AS (VALUE:message::STRING)
)
WITH LOCATION = @my_stage/logs/
FILE_FORMAT = (TYPE = 'PARQUET')
AUTO_REFRESH = TRUE;
```

**Iceberg tables** provide open-format interoperability:
```sql
-- Snowflake-managed Iceberg table (Snowflake manages the Iceberg catalog)
CREATE ICEBERG TABLE events_iceberg (
    event_id STRING,
    event_type STRING,
    event_time TIMESTAMP_NTZ,
    payload VARIANT
)
CATALOG = 'SNOWFLAKE'
EXTERNAL_VOLUME = 'my_external_volume'
BASE_LOCATION = 'events/';

-- Externally managed Iceberg table (read from external Iceberg catalog)
CREATE ICEBERG TABLE ext_iceberg_table
  CATALOG = 'my_glue_catalog'
  EXTERNAL_VOLUME = 'my_external_volume'
  CATALOG_TABLE_NAME = 'my_database.my_table';
```

**Iceberg tables use cases:** Open data lakehouse, multi-engine interoperability (Spark, Trino, Flink can read the same Iceberg data), avoiding vendor lock-in, compliance requirements for open formats.

## Cost Optimization

**Credit consumption hierarchy:**
1. Virtual warehouses (typically 50-80% of bill)
2. Serverless features (Snowpipe, serverless tasks, auto-clustering, search optimization, replication)
3. Cloud services (>10% of daily warehouse credits)
4. Storage (compressed bytes + Time Travel + Fail-Safe)

**Key optimization strategies:**
```sql
-- Resource monitors for budget alerts and enforcement
CREATE RESOURCE MONITOR daily_monitor
  WITH CREDIT_QUOTA = 100
  FREQUENCY = DAILY
  START_TIMESTAMP = IMMEDIATELY
  TRIGGERS
    ON 75 PERCENT DO NOTIFY
    ON 90 PERCENT DO NOTIFY
    ON 100 PERCENT DO SUSPEND;

ALTER WAREHOUSE analytics_wh SET RESOURCE_MONITOR = daily_monitor;
```

**Warehouse optimization:**
- Right-size warehouses: start small, scale up only if queries spill or timeout
- Set aggressive auto-suspend (60s for interactive, 0 for batch with manual suspend)
- Use multi-cluster warehouses instead of a single large warehouse for concurrency
- Separate warehouses per workload (ETL, BI, ad-hoc) to avoid contention and enable independent sizing

**Storage optimization:**
- Use transient tables for staging/temp data (no Fail-Safe costs)
- Reduce Time Travel retention for non-critical tables
- Drop unused clones and historical data
- Monitor Time Travel and Fail-Safe storage growth
