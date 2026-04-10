# GlusterFS Architecture

## Trusted Storage Pool (TSP)

All nodes must be added to the pool via peer probing before volumes can span them.

```bash
gluster peer probe server2
gluster peer status
```

Minimum recommended: 3 nodes. A node belongs to only one TSP. TSP does not span WANs.

## Bricks

A brick is an export directory on a server node backed by a dedicated filesystem (XFS preferred, format with `isize=512`).

- `.glusterfs/` directory at brick root contains GFID-indexed hard links
- `/.glusterfs/indices/xattrop/` holds pending self-heal markers
- Never share a brick path with two volumes
- Each brick served by a dedicated `glusterfsd` process

## Volume Types

**Distributed:** Files distributed via consistent hashing. No redundancy.

**Replicated:** Every file on all bricks in replica set. Prefer replica 3 for automatic split-brain resolution.

**Arbiter (2+1):** Third brick stores only filenames and metadata (not data). Split-brain prevention at ~2x overhead. Client quorum automatically set to `auto`.

**Dispersed (Erasure Coding):** Reed-Solomon codes. Data encoded across N bricks with R redundancy. Example: 4+2 = 67% efficiency, tolerates 2 failures. High write amplification for small random writes.

**Distributed Replicated:** Most common production topology. Bricks grouped in order listed into replica sets.

**Distributed Dispersed:** Distribution + erasure coding for scale + efficiency.

## Translators (Xlators)

Composable stack of modules processing every file operation:

**Cluster translators:**
- DHT (Distributed Hash Table): assigns files to subvolumes via 32-bit hash space. Directory xattrs store hash assignments.
- AFR (Automatic File Replication): parallel writes to all replicas. Transaction model with pre-op/post-op xattr markers (`trusted.afr.*`).
- EC (Erasure Coding): Reed-Solomon encoding/decoding/reconstruction.

**Performance translators:** io-cache, write-behind, read-ahead, io-threads, md-cache, open-behind, quick-read.

**Feature translators:** quota, snapshot, geo-replication marker, locks, index.

**POSIX xlator:** Bottom-most; translates to POSIX syscalls on underlying filesystem.

## FUSE Mount

```bash
mount -t glusterfs server1:volname /mnt/gluster
# /etc/fstab:
server1:volname  /mnt/gluster  glusterfs  defaults,_netdev,log-level=WARNING  0 0
```

Key options: `_netdev`, `log-level=WARNING`, `direct-io-mode=disable` (enables kernel page cache), `attribute-timeout`/`entry-timeout`.

## NFS via NFS-Ganesha

Userspace NFS server using `libgfapi` (bypasses FUSE). NFSv3/v4/v4.1 and pNFS support. HA via Pacemaker/Corosync with virtual IP.

## SMB via Samba

`vfs_glusterfs` module accesses GlusterFS via `libgfapi`. Ctdb for HA Samba with consistent lock state.

## Geo-Replication

Asynchronous incremental replication between master and slave volumes. `gsync` daemons monitor changes via changelog translator, sync via rsync/ssh.

```bash
gluster volume geo-replication master-vol slave-server1::slave-vol create push-pem
gluster volume geo-replication master-vol slave-server1::slave-vol start
gluster volume geo-replication master-vol slave-server1::slave-vol status
```

## Self-Heal Daemon

One `glustershd` per node. Crawls `/.glusterfs/indices/xattrop/` for files with pending change markers. Determines authoritative copy and repairs out-of-date bricks.

```bash
gluster volume heal <volname> full        # Comprehensive crawl
gluster volume heal <volname> info summary
```

## Network Ports

| Service | Port |
|---|---|
| glusterd | 24007/TCP |
| Brick processes | 49152+ (one per brick) |
| NFS-Ganesha | 2049/TCP |
| SMB (Samba) | 445/TCP |
