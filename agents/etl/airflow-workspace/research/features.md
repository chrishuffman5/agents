# Apache Airflow Version Features

## Airflow 2.x Feature Timeline (EOL April 2026)

### Airflow 2.0 (December 2020) -- Foundation
- **TaskFlow API:** Write DAGs using `@dag` and `@task` decorators instead of explicit operator instantiation
- **Full REST API:** Programmatic access to Airflow resources
- **Smart Sensors:** Batch-process sensor tasks to reduce resource consumption (later superseded by deferrable operators)
- **Scheduler HA:** Run multiple scheduler instances for high availability
- **Simplified UI:** Improved DAG views and navigation

### Airflow 2.2 (October 2021)
- **Deferrable Operators and Triggers:** Tasks can defer to the Triggerer process for async waiting, freeing up worker slots
- **Custom Timetables:** Replace the rigid cron-only scheduling with pluggable timetable classes

### Airflow 2.3 (April 2022)
- **Dynamic Task Mapping:** Create variable numbers of task instances at runtime based on upstream output
- **Grid View:** Replaced Tree View with a more intuitive grid visualization of DAG runs and task states

### Airflow 2.4 (September 2022)
- **Data-Aware Scheduling (Datasets):** DAGs can trigger based on upstream dataset updates, enabling event-driven pipelines
- **`@task.bash` decorator:** Inline bash task definition via TaskFlow

### Airflow 2.5 (December 2022)
- Multiple `@task` decorator improvements
- Dataset UI view improvements

### Airflow 2.6 (April 2023)
- **Notifier classes:** Abstraction for sending notifications (Slack, email, etc.) on task/DAG events
- Improved Dataset event handling

### Airflow 2.7 (August 2023)
- **Setup and Teardown tasks:** Define resource provisioning/cleanup tasks that run regardless of main task outcome
- Cluster Activity tab in the UI

### Airflow 2.8 (December 2023)
- **Object Storage API:** Unified interface for interacting with cloud object stores (S3, GCS, Azure Blob)
- **`@task.sensor` decorator:** Define sensors inline using TaskFlow
- Listener hooks for plugins

### Airflow 2.9 (April 2024)
- **DatasetOrTimeSchedule:** Combine dataset-triggered and time-based scheduling in a single timetable
- Improved Dataset conditional logic (AND/OR dependencies)
- UI improvements for Dataset views

### Airflow 2.10 (September 2024)
- **Multiple Executors:** Configure multiple executor classes and assign tasks to specific executors
- Further Dataset improvements
- Last 2.x feature release before 3.0

---

## Airflow 3.x Feature Timeline (Current)

### Airflow 3.0 (April 2025) -- Major Rewrite

The most significant release in Airflow's history. Four years of development with 300+ contributors.

#### Architecture Overhaul

**Task Execution Interface (AIP-72)**
- Client-server architecture: tasks communicate with Airflow via the API Server, not direct database access
- Enables remote execution across any environment
- Foundation for multi-language Task SDKs (Python first, Golang planned)
- Workers no longer need database credentials or network access to the Metadata DB

**API Server**
- Replaces the Flask-based Webserver with a FastAPI-based API Server
- Serves both the new UI and the REST API v2
- Single access point for the Metadata DB from tasks/workers
- Command: `airflow api-server` (replaces `airflow webserver`)

**DAG Processor Separation**
- Can run as an independent process: `airflow dag-processor`
- Better resource isolation between DAG parsing and scheduling

#### DAG Versioning (AIP-65, AIP-66) -- Most Requested Feature

- DAG structure changes are tracked in the Metadata Database
- A running DAG completes using the version that was active when it started, even if a new version is deployed mid-run
- Historical DAG structures visible in UI and API
- The "Code" tab shows the exact DAG source for the specific version

#### DAG Bundles

New mechanism for DAG file sourcing:
- **Local bundles:** Traditional local directories
- **Git bundles:** Native Git repository integration (replaces git-sync sidecars)
- **S3 bundles:** Load DAGs from S3 (no versioning)
- Configured via `dag_bundle_config_list`

#### New React UI

- Completely rewritten from scratch using React and FastAPI
- Unified asset-oriented and task-oriented workflow navigation
- Improved Grid and Graph views with DAG version context
- Asset relationships visible from DAG details page
- Faster, more responsive, better filtering and search

#### Assets (formerly Datasets) (AIP-74, AIP-75)

- "Datasets" renamed to "Assets" to align with industry terminology
- New asset-centric syntax using Python decorators
- **Watchers:** Monitor external systems for asset creation/updates
- Improved internal model for future features (partitions, validations)

