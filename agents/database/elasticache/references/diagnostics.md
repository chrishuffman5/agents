# Amazon ElastiCache and MemoryDB Diagnostics Reference

> 120+ AWS CLI commands, redis-cli commands, and CloudWatch queries for ElastiCache and MemoryDB diagnostics, monitoring, and troubleshooting. Every command includes full syntax, what it reveals, key output fields, concerning thresholds, and remediation steps.

---

## ElastiCache Cluster Information

### 1. Describe All Cache Clusters

```bash
aws elasticache describe-cache-clusters
```
**Shows:** All ElastiCache cache clusters (individual nodes) in the current region.
**Key output fields:**
- `CacheClusters[].CacheClusterId` -- Node identifier
- `CacheClusters[].CacheClusterStatus` -- available, creating, modifying, deleting, rebooting, snapshotting
- `CacheClusters[].Engine` -- redis, valkey, or memcached
- `CacheClusters[].EngineVersion` -- Engine version
- `CacheClusters[].CacheNodeType` -- Node type (e.g., cache.r7g.large)
- `CacheClusters[].NumCacheNodes` -- Number of nodes (1 for Redis/Valkey, 1-40 for Memcached)
- `CacheClusters[].PreferredAvailabilityZone`
- `CacheClusters[].CacheClusterCreateTime`
**Concerning:** Status not `available`, unexpected engine version.

### 2. Describe a Specific Cache Cluster with Node Details

```bash
aws elasticache describe-cache-clusters \
  --cache-cluster-id my-cache-001 \
  --show-cache-node-info
```
**Shows:** Detailed information including individual cache node endpoints and status.
**Key output fields:**
- `CacheNodes[].CacheNodeId` -- Individual node ID (0001, 0002, ...)
- `CacheNodes[].CacheNodeStatus` -- available, creating, etc.
- `CacheNodes[].Endpoint.Address` / `.Port`
- `CacheNodes[].ParameterGroupStatus` -- in-sync or pending-reboot
- `CacheNodes[].CustomerAvailabilityZone`

### 3. List All Cache Clusters with Status Summary

```bash
aws elasticache describe-cache-clusters \
  --query 'CacheClusters[].{ID:CacheClusterId,Status:CacheClusterStatus,Engine:Engine,Version:EngineVersion,NodeType:CacheNodeType,AZ:PreferredAvailabilityZone}'  \
  --output table
```
**Shows:** Compact overview of all clusters.

### 4. Filter Clusters by Engine Type

```bash
# Only Redis clusters
aws elasticache describe-cache-clusters \
  --query 'CacheClusters[?Engine==`redis`].{ID:CacheClusterId,Version:EngineVersion,NodeType:CacheNodeType}' \
  --output table

# Only Valkey clusters
aws elasticache describe-cache-clusters \
  --query 'CacheClusters[?Engine==`valkey`].{ID:CacheClusterId,Version:EngineVersion,NodeType:CacheNodeType}' \
  --output table

# Only Memcached clusters
aws elasticache describe-cache-clusters \
  --query 'CacheClusters[?Engine==`memcached`].{ID:CacheClusterId,Version:EngineVersion,NodeType:CacheNodeType}' \
  --output table
```

### 5. Check Cache Cluster Creation Time and Age

```bash
aws elasticache describe-cache-clusters \
  --query 'CacheClusters[].{ID:CacheClusterId,Created:CacheClusterCreateTime}' \
  --output table
```

---

## Replication Group Diagnostics

### 6. Describe All Replication Groups

```bash
aws elasticache describe-replication-groups
```
**Shows:** All Redis/Valkey replication groups (logical clusters including primary and replicas).
**Key output fields:**
- `ReplicationGroups[].ReplicationGroupId`
- `ReplicationGroups[].Status` -- available, creating, modifying, deleting, snapshotting
- `ReplicationGroups[].ClusterEnabled` -- true (cluster mode) or false
- `ReplicationGroups[].MultiAZ` -- enabled or disabled
- `ReplicationGroups[].AutomaticFailover` -- enabled or disabled
- `ReplicationGroups[].NodeGroups[].NodeGroupId` -- Shard ID
- `ReplicationGroups[].NodeGroups[].Status`
- `ReplicationGroups[].NodeGroups[].Slots` -- Hash slot range (e.g., "0-5460")
- `ReplicationGroups[].NodeGroups[].NodeGroupMembers[]` -- Primary and replica nodes
**Concerning:** Status not `available`, `AutomaticFailover: disabled`, `MultiAZ: disabled` for production.

### 7. Describe a Specific Replication Group

```bash
aws elasticache describe-replication-groups \
  --replication-group-id my-cache
```

### 8. Get Replication Group Endpoints

```bash
aws elasticache describe-replication-groups \
  --replication-group-id my-cache \
  --query 'ReplicationGroups[0].{PrimaryEndpoint:NodeGroups[0].PrimaryEndpoint,ReaderEndpoint:NodeGroups[0].ReaderEndpoint,ConfigEndpoint:ConfigurationEndpoint}'
```
**Shows:** Primary, reader, and configuration endpoints.

### 9. List All Shards and Their Slot Ranges

```bash
aws elasticache describe-replication-groups \
  --replication-group-id my-cache \
  --query 'ReplicationGroups[0].NodeGroups[].{ShardId:NodeGroupId,Slots:Slots,Status:Status}' \
  --output table
```

### 10. List All Node Group Members with Roles

```bash
aws elasticache describe-replication-groups \
  --replication-group-id my-cache \
  --query 'ReplicationGroups[0].NodeGroups[].NodeGroupMembers[].{ShardId:CacheClusterId,Role:CurrentRole,AZ:PreferredAvailabilityZone,Endpoint:ReadEndpoint.Address}' \
  --output table
```
**Shows:** Which nodes are primary vs. replica in each shard.

### 11. Check Multi-AZ and Automatic Failover Status

```bash
aws elasticache describe-replication-groups \
  --replication-group-id my-cache \
  --query 'ReplicationGroups[0].{MultiAZ:MultiAZ,AutoFailover:AutomaticFailover,Status:Status}' \
  --output table
```
**Concerning:** `MultiAZ: disabled` or `AutoFailover: disabled` for production clusters.

