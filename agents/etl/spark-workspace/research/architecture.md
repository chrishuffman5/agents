# Apache Spark Architecture

## Core Architecture: Driver-Executor Model

Apache Spark uses a **Driver-Executor** distributed architecture where one central coordinator (the Driver) manages many distributed workers (Executors).

### Driver
- A JVM process that orchestrates the execution of a Spark application
- Translates user code (Scala, Python, Java, R) into a Directed Acyclic Graph (DAG) of tasks
- Hosts the SparkContext/SparkSession, which is the entry point for all Spark functionality
- Responsible for: parsing user code, creating logical/physical plans, scheduling tasks, collecting results
- Runs either on the client machine (client mode) or inside the cluster (cluster mode)

### Executors
- JVM processes running on worker nodes in a distributed fashion
- Execute the tasks assigned by the Driver
- Store data in memory or disk for caching (BlockManager)
- Each executor has a fixed number of cores (slots) and a fixed amount of memory
- Report status back to the Driver via heartbeats
- Lifecycle: created at application start, destroyed at application end (or with dynamic allocation)

### Cluster Manager
- External service that allocates resources (CPU, memory) across the cluster
- Acts as intermediary between the Driver and worker nodes
- Manages the lifecycle of Executors
- Spark is **agnostic** to the underlying cluster manager

### SparkSession vs SparkContext
- **SparkSession**: Unified entry point (introduced in Spark 2.0), provides access to DataFrames, SQL, config management, and catalog. Think of it as the "front desk"
- **SparkContext**: The core engine underneath SparkSession that actually drives distributed computation. Think of it as the "operations center"
- In Spark 4.x, SparkSession is the primary API; SparkContext is accessed via `spark.sparkContext`

---

## Execution Model

### DAG (Directed Acyclic Graph)
- When an action is triggered (e.g., `collect()`, `save()`), Spark constructs a DAG of stages
- The DAG represents the lineage of transformations from input to output
- Two types of dependencies:
  - **Narrow dependencies**: Each partition of the parent RDD is used by at most one partition of the child (e.g., `map`, `filter`). Allows pipelined execution on a single node
  - **Wide dependencies**: Multiple child partitions depend on the same parent partition, requiring a **shuffle** (e.g., `groupBy`, `join`, `repartition`)

### Stages
- The DAG scheduler divides the DAG into **stages** at shuffle boundaries
- Each stage contains a set of tasks that can be pipelined together without shuffling
- A new stage begins after every wide dependency (shuffle)

### Tasks
- The smallest unit of execution in Spark
- One task per partition per stage
- Tasks within a stage can run in parallel across executor slots

### Shuffle
- The process of redistributing data across partitions (and network)
- Triggered by wide transformations: `groupByKey`, `reduceByKey`, `join`, `repartition`
- Shuffle involves writing intermediate data to disk (Tungsten binary format), transferring across the network, and reading on the other side
- Most expensive operation in Spark -- minimize shuffles for performance

### Catalyst Optimizer
The query optimization framework for Spark SQL, DataFrames, and Datasets. Operates in four phases:

1. **Analysis**: Resolves column references, table names, and types using the catalog
2. **Logical Optimization**: Applies rule-based transformations:
   - Predicate pushdown (push filters closer to data source)
   - Constant folding (evaluate constant expressions at compile time)
   - Projection pruning (remove unnecessary columns)
   - Boolean simplification
3. **Physical Planning**: Generates multiple physical execution plans, selects optimal one using cost model
4. **Code Generation**: Converts the selected plan into optimized JVM bytecode (whole-stage codegen)

### Tungsten Execution Engine
Optimizes the physical execution layer:

- **Whole-Stage Code Generation**: Generates optimized bytecode at runtime, fusing multiple operators into a single function to avoid virtual method dispatch and interpretation overhead
- **Cache-Friendly Layout**: Optimizes memory layout for CPU cache utilization using binary format instead of Java objects
- **Off-Heap Memory Management**: Uses sun.misc.Unsafe for direct memory access, reducing GC overhead
- **Binary Processing**: Operates on binary data (UnsafeRow) directly without deserialization where possible

---

