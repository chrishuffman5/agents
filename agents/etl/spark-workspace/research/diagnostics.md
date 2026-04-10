# Apache Spark Diagnostics and Troubleshooting

## Spark UI

The Spark UI is a web-based dashboard (default: port 4040) providing real-time and historical insights into running Spark applications.

### Jobs Tab
- Shows all jobs triggered by actions (collect, save, count, etc.)
- Each job maps to one action in your code
- Key metrics: duration, number of stages, status (succeeded/failed/running)
- **Diagnosis**: Identify which jobs are slowest; drill into their stages

### Stages Tab
- Shows all stages across all jobs
- Each stage = a set of tasks separated by shuffle boundaries
- Key metrics per stage:
  - **Duration**: Wall-clock time for the stage
  - **Input/Output size**: Data read/written
  - **Shuffle Read/Write**: Data moved between executors
  - **Tasks**: Number of tasks, success/failure count
- **Task detail view**: Shows per-task metrics (duration, GC time, shuffle spill, input size)
- **Diagnosis**: Look for stages with high shuffle write/read, long GC time, or task skew

### Storage Tab
- Shows cached/persisted RDDs and DataFrames
- Metrics: storage level, size in memory, size on disk, partitions cached
- **Diagnosis**: Verify caching is working; check if cached data is being evicted

### Environment Tab
- Shows all Spark configuration properties, JVM info, classpath
- **Diagnosis**: Verify configuration values are set correctly (especially for debugging misconfigurations)

### SQL Tab
- Shows executed SQL queries and DataFrame operations
- Displays logical and physical execution plans as visual DAGs
- Key metrics: duration, associated jobs, number of rows processed per operator
- **Diagnosis**: Most important tab for ETL performance. Examine physical plans for:
  - Exchange nodes (shuffles) -- minimize these
  - BroadcastHashJoin vs SortMergeJoin -- verify correct join strategy
  - Filter pushdown -- verify filters appear close to Scan nodes
  - WholeStageCodegen -- verify operators are fused

### Executors Tab
- Per-executor resource usage: memory, disk, cores, tasks completed
- GC time, shuffle read/write, input/output
- **Diagnosis**: Identify overloaded or underutilized executors

---

## Common Errors and Solutions

### OutOfMemoryError (OOM)

**Driver OOM:**
```
java.lang.OutOfMemoryError: Java heap space (driver)
```
- **Cause**: `collect()` on large dataset, large broadcast variable, too many partitions tracked
- **Fix**:
  - Increase `spark.driver.memory` (e.g., 4g → 8g)
  - Avoid `collect()` on large data -- use `take(N)` or write to storage
  - Increase `spark.driver.maxResultSize` if collecting large results
  - Reduce broadcast table size or use sort-merge join instead

**Executor OOM:**
```
java.lang.OutOfMemoryError: Java heap space
ExecutorLostFailure (executor N exited caused by one of the running tasks)
Container killed by YARN for exceeding memory limits. X.X GB of physical memory used.
```
- **Cause**: Data skew, too few partitions, large shuffle blocks, memory-intensive operations
- **Fix**:
  - Increase `spark.executor.memory`
  - Increase `spark.executor.memoryOverhead` (especially for PySpark)
  - Increase `spark.sql.shuffle.partitions` (reduce per-partition data size)
  - Enable AQE for automatic partition coalescing and skew handling
  - Check for data skew and apply salting or broadcast join

**Off-Heap OOM:**
```
java.lang.OutOfMemoryError: Direct buffer memory
```
- **Fix**: Increase `spark.executor.memoryOverhead` or enable off-heap memory with sufficient size

### Shuffle Fetch Failures

```
org.apache.spark.shuffle.FetchFailedException: Failed to connect to host:port
org.apache.spark.shuffle.FetchFailedException: Connection reset
```

**Common Causes:**
1. **Executor crash during shuffle**: The executor writing shuffle data ran out of memory or was killed
2. **Auto-scaling event**: Cluster downsized before shuffle data was consumed
3. **Spot instance termination**: Cloud spot instance reclaimed
4. **Network issues**: Transient network failures between nodes
5. **Shuffle block > 2GB**: Integer.MAX_VALUE limit on shuffle block size

