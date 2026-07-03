-- Purpose:        Top statements by total latency from performance_schema digests - the statistical slow-query ranking
-- Applies to:     MySQL 8.0+ (performance_schema statement digests enabled by default)
-- Read-only:      yes
-- Inputs:         none
-- Interpretation: High total latency + high count = throughput optimization target. High rows_examined_avg relative to
--                 rows_sent_avg = scanning far more than it returns - the missing-index signature (verify with EXPLAIN).
--                 tmp_disk_tables > 0 on hot statements = sorts/groups spilling to disk - check sort buffer sizes or
--                 add covering indexes. Digests survive since server start or last TRUNCATE of the summary table.
-- Next step:      EXPLAIN ANALYZE the top offenders; 04-table-sizes.sql for the tables they hit

SELECT
    LEFT(digest_text, 100)                              AS statement,
    count_star                                          AS calls,
    ROUND(sum_timer_wait / 1e12, 1)                     AS total_seconds,
    ROUND(avg_timer_wait / 1e9, 2)                      AS avg_ms,
    ROUND(sum_rows_examined / NULLIF(count_star, 0))    AS rows_examined_avg,
    ROUND(sum_rows_sent / NULLIF(count_star, 0))        AS rows_sent_avg,
    sum_created_tmp_disk_tables                         AS tmp_disk_tables
FROM performance_schema.events_statements_summary_by_digest
WHERE schema_name IS NOT NULL
ORDER BY sum_timer_wait DESC
LIMIT 25
