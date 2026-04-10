# Airflow Best Practices

## DAG Design Patterns

### Idempotent Tasks

Every task must produce the same result when run multiple times with the same inputs:
- Use `INSERT ... ON CONFLICT UPDATE` or `MERGE` instead of plain `INSERT`
- Overwrite output partitions/files rather than appending
- Use deterministic file names based on `logical_date` or `data_interval_start`
- Design for retries: a task that fails halfway and retries must not create duplicates

### Atomic Operations

Each task should be a self-contained unit of work:
- A task either fully completes or fully fails -- no partial results
- Write to temporary locations and atomically rename/swap on success
- Use database transactions within a single task
- Avoid tasks that depend on the current state of a shared mutable resource

### Single Responsibility

- One DAG per business outcome (e.g., `daily_sales_report` not `do_everything`)
- One task per logical operation (separate extract, transform, load)
- Avoid "god tasks" that combine extraction, transformation, and loading in a single function

### Dependency Management

- Keep DAGs shallow and wide rather than deep and narrow
- Use TaskGroups to organize related tasks visually without nesting complexity
- Use `trigger_rule` appropriately (prefer `none_failed` or `none_failed_min_one_success` when upstream tasks may be skipped)
- Use Assets/Datasets for cross-DAG dependencies instead of ExternalTaskSensor chains

### Descriptive Naming

- Task IDs: `transfer_s3_to_redshift` not `task_1`
- DAG IDs: `daily_customer_churn_etl` not `pipeline_3`
- Consistent naming conventions across all DAGs

## TaskFlow API vs Traditional Operators

### When to Use TaskFlow API (`@task`)

- Python-centric logic (data transformations, API calls, calculations)
- When tasks need to pass data between each other (automatic XCom)
- New DAG development (recommended approach in Airflow 3)
- Complex branching or dynamic workflows

```python
from airflow.sdk import dag, task

@dag(schedule="@daily")
def sales_pipeline():
    @task
    def extract_sales():
        return query_database("SELECT * FROM sales WHERE date = ...")

    @task
    def transform(raw_data):
        return [clean(record) for record in raw_data]

    @task
    def load(clean_data):
        write_to_warehouse(clean_data)

    raw = extract_sales()
    clean = transform(raw)
    load(clean)

sales_pipeline()
```

### When to Use Traditional Operators

- Leveraging provider-specific operators (S3ToRedshiftOperator, BigQueryInsertJobOperator)
- Simple bash/SQL commands where a decorator adds no value
- When the operator provides retry/error handling tuned for its specific system
- Migrating existing Airflow 2.x DAGs incrementally

```python
from airflow.sdk import DAG
from airflow.providers.amazon.aws.transfers.s3_to_redshift import S3ToRedshiftOperator

with DAG("load_to_redshift", schedule="@daily") as dag:
    load = S3ToRedshiftOperator(
        task_id="s3_to_redshift",
        s3_bucket="data-lake",
        s3_key="sales/{{ ds }}/output.parquet",
        schema="public",
        table="sales",
        copy_options=["FORMAT PARQUET"],
    )
```

### Mixing Both Approaches

TaskFlow tasks and traditional operators interoperate seamlessly. Use TaskFlow for orchestration logic and operators for system-specific operations.

## XCom Patterns and Limitations

### Size Limits

- Default backend stores XCom in the Metadata Database
- Practical limit: under 48 KB for reliability; values over 1 MB cause serious performance degradation
- **Never** pass DataFrames, large JSON payloads, or binary files through XCom
- Airflow 3: Pickling disabled by default -- values must be JSON-serializable

### Recommended Patterns

**Pattern 1: Pass references, not data**
```python
@task
def extract():
    df = query_large_dataset()
    path = f"s3://data-lake/staging/{logical_date}/extract.parquet"
    df.to_parquet(path)
    return path  # Small string in XCom

@task
def transform(path):
    df = pd.read_parquet(path)
    # ... transform ...
```

**Pattern 2: Multiple return values**
```python
@task(multiple_outputs=True)
def extract():
    return {
        "row_count": 1500,
        "s3_path": "s3://bucket/file.parquet",
        "schema_version": "v2",
    }
```

**Pattern 3: Custom XCom backend**

For teams that need to pass larger objects, configure a custom XCom backend (S3, GCS) that stores values in object storage and keeps references in the database.

### XCom Anti-Patterns

