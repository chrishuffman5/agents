-- Purpose:        Package duration trend over 30 days (avg/max) to catch loads drifting toward their batch window limits
-- Applies to:     SSIS 2016+ project deployment model (SSISDB catalog)
-- Read-only:      yes
-- Inputs:         run against SSISDB
-- Interpretation: Steadily rising avg = growing source data outpacing the design (full loads that need to become
--                 incremental). Stable avg with occasional huge max = contention (blocking at the destination, source
--                 backup windows). Compare against your batch window: anything trending past ~70% of the window is a
--                 redesign candidate before it becomes an incident.
-- Next step:      04-longest-executables.sql to find which task inside the slow package grew

SELECT
    e.folder_name,
    e.project_name,
    e.package_name,
    COUNT(*)                                                            AS runs_30d,
    AVG(DATEDIFF(second, e.start_time, e.end_time)) / 60.0              AS avg_minutes,
    MAX(DATEDIFF(second, e.start_time, e.end_time)) / 60.0              AS max_minutes
FROM catalog.executions e
WHERE e.start_time >= DATEADD(day, -30, SYSDATETIMEOFFSET())
  AND e.end_time IS NOT NULL
  AND e.status = 7
GROUP BY e.folder_name, e.project_name, e.package_name
HAVING COUNT(*) >= 3
ORDER BY avg_minutes DESC
