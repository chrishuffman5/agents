---
name: database-cassandra-4x
description: "Apache Cassandra 4.x version-specific expert covering 4.0 and 4.1. Deep knowledge of virtual tables, audit logging, full query logging, incremental repair improvements, Java 11 support, transient replication (experimental), ZGC support, and operational enhancements. WHEN: \"Cassandra 4\", \"Cassandra 4.0\", \"Cassandra 4.1\", \"virtual tables Cassandra\", \"audit logging Cassandra\", \"full query logging\", \"fql Cassandra\", \"Cassandra incremental repair\", \"Cassandra Java 11\", \"transient replication\", \"Cassandra ZGC\"."
license: MIT
metadata:
  version: "1.0.0"
  author: christopher huffman
---

# Apache Cassandra 4.x Expert

You are a specialist in Apache Cassandra 4.0 (released July 2021) and 4.1 (released December 2022). You have deep knowledge of the features introduced in these versions, particularly virtual tables, audit logging, full query logging, incremental repair improvements, and the Java 11 migration.

**Support status:** Cassandra 4.0 is in maintenance. Cassandra 4.1 is actively supported. Both receive security and critical bug fixes.

## Key Features in Cassandra 4.0

### Virtual Tables

Virtual tables expose Cassandra internals as CQL-queryable tables without storing data on disk. They live in the `system_views` keyspace:

```sql
-- List all virtual tables
SELECT * FROM system_schema.tables WHERE keyspace_name = 'system_views';

-- Thread pool statistics (replaces nodetool tpstats)
SELECT name, active_tasks, pending_tasks, completed_tasks, blocked_tasks, all_time_blocked
FROM system_views.thread_pools;

-- Active settings (replaces nodetool getconfig)
SELECT name, value FROM system_views.settings;

-- SSTable tasks (compaction, cleanup, etc.)
SELECT * FROM system_views.sstable_tasks;

-- Active client connections
SELECT * FROM system_views.clients;

-- Internode messaging
SELECT * FROM system_views.internode_inbound;
SELECT * FROM system_views.internode_outbound;

-- Pending hints
SELECT * FROM system_views.pending_hints;

-- Disk usage per table
SELECT * FROM system_views.disk_usage;

-- Streaming status
SELECT * FROM system_views.streaming;

-- Top partitions (requires nodetool toppartitions to be active)
SELECT * FROM system_views.top_partitions;

-- System properties
SELECT * FROM system_views.system_properties;

-- Caches
SELECT * FROM system_views.caches;

-- GC statistics (replaces nodetool gcstats)
SELECT * FROM system_views.jmx WHERE object_name LIKE '%GarbageCollector%';
```

**Key advantage:** Virtual tables can be queried remotely via CQL, unlike nodetool which requires SSH access to each node. This enables centralized monitoring via CQL-based dashboards.

**Limitations:**
- Virtual tables are read-only
- Data is generated on-demand (not stored)
- Only reflects the local node's state
- Cannot be used in JOIN operations with regular tables

### Audit Logging

Native audit logging tracks CQL operations for compliance and security:

```yaml
# cassandra.yaml
audit_logging_options:
    enabled: true
    logger:
      - class_name: FileAuditLogger      # Writes to audit/audit.log
    # Alternatively:
    # - class_name: BinAuditLogger        # Binary format (more efficient)
    audit_logs_dir: /var/log/cassandra/audit
    included_keyspaces: my_keyspace       # comma-separated; empty = all
    excluded_keyspaces: system,system_schema,system_auth
    included_categories: AUTH,DDL,DML,DCL # categories to log
    excluded_categories:                   # categories to exclude
    included_users:                        # specific users to audit
    excluded_users: cassandra              # exclude system user
    roll_cycle: HOURLY                     # MINUTELY, HOURLY, DAILY
    block: true                            # block if audit log cannot write
    max_queue_weight: 268435456            # 256MB max queue before blocking
    max_log_size: 17179869184             # 16GB max total log size
    max_archive_retries: 10
```

**Audit categories:**
| Category | Operations Logged |
|---|---|
| `AUTH` | Login attempts (success and failure) |
| `DDL` | CREATE, ALTER, DROP statements |
| `DML` | SELECT, INSERT, UPDATE, DELETE, BATCH |
| `DCL` | GRANT, REVOKE, CREATE ROLE |
| `PREPARE` | PREPARE statements |
| `QUERY` | All CQL queries |

**Enable/disable at runtime:**
```bash
nodetool enableauditlog
nodetool enableauditlog --included-keyspaces my_keyspace --included-categories DML,DDL
nodetool disableauditlog
```

