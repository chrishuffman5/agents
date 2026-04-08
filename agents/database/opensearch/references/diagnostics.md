# OpenSearch Diagnostics Reference

100+ REST API diagnostic commands organized by category. All commands in curl format with interpretation guidance.

**Base URL assumption:** `localhost:9200` (adjust for your cluster). Add `-u admin:admin` or `-H "Authorization: Bearer ..."` for secured clusters. For HTTPS: add `--insecure` or `--cacert /path/to/root-ca.pem`.

---

## Cluster Health (15 commands)

### 1. Cluster Health Summary
```bash
curl -s localhost:9200/_cluster/health?pretty
```
**Key fields:** `status` (green/yellow/red), `unassigned_shards`, `number_of_pending_tasks`, `active_shards_percent_as_number`.
**Concerning:** `status: red` (missing primary shards, data loss risk), `status: yellow` (missing replicas), `unassigned_shards > 0`.

### 2. Cluster Health Per Index
```bash
curl -s localhost:9200/_cluster/health?level=indices&pretty
```
Shows health broken down per index. Identifies which specific index is red/yellow.

### 3. Cluster Health Per Shard
```bash
curl -s localhost:9200/_cluster/health?level=shards&pretty
```
Shows health per shard, per index. Use to find the exact unassigned or initializing shards.

### 4. Wait for Green Status (with Timeout)
```bash
curl -s localhost:9200/_cluster/health?wait_for_status=green&timeout=60s&pretty
```
Blocks until cluster is green or timeout. Useful in scripts after maintenance.

### 5. Cluster Stats (Comprehensive)
```bash
curl -s localhost:9200/_cluster/stats?pretty
```
**Key fields:** `indices.count`, `indices.shards.total`, `indices.store.size_in_bytes`, `nodes.count.total`, `nodes.jvm.mem.heap_used_in_bytes`.
**Concerning:** High `shards.total` relative to node count. Memory pressure.

### 6. Cluster State Overview
```bash
curl -s localhost:9200/_cluster/state?filter_path=metadata.indices.*.state,metadata.indices.*.settings.index.number_of_shards&pretty
```
Shows index states and shard counts without downloading the full cluster state.

### 7. Cluster State (Routing Table Only)
```bash
curl -s localhost:9200/_cluster/state/routing_table?pretty
```
Shows which shards are on which nodes.

### 8. Cluster Settings (All)
```bash
curl -s localhost:9200/_cluster/settings?include_defaults=true&flat_settings=true&pretty
```
Shows all cluster settings including defaults. Use `flat_settings` for grep-friendly output.

### 9. Cluster Settings (Active Overrides Only)
```bash
curl -s localhost:9200/_cluster/settings?pretty
```
Shows only persistent and transient settings that override defaults.

### 10. Cluster Allocation Explain (Why is a Shard Unassigned?)
```bash
curl -s localhost:9200/_cluster/allocation/explain?pretty
```
Explains why the first unassigned shard cannot be allocated. Essential for troubleshooting yellow/red clusters.

### 11. Cluster Allocation Explain (Specific Shard)
```bash
curl -s localhost:9200/_cluster/allocation/explain -H 'Content-Type: application/json' -d '{
  "index": "my-index",
  "shard": 0,
  "primary": true
}'
```
Explains allocation for a specific shard.

### 12. Pending Cluster Tasks
```bash
curl -s localhost:9200/_cluster/pending_tasks?pretty
```
**Concerning:** Queue of pending tasks > 0 sustained. Indicates cluster manager node is overloaded.

### 13. Cluster Reroute (Dry Run)
```bash
curl -s localhost:9200/_cluster/reroute?dry_run=true&explain=true -H 'Content-Type: application/json' -d '{
  "commands": [
    { "move": { "index": "my-index", "shard": 0, "from_node": "node1", "to_node": "node2" } }
  ]
}'
```
Tests shard move without executing it.

### 14. Cluster Info (Version, Build)
```bash
curl -s localhost:9200/?pretty
```
Shows OpenSearch version, Lucene version, cluster name, cluster UUID.

### 15. Voting Configuration (Cluster Manager Election)
```bash
curl -s localhost:9200/_cluster/state?filter_path=metadata.cluster_coordination.last_committed_config&pretty
```
Shows which nodes participate in cluster manager voting.

---

## Node Information (17 commands)

### 16. All Node Stats
```bash
curl -s localhost:9200/_nodes/stats?pretty
```
Comprehensive statistics for all nodes. Very large response.

### 17. Node Summary Table
```bash
curl -s 'localhost:9200/_cat/nodes?v&h=name,ip,heap.percent,heap.max,ram.percent,cpu,load_1m,load_5m,disk.used_percent,node.role,master'
```
**Concerning:** `heap.percent > 85%`, `cpu > 90%`, `disk.used_percent > 80%`, frequent GC.

