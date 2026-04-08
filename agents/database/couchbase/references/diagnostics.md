# Couchbase Diagnostics Reference

## couchbase-cli Commands

### Cluster Information

```bash
# List all nodes in the cluster with status and services
couchbase-cli server-list -c localhost:8091 -u Administrator -p password
# Output: ns_1@10.0.0.1 10.0.0.1:8091 healthy active  kv,n1ql,index
#         ns_1@10.0.0.2 10.0.0.2:8091 healthy active  kv
#         ns_1@10.0.0.3 10.0.0.3:8091 healthy active  kv,fts

# List all hosts in the cluster
couchbase-cli host-list -c localhost:8091 -u Administrator -p password

# Get detailed server info for local node
couchbase-cli server-info -c localhost:8091 -u Administrator -p password
# Shows: version, OS, uptime, memory totals, CPU count, cluster membership

# View current cluster settings
couchbase-cli setting-cluster -c localhost:8091 -u Administrator -p password --get
# Shows: data RAM quota, index RAM quota, FTS RAM quota, analytics RAM quota, cluster name

# Modify cluster RAM quotas
couchbase-cli setting-cluster -c localhost:8091 -u Administrator -p password \
  --cluster-ramsize 8192 \
  --cluster-index-ramsize 2048 \
  --cluster-fts-ramsize 1024 \
  --cluster-eventing-ramsize 512 \
  --cluster-analytics-ramsize 2048

# Check rebalance status
couchbase-cli rebalance-status -c localhost:8091 -u Administrator -p password
# Output: (u'running', 52.1234) or (u'none', 0)
```

### Bucket Management

```bash
# List all buckets with basic info
couchbase-cli bucket-list -c localhost:8091 -u Administrator -p password
# Output per bucket: name, type, RAM quota, replicas, auth type

# Get detailed info for a specific bucket
couchbase-cli bucket-list -c localhost:8091 -u Administrator -p password --bucket travel-sample
# Shows: bucket type, storage engine, RAM quota, replica count, eviction policy

# Create a new bucket
couchbase-cli bucket-create -c localhost:8091 -u Administrator -p password \
  --bucket my-bucket \
  --bucket-type couchbase \
  --bucket-ramsize 1024 \
  --bucket-replica 2 \
  --bucket-eviction-policy valueOnly \
  --storage-backend magma \
  --max-ttl 0 \
  --compression-mode passive \
  --conflict-resolution sequence \
  --enable-flush 0

# Edit bucket settings (RAM quota, replicas, etc.)
couchbase-cli bucket-edit -c localhost:8091 -u Administrator -p password \
  --bucket my-bucket \
  --bucket-ramsize 2048 \
  --bucket-replica 2

# Compact a bucket (trigger manual compaction)
couchbase-cli bucket-compact -c localhost:8091 -u Administrator -p password \
  --bucket my-bucket

# Flush a bucket (delete all data -- DESTRUCTIVE)
couchbase-cli bucket-flush -c localhost:8091 -u Administrator -p password \
  --bucket my-bucket --force

# Delete a bucket (DESTRUCTIVE)
couchbase-cli bucket-delete -c localhost:8091 -u Administrator -p password \
  --bucket my-bucket
```

### Node and Service Management

```bash
# Initialize a new node
couchbase-cli node-init -c localhost:8091 -u Administrator -p password \
  --node-init-data-path /opt/couchbase/var/lib/couchbase/data \
  --node-init-index-path /opt/couchbase/var/lib/couchbase/data \
  --node-init-analytics-path /opt/couchbase/var/lib/couchbase/data

# Add a server to the cluster
couchbase-cli server-add -c localhost:8091 -u Administrator -p password \
  --server-add 10.0.0.4:8091 \
  --server-add-username Administrator \
  --server-add-password password \
  --services data,index,query

# Rebalance the cluster
couchbase-cli rebalance -c localhost:8091 -u Administrator -p password

# Rebalance with node removal
couchbase-cli rebalance -c localhost:8091 -u Administrator -p password \
  --server-remove 10.0.0.4:8091

# Stop a running rebalance
couchbase-cli rebalance-stop -c localhost:8091 -u Administrator -p password

# Graceful failover
couchbase-cli failover -c localhost:8091 -u Administrator -p password \
  --server-failover 10.0.0.4:8091

# Hard failover
couchbase-cli failover -c localhost:8091 -u Administrator -p password \
  --server-failover 10.0.0.4:8091 --force

# Recover a failed-over node (delta recovery)
couchbase-cli recovery -c localhost:8091 -u Administrator -p password \
  --server-recovery 10.0.0.4:8091 --recovery-type delta

# Recover with full recovery
couchbase-cli recovery -c localhost:8091 -u Administrator -p password \
  --server-recovery 10.0.0.4:8091 --recovery-type full
```

### Auto-Failover Settings

```bash
# Get current auto-failover settings
couchbase-cli setting-autofailover -c localhost:8091 -u Administrator -p password --get

# Enable auto-failover with 30-second timeout
couchbase-cli setting-autofailover -c localhost:8091 -u Administrator -p password \
  --enable-auto-failover 1 \
  --auto-failover-timeout 30 \
  --max-failovers 2 \
  --enable-failover-of-server-groups 0 \
  --failover-on-data-disk-issues 1 \
  --failover-data-disk-period 120
```

### XDCR Management

