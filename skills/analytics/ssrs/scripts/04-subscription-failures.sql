-- Purpose:        List subscriptions whose last run failed or stalled, with owner and schedule, to fix silent delivery breakage
-- Applies to:     SSRS 2016+ and Power BI Report Server (ReportServer catalog database)
-- Read-only:      yes
-- Inputs:         run against the __REPORTSERVER_DB__ database (default name: ReportServer)
-- How to run:     SSMS against the ReportServer catalog instance
-- Interpretation: LastStatus starting with 'Failure' or 'Error' = broken delivery (commonly: expired data source
--                 credentials, unreachable file share, mail relay rejecting). A LastRunTime far older than the schedule
--                 implies SQL Server Agent job issues - check the Agent jobs named by the ScheduleID GUIDs.
-- Next step:      Fix credentials/destination, then re-run the subscription's Agent job to verify

SELECT
    c.Path                AS ReportPath,
    u.UserName            AS Owner,
    s.Description,
    s.DeliveryExtension,
    s.LastStatus,
    s.LastRunTime,
    s.EventType
FROM dbo.Subscriptions s
JOIN dbo.Catalog c ON c.ItemID = s.Report_OID
JOIN dbo.Users   u ON u.UserID = s.OwnerID
WHERE s.LastStatus NOT LIKE 'Pending%'
  AND s.LastStatus NOT LIKE '%was written%'   -- successful file share delivery
  AND s.LastStatus NOT LIKE 'Mail sent%'       -- successful email delivery
  AND s.LastStatus NOT LIKE 'Done%'
ORDER BY s.LastRunTime DESC