### 18. Node Stats (JVM Only)
```bash
curl -s localhost:9200/_nodes/stats/jvm?pretty
```
**Key fields per node:** `jvm.mem.heap_used_percent`, `jvm.gc.collectors.young.collection_count`, `jvm.gc.collectors.young.collection_time_in_millis`, `jvm.gc.collectors.old.collection_count`, `jvm.gc.collectors.old.collection_time_in_millis`.
**Concerning:** `heap_used_percent > 85%`, old GC time > 5 seconds per collection, old GC frequency increasing.

### 19. Node Stats (OS and Process)
```bash
curl -s localhost:9200/_nodes/stats/os,process?pretty
```
**Key fields:** `os.cpu.percent`, `os.mem.free_percent`, `process.open_file_descriptors`, `process.max_file_descriptors`.
**Concerning:** `open_file_descriptors` approaching `max_file_descriptors`, `mem.free_percent < 5%`.

### 20. Node Stats (Filesystem)
```bash
curl -s localhost:9200/_nodes/stats/fs?pretty
```
**Key fields:** `fs.total.total_in_bytes`, `fs.total.free_in_bytes`, `fs.total.available_in_bytes`.
**Concerning:** Available < 15% of total.

### 21. Node Stats (Transport Layer)
```bash
curl -s localhost:9200/_nodes/stats/transport?pretty
```
**Key fields:** `transport.rx_size_in_bytes`, `transport.tx_size_in_bytes`, `transport.server_open`.
**Concerning:** Very high `server_open` count, high throughput between nodes during normal operations.

### 22. Node Stats (HTTP Layer)
```bash
curl -s localhost:9200/_nodes/stats/http?pretty
```
**Key fields:** `http.current_open`, `http.total_opened`.
**Concerning:** `current_open` very high (connection leak), rapid growth of `total_opened` (no keepalive).

### 23. Node Stats (Breakers)
```bash
curl -s localhost:9200/_nodes/stats/breaker?pretty
```
**Key fields per breaker:** `limit_size_in_bytes`, `estimated_size_in_bytes`, `tripped`.
**Concerning:** Any breaker `tripped > 0` (indicates memory pressure or large queries/aggregations).

### 24. Node Stats (Indices)
```bash
curl -s localhost:9200/_nodes/stats/indices?pretty
```
Shows indexing, search, merging, refresh, flush, query cache, fielddata, segments stats per node.

### 25. Node Stats (Indexing)
```bash
curl -s localhost:9200/_nodes/stats/indices/indexing?pretty
```
**Key fields:** `indexing.index_total`, `indexing.index_time_in_millis`, `indexing.index_current`, `indexing.index_failed`.
**Concerning:** `index_failed > 0`, high `index_time_in_millis` per document, `index_current` sustained high.

### 26. Node Stats (Search)
```bash
curl -s localhost:9200/_nodes/stats/indices/search?pretty
```
**Key fields:** `search.query_total`, `search.query_time_in_millis`, `search.query_current`, `search.fetch_total`, `search.fetch_time_in_millis`, `search.scroll_current`, `search.scroll_total`.
**Concerning:** High `query_time_in_millis / query_total` (avg search latency), `scroll_current` high (scroll context leak).

### 27. Node Stats (Merges)
```bash
curl -s localhost:9200/_nodes/stats/indices/merges?pretty
```
**Key fields:** `merges.current`, `merges.total`, `merges.total_time_in_millis`, `merges.total_size_in_bytes`.
**Concerning:** `current` high sustained (merge bottleneck), high `total_time_in_millis`.

### 28. Node Stats (Segments)
```bash
curl -s localhost:9200/_nodes/stats/indices/segments?pretty
```
**Key fields:** `segments.count`, `segments.memory_in_bytes`, `segments.terms_memory_in_bytes`, `segments.stored_fields_memory_in_bytes`, `segments.norms_memory_in_bytes`, `segments.doc_values_memory_in_bytes`.
**Concerning:** `memory_in_bytes` consuming large portion of heap, very high `count` per node.

### 29. Hot Threads (CPU Diagnostics)
```bash
curl -s localhost:9200/_nodes/hot_threads?threads=5&interval=1s&type=cpu
```
Shows the top CPU-consuming threads on each node. Essential for diagnosing high CPU usage.

### 30. Hot Threads (Wait Diagnostics)
```bash
curl -s localhost:9200/_nodes/hot_threads?threads=5&interval=1s&type=wait
```
Shows threads spending time waiting (I/O, locks). Useful for diagnosing slow disk or lock contention.

### 31. Node Info (Settings and Plugins)
```bash
curl -s localhost:9200/_nodes?filter_path=nodes.*.name,nodes.*.roles,nodes.*.os.name,nodes.*.jvm.version,nodes.*.plugins&pretty
```
Shows node names, roles, OS, JVM version, and installed plugins.

### 32. Node Usage Stats
```bash
curl -s localhost:9200/_nodes/usage?pretty
```
Shows REST API endpoint usage counts per node.

---

## Index Information (16 commands)

