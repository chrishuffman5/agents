-- Purpose:        Unused indexes (write overhead, zero reads) and seq-scan-heavy tables (missing-index candidates)
-- Applies to:     PostgreSQL 14+
-- Read-only:      yes
-- Inputs:         none; stats accumulate since last reset - check stats_reset before trusting "unused"
-- Interpretation: Result set 1: idx_scan = 0 indexes burn write throughput and space for nothing - but verify they do
--                 not back a unique/PK constraint or exist only for rare month-end queries (check stats age!).
--                 Result set 2: big tables with heavy seq_scan and low idx_scan are missing-index candidates - confirm
--                 with EXPLAIN on the actual queries from 02-slow-queries.sql before creating anything.
-- Next step:      DROP INDEX CONCURRENTLY unused ones (after the stats-age check); CREATE INDEX CONCURRENTLY for confirmed gaps

-- Result set 1: never-scanned indexes
SELECT
    s.schemaname,
    s.relname                                  AS table_name,
    s.indexrelname                             AS index_name,
    pg_size_pretty(pg_relation_size(s.indexrelid)) AS index_size,
    s.idx_scan
FROM pg_stat_user_indexes s
JOIN pg_index i ON i.indexrelid = s.indexrelid
WHERE s.idx_scan = 0
  AND NOT i.indisunique
  AND NOT i.indisprimary
ORDER BY pg_relation_size(s.indexrelid) DESC
LIMIT 25;

-- Result set 2: seq-scan-heavy tables
SELECT
    schemaname,
    relname,
    seq_scan,
    idx_scan,
    n_live_tup,
    pg_size_pretty(pg_total_relation_size(relid)) AS total_size
FROM pg_stat_user_tables
WHERE seq_scan > 1000
  AND n_live_tup > 100000
ORDER BY seq_scan DESC
LIMIT 25;