### 12. Check Pending Modifications

```bash
aws elasticache describe-replication-groups \
  --replication-group-id my-cache \
  --query 'ReplicationGroups[0].PendingModifiedValues'
```
**Shows:** Any pending changes (engine version, node type, etc.) waiting to be applied.

---

## Engine Version and Compatibility

### 13. List Available Cache Engine Versions

```bash
aws elasticache describe-cache-engine-versions --engine redis
aws elasticache describe-cache-engine-versions --engine valkey
aws elasticache describe-cache-engine-versions --engine memcached
```
**Shows:** All available engine versions, parameter group family, and whether the version is the default.
**Key output fields:**
- `CacheEngineVersions[].EngineVersion`
- `CacheEngineVersions[].CacheParameterGroupFamily`
- `CacheEngineVersions[].CacheEngineDescription`

### 14. Check Upgrade Eligibility for a Specific Version

```bash
aws elasticache describe-cache-engine-versions \
  --engine valkey \
  --engine-version 7.2 \
  --query 'CacheEngineVersions[].{Version:EngineVersion,Family:CacheParameterGroupFamily}'
```

### 15. List All Allowed Node Types for an Engine

```bash
aws elasticache list-allowed-node-type-modifications \
  --replication-group-id my-cache
```
**Shows:** Which node types you can scale up/down to from the current node type.

---

## Parameter Group Diagnostics

### 16. Describe Cache Parameter Groups

```bash
aws elasticache describe-cache-parameter-groups
```
**Shows:** All parameter groups in the account.

### 17. List Parameters in a Parameter Group

```bash
aws elasticache describe-cache-parameters \
  --cache-parameter-group-name my-valkey-params
```
**Shows:** All parameters, their current values, allowed values, data type, and whether changes require reboot.

### 18. Show Only Modified Parameters (Non-Default)

```bash
aws elasticache describe-cache-parameters \
  --cache-parameter-group-name my-valkey-params \
  --source user \
  --query 'Parameters[].{Name:ParameterName,Value:ParameterValue,DataType:DataType}'  \
  --output table
```
**Shows:** Only parameters explicitly modified from defaults.

### 19. Compare Custom Parameters Against Defaults

```bash
# Get default values
aws elasticache describe-cache-parameters \
  --cache-parameter-group-name default.valkey8.0 \
  --query 'Parameters[].{Name:ParameterName,Value:ParameterValue}' \
  --output json > /tmp/defaults.json

# Get custom values
aws elasticache describe-cache-parameters \
  --cache-parameter-group-name my-valkey-params \
  --query 'Parameters[].{Name:ParameterName,Value:ParameterValue}' \
  --output json > /tmp/custom.json

# Diff
diff /tmp/defaults.json /tmp/custom.json
```

### 20. Check a Specific Parameter Value

```bash
aws elasticache describe-cache-parameters \
  --cache-parameter-group-name my-valkey-params \
  --query "Parameters[?ParameterName=='maxmemory-policy'].{Name:ParameterName,Value:ParameterValue,Modifiable:IsModifiable}" \
  --output table
```

### 21. List Parameters Requiring Reboot

```bash
aws elasticache describe-cache-parameters \
  --cache-parameter-group-name my-valkey-params \
  --query "Parameters[?ChangeType=='requires-reboot'].{Name:ParameterName,Value:ParameterValue}" \
  --output table
```

---

## Event and Notification Diagnostics

### 22. Describe Recent Events (Last 24 Hours)

```bash
aws elasticache describe-events \
  --duration 1440 \
  --source-type cache-cluster
```
**Shows:** Events related to cache clusters (failover, maintenance, scaling, errors).
**Key output fields:**
- `Events[].SourceIdentifier`
- `Events[].SourceType`
- `Events[].Message`
- `Events[].Date`

### 23. Filter Events for a Specific Cluster

```bash
aws elasticache describe-events \
  --source-identifier my-cache-001 \
  --source-type cache-cluster \
  --duration 10080
```
**Shows:** Events for a specific node in the last 7 days.

### 24. Filter Events for Replication Groups

```bash
aws elasticache describe-events \
  --source-type replication-group \
  --duration 10080
```

### 25. Filter Events for Failover Events

```bash
aws elasticache describe-events \
  --source-type replication-group \
  --duration 10080 \
  --query "Events[?contains(Message, 'failover')]"
```

### 26. Filter Events for Maintenance Events

```bash
aws elasticache describe-events \
  --source-type cache-cluster \
  --duration 10080 \
  --query "Events[?contains(Message, 'maintenance') || contains(Message, 'patching')]"
```

---

## Snapshot and Backup Diagnostics

### 27. List All Snapshots

```bash
aws elasticache describe-snapshots
```
**Key output fields:**
- `Snapshots[].SnapshotName`
- `Snapshots[].SnapshotStatus` -- creating, available, deleting, copying, restoring
- `Snapshots[].SnapshotSource` -- automated or manual
- `Snapshots[].CacheClusterCreateTime`
- `Snapshots[].NodeSnapshots[].SnapshotCreateTime`
- `Snapshots[].NodeSnapshots[].CacheSize` -- Size of the snapshot

### 28. List Snapshots for a Specific Replication Group

```bash
aws elasticache describe-snapshots \
  --replication-group-id my-cache \
  --query 'Snapshots[].{Name:SnapshotName,Status:SnapshotStatus,Source:SnapshotSource,Size:NodeSnapshots[0].CacheSize,Created:NodeSnapshots[0].SnapshotCreateTime}' \
  --output table
```

### 29. Check Snapshot Details

```bash
aws elasticache describe-snapshots \
  --snapshot-name my-cache-pre-upgrade-2026-04-07
```
**Shows:** Full snapshot metadata including engine, node type, number of shards, and per-shard snapshot sizes.

### 30. Verify Backup Window Configuration

```bash
aws elasticache describe-replication-groups \
  --replication-group-id my-cache \
  --query 'ReplicationGroups[0].{SnapshotRetention:SnapshotRetentionLimit,SnapshotWindow:SnapshotWindow,SnapshottingNodeId:SnapshottingClusterId}'
```
**Concerning:** `SnapshotRetentionLimit: 0` means automatic backups are disabled.