### 33. All Indices Summary
```bash
curl -s 'localhost:9200/_cat/indices?v&s=store.size:desc&h=health,status,index,pri,rep,docs.count,store.size,pri.store.size'
```
Lists all indices sorted by size. **Concerning:** `health: red`, `status: close`, unexpectedly large indices.

### 34. Index Count
```bash
curl -s 'localhost:9200/_cat/count?v'
```
Total document count across all indices.

### 35. Specific Index Stats
```bash
curl -s localhost:9200/my-index/_stats?pretty
```
Detailed stats for a specific index: indexing, search, merges, refresh, flush, query_cache, fielddata, segments.

### 36. Index Settings
```bash
curl -s localhost:9200/my-index/_settings?pretty
```
Shows all index-level settings (shard count, replicas, refresh interval, ISM policy, etc.).

### 37. Index Mapping
```bash
curl -s localhost:9200/my-index/_mapping?pretty
```
Shows the full mapping definition. Check for unexpected field type changes or mapping explosion.

### 38. Index Field Mapping (Specific Field)
```bash
curl -s localhost:9200/my-index/_mapping/field/field_name?pretty
```
Shows mapping for a specific field.

### 39. Shard Distribution
```bash
curl -s 'localhost:9200/_cat/shards?v&h=index,shard,prirep,state,docs,store,node,unassigned.reason&s=index'
```
Shows where every shard lives. **Concerning:** `state: UNASSIGNED`, `state: RELOCATING` (many = shard storm).

### 40. Shard Distribution (Specific Index)
```bash
curl -s 'localhost:9200/_cat/shards/my-index?v&h=shard,prirep,state,docs,store,node'
```
Shard layout for a specific index.

### 41. Segment Info Per Index
```bash
curl -s 'localhost:9200/_cat/segments/my-index?v&h=shard,segment,generation,docs.count,docs.deleted,size,size.memory,committed,searchable,compound'
```
Shows per-segment details. **Concerning:** Many small segments (need forcemerge on read-only index), high `docs.deleted`.

### 42. Disk Allocation Per Node
```bash
curl -s 'localhost:9200/_cat/allocation?v&h=node,shards,disk.indices,disk.used,disk.avail,disk.total,disk.percent'
```
**Concerning:** `disk.percent > 80%` (approaching low watermark), uneven shard distribution.

### 43. Recovery Progress
```bash
curl -s 'localhost:9200/_cat/recovery?v&active_only=true&h=index,shard,time,type,stage,source_node,target_node,bytes_percent,translog_ops_percent'
```
Shows active shard recoveries. **Concerning:** Many concurrent recoveries (recovery storm), slow progress.

### 44. Index Aliases
```bash
curl -s 'localhost:9200/_cat/aliases?v&s=alias'
```
Lists all aliases and which indices they point to.

### 45. Index Templates
```bash
curl -s localhost:9200/_index_template?pretty
```
Shows all composable index templates.

### 46. Legacy Index Templates
```bash
curl -s localhost:9200/_template?pretty
```
Shows legacy (pre-composable) index templates.

### 47. Data Streams
```bash
curl -s localhost:9200/_data_stream?pretty
```
Shows all data streams and their backing indices.

### 48. Field Caps (Available Fields)
```bash
curl -s localhost:9200/my-index/_field_caps?fields=*&pretty
```
Shows all fields across index/indices with their types. Useful for mapping exploration.

---

## ISM (Index State Management) (10 commands)

### 49. List All ISM Policies
```bash
curl -s localhost:9200/_plugins/_ism/policies?pretty
```
Shows all defined ISM policies.

### 50. Get Specific ISM Policy
```bash
curl -s localhost:9200/_plugins/_ism/policies/my-policy?pretty
```
Shows a specific ISM policy definition.

### 51. Explain ISM State for Index
```bash
curl -s localhost:9200/_plugins/_ism/explain/my-index?pretty
```
**Key fields:** `policy_id`, `state.name`, `action.name`, `action.failed`, `info.message`.
**Concerning:** `action.failed: true`, `retry_info.failed: true`. Shows current state, last executed action, and any errors.

### 52. Explain ISM for All Managed Indices
```bash
curl -s localhost:9200/_plugins/_ism/explain/*?pretty
```
Shows ISM state for all managed indices.

### 53. Retry Failed ISM Action
```bash
curl -s -X POST localhost:9200/_plugins/_ism/retry/my-index -H 'Content-Type: application/json' -d '{
  "state": "warm"
}'
```
Retries a failed ISM action on the specified index.

### 54. Change ISM Policy on Index
```bash
curl -s -X POST localhost:9200/_plugins/_ism/change_policy/my-index -H 'Content-Type: application/json' -d '{
  "policy_id": "new-policy",
  "state": "hot"
}'
```
Changes the ISM policy attached to an index.

### 55. Remove ISM Policy from Index
```bash
curl -s -X POST localhost:9200/_plugins/_ism/remove/my-index
```
Removes the ISM policy from an index.

