# SSAS Diagnostics

## Performance Analysis Tools

### DAX Studio
The primary tool for DAX query analysis and performance troubleshooting.

**Key features:**
- **Server Timings**: Breaks down query execution into Storage Engine (SE) time and Formula Engine (FE) time. This is the single most important diagnostic for understanding query performance
- **Query Plan**: Shows logical and physical query plans to understand how the engine processes a query
- **Trace output**: Captures xVelocity/VertiPaq SE queries (the internal queries the engine generates)
- **Benchmark mode**: Run queries multiple times to get consistent timing measurements
- **Model Metrics**: Built-in VertiPaq Analyzer for examining model structure and memory usage

**Interpreting Server Timings:**
- **High SE time, low FE time**: Storage Engine bottleneck. Look at column cardinality, missing aggregations, or cold cache. SE is multi-threaded and benefits from warm cache
- **Low SE time, high FE time**: Formula Engine bottleneck. The DAX itself is complex. FE is single-threaded, and caching has less impact -- a warm-cache run takes nearly as long as cold-cache
- **Many SE queries**: The DAX may be generating excessive internal queries. Simplify the measure or use variables

### SQL Server Profiler / Extended Events (XEvents)

**Profiler (legacy):**
- Captures SSAS trace events: query begin/end, process begin/end, errors
- Useful for monitoring all queries hitting the server
- Higher overhead than XEvents; not recommended for production monitoring

**Extended Events (recommended):**
- Lightweight event tracing system
- SSAS 2025 exposes execution metrics via XEvents for detailed query-level performance analysis
- Key events to monitor:
  - `QueryBegin` / `QueryEnd`: Track query execution time
  - `ProgressReportBegin` / `ProgressReportEnd`: Monitor processing operations
  - `ResourceUsage`: Memory and CPU consumption per query
  - `Error`: Processing and query errors

### Dynamic Management Views (DMVs)

DMVs provide metadata and runtime information about the SSAS instance. Queried via DAX Studio, SSMS, or any XMLA-capable tool.

**Key DMVs:**

| DMV | Purpose |
|-----|---------|
| `$SYSTEM.DISCOVER_SESSIONS` | Active sessions and their resource usage |
| `$SYSTEM.DISCOVER_COMMANDS` | Currently executing commands |
| `$SYSTEM.DISCOVER_CONNECTIONS` | Active connections to the server |
| `SYSTEMRESTRICTSCHEMA($SYSTEM.DISCOVER_STORAGE_TABLE_COLUMNS)` | Column-level storage statistics (cardinality, size, encoding) |
| `SYSTEMRESTRICTSCHEMA($SYSTEM.DISCOVER_STORAGE_TABLES)` | Table-level storage statistics |
| `$SYSTEM.DISCOVER_OBJECT_MEMORY_USAGE` | Memory consumption by object |
| `$SYSTEM.DISCOVER_PERFORMANCE_COUNTERS` | Performance counter values |
| `$SYSTEM.MDSCHEMA_MEASUREGROUP_DIMENSIONS` | Measure group and dimension relationships (Multidimensional) |

### VertiPaq Analyzer

Specialized analysis of VertiPaq storage structures.

**What it reveals:**
- Total model size and per-table sizes
- Per-column: cardinality, data size, dictionary size, number of segments
- Hierarchy storage costs
- Relationship sizes
- Identifies the "most expensive" objects consuming the most memory

**How to access:**
- DAX Studio: Advanced tab > View Metrics
- Tabular Editor: built-in via SQLBI's VertiPaq Analyzer library
- Standalone: VertiPaq Analyzer Excel workbook (SQLBI)

---

## Common Performance Issues

### High Cardinality Columns
**Symptoms:** Large model size, slow processing, high memory consumption
**Diagnosis:** VertiPaq Analyzer shows columns with millions of distinct values consuming disproportionate space
**Solutions:**
- Remove the column if not needed for analysis
- Split into lower-cardinality components (e.g., date + time from datetime)
- Round numeric values to reduce distinct values
- Consider whether the column should be in the model at all

### Complex DAX Measures
**Symptoms:** Slow query performance, high Formula Engine time in DAX Studio Server Timings
**Diagnosis:** Server Timings show FE >> SE time; query plan shows many internal iterations
**Solutions:**
- Simplify DAX logic; use variables to cache intermediate results
- Avoid nested iterators (SUMX inside SUMX)
- Replace FILTER(ALL(...)) with direct column filters in CALCULATE arguments
- Push calculations to the source query / ETL layer if they do not need to be dynamic
- Avoid FORMAT() in measures (forces FE processing)

### Large Models Exceeding Memory
**Symptoms:** Out-of-memory errors, server paging, degraded performance for all queries
**Diagnosis:** Monitor Windows performance counters for SSAS memory usage; check VertiPaq Analyzer total model size
**Solutions:**
- Apply column cardinality optimizations (see above)
- Remove unused tables and columns
- Partition the model: consider splitting into multiple models if the domain allows
- Upgrade server memory or use a larger Azure SKU
- Consider DirectQuery for the largest tables

### Slow DirectQuery Performance
**Symptoms:** High query latency, queries timing out
**Diagnosis:** Trace the SQL generated by DAX and analyze execution plans on the source database
**Solutions:**
- Optimize source database indexes for the generated SQL patterns
- Use SSAS 2022+ parallel DirectQuery to reduce serialized latency
- Use SSAS 2025 Horizontal Fusion to reduce the number of generated SQL queries
- Consider importing the most-queried data (hybrid approach with composite models)

---

## Memory Pressure

