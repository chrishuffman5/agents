-- Purpose:        Slowest executables (tasks/containers) across recent executions - locate the bottleneck inside a package
-- Applies to:     SSIS 2016+ project deployment model (SSISDB catalog)
-- Read-only:      yes
-- Inputs:         run against SSISDB; narrow with AND es.execution_id = __EXECUTION_ID__ for one run
-- Interpretation: execution_duration is milliseconds. A Data Flow Task dominating = source query or destination commit
--                 is the bottleneck (check batch/commit sizes, destination indexes during load). An Execute SQL Task
--                 dominating = the statement belongs in query tuning, not SSIS. execution_result: 0=success 1=failure
--                 2=completion 3=canceled.
-- Next step:      Tune the named task; re-run 03-package-duration-trend.sql after the change to confirm the win

SELECT TOP 30
    e.package_name,
    es.execution_path,
    COUNT(*)                                   AS runs,
    AVG(es.execution_duration) / 60000.0       AS avg_minutes,
    MAX(es.execution_duration) / 60000.0       AS max_minutes
FROM catalog.executable_statistics es
JOIN catalog.executions e ON e.execution_id = es.execution_id
WHERE e.start_time >= DATEADD(day, -14, SYSDATETIMEOFFSET())
GROUP BY e.package_name, es.execution_path
ORDER BY avg_minutes DESC
