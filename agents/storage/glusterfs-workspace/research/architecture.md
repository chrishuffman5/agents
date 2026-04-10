# GlusterFS Architecture

## Overview

GlusterFS is a free and open-source, scalable network filesystem that aggregates disk storage resources from multiple servers into a single global namespace. It is designed around a client-server model with no central metadata server, instead distributing metadata across the cluster using consistent hashing and extended attributes stored directly on the filesystem.

The three key runtime components are:
- **glusterd** — Management daemon running on every server node, handles peer probing, volume configuration, and cluster state.
- **glusterfsd** — Brick process, one per brick per volume; exports the underlying XFS/ext4/ZFS directory over the internal protocol.
- **glusterfs (client)** — Mounts the volume on client nodes; implements the full translator stack in userspace.

---

## Trusted Storage Pool (TSP)

The Trusted Storage Pool is the foundational cluster membership group. All nodes that will contribute storage must be added to the pool via peer probing before any volume can be created across them.

```bash
# On any one node, probe each peer
gluster peer probe server2
gluster peer probe server3
gluster peer probe server4

# Verify membership
gluster peer status
```

Key properties:
- Membership is symmetric: probing from node A adds both A and the target to each other's peer list.
- `glusterd` on each node maintains the pool state in `/var/lib/glusterd/`.
- A node can belong to only one TSP at a time.
- The TSP does not span WANs; geo-replication handles cross-site replication separately.
- Minimum recommended pool size is 3 nodes to avoid split-brain at the pool level.

---

## Bricks

A **brick** is the fundamental unit of storage in GlusterFS. It is an export directory on a server node within the TSP, typically backed by a dedicated filesystem on a separate disk or RAID set.

```
server1:/data/glusterfs/myvol/brick1/data
```

Brick anatomy:
- The exported path (e.g., `/data/glusterfs/myvol/brick1`) is the brick root.
- A subdirectory (e.g., `/data/glusterfs/myvol/brick1/data`) is commonly used as the actual export to keep GlusterFS metadata files (`.glusterfs/`) separate from user data.
- `.glusterfs/` is a hidden directory at the brick root containing hard links indexed by GFID (GlusterFS Internal File Identifier), the inode-independent UUID assigned to every file.
- `/.glusterfs/indices/xattrop/` holds pending self-heal markers.

Brick requirements:
- Must be on a local filesystem with xattr support (XFS strongly preferred; format with `isize=512`).
- Never share a brick path with two volumes.
- Each brick is served by a dedicated `glusterfsd` process.

---

## Volume Types

A **volume** is a logical grouping of bricks that presents a unified namespace to clients. Volume type determines data distribution, redundancy, and performance characteristics.

### Distributed Volume

Files are distributed across bricks using consistent hashing. No redundancy; a brick failure causes data loss for files on that brick.

```bash
gluster volume create dist-vol transport tcp \
  server1:/data/brick1/data \
  server2:/data/brick2/data \
  server3:/data/brick3/data
```

- Use case: Maximum capacity with no redundancy requirement, or when underlying hardware (RAID) already provides redundancy.
- Scaling: Add bricks in any quantity.

### Replicated Volume

Every file is stored on all bricks in a replica set. Survives failure of all but one replica without data loss.

```bash
# 2-way replica (mirror)
gluster volume create rep-vol replica 2 transport tcp \
  server1:/data/brick1/data \
  server2:/data/brick2/data

# 3-way replica (recommended; avoids split-brain)
gluster volume create rep-vol replica 3 transport tcp \
  server1:/data/brick1/data \
  server2:/data/brick2/data \
  server3:/data/brick3/data
```

- Use case: High availability and data durability for critical workloads.
- Penalty: N× storage overhead where N is replica count.
- Strongly prefer replica 3 over replica 2 to allow automatic split-brain resolution via quorum.

### Arbiter Volume (Replica 2+1)

A special form of replica 3 where the third brick (arbiter) stores only file names and metadata (xattrs), not actual file data. This gives split-brain prevention at roughly 2× storage cost instead of 3×.

