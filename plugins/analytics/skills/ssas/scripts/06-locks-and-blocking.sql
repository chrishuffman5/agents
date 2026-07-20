-- Purpose:        Show current locks to diagnose processing-vs-query blocking (queries stalled during a model refresh)
-- Applies to:     SSAS Tabular/Multidimensional 2016+ (also Azure AS and Power BI via XMLA)
-- Read-only:      yes
-- Inputs:         none
-- How to run:     SSMS MDX query window or DAX Studio
-- Interpretation: LOCK_STATUS 1 = granted, 0 = waiting. Waiting locks whose LOCK_TYPE is a commit-level lock while a
--                 processing batch holds granted locks = the classic "refresh blocks all queries at commit" pattern.
--                 Cross-reference SPID against 01-active-sessions.sql to identify the holder.
-- Next step:      If refresh-commit blocking recurs, review processing windows and consider scale-out (query replicas)

SELECT
    SPID,
    LOCK_ID,
    LOCK_TRANSACTION_ID,
    LOCK_OBJECT_ID,
    LOCK_TYPE,
    LOCK_STATUS,
    LOCK_CREATION_TIME,
    LOCK_GRANT_TIME
FROM $SYSTEM.DISCOVER_LOCKS
ORDER BY LOCK_STATUS, LOCK_CREATION_TIME
