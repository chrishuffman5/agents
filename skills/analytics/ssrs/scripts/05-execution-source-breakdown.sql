-- Purpose:        Break executions down by Source (Live vs Cache vs Snapshot vs History) to quantify how much caching absorbs
-- Applies to:     SSRS 2016+ and Power BI Report Server (ExecutionLog3 view)
-- Read-only:      yes
-- Inputs:         run against the __REPORTSERVER_DB__ database (default name: ReportServer)
-- How to run:     SSMS against the ReportServer catalog instance
-- Interpretation: A heavy report with Source='Live' for near-100% of runs and low parameter variety is the ideal
--                 cache/snapshot candidate - enabling caching moves TimeDataRetrieval to ~0 for repeat runs. High
--                 parameter cardinality reports cache poorly (every combination is a separate cache entry).
-- Next step:      Enable caching or scheduled snapshots on the top Live-heavy reports; re-run 01-execution-summary-daily.sql after a week

SELECT
    ItemPath,
    Source,
    COUNT(*)                                   AS Executions,
    AVG(TimeDataRetrieval)                     AS AvgDataRetrievalMs,
    AVG(TimeDataRetrieval + TimeProcessing + TimeRendering) AS AvgTotalMs
FROM dbo.ExecutionLog3
WHERE TimeStart >= DATEADD(day, -30, GETDATE())
GROUP BY ItemPath, Source
ORDER BY ItemPath, Executions DESC
