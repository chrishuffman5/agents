# Elasticsearch Diagnostics Reference

100+ REST API diagnostic commands organized by category. All commands in curl format with interpretation guidance.

**Base URL assumption:** `localhost:9200` (adjust for your cluster). Add `-u user:password` or `-H "Authorization: ApiKey ..."` for secured clusters.

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
**Concerning:** Queue of pending tasks > 0 sustained. Indicates master node is overloaded or cluster state updates are bottlenecked.

### 13. Cluster Reroute (Dry Run)
```bash
curl -s localhost:9200/_cluster/reroute?dry_run=true&explain=true -H 'Content-Type: application/json' -d '{
  "commands": [
    { "move": { "index": "my-index", "shard": 0, "from_node": "node1", "to_node": "node2" } }
  ]
}'
```
Tests shard move without executing it. Shows allocation decision explanations.

### 14. Cluster Info (Version, Build, Lucene)
```bash
curl -s localhost:9200/?pretty
```
Shows Elasticsearch version, Lucene version, cluster name, cluster UUID.

### 15. Voting Configuration (Master Election)
```bash
curl -s localhost:9200/_cluster/state?filter_path=metadata.cluster_coordination.last_committed_config&pretty
```
Shows which nodes participate in master voting.

---

## Node Information (17 commands)

### 16. All Node Stats
```bash
curl -s localhost:9200/_nodes/stats?pretty
```
Comprehensive statistics for all nodes. Very large response.

### 17. Node Summary Table
```bash
curl -s localhost:9200/_cat/nodes?v&h=name,ip,heap.percent,heap.max,ram.percent,cpu,load_1m,load_5m,disk.used_percent,node.role,master
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
**Concerning:** `current` high sustained (merge bottleneck, consider merge throttle), high `total_time_in_millis`.

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
Shows the top CPU-consuming threads on each node. Essential for diagnosing high CPU usage. Check for runaway search queries, aggressive merges, or GC threads.

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
Shows REST API endpoint usage counts per node. Helps understand workload patterns.

---

## Index Information (16 commands)

### 33. All Indices Summary
```bash
curl -s localhost:9200/_cat/indices?v&s=store.size:desc&h=health,status,index,pri,rep,docs.count,store.size,pri.store.size
```
Lists all indices sorted by size. **Concerning:** `health: red`, `status: close`, unexpectedly large indices.

### 34. Index Count
```bash
curl -s localhost:9200/_cat/count?v
```
Total document count across all indices.

### 35. Specific Index Stats
```bash
curl -s localhost:9200/my-index/_stats?pretty
```
Detailed stats for a specific index: indexing, search, merges, refresh, flush, warmer, query_cache, fielddata, segments.

### 36. Index Settings
```bash
curl -s localhost:9200/my-index/_settings?pretty
```
Shows all index-level settings (shard count, replicas, refresh interval, ILM policy, etc.).

### 37. Index Mapping
```bash
curl -s localhost:9200/my-index/_mapping?pretty
```
Shows the full mapping definition. Check for unexpected field type changes or mapping explosion.

### 38. Index Field Mapping (Specific Field)
```bash
curl -s localhost:9200/my-index/_mapping/field/field_name?pretty
```
Shows mapping for a specific field across all types.

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
Shows per-segment details. **Concerning:** Many small segments (need forcemerge on read-only index), high `docs.deleted` (deletions not yet merged away).

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
curl -s localhost:9200/_cat/aliases?v&s=alias
```
Shows all aliases and which indices they point to.

### 45. Data Streams
```bash
curl -s localhost:9200/_data_stream?pretty
```
Lists all data streams, their backing indices, and template info.

### 46. Index Field Usage Stats
```bash
curl -s localhost:9200/my-index/_field_usage_stats?pretty
```
Shows which fields are actually queried, aggregated, sorted, or scripted. Helps identify unused fields.

### 47. Index Disk Usage (Analyze API)
```bash
curl -s localhost:9200/my-index/_disk_usage?run_expensive_tasks=true&pretty
```
Shows disk usage broken down by field. Identifies fields consuming the most storage.

### 48. Indices Sorted by Document Count
```bash
curl -s 'localhost:9200/_cat/indices?v&s=docs.count:desc&h=index,docs.count,store.size'
```

---

## Thread Pool Analysis (5 commands)

