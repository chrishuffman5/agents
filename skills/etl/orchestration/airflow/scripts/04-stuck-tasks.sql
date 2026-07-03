-- Purpose:        Find tasks stuck in running/queued state for hours - zombie tasks and orphaned runs that block schedules
-- Applies to:     Airflow 2.x metadata database (PostgreSQL); read-only against Airflow 3 tables too
-- Read-only:      yes
-- Inputs:         connect to the Airflow metadata DB; adjust the 6-hour threshold to your longest legitimate task
-- Interpretation: Tasks running far beyond any legitimate duration are usually zombies (worker died, heartbeat lost) -
--                 the scheduler should reap them, but stuck ones hold pool slots and block downstream DAG runs.
--                 Long-queued tasks with free capacity elsewhere = pool or concurrency limit on that specific DAG.
-- Next step:      Clear the zombies via UI/CLI (airflow tasks clear) after confirming the worker is gone; fix heartbeat/timeout settings if recurring

SELECT
    dag_id,
    task_id,
    run_id,
    state,
    try_number,
    queued_dttm,
    start_date,
    ROUND(EXTRACT(EPOCH FROM (NOW() - COALESCE(start_date, queued_dttm)))::numeric / 3600, 1) AS hours_in_state,
    pool,
    hostname
FROM task_instance
WHERE state IN ('running', 'queued')
  AND COALESCE(start_date, queued_dttm) < NOW() - INTERVAL '6 hours'
ORDER BY hours_in_state DESC