### 56. Add ISM Policy to Index
```bash
curl -s -X POST localhost:9200/_plugins/_ism/add/my-index -H 'Content-Type: application/json' -d '{
  "policy_id": "my-policy"
}'
```
Attaches an ISM policy to an existing index.

### 57. ISM Job Interval Setting
```bash
curl -s localhost:9200/_cluster/settings?flat_settings=true&pretty | grep -i ism
```
Shows ISM-related cluster settings including the job interval (default 5 minutes).

### 58. Rollover Target Check
```bash
curl -s localhost:9200/my-index/_stats?pretty | grep -E '"docs"|"store"'
```
Check if an index meets rollover conditions (doc count, size, age).

---

## Security Plugin (14 commands)

### 59. Security Plugin Health
```bash
curl -s localhost:9200/_plugins/_security/health?pretty
```
Shows security plugin status and configuration.

### 60. Current User Auth Info
```bash
curl -s localhost:9200/_plugins/_security/authinfo?pretty
```
Shows authentication info for the current user, including roles, backend roles, and tenants.

### 61. List All Roles
```bash
curl -s localhost:9200/_plugins/_security/api/roles?pretty
```
Lists all defined roles with their permissions.

### 62. Get Specific Role
```bash
curl -s localhost:9200/_plugins/_security/api/roles/my-role?pretty
```
Shows a specific role definition including cluster/index permissions, FLS, DLS.

### 63. List All Role Mappings
```bash
curl -s localhost:9200/_plugins/_security/api/rolesmapping?pretty
```
Shows which users, backend roles, and hosts are mapped to each role.

### 64. Get Specific Role Mapping
```bash
curl -s localhost:9200/_plugins/_security/api/rolesmapping/my-role?pretty
```
Shows mapping for a specific role.

### 65. List All Internal Users
```bash
curl -s localhost:9200/_plugins/_security/api/internalusers?pretty
```
Lists all internal user accounts (passwords are hashed).

### 66. List All Action Groups
```bash
curl -s localhost:9200/_plugins/_security/api/actiongroups?pretty
```
Shows all named permission groups.

### 67. List All Tenants
```bash
curl -s localhost:9200/_plugins/_security/api/tenants?pretty
```
Shows all multi-tenancy tenants for OpenSearch Dashboards.

### 68. Audit Log Configuration
```bash
curl -s localhost:9200/_plugins/_security/api/audit?pretty
```
Shows current audit logging configuration.

### 69. Security Configuration
```bash
curl -s localhost:9200/_plugins/_security/api/securityconfig?pretty
```
Shows the full security configuration including authentication backends.

### 70. SSL/TLS Certificate Info
```bash
curl -s localhost:9200/_plugins/_security/api/ssl/certs?pretty
```
Shows currently loaded TLS certificates for transport and HTTP layers.

### 71. Permission Check (Who Am I?)
```bash
curl -s localhost:9200/_plugins/_security/api/account?pretty
```
Shows the current user's account details, roles, and whether they are reserved.

### 72. Cache Flush (Security)
```bash
curl -s -X DELETE localhost:9200/_plugins/_security/api/cache
```
Flushes the security plugin's internal cache. Useful after bulk role/mapping changes.

---

## Anomaly Detection (8 commands)

### 73. List All Detectors
```bash
curl -s localhost:9200/_plugins/_anomaly_detection/detectors/_search -H 'Content-Type: application/json' -d '{
  "query": { "match_all": {} }
}'
```
Lists all anomaly detection detectors.

### 74. Get Specific Detector
```bash
curl -s localhost:9200/_plugins/_anomaly_detection/detectors/<detector_id>?pretty
```
Shows a specific detector's configuration.

### 75. Get Detector Profile (Status)
```bash
curl -s localhost:9200/_plugins/_anomaly_detection/detectors/<detector_id>/_profile?pretty
```
**Key fields:** `state` (RUNNING, DISABLED, INIT), `error`. Shows detector runtime state.

### 76. Get Detector Stats
```bash
curl -s localhost:9200/_plugins/_anomaly_detection/stats?pretty
```
Shows aggregate anomaly detection statistics.

### 77. Get Anomaly Results
```bash
curl -s localhost:9200/_plugins/_anomaly_detection/detectors/<detector_id>/results/_search -H 'Content-Type: application/json' -d '{
  "size": 10,
  "sort": [{ "data_start_time": "desc" }],
  "query": { "range": { "anomaly_grade": { "gt": 0 } } }
}'
```
Shows recent anomaly results for a detector. `anomaly_grade > 0` means anomaly detected.

### 78. Start Detector
```bash
curl -s -X POST localhost:9200/_plugins/_anomaly_detection/detectors/<detector_id>/_start
```
Starts an anomaly detector.

### 79. Stop Detector
```bash
curl -s -X POST localhost:9200/_plugins/_anomaly_detection/detectors/<detector_id>/_stop
```
Stops an anomaly detector.

