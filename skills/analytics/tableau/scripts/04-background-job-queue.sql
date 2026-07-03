-- Purpose:        Measure backgrounder queue latency (created vs started) by job type to size backgrounder capacity
-- Applies to:     Tableau Server (self-hosted) - PostgreSQL repository "workgroup", readonly user
-- Read-only:      yes
-- Inputs:         connect: psql -h __TABLEAU_HOST__ -p 8060 -U readonly workgroup
-- How to run:     any PostgreSQL client against the repository
-- Interpretation: avg_queue_minutes climbing across days = backgrounders saturated; refreshes start late and data goes
--                 stale even though every job "succeeds". Fixes: spread schedules off the hour marks, add backgrounder
--                 processes/nodes, or convert full refreshes to incremental. p95 queue > 15 min is a capacity flag.
-- Next step:      Compare against 02-extract-refresh-failures.sql timeouts; rebalance schedules before adding hardware

SELECT
    CAST(created_at AS date)  AS day,
    job_name,
    COUNT(*)                  AS jobs,
    ROUND(AVG(EXTRACT(EPOCH FROM (started_at - created_at)))::numeric / 60, 1)  AS avg_queue_minutes,
    ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (started_at - created_at)))::numeric / 60, 1) AS p95_queue_minutes,
    ROUND(AVG(EXTRACT(EPOCH FROM (completed_at - started_at)))::numeric / 60, 1) AS avg_run_minutes
FROM background_jobs
WHERE created_at >= NOW() - INTERVAL '7 days'
  AND started_at IS NOT NULL
GROUP BY CAST(created_at AS date), job_name
ORDER BY day DESC, jobs DESC
