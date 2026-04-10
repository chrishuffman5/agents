# Ceph Architecture

## Overview

Ceph is a software-defined unified storage platform providing object, block, and file storage from a single system. It is designed for scalability from terabytes to exabytes, self-healing, self-managing, and with no single point of failure. The entire platform rests on RADOS, the Reliable Autonomic Distributed Object Store.

---

## RADOS — Reliable Autonomic Distributed Object Store

RADOS is the foundation beneath all Ceph interfaces. It is a self-healing, self-managing distributed object store that coordinates all data placement, replication, recovery, and cluster state without a central lookup table or metadata server. Every piece of data in Ceph ultimately lives in RADOS as named objects within named pools.

Key properties of RADOS:
- Clients compute object locations directly using the CRUSH algorithm — no central broker required
- The cluster map encodes the current state of every component; clients and daemons track map epochs and update incrementally
- Consistency is enforced per-object using a primary-replica model; the primary OSD coordinates all writes to replica OSDs before acknowledging to the client

---

## Cluster Map

The cluster map is a collection of versioned maps that together describe full cluster topology and state:

| Map | Contents |
|-----|----------|
| MonMap | Monitor IP addresses and epochs |
| OSDMap | OSD states (up/down/in/out), weights, CRUSH topology |
| PGMap | Placement group states and statistics |
| MDSMap | MDS states and filesystem metadata (CephFS only) |
| CRUSHMap | Embedded inside OSDMap; full CRUSH hierarchy and rules |

Clients and daemons keep cached copies and subscribe to incremental updates. An outdated map causes an operation to be rejected with an epoch mismatch, prompting the client to fetch the latest map before retrying.

---

## Monitors (MON)

Monitors maintain the authoritative cluster map and are the source of truth for cluster state. They do not serve data directly.

**Consensus:** Monitors use the Paxos consensus protocol. An elected leader drives proposal/accept rounds for all map updates. A quorum of more than half the monitors must agree before any map change is committed. This is why an odd number of monitors (typically 3 or 5) is required.

**Functions:**
- Accept and propagate map changes (OSD up/down, weight changes, etc.)
- Authenticate daemons and clients via CephX
- Maintain cluster health and raise/clear health warnings
- Store small amounts of cluster configuration in the monitor key-value store

**Deployment guidance:** Monitors should run on dedicated SSDs for their RocksDB store. Disk I/O on the monitor can cause election timeouts and quorum instability. Standard production deployments use 3 monitors across separate failure domains.

---

## OSD Daemons (OSD)

Each OSD daemon manages one storage device (typically one disk or NVMe). OSDs are where all data, metadata checksums, and recovery state live.

**Core responsibilities:**
- Store RADOS objects using the BlueStore backend
- Handle replication writes: the primary OSD receives a write, fans out to replica OSDs, waits for acknowledgments, then replies to the client
- Run CRUSH to self-compute PG-to-OSD mappings without asking monitors
- Heartbeat to peer OSDs; report suspected failures to monitors
- Execute scrub and deep-scrub to detect bitrot and data integrity issues
- Participate in backfill and recovery when OSDs rejoin after being down

**OSD states:**
- `up` / `down`: whether the daemon process is running
- `in` / `out`: whether the OSD holds data (CRUSH weight > 0)
- An OSD that goes down but stays `in` triggers PG peering and eventual marking-out after `mon_osd_down_out_interval` (default 600 seconds)

---

## Manager (MGR)

The Manager daemon extends cluster management without burdening monitors with non-consensus tasks.

**Functions:**
- Expose the Prometheus metrics endpoint (default port 9283)
- Host the Ceph Dashboard web UI
- Run orchestration modules (Cephadm, Rook)
- Provide the RESTful API, telemetry, PG autoscaler, and balancer modules
- Collect and aggregate statistics from OSDs (IOPS, throughput, latency per pool/OSD)

**Deployment:** Run one active MGR per cluster with one or more standbys. Standby MGRs take over within seconds on active failure. MGR daemons communicate with monitors for cluster state and subscribe to OSD map updates.

