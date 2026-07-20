# Druid Troubleshooting

## Troubleshooting Playbooks

### Ingestion Lag (Kafka/Kinesis)

**Symptom:** Supervisor reports increasing lag, data is delayed.

**Diagnostic:**
```sql
SELECT * FROM sys.supervisors;
```
```
GET /druid/indexer/v1/supervisor/<supervisorId>/stats
```

**Resolution:**
1. **Check task count** -- Increase `taskCount` in supervisor spec to parallelize consumption
2. **Check task duration** -- Reduce `taskDuration` (e.g., PT30M) for faster handoff
3. **Check persist settings** -- Increase `maxRowsInMemory` or reduce `intermediatePersistPeriod` to avoid excessive disk I/O
4. **Check consumer lag** -- Verify Kafka/Kinesis throughput matches task capacity
5. **Check segment handoff** -- If Historical nodes are slow to load, check deep storage write speed and Coordinator load queue
6. **Scale MiddleManagers** -- Add capacity if CPU/memory is saturated on ingestion nodes

### Segment Unavailable

**Symptom:** Queries return partial results or "segment not found" errors.

**Diagnostic:**
```sql
SELECT datasource, is_published, is_available, is_realtime, is_overshadowed, COUNT(*) AS cnt
FROM sys.segments
GROUP BY 1, 2, 3, 4, 5;
```
```
GET /druid/coordinator/v1/loadstatus?simple
GET /druid/coordinator/v1/loadqueue?simple
```

**Resolution:**
1. **Check Coordinator logs** -- Look for "unable to assign segment" messages
2. **Check Historical capacity** -- `maxSize` may be reached; add nodes or increase disk
3. **Check deep storage** -- Segments may be missing from S3/HDFS; verify paths
4. **Check load rules** -- Ensure retention rules include the time range and replica count
5. **Check metadata store** -- Verify segments are marked as `used=1` in the `druid_segments` table
6. **Force load** -- `POST /druid/coordinator/v1/datasources/<ds>/segments/<segmentId>`

### Query Timeout

**Symptom:** Queries fail with timeout or take excessively long.

**Diagnostic:**
```sql
SELECT * FROM sys.segments
WHERE datasource = 'events'
  AND is_available = 1
ORDER BY num_rows DESC;
```

**Resolution:**
1. **Check segment sizes** -- Segments with >10M rows need compaction
2. **Add query filters** -- Always filter on `__time` to limit segment scan range
3. **Use appropriate query type** -- Timeseries/TopN instead of GroupBy when possible
4. **Increase timeout** -- `druid.server.http.defaultQueryTimeout` (but fix root cause)
5. **Scale Broker/Historical** -- Add nodes for query parallelism
6. **Enable caching** -- Configure Broker and Historical cache for repeated queries
7. **Check for excessive subqueries** -- Druid SQL can generate subqueries; use EXPLAIN PLAN

### Out of Memory (OOM)

**Symptom:** Historical or Broker JVM crashes with OutOfMemoryError.

**Resolution:**
1. **Increase JVM heap** -- Historical: 50% of RAM for heap, 50% for direct memory + OS cache
2. **Tune processing buffers** -- `druid.processing.buffer.sizeBytes` and `druid.processing.numThreads`
3. **Limit concurrent queries** -- `druid.server.http.numThreads`
4. **Reduce groupBy memory** -- `druid.query.groupBy.maxOnDiskStorage` to spill to disk
5. **Check segment sizes** -- Oversized segments consume more memory during query processing
6. **Monitor JVM** -- Enable GC logging, use `-XX:+HeapDumpOnOutOfMemoryError`

**Memory formula for Historical:**
```
Total RAM = JVM Heap + Direct Memory + OS page cache reserve
JVM Heap = 50% of RAM (max ~24GB recommended)
Direct Memory = processing.buffer.sizeBytes * (processing.numThreads + 1)
OS Page Cache = remaining RAM (caches segment data)
```

### Compaction Debt

**Symptom:** Increasing number of small segments, degraded query performance.

**Diagnostic:**
```sql
SELECT datasource, COUNT(*) AS segments,
  AVG(num_rows) AS avg_rows, MIN(num_rows) AS min_rows
FROM sys.segments
WHERE is_published = 1 AND is_overshadowed = 0
GROUP BY 1
ORDER BY segments DESC;
```
```
GET /druid/coordinator/v1/compaction/status
```

**Resolution:**
1. **Configure auto-compaction** -- Set up compaction config per datasource
2. **Increase compaction slots** -- `druid.coordinator.compaction.maxCompactionTaskSlots`
3. **Use MSQ compaction** -- Set `engine: msq` for faster compaction (31+)
4. **Adjust skip offset** -- `skipOffsetFromLatest` to compact closer to real-time data
5. **Tune partition spec** -- Use hash or range partitioning for perfect rollup
6. **Monitor** -- Track compaction status via REST API and Coordinator console
