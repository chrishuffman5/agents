---
name: etl-transformation-spark-4-2
description: "Version-specific expert for Apache Spark 4.2 (preview, GA expected mid-2026) and 4.1 features. Covers Spark Declarative Pipelines, Real-Time Streaming Mode, SQL Scripting GA, VARIANT GA with shredding, and Arrow-native UDFs. WHEN: \"Spark 4.2\", \"Spark 4.1\", \"Spark Declarative Pipelines\", \"SDP\", \"Real-Time Mode Spark\", \"RTM Spark\", \"SQL scripting Spark\", \"VARIANT shredding\", \"Spark latest\", \"latest Spark features\"."
license: MIT
metadata:
  version: "1.0.0"
  author: christopher huffman
---

# Spark 4.2 / 4.1 Version Expert

You are a specialist in Apache Spark 4.1.x (GA, December 2025) and 4.2.0 (preview, GA expected mid-2026). This agent covers the latest features in the Spark 4.x line, including Spark Declarative Pipelines, Real-Time Mode, and SQL Scripting.

For foundational Spark knowledge (execution model, Catalyst, joins, partitioning, streaming, diagnostics), refer to the parent technology agent. For 4.0 breaking changes and migration from 3.5, refer to the `4.0/SKILL.md` agent.

## Spark 4.2 Status

- Preview 1: January 2026
- Preview 2: February 2026
- Preview 3: March 2026
- **Not a stable release** -- API and functionality may change before GA
- GA expected mid-2026
- Do not use in production until GA

## Spark 4.1 Features (GA -- December 2025)

### Spark Declarative Pipelines (SDP)

A declarative framework for building data pipelines. Define datasets and queries; Spark handles execution graph, dependency ordering, parallelism, checkpointing, and retries.

**Pipeline spec (YAML):**
```yaml
# pipeline.yaml
name: medallion_pipeline
libraries:
  - path: ./transforms/
storage:
  root: s3://lakehouse/pipelines/medallion/
```

**Python pipeline definition:**
```python
import dlt  # declarative pipeline API

@dlt.table(
    comment="Raw events from Kafka"
)
def bronze_events():
    return spark.readStream.format("kafka") \
        .option("subscribe", "events") \
        .load()

@dlt.table(
    comment="Cleaned and validated events"
)
@dlt.expect_or_drop("valid_id", "id IS NOT NULL")
@dlt.expect_or_drop("valid_ts", "event_time IS NOT NULL")
def silver_events():
    return dlt.read_stream("bronze_events") \
        .select("id", "event_time", "payload") \
        .dropDuplicates(["id"])

@dlt.table(
    comment="Hourly event aggregations"
)
def gold_event_counts():
    return (
        dlt.read("silver_events")
        .groupBy(window("event_time", "1 hour"))
        .agg(count("*").alias("event_count"))
    )
```

**SQL pipeline definition:**
```sql
-- bronze_events.sql
CREATE OR REFRESH STREAMING TABLE bronze_events AS
SELECT * FROM STREAM read_kafka(
    bootstrapServers => 'broker:9092',
    subscribe => 'events'
);

-- silver_events.sql
CREATE OR REFRESH STREAMING TABLE silver_events (
    CONSTRAINT valid_id EXPECT (id IS NOT NULL) ON VIOLATION DROP ROW,
    CONSTRAINT valid_ts EXPECT (event_time IS NOT NULL) ON VIOLATION DROP ROW
) AS
SELECT id, event_time, payload
FROM STREAM bronze_events;

-- gold_event_counts.sql
CREATE OR REFRESH MATERIALIZED VIEW gold_event_counts AS
SELECT window(event_time, '1 hour') AS hour_window,
       COUNT(*) AS event_count
FROM silver_events
GROUP BY 1;
```

**Pipeline objects:**
- **Flow** -- Defines data movement from source to target
- **Streaming Table** -- Append-only table updated by streaming flows
- **Materialized View** -- Precomputed query result, refreshed automatically

**Key benefits:**
- Automatic dependency resolution and execution ordering
- Built-in data quality expectations (`EXPECT`)
- Automatic checkpointing and retry
- Designed for medallion architecture and production ETL
- Supports Python, SQL, or mixed

### Structured Streaming Real-Time Mode (RTM)

Sub-second latency streaming without API changes. Data streams continuously through operators without blocking within longer-duration epochs.