---

## Metadata Server (MDS)

MDS daemons manage the namespace (directory tree, file metadata, inodes) for CephFS. They do not store file data — data blocks go directly to OSDs via RADOS.

**Functions:**
- Handle POSIX metadata operations: create, stat, rename, unlink, chmod
- Manage client capabilities (locks) so multiple clients can safely share the filesystem
- Cache hot metadata in RAM; flush dirty metadata to the metadata pool in RADOS
- Support multiple active ranks (parallel MDS) for horizontal scaling of metadata throughput

**MDS states:** standby, standby-replay, creating, active, stopping, damaged

**Failure model:** If an active MDS fails, a standby (or standby-replay) MDS takes over that rank. Standby-replay MDS continuously tails the active's journal for faster failover.

---

## CRUSH Algorithm

CRUSH (Controlled Replication Under Scalable Hashing) is the algorithm that all Ceph clients and OSDs use to compute data placement. There is no central lookup service; any party with the current CRUSH map can independently compute where any object lives.

### How CRUSH works

```
Object Name → Hash → PG ID → CRUSH(PGid, OSDMap, CRUSHmap) → [OSD list]
```

1. The client hashes the object name against the pool's PG count to get a PG ID
2. CRUSH traverses the bucket hierarchy from root downward, using a pseudo-random function seeded by (PG ID, bucket ID) to select a child at each level
3. The result is a deterministic ordered list of OSDs — first is primary, rest are replicas (or erasure shards)

### CRUSH hierarchy buckets

The CRUSH map encodes a hierarchy of named buckets. Common types (from root to leaf):

```
root → datacenter → room → row → rack → chassis → host → osd
```

Each level can be a different bucket algorithm:
- `straw2` (default): distributes load proportionally to weights; best for most cases
- `uniform`: equal-size buckets, fastest computation
- `list`: optimized for growing clusters (new items only affect existing items)

### Failure domains

A CRUSH rule specifies a failure domain type. When `failure_domain = host`, each replica is placed on a distinct host. When `failure_domain = rack`, each replica goes to a different rack. The rule must be matched against the actual hierarchy depth in your CRUSH map.

### OSD weights

OSD weights represent relative storage capacity. Convention: 1.0 = 1 TB. A 2 TB device gets weight 2.0. Weights direct proportionally more PGs to larger devices.

**Reweight vs weight:** `ceph osd reweight` sets a temporary per-OSD multiplier (0.0–1.0) to reduce PG load on a hot or nearly-full OSD without changing the CRUSH map permanently.

---

## Placement Groups (PGs)

Placement groups are the unit of data distribution and recovery within a pool. Objects are not mapped directly to OSDs; instead:

```
Object → PG (via hash) → OSDs (via CRUSH)
```

This indirection means the cluster can move data between OSDs by reassigning PGs without tracking individual objects.

**PG count:** Each pool has a fixed `pg_num`. PGs are distributed across OSDs. More PGs = finer-grained distribution but more overhead. The PG autoscaler (enabled by default) adjusts `pg_num` based on pool data size.

**Target:** 100–200 PGs per OSD (across all pools). The autoscaler targets `mon_target_pg_per_osd` (default 100; Red Hat recommends 200–250 for BlueStore).

**PG lifecycle states:**
- `creating` → `active+clean` (healthy)
- `peering`: OSDs are negotiating the authoritative object set
- `active+degraded`: some replicas missing, I/O continues
- `active+recovering`: missing data is being restored
- `active+backfilling`: data is being redistributed (e.g., after OSD rejoins)
- `inactive`: no I/O possible — all OSDs for this PG are unavailable
- `stale`: PG has not reported status recently
- `inconsistent`: scrub found data mismatch between replicas
- `repair`: automatic repair in progress after inconsistency

---

## BlueStore

BlueStore is the default OSD backend since Luminous (2017). It replaces FileStore (ext4/xfs + journal) with a purpose-built storage engine that manages block devices directly without an intermediate filesystem.

### Architecture

