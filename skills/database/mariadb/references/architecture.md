# MariaDB Architecture Reference

## Storage Engine Architecture

MariaDB uses a pluggable storage engine architecture. The server layer handles parsing, optimization, authentication, and caching, while storage engines handle data storage and retrieval.

### Server Layer

```
Client Connection
    |
    v
Connection Handler (thread pool or one-thread-per-connection)
    |
    v
Parser --> Query Cache (deprecated/removed in 10.1.7+)
    |
    v
Optimizer (cost-based in 11.4+, rule-based elements in older)
    |
    v
Executor
    |
    v
Storage Engine API (handler interface)
    |
    v
InnoDB / Aria / ColumnStore / Spider / S3 / CONNECT
```

### InnoDB Architecture

InnoDB is the primary transactional engine:

**In-Memory Structures:**
- **Buffer Pool**: Caches data and index pages in memory. Sized with `innodb_buffer_pool_size` (target ~80% RAM for dedicated servers). Divided into instances (`innodb_buffer_pool_instances`) to reduce contention.
- **Change Buffer**: Caches changes to secondary index pages when those pages are not in the buffer pool. Merged later during reads or background operations. Removed in MariaDB 11.4+.
- **Adaptive Hash Index**: Automatically builds hash indexes on hot B-tree pages for faster equality lookups. Can be disabled (`innodb_adaptive_hash_index=OFF`) if lock contention is observed.
- **Log Buffer**: Buffers redo log writes before flushing to disk (`innodb_log_buffer_size`).

**On-Disk Structures:**
- **System Tablespace** (`ibdata1`): Contains the data dictionary, doublewrite buffer, change buffer, and undo logs (unless moved to separate files).
- **File-Per-Table Tablespaces** (default): Each table stored in its own `.ibd` file.
- **Redo Log** (`ib_logfile0`/`ib_logfile1` or unified `ib_redo`): Write-ahead log for crash recovery.
- **Undo Tablespaces**: Store undo logs for MVCC. Configurable via `innodb_undo_tablespaces`.
- **Doublewrite Buffer**: Pages written to a doublewrite area before their final location to prevent partial page writes.

### Aria Architecture

Aria is MariaDB's crash-safe improvement over MyISAM:

- Uses a write-ahead log for crash recovery (unlike MyISAM)
- Table-level locking (no row-level concurrency)
- Two modes: transactional (default for system tables) and non-transactional
- Used automatically for on-disk internal temporary tables
- Data files: `.MAD` (data), `.MAI` (index), aria_log.* (WAL)
- Page cache sized with `aria_pagecache_buffer_size`

### ColumnStore Architecture

ColumnStore is a columnar engine for OLAP:

- Data stored in column-oriented extents (8 million rows per extent)
- Extent map provides min/max elimination (skip irrelevant extents)
- Uses a Performance Module (PM) for storage/processing and a User Module (UM) for query coordination
- Supports cross-engine joins with InnoDB tables
- No traditional indexes; relies on extent elimination and partition scanning
- Best for: aggregations, full-column scans, analytics on wide tables

### Spider Architecture (Sharding)

Spider enables horizontal partitioning across multiple MariaDB servers:

- Creates a table that transparently maps partitions to remote tables
- Uses the MySQL/MariaDB client protocol to connect to backend nodes
- Supports parallel query execution across shards
- XA transactions for cross-shard consistency
- Partition pruning routes queries to relevant shards only

### S3 Engine (Archival)

S3 stores read-only table data in S3-compatible object storage:

- Tables are converted from InnoDB/Aria to S3 via `ALTER TABLE ... ENGINE=S3`
- Data becomes read-only after conversion
- Supports `SELECT` and `DROP` only (no INSERT/UPDATE/DELETE)
- Ideal for archival: move old partitions to S3 for cost savings
- Configurable endpoint for MinIO, Ceph, or AWS S3

### CONNECT Engine (External Data)

CONNECT accesses external data sources without importing:

- Supported formats: CSV, JSON, XML, fixed-width, INI, ODBC, JDBC, MongoDB, REST APIs
- Creates virtual tables mapped to external sources
- Useful for ETL and data integration tasks
- Data can be read and written (depending on source type)

## Thread Pool Implementation

MariaDB's built-in thread pool reduces overhead from high connection counts:

```
Incoming Connections
    |
    v
Thread Pool (pool-of-threads)
    |
    +-- Thread Group 0 [listener + workers]
    +-- Thread Group 1 [listener + workers]
    +-- Thread Group 2 [listener + workers]
    +-- ...
    +-- Thread Group N [listener + workers]
```

**Mechanics:**
- Connections are assigned to thread groups via `connection_id % thread_pool_size`
- Each group has one listener thread polling for I/O events
- Worker threads execute queries; idle workers return to the pool
- If a query runs longer than `thread_pool_stall_limit` (default 500ms), the group creates an additional worker thread to prevent head-of-line blocking
- Total threads capped at `thread_pool_max_threads`

## Galera Cluster Internals

### WSREP API

The Write Set Replication (WSREP) API is the interface between MariaDB and the Galera replication library:

```
MariaDB Server
    |
    v
WSREP API (wsrep_provider = libgalera_smm.so)
    |
    v
Galera Library
    |
    +-- Certification Module (conflict detection)
    +-- Replication Module (writeset handling)
    +-- Group Communication (GComm)
         |
         +-- EVS (Extended Virtual Synchrony)
         +-- TCP/UDP transport
```

### Certification-Based Replication

1. Transaction executes locally using optimistic concurrency
2. At COMMIT, a writeset is created containing: primary keys of modified rows, column values, and database/table identifiers
3. The writeset is broadcast to all nodes with a global sequence number (seqno)
4. Each node independently runs certification: checks if any row modified by this writeset was also modified by a concurrent committed writeset with a higher seqno
5. If no conflict: all nodes apply; if conflict: originating node rolls back

### GCache

The Galera Cache (GCache) stores recent writesets for Incremental State Transfer:

- Ring buffer implementation in a memory-mapped file (`gcache.size`, default 128M)
- Retains writesets until overwritten or purged
- If a rejoining node's last committed seqno is within the GCache, IST is used (fast)
- If outside GCache range, SST is required (full snapshot, slow)
- Size GCache to hold at least a few hours of writesets

### Flow Control

Flow control prevents slow nodes from falling too far behind:

- When a node's receive queue exceeds `gcs.fc_limit` (default 16), it sends a flow control STOP message
- All nodes pause replication until the slow node catches up
- Monitored via `wsrep_flow_control_paused` (fraction of time cluster was paused; should be < 0.01)
- `wsrep_local_recv_queue_avg` shows the average receive queue length

## MaxScale Architecture

### Components

```
Client --> MaxScale --> Backend MariaDB Servers
              |
              +-- Listeners (port/socket binding)
              +-- Routers (query routing logic)
              +-- Filters (query transformation)
              +-- Monitors (server health checks)
              +-- Authenticators (client auth)
```

### Routers

| Router | Purpose |
|---|---|
| **ReadWriteSplit** | Sends writes to master, reads to slaves; transaction-aware |
| **ReadConnRoute** | Balances connections (not queries) across servers |
| **SchemaRouter** | Routes based on database/schema name |
| **BinlogRouter** | Acts as a binlog relay for replication fan-out |

### Monitors

| Monitor | Purpose |
|---|---|
| **MariaDB Monitor** | Detects master/slave topology; handles automatic failover/switchover |
| **Galera Monitor** | Monitors Galera cluster state; tracks donor/synced/desynced status |
| **Cooperative Monitoring** | Multiple MaxScale instances coordinate to avoid split-brain failover |

### Filters

| Filter | Purpose |
|---|---|
| **Query Log All (QLA)** | Logs all queries passing through MaxScale |
| **Database Firewall** | Blocks queries matching defined rules |
| **Masking** | Masks sensitive column data in query results |
| **Tee** | Duplicates queries to a secondary server (shadow traffic) |
| **Cache** | Caches query results to reduce backend load |