### 49. Thread Pool Summary
```bash
curl -s 'localhost:9200/_cat/thread_pool?v&h=node_name,name,active,queue,rejected,completed&s=rejected:desc'
```
**Concerning:** Any `rejected > 0` on `write`, `search`, or `get` pools indicates the cluster cannot keep up with the workload.

### 50. Write Thread Pool (Indexing Rejections)
```bash
curl -s 'localhost:9200/_cat/thread_pool/write?v&h=node_name,active,queue,rejected,completed'
```
**Concerning:** `rejected > 0` means bulk/index requests are being dropped. Client must retry with backoff.

### 51. Search Thread Pool
```bash
curl -s 'localhost:9200/_cat/thread_pool/search?v&h=node_name,active,queue,rejected,completed'
```
**Concerning:** `rejected > 0` means search requests are being dropped. Reduce concurrent searches or add nodes.

### 52. All Thread Pool Stats (Detailed)
```bash
curl -s localhost:9200/_nodes/stats/thread_pool?pretty
```
Detailed thread pool stats including queue sizes and rejection counts per node.

### 53. Thread Pool Configuration
```bash
curl -s localhost:9200/_nodes?filter_path=nodes.*.thread_pool&pretty
```
Shows configured sizes and queue capacities for each thread pool.

---

## Query Performance (12 commands)

### 54. Search Profile (Query Execution Breakdown)
```bash
curl -s localhost:9200/my-index/_search -H 'Content-Type: application/json' -d '{
  "profile": true,
  "query": {
    "match": { "message": "error timeout" }
  }
}'
```
Returns detailed timing for each query component (rewrite, build_scorer, advance, match, etc.) on each shard.

### 55. Explain API (Scoring Breakdown)
```bash
curl -s localhost:9200/my-index/_explain/doc-id -H 'Content-Type: application/json' -d '{
  "query": {
    "match": { "title": "elasticsearch guide" }
  }
}'
```
Explains why a specific document matched/did not match and how the score was calculated.

### 56. Validate Query (Syntax Check)
```bash
curl -s localhost:9200/my-index/_validate/query?explain=true -H 'Content-Type: application/json' -d '{
  "query": {
    "match": { "title": "test" }
  }
}'
```
Validates query syntax without executing. With `explain=true`, shows the Lucene query.

### 57. Slow Log Configuration (Search)
```bash
curl -X PUT localhost:9200/my-index/_settings -H 'Content-Type: application/json' -d '{
  "index.search.slowlog.threshold.query.warn": "10s",
  "index.search.slowlog.threshold.query.info": "5s",
  "index.search.slowlog.threshold.query.debug": "2s",
  "index.search.slowlog.threshold.query.trace": "500ms",
  "index.search.slowlog.threshold.fetch.warn": "1s",
  "index.search.slowlog.threshold.fetch.info": "500ms",
  "index.search.slowlog.level": "info"
}'
```
Logs slow queries to the slow log file. Check `/var/log/elasticsearch/*_index_search_slowlog.json`.

### 58. Slow Log Configuration (Indexing)
```bash
curl -X PUT localhost:9200/my-index/_settings -H 'Content-Type: application/json' -d '{
  "index.indexing.slowlog.threshold.index.warn": "10s",
  "index.indexing.slowlog.threshold.index.info": "5s",
  "index.indexing.slowlog.threshold.index.debug": "2s",
  "index.indexing.slowlog.threshold.index.trace": "500ms",
  "index.indexing.slowlog.level": "info",
  "index.indexing.slowlog.source": "1000"
}'
```
Logs slow indexing operations. `source: 1000` includes the first 1000 chars of the document.

### 59. Analyze API (Test Analyzer)
```bash
curl -s localhost:9200/my-index/_analyze -H 'Content-Type: application/json' -d '{
  "analyzer": "standard",
  "text": "The quick Brown Fox jumped-over the lazy dog!"
}'
```
Shows how text is tokenized by an analyzer. Essential for debugging search relevance issues.

### 60. Analyze API (Custom Analysis Chain)
```bash
curl -s localhost:9200/_analyze -H 'Content-Type: application/json' -d '{
  "tokenizer": "standard",
  "filter": ["lowercase", "stop", "snowball"],
  "text": "Running quickly through the Elasticsearch documentation"
}'
```

### 61. Analyze API (Field-Specific)
```bash
curl -s localhost:9200/my-index/_analyze -H 'Content-Type: application/json' -d '{
  "field": "title",
  "text": "Elasticsearch Performance Tuning Guide"
}'
```
Shows how a specific field's configured analyzer processes text.