```
[Client I/O]
    │
    ▼
[OSD process]
    │
    ├─► RocksDB (on BlueFS partition)
    │     Stores: object metadata (onodes), PG logs, omap data, allocation state
    │
    └─► Raw block device
          Stores: actual object data extents
```

**BlueFS** is a minimal log-structured filesystem embedded in BlueStore solely to host RocksDB. It is not accessible to users.

### Key data structures

| Structure | Description |
|-----------|-------------|
| Onode | Per-object metadata: size, mtime, extent map references |
| ExtentMap | Logical-to-physical offset mappings for each object |
| Blob | Contiguous physical disk allocation, possibly shared across extents |

### Checksumming

BlueStore checksums all data and metadata at write time:
- RocksDB (metadata): crc32c
- Object data: configurable — crc32c, xxhash32, xxhash64

On read, checksums are validated. Mismatches trigger scrub-level repair if a valid replica exists.

### Copy-on-write snapshots

BlueStore uses reference-counted blobs. When a snapshot is taken, data blobs are shared between the snapshot and the live object. Writes to the live object allocate new extents without touching the snapshot's data.

### WAL and DB device separation

For mixed-media clusters (HDDs + NVMe), BlueStore supports offloading RocksDB to a faster device:

```
--block-db /dev/nvme0n1p1   # RocksDB database partition
--block-wal /dev/nvme0n1p2  # RocksDB write-ahead log partition
```

Sizing guideline: WAL = 1–2 GB per OSD; DB = 1–4% of data device size (use 4%+ for RGW-heavy workloads with large omap).

### Compression

BlueStore supports per-pool inline compression:
- Algorithms: snappy, lz4, zlib, zstd
- Modes: `none`, `passive` (compress if client requests), `aggressive` (compress unless client requests not to), `force` (always compress)

---

## RBD — RADOS Block Device

RBD provides thin-provisioned block storage by striping a virtual disk image across RADOS objects (default 4 MB each).

### Object naming

An RBD image named `vol01` with 4 MB objects appears in RADOS as:
```
rbd_data.<image_id>.0000000000000000
rbd_data.<image_id>.0000000000000001
...
```

### Features

- **Layering (clones/snapshots):** Copy-on-write clones from protected snapshots. Hundreds of VMs can share a base image with no data duplication.
- **Exclusive lock:** Ensures only one writer at a time; required for features like journaling and mirroring.
- **Journaling:** Write-ahead journal for crash-consistent point-in-time recovery and asynchronous mirroring.
- **RBD mirroring:** Asynchronous or synchronous replication between two Ceph clusters (active/passive or active/active per pool or image).
- **Live migration:** Move an image between pools or clusters while it is in use.

### Access methods

- `librbd`: C/C++ library used by QEMU/KVM directly for maximum performance
- `krbd`: In-kernel RBD driver (`/dev/rbdX` block devices)
- `NBD`: Network Block Device for environments without kernel driver
- Ceph CSI driver: Kubernetes dynamic provisioning via RBD

---

## CephFS — Ceph Distributed Filesystem

CephFS is a POSIX-compliant distributed filesystem built on RADOS. It uses separate pools for metadata and data:
- **Metadata pool:** Small, fast — stores inodes, directory entries, MDS journal; should be on SSDs
- **Data pool(s):** Large — stores actual file data as RADOS objects

### Client access

- **Kernel client (kcephfs):** `mount -t ceph`; best performance; requires matching kernel support
- **FUSE client (ceph-fuse):** Userspace; more portable; slightly higher latency
- **NFS gateway:** Export CephFS via NFS using the `nfs` MGR module (Ganesha-backed)
- **SMB gateway:** Export via Samba; Tentacle 20.2 adds integrated SMB Manager module

### Multiple active MDS (multi-rank)

Scale metadata throughput by adding MDS ranks. Each rank manages a subtree of the directory hierarchy via dynamic subtree partitioning. Clients communicate with the rank that owns the directory they are accessing.

```
ceph fs set <fsname> max_mds <N>
```

### Snapshots

