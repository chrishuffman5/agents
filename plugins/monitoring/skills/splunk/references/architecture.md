# Splunk Architecture Reference

> Core components, distributed architecture, data pipeline, bucket lifecycle, SmartStore, and Cloud vs Enterprise.

---

## Core Components

### Search Head

The user-facing interface for running searches, creating dashboards, and managing alerts. Accepts search requests, distributes them across indexers, and merges results. Does not store indexed data in distributed deployments. Runs Splunk Web UI and REST API. In clustered deployments, a Captain coordinates job scheduling among Search Head Cluster members.

### Indexer

Receives parsed events from forwarders, indexes them, and stores on disk. Maintains index buckets (hot, warm, cold, frozen). Responds to search requests distributed by the Search Head. In clustered deployment, replicates bucket data across peers. Each indexer manages multiple indexes (main, _internal, _audit, custom).

### Universal Forwarder (UF)

Lightweight agent on source machines (~100 MB RAM). Collects data from files, Windows Event Logs, registry, scripts, and network ports. Forwards raw or minimally processed data. No local indexing. Managed centrally via Deployment Server.

### Heavy Forwarder (HF)

Full Splunk instance configured to forward rather than index. Can parse, filter, mask, route, and transform data before forwarding. Used for protocol translation (syslog to TCP), data enrichment, load balancing, and PII masking in DMZ deployments.

### Deployment Server (DS)

Centrally manages configuration (apps, inputs.conf, outputs.conf) pushed to forwarders. Organizes forwarders into server classes. Scales to tens of thousands of Universal Forwarders. Does not manage SHC or Indexer Cluster members.

### Cluster Manager (formerly Master Node)

Manages Indexer Cluster: peer registration, bucket replication, search factor, replication factor. Distributes bundle updates. Monitors peer health and triggers bucket fixup on failure. Does not participate in search or indexing.

### License Server

Enforces daily indexing volume limits (GB/day). All indexers report to a single License Server. Violations trigger warnings; 5 violations in 30 days disables search for non-internal queries.

---

## Distributed Architecture

### Indexer Cluster

- **Replication Factor (RF):** Number of raw data copies (typically 2-3)
- **Search Factor (SF):** Number of searchable copies (must be <= RF)
- **Site replication:** Multi-site deployments with site-aware search and failover
- **SmartStore:** Tiered storage -- hot/warm on local SSD, cold on S3-compatible object storage

### Search Head Cluster (SHC)

- Minimum 3 Search Heads + 1 Deployer
- Captain election via Raft consensus; Captain schedules jobs
- Artifact replication: search results and knowledge objects sync across members
- Load-balanced by external load balancer (HAProxy, F5, AWS ALB)

### Reference Topology

```
[Universal Forwarders] -> [Heavy Forwarder] -> [Indexer Cluster (3+ peers)]
                                                        |
                                              [Cluster Manager]
[Search Head Cluster (3 SH)] <-> [Deployer]
                  |
          [License Server]
```

---

## Data Pipeline

```
INPUT -> PARSING -> INDEXING -> SEARCH
```

1. **Input:** Data arrives via forwarders, HEC, syslog, scripted inputs, or modular inputs
2. **Parsing:** Events broken (line-breaking), timestamps extracted, metadata stamped (host, source, sourcetype), transforms applied
3. **Indexing:** Events written to hot bucket as compressed raw journal + tsidx (time-series index). Bloom filters accelerate searches
4. **Search:** Search Head dispatches to indexers; indexers scan tsidx, return matching events to SH for aggregation

### Index Bucket Lifecycle

| Stage | Description | Storage |
|-------|-------------|---------|
| Hot | Actively written | Fast local SSD |
| Warm | Closed hot buckets | Local disk, searchable |
| Cold | Moved to cheaper storage | Slower disk or SmartStore (S3) |
| Frozen | Archived or deleted | Not searchable unless thawed |

### SmartStore

Moves warm/cold buckets to S3-compatible object storage. Hot bucket stays on SSD for write performance. Cold buckets fetched on-demand from object storage during search. Reduces local disk cost for long-retention deployments.

---

## Splunk Cloud vs Enterprise

| Aspect | Splunk Cloud | Splunk Enterprise |
|--------|-------------|------------------|
| Infrastructure | Managed by Splunk (AWS/GCP/Azure) | Customer-managed on-prem or IaaS |
| Upgrades | Automatic, phased | Manual, customer-controlled |
| SmartStore | Default storage model | Optional, requires S3-compatible |
| Pricing | Per-GB ingest or workload-based | Per-GB/day license |
| Apps | Splunk-vetted via Splunkbase | Any app, custom or Splunkbase |
| Self-storage | Victoria experience (new), Classic | Full filesystem control |
