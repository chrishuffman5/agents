# Elastic Security Architecture Reference

## Elasticsearch Cluster

### Node Types

| Node Type | Role | Purpose |
|---|---|---|
| **Master-eligible** | Cluster coordination | Manages cluster state, index creation, shard allocation |
| **Data (hot)** | Active indexing and search | SSD storage, high CPU for recent data |
| **Data (warm)** | Less-frequent search | Larger, slower storage for aging data |
| **Data (cold)** | Infrequent search | Cheapest storage, searchable snapshots |
| **Data (frozen)** | Rarely accessed | Fully mounted searchable snapshots from object storage |
| **Ingest** | Pipeline processing | Runs ingest pipelines (parsing, enrichment, GeoIP) |
| **Coordinating** | Query routing | Distributes search requests, merges results |
| **ML** | Machine learning | Dedicated resources for anomaly detection jobs |
| **Fleet Server** | Agent coordination | Manages Elastic Agent fleet |

### Data Flow

```
Data Source
    |
    ├── Elastic Agent (endpoint) --> Fleet Server --> Elasticsearch
    ├── Logstash (server-side) --> Elasticsearch
    ├── Beats (legacy) --> Elasticsearch
    └── API (direct) --> Elasticsearch
    |
    v
Ingest Pipeline (parse, transform, enrich)
    |
    v
Data Stream (time-series index pattern)
    |
    ├── Hot tier (current write index)
    ├── Warm tier (rolled over, still frequently searched)
    ├── Cold tier (infrequently searched, searchable snapshots)
    └── Frozen tier (rarely searched, fully mounted snapshots)
    |
    v
Kibana Security App
    |
    ├── Detection engine (rules, alerts)
    ├── Timeline (investigation)
    ├── Cases (incident management)
    ├── Osquery (live queries)
    └── ML anomaly detection
```

### Data Streams

Data streams are the recommended storage pattern for time-series security data:

```
Data stream: logs-endpoint.events.process-default
    |
    ├── .ds-logs-endpoint.events.process-default-2026.04.01-000001 (backing index, hot)
    ├── .ds-logs-endpoint.events.process-default-2026.03.01-000002 (backing index, warm)
    └── .ds-logs-endpoint.events.process-default-2026.02.01-000003 (backing index, cold)
```

**Naming convention:** `{type}-{dataset}-{namespace}`
- Type: `logs`, `metrics`, `traces`
- Dataset: `endpoint.events.process`, `system.auth`, `firewall`
- Namespace: `default`, `production`, `dmz`

### Index Lifecycle Management (ILM)

ILM automates index transitions through tiers:

```json
{
  "policy": {
    "phases": {
      "hot": {
        "actions": {
          "rollover": {
            "max_primary_shard_size": "50gb",
            "max_age": "1d"
          }
        }
      },
      "warm": {
        "min_age": "7d",
        "actions": {
          "shrink": {"number_of_shards": 1},
          "forcemerge": {"max_num_segments": 1},
          "allocate": {"require": {"data": "warm"}}
        }
      },
      "cold": {
        "min_age": "30d",
        "actions": {
          "searchable_snapshot": {"snapshot_repository": "my-repo"}
        }
      },
      "frozen": {
        "min_age": "90d",
        "actions": {
          "searchable_snapshot": {"snapshot_repository": "my-repo"}
        }
      },
      "delete": {
        "min_age": "365d",
        "actions": {"delete": {}}
      }
    }
  }
}
```

### Shard Strategy

**Sizing guidelines:**
- Target 25-50 GB per shard (hot tier)
- Avoid shards smaller than 1 GB (overhead) or larger than 65 GB (recovery time)
- Number of shards per index = expected daily size / target shard size
- Total cluster shards: aim for < 20 shards per GB of heap memory

**Shard allocation awareness:**
```yaml
# elasticsearch.yml
node.attr.zone: zone1
cluster.routing.allocation.awareness.attributes: zone
cluster.routing.allocation.awareness.force.zone.values: zone1,zone2
```

## Fleet Architecture

### Fleet Server

Fleet Server runs as an Elastic Agent integration:

```
Kibana (Fleet UI)
    |
    v
Fleet Server (API endpoint for agents)
    |
    ├── Agent enrollment
    ├── Policy distribution
    ├── Agent check-in (default: 30 seconds)
    ├── Action dispatching (response actions)
    └── Status reporting
    |
    v
Elastic Agents (10,000+ per Fleet Server)
```

**Scaling Fleet Server:**
- Single Fleet Server: up to ~10,000 agents
- Fleet Server cluster: multiple Fleet Servers behind a load balancer
- Fleet Server on Elasticsearch: co-locate for small deployments
- Dedicated Fleet Server: separate hosts for large deployments

### Elastic Agent Integrations

Integrations are modular data collection packages:

