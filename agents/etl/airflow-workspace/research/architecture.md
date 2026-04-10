# Apache Airflow Architecture

## Core Components

### Scheduler

The Scheduler is the central orchestration engine of Airflow. It is a persistent background process that:

- Continuously parses DAG files from configured DAG bundles (local directories, Git repos, S3)
- Determines which tasks are ready for execution based on dependencies, trigger rules, and scheduling intervals
- Queues ready tasks and delegates them to the configured Executor
- Manages task state transitions and writes all state changes to the Metadata Database
- Handles backfill operations (Airflow 3 moved backfills into the scheduler for better control)
- Detects zombie tasks via heartbeat monitoring (`zombie_detection_interval`, default 10 seconds)

Key configuration knobs: `parallelism`, `max_active_runs_per_dag`, `dag_dir_list_interval`, `min_file_process_interval`.

### API Server (Airflow 3) / Webserver (Airflow 2)

**Airflow 3:** The Webserver has been replaced by the **API Server** (`airflow api-server`), built on FastAPI. It serves:
- The completely rewritten React-based UI
- The REST API v2 (`/api/v2`) for programmatic access
- Authentication and authorization endpoints

**Airflow 2:** Used Flask/Flask-AppBuilder to serve the UI and REST API v1.

The API Server is optional for DAG execution -- the Scheduler and Executor can run DAGs without it -- but it is essential for monitoring, triggering, and management.

### Workers

Workers are the processes or containers that actually execute task code. Their nature depends on the Executor:
- **LocalExecutor:** Worker processes are spawned on the same machine as the Scheduler
- **CeleryExecutor:** Separate worker processes (potentially on different machines) pull tasks from a message broker
- **KubernetesExecutor:** Each task runs in its own Kubernetes Pod

Workers interact with the Metadata Database for state updates (in Airflow 2 directly; in Airflow 3 via the API Server).

### Metadata Database

A relational database (PostgreSQL recommended; MySQL also supported) that stores:
- DAG definitions, DAG versions, and serialized DAG structures
- DAG runs and task instance states
- XCom values
- Connections, Variables, and Pools
- User accounts, roles, and permissions
- Audit logs and job history

**Airflow 3 architectural change:** The Metadata Database is now accessed exclusively through the API Server by tasks and workers. Direct database access from worker nodes has been removed, improving security and enabling task isolation.

Supported backends: PostgreSQL 13+ (recommended), MySQL 8.0+. SQLite is supported only for testing. PostgreSQL 12 and below dropped in Airflow 3.

### DAG Processor

In Airflow 3, the DAG Processor can run as a separate process (`airflow dag-processor`) or remain embedded in the Scheduler. It:
- Reads and parses DAG files
- Serializes DAG structures into the Metadata Database
- Validates DAG integrity

### Triggerer

A separate process that runs Triggers (async event listeners) for deferrable operators. Instead of occupying a worker slot while waiting for an external condition, a deferred task hands off to the Triggerer, which uses asyncio to efficiently monitor many triggers concurrently. When the condition is met, the Triggerer re-queues the task.

---

## DAG Concepts

### DAGs (Directed Acyclic Graphs)

A DAG is a collection of tasks with defined dependencies, forming a directed graph with no cycles. DAGs define:
- **Schedule:** When to run (cron, timetable, asset-triggered, or manual-only)
- **Default arguments:** Shared parameters for all tasks (retries, retry_delay, owner, etc.)
- **Catchup behavior:** Whether to backfill missed runs (`catchup=False` is the default in Airflow 3)

### Tasks

A Task is a unit of work within a DAG. Tasks can be defined using:
- **Operators:** Pre-built task templates (BashOperator, PythonOperator, etc.)
- **TaskFlow API:** Python functions decorated with `@task` (recommended approach in Airflow 3)
- **Sensors:** Special operators that wait for an external condition

### Operators

Operators define what a task does. Categories include:
- **Action operators:** Perform an action (BashOperator, PythonOperator, EmailOperator)
- **Transfer operators:** Move data between systems (S3ToRedshiftOperator, etc.)
- **Sensor operators:** Wait for conditions (FileSensor, ExternalTaskSensor, HttpSensor)