```bash
# Create a remote cluster reference
couchbase-cli xdcr-setup -c localhost:8091 -u Administrator -p password \
  --create --xdcr-cluster-name remote-dc \
  --xdcr-hostname 10.1.0.1:8091 \
  --xdcr-username Administrator \
  --xdcr-password password \
  --xdcr-demand-encryption 1 \
  --xdcr-certificate /path/to/remote-cert.pem

# List remote cluster references
couchbase-cli xdcr-setup -c localhost:8091 -u Administrator -p password --list

# Delete a remote cluster reference
couchbase-cli xdcr-setup -c localhost:8091 -u Administrator -p password \
  --delete --xdcr-cluster-name remote-dc

# Create an XDCR replication
couchbase-cli xdcr-replicate -c localhost:8091 -u Administrator -p password \
  --create \
  --xdcr-cluster-name remote-dc \
  --xdcr-from-bucket source-bucket \
  --xdcr-to-bucket target-bucket \
  --filter-expression "^user::" \
  --xdcr-replication-mode xmem \
  --enable-compression 1

# List active replications
couchbase-cli xdcr-replicate -c localhost:8091 -u Administrator -p password --list

# Pause a replication
couchbase-cli xdcr-replicate -c localhost:8091 -u Administrator -p password \
  --pause --xdcr-replicator <replication_id>

# Resume a replication
couchbase-cli xdcr-replicate -c localhost:8091 -u Administrator -p password \
  --resume --xdcr-replicator <replication_id>

# Delete a replication
couchbase-cli xdcr-replicate -c localhost:8091 -u Administrator -p password \
  --delete --xdcr-replicator <replication_id>
```

### Security and User Management

```bash
# List all users
couchbase-cli user-manage -c localhost:8091 -u Administrator -p password --list

# Create a local user with specific roles
couchbase-cli user-manage -c localhost:8091 -u Administrator -p password \
  --set --rbac-username appuser --rbac-password apppass123 \
  --rbac-name "Application User" \
  --roles "bucket_full_access[travel-sample],query_select[travel-sample]" \
  --auth-domain local

# Delete a user
couchbase-cli user-manage -c localhost:8091 -u Administrator -p password \
  --delete --rbac-username appuser --auth-domain local

# View available roles
couchbase-cli user-manage -c localhost:8091 -u Administrator -p password --my-roles

# Manage server groups
couchbase-cli group-manage -c localhost:8091 -u Administrator -p password --list

# Create a server group
couchbase-cli group-manage -c localhost:8091 -u Administrator -p password \
  --create --group-name "Rack-A"

# Configure audit settings
couchbase-cli setting-audit -c localhost:8091 -u Administrator -p password \
  --set-audit-enabled 1 \
  --audit-log-path /opt/couchbase/var/lib/couchbase/logs \
  --audit-log-rotate-interval 86400

# Configure LDAP
couchbase-cli setting-ldap -c localhost:8091 -u Administrator -p password \
  --hosts ldap.example.com \
  --port 389 \
  --encryption TLS \
  --bind-dn "cn=admin,dc=example,dc=com" \
  --bind-password ldap_password \
  --authentication-enabled 1

# Manage SSL certificates
couchbase-cli ssl-manage -c localhost:8091 -u Administrator -p password \
  --cluster-cert-info

# Regenerate internal certificates
couchbase-cli ssl-manage -c localhost:8091 -u Administrator -p password \
  --regenerate-cert /tmp/newcert.pem

# Configure security settings
couchbase-cli setting-security -c localhost:8091 -u Administrator -p password \
  --set --tls-min-version tlsv1.2 --cluster-encryption-level all

# Configure password policy
couchbase-cli setting-password-policy -c localhost:8091 -u Administrator -p password \
  --set --min-length 8 --uppercase 1 --lowercase 1 --digit 1 --special-char 1
```

### Index and Query Settings

```bash
# View current index settings
couchbase-cli setting-index -c localhost:8091 -u Administrator -p password --get

# Change index storage mode
couchbase-cli setting-index -c localhost:8091 -u Administrator -p password \
  --index-storage-setting plasma

# View current query settings
couchbase-cli setting-query -c localhost:8091 -u Administrator -p password --get

# Set query timeout
couchbase-cli setting-query -c localhost:8091 -u Administrator -p password \
  --set --query-timeout 300
```

### Compaction Settings

```bash
# View current compaction settings
couchbase-cli setting-compaction -c localhost:8091 -u Administrator -p password --get

# Set auto-compaction thresholds
couchbase-cli setting-compaction -c localhost:8091 -u Administrator -p password \
  --compaction-db-percentage 30 \
  --compaction-view-percentage 30 \
  --compaction-period-from 02:00 \
  --compaction-period-to 06:00 \
  --enable-compaction-abort 1 \
  --enable-compaction-parallel 0
```

### Log Collection

```bash
# Start log collection
couchbase-cli collect-logs-start -c localhost:8091 -u Administrator -p password \
  --all-nodes --output-directory /tmp/logs

# Check log collection status
couchbase-cli collect-logs-status -c localhost:8091 -u Administrator -p password

# Stop log collection
couchbase-cli collect-logs-stop -c localhost:8091 -u Administrator -p password
```

### Eventing Management

```bash
# List all eventing functions
couchbase-cli eventing-function-setup -c localhost:8091 -u Administrator -p password --list

# Export an eventing function
couchbase-cli eventing-function-setup -c localhost:8091 -u Administrator -p password \
  --export --name my_function

# Import an eventing function
couchbase-cli eventing-function-setup -c localhost:8091 -u Administrator -p password \
  --import --file /path/to/function.json
```

### Collection Management

```bash
# List scopes and collections for a bucket
couchbase-cli collection-manage -c localhost:8091 -u Administrator -p password \
  --bucket my-bucket --list-scopes

couchbase-cli collection-manage -c localhost:8091 -u Administrator -p password \
  --bucket my-bucket --list-collections inventory

# Create a scope
couchbase-cli collection-manage -c localhost:8091 -u Administrator -p password \
  --bucket my-bucket --create-scope my_scope

# Create a collection
couchbase-cli collection-manage -c localhost:8091 -u Administrator -p password \
  --bucket my-bucket --create-collection my_scope.my_collection --max-ttl 86400

# Drop a collection
couchbase-cli collection-manage -c localhost:8091 -u Administrator -p password \
  --bucket my-bucket --drop-collection my_scope.my_collection

# Drop a scope
couchbase-cli collection-manage -c localhost:8091 -u Administrator -p password \
  --bucket my-bucket --drop-scope my_scope
```

