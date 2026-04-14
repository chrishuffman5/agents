# Elasticsearch Architecture Reference

## Lucene Internals

Elasticsearch is built on Apache Lucene. Every shard is a self-contained Lucene index. Understanding Lucene internals is essential for performance tuning and troubleshooting.

### Inverted Index

The inverted index is the core data structure for full-text search:

- Maps each unique **term** to a list of **document IDs** (postings list) that contain that term
- Built per-field: each analyzed text field has its own inverted index
- Includes term frequency (TF), document frequency (DF), and positional information

```
Term         | Document IDs (postings list)
-------------|-----------------------------
"elastic"    | [1, 5, 12, 45, 99]
"search"     | [1, 3, 5, 12, 33, 99]
"cluster"    | [3, 12, 45]
"shard"      | [5, 45, 99]
```

Postings list components:
- **Document frequency** -- Number of documents containing the term (used for IDF in BM25)
- **Term frequency** -- How many times the term appears in each document
- **Positions** -- Token positions within the document (for phrase queries and proximity matching)
- **Offsets** -- Character start/end offsets (for highlighting)
- **Payloads** -- Arbitrary byte data attached to term occurrences (rarely used directly)

The inverted index is stored in multiple files per segment:
- `.tim` -- Term dictionary (sorted term list with metadata)
- `.tip` -- Term index (prefix trie for fast lookup into .tim)
- `.doc` -- Postings lists (document IDs and term frequencies)
- `.pos` -- Position data (for phrase and proximity queries)
- `.pay` -- Payloads and offsets

### Doc Values

Doc values are an on-disk columnar data structure used for sorting, aggregations, and scripting:

- Column-oriented: all values for a single field stored contiguously
- Built at index time (not lazily like fielddata)
- Stored in `.dvd` (data) and `.dvm` (metadata) files
- Enabled by default for all fields except `text` (which uses fielddata if needed)
- Can be disabled to save disk space for fields never used in aggregations/sorting:

```json
{
  "properties": {
    "description": {
      "type": "keyword",
      "doc_values": false
    }
  }
}
```

Doc values encoding strategies (Lucene auto-selects):
- **Numeric** -- Delta encoding, GCD compression, table encoding for low-cardinality
- **Binary** -- Variable-length byte arrays with shared prefixes
- **Sorted** -- Ordinal mapping (ordinal -> value lookup table) for keyword fields
- **Sorted Set** -- For multi-valued fields (arrays)
- **Sorted Numeric** -- For multi-valued numeric fields

### Stored Fields

Stored fields hold the original document `_source` and any explicitly stored fields:

- The `_source` field stores the entire original JSON document (compressed)
- Stored in `.fdt` (field data) and `.fdx` (field index) files
- Compressed using LZ4 (fast) or best_compression (DEFLATE, higher ratio)
- Loading stored fields requires disk I/O; avoid fetching `_source` when only aggregation results are needed
- `_source` can be disabled to save disk (but breaks reindex, update, highlight without stored fields):

```json
PUT /my-index
{
  "mappings": {
    "_source": { "enabled": false }
  }
}
```

Selective `_source` filtering at index level:
```json
PUT /my-index
{
  "mappings": {
    "_source": {
      "includes": ["title", "date", "author"],
      "excludes": ["large_blob"]
    }
  }
}
```

### Segment Architecture

Each Lucene index (ES shard) consists of one or more immutable **segments**:

```
Shard 0 (Lucene Index)
├── Segment _0 (committed)
│   ├── Inverted index (.tim, .tip, .doc, .pos)
│   ├── Doc values (.dvd, .dvm)
│   ├── Stored fields (.fdt, .fdx)
│   ├── Term vectors (.tvd, .tvx) [if enabled]
│   ├── Norms (.nvd, .nvm)
│   ├── Points (BKD tree: .kdi, .kdd, .kdm)
│   ├── Live docs (.liv) [tracks deletions]
│   └── Segment info (.si)
├── Segment _1 (committed)
├── Segment _2 (uncommitted, in-memory buffer)
├── segments_N (commit point file)
└── write.lock
```

