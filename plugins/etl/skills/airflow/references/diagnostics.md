# Airflow Diagnostics

## Zombie Tasks

### What They Are

Tasks stuck in "running" state after the actual process has died. The worker process was killed so suddenly (SIGKILL) that it could not report a failure, so heartbeats stop but the Scheduler does not immediately know why.

### Common Causes

1. **Resource exhaustion (most common):** Worker runs out of memory; the OS OOM killer terminates the process with SIGKILL
2. **Network partitions:** Lost connectivity between scheduler and worker nodes
3. **Container limits:** Kubernetes memory limits or Docker memory caps triggering OOM kills
4. **System crashes:** Unexpected worker node reboots or container eviction
5. **Misconfiguration:** `scheduler_zombie_task_threshold` too high; detection too slow

### Detection Configuration

- `zombie_detection_interval`: How often the scheduler checks (default: 10s)
- `scheduler_zombie_task_threshold`: Seconds since last heartbeat before zombie flag (default: 300)

### Resolution

1. Increase worker memory/CPU resources
2. Set `execution_timeout` on tasks to prevent indefinite runs
3. Reduce task concurrency (`max_active_tasks_per_dag`, pool sizes)
4. Use KubernetesExecutor for per-task resource isolation
5. Monitor worker resource utilization with system-level tools
6. For CeleryExecutor: ensure broker (Redis/RabbitMQ) is properly sized

## Scheduler Delays

### Symptoms

Tasks take a long time to move from "scheduled" to "running." DAG runs start late.

### Common Causes

1. **Too many DAGs or tasks:** Scheduler overwhelmed by scheduling decisions
2. **Slow DAG parsing:** Complex module-level code in DAG files
3. **Database bottleneck:** Slow queries against the Metadata Database
4. **Pool exhaustion:** All pool slots consumed; tasks wait in queue
5. **Executor saturation:** All executor slots consumed

### Diagnosis

- Check `scheduler.scheduler_loop_duration` metric (increasing = overload)
- Check `scheduler.tasks.starving` metric (tasks waiting for resources)
- Monitor database query performance (slow query log)
- Check DAG parse times: Admin > DAG Parse Times in the UI

### Resolution

- Increase `parallelism` if executor slots are the bottleneck
- Increase `min_file_process_interval` to reduce re-parsing frequency
- Optimize module-level code (zero I/O at import time)
- Scale up the metadata database (CPU, memory, IOPS)
- Use multiple scheduler instances (HA scheduler, 2.0+)
- Split DAGs across DAG bundles (Airflow 3)

## DAG Parsing Errors

### Symptoms

DAG does not appear in the UI; error shown in DAG Import Errors view.

### Common Causes

1. **Python syntax errors** in DAG files
2. **Import errors:** Missing packages, incorrect import paths
3. **Top-level exceptions:** Code at module level that raises (failed DB connections, missing files)
4. **Circular imports:** DAG files importing from each other
5. **Airflow 3 import changes:** Old paths that no longer work

### Diagnosis

- Airflow UI: Browse > DAG Import Errors
- CLI: `airflow dags list-import-errors`
- Local: `python dags/my_dag.py`
- Migration check: `ruff check dags/ --select AIR301`

### Prevention

- Run DAG validation tests in CI before deployment
- Use a `DagBag` test to catch import errors early
- Keep module-level code minimal and error-free
- Pin dependencies in requirements.txt

## Import Errors

### Common Causes

1. **Missing provider packages:** In Airflow 3, BashOperator and PythonOperator require `apache-airflow-providers-standard`
2. **Path issues:** Shared modules not on PYTHONPATH (missing `__init__.py` files)
3. **Version mismatches:** Provider package version incompatible with Airflow core
4. **Airflow 3 path changes:** `airflow.models.dag.DAG` moved to `airflow.sdk.DAG`, etc.

### Resolution

