-- Purpose:        Show all active SSAS sessions with user, duration, and last command to find who/what is loading the server
-- Applies to:     SSAS Tabular/Multidimensional 2016+ (also Azure AS and Power BI via XMLA)
-- Read-only:      yes
-- Inputs:         none
-- How to run:     SSMS (connect to AS instance, new MDX query window) or DAX Studio
-- Interpretation: Sessions with SESSION_CPU_TIME_MS in the millions or SESSION_ELAPSED_TIME far above peers indicate runaway
--                 queries or oversized processing jobs. SESSION_LAST_COMMAND shows what the session is doing.
-- Next step:      02-current-commands.sql for what each session is executing right now

SELECT
    SESSION_SPID,
    SESSION_USER_NAME,
    SESSION_CURRENT_DATABASE,
    SESSION_START_TIME,
    SESSION_ELAPSED_TIME_MS,
    SESSION_CPU_TIME_MS,
    SESSION_READS,
    SESSION_WRITES,
    SESSION_LAST_COMMAND
FROM $SYSTEM.DISCOVER_SESSIONS
ORDER BY SESSION_CPU_TIME_MS DESC