**Segment lifecycle:**
1. New documents are added to an in-memory buffer (not yet searchable)
2. On **refresh** (default every 1 second), the buffer is written as a new segment to the filesystem cache (now searchable, but not durable)
3. On **flush** (triggered by translog size or explicit API), segments are fsync'd to disk and the translog is cleared
4. Background **merge** threads combine smaller segments into larger ones, removing deleted documents

**Immutability implications:**
- Updates are delete + re-add (old version marked as deleted in `.liv` file, new version in new segment)
- Deletes are soft: marked in `.liv`, physically removed during segment merges
- Concurrent reads are safe because segments never change after creation
- New segments from refresh are immediately visible to new search requests (near-real-time)

### Segment Merging

Merge policy controls how and when segments are combined:

**Tiered merge policy** (default):
- Groups segments by size into tiers
- Merges segments of similar size together
- Key parameters:

```json
PUT /my-index/_settings
{
  "index.merge.policy.max_merge_at_once": 10,
  "index.merge.policy.max_merged_segment": "5gb",
  "index.merge.policy.segments_per_tier": 10,
  "index.merge.policy.floor_segment": "2mb",
  "index.merge.policy.deletes_pct_allowed": 20.0
}
```

**Merge scheduler** -- Controls concurrent merge threads:
```json
PUT /my-index/_settings
{
  "index.merge.scheduler.max_thread_count": 1
}
```
- Default: `Math.max(1, Math.min(4, Runtime.availableProcessors() / 2))`
- Set to 1 for spinning disks (sequential I/O)
- Higher values for SSD/NVMe

**Force merge** -- Manually trigger segment merging (use carefully):
```
POST /my-index/_forcemerge?max_num_segments=1
```
- Only use on read-only indices (warm/cold tier)
- Merging to 1 segment optimizes search (no per-segment overhead) but is I/O intensive
- Never force-merge indices that are still being written to

### Norms

Norms store per-document, per-field normalization factors used in BM25 scoring:

- Encode field length at index time (longer fields = lower norm)
- Stored in `.nvd` and `.nvm` files
- 1 byte per document per field
- Can be disabled for fields where scoring does not matter:

```json
{
  "properties": {
    "tags": {
      "type": "text",
      "norms": false
    }
  }
}
```

### Points (BKD Trees)

Numeric, date, IP, and geo_point fields are stored as points in a BKD (Block K-Dimensional) tree:

- Stored in `.kdi`, `.kdd`, `.kdm` files
- Optimized for range queries (`gte`, `lte`)
- More efficient than inverted index for numeric ranges
- Used automatically for numeric and date field types

## Node Roles and Cluster Topology

### Master Node

The elected master node manages the cluster state:

**Cluster state contents:**
- Index metadata (mappings, settings, aliases for every index)
- Shard routing table (which shard lives on which node, allocation status)
- Node membership (list of all nodes in the cluster)
- Persistent and transient cluster settings
- Ingest pipeline definitions
- ILM policies, SLM policies, transforms
- Security configuration (roles, role mappings)

**Master election:**
- Uses a quorum-based election protocol
- Requires a majority of master-eligible nodes to elect a master
- In ES 7.0+, the `discovery.seed_hosts` and `cluster.initial_master_nodes` settings replaced the old `minimum_master_nodes` setting
- Split-brain is prevented by requiring a quorum: `(master_eligible_nodes / 2) + 1`

**Cluster state publication:**
- Master publishes cluster state updates to all nodes
- Two-phase commit: first publish, then commit after majority acknowledgment
- Large cluster state (many indices/shards) increases publication latency

**Dedicated master recommendation:**
- Always use 3 dedicated master nodes in production (or 5 for large clusters)
- Dedicated master nodes should NOT hold data (`node.roles: [master]`)
- Prevents data node GC pauses from destabilizing master election
- Low resource requirements: 2-4 CPU cores, 4-8GB heap, small SSD

### Data Node

Data nodes store shards and execute search, aggregation, and indexing operations:

**Resource consumption:**
- **Heap** -- Used for segment metadata, field data caches, query caches, indexing buffers. Typically 50% of available RAM (max ~31GB).
- **OS page cache** -- The other 50% of RAM. Lucene relies heavily on the OS filesystem cache for reading segment files. More OS cache = fewer disk reads.
- **CPU** -- Search, aggregation, indexing, segment merging all consume CPU. CPU-bound workloads benefit from more cores.
- **Disk** -- SSD/NVMe strongly recommended for hot data. Throughput matters more than latency for warm/cold data.
- **Network** -- Shard replication and recovery generate significant inter-node traffic.

### Coordinating Node

Every node acts as a coordinating node by default. A dedicated coordinating-only node (`node.roles: []`) handles:

1. **Scatter phase** -- Routes search request to all relevant shards
2. **Gather phase** -- Collects partial results from each shard, merges, sorts, and returns final result
3. **Reduce phase for aggregations** -- Combines aggregation results from all shards (memory-intensive for large cardinality aggregations)

Dedicated coordinating nodes are valuable when:
- Aggregations have high cardinality (thousands of buckets)
- Many concurrent search requests need merging
- You want to isolate search coordination from indexing load

## Shard Allocation

### Allocation Deciders

The master node uses allocation deciders to determine where shards are placed:

| Decider | Controls | Key Settings |
|---|---|---|
| **Disk threshold** | Prevents allocation to nodes with high disk usage | `cluster.routing.allocation.disk.watermark.low` (85%), `.high` (90%), `.flood_stage` (95%) |
| **Awareness** | Distributes shards across failure domains | `cluster.routing.allocation.awareness.attributes: rack_id` |
| **Forced awareness** | Ensures replicas are in different zones | `cluster.routing.allocation.awareness.force.zone.values: zone1,zone2` |
| **Filter** | Include/exclude nodes for specific indices | `index.routing.allocation.include._name: hot-*` |
| **Same shard** | Prevents primary and replica on same node | Always active (cannot be disabled) |
| **Max retries** | Limits allocation retry attempts | `index.allocation.max_retries: 5` (default) |
| **Throttle** | Limits concurrent shard recoveries | `cluster.routing.allocation.node_concurrent_recoveries: 2` |
| **Rebalance** | Controls when to rebalance shards | `cluster.routing.rebalance.enable: all` |

### Disk Watermarks

Disk watermarks are critical for cluster health:

| Watermark | Default | Behavior |
|---|---|---|
| **Low** | 85% | No new shards allocated to the node (warning) |
| **High** | 90% | Shards start relocating away from the node |
| **Flood stage** | 95% | All indices on the node become read-only (`index.blocks.read_only_allow_delete`) |

```json
PUT _cluster/settings
{
  "persistent": {
    "cluster.routing.allocation.disk.watermark.low": "85%",
    "cluster.routing.allocation.disk.watermark.high": "90%",
    "cluster.routing.allocation.disk.watermark.flood_stage": "95%",
    "cluster.routing.allocation.disk.watermark.flood_stage.frozen": "95%"
  }
}
```

To recover from flood stage:
```json
PUT /affected-index/_settings
{
  "index.blocks.read_only_allow_delete": null
}
```

### Shard Allocation Awareness

Distribute shards across failure domains (racks, zones, regions):

```yaml
# elasticsearch.yml on each node
node.attr.zone: us-east-1a
```

```json
PUT _cluster/settings
{
  "persistent": {
    "cluster.routing.allocation.awareness.attributes": "zone",
    "cluster.routing.allocation.awareness.force.zone.values": "us-east-1a,us-east-1b,us-east-1c"
  }
}
```

With forced awareness, if only 2 of 3 zones are available, replica shards that would be assigned to the missing zone remain unassigned rather than being placed in an available zone (which would defeat the purpose of zone awareness).

## Translog (Transaction Log)

The translog provides durability guarantees for indexed data that has not yet been Lucene-committed:

### Translog Lifecycle