#### Event-Driven Scheduling (AIP-82)

- React to events from external systems
- Initial AWS SQS integration
- Asset Watchers enable reactive pipelines without polling

#### Backfill Improvements (AIP-78)

- Scheduler-managed backfills (moved from CLI to scheduler)
- Start backfills from UI or API
- Monitor backfill progress in UI
- Reduced database load during backfill operations
- Better isolation between backfill and real-time execution

#### Inference Support (AIP-83)

- Removed execution_date unique constraints
- Enables non-data-interval DAGs for ML inference and hyperparameter tuning
- Better support for ML/AI workflows (30% of users now use Airflow for MLOps)

#### Security Changes

- DAG authors cannot directly access the database or run arbitrary queries
- Task isolation via API-based communication
- Flask AppBuilder moved to separate provider package (AIP-79)
- Default auth manager changed to SimpleAuthManager
- XCom pickling disabled by default for security
- CLI split: local CLI remains, remote operations via `airflowctl` provider

#### Edge Executor

- Execute tasks on edge devices outside core data centers
- Available as a provider package
- Supports IoT and hybrid cloud scenarios

#### Removed Features

| Feature | Replacement |
|---------|-------------|
| SequentialExecutor | LocalExecutor |
| DebugExecutor | LocalExecutor |
| SubDAGs | TaskGroups, Assets |
| CeleryKubernetesExecutor | Multiple Executors Concurrently |
| LocalKubernetesExecutor | Multiple Executors Concurrently |
| SLA feature | Deadline Alerts |
| REST API v1 | REST API v2 (FastAPI) |
| `execution_date` context key | `logical_date` |
| `tomorrow_ds`, `yesterday_ds`, etc. | Manual date math or `data_interval_start/end` |
| `enable_xcom_pickling` config | JSON serialization only (default backend) |
| `--subdir` CLI argument | DAG bundles |
| Direct DB access from tasks | API Server / REST API |

#### Removed Context Variables

The following Jinja template / context variables no longer exist:
- `execution_date` -> use `logical_date`
- `next_execution_date`, `prev_execution_date` -> removed
- `tomorrow_ds`, `tomorrow_ds_nodash` -> removed
- `yesterday_ds`, `yesterday_ds_nodash` -> removed
- `prev_ds`, `prev_ds_nodash`, `next_ds`, `next_ds_nodash` -> removed

#### Import Path Changes

| Old Import | New Import |
|------------|-----------|
| `airflow.decorators.dag` | `airflow.sdk.dag` |
| `airflow.decorators.task` | `airflow.sdk.task` |
| `airflow.models.dag.DAG` | `airflow.sdk.DAG` |
| `airflow.models.baseoperator.BaseOperator` | `airflow.sdk.BaseOperator` |
| `airflow.sensors.base.BaseSensorOperator` | `airflow.sdk.BaseSensorOperator` |
| `airflow.datasets.Dataset` | `airflow.sdk.Asset` |
| `airflow.models.connection.Connection` | `airflow.sdk.Connection` |
| `airflow.models.variable.Variable` | `airflow.sdk.Variable` |

Legacy imports show deprecation warnings in Airflow 3.1; removal planned for future versions.

#### Configuration Changes

- `catchup_by_default`: Changed to `False`
- `create_cron_data_intervals`: Changed to `False` (uses CronTriggerTimetable)
- Auth manager default: SimpleAuthManager (FAB requires provider installation)
- Python 3.8 dropped (requires 3.9+)
- PostgreSQL 12 dropped (requires 13+)

---

### Airflow 3.1 (September 2025)

#### Human-in-the-Loop (HITL) Workflows (AIP-90)

Major new capability enabling user interaction during DAG execution:
- **Branch selection:** Users can choose which branch of a workflow to execute mid-run
- **Approval gates:** Approve or reject task outputs before proceeding
- **Text input:** Provide input values consumed by subsequent tasks
- All interactions happen through the UI during a live DAG run

#### Internationalization (i18n)

- UI translated into 17 languages
- Community-contributed translations

#### Deadline Alerts

- Define deadlines for DAG runs and task instances
- Receive alerts when deadlines are at risk or missed
- Replaces the removed SLA feature with a more flexible system

#### React Plugin System

- Extend the Airflow UI with custom React components
- Plugin framework for building custom views and dashboards

---

### Airflow 3.2 (April 2026) -- Current Stable

#### Asset Partitioning

