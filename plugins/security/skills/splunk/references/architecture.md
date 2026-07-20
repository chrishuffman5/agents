# Splunk Architecture Reference

## Component Overview

### Indexers

Indexers receive, parse, and store data. They are the core of Splunk's data storage and search execution layer.

**Data pipeline on the indexer:**
```
Input (raw data)
    |
    v
Parsing Pipeline
  - Line breaking (LINE_BREAKER in props.conf)
  - Header/footer removal
  - Encoding detection
    |
    v
Indexing Pipeline
  - Timestamp extraction (TIME_FORMAT, TIME_PREFIX)
  - Event segmentation
  - Index-time field extraction (TRANSFORMS)
  - Write to index (journal, tsidx, bloomfilter)
    |
    v
Storage
  - Hot bucket (actively written)
  - Warm bucket (closed, no longer written)
  - Cold bucket (aged, typically moved to cheaper storage)
  - Frozen bucket (deleted or archived to external storage)
```

**Bucket lifecycle:**

| Stage | State | Storage | Searchable |
|---|---|---|---|
| **Hot** | Actively receiving data | Fast SSD | Yes |
| **Warm** | Closed, recently aged | SSD or fast disk | Yes |
| **Cold** | Aged past `maxWarmDBCount` | Slower/cheaper disk | Yes |
| **Frozen** | Aged past `frozenTimePeriodInSecs` | Deleted or archived | No (unless thawed) |

Bucket transitions are controlled by `indexes.conf` settings: `maxHotBuckets`, `maxWarmDBCount`, `maxTotalDataSizeMB`, `frozenTimePeriodInSecs`.

**Bucket structure:**
```
db_<epoch_latest>_<epoch_earliest>_<id>_<guid>/
├── rawdata/
│   └── journal.zst        # Compressed raw events (zstd since 9.x)
├── *.tsidx                 # Time-series index files (inverted index)
├── bloomfilter             # Probabilistic filter for fast field existence checks
├── .csv metadata files     # Bucket metadata
└── Hosts.data, Sources.data, SourceTypes.data  # Indexed field metadata
```

### Search Heads

Search heads distribute search requests across indexers and merge results. They do not store indexed data (except for internal indexes and KV store).

**Search execution flow:**
```
User submits search
    |
    v
Search head parses SPL
    |
    v
Distributes search to indexers (map phase)
  - Each indexer searches its local buckets
  - Applies transforming commands that can run locally (e.g., stats per indexer)
    |
    v
Results streamed back to search head
    |
    v
Search head merges results (reduce phase)
  - Final aggregation, sorting, dedup
    |
    v
Results returned to user
```

**Search types:**
- **Historical search** -- Searches past indexed data. Disk-bound on indexers.
- **Real-time search** -- Continuously runs against incoming data. Resource-intensive. Avoid if possible; use scheduled searches or indexed real-time.
- **Saved/scheduled search** -- Runs on a cron schedule. Results cached for dashboards.
- **Accelerated report** -- Pre-computed summary for fast dashboard loading.
- **Data model acceleration** -- Background search that builds summary indexes (tsidx) for `tstats` queries.

### Forwarders

**Universal Forwarder (UF):**
- Lightweight (~50 MB installed)
- Collects data from files, WinEventLog, syslog, scripted inputs
- Does NOT parse or index data -- sends raw to indexers or heavy forwarders
- Managed centrally via Deployment Server
- Runs as a service on endpoints

**Heavy Forwarder (HF):**
- Full Splunk Enterprise instance configured to forward
- Can parse, filter, route, mask, and enrich data before forwarding
- Used for: syslog aggregation, data routing, PII masking, event filtering
- Resource-intensive compared to UF

**Configuration deployment:**
- **Deployment Server** -- Pushes apps/configs to forwarders via serverclass.conf
- **Deployment Client** -- Each forwarder polls the deployment server on an interval

### Indexer Clustering

Indexer clustering provides data replication and search availability:

**Roles:**
- **Cluster Manager (CM)** -- Formerly "master node." Coordinates replication and search factor.
- **Peer nodes** -- Indexers that replicate data among themselves.
- **Search heads** -- Connect to the cluster for distributed search.

**Key settings:**
- **Replication Factor (RF)** -- Number of copies of raw data. Default 3. Protects against data loss.
- **Search Factor (SF)** -- Number of searchable copies (with tsidx files). Default 2. Protects against search unavailability.

Example: RF=3, SF=2 means 3 copies of raw data exist, 2 of which are searchable. Lose any 2 peers and data is still available; lose 1 peer and search is unaffected.

**Bucket replication:**
```
Primary bucket (on originating peer)
    |
    ├── Replicated copy 1 (raw only if non-searchable)
    ├── Replicated copy 2 (raw + tsidx if searchable)
    └── ...up to RF copies
```

**Rolling restart:** Use `splunk rolling-restart cluster-peers` to restart indexers without search downtime.

### Search Head Clustering (SHC)

Search head clustering provides high availability for search:

- **Captain** -- Elected leader that coordinates job scheduling, replication of artifacts, and captain transfers.
- **Members** -- Peer search heads. All members can serve user requests.
- **Deployer** -- Pushes apps and configs to all SHC members (replaces deployment server for SH-specific content).

SHC replicates: saved searches, dashboards, lookups, KV store collections, user preferences.

Minimum deployment: 3 search heads (for captain election quorum).

### SmartStore

SmartStore offloads warm/cold buckets to remote object storage (S3, Azure Blob, GCS):

