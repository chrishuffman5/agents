# Apache Spark Version Features

## Version Timeline

| Version | Release Date | Status | Java | Scala |
|---------|-------------|--------|------|-------|
| 3.5.x | Sep 2023 | Extended LTS (security-only, EOL Nov 2027) | 8/11/17 | 2.12/2.13 |
| 4.0.0 | Jun 2025 | Stable (current LTS line) | 17/21 | 2.13 |
| 4.0.2 | Latest patch | Stable | 17/21 | 2.13 |
| 4.1.0 | Dec 2025 | Stable (latest GA) | 17/21 | 2.13 |
| 4.1.1 | Latest patch | Stable | 17/21 | 2.13 |
| 4.2.0 | Preview 3 (Mar 2026) | Preview -- not production-ready | 17/21 | 2.13 |

---

## Spark 3.5.x (Extended LTS -- Security Fixes Only Until Nov 2027)

### Spark Connect
- **General Availability** for Python and Scala clients
- Go client support added
- Decoupled client-server architecture using unresolved logical plans as protocol
- Remote connectivity to Spark clusters using DataFrame API
- Structured Streaming support for both Python and Scala

### PySpark Improvements
- Pandas API on Spark expanded coverage
- PyTorch-based distributed ML support via Spark Connect
- Arrow-optimized Python UDFs

### English SDK for Apache Spark
- Natural language interface for generating Spark code
- Experimental feature for assisted code generation

### Other Notable Features
- `OFFSET` clause in SQL
- Arrow-optimized Python UDTFs (User-Defined Table Functions)
- Simplified `IDENTIFIER` clause for parameterized SQL
- `spark.sql.defaultCatalog` configuration
- `Dataset.as` for schema conversion

### Key Configurations
- Default shuffle partitions: 200 (`spark.sql.shuffle.partitions`)
- AQE enabled by default since 3.2
- Default ANSI mode: **false** (Hive-compatible behavior)

---

## Spark 4.0.0 (Released June 2025) -- Major Version

### ANSI Mode Default
- `spark.sql.ansi.enabled` now **true by default** -- the single largest breaking change
- Stricter SQL semantics: runtime errors instead of silent nulls on overflow, type mismatch, etc.
- Aligns Spark SQL behavior with standard SQL databases (PostgreSQL, etc.)
- Can be disabled: `spark.sql.ansi.enabled=false` for backward compatibility

### VARIANT Data Type
- New native type for semi-structured data (JSON-like) without rigid schemas
- Stores semi-structured data efficiently in Parquet
- Replaces common pattern of storing JSON as strings
- Functions: `parse_json()`, `variant_get()`, `try_variant_get()`, `schema_of_variant()`

### String Collation Support
- Case-insensitive and locale-aware string comparisons
- Collation specified per column or expression
- Syntax: `STRING COLLATE 'UNICODE_CI'`

### Python Data Source API
- Create custom data sources and sinks entirely in Python (no Scala/Java required)
- Supports both batch and streaming queries
- Ideal for Python-centric data engineering teams
- Implements DataSource V2 API from Python

### Polymorphic Python UDTFs
- User-Defined Table Functions that can return different schemas based on input
- `analyze()` static method to determine output schema at plan time
- Partition-by and order-by semantics supported

### Spark Connect Enhancements
- High feature parity with Spark Classic
- New clients for Go, Swift, and Rust
- `spark.api.mode` setting for migration path
- Spark ML on Connect: GA for Python client

### SQL Enhancements
- SQL User-Defined Functions (SQL UDFs)
- Session variables
- Pipe syntax (`|>`) for chaining transformations
- Recursive CTEs (preliminary support)
- SQL scripting (preview)

### Structured Streaming
- Streaming State Store data source for inspecting/debugging state
- Improved checkpoint format

### Platform Changes
- **Java 17** by default (Java 21 supported)
- **Scala 2.13** only (Scala 2.12 dropped)
- **Mesos support removed**
- Servlet API migrated from `javax` to `jakarta`
- Structured logging (JSON format by default)

---

## Spark 4.1.0 (Released December 2025)

### Spark Declarative Pipelines (SDP)
- New declarative framework for building data pipelines
- Define datasets and queries; Spark handles execution graph, dependency ordering, parallelism, checkpoints, retries
- Pipeline spec in YAML format with `libraries` and `storage` fields
- Supports Python, SQL, or mixed source files
- Pipeline objects: flows, streaming tables, materialized views
- Designed for medallion architecture and production ETL

