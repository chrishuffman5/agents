# Apache Airflow Diagnostics

## Common Issues

### Zombie Tasks

**What they are:** Tasks stuck in "running" state after the actual process has died. The worker process was killed so suddenly (SIGKILL) that it could not report a failure, so heartbeats stop but the Scheduler does not immediately know why.

**Common causes:**
1. **Resource exhaustion (most common):** Worker runs out of memory or CPU; the OS OOM killer terminates the process with SIGKILL, giving no chance for graceful shutdown
2. **Network partitions:** Loss of connectivity between scheduler and worker nodes; heartbeats cannot reach the metadata database
3. **System crashes:** Unexpected worker node reboots or container eviction
4. **Misconfiguration:** Timeout values too low for long-running tasks
5. **Container limits:** Kubernetes memory limits or Docker memory caps triggering OOM kills

**Detection and configuration:**
- `zombie_detection_interval`: How often (seconds) the scheduler checks for zombies (default: 10)
- `scheduler_zombie_task_threshold`: Time (seconds) since last heartbeat before a task is considered a zombie (default: 300)
- The scheduler's zombie detection checks the `latest_heartbeat` of running task instances

**Resolution strategies:**
1. Increase worker memory/CPU resources
2. Set appropriate `execution_timeout` on tasks to prevent indefinite runs
3. Reduce task concurrency (`max_active_tasks_per_dag`, pool sizes)
4. Use KubernetesExecutor for per-task resource isolation
5. Monitor worker resource utilization with system-level tools
6. For CeleryExecutor: ensure broker (Redis/RabbitMQ) is stable and properly sized

### Scheduler Delays

**Symptoms:** Tasks take a long time to move from "scheduled" to "running"; DAG runs start late.

**Common causes:**
1. **Too many DAGs or tasks:** Scheduler overwhelmed by the volume of scheduling decisions
2. **Slow DAG parsing:** Complex module-level code slows down DAG file processing
3. **Database bottleneck:** Slow queries against the metadata database
4. **Pool exhaustion:** All pool slots consumed; tasks wait in queue
5. **Executor saturation:** All executor slots consumed

**Diagnosis:**
- Check `scheduler.scheduler_loop_duration` metric -- increasing values indicate scheduler overload
- Check `scheduler.tasks.starving` metric -- tasks waiting for resources
- Monitor database query performance (slow query log)
- Check `dagbag_size` and DAG parse times in the UI

**Resolution:**
- Increase `parallelism` if executor slots are the bottleneck
- Increase `min_file_process_interval` to reduce DAG re-parsing frequency
- Optimize module-level code in DAG files (no I/O at import time)
- Scale up the metadata database (CPU, memory, IOPS)
- Use multiple scheduler instances (HA scheduler, Airflow 2.0+)
- Split DAGs across multiple DAG bundles (Airflow 3)

### DAG Parsing Errors

**Symptoms:** DAG does not appear in the UI; error shown in the DAG import errors view.

**Common causes:**
1. **Python syntax errors:** Standard Python errors in DAG files
2. **Import errors:** Missing packages, incorrect import paths
3. **Top-level exceptions:** Code at module level that raises exceptions (failed DB connections, missing files, API errors)
4. **Circular imports:** DAG files importing from each other
5. **Airflow 3 import changes:** Old import paths that no longer work

**Diagnosis:**
- Check the Airflow UI: Browse > DAG Import Errors
- Run `airflow dags list-import-errors` from CLI
- Test DAG parsing locally: `python dags/my_dag.py`
- For Airflow 3 migration: `ruff check dags/ --select AIR301`

**Prevention:**
- Run DAG validation tests in CI before deployment
- Use a `DagBag` test to catch import errors early
- Keep module-level code minimal and error-free
- Pin dependencies in requirements.txt

### Import Errors

**Symptoms:** DAG fails to load with `ModuleNotFoundError` or `ImportError`.

**Common causes:**
1. **Missing provider packages:** In Airflow 3, operators like BashOperator and PythonOperator require `apache-airflow-providers-standard`
2. **Path issues:** Shared modules not on PYTHONPATH (ensure proper `__init__.py` files)
3. **Version mismatches:** Provider package version incompatible with Airflow core version
4. **Airflow 3 path changes:** `airflow.models.dag.DAG` moved to `airflow.sdk.DAG`, etc.

**Resolution:**
- Install required provider packages
- Verify PYTHONPATH includes `dags/`, `plugins/`, and `config/` directories
- Use `ruff check --select AIR301 --fix` to auto-fix import path changes
- Check provider compatibility matrix in Airflow documentation

---

## Performance Bottlenecks

### Slow DAG Loading

**Symptoms:** High DAG file processing times; scheduler spending too much time on parsing.

**Causes:**
- Heavy computation at module level (database queries, API calls, file reads)
- Large number of dynamically generated DAGs
- Complex import chains
- Large DAG files with many tasks

