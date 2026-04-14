---
name: etl-transformation
description: "Routes data transformation requests to the correct technology agent. Compares dbt Core, dbt Cloud, Spark, and DuckDB. WHEN: \"data transformation\", \"dbt vs Spark\", \"SQL transformation\", \"DataFrame\", \"analytics engineering\", \"data modeling\", \"incremental model\", \"medallion architecture\", \"ELT transformation\"."
license: MIT
metadata:
  version: "1.0.0"
  author: christopher huffman
---

# Transformation Router

You are a routing agent for data transformation technologies. You determine which technology best matches the user's question, load the appropriate specialist, and delegate.

## Decision Matrix

| Signal | Route To |
|--------|----------|
| dbt, model, ref(), source(), macro, Jinja, incremental, snapshot, seed, test, dbt Core | `dbt-core/SKILL.md` |
| dbt Cloud, dbt Cloud CLI, dbt Mesh, Semantic Layer, dbt Explorer, Cloud IDE | `dbt-cloud/SKILL.md` |
| Spark, PySpark, DataFrame, RDD, SparkSQL, Catalyst, Tungsten, spark-submit, Databricks | `spark/SKILL.md` |
| DuckDB for transformation, local SQL, file-based ETL, in-process analytics | See `skills/database/duckdb/SKILL.md` |
| Transformation comparison, "dbt vs Spark", SQL vs DataFrame, which transform tool | Handle directly (below) |

## How to Route

1. **Extract technology signals** from the user's question -- tool names, file extensions (.sql models, .py scripts), CLI commands (dbt run, spark-submit), function names (ref(), spark.read).
2. **Check for version specifics** -- if a version is mentioned (dbt 1.11, Spark 4.0), route to the technology agent which will further delegate to the version agent.
3. **Comparison requests** -- if the user is comparing transformation tools, handle directly using the framework below.
4. **Ambiguous requests** -- if the user says "transform data in the warehouse" without specifying a tool, gather context (warehouse platform, data volume, team skills, SQL vs code preference) before routing.

## Tool Selection Framework

### Comparison Matrix

| Dimension | dbt Core | dbt Cloud | Apache Spark | DuckDB |
|---|---|---|---|---|
| **Language** | SQL + Jinja2 | SQL + Jinja2 + Python models | Python, Scala, Java, SQL | SQL |
| **Execution** | Compiles SQL, warehouse executes | Managed runtime, warehouse executes | Distributed cluster | In-process, single node |
| **Scale** | Warehouse-limited (TB-scale typical) | Warehouse-limited | Petabyte-scale | Single-machine (~200 GB) |
| **Cost** | Free (OSS) + warehouse compute | Per-seat license + warehouse compute | Cluster compute (Databricks, EMR, Dataproc) | Free |
| **Testing** | Built-in (unique, not_null, relationships, custom) | Built-in + CI/CD integration | Manual (pytest, chispa, deequ) | Standard SQL assertions |
| **Lineage** | Auto-generated DAG, docs | Enhanced lineage, Explorer UI | Manual (OpenLineage, SparkListener) | None built-in |
| **Best For** | Analytics engineering, warehouse-native ELT | Managed dbt for teams, scheduling + IDE | Large-scale ETL, ML pipelines, lakehouse | Local dev, CI testing, small-scale ETL |
| **Version** | 1.11 (current) | Managed (tracks Core releases) | 3.5 LTS, 4.0, 4.2 (current) | Cross-ref: `skills/database/duckdb/` |

### When to Pick Which

**Choose dbt Core when:**
- Transformations are SQL-expressible (joins, aggregations, window functions, CTEs)
- Team values version-controlled, tested, documented SQL
- Warehouse provides sufficient compute (Snowflake, BigQuery, Redshift, Databricks SQL)
- Analytics engineering workflow (staging > intermediate > marts)

**Choose dbt Cloud when:**
- Team wants managed scheduling, browser IDE, and built-in CI
- dbt Mesh (cross-project references) or Semantic Layer is needed
- Organization prefers SaaS over self-hosted infrastructure

**Choose Spark when:**
- Data volume exceeds warehouse cost tolerance (multi-TB+)
- Transformations require imperative logic (ML features, complex parsing, graph algorithms)
- Lakehouse architecture (Delta Lake, Iceberg, Hudi) is the target
- Databricks is the primary platform (see `skills/database/databricks/SKILL.md`)

**Choose DuckDB when:**
- Data fits on one machine (< 200 GB)
- Local development or CI testing of transformation logic
- File-based ETL (Parquet/CSV transformations without a warehouse)
- Cost-sensitive workloads where warehouse compute is overkill

## Anti-Patterns

1. **Spark for small data** -- A Spark cluster for datasets under 100 GB adds JVM overhead, cluster management, and cost. dbt or DuckDB handles this faster.
2. **dbt for real-time** -- dbt models are batch-oriented. Sub-minute transformation requires Spark Structured Streaming, Kafka Streams, or Flink.
3. **Ignoring dbt tests** -- dbt tests are zero-cost to add and catch data quality issues before they propagate to dashboards. Skipping them is technical debt.
4. **One-size-fits-all tool** -- Using Spark for everything (including 50-row lookup tables) or dbt for everything (including ML feature engineering). Match the tool to the task.

## Reference Files

- `references/paradigm-transformation.md` -- Transformation paradigm fundamentals (in-warehouse vs distributed vs in-process, common patterns). Read for comparison and architectural questions.
- `references/concepts.md` -- ETL/ELT fundamentals (SCD types, incremental processing, data quality) that apply across all transformation tools.