---

## Security Diagnostics

### 31. Describe Cache Subnet Groups

```bash
aws elasticache describe-cache-subnet-groups
```
**Shows:** Subnet groups, their VPC, and constituent subnets.

### 32. Check Subnet Group for a Cluster

```bash
aws elasticache describe-cache-clusters \
  --cache-cluster-id my-cache-001 \
  --query 'CacheClusters[0].{SubnetGroup:CacheSubnetGroupName,SecurityGroups:SecurityGroups}'
```

### 33. List Security Groups Attached to a Cluster

```bash
aws elasticache describe-cache-clusters \
  --cache-cluster-id my-cache-001 \
  --query 'CacheClusters[0].SecurityGroups[].{SGId:SecurityGroupId,Status:Status}' \
  --output table
```
**Shows:** Security group IDs and their association status.

### 34. Check Encryption Configuration

```bash
aws elasticache describe-replication-groups \
  --replication-group-id my-cache \
  --query 'ReplicationGroups[0].{TransitEncryption:TransitEncryptionEnabled,AtRestEncryption:AtRestEncryptionEnabled,KmsKeyId:KmsKeyId,AuthTokenEnabled:AuthTokenEnabled}'
```
**Concerning:** `TransitEncryptionEnabled: false` or `AtRestEncryptionEnabled: false` for production.

### 35. List ElastiCache Users

```bash
aws elasticache describe-users
```
**Shows:** All ElastiCache users (for ACL-based authentication).
**Key output fields:**
- `Users[].UserId`
- `Users[].UserName`
- `Users[].Status` -- active, modifying, deleting
- `Users[].Engine`
- `Users[].Authentication.Type` -- password, iam, no-password
- `Users[].AccessString` -- ACL permissions

### 36. Describe a Specific User's Permissions

```bash
aws elasticache describe-users \
  --user-id app-user-01 \
  --query 'Users[0].{UserId:UserId,UserName:UserName,Auth:Authentication,Access:AccessString}'
```

### 37. List User Groups

```bash
aws elasticache describe-user-groups
```
**Shows:** User groups and their member users.

### 38. Check Which User Group Is Applied to a Replication Group

```bash
aws elasticache describe-replication-groups \
  --replication-group-id my-cache \
  --query 'ReplicationGroups[0].UserGroupIds'
```

---

## ElastiCache Serverless Diagnostics

### 39. Describe Serverless Caches

```bash
aws elasticache describe-serverless-caches
```
**Key output fields:**
- `ServerlessCaches[].ServerlessCacheName`
- `ServerlessCaches[].Status` -- available, creating, modifying, deleting
- `ServerlessCaches[].Engine` -- redis, valkey
- `ServerlessCaches[].MajorEngineVersion`
- `ServerlessCaches[].Endpoint.Address` / `.Port`
- `ServerlessCaches[].ReaderEndpoint.Address` / `.Port`
- `ServerlessCaches[].CacheUsageLimits.DataStorage.Maximum` -- Max data storage in GB
- `ServerlessCaches[].CacheUsageLimits.ECPUPerSecond.Maximum` -- Max ECPUs/second

### 40. Describe a Specific Serverless Cache

```bash
aws elasticache describe-serverless-caches \
  --serverless-cache-name my-serverless-cache
```

### 41. Check Serverless Cache Snapshots

```bash
aws elasticache describe-serverless-cache-snapshots \
  --serverless-cache-name my-serverless-cache
```

---

## Global Datastore Diagnostics

### 42. Describe Global Replication Groups

```bash
aws elasticache describe-global-replication-groups
```
**Key output fields:**
- `GlobalReplicationGroups[].GlobalReplicationGroupId`
- `GlobalReplicationGroups[].Status` -- available, creating, modifying, deleting
- `GlobalReplicationGroups[].Engine`
- `GlobalReplicationGroups[].Members[].ReplicationGroupId`
- `GlobalReplicationGroups[].Members[].ReplicationGroupRegion`
- `GlobalReplicationGroups[].Members[].Role` -- PRIMARY or SECONDARY
- `GlobalReplicationGroups[].Members[].Status`

### 43. Describe a Specific Global Datastore

```bash
aws elasticache describe-global-replication-groups \
  --global-replication-group-id ldgnf-my-global \
  --show-member-info
```
**Shows:** Full member details including regional replication group IDs and their roles.

### 44. Check Global Datastore Replication Lag

```bash
# Via CloudWatch (primary metric for cross-region lag)
aws cloudwatch get-metric-statistics \
  --namespace AWS/ElastiCache \
  --metric-name GlobalDatastoreReplicationLag \
  --dimensions Name=GlobalReplicationGroupId,Value=ldgnf-my-global \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Average Maximum \
  --unit Seconds
```
**Concerning:** Average > 1 second, Maximum > 5 seconds.

---

## MemoryDB Diagnostics

### 45. Describe MemoryDB Clusters

```bash
aws memorydb describe-clusters
```
**Key output fields:**
- `Clusters[].Name`
- `Clusters[].Status` -- available, creating, updating, deleting
- `Clusters[].Engine` -- redis, valkey
- `Clusters[].EngineVersion`
- `Clusters[].NodeType`
- `Clusters[].NumberOfShards`
- `Clusters[].ClusterEndpoint.Address` / `.Port`
- `Clusters[].TLSEnabled`
- `Clusters[].ACLName`

### 46. Describe a Specific MemoryDB Cluster

```bash
aws memorydb describe-clusters \
  --cluster-name my-memorydb \
  --show-shard-details
```
**Shows:** Full shard details including node endpoints, roles, and status.

### 47. List MemoryDB Cluster Shards and Nodes

```bash
aws memorydb describe-clusters \
  --cluster-name my-memorydb \
  --show-shard-details \
  --query 'Clusters[0].Shards[].{ShardName:Name,Slots:Slots,Status:Status,Nodes:Nodes[].{Name:Name,Status:Status,AZ:AvailabilityZone,Endpoint:Endpoint.Address}}' \
  --output json
```

### 48. Describe MemoryDB ACLs

```bash
aws memorydb describe-acls
```
**Shows:** All ACLs with member users.