## cbstats Commands

cbstats provides Data Service statistics for a specific node. Connect via port 11210.

### Overall Statistics

```bash
# All statistics for a bucket
cbstats localhost:11210 all -u Administrator -p password -b travel-sample
# Returns hundreds of stats: ep_mem_used, ep_bg_fetched, cmd_get, cmd_set, etc.

# Key memory statistics
cbstats localhost:11210 all -u Administrator -p password -b travel-sample | grep -E "^ep_mem|^ep_kv|^mem_used|^ep_overhead"
# ep_mem_used: total memory used by bucket
# ep_kv_size: memory used by document values
# ep_overhead: metadata overhead
# ep_mem_high_wat: high water mark for eviction
# ep_mem_low_wat: low water mark for eviction
```

### Memory Statistics

```bash
# Detailed memory stats
cbstats localhost:11210 memory -u Administrator -p password -b travel-sample
# Shows: mem_used, ep_kv_size, ep_blob_num, ep_storedval_size, etc.

# Memory allocator statistics
cbstats localhost:11210 allocator -u Administrator -p password -b travel-sample
# Shows: je_malloc statistics, arena info, fragmentation

# Check if eviction is occurring
cbstats localhost:11210 all -u Administrator -p password -b travel-sample | grep -E "ep_num_value_ejects|ep_num_non_resident"
# ep_num_value_ejects: number of items ejected from RAM
# ep_num_non_resident: items not in RAM (resident ratio = 1 - non_resident/total)
```

### vBucket Statistics

```bash
# vBucket state summary
cbstats localhost:11210 vbucket -u Administrator -p password -b travel-sample
# Shows state (active/replica/pending/dead) for each vBucket

# Detailed vBucket statistics
cbstats localhost:11210 vbucket-details -u Administrator -p password -b travel-sample
# Per-vBucket: num_items, high_seqno, disk_size, data_size, etc.

# vBucket sequence numbers (useful for DCP/replication monitoring)
cbstats localhost:11210 vbucket-seqno -u Administrator -p password -b travel-sample
# Shows high_seqno per vBucket -- useful for tracking replication progress
```

### DCP Statistics

```bash
# DCP connection statistics
cbstats localhost:11210 dcp -u Administrator -p password -b travel-sample
# Shows all DCP connections: producers, consumers, their status and throughput

# DCP aggregated stats
cbstats localhost:11210 dcp -u Administrator -p password -b travel-sample | grep -E "^ep_dcp"
# ep_dcp_views+indexes_backoff: DCP backpressure events for indexing
# ep_dcp_replica_backoff: DCP backpressure for replication
# ep_dcp_xdcr_backoff: DCP backpressure for XDCR
# ep_dcp_other_items_remaining: items remaining to be sent
```

### Disk and Persistence Statistics

```bash
# Disk info
cbstats localhost:11210 diskinfo -u Administrator -p password -b travel-sample
# Shows: data file size, couch_docs_fragmentation, couch_docs_actual_disk_size

# Disk queue (pending writes to disk)
cbstats localhost:11210 all -u Administrator -p password -b travel-sample | grep -E "ep_queue_size|ep_flusher|ep_diskqueue"
# ep_queue_size: items waiting to be flushed to disk
# ep_flusher_state: running or paused
# ep_diskqueue_items: total items in disk queue
# ep_diskqueue_drain: rate of disk queue drain

# Persistence statistics
cbstats localhost:11210 all -u Administrator -p password -b travel-sample | grep -E "ep_total_persisted|ep_commit_time|ep_io_total"
# ep_total_persisted: total items persisted since start
# ep_commit_time: time for last commit in microseconds
```

### Timing Histograms

```bash
# Operation timing histograms
cbstats localhost:11210 timings -u Administrator -p password -b travel-sample
# Shows latency distribution for get, set, delete, bg_fetch operations
# Look for: get_cmd, set_cmd, delete_cmd, bg_wait, bg_load, disk_commit

# Specific timing: background fetches (disk reads for cache misses)
cbstats localhost:11210 timings -u Administrator -p password -b travel-sample | grep -A 20 "bg_wait"
```

### Workload Statistics

```bash
# Current thread utilization
cbstats localhost:11210 workload -u Administrator -p password -b travel-sample
# Shows: reader threads, writer threads, auxIO threads, nonIO threads
# And their active/waiting status

# Hash table statistics (managed cache internals)
cbstats localhost:11210 hash -u Administrator -p password -b travel-sample
# Shows: hash table size, number of locks, items per lock, etc.
```

### Collection Statistics

```bash
# Collection statistics
cbstats localhost:11210 collections -u Administrator -p password -b travel-sample
# Shows: item count, disk size, ops per collection

# Collection details for a specific scope/collection
cbstats localhost:11210 collections-details -u Administrator -p password -b travel-sample
```

### Checkpoint Statistics

```bash
# Checkpoint statistics (DCP checkpointing)
cbstats localhost:11210 checkpoint -u Administrator -p password -b travel-sample
# Shows per-vBucket: num_checkpoints, num_items_for_persistence, open_checkpoint_id
```

### Runtime Configuration

```bash
# View current runtime configuration
cbstats localhost:11210 runtimes -u Administrator -p password -b travel-sample

# View active configuration
cbstats localhost:11210 config -u Administrator -p password -b travel-sample
```

## REST API Diagnostics

### Cluster Information