### 62. Term Vectors (Per-Document Field Analysis)
```bash
curl -s localhost:9200/my-index/_termvectors/doc-id?fields=title,body&pretty
```
Shows term frequency, document frequency, positions, and offsets for each term in a document's field.

### 63. Search Shard Routing
```bash
curl -s localhost:9200/my-index/_search_shards?pretty
```
Shows which shards will be searched for a given index or routing value.

### 64. Multi-Search (Batch Queries)
```bash
curl -s localhost:9200/_msearch -H 'Content-Type: application/x-ndjson' -d '
{"index": "logs-*"}
{"query": {"match": {"level": "error"}}, "size": 0}
{"index": "metrics-*"}
{"query": {"range": {"@timestamp": {"gte": "now-1h"}}}, "size": 0}
'
```

### 65. Count API (Fast Document Count)
```bash
curl -s localhost:9200/my-index/_count -H 'Content-Type: application/json' -d '{
  "query": {
    "range": { "@timestamp": { "gte": "now-24h" } }
  }
}'
```

---

## Memory and JVM (8 commands)

### 66. JVM Memory Per Node
```bash
curl -s localhost:9200/_nodes/stats/jvm?filter_path=nodes.*.name,nodes.*.jvm.mem&pretty
```
**Key fields:** `heap_used_in_bytes`, `heap_max_in_bytes`, `heap_used_percent`, `non_heap_used_in_bytes`.
**Concerning:** `heap_used_percent > 85%` sustained.

### 67. GC Statistics
```bash
curl -s localhost:9200/_nodes/stats/jvm?filter_path=nodes.*.name,nodes.*.jvm.gc&pretty
```
**Key fields:** `collectors.young.collection_count`, `collectors.young.collection_time_in_millis`, `collectors.old.collection_count`, `collectors.old.collection_time_in_millis`.
**Concerning:** Old GC > 5s per collection, old GC happening frequently (every few minutes), young GC > 500ms.

### 68. Circuit Breaker Stats
```bash
curl -s localhost:9200/_nodes/stats/breaker?filter_path=nodes.*.name,nodes.*.breakers&pretty
```
**Key fields per breaker:** `limit_size_in_bytes`, `estimated_size_in_bytes`, `overhead`, `tripped`.
**Concerning:** `tripped > 0` on any breaker. `estimated_size` approaching `limit_size`.

### 69. Fielddata Usage Per Node
```bash
curl -s 'localhost:9200/_cat/fielddata?v&h=node,field,size'
```
Shows memory consumed by fielddata cache per field per node. **Concerning:** Large fielddata = aggregating on text fields.

### 70. Fielddata Usage Per Index
```bash
curl -s localhost:9200/_nodes/stats/indices/fielddata?fields=*&pretty
```
Detailed fielddata stats with per-field breakdown.

### 71. Index Buffer Memory
```bash
curl -s localhost:9200/_nodes/stats?filter_path=nodes.*.name,nodes.*.indices.indexing_buffer&pretty
```

### 72. Segment Memory Breakdown
```bash
curl -s localhost:9200/_nodes/stats/indices/segments?filter_path=nodes.*.name,nodes.*.indices.segments&pretty
```
Shows heap consumed by segment metadata: terms, stored fields, norms, doc values, points, version map.

### 73. Memory Lock Verification
```bash
curl -s localhost:9200/_nodes?filter_path=nodes.*.process.mlockall&pretty
```
Verifies `bootstrap.memory_lock: true` is effective. `mlockall: true` means heap is locked in RAM (no swapping).

---

## Disk and Storage (6 commands)

### 74. Disk Allocation Summary
```bash
curl -s 'localhost:9200/_cat/allocation?v&h=node,shards,disk.indices,disk.used,disk.avail,disk.total,disk.percent&s=disk.percent:desc'
```
**Concerning:** `disk.percent > 85%` (low watermark), `> 90%` (high watermark), `> 95%` (flood stage).

### 75. Filesystem Stats Per Node
```bash
curl -s localhost:9200/_nodes/stats/fs?pretty
```
Shows total, free, and available bytes per data path per node.

### 76. Store Size Per Index
```bash
curl -s 'localhost:9200/_cat/indices?v&h=index,store.size,pri.store.size&s=store.size:desc' | head -20
```
Top 20 largest indices.

