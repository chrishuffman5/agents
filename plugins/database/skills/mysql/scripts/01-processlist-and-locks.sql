-- Purpose:        Current sessions plus InnoDB lock-wait chains - who runs what, who blocks whom
-- Applies to:     MySQL 8.0+ (sys schema and performance_schema enabled, the defaults)
-- Read-only:      yes
-- Inputs:         none; needs PROCESS privilege and SELECT on sys/performance_schema
-- Interpretation: In the lock-wait result set, one blocking_pid appearing repeatedly is the root blocker - its
--                 blocking_query shows why (or NULL if it is an uncommitted idle transaction - the classic app bug).
--                 Long 'Sleep' sessions with open transactions (trx started long ago) hold undo history and locks.
--                 wait_age_secs climbing past your lock_wait_timeout predicts imminent application errors.
-- Next step:      02-statement-digest.sql for the statistical view; KILL the root blocker only with user signoff

-- Result set 1: non-sleeping sessions
SELECT id, user, host, db, command, time AS seconds, state, LEFT(info, 120) AS query
FROM information_schema.processlist
WHERE command <> 'Sleep'
ORDER BY time DESC
LIMIT 30;

-- Result set 2: lock-wait chains
SELECT
    waiting_pid,
    LEFT(waiting_query, 80)   AS waiting_query,
    wait_age_secs,
    blocking_pid,
    LEFT(blocking_query, 80)  AS blocking_query,
    blocking_trx_age
FROM sys.innodb_lock_waits
ORDER BY wait_age_secs DESC;
