-- Purpose:        Dead-tuple pressure and vacuum recency per table - find bloat before it becomes seq-scan misery
-- Applies to:     PostgreSQL 14+
-- Read-only:      yes
-- Inputs:         none
-- Interpretation: dead_pct over ~10-20% on a large, hot table = autovacuum is losing (long transactions holding back
--                 the xmin horizon, or cost limits too low for the write rate). last_autovacuum NULL or days old on a
--                 churning table confirms it. Fix causes first (idle-in-transaction sessions from 01), then tune
--                 per-table autovacuum settings; VACUUM FULL is an outage-class last resort (exclusive lock, rewrite).
-- Next step:      Check 01-activity-and-blocking.sql for old transactions pinning xmin; tune autovacuum_vacuum_scale_factor per table

SELECT
    schemaname,
    relname,
    n_live_tup,
    n_dead_tup,
    ROUND(100.0 * n_dead_tup / NULLIF(n_live_tup + n_dead_tup, 0), 1) AS dead_pct,
    last_vacuum,
    last_autovacuum,
    last_autoanalyze,
    pg_size_pretty(pg_total_relation_size(relid)) AS total_size
FROM pg_stat_user_tables
WHERE n_live_tup + n_dead_tup > 10000
ORDER BY n_dead_tup DESC
LIMIT 30
