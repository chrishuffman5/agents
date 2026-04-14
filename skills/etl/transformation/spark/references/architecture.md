# Spark Architecture Deep Dive

## Driver-Executor Model

Spark applications run as independent sets of processes on a cluster, coordinated by the Driver:

```
                   ┌─────────────────────────┐
                   │         Driver           │
                   │  ┌───────────────────┐   │
                   │  │   SparkSession    │   │
                   │  │   ┌───────────┐   │   │
                   │  │   │ Catalyst  │   │   │
                   │  │   │ Optimizer │   │   │
                   │  │   └───────────┘   │   │
                   │  │   ┌───────────┐   │   │
                   │  │   │DAG Sched- │   │   │
                   │  │   │  uler     │   │   │
                   │  │   └───────────┘   │   │
                   │  │   ┌───────────┐   │   │
                   │  │   │Task Sched-│   │   │
                   │  │   │  uler     │   │   │
                   │  │   └───────────┘   │   │
                   │  └───────────────────┘   │
                   └────────────┬──────────────┘
                               │
              ┌────────────────┼────────────────┐
              │                │                │
     ┌────────▼──────┐ ┌──────▼────────┐ ┌─────▼───────┐
     │  Executor 1   │ │  Executor 2   │ │  Executor N  │
     │ ┌──────────┐  │ │ ┌──────────┐  │ │ ┌──────────┐ │
     │ │ Task Slot│  │ │ │ Task Slot│  │ │ │ Task Slot│ │
     │ │ Task Slot│  │ │ │ Task Slot│  │ │ │ Task Slot│ │
     │ │ Task Slot│  │ │ │ Task Slot│  │ │ │ Task Slot│ │
     │ ├──────────┤  │ │ ├──────────┤  │ │ ├──────────┤ │
     │ │Block Mgr │  │ │ │Block Mgr │  │ │ │Block Mgr │ │
     │ │ (Cache)  │  │ │ │ (Cache)  │  │ │ │ (Cache)  │ │
     │ └──────────┘  │ │ └──────────┘  │ │ └──────────┘ │
     └───────────────┘ └───────────────┘ └──────────────┘
```

**Driver** -- A JVM process that:
- Hosts the SparkSession (unified entry point since Spark 2.0)
- Translates user code into a DAG of stages and tasks
- Negotiates resources with the cluster manager
- Collects results from executors
- Runs in `client` mode (on submitting machine) or `cluster` mode (inside the cluster)

**Executors** -- JVM processes on worker nodes that:
- Execute tasks assigned by the driver
- Store cached data via BlockManager
- Have fixed cores (task slots) and memory
- Report heartbeats back to the driver
- Created at application start, destroyed at end (unless dynamic allocation)

**Cluster Manager** -- External resource allocator (Standalone, YARN, Kubernetes). Spark is agnostic to the cluster manager; all three support the same Spark APIs.

## Execution Flow: From Code to Tasks

### Step 1: Logical Plan (Catalyst Analysis)

User code (DataFrame/SQL) produces an unresolved logical plan. Catalyst resolves column references, table names, and types using the catalog.

```
Unresolved Plan          Resolved Plan
─────────────────        ──────────────────
Filter ???.age > 25  --> Filter users.age > 25
  Scan ???.users             Scan catalog.db.users
                              columns: [name: STRING, age: INT]
```

### Step 2: Logical Optimization

Catalyst applies rule-based transformations to the resolved plan:

| Optimization | What It Does | Impact |
|---|---|---|
| **Predicate pushdown** | Moves filters closer to data source (Scan node) | Reduces data read from storage |
| **Projection pruning** | Removes unreferenced columns from Scan | Reduces I/O and memory |
| **Constant folding** | Evaluates constant expressions at compile time | Eliminates runtime computation |
| **Boolean simplification** | Simplifies boolean expressions | Reduces filter evaluation cost |
| **Join reordering** | Reorders joins based on table statistics (CBO) | Reduces intermediate data size |
| **Subquery elimination** | Converts correlated subqueries to joins | Avoids repeated subquery execution |

### Step 3: Physical Planning

Catalyst generates candidate physical plans and selects the cheapest using a cost model:

- Sort-merge join vs broadcast hash join vs shuffle hash join
- Hash aggregate vs sort aggregate
- Scan with predicate pushdown vs scan + filter

### Step 4: Code Generation (Tungsten)

The selected physical plan is compiled to optimized JVM bytecode via whole-stage code generation. Multiple operators are fused into a single function, eliminating virtual method dispatch overhead.

```
Physical Plan              Generated Code
──────────────             ──────────────
*HashAggregate             while (input.hasNext()) {
  *Filter                    row = input.next();
    *Scan parquet              if (row.getInt(1) > 25) {
                                 agg.update(row.getString(0), row.getInt(2));
                               }
                             }
```

The asterisk `*` prefix in `explain()` output indicates whole-stage codegen is active for that operator.

## Catalyst Optimizer Internals

Catalyst operates on trees of logical plan nodes. Optimization rules are expressed as tree transformations:

**Rule application order:**
1. Analysis rules (resolve references)
2. Optimizer rules (logical optimization, applied repeatedly until fixed point)
3. Physical planning rules (strategy selection)
4. Code generation

**Cost-Based Optimization (CBO):**
- Requires table/column statistics: `ANALYZE TABLE t COMPUTE STATISTICS FOR ALL COLUMNS`
- Uses cardinality estimates to choose join order and join strategy
- Effective for multi-way joins where join order matters significantly
- Falls back to heuristics when statistics are unavailable

## Tungsten Execution Engine

Tungsten optimizes the physical execution layer across three dimensions:

### Memory Management
- **Off-heap allocation** via `sun.misc.Unsafe` -- bypasses JVM garbage collector
- **UnsafeRow** binary format -- fixed-width fields stored as raw bytes, variable-length fields as offsets + data
- Rows never deserialized to Java objects during computation (when possible)
- Reduces GC pressure dramatically compared to Java object-based processing

### Cache-Friendly Computation
- Data laid out contiguously in memory for sequential access
- Tight loops over binary data exploit CPU prefetching and L1/L2 cache
- Sort operations use prefix keys in the pointer array for cache-efficient comparison

### Whole-Stage Code Generation
- Fuses multiple operators (filter, project, aggregate) into a single Java method
- Eliminates virtual method dispatch between operators
- Produces code similar to hand-written loops over raw data
- Compilation via Janino (a lightweight Java compiler)
- Falls back to interpreted execution for very complex plans or unsupported operators

## Adaptive Query Execution (AQE)

AQE re-optimizes the query plan at runtime using actual data statistics collected during shuffle stages. Enabled by default since Spark 3.2.

### Coalescing Post-Shuffle Partitions

After a shuffle, Spark knows the actual size of each partition. AQE combines small partitions to reduce task overhead:

```
Before AQE coalescing (200 partitions, most tiny):
  [1KB] [2KB] [500B] [1KB] [3KB] [200MB] [1KB] [2KB] ...

After AQE coalescing (10 partitions, balanced):
  [200MB] [180MB] [220MB] [190MB] [210MB] [200MB] ...
```

Key configs:
- `spark.sql.adaptive.coalescePartitions.enabled` (default true)
- `spark.sql.adaptive.advisoryPartitionSizeInBytes` (default 64MB, target size)
- `spark.sql.adaptive.coalescePartitions.minPartitionSize` (default 1MB)

### Dynamic Join Strategy Switching

If actual shuffle data is smaller than the broadcast threshold, AQE converts sort-merge join to broadcast hash join at runtime -- even if compile-time estimates suggested the table was too large.

### Skew Join Optimization

AQE detects partitions that are significantly larger than the median and splits them, replicating the non-skewed side:

```
Before:
  Partition A: 10MB (normal)
  Partition B: 5GB  (skewed -- 1 task takes 100x longer)

After AQE:
  Partition B-1: 500MB (split, non-skewed side replicated)
  Partition B-2: 500MB
  ...
  Partition B-10: 500MB
```

Key configs:
- `spark.sql.adaptive.skewJoin.enabled` (default true)
- `spark.sql.adaptive.skewJoin.skewedPartitionFactor` (default 5 -- partition is skewed if > 5x median)
- `spark.sql.adaptive.skewJoin.skewedPartitionThresholdInBytes` (default 256MB)

### Dynamic Partition Pruning (DPP)

Filters partitions at runtime based on join conditions. Most effective for star-schema queries where a filtered dimension table drives partition pruning on a fact table.

## Memory Model

### Unified Memory Manager

```
Total Executor Memory (spark.executor.memory)
├── Reserved Memory: 300 MB (hardcoded)
├── Unified Memory: 60% of (total - 300MB)  [spark.memory.fraction]
│   ├── Storage Memory: 50% of unified  [spark.memory.storageFraction]
│   │   └── Cached DataFrames, broadcast variables
│   └── Execution Memory: 50% of unified
│       └── Shuffles, joins, sorts, aggregations
└── User Memory: remaining 40% of (total - 300MB)
    └── User data structures, UDF variables, internal metadata
```

**Borrowing rules:**
- Storage and Execution borrow from each other when the other is idle
- Execution can evict cached data from Storage if it needs more memory
- Storage cannot evict Execution memory -- it can only reclaim space Execution has released
- Data cached below the `storageFraction` threshold is protected from eviction

**Off-heap memory** (`spark.memory.offHeap.enabled=true`):
- Allocated outside the JVM heap, managed by the OS
- No garbage collection overhead
- Contains only Storage and Execution pools (no User Memory)
- Size set via `spark.memory.offHeap.size`

**Memory overhead** (`spark.executor.memoryOverhead`):
- Default: max(384MB, 10% of executor memory)
- Covers: Python processes (PySpark), off-heap buffers, network I/O, container overhead
- Increase for PySpark workloads (Python processes consume additional memory outside the JVM)

## Deployment Modes

### YARN
- Mature, battle-tested at enterprise scale in Hadoop clusters
- Two sub-modes: `client` (driver on submitting machine) and `cluster` (driver inside the cluster)
- Slower executor provisioning (~90+ seconds for large jobs)
- Widely used in on-premises deployments

### Kubernetes
- Containerized pods with dependency isolation
- GA since Spark 3.1
- Faster scaling (under 30 seconds), cloud-native, multi-tenant
- Supports node selectors, tolerations, pod templates
- Increasingly the standard for cloud Spark deployments
- Dynamic allocation via shuffle tracking

### Standalone
- Spark's built-in cluster manager
- Simplest setup, no external dependencies
- Best for Spark-only clusters or development

### Local Mode
- Single JVM on the local machine: `--master local[N]`
- Used for development, testing, debugging
- `local[*]` uses all available cores

### Mesos
- **Removed in Spark 4.0** -- migrate to Kubernetes or YARN

## Data Source API v2

Pluggable interface for external data sources supporting:
- Predicate pushdown and column pruning at the source level
- Partition pruning for efficient reads
- Micro-batch and continuous streaming reads
- Catalog plugin API for multi-catalog access (e.g., `catalog.schema.table`)
- Storage Partition Joins -- avoids shuffles when data is already co-partitioned
- Python Data Source API (Spark 4.0+) for Python-only custom connectors