```
Hot buckets (local SSD)
    |
    v (bucket rolls to warm)
Warm buckets uploaded to remote store
    |
    v (local copy evicted by cache manager)
Cache miss? Bucket downloaded on-demand during search
```

**Benefits:**
- Decouple compute (indexers) from storage (S3)
- Elastic storage at S3 pricing
- Simplified scaling -- add indexers without migrating data

**Trade-offs:**
- Search latency increases for cache misses (especially cold data)
- Requires fast, reliable network to object storage
- Not all search types benefit -- `tstats` on accelerated data models still fast

**Key configuration (indexes.conf):**
```ini
[volume:remote_store]
storageType = remote
path = s3://my-bucket/splunk-smartstore
remote.s3.access_key = <key>
remote.s3.secret_key = <secret>
remote.s3.endpoint = https://s3.amazonaws.com

[my_index]
remotePath = volume:remote_store/$_index_name
```

### HTTP Event Collector (HEC)

HEC receives data over HTTP/HTTPS using token-based authentication:

```
Application/Container/Lambda
    |
    POST /services/collector/event
    Authorization: Splunk <token>
    Body: {"event": "log line", "sourcetype": "myapp", "index": "main"}
    |
    v
HEC endpoint (indexer or HEC load balancer)
    |
    v
Indexed directly (no forwarder needed)
```

**HEC best practices:**
- Use HTTPS in production
- Use index-specific tokens with restricted permissions
- Set `useACK=true` for guaranteed delivery (client must check acknowledgment)
- Load-balance HEC endpoints behind a reverse proxy for scale
- Use `/services/collector/raw` for raw text (not JSON-wrapped)

### Deployment Topologies

**Small (< 50 GB/day):**
```
All-in-one instance (indexer + search head)
  + Universal Forwarders on endpoints
```

**Medium (50-300 GB/day):**
```
1 Search Head
2-4 Indexers (clustered, RF=2, SF=2)
1 Deployment Server
1 License Manager
Universal Forwarders + optional Heavy Forwarder for syslog
```

**Large (300+ GB/day):**
```
3+ Search Head Cluster (with deployer)
6+ Indexer Cluster (RF=3, SF=2) with SmartStore
1 Cluster Manager
1 Deployment Server
1 License Manager
1 Monitoring Console
Heavy Forwarders for syslog aggregation
Universal Forwarders on endpoints
DMZ: dedicated indexers for external-facing data
```

**Splunk Cloud:**
- Indexers and search heads managed by Splunk
- Customer manages: forwarders, inputs, apps, searches, knowledge objects
- Inputs Data Manager (IDM) for cloud-to-cloud data collection
- Admin Config Service (ACS) for self-service configuration
- Victoria experience (latest architecture) uses SmartStore by default

## Data Pipeline Deep Dive

### Parsing Pipeline (Input → Indexing)

1. **Character encoding** -- Detect and convert to UTF-8
2. **Line breaking** -- `LINE_BREAKER` regex splits raw data into events
3. **Line merging** -- `SHOULD_LINEMERGE`, `BREAK_ONLY_BEFORE`, `MUST_BREAK_AFTER` combine multi-line events
4. **Header/footer stripping** -- Remove non-event content from structured files
5. **Timestamp extraction** -- `TIME_FORMAT`, `TIME_PREFIX`, `MAX_TIMESTAMP_LOOKAHEAD` identify event time
6. **Metadata assignment** -- `host`, `source`, `sourcetype`, `index` set from input configuration

### Indexing Pipeline

1. **Segmentation** -- Break event text into searchable tokens (controlled by `segmenters.conf`)
2. **Index-time field extraction** -- `TRANSFORMS-*` with `WRITE_META = true` (use sparingly)
3. **tsidx generation** -- Build inverted index entries for each token
4. **Journal write** -- Compress and write raw event to `rawdata/journal.zst`
5. **Bloom filter update** -- Add tokens to bucket-level bloom filter for fast field existence checks

### Search Pipeline

1. **Bloom filter check** -- Skip buckets that definitely don't contain search terms
2. **tsidx scan** -- Find matching events by token in the inverted index
3. **Raw data retrieval** -- Fetch matching events from journal
4. **Search-time field extraction** -- Apply `props.conf` EXTRACT and REPORT rules
5. **Search-time lookup** -- Apply automatic lookups
6. **Command pipeline** -- Execute SPL commands in order

## Capacity Planning

### Sizing Guidelines

| Component | CPU | RAM | Disk |
|---|---|---|---|
| **Indexer** | 12+ cores per 100 GB/day | 12-16 GB base + more for concurrent searches | SSD for hot/warm; storage per retention need |
| **Search Head** | 16+ cores | 32-64 GB (more for heavy concurrent use) | 300 GB SSD for OS, apps, dispatch |
| **Heavy Forwarder** | 8-16 cores per 100 GB/day routing | 8-16 GB | Minimal (pass-through) |
| **Universal Forwarder** | 1 core | 512 MB | 100 MB |

### Ingestion Volume Estimation

```
Daily volume = (events/sec) x (avg event size in bytes) x 86400 / (1024^3)
Example: 5,000 EPS x 500 bytes x 86400 = ~200 GB/day
```

### Storage Estimation

```
Indexed storage = daily volume x compression ratio x retention days x replication factor
Example: 200 GB/day x 0.5 (compression) x 90 days x 3 (RF) = 27 TB
SmartStore: hot/warm cache = 3-7 days of data on local SSD; rest in S3
```
