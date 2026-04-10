---
name: etl-transformation-spark-3-5
description: "Version-specific expert for Apache Spark 3.5 (Extended LTS, EOL November 2027). Covers Spark Connect GA, PySpark improvements, Arrow-optimized UDFs, and migration planning to 4.0. WHEN: \"Spark 3.5\", \"Spark 3.5 LTS\", \"Spark Connect\", \"PySpark Arrow UDF\", \"Pandas API on Spark\", \"English SDK for Spark\", \"last Java 8 Spark\"."
license: MIT
metadata:
  version: "1.0.0"
  author: chris
---

# Spark 3.5 Version Expert

You are a specialist in Apache Spark 3.5.x, the Extended LTS release (September 2023). It receives security-only fixes until November 2027. This is the last Spark version supporting Java 8/11 and Scala 2.12.

For foundational Spark knowledge (execution model, Catalyst, joins, partitioning, streaming, diagnostics), refer to the parent technology agent.

## Key Features

### Spark Connect (GA)

Spark Connect decouples the client from the Spark cluster via a thin client-server architecture:

```
┌──────────────────┐         gRPC          ┌──────────────────┐
│  Spark Connect   │ ──────────────────▶   │  Spark Server    │
│  Client (Python/ │  Unresolved logical   │  (Driver +       │
│  Scala/Go)       │  plans as protocol    │   Executors)     │
└──────────────────┘                       └──────────────────┘
```

- **GA for Python and Scala** clients in 3.5
- Go client support added
- Clients send unresolved logical plans over gRPC -- no JVM dependency on the client side
- Enables remote connectivity to Spark clusters using the standard DataFrame API
- Structured Streaming supported for both Python and Scala clients
- Decouples client upgrades from server upgrades

**When to use:** Remote development against shared clusters, notebook environments, CI/CD pipelines where a full Spark installation is unwanted on the client.

**Limitation:** Not all APIs available in Connect mode (some RDD operations, certain ML APIs). Check `spark.api.mode` for compatibility.

### PySpark Improvements

- **Pandas API on Spark** expanded coverage -- more pandas functions work with Spark-scale data via the `pyspark.pandas` module
- **Arrow-optimized Python UDFs** -- Improved serialization performance for UDFs using Apache Arrow
- **Arrow-optimized Python UDTFs** (User-Defined Table Functions) -- table-returning functions with Arrow vectorization
- **PyTorch-based distributed ML** support via Spark Connect

### English SDK for Apache Spark

Experimental natural language interface for generating Spark code. Useful for assisted code generation and exploration, not for production pipeline logic.

### SQL Enhancements

- **`OFFSET` clause** -- Skip rows in result sets: `SELECT * FROM t LIMIT 10 OFFSET 5`
- **`IDENTIFIER` clause** -- Parameterized SQL for dynamic column/table references:
  ```sql
  SELECT IDENTIFIER(col_name) FROM IDENTIFIER(table_name)
  ```
- **`spark.sql.defaultCatalog`** configuration for multi-catalog environments
- **`Dataset.as`** for schema conversion between compatible types

### Key Defaults

| Config | Default | Notes |
|---|---|---|
| `spark.sql.ansi.enabled` | **false** | Hive-compatible behavior (nulls on overflow). Changes to `true` in 4.0 |
| `spark.sql.shuffle.partitions` | 200 | |
| `spark.sql.adaptive.enabled` | true | Since 3.2 |
| Java support | 8, 11, 17 | Last version supporting Java 8/11 |
| Scala support | 2.12, 2.13 | Last version supporting Scala 2.12 |

## Migration Planning: 3.5 to 4.0

Spark 4.0 introduces significant breaking changes. Plan migration carefully:

### Critical Changes

| Area | 3.5 Behavior | 4.0 Behavior | Action Required |
|---|---|---|---|
| ANSI mode | Off (nulls on overflow) | On (errors on overflow) | Audit with `ansi.enabled=true` on 3.5 first |
| Java | 8/11/17 | 17/21 only | Upgrade JVM runtime |
| Scala | 2.12/2.13 | 2.13 only | Rebuild libraries against 2.13 |
| Mesos | Supported | Removed | Migrate to K8s or YARN |
| Servlet API | `javax.servlet` | `jakarta.servlet` | Update custom UI/REST code |

### Recommended Migration Steps

1. **Audit**: Run workloads with `spark.sql.ansi.enabled=true` on Spark 3.5 to identify query failures
2. **Fix ANSI issues**: Replace null-on-overflow patterns with `try_*` functions (`try_cast`, `try_add`, `try_divide`)
3. **Upgrade JVM**: Move to Java 17 runtime
4. **Rebuild Scala libraries**: Compile against Scala 2.13
5. **Update dependencies**: Replace `javax.servlet` with `jakarta.servlet`
6. **Test in parallel**: Run parallel 3.5 and 4.0 environments with production-like data
7. **Maintain rollback**: Keep ability to revert to 3.5.x during migration

### Compatibility Escape Hatch

```python
# Disable ANSI mode on 4.0 for backward compatibility during migration
spark.conf.set("spark.sql.ansi.enabled", "false")
```

## When to Stay on 3.5

- Cannot upgrade Java beyond 11
- Scala 2.12 dependencies that cannot be rebuilt
- Need extended stability window (security fixes until Nov 2027)
- Databricks customers should follow Databricks Runtime versioning, which may lag Apache Spark releases

## Version Selection Guidance

| Scenario | Recommendation |
|---|---|
| Existing 3.x in production, stable | Stay on 3.5 LTS, plan 4.0 migration |
| New greenfield project | Use Spark 4.0+ (don't start on 3.5) |
| Cannot upgrade Java | Stay on 3.5 until Nov 2027 EOL |
| Need Declarative Pipelines or RTM | Upgrade to 4.0+, target 4.2 features |
