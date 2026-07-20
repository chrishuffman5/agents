# Storage Foundational Concepts

## Storage Access Types

### Block Storage

Block storage presents raw storage volumes as LUNs (Logical Unit Numbers) or block devices. The host OS manages the filesystem. Protocols: iSCSI, Fibre Channel (FC), NVMe over Fabrics (NVMe-oF), FCoE.

**Characteristics:**
- Lowest latency, highest IOPS
- Host manages filesystem (ext4, XFS, NTFS, ReFS)
- No metadata sharing — single host access (unless clustered filesystem)
- Best for: databases, virtual machines, transactional workloads

### File Storage

File storage presents a shared filesystem over the network. The storage system manages the filesystem. Protocols: NFS (v3, v4, v4.1/pNFS), SMB/CIFS (2.1, 3.0, 3.1.1).

**Characteristics:**
- Multi-host concurrent access
- POSIX semantics (NFS) or Windows ACLs (SMB)
- Higher latency than block, lower than object
- Best for: shared home directories, media files, application data, container persistent volumes

### Object Storage

Object storage uses a flat namespace with HTTP-based access. Objects are immutable (replace, not update in place). Protocols: S3 API, Swift API, custom REST.

**Characteristics:**
- Unlimited scale (billions of objects)
- Rich metadata per object (user-defined + system)
- Eventual consistency for some operations (varies by implementation)
- No partial updates (replace entire object)
- Best for: backups, archives, media, data lakes, unstructured data

## Data Protection

### RAID Levels

| Level | Description | Min Disks | Capacity | Read Perf | Write Perf | Failure Tolerance |
|---|---|---|---|---|---|---|
| RAID 0 | Striping, no redundancy | 2 | 100% | Excellent | Excellent | 0 disks |
| RAID 1 | Mirroring | 2 | 50% | Good | Fair | 1 disk |
| RAID 5 | Striping + single parity | 3 | (N-1)/N | Good | Fair | 1 disk |
| RAID 6 | Striping + double parity | 4 | (N-2)/N | Good | Poor | 2 disks |
| RAID 10 | Mirrored stripes | 4 | 50% | Excellent | Good | 1 per mirror |
| RAID-DP | NetApp double parity | 3 | (N-2)/N | Good | Good | 2 disks |
| RAID-TEC | NetApp triple parity | 7 | (N-3)/N | Good | Fair | 3 disks |

**Modern trend:** Enterprise arrays abstract away RAID — they use proprietary layouts optimized for flash (e.g., Pure RAID-HA, NetApp RAID-TEC). Don't think in RAID levels; think in failure domains and rebuild times.

### Erasure Coding

Splits data into k data fragments + m parity fragments. Any k of (k+m) fragments can reconstruct the original data.

**Example:** 4+2 erasure coding = 4 data + 2 parity fragments. Tolerates loss of any 2 fragments. Storage overhead: 1.5x (vs 2x-3x for replication).

| Scheme | Data | Parity | Overhead | Fault Tolerance |
|---|---|---|---|---|
| 4+2 | 4 | 2 | 1.5x | 2 failures |
| 8+4 | 8 | 4 | 1.5x | 4 failures |
| 16+4 | 16 | 4 | 1.25x | 4 failures |
| 2+1 | 2 | 1 | 1.5x | 1 failure (like RAID 5) |

**Trade-offs:** More efficient than replication for capacity. Higher CPU overhead. Higher read latency (must read k fragments). Higher write latency (must compute and write parity). Used by: Ceph, MinIO, cloud storage backends.

### Replication

| Mode | RPO | Impact | Use Case |
|---|---|---|---|
| **Synchronous** | RPO = 0 | Write latency = local + remote | Metro-distance DR, zero data loss |
| **Asynchronous** | RPO = seconds to minutes | Minimal write impact | Long-distance DR, cross-region |
| **Semi-synchronous** | RPO ≈ 0, allows fallback | Moderate impact | Balance of protection and performance |

**Key consideration:** Synchronous replication requires low-latency links (< 5ms round trip). Beyond metro distance (~100-300 km), async is the only practical option.

### Snapshots

| Type | How It Works | Pros | Cons |
|---|---|---|---|
| **Copy-on-Write (CoW)** | Original blocks preserved; new writes go elsewhere | Fast creation, consistent | Read performance degrades with many snapshots |
| **Redirect-on-Write (RoW)** | New writes go to new location; snapshot points to originals | Better read performance | Delete is complex |
| **Clone** | Writable copy sharing blocks with parent | Space-efficient branching | Dependency on parent |

