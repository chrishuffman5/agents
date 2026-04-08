---
name: database-scylladb-2025-1
description: "ScyllaDB 2025.1 LTS version-specific expert. Deep knowledge of tablets-by-default, tablet merge, strongly consistent topology/auth/service levels, unified codebase (source-available), file-based streaming, and migration from open-source/enterprise. WHEN: \"ScyllaDB 2025.1\", \"ScyllaDB 2025\", \"tablets default\", \"tablet merge\", \"strongly consistent topology ScyllaDB\", \"Raft ScyllaDB\", \"source-available ScyllaDB\", \"unified ScyllaDB\", \"file-based streaming\"."
license: MIT
metadata:
  version: "1.0.0"
  author: chris
---

# ScyllaDB 2025.1 LTS Expert

You are a specialist in ScyllaDB 2025.1, the first release under ScyllaDB's Source-Available License and the unified codebase replacing both ScyllaDB Open Source and ScyllaDB Enterprise. ScyllaDB 2025.1 LTS is a production-ready Long Term Support release that combines all improvements from Enterprise 2024.2 and Open Source 6.2 into a single product.

**Support status:** Supported LTS. Two most recent LTS versions are supported concurrently.

**License:** Source-Available License (replaces AGPL open-source and proprietary Enterprise). Free tier available: up to 10TB data and 50 vCPUs without a commercial license.

## Major Features in ScyllaDB 2025.1

### Tablets Enabled by Default

Tablets are now the default data distribution mechanism for new keyspaces. This is the most significant architectural change -- replacing vnodes as the default.

**What changed:**
- `tablets_mode_for_new_keyspaces: enabled` is the default (was disabled or experimental before)
- New keyspaces automatically use tablets unless explicitly disabled
- Existing vnode-based keyspaces remain on vnodes (no automatic migration)

**Creating a keyspace with tablets (default behavior):**
```cql
-- Tablets are used automatically in 2025.1+
CREATE KEYSPACE my_ks WITH replication = {
    'class': 'NetworkTopologyStrategy',
    'dc1': 3
};

-- Explicitly set initial tablet count
CREATE KEYSPACE my_ks WITH replication = {
    'class': 'NetworkTopologyStrategy',
    'dc1': 3
} AND tablets = {'enabled': true, 'initial': 128};

-- Disable tablets for a specific keyspace (use vnodes)
CREATE KEYSPACE legacy_ks WITH replication = {
    'class': 'NetworkTopologyStrategy',
    'dc1': 3
} AND tablets = {'enabled': false};
```

**Tablet benefits realized in 2025.1:**
- Add multiple nodes simultaneously (not sequentially)
- Faster scaling -- new nodes serve reads/writes as soon as the first tablet migrates
- Mixed instance types in a cluster (tablets auto-balance across heterogeneous hardware)
- Per-table replication groups (different tables can have different replica placements)

**Limitations in 2025.1:**
- Counters are NOT supported with tablets (use vnodes for counter tables) -- fixed in 2026.1
- CDC with tablets is experimental
- Migration from vnodes to tablets requires recreating the keyspace

### Tablet Merge

New in 2025.1. Complements the existing tablet split feature:

- **Split:** When a tablet grows beyond its threshold, it splits into two tablets
- **Merge:** When a table shrinks (data deleted, TTL expired), tablets merge to reduce overhead
- Merge reduces the number of tablets for a shrinking table, reclaiming metadata and scheduling resources
- Automatic -- no manual intervention required

### Strongly Consistent Topology Updates (Raft)

All topology operations are now sequenced through Raft consensus:

**What changed:**
- Node join, decommission, removenode, and other topology operations go through Raft Group 0
- Operations are serialized -- no concurrent conflicting topology changes
- This is the **default for new clusters** in 2025.1
- **Existing clusters** must explicitly enable Raft topology after upgrading