- Install required provider packages
- Verify PYTHONPATH includes `dags/`, `plugins/`, and `config/` directories
- Use `ruff check --select AIR301 --fix` to auto-fix import path changes
- Check provider compatibility matrix in Airflow documentation

## Executor-Specific Issues

### CeleryExecutor

**Queue depth issues:**
- Symptom: Tasks accumulate in broker queue; workers not consuming fast enough
- Diagnosis: Monitor broker queue depth (Redis: `LLEN`; RabbitMQ: management UI)
- Fix: Add workers, increase `worker_concurrency`, ensure broker has adequate resources

**Worker disconnections:**
- Symptom: Workers go offline; tasks fail with "received SIGTERM"
- Causes: Broker connection timeout, network issues, worker OOM
- Fix: Increase broker connection timeout, monitor worker memory, use `--autoscale`

**Task routing issues:**
- Symptom: Tasks sent to wrong queue or no worker picks them up
- Diagnosis: Check task `queue` parameter; verify worker listens to correct queue (`-Q <queue>`)
- Airflow 3 note: `@task` decorated tasks may not inherit `queue` from DAG defaults; set `executor` parameter explicitly

### KubernetesExecutor

**Pod failures:**
- OOMKilled: Memory limit exceeded. Increase `resources.limits.memory` in pod spec
- Image pull errors: Docker image not found or registry auth failed. Verify image name and pull secret
- Pod eviction: Node resource pressure. Set appropriate `requests` and `limits`

**Diagnosis commands:**
```bash
kubectl describe pod <pod-name>     # Check Events section
kubectl logs <pod-name>             # Container logs
kubectl get events --sort-by=.metadata.creationTimestamp  # Cluster events
```

**Pod startup latency:**
- Symptom: 30-60+ seconds from "queued" to "running"
- Fix: Lighter Docker images, pre-pull images on nodes, `imagePullPolicy: IfNotPresent`, reduce init container overhead

**Log loss:**
- Symptom: Task logs missing after pod completes or is evicted
- Fix: Configure remote logging (S3, GCS, Elasticsearch) -- essential for KubernetesExecutor

### Multiple Executors (Airflow 3)

**Task routing issues:**
- Known bug (3.0.x): Tasks with `queue='kubernetes'` not routed to KubernetesExecutor
- Workaround: Use the `executor` parameter on tasks instead of queue-based routing
- TaskFlow limitation: `@task` may not inherit `queue` from DAG defaults; set `executor` explicitly

## Database Maintenance

### Why Cleanup Matters

Airflow never automatically removes metadata. Production tables grow to tens of gigabytes, degrading scheduler, webserver, and UI performance. Performance noticeably degrades when tables exceed ~50 GB.

### Key Tables That Grow

| Table | Growth Driver |
|---|---|
| `task_instance` | Row per task execution (largest) |
| `dag_run` | Row per DAG run |
| `log` | Audit log entries |
| `xcom` | XCom values (especially with improper use) |
| `rendered_task_instance_fields` | Rendered templates per task instance |
| `task_fail` | Failed task records |
| `job` | Scheduler and worker job records |

### Cleanup Methods

**CLI (recommended):**
```bash
# Archive old data (safe -- data moved to _archive tables)
airflow db clean --clean-before-timestamp "2025-01-01"

# Drop the archive tables after verification
airflow db drop-archived

# Skip archival (permanently delete -- backup first!)
airflow db clean --clean-before-timestamp "2025-01-01" --skip-archive
```

**Maintenance DAG:** Schedule a periodic DAG to run `airflow db clean`. Multiple community-maintained cleanup DAGs exist.

**Direct SQL (use with caution):**
```sql
-- Check table sizes (PostgreSQL)
SELECT relname, pg_size_pretty(pg_relation_size(relid))
FROM pg_catalog.pg_statio_user_tables
ORDER BY pg_relation_size(relid) DESC;
```

### Cleanup Best Practices

