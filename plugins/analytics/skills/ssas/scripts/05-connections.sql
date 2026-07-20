-- Purpose:        List all client connections to the SSAS instance to audit who connects with what tool and spot leaks
-- Applies to:     SSAS Tabular/Multidimensional 2016+ (also Azure AS and Power BI via XMLA)
-- Read-only:      yes
-- Inputs:         none
-- How to run:     SSMS MDX query window or DAX Studio
-- Interpretation: Many connections from one host with old CONNECTION_LAST_COMMAND_START_TIME = a client leaking
--                 connections (frequently unclosed Excel/custom app sessions). CONNECTION_HOST_APPLICATION identifies
--                 the tool (Excel, Power BI Desktop, SSMS, custom).
-- Next step:      01-active-sessions.sql to see which connections carry active sessions

SELECT
    CONNECTION_ID,
    CONNECTION_USER_NAME,
    CONNECTION_HOST_NAME,
    CONNECTION_HOST_APPLICATION,
    CONNECTION_START_TIME,
    CONNECTION_LAST_COMMAND_START_TIME,
    CONNECTION_BUSY_DISK_IO_MS
FROM $SYSTEM.DISCOVER_CONNECTIONS
ORDER BY CONNECTION_START_TIME
