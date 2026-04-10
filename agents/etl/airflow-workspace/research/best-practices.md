# Apache Airflow Best Practices

## DAG Design Patterns

### Idempotent Tasks

Every task should produce the same result when run multiple times with the same inputs:
- Use `INSERT ... ON CONFLICT UPDATE` or `MERGE` instead of plain `INSERT`
- Overwrite output partitions/files rather than appending
- Use deterministic file names based on logical_date or data_interval
- Design for retries: a task that fails halfway and retries should not create duplicates

### Atomic Operations

Each task should be a self-contained unit of work:
- A task either fully completes or fully fails -- no partial results
- Write to temporary locations and atomically rename/swap on success
- Use database transactions within a single task
- Avoid tasks that depend on the current state of a shared mutable resource

### Single Responsibility

- One DAG per business outcome (e.g., "daily_sales_report" not "do_everything")
- One task per logical operation (e.g., separate "extract" and "transform" tasks)
- Avoid "god tasks" that do extraction, transformation, and loading in a single function

### Dependency Management

- Keep DAGs shallow and wide rather than deep and narrow when possible
- Use TaskGroups to organize related tasks visually without nesting complexity
- Avoid circular dependencies (Airflow prevents them but detect design issues early)
- Use `trigger_rule` appropriately to handle conditional paths
- Prefer `none_failed` or `none_failed_min_one_success` over `all_success` when some upstream tasks may be skipped

### Descriptive Naming

- Task IDs should be descriptive: `transfer_s3_to_redshift` not `task_1`
- DAG IDs should reflect the pipeline purpose: `daily_customer_churn_etl`
- Use consistent naming conventions across all DAGs

---

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
        # Returns data automatically pushed to XCom
        return query_database("SELECT * FROM sales WHERE date = ...")

    @task
    def transform(raw_data):
        # Input automatically pulled from XCom
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
- When migrating existing Airflow 2.x DAGs incrementally
- When the operator provides retry/error handling tuned for its specific system

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

TaskFlow tasks and traditional operators work together seamlessly:

```python
@dag(schedule="@daily")
def hybrid_pipeline():
    @task
    def prepare_query():
        return "SELECT * FROM staging.events"

    query = prepare_query()

    run_query = PostgresOperator(
        task_id="run_query",
        postgres_conn_id="warehouse",
        sql=query,
    )
```

---

## XCom Patterns and Limitations

### Size Limits

- Default backend (database): XCom values stored as rows in the metadata DB
- Practical limit: Keep values under ~48 KB for reliability; values over 1 MB will cause serious performance degradation
- **Never** pass DataFrames, large JSON payloads, or binary files through XCom

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

For teams that need to pass larger objects, configure a custom XCom backend:
- S3/GCS XCom backend: Stores values in object storage, keeps references in DB
- Available via provider packages or custom implementation

### Serialization

- **Airflow 3:** Pickling disabled by default (security). XCom values must be JSON-serializable with the default backend.
- Use custom serialization for complex objects (convert to dict/JSON first)
- Consider Pydantic models for structured data with validation

### Anti-Patterns

- Passing entire database query results through XCom
- Using XCom as a cache or shared state store
- Relying on XCom for task ordering (use explicit dependencies instead)
- Storing credentials or secrets in XCom

---

## Testing DAGs

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

def test_no_cycles(dagbag):
    # DAGs with cycles will fail to load, but explicitly test
    for dag_id, dag in dagbag.dags.items():
        assert not dag.test_cycle(), f"DAG {dag_id} has a cycle"
```

### Unit Tests for Task Logic

Test the business logic independently of Airflow:

```python
# Extract the logic into pure functions
def clean_record(record):
    """Pure function - easy to test."""
    return {
        "name": record["name"].strip().title(),
        "amount": round(float(record["amount"]), 2),
    }

# Test the function directly
def test_clean_record():
    raw = {"name": "  john doe  ", "amount": "123.456"}
    result = clean_record(raw)
    assert result["name"] == "John Doe"
    assert result["amount"] == 123.46