```bash
gluster volume create arb-vol replica 2 arbiter 1 transport tcp \
  server1:/data/brick1/data \
  server2:/data/brick2/data \
  server3:/data/arbiter/data
```

- The arbiter brick participates in quorum decisions and stores GFIDs/xattrs but not file content.
- Client quorum is automatically set to `auto` (2 of 3 bricks required for writes to succeed).

### Dispersed Volume (Erasure Coding)

Based on Reed-Solomon erasure codes. Data is encoded and spread across N bricks with R redundancy bricks. Can tolerate R simultaneous brick failures without data loss, using less storage than equivalent replication.

```bash
# 4+2 disperse (4 data fragments, 2 redundancy; tolerates 2 failures)
gluster volume create disp-vol disperse 6 redundancy 2 transport tcp \
  server{1..6}:/data/brick1/data

# Explicit disperse-data syntax
gluster volume create disp-vol disperse-data 4 redundancy 2 transport tcp \
  server1:/data/brick1/data server2:/data/brick2/data \
  server3:/data/brick3/data server4:/data/brick4/data \
  server5:/data/brick5/data server6:/data/brick6/data
```

- Storage efficiency: (N-R)/N × total raw capacity. A 4+2 config uses 67% of raw capacity vs 33% for replica 3.
- Implemented by the EC (Erasure Coding) translator using Galois Field GF(2^8) arithmetic and SIMD-optimized matrix multiplication.
- Stripe size = 512 × (N - R) bytes. Write amplification affects small random writes significantly.
- Use case: Archival, large-file sequential workloads where storage efficiency matters more than write latency.

### Distributed Replicated Volume

Combines distribution and replication. Files are distributed across multiple replica sets. This is the most common production topology.

```bash
# 2-replica across 4 nodes (2 replica sets of 2)
gluster volume create dr-vol replica 2 transport tcp \
  server1:/data/brick1/data server2:/data/brick2/data \
  server3:/data/brick3/data server4:/data/brick4/data

# 3-replica across 6 nodes (2 replica sets of 3)
gluster volume create dr-vol replica 3 transport tcp \
  server1:/data/brick1/data server2:/data/brick2/data server3:/data/brick3/data \
  server4:/data/brick4/data server5:/data/brick5/data server6:/data/brick6/data
```

- Brick order matters: bricks are grouped into replica sets in the order listed. First R bricks form replica set 1, next R bricks form replica set 2, etc.
- Scaling: Add bricks in multiples of replica count.
- Use case: General-purpose production storage combining horizontal scale with HA.

### Distributed Dispersed Volume

Files distributed across multiple dispersed subvolumes. Combines the capacity scaling of distribution with the storage efficiency of erasure coding.

```bash
gluster volume create dd-vol disperse 3 redundancy 1 transport tcp \
  server1:/br1 server2:/br1 server3:/br1 \
  server1:/br2 server2:/br2 server3:/br2
```

- Total bricks must be a multiple of the disperse count.

---

## Translators (Xlators)

GlusterFS is built entirely on a stack of composable **translators** (xlators). Every file operation passes through the stack from top (client or mount) to bottom (brick/IO). Each translator performs a specific function and passes the request to its child.

```
Application
    |
  VFS (kernel)
    |
 FUSE (kernel module)
    |
[Client Process / glusterfs]
    |
  Protocol Client xlator  <---- network ---->  Protocol Server xlator
                                                      |
                                              [glusterfsd / brick process]
                                                      |
                                                 POSIX xlator
                                                      |
                                              Underlying filesystem (XFS)
```

### Key Translator Categories

**Mount/Protocol translators**
- `fuse` — Interfaces the VFS kernel layer with the userspace GlusterFS client via `/dev/fuse`.
- `protocol/client` — Sends operations over the wire to brick processes.
- `protocol/server` — Receives operations on brick nodes and dispatches to local xlators.

