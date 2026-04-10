# Apache Spark ETL Best Practices

## Partition Strategies

### Optimal Partition Sizing
- Target **128-256 MB** per partition (sweet spot for most workloads)
- Aim for **2-3 tasks per CPU core** in the cluster
- Formula: For a cluster with N nodes, C cores each → target N × C × 2 to N × C × 3 partitions
- Example: 10 nodes × 4 cores = 40 cores → target 80-120 partitions

### repartition() vs coalesce()
| Operation | Behavior | Shuffle? | Use Case |
|-----------|----------|----------|----------|
| `repartition(N)` | Creates exactly N partitions, redistributes data evenly | Yes (full shuffle) | Increasing partitions, fixing skew, before writes |
| `repartition(col)` | Partitions by column values | Yes (full shuffle) | Co-locating data by key before joins/writes |
| `coalesce(N)` | Reduces partitions by merging adjacent ones | No (narrow dependency) | Reducing partitions after filter, before small writes |

**Rules of thumb:**
- Use `coalesce()` when reducing partitions (it avoids a shuffle)
- Use `repartition()` when increasing partitions or when you need even distribution
- Never `coalesce(1)` on large datasets -- use `repartition(1)` only for small outputs
- After heavy filtering (>50% data removed), consider `coalesce()` to consolidate

### Partition Pruning
- **Static partition pruning**: Spark skips reading partitions not matching WHERE clause filters
- **Dynamic Partition Pruning (DPP)**: Runtime filtering based on join conditions (enabled by default in Spark 3.0+)
- Design partition columns around common query predicates (date, region, etc.)
- Use Hive-style partitioning (`df.write.partitionBy("year", "month")`) for large tables
- Avoid high-cardinality partition columns (>10,000 distinct values creates too many small files)

---

## Join Optimization

### Join Types by Strategy

| Strategy | When Used | Requirements | Performance |
|----------|-----------|--------------|-------------|
| **Broadcast Hash Join** | One side < 10MB (default threshold) | Equi-join, fits in memory | Fastest (no shuffle) |
| **Sort-Merge Join** | Both sides large | Equi-join, sortable keys | Default for large data |
| **Shuffle Hash Join** | Medium-sized tables | Equi-join, one side fits in memory after shuffle | Faster than sort-merge (no sort) |
| **Broadcast Nested Loop** | Non-equi join, one side small | Any join type | Slow but flexible |
| **Cartesian Product** | Cross join | No join condition | Very slow, avoid |

### Broadcast Join Best Practices
```python
from pyspark.sql.functions import broadcast

# Explicit broadcast hint (overrides threshold)
result = large_df.join(broadcast(small_df), "key")

# Configure threshold (default 10MB)
spark.conf.set("spark.sql.autoBroadcastJoinThreshold", "50m")  # Increase to 50MB

# Disable auto-broadcast
spark.conf.set("spark.sql.autoBroadcastJoinThreshold", "-1")
```
- Broadcast the smaller table in dimension-fact joins
- Be cautious: broadcasting too-large DataFrames causes OOM on the driver
- AQE can dynamically convert sort-merge to broadcast if runtime size is small enough

### Sort-Merge Join Optimization
- Pre-sort and bucket data on join keys to avoid shuffle at join time
- Use bucketing: `df.write.bucketBy(N, "key").saveAsTable("bucketed_table")`
- Bucketed tables skip shuffle if bucket counts match and join keys align

### Join Hints (Spark 3.0+)
```sql
-- SQL hints
SELECT /*+ BROADCAST(small_table) */ * FROM large_table JOIN small_table ON ...
SELECT /*+ MERGE(t1) */ * FROM t1 JOIN t2 ON ...
SELECT /*+ SHUFFLE_HASH(t1) */ * FROM t1 JOIN t2 ON ...
```

---

## Data Skew Handling

### Detecting Skew
- **Spark UI**: Look for tasks with significantly longer duration than others in a stage
- **Metrics**: Check task input sizes -- large variance indicates skew
- **Code**: `df.groupBy("key").count().orderBy(desc("count"))` to find hot keys