```

### Integration Tests

Test tasks in context with XCom and connections:

```python
def test_extract_task(tmp_path):
    """Test that extract task produces expected output."""
    # Use test database or mock
    with mock.patch("my_module.query_database") as mock_query:
        mock_query.return_value = [{"id": 1, "value": "test"}]
        result = extract_function()
        assert len(result) == 1
        assert result[0]["id"] == 1
```

### Testing Tips

- Reset global state (Variables, XCom, Connections) at the beginning and end of every test
- Use `pytest` fixtures for DagBag setup and teardown
- Test edge cases: empty datasets, null values, schema changes
- Use `dag.test()` method for end-to-end DAG testing in development
- Validate DAG structure in CI: task count, dependency graph, schedule interval

---

## Dynamic DAGs

### When to Use Dynamic Task Mapping

Good use cases:
- Processing a variable number of files from a directory
- Running the same transformation on multiple database tables
- Parallel API calls to a list of endpoints
- Fan-out/fan-in patterns where the fan-out count is unknown at DAG parse time

```python
@task
def list_tables():
    return ["customers", "orders", "products"]

@task
def sync_table(table_name):
    # Sync each table independently
    extract_and_load(table_name)

tables = list_tables()
sync_table.expand(table_name=tables)
```

### When NOT to Use Dynamic Task Mapping

- Fixed, known number of tasks (just define them explicitly)
- When mapped task count could be very large (>1000) -- consider batching instead
- When each "task" needs fundamentally different logic (use branching instead)

### Partial and Expand

```python
@task
def process(table_name, target_schema, batch_size):
    # table_name varies, target_schema and batch_size are constant
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
    loaded = load(transformed)

process_file.expand(filename=get_files())
```

### Runtime DAG Generation

For cases where dynamic task mapping is insufficient (e.g., entirely different DAG structures per configuration):

```python
# Generate DAGs from configuration
configs = load_pipeline_configs()  # Keep this lightweight!
for config in configs:
    dag_id = f"pipeline_{config['name']}"
    with DAG(dag_id=dag_id, schedule=config["schedule"]) as dag:
        # Build DAG from config
        globals()[dag_id] = dag
```

**Caution:** Generated DAGs are parsed every scheduler cycle. Keep the generation logic fast and avoid I/O (database queries, API calls) at module level.

---

## Monitoring

### Airflow Metrics

Airflow emits metrics via StatsD or OpenTelemetry. Key metrics to monitor:

**Scheduler health:**
- `scheduler.scheduler_loop_duration` -- How long each scheduler loop takes
- `scheduler.tasks.running` -- Number of currently running tasks
- `scheduler.tasks.starving` -- Tasks that cannot be scheduled due to pool/concurrency limits
- `dagbag_size` -- Number of DAGs loaded

**Task performance:**
- `ti.start.<dag_id>.<task_id>` -- Task start timestamp
- `ti.finish.<dag_id>.<task_id>.<state>` -- Task completion by state
- `dag.duration.<dag_id>` -- Total DAG run duration

**Executor metrics:**
- `executor.open_slots` -- Available executor slots
- `executor.queued_tasks` -- Tasks waiting in the executor queue

### Monitoring Stack

Typical production monitoring setup:
1. **Airflow** emits metrics to **StatsD**
2. **StatsD Exporter** converts to Prometheus format
3. **Prometheus** scrapes and stores metrics
4. **Grafana** visualizes dashboards and alerts
5. **Alertmanager** sends notifications (Slack, PagerDuty, email)

### Deadline Alerts (Airflow 3, replacing SLAs)

```python
from airflow.sdk import dag
from datetime import timedelta

@dag(
    schedule="@daily",
    # Define when the DAG run should complete by
)
def my_pipeline():
    # Tasks with deadline configuration
    pass
