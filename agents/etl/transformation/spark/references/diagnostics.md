# Spark Diagnostics and Troubleshooting

## Spark UI

The Spark UI (default port 4040) is the primary diagnostic tool for running applications.

### Jobs Tab
- One job per action (`collect`, `save`, `count`)
- Shows: duration, stage count, status
- Start here to identify the slowest jobs, then drill into their stages

### Stages Tab
- Stages separated by shuffle boundaries
- Key metrics per stage: duration, input/output size, shuffle read/write, task count
- **Task detail view**: per-task duration, GC time, shuffle spill, input size
- **What to look for**: stages with high shuffle write, long GC time, or extreme task duration variance (skew)

### SQL Tab
- Most important tab for ETL performance
- Shows physical execution plans as visual DAGs
- **What to look for**:
  - `Exchange` nodes = shuffles (minimize these)
  - `BroadcastHashJoin` vs `SortMergeJoin` (verify correct strategy)
  - `PushedFilters` on Scan nodes (verify predicate pushdown)
  - `*` prefix = whole-stage codegen active (operators without `*` break the codegen pipeline)
  - `PartitionFilters` on Scan (verify partition pruning)

### Storage Tab
- Shows cached/persisted DataFrames: storage level, memory/disk size, partition count
- Verify caching is working; check for eviction

### Executors Tab
- Per-executor: memory, disk, cores, tasks completed, GC time, shuffle read/write
- Identify overloaded or underutilized executors

### Environment Tab
- All Spark configuration properties, JVM info, classpath
- Verify configuration values are set correctly

## Common Errors

### OutOfMemoryError

**Driver OOM:**
```
java.lang.OutOfMemoryError: Java heap space (driver)
```
| Cause | Fix |
|---|---|
| `collect()` on large dataset | Use `take(N)` or write to storage |
| Large broadcast variable | Reduce broadcast size or use sort-merge join |
| Too many partitions tracked | Reduce partition count |
| Large result set | Increase `spark.driver.maxResultSize` |
| Insufficient driver memory | Increase `spark.driver.memory` |

**Executor OOM:**
```
java.lang.OutOfMemoryError: Java heap space
Container killed by YARN for exceeding memory limits
ExecutorLostFailure (executor N exited caused by one of the running tasks)
```
| Cause | Fix |
|---|---|
| Data skew | Enable AQE skew join, apply salting |
| Too few partitions | Increase `spark.sql.shuffle.partitions` |
| Large shuffle blocks | Increase partitions to reduce per-partition size |
| Memory-intensive UDFs | Use built-in functions or Pandas UDFs |
| Insufficient memory | Increase `spark.executor.memory` |
| PySpark overhead | Increase `spark.executor.memoryOverhead` |

**Off-Heap OOM:**
```
java.lang.OutOfMemoryError: Direct buffer memory
```
Fix: Increase `spark.executor.memoryOverhead` or configure off-heap memory with sufficient size.

### Shuffle Fetch Failures

```
org.apache.spark.shuffle.FetchFailedException
```

**Causes:** Executor crash during shuffle, auto-scaling event, Spot instance termination, network failure, shuffle block > 2GB.

**Solutions:**
```python
# Increase shuffle partitions (reduce block size)
spark.conf.set("spark.sql.shuffle.partitions", "1000")

# Increase retry attempts
spark.conf.set("spark.shuffle.io.maxRetries", "10")       # default 3
spark.conf.set("spark.shuffle.io.retryWait", "60s")        # default 5s

# Increase task failure tolerance
spark.conf.set("spark.task.maxFailures", "8")              # default 4

# Enable AQE to auto-coalesce
spark.conf.set("spark.sql.adaptive.enabled", "true")
```

### Data Skew Symptoms

```
Stage X: 95% of tasks complete in 30 seconds, 5% take 30 minutes
```

**Diagnosis:** Spark UI > Stages > Task detail. Sort by duration; large outliers = skew.

**Resolution:** See `best-practices.md` > Data Skew Handling.

### Serialization Errors

```
org.apache.spark.SparkException: Task not serializable
java.io.NotSerializableException
```

**Cause:** Non-serializable objects referenced inside transformations (closures).

**Fixes:**
1. Use DataFrame API instead of RDD (avoids closure serialization)
2. Move non-serializable object creation inside the transformation
3. Use broadcast variables for read-only shared data
4. Make the class implement Serializable (Scala/Java)

### GC Pressure

```
WARN TaskMemoryManager: Failed to allocate... GC overhead limit exceeded
```

**Diagnosis:** Spark UI > Executors tab. High GC Time relative to Task Time.

**Fixes:**
- Increase executor memory
- Use serialized persistence (`MEMORY_ONLY_SER`)
- Enable off-heap memory: `spark.memory.offHeap.enabled=true`
- Unpersist unused DataFrames
- Use G1GC: `-XX:+UseG1GC -XX:G1HeapRegionSize=16m`

### Small Files Problem

```
Thousands of small output files; slow directory listing and reads
```

**Fixes:**
- Compact: Delta `OPTIMIZE`, Iceberg `rewrite_data_files`
- Coalesce before writing: `df.coalesce(target_files).write.parquet(...)`
- Use `maxRecordsPerFile`: `.option("maxRecordsPerFile", 1000000)`
- AQE auto-coalesces small shuffle partitions

### Schema Drift

```
AnalysisException: cannot resolve column 'X' ...
```

