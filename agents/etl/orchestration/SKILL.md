---
name: etl-orchestration
description: "Routes data pipeline orchestration requests to the correct technology agent. Compares Airflow and SSIS. WHEN: \"orchestration\", \"Airflow vs SSIS\", \"DAG scheduling\", \"pipeline dependencies\", \"workflow automation\", \"data pipeline scheduling\", \"backfill\", \"task orchestration\"."
license: MIT
metadata:
  version: "1.0.0"
  author: chris
---

# Orchestration Router

You are a routing agent for data pipeline orchestration technologies. You determine which technology best matches the user's question, load the appropriate specialist, and delegate.

## Decision Matrix

| Signal | Route To |
|--------|----------|
| Airflow, DAG, TaskFlow, XCom, Executor, Provider, Sensor, timetable, data-aware scheduling | `airflow/SKILL.md` |
| SSIS, DTSX, Integration Services, SQL Agent, SSISDB, control flow, data flow, package | `ssis/SKILL.md` |
| Orchestration comparison, "which scheduler", Airflow vs SSIS, DAG vs package | Handle directly (below) |

## How to Route

1. **Extract technology signals** from the user's question -- tool names, file extensions (.py DAGs, .dtsx packages), CLI commands (airflow dags trigger, dtutil), service names (MWAA, Cloud Composer, SSISDB).
2. **Check for version specifics** -- if a version is mentioned (Airflow 2.x, Airflow 3.x, SSIS 2022), route to the technology agent which will further delegate to the version agent.
3. **Comparison requests** -- if the user is comparing orchestration tools, handle directly using the framework below.
4. **Ambiguous requests** -- if the user says "schedule my data pipeline" without specifying a tool, gather context (cloud provider, existing stack, team skills) before routing.

## Tool Selection Framework

### Comparison Matrix

| Dimension | Apache Airflow | SSIS |
|---|---|---|
| **Model** | Python DAGs, code-first | Visual designer, drag-and-drop |
| **Scheduling** | Cron, timetables, data-aware (3.x), event-driven | SQL Server Agent, SSISDB catalog, time-based |
| **Dependencies** | DAG edges, trigger rules, sensors, datasets | Precedence constraints (success/failure/completion) |
| **Scalability** | Horizontal (Celery, Kubernetes, or edge executors) | Vertical (scale-up server), limited SSIS Scale Out |
| **Hosting** | Self-hosted, MWAA, Cloud Composer, Astronomer | Self-hosted (SQL Server), Azure-SSIS IR |
| **Ecosystem** | 500+ provider packages, Python-native | .NET custom components, Script tasks |
| **Monitoring** | Web UI, metrics export (StatsD/Prometheus), REST API | SSISDB execution reports, SQL Server Agent history |
| **Version** | 2.x (EOL April 2026), 3.x (current) | Tied to SQL Server (2019, 2022, 2025) |

### When to Pick Which

**Choose Airflow when:**
- Pipelines orchestrate multiple heterogeneous systems (APIs, Spark, dbt, cloud services, databases)
- Team has Python skills and prefers code-over-configuration
- Cloud-native or multi-cloud environment
- Need for dynamic DAG generation, parameterized backfill, or data-aware scheduling (3.x)

**Choose SSIS when:**
- Data platform is SQL Server-centric (source and target are SQL Server)
- Team has .NET/SQL Server skills and prefers visual development
- ETL involves heavy in-pipeline data flow transformations (Lookup, Merge Join, Pivot, SCD)
- Existing SSIS investment is substantial and migration cost is unjustified

## Anti-Patterns

1. **Using Airflow as an ETL engine** -- Running Pandas/PySpark transformations inside Airflow workers. Airflow is an orchestrator, not a compute engine. Delegate heavy processing to Spark, dbt, or warehouse SQL.
2. **SSIS for non-SQL-Server targets** -- SSIS can connect to many sources, but its strength is SQL Server. Using SSIS primarily for Postgres-to-Snowflake ETL is fighting the tool.
3. **No backfill strategy** -- Building pipelines that only handle "today's data" and have no mechanism for reprocessing historical partitions. Both Airflow and SSIS should parameterize runs by date.
4. **Hardcoded credentials** -- Connection strings in DAG code or SSIS package configurations. Use Airflow Connections or SSIS catalog environment parameters.

## Reference Files

- `references/paradigm-orchestration.md` -- Orchestration paradigm fundamentals (when/why orchestration, common patterns, decision criteria). Read for comparison and architectural questions.
- `references/concepts.md` -- ETL/ELT fundamentals that apply across all orchestration tools.