1. Client sends an index/delete/update request
2. Operation is written to the in-memory Lucene buffer AND appended to the translog on disk
3. Operation is acknowledged to the client (after translog fsync if `index.translog.durability: request`)
4. On **refresh** (default 1s), the in-memory buffer becomes a searchable segment, but the translog is NOT cleared
5. On **flush**, Lucene commits (fsync's segments), and the translog is truncated

### Translog Settings

```json
PUT /my-index/_settings
{
  "index.translog.durability": "request",
  "index.translog.sync_interval": "5s",
  "index.translog.flush_threshold_size": "512mb"
}
```

| Setting | Default | Description |
|---|---|---|
| `index.translog.durability` | `request` | `request`: fsync after every operation (safest). `async`: fsync at `sync_interval` (faster, risk of data loss). |
| `index.translog.sync_interval` | `5s` | How often to fsync when durability is `async` |
| `index.translog.flush_threshold_size` | `512mb` | Trigger flush when translog exceeds this size |

### Crash Recovery

On node restart:
1. Lucene opens the last committed segments (from the commit point)
2. The translog is replayed from the last commit point forward
3. All operations in the translog are re-applied to Lucene
4. A new commit is performed and the translog is cleared
5. The shard is marked as recovered

## Refresh vs. Flush

| Operation | What Happens | Makes Data Searchable? | Makes Data Durable? | Translog Cleared? |
|---|---|---|---|---|
| **Index** | Document added to in-memory buffer + translog | No | Translog only | No |
| **Refresh** | In-memory buffer written as new segment to filesystem cache | Yes | No (filesystem cache only) | No |
| **Flush** | Lucene commit (fsync segments to disk) | Already was | Yes (disk) | Yes |
| **Translog fsync** | Translog written to disk | No | Yes (translog) | No |

**Near-real-time search:** Documents become searchable after refresh (default 1 second), not after flush. This is why Elasticsearch is called "near-real-time" -- there is a 1-second delay between indexing and searchability by default.

**Optimization for bulk indexing:**
```json
PUT /my-index/_settings
{ "index.refresh_interval": "-1" }

// ... perform bulk indexing ...

POST /my-index/_refresh

PUT /my-index/_settings
{ "index.refresh_interval": "1s" }
```

## Circuit Breakers

Circuit breakers prevent the JVM from running out of memory by tracking and limiting memory usage:

| Breaker | Default Limit | What It Protects |
|---|---|---|
| **Total** | 70% of heap (ES 7+: 95% with real memory tracking) | Combined limit for all breakers |
| **Request** | 60% of heap | Per-request data structures (aggregations, sorting) |
| **Fielddata** | 40% of heap | Fielddata loaded for text field aggregations/sorting |
| **In-flight requests** | 100% of heap | Incoming HTTP/transport request content |
| **Accounting** | 100% of heap | Long-lived objects (Lucene segment metadata) |

When a circuit breaker trips:
- The request is rejected with a `CircuitBreakingException`
- Error code: `429 Too Many Requests` or `503 Service Unavailable`
- The breaker resets automatically once the offending memory is released

```json
GET _nodes/stats/breaker
```

**Tripped breaker response:**
```json
{
  "error": {
    "type": "circuit_breaking_exception",
    "reason": "[parent] Data too large, data for [<http_request>] would be [1707382734/1.5gb], which is larger than the limit of [1503238553/1.3gb]",
    "bytes_wanted": 1707382734,
    "bytes_limit": 1503238553,
    "durability": "PERMANENT"
  },
  "status": 429
}
```

## Fielddata vs. Doc Values

| Aspect | Fielddata | Doc Values |
|---|---|---|
| Storage | In JVM heap (loaded lazily on first access) | On disk (built at index time) |
| Field types | `text` fields only | All except `text` |
| Performance | Fast once loaded; expensive to load; heap pressure | Always available; uses OS page cache; no heap |
| Memory impact | Can cause OOM; controlled by fielddata circuit breaker | Minimal heap impact |
| Use case | Aggregating/sorting on `text` (avoid this) | Aggregating/sorting on `keyword`, numeric, date |

**Best practice:** Never aggregate on `text` fields. Use a `keyword` multi-field instead:
```json
{
  "properties": {
    "status": {
      "type": "text",
      "fields": {
        "keyword": { "type": "keyword" }
      }
    }
  }
}
// Aggregate on status.keyword, NOT status
```

If you must aggregate on a `text` field (not recommended), enable fielddata:
```json
PUT /my-index/_mapping
{
  "properties": {
    "field_name": {
      "type": "text",
      "fielddata": true,
      "fielddata_frequency_filter": {
        "min": 0.01,
        "max": 1.0,
        "min_segment_size": 500
      }
    }
  }
}
```

## Caching Architecture

### Node Query Cache (Filter Cache)

- Caches results of queries used in filter context (term filters, range filters in bool/filter)
- LRU eviction policy
- Per-segment: invalidated when segment is merged or deleted
- Only caches segments with > 10,000 documents (by default)
- Size: `indices.queries.cache.size: 10%` of heap (default)

### Shard Request Cache

- Caches the full response of search requests where `size: 0` (aggregation-only requests)
- Keyed on the full request body
- Invalidated when the index is refreshed (new data makes cache stale)
- Size: `indices.requests.cache.size: 1%` of heap (default)
- Per-request opt-in: `GET /my-index/_search?request_cache=true`

### Fielddata Cache

- Caches fielddata structures for text field aggregations/sorting
- Managed by the fielddata circuit breaker
- Clear manually: `POST /my-index/_cache/clear?fielddata=true`
- Monitor: `GET _cat/fielddata?v`

## Thread Pools

Elasticsearch uses thread pools to manage concurrent operations:

| Thread Pool | Type | Default Size | Purpose |
|---|---|---|---|
| `search` | fixed | `int((# of available_processors * 3) / 2) + 1` | Search and count requests |
| `search_throttled` | fixed | 1 | Searches on frozen indices |
| `write` | fixed | `# of available_processors` | Index, delete, update, bulk requests |
| `get` | fixed | `# of available_processors` | Get by ID requests |
| `analyze` | fixed | 1 | Analyze API requests |
| `management` | scaling | 5 (max: # processors * 5) | Cluster management (state updates, etc.) |
| `snapshot` | scaling | min(5, # processors / 2) | Snapshot/restore operations |
| `warmer` | scaling | min(5, # processors / 2) | Segment warming |
| `refresh` | scaling | min(10, # processors / 2) | Refresh operations |
| `flush` | scaling | min(5, # processors / 2) | Flush and translog operations |
| `force_merge` | fixed | max(1, # processors / 8) | Force merge operations |
| `fetch_shard_started` | scaling | # processors * 2 | Shard startup fetching |
| `fetch_shard_store` | scaling | # processors * 2 | Shard store fetching |

Each fixed thread pool has an associated **queue**. When all threads are busy, requests queue. When the queue is full, requests are **rejected** (429 status).

```
GET _cat/thread_pool?v&h=node_name,name,active,queue,rejected,completed
```

## Discovery and Cluster Formation

### Bootstrap Process (ES 7.0+)

1. Start nodes with `discovery.seed_hosts` listing addresses of master-eligible nodes
2. On first cluster formation, set `cluster.initial_master_nodes` with the names of the initial master-eligible nodes
3. Nodes discover each other via the seed hosts list
4. A master election occurs among master-eligible nodes
5. The elected master forms the cluster and publishes the initial cluster state
6. `cluster.initial_master_nodes` is automatically removed after the first election (in ES 8+, it is not persisted)

```yaml
# elasticsearch.yml
cluster.name: production-cluster
node.name: master-1
node.roles: [master]
discovery.seed_hosts: ["master-1:9300", "master-2:9300", "master-3:9300"]
cluster.initial_master_nodes: ["master-1", "master-2", "master-3"]
```

### Zen Discovery (Legacy, ES < 7.0)

Pre-7.0 used Zen Discovery with `discovery.zen.minimum_master_nodes` to prevent split-brain. This is replaced by the quorum-based system in 7.0+.

## Shard Recovery

Shard recovery occurs when:
- A node restarts (local recovery from translog)
- A replica is allocated to a new node (peer recovery from primary)
- A snapshot is being restored

**Recovery throttling:**
```json
PUT _cluster/settings
{
  "persistent": {
    "indices.recovery.max_bytes_per_sec": "100mb",
    "cluster.routing.allocation.node_concurrent_incoming_recoveries": 2,
    "cluster.routing.allocation.node_concurrent_outgoing_recoveries": 2
  }
}
```

Monitor recovery progress:
```
GET _cat/recovery?v&active_only=true
```