```

Note: The legacy SLA feature was removed in Airflow 3. Deadline Alerts provide a more flexible replacement that works with all trigger types (not just scheduled DAGs).

### Task Duration Trends

- Monitor via Airflow UI: Browse > Task Duration
- Set up Grafana alerts for task duration anomalies
- Track p50, p90, p99 task durations over time
- Alert on DAG runs exceeding expected duration thresholds

---

## Connection Management

### Secrets Backends

For production deployments, use external secrets backends instead of storing connections in the Airflow database:

**HashiCorp Vault:**
```ini
[secrets]
backend = airflow.providers.hashicorp.secrets.vault.VaultBackend
backend_kwargs = {
    "connections_path": "connections",
    "variables_path": "variables",
    "mount_point": "airflow",
    "url": "https://vault.example.com:8200"
}
```
Provider: `apache-airflow-providers-hashicorp`

**AWS Secrets Manager:**
```ini
[secrets]
backend = airflow.providers.amazon.aws.secrets.secrets_manager.SecretsManagerBackend
backend_kwargs = {
    "connections_prefix": "airflow/connections",
    "variables_prefix": "airflow/variables"
}
```
Provider: `apache-airflow-providers-amazon` (7.3.0+ for lookup patterns)

**GCP Secret Manager:**
```ini
[secrets]
backend = airflow.providers.google.cloud.secrets.secret_manager.CloudSecretManagerBackend
backend_kwargs = {
    "connections_prefix": "airflow-connections",
    "variables_prefix": "airflow-variables",
    "project_id": "my-gcp-project"
}
```

### Connection Best Practices

- Use environment variables (`AIRFLOW_CONN_*`) for local development
- Use secrets backends for staging and production
- Never hardcode credentials in DAG files
- Use connection extras (JSON) for provider-specific parameters
- Rotate credentials regularly; secrets backends make this easier
- Test connections via the Airflow UI or CLI before deploying DAGs

---

## Performance

### DAG File Processing

- **Keep module-level code minimal:** All logic should be inside tasks or operators. Code at module level runs every scheduler parse cycle (every `min_file_process_interval` seconds).
- **Avoid top-level I/O:** No database queries, API calls, or file reads at import time
- **Use DAG bundles (Airflow 3):** Partition DAG files across bundles for parallel processing
- **Limit DAG count per file:** One DAG per file is ideal; multiple DAGs per file increase parse time for all of them
- **Monitor parse time:** `dag_file_processor_timeouts` metric indicates files that are too slow to parse

### Scheduler Tuning

Key configuration parameters:

| Parameter | Description | Default | Tuning |
|-----------|-------------|---------|--------|
| `parallelism` | Max concurrent task instances across all DAGs | 32 | Increase for large deployments |
| `max_active_runs_per_dag` | Max concurrent runs per DAG | 16 | Lower for resource-heavy DAGs |
| `max_active_tasks_per_dag` | Max concurrent tasks per DAG run | 16 | Tune based on task resource needs |
| `min_file_process_interval` | Min seconds between DAG file re-parses | 30 | Increase if many DAG files |
| `dag_dir_list_interval` | Seconds between scanning for new DAG files | 300 | Increase for large DAG directories |
| `scheduler_heartbeat_sec` | Scheduler heartbeat interval | 5 | Rarely needs changing |

### Pool Management

- Create pools for each external system (database pools, API rate limits)
- Set pool sizes based on the target system's capacity, not Airflow's
- Monitor pool utilization: consistently full pools indicate bottlenecks
- Use `priority_weight` to ensure critical tasks get pool slots first
- Consider `pool_slots` parameter on tasks to reserve multiple slots for heavy tasks

### General Performance Tips

- Use deferrable operators/sensors instead of `poke` mode sensors
- Set appropriate `execution_timeout` on tasks to prevent runaway processes
- Use `max_active_tis_per_dag` to prevent a single DAG from monopolizing resources
- Regularly clean the metadata database (`airflow db clean`)
- Index heavily-queried custom tables if using a custom XCom backend

---

## Code Organization

### Recommended Project Structure

```
airflow-project/
|-- dags/
|   |-- __init__.py
|   |-- sales/
|   |   |-- __init__.py
|   |   |-- daily_sales_etl.py
|   |   |-- weekly_sales_report.py
|   |-- marketing/
|   |   |-- __init__.py
|   |   |-- campaign_sync.py
|   |-- common/
|       |-- __init__.py
|       |-- utils.py              # Shared utility functions
|       |-- constants.py          # Shared constants
|-- plugins/
|   |-- __init__.py
|   |-- operators/
|   |   |-- __init__.py
|   |   |-- custom_s3_operator.py
|   |-- hooks/
|   |   |-- __init__.py
|   |   |-- custom_api_hook.py
|   |-- sensors/
|       |-- __init__.py
|       |-- custom_file_sensor.py
|-- tests/
|   |-- __init__.py
|   |-- test_dag_integrity.py     # DAG validation tests
|   |-- test_utils.py             # Unit tests for shared utilities
|   |-- dags/
|       |-- test_sales_etl.py     # Tests for specific DAG logic
|-- config/
|   |-- airflow.cfg               # Airflow configuration (or env vars)
|   |-- connections.yaml          # Connection definitions (dev only)
|-- Dockerfile
|-- requirements.txt
|-- pyproject.toml
```

### Key Principles

- **dags/**: Only DAG definitions and lightweight utilities. Airflow adds this to PYTHONPATH.
- **plugins/**: Custom operators, hooks, sensors. Also added to PYTHONPATH by Airflow.
- **tests/**: Mirror the dags/ structure. Run in CI before deployment.
- **Shared code as packages:** For large teams, publish shared operators/hooks as internal Python packages with proper versioning.
- **Security:** Shared code used by the webserver should go in `plugins/` or `config/`, which are managed by admins. DAG folder code is typically managed by data engineers.

### Custom Operators

```python
# plugins/operators/custom_s3_operator.py
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