### Structured Streaming Real-Time Mode (RTM)
- Continuous, sub-second latency processing
- Stateless tasks achieve single-digit millisecond P99 latency
- Data streams continuously through operators without blocking
- Longer-duration epochs amortize checkpoint overhead
- Enable with single config change -- no API rewrites needed

### SQL Scripting GA
- Enabled by default
- Improved error handling
- Cleaner declarations
- Variables, loops, conditionals in SQL

### VARIANT GA with Shredding
- Automatically extracts commonly occurring fields within variant columns
- Stores extracted fields as separate typed Parquet fields
- Dramatically reduces I/O by skipping full binary blob reads
- Transparent to queries -- no code changes needed

### Spark ML on Connect GA
- Full ML support via Spark Connect Python client
- Smarter model caching and memory management

### Additional Features
- Recursive CTE support (full)
- Approximate data sketches: KLL (quantiles) and Theta (distinct counts)
- Enhanced PySpark: Arrow-native UDF decorators, eliminating Pandas overhead
- 1,800+ Jira tickets resolved, 230+ contributors

---

## Spark 4.2.0 (Preview -- Expected 2026)

### Status
- Preview 1: January 11, 2026
- Preview 2: February 8, 2026
- Preview 3: March 12, 2026
- **Not a stable release** -- API and functionality may change
- GA release expected mid-2026

### Expected Features
- Continued evolution of Spark Declarative Pipelines
- Further Spark Connect improvements
- Additional SQL and DataFrame API enhancements
- Performance improvements
- Specific feature list will be finalized at GA

---

## Breaking Changes: 3.5 to 4.0 Migration Guide

### Critical Changes

| Area | Change | Impact |
|------|--------|--------|
| ANSI Mode | Default `true` | Queries may throw errors instead of returning null on overflow/type mismatch |
| Java | Minimum Java 17 | JVM upgrade required; Java 8/11 no longer supported |
| Scala | Only Scala 2.13 | Scala 2.12 artifacts no longer published |
| Mesos | Removed | Must migrate to YARN, K8s, or Standalone |
| Servlet API | `javax` → `jakarta` | Custom UI extensions, REST clients may need updates |
| Accumulator v1 | Removed | Must use v2 API |
| TaskContext | `isRunningLocally` removed | Remove usage |
| ExecutorPlugin | Replaced by `SparkPlugin` | Rewrite plugins |

### ANSI Mode Behavioral Changes
- **Arithmetic overflow**: Throws `ArithmeticException` instead of wrapping/returning null
- **Cast overflow**: Returns error instead of null (e.g., casting large timestamp to int)
- **Division by zero**: Throws error instead of returning null
- **Invalid casts**: Throws error instead of returning null
- **Array index out of bounds**: Throws error instead of returning null

### Configuration Changes
- `spark.sql.legacy.ctePrecedencePolicy` default: `EXCEPTION` → `CORRECTED` (inner CTEs take precedence)
- `spark.sql.legacy.timeParserPolicy` default: `EXCEPTION` → `CORRECTED`
- Various `spark.sql.legacy.*` defaults changed

### Recommended Migration Steps
1. **Audit**: Run with `spark.sql.ansi.enabled=true` on Spark 3.5 first to identify failures
2. **Test**: Run parallel 3.5 and 4.0 environments
3. **Fix**: Update code that relies on null-on-overflow behavior (use `try_*` functions)
4. **JVM**: Upgrade to Java 17 runtime
5. **Scala**: Rebuild libraries against Scala 2.13
6. **Dependencies**: Update any `javax.servlet` references to `jakarta.servlet`
7. **Plugins**: Migrate ExecutorPlugin → SparkPlugin
8. **Validate**: Comprehensive regression testing with production-like data
9. **Rollback plan**: Maintain ability to revert to Spark 3.5.x

### Compatibility Escape Hatches
```python
# Disable ANSI mode for backward compatibility
spark.conf.set("spark.sql.ansi.enabled", "false")

# Use try_* functions for null-on-error behavior
# try_cast, try_add, try_divide, try_multiply, try_subtract
df.select(try_cast(col("value").cast("int")))
```

---

## Version Selection Guidance

| Scenario | Recommended Version |
|----------|-------------------|
| New greenfield project | Spark 4.1.x |
| Existing Spark 3.x in production | Stay on 3.5.x LTS, plan 4.0 migration |
| Need Declarative Pipelines | Spark 4.1.x |
| Need sub-second streaming latency | Spark 4.1.x (RTM) |
| Databricks customers | Follow Databricks Runtime versioning |
| Cannot upgrade Java beyond 11 | Stay on Spark 3.5.x |
| Need bleeding-edge features | Spark 4.2.0 preview (non-production) |