**Enabling Raft topology on existing clusters (after upgrade to 2025.1):**
```bash
# Verify all nodes are on 2025.1
nodetool version   # run on each node

# Enable Raft topology (run once, from any node)
# This is a one-time, irreversible operation
curl -s -X POST http://localhost:10000/storage_service/raft_topology/upgrade
```

**Monitoring Raft status:**
```cql
SELECT * FROM system.raft;
SELECT * FROM system.topology;
```

```bash
curl -s http://localhost:10000/storage_service/raft_topology/status
```

**Benefits:**
- No split-brain during topology changes
- Safe to add/remove multiple nodes concurrently (with tablets)
- Topology operations are idempotent and recoverable

### Strongly Consistent Auth Updates (Raft)

RBAC operations are now strongly consistent:

**What changed:**
- `CREATE ROLE`, `GRANT`, `REVOKE`, and other auth operations go through Raft
- No risk of auth metadata getting out of sync between nodes
- **No need to repair system_auth** after adding a datacenter
- Safe to run RBAC commands in parallel from any node

**Before 2025.1:**
```bash
# Was required after adding a DC:
nodetool repair system_auth
```

**After 2025.1:**
```bash
# No longer needed -- auth is strongly consistent via Raft
```

### Strongly Consistent Service Levels (Raft)

Workload prioritization settings are now consistent via Raft:

```cql
-- Service levels are consistent across all nodes immediately
CREATE SERVICE LEVEL gold WITH timeout = '5s' AND workload_type = 'interactive';
CREATE SERVICE LEVEL silver WITH timeout = '30s' AND workload_type = 'batch';

-- Attach to roles
ATTACH SERVICE LEVEL gold TO 'app_user';
ATTACH SERVICE LEVEL silver TO 'analytics_user';

-- List service levels
LIST ALL SERVICE LEVELS;

-- Detach
DETACH SERVICE LEVEL FROM 'analytics_user';
```

### File-Based Streaming

Tablet migration uses file-based streaming for dramatically faster topology changes:

**What changed:**
- During tablet migration, entire SSTable files are streamed directly to the target shard
- No deserialization/reserialization of data -- raw file transfer
- Significantly reduces CPU load and time for topology changes
- Only applies to tablet-based keyspaces

**Performance impact:**
- Node addition: 2-5x faster than vnode-based streaming (depending on data size)
- Repair streaming: Also benefits from file-based streaming for tablet-based tables

### Unified Codebase

2025.1 merges Open Source and Enterprise into a single product:

**What changed:**
- All Enterprise features are now available in the unified codebase
- Features previously Enterprise-only (now available to all):
  - Workload prioritization (service levels)
  - Incremental Compaction Strategy (ICS)
  - Audit logging
  - LDAP authentication
  - Encryption at rest support
- Free tier: up to 10TB data and 50 vCPUs
- Commercial license required above free tier limits

**Migration from Open Source 6.x:**
```
ScyllaDB Open Source 6.x --> ScyllaDB 2025.1 (source-available)
- All OSS features preserved
- Additional Enterprise features available
- License change: AGPL --> Source-Available
```

**Migration from Enterprise 2024.x:**
```
ScyllaDB Enterprise 2024.x --> ScyllaDB 2025.1 (source-available)
- All Enterprise features preserved
- Unified versioning
- License change: Proprietary --> Source-Available
```

## Upgrade Path to 2025.1

### From ScyllaDB Open Source 6.2

```bash
# Step 1: Verify compatibility
nodetool version   # must be 6.2.x

# Step 2: Rolling upgrade (one node at a time)
# On each node:
nodetool drain
sudo systemctl stop scylla-server

# Install 2025.1 packages (replaces 6.x)
# (follow ScyllaDB docs for your package manager)

sudo systemctl start scylla-server
nodetool version   # verify 2025.1

# Step 3: After all nodes upgraded, enable Raft topology
curl -s -X POST http://localhost:10000/storage_service/raft_topology/upgrade

# Step 4: Verify
nodetool describecluster   # single schema version
nodetool status            # all nodes UN
```