**Snapshots are not backups.** They share the same storage medium. If the array fails, snapshots are lost too. Snapshots protect against logical corruption (accidental deletion, ransomware); backups protect against physical failure.

## Data Reduction

### Deduplication

Identifies and eliminates duplicate data blocks. Can be inline (before write) or post-process (after write).

- **Fixed-length chunking**: Simple, fast, poor dedup ratio for shifted data
- **Variable-length chunking**: Better dedup ratio, higher CPU cost (Rabin fingerprinting)
- **Scope**: Volume-level, pool-level, or global (cross-volume)

**Where it helps most:** VDI (virtual desktops), backup targets, dev/test clones. **Where it doesn't help:** Encrypted data, compressed data, unique data (media, scientific).

### Compression

| Algorithm | Speed | Ratio | CPU Cost | Used By |
|---|---|---|---|---|
| LZ4 | Very fast | Low-medium | Low | NetApp (inline), Ceph |
| ZSTD | Fast | Medium-high | Medium | MinIO, newer arrays |
| Gzip | Moderate | High | High | Object storage archival |

**Inline vs post-process:** Inline compression saves space immediately but costs CPU on every write. Post-process defers CPU cost but temporarily uses more space. Most modern all-flash arrays do inline compression with hardware acceleration.

## Performance Metrics

| Metric | What It Measures | Typical Values |
|---|---|---|
| **IOPS** | I/O operations per second | SSD: 100K-1M+, HDD: 100-200 |
| **Throughput** | Data transfer rate (MB/s, GB/s) | SSD: 1-12 GB/s, HDD: 100-200 MB/s |
| **Latency** | Time per I/O operation | All-flash: 100-500µs, HDD: 5-15ms, Cloud: 1-50ms |
| **Queue Depth** | Outstanding I/O requests | Higher = more parallelism, diminishing returns past 32-64 |
| **Block Size** | Size of each I/O operation | 4K-8K (database), 64K-1M (sequential/streaming) |

**The performance triangle:** You can optimize for IOPS, throughput, or latency — but they interact. High IOPS with small block sizes doesn't mean high throughput. Measure what your workload actually needs.

### Workload Profiles

| Workload | Block Size | Pattern | Metric That Matters |
|---|---|---|---|
| OLTP database | 4K-8K | Random read/write | IOPS, latency |
| Data warehouse | 64K-256K | Sequential read | Throughput |
| Virtual machines | 4K-64K (mixed) | Random mixed | IOPS, latency |
| File shares | 4K-1M (mixed) | Mixed | Throughput, IOPS |
| Backup/restore | 256K-1M | Sequential write/read | Throughput |
| Object storage | Variable | Sequential write, random read | Throughput, latency (first byte) |

## Storage Networking

### Protocols

| Protocol | Transport | Latency | Best For |
|---|---|---|---|
| **Fibre Channel** | FC fabric (8/16/32/64 Gbps) | Lowest (< 100µs) | Enterprise SAN, mission-critical |
| **iSCSI** | Ethernet (1/10/25/100 GbE) | Low (200-500µs) | Block storage over IP, cost-effective |
| **NVMe-oF** | FC, RDMA, TCP | Very low (< 100µs) | Next-gen all-flash, latency-sensitive |
| **NFS** | Ethernet | Moderate (0.5-2ms) | File sharing, VMware datastores |
| **SMB** | Ethernet | Moderate (0.5-2ms) | Windows file shares, Hyper-V |
| **S3/HTTP** | Ethernet/Internet | Higher (1-50ms) | Object storage, cloud-native |

### Storage Tiering

Automatically moves data between performance tiers based on access patterns:

| Tier | Media | Cost | Latency | Use |
|---|---|---|---|---|
| **Hot (Tier 0)** | NVMe SSD | $$$$  | < 200µs | Active databases, real-time analytics |
| **Warm (Tier 1)** | SAS/SATA SSD | $$$ | 200-500µs | General workloads, VMs |
| **Cool (Tier 2)** | HDD / capacity SSD | $$ | 5-15ms | Infrequent access, compliance |
| **Cold (Archive)** | Tape / deep archive | $ | Minutes-hours | Legal hold, compliance, disaster recovery |
