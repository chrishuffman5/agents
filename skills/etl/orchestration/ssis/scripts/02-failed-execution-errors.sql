-- Purpose:        Error messages from failed SSIS executions in the last 7 days - what actually broke, in the engine's own words
-- Applies to:     SSIS 2016+ project deployment model (SSISDB catalog)
-- Read-only:      yes
-- Inputs:         run against SSISDB; narrow with AND e.execution_id = __EXECUTION_ID__ for one run
-- Interpretation: message_type 120 = error, 130 = warning. The FIRST error per execution is usually the root cause;
--                 later errors are cascade noise. Login/connection errors name the connection manager - credential or
--                 firewall. "violation of PRIMARY KEY" and truncation errors = data quality, not infrastructure.
-- Next step:      Fix the first error's cause; 03-package-duration-trend.sql if failures are timeout-driven

SELECT
    em.operation_id            AS execution_id,
    e.package_name,
    em.message_time,
    em.message_source_name,
    LEFT(em.message, 500)      AS error_message
FROM catalog.event_messages em
JOIN catalog.executions e ON e.execution_id = em.operation_id
WHERE em.message_type = 120
  AND em.message_time >= DATEADD(day, -7, SYSDATETIMEOFFSET())
ORDER BY em.operation_id DESC, em.message_time