### 80. Search Anomaly Results Index
```bash
curl -s localhost:9200/.opendistro-anomaly-results*/_search -H 'Content-Type: application/json' -d '{
  "size": 5,
  "sort": [{ "data_start_time": "desc" }],
  "query": { "range": { "anomaly_grade": { "gt": 0.5 } } }
}'
```
Searches across all anomaly result indices for significant anomalies.

---

## Alerting (8 commands)

### 81. List All Monitors
```bash
curl -s localhost:9200/_plugins/_alerting/monitors/_search -H 'Content-Type: application/json' -d '{
  "query": { "match_all": {} }
}'
```
Lists all alerting monitors.

### 82. Get Specific Monitor
```bash
curl -s localhost:9200/_plugins/_alerting/monitors/<monitor_id>?pretty
```
Shows a specific monitor's configuration.

### 83. Get Monitor Alerts (Active)
```bash
curl -s localhost:9200/_plugins/_alerting/monitors/<monitor_id>/alerts?pretty
```
Shows active and acknowledged alerts for a monitor.

### 84. Get All Active Alerts
```bash
curl -s localhost:9200/_plugins/_alerting/monitors/alerts?alertState=ACTIVE&pretty
```
Shows all active alerts across all monitors.

### 85. Acknowledge Alert
```bash
curl -s -X POST localhost:9200/_plugins/_alerting/monitors/<monitor_id>/alerts/_acknowledge -H 'Content-Type: application/json' -d '{
  "alerts": ["<alert_id>"]
}'
```
Acknowledges an alert.

### 86. Execute Monitor (Dry Run)
```bash
curl -s -X POST localhost:9200/_plugins/_alerting/monitors/<monitor_id>/_execute?dryrun=true
```
Executes a monitor without triggering actions. Useful for testing.

### 87. List Notification Channels
```bash
curl -s localhost:9200/_plugins/_notifications/configs -H 'Content-Type: application/json' -d '{
  "query": { "match_all": {} }
}'
```
Lists all notification channels (replaces legacy destinations in 2.0+).

### 88. Get Notification Channel
```bash
curl -s localhost:9200/_plugins/_notifications/configs/<config_id>?pretty
```
Shows a specific notification channel configuration.

---

## k-NN Vector Search (10 commands)

### 89. k-NN Plugin Stats
```bash
curl -s localhost:9200/_plugins/_knn/stats?pretty
```
**Key fields:** `total_load_time`, `graph_memory_usage`, `graph_memory_usage_percentage`, `cache_capacity_reached`, `circuit_breaker_triggered`, `graph_count`.
**Concerning:** `cache_capacity_reached: true`, `circuit_breaker_triggered: true`, high `graph_memory_usage_percentage`.

### 90. k-NN Stats Per Node
```bash
curl -s localhost:9200/_plugins/_knn/node1/stats?pretty
```
Shows k-NN stats for a specific node.

### 91. k-NN Index Stats
```bash
curl -s 'localhost:9200/_cat/indices?v&h=index,health,status,docs.count,store.size&s=index' | grep knn
```
Shows k-NN enabled indices and their sizes.

### 92. k-NN Warmup Index
```bash
curl -s localhost:9200/_plugins/_knn/warmup/my-knn-index?pretty
```
Pre-loads k-NN graphs into memory. Run before production traffic.

### 93. k-NN Model Info
```bash
curl -s localhost:9200/_plugins/_knn/models/<model_id>?pretty
```
Shows trained model info (for IVF algorithms that require training).

### 94. k-NN Search with Profiling
```bash
curl -s localhost:9200/my-knn-index/_search -H 'Content-Type: application/json' -d '{
  "profile": true,
  "size": 10,
  "query": {
    "knn": {
      "my_vector": { "vector": [0.1, 0.2, 0.3], "k": 10 }
    }
  }
}'
```
Profiles a k-NN search to identify latency breakdown.

### 95. k-NN Search with Filter
```bash
curl -s localhost:9200/my-knn-index/_search -H 'Content-Type: application/json' -d '{
  "size": 10,
  "query": {
    "knn": {
      "my_vector": {
        "vector": [0.1, 0.2, 0.3],
        "k": 10,
        "filter": { "term": { "category": "electronics" } }
      }
    }
  }
}'
```
Filtered k-NN search.

### 96. k-NN Index Settings
```bash
curl -s localhost:9200/my-knn-index/_settings?pretty | grep -i knn
```
Shows k-NN specific index settings.

### 97. k-NN Circuit Breaker Settings
```bash
curl -s localhost:9200/_cluster/settings?flat_settings=true&include_defaults=true&pretty | grep knn
```
Shows all k-NN related cluster settings including circuit breaker limits.

### 98. k-NN Clear Cache
```bash
curl -s -X POST localhost:9200/_plugins/_knn/clear_cache/my-knn-index
```
Clears k-NN graphs from memory cache for a specific index.

---

## Performance and Thread Pools (12 commands)