In Airflow 3, common operators like BashOperator, PythonOperator, ExternalTaskSensor, and FileSensor have moved to the `apache-airflow-providers-standard` package.

### Sensors

Sensors are a specialized type of operator that wait (poll or use deferral) for an external condition to be met before proceeding. Modes:
- **poke:** Occupies a worker slot, periodically checking the condition
- **reschedule:** Releases the worker slot between checks, re-queued by the Scheduler
- **Deferrable sensors:** Hand off to the Triggerer process for async waiting (most efficient)

### Hooks

Hooks are interfaces to external systems (databases, APIs, cloud services). They abstract connection management and are used internally by operators. Examples: PostgresHook, S3Hook, HttpHook. Hooks encourage code reuse -- build a Hook, then multiple operators can use it.

### Connections

Connections store credentials and connection parameters for external systems. Stored in:
- The Metadata Database (default)
- Environment variables (AIRFLOW_CONN_*)
- Secrets backends (Vault, AWS Secrets Manager, GCP Secret Manager)

Each connection has: conn_id, conn_type, host, schema, login, password, port, and extra (JSON for additional parameters).

### Pools

Pools limit the number of concurrent task instances across all DAGs. Use cases:
- Limiting concurrent database connections
- Throttling API calls to avoid rate limits
- Controlling resource utilization

Each pool has a configurable number of slots. Tasks can be assigned to a pool and consume a configurable number of slots.

### XCom (Cross-Communication)

XCom enables tasks to exchange small amounts of data. Key characteristics:
- Push/pull model: tasks push values, downstream tasks pull them
- TaskFlow API handles XCom automatically via return values
- **Size limitations:** Designed for small values (metadata, file paths, counts) -- NOT for large datasets
- Default backend stores XCom in the Metadata Database
- Custom backends available for larger payloads (S3, GCS, etc.)
- **Airflow 3:** XCom pickling is no longer allowed with the default backend (security improvement)

---

## Executor Types

### LocalExecutor (Default in Airflow 3)

- Runs tasks as subprocesses on the same machine as the Scheduler
- Supports parallelism (multiple concurrent tasks)
- Good for: development, small-to-medium workloads, single-machine deployments
- **Note:** SequentialExecutor and DebugExecutor were removed in Airflow 3

### CeleryExecutor

- Distributes tasks to a pool of Celery workers via a message broker (Redis or RabbitMQ)
- Supports horizontal scaling by adding worker machines
- Good for: medium-to-large workloads, when you need distributed execution
- Trade-offs: Requires maintaining broker infrastructure; workers need Airflow + all dependencies installed

### KubernetesExecutor

- Runs each task instance in its own Kubernetes Pod
- Full task isolation: each task gets its own container with specified resources and dependencies
- Good for: heterogeneous workloads, strong isolation requirements, cloud-native deployments
- Trade-offs: Slower task startup (pod spin-up time), requires Kubernetes cluster

### Edge Executor (New in Airflow 3)

- Enables task execution on edge devices and remote environments outside core data centers
- Available as a provider package
- Good for: IoT pipelines, hybrid cloud, restricted network environments

### Multiple Executors Concurrently (Airflow 2.10+ / Airflow 3)

- Configure multiple executor classes via `core.executor` as a comma-separated list
- First executor in the list is the default
- Assign specific tasks to non-default executors via the `executor` parameter on the task
- Replaces the removed CeleryKubernetesExecutor and LocalKubernetesExecutor hybrid classes

---

## Task Lifecycle

### Task States

```
none -> scheduled -> queued -> running -> success
                                      \-> failed -> up_for_retry -> scheduled ...
                                      \-> upstream_failed
                                      \-> skipped
                                      \-> deferred -> scheduled ...
                                      \-> removed
```

Key states:
- **none:** Task has not been queued yet (dependencies not met or not scheduled)
- **scheduled:** Scheduler has determined the task is ready to run
- **queued:** Task has been sent to the Executor
- **running:** Task is actively executing on a worker
- **success:** Task completed successfully
- **failed:** Task raised an exception or timed out
- **up_for_retry:** Task failed but has retries remaining
- **skipped:** Task was skipped (e.g., by a branch operator or trigger rule)
- **upstream_failed:** An upstream dependency failed (and trigger rule requires it to succeed)
- **deferred:** Task is waiting asynchronously via the Triggerer
- **removed:** Task was removed from the DAG after it was scheduled