- Passing entire database query results through XCom
- Using XCom as a cache or shared state store
- Relying on XCom for task ordering (use explicit dependencies)
- Storing credentials or secrets in XCom

## Testing Strategies

### DAG Validation Tests

Ensure DAGs load without errors and have valid structure:

```python
import pytest
from airflow.models import DagBag

@pytest.fixture
def dagbag():
    return DagBag(dag_folder="dags/", include_examples=False)

def test_no_import_errors(dagbag):
    assert len(dagbag.import_errors) == 0, f"Import errors: {dagbag.import_errors}"

def test_dag_has_tasks(dagbag):
    for dag_id, dag in dagbag.dags.items():
        assert len(dag.tasks) > 0, f"DAG {dag_id} has no tasks"
```

### Unit Tests for Task Logic

Extract business logic into pure functions and test independently:

```python
# Extract logic into testable functions
def clean_record(record):
    return {
        "name": record["name"].strip().title(),
        "amount": round(float(record["amount"]), 2),
    }

def test_clean_record():
    raw = {"name": "  john doe  ", "amount": "123.456"}
    result = clean_record(raw)
    assert result["name"] == "John Doe"
    assert result["amount"] == 123.46
```

### Integration Tests

Use `dag.test()` for end-to-end DAG testing in development. Mock external dependencies with `unittest.mock`.

### CI/CD Integration

- Run DAG validation tests in CI before deployment
- Use a `DagBag` test to catch import errors early
- Validate DAG structure: task count, dependency graph, schedule interval
- Run `ruff check --select AIR301` in CI for Airflow 3 migration readiness

## Dynamic DAGs

### When to Use Dynamic Task Mapping

Good use cases:
- Processing a variable number of files from a directory
- Running the same transformation on multiple database tables
- Parallel API calls to a list of endpoints
- Fan-out/fan-in patterns where the fan-out count is unknown at parse time

```python
@task
def list_tables():
    return ["customers", "orders", "products"]

@task
def sync_table(table_name):
    extract_and_load(table_name)

tables = list_tables()
sync_table.expand(table_name=tables)
```

### When NOT to Use Dynamic Task Mapping

- Fixed, known number of tasks (define them explicitly)
- Mapped task count could be very large (>1000) -- batch instead
- Each "task" needs fundamentally different logic (use branching)

### Partial and Expand

```python
@task
def process(table_name, target_schema, batch_size):
    pass

process.partial(target_schema="analytics", batch_size=1000).expand(
    table_name=list_tables()
)
```

### Dynamic Task Groups

Map over entire task groups for complex per-item pipelines:

```python
@task_group
def process_file(filename):
    validated = validate(filename)
    transformed = transform(validated)
    load(transformed)

process_file.expand(filename=get_files())
```

### Runtime DAG Generation

For entirely different DAG structures per configuration:

```python
configs = load_pipeline_configs()  # Keep this lightweight!
for config in configs:
    dag_id = f"pipeline_{config['name']}"
    with DAG(dag_id=dag_id, schedule=config["schedule"]) as dag:
        # Build DAG from config
        globals()[dag_id] = dag
```

**Caution:** Generated DAGs are parsed every scheduler cycle. Keep generation logic fast with zero I/O at module level.

## Monitoring

### Key Metrics

Airflow emits metrics via StatsD or OpenTelemetry:

**Scheduler health:**
- `scheduler.scheduler_loop_duration` -- Loop duration (increasing = overload)
- `scheduler.tasks.running` -- Currently running tasks
- `scheduler.tasks.starving` -- Tasks waiting for resources

**Task performance:**
- `ti.finish.<dag_id>.<task_id>.<state>` -- Task completion by state
- `dag.duration.<dag_id>` -- Total DAG run duration

**Executor:**
- `executor.open_slots` -- Available executor slots
- `executor.queued_tasks` -- Queue depth

### Monitoring Stack

Typical production setup:
1. Airflow emits metrics to StatsD
2. StatsD Exporter converts to Prometheus format
3. Prometheus scrapes and stores metrics
4. Grafana visualizes dashboards and alerts
5. Alertmanager sends notifications (Slack, PagerDuty, email)

### Deadline Alerts (Airflow 3.1+)

Replaces the removed SLA feature with a more flexible system. Define deadlines for DAG runs and task instances; receive alerts when deadlines are at risk or missed.

### Duration Monitoring

- Monitor via Airflow UI: Browse > Task Duration
- Track p50, p90, p99 task durations over time
- Alert on DAG runs exceeding expected duration thresholds

