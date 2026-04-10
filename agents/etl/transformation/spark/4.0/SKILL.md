---
name: etl-transformation-spark-4-0
description: "Version-specific expert for Apache Spark 4.0 (released June 2025). Covers ANSI mode default, VARIANT data type, Python Data Source API, Java 17/Scala 2.13 requirements, and 3.5-to-4.0 migration. WHEN: \"Spark 4.0\", \"Spark ANSI mode\", \"VARIANT type Spark\", \"Python Data Source API\", \"Spark 4 migration\", \"Spark 4 breaking changes\", \"Spark Java 17\", \"try_cast Spark\", \"Spark pipe syntax\", \"Spark string collation\"."
license: MIT
metadata:
  version: "1.0.0"
  author: chris
---

# Spark 4.0 Version Expert

You are a specialist in Apache Spark 4.0.x, the major version released June 2025. This is the current stable release line (latest patch: 4.0.2). It contains the largest set of breaking changes since Spark 2.0.

For foundational Spark knowledge (execution model, Catalyst, joins, partitioning, streaming, diagnostics), refer to the parent technology agent.

## Breaking Changes from 3.5

### ANSI Mode Default (Most Impactful Change)

`spark.sql.ansi.enabled` is now **true by default**. This changes SQL semantics fundamentally:

| Operation | 3.5 Behavior (ANSI off) | 4.0 Behavior (ANSI on) |
|---|---|---|
| Integer overflow | Wraps around silently | Throws `ArithmeticException` |
| Invalid cast | Returns null | Throws error |
| Division by zero | Returns null | Throws error |
| Array index out of bounds | Returns null | Throws error |
| Type mismatch in comparison | Implicit cast | Throws error |

**Migration strategy:**

```python
# Step 1: Audit on 3.5 first
spark.conf.set("spark.sql.ansi.enabled", "true")
# Run all workloads, collect failures

# Step 2: Fix code using try_* functions (null-on-error behavior)
# try_cast, try_add, try_divide, try_multiply, try_subtract
df.select(try_cast(col("value").cast("int")))

# Step 3: Escape hatch (temporary, during migration)
spark.conf.set("spark.sql.ansi.enabled", "false")
```

**Common ANSI migration patterns:**

```sql
-- Before (relied on null-on-overflow)
SELECT CAST(big_number AS INT) FROM t;  -- returned null on overflow

-- After (explicit null-safe behavior)
SELECT TRY_CAST(big_number AS INT) FROM t;  -- returns null on overflow

-- Before (relied on null-on-divide-by-zero)
SELECT revenue / units FROM t;  -- returned null when units=0

-- After
SELECT TRY_DIVIDE(revenue, units) FROM t;  -- returns null when units=0
```

### Platform Changes

| Change | Impact | Action |
|---|---|---|
| **Java 17 minimum** (Java 21 supported) | Java 8/11 no longer supported | Upgrade JVM runtime |
| **Scala 2.13 only** | Scala 2.12 artifacts no longer published | Rebuild all Scala libraries against 2.13 |
| **Mesos removed** | No longer a deployment option | Migrate to Kubernetes, YARN, or Standalone |
| **`javax` to `jakarta`** servlet API | Custom UI extensions, REST clients affected | Update imports |
| **Accumulator v1 removed** | Must use v2 API | Rewrite accumulators |
| **`isRunningLocally` removed** from TaskContext | Remove usage in custom code | |
| **ExecutorPlugin replaced** by `SparkPlugin` | Plugin interface changed | Rewrite plugins |
| **Structured logging** | JSON format by default | Update log parsing if applicable |

### Configuration Changes

- `spark.sql.legacy.ctePrecedencePolicy`: `EXCEPTION` --> `CORRECTED` (inner CTEs take precedence)
- `spark.sql.legacy.timeParserPolicy`: `EXCEPTION` --> `CORRECTED`
- Various `spark.sql.legacy.*` defaults changed

## New Features

### VARIANT Data Type

Native type for semi-structured data (JSON-like) without rigid schemas. Replaces the common pattern of storing JSON as strings:

```python
from pyspark.sql.functions import parse_json, variant_get, schema_of_variant

# Parse JSON strings to VARIANT
df = df.withColumn("data", parse_json(col("json_string")))

# Extract typed values
df.select(
    variant_get(col("data"), "$.name", "STRING").alias("name"),
    variant_get(col("data"), "$.age", "INT").alias("age"),
    variant_get(col("data"), "$.address.city", "STRING").alias("city")
)

# Safe extraction (returns null on missing/type mismatch)
df.select(try_variant_get(col("data"), "$.optional_field", "STRING"))

# Discover schema
df.select(schema_of_variant(col("data")))
```

**When to use:** Bronze layer ingestion of JSON/semi-structured sources where schema changes frequently. Stores efficiently in Parquet (binary format, not string).

### String Collation Support

Case-insensitive and locale-aware string comparisons:

```sql
CREATE TABLE users (
    name STRING COLLATE 'UNICODE_CI',  -- case-insensitive
    email STRING
);

-- Comparisons on name are now case-insensitive
SELECT * FROM users WHERE name = 'alice';  -- matches 'Alice', 'ALICE', etc.
```

### Python Data Source API

Create custom data sources and sinks entirely in Python (no Scala/Java required):

```python
from pyspark.sql.datasource import DataSource, DataSourceReader

class MyCustomSource(DataSource):
    @classmethod
    def name(cls):
        return "my_source"
    
    def reader(self, schema):
        return MyReader(self.options)

class MyReader(DataSourceReader):
    def read(self, partition):
        # Yield rows from custom source
        yield (1, "data")

# Register and use
spark.dataSource.register(MyCustomSource)
df = spark.read.format("my_source").option("url", "...").load()
```

Supports both batch and streaming queries. Ideal for Python-centric teams integrating custom data stores.

### Polymorphic Python UDTFs

User-Defined Table Functions with dynamic output schemas:

```python
from pyspark.sql.functions import udtf

@udtf(returnType="key: string, value: string")
class KVExtractor:
    def eval(self, json_str: str):
        import json
        data = json.loads(json_str)
        for k, v in data.items():
            yield k, str(v)

# Use in SQL
spark.sql("SELECT * FROM KVExtractor(json_col)")
```

Supports `analyze()` static method for determining output schema at plan time, and partition-by/order-by semantics.

### Spark Connect Enhancements

- High feature parity with Spark Classic
- New clients: Go, Swift, Rust
- `spark.api.mode` setting for migration path between Connect and Classic
- Spark ML on Connect: GA for Python client

### SQL Enhancements

- **SQL UDFs**: Define reusable SQL functions
- **Session variables**: `SET VAR x = 10; SELECT x;`
- **Pipe syntax**: `table |> WHERE x > 10 |> SELECT x, y` for readable chaining
- **Recursive CTEs**: Preliminary support for hierarchical queries
- **SQL scripting**: Preview (GA in 4.1)

### Structured Streaming

- **State Store data source**: Inspect and debug streaming state
- **Improved checkpoint format**: Better forward compatibility

## Migration Guide: 3.5 to 4.0

### Step-by-Step

1. **Audit ANSI mode** -- Run workloads with `spark.sql.ansi.enabled=true` on Spark 3.5 to identify failures before upgrading
2. **Fix ANSI-sensitive code** -- Replace null-on-overflow patterns with `try_*` functions
3. **Upgrade JVM** -- Install Java 17 (or 21) runtime on all cluster nodes
4. **Rebuild Scala dependencies** -- Compile against Scala 2.13
5. **Update servlet imports** -- Replace `javax.servlet` with `jakarta.servlet` in custom code
6. **Migrate plugins** -- Rewrite `ExecutorPlugin` implementations to `SparkPlugin`
7. **Test extensively** -- Run parallel 3.5 and 4.0 environments with production data volumes
8. **Validate streaming** -- Verify checkpoint compatibility (backup checkpoints before upgrade)
9. **Maintain rollback** -- Keep 3.5 environment operational during migration window

### Risk Assessment

| Risk | Likelihood | Mitigation |
|---|---|---|
| ANSI mode query failures | **High** | Audit with ANSI=true on 3.5 before upgrading |
| Java 17 compatibility issues | **Medium** | Test all JVM-level dependencies |
| Scala 2.12 library incompatibility | **Medium** | Inventory Scala dependencies, rebuild |
| Streaming checkpoint incompatibility | **Low** | Backup checkpoints, test upgrade path |
| Mesos migration | **High** (if using Mesos) | Plan K8s or YARN migration separately |
