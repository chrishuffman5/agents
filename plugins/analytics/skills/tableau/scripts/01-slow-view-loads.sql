-- Purpose:        Find the slowest-loading views on Tableau Server over the last 7 days from the repository's http_requests log
-- Applies to:     Tableau Server (self-hosted) - PostgreSQL repository "workgroup", readonly user (enable via tsm data-access repository-access)
-- Read-only:      yes
-- Inputs:         connect: psql -h __TABLEAU_HOST__ -p 8060 -U readonly workgroup
-- How to run:     any PostgreSQL client against the repository (never write to it - unsupported)
-- Interpretation: p95 durations above ~10s make users abandon dashboards. High AvgSeconds with low Loads = a heavy
--                 workbook someone occasionally opens; high both = a popular slow dashboard - prioritize it. Fixes live
--                 in the workbook (extract instead of live, fewer marks/quick filters) - see references/diagnostics.md.
-- Next step:      02-extract-refresh-failures.sql (staleness) and 04-background-job-queue.sql (server-side pressure)

SELECT
    currentsheet                                          AS view_path,
    COUNT(*)                                              AS loads,
    ROUND(AVG(EXTRACT(EPOCH FROM (completed_at - created_at)))::numeric, 1) AS avg_seconds,
    ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (completed_at - created_at)))::numeric, 1) AS p95_seconds
FROM http_requests
WHERE action = 'bootstrapSession'
  AND created_at >= NOW() - INTERVAL '7 days'
  AND completed_at IS NOT NULL
  AND currentsheet IS NOT NULL AND currentsheet <> ''
GROUP BY currentsheet
HAVING COUNT(*) >= 5
ORDER BY p95_seconds DESC
LIMIT 25