**Cluster translators** (manage distribution and replication)
- `DHT (Distributed Hash Table)` — Core distribution translator. Assigns each file to exactly one subvolume (brick or replica set) by hashing the filename into a 32-bit hash space. Each subvolume is assigned a non-overlapping range of the hash space; assignments are stored in directory xattrs (`trusted.glusterfs.dht`). Responsible for rebalancing during expansion.
- `AFR (Automatic File Replication)` — Implements replication. For every write, AFR sends the operation to all bricks in the replica set in parallel. Uses a transaction model with pre-op/post-op xattr markers (`trusted.afr.*`) to track pending operations. The self-heal daemon uses these markers to detect and repair inconsistencies.
- `EC (Erasure Coding)` — Implements dispersed volumes using Reed-Solomon codes. Handles encoding, decoding, and reconstruction from fragments.

**Performance translators**
- `io-cache` — Read cache for frequently accessed data.
- `write-behind` — Buffers writes and acknowledges early; flushes asynchronously (configurable window size).
- `read-ahead` — Prefetches data for sequential reads.
- `io-threads` — Threadpool for parallelizing IO operations on the server side.
- `md-cache` — Caches metadata (stat, xattr) to reduce RPC calls.
- `open-behind` — Delays open() calls until actual IO is needed.
- `quick-read` — Reads small files in a single RPC together with the open.

**Feature translators**
- `quota` — Enforces directory and volume space limits.
- `snapshot` — Manages volume snapshots (integrates with LVM thin provisioning or ZFS).
- `geo-replication (marker)` — Tracks changes for geo-replication via a changelog.
- `locks` — Provides inode and entry locks (`inodelk`, `entrylk`) used by AFR for synchronization.
- `index` — Maintains the `/.glusterfs/indices/xattrop/` directory used by AFR and the self-heal daemon.

**POSIX xlator**
- The bottom-most translator on brick nodes; translates GlusterFS file operations into standard POSIX syscalls against the underlying filesystem.

---

## FUSE Mount

GlusterFS uses FUSE (Filesystem in Userspace) to mount volumes on client nodes without kernel filesystem drivers.

Request flow:
1. Application issues a syscall (e.g., `read()`).
2. Kernel VFS routes the call to the FUSE kernel module.
3. FUSE module forwards the request to the GlusterFS client process via `/dev/fuse`.
4. GlusterFS client processes the request through its translator stack (DHT → AFR or EC → Protocol/Client).
5. Protocol/Client sends RPC calls to the appropriate brick process(es) over TCP (or RDMA).
6. Brick processes execute the operation on local storage and return responses.
7. Response travels back through the client translator stack to FUSE, then to the application.

```bash
# Basic FUSE mount
mount -t glusterfs server1:volname /mnt/gluster

# With options (recommended for production)
mount -t glusterfs -o log-level=WARNING,log-file=/var/log/glusterfs/mnt-vol.log \
  server1:volname /mnt/gluster

# /etc/fstab entry
server1:volname  /mnt/gluster  glusterfs  defaults,_netdev,log-level=WARNING  0 0
```

Key mount options:
- `_netdev` — Ensures network is available before mounting at boot.
- `log-level=WARNING` — Reduces log verbosity (default is INFO).
- `direct-io-mode=disable` — Disables direct IO to allow kernel page cache (beneficial for workloads with repeated reads).
- `attribute-timeout=0` / `entry-timeout=0` — Disables attribute caching for consistency-sensitive workloads.

---

## NFS and SMB Gateways

### NFS via NFS-Ganesha

GlusterFS ships a built-in NFSv3 server (now deprecated in favor of NFS-Ganesha). NFS-Ganesha is a userspace NFS server that uses the `libgfapi` library to access GlusterFS volumes directly (without FUSE), providing NFSv3, NFSv4, NFSv4.1, and pNFS support.