The headline feature -- a major evolution of data-aware scheduling:
- Partitions are named slices of an asset (string key attached to an asset event)
- Airflow tracks asset state at the partition level
- Only the relevant data partition triggers downstream work
- Enables granular, efficient pipeline orchestration
- Example: only re-process the `date=2026-04-09` partition of a daily asset

#### Multi-Team Deployments

Enterprise-scale isolation within a single Airflow deployment:
- Each team gets its own DAGs, connections, variables, pools, and executors
- True resource and permission isolation
- Eliminates the need for separate Airflow instances per team
- Significant operational cost savings for large organizations

#### Synchronous Deadline Alert Callbacks

- Building on the Deadline Alerts from 3.1
- Synchronous callbacks execute directly via the executor
- Optional targeting of a specific executor via the `executor` parameter

#### Task SDK Separation Progress

- Continued work toward full separation of the Task SDK from Airflow core
- Improved portability and language-agnostic execution
- `retry_exponential_backoff` now accepts a float to specify custom multiplier factor

---

## Key Differences Between 2.x and 3.x for ETL Teams

### What Changes Day-to-Day

| Aspect | Airflow 2.x | Airflow 3.x |
|--------|-------------|-------------|
| **DAG writing** | `airflow.decorators` or `airflow.models` | `airflow.sdk` (recommended) |
| **Dataset/Asset references** | `Dataset("s3://...")` | `Asset("s3://...")` |
| **UI experience** | Flask-based, separate views | React-based, unified asset+task views |
| **DAG deployment** | Git-sync sidecar or shared volume | DAG bundles (Git, S3, local) |
| **Backfills** | CLI-driven (`airflow dags backfill`) | UI/API-driven, scheduler-managed |
| **SLA monitoring** | `sla` parameter on tasks | Deadline Alerts |
| **Approval workflows** | External (custom sensors, manual triggers) | Native HITL (branch, approve, input) |
| **Multi-team** | Separate instances or DAG-level RBAC | Native multi-team isolation (3.2) |
| **Data partitions** | Manual partition management | Asset partitioning (3.2) |

### Migration Effort Considerations

1. **Import path changes:** Automated via Ruff linter rules (AIR301, AIR302)
2. **SubDAG replacement:** Requires manual refactoring to TaskGroups
3. **Direct DB access removal:** Biggest effort -- any custom operator or DAG that queries the Metadata DB needs refactoring to use the REST API
4. **execution_date removal:** Replace with `logical_date` or `data_interval_start/end`
5. **Provider package updates:** Install `apache-airflow-providers-standard` for BashOperator, PythonOperator, etc.
6. **Auth/SSO reconfiguration:** Update OAuth redirect URLs (now `/auth` prefixed), install FAB provider if using RBAC
7. **New environment recommended:** Migration documentation recommends creating a new environment rather than in-place upgrade

### Migration Tool

The DAG upgrade check utility uses Ruff with AIR rules (requires Ruff 0.13.1+):
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

---

## Sources

- [Apache Airflow 3 is Generally Available](https://airflow.apache.org/blog/airflow-three-point-oh-is-here/)
- [Airflow 3.2.0 Release Blog](https://airflow.apache.org/blog/airflow-3.2.0/)
- [Airflow 3.2.0 Release Notes](https://airflow.apache.org/docs/apache-airflow/stable/release_notes.html)
- [Upgrading to Airflow 3](https://airflow.apache.org/docs/apache-airflow/stable/installation/upgrading_to_airflow3.html)
- [Astronomer - Upgrading Airflow 2 to 3 Checklist](https://www.astronomer.io/blog/upgrading-airflow-2-to-airflow-3-a-checklist-for-2026/)
- [Astronomer - Introducing Airflow 3.1](https://www.astronomer.io/blog/introducing-apache-airflow-3-1/)
- [Astronomer - Introducing Airflow 3.2](https://www.astronomer.io/blog/apache-airflow-3-2-release/)
- [Astronomer - Upgrade from Airflow 2 to 3](https://www.astronomer.io/docs/learn/airflow-upgrade-2-3)
- [NextLytics - Airflow Updates 2025](https://www.nextlytics.com/blog/apache-airflow-updates-2025-a-deep-dive-into-features-added-after-3.0)
- [AWS - Best Practices Migrating Airflow 2.x to 3.x on MWAA](https://aws.amazon.com/blogs/big-data/best-practices-for-migrating-from-apache-airflow-2-x-to-apache-airflow-3-x-on-amazon-mwaa/)
- [DataCamp - Airflow 3.0 Overview](https://www.datacamp.com/blog/apache-airflow-3-0)
