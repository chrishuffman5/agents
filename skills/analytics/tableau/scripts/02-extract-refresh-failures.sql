-- Purpose:        List failed extract refreshes in the last 7 days with error notes - the silent dashboard-staleness killer
-- Applies to:     Tableau Server (self-hosted) - PostgreSQL repository "workgroup", readonly user
-- Read-only:      yes
-- Inputs:         connect: psql -h __TABLEAU_HOST__ -p 8060 -U readonly workgroup
-- How to run:     any PostgreSQL client against the repository
-- Interpretation: finish_code: 0 = success, 1 = failure, 2 = cancelled. Repeated failures with the same title = a broken
--                 credential or unreachable source; Tableau suspends schedules after 5 consecutive failures, so fix before
--                 users notice week-old data. notes carries the source error text.
-- Next step:      Fix the data source auth/connectivity, then trigger a manual refresh to confirm; 04-background-job-queue.sql if failures are timeouts

SELECT
    bj.job_name,
    bj.title,
    bj.finish_code,
    bj.started_at,
    bj.completed_at,
    ROUND(EXTRACT(EPOCH FROM (bj.completed_at - bj.started_at))::numeric / 60, 1) AS run_minutes,
    LEFT(bj.notes, 300) AS error_excerpt
FROM background_jobs bj
WHERE bj.job_name IN ('Refresh Extracts', 'Increment Extracts')
  AND bj.created_at >= NOW() - INTERVAL '7 days'
  AND bj.finish_code <> 0
ORDER BY bj.completed_at DESC