**Diagnosis:**
- Monitor `dag_file_processor_timeouts` metric
- Check DAG parse times: Admin > DAG Parse Times (Airflow UI)
- Profile DAG file: `time python -c "import my_dag"`

**Fixes:**
- Move all logic inside task functions
- Cache configuration reads (but not at module level -- use Variables with default values)
- Split large DAGs into smaller, focused DAGs
- Use DAG bundles to parallelize file processing (Airflow 3)
- Increase `dagbag_import_timeout` if DAGs legitimately take time to import (default: 30s)

### Worker Saturation

**Symptoms:** Tasks stuck in "queued" state; long queue wait times.

**Causes:**
- More tasks scheduled than workers can handle
- Long-running tasks occupying worker slots
- Sensors in `poke` mode consuming worker slots while waiting
- Pool sizes too small

**Diagnosis:**
- Check `executor.open_slots` and `executor.queued_tasks` metrics
- Monitor worker CPU and memory utilization
- Check pool utilization in UI: Admin > Pools

**Fixes:**
- Scale workers horizontally (CeleryExecutor: add workers; KubernetesExecutor: increase cluster capacity)
- Use deferrable operators/sensors instead of `poke` mode
- Set `execution_timeout` to prevent tasks from running indefinitely
- Tune pool sizes and task priorities
- Use `max_active_tis_per_dag` to prevent single DAGs from monopolizing

### Database Load

**Symptoms:** Slow UI, slow scheduling, high database CPU/connection count.

**Causes:**
- Accumulated metadata (never automatically cleaned)
- Too many concurrent database connections
- Missing database indexes
- Large XCom values stored in the database
- Frequent database access from many DAGs simultaneously

**Diagnosis:**
- Monitor database connection count, CPU, and query latency
- Check metadata table sizes (especially `task_instance`, `dag_run`, `xcom`, `log`, `rendered_task_instance_fields`)
- Enable slow query logging on the database

**Fixes:**
- Run `airflow db clean` regularly (see Database Maintenance section below)
- Use a custom XCom backend for large values (S3, GCS)
- Scale up the database (vertical: more CPU/RAM; or use managed services with auto-scaling)
- Reduce `min_file_process_interval` to avoid excessive DAG re-parsing DB writes
- Tune `sql_alchemy_pool_size` and `sql_alchemy_max_overflow`

---

## Debugging

### Task Logs

**Accessing logs:**
- **UI:** Click on a task instance > Logs tab
- **CLI:** `airflow tasks logs <dag_id> <task_id> <execution_date>`
- **File system:** Configured via `base_log_folder` (default: `$AIRFLOW_HOME/logs/`)
- **Remote logging:** Configure S3, GCS, Azure Blob, or Elasticsearch for centralized log storage

**Log levels:**
- Set `logging_level` in airflow.cfg (default: INFO)
- Set `fab_logging_level` for FAB/auth logging
- Use `AIRFLOW__LOGGING__LOGGING_LEVEL` environment variable

**Tips:**
- Include contextual information in task logs (record counts, file paths, duration)
- Use Python's `logging` module inside tasks for structured logging
- For KubernetesExecutor: logs may be lost if the pod is evicted; use remote logging

### XCom Inspection