### Retries

- `retries`: Maximum number of retry attempts (default: 0)
- `retry_delay`: Time between retries (default: timedelta(minutes=5))
- `retry_exponential_backoff`: Double the delay on each retry (bool in Airflow 2/3.0; float multiplier in Airflow 3.2+)
- `max_retry_delay`: Cap on the retry delay
- `on_retry_callback`: Function called when a task retries

### depends_on_past

When `depends_on_past=True`, a task can only run if the same task in the previous DAG run succeeded or was skipped. The first run always proceeds since there is no prior run to depend on.

### Trigger Rules

Control when a task runs based on upstream task states:
- **all_success** (default): All upstream tasks succeeded
- **all_failed:** All upstream tasks failed or have upstream failures
- **all_done:** All upstream tasks completed (any state)
- **all_skipped:** All upstream tasks were skipped
- **one_success:** At least one upstream task succeeded
- **one_failed:** At least one upstream task failed
- **one_done:** At least one upstream task completed
- **none_failed:** No upstream tasks failed (success or skipped)
- **none_failed_min_one_success:** No upstream failures, at least one success
- **none_skipped:** No upstream tasks were skipped
- **always:** Run regardless of upstream states

---

## Scheduling Concepts

### Timetables

Timetables define when DAG runs are created. Built-in options:
- **CronTriggerTimetable:** Standard cron expressions (default cron behavior in Airflow 3)
- **DeltaDataIntervalTimetable:** Fixed intervals (e.g., every 30 minutes)
- **DatasetOrTimeSchedule:** Combine asset-triggered and time-based scheduling (Airflow 2.9+)
- Custom timetables can be created by subclassing `Timetable`

### Data-Aware Scheduling (Assets/Datasets)

DAGs can be triggered by asset (formerly "dataset") updates:
- Producer DAGs declare which assets they update via `outlets`
- Consumer DAGs declare `schedule=[asset1, asset2]` to trigger when assets are updated
- Supports AND/OR logic for multiple asset dependencies
- **Airflow 3.0:** Datasets renamed to Assets; new asset-centric syntax with decorators; Watchers for external asset events
- **Airflow 3.2:** Asset partitioning -- trigger based on specific partitions of data, not just the entire asset

### Event-Driven Scheduling (Airflow 3.0+)

Airflow can react to events from external systems:
- Integration with message queues (initial AWS SQS support)
- Asset Watchers monitor external systems for asset creation/updates
- Enables reactive pipelines without polling

---

## Dynamic DAGs

### TaskFlow API

The recommended way to write DAGs in Airflow 3:

```python
from airflow.sdk import dag, task

@dag(schedule="@daily")
def my_pipeline():
    @task
    def extract():
        return {"data": [1, 2, 3]}

    @task
    def transform(data):
        return [x * 2 for x in data["data"]]

    @task
    def load(data):
        print(f"Loading {data}")

    raw = extract()
    transformed = transform(raw)
    load(transformed)

my_pipeline()
```

Benefits: Implicit XCom handling, cleaner Python-native syntax, better type hints (Airflow 3), asset-based programming support.

### Dynamic Task Mapping

Create a variable number of task instances at runtime based on upstream task output:

```python
@task
def get_files():
    return ["file1.csv", "file2.csv", "file3.csv"]

@task
def process_file(filename):
    # Process each file
    pass

files = get_files()
process_file.expand(filename=files)
```

- The scheduler determines the number of mapped instances at runtime
- Supports mapping over task groups
- Can use `.partial()` to set constant parameters and `.expand()` for varying ones
- Replaces manual for-loop DAG generation for many use cases

### Branch Operators

Conditional execution paths within a DAG:
- `@task.branch`: Decorated function returns the task_id(s) to execute
- `BranchPythonOperator`: Traditional operator-based branching
- Tasks not on the chosen branch are marked as `skipped`
- Cannot branch on mapped task results directly, but can branch based on task group inputs

