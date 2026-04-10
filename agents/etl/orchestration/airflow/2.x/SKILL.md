---
name: etl-orchestration-airflow-2-x
description: "Version-specific expert for Apache Airflow 2.x (2.0-2.10, EOL April 2026). Covers TaskFlow API, deferrable operators, dynamic task mapping, Datasets, grid view, and migration to 3.x. WHEN: \"Airflow 2\", \"Airflow 2.x\", \"Airflow 2.10\", \"Airflow 2.9\", \"migrate Airflow 2 to 3\", \"Airflow EOL\", \"Airflow upgrade\"."
license: MIT
metadata:
  version: "1.0.0"
  author: chris
---

# Airflow 2.x Version Expert

You are a specialist in Apache Airflow 2.x (2.0 through 2.10), the previous major version series. **Airflow 2.x reached End of Life in April 2026.** No further patches will be released. Active migration to 3.x is strongly recommended.

For foundational Airflow knowledge (DAG design, executors, XCom patterns, deployment), refer to the parent technology agent. This agent focuses on what is specific to 2.x and migration to 3.x.

## EOL Warning

Airflow 2.x is end-of-life as of April 2026. This means:
- No security patches, bug fixes, or community support
- Provider packages will drop 2.x compatibility over time
- New features (HITL, asset partitioning, multi-team) are 3.x only
- **Start migration planning now** if still on 2.x

## Key Features by Minor Version

| Version | Date | Headline Feature |
|---|---|---|
| 2.0 | Dec 2020 | TaskFlow API, REST API, Scheduler HA |
| 2.2 | Oct 2021 | Deferrable operators, custom timetables |
| 2.3 | Apr 2022 | Dynamic task mapping, grid view |
| 2.4 | Sep 2022 | Data-aware scheduling (Datasets), `@task.bash` |
| 2.5 | Dec 2022 | Multiple `@task` decorator improvements |
| 2.6 | Apr 2023 | Notifier classes, improved Dataset events |
| 2.7 | Aug 2023 | Setup and teardown tasks |
| 2.8 | Dec 2023 | Object Storage API, `@task.sensor` |
| 2.9 | Apr 2024 | DatasetOrTimeSchedule, Dataset AND/OR logic |
| 2.10 | Sep 2024 | Multiple executors concurrently |

## Airflow 2.x Architecture

### Component Differences from 3.x

| Component | Airflow 2.x | Airflow 3.x |
|---|---|---|
| Web tier | Flask-based Webserver (`airflow webserver`) | FastAPI-based API Server (`airflow api-server`) |
| DB access | Workers access metadata DB directly | Workers access DB via API Server only |
| DAG source | `dags_folder`, git-sync sidecar | DAG bundles (local, Git, S3) |
| Data triggers | Datasets (`Dataset("...")`) | Assets (`Asset("...")`) |
| Auth | FAB-based RBAC (built-in) | SimpleAuthManager (FAB via provider) |
| Executors | Local, Celery, Kubernetes, CeleryKubernetes, LocalKubernetes | Local, Celery, Kubernetes, Edge, Multiple |

### Import Paths (2.x style)

```python
# Airflow 2.x imports
from airflow.decorators import dag, task
from airflow.models.dag import DAG
from airflow.models.baseoperator import BaseOperator
from airflow.sensors.base import BaseSensorOperator
from airflow.datasets import Dataset
from airflow.models import Variable, Connection
```

### Executors Removed in 3.x

- **SequentialExecutor** -- Used for testing. Replaced by LocalExecutor in 3.x.
- **DebugExecutor** -- Used for IDE debugging. Removed in 3.x.
- **CeleryKubernetesExecutor** -- Replaced by Multiple Executors Concurrently.
- **LocalKubernetesExecutor** -- Replaced by Multiple Executors Concurrently.

### Context Variables Removed in 3.x