### Adaptive Skew Join (AQE -- Zero Code Changes)
```python
# Enabled by default in Spark 3.2+
spark.conf.set("spark.sql.adaptive.enabled", "true")
spark.conf.set("spark.sql.adaptive.skewJoin.enabled", "true")
spark.conf.set("spark.sql.adaptive.skewJoin.skewedPartitionFactor", "5")  # default
spark.conf.set("spark.sql.adaptive.skewJoin.skewedPartitionThresholdInBytes", "256m")  # default
```
- AQE detects skewed partitions at runtime and splits them
- Replicates the non-skewed side to match split partitions
- Works for sort-merge and shuffle-hash joins
- **Try AQE first** before manual interventions

### Manual Salting Technique
```python
from pyspark.sql.functions import col, lit, explode, array, rand

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

### Asymmetric Salting
- Only decompose (explode) the heavy side
- Replicate the light side with matching salt values
- Useful when skew is caused by data volume per key, not just key frequency

### Other Skew Mitigation
- **Isolate hot keys**: Process hot keys separately with broadcast join, remaining keys with sort-merge
- **Pre-aggregate**: Reduce data volume before joins with partial aggregations
- **Repartition**: `repartition(N, col("key"))` to redistribute before operations

---

## Caching and Persistence

### Storage Levels

| Level | Space | CPU | In Memory | On Disk | Serialized | Replication |
|-------|-------|-----|-----------|---------|------------|-------------|
| `MEMORY_ONLY` | High | Low | Yes | No | No | 1 |
| `MEMORY_ONLY_SER` | Low | High | Yes | No | Yes | 1 |
| `MEMORY_AND_DISK` | High | Medium | Yes | Spillover | No | 1 |
| `MEMORY_AND_DISK_SER` | Low | High | Yes | Spillover | Yes | 1 |
| `DISK_ONLY` | Low | High | No | Yes | Yes | 1 |
| `*_2` variants | 2× | Same | Same | Same | Same | 2 |

### When to Cache
- DataFrame used **multiple times** in the same job (reused across actions)
- Expensive computations (complex joins, aggregations) that feed multiple downstream operations
- Lookup/dimension tables used in repeated joins
- **Do NOT cache**: DataFrames used only once, very large datasets that don't fit in memory, streaming DataFrames

### Caching Best Practices
```python
# cache() = persist(StorageLevel.MEMORY_AND_DISK) in PySpark
# cache() = persist(StorageLevel.MEMORY_ONLY) in Scala/Java
df.cache()  # Lazy -- materialized on first action

# Explicit persistence level
from pyspark import StorageLevel
df.persist(StorageLevel.MEMORY_AND_DISK_SER)  # Serialized, spills to disk

# IMPORTANT: unpersist when done
df.unpersist()

# Force materialization
df.cache().count()  # count() triggers caching
```

- Always `unpersist()` when cached data is no longer needed
- Monitor cache usage in Spark UI > Storage tab
- Use `MEMORY_AND_DISK` for safety (avoids recomputation if evicted)
- Use `MEMORY_ONLY_SER` when memory is constrained (serialized data uses less space)

---

## UDF Performance

### Performance Hierarchy (Fastest to Slowest)
1. **Built-in functions** (`pyspark.sql.functions.*`) -- always prefer these
2. **SQL expressions** -- optimized by Catalyst
3. **Pandas UDFs (vectorized)** -- 10-100× faster than Python UDFs
4. **Python UDFs** -- avoid in production if possible

### Why Python UDFs Are Slow
- Data serialized from JVM → Python process → JVM for each row
- Breaks Catalyst optimization pipeline (opaque to optimizer)
- Cannot benefit from Tungsten/whole-stage codegen
- Per-row processing, no vectorization

### Pandas UDFs (Vectorized UDFs)
```python
import pandas as pd
from pyspark.sql.functions import pandas_udf
from pyspark.sql.types import DoubleType

# Series to Series (most common)
@pandas_udf(DoubleType())
def multiply_by_two(s: pd.Series) -> pd.Series:
    return s * 2

df.select(multiply_by_two(col("value")))

# Grouped Map
@pandas_udf(schema, PandasUDFType.GROUPED_MAP)
def normalize(pdf: pd.DataFrame) -> pd.DataFrame:
    pdf["value"] = (pdf["value"] - pdf["value"].mean()) / pdf["value"].std()
    return pdf