```bash
# Full cluster overview
curl -s -u Administrator:password http://localhost:8091/pools/default | python3 -m json.tool
# Returns: nodes, buckets, RAM/disk totals, rebalance status

# Terse cluster info
curl -s -u Administrator:password http://localhost:8091/pools/default/terseClusterInfo

# Node list with services
curl -s -u Administrator:password http://localhost:8091/pools/default | \
  python3 -c "import sys,json; d=json.load(sys.stdin); [print(n['hostname'],n['services'],n['status']) for n in d['nodes']]"

# Cluster tasks (rebalance progress, compaction, XDCR)
curl -s -u Administrator:password http://localhost:8091/pools/default/tasks | python3 -m json.tool

# Check if rebalance is running
curl -s -u Administrator:password http://localhost:8091/pools/default/rebalanceProgress
# Returns {"status":"none"} or detailed progress per node

# Pending rebalance retry (after failed rebalance)
curl -s -u Administrator:password http://localhost:8091/pools/default/pendingRetryRebalance

# Node services detail
curl -s -u Administrator:password http://localhost:8091/pools/default/nodeServices

# Internal settings (advanced tuning)
curl -s -u Administrator:password http://localhost:8091/internalSettings | python3 -m json.tool
```

### Bucket Diagnostics

```bash
# List all buckets with stats
curl -s -u Administrator:password http://localhost:8091/pools/default/buckets | python3 -m json.tool

# Specific bucket details
curl -s -u Administrator:password http://localhost:8091/pools/default/buckets/travel-sample | python3 -m json.tool
# Includes: RAM quota, item count, disk used, ops/sec, storage engine, eviction policy

# Bucket stats (recent metrics)
curl -s -u Administrator:password http://localhost:8091/pools/default/buckets/travel-sample/stats
# Returns time-series data for: ops, cmd_get, cmd_set, disk_write_queue, ep_cache_miss_rate, etc.

# Specific stat range (Prometheus-compatible)
curl -s -u Administrator:password \
  "http://localhost:8091/pools/default/stats/range/kv_ops?bucket=travel-sample&start=-1h&step=60"

# Bucket node-level stats
curl -s -u Administrator:password \
  "http://localhost:8091/pools/default/buckets/travel-sample/nodes/ns_1@10.0.0.1/stats"
```

### Index Service Diagnostics

```bash
# Index service settings
curl -s -u Administrator:password http://localhost:9102/settings | python3 -m json.tool
# Shows: storage mode, memory quota, log level, num_replica

# Index statistics (all indexes)
curl -s -u Administrator:password http://localhost:9102/api/v1/stats | python3 -m json.tool
# Per-index: items_count, data_size, disk_size, num_docs_pending, scan_rate, etc.

# Index statistics for a specific keyspace
curl -s -u Administrator:password \
  "http://localhost:9102/api/v1/stats/travel-sample.inventory.hotel" | python3 -m json.tool

# Index storage stats
curl -s -u Administrator:password http://localhost:9102/api/v1/stats | \
  python3 -c "import sys,json; d=json.load(sys.stdin); \
  [print(k,v.get('data_size','?'),v.get('items_count','?')) for k,v in d.items() if isinstance(v,dict)]"
```

### Search Service (FTS) Diagnostics

```bash
# FTS service configuration
curl -s -u Administrator:password http://localhost:8094/api/cfg | python3 -m json.tool

# FTS stats (global)
curl -s -u Administrator:password http://localhost:8094/api/stats | python3 -m json.tool
# Includes: num_mutations_to_index, total_queries, total_request_time, etc.

# List all FTS indexes
curl -s -u Administrator:password http://localhost:8094/api/bucket/travel-sample/scope/inventory/index | python3 -m json.tool

# FTS index details
curl -s -u Administrator:password \
  "http://localhost:8094/api/bucket/travel-sample/scope/inventory/index/hotel-search" | python3 -m json.tool

# FTS index stats (specific index)
curl -s -u Administrator:password \
  "http://localhost:8094/api/nsstats" | python3 -m json.tool

# FTS partition info
curl -s -u Administrator:password http://localhost:8094/api/pindex | python3 -m json.tool

# Run an FTS query via REST
curl -s -u Administrator:password -X POST \
  http://localhost:8094/api/bucket/travel-sample/scope/inventory/index/hotel-search/query \
  -H "Content-Type: application/json" \
  -d '{"query":{"match":"pool","field":"description"},"size":5}'

# FTS diagnostics
curl -s -u Administrator:password http://localhost:8094/api/diag | python3 -m json.tool

# FTS runtime info
curl -s -u Administrator:password http://localhost:8094/api/runtime | python3 -m json.tool
```

### Query Service Diagnostics

```bash
# Query service vitals
curl -s -u Administrator:password http://localhost:8093/admin/vitals | python3 -m json.tool
# Shows: uptime, version, request.per.sec, request.active, cores, gc.percent, memory

# Query service settings
curl -s -u Administrator:password http://localhost:8093/admin/settings | python3 -m json.tool
# Shows: query timeout, max parallelism, pipeline batch, scan cap, etc.

# Active requests (currently running queries)
curl -s -u Administrator:password http://localhost:8093/admin/active_requests | python3 -m json.tool
# Shows: statement, request ID, elapsed time, phase, node

# Completed requests (recent query history)
curl -s -u Administrator:password http://localhost:8093/admin/completed_requests | python3 -m json.tool
# Shows: statement, elapsed time, result count, service time, errors

# Prepared statements cache
curl -s -u Administrator:password http://localhost:8093/admin/prepareds | python3 -m json.tool

# Query service statistics
curl -s -u Administrator:password http://localhost:8093/admin/stats | python3 -m json.tool
# Shows: selects, mutations, errors, warnings, request_time, service_time

# Ping query service
curl -s -u Administrator:password http://localhost:8093/admin/ping

# Configure query settings
curl -s -u Administrator:password -X POST http://localhost:8093/admin/settings \
  -d '{"completed-threshold":"1000ms","completed-limit":10000}'

# Clear completed requests log
curl -s -u Administrator:password -X DELETE http://localhost:8093/admin/completed_requests

# Cluster-wide query settings
curl -s -u Administrator:password http://localhost:8091/settings/querySettings | python3 -m json.tool

# Query cURL whitelist
curl -s -u Administrator:password http://localhost:8091/settings/querySettings/curlWhitelist | python3 -m json.tool
```