## Deployment Modes

### Standalone
- Spark's built-in cluster manager
- Simplest to set up; no external dependencies
- Best for Spark-only clusters or development/testing
- Limited scalability compared to YARN/K8s
- Does not share resources with non-Spark workloads

### YARN (Yet Another Resource Negotiator)
- Hadoop's cluster manager; enables Spark to coexist with Hive, HBase, MapReduce
- Mature, battle-tested at enterprise scale
- Two sub-modes: `--deploy-mode client` (driver on submitting machine) and `--deploy-mode cluster` (driver on cluster)
- Limitations: slower executor provisioning (~90+ seconds for large jobs), weaker job isolation, dependency management challenges
- Still widely used in on-premises Hadoop deployments

### Kubernetes
- Runs Spark applications as containerized pods
- GA since Spark 3.1 (March 2021)
- Benefits: container-based isolation, dependency packaging, rapid scaling (under 30 seconds), cloud-native, multi-tenant
- ~5% faster than YARN on TPC-DS 1TB benchmarks
- **Trend**: Organizations increasingly migrating from YARN to Kubernetes
- Supports node selectors, tolerations, pod templates for fine-grained scheduling
- Dynamic allocation supported via shuffle tracking or external shuffle service

### Mesos
- **Removed in Spark 4.0** -- no longer supported
- Was used for shared multi-framework clusters

### Local Mode
- Runs everything in a single JVM on the local machine
- Used for development, testing, and small-scale processing
- Syntax: `--master local[N]` where N is number of threads (`local[*]` for all cores)

---

## API Layers

### RDD (Resilient Distributed Dataset) API
- Lowest-level API; strongly typed (Scala/Java)
- Direct control over partitioning and transformations
- No Catalyst optimization -- transformations are opaque
- Use cases: custom partitioning, low-level control, complex algorithms
- Still available but rarely recommended for ETL workloads

### DataFrame API
- Higher-level API built on top of RDDs
- Schema-aware (columns with names and types)
- Benefits from Catalyst optimizer and Tungsten engine
- Available in Python, Scala, Java, R
- Primary API for ETL and data engineering in Spark 3.x/4.x

### Dataset API (Scala/Java only)
- Typed version of DataFrame with compile-time type safety
- `Dataset[Row]` is equivalent to DataFrame
- Combines benefits of RDD type safety with Catalyst optimization
- Not available in PySpark (PySpark DataFrames are equivalent to `Dataset[Row]`)

### Spark SQL
- SQL interface on top of DataFrames
- Supports ANSI SQL (default in Spark 4.0+)
- Catalog integration (Hive metastore, Unity Catalog, Glue Catalog)
- Can mix SQL with DataFrame API via `spark.sql("SELECT ...")`

---

## Spark Structured Streaming

### Processing Modes

**Micro-Batch (Default)**
- Processes data as a series of small batch jobs
- End-to-end latencies: ~100ms minimum
- **Exactly-once** fault-tolerance guarantees
- Mature, well-tested, production-ready

**Continuous Processing (Experimental)**
- Introduced in Spark 2.3, still experimental
- End-to-end latency as low as ~1ms
- **At-least-once** guarantees only
- Not recommended for production by Databricks

**Real-Time Mode (RTM) -- New in Spark 4.1**
- Continuous, sub-second latency processing
- P99 latencies in single-digit milliseconds for stateless tasks
- Data streams continuously through operators without blocking within longer-duration epochs
- Checkpointing overhead amortized across longer epochs
- Enabled with a single config change -- no API changes needed
- Recommended over Continuous Processing mode

### Streaming Concepts
- **Trigger**: Controls when micro-batches execute (processingTime, once, availableNow, continuous)
- **Watermark**: Handles late data by specifying how long to wait for late events
- **Output Modes**: append, complete, update
- **Checkpointing**: Required for fault tolerance; stores offsets and state to durable storage
- **State Store**: Manages stateful operations (aggregations, deduplication, sessionization)

---

## Storage Integration