```bash
# Install
dnf install nfs-ganesha nfs-ganesha-gluster

# Minimal /etc/ganesha/ganesha.conf
EXPORT {
    Export_Id = 1;
    Path = "/myvol";
    FSAL {
        name = GLUSTER;
        hostname = "localhost";
        volume = "myvol";
    }
    Access_type = RW;
    Squash = No_root_squash;
    Protocols = 4;
    Transports = TCP;
    SecType = sys;
}

# Start
systemctl start nfs-ganesha
```

pNFS (Parallel NFS) support allows clients to read/write directly to GlusterFS bricks in parallel. Requires `features.cache-invalidation` enabled on the volume:
```bash
gluster volume set myvol features.cache-invalidation on
```

For HA NFS, use Pacemaker/Corosync with a virtual IP to provide a failover NFS endpoint backed by multiple NFS-Ganesha instances accessing the same GlusterFS volume.

### SMB via Samba

GlusterFS volumes are exported as SMB/CIFS shares using Samba with the `vfs_glusterfs` VFS module, which accesses GlusterFS via `libgfapi` (bypassing FUSE for better performance).

```bash
# smb.conf
[glustershare]
    comment = GlusterFS Volume Share
    path = /
    vfs objects = glusterfs
    glusterfs:volume = myvol
    glusterfs:loglevel = 7
    glusterfs:logfile = /var/log/samba/glusterfs.log
    read only = no
    guest ok = no
```

Ctdb (Clustered TDB) is used for HA Samba deployments to maintain consistent lock state across multiple Samba nodes serving the same GlusterFS volume.

---

## Geo-Replication

Geo-replication provides asynchronous, incremental replication between a **master** GlusterFS volume and a **slave** GlusterFS volume, typically at a geographically remote site. It is used for disaster recovery and data locality.

Architecture:
- A `gsync` daemon runs on each node of the master volume, monitoring changes.
- Changes are detected via the **changelog** translator, which logs all file operations.
- `gsync` syncs changes to the slave using `rsync`/`ssh` over the WAN.
- One node of the master connects to one node of the slave via passwordless SSH; the slave-side gsyncd daemon is launched through SSH.

```bash
# Prerequisites: passwordless SSH from master node to slave node
ssh-keygen
ssh-copy-id root@slave-server1

# Create the geo-replication session
gluster volume geo-replication master-vol slave-server1::slave-vol create push-pem

# Start geo-replication
gluster volume geo-replication master-vol slave-server1::slave-vol start

# Monitor status
gluster volume geo-replication master-vol slave-server1::slave-vol status

# Stop and delete
gluster volume geo-replication master-vol slave-server1::slave-vol stop
gluster volume geo-replication master-vol slave-server1::slave-vol delete
```

Session states: `Initializing` → `Not Started` → `Active` (syncing) / `Passive` (standby on non-primary nodes).

Configuration options:
```bash
gluster volume geo-replication master-vol slave::slave-vol config sync-jobs 3
gluster volume geo-replication master-vol slave::slave-vol config checkpoint now
```

---

## Self-Heal Daemon

The **Self-Heal Daemon (shd)** runs as a separate process on every node in the TSP. Its job is to proactively repair files on bricks that were offline and missed writes while other replicas continued to serve IO.

- One `glustershd` process per node handles all replicated/dispersed volumes on that node.
- The shd periodically crawls `/.glusterfs/indices/xattrop/` on local bricks to find files with pending change markers.
- For each candidate file, it determines which brick has the authoritative copy and copies data to the out-of-date bricks.
- Manual heal trigger: `gluster volume heal <volname> full`
- Self-heal can be disabled per volume: `gluster volume set <volname> cluster.self-heal-daemon off` (not recommended for production).
- Log: `/var/log/glusterfs/glustershd.log`

---

## Network Ports

| Service | Port |
|---|---|
| glusterd (management) | 24007/TCP |
| Brick processes | 49152+ (one per brick) |
| Built-in NFS | 38465-38467/TCP, 111/TCP (portmap) |
| NFS-Ganesha | 2049/TCP, 111/TCP |
| SMB (Samba) | 445/TCP, 139/TCP |

Firewall rules must allow all inter-node communication on port 24007 and the dynamic brick port range.