**Solutions:**
```python
# Increase shuffle partitions to reduce block size
spark.conf.set("spark.sql.shuffle.partitions", "1000")  # default 200

# Increase retry attempts
spark.conf.set("spark.shuffle.io.maxRetries", "10")  # default 3
spark.conf.set("spark.shuffle.io.retryWait", "60s")    # default 5s

# Increase task max failures
spark.conf.set("spark.task.maxFailures", "8")  # default 4

# Enable external shuffle service (for dynamic allocation)
spark.conf.set("spark.shuffle.service.enabled", "true")

# For 2GB limit: increase partitions or enable AQE
spark.conf.set("spark.sql.adaptive.enabled", "true")
```

### Data Skew Symptoms

```
Stage X contains tasks with very uneven durations:
- 95% of tasks complete in 30 seconds
- 5% of tasks take 30 minutes
```

- **Diagnosis**: Spark UI > Stages > Task detail. Sort by duration; check for outliers
- **Solutions**: See best-practices.md > Data Skew Handling

### Serialization Errors

```
org.apache.spark.SparkException: Task not serializable
java.io.NotSerializableException: com.example.MyClass
```

**Cause**: Spark cannot serialize objects referenced inside transformations

**Solutions:**
```python
# Problem: referencing non-serializable outer object
class MyProcessor:
    def __init__(self):
        self.connection = DatabaseConnection()  # not serializable
    
    def process(self, df):
        # This fails because 'self' must be serialized
        return df.rdd.map(lambda row: self.transform(row))

# Fix 1: Make the class serializable (implement Serializable in Scala/Java)
# Fix 2: Move the non-serializable object creation inside the transformation
# Fix 3: Use broadcast variables for read-only shared data
# Fix 4: Use DataFrame API instead of RDD (avoids serialization of closures)
```

### GC Pressure / Long GC Pauses

```
WARN TaskMemoryManager: Failed to allocate a page... GC overhead limit exceeded
```

- **Diagnosis**: Spark UI > Executors tab. High GC Time relative to Task Time
- **Solutions**:
  - Increase executor memory
  - Use serialized persistence (`MEMORY_ONLY_SER` instead of `MEMORY_ONLY`)
  - Enable off-heap memory: `spark.memory.offHeap.enabled=true`
  - Reduce cached data (unpersist unused DataFrames)
  - Use G1GC: `-XX:+UseG1GC -XX:G1HeapRegionSize=16m`

### Small Files Problem

```
Reading thousands of small files is extremely slow
Too many files in directory listing
```

- **Cause**: Many small output files from previous writes or frequent streaming micro-batches
- **Solutions**:
  - Compact files: Delta Lake `OPTIMIZE`, Iceberg `rewrite_data_files`
  - Coalesce before writing: `df.coalesce(target_files).write.parquet(...)`
  - Use `maxRecordsPerFile` option: `.option("maxRecordsPerFile", 1000000).write...`
  - AQE coalesces small shuffle partitions automatically

---

## Performance Tuning Configurations

### Shuffle Configuration
```python
# Number of partitions for shuffle operations (default: 200)
spark.conf.set("spark.sql.shuffle.partitions", "200")
# Rule of thumb: 2-3× number of total cores for small data, 
# increase for large data (aim for 128-256MB per partition)

# With AQE, set high and let AQE coalesce down
spark.conf.set("spark.sql.shuffle.partitions", "2000")
spark.conf.set("spark.sql.adaptive.coalescePartitions.enabled", "true")
spark.conf.set("spark.sql.adaptive.coalescePartitions.minPartitionSize", "64m")
```

### Adaptive Query Execution (AQE)
```python
# Master switch (default true since Spark 3.2)
spark.conf.set("spark.sql.adaptive.enabled", "true")

# Coalesce partitions
spark.conf.set("spark.sql.adaptive.coalescePartitions.enabled", "true")
spark.conf.set("spark.sql.adaptive.coalescePartitions.initialPartitionNum", "2000")
spark.conf.set("spark.sql.adaptive.coalescePartitions.minPartitionSize", "64m")
spark.conf.set("spark.sql.adaptive.advisoryPartitionSizeInBytes", "256m")

# Skew join
spark.conf.set("spark.sql.adaptive.skewJoin.enabled", "true")
spark.conf.set("spark.sql.adaptive.skewJoin.skewedPartitionFactor", "5")
spark.conf.set("spark.sql.adaptive.skewJoin.skewedPartitionThresholdInBytes", "256m")

# Dynamic join switching
spark.conf.set("spark.sql.adaptive.autoBroadcastJoinThreshold", "10m")
```