| Category | Key Integrations | Data Generated |
|---|---|---|
| **Endpoint Security** | Elastic Defend | Process, file, network, registry events; malware detection |
| **Operating System** | System, Windows, Linux | Auth logs, system metrics, syslog |
| **Network** | Palo Alto, Fortinet, Cisco, Suricata | Firewall logs, IDS/IPS alerts |
| **Cloud** | AWS, Azure, GCP | CloudTrail, Activity logs, Audit logs |
| **Identity** | Okta, Azure AD, Google Workspace | Authentication, admin activity |
| **Custom** | Custom logs, CEF, Syslog | Any structured/unstructured data |

### Ingest Pipelines

Ingest pipelines process data before indexing:

```json
{
  "description": "Security event enrichment pipeline",
  "processors": [
    {
      "geoip": {
        "field": "source.ip",
        "target_field": "source.geo"
      }
    },
    {
      "user_agent": {
        "field": "user_agent.original",
        "target_field": "user_agent"
      }
    },
    {
      "set": {
        "field": "event.ingested",
        "value": "{{_ingest.timestamp}}"
      }
    },
    {
      "script": {
        "source": "if (ctx.source?.ip != null && ctx.source.ip.startsWith('10.')) { ctx.source.internal = true; }"
      }
    }
  ]
}
```

## ECS Deep Dive

### Field Hierarchy

ECS uses a hierarchical dot-notation structure:

```
Base Fields
├── @timestamp          # Event timestamp
├── message             # Human-readable event description
├── tags                # User-defined tags
└── labels              # Key-value pairs for custom metadata

Event Fields
├── event.category      # Category: authentication, network, process, file
├── event.type          # Type: start, end, access, creation, deletion
├── event.outcome       # Outcome: success, failure, unknown
├── event.action        # Specific action: logged-in, file-deleted
├── event.severity      # Numeric severity (0-100)
└── event.risk_score    # Calculated risk score

Process Fields
├── process.name        # Process name (e.g., powershell.exe)
├── process.pid         # Process ID
├── process.args        # Command line arguments (array)
├── process.executable  # Full path to executable
├── process.hash.*      # File hashes (md5, sha1, sha256)
├── process.parent.*    # Parent process (same structure)
└── process.entry_leader.* # Session leader process

Host Fields
├── host.name           # Hostname
├── host.ip             # Host IP addresses (array)
├── host.os.*           # Operating system details
└── host.architecture   # CPU architecture

Network Fields
├── source.ip           # Source IP
├── source.port         # Source port
├── destination.ip      # Destination IP
├── destination.port    # Destination port
├── network.transport   # Transport protocol (tcp, udp)
└── network.protocol    # Application protocol (http, dns, tls)
```

### Custom Field Mapping

When onboarding non-ECS data, map vendor fields to ECS:

```json
{
  "description": "Map vendor firewall fields to ECS",
  "processors": [
    {"rename": {"field": "src_addr", "target_field": "source.ip"}},
    {"rename": {"field": "dst_addr", "target_field": "destination.ip"}},
    {"rename": {"field": "dst_port", "target_field": "destination.port"}},
    {"set": {"field": "event.category", "value": "network"}},
    {"set": {"field": "event.type", "value": "connection"}},
    {
      "script": {
        "source": "ctx.event.outcome = ctx.action == 'allow' ? 'success' : 'failure';"
      }
    }
  ]
}
```

## Capacity Planning

### Cluster Sizing Guidelines

| Component | CPU | Memory | Storage |
|---|---|---|---|
| **Master (3 nodes)** | 4 cores | 8 GB | 50 GB SSD |
| **Hot data node** | 16+ cores | 64 GB (31 GB heap) | NVMe SSD, 5-10 TB |
| **Warm data node** | 8 cores | 32 GB (16 GB heap) | Large HDD/SSD, 20+ TB |
| **Cold/Frozen** | 4 cores | 16 GB | Object storage (S3, GCS, Azure Blob) |
| **ML node** | 16 cores | 64 GB | 100 GB SSD |
| **Coordinating** | 8 cores | 32 GB | Minimal |
| **Fleet Server** | 4-8 cores | 8-16 GB | 50 GB |

### Storage Estimation

```
Hot tier: (daily_ingest_GB) x (hot_retention_days) x 1.1 (overhead)
Warm tier: (daily_ingest_GB) x (warm_retention_days) x 0.5 (forcemerge savings)
Cold/Frozen: (daily_ingest_GB) x (cold_retention_days) x 0.4 (snapshot compression)

Example: 100 GB/day, 7 days hot, 30 days warm, 365 days frozen
  Hot: 100 x 7 x 1.1 = 770 GB
  Warm: 100 x 30 x 0.5 = 1,500 GB
  Frozen: 100 x 365 x 0.4 = 14,600 GB (in object storage)
```

### Performance Tuning

- **Heap size** -- Set to 50% of RAM, max 31 GB (compressed oops threshold)
- **Thread pool** -- Monitor `thread_pool.search.rejected` for search queue saturation
- **Circuit breakers** -- Monitor `parent` circuit breaker trips for memory pressure
- **Refresh interval** -- Increase from 1s to 30s on high-volume indices to reduce indexing overhead
- **Translog durability** -- `request` (default, durable) vs `async` (higher throughput, risk of data loss on crash)