### File Formats
- **Parquet**: Columnar format, default for Spark. Predicate pushdown, column pruning, efficient compression. Best general-purpose choice
- **ORC**: Columnar format, optimized for Hive workloads. Comparable to Parquet; historically preferred in Hive ecosystem
- **Avro**: Row-based format, good for write-heavy streaming workloads
- **JSON/CSV**: Human-readable but slow and space-inefficient. Avoid for production ETL

### Open Table Formats
- **Delta Lake**: ACID transactions, time travel, schema enforcement/evolution, MERGE INTO (upserts). Deep Databricks integration. Default COW, Liquid Clustering for optimization
- **Apache Iceberg**: Vendor-neutral open specification, broadest engine support (Spark, Trino, Flink, Dremio). Hidden partitioning, partition evolution, schema evolution
- **Apache Hudi**: Born at Uber for near-real-time CDC. Copy-on-Write (COW) and Merge-on-Read (MOR) table types. Strong streaming update support
- **Apache XTable**: Cross-format metadata translation between Iceberg, Delta, Hudi
- **Delta UniForm**: Enables Delta tables to be read as Iceberg or Hudi

---

## Memory Management

### Unified Memory Manager (Default since Spark 1.6)
A shared memory region for both storage (caching) and execution (shuffles, joins, sorts).

**On-Heap Memory Layout:**
```
Total Executor Memory (spark.executor.memory)
├── Reserved Memory: 300 MB (hardcoded, for Spark internals)
├── Unified Memory: 60% of (total - 300MB)  [spark.memory.fraction = 0.6]
│   ├── Storage Memory: 50% of unified  [spark.memory.storageFraction = 0.5]
│   │   └── Cached RDDs, broadcast variables
│   └── Execution Memory: 50% of unified
│       └── Shuffles, joins, sorts, aggregations
└── User Memory: remaining 40% of (total - 300MB)
    └── User data structures, UDF variables
```

**Key Rules:**
- Storage and Execution can borrow from each other when the other is idle
- **Execution has priority**: it can evict cached data from Storage
- Storage cannot evict Execution memory (only reclaim unused Execution space)
- Storage blocks below `storageFraction` threshold are protected from eviction

**Off-Heap Memory:**
- Enabled via `spark.memory.offHeap.enabled=true` and `spark.memory.offHeap.size`
- Simpler model: only Execution and Storage (no User Memory, no GC)
- Managed by the OS, not the JVM garbage collector
- Reduces GC pauses for large-scale workloads
- Divided into Storage and Execution pools, same borrowing rules apply

### Memory Overhead
- `spark.executor.memoryOverhead`: Additional memory beyond executor heap (default: max(384MB, 10% of executor memory))
- Used for: Python processes (PySpark), off-heap memory, network buffers, container overhead
- Critical for PySpark workloads where Python processes consume additional memory

---

## Adaptive Query Execution (AQE)

Enabled by default since Spark 3.2.0 (`spark.sql.adaptive.enabled=true`).

### Core Features:
1. **Coalescing Post-Shuffle Partitions**: Combines small partitions after shuffle to reduce task overhead. Configured via `spark.sql.adaptive.coalescePartitions.enabled`
2. **Dynamic Join Strategy Switching**: Converts sort-merge joins to broadcast hash joins at runtime when actual data size is smaller than threshold
3. **Skew Join Optimization**: Detects and splits skewed partitions, replicating the non-skewed side to balance work
4. **Dynamic Partition Pruning (DPP)**: Filters partitions at runtime based on query conditions

### Impact:
- Can reduce job runtimes by 20-40% on skewed workloads with zero code changes
- Most effective for queries with data skew or inaccurate statistics

---

## Data Source API v2

- Introduced progressively from Spark 2.3, significantly enriched in 3.0+
- Provides a pluggable interface for external data sources
- Supports: predicate pushdown, column pruning, partition pruning, micro-batch and continuous streaming
- Catalog plugin API: external catalogs (e.g., Iceberg, Delta, Hive) can be registered, enabling multi-part identifier access (e.g., `catalog.schema.table`)
- Storage Partition Joins: supported for compatible V2 DataSources, avoiding unnecessary shuffles when data is already co-partitioned
- Python Data Source API (Spark 4.0+): allows creating custom data sources entirely in Python