CephFS supports directory-level snapshots. A snapshot is created by making a directory named `.snap/<snapshot_name>` inside the directory to protect. Snapshots are consistent across all clients that hold caps at the time.

---

## RGW — RADOS Gateway (Object Storage)

RGW is a Ceph daemon (`radosgw`) that exposes RADOS as an S3-compatible (and Swift-compatible) object store via an HTTP/REST API.

### Protocol support

- Amazon S3 (primary; nearly full API coverage)
- OpenStack Swift
- S3 Select (server-side object filtering)
- S3 Object Lock (WORM compliance)
- S3 Lifecycle rules, versioning, multipart upload
- STS (Security Token Service) for temporary credentials

### Internal storage model

RGW stores objects in RADOS. A large object is split into head + data chunks. Metadata (ACLs, user info, bucket indexes) is stored in separate RADOS pools using omap (RocksDB-backed key-value inside RADOS objects).

### Multi-site replication

RGW supports asynchronous replication between zones within a zonegroup. Zones can be active-active (with conflict resolution) or active-passive. The `radosgw-admin sync status` command shows replication lag.

### Tentacle 20.2 additions

- `GetObjectAttributes` S3 API support
- Object Lock can be enabled on existing versioned buckets
- Bucket resharding pre-processes most operations before blocking writes (less client impact)
- User Account model replaces tenant-level IAM for finer-grained access management

---

## Data Flow: Write Path

```
Client
  │  1. Compute PG: hash(object_name) % pg_num
  │  2. Compute OSDs: CRUSH(PG, OSDMap)
  │  3. Connect to primary OSD
  ▼
Primary OSD
  │  4. Write to BlueStore (WAL first, then RocksDB + data extent)
  │  5. Fan out to replica OSDs in parallel
  ▼
Replica OSDs (N-1)
  │  6. Write to BlueStore
  │  7. Acknowledge to primary
  ▼
Primary OSD
  │  8. Commit local transaction
  │  9. Acknowledge to client
  ▼
Client
     10. I/O complete
```

---

## Data Flow: Read Path

```
Client
  │  1. Compute PG and OSD list (same CRUSH calculation)
  │  2. Connect to primary OSD (or any for erasure reads)
  ▼
Primary OSD
  │  3. Check BlueStore object cache
  │  4. Query RocksDB for extent map (onode)
  │  5. Issue async block device reads for data extents
  │  6. Validate checksums
  │  7. Return data to client
```

---

## Erasure Coding

Erasure coding is an alternative to replication that uses less raw space. An EC pool with profile `k=4, m=2` splits each object into 4 data shards and 2 parity shards, tolerating 2 OSD failures while only using 1.5x raw space (vs 3x for 3-replica replication).

Trade-offs:
- Lower raw storage overhead
- Higher CPU cost on writes (encoding) and reads (partial stripe reconstruction)
- Partial writes require read-modify-write of the full stripe unless aligned

Tentacle 20.2 introduces **FastEC**: parity-delta optimization for writes and partial-read optimization that reads only minimal data to serve client requests. ISA-L (Intel Storage Acceleration Library) replaces the unmaintained Jerasure as the default erasure code plugin.

---

## Cephadm and Orchestration

Cephadm is the modern deployment and lifecycle management tool. It deploys Ceph daemons as containers (Podman or Docker) managed by systemd.

Key operations:
```bash
cephadm bootstrap --mon-ip <IP>        # Initialize first monitor
ceph orch host add <hostname> <IP>     # Add a host
ceph orch daemon add osd <host>:<dev>  # Add an OSD
ceph orch apply osd --all-available-devices  # Auto-provision OSDs
ceph orch ls                           # List services
ceph orch ps                           # List daemon instances
```

Tentacle 20.2 adds:
- `mgmt-gateway` service: nginx-based reverse proxy providing a single TLS-terminated entry point for Dashboard, Prometheus, Grafana, Alertmanager
- `oauth2-proxy` service: centralized authentication and SSO
- `certmgr` subsystem: centralized certificate lifecycle management
