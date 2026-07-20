# Snowflake Troubleshooting Playbooks

## Slow Queries

**Diagnostic sequence:**
1. Check query profile in Snowsight (UI) or via `GET_QUERY_OPERATOR_STATS`
2. Look for: bytes spilled (local or remote), partition pruning ratio, exploding JOINs, remote storage reads

```sql
-- Find recent slow queries
SELECT query_id, query_text, warehouse_name, execution_time/1000 AS exec_sec,
       bytes_scanned, partitions_scanned, partitions_total,
       bytes_spilled_to_local_storage, bytes_spilled_to_remote_storage
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE execution_time > 60000  -- >60 seconds
  AND start_time > DATEADD(day, -1, CURRENT_TIMESTAMP())
ORDER BY execution_time DESC LIMIT 20;
```

**Common fixes:**
- Poor partition pruning: Add or adjust clustering keys on filter columns
- Spilling: Size up the warehouse or reduce intermediate result sizes
- Full table scans: Add WHERE predicates that align with clustering
- Cartesian JOINs: Fix JOIN conditions or add filters to reduce row counts before JOIN

## Warehouse Queueing

**Symptom:** Queries waiting in queue, high latency.

```sql
SELECT query_id, query_text, warehouse_name, queued_overload_time/1000 AS queue_sec,
       execution_time/1000 AS exec_sec
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE queued_overload_time > 5000
  AND start_time > DATEADD(day, -1, CURRENT_TIMESTAMP())
ORDER BY queued_overload_time DESC;
```

**Resolution:**
1. Enable multi-cluster warehouses (Enterprise+) and increase MAX_CLUSTER_COUNT
2. Use STANDARD scaling policy for latency-sensitive workloads
3. Separate workloads into dedicated warehouses
4. Optimize expensive queries that block resources

## Credit Spikes

```sql
-- Identify warehouses consuming the most credits
SELECT warehouse_name, SUM(credits_used) AS total_credits
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE start_time > DATEADD(day, -7, CURRENT_TIMESTAMP())
GROUP BY warehouse_name ORDER BY total_credits DESC;

-- Find users driving the most compute
SELECT user_name, warehouse_name, COUNT(*) AS query_count,
       SUM(execution_time)/1000 AS total_exec_sec
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time > DATEADD(day, -7, CURRENT_TIMESTAMP())
GROUP BY user_name, warehouse_name ORDER BY total_exec_sec DESC;
```

**Resolution:** Set resource monitors, review auto-suspend settings, right-size warehouses, identify and optimize expensive recurring queries.

## Data Loading Failures

```sql
-- Check Snowpipe errors
SELECT * FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
    TABLE_NAME => 'target_table',
    START_TIME => DATEADD(hours, -24, CURRENT_TIMESTAMP())
)) WHERE status = 'LOAD_FAILED';

-- Validate file before loading
COPY INTO target_table FROM @my_stage
  VALIDATION_MODE = 'RETURN_ERRORS';

-- Check Snowpipe status
SELECT SYSTEM$PIPE_STATUS('my_pipe');
```

**Common causes:** Schema mismatch, corrupt files, encoding issues, insufficient permissions on stage, exhausted file format options.