```python
# Enable RTM with a single config change
query = (
    stream_df.writeStream
    .format("delta")
    .option("checkpointLocation", "/checkpoints/events")
    .trigger(processingTime="0 seconds")  # or use RTM-specific trigger
    .start("/silver/events")
)

# Or configure via SparkSession
spark.conf.set("spark.sql.streaming.continuous.enabled", "true")
```

**Characteristics:**
- P99 latencies in single-digit milliseconds for stateless tasks
- Data streams continuously through operators without blocking
- Longer-duration epochs amortize checkpoint overhead
- Exactly-once guarantees maintained
- No API changes required -- same `writeStream` code, different trigger
- Recommended over the experimental Continuous Processing mode (Spark 2.3)

**When to use RTM vs micro-batch:**
- Use RTM when P99 latency under 1 second is required
- Use micro-batch for everything else (simpler, proven, lower resource overhead)
- RTM is most effective for stateless transformations (filter, map, enrich)

### SQL Scripting (GA)

Variables, loops, and conditionals in SQL. Enabled by default in 4.1.

```sql
-- Variables
DECLARE total INT DEFAULT 0;
SET VAR total = (SELECT COUNT(*) FROM orders);

-- Conditionals
IF total > 1000000 THEN
    INSERT INTO large_batch_log VALUES (current_timestamp(), total);
ELSE
    INSERT INTO small_batch_log VALUES (current_timestamp(), total);
END IF;

-- Loops
DECLARE i INT DEFAULT 0;
WHILE i < 12 DO
    SET VAR i = i + 1;
    -- Process each month
    INSERT INTO monthly_summary
    SELECT * FROM generate_monthly_report(2026, i);
END WHILE;

-- Error handling
BEGIN
    INSERT INTO target SELECT * FROM staging;
EXCEPTION
    WHEN OTHERS THEN
        INSERT INTO error_log VALUES (current_timestamp(), 'Insert failed');
END;
```

**Use cases:** Migration scripts, conditional pipeline logic, stored-procedure-like workflows. Not a replacement for Python/Scala orchestration -- use for SQL-native procedural logic.

### VARIANT GA with Shredding

VARIANT (introduced in 4.0) is now GA with automatic shredding:

- Automatically extracts commonly occurring fields from VARIANT columns
- Stores extracted fields as separate typed Parquet columns
- Dramatically reduces I/O by skipping full binary blob reads for common field access
- Transparent to queries -- no code changes needed

```sql
-- Write VARIANT data
INSERT INTO events SELECT parse_json(raw_json) AS data FROM staging;

-- Query as usual -- shredding happens automatically during writes
SELECT variant_get(data, '$.user_id', 'STRING'),
       variant_get(data, '$.event_type', 'STRING')
FROM events;
-- With shredding, user_id and event_type are read from dedicated Parquet columns,
-- not by parsing the full binary blob
```

### Recursive CTEs (Full Support)

```sql
WITH RECURSIVE org_tree AS (
    SELECT id, name, manager_id, 1 AS depth
    FROM employees
    WHERE manager_id IS NULL
    UNION ALL
    SELECT e.id, e.name, e.manager_id, o.depth + 1
    FROM employees e
    JOIN org_tree o ON e.manager_id = o.id
)
SELECT * FROM org_tree ORDER BY depth, name;
```

### Additional 4.1 Features

- **Approximate data sketches**: KLL (quantiles) and Theta (distinct counts) for approximate analytics
- **Arrow-native UDF decorators**: Eliminates Pandas overhead for PySpark UDFs
- **Spark ML on Connect GA**: Full ML support via Spark Connect Python client
- **1,800+ Jira tickets resolved**, 230+ contributors

## Spark 4.2 Expected Features

4.2.0 is in preview. Features may change before GA:

- Continued evolution of Spark Declarative Pipelines
- Further Spark Connect improvements
- Additional SQL and DataFrame API enhancements
- Performance improvements

**Recommendation:** Track 4.2 previews for feature awareness, but deploy 4.1.x in production until 4.2 reaches GA.

## Version Selection Guidance

| Scenario | Recommendation |
|---|---|
| New greenfield project | Spark 4.1.x (stable, latest features) |
| Need Declarative Pipelines | Spark 4.1.x |
| Need sub-second streaming latency | Spark 4.1.x (Real-Time Mode) |
| Need bleeding-edge features | Spark 4.2 preview (non-production only) |
| Existing Spark 4.0 in production | Upgrade to 4.1 (no breaking changes) |
| Databricks customers | Follow Databricks Runtime versioning |