### 49. Describe a Specific MemoryDB ACL

```bash
aws memorydb describe-acls \
  --acl-name my-acl \
  --query 'ACLs[0].{Name:Name,Status:Status,UserNames:UserNames,MinEngineVersion:MinimumEngineVersion}'
```

### 50. List MemoryDB Users

```bash
aws memorydb describe-users
```
**Key output fields:**
- `Users[].Name`
- `Users[].Status`
- `Users[].AccessString`
- `Users[].Authentication.Type`
- `Users[].ACLNames`

### 51. Describe MemoryDB Snapshots

```bash
aws memorydb describe-snapshots
```

### 52. Describe Snapshots for a Specific MemoryDB Cluster

```bash
aws memorydb describe-snapshots \
  --cluster-name my-memorydb \
  --query 'Snapshots[].{Name:Name,Status:Status,Source:Source,ClusterConfig:ClusterConfiguration.{Engine:Engine,Version:EngineVersion,Shards:NumShards,NodeType:NodeType}}' \
  --output table
```

### 53. Describe MemoryDB Parameter Groups

```bash
aws memorydb describe-parameter-groups
```

### 54. List Parameters in a MemoryDB Parameter Group

```bash
aws memorydb describe-parameters \
  --parameter-group-name my-memorydb-params
```

### 55. Describe MemoryDB Subnet Groups

```bash
aws memorydb describe-subnet-groups
```

### 56. Describe MemoryDB Events

```bash
aws memorydb describe-events \
  --duration 10080 \
  --source-type cluster
```

---

## Redis/Valkey INFO Command Diagnostics (via redis-cli)

Connect to an ElastiCache or MemoryDB endpoint using redis-cli:

```bash
# Non-TLS connection
redis-cli -h my-cache.abc123.ng.0001.use1.cache.amazonaws.com -p 6379

# TLS connection
redis-cli -h my-cache.abc123.ng.0001.use1.cache.amazonaws.com -p 6379 --tls

# TLS + AUTH token
redis-cli -h my-cache.abc123.ng.0001.use1.cache.amazonaws.com -p 6379 --tls -a 'MyAuthToken'

# TLS + ACL user
redis-cli -h my-cache.abc123.ng.0001.use1.cache.amazonaws.com -p 6379 --tls --user appuser -a 'password'
```

### 57. Full INFO Output

```bash
redis-cli INFO
```
**Shows:** Complete server state across all sections.

### 58. INFO Server Section

```bash
redis-cli INFO server
```
**Key fields:**
- `redis_version` / `valkey_version` -- Engine version running
- `uptime_in_seconds` / `uptime_in_days`
- `tcp_port`
- `os` -- Operating system
- `process_id`
- `connected_clients` -- Current connection count
- `maxclients` -- Maximum allowed connections

### 59. INFO Memory Section

```bash
redis-cli INFO memory
```
**Key fields:**
- `used_memory` -- Total bytes allocated by the allocator (data + overhead)
- `used_memory_human` -- Human-readable version
- `used_memory_rss` -- Resident set size (actual RAM used, as seen by OS)
- `used_memory_peak` -- Peak memory usage since startup
- `maxmemory` -- Maximum memory limit configured
- `maxmemory_policy` -- Eviction policy
- `mem_fragmentation_ratio` -- `used_memory_rss / used_memory`. Ideal: 1.0-1.5. > 1.5 indicates fragmentation. < 1.0 indicates swap usage.
- `mem_allocator` -- jemalloc version
**Concerning:** `mem_fragmentation_ratio` > 1.5, `used_memory` approaching `maxmemory`, swap usage indicated by ratio < 1.0.

### 60. INFO Replication Section

```bash
redis-cli INFO replication
```
**Key fields:**
- `role` -- master or slave
- `connected_slaves` -- Number of connected replicas (on primary)
- `master_repl_offset` -- Primary replication offset
- `slave0:ip=...,port=...,state=online,offset=...,lag=...` -- Per-replica status
- `master_link_status` -- up or down (on replica)
- `master_last_io_seconds_ago` -- Seconds since last communication with primary (on replica)
- `master_sync_in_progress` -- 1 if full sync in progress
- `slave_repl_offset` -- Replica's current replication offset
- `repl_backlog_size` -- Size of the replication backlog buffer
- `repl_backlog_histlen` -- Amount of data in the backlog
**Concerning:** `connected_slaves` less than expected, `master_link_status: down`, `lag` > 1 second, `master_sync_in_progress: 1` (full resync happening).

### 61. INFO Clients Section

```bash
redis-cli INFO clients
```
**Key fields:**
- `connected_clients` -- Current number of connected clients
- `blocked_clients` -- Clients blocked on BRPOP, BLPOP, XREAD BLOCK
- `tracking_clients` -- Clients using client-side caching (RESP3)
- `maxclients` -- Maximum allowed clients
**Concerning:** `connected_clients` approaching `maxclients`, `blocked_clients` high (check BRPOP/BLPOP usage).

### 62. INFO Stats Section

```bash
redis-cli INFO stats
```
**Key fields:**
- `total_connections_received` -- Total connections since startup
- `total_commands_processed` -- Total commands since startup
- `instantaneous_ops_per_sec` -- Current operations per second
- `keyspace_hits` -- Successful key lookups
- `keyspace_misses` -- Failed key lookups (cache misses)
- `evicted_keys` -- Total keys evicted due to maxmemory
- `expired_keys` -- Total keys expired
- `rejected_connections` -- Connections rejected (maxclients reached)
- `total_net_input_bytes` / `total_net_output_bytes` -- Network I/O totals
**Concerning:** `evicted_keys` increasing rapidly, `rejected_connections` > 0, low hit rate (`keyspace_hits / (keyspace_hits + keyspace_misses)` < 0.8).

### 63. INFO Keyspace Section

```bash
redis-cli INFO keyspace
```
**Key fields:**
- `db0:keys=1234567,expires=987654,avg_ttl=3600000` -- Per-database key count, keys with TTL, average TTL in ms
**Shows:** Total number of keys, how many have expiration set, and average TTL.

### 64. INFO Persistence Section

