-- Purpose:        Slowest tasks by average duration over 14 days - find which task inside a slow DAG actually grew
-- Applies to:     Airflow 2.x metadata database (PostgreSQL); read-only against Airflow 3 tables too
-- Read-only:      yes
-- Inputs:         connect to the Airflow metadata DB; optionally filter WHERE dag_id = '__DAG_ID__'
-- Interpretation: The duration column is seconds. One task dominating its DAG's runtime is the optimization target -
--                 usually a full-reload that should be incremental, or a sensor in poke mode holding a slot (convert to
--                 deferrable/reschedule mode). High avg with high runs = biggest total compute spend.
-- Next step:      For sensors: switch to reschedule/deferrable. For loads: check incremental strategy with the dbt/Spark side

SELECT
    dag_id,
    task_id,
    operator,
    COUNT(*)                              AS runs_14d,
    ROUND(AVG(duration)::numeric / 60, 1) AS avg_minutes,
    ROUND(MAX(duration)::numeric / 60, 1) AS max_minutes,
    ROUND(SUM(duration)::numeric / 3600, 1) AS total_hours_14d
FROM task_instance
WHERE state = 'success'
  AND end_date >= NOW() - INTERVAL '14 days'
  AND duration IS NOT NULL
GROUP BY dag_id, task_id, operator
ORDER BY avg_minutes DESC
LIMIT 50