### Analytics Service Diagnostics

```bash
# Analytics cluster status
curl -s -u Administrator:password http://localhost:8095/analytics/cluster | python3 -m json.tool

# Analytics service configuration
curl -s -u Administrator:password http://localhost:8095/analytics/config/service | python3 -m json.tool

# Active analytics requests
curl -s -u Administrator:password http://localhost:8095/analytics/admin/active_requests | python3 -m json.tool

# Analytics settings
curl -s -u Administrator:password http://localhost:8091/settings/analytics | python3 -m json.tool

# Run an analytics query via REST
curl -s -u Administrator:password -X POST http://localhost:8095/analytics/service \
  -H "Content-Type: application/json" \
  -d '{"statement":"SELECT COUNT(*) FROM `travel-sample`.inventory.hotel"}'
```

### Eventing Service Diagnostics

```bash
# List all eventing functions
curl -s -u Administrator:password http://localhost:8096/api/v1/functions | python3 -m json.tool

# Eventing status (deployed functions)
curl -s -u Administrator:password http://localhost:8096/api/v1/status | python3 -m json.tool
# Shows: app name, deployment status, num_deployed_nodes, processing stats

# Specific function status
curl -s -u Administrator:password http://localhost:8096/api/v1/functions/my_function | python3 -m json.tool

# Eventing statistics
curl -s -u Administrator:password http://localhost:8096/api/v1/stats | python3 -m json.tool
# Per function: on_update_success, on_delete_success, timer_create_success, failures, etc.

# Deploy an eventing function
curl -s -u Administrator:password -X POST \
  http://localhost:8096/api/v1/functions/my_function/deploy

# Undeploy an eventing function
curl -s -u Administrator:password -X POST \
  http://localhost:8096/api/v1/functions/my_function/undeploy

# Pause an eventing function
curl -s -u Administrator:password -X POST \
  http://localhost:8096/api/v1/functions/my_function/pause

# Resume an eventing function
curl -s -u Administrator:password -X POST \
  http://localhost:8096/api/v1/functions/my_function/resume
```

### XDCR Diagnostics

```bash
# List remote cluster references
curl -s -u Administrator:password http://localhost:8091/pools/default/remoteClusters | python3 -m json.tool

# List all XDCR replications
curl -s -u Administrator:password http://localhost:8091/pools/default/tasks | \
  python3 -c "import sys,json; tasks=json.load(sys.stdin); \
  [print(t['id'],t.get('source',''),t.get('target',''),t.get('status','')) for t in tasks if t['type']=='xdcr']"

# XDCR replication settings
curl -s -u Administrator:password \
  "http://localhost:8091/settings/replications/<replication_id>" | python3 -m json.tool

# XDCR global settings
curl -s -u Administrator:password http://localhost:8091/settings/replications | python3 -m json.tool

# Create XDCR replication via REST
curl -s -u Administrator:password -X POST http://localhost:8091/controller/createReplication \
  -d fromBucket=source-bucket \
  -d toCluster=remote-dc \
  -d toBucket=target-bucket \
  -d replicationType=continuous \
  -d compressionType=Auto

# Modify XDCR replication settings
curl -s -u Administrator:password -X POST \
  "http://localhost:8091/settings/replications/<replication_id>" \
  -d sourceNozzlePerNode=4 \
  -d targetNozzlePerNode=4 \
  -d optimisticReplicationThreshold=512

# Delete an XDCR replication
curl -s -u Administrator:password -X DELETE \
  "http://localhost:8091/controller/cancelXDCR/<url_encoded_replication_id>"
```

### Backup Service Diagnostics

```bash
# Backup service cluster info
curl -s -u Administrator:password http://localhost:8097/api/v1/cluster/self | python3 -m json.tool

# Backup service configuration
curl -s -u Administrator:password http://localhost:8097/api/v1/config | python3 -m json.tool

# List backup repositories (active)
curl -s -u Administrator:password http://localhost:8097/api/v1/cluster/self/repository/active | python3 -m json.tool

# List backup plans
curl -s -u Administrator:password http://localhost:8097/api/v1/cluster/plan | python3 -m json.tool

# Backup threads map
curl -s -u Administrator:password http://localhost:8097/api/v1/nodesThreadsMap | python3 -m json.tool
```

### Security Diagnostics

```bash
# Check current user identity
curl -s -u Administrator:password http://localhost:8091/whoami | python3 -m json.tool

# List all RBAC roles
curl -s -u Administrator:password http://localhost:8091/settings/rbac/roles | python3 -m json.tool

# List all local users
curl -s -u Administrator:password http://localhost:8091/settings/rbac/users/local | python3 -m json.tool

# List all external users (LDAP)
curl -s -u Administrator:password http://localhost:8091/settings/rbac/users/external | python3 -m json.tool

# List all groups
curl -s -u Administrator:password http://localhost:8091/settings/rbac/groups | python3 -m json.tool

# Check permissions for current user
curl -s -u Administrator:password -X POST http://localhost:8091/pools/default/checkPermissions \
  -d 'cluster.bucket[travel-sample].data!read'

# View audit settings
curl -s -u Administrator:password http://localhost:8091/settings/audit | python3 -m json.tool

# View security settings
curl -s -u Administrator:password http://localhost:8091/settings/security | python3 -m json.tool

# View cluster certificates
curl -s -u Administrator:password http://localhost:8091/pools/default/certificates | python3 -m json.tool

# View LDAP settings
curl -s -u Administrator:password http://localhost:8091/settings/ldap | python3 -m json.tool

# View password policy
curl -s -u Administrator:password http://localhost:8091/settings/passwordPolicy | python3 -m json.tool
```

