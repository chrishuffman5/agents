-- Purpose:        Measure queued-to-started latency per day to detect scheduler/executor saturation (tasks wait, nothing "fails")
-- Applies to:     Airflow 2.x metadata database (PostgreSQL); read-only against Airflow 3 tables too
-- Read-only:      yes
-- Inputs:         connect to the Airflow metadata DB
-- Interpretation: avg queue latency over ~60s or p95 over a few minutes = not enough executor slots (parallelism,
--                 pool limits, worker count) or a starved scheduler. Rising latency at fixed times of day = schedule
--                 stacking - stagger your DAG schedules. This is the silent killer behind "the DAG succeeded but late".
-- Next step:      Check pool utilization and executor capacity; re-run after raising parallelism or staggering schedules

SELECT
    CAST(queued_dttm AS date)   AS day,
    COUNT(*)                    AS tasks,
    ROUND(AVG(EXTRACT(EPOCH FROM (start_date - queued_dttm)))::numeric, 1)  AS avg_queue_seconds,
    ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (start_date - queued_dttm)))::numeric, 1) AS p95_queue_seconds,
    ROUND(MAX(EXTRACT(EPOCH FROM (start_date - queued_dttm)))::numeric, 1)  AS max_queue_seconds
FROM task_instance
WHERE queued_dttm IS NOT NULL
  AND start_date IS NOT NULL
  AND queued_dttm >= NOW() - INTERVAL '7 days'
GROUP BY CAST(queued_dttm AS date)
ORDER BY day DESC
