# ETL / Data Integration Foundational Concepts

## ETL vs ELT vs EL Patterns

### ETL (Extract-Transform-Load)

Data is extracted from sources, transformed in an external engine (Spark, SSIS, Informatica), and loaded into the target in its final form.

- **When to use**: Transformation requires external compute (ML models, complex parsing, binary file processing), target system has limited compute (OLTP database), or data must be cleansed before it enters the warehouse (PII masking, compliance).
- **Trade-offs**: External compute costs, pipeline complexity, slower iteration on transformation logic (redeploy pipeline vs rerun SQL).

### ELT (Extract-Load-Transform)

Data is extracted from sources, loaded raw into a staging area (data lake, warehouse raw zone), and transformed using the target's compute engine (dbt, Spark SQL, warehouse SQL).

- **When to use**: Target is a modern cloud warehouse (Snowflake, BigQuery, Redshift, Databricks) with elastic compute. Analysts need access to raw data. Transformation logic changes frequently.
- **Trade-offs**: Warehouse compute costs scale with transformation complexity. Raw data in the warehouse increases storage costs and requires access controls on staging zones.
- **This is the dominant modern pattern.** Cloud warehouses have made compute cheap and elastic, so the argument for external transformation engines has weakened significantly.

### EL (Extract-Load)

Data is extracted and loaded with minimal or no transformation. Fivetran, Airbyte, and ADF copy activities are EL tools.

- **When to use**: Source-to-staging replication where transformation happens downstream. SaaS data ingestion (Salesforce, HubSpot, Stripe) where the EL tool handles API pagination, rate limiting, and schema changes.
- **Trade-offs**: You still need a transformation layer (dbt, Spark) downstream. EL tools are black boxes -- debugging sync failures requires understanding the tool's internal behavior.

## Batch vs Micro-Batch vs Streaming

| Dimension | Batch | Micro-Batch | Streaming |
|---|---|---|---|
| **Latency** | Minutes to hours | Seconds to minutes | Milliseconds to seconds |
| **Processing model** | Bounded dataset, run to completion | Small bounded windows processed frequently | Unbounded stream, continuous processing |
| **Complexity** | Lowest (SQL, simple scripts) | Moderate (Spark Structured Streaming, frequent Airflow) | Highest (ordering, watermarks, state management) |
| **Cost model** | Pay per run (serverless) or scheduled compute | Sustained compute with periodic spikes | Always-on infrastructure |
| **Error handling** | Retry the entire batch or failed partition | Retry the micro-batch window | Dead letter queue, per-record retry |
| **Examples** | Nightly warehouse load, monthly report | 5-minute Spark Streaming windows | Kafka consumer, Flink job, real-time fraud scoring |

**Decision rule**: Start with batch. Move to micro-batch when batch latency is unacceptable. Move to streaming only when micro-batch latency is unacceptable. Each step adds operational complexity.

## Change Data Capture (CDC) Patterns

CDC captures only the changed rows from a source system, avoiding full table scans.

### Log-Based CDC

Reads the database transaction log (WAL, binlog, redo log) to capture INSERT, UPDATE, DELETE events.

- **Tools**: Debezium (Kafka Connect), AWS DMS, Oracle GoldenGate, SQL Server CDC
- **Pros**: Zero impact on source queries, captures all changes including deletes, near-real-time
- **Cons**: Requires log access permissions, log retention configuration, schema changes require re-snapshotting
- **Best for**: High-volume OLTP sources where query-based CDC would impact performance

### Trigger-Based CDC

Database triggers fire on DML events and write changes to a shadow/audit table.

- **Pros**: Works on any database that supports triggers, captures before/after values
- **Cons**: Write amplification (every DML fires a trigger), performance impact on source, trigger maintenance
- **Best for**: Legacy databases without log access, low-volume sources

### Timestamp-Based CDC (Incremental Extraction)

Query rows where `updated_at > last_extraction_timestamp`.

- **Pros**: Simple, no infrastructure requirements, works with any SQL database
- **Cons**: Misses deletes (no row to query), misses updates that don't update the timestamp, clock skew between source and pipeline
- **Best for**: Sources with reliable `updated_at` columns, when missing deletes is acceptable

