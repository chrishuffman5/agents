-- Purpose:        Show commands currently executing on the SSAS instance to identify the query or processing job causing load
-- Applies to:     SSAS Tabular/Multidimensional 2016+ (also Azure AS and Power BI via XMLA)
-- Read-only:      yes
-- Inputs:         none
-- How to run:     SSMS MDX query window or DAX Studio
-- Interpretation: COMMAND_ELAPSED_TIME_MS >> COMMAND_CPU_TIME_MS suggests the command is waiting (storage engine IO,
--                 blocking, or DirectQuery source latency) rather than computing. Long-running COMMAND_TEXT starting with
--                 <Batch or {"refresh" is processing; DAX/MDX text is a user query.
-- Next step:      06-locks-and-blocking.sql if commands appear stalled; 03-object-memory.sql if memory pressure is suspected

SELECT
    SESSION_SPID,
    COMMAND_START_TIME,
    COMMAND_ELAPSED_TIME_MS,
    COMMAND_CPU_TIME_MS,
    COMMAND_READS,
    COMMAND_WRITES,
    COMMAND_TEXT
FROM $SYSTEM.DISCOVER_COMMANDS
ORDER BY COMMAND_ELAPSED_TIME_MS DESC
