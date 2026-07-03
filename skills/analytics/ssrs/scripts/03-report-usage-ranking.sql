-- Purpose:        Rank reports by usage over 90 days and list reports never executed - drives cleanup and migration scoping
-- Applies to:     SSRS 2016+ and Power BI Report Server (Catalog + ExecutionLog3)
-- Read-only:      yes
-- Inputs:         run against the __REPORTSERVER_DB__ database (default name: ReportServer)
-- How to run:     SSMS against the ReportServer catalog instance
-- Interpretation: The bottom of the first result set plus everything in the second (never-run) set is your decommission
--                 candidate list - typically 30-60% of a mature catalog. Confirm with owners before deleting; export
--                 RDLs first. Type 2 = report, 5 = data source, 8 = dataset in Catalog.
-- Next step:      04-subscription-failures.sql before decommissioning (a "never viewed" report may still be subscribed)

-- Result set 1: usage ranking, last 90 days
SELECT
    c.Path,
    c.Name,
    COUNT(e.ExecutionId)      AS Executions90d,
    COUNT(DISTINCT e.UserName) AS DistinctUsers,
    MAX(e.TimeStart)          AS LastRun
FROM dbo.Catalog c
LEFT JOIN dbo.ExecutionLog3 e
    ON e.ItemPath = c.Path
   AND e.TimeStart >= DATEADD(day, -90, GETDATE())
WHERE c.Type = 2
GROUP BY c.Path, c.Name
ORDER BY Executions90d DESC;

-- Result set 2: reports with zero executions in the whole retained log
SELECT c.Path, c.Name, c.CreationDate, c.ModifiedDate
FROM dbo.Catalog c
WHERE c.Type = 2
  AND NOT EXISTS (SELECT 1 FROM dbo.ExecutionLog3 e WHERE e.ItemPath = c.Path)
ORDER BY c.Path;