### Auto-Compaction Diagnostics

```bash
# Get auto-compaction settings
curl -s -u Administrator:password http://localhost:8091/settings/autoCompaction | python3 -m json.tool

# Set auto-compaction settings
curl -s -u Administrator:password -X POST http://localhost:8091/controller/setAutoCompaction \
  -d databaseFragmentationThreshold[percentage]=30 \
  -d viewFragmentationThreshold[percentage]=30 \
  -d parallelDBAndViewCompaction=false

# Trigger manual compaction on a bucket
curl -s -u Administrator:password -X POST \
  "http://localhost:8091/pools/default/buckets/travel-sample/controller/compactBucket"

# Cancel running compaction
curl -s -u Administrator:password -X POST \
  "http://localhost:8091/pools/default/buckets/travel-sample/controller/cancelBucketCompaction"
```

## N1QL / SQL++ Diagnostic Queries

### System Catalog Queries

```sql
-- List all indexes in the cluster
SELECT * FROM system:indexes;

-- List indexes for a specific collection
SELECT idx.name, idx.index_key, idx.condition, idx.state, idx.using
FROM system:indexes idx
WHERE idx.keyspace_id = "hotel"
  AND idx.scope_id = "inventory"
  AND idx.bucket_id = "travel-sample";

-- Index status and statistics
SELECT name, state, is_primary, index_key, condition,
       IFMISSING(partition, "none") AS partition
FROM system:indexes
WHERE state != "online"
ORDER BY bucket_id, name;

-- Check for deferred indexes (not yet built)
SELECT name, bucket_id, scope_id, keyspace_id, state
FROM system:indexes
WHERE state = "deferred";

-- Active running queries
SELECT *, META().id AS request_id
FROM system:active_requests
WHERE state = "running"
ORDER BY elapsedTime DESC;

-- Recently completed queries (slow query log)
SELECT statement, elapsedTime, resultCount, errorCount, node
FROM system:completed_requests
ORDER BY elapsedTime DESC
LIMIT 20;

-- System keyspaces available
SELECT * FROM system:keyspaces;

-- System datastores
SELECT * FROM system:datastores;

-- Namespace/bucket info
SELECT * FROM system:buckets;

-- Scope info (7.0+)
SELECT * FROM system:scopes;

-- Collection info (7.0+)
SELECT * FROM system:keyspaces
WHERE `namespace` = "default" AND `bucket` = "travel-sample";

-- Query service nodes
SELECT * FROM system:nodes;

-- Prepareds (cached prepared statements)
SELECT name, statement, uses
FROM system:prepareds
ORDER BY uses DESC
LIMIT 20;

-- Functions (UDFs)
SELECT * FROM system:functions;

-- System vitals
SELECT * FROM system:vitals;

-- User info (8.0+)
SELECT * FROM system:user_info;

-- Group info (8.0+)
SELECT * FROM system:group_info;

-- Bucket info (8.0+)
SELECT * FROM system:bucket_info;

-- Transactions in progress
SELECT * FROM system:transactions;
```

### Query Performance Analysis

```sql
-- EXPLAIN a query to see execution plan
EXPLAIN SELECT h.name FROM `travel-sample`.inventory.hotel h
WHERE h.city = "San Francisco" AND h.vacancy = true;

-- EXPLAIN with execution profile
EXPLAIN SELECT h.name FROM `travel-sample`.inventory.hotel h
WHERE h.city = "San Francisco";

-- Index advisor for a single query
ADVISE SELECT h.name FROM `travel-sample`.inventory.hotel h
WHERE h.city = "San Francisco" AND h.vacancy = true;

-- Index advisor for multiple queries (workload)
SELECT ADVISOR([
    "SELECT name FROM `travel-sample`.inventory.hotel WHERE city = $1",
    "SELECT * FROM `travel-sample`.inventory.airline WHERE country = $1",
    "SELECT r.airline FROM `travel-sample`.inventory.route r WHERE r.sourceairport = $1"
]);

-- Update statistics for cost-based optimizer
UPDATE STATISTICS FOR `travel-sample`.inventory.hotel(city, country, avg_rating);

-- Update all index statistics
UPDATE STATISTICS FOR `travel-sample`.inventory.hotel INDEX ALL;

-- Delete statistics
UPDATE STATISTICS FOR `travel-sample`.inventory.hotel DELETE ALL;

-- Find queries causing full primary scans
SELECT statement, elapsedTime, phaseTimes
FROM system:completed_requests
WHERE phaseTimes LIKE "%primaryScan%"
ORDER BY elapsedTime DESC
LIMIT 10;

-- Find slow queries (> 1 second)
SELECT statement, elapsedTime, resultCount, node
FROM system:completed_requests
WHERE STR_TO_DURATION(elapsedTime) > 1000000000
ORDER BY elapsedTime DESC
LIMIT 20;

-- Query throughput by node
SELECT node, COUNT(*) AS query_count,
       AVG(STR_TO_DURATION(elapsedTime)) / 1000000 AS avg_ms,
       MAX(STR_TO_DURATION(elapsedTime)) / 1000000 AS max_ms
FROM system:completed_requests
GROUP BY node;
```

### Index Health Checks

