# Spark ETL Best Practices

## Partition Strategies

### Optimal Partition Sizing
- Target **128-256 MB** per partition for most workloads
- Aim for **2-3 tasks per CPU core** in the cluster
- Formula: N nodes x C cores = total cores; target total_cores x 2 to total_cores x 3 partitions
- Example: 10 nodes x 4 cores = 40 cores --> target 80-120 partitions

### repartition() vs coalesce()

| Operation | Shuffle? | Use Case |
|---|---|---|
| `repartition(N)` | Full shuffle | Increasing partitions, fixing skew, before writes |
| `repartition(col)` | Full shuffle | Co-locating data by key before joins/writes |
| `coalesce(N)` | No (narrow) | Reducing partitions after filter, before small writes |

**Rules:**
- Use `coalesce()` when reducing partitions (avoids shuffle)
- Use `repartition()` when increasing or when even distribution is needed
- Never `coalesce(1)` on large data -- creates a single-threaded bottleneck
- After heavy filtering (>50% removed), `coalesce()` to consolidate small partitions

### Partition Pruning
- Design partition columns around common query predicates (date, region)
- Use Hive-style partitioning: `df.write.partitionBy("year", "month")`
- Avoid high-cardinality partition columns (>10,000 values = small file explosion)
- Dynamic Partition Pruning (DPP) filters at runtime based on join conditions (default since 3.0)

## Join Optimization

### Strategy Selection

| Strategy | Condition | Shuffle? | Notes |
|---|---|---|---|
| **Broadcast Hash Join** | One side < 10MB (default) | No | Fastest. Broadcasts small side to all executors |
| **Sort-Merge Join** | Both sides large | Yes | Default for large-large joins. Requires equi-join |
| **Shuffle Hash Join** | One side fits in memory post-shuffle | Yes | Faster than sort-merge (no sort step) |
| **Broadcast Nested Loop** | Non-equi join, one side small | No | Slow but handles inequality conditions |

### Broadcast Join Patterns

```python
from pyspark.sql.functions import broadcast

# Explicit broadcast hint
result = large_df.join(broadcast(small_df), "key")

# Increase threshold (default 10MB)
spark.conf.set("spark.sql.autoBroadcastJoinThreshold", "50m")

# Disable auto-broadcast (force sort-merge)
spark.conf.set("spark.sql.autoBroadcastJoinThreshold", "-1")
```

- Broadcast the smaller table in dimension-fact joins
- Be cautious: broadcasting too-large DataFrames causes driver OOM
- AQE can dynamically convert sort-merge to broadcast if runtime size qualifies

### Bucketed Joins (Shuffle-Free Large Joins)

```python
# Write bucketed tables
df.write.bucketBy(256, "customer_id").sortBy("customer_id").saveAsTable("orders_bucketed")
df2.write.bucketBy(256, "customer_id").sortBy("customer_id").saveAsTable("customers_bucketed")

# Join skips shuffle if bucket counts and keys match
orders = spark.table("orders_bucketed")
customers = spark.table("customers_bucketed")
result = orders.join(customers, "customer_id")  # no shuffle
```

### SQL Join Hints

```sql
SELECT /*+ BROADCAST(dim) */ * FROM fact JOIN dim ON fact.key = dim.key;
SELECT /*+ MERGE(t1) */ * FROM t1 JOIN t2 ON t1.key = t2.key;
SELECT /*+ SHUFFLE_HASH(t1) */ * FROM t1 JOIN t2 ON t1.key = t2.key;
```

## Data Skew Handling

### Detection
- **Spark UI**: Stages tab > sort tasks by duration. Large variance = skew
- **Metrics**: Check per-task input sizes -- one task with 10x data = skew
- **Code**: `df.groupBy("key").count().orderBy(desc("count"))` to find hot keys

### AQE Skew Join (Zero Code Changes)

```python
# Enabled by default since Spark 3.2
spark.conf.set("spark.sql.adaptive.enabled", "true")
spark.conf.set("spark.sql.adaptive.skewJoin.enabled", "true")
spark.conf.set("spark.sql.adaptive.skewJoin.skewedPartitionFactor", "5")
spark.conf.set("spark.sql.adaptive.skewJoin.skewedPartitionThresholdInBytes", "256m")
```

Always try AQE first. It detects skewed partitions at runtime, splits them, and replicates the non-skewed side. Works for sort-merge and shuffle-hash joins.

### Manual Salting

When AQE is insufficient (extreme skew, non-join operations):

