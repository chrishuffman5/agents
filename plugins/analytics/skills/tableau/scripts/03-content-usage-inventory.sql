-- Purpose:        Rank workbooks by view traffic over 90 days and flag dormant content for cleanup/migration scoping
-- Applies to:     Tableau Server (self-hosted) - PostgreSQL repository "workgroup", readonly user
-- Read-only:      yes
-- Inputs:         connect: psql -h __TABLEAU_HOST__ -p 8060 -U readonly workgroup
-- How to run:     any PostgreSQL client against the repository
-- Interpretation: Workbooks in result set 2 (zero traffic in 90 days) are archive candidates - typically a third of a
--                 mature server. Check owners and embedded/API access before removing; extract-refresh schedules on
--                 dormant workbooks are pure waste - kill those first.
-- Next step:      Disable refresh schedules on dormant workbooks, then archive; re-run quarterly

-- Result set 1: most-viewed workbooks, last 90 days
SELECT
    w.name                        AS workbook,
    p.name                        AS project,
    SUM(vs.nviews)                AS views_90d,
    COUNT(DISTINCT vs.user_id)    AS distinct_users
FROM _views_stats vs
JOIN _views v  ON v.id = vs.views_id
JOIN _workbooks w ON w.id = v.workbook_id
JOIN projects p   ON p.id = w.project_id
WHERE vs.time >= NOW() - INTERVAL '90 days'
GROUP BY w.name, p.name
ORDER BY views_90d DESC
LIMIT 25;

-- Result set 2: workbooks with no views in 90 days
SELECT w.name AS workbook, p.name AS project, w.created_at, w.updated_at
FROM _workbooks w
JOIN projects p ON p.id = w.project_id
WHERE NOT EXISTS (
    SELECT 1
    FROM _views_stats vs
    JOIN _views v ON v.id = vs.views_id
    WHERE v.workbook_id = w.id
      AND vs.time >= NOW() - INTERVAL '90 days'
)
ORDER BY w.updated_at;