```sql
-- Indexes not in "online" state
SELECT name, state, bucket_id, scope_id, keyspace_id
FROM system:indexes
WHERE state != "online";

-- Primary indexes (should be dropped in production)
SELECT name, bucket_id, scope_id, keyspace_id
FROM system:indexes
WHERE is_primary = true;

-- Duplicate indexes (same keys, same collection)
SELECT i1.name AS idx1, i2.name AS idx2,
       i1.bucket_id, i1.scope_id, i1.keyspace_id,
       i1.index_key
FROM system:indexes i1
JOIN system:indexes i2
  ON i1.bucket_id = i2.bucket_id
  AND i1.scope_id = i2.scope_id
  AND i1.keyspace_id = i2.keyspace_id
  AND i1.index_key = i2.index_key
  AND i1.name < i2.name;

-- Covering index verification
EXPLAIN SELECT city, name FROM `travel-sample`.inventory.hotel
WHERE city = "Paris";
-- If plan shows "covers" array, the index is covering (no Fetch needed)
```

## cbcollect_info

cbcollect_info gathers comprehensive diagnostic data for support tickets:

```bash
# Collect full diagnostics (generates a zip file)
/opt/couchbase/bin/cbcollect_info /tmp/cb_collect_$(date +%Y%m%d_%H%M%S).zip

# Collect with specific node
/opt/couchbase/bin/cbcollect_info /tmp/cb_collect.zip --multi-node-diag

# Collect with upload to Couchbase support
/opt/couchbase/bin/cbcollect_info /tmp/cb_collect.zip \
  --upload --upload-host https://s3.amazonaws.com/cb-customers \
  --customer "COMPANY_NAME" --ticket 12345
```

Contents of cbcollect_info zip:
- `ns_server.stats.log` -- Cluster stats over time
- `ns_server.couchdb.log` -- View engine logs
- `ns_server.babysitter.log` -- Process supervisor logs
- `ns_server.debug.log` -- Detailed debug log
- `memcached.log` -- Data service (memcached/ep-engine) logs
- `indexer.log` -- Index service logs
- `query.log` -- Query service logs
- `fts.log` -- Search service logs
- `analytics.log` -- Analytics service logs
- `eventing.log` -- Eventing service logs
- `xdcr.log` / `goxdcr.log` -- XDCR replication logs
- System info: `syslog`, `dmesg`, `top`, `vmstat`, disk usage, network config

## Log Analysis Patterns

### Log File Locations

```bash
# Default log directory
/opt/couchbase/var/lib/couchbase/logs/

# Key log files
ls -la /opt/couchbase/var/lib/couchbase/logs/
# debug.log           -- Cluster manager debug log
# info.log            -- Cluster manager info
# error.log           -- Errors across services
# babysitter.log      -- Process supervisor
# couchdb.log         -- View engine
# memcached.log.000000.txt  -- Data service
# indexer.log          -- Index service
# query.log            -- Query service
# fts.log              -- Search service
# eventing.log         -- Eventing service
# analytics.log        -- Analytics service
# goxdcr.log           -- XDCR logs
# audit.log            -- Audit events (JSON format)
# rebalance/           -- Rebalance reports (per rebalance)
# http_access.log      -- REST API access log
```

### Common Log Patterns to Search

```bash
# OOM (Out of Memory) events
grep -i "out of memory\|oom\|hard_out_of_memory" /opt/couchbase/var/lib/couchbase/logs/memcached.log*

# Warmup progress
grep -i "warmup\|warm up" /opt/couchbase/var/lib/couchbase/logs/memcached.log* | tail -20

# Rebalance failures
grep -i "rebalance.*fail\|rebalance.*error" /opt/couchbase/var/lib/couchbase/logs/debug.log

# Auto-failover events
grep -i "auto_failover\|failover" /opt/couchbase/var/lib/couchbase/logs/info.log

# XDCR errors
grep -i "error\|fail\|timeout" /opt/couchbase/var/lib/couchbase/logs/goxdcr.log | tail -50

# Index build failures
grep -i "error\|fail\|panic" /opt/couchbase/var/lib/couchbase/logs/indexer.log | tail -50

# Query errors
grep -i "error\|timeout\|panic" /opt/couchbase/var/lib/couchbase/logs/query.log | tail -50

# Disk space warnings
grep -i "disk\|space\|quota" /opt/couchbase/var/lib/couchbase/logs/error.log

# TLS/SSL errors
grep -i "tls\|ssl\|certificate\|handshake" /opt/couchbase/var/lib/couchbase/logs/debug.log | tail -30

# Audit log analysis (JSON format)
python3 -c "
import json, sys
for line in open('/opt/couchbase/var/lib/couchbase/logs/audit.log'):
    try:
        event = json.loads(line)
        if event.get('id') in [8192, 8193, 8194]:  # login events
            print(event['timestamp'], event.get('real_userid',{}).get('user','?'), event.get('remote',{}).get('ip','?'))
    except: pass
"
```

## Troubleshooting Playbooks

### High Latency / Slow Queries

```bash
# 1. Check active queries
curl -s -u Administrator:password http://localhost:8093/admin/active_requests | python3 -m json.tool

# 2. Check completed queries for slow ones
curl -s -u Administrator:password http://localhost:8093/admin/completed_requests | \
  python3 -c "import sys,json; reqs=json.load(sys.stdin); \
  [print(r.get('elapsedTime',''),r.get('statement','')[:100]) for r in sorted(reqs, key=lambda x: x.get('elapsedTime',''), reverse=True)[:10]]"

# 3. Check for cache misses (high bg_fetched = data not in RAM)
cbstats localhost:11210 all -u Administrator -p password -b <bucket> | grep ep_bg_fetched

# 4. Check resident ratio
cbstats localhost:11210 all -u Administrator -p password -b <bucket> | grep ep_resident_items_rate
# Should be > 90% for low-latency workloads with Couchstore

# 5. Check disk queue (persistence backlog)
cbstats localhost:11210 all -u Administrator -p password -b <bucket> | grep ep_queue_size

# 6. EXPLAIN the slow query to check index usage
# Look for PrimaryScan (bad), IntersectScan (needs composite index), or no covering
```