### 77. Watermark Status Check
```bash
curl -s localhost:9200/_cluster/settings?include_defaults=true&flat_settings=true | grep -i watermark
```
Shows current disk watermark settings.

### 78. Read-Only Indices (Flood Stage Triggered)
```bash
curl -s localhost:9200/_all/_settings?filter_path=*.settings.index.blocks.read_only_allow_delete&pretty
```
Shows any indices that have been made read-only due to disk pressure. Non-empty result = flood stage was triggered.

### 79. Clear Read-Only Block (After Freeing Disk)
```bash
curl -X PUT localhost:9200/_all/_settings -H 'Content-Type: application/json' -d '{
  "index.blocks.read_only_allow_delete": null
}'
```

---

## Task Management (7 commands)

### 80. List All Running Tasks
```bash
curl -s localhost:9200/_tasks?pretty
```
Shows all running tasks across the cluster.

### 81. List Long-Running Tasks
```bash
curl -s 'localhost:9200/_tasks?detailed=true&actions=*reindex*,*update_by_query*,*delete_by_query*&pretty'
```
Shows long-running data manipulation tasks with details.

### 82. Task Status (Specific Task)
```bash
curl -s localhost:9200/_tasks/node_id:task_id?pretty
```
Check the status of a specific task by its ID.

### 83. Cancel a Task
```bash
curl -X POST localhost:9200/_tasks/node_id:task_id/_cancel
```
Cancels a running task (reindex, update_by_query, etc.).

### 84. List Tasks Grouped by Parent
```bash
curl -s localhost:9200/_tasks?group_by=parents&pretty
```
Groups tasks by their parent task. Useful for understanding task hierarchies.

### 85. Pending Cluster Tasks
```bash
curl -s localhost:9200/_cluster/pending_tasks?pretty
```
Shows cluster-level tasks waiting to be processed by the master node. **Concerning:** Growing queue.

### 86. Tasks by Node
```bash
curl -s localhost:9200/_tasks?group_by=nodes&pretty
```

---

## Index Lifecycle Management (7 commands)

### 87. ILM Status
```bash
curl -s localhost:9200/_ilm/status?pretty
```
Shows whether ILM is running, stopped, or stopping.

### 88. List All ILM Policies
```bash
curl -s localhost:9200/_ilm/policy?pretty
```
Shows all defined ILM policies with their phase configurations.

### 89. Specific ILM Policy
```bash
curl -s localhost:9200/_ilm/policy/my-policy?pretty
```

### 90. Index ILM Status (Explain)
```bash
curl -s localhost:9200/my-index/_ilm/explain?pretty
```
**Key fields:** `managed` (true/false), `phase`, `action`, `step`, `failed_step`, `step_info`.
**Concerning:** `step: ERROR`, `failed_step` not null -- indicates ILM is stuck.

### 91. ILM Explain for All Managed Indices
```bash
curl -s 'localhost:9200/*/_ilm/explain?only_managed=true&only_errors=true&pretty'
```
Shows only indices with ILM errors. Essential for catching stuck ILM transitions.

### 92. Retry Failed ILM Step
```bash
curl -X POST localhost:9200/my-index/_ilm/retry
```
Retries ILM on an index stuck in an error state.

### 93. Move Index to ILM Phase
```bash
curl -X POST localhost:9200/_ilm/move/my-index -H 'Content-Type: application/json' -d '{
  "current_step": {
    "phase": "hot",
    "action": "complete",
    "name": "complete"
  },
  "next_step": {
    "phase": "warm",
    "action": "shrink",
    "name": "shrink"
  }
}'
```
Manually moves an index to a different ILM step.

---

## Snapshot and Restore (8 commands)

### 94. List Snapshot Repositories
```bash
curl -s localhost:9200/_snapshot/_all?pretty
```
Shows all configured snapshot repositories.

### 95. Verify Repository
```bash
curl -X POST localhost:9200/_snapshot/my-repo/_verify?pretty
```
Tests that all nodes can access the snapshot repository.

### 96. List All Snapshots in Repository
```bash
curl -s localhost:9200/_snapshot/my-repo/_all?pretty
```
Lists all snapshots with their status, indices, and timing.

### 97. Snapshot Status (Active Snapshots)
```bash
curl -s localhost:9200/_snapshot/_status?pretty
```
Shows progress of currently running snapshot operations.

### 98. Specific Snapshot Details
```bash
curl -s localhost:9200/_snapshot/my-repo/snapshot-name?pretty
```
Shows detailed info: state, start/end time, indices, shards succeeded/failed, total size.