**Viewing XCom values:**
- **UI:** Admin > XComs (browse all XCom entries)
- **UI:** Click on a task instance > XCom tab (view task's pushed values)
- **CLI:** `airflow xcom list` or `airflow xcom get`
- **API:** `GET /api/v2/xcoms`

**Common XCom issues:**
- Value too large: causes database performance issues
- Serialization failure: object not JSON-serializable (Airflow 3 default backend)
- Missing XCom: upstream task did not push expected value (check for exceptions before the return statement)

### Trigger Rule Debugging

When a task does not run as expected, check:
1. What trigger rule is configured? (default: `all_success`)
2. What are the states of all upstream tasks?
3. Are any upstream tasks skipped? (`all_success` treats skipped as not-success)
4. Is `depends_on_past=True` blocking on a previous failed run?
5. Is the task in a branch that was not chosen?

**Common confusion:**
- Task skipped unexpectedly: Usually due to an upstream branch operator. Tasks not on the chosen branch path get `skipped` state, which propagates downstream with default trigger rules.
- Fix: Use `trigger_rule="none_failed"` or `trigger_rule="none_failed_min_one_success"` for tasks that should run regardless of branch choice.

### Rendered Templates

View the actual values of Jinja-templated parameters after rendering:
- **UI:** Click on a task instance > Rendered Template tab
- Useful for debugging SQL queries, file paths, and other templated values
- In Airflow 3, rendered templates are shown for the specific DAG version

---

## Executor-Specific Issues

### CeleryExecutor

**Queue depth issues:**
- **Symptom:** Tasks accumulate in the broker queue; workers not picking them up fast enough
- **Diagnosis:** Monitor broker queue depth (Redis: `LLEN`; RabbitMQ: management UI)
- **Fixes:** Add more workers; increase worker concurrency (`worker_concurrency`); ensure broker has adequate resources

**Worker disconnections:**
- **Symptom:** Workers go offline; tasks fail with "received SIGTERM"
- **Causes:** Broker connection timeout, network issues, worker OOM
- **Fixes:** Increase broker connection timeout; monitor worker memory; use `--autoscale` for Celery workers

**Task routing issues:**
- **Symptom:** Tasks sent to wrong queue or no worker picks them up
- **Diagnosis:** Check task `queue` parameter; verify worker is listening to the correct queue
- **Fix:** Ensure workers start with `-Q <queue_name>` matching the task queue configuration

**Airflow 3 note:** CeleryKubernetesExecutor has been removed. Use Multiple Executors Concurrently instead. Known issue: TaskFlow API tasks (`@task`) may not properly inherit the `queue` parameter from DAG code, defaulting to `queue='default'`.

### KubernetesExecutor

**Pod failures:**
- **Symptom:** Tasks fail with "Pod failed" or "Pod evicted"
- **Common causes:**
  - Memory limit exceeded (OOMKilled): Pod's memory usage exceeded `resources.limits.memory`
  - Image pull errors: Docker image not found or registry authentication failed
  - Init container failures: Initialization steps (git-sync, config loading) failed
  - Node pressure: Kubernetes node running low on resources; pods evicted

**Diagnosis:**
- `kubectl describe pod <pod-name>` -- check Events section
- `kubectl logs <pod-name>` -- check container logs
- `kubectl get events --sort-by=.metadata.creationTimestamp` -- cluster-level events
- `airflow kubernetes generate-dag-yaml` -- inspect generated pod specs

**Pod startup latency:**
- **Symptom:** Tasks take 30-60+ seconds from "queued" to "running"
- **Causes:** Image pull time (large images), resource scheduling delays, init containers
- **Fixes:** Use lighter Docker images; pre-pull images on nodes; use `imagePullPolicy: IfNotPresent`; reduce init container overhead

**Log loss:**
- **Symptom:** Task logs missing after pod completes or is evicted
- **Cause:** Pod logs are ephemeral; when the pod terminates, logs are lost
- **Fix:** Configure remote logging (S3, GCS, Elasticsearch) -- this is essential for KubernetesExecutor

**Resource requests and limits:**
- Always set both `requests` and `limits` for memory and CPU
- Set requests close to actual usage for better scheduling
- Set limits with headroom to avoid OOMKilled

### Multiple Executors (Airflow 3)

**Task routing issues:**
- **Known bug (Airflow 3.0.6):** Tasks with `queue='kubernetes'` not routed to KubernetesExecutor; all tasks executed by the first (default) executor
- **Workaround:** Use the `executor` parameter on tasks instead of relying on queue-based routing
- **TaskFlow API limitation:** `@task` decorated tasks may not inherit `queue` from DAG-level defaults; explicitly set `executor` parameter on the task

---

## Database Maintenance

### Metadata Database Cleanup

**Why it matters:** Airflow never automatically removes metadata. Over time, tables grow to tens of gigabytes, degrading scheduler, webserver, and UI performance. When a metadata table exceeds ~50 GB, scheduler performance noticeably degrades.

**Key tables that grow:**
- `task_instance` -- A row per task execution
- `dag_run` -- A row per DAG run
- `log` -- Audit log entries
- `xcom` -- XCom values (especially large if used improperly)
- `rendered_task_instance_fields` -- Rendered templates for each task instance
- `task_fail` -- Failed task records
- `job` -- Scheduler and worker job records
- `import_error` -- DAG import errors

### Cleanup Methods

**CLI (recommended):**
```bash
# Archive old data (safe -- data moved to _archive tables)
airflow db clean --clean-before-timestamp "2025-01-01"

# Then drop the archive tables
airflow db drop-archived

# Skip archival (permanently delete -- backup first!)
airflow db clean --clean-before-timestamp "2025-01-01" --skip-archive
```

**Cleanup DAG:** Create a DAG that runs periodically to clean old data. Multiple community-maintained cleanup DAGs exist (e.g., teamclairvoyant/airflow-maintenance-dags).

**Direct SQL (use with caution):**
```sql
-- Check table sizes
SELECT relname, pg_size_pretty(pg_relation_size(relid))
FROM pg_catalog.pg_statio_user_tables
ORDER BY pg_relation_size(relid) DESC;
```

### Cleanup Best Practices

1. **Always backup before cleanup:** `pg_dump` or equivalent before any data removal
2. **Disable the cluster during major cleanup:** Prevent scheduler from writing new data during cleanup
3. **Schedule regular cleanup:** Run `airflow db clean` weekly or monthly via a maintenance DAG
4. **Set retention policy:** Define how long to keep historical data (30, 60, 90 days depending on audit requirements)
5. **Run ANALYZE after cleanup:** Help the database optimizer update statistics
6. **Monitor table sizes:** Alert when tables exceed threshold sizes

### Log Rotation

**Task logs:**
- Configure `base_log_folder` with adequate disk space
- Use remote logging (S3, GCS, Elasticsearch) for long-term storage
- Implement log rotation via logrotate or container-level log management
- In Airflow 3 Helm chart: configure persistent volume claims for log storage

**Scheduler/webserver logs:**
- Standard Python logging; configure via `logging_config_class`
- Use `TimedRotatingFileHandler` or `RotatingFileHandler`
- In containerized deployments: log to stdout and use cluster-level log aggregation (Fluentd, Filebeat)

---

## Upgrade and Migration Troubleshooting

### Pre-Upgrade Checks

```bash
# Check for import errors in current DAGs
airflow dags list-import-errors

# Reserialize all DAGs (must complete without errors)
airflow dags reserialize

# Run Ruff to find breaking changes
ruff check dags/ --select AIR301,AIR302

# Check provider compatibility
pip list | grep apache-airflow-providers
```

### Common Migration Issues (2.x to 3.x)

**Issue: DAG fails to load after upgrade**
- Cause: Import path changes (`airflow.models.*` -> `airflow.sdk.*`)
- Fix: Run `ruff check --select AIR301 --fix`

**Issue: Custom operator fails with database access error**
- Cause: Direct metadata DB access removed from worker tasks
- Fix: Refactor to use the Airflow REST API client, or redesign to not require direct DB queries

**Issue: XCom values fail to deserialize**
- Cause: XCom pickling disabled in Airflow 3
- Fix: Re-serialize XCom values as JSON; archived pickled XComs are moved to `_xcom_archive` table

**Issue: SSO/OAuth login fails**
- Cause: OAuth redirect URLs now require `/auth` prefix; FAB moved to provider package
- Fix: Update OAuth redirect URLs in identity provider; install `apache-airflow-providers-fab`; update `webserver_config.py` imports

**Issue: SubDAGs error on load**
- Cause: SubDAGs completely removed in Airflow 3
- Fix: Refactor to TaskGroups (visual grouping) or Assets (cross-DAG dependencies)

**Issue: SLA callbacks not firing**
- Cause: SLA feature removed in Airflow 3
- Fix: Migrate to Deadline Alerts (available in Airflow 3.1+)

**Issue: Context variable KeyError (execution_date, etc.)**
- Cause: Deprecated context variables removed
- Fix: Replace `execution_date` with `logical_date`; replace `yesterday_ds/tomorrow_ds` with manual date calculations from `data_interval_start/end`

### Post-Upgrade Verification

1. Verify all DAGs load without import errors
2. Test connections to external systems
3. Trigger a sample DAG run and verify completion
4. Check the UI for proper rendering (DAG graph, grid view, asset views)
5. Verify SSO/authentication works
6. Confirm monitoring metrics are flowing
7. Run backfill of a test DAG to verify scheduler-managed backfill works
8. Test API endpoints if any external systems integrate with Airflow's API

---

## Sources

- [Airflow Tasks Documentation](https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/tasks.html)
- [Airflow Best Practices](https://airflow.apache.org/docs/apache-airflow/stable/best-practices.html)
- [Airflow FAQ](https://airflow.apache.org/docs/apache-airflow/stable/faq.html)
- [Upgrading to Airflow 3](https://airflow.apache.org/docs/apache-airflow/stable/installation/upgrading_to_airflow3.html)
- [Kubernetes Executor Documentation](https://airflow.apache.org/docs/apache-airflow-providers-cncf-kubernetes/stable/kubernetes_executor.html)
- [Astronomer - Clean Up Metadata DB](https://www.astronomer.io/docs/learn/2.x/cleanup-dag-tutorial)
- [Astronomer - Upgrading Checklist](https://www.astronomer.io/blog/upgrading-airflow-2-to-airflow-3-a-checklist-for-2026/)
- [Google Cloud - Troubleshooting DAGs](https://cloud.google.com/composer/docs/composer-2/troubleshooting-dags)
- [AWS - Metadata DB Cleanup on MWAA](https://docs.aws.amazon.com/mwaa/latest/userguide/samples-database-cleanup.html)
- [Zombie Task Troubleshooting (Medium)](https://medium.com/@shakik19/troubleshooting-zombie-task-job-errors-in-apache-airflow-5527303dbcad)
- [Airflow Maintenance and Optimisation (Medium)](https://lshw.medium.com/apache-airflow-maintenance-and-optimisation-1532b953527)