### Memory Pressure / OOM

```bash
# 1. Check bucket memory usage vs quota
curl -s -u Administrator:password http://localhost:8091/pools/default/buckets | \
  python3 -c "import sys,json; bs=json.load(sys.stdin); \
  [print(b['name'], 'used:', b['basicStats']['memUsed']//1024//1024, 'MB', 'quota:', b['quota']['ram']//1024//1024, 'MB') for b in bs]"

# 2. Check eviction stats
cbstats localhost:11210 all -u Administrator -p password -b <bucket> | grep -E "ep_num_value_ejects|ep_num_non_resident"

# 3. Check metadata overhead
cbstats localhost:11210 memory -u Administrator -p password -b <bucket>

# 4. Check if working set fits in RAM
cbstats localhost:11210 all -u Administrator -p password -b <bucket> | grep -E "ep_bg_fetched|ep_resident"

# 5. Check per-node memory distribution
curl -s -u Administrator:password http://localhost:8091/pools/default | \
  python3 -c "import sys,json; d=json.load(sys.stdin); \
  [print(n['hostname'], 'memUsed:', n.get('memoryTotal',0)//1024//1024, 'MB', 'memFree:', n.get('memoryFree',0)//1024//1024, 'MB') for n in d['nodes']]"
```

### XDCR Replication Lag

```bash
# 1. Check replication status and lag
curl -s -u Administrator:password http://localhost:8091/pools/default/tasks | \
  python3 -c "import sys,json; tasks=json.load(sys.stdin); \
  [print('src:', t.get('source',''), 'changes_left:', t.get('changesLeft',0), 'docs_checked:', t.get('docsChecked',0), 'errors:', t.get('errors',[])) for t in tasks if t.get('type')=='xdcr']"

# 2. Check XDCR DCP backoff (backpressure)
cbstats localhost:11210 dcp -u Administrator -p password -b <bucket> | grep xdcr

# 3. Check network throughput between clusters
# Use iperf or similar tool

# 4. Adjust nozzle counts for higher throughput
curl -s -u Administrator:password -X POST \
  "http://localhost:8091/settings/replications/<repl_id>" \
  -d sourceNozzlePerNode=8 -d targetNozzlePerNode=8

# 5. Check if compression is enabled
curl -s -u Administrator:password \
  "http://localhost:8091/settings/replications/<repl_id>" | python3 -c "import sys,json; print(json.load(sys.stdin).get('compressionType'))"
```

### Rebalance Failure

```bash
# 1. Check rebalance status
couchbase-cli rebalance-status -c localhost:8091 -u Administrator -p password

# 2. Check rebalance report
curl -s -u Administrator:password http://localhost:8091/logs/rebalanceReport | python3 -m json.tool

# 3. Check for failed nodes
curl -s -u Administrator:password http://localhost:8091/pools/default | \
  python3 -c "import sys,json; d=json.load(sys.stdin); \
  [print(n['hostname'], n['status'], n.get('clusterMembership','')) for n in d['nodes']]"

# 4. Check disk space on all nodes
curl -s -u Administrator:password http://localhost:8091/pools/default | \
  python3 -c "import sys,json; d=json.load(sys.stdin); \
  [print(n['hostname'], 'storageFree:', sum(s.get('free',0) for s in n.get('storage',{}).get('hdd',[]))//1024//1024//1024, 'GB') for n in d['nodes']]"

# 5. Check cluster tasks for errors
curl -s -u Administrator:password http://localhost:8091/pools/default/tasks | python3 -m json.tool

# 6. Retry rebalance
couchbase-cli rebalance -c localhost:8091 -u Administrator -p password
```

### Index Issues

```bash
# 1. Check index status
curl -s -u Administrator:password http://localhost:9102/api/v1/stats | \
  python3 -c "import sys,json; d=json.load(sys.stdin); \
  [print(k, 'items:', v.get('items_count',0), 'pending:', v.get('num_docs_pending',0), 'state:', v.get('index_state','')) for k,v in d.items() if isinstance(v,dict) and 'items_count' in v]"

# 2. Check for indexes stuck in building state
cbstats localhost:11210 all -u Administrator -p password -b <bucket> | grep -i "index\|scan"

# 3. Check index memory usage
curl -s -u Administrator:password http://localhost:9102/api/v1/stats | \
  python3 -c "import sys,json; d=json.load(sys.stdin); \
  [print(k, 'memory:', v.get('data_size',0)//1024//1024, 'MB', 'disk:', v.get('disk_size',0)//1024//1024, 'MB') for k,v in d.items() if isinstance(v,dict) and 'data_size' in v]"

# 4. Check indexer log for errors
grep -i "error\|fail\|panic" /opt/couchbase/var/lib/couchbase/logs/indexer.log | tail -30
```

### Disk Space Issues

```bash
# 1. Check disk usage per bucket
cbstats localhost:11210 diskinfo -u Administrator -p password -b <bucket>

# 2. Check compaction status
curl -s -u Administrator:password http://localhost:8091/pools/default/tasks | \
  python3 -c "import sys,json; tasks=json.load(sys.stdin); \
  [print(t['type'], t.get('bucket',''), t.get('progress',0)) for t in tasks if 'compact' in t.get('type','').lower()]"

# 3. Trigger manual compaction
curl -s -u Administrator:password -X POST \
  "http://localhost:8091/pools/default/buckets/<bucket>/controller/compactBucket"

# 4. Check Couchstore fragmentation
cbstats localhost:11210 all -u Administrator -p password -b <bucket> | grep -i frag
# couch_docs_fragmentation: percentage of wasted space

# 5. Check data directory disk usage
du -sh /opt/couchbase/var/lib/couchbase/data/*
```