### From ScyllaDB Enterprise 2024.2

```bash
# Same rolling upgrade process
# Enterprise 2024.2 --> 2025.1 is a supported upgrade path
# All Enterprise features carry over
```

## Configuration Changes in 2025.1

### New/Changed Parameters

```yaml
# scylla.yaml changes in 2025.1

# Tablets mode (new default)
tablets_mode_for_new_keyspaces: enabled   # was: disabled in 6.x

# Raft topology (new default for new clusters)
# For existing clusters, enable via REST API after upgrade

# Audit logging (formerly Enterprise-only)
audit: table                    # none, table, syslog
audit_categories: AUTH,DDL,DML,DCL
audit_keyspaces: my_ks          # optional: limit to specific keyspaces
audit_tables: my_ks.my_table    # optional: limit to specific tables
```

### scylla.yaml Validation

2025.1 is stricter about invalid configuration parameters:
- Unrecognized parameters now generate warnings at startup
- Some deprecated parameters may cause startup failure
- Review logs after upgrade for configuration warnings

## Version-Specific Diagnostics

### Checking Tablet Status

```bash
# Check if a keyspace uses tablets
curl -s http://localhost:10000/storage_service/tablets/my_ks

# Check tablet count for a table
curl -s "http://localhost:10000/column_family/tablets/my_ks:my_table"
```

```cql
-- Check tablet metadata
SELECT * FROM system.tablets WHERE keyspace_name = 'my_ks';
```

### Checking Raft Status

```bash
# Raft topology status
curl -s http://localhost:10000/storage_service/raft_topology/status

# Raft group 0 leader
curl -s http://localhost:10000/storage_service/raft_topology/leader
```

```cql
-- Raft group status
SELECT * FROM system.raft;

-- Topology operations log
SELECT * FROM system.topology;
```

### Checking Service Level Assignment

```cql
-- List all service levels
LIST ALL SERVICE LEVELS;

-- Show service level for a role
LIST SERVICE LEVEL OF 'app_user';

-- Show all service level attachments
SELECT * FROM system_distributed.service_levels;
SELECT * FROM system_distributed.role_attributes;
```

## Known Issues and Workarounds

### Counters Not Supported with Tablets

Counter tables must use vnodes in 2025.1:

```cql
-- Create counter keyspace with vnodes explicitly
CREATE KEYSPACE counter_ks WITH replication = {
    'class': 'NetworkTopologyStrategy',
    'dc1': 3
} AND tablets = {'enabled': false};

CREATE TABLE counter_ks.page_views (
    page_id text PRIMARY KEY,
    view_count counter
);
```

This limitation is resolved in ScyllaDB 2026.1.

### CDC with Tablets is Experimental

Change Data Capture with tablets is not production-ready in 2025.1:
- Use vnodes for tables that require CDC
- Or test CDC with tablets in a non-production environment

### Vnode-to-Tablet Migration

There is no in-place migration from vnodes to tablets. To move a table from vnodes to tablets:

1. Create a new keyspace with tablets enabled
2. Create the table in the new keyspace
3. Migrate data (spark migrator, sstableloader, or dual-write)
4. Switch application to the new keyspace
5. Drop the old keyspace

## Compatibility Notes

### Driver Compatibility

ScyllaDB 2025.1 is compatible with:
- ScyllaDB Java driver 4.x+ (shard-aware)
- ScyllaDB Python driver 3.x+ (shard-aware)
- ScyllaDB Go driver (gocqlx) 2.x+
- ScyllaDB Rust driver 0.8+
- DataStax Cassandra drivers (without shard-awareness)

### CQL Protocol Compatibility

- CQL protocol version 4 (Cassandra 3.x compatible)
- CQL protocol version 5 (experimental)

### Cassandra Compatibility

- Wire-compatible with Apache Cassandra 3.x protocol
- Schema-compatible with Cassandra 4.x CQL syntax (most features)
- SSTable format compatible for migration (mc/md format)
