# Airflow Architecture

## Scheduler Deep Dive

### Scheduler Loop

The Scheduler is a persistent background process that runs in a continuous loop:

1. **DAG File Discovery** -- Scans configured DAG directories (or DAG bundles in 3.x) for new/changed files every `dag_dir_list_interval` seconds (default: 300)
2. **DAG Parsing** -- Parses each DAG file at least every `min_file_process_interval` seconds (default: 30). The DAG Processor can run embedded in the Scheduler or as a separate process (`airflow dag-processor` in 3.x)
3. **DAG Serialization** -- Serialized DAG structures are stored in the Metadata Database. The Webserver/API Server reads serialized DAGs (never parses DAG files directly)
4. **Scheduling Decision** -- For each active DAG run, the Scheduler evaluates task dependencies, trigger rules, pools, and concurrency limits to determine which tasks are ready
5. **Task Queuing** -- Ready tasks are queued with the configured Executor
6. **Heartbeat Monitoring** -- Running tasks send heartbeats; the Scheduler detects zombies when heartbeats stop (checked every `zombie_detection_interval` seconds, default: 10)
7. **State Transitions** -- The Scheduler updates task states based on executor callbacks and heartbeat checks

### Scheduler Configuration

| Parameter | Description | Default | Impact |
|---|---|---|---|
| `parallelism` | Max concurrent task instances across all DAGs | 32 | Global concurrency ceiling |
| `max_active_runs_per_dag` | Max concurrent runs per DAG | 16 | Prevents runaway catchup |
| `max_active_tasks_per_dag` | Max concurrent tasks per DAG run | 16 | Per-DAG resource control |
| `min_file_process_interval` | Min seconds between re-parsing a DAG file | 30 | Lower = faster DAG updates, higher CPU |
| `dag_dir_list_interval` | Seconds between scanning for new DAG files | 300 | Lower = faster new DAG discovery |
| `scheduler_heartbeat_sec` | Scheduler heartbeat interval | 5 | Rarely needs changing |
| `zombie_detection_interval` | Seconds between zombie detection runs | 10 | Balance detection speed vs CPU |
| `scheduler_zombie_task_threshold` | Seconds since last heartbeat before zombie | 300 | Lower = faster zombie detection, risk of false positives |
| `dagbag_import_timeout` | Max seconds to import a DAG file | 30 | Increase for legitimately slow DAG imports |

### Scheduler HA (High Availability)

Available since Airflow 2.0. Multiple scheduler instances can run concurrently:
- Schedulers use database row-level locking to coordinate
- Only one scheduler processes a given DAG file at a time
- HA improves fault tolerance, not throughput (scheduling is DB-bound)
- No external coordination service needed (unlike Celery which needs a broker)

### DAG Processor Separation (Airflow 3.x)

The DAG Processor can run as a separate process: `airflow dag-processor`
- Isolates DAG parsing from scheduling decisions
- Prevents slow/buggy DAG files from blocking the scheduler loop
- Useful when DAG files contain heavy import chains or numerous files
- Shares the Metadata Database with the Scheduler

## Executor Types

### LocalExecutor

- Tasks run as subprocesses on the Scheduler machine
- Supports parallelism (controlled by `parallelism` setting)
- Default executor in Airflow 3.x
- Process-based isolation only (shared filesystem, shared memory space)
- **Removed in Airflow 3:** SequentialExecutor and DebugExecutor (use LocalExecutor instead)

### CeleryExecutor

- Distributes tasks via a message broker (Redis or RabbitMQ)
- Workers pull tasks from named queues, execute them, and report results
- Workers must have Airflow installed with all task dependencies
- Horizontal scaling: add workers to increase capacity
- **Broker sizing matters:** Undersized Redis/RabbitMQ causes task loss and disconnections
- `worker_concurrency` controls how many tasks each worker runs concurrently (default: 16)
- `--autoscale` flag enables dynamic worker scaling based on load

### KubernetesExecutor

- Each task instance runs in a dedicated Kubernetes Pod
- Full task isolation: separate container, dedicated resources, independent dependencies
- Pod spec can be customized per task via `executor_config` or `pod_override`
- Pod startup overhead: 10-60 seconds depending on image size and cluster load
- **Remote logging is essential** -- pod logs are ephemeral; configure S3/GCS/Elasticsearch logging
- Resource requests/limits should always be set to prevent OOMKill and ensure scheduling

