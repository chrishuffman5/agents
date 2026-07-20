-- Purpose:        Top 20 slowest reports over the last 14 days with per-phase timing so you know WHAT is slow and WHY
-- Applies to:     SSRS 2016+ and Power BI Report Server (ExecutionLog3 view)
-- Read-only:      yes
-- Inputs:         run against the __REPORTSERVER_DB__ database (default name: ReportServer)
-- How to run:     SSMS against the ReportServer catalog instance
-- Interpretation: Phase dominance decides the fix: DataRetrieval-dominated -> tune the dataset query / add indexes at the
--                 source; Processing-dominated -> reduce row counts returned to the report, move aggregation to SQL;
--                 Rendering-dominated -> simplify layout, avoid huge tablixes, check export format (PDF is heaviest).
-- Next step:      05-execution-source-breakdown.sql to check whether caching/snapshots could absorb the load

SELECT TOP 20
    ItemPath,
    COUNT(*)                    AS Executions,
    AVG(TimeDataRetrieval)      AS AvgDataRetrievalMs,
    AVG(TimeProcessing)         AS AvgProcessingMs,
    AVG(TimeRendering)          AS AvgRenderingMs,
    AVG(TimeDataRetrieval + TimeProcessing + TimeRendering) AS AvgTotalMs,
    MAX(TimeDataRetrieval + TimeProcessing + TimeRendering) AS MaxTotalMs,
    AVG(CAST([RowCount] AS bigint)) AS AvgRowCount
FROM dbo.ExecutionLog3
WHERE TimeStart >= DATEADD(day, -14, GETDATE())
  AND Status = 'rsSuccess'
GROUP BY ItemPath
ORDER BY AvgTotalMs DESC