### 99. SLM Policy Status
```bash
curl -s localhost:9200/_slm/policy?pretty
```
Shows all SLM policies, their schedules, last execution time, and success/failure counts.

### 100. SLM Stats
```bash
curl -s localhost:9200/_slm/stats?pretty
```
**Key fields:** `snapshots_taken`, `snapshots_failed`, `snapshots_deleted`, `snapshot_deletion_failures`.
**Concerning:** `snapshots_failed > 0`, `snapshot_deletion_failures > 0`.

### 101. Delete a Snapshot
```bash
curl -X DELETE localhost:9200/_snapshot/my-repo/old-snapshot-name
```

---

## Ingest Pipelines (5 commands)

### 102. List All Ingest Pipelines
```bash
curl -s localhost:9200/_ingest/pipeline?pretty
```

### 103. Specific Pipeline Definition
```bash
curl -s localhost:9200/_ingest/pipeline/my-pipeline?pretty
```

### 104. Simulate Pipeline (Test Without Indexing)
```bash
curl -s localhost:9200/_ingest/pipeline/my-pipeline/_simulate -H 'Content-Type: application/json' -d '{
  "docs": [
    {
      "_source": {
        "message": "192.168.1.1 - - [15/Jan/2024:10:30:00 +0000] \"GET /index.html HTTP/1.1\" 200 1234"
      }
    }
  ]
}'
```
Tests pipeline processing on sample documents. Essential for debugging Grok patterns.

### 105. Ingest Node Stats
```bash
curl -s localhost:9200/_nodes/stats/ingest?pretty
```
**Key fields per pipeline:** `count`, `time_in_millis`, `current`, `failed`.
**Concerning:** `failed > 0` (pipeline errors), high `time_in_millis / count` (slow pipeline).

### 106. Ingest Node Stats (Per Processor)
```bash
curl -s localhost:9200/_nodes/stats/ingest?filter_path=nodes.*.ingest.pipelines.*.processors&pretty
```
Shows timing per processor within each pipeline. Identifies bottleneck processors.

---

## Index Templates (4 commands)

### 107. List All Index Templates (Composable)
```bash
curl -s localhost:9200/_index_template?pretty
```

### 108. List All Component Templates
```bash
curl -s localhost:9200/_component_template?pretty
```

### 109. Specific Index Template
```bash
curl -s localhost:9200/_index_template/my-template?pretty
```

### 110. Simulate Index Template (What Would Apply?)
```bash
curl -s localhost:9200/_index_template/_simulate_index/logs-2024.01.15?pretty
```
Shows what settings, mappings, and aliases would apply if an index with this name were created.

---

## Cross-Cluster (3 commands)

### 111. Remote Cluster Info
```bash
curl -s localhost:9200/_remote/info?pretty
```
Shows connected remote clusters, their seed nodes, and connection status. **Concerning:** `connected: false`.

### 112. Cross-Cluster Search
```bash
curl -s localhost:9200/remote_cluster:logs-*/_search -H 'Content-Type: application/json' -d '{
  "query": { "match": { "level": "error" } },
  "size": 10
}'
```

### 113. Cross-Cluster Replication Stats
```bash
curl -s localhost:9200/follower-index/_ccr/stats?pretty
```
**Key fields:** `leader_global_checkpoint`, `follower_global_checkpoint`, `operations_read`, `operations_written`.
**Concerning:** Large gap between leader and follower global checkpoints (replication lag).

---

## Bulk and Indexing Stats (4 commands)

### 114. Indexing Rate Per Node
```bash
curl -s localhost:9200/_nodes/stats/indices/indexing?pretty
```
**Key fields:** `index_total`, `index_time_in_millis`, `index_failed`, `throttle_time_in_millis`.
**Concerning:** `throttle_time_in_millis > 0` (merge throttling), `index_failed > 0`.

### 115. Refresh Stats
```bash
curl -s localhost:9200/_nodes/stats/indices/refresh?pretty
```
**Key fields:** `total`, `total_time_in_millis`, `external_total`, `external_total_time_in_millis`.

### 116. Flush Stats
```bash
curl -s localhost:9200/_nodes/stats/indices/flush?pretty
```