**Read binary audit logs:**
```bash
# Convert binary audit log to readable format
auditlogviewer /var/log/cassandra/audit/
```

### Full Query Logging (FQL)

Records all CQL queries with full fidelity for replay and analysis:

```bash
# Enable FQL
nodetool enablefullquerylog --path /var/log/cassandra/fql

# Enable with options
nodetool enablefullquerylog \
    --path /var/log/cassandra/fql \
    --roll-cycle HOURLY \
    --max-log-size 1073741824 \
    --blocking true \
    --max-archive-retries 10

# Disable FQL
nodetool disablefullquerylog

# Read FQL logs
fqltool dump /var/log/cassandra/fql/

# Replay FQL against another cluster (for testing)
fqltool replay \
    --keyspace my_keyspace \
    --target node1:9042 \
    --results /tmp/fql_results \
    /var/log/cassandra/fql/

# Compare results between clusters
fqltool compare /tmp/fql_results_original /tmp/fql_results_replay
```

**Use cases:**
- Capture production query patterns for replay in staging
- Audit all queries for compliance
- Debug intermittent issues by replaying exact queries
- Performance testing with production-realistic workloads

### Incremental Repair Improvements

Cassandra 4.0 fixed critical bugs in incremental repair that existed in 3.x:

**Key improvements:**
- Repaired and unrepaired SSTables are stored in **separate compaction pools**
- This prevents repaired data from being mixed with unrepaired data during compaction
- Incremental repair is now the **default** repair mode (no `--incremental` flag needed)
- `--full` flag explicitly requests full (non-incremental) repair

```bash
# Incremental repair (default in 4.0)
nodetool repair -pr my_keyspace

# Explicit full repair
nodetool repair --full -pr my_keyspace

# Paxos-only repair (new in 4.0)
nodetool repair --paxos-only my_keyspace

# Preview repair (check for inconsistencies without streaming)
nodetool repair --preview my_keyspace

# Validate repaired data (check that repaired SSTables are consistent)
nodetool repair --validate my_keyspace
```

**Repaired data tracking:**
```sql
-- Check repair percentage via virtual tables
SELECT * FROM system_views.repair_sessions;

-- Check via nodetool
nodetool info | grep "Percent Repaired"
```

### Java 11 Support

Cassandra 4.0 requires Java 8 or Java 11 (Java 11 recommended):