```bash
redis-cli INFO persistence
```
**Key fields:**
- `rdb_last_save_time` -- Timestamp of last successful RDB save
- `rdb_last_bgsave_status` -- ok or err
- `rdb_last_bgsave_time_sec` -- Duration of last BGSAVE
- `rdb_current_bgsave_time_sec` -- Duration of current BGSAVE (if in progress)
- `loading` -- 1 if server is loading RDB file
**Concerning:** `rdb_last_bgsave_status: err`, `loading: 1` (server recovering).

### 65. INFO CPU Section

```bash
redis-cli INFO cpu
```
**Key fields:**
- `used_cpu_sys` -- System CPU consumed by Redis process
- `used_cpu_user` -- User CPU consumed by Redis process
- `used_cpu_sys_children` -- System CPU consumed by background children (BGSAVE)
- `used_cpu_user_children` -- User CPU consumed by background children

---

## Slow Log and Latency Diagnostics

### 66. Get Slow Log Entries

```bash
redis-cli SLOWLOG GET 25
```
**Shows:** Last 25 commands that exceeded the `slowlog-log-slower-than` threshold (default: 10,000 microseconds = 10ms).
**Output per entry:** ID, timestamp, execution time (microseconds), command with arguments, client IP:port.
**Concerning:** Frequent slow commands, O(N) commands on large datasets (KEYS, SMEMBERS, HGETALL, SORT).

### 67. Get Slow Log Length

```bash
redis-cli SLOWLOG LEN
```
**Shows:** Number of entries in the slow log. If it fills up, oldest entries are evicted.

### 68. Reset Slow Log

```bash
redis-cli SLOWLOG RESET
```
**Use:** Clear slow log before a test to capture only new slow commands.

### 69. Get Latency History

```bash
redis-cli LATENCY HISTORY command
redis-cli LATENCY HISTORY fast-command
redis-cli LATENCY HISTORY fork
```
**Shows:** Timestamped latency samples for specific event types. Requires `latency-monitor-threshold` to be set (default 0 = disabled).

### 70. Enable Latency Monitoring

```bash
redis-cli CONFIG SET latency-monitor-threshold 5
```
**Sets:** Record events that take longer than 5 milliseconds.

### 71. Get Latest Latency Events

```bash
redis-cli LATENCY LATEST
```
**Shows:** Latest latency spike for each event type (command, fork, expire-cycle, etc.).

### 72. Get Latency Doctor Report

```bash
redis-cli LATENCY DOCTOR
```
**Shows:** Human-readable analysis of latency issues with recommendations.

### 73. Get Memory Doctor Report

```bash
redis-cli MEMORY DOCTOR
```
**Shows:** Memory-related recommendations (fragmentation, allocation issues).

---

## Cluster Mode Diagnostics

### 74. CLUSTER INFO

```bash
redis-cli CLUSTER INFO
```
**Key fields:**
- `cluster_enabled` -- 1 if cluster mode is enabled
- `cluster_state` -- ok or fail
- `cluster_slots_assigned` -- Should be 16384
- `cluster_slots_ok` -- Should be 16384
- `cluster_slots_pfail` -- Slots in PFAIL state (potential failure)
- `cluster_slots_fail` -- Slots in FAIL state (confirmed failure)
- `cluster_known_nodes` -- Total nodes in the cluster
- `cluster_size` -- Number of master nodes with assigned slots
**Concerning:** `cluster_state: fail`, `cluster_slots_fail > 0`, `cluster_slots_assigned < 16384`.

### 75. CLUSTER NODES

```bash
redis-cli CLUSTER NODES
```
**Shows:** All nodes in the cluster with their ID, IP:port, role (master/slave), connected/disconnected, slot ranges.
**Format per line:** `<node-id> <ip>:<port>@<bus-port> <flags> <master-id> <ping-sent> <pong-recv> <config-epoch> <link-state> <slots>`
**Concerning:** Nodes with `fail` or `pfail` flag, nodes with `disconnected` link state.

### 76. CLUSTER SLOTS

```bash
redis-cli CLUSTER SLOTS
```
**Shows:** Slot ranges mapped to primary and replica nodes. Useful for verifying slot distribution.

### 77. CLUSTER KEYSLOT (Check Key Placement)

```bash
redis-cli CLUSTER KEYSLOT "user:1000:profile"
redis-cli CLUSTER KEYSLOT "{user:1000}:profile"
redis-cli CLUSTER KEYSLOT "{user:1000}:sessions"
```
**Shows:** Which hash slot a key maps to. Verify co-location with hash tags.

### 78. CLUSTER COUNTKEYSINSLOT (Keys Per Slot)

```bash
redis-cli CLUSTER COUNTKEYSINSLOT 5000
```
**Shows:** Number of keys in a specific slot. Useful for detecting hot slots.

### 79. CLUSTER GETKEYSINSLOT (List Keys in a Slot)

```bash
redis-cli CLUSTER GETKEYSINSLOT 5000 10
```
**Shows:** Up to 10 key names in slot 5000. Useful for inspecting hot slot contents.

### 80. Check Cluster Slot Distribution Balance

```bash
# Count keys per shard by checking slot ranges
for shard_start in 0 5461 10923; do
  echo "Slot $shard_start:"
  redis-cli CLUSTER COUNTKEYSINSLOT $shard_start
done
```
**Investigating skewed data distribution across shards.**

---

## Connection and Client Diagnostics

### 81. CLIENT LIST (Active Connections)

```bash
redis-cli CLIENT LIST
```
**Shows:** All connected clients with ID, address, file descriptor, age, idle time, flags, database, subscriptions, output buffer length, and command being executed.
**Key fields per client:**
- `addr` -- Client IP:port
- `age` -- Connection age in seconds
- `idle` -- Seconds since last command
- `flags` -- S=slave, N=normal, P=pubsub, x=executing multi/exec
- `cmd` -- Last command executed
- `omem` -- Output buffer memory usage
**Concerning:** Many clients with high `idle` time (connection leaks), clients with large `omem` (slow consumers).

### 82. CLIENT LIST Filtered by Type

```bash
redis-cli CLIENT LIST TYPE normal
redis-cli CLIENT LIST TYPE replica
redis-cli CLIENT LIST TYPE pubsub
```

### 83. CLIENT INFO (Self)