### VertiPaq Memory Usage
- All in-memory data resides in SSAS process memory
- Memory = sum of all loaded model data + processing workspace + query workspace + caches
- The server caches query results in both the Formula Engine cache and Storage Engine cache

### Paging
- If SSAS memory exceeds available RAM, the OS pages VertiPaq data to disk
- Paged queries are dramatically slower (orders of magnitude)
- Monitor: Windows Performance Monitor > Process > Working Set for the msmdsrv.exe process
- If working set is significantly less than commit size, paging is occurring

### Resource Governance Settings

| Setting | Default | Purpose |
|---------|---------|---------|
| `Memory\LowMemoryLimit` | 65% | SSAS starts clearing caches when memory exceeds this % of total physical memory |
| `Memory\TotalMemoryLimit` | 80% | Hard cap; SSAS may reject new requests if processing would exceed this |
| `Memory\HardMemoryLimit` | 80% | Absolute limit; operations fail if they would exceed this |
| `Memory\VertiPaqPagingPolicy` | 1 | 0 = no paging (fail on OOM); 1 = allow paging to disk (default) |

**Recommendations:**
- Size the server so all active models fit in memory with 20-30% headroom
- If multiple models share a server, monitor per-model memory via DMVs
- Set VertiPaqPagingPolicy to 0 in production if you prefer fast failure over degraded performance
- Consider splitting models across multiple servers if memory is the bottleneck

---

## Processing Failures

### Data Type Mismatches
**Symptoms:** Processing fails with conversion errors
**Common causes:**
- Source column data type changed after model was designed
- Null values where the model expects non-nullable data
- String values in numeric columns (dirty source data)
- Date format inconsistencies

**Solutions:**
- Validate source data types before processing
- Add error handling in source queries (CAST/CONVERT with defaults)
- Configure error handling in the partition properties (KeyErrorLimit, KeyErrorAction)
- Use staging views that enforce consistent data types

### Source Connectivity Issues
**Symptoms:** Processing fails with connection errors, timeouts, or authentication failures
**Common causes:**
- Source database unavailable or under maintenance
- Credentials expired or changed
- Network connectivity issues between SSAS server and source
- Connection pool exhaustion on the source

**Solutions:**
- Implement retry logic in processing automation scripts
- Monitor source database availability before triggering processing
- Use service accounts with non-expiring credentials (or automate credential rotation)
- Set appropriate connection timeout values in data source properties

### Timeout Issues
**Symptoms:** Processing starts but fails after a period with timeout errors
**Common causes:**
- ExternalCommandTimeout too low for the data volume (default: 3,600 seconds / 60 minutes)
- Source query takes too long to return results
- Network timeouts between SSAS and source

**Solutions:**
- Increase ExternalCommandTimeout in SSAS server properties
- Optimize source queries (add indexes, reduce data volume per partition)
- Partition large tables into smaller chunks that process within timeout limits
- Process partitions sequentially with MaxParallelism = 1 if source cannot handle concurrent loads

### Key Errors (Multidimensional)
**Symptoms:** Processing fails with "key not found" or "duplicate key" errors
**Common causes:**
- Fact table contains attribute key values that do not exist in the dimension table
- Referential integrity violations in the source
- Late-arriving dimensions (facts arrive before dimensions are loaded)

**Solutions:**
- Fix referential integrity issues in the ETL layer
- Configure ErrorConfiguration on the partition to handle key errors (ignore, convert to unknown, or log and continue)
- Ensure dimension processing completes before fact processing
- Add unknown member handling to dimensions

---

## Query Performance Deep Dive

### Storage Engine vs. Formula Engine

**Storage Engine (SE):**
- Multi-threaded
- Reads data from VertiPaq segments
- Performs scans, filters, and simple aggregations
- Results are cached and reusable across queries
- Cache is invalidated on model processing
- Warm-cache queries can be dramatically faster than cold-cache

**Formula Engine (FE):**
- Single-threaded
- Performs complex calculations, iterations, context transitions
- Orchestrates SE queries and combines their results
- Has its own cache (flat cache limited to 10% of TotalMemoryLimit, plus calculated data cache)
- Warm-cache benefit is minimal for FE-bound queries

### Cache Behavior

**Storage Engine Cache:**
- Caches the results of SE queries (subcube requests)
- Shared across all users and queries
- Cleared when the model is processed or memory pressure triggers eviction
- Warm-cache performance can be 10-100x faster than cold-cache

**Formula Engine Cache:**
- Caches flat data and calculated results
- Flat cache limited to 10% of TotalMemoryLimit
- Results are reusable across users if the same calculation context occurs
- Less impactful than SE cache for performance optimization

**Windows File System Cache:**
- VertiPaq data on disk benefits from OS-level file caching
- Relevant when data is paged out of SSAS memory

### Query Optimization Checklist

1. **Capture Server Timings** in DAX Studio for the slow query
2. **Identify the bottleneck**: SE-bound or FE-bound?
3. If **SE-bound**:
   - Check if the query is running on cold cache (re-run to verify)
   - Look for high-cardinality columns being scanned
   - Check for missing or inefficient aggregations (Multidimensional)
   - Verify partition pruning is working (check SE query count)
4. If **FE-bound**:
   - Simplify the DAX measure
   - Use variables to reduce redundant calculations
   - Avoid nested iterators
   - Check for unnecessary context transitions
   - Consider pre-calculating in ETL if the logic is static
5. **Monitor over time**: Use XEvents or Profiler to track query patterns and identify recurring slow queries
6. **Benchmark**: Use DAX Studio benchmark mode to get repeatable measurements