**Migration from Java 8 to Java 11:**
1. Install Java 11 (OpenJDK 11 recommended)
2. Update `JAVA_HOME` in `cassandra-env.sh`
3. Use `jvm11-server.options` instead of `jvm-server.options`
4. Remove Java 8-specific flags (e.g., `-XX:+UseConcMarkSweepGC`)
5. Add Java 11 module access flags (handled automatically in 4.0's `jvm11-server.options`)

**Key JVM 11 options (jvm11-server.options):**
```bash
-XX:+UseG1GC
-XX:+ParallelRefProcEnabled
-XX:G1RSetUpdatingPauseTimePercent=5
-XX:MaxGCPauseMillis=300
-XX:InitiatingHeapOccupancyPercent=70

# Module access required for Cassandra internals
--add-exports java.base/jdk.internal.misc=ALL-UNNAMED
--add-exports java.base/jdk.internal.ref=ALL-UNNAMED
--add-opens java.base/java.lang.module=ALL-UNNAMED
--add-opens java.base/jdk.internal.loader=ALL-UNNAMED
```

### Networking Improvements

Cassandra 4.0 overhauled the inter-node messaging:

- **Single connection per node** -- Replaced the previous multi-connection model with a single multiplexed connection per peer
- **Reduced connection count** -- From `O(n^2 * connections_per_host)` to `O(n)` total connections
- **Message coalescing** -- Small messages are batched for efficiency
- **Improved backpressure** -- Flow control prevents overwhelming slow nodes
- **Configurable ports per peer** -- `native_transport_port_ssl` for mixed encrypted/unencrypted

### Guardrails Framework (4.0+)

Runtime-configurable limits to prevent problematic operations:

```yaml
# cassandra.yaml (4.0+)
guardrails:
    partition_keys_in_select_warn_threshold: 100
    partition_keys_in_select_failure_threshold: -1     # disabled
    in_select_cartesian_product_warn_threshold: 25
    in_select_cartesian_product_failure_threshold: -1
    tables_warn_threshold: 150
    tables_failure_threshold: -1
    columns_per_table_warn_threshold: 20
    columns_per_table_failure_threshold: -1
    secondary_indexes_per_table_warn_threshold: 5
    secondary_indexes_per_table_failure_threshold: -1
    materialized_views_per_table_warn_threshold: 0
    materialized_views_per_table_failure_threshold: 0   # MV creation blocked by default
    page_size_warn_threshold: 5000
    page_size_failure_threshold: -1
    partition_size_warn_threshold: 100MB
    partition_size_failure_threshold: -1
    collection_size_warn_threshold: -1                   # collection (list, set, map) sizes
    collection_size_failure_threshold: -1
```

### Other 4.0 Features

- **Chunk cache** -- Replaces the old buffer pool and file cache with a unified off-heap cache (`file_cache_size_in_mb`)
- **Improved streaming** -- Zero-copy streaming for faster bootstrap and repair
- **Better diagnostics** -- `nodetool sjk` integration for JVM profiling
- **Configuration hot-reload** -- Some settings reloadable without restart
- **Internode encryption** -- Optional per-port encryption (`native_transport_port_ssl`)
- **nodetool import** -- Import externally loaded SSTables into a running table
- **nodetool reloadssl** -- Reload SSL certificates without restart
- **Improved nodetool repair** -- `--preview`, `--validate`, `--paxos-only` options
- **Startup/shutdown improvements** -- Faster startup with commit log replay optimizations

## Key Features in Cassandra 4.1

### Pluggable Memtable Implementations

4.1 introduces the ability to plug in custom memtable implementations:

```yaml
# cassandra.yaml
memtable:
    configurations:
        default:
            class_name: SkipListMemtable   # default
        trie:
            class_name: TrieMemtable        # experimental trie-based memtable
```

```cql
-- Use a specific memtable implementation for a table
CREATE TABLE my_table (...) WITH memtable = 'trie';
ALTER TABLE my_table WITH memtable = 'default';
```

**TrieMemtable (experimental in 4.1):**
- Uses trie data structures instead of skip lists
- Better memory efficiency for large memtables
- Foundation for the trie-based storage in Cassandra 5.0

### ZGC Support (Experimental)

Java 11's ZGC garbage collector is experimentally supported:

```bash
# jvm11-server.options
-XX:+UseZGC
-XX:ConcGCThreads=<cores/4>
```

**Benefits:**
- Ultra-low GC pause times (< 1ms target)
- Pause times do not increase with heap size
- Good for latency-sensitive workloads

**Caveats:**
- Higher memory overhead than G1GC
- Higher CPU usage for GC threads
- Not extensively tested in all Cassandra workloads in 4.1
- Recommended to test thoroughly before production use

### Transient Replication (Experimental)

Transient replication allows some replicas to store only unrepaired data:

```cql
-- Create keyspace with transient replication
CREATE KEYSPACE tr_keyspace WITH replication = {
    'class': 'NetworkTopologyStrategy',
    'dc1': '3/1'   -- 3 replicas, 1 of which is transient
};
```

**How it works:**
- In `3/1` configuration: 2 full replicas + 1 transient replica
- Transient replicas only store unrepaired data
- After repair, transient replicas discard their copy
- Reduces storage requirements while maintaining write availability
- Reads at `QUORUM` still work (only full replicas counted for quorum)

**Limitations (experimental):**
- Not compatible with materialized views
- Not compatible with CDC (Change Data Capture)
- Cannot use SERIAL/LOCAL_SERIAL consistency
- Limited testing in production environments
- Repair behavior more complex

### Paxos Improvements (4.1)

- **Faster Paxos** -- Reduced round trips for uncontested LWT operations
- **Paxos repair** -- More efficient repair of Paxos state
- **Paxos auto-repair** -- Background repair of Paxos state during normal operations

### Other 4.1 Features

- **Top partition tracking** -- `nodetool toppartitions` for real-time hot partition detection
- **Pluggable crypto providers** -- Custom SSL/TLS providers
- **Improved guardrails** -- Additional configurable limits
- **Better compaction** -- Improved compaction controller for better throughput management
- **Native transport rate limiting** -- Per-client CQL rate limiting
- **Improved snitch** -- Better handling of cloud topology changes

## Migration Guidance

### Upgrading from 3.11 to 4.0

**Pre-upgrade checklist:**
1. Run `nodetool upgradesstables` on all nodes (converts 3.x SSTables to 4.0 format)
2. Resolve all schema disagreements (`nodetool describecluster`)
3. Complete any in-progress repairs
4. Take snapshots on all nodes: `nodetool snapshot -t pre_upgrade`
5. Verify application compatibility with 4.0 CQL changes

**Breaking changes in 4.0:**
- Java 11 recommended (Java 8 still supported but deprecated)
- `read_repair_chance` and `dclocal_read_repair_chance` table properties removed (read repair is always on, background-only)
- Materialized view creation blocked by default (guardrails)
- `ALTER TABLE ... DROP` of columns with 3.x data may lose data (run `upgradesstables` first)
- Default compaction throughput changed
- `batch_size_warn_threshold_in_kb` default changed from 5 to 64
- `enable_user_defined_functions` and `enable_scripted_user_defined_functions` removed (UDFs always enabled if `enable_user_defined_functions_threads` > 0)

**Rolling upgrade procedure:**
1. Upgrade one node at a time
2. On each node:
   a. `nodetool drain` (flush and stop accepting connections)
   b. Stop Cassandra
   c. Install Cassandra 4.0
   d. Update `cassandra.yaml` (merge new settings)
   e. Switch to `jvm11-server.options` if using Java 11
   f. Start Cassandra
   g. Verify node is up: `nodetool status`
   h. Run `nodetool upgradesstables` (optional but recommended)
3. After all nodes upgraded, run `nodetool repair` on each node

### Upgrading from 4.0 to 4.1

A straightforward minor-version upgrade:
1. Rolling upgrade, one node at a time
2. No SSTable format changes (no `upgradesstables` needed)
3. Review new cassandra.yaml settings (memtable pluggability, new guardrails)
4. No CQL breaking changes

### Upgrading from 4.1 to 5.0

See `../5.0/SKILL.md` for detailed 4.1-to-5.0 migration guidance.

## Version-Specific Commands

### 4.0+ Only Commands

```bash
# Virtual table queries
cqlsh -e "SELECT * FROM system_views.thread_pools;"
cqlsh -e "SELECT * FROM system_views.settings;"
cqlsh -e "SELECT * FROM system_views.clients;"
cqlsh -e "SELECT * FROM system_views.sstable_tasks;"

# Full query logging
nodetool enablefullquerylog --path /var/log/cassandra/fql
nodetool disablefullquerylog
fqltool dump /var/log/cassandra/fql/
fqltool replay --target node1:9042 /var/log/cassandra/fql/

# Audit logging
nodetool enableauditlog
nodetool disableauditlog
auditlogviewer /var/log/cassandra/audit/

# Repair enhancements
nodetool repair --preview my_keyspace
nodetool repair --validate my_keyspace
nodetool repair --paxos-only my_keyspace
nodetool repair_admin list
nodetool repair_admin cancel <session_id>

# Import SSTables at runtime
nodetool import my_keyspace my_table /path/to/sstables

# Reload SSL certificates
nodetool reloadssl

# JVM profiling
nodetool sjk gc
nodetool sjk ttop
nodetool sjk hh

# Streaming improvements
nodetool getstreams

# Guardrails inspection
cqlsh -e "SELECT * FROM system_views.settings WHERE name LIKE 'guardrail%';"

# Concurrent compactors (runtime)
nodetool getconcurrentcompactors
nodetool setconcurrentcompactors 4

# Concurrent view builders (runtime)
nodetool getconcurrentviewbuilders
nodetool setconcurrentviewbuilders 2
```

### 4.1+ Only Commands

```bash
# Top partitions (enhanced in 4.1)
nodetool toppartitions my_keyspace my_table 10000 10

# Pluggable memtable configuration (via cassandra.yaml and CQL ALTER TABLE)
```

## Version Boundaries

| Feature | 4.0 | 4.1 | Notes |
|---|---|---|---|
| Virtual tables | Yes | Yes | Extended in 4.1 |
| Audit logging | Yes | Yes | |
| Full query logging | Yes | Yes | |
| Incremental repair v2 | Yes | Yes | Fixed in 4.0, default mode |
| Java 11 support | Yes (recommended) | Yes (required) | Java 8 deprecated in 4.0 |
| Guardrails | Basic | Extended | More configurable in 4.1 |
| Zero-copy streaming | Yes | Yes | |
| Chunk cache | Yes | Yes | Replaces buffer pool |
| Transient replication | Experimental | Experimental | Not production-ready |
| ZGC support | No | Experimental | Java 11+ |
| Pluggable memtable | No | Yes | Experimental |
| Paxos auto-repair | No | Yes | |
| nodetool import | Yes | Yes | |
| nodetool reloadssl | Yes | Yes | |
| nodetool toppartitions | Basic | Enhanced | More granular in 4.1 |
