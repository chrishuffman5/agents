-- Purpose:        Daily report-execution volume and latency breakdown for the last 14 days - the first look at any "SSRS is slow" complaint
-- Applies to:     SSRS 2016+ and Power BI Report Server (ReportServer catalog database, ExecutionLog3 view)
-- Read-only:      yes
-- Inputs:         run against the __REPORTSERVER_DB__ database (default name: ReportServer)
-- How to run:     SSMS against the SQL Server instance hosting the ReportServer catalog
-- Interpretation: The three Time columns tell you where time goes per day: TimeDataRetrieval (source queries),
--                 TimeProcessing (grouping/aggregation), TimeRendering (output format). A day where AvgDataRetrievalMs
--                 jumps points at source-database regression, not the report server.
-- Next step:      02-slowest-reports.sql to identify the specific reports driving the numbers

SELECT
    CAST(TimeStart AS date)            AS RunDate,
    COUNT(*)                           AS Executions,
    SUM(CASE WHEN Status <> 'rsSuccess' THEN 1 ELSE 0 END) AS Failures,
    AVG(TimeDataRetrieval)             AS AvgDataRetrievalMs,
    AVG(TimeProcessing)                AS AvgProcessingMs,
    AVG(TimeRendering)                 AS AvgRenderingMs,
    MAX(TimeDataRetrieval + TimeProcessing + TimeRendering) AS WorstTotalMs
FROM dbo.ExecutionLog3
WHERE TimeStart >= DATEADD(day, -14, GETDATE())
GROUP BY CAST(TimeStart AS date)
ORDER BY RunDate DESC