```python
@task(
    executor_config={
        "pod_override": k8s.V1Pod(
            spec=k8s.V1PodSpec(
                containers=[k8s.V1Container(
                    name="base",
                    resources=k8s.V1ResourceRequirements(
                        requests={"memory": "512Mi", "cpu": "250m"},
                        limits={"memory": "1Gi", "cpu": "500m"},
                    ),
                )]
            )
        )
    }
)
def heavy_task():
    # Runs in its own pod with dedicated resources
    pass
```

### Edge Executor (Airflow 3.x)

- Executes tasks on edge devices outside the core data center
- Available as a provider package (`apache-airflow-providers-edge`)
- Use cases: IoT data collection, on-premise systems behind firewalls, hybrid cloud
- Workers register with the API Server and pull tasks assigned to them

### Multiple Executors Concurrently (2.10+ / 3.x)

- Configure multiple executor classes via `core.executor` as a comma-separated list
- First executor in the list is the default
- Assign specific tasks to non-default executors via the `executor` parameter
- Replaces removed hybrid executors (CeleryKubernetesExecutor, LocalKubernetesExecutor)
- **Known issue (3.0.x):** Queue-based routing may not work correctly; use `executor` parameter explicitly

## Metadata Database

### Schema Overview

Key tables:

| Table | Purpose | Growth Pattern |
|---|---|---|
| `dag` | DAG metadata (schedule, owner, tags) | One row per DAG |
| `dag_run` | DAG run instances | One row per run (grows continuously) |
| `task_instance` | Task execution records | One row per task execution (largest table) |
| `xcom` | Inter-task data exchange | Grows with task count and XCom usage |
| `log` | Audit log entries | Grows with every action |
| `rendered_task_instance_fields` | Rendered Jinja templates | Parallel to task_instance |
| `connection` | External system credentials | Managed manually |
| `variable` | Key-value configuration | Managed manually |
| `pool` | Concurrency limit definitions | Managed manually |
| `serialized_dag` | Serialized DAG structures | One per DAG (updated on change) |

### Database Sizing

- Tables grow indefinitely without cleanup
- Performance degrades noticeably when tables exceed ~50 GB
- Regular cleanup is mandatory: `airflow db clean --clean-before-timestamp <date>`
- PostgreSQL recommended for production (better concurrency, JSON support, VACUUM)
- MySQL supported but requires careful `sql_alchemy_pool_size` tuning

### Airflow 3 Database Access Model

Tasks and workers no longer access the Metadata Database directly:
- All task-side database operations go through the API Server (REST API v2)
- Workers do not need database credentials or network access to the DB
- Improves security: DAG authors cannot run arbitrary SQL against the metadata DB
- Enables true task isolation in multi-team deployments

## DAG Parsing

### Parse Lifecycle

1. Scheduler discovers DAG files in configured locations
2. Python interpreter executes the file at module level
3. All DAG objects created during execution are registered
4. DAG structures are serialized to the Metadata Database
5. Webserver/API Server reads serialized DAGs (never touches DAG files)

### Parse Performance

- **Module-level code runs every parse cycle** -- This is the most common performance pitfall
- No database queries, API calls, or file reads at import time
- Keep DAG files lightweight: one DAG per file is ideal
- Complex import chains slow parsing for all DAGs in the file
- Monitor parse times: Admin > DAG Parse Times in the UI
- `dagbag_import_timeout` kills DAG files that take too long to parse (default: 30s)

### DAG Bundles (Airflow 3.x)

Replace traditional DAG folder scanning with structured bundle sources:

```ini
# airflow.cfg
[core]
dag_bundle_config_list = [
  {"name": "main", "classpath": "airflow.dag_bundles.local.LocalDagBundle", "kwargs": {"path": "/opt/airflow/dags"}},
  {"name": "team-a", "classpath": "airflow.dag_bundles.git.GitDagBundle", "kwargs": {"repo_url": "https://github.com/org/team-a-dags.git", "branch": "main"}},
  {"name": "team-b", "classpath": "airflow.dag_bundles.s3.S3DagBundle", "kwargs": {"bucket": "team-b-dags", "prefix": "dags/"}}
]
```

Bundle types:
- **LocalDagBundle** -- Traditional local directory
- **GitDagBundle** -- Clones and syncs a Git repository (replaces git-sync sidecars)
- **S3DagBundle** -- Fetches from S3 (no versioning support)

## Task Lifecycle

### State Machine

```
none ─────► scheduled ─────► queued ─────► running ─────► success
                                              │
                                              ├──► failed ──► up_for_retry ──► scheduled ...
                                              │
                                              ├──► deferred ──► trigger fires ──► scheduled ...
                                              │
                                              └──► upstream_failed
                                              └──► skipped
                                              └──► removed
```

