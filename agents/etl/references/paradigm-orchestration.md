# Paradigm: Data Pipeline Orchestration

When and why to choose orchestration tools for data pipelines. This file covers the paradigm itself, not specific engines -- see technology agents for engine-specific guidance.

## Choose Orchestration Tools When

- **Pipelines have complex dependencies.** Task B depends on Task A completing successfully. Task C depends on both A and B. Task D runs only if C fails. DAG-based orchestrators (Airflow) express these dependency graphs natively.
- **Scheduling is non-trivial.** Beyond simple cron, you need data-aware scheduling (run when upstream data lands), event-driven triggers, SLA monitoring, and backfill support for historical reprocessing.
- **Visibility into pipeline state is required.** Orchestrators provide dashboards showing DAG runs, task status, duration trends, retry history, and failure logs. Without an orchestrator, pipeline observability is ad hoc (grep through logs, check cron output).
- **Multiple systems need coordination.** A pipeline that extracts from Postgres, lands in S3, triggers a Spark job, waits for completion, runs dbt, and sends a Slack notification needs a coordinator. Orchestrators are that coordinator.
- **Backfill and reprocessing are expected.** Orchestrators parameterize runs by date/partition, making it possible to reprocess historical data without rewriting pipeline logic.

## Avoid Orchestration Tools When

- **You have a single, simple scheduled task.** A cron job or cloud scheduler (EventBridge, Cloud Scheduler) is simpler than deploying Airflow for one pipeline.
- **The managed EL tool handles scheduling.** Fivetran, ADF, and dbt Cloud have built-in scheduling. Adding Airflow to trigger Fivetran adds complexity without value unless you need cross-tool dependency management.
- **The pipeline is purely event-driven.** If processing is triggered by events (Kafka message, S3 object creation, webhook) with no time-based scheduling, an event-driven architecture (Lambda, Cloud Functions, Kafka consumers) is more appropriate than a scheduler.

## Technology Comparison

| Dimension | Apache Airflow | SSIS |
|---|---|---|
| **Model** | Python DAGs, TaskFlow API | Visual control flow + data flow designer |
| **Scheduling** | Cron, timetables, data-aware (3.x), event-driven | SQL Server Agent jobs, SSISDB catalog |
| **Dependencies** | DAG edges, trigger rules, sensors, deferrable operators | Precedence constraints (success, failure, completion) |
| **Extensibility** | Custom operators, providers (500+ packages) | Custom components (.NET), Script tasks |
| **Hosting** | Self-hosted, Astronomer, MWAA (AWS), Cloud Composer (GCP) | Self-hosted (SQL Server), Azure-SSIS IR in ADF |
| **Scalability** | Horizontal (Celery/Kubernetes executor) | Vertical (scale-up), limited horizontal |
| **Ecosystem** | Open source, massive community, Python-native | Microsoft ecosystem, tight SQL Server integration |
| **Best For** | Multi-system orchestration, cloud-native, modern data stack | SQL Server ETL, Windows/.NET teams, visual development |

## Common Patterns

1. **Stage-Transform-Publish**: Separate DAGs/packages for extraction (stage), transformation, and publication. Loose coupling between stages.
2. **Sensor-based triggering**: Wait for upstream data to land (file sensor, partition sensor) before starting processing. Prevents empty or partial runs.
3. **Parameterized backfill**: DAGs accept a date parameter, allowing re-execution for any historical date range.
4. **Dynamic DAG generation**: Generate DAGs programmatically from metadata (table list, config files) instead of hand-coding each pipeline.

## Anti-Patterns

1. **Orchestrator as ETL engine** -- Running heavy data transformations inside Airflow workers (Pandas in a PythonOperator). Airflow should orchestrate, not execute. Delegate to Spark, dbt, or warehouse SQL.
2. **Monolithic DAG** -- One 200-task DAG that does everything. Break into smaller, composable DAGs with cross-DAG dependencies (Airflow datasets/data-aware scheduling in 3.x, or ExternalTaskSensor in 2.x).
3. **No idempotent tasks** -- Tasks that fail on rerun because they don't handle already-existing data. Every task should be safe to rerun.
4. **Hardcoded connection strings** -- Credentials in DAG code or SSIS package configuration. Use Airflow Connections/Variables or SSIS catalog environments with parameter binding.

## Decision Criteria

**Choose Airflow when:**
- Multi-cloud or cloud-agnostic orchestration is needed
- Pipelines span many heterogeneous systems (APIs, databases, Spark, dbt, cloud services)
- Team has Python skills and prefers code-first configuration
- Open-source flexibility and community ecosystem matter

**Choose SSIS when:**
- The data platform is SQL Server-centric
- Team has .NET/SQL Server skills and prefers visual development
- ETL involves heavy data flow transformations (lookups, pivots, merge joins) within SQL Server
- Organization has existing SSIS investment and migration cost is unjustified

## Orchestration Maturity Model

### Level 1: Cron + Scripts
Shell scripts or SQL Agent jobs on a schedule. No dependency management, no retry logic, no visibility. Appropriate only for trivial, single-step tasks.

### Level 2: Basic Orchestrator
Airflow or SSIS with linear task chains. Dependencies are explicit, retries are configured, logs are centralized. Most teams should be at this level minimum.

### Level 3: Data-Aware Orchestration
Pipelines trigger based on data availability (Airflow datasets in 3.x, file sensors, event-driven triggers). Cross-DAG dependencies are explicit. Backfill is parameterized and tested.

### Level 4: Self-Service Platform
Orchestration is a platform service. Domain teams define their own DAGs/packages using templates. Metadata-driven dynamic DAG generation. Centralized monitoring with per-team alerting.

## Key Metrics to Monitor

| Metric | What It Tells You | Alert Threshold |
|---|---|---|
| **Task duration** | Performance regression or source degradation | > 2x historical average |
| **Task failure rate** | Pipeline reliability | > 5% of runs failing |
| **SLA misses** | Business impact of late data | Any miss (SLA is a hard contract) |
| **Scheduler lag** | Orchestrator capacity | Tasks queued > 5 minutes |
| **Backfill queue depth** | Reprocessing debt | Growing over time (never catches up) |
