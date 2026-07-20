# Btrfs/Snapper Architecture Reference

Deep architecture reference for Btrfs filesystem and Snapper snapshot management on SLES 15+.

---

## Copy-on-Write (CoW)

Btrfs is a B-tree filesystem built around a copy-on-write design. Every write operation creates a new copy of modified data at a new location rather than overwriting in place. The old location is freed only after the new write is committed.

### On-Disk Format

The on-disk format is a forest of B-trees. The tree of trees (root tree) points to subvolume trees, extent trees, chunk trees, checksum trees, and device trees. When a file is modified, Btrfs walks the tree from the leaf (data) up to the root, writing new copies of every node that changed. The superblock is updated atomically. The result is a crash-consistent filesystem at every write -- no journal replay is needed.

### Performance Implications

CoW introduces write amplification: a small write causes the data block, leaf node, internal nodes, and root to all be rewritten. For sequential workloads this is acceptable. For random overwrite workloads (databases, VM disk images), CoW causes:

- Fragmentation over time as contiguous files become scattered
- Write amplification proportional to tree depth
- Increased I/O latency due to metadata contention

Mitigation: `nodatacow` mount option or `chattr +C` per file/directory. This disables CoW and checksums for that inode. SLES ships `/var/lib/libvirt` with `nodatacow` recommended.

### Data and Metadata Profiles

Btrfs separates data (file content) and metadata (inodes, directory entries, extent maps) into distinct block groups, each with its own RAID profile. Single-device systems default to `single` for data, `dup` for metadata. `dup` writes two copies of metadata on the same device.

### Checksums

Every data and metadata block has a checksum stored in the checksum tree:

| Algorithm | Notes |
|---|---|
| crc32c | Hardware accelerated, fast, default pre-5.5 |
| xxhash | Faster than crc32c on modern CPUs, SLES 15 SP3+ |
| sha256 | Cryptographic, slow |
| blake2b | Cryptographic, faster than sha256 |

Specify at mkfs time: `mkfs.btrfs --checksum xxhash /dev/sda`

### Self-Healing

When a read fails checksum verification and redundant data exists (RAID 1, RAID 10, or DUP metadata), Btrfs reads the good copy and rewrites it to the corrupt location transparently. Without redundancy, checksum failures are logged but cannot be auto-repaired.

---

## Subvolumes

A subvolume is an independently mountable B-tree within the filesystem. Each has its own inode namespace and can be snapshot independently.

### SLES Default Flat Layout

All subvolumes are children of the top-level (subvolid=5) container, with `@` as the root:

```
/                   → @          (snapshotted by Snapper)
/home               → @/home     (excluded from snapshots)
/var                → @/var      (excluded)
/var/log            → @/var/log  (excluded)
/var/crash          → @/var/crash (excluded)
/var/spool          → @/var/spool (excluded)
/var/tmp            → @/var/tmp  (excluded)
/opt                → @/opt      (excluded)
/srv                → @/srv      (excluded)
/tmp                → @/tmp      (excluded)
/usr/local          → @/usr/local (excluded)
/.snapshots         → snapshot store
```

### Subvolume vs Directory

A directory is part of its parent subvolume's B-tree. A subvolume is its own B-tree root. Key differences:
- Snapshot of parent does NOT include child subvolumes
- `df` reports the entire filesystem, not per-subvolume (use qgroups for that)
- Subvolumes can be mounted independently with different mount options

### Nested vs Flat Layout

SLES uses flat layout. Flat is preferred for Snapper rollback because it allows the default subvolume to be changed without restructuring the tree.

---

## RAID Levels

Btrfs implements software RAID across multiple devices. Profiles apply separately to data and metadata block groups.

| Profile | Min Devices | Description | Production |
|---|---|---|---|
| single | 1 | No redundancy | Yes |
| dup | 1 | Two copies on same device (metadata default) | Yes |
| RAID 0 | 2 | Striping, no redundancy | Yes |
| RAID 1 | 2 | Mirror -- 2 copies on different devices | Yes |
| RAID 1C3 | 3 | Mirror -- 3 copies | Yes |
| RAID 1C4 | 4 | Mirror -- 4 copies | Yes |
| RAID 10 | 4 | Stripe of mirrors | Yes |
| RAID 5 | 3 | Parity -- **DO NOT USE** | No |
| RAID 6 | 4 | Double parity -- **DO NOT USE** | No |

RAID 5/6 have a known write hole bug causing silent data corruption during power failure.

```bash
# Check current profile
btrfs filesystem df /

# Convert between profiles
btrfs balance start -dconvert=raid1 -mconvert=raid1 /
```

---

## Snapshots

A snapshot is a subvolume that shares its initial state with another subvolume. Because of CoW, creating a snapshot is instantaneous and initially takes zero additional space.

### Space Accounting

- **Shared extents**: blocks referenced by more than one subvolume, counted once
- **Exclusive extents**: blocks referenced only by one subvolume

After a snapshot, all existing extents are shared. As the filesystem evolves, new extents become exclusive to either the snapshot or the live system.

```bash
btrfs qgroup show -reF /      # Per-subvolume shared and exclusive usage (requires qgroups)
```

---

## Compression

Btrfs supports transparent per-file compression at write time.

| Algorithm | Speed | Ratio | Recommended |
|---|---|---|---|
| zlib | Slow | High | Archival workloads |
| lzo | Fast | Low | I/O-bound workloads |
| zstd | Fast | High | Most workloads (level 3 default) |

```bash
# Mount option (new writes)
mount -o compress=zstd:3 /dev/sda2 /

# Per-subvolume property
btrfs property set / compression zstd

# Check ratio
compsize /usr   # install btrfs-compsize
```

Incompressible data (JPEG, MP4, ZIP): Btrfs detects and stops trying after the first extent. Use `chattr +m` to skip.

---

## Quota Groups (qgroups)

Qgroups enable per-subvolume space accounting. Without them, there is no way to know per-snapshot exclusive usage.

```bash
btrfs quota enable /
btrfs quota rescan /
btrfs qgroup show -reF /
btrfs qgroup limit 10G 0/256 /
```

### Hierarchy

Each subvolume gets a level-0 qgroup (0/subvolid). Higher levels (1/0, 2/0) provide group accounting.

### Performance Impact

Qgroups add 10-30% write overhead on systems with many snapshots. Each write must update qgroup accounting trees. Consider disabling if performance is critical and snapshot size reporting is not needed.

---

## Snapper Architecture

### Configuration

- `/etc/snapper/configs/root` -- root filesystem config
- `/etc/sysconfig/snapper` -- global daemon settings
- Zypper plugin: `/usr/lib/zypp/plugins/commit/snapper`

### Snapshot Types

| Type | Created By | Purpose |
|---|---|---|
| single | Manual (`snapper create`) | Point-in-time capture |
| pre | Zypper/YaST (before operation) | Pre-change state |
| post | Zypper/YaST (after operation) | Post-change state |
| timeline | systemd timer (hourly) | Scheduled snapshots |

### Cleanup Algorithms

- **Number cleanup**: Keeps most recent N snapshots (`NUMBER_LIMIT`)
- **Timeline cleanup**: Retains time-distributed set across hourly/daily/weekly/monthly
- **Empty pre-post cleanup**: Deletes pre/post pairs where no files changed

### GRUB Integration

`grub2-snapper-plugin` generates boot entries for each snapshot. At boot, selecting a snapshot mounts it as read-only root. Run `snapper rollback` from within to make permanent.
