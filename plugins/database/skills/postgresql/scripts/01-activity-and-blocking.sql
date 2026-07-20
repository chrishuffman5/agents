-- Purpose:        Current activity with blocking chains - who is running what, who is waiting on whom
-- Applies to:     PostgreSQL 14+ (all documented versions)
-- Read-only:      yes
-- Inputs:         none; run as a role with pg_read_all_stats (or superuser)
-- Interpretation: Rows with blocked_by set are waiting on the listed PIDs - walk to the root blocker (a blocker that is
--                 itself 'idle in transaction' is the classic app bug: transaction opened, never committed). Long
--                 'active' queries with wait_event_type = 'Lock' vs 'IO' distinguish contention from storage. Many
--                 'idle in transaction' sessions = connection-pool or ORM misuse.
-- Next step:      02-slow-queries.sql for the statistical view; terminate a root blocker only with pg_terminate_backend and user signoff

SELECT
    a.pid,
    a.usename,
    a.state,
    a.wait_event_type,
    a.wait_event,
    now() - a.query_start                         AS query_age,
    now() - a.xact_start                          AS xact_age,
    pg_blocking_pids(a.pid)                       AS blocked_by,
    LEFT(a.query, 120)                            AS query
FROM pg_stat_activity a
WHERE a.state <> 'idle'
  AND a.pid <> pg_backend_pid()
ORDER BY xact_age DESC NULLS LAST