### 99. Thread Pool Summary
```bash
curl -s 'localhost:9200/_cat/thread_pool?v&h=node_name,name,active,queue,rejected,completed,type,size&s=rejected:desc'
```
**Concerning:** `rejected > 0` for `search`, `write`, or `bulk` pools. Indicates thread pool exhaustion.

### 100. Thread Pool (Write)
```bash
curl -s 'localhost:9200/_cat/thread_pool/write?v&h=node_name,active,queue,rejected,completed'
```
Shows write thread pool status. `rejected > 0` means bulk/index requests are being rejected.

### 101. Thread Pool (Search)
```bash
curl -s 'localhost:9200/_cat/thread_pool/search?v&h=node_name,active,queue,rejected,completed'
```
Shows search thread pool status.

### 102. Thread Pool (Force Merge)
```bash
curl -s 'localhost:9200/_cat/thread_pool/force_merge?v&h=node_name,active,queue,rejected,completed'
```
Shows force merge thread pool status.

### 103. Task List (Running Tasks)
```bash
curl -s localhost:9200/_tasks?pretty
```
Shows all currently running tasks.

### 104. Long-Running Tasks
```bash
curl -s 'localhost:9200/_tasks?actions=*search*&detailed=true&pretty'
```
Shows running search tasks with details. Filter by action type.

### 105. Cancel Task
```bash
curl -s -X POST localhost:9200/_tasks/<task_id>/_cancel
```
Cancels a specific running task.

### 106. Pending Tasks
```bash
curl -s localhost:9200/_cluster/pending_tasks?pretty
```
Shows tasks waiting for cluster manager to process. High counts indicate cluster manager bottleneck.

### 107. Node-Level Search Stats
```bash
curl -s localhost:9200/_nodes/stats/indices/search?pretty
```
Per-node search statistics for identifying hot spots.

### 108. Fielddata Stats
```bash
curl -s localhost:9200/_nodes/stats/indices/fielddata?fields=*&pretty
```
**Concerning:** High fielddata memory. Indicates `text` field being used for aggregations/sorting without proper `keyword` mapping.

### 109. Query Cache Stats
```bash
curl -s localhost:9200/_nodes/stats/indices/query_cache?pretty
```
Shows filter/query cache hit rates per node.

### 110. Request Cache Stats
```bash
curl -s localhost:9200/_nodes/stats/indices/request_cache?pretty
```
Shows shard-level request cache statistics.

---

## Snapshot and Restore (8 commands)

### 111. List Snapshot Repositories
```bash
curl -s localhost:9200/_snapshot?pretty
```
Shows all registered snapshot repositories.

### 112. Verify Repository
```bash
curl -s -X POST localhost:9200/_snapshot/my-repo/_verify?pretty
```
Verifies connectivity and permissions for a snapshot repository.

### 113. List Snapshots in Repository
```bash
curl -s localhost:9200/_snapshot/my-repo/_all?pretty
```
Lists all snapshots in a repository.

### 114. Snapshot Status (Running)
```bash
curl -s localhost:9200/_snapshot/_status?pretty
```
Shows progress of currently running snapshots.

### 115. Specific Snapshot Details
```bash
curl -s localhost:9200/_snapshot/my-repo/my-snapshot?pretty
```
Shows details of a specific snapshot (indices, shards, state, start/end time).

### 116. Snapshot Shard Status
```bash
curl -s localhost:9200/_snapshot/my-repo/my-snapshot/_status?pretty
```
Shows per-shard snapshot progress.

### 117. Delete Snapshot
```bash
curl -s -X DELETE localhost:9200/_snapshot/my-repo/my-snapshot?pretty
```
Deletes a snapshot. Frees storage in the repository.

### 118. Restore Snapshot (Dry Check)
```bash
curl -s localhost:9200/_snapshot/my-repo/my-snapshot?pretty | grep -E '"indices"|"state"'
```
Quick check of snapshot contents and state before restore.

---

## Cross-Cluster Replication and Search (8 commands)

### 119. Remote Cluster Info
```bash
curl -s localhost:9200/_remote/info?pretty
```
Shows configured remote clusters and their connection status.

### 120. Replication Status (All)
```bash
curl -s localhost:9200/_plugins/_replication/follower_stats?pretty
```
Shows replication status for all follower indices.

### 121. Replication Status (Specific Index)
```bash
curl -s localhost:9200/_plugins/_replication/my-follower-index/_status?pretty
```
Shows replication status for a specific follower index.

### 122. Pause Replication
```bash
curl -s -X POST localhost:9200/_plugins/_replication/my-follower-index/_pause -H 'Content-Type: application/json' -d '{}'
```
Pauses replication for a follower index.

### 123. Resume Replication
```bash
curl -s -X POST localhost:9200/_plugins/_replication/my-follower-index/_resume -H 'Content-Type: application/json' -d '{}'
```
Resumes paused replication.

### 124. Stop Replication
```bash
curl -s -X POST localhost:9200/_plugins/_replication/my-follower-index/_stop -H 'Content-Type: application/json' -d '{}'
```
Stops replication and promotes follower to a standalone index.

