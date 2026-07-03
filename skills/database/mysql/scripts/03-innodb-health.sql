-- Purpose:        InnoDB vitals - buffer pool efficiency, redo pressure, history list, and key status counters
-- Applies to:     MySQL 8.0+
-- Read-only:      yes
-- Inputs:         none
-- Interpretation: Buffer pool hit rate under ~99% for OLTP = pool too small for the working set (innodb_buffer_pool_size
--                 is THE MySQL memory knob). History list length climbing without bound = a long-running transaction
--                 blocking purge (find it in 01) - undo bloat and slowdown follow. Checkpoint age pressing against the
--                 redo capacity = write bursts stalling on flush; raise innodb_redo_log_capacity.
-- Next step:      Size the named knob, or kill the purge-blocking transaction; re-run after change

SELECT 'buffer_pool_hit_rate' AS metric,
       CONCAT(ROUND(100 - 100 * v1.variable_value / NULLIF(v2.variable_value, 0), 2), ' %') AS value
FROM performance_schema.global_status v1
JOIN performance_schema.global_status v2
WHERE v1.variable_name = 'Innodb_buffer_pool_reads'      -- disk reads
  AND v2.variable_name = 'Innodb_buffer_pool_read_requests'
UNION ALL
SELECT variable_name, variable_value
FROM performance_schema.global_status
WHERE variable_name IN (
    'Innodb_buffer_pool_pages_free',
    'Innodb_buffer_pool_pages_total',
    'Innodb_row_lock_waits',
    'Innodb_row_lock_time_avg',
    'Threads_connected',
    'Threads_running',
    'Created_tmp_disk_tables',
    'Select_full_join'
)
UNION ALL
SELECT 'trx_rseg_history_len (purge lag)', count
FROM information_schema.innodb_metrics
WHERE name = 'trx_rseg_history_len'