### Memory Configuration
```python
# Executor memory
spark.conf.set("spark.executor.memory", "8g")
spark.conf.set("spark.executor.memoryOverhead", "2g")  # For PySpark, Arrow, off-heap

# Memory fraction (default 0.6 -- 60% of heap for Spark)
spark.conf.set("spark.memory.fraction", "0.6")
spark.conf.set("spark.memory.storageFraction", "0.5")  # Within unified memory

# Off-heap memory
spark.conf.set("spark.memory.offHeap.enabled", "true")
spark.conf.set("spark.memory.offHeap.size", "4g")

# Driver memory (increase for large collects, broadcasts)
spark.conf.set("spark.driver.memory", "4g")
spark.conf.set("spark.driver.maxResultSize", "2g")
```

### Join and Broadcast
```python
# Auto broadcast threshold (default 10MB)
spark.conf.set("spark.sql.autoBroadcastJoinThreshold", "50m")

# Broadcast timeout (default 300s)
spark.conf.set("spark.sql.broadcastTimeout", "600")
```

### I/O and File Configuration
```python
# Parquet read optimizations
spark.conf.set("spark.sql.parquet.filterPushdown", "true")  # default true
spark.conf.set("spark.sql.parquet.mergeSchema", "false")     # default false, expensive
spark.conf.set("spark.sql.files.maxPartitionBytes", "128m")  # default 128MB

# Small file handling
spark.conf.set("spark.sql.files.openCostInBytes", "4m")     # default 4MB

# Speculative execution (retry slow tasks on other executors)
spark.conf.set("spark.speculation", "true")
spark.conf.set("spark.speculation.multiplier", "1.5")
spark.conf.set("spark.speculation.quantile", "0.9")
```

---

## Debugging Slow Queries

### Using explain()

```python
# Simple physical plan
df.explain()

# Extended (logical + physical plans)
df.explain(mode="extended")

# Formatted (structured, human-readable)
df.explain(mode="formatted")

# Cost-based statistics
df.explain(mode="cost")

# Generated Java code
df.explain(mode="codegen")
```

### What to Look For in Query Plans

**Exchange nodes (Shuffles):**
```
+- Exchange hashpartitioning(key, 200)    <-- SHUFFLE -- minimize these
   +- *(1) Filter (value > 100)
```
- Every `Exchange` = a shuffle operation
- Reduce by: broadcast joins, bucketing, colocating data

**Join strategies:**
```
+- BroadcastHashJoin [key], [key]         <-- GOOD for small tables
+- SortMergeJoin [key], [key]             <-- Expected for large tables
```
- Verify the right strategy is chosen
- Check if AQE converts sort-merge to broadcast at runtime

**Filter pushdown:**
```
+- *(1) Scan parquet [key, value]
         PushedFilters: [IsNotNull(key), GreaterThan(value, 100)]    <-- GOOD
```
- Filters should appear as `PushedFilters` on Scan nodes
- If filters are above the scan, pushdown may not be working

**Whole-Stage CodeGen:**
```
*(1) Project [key, value]                  <-- * = codegen enabled (GOOD)
```
- Asterisk prefix `*` indicates whole-stage codegen is active
- Operations without `*` break the codegen pipeline

**Partition pruning:**
```
PartitionFilters: [isnotnull(date), date = 2025-01-01]    <-- GOOD
```
- Verify partition filters are applied on scan

---

## Monitoring

### Spark Event Logs
```python
# Enable event logging
spark.conf.set("spark.eventLog.enabled", "true")
spark.conf.set("spark.eventLog.dir", "s3://bucket/spark-event-logs/")
spark.conf.set("spark.eventLog.compress", "true")
```
- Stores all Spark events that the UI displays
- Can be replayed in History Server after application completes

