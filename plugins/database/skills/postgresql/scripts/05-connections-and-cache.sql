-- Purpose:        Connection saturation by state and database-wide cache hit ratio - capacity vitals in one pass
-- Applies to:     PostgreSQL 14+
-- Read-only:      yes
-- Inputs:         none
-- Interpretation: total connections near max_connections = incidents on the next spike; the fix is pooling (pgbouncer),
--                 not raising the limit. A large 'idle' herd is normal with pools; a large 'idle in transaction' herd
--                 is an app bug (see 01). Cache hit ratio under ~99% for OLTP = shared_buffers too small for the
--                 working set or scan-heavy queries evicting it (02 shows which).
-- Next step:      Add/resize the pooler for connection pressure; revisit shared_buffers and the top queries for cache misses

-- Result set 1: connection states vs limit
SELECT
    (SELECT setting::int FROM pg_settings WHERE name = 'max_connections') AS max_connections,
    COUNT(*)                                                              AS total,
    COUNT(*) FILTER (WHERE state = 'active')                              AS active,
    COUNT(*) FILTER (WHERE state = 'idle')                                AS idle,
    COUNT(*) FILTER (WHERE state = 'idle in transaction')                 AS idle_in_xact
FROM pg_stat_activity;

-- Result set 2: cache hit ratio per database
SELECT
    datname,
    ROUND(100.0 * blks_hit / NULLIF(blks_hit + blks_read, 0), 2) AS cache_hit_pct,
    numbackends,
    xact_commit,
    xact_rollback,
    deadlocks,
    temp_files,
    pg_size_pretty(temp_bytes) AS temp_spill
FROM pg_stat_database
WHERE datname NOT LIKE 'template%'
ORDER BY blks_read DESC;
