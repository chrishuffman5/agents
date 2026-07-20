-- Purpose:        DAG run duration trend over 14 days (avg/p95/max) to spot pipelines drifting toward their SLAs
-- Applies to:     Airflow 2.x metadata database (PostgreSQL); read-only against Airflow 3 tables too
-- Read-only:      yes
-- Inputs:         connect to the Airflow metadata DB
-- Interpretation: p95 creeping up release over release = growing input data or a degrading source - catch it before the
--                 SLA breach. avg stable but max spiking = intermittent contention (pool exhaustion, noisy neighbor on
--                 the executor). Compare failed_runs to 01-failed-tasks-recent.sql output.
-- Next step:      05-top-longest-tasks.sql to find which task inside the slow DAG grew

SELECT
    dag_id,
    COUNT(*)                                                        AS runs_14d,
    SUM(CASE WHEN state = 'failed' THEN 1 ELSE 0 END)               AS failed_runs,
    ROUND(AVG(EXTRACT(EPOCH FROM (end_date - start_date)))::numeric / 60, 1) AS avg_minutes,
    ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (end_date - start_date)))::numeric / 60, 1) AS p95_minutes,
    ROUND(MAX(EXTRACT(EPOCH FROM (end_date - start_date)))::numeric / 60, 1) AS max_minutes
FROM dag_run
WHERE start_date >= NOW() - INTERVAL '14 days'
  AND end_date IS NOT NULL
GROUP BY dag_id
ORDER BY p95_minutes DESC
LIMIT 50
