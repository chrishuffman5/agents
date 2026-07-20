# TimescaleDB Performance Tuning

## Performance Tuning

**PostgreSQL GUC parameters critical for TimescaleDB:**
```
# Memory (scale with available RAM)
shared_buffers = '8GB'              # 25% of RAM (standard PG guidance)
effective_cache_size = '24GB'       # 75% of RAM
work_mem = '64MB'                   # per-sort/hash operation
maintenance_work_mem = '2GB'        # for VACUUM, CREATE INDEX, compression

# Parallelism
max_parallel_workers_per_gather = 4
max_parallel_workers = 8
max_worker_processes = 16           # must be high enough for background workers

# TimescaleDB-specific
timescaledb.max_background_workers = 8
timescaledb.max_insert_batch_size = 1000

# Planner
enable_chunk_append = on            # (default) enables chunk-aware append
enable_parallel_chunk_append = on   # (default) parallel scans across chunks

# Write-ahead log (for high ingest)
wal_level = replica
max_wal_size = '4GB'
min_wal_size = '1GB'
checkpoint_completion_target = 0.9
```

**Chunk exclusion optimization:**
```sql
-- GOOD: time predicate enables chunk exclusion
SELECT * FROM sensor_data
WHERE time > NOW() - INTERVAL '1 hour' AND sensor_id = 42;

-- BAD: no time predicate, scans ALL chunks
SELECT * FROM sensor_data WHERE sensor_id = 42;

-- Verify chunk exclusion in EXPLAIN
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM sensor_data
WHERE time > NOW() - INTERVAL '1 hour';
-- Look for: "Chunks excluded: N" in the output
```