### Diff-Based CDC

Compare full snapshots between runs to identify changes.

- **Pros**: Catches all changes including deletes
- **Cons**: Requires storing previous snapshot, expensive for large tables, latency limited by snapshot frequency
- **Best for**: Small reference tables, sources with no change tracking

## Slowly Changing Dimensions (SCD)

SCD strategies define how dimension tables handle changes to source records over time.

### Type 1: Overwrite

Replace the old value with the new value. No history preserved.

- **Use when**: Correcting errors (typo in customer name), history is irrelevant, or downstream doesn't need point-in-time accuracy.

### Type 2: Add New Row

Insert a new row with the new values, mark the old row as inactive (effective_from/effective_to dates, is_current flag).

- **Use when**: Full history is required for audit or analytics (e.g., customer address changes over time, product price history). This is the most common SCD type in data warehouses.
- **Implementation**: Surrogate key (warehouse-generated) as PK, natural key (source PK) for matching, effective date range, is_current flag.

### Type 3: Add New Column

Add a column to store the previous value (e.g., `previous_address`, `current_address`).

- **Use when**: Only the immediately prior value matters, not full history. Rarely used in practice.

### Type 4: History Table

Maintain a separate history table alongside the current dimension table.

- **Use when**: Current dimension needs to stay small for query performance, but full history must be preserved.

### Type 6: Hybrid (1 + 2 + 3)

Combines Type 1 (overwrite current columns), Type 2 (add new row), and Type 3 (previous value column).

- **Use when**: Users need both current and previous values without joining to the history.

## Data Quality Dimensions

### Accuracy

Data reflects the real-world entity it represents. Postal code matches the city, email format is valid, numeric values are within expected ranges.

- **Checks**: Range validation, format validation, cross-field consistency, referential lookups against master data.

### Completeness

Required fields are populated. No unexpected NULLs in mandatory columns.

- **Checks**: NOT NULL assertions, required field counts, percentage thresholds (e.g., > 99% of records must have email).

### Consistency

The same data is represented the same way across systems. "USA", "US", "United States" should resolve to one canonical value.

- **Checks**: Conformance to reference data (ISO codes), cross-system reconciliation, duplicate detection.

### Timeliness

Data arrives within the expected SLA. A pipeline that should complete by 6 AM actually completes by 6 AM.

- **Checks**: Freshness monitors (max timestamp in target vs current time), SLA-based alerting, pipeline duration tracking.

### Uniqueness

No duplicate records where uniqueness is expected. Primary keys are unique, business keys don't have phantom duplicates from bad merges.

- **Checks**: DISTINCT counts vs total counts, primary key uniqueness assertions, fuzzy duplicate detection for entity resolution.

## Idempotency in Data Pipelines

An idempotent pipeline produces the same output regardless of how many times it runs for the same input window.

### Patterns for Achieving Idempotency

| Pattern | How | When |
|---|---|---|
| **Partition overwrite** | DELETE all rows in the target partition, then INSERT new rows | Date-partitioned fact tables, warehouse loads |
| **MERGE / upsert** | Match on business key, UPDATE existing rows, INSERT new ones | Dimension tables, SCD Type 1 |
| **Staging + swap** | Load into a staging table, then atomically swap with the production table | Small tables, full refreshes |
| **Deduplication on write** | Use QUALIFY ROW_NUMBER() or GROUP BY to deduplicate before INSERT | When source may send duplicates |
| **Transactional write** | Write output atomically with a checkpoint/watermark update | When pipeline state must be consistent with output |

### Why It Matters

Without idempotency, any pipeline retry, backfill, or reprocessing creates duplicates or corrupts data. Every pipeline will eventually need to be rerun -- infrastructure failures, source data corrections, logic changes requiring backfill.

## Schema Evolution Strategies

### Backward Compatibility

New schema can read data written with the old schema. Adding optional columns is backward-compatible; removing columns or changing types is not.

### Forward Compatibility

Old schema can read data written with the new schema. Readers ignore unknown fields. Requires schema-on-read or flexible deserialization.

### Schema Registry

A centralized registry (Confluent Schema Registry, AWS Glue Schema Registry) that enforces compatibility rules on schema changes. Producers must register schemas; consumers look up schemas by ID.