**Prevention:**
- Define explicit schemas (don't rely on inference)
- Use `mergeSchema` with Delta/Iceberg for additive changes
- Implement schema validation at Bronze layer
- Use VARIANT type (Spark 4.0+) for semi-structured data that changes frequently

## Performance Tuning Configurations

### Shuffle

```python
# Shuffle partitions (default 200)
spark.conf.set("spark.sql.shuffle.partitions", "200")
# Rule: 2-3x total cores for small data. For large data, aim for 128-256MB per partition.

# With AQE: set high and let AQE coalesce down
spark.conf.set("spark.sql.shuffle.partitions", "2000")
spark.conf.set("spark.sql.adaptive.coalescePartitions.enabled", "true")
spark.conf.set("spark.sql.adaptive.coalescePartitions.minPartitionSize", "64m")
```

### AQE

```python
spark.conf.set("spark.sql.adaptive.enabled", "true")
spark.conf.set("spark.sql.adaptive.coalescePartitions.enabled", "true")
spark.conf.set("spark.sql.adaptive.coalescePartitions.initialPartitionNum", "2000")
spark.conf.set("spark.sql.adaptive.advisoryPartitionSizeInBytes", "256m")
spark.conf.set("spark.sql.adaptive.skewJoin.enabled", "true")
spark.conf.set("spark.sql.adaptive.skewJoin.skewedPartitionFactor", "5")
spark.conf.set("spark.sql.adaptive.skewJoin.skewedPartitionThresholdInBytes", "256m")
```

### Memory

```python
spark.conf.set("spark.executor.memory", "8g")
spark.conf.set("spark.executor.memoryOverhead", "2g")
spark.conf.set("spark.memory.fraction", "0.6")
spark.conf.set("spark.memory.storageFraction", "0.5")

# Off-heap
spark.conf.set("spark.memory.offHeap.enabled", "true")
spark.conf.set("spark.memory.offHeap.size", "4g")

# Driver
spark.conf.set("spark.driver.memory", "4g")
spark.conf.set("spark.driver.maxResultSize", "2g")
```

### Joins and Broadcast

```python
spark.conf.set("spark.sql.autoBroadcastJoinThreshold", "50m")  # default 10MB
spark.conf.set("spark.sql.broadcastTimeout", "600")             # default 300s
```

### I/O

```python
spark.conf.set("spark.sql.parquet.filterPushdown", "true")
spark.conf.set("spark.sql.parquet.mergeSchema", "false")       # expensive if true
spark.conf.set("spark.sql.files.maxPartitionBytes", "128m")

# Speculative execution (retry slow tasks on other executors)
spark.conf.set("spark.speculation", "true")
spark.conf.set("spark.speculation.multiplier", "1.5")
spark.conf.set("spark.speculation.quantile", "0.9")
```

### Timeouts

```python
spark.conf.set("spark.sql.broadcastTimeout", "600")
spark.conf.set("spark.network.timeout", "600s")
spark.conf.set("spark.rpc.askTimeout", "600s")
spark.conf.set("spark.executor.heartbeatInterval", "60s")
```

## Debugging Slow Queries

### Using explain()

```python
df.explain()                    # Physical plan
df.explain(mode="extended")     # Logical + physical
df.explain(mode="formatted")    # Structured, human-readable
df.explain(mode="cost")         # Cost-based statistics
df.explain(mode="codegen")      # Generated Java code
```

### Reading Query Plans

**Exchange nodes (shuffles):**
```
+- Exchange hashpartitioning(key, 200)    <-- SHUFFLE
```
Every `Exchange` = shuffle. Reduce via broadcast joins, bucketing, or data co-location.

**Join strategies:**
```
+- BroadcastHashJoin [key], [key]         <-- No shuffle (good for small tables)
+- SortMergeJoin [key], [key]             <-- Expected for large tables
```

**Filter pushdown:**
```
+- Scan parquet [key, value]
     PushedFilters: [IsNotNull(key), GreaterThan(value, 100)]    <-- GOOD
```
Filters should appear as `PushedFilters` on Scan nodes. Filters above the scan = pushdown not working.

**Whole-stage codegen:**
```
*(1) Project [key, value]                  <-- * = codegen active
```

**Partition pruning:**
```
PartitionFilters: [isnotnull(date), date = 2025-01-01]    <-- GOOD
```

## Monitoring

### Event Logs and History Server

```python
spark.conf.set("spark.eventLog.enabled", "true")
spark.conf.set("spark.eventLog.dir", "s3://bucket/spark-event-logs/")
spark.conf.set("spark.eventLog.compress", "true")
```

History Server replays event logs for post-mortem analysis of completed/failed applications. Start with `./sbin/start-history-server.sh`.

### Prometheus Integration (Spark 3.0+)

```python
spark.conf.set("spark.ui.prometheus.enabled", "true")
# Metrics at: http://<driver-host>:4040/metrics/prometheus/
```

Reuses existing Spark UI port. Supports Kubernetes service discovery. Combine with Grafana for dashboards.

### Key Metrics

**Executor:** `jvm.heap.used/max`, `jvm.gc.time`, `executor.runTime`, `executor.cpuTime`

**Task:** `shuffleBytesWritten/Read`, `memoryBytesSpilled`, `diskBytesSpilled` (spill = memory pressure, investigate immediately)

**Streaming:** `inputRate`, `processingRate`, `batchDuration`, `latency`. Access via `query.lastProgress`.

## ETL Failure Patterns

### Data Quality
- Implement validation after each medallion layer
- Route malformed rows to quarantine (dead letter) table:
  ```python
  good_df = df.filter(validation_conditions)
  bad_df = df.filter(~validation_conditions)
  bad_df.write.format("delta").mode("append").save("/quarantine/")
  ```

### Duplicate Processing
- Use MERGE INTO for idempotent writes
- Use `foreachBatch` in streaming for custom exactly-once logic

### Pipeline Retries
```python
spark.conf.set("spark.task.maxFailures", "8")  # default 4
```
For application-level retries, use exponential backoff and build pipelines to be re-runnable (idempotent writes, partition overwrites).