```bash
redis-cli CLIENT INFO
```
**Shows:** Information about the current connection.

### 84. CLIENT GETNAME / SETNAME

```bash
redis-cli CLIENT SETNAME "my-app-instance-1"
redis-cli CLIENT GETNAME
```
**Use:** Tag connections with application names for easier debugging in CLIENT LIST.

### 85. Count Connections by Source IP

```bash
redis-cli CLIENT LIST | grep -oP 'addr=\K[^:]+' | sort | uniq -c | sort -rn | head -20
```
**Shows:** Top 20 source IPs by connection count. Identify which application instances have the most connections.

---

## Memory Analysis

### 86. MEMORY USAGE (Per-Key Memory)

```bash
redis-cli MEMORY USAGE "user:1000:profile"
```
**Shows:** Memory consumed by a specific key in bytes (including overhead).

### 87. MEMORY STATS

```bash
redis-cli MEMORY STATS
```
**Shows:** Detailed memory allocation breakdown (dataset, overhead, replication, clients, etc.).

### 88. DBSIZE (Total Key Count)

```bash
redis-cli DBSIZE
```
**Shows:** Total number of keys in the current database.

### 89. TYPE (Key Type)

```bash
redis-cli TYPE "user:1000:profile"
```
**Shows:** Data type of a key (string, hash, list, set, zset, stream).

### 90. OBJECT ENCODING (Internal Encoding)

```bash
redis-cli OBJECT ENCODING "user:1000:profile"
```
**Shows:** Internal encoding (listpack, hashtable, ziplist, skiplist, etc.). Useful for verifying memory efficiency.

### 91. OBJECT FREQ (Access Frequency for LFU)

```bash
redis-cli OBJECT FREQ "user:1000:profile"
```
**Shows:** LFU frequency counter. Only works when `maxmemory-policy` is an LFU variant.

### 92. OBJECT IDLETIME (Idle Time for LRU)

```bash
redis-cli OBJECT IDLETIME "user:1000:profile"
```
**Shows:** Seconds since last access. Only works when `maxmemory-policy` is an LRU variant.

### 93. SCAN for Key Pattern Analysis

```bash
# Count keys matching a pattern
redis-cli --scan --pattern "user:*" | wc -l

# Sample large keys by type
redis-cli --scan --pattern "*" --count 1000 | head -100 | while read key; do
  echo "$key $(redis-cli TYPE $key) $(redis-cli MEMORY USAGE $key)"
done
```

### 94. Find Big Keys

```bash
redis-cli --bigkeys
```
**Shows:** Samples the keyspace and reports the largest key per data type. Useful for identifying memory hogs.
**Note:** This command performs a full scan and can take a long time on large datasets. Run during low traffic.

### 95. Memory Usage Summary by Key Prefix

```bash
redis-cli --memkeys
```
**Shows:** Samples the keyspace and summarizes memory usage by key pattern. More detailed than `--bigkeys`.

---

## CloudWatch Metrics Diagnostics

### 96. Get CPUUtilization

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/ElastiCache \
  --metric-name CPUUtilization \
  --dimensions Name=CacheClusterId,Value=my-cache-001 \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average Maximum
```
**Concerning:** Average > 90%, Maximum > 95%.
**Note:** CPUUtilization includes all vCPU cores. For single-threaded Redis, check `EngineCPUUtilization` instead.

### 97. Get EngineCPUUtilization

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/ElastiCache \
  --metric-name EngineCPUUtilization \
  --dimensions Name=CacheClusterId,Value=my-cache-001 \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average Maximum
```
**Shows:** CPU utilization of the Redis/Valkey engine thread only.
**Concerning:** > 80% sustained indicates the engine is bottlenecked. Scale up or optimize commands.

