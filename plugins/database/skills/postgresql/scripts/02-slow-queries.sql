-- Purpose:        Top queries by total and mean time from pg_stat_statements - the statistical slow-query ranking
-- Applies to:     PostgreSQL 14+ with the pg_stat_statements extension enabled (shared_preload_libraries)
-- Read-only:      yes
-- Inputs:         none; requires pg_read_all_stats
-- Interpretation: High total_time + high calls = optimize for throughput (small win x many calls). High mean_time +
--                 low calls = the heavy analytical offender. hit_ratio well under 99% on a hot query = working set
--                 exceeds shared_buffers or a scan is flushing the cache - check the plan for seq scans (03/04).
--                 If this view is empty, the extension is not preloaded - that is finding #1.
-- Next step:      EXPLAIN (ANALYZE, BUFFERS) the top offenders; 04-index-usage.sql for the index angle

SELECT
    LEFT(query, 100)                                   AS query,
    calls,
    ROUND(total_exec_time::numeric / 1000, 1)          AS total_seconds,
    ROUND(mean_exec_time::numeric, 2)                  AS mean_ms,
    rows,
    ROUND(100.0 * shared_blks_hit /
          NULLIF(shared_blks_hit + shared_blks_read, 0), 1) AS hit_ratio_pct
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 25