### 117. Translog Stats
```bash
curl -s localhost:9200/_nodes/stats/indices/translog?pretty
```
**Key fields:** `operations`, `size_in_bytes`, `uncommitted_operations`, `uncommitted_size_in_bytes`.
**Concerning:** Very large `uncommitted_size_in_bytes` (flush not happening, risk of slow recovery).

---

## Cache Statistics (4 commands)

### 118. Query Cache Stats
```bash
curl -s localhost:9200/_nodes/stats/indices/query_cache?pretty
```
**Key fields:** `memory_size_in_bytes`, `total_count`, `hit_count`, `miss_count`, `evictions`.
**Concerning:** `hit_count` << `miss_count` (cache not effective), frequent `evictions`.

### 119. Request Cache Stats
```bash
curl -s localhost:9200/_nodes/stats/indices/request_cache?pretty
```
**Key fields:** `memory_size_in_bytes`, `hit_count`, `miss_count`, `evictions`.

### 120. Clear All Caches
```bash
curl -X POST localhost:9200/_cache/clear?pretty
```

### 121. Clear Specific Index Cache
```bash
curl -X POST localhost:9200/my-index/_cache/clear?query=true&fielddata=true&request=true
```

---

## Troubleshooting Playbooks

### Playbook: Cluster Status RED

**Symptom:** `_cluster/health` returns `status: red`. At least one primary shard is unassigned.

**Diagnosis steps:**
```bash
# 1. Which indices are red?
curl -s 'localhost:9200/_cat/indices?v&health=red'

# 2. Which shards are unassigned?
curl -s 'localhost:9200/_cat/shards?v&h=index,shard,prirep,state,unassigned.reason' | grep UNASSIGNED

# 3. Why is the shard unassigned?
curl -s localhost:9200/_cluster/allocation/explain?pretty

# 4. Check for missing nodes
curl -s localhost:9200/_cat/nodes?v

# 5. Check disk space
curl -s 'localhost:9200/_cat/allocation?v'
```

**Common causes and fixes:**
- **Node crashed:** Restart the node. Primary shard data on the lost node may be gone if no replica exists.
- **Disk full (flood stage):** Free disk space, then clear read-only blocks.
- **Corrupt shard:** As last resort, allocate an empty primary: `POST _cluster/reroute { "commands": [{ "allocate_empty_primary": { "index": "my-index", "shard": 0, "node": "node1", "accept_data_loss": true }}]}`
- **No valid shard copy:** If the shard data is lost and no replica exists, you must accept data loss or restore from snapshot.

### Playbook: Cluster Status YELLOW

**Symptom:** `_cluster/health` returns `status: yellow`. All primaries assigned but some replicas are not.

**Diagnosis steps:**
```bash
# 1. Which indices are yellow?
curl -s 'localhost:9200/_cat/indices?v&health=yellow'

# 2. Why can't replicas be assigned?
curl -s localhost:9200/_cluster/allocation/explain?pretty

# 3. Check node count vs. replica requirements
curl -s localhost:9200/_cat/nodes?v | wc -l
```

**Common causes:**
- **Single-node cluster with replicas:** Set replicas to 0: `PUT /my-index/_settings { "number_of_replicas": 0 }`
- **Not enough nodes in required zone:** Check awareness settings.
- **Disk watermark exceeded:** Free space or add storage.

### Playbook: Shard Relocation Storm

**Symptom:** Constant shard relocations causing high I/O and degraded performance.

```bash
# 1. Count active relocations
curl -s 'localhost:9200/_cat/shards?v' | grep -c RELOCATING

# 2. Check why rebalancing is occurring
curl -s localhost:9200/_cluster/allocation/explain?pretty

# 3. Temporarily pause allocation
curl -X PUT localhost:9200/_cluster/settings -H 'Content-Type: application/json' -d '{
  "transient": { "cluster.routing.allocation.enable": "primaries" }
}'

# 4. Investigate root cause (node joining/leaving, disk pressure)

# 5. Re-enable allocation
curl -X PUT localhost:9200/_cluster/settings -H 'Content-Type: application/json' -d '{
  "transient": { "cluster.routing.allocation.enable": "all" }
}'
```

### Playbook: Circuit Breaker Trips

**Symptom:** 429 errors with `circuit_breaking_exception`.

