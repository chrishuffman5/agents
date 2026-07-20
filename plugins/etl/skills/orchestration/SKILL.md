---
name: orchestration
description: "Cross-platform guidance for data pipeline orchestration technologies. Compares Airflow and SSIS. WHEN: \"orchestration\", \"Airflow vs SSIS\", \"DAG scheduling\", \"pipeline dependencies\", \"workflow automation\", \"data pipeline scheduling\", \"backfill\", \"task orchestration\", \"which scheduler\", \"orchestration tool comparison\". Do NOT use for Airflow-specific questions (DAGs, TaskFlow, executors, XCom) -- use the `airflow` skill. Do NOT use for SSIS-specific questions (packages, SSISDB, control flow) -- use the `ssis` skill."
license: MIT
---

# Orchestration

This skill helps determine which data pipeline orchestration technology best matches a given need, and covers cross-tool comparison and selection guidance directly.

## Decision Matrix

| Signal | See Skill |
|--------|----------|
| Airflow, DAG, TaskFlow, XCom, Executor, Provider, Sensor, timetable, data-aware scheduling | `airflow` |
| SSIS, DTSX, Integration Services, SQL Agent, SSISDB, control flow, data flow, package | `ssis` |
| Orchestration comparison, "which scheduler", Airflow vs SSIS, DAG vs package | Handled directly (below) |

## How to Choose

1. **Extract technology signals** from the question -- tool names, file extensions (.py DAGs, .dtsx packages), CLI commands (airflow dags trigger, dtutil), service names (MWAA, Cloud Composer, SSISDB).
2. **Check for version specifics** -- if a version is mentioned (Airflow 2.x, Airflow 3.x, SSIS 2022), see the technology skill, which points to the version reference.
3. **Comparison requests** -- if comparing orchestration tools, use the framework below.
4. **Ambiguous requests** -- if the request is "schedule my data pipeline" without specifying a tool, gather context (cloud provider, existing stack, team skills) before recommending one.

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

- The `overview` skill's `references/paradigm-orchestration.md` -- Orchestration paradigm fundamentals (when/why orchestration, common patterns, decision criteria). Read for comparison and architectural questions.
- The `overview` skill's `references/concepts.md` -- ETL/ELT fundamentals that apply across all orchestration tools.