df.groupBy("group").apply(normalize)
```

### How Arrow Vectorization Works
- Spark converts data to Apache Arrow columnar format
- Splits into batches, transfers to Python workers as Arrow structures
- Python processes using pandas/NumPy (vectorized, SIMD-optimized)
- Results returned via same Arrow pathway
- Zero-copy shared memory model between JVM and Python

### Spark 4.0+ UDF Improvements
- Arrow-native UDF decorators in Spark 4.1 (eliminates Pandas overhead)
- Python UDTFs (User-Defined Table Functions) with partition-by semantics
- Python Data Source API for custom connectors

---

## Resource Sizing

### Executor Configuration Formula

**Cores per executor:**
- Recommended: **5 cores per executor** (optimal for HDFS I/O throughput)
- More than 5 cores degrades HDFS write performance
- Minimum: 2 cores (1 core leaves no room for concurrent tasks)

**Number of executors per node:**
```
executors_per_node = (total_node_cores - 1) / cores_per_executor
# Reserve 1 core per node for OS/YARN/Hadoop daemons
```

**Memory per executor:**
```
memory_per_executor = (total_node_memory - OS_reserve) / (executors_per_node + 1)
# +1 accounts for YARN Application Manager
# OS_reserve: typically 1-2 GB

# Overhead (additional non-heap memory)
overhead = max(384MB, 0.10 * executor_memory)
# For PySpark: consider 0.20 * executor_memory
```

**Example calculation (10-node cluster, 16 cores/128GB per node):**
```
Cores per executor: 5
Executors per node: (16 - 1) / 5 = 3
Total executors: 10 × 3 - 1 (for AM) = 29
Memory per executor: (128GB - 1GB) / (3 + 1) ≈ 31GB → use 30GB
Overhead: max(384MB, 3GB) = 3GB
Total per executor: 30GB heap + 3GB overhead = 33GB
```

### Dynamic Allocation
```python
spark.conf.set("spark.dynamicAllocation.enabled", "true")
spark.conf.set("spark.dynamicAllocation.minExecutors", "2")
spark.conf.set("spark.dynamicAllocation.maxExecutors", "100")
spark.conf.set("spark.dynamicAllocation.executorIdleTimeout", "60s")
spark.conf.set("spark.dynamicAllocation.schedulerBacklogTimeout", "1s")
```
- Automatically scales executors up/down based on workload
- Requires external shuffle service (or shuffle tracking in Spark 3.0+)
- Essential for cost optimization in cloud environments

---

## Pipeline Patterns

### Medallion Architecture
```
Bronze (Raw) → Silver (Cleaned) → Gold (Business)
```

**Bronze Layer:**
- Raw data ingestion, exactly as received
- Partition by ingestion date and source system
- Immutable, append-only (audit trail)
- Schema-on-read; accept all data even if messy
- Format: Delta Lake / Iceberg with VARIANT columns for semi-structured data

**Silver Layer:**
- Cleaned, filtered, deduplicated, validated
- Schema enforcement and evolution
- Joins with reference data
- Data quality checks at entry
- SCD (Slowly Changing Dimension) processing
- Format: Delta Lake / Iceberg with typed columns

**Gold Layer:**
- Business-specific aggregations and denormalized views
- Optimized for query performance (pre-aggregated, pre-joined)
- Serves BI dashboards, ML feature stores, APIs
- Often star/snowflake schema

### Incremental Processing
```python
# Delta Lake incremental reads
df = spark.readStream.format("delta").load("/bronze/events")

# Merge (upsert) pattern
from delta.tables import DeltaTable
delta_table = DeltaTable.forPath(spark, "/silver/customers")
delta_table.alias("target").merge(
    updates_df.alias("source"),
    "target.id = source.id"
).whenMatchedUpdateAll().whenNotMatchedInsertAll().execute()

# Auto Loader (Databricks) / file-based incremental
df = spark.readStream.format("cloudFiles") \
    .option("cloudFiles.format", "json") \
    .load("/landing/events/")