### 125. Auto-Follow Rules
```bash
curl -s localhost:9200/_plugins/_replication/_autofollow?pretty
```
Shows auto-follow patterns for automatic replication of new indices.

### 126. Cross-Cluster Search Test
```bash
curl -s localhost:9200/cluster-b:remote-index/_search -H 'Content-Type: application/json' -d '{
  "query": { "match_all": {} },
  "size": 1
}'
```
Tests cross-cluster search connectivity and returns one document.

---

## ML Commons (8 commands)

### 127. List Deployed Models
```bash
curl -s localhost:9200/_plugins/_ml/models/_search -H 'Content-Type: application/json' -d '{
  "query": { "match_all": {} },
  "size": 100
}'
```
Lists all registered ML models.

### 128. Get Model Profile
```bash
curl -s localhost:9200/_plugins/_ml/profile/models/<model_id>?pretty
```
Shows model deployment status across nodes.

### 129. ML Stats
```bash
curl -s localhost:9200/_plugins/_ml/stats?pretty
```
Shows ML plugin statistics including model count, request count.

### 130. Get Model Group
```bash
curl -s localhost:9200/_plugins/_ml/model_groups/_search -H 'Content-Type: application/json' -d '{
  "query": { "match_all": {} }
}'
```
Lists all model groups.

### 131. Get Connectors
```bash
curl -s localhost:9200/_plugins/_ml/connectors/_search -H 'Content-Type: application/json' -d '{
  "query": { "match_all": {} }
}'
```
Lists all ML connectors (for remote model integrations).

### 132. Undeploy Model
```bash
curl -s -X POST localhost:9200/_plugins/_ml/models/<model_id>/_undeploy
```
Undeploys a model from all nodes to free resources.

### 133. ML Task Status
```bash
curl -s localhost:9200/_plugins/_ml/tasks/<task_id>?pretty
```
Shows status of an ML task (model registration, deployment, etc.).

### 134. Test Model Inference
```bash
curl -s localhost:9200/_plugins/_ml/models/<model_id>/_predict -H 'Content-Type: application/json' -d '{
  "text_docs": ["test input for embedding"]
}'
```
Runs inference on a deployed model to verify it works.

---

## Observability and PPL (6 commands)

### 135. PPL Query
```bash
curl -s localhost:9200/_plugins/_ppl -H 'Content-Type: application/json' -d '{
  "query": "source=logs-* | where level='\''ERROR'\'' | stats count() by service | sort -count()"
}'
```
Executes a PPL query.

### 136. SQL Query
```bash
curl -s localhost:9200/_plugins/_sql -H 'Content-Type: application/json' -d '{
  "query": "SELECT service, COUNT(*) as error_count FROM logs-* WHERE level = '\''ERROR'\'' GROUP BY service ORDER BY error_count DESC LIMIT 10"
}'
```
Executes a SQL query.

### 137. SQL Explain
```bash
curl -s localhost:9200/_plugins/_sql/_explain -H 'Content-Type: application/json' -d '{
  "query": "SELECT * FROM logs-* WHERE level = '\''ERROR'\'' LIMIT 10"
}'
```
Shows how a SQL query is translated to OpenSearch DSL.

### 138. List Data Sources
```bash
curl -s localhost:9200/_plugins/_query/_datasources?pretty
```
Shows configured external data sources (e.g., Prometheus, S3).

### 139. Trace Analytics Dashboard
```bash
curl -s localhost:9200/otel-v1-apm-span-*/_search -H 'Content-Type: application/json' -d '{
  "size": 0,
  "aggs": {
    "services": {
      "terms": { "field": "serviceName", "size": 50 },
      "aggs": {
        "avg_duration": { "avg": { "field": "durationInNanos" } },
        "error_count": {
          "filter": { "term": { "status.code": 2 } }
        }
      }
    }
  }
}'
```
Shows service-level trace metrics.

### 140. Service Map Data
```bash
curl -s localhost:9200/otel-v1-apm-service-map*/_search -H 'Content-Type: application/json' -d '{
  "size": 100,
  "query": { "match_all": {} }
}'
```
Shows service dependency map data.

---

## Search Pipelines (4 commands)

### 141. List All Search Pipelines
```bash
curl -s localhost:9200/_search/pipeline?pretty
```
Shows all registered search pipelines.

### 142. Get Specific Search Pipeline
```bash
curl -s localhost:9200/_search/pipeline/my-pipeline?pretty
```
Shows a specific search pipeline definition.

### 143. Search with Pipeline (Inline)
```bash
curl -s localhost:9200/my-index/_search?search_pipeline=my-pipeline -H 'Content-Type: application/json' -d '{
  "query": { "match": { "title": "search query" } }
}'
```
Executes a search with an applied pipeline.

### 144. Delete Search Pipeline
```bash
curl -s -X DELETE localhost:9200/_search/pipeline/my-pipeline
```
Deletes a search pipeline.