## Connection Management

### Secrets Backends

**HashiCorp Vault:**
```ini
[secrets]
backend = airflow.providers.hashicorp.secrets.vault.VaultBackend
backend_kwargs = {"connections_path": "connections", "variables_path": "variables", "mount_point": "airflow", "url": "https://vault.example.com:8200"}
```

**AWS Secrets Manager:**
```ini
[secrets]
backend = airflow.providers.amazon.aws.secrets.secrets_manager.SecretsManagerBackend
backend_kwargs = {"connections_prefix": "airflow/connections", "variables_prefix": "airflow/variables"}
```

**GCP Secret Manager:**
```ini
[secrets]
backend = airflow.providers.google.cloud.secrets.secret_manager.CloudSecretManagerBackend
backend_kwargs = {"connections_prefix": "airflow-connections", "variables_prefix": "airflow-variables", "project_id": "my-gcp-project"}
```

### Best Practices

- Use environment variables (`AIRFLOW_CONN_*`) for local development
- Use secrets backends for staging and production
- Never hardcode credentials in DAG files
- Use connection extras (JSON) for provider-specific parameters
- Rotate credentials regularly; secrets backends make this easier
- Test connections via the Airflow UI or CLI before deploying DAGs

## Performance Tuning

### DAG File Processing

- Keep module-level code minimal (no I/O at import time)
- One DAG per file is ideal; multiple DAGs per file increase parse time for all
- Use DAG bundles (3.x) to parallelize file processing across bundles
- Monitor `dag_file_processor_timeouts` for files too slow to parse
- Increase `dagbag_import_timeout` for legitimately complex imports

### Scheduler Tuning

| Parameter | Default | When to Increase |
|---|---|---|
| `parallelism` | 32 | Large deployments with many concurrent tasks |
| `max_active_runs_per_dag` | 16 | Rarely (lower for resource-heavy DAGs) |
| `min_file_process_interval` | 30 | Many DAG files (reduces CPU from frequent re-parsing) |
| `dag_dir_list_interval` | 300 | Large DAG directories |

### Pool Management

- Create pools for each external system (database pools, API rate limits)
- Set pool sizes based on the target system's capacity
- Use `priority_weight` to ensure critical tasks get pool slots first
- Use `pool_slots` on tasks to reserve multiple slots for heavy operations
- Monitor pool utilization: consistently full pools indicate bottlenecks

### General Tips

- Use deferrable operators/sensors instead of `poke` mode sensors
- Set `execution_timeout` on tasks to prevent runaway processes
- Use `max_active_tis_per_dag` to prevent single DAGs from monopolizing
- Regularly clean the metadata database (`airflow db clean`)
- Index heavily-queried custom tables if using a custom XCom backend

## Code Organization

### Recommended Project Structure

```
airflow-project/
|-- dags/
|   |-- sales/
|   |   |-- daily_sales_etl.py
|   |   |-- weekly_sales_report.py
|   |-- marketing/
|   |   |-- campaign_sync.py
|   |-- common/
|       |-- utils.py
|       |-- constants.py
|-- plugins/
|   |-- operators/
|   |   |-- custom_s3_operator.py
|   |-- hooks/
|   |   |-- custom_api_hook.py
|   |-- sensors/
|       |-- custom_file_sensor.py
|-- tests/
|   |-- test_dag_integrity.py
|   |-- dags/
|       |-- test_sales_etl.py
|-- Dockerfile
|-- requirements.txt
|-- pyproject.toml
```

### Key Principles

- **dags/** -- Only DAG definitions and lightweight utilities. Added to PYTHONPATH by Airflow.
- **plugins/** -- Custom operators, hooks, sensors. Also added to PYTHONPATH.
- **tests/** -- Mirror the dags/ structure. Run in CI before deployment.
- **Shared code** -- For large teams, publish shared operators/hooks as internal Python packages.

### Custom Operators

```python
from airflow.sdk import BaseOperator
from airflow.providers.amazon.aws.hooks.s3 import S3Hook

class S3DataQualityOperator(BaseOperator):
    def __init__(self, bucket, key, checks, **kwargs):
        super().__init__(**kwargs)
        self.bucket = bucket
        self.key = key
        self.checks = checks

    def execute(self, context):
        hook = S3Hook()
        data = hook.read_key(self.key, self.bucket)
        for check in self.checks:
            if not check(data):
                raise ValueError(f"Data quality check failed: {check.__name__}")
        return True
```