### State Descriptions

| State | Meaning | Action |
|---|---|---|
| `none` | Not yet evaluated by scheduler | Wait for dependencies |
| `scheduled` | Dependencies met, ready to run | Scheduler will queue |
| `queued` | Sent to executor | Executor will assign to worker |
| `running` | Executing on a worker | Heartbeats sent to scheduler |
| `success` | Completed without error | Downstream tasks unblocked |
| `failed` | Raised exception or timed out | Check retries remaining |
| `up_for_retry` | Failed but has retries left | Waits for `retry_delay` then re-scheduled |
| `skipped` | Skipped by branch or trigger rule | Does not block downstream (depends on trigger rule) |
| `deferred` | Handed off to Triggerer | Triggerer monitors async condition |
| `upstream_failed` | Upstream task failed | Will not run (with default trigger rule) |
| `removed` | Task removed from DAG after scheduling | Cleanup state |

### Retry Configuration

```python
@task(
    retries=3,
    retry_delay=timedelta(minutes=5),
    retry_exponential_backoff=True,  # Double delay each retry (bool in 2.x/3.0; float multiplier in 3.2+)
    max_retry_delay=timedelta(hours=1),
    on_retry_callback=notify_on_retry,
)
def fragile_api_call():
    response = requests.get("https://api.example.com/data")
    response.raise_for_status()
    return response.json()
```

### Trigger Rules

Control when a task runs based on upstream states:

| Rule | Meaning |
|---|---|
| `all_success` (default) | All upstream tasks succeeded |
| `all_failed` | All upstream tasks failed |
| `all_done` | All upstream tasks completed (any state) |
| `one_success` | At least one upstream succeeded |
| `one_failed` | At least one upstream failed |
| `none_failed` | No upstream tasks failed (success or skipped OK) |
| `none_failed_min_one_success` | No failures and at least one success |
| `always` | Run regardless of upstream states |

**Common confusion:** Tasks downstream of a `@task.branch` get skipped if not on the chosen path. Use `trigger_rule="none_failed"` or `"none_failed_min_one_success"` for tasks that should run regardless of which branch was taken.

## Scheduling Concepts

### Timetables

| Timetable | Use Case |
|---|---|
| `CronTriggerTimetable` | Standard cron expressions (default in 3.x) |
| `DeltaDataIntervalTimetable` | Fixed intervals (every 30 minutes) |
| `DatasetOrTimeSchedule` | Combined data-aware + time-based (2.9+) |
| Custom `Timetable` subclass | Business days, market hours, fiscal calendar |

### Data-Aware Scheduling (Assets / Datasets)

Producer DAGs declare outlets; consumer DAGs trigger when assets update:

```python
# Producer
from airflow.sdk import Asset

sales_data = Asset("s3://data-lake/sales/daily")

@dag(schedule="@daily")
def produce_sales():
    @task(outlets=[sales_data])
    def export():
        # Write data to S3
        pass

# Consumer
@dag(schedule=[sales_data])
def consume_sales():
    @task
    def process():
        # Triggered when sales_data is updated
        pass
```

- Supports AND/OR logic for multiple asset dependencies
- **Airflow 3.0:** "Datasets" renamed to "Assets"; Watchers for external asset events
- **Airflow 3.2:** Asset partitioning (trigger on specific data partitions)

## Security Model

### Airflow 2.x
- Flask AppBuilder RBAC with built-in roles (Admin, User, Viewer, Op)
- DAG-level access control
- OAuth/OIDC via FAB configuration

### Airflow 3.x
- Default auth manager changed to SimpleAuthManager
- FAB-based RBAC requires `apache-airflow-providers-fab`
- Task isolation: workers have no direct database access
- Multi-team deployment isolation (3.2): separate DAGs, connections, variables, pools per team
- OAuth redirect URLs prefixed with `/auth`
- XCom pickling disabled by default (security hardening)

## Provider Packages

Airflow's integration ecosystem is modular via ~80+ provider packages:
- Each provider includes operators, hooks, sensors, connections, and potentially secrets backends
- Providers are versioned independently from Airflow core
- **Airflow 3:** Core operators (BashOperator, PythonOperator, FileSensor, ExternalTaskSensor) moved to `apache-airflow-providers-standard`
- Common providers: `amazon`, `google`, `microsoft-azure`, `snowflake`, `databricks`, `dbt-cloud`, `slack`, `ssh`