---

## Ingest Pipelines (4 commands)

### 145. List All Ingest Pipelines
```bash
curl -s localhost:9200/_ingest/pipeline?pretty
```
Shows all registered ingest pipelines.

### 146. Get Specific Ingest Pipeline
```bash
curl -s localhost:9200/_ingest/pipeline/my-pipeline?pretty
```
Shows a specific ingest pipeline definition.

### 147. Simulate Ingest Pipeline
```bash
curl -s localhost:9200/_ingest/pipeline/my-pipeline/_simulate -H 'Content-Type: application/json' -d '{
  "docs": [
    { "_source": { "message": "192.168.1.1 - - [07/Apr/2026:12:00:00 +0000] \"GET /api/health HTTP/1.1\" 200 52" } }
  ]
}'
```
Tests a pipeline against sample documents without indexing.

### 148. Ingest Pipeline Stats
```bash
curl -s localhost:9200/_nodes/stats/ingest?pretty
```
Shows per-pipeline and per-processor statistics (count, time, failures).

---

## Troubleshooting Playbooks

### Playbook: Red Cluster

1. **Identify the problem:**
   ```bash
   curl -s localhost:9200/_cluster/health?pretty
   curl -s localhost:9200/_cluster/health?level=indices&pretty | grep red
   ```

2. **Find unassigned primary shards:**
   ```bash
   curl -s 'localhost:9200/_cat/shards?v&h=index,shard,prirep,state,unassigned.reason' | grep UNASSIGNED | grep ' p '
   ```

3. **Get allocation explanation:**
   ```bash
   curl -s localhost:9200/_cluster/allocation/explain?pretty
   ```

4. **Common causes and fixes:**
   - **Node failure:** Wait for node recovery or force-allocate stale shard
   - **Disk full:** Free disk space, adjust watermarks
   - **Corrupt shard:** Allocate stale shard (accepts data loss):
     ```bash
     curl -s -X POST localhost:9200/_cluster/reroute -H 'Content-Type: application/json' -d '{
       "commands": [{ "allocate_stale_primary": { "index": "my-index", "shard": 0, "node": "node1", "accept_data_loss": true } }]
     }'
     ```

### Playbook: High JVM Heap Pressure

1. **Check heap usage:**
   ```bash
   curl -s 'localhost:9200/_cat/nodes?v&h=name,heap.percent,heap.max,ram.percent,cpu'
   ```

2. **Check circuit breakers:**
   ```bash
   curl -s localhost:9200/_nodes/stats/breaker?pretty
   ```

3. **Check segment memory:**
   ```bash
   curl -s localhost:9200/_nodes/stats/indices/segments?pretty
   ```

4. **Check fielddata:**
   ```bash
   curl -s localhost:9200/_nodes/stats/indices/fielddata?fields=*&pretty
   ```

5. **Common fixes:**
   - Force merge old indices: `POST /old-index/_forcemerge?max_num_segments=1`
   - Clear fielddata cache: `POST /_cache/clear?fielddata=true`
   - Reduce number of shards (shrink indices)
   - Increase heap (up to 31GB max)

### Playbook: Slow Search

1. **Enable slow log:**
   ```bash
   curl -s -X PUT localhost:9200/my-index/_settings -H 'Content-Type: application/json' -d '{
     "index.search.slowlog.threshold.query.warn": "5s",
     "index.search.slowlog.threshold.query.info": "2s"
   }'
   ```

2. **Profile the query:**
   ```bash
   curl -s localhost:9200/my-index/_search -H 'Content-Type: application/json' -d '{
     "profile": true,
     "query": { "match": { "field": "value" } }
   }'
   ```

3. **Check hot threads:**
   ```bash
   curl -s localhost:9200/_nodes/hot_threads?threads=5
   ```

4. **Check search thread pool rejections:**
   ```bash
   curl -s 'localhost:9200/_cat/thread_pool/search?v&h=node_name,active,queue,rejected'
   ```

5. **Common fixes:**
   - Add filter context for non-scoring clauses
   - Use `search_after` instead of deep `from`/`size` pagination
   - Reduce shard count (fewer shards = fewer merge phases)
   - Use `_source` filtering to reduce fetch sizes
   - Increase replicas for read-heavy workloads

### Playbook: Indexing Rejections

1. **Check write thread pool:**
   ```bash
   curl -s 'localhost:9200/_cat/thread_pool/write?v&h=node_name,active,queue,rejected'
   ```

2. **Check indexing stats:**
   ```bash
   curl -s localhost:9200/_nodes/stats/indices/indexing?pretty
   ```

3. **Check merge pressure:**
   ```bash
   curl -s localhost:9200/_nodes/stats/indices/merges?pretty
   ```

4. **Common fixes:**
   - Reduce bulk request size (aim for 5-15MB)
   - Increase `index.refresh_interval` to reduce segment creation
   - Increase `index.translog.flush_threshold_size`
   - Reduce replica count during bulk loading
   - Add more data nodes