---

## Connections and Providers

### Provider Packages

Airflow's integration ecosystem is modular via provider packages:
- ~80+ provider packages for AWS, GCP, Azure, Snowflake, dbt, Slack, etc.
- Each provider can include: operators, hooks, sensors, connections, secrets backends, auth managers
- Providers are versioned independently from Airflow core
- **Airflow 3:** Many core operators moved to `apache-airflow-providers-standard`

### Connection Types

Each provider defines connection types that appear in the UI. Common types:
- `postgres`, `mysql`, `sqlite` (databases)
- `aws`, `google_cloud_platform`, `azure` (cloud)
- `http`, `ssh`, `ftp` (protocols)
- `slack`, `smtp` (notifications)

---

## Security

### RBAC (Role-Based Access Control)

- **Airflow 3:** Default auth manager changed to SimpleAuthManager; FAB-based RBAC requires installing `apache-airflow-providers-fab`
- Built-in roles: Admin, User, Viewer, Op, Public
- Custom roles with granular permissions on DAGs, connections, variables, pools
- DAG-level access control: restrict users to specific DAGs

### Authentication Integration

- **OAuth/OIDC:** Supported via FAB provider (Google, GitHub, Azure AD, Okta, etc.)
- **LDAP:** Supported via FAB provider
- **Kerberos:** Supported for Hadoop ecosystem integration
- **Airflow 3:** OAuth redirect URLs now prefixed with `/auth` route

### Task Isolation (Airflow 3)

- Workers no longer have direct database access
- Tasks communicate through the API Server
- DAG authors cannot run arbitrary database queries
- Improved security for multi-team shared deployments

---

## Deployment Options

### Docker / Docker Compose

- Official Docker image: `apache/airflow`
- Docker Compose files provided for local development
- Good for: development, testing, small deployments

### Kubernetes (Helm Chart)

- Official Helm chart maintained by Airflow PMC
- Requires Kubernetes 1.30+
- Supports all executor types
- Features: Git-sync for DAGs (Airflow 2) or DAG bundles (Airflow 3), log persistence, scaling
- Community Helm chart also available with different design philosophy

### DAG Bundles (Airflow 3)

New mechanism for DAG file sourcing:
- **Local bundles:** Traditional local directory
- **Git bundles:** Fetch DAGs directly from Git repos (replaces git-sync sidecars)
- **S3 bundles:** Load DAGs from S3 buckets (no versioning support)
- Configured via `dag_bundle_config_list`

### Managed Services

| Service | Provider | Executor Support | Key Characteristics |
|---------|----------|-----------------|---------------------|
| **MWAA** | AWS | Celery (Airflow 2), more options in 3 | Fully managed, VPC integration, S3 for DAGs |
| **Cloud Composer** | GCP | Kubernetes-based | GKE-based, integrated with GCP services |
| **Astronomer** | Astronomer | Local, Celery, Kubernetes | Full control, Helm-based, Astro CLI |

### Key Trade-offs

- **MWAA / Cloud Composer:** Easier setup, limited configuration options, cloud-vendor lock-in
- **Astronomer:** More control over executor and infrastructure, but requires more operational knowledge
- **Self-managed Kubernetes:** Maximum flexibility, highest operational burden

---

## Sources

- [Apache Airflow 3 is Generally Available](https://airflow.apache.org/blog/airflow-three-point-oh-is-here/)
- [Airflow 3.2.0 Architecture Overview](https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/overview.html)
- [Upgrading to Airflow 3](https://airflow.apache.org/docs/apache-airflow/stable/installation/upgrading_to_airflow3.html)
- [Executor Documentation](https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/executor/index.html)
- [DAG Bundles Documentation](https://airflow.apache.org/docs/apache-airflow/stable/administration-and-deployment/dag-bundles.html)
- [Airflow Task SDK Documentation](https://airflow.apache.org/docs/task-sdk/stable/index.html)
- [Astronomer - Airflow Executors Explained](https://www.astronomer.io/docs/learn/airflow-executors-explained/)
- [Airflow Helm Chart](https://airflow.apache.org/docs/helm-chart/stable/index.html)
