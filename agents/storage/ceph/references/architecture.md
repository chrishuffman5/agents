# Ceph Architecture

## RADOS -- Reliable Autonomic Distributed Object Store

RADOS is the foundation beneath all Ceph interfaces. It is a self-healing, self-managing distributed object store that coordinates all data placement, replication, recovery, and cluster state without a central lookup table or metadata server.

Key properties:
- Clients compute object locations directly using the CRUSH algorithm -- no central broker required
- The cluster map encodes the current state of every component; clients and daemons track map epochs and update incrementally
- Consistency is enforced per-object using a primary-replica model; the primary OSD coordinates all writes to replica OSDs before acknowledging to the client

## Cluster Map

| Map | Contents |
|-----|----------|
| MonMap | Monitor IP addresses and epochs |
| OSDMap | OSD states (up/down/in/out), weights, CRUSH topology |
| PGMap | Placement group states and statistics |
| MDSMap | MDS states and filesystem metadata (CephFS only) |
| CRUSHMap | Embedded inside OSDMap; full CRUSH hierarchy and rules |

## Monitors (MON)

Monitors maintain the authoritative cluster map and are the source of truth for cluster state. They use the Paxos consensus protocol with an elected leader. A quorum of more than half the monitors must agree before any map change is committed (odd count required: 3 or 5).

Functions: accept and propagate map changes, authenticate daemons and clients via CephX, maintain cluster health, store cluster configuration in key-value store.

Deployment: dedicated SSDs for RocksDB store. Standard production uses 3 monitors across separate failure domains.

## OSD Daemons

Each OSD daemon manages one storage device. Core responsibilities:
- Store RADOS objects using BlueStore
- Handle replication writes: primary receives, fans out to replicas, waits for acks
- Self-compute PG-to-OSD mappings via CRUSH
- Heartbeat to peer OSDs; report suspected failures to monitors
- Execute scrub and deep-scrub for data integrity
- Participate in backfill and recovery

OSD states: `up`/`down` (process running), `in`/`out` (holds data). An OSD that goes down triggers marking-out after `mon_osd_down_out_interval` (default 600 seconds).

## Manager (MGR)

Extends cluster management: Prometheus metrics (port 9283), Dashboard web UI, orchestration modules (Cephadm, Rook), RESTful API, PG autoscaler, balancer. One active + standby(s).

## Metadata Server (MDS)

Manages the CephFS namespace (directory tree, inodes, file metadata). Does not store file data. Supports multiple active ranks for horizontal scaling via dynamic subtree partitioning. States: standby, standby-replay, active, damaged.

## CRUSH Algorithm

```
Object Name -> Hash -> PG ID -> CRUSH(PGid, OSDMap, CRUSHmap) -> [OSD list]
```

1. Client hashes object name against pool's PG count to get PG ID
2. CRUSH traverses bucket hierarchy using pseudo-random function seeded by (PG ID, bucket ID)
3. Result is deterministic ordered OSD list -- first is primary, rest are replicas/EC shards

### Hierarchy Buckets

```
root -> datacenter -> room -> row -> rack -> chassis -> host -> osd
```

Default algorithm: `straw2` (proportional weight-based distribution with minimal rebalancing).

### Failure Domains

A CRUSH rule specifies failure domain type. `failure_domain = host` places each replica on a distinct host. `failure_domain = rack` places each on a different rack.

### OSD Weights

Convention: 1.0 = 1 TB. A 4 TB device gets weight 4.0. `ceph osd reweight` sets a temporary 0.0-1.0 multiplier without changing CRUSH map permanently.

## Placement Groups (PGs)

```
Object -> PG (via hash) -> OSDs (via CRUSH)
```

PGs are the unit of data distribution and recovery. Target: 100-200 PGs per OSD across all pools. The PG autoscaler adjusts `pg_num` based on pool data size.

PG states: `creating`, `active+clean` (healthy), `peering`, `active+degraded`, `active+recovering`, `active+backfilling`, `inactive`, `stale`, `inconsistent`, `repair`.

## BlueStore

Default OSD backend since Luminous. Manages block devices directly without intermediate filesystem.

```
[OSD process]
    |
    |-- RocksDB (on BlueFS partition)
    |     Stores: onodes, PG logs, omap data, allocation state
    |
    |-- Raw block device
          Stores: actual object data extents
```

Key structures: Onode (per-object metadata), ExtentMap (logical-to-physical mappings), Blob (physical disk allocations).

Checksumming: crc32c on metadata, configurable (crc32c/xxhash32/xxhash64) on data. Validated on every read.

Copy-on-write snapshots via reference-counted blobs.

WAL/DB separation: `--block-db` for RocksDB database, `--block-wal` for write-ahead log on faster device. WAL: 1-2 GB per OSD; DB: 1-4% of data device.

Compression: per-pool inline (snappy, lz4, zlib, zstd). Modes: none, passive, aggressive, force.

## RBD -- RADOS Block Device

Thin-provisioned block storage by striping a virtual disk image across RADOS objects (default 4 MB each).

Features: layering (copy-on-write clones from snapshots), exclusive lock, journaling, RBD mirroring (async or sync between clusters), live migration.

Access: librbd (C/C++ for QEMU/KVM), krbd (kernel driver), NBD, Ceph CSI driver for Kubernetes.

## CephFS -- Ceph Distributed Filesystem

POSIX-compliant distributed filesystem on RADOS. Separate metadata pool (SSD, fast) and data pool(s) (large).

Client access: kernel client (kcephfs), FUSE (ceph-fuse), NFS gateway (Ganesha), SMB gateway (Samba; Tentacle adds integrated SMB Manager).

Multiple active MDS ranks for parallel metadata throughput via subtree partitioning. Directory-level snapshots via `.snap/<name>`.

## RGW -- RADOS Gateway

S3-compatible (and Swift-compatible) object store via HTTP/REST. Supports S3 Select, Object Lock, lifecycle rules, versioning, multipart upload, STS.

Multi-site: asynchronous replication between zones (active-active or active-passive). `radosgw-admin sync status` shows replication lag.

## Data Flow: Write Path

```
Client -> Compute PG (hash) -> Compute OSDs (CRUSH) -> Connect to Primary OSD
Primary OSD -> Write to BlueStore -> Fan out to Replica OSDs in parallel
Replica OSDs -> Write to BlueStore -> Ack to Primary
Primary OSD -> Commit local -> Ack to Client
```

## Data Flow: Read Path

```
Client -> Compute PG and OSD list (CRUSH) -> Connect to Primary OSD
Primary OSD -> Check BlueStore cache -> Query RocksDB for extent map
  -> Read data extents -> Validate checksums -> Return to Client
```

## Erasure Coding

Alternative to replication using less raw space. EC profile k=4, m=2 splits each object into 4 data + 2 parity shards, tolerating 2 OSD failures at 1.5x raw space (vs 3x for replication).

Trade-offs: lower storage overhead, higher CPU on writes, partial writes require read-modify-write.

Tentacle 20.2 introduces FastEC: parity-delta optimization, partial-read optimization, ISA-L as default plugin.

## Cephadm and Orchestration

Modern deployment tool using containers (Podman/Docker) managed by systemd.

```bash
cephadm bootstrap --mon-ip <IP>
ceph orch host add <hostname> <IP>
ceph orch daemon add osd <host>:<dev>
ceph orch apply osd --all-available-devices
```

Tentacle adds: mgmt-gateway (nginx reverse proxy for Dashboard/Prometheus/Grafana), oauth2-proxy (SSO), certmgr (certificate lifecycle).