### 98. Get DatabaseMemoryUsagePercentage

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/ElastiCache \
  --metric-name DatabaseMemoryUsagePercentage \
  --dimensions Name=CacheClusterId,Value=my-cache-001 \
  --start-time $(date -u -d '6 hours ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average Maximum
```
**Concerning:** Average > 80%, Maximum > 90%. Risk of evictions or OOM.

### 99. Get Evictions

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/ElastiCache \
  --metric-name Evictions \
  --dimensions Name=CacheClusterId,Value=my-cache-001 \
  --start-time $(date -u -d '24 hours ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 3600 \
  --statistics Sum
```
**Concerning:** Any evictions in a non-caching workload (data loss). Sustained evictions in caching workload indicates under-sizing.

### 100. Get CacheHitRate

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/ElastiCache \
  --metric-name CacheHitRate \
  --dimensions Name=CacheClusterId,Value=my-cache-001 \
  --start-time $(date -u -d '24 hours ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 3600 \
  --statistics Average
```
**Concerning:** < 80% indicates poor caching effectiveness. Review TTLs, caching strategy, and key design.

### 101. Get CurrConnections

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/ElastiCache \
  --metric-name CurrConnections \
  --dimensions Name=CacheClusterId,Value=my-cache-001 \
  --start-time $(date -u -d '24 hours ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average Maximum
```
**Concerning:** Approaching maxclients limit (65,000), sudden spikes indicate connection storms.

### 102. Get NewConnections

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/ElastiCache \
  --metric-name NewConnections \
  --dimensions Name=CacheClusterId,Value=my-cache-001 \
  --start-time $(date -u -d '24 hours ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum
```
**Concerning:** Spikes > 1000 per 5 minutes suggest connection churn (no pooling) or application restarts.

### 103. Get ReplicationLag

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/ElastiCache \
  --metric-name ReplicationLag \
  --dimensions Name=CacheClusterId,Value=my-cache-002 \
  --start-time $(date -u -d '6 hours ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Average Maximum
```
**Note:** Metric is on the replica node, not the primary.
**Concerning:** Average > 0.5 seconds, Maximum > 2 seconds.

### 104. Get SwapUsage

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/ElastiCache \
  --metric-name SwapUsage \
  --dimensions Name=CacheClusterId,Value=my-cache-001 \
  --start-time $(date -u -d '6 hours ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Maximum
```
**Concerning:** Any swap usage > 50 MB indicates severe memory pressure. Scale up immediately.

### 105. Get NetworkBytesIn and NetworkBytesOut

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/ElastiCache \
  --metric-name NetworkBytesIn \
  --dimensions Name=CacheClusterId,Value=my-cache-001 \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum

aws cloudwatch get-metric-statistics \
  --namespace AWS/ElastiCache \
  --metric-name NetworkBytesOut \
  --dimensions Name=CacheClusterId,Value=my-cache-001 \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum
```
**Concerning:** Approaching network bandwidth limit of the node type.

### 106. Get GetTypeCmds and SetTypeCmds (Operations Per Second)

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/ElastiCache \
  --metric-name GetTypeCmds \
  --dimensions Name=CacheClusterId,Value=my-cache-001 \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum

aws cloudwatch get-metric-statistics \
  --namespace AWS/ElastiCache \
  --metric-name SetTypeCmds \
  --dimensions Name=CacheClusterId,Value=my-cache-001 \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum
```
**Shows:** Read and write operation volumes. Useful for capacity planning and identifying read/write ratio.

### 107. Get BytesUsedForCache (Memcached)

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/ElastiCache \
  --metric-name BytesUsedForCache \
  --dimensions Name=CacheClusterId,Value=my-memcached-001 \
  --start-time $(date -u -d '6 hours ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

### 108. Get FreeableMemory

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/ElastiCache \
  --metric-name FreeableMemory \
  --dimensions Name=CacheClusterId,Value=my-cache-001 \
  --start-time $(date -u -d '6 hours ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Minimum
```
**Concerning:** Freeable memory approaching 0 bytes.

---

## MemoryDB CloudWatch Metrics

### 109. Get MemoryDB EngineCPUUtilization

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/MemoryDB \
  --metric-name EngineCPUUtilization \
  --dimensions Name=ClusterName,Value=my-memorydb Name=NodeName,Value=my-memorydb-0001-001 \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average Maximum
```

### 110. Get MemoryDB DatabaseMemoryUsagePercentage

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/MemoryDB \
  --metric-name DatabaseMemoryUsagePercentage \
  --dimensions Name=ClusterName,Value=my-memorydb Name=NodeName,Value=my-memorydb-0001-001 \
  --start-time $(date -u -d '6 hours ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average Maximum
```

### 111. Get MemoryDB ReplicationLag

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/MemoryDB \
  --metric-name ReplicationLag \
  --dimensions Name=ClusterName,Value=my-memorydb Name=NodeName,Value=my-memorydb-0001-002 \
  --start-time $(date -u -d '6 hours ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Average Maximum
```

---

## Failover Testing and Diagnostics

### 112. Test Failover

```bash
aws elasticache test-failover \
  --replication-group-id my-cache \
  --node-group-id 0001
```
**Use:** Triggers a failover of the specified shard for testing. Primary is replaced by a replica. Monitor failover duration and application behavior.
**Note:** This is a production operation. Test during a maintenance window.

### 113. Test MemoryDB Failover

```bash
aws memorydb failover-shard \
  --cluster-name my-memorydb \
  --shard-name 0001
```

### 114. Monitor Failover Events

```bash
# Watch events during failover
aws elasticache describe-events \
  --source-identifier my-cache \
  --source-type replication-group \
  --duration 30
```

---

## Cost Analysis

### 115. List Reserved Cache Nodes

```bash
aws elasticache describe-reserved-cache-nodes \
  --query 'ReservedCacheNodes[].{ID:ReservedCacheNodeId,NodeType:CacheNodeType,Count:CacheNodeCount,Duration:Duration,Offering:OfferingType,State:State,StartTime:StartTime}' \
  --output table
```
**Shows:** All reserved node commitments. Verify reservations match current cluster configuration.

### 116. List Reserved Node Offerings

```bash
aws elasticache describe-reserved-cache-nodes-offerings \
  --cache-node-type cache.r7g.xlarge \
  --duration 31536000 \
  --query 'ReservedCacheNodesOfferings[].{OfferingId:ReservedCacheNodesOfferingId,NodeType:CacheNodeType,Duration:Duration,OfferingType:OfferingType,FixedPrice:FixedPrice,RecurringCharges:RecurringCharges}' \
  --output table
```

### 117. MemoryDB Reserved Nodes

```bash
aws memorydb describe-reserved-nodes \
  --query 'ReservedNodes[].{ID:ReservedNodeId,NodeType:NodeType,Count:NodeCount,Duration:Duration,Offering:OfferingType,State:State}' \
  --output table
```

### 118. Cost Explorer -- ElastiCache Spend (Last 30 Days)

```bash
aws ce get-cost-and-usage \
  --time-period Start=$(date -u -d '30 days ago' +%Y-%m-%d),End=$(date -u +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --filter '{"Dimensions":{"Key":"SERVICE","Values":["Amazon ElastiCache"]}}' \
  --query 'ResultsByTime[].{Period:TimePeriod.Start,Cost:Total.BlendedCost.Amount,Unit:Total.BlendedCost.Unit}'
```

### 119. Cost Explorer -- ElastiCache Spend by Usage Type

```bash
aws ce get-cost-and-usage \
  --time-period Start=$(date -u -d '30 days ago' +%Y-%m-%d),End=$(date -u +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --filter '{"Dimensions":{"Key":"SERVICE","Values":["Amazon ElastiCache"]}}' \
  --group-by Type=DIMENSION,Key=USAGE_TYPE \
  --query 'ResultsByTime[].Groups[].{UsageType:Keys[0],Cost:Metrics.BlendedCost.Amount}' \
  --output table
```
**Shows:** Cost breakdown by usage type (node hours, data transfer, backup storage, etc.).

### 120. Cost Explorer -- MemoryDB Spend

```bash
aws ce get-cost-and-usage \
  --time-period Start=$(date -u -d '30 days ago' +%Y-%m-%d),End=$(date -u +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --filter '{"Dimensions":{"Key":"SERVICE","Values":["Amazon MemoryDB"]}}' \
  --query 'ResultsByTime[].{Period:TimePeriod.Start,Cost:Total.BlendedCost.Amount,Unit:Total.BlendedCost.Unit}'
```

---

## Advanced Diagnostics

### 121. COMMANDSTATS (Command Execution Profile)

```bash
redis-cli INFO commandstats
```
**Shows:** Per-command execution statistics: call count, total microseconds, average microseconds per call.
**Example output:** `cmdstat_get:calls=1000000,usec=500000,usec_per_call=0.50`
**Use:** Identify hot commands, commands with high average latency, and unexpected command usage patterns.

### 122. CONFIG GET (Runtime Configuration)

```bash
redis-cli CONFIG GET maxmemory
redis-cli CONFIG GET maxmemory-policy
redis-cli CONFIG GET timeout
redis-cli CONFIG GET tcp-keepalive
redis-cli CONFIG GET slowlog-log-slower-than
redis-cli CONFIG GET hz
redis-cli CONFIG GET "*"  # All configuration parameters
```
**Use:** Verify runtime configuration matches expected parameter group settings.

### 123. DEBUG SLEEP (Simulating Latency for Testing)

```bash
# NOT recommended for production -- for test environments only
redis-cli DEBUG SLEEP 2
```
**Use:** Simulate a 2-second engine stall to test client timeout behavior and alerting.
**Note:** This command may be disabled in ElastiCache managed environments.

### 124. ACL LIST (View Current ACL Rules)

```bash
redis-cli ACL LIST
```
**Shows:** All ACL users and their permission rules. Verify least-privilege configuration.

### 125. ACL WHOAMI

```bash
redis-cli ACL WHOAMI
```
**Shows:** The current authenticated user. Verify which user your connection is authenticated as.

### 126. ACL LOG (Authentication Failures and Permission Denials)

```bash
redis-cli ACL LOG 10
```
**Shows:** Last 10 ACL-related log entries (failed auth attempts, command denials). Useful for security auditing and debugging permission issues.

### 127. Check ElastiCache Service Updates

```bash
aws elasticache describe-service-updates \
  --query 'ServiceUpdates[?ServiceUpdateStatus==`available`].{Name:ServiceUpdateName,Severity:ServiceUpdateSeverity,Type:ServiceUpdateType,Release:ServiceUpdateReleaseDate,RecommendedApply:ServiceUpdateRecommendedApplyByDate}' \
  --output table
```
**Shows:** Available security patches and engine updates. Apply critical and important updates promptly.

### 128. Check Update Actions for a Cluster

```bash
aws elasticache describe-update-actions \
  --replication-group-ids my-cache \
  --query 'UpdateActions[].{Update:ServiceUpdateName,Status:UpdateActionStatus,Severity:ServiceUpdateSeverity,ApplyDate:ServiceUpdateRecommendedApplyByDate}' \
  --output table
```

### 129. Apply a Service Update

```bash
aws elasticache batch-apply-update-action \
  --replication-group-ids my-cache \
  --service-update-name elc-xxxxxxxx
```

### 130. Describe MemoryDB Service Updates

```bash
aws memorydb describe-service-updates \
  --query 'ServiceUpdates[?Status==`available`].{Name:ServiceUpdateName,Type:Type,Release:ReleaseDate,Description:Description}' \
  --output table
```

---

## ElastiCache Serverless Monitoring

### 131. Get Serverless ECPU Consumption

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/ElastiCache \
  --metric-name ElastiCacheProcessingUnits \
  --dimensions Name=ServerlessCacheName,Value=my-serverless-cache \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum Average
```
**Shows:** ECPU consumption over time. Use for cost optimization and capacity monitoring.

### 132. Get Serverless Data Storage

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/ElastiCache \
  --metric-name BytesUsedForCache \
  --dimensions Name=ServerlessCacheName,Value=my-serverless-cache \
  --start-time $(date -u -d '24 hours ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 3600 \
  --statistics Maximum
```
**Concerning:** Approaching the configured maximum data storage limit (up to 5 TB).

### 133. Get Serverless Throttled Commands

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/ElastiCache \
  --metric-name ThrottledCmds \
  --dimensions Name=ServerlessCacheName,Value=my-serverless-cache \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Sum
```
**Concerning:** Any throttled commands indicate the cache has hit its ECPU limit. Increase the maximum ECPU setting or optimize the workload.

---

## Network and Connectivity Diagnostics

### 134. Test Connectivity to ElastiCache Endpoint

```bash
# Test TCP connectivity
nc -zv my-cache.abc123.ng.0001.use1.cache.amazonaws.com 6379

# Test with timeout
timeout 5 bash -c 'echo > /dev/tcp/my-cache.abc123.ng.0001.use1.cache.amazonaws.com/6379' && echo "Connected" || echo "Connection failed"
```

### 135. Test TLS Connectivity

```bash
openssl s_client -connect my-cache.abc123.ng.0001.use1.cache.amazonaws.com:6379 -servername my-cache.abc123.ng.0001.use1.cache.amazonaws.com
```
**Shows:** TLS certificate chain, protocol version, and cipher suite. Useful for debugging TLS connection failures.

### 136. DNS Resolution Check

```bash
nslookup my-cache.abc123.ng.0001.use1.cache.amazonaws.com
dig my-cache.abc123.ng.0001.use1.cache.amazonaws.com
```
**Shows:** Resolved IP address. After failover, verify the endpoint resolves to the new primary IP.

### 137. Redis PING Test

```bash
redis-cli -h my-cache.abc123.ng.0001.use1.cache.amazonaws.com -p 6379 --tls PING
```
**Expected:** `PONG`. If no response, check security groups, NACLs, and endpoint correctness.

### 138. Measure Round-Trip Latency

```bash
redis-cli -h my-cache.abc123.ng.0001.use1.cache.amazonaws.com -p 6379 --tls --latency
```
**Shows:** Continuous latency measurements (min, max, avg). Run for 60 seconds to get a representative sample.

### 139. Measure Latency Distribution

```bash
redis-cli -h my-cache.abc123.ng.0001.use1.cache.amazonaws.com -p 6379 --tls --latency-dist
```
**Shows:** Color-coded latency distribution histogram. Visual tool for identifying latency spikes.

### 140. Measure Intrinsic Latency (Baseline)

```bash
redis-cli --intrinsic-latency 10
```
**Shows:** The inherent latency of the system (OS + hardware) without Redis overhead. Run on the client machine to establish a baseline. Typical: < 0.1ms.