- **Use with**: Kafka (Avro, Protobuf, JSON Schema), Spark streaming, any event-driven pipeline
- **Compatibility modes**: BACKWARD (consumers upgraded first), FORWARD (producers upgraded first), FULL (both), NONE (no enforcement)

### Practical Strategies

1. **Additive-only changes** -- Only add columns, never remove or rename. Downstream handles NULLs for new columns.
2. **Staging layer absorbs changes** -- Raw/staging tables use schema-on-read (Parquet with schema merging, JSON columns). Transformation layer maps to a stable target schema.
3. **Version-stamped schemas** -- Include schema version in the payload. Transformation logic branches on version.
4. **Data contracts** -- Formal agreements between producers and consumers on schema, semantics, and SLAs. Breaking changes require contract negotiation.

## Data Lineage and Observability

### Lineage

Tracking data from source to target: which tables, columns, and transformations produced a given metric.

- **Column-level lineage**: dbt exposes column-level lineage through `ref()` and `source()`. Spark plans reveal column dependencies.
- **Table-level lineage**: Airflow task dependencies, ADF pipeline activities, dbt DAG visualization.
- **Cross-system lineage**: OpenLineage standard, Marquez, Atlan, Collibra for end-to-end tracking.

### Observability

Monitoring pipeline health beyond "did it succeed":

- **Freshness**: When was the target table last updated? Alert if stale beyond SLA.
- **Volume**: How many rows were processed? Alert on anomalous drops or spikes.
- **Schema**: Did the source schema change? Alert on unexpected columns or type changes.
- **Distribution**: Has the statistical distribution of key columns shifted? Alert on anomalies.
- **Tools**: dbt tests, Great Expectations, Monte Carlo, Soda, elementary-data, custom SQL checks.

## Partitioning Strategies for Large Datasets

### Time-Based Partitioning

Partition by date (day, month, year). The most common strategy for fact tables and event logs.

- **Pros**: Aligns with typical query patterns (WHERE date BETWEEN), efficient pruning, natural for incremental loads
- **Cons**: Skewed if traffic varies by day, hot partition for current day

### Key-Based Partitioning

Partition by a business key (customer_id, region, tenant_id).

- **Pros**: Even distribution if key has high cardinality, aligns with access patterns (multi-tenant queries)
- **Cons**: Skew risk if key distribution is uneven, harder to prune for time-range queries

### Composite Partitioning

Combine time and key partitioning (e.g., partition by month, sub-partition by region).

- **Pros**: Efficient for queries filtering on both dimensions
- **Cons**: Partition explosion if both dimensions have high cardinality

### Alignment Principle

Source extraction partitioning, storage partitioning, and query partitioning should align. If you extract by date, store by date, and most queries filter by date, every layer benefits. Misalignment (extract by date, store by customer) means reprocessing requires scanning all customer partitions for a given date.

## Error Handling Patterns

### Dead Letter Queues / Tables

Route failed records to a separate table/queue instead of failing the entire batch. Process the dead letter table separately (manual review, automated retry with relaxed rules).

- **When**: Record-level failures (parsing errors, constraint violations) should not block valid records.
- **Implementation**: TRY_CAST/TRY_PARSE for type conversion, conditional routing in NiFi/ADF, Kafka dead letter topic.

### Retry with Backoff

Automatically retry transient failures (network timeouts, throttling) with exponential backoff.

- **When**: Source API rate limiting, cloud service transient errors, network instability.
- **Implementation**: Airflow retry/retry_delay, ADF retry policy, Kafka producer retries.

### Circuit Breaker

Stop processing when error rate exceeds a threshold. Prevent cascading failures from propagating bad data downstream.

- **When**: Source system is returning corrupt data, transformation logic has a bug affecting many records.
- **Implementation**: dbt `--fail-fast`, Airflow `trigger_rule`, custom error rate checks in pipeline code.

### Compensation / Rollback

Undo partial writes when a pipeline fails mid-execution. Restore the target to its pre-execution state.

- **When**: Atomic batch loads where partial data is worse than no data.
- **Implementation**: Database transactions, staging + swap patterns, Spark write-ahead logs, savepoints.