These template variables exist in 2.x but are removed in 3.x:
- `execution_date` -- Use `logical_date`
- `next_execution_date`, `prev_execution_date` -- Removed
- `tomorrow_ds`, `tomorrow_ds_nodash` -- Removed
- `yesterday_ds`, `yesterday_ds_nodash` -- Removed
- `prev_ds`, `prev_ds_nodash`, `next_ds`, `next_ds_nodash` -- Removed

## Migration to 3.x

### Migration Strategy

The official recommendation is to **create a new Airflow 3.x environment** rather than in-place upgrade. Key steps:

1. **Audit DAGs** with Ruff linter:
   ```bash
   ruff check dags/ --select AIR301,AIR302
   ruff check dags/ --select AIR301 --fix        # Auto-fix safe changes
   ruff check dags/ --select AIR301 --fix --unsafe-fixes  # Review carefully
   ```

2. **Update import paths** (`airflow.decorators` -> `airflow.sdk`, `Dataset` -> `Asset`, etc.):

   | 2.x Import | 3.x Import |
   |---|---|
   | `airflow.decorators.dag` | `airflow.sdk.dag` |
   | `airflow.decorators.task` | `airflow.sdk.task` |
   | `airflow.models.dag.DAG` | `airflow.sdk.DAG` |
   | `airflow.models.baseoperator.BaseOperator` | `airflow.sdk.BaseOperator` |
   | `airflow.datasets.Dataset` | `airflow.sdk.Asset` |
   | `airflow.models.variable.Variable` | `airflow.sdk.Variable` |
   | `airflow.models.connection.Connection` | `airflow.sdk.Connection` |

3. **Install `apache-airflow-providers-standard`** for BashOperator, PythonOperator, FileSensor, ExternalTaskSensor (moved out of core).

4. **Remove direct database access** from custom operators and DAGs. This is the biggest effort. Refactor to use the REST API client.

5. **Replace SubDAGs** with TaskGroups (visual grouping) or Assets (cross-DAG dependencies). SubDAGs are completely removed.

6. **Replace deprecated context variables** -- `execution_date` becomes `logical_date`; replace `yesterday_ds`/`tomorrow_ds` with date math from `data_interval_start`/`data_interval_end`.

7. **Reconfigure authentication** -- Install `apache-airflow-providers-fab` if using RBAC. Update OAuth redirect URLs (now prefixed with `/auth`).

8. **Update DAG deployment** -- Replace git-sync sidecars with DAG bundles if deploying on Kubernetes.

9. **Migrate SLAs** -- SLA feature removed. Use Deadline Alerts (3.1+) instead.

### Configuration Changes

| Setting | 2.x Default | 3.x Default | Impact |
|---|---|---|---|
| `catchup_by_default` | `True` | `False` | New DAGs won't backfill by default |
| `create_cron_data_intervals` | `True` | `False` | Uses CronTriggerTimetable instead |
| Auth manager | FAB (built-in) | SimpleAuthManager | FAB requires provider installation |
| Python minimum | 3.8 | 3.9 | Update runtime if on 3.8 |
| PostgreSQL minimum | 12 | 13 | Upgrade database if on 12 |

### Breaking Changes Checklist

- [ ] Run `ruff check --select AIR301,AIR302` and fix all violations
- [ ] Replace all `Dataset` references with `Asset`
- [ ] Remove all direct Metadata DB access from tasks/operators
- [ ] Replace SubDAGs with TaskGroups
- [ ] Replace `execution_date` with `logical_date` in templates and code
- [ ] Install `apache-airflow-providers-standard`
- [ ] Install `apache-airflow-providers-fab` if using RBAC
- [ ] Update OAuth redirect URLs (add `/auth` prefix)
- [ ] Remove SLA parameters; plan Deadline Alert migration
- [ ] Replace git-sync with DAG bundles (if on Kubernetes)
- [ ] Verify XCom values are JSON-serializable (pickling disabled)
- [ ] Test all DAGs in new environment before cutover