```bash
# 1. Which breaker tripped?
curl -s localhost:9200/_nodes/stats/breaker?pretty

# 2. Check heap pressure
curl -s localhost:9200/_cat/nodes?v&h=name,heap.percent,heap.max

# 3. Check fielddata usage (common culprit)
curl -s 'localhost:9200/_cat/fielddata?v'

# 4. Clear fielddata cache if needed
curl -X POST localhost:9200/_cache/clear?fielddata=true

# 5. Find expensive queries/aggregations
curl -s localhost:9200/_tasks?detailed=true&pretty
```

**Fixes:**
- **Parent breaker:** Reduce query complexity, add more nodes, increase heap (up to 31GB).
- **Fielddata breaker:** Stop aggregating on text fields. Use keyword multi-field.
- **Request breaker:** Reduce aggregation cardinality (use `execution_hint: map` or reduce `size`).

### Playbook: Slow Search Queries

**Symptom:** Search latency is high, users report slow results.

```bash
# 1. Check search latency stats
curl -s localhost:9200/_nodes/stats/indices/search?pretty

# 2. Enable slow log
curl -X PUT localhost:9200/_all/_settings -H 'Content-Type: application/json' -d '{
  "index.search.slowlog.threshold.query.warn": "5s",
  "index.search.slowlog.threshold.query.info": "2s"
}'

# 3. Check thread pool rejections
curl -s 'localhost:9200/_cat/thread_pool/search?v'

# 4. Check GC (long GC pauses = search stalls)
curl -s localhost:9200/_nodes/stats/jvm?filter_path=nodes.*.jvm.gc&pretty

# 5. Profile a specific slow query
curl -s localhost:9200/my-index/_search -H 'Content-Type: application/json' -d '{
  "profile": true,
  "query": { "match": { "title": "your slow query" } }
}'

# 6. Check segment count (too many segments = slow search)
curl -s 'localhost:9200/_cat/segments/my-index?v' | wc -l
```

**Fixes:**
- Force merge read-only indices to 1 segment
- Add filter context for non-scoring clauses
- Use `search_after` instead of deep `from/size` pagination
- Increase replicas for read-heavy workloads
- Scale out with more data nodes

### Playbook: Disk Pressure

**Symptom:** Disk usage approaching watermarks, potential read-only indices.

```bash
# 1. Check disk usage per node
curl -s 'localhost:9200/_cat/allocation?v&s=disk.percent:desc'

# 2. Check which indices use the most space
curl -s 'localhost:9200/_cat/indices?v&s=store.size:desc&h=index,store.size' | head -20

# 3. Check for read-only indices (flood stage)
curl -s localhost:9200/_all/_settings?filter_path=*.settings.index.blocks.read_only_allow_delete&pretty

# 4. Check ILM for stuck transitions
curl -s '*/_ilm/explain?only_managed=true&only_errors=true&pretty'

# 5. Check for old indices that should have been deleted
curl -s 'localhost:9200/_cat/indices?v&h=index,creation.date.string,store.size&s=creation.date.string'
```

**Fixes:**
- Delete old/unnecessary indices
- Force merge old indices (reduces storage)
- Fix stuck ILM policies
- Add disk capacity or data nodes
- Move old data to cold/frozen tier (searchable snapshots)
- Clear read-only blocks after freeing space: `PUT _all/_settings { "index.blocks.read_only_allow_delete": null }`

### Playbook: JVM GC Issues

**Symptom:** High heap usage, frequent or long GC pauses, node unresponsive.

```bash
# 1. Check heap and GC stats
curl -s 'localhost:9200/_cat/nodes?v&h=name,heap.percent,heap.max'
curl -s localhost:9200/_nodes/stats/jvm?filter_path=nodes.*.name,nodes.*.jvm.gc&pretty

# 2. Check what is consuming heap
curl -s localhost:9200/_nodes/stats/indices/segments,fielddata,query_cache?pretty

# 3. Check for large number of shards (each consumes ~10MB heap)
curl -s localhost:9200/_cluster/stats?filter_path=indices.shards.total&pretty

# 4. Check for runaway fielddata
curl -s 'localhost:9200/_cat/fielddata?v&s=size:desc'

# 5. Check hot threads for GC threads
curl -s localhost:9200/_nodes/hot_threads?threads=10
```

**Fixes:**
- Reduce shard count (merge small indices, fewer shards per index)
- Clear fielddata: `POST _cache/clear?fielddata=true`
- Increase heap to max 31GB (never exceed 50% of RAM)
- Review aggregation queries for high cardinality
- Force merge old indices (fewer segments = less heap for segment metadata)
- Consider dedicated coordinating nodes for heavy aggregation workloads