```python
from pyspark.sql.functions import col, lit, concat, rand, explode, array

SALT_BUCKETS = 10

# Salt the skewed (large) side
skewed_df = skewed_df.withColumn("salt", (rand() * SALT_BUCKETS).cast("int"))
skewed_df = skewed_df.withColumn("salted_key", concat(col("key"), lit("_"), col("salt")))

# Explode the small side to match all salt values
salt_values = [lit(i) for i in range(SALT_BUCKETS)]
small_df = small_df.withColumn("salt", explode(array(*salt_values)))
small_df = small_df.withColumn("salted_key", concat(col("key"), lit("_"), col("salt")))

# Join on salted key
result = skewed_df.join(small_df, "salted_key")
```

### Isolate Hot Keys

Process hot keys separately with broadcast join, remaining keys with sort-merge:

```python
hot_keys = ["key_A", "key_B"]
hot_df = large_df.filter(col("key").isin(hot_keys))
normal_df = large_df.filter(~col("key").isin(hot_keys))

hot_result = hot_df.join(broadcast(small_df), "key")
normal_result = normal_df.join(small_df, "key")

result = hot_result.unionAll(normal_result)
```

## UDF Performance

### Performance Hierarchy (Fastest to Slowest)

1. **Built-in functions** (`pyspark.sql.functions.*`) -- Catalyst-optimized, Tungsten codegen
2. **SQL expressions** -- Optimized by Catalyst
3. **Pandas UDFs (vectorized)** -- 10-100x faster than Python UDFs, Arrow-based
4. **Arrow-native UDFs** (Spark 4.1+) -- Eliminates Pandas overhead
5. **Python UDFs** -- Avoid in production. Serialization overhead per row, opaque to optimizer

### Why Python UDFs Are Slow
- Each row serialized: JVM --> Python process --> JVM
- Breaks Catalyst optimization (opaque to optimizer)
- Cannot use Tungsten codegen
- No vectorization

### Pandas UDFs

```python
import pandas as pd
from pyspark.sql.functions import pandas_udf
from pyspark.sql.types import DoubleType

@pandas_udf(DoubleType())
def multiply_by_two(s: pd.Series) -> pd.Series:
    return s * 2

df.select(multiply_by_two(col("value")))
```

How it works: Spark converts data to Arrow columnar format, sends batches to Python, Python processes via pandas/NumPy (vectorized, SIMD), returns via Arrow. Near zero-copy between JVM and Python.

### Always Prefer Built-Ins

```python
# BAD: Python UDF
@udf(StringType())
def clean_name(name):
    return name.strip().upper() if name else None

# GOOD: Built-in functions (100x faster, Catalyst-optimized)
from pyspark.sql.functions import upper, trim
df.select(upper(trim(col("name"))))
```

## Resource Sizing

### Executor Configuration

**Cores per executor:** 5 (optimal for HDFS I/O throughput). More than 5 degrades HDFS write performance.

**Executors per node:**
```
executors_per_node = (total_node_cores - 1) / cores_per_executor
# Reserve 1 core per node for OS/YARN daemons
```

**Memory per executor:**
```
memory_per_executor = (total_node_memory - OS_reserve) / (executors_per_node + 1)
# +1 accounts for YARN Application Manager
# OS_reserve: 1-2 GB

overhead = max(384MB, 0.10 * executor_memory)
# For PySpark: consider 0.20 * executor_memory
```

**Example (10-node cluster, 16 cores / 128GB each):**
```
Cores per executor: 5
Executors per node: (16 - 1) / 5 = 3
Total executors: 10 x 3 - 1 (AM) = 29
Memory per executor: (128GB - 1GB) / 4 = ~31GB --> use 30GB
Overhead: max(384MB, 3GB) = 3GB
Total: 30GB heap + 3GB overhead = 33GB per executor
```

### Dynamic Allocation

```python
spark.conf.set("spark.dynamicAllocation.enabled", "true")
spark.conf.set("spark.dynamicAllocation.minExecutors", "2")
spark.conf.set("spark.dynamicAllocation.maxExecutors", "100")
spark.conf.set("spark.dynamicAllocation.executorIdleTimeout", "60s")
spark.conf.set("spark.dynamicAllocation.schedulerBacklogTimeout", "1s")
```

Requires external shuffle service or shuffle tracking (Spark 3.0+). Essential for cost optimization in cloud environments.

## Pipeline Patterns

### Medallion Architecture

```
Bronze (Raw) --> Silver (Cleaned) --> Gold (Business)
```

**Bronze:** Raw ingestion, partition by ingestion date and source. Append-only, schema-on-read. Use VARIANT for semi-structured data (Spark 4.0+).

**Silver:** Cleaned, deduplicated, validated. Schema enforcement and evolution. Joins with reference data. Use typed columns with data quality checks at entry.

