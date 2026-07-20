# ScyllaDB Operations

## ScyllaDB Monitoring Stack

The monitoring stack is container-based, using Prometheus + Grafana + Loki:

**Components:**
- **Prometheus** -- Scrapes metrics from ScyllaDB nodes (port 9180 by default)
- **Grafana** -- Pre-built dashboards for cluster, node, and table-level metrics
- **Loki** -- Log aggregation and alerting based on log patterns
- **Alertmanager** -- Alert routing and notification

**Key Grafana dashboards:**
- **Overview** -- Cluster-wide throughput, latency, errors
- **Per-Server** -- CPU, memory, disk, network per node
- **Per-Table** -- Read/write latency, operations, SSTable count per table
- **Compaction** -- Compaction throughput, pending tasks, backlog
- **Repair** -- Repair progress and errors
- **CQL** -- CQL statement latency, errors, timeouts
- **Alternator** -- DynamoDB API metrics (if enabled)
- **Manager** -- ScyllaDB Manager task metrics
- **Advisor** -- Automated recommendations based on metrics

**Setup:**
```bash
# Clone monitoring stack
git clone https://github.com/scylladb/scylla-monitoring.git
cd scylla-monitoring

# Configure targets
# Edit prometheus/scylla_servers.yml:
# - targets:
#   - 10.0.1.1:9180
#   - 10.0.1.2:9180
#   - 10.0.1.3:9180

# Start the stack
./start-all.sh -d /path/to/data

# Access Grafana at http://<monitoring-server>:3000
```

## Cassandra-to-Scylla Migration

**Migration paths:**
1. **SSTableLoader** -- Export SSTables from Cassandra, load into ScyllaDB
2. **Spark Migrator** -- Use ScyllaDB Spark Migrator for large-scale migration
3. **Dual-write + backfill** -- Write to both during migration, backfill historical data
4. **ScyllaDB Manager restore** -- Restore from Cassandra-compatible backup format

**Pre-migration checklist:**
- Verify CQL compatibility (ScyllaDB supports Cassandra 3.x CQL protocol)
- Check for unsupported features: Materialized Views (limited support), SASI indexes (not supported, use SI or SAI equivalent), custom Cassandra plugins
- Review compaction strategy -- switch STCS to ICS
- Review JVM tuning -- none of it applies to ScyllaDB
- Update client drivers -- use ScyllaDB-aware drivers for shard-aware routing
- Plan for schema migration -- schema is CQL-compatible but test thoroughly

**SSTableLoader migration:**
```bash
# On Cassandra nodes, take a snapshot
nodetool snapshot -t migration_snap my_keyspace

# Copy SSTables to ScyllaDB-accessible location
# Then load using sstableloader
sstableloader -d <scylla-node-ip> /path/to/my_keyspace/my_table-<uuid>/snapshots/migration_snap/
```

**Driver configuration for shard-aware routing:**
ScyllaDB drivers extend Cassandra drivers with shard-awareness -- the driver routes requests directly to the correct shard on the correct node, eliminating inter-shard forwarding:
- Java: `scylla-driver` (extends DataStax driver)
- Python: `scylla-driver` (extends `cassandra-driver`)
- Go: `gocqlx` with shard-awareness
- Rust: `scylla-rust-driver`
- C++: `scylla-cpp-driver`