1. Always backup before cleanup (`pg_dump` or equivalent)
2. Schedule regular cleanup: weekly or monthly via maintenance DAG
3. Set retention policy (30, 60, or 90 days depending on audit requirements)
4. Run `ANALYZE` after cleanup to update database optimizer statistics
5. Monitor table sizes and alert when thresholds exceeded

### Log Management

- Configure `base_log_folder` with adequate disk space
- Use remote logging (S3, GCS, Elasticsearch) for long-term storage and KubernetesExecutor
- In containerized deployments: log to stdout, use cluster-level log aggregation (Fluentd, Filebeat)

## Debugging Techniques

### Task Logs

- **UI:** Click on task instance > Logs tab
- **CLI:** `airflow tasks logs <dag_id> <task_id> <execution_date>`
- **Remote logging:** Configure S3/GCS/Elasticsearch for centralized storage
- Include contextual information in task logs (record counts, file paths, duration)

### XCom Inspection

- **UI:** Admin > XComs (browse all entries) or task instance > XCom tab
- **CLI:** `airflow xcom list` or `airflow xcom get`
- Common issues: value too large (DB performance), serialization failure (not JSON-serializable), missing XCom (upstream exception before return)

### Trigger Rule Debugging

When a task does not run as expected, check:
1. What trigger rule is configured? (default: `all_success`)
2. What are the states of all upstream tasks?
3. Are any upstream tasks skipped? (`all_success` treats skipped as not-success)
4. Is `depends_on_past=True` blocking on a previous failed run?
5. Is the task in a branch that was not chosen?

Common fix: Use `trigger_rule="none_failed"` for tasks that should run regardless of branch choice.

### Rendered Templates

View actual values of Jinja-templated parameters:
- **UI:** Click on task instance > Rendered Template tab
- Useful for debugging SQL queries, file paths, and templated values
- In Airflow 3, rendered templates shown for the specific DAG version

## Migration Troubleshooting (2.x to 3.x)

### Pre-Upgrade Checks

```bash
airflow dags list-import-errors        # Check current DAG health
airflow dags reserialize               # Must complete without errors
ruff check dags/ --select AIR301,AIR302  # Find breaking changes
pip list | grep apache-airflow-providers  # Check provider compatibility
```

### Common Migration Issues

| Issue | Cause | Fix |
|---|---|---|
| DAG fails to load | Import path changes | `ruff check --select AIR301 --fix` |
| Custom operator DB access error | Direct metadata DB access removed | Refactor to REST API client |
| XCom deserialization failure | Pickling disabled in 3.x | Re-serialize as JSON |
| SSO/OAuth login fails | Redirect URLs need `/auth` prefix; FAB moved to provider | Update redirect URLs, install `apache-airflow-providers-fab` |
| SubDAG errors | SubDAGs completely removed | Refactor to TaskGroups or Assets |
| SLA callbacks not firing | SLA feature removed | Migrate to Deadline Alerts (3.1+) |
| Context variable KeyError | `execution_date` etc. removed | Use `logical_date`, `data_interval_start/end` |

### Migration Tool (Ruff)

```bash
# Check for breaking changes
ruff check dags/ --select AIR301

# Auto-fix safe changes
ruff check dags/ --select AIR301 --fix

# Auto-fix including unsafe changes (review carefully)
ruff check dags/ --select AIR301 --fix --unsafe-fixes
```

Rule categories:
- **AIR301, AIR302:** Breaking changes (must fix before upgrading)
- **AIR311, AIR312:** Recommended updates (not currently breaking)

### Post-Upgrade Verification

1. Verify all DAGs load without import errors
2. Test connections to external systems
3. Trigger a sample DAG run and verify completion
4. Check the UI rendering (DAG graph, grid view, asset views)
5. Verify SSO/authentication works
6. Confirm monitoring metrics are flowing
7. Test backfill via UI/API (scheduler-managed in 3.x)
8. Test API endpoints for external system integrations
