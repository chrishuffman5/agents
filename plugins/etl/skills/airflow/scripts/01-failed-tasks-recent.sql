-- Purpose:        Failed task instances in the last 7 days grouped by DAG/task - the starting map for any "pipelines are failing" report
-- Applies to:     Airflow 2.x metadata database (PostgreSQL). Airflow 3: direct metadata-DB access is discouraged - prefer the REST API; these queries still work read-only against the same tables
-- Read-only:      yes
-- Inputs:         connect to the Airflow metadata DB (e.g. psql -h __HOST__ -U __USER__ __AIRFLOW_DB__)
-- Interpretation: A task failing across many logical dates = code/data defect (fix the task). Many different tasks
--                 failing in one time window = infrastructure event (executor, connection, upstream outage) - check
--                 03-scheduler-lag.sql for that window. max_tries exhausted rows are the ones that paged someone.
-- Next step:      02-dag-run-durations.sql for the impact on delivery times; Airflow UI logs for the top offender

SELECT
    dag_id,
    task_id,
    COUNT(*)                        AS failures_7d,
    MAX(end_date)                   AS last_failure,
    MAX(try_number)                 AS max_tries_seen
FROM task_instance
WHERE state = 'failed'
  AND end_date >= NOW() - INTERVAL '7 days'
GROUP BY dag_id, task_id
ORDER BY failures_7d DESC, last_failure DESC
LIMIT 50
