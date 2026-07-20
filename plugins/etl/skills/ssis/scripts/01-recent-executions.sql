-- Purpose:        SSIS execution summary for the last 7 days by project/package with status mix - the first look at catalog health
-- Applies to:     SSIS 2016+ project deployment model (SSISDB catalog)
-- Read-only:      yes
-- Inputs:         run against the SSISDB database on the catalog instance
-- Interpretation: status: 1=created 2=running 3=canceled 4=failed 5=pending 6=ended unexpectedly 7=succeeded 8=stopping 9=completed.
--                 Packages with mixed 4/7 results are flaky (source contention, timeouts); packages 100% failed since a
--                 date = something changed that day (deployment, credential, schema). "ended unexpectedly" (6) = the
--                 SSIS process died - check the SQL Server error log, not the package.
-- Next step:      02-failed-execution-errors.sql for the actual error messages of the failures

SELECT
    e.folder_name,
    e.project_name,
    e.package_name,
    COUNT(*)                                              AS executions_7d,
    SUM(CASE WHEN e.status = 7 THEN 1 ELSE 0 END)         AS succeeded,
    SUM(CASE WHEN e.status = 4 THEN 1 ELSE 0 END)         AS failed,
    SUM(CASE WHEN e.status = 6 THEN 1 ELSE 0 END)         AS ended_unexpectedly,
    MAX(e.start_time)                                     AS last_run
FROM catalog.executions e
WHERE e.start_time >= DATEADD(day, -7, SYSDATETIMEOFFSET())
GROUP BY e.folder_name, e.project_name, e.package_name
ORDER BY failed DESC, executions_7d DESC