```

### CDC (Change Data Capture) Pattern
- Capture database changes via Debezium or native CDC connectors into Kafka
- Ingest CDC events into Bronze layer
- Apply MERGE operations in Silver layer to maintain current state
- Use Delta Lake MERGE INTO for idempotent upserts

### Idempotent Writes
- Use MERGE INTO with primary keys for safe reprocessing
- Design pipelines to be re-runnable without duplicates
- Track watermarks/offsets for incremental processing
- Use `foreachBatch` in Structured Streaming for custom exactly-once logic

---

## Testing Spark Applications

### Frameworks and Libraries

**Built-in (Spark 4.1+):**
```python
from pyspark.testing.utils import assertDataFrameEqual, assertSchemaEqual

# DataFrame equality
assertDataFrameEqual(actual_df, expected_df)

# Schema equality
assertSchemaEqual(actual_df.schema, expected_schema)
```

**Chispa (PySpark -- 2.5M+ monthly downloads):**
```python
# pip install chispa
from chispa import assert_df_equality, assert_column_equality

assert_df_equality(actual_df, expected_df, ignore_nullable=True)
assert_column_equality(df, "actual_col", "expected_col")
```
- Descriptive error messages highlighting exactly which rows differ
- v0.11.1 (as of 2025)

**spark-fast-tests (Scala):**
```scala
import com.github.mrpowers.spark.fast.tests.DataFrameComparer
assertSmallDataFrameEquality(actualDF, expectedDF)
```

### Testing Best Practices
- **Modularize transformations**: Extract logic into pure functions that take/return DataFrames
- **Use local mode** for unit tests: `SparkSession.builder.master("local[2]").getOrCreate()`
- **Small test data**: Create test DataFrames with `spark.createDataFrame()`, not files
- **Test schema separately**: Validate schema before testing data content
- **Integration tests**: Test with representative data volumes, actual file formats, external systems
- **Property-based testing**: Use Hypothesis or ScalaCheck for generating edge cases

### Test Structure
```python
import pytest
from pyspark.sql import SparkSession

@pytest.fixture(scope="session")
def spark():
    return SparkSession.builder \
        .master("local[2]") \
        .appName("tests") \
        .getOrCreate()

def test_dedup_logic(spark):
    input_data = [(1, "a"), (1, "a"), (2, "b")]
    input_df = spark.createDataFrame(input_data, ["id", "value"])
    
    result = dedup_transform(input_df)
    
    expected_data = [(1, "a"), (2, "b")]
    expected_df = spark.createDataFrame(expected_data, ["id", "value"])
    assertDataFrameEqual(result, expected_df)
```

---

## Cost Optimization Strategies

### Compute Cost Reduction
- **Spot/Preemptible instances**: Up to 70-90% savings for executor nodes
  - Run drivers on On-Demand instances for stability
  - Run executors on Spot instances (replaceable workers)
  - Use multiple instance types/pools for availability
  - Enable graceful decommissioning for Spot interruptions
- **Auto-scaling**: EMR Managed Scaling, Kubernetes Cluster Autoscaler, or Spark dynamic allocation
  - EMR Managed Scaling: ~60% cost reduction vs fixed clusters
- **Right-sizing**: Avoid over-provisioned clusters; monitor utilization
- **Serverless**: EMR Serverless, Databricks Serverless (pay only for compute used)

### Storage Cost Reduction
- Use **columnar formats** (Parquet/ORC) instead of JSON/CSV (5-10× compression)
- **Partition pruning**: Design partitions to skip irrelevant data
- **Z-ordering / Liquid Clustering**: Optimize data layout for common query patterns
- **Compaction**: Compact small files periodically (Delta OPTIMIZE, Iceberg rewrite_data_files)
- **Data lifecycle**: Archive or delete old data; use cloud storage tiers (S3 IA, Glacier)

### Processing Cost Reduction
- **Enable AQE**: Free optimization, 20-40% improvement on skewed workloads
- **Broadcast joins**: Avoid shuffles for small dimension tables
- **Filter early**: Push filters as close to source as possible (predicate pushdown)
- **Select only needed columns**: Column pruning reduces I/O
- **Cache wisely**: Cache only reused DataFrames, unpersist when done
- **Avoid Python UDFs**: Use built-in functions or Pandas UDFs
- **Incremental processing**: Process only new/changed data, not full reloads

### Monitoring for Cost
- Track **cluster utilization**: CPU, memory, I/O per executor
- Monitor **shuffle data size**: Large shuffles indicate optimization opportunities
- Review **task duration distribution**: Skew wastes resources on idle executors
- Set budgets and alerts on cloud provider dashboards