### Shared Hooks

Build Hooks for reusable integrations; then build operators on top of them:

```python
# plugins/hooks/custom_api_hook.py
from airflow.hooks.base import BaseHook
import requests

class CustomAPIHook(BaseHook):
    conn_name_attr = "custom_api_conn_id"
    default_conn_name = "custom_api_default"
    conn_type = "http"

    def __init__(self, custom_api_conn_id="custom_api_default"):
        super().__init__()
        self.conn_id = custom_api_conn_id

    def get_data(self, endpoint):
        conn = self.get_connection(self.conn_id)
        url = f"{conn.host}/{endpoint}"
        headers = {"Authorization": f"Bearer {conn.password}"}
        response = requests.get(url, headers=headers)
        response.raise_for_status()
        return response.json()
```

---

## Sources

- [Airflow Best Practices (Official)](https://airflow.apache.org/docs/apache-airflow/stable/best-practices.html)
- [Airflow DAG Documentation](https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/dags.html)
- [Airflow XCom Documentation](https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/xcoms.html)
- [Airflow Dynamic Task Mapping](https://airflow.apache.org/docs/apache-airflow/stable/authoring-and-scheduling/dynamic-task-mapping.html)
- [Airflow Creating Custom Operators](https://airflow.apache.org/docs/apache-airflow/stable/howto/custom-operator.html)
- [Airflow Modules Management](https://airflow.apache.org/docs/apache-airflow/stable/administration-and-deployment/modules_management.html)
- [Airflow Secrets Backend](https://airflow.apache.org/docs/apache-airflow/stable/security/secrets/secrets-backend/index.html)
- [Airflow Metrics Configuration](https://airflow.apache.org/docs/apache-airflow/stable/administration-and-deployment/logging-monitoring/metrics.html)
- [Astronomer - DAG Writing Best Practices](https://www.astronomer.io/docs/learn/dag-best-practices)
- [Astronomer - Testing Airflow DAGs](https://www.astronomer.io/docs/learn/testing-airflow)
- [Astronomer - Monitoring Airflow](https://www.astronomer.io/blog/expert-tips-for-monitoring-the-health-and-slas-of-your-apache-airflow-dags/)
- [SparkCodeHub - Project Structure](https://www.sparkcodehub.com/airflow/best-practices/project-structure)
