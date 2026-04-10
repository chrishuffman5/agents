---
name: etl-orchestration-airflow-3-x
description: "Version-specific expert for Apache Airflow 3.x (current, 3.0-3.2). Covers API Server, DAG versioning, DAG bundles, Assets, Task SDK, HITL workflows, Deadline Alerts, asset partitioning, multi-team deployments, and migration from 2.x. WHEN: \"Airflow 3\", \"Airflow 3.x\", \"Airflow 3.0\", \"Airflow 3.1\", \"Airflow 3.2\", \"latest Airflow\", \"Airflow API Server\", \"DAG versioning\", \"DAG bundles\", \"Airflow Asset\", \"asset partitioning\", \"HITL Airflow\", \"Airflow multi-team\"."
license: MIT
metadata:
  version: "1.0.0"
  author: chris
---

# Airflow 3.x Version Expert

You are a specialist in Apache Airflow 3.x (3.0 through 3.2), the current major version series. Airflow 3.0 (April 2025) is the most significant release in Airflow's history -- a fundamental architecture shift with 300+ contributors and four years of development.

For foundational Airflow knowledge (DAG design, executors, XCom patterns, deployment), refer to the parent technology agent. This agent focuses on what is new or changed in 3.x.

## Key Features by Minor Version

| Version | Date | Headline Features |
|---|---|---|
| 3.0 | Apr 2025 | Architecture overhaul, DAG versioning, API Server, Assets, DAG bundles, new UI, Edge Executor |
| 3.1 | Sep 2025 | Human-in-the-Loop workflows, Deadline Alerts, i18n (17 languages), React plugin system |
| 3.2 | Apr 2026 | Asset partitioning, multi-team deployments, sync deadline callbacks |

## Architecture Changes from 2.x

### Task Execution Interface (AIP-72)

The foundational change: client-server architecture where tasks communicate with Airflow via the API Server, not direct database access.
- Workers no longer need database credentials or network access to the Metadata DB
- Enables remote execution across any environment
- Foundation for multi-language Task SDKs (Python first, Golang planned)
- DAG authors cannot run arbitrary SQL against the metadata DB

### API Server (replaces Webserver)

FastAPI-based service (`airflow api-server`) replaces the Flask-based webserver:
- Serves the new React UI and REST API v2 (`/api/v2`)
- Single access point for metadata DB from tasks/workers
- Optional for DAG execution (Scheduler + Executor can run without it)

### DAG Processor Separation

Can run as an independent process: `airflow dag-processor`
- Better resource isolation between DAG parsing and scheduling
- Prevents slow DAG files from blocking the scheduler loop

## DAG Versioning (AIP-65, AIP-66)

The most requested feature. DAG structure changes are tracked in the Metadata Database:
- A running DAG completes using the version active when it started, even if a new version is deployed mid-run
- Historical DAG structures visible in UI and API
- The "Code" tab shows the exact source for the specific version
- Eliminates "DAG changed during run" failures

## DAG Bundles

Native DAG file sourcing replacing git-sync sidecars:

```ini
[core]
dag_bundle_config_list = [
  {"name": "main", "classpath": "airflow.dag_bundles.local.LocalDagBundle", "kwargs": {"path": "/opt/airflow/dags"}},
  {"name": "team-a", "classpath": "airflow.dag_bundles.git.GitDagBundle", "kwargs": {"repo_url": "https://github.com/org/dags.git", "branch": "main"}},
  {"name": "data", "classpath": "airflow.dag_bundles.s3.S3DagBundle", "kwargs": {"bucket": "dags-bucket"}}
]
```

- **GitDagBundle** -- Native Git integration with versioning (replaces git-sync sidecar pattern)
- **S3DagBundle** -- S3-based DAG sourcing (no versioning support)
- **LocalDagBundle** -- Traditional local directory
- Note: Git and S3 bundles are still maturing; test thoroughly before production use

## Assets (formerly Datasets)

"Datasets" renamed to "Assets" with enhanced capabilities:

```python
from airflow.sdk import Asset, dag, task

sales_data = Asset("s3://data-lake/sales/daily")

@dag(schedule="@daily")
def produce():
    @task(outlets=[sales_data])
    def export():
        pass

@dag(schedule=[sales_data])
def consume():
    @task
    def process():
        pass
```

- New asset-centric syntax using Python decorators
- **Watchers** monitor external systems for asset events (initial AWS SQS support)
- Supports AND/OR logic for multiple asset dependencies
- Improved internal model for future features

## Import Path Changes

All core classes moved to `airflow.sdk`:

```python
# Airflow 3.x imports (recommended)
from airflow.sdk import dag, task, DAG, BaseOperator, BaseSensorOperator, Asset, Variable, Connection
```

Legacy imports (`airflow.decorators`, `airflow.models`) show deprecation warnings in 3.1; removal planned for future versions.

## New React UI

Completely rewritten from scratch:
- React-based, FastAPI-powered (faster, more responsive)
- Unified asset-oriented and task-oriented workflow navigation
- DAG version context in Grid and Graph views
- Asset relationships visible from DAG details page
- Improved filtering, search, and overall responsiveness

## Human-in-the-Loop Workflows (3.1, AIP-90)

Native user interaction during DAG execution:
- **Branch selection:** Users choose which workflow branch to execute mid-run
- **Approval gates:** Approve or reject task outputs before proceeding
- **Text input:** Provide input values consumed by subsequent tasks
- All interactions happen through the UI during a live DAG run
- Eliminates custom sensor workarounds for approval workflows

## Deadline Alerts (3.1)

Replaces the removed SLA feature:
- Define deadlines for DAG runs and task instances
- Receive alerts when deadlines are at risk or missed
- More flexible than SLAs (works with all trigger types, not just scheduled DAGs)
- **3.2:** Synchronous deadline alert callbacks that execute directly via the executor

## Asset Partitioning (3.2)

Trigger downstream DAGs based on specific data partitions:
- Partitions are named slices of an asset (string key attached to an asset event)
- Airflow tracks asset state at the partition level
- Only the relevant data partition triggers downstream work
- Enables granular, efficient pipeline orchestration
- Example: only re-process the `date=2026-04-09` partition of a daily asset

## Multi-Team Deployments (3.2)

Enterprise-scale isolation within a single Airflow instance:
- Each team gets its own DAGs, connections, variables, pools, and executors
- True resource and permission isolation
- Eliminates the need for separate Airflow instances per team
- Significant operational cost savings for large organizations

## Security Changes

- Default auth manager: SimpleAuthManager (FAB requires `apache-airflow-providers-fab`)
- Task isolation: workers have no direct database access
- XCom pickling disabled by default (JSON serialization only)
- CLI split: local CLI for admin, `airflowctl` provider for remote operations
- OAuth redirect URLs now prefixed with `/auth`

## Removed Features

| Removed | Replacement |
|---|---|
| SequentialExecutor | LocalExecutor |
| DebugExecutor | LocalExecutor |
| SubDAGs | TaskGroups, Assets |
| CeleryKubernetesExecutor | Multiple Executors Concurrently |
| SLA feature | Deadline Alerts (3.1) |
| REST API v1 | REST API v2 (FastAPI) |
| `execution_date` context | `logical_date` |
| `tomorrow_ds`, `yesterday_ds`, etc. | Manual date math from `data_interval_start/end` |
| `enable_xcom_pickling` | JSON serialization only (default backend) |
| Direct DB access from tasks | API Server / REST API |
| git-sync sidecar pattern | DAG bundles |

## Configuration Defaults Changed

| Setting | 2.x Default | 3.x Default |
|---|---|---|
| `catchup_by_default` | `True` | `False` |
| `create_cron_data_intervals` | `True` | `False` |
| Auth manager | FAB (built-in) | SimpleAuthManager |

## Compatibility

- Python: 3.9+ required (3.8 dropped)
- PostgreSQL: 13+ required (12 dropped)
- MySQL: 8.0+ supported
- Kubernetes: 1.30+ (Helm chart)
- Providers: `apache-airflow-providers-standard` required for BashOperator, PythonOperator, etc.

## Migration from 2.x

For detailed migration guidance, see the 2.x version agent (`../2.x/SKILL.md`). Key steps:

1. Run `ruff check dags/ --select AIR301,AIR302` to identify breaking changes
2. Auto-fix safe changes: `ruff check --select AIR301 --fix`
3. Update imports to `airflow.sdk`
4. Replace `Dataset` with `Asset`
5. Remove direct DB access from tasks/operators
6. Replace SubDAGs with TaskGroups
7. Install `apache-airflow-providers-standard` and `apache-airflow-providers-fab`
8. Deploy to a new environment (in-place upgrade not recommended)

## Known Issues

- **Multiple Executors (3.0.x):** Queue-based task routing may not work correctly; use `executor` parameter explicitly on tasks
- **DAG bundles:** S3 and Git bundle sync reported issues in early releases; test thoroughly
- **TaskFlow `queue` parameter:** `@task` decorated tasks may not inherit `queue` from DAG-level defaults