**Gold:** Business aggregations, denormalized views, pre-joined star/snowflake schemas. Optimized for BI dashboards, ML feature stores, APIs.

### Incremental Processing

```python
# Delta Lake streaming reads
df = spark.readStream.format("delta").load("/bronze/events")

# MERGE (upsert) pattern
from delta.tables import DeltaTable
delta_table = DeltaTable.forPath(spark, "/silver/customers")
delta_table.alias("target").merge(
    updates_df.alias("source"),
    "target.id = source.id"
).whenMatchedUpdateAll().whenNotMatchedInsertAll().execute()
```

### CDC Pattern
1. Capture database changes via Debezium or native CDC into Kafka
2. Ingest CDC events into Bronze layer
3. Apply MERGE in Silver to maintain current state
4. Use `foreachBatch` in Structured Streaming for custom exactly-once logic

### Idempotent Writes
- Use MERGE INTO with primary keys for safe reprocessing
- Design pipelines to be re-runnable without duplicates
- Track watermarks/offsets for incremental processing
- Use partition-based overwrites: `.mode("overwrite").option("replaceWhere", "date = '2026-01-01'")`

## Caching Best Practices

### When to Cache
- DataFrame reused across multiple actions in the same job
- Expensive computations (complex joins, aggregations) feeding multiple downstream operations
- Lookup/dimension tables used in repeated joins

### When NOT to Cache
- DataFrames used only once (caching adds overhead for no benefit)
- Very large datasets that don't fit in memory (triggers eviction thrashing)
- Streaming DataFrames

### Cache Patterns

```python
# cache() = MEMORY_AND_DISK in PySpark, MEMORY_ONLY in Scala
df.cache()  # Lazy -- materialized on first action

# Explicit level
from pyspark import StorageLevel
df.persist(StorageLevel.MEMORY_AND_DISK_SER)  # Serialized, spills to disk

# Force materialization
df.cache().count()

# IMPORTANT: unpersist when done
df.unpersist()
```

- Always `unpersist()` when finished -- cached data consumes memory until released
- Use `MEMORY_AND_DISK` (default in PySpark) for safety
- Use `MEMORY_ONLY_SER` when memory is constrained (serialized uses less space)
- Monitor via Spark UI > Storage tab

## Testing

### Frameworks

**Built-in (Spark 4.1+):**
```python
from pyspark.testing.utils import assertDataFrameEqual, assertSchemaEqual
assertDataFrameEqual(actual_df, expected_df)
```

**Chispa (PySpark):**
```python
from chispa import assert_df_equality
assert_df_equality(actual_df, expected_df, ignore_nullable=True)
```

**spark-fast-tests (Scala):**
```scala
import com.github.mrpowers.spark.fast.tests.DataFrameComparer
assertSmallDataFrameEquality(actualDF, expectedDF)
```

### Testing Patterns

```python
import pytest
from pyspark.sql import SparkSession

@pytest.fixture(scope="session")
def spark():
    return SparkSession.builder.master("local[2]").appName("tests").getOrCreate()

def test_dedup_logic(spark):
    input_data = [(1, "a"), (1, "a"), (2, "b")]
    input_df = spark.createDataFrame(input_data, ["id", "value"])
    result = dedup_transform(input_df)
    expected = spark.createDataFrame([(1, "a"), (2, "b")], ["id", "value"])
    assertDataFrameEqual(result, expected)
```

- **Modularize transformations** as pure functions: DataFrame in, DataFrame out
- **Use local mode** for unit tests: `master("local[2]")`
- **Small test data** via `spark.createDataFrame()`, not files
- **Test schema separately** before testing data content

## Cost Optimization

### Compute
- **Spot/preemptible instances** for executors (70-90% savings). Run drivers on on-demand.
- **Dynamic allocation** to auto-scale executors
- **Right-size** clusters -- monitor utilization before adding capacity
- **Serverless** (EMR Serverless, Databricks Serverless) for intermittent workloads

### Processing
- **Enable AQE** -- free 20-40% improvement on skewed workloads
- **Broadcast joins** for small dimension tables (avoid shuffles)
- **Filter early** -- predicate pushdown reduces I/O at the source
- **Select only needed columns** -- column pruning in columnar formats (Parquet/ORC) is significant
- **Avoid Python UDFs** -- use built-ins or Pandas UDFs
- **Incremental processing** -- process only new/changed data

### Storage
- **Columnar formats** (Parquet/ORC) over JSON/CSV -- 5-10x compression
- **Compaction** -- Delta `OPTIMIZE`, Iceberg `rewrite_data_files` to eliminate small files
- **Z-ordering / Liquid Clustering** -- optimize data layout for common query patterns
- **Data lifecycle** -- archive or delete old data; use cloud storage tiers