### History Server
```bash
# Start the history server
./sbin/start-history-server.sh

# Configuration
spark.history.fs.logDirectory=s3://bucket/spark-event-logs/
spark.history.ui.port=18080
```
- View completed application UIs retroactively
- Essential for post-mortem analysis of failed jobs

### Prometheus Integration (Spark 3.0+)
```python
# Enable Prometheus servlet
spark.conf.set("spark.ui.prometheus.enabled", "true")

# Metrics available at: http://<driver-host>:4040/metrics/prometheus/
# Includes: executor metrics, JVM metrics, task metrics, shuffle metrics
```

- PrometheusServlet reuses existing Spark UI port (no external JAR needed)
- Supports Prometheus service discovery in Kubernetes
- Combine with Grafana for dashboards (community dashboards available, e.g., Grafana ID 7890)

### Key Metrics to Monitor

**Executor Metrics:**
- `jvm.heap.used` / `jvm.heap.max` -- memory pressure
- `jvm.gc.time` -- GC overhead
- `executor.runTime` -- task execution time
- `executor.cpuTime` -- actual CPU usage

**Task Metrics:**
- `shuffleBytesWritten` / `shuffleBytesRead` -- shuffle volume
- `shuffleRecordsWritten` / `shuffleRecordsRead` -- shuffle records
- `memoryBytesSpilled` / `diskBytesSpilled` -- memory pressure (spill = bad)
- `resultSize` -- data returned to driver

**Streaming Metrics (Structured Streaming):**
- `inputRate` -- records per second ingested
- `processingRate` -- records per second processed
- `batchDuration` -- time per micro-batch
- `latency` -- end-to-end processing delay
- Streaming query progress available via `query.lastProgress`

---

## Common ETL Failure Patterns and Resolution

### Schema Drift
- **Symptom**: Pipeline fails with `AnalysisException: cannot resolve column`
- **Cause**: Source schema changed (new columns, type changes, removed columns)
- **Prevention**:
  - Use `mergeSchema` option with Delta/Iceberg for additive changes
  - Define explicit schemas instead of relying on inference
  - Implement schema validation at Bronze layer
  - Use VARIANT type (Spark 4.0+) for semi-structured data that changes frequently

### Data Quality Failures
- **Pattern**: Implement validation checks after each layer
  - Null checks on required fields
  - Range validation on numeric fields
  - Referential integrity checks between tables
  - Row count expectations
- **Dead Letter Queue**: Route malformed rows to quarantine table
  ```python
  good_df = df.filter(validation_conditions)
  bad_df = df.filter(~validation_conditions)
  bad_df.write.format("delta").mode("append").save("/quarantine/")
  ```

### Duplicate Processing
- **Pattern**: Use idempotent writes with MERGE INTO
  ```sql
  MERGE INTO silver.customers AS target
  USING bronze.customers_update AS source
  ON target.id = source.id
  WHEN MATCHED THEN UPDATE SET *
  WHEN NOT MATCHED THEN INSERT *
  ```

### Pipeline Retry Strategy
```python
# Configure task-level retries
spark.conf.set("spark.task.maxFailures", "8")    # default 4

# Application-level retry with exponential backoff
MAX_RETRIES = 3
for attempt in range(MAX_RETRIES):
    try:
        run_pipeline()
        break
    except Exception as e:
        if attempt == MAX_RETRIES - 1:
            raise
        wait_time = 2 ** attempt * 60  # exponential backoff
        time.sleep(wait_time)
```

### Network and Connectivity Failures
- Increase shuffle retry parameters (see Shuffle Fetch Failures above)
- Use external shuffle service for resilience to executor failures
- Enable speculative execution for stragglers
- Use checkpointing in streaming for exactly-once recovery

### Timeouts
```python
# Broadcast timeout (default 300s -- increase for large broadcasts)
spark.conf.set("spark.sql.broadcastTimeout", "600")

# Network timeout
spark.conf.set("spark.network.timeout", "600s")

# RPC timeouts
spark.conf.set("spark.rpc.askTimeout", "600s")

# Heartbeat interval (executor to driver)
spark.conf.set("spark.executor.heartbeatInterval", "60s")
```
