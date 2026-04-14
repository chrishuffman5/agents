# Failover Clustering Architecture Reference

## Cluster Service Internals

### Core Processes

**Cluster Service (clussvc.exe)**

The Cluster Service is the central Windows service (NT SERVICE\ClusSvc) responsible for all cluster coordination. It runs on every cluster node and manages:

- Node membership tracking and quorum management
- Cluster database replication (CLUSDB) across nodes via the Global Update Manager
- Resource group management and failover orchestration
- Health monitoring of nodes and resources
- Network heartbeat management
- Communication with the Resource Host Subsystem (RHS) via RPC

Service dependencies: Server, Workstation, Remote Registry, and the cluster network driver (netft.sys).

**Resource Host Subsystem (rhs.exe)**

rhs.exe runs as a separate process to host resource DLLs in isolation. This design ensures a failing resource DLL does not crash clussvc.exe.

Key behaviors:
- Each resource runs within an rhs.exe process
- If RHS crashes, the Cluster Service detects it and restarts or marks resources as failed
- Separate RHS processes can be configured per resource with the `SeparateMonitor` property to further isolate unstable resources
- Resource DLLs implement the Cluster Resource API: Open, Close, Online, Offline, Terminate, LooksAlive, IsAlive callbacks

**Cluster Network Driver (netft.sys)**

NetFT (Network Fault Tolerant) is a virtual network adapter providing the abstraction layer for cluster internal communication:

- Cross-subnet heartbeats via UDP port 3343
- Automatic failover of cluster communication across multiple NICs
- Internal cluster network binding

---

## Cluster Database (CLUSDB)

CLUSDB stores the cluster configuration as a registry hive.

- **File location**: `C:\Windows\Cluster\CLUSDB` (binary hive)
- **Registry path when loaded**: `HKLM\Cluster`
- **Replication**: Synchronous via the Global Update Manager (GUM) protocol -- a write must be acknowledged by a quorum of nodes before completing
- **Contents**: Resource definitions, group configurations, network settings, quorum configuration, node properties, cluster properties

CLUSDB hive structure:
```
HKLM\Cluster\
  Nodes\          -- Per-node properties, node weight, vote status
  Groups\         -- Resource group definitions, preferred owners, failover policy
  Resources\      -- Individual resource entries, type, dependencies, parameters
  ResourceTypes\  -- Registered resource type DLLs and their properties
  Networks\       -- Cluster network definitions, role (internal/client/both)
  NetInterfaces\  -- Per-node network interface bindings
  Quorum\         -- Witness configuration, quorum type
  Parameters\     -- Global cluster parameters (cluster name, description)
```

Backup methods: `Get-ClusterLog`, Volume Shadow Copy, or `reg save HKLM\Cluster`.

Disaster recovery: If CLUSDB is corrupt on all nodes, force start with `Start-ClusterNode -FixQuorum`, then restore from backup.

---

## Global Update Manager (GUM)

GUM ensures CLUSDB consistency across all nodes using a two-phase commit protocol.

1. All CLUSDB writes route through the GUM coordinator (typically the node with the lowest node ID or the quorum resource owner)
2. **PREPARE phase**: All nodes acknowledge they can apply the update
3. **COMMIT phase**: Update applied atomically on all nodes
4. If a node does not acknowledge within the timeout, it is considered unresponsive and may be evicted

GUM operations appear in the cluster log as `[GUM]` entries. The GUM coordinator changes when the current coordinator fails or leaves the cluster.

---

## Heartbeat Mechanism

The cluster heartbeat is the primary mechanism for node liveness detection.

### Intra-Subnet Heartbeat

- Transport: UDP port 3343
- `SameSubnetDelay`: Interval between heartbeats (default: 1000ms)
- `SameSubnetThreshold`: Missed heartbeats before node is marked down (default: 5)
- Effective detection time: approximately 5 seconds on the same subnet

### Cross-Subnet Heartbeat

- `CrossSubnetDelay`: Interval between heartbeats (default: 1000ms)
- `CrossSubnetThreshold`: Missed heartbeats before marking node down (default: 5)
- Stretch clusters may require higher thresholds to tolerate WAN latency

```powershell
# View heartbeat settings
Get-Cluster | Select-Object SameSubnetDelay, SameSubnetThreshold, CrossSubnetDelay, CrossSubnetThreshold

# Tune for high-latency WAN links
(Get-Cluster).CrossSubnetDelay = 2000
(Get-Cluster).CrossSubnetThreshold = 10
```

### Network Failover

The cluster evaluates all networks in priority order for heartbeats. If a heartbeat fails on the primary network, the cluster tries secondary networks. Only when ALL networks show a node as unresponsive is the node marked Down.

### Network Quarantine

When a node loses connectivity briefly and rejoins, it enters quarantine before being fully trusted:

- `QuarantineDuration`: How long a node stays quarantined (default: 7200 seconds / 2 hours)
- `QuarantineThreshold`: Number of failures before quarantine triggers (default: 3)
- Look for `[QM]` entries in the cluster log for quarantine manager activity

---

## Cluster Shared Volumes (CSV) Architecture

CSVs allow multiple cluster nodes to simultaneously access the same NTFS or ReFS volume. This capability is essential for Hyper-V live migration, Scale-Out File Server, and SQL Server FCI deployments.

### CSV I/O Modes

**Direct I/O (normal mode)**

Each node communicates directly with the storage device. The coordinator node manages metadata operations (file creation, deletion, resize), while other nodes perform data I/O directly. This is the highest-performance mode.

**Redirected I/O**

All I/O is redirected through the CSV coordinator node over the cluster network using SMB3. This mode is triggered by:
- Storage errors or connectivity issues
- BitLocker initialization in progress
- VSS backup operations
- Maintenance mode (`Get-ClusterSharedVolume` shows state as `Redirected`)
- Storage driver issues

Redirected I/O is significantly slower than direct I/O because all data traverses the cluster network.

**CSV Cache**

A block-level read cache on each node stored in memory (separate from the Windows file cache):
- Reduces IOPS to backend storage for frequently-read data
- Configured per-cluster: `(Get-Cluster).BlockCacheSize = 1024` (value in MB)
- Not available on all editions in all versions

### CSV Coordinator Node

One node per CSV volume acts as coordinator and owns the CSV disk resource:
- Handles NTFS/ReFS metadata operations
- Manages file lock coordination
- Orchestrates VSS operations for host-level backups
- Viewable: `Get-ClusterSharedVolume` shows `OwnerNode` for each CSV

### CSV Namespace

All nodes access CSV volumes at the same deterministic path:
- `C:\ClusterStorage\Volume1`, `C:\ClusterStorage\Volume2`, etc.
- Symlink from `C:\ClusterStorage` to a cluster-managed virtual directory
- Applications use the same path regardless of which node accesses the volume

### CSV vs Non-CSV Clustered Disks

- **Non-CSV disk resources**: Owned by one node at a time, mounted only on that node. Used for SQL Server FCI data drives.
- **CSV volumes**: Accessible by all nodes simultaneously. Used for Hyper-V VMs, Scale-Out File Server shares.

---

## Quorum Models

Quorum prevents split-brain: the condition where two partitions of a cluster each believe they are authoritative, potentially causing data corruption.

### Vote Calculation

- Each cluster node has 1 vote (or 0 if dynamic quorum removes it)
- A witness contributes 1 additional vote
- Quorum achieved when: (votes present) > (total possible votes) / 2
- For N total votes, need floor(N/2) + 1 to achieve quorum

### Model Descriptions

**Node Majority (no witness)**: Requires an odd number of nodes. A 3-node cluster survives 1 failure; a 5-node cluster survives 2 failures. Not recommended for even-node counts because symmetric failure is unresolvable.

**Node and Disk Majority**: A small shared disk (minimum 512 MB, typically 1 GB) acts as the witness. The disk is a cluster resource owned by one node at a time. Traditional choice for 2-node and even-node clusters with shared storage. The disk witness stores a quorum log at its root.

**Node and File Share Majority**: A UNC file share on a server outside the cluster acts as tiebreaker. The file share stores only a small metadata file, not cluster data. The share server must NOT be a cluster member node. Best for 2-node clusters without shared storage and multi-site clusters.

**Cloud Witness (2016+)**: Uses Azure Blob Storage as the witness. Requires only an Azure Storage Account -- no Azure VM. The blob container `msft-cloud-witness` is auto-created. Resilient to datacenter-level failures. Minimal cost (blob storage only).

```powershell
Set-ClusterQuorum -CloudWitness -AccountName <storageAccount> -AccessKey <key>
```

**USB Witness (2019+)**: USB drive connected to a node or external device. Limited to specific physical deployment scenarios.

### Dynamic Quorum

Dynamic quorum (enabled by default since 2012) adjusts node vote counts automatically:
- As nodes leave cleanly (graceful shutdown, pause-drain), the cluster reduces their vote to 0
- This allows a smaller surviving set to maintain quorum
- `NodeWeight` property tracks each node's current vote (1 = voting, 0 = not voting)
- `DynamicQuorum` cluster property enables/disables this behavior

**Dynamic Witness**: The witness vote is added or removed based on cluster state. If the cluster has an odd number of node votes, the witness vote is removed (not needed). If even, it is added as a tiebreaker.

---

## Resource Model

### Built-in Resource Types

| Resource Type | Description |
|---|---|
| Physical Disk | Cluster disk resource, one owner at a time |
| IP Address | IPv4/IPv6 cluster endpoint |
| Network Name | Cluster/role DNS network name |
| File Share | SMB file share resource |
| Generic Application | Wraps any executable as a cluster resource |
| Generic Script | Wraps VBScript/PowerShell as a resource |
| Generic Service | Wraps a Windows service as a resource |
| Virtual Machine | Hyper-V VM resource |
| Scale-Out File Server | SOFS role resource |
| Distributed Network Name | Distributed name for AGs/SOFS |
| Cloud Witness | Cloud witness resource |
| SQL Server | SQL Server FCI resource |
| SQL Server Availability Group | AG resource |

### Resource States

- **Online** -- Resource is running and providing service
- **Offline** -- Resource is stopped; not in a failed state
- **Failed** -- Resource attempted to come online or stay online and failed
- **Online Pending** -- Resource is in the process of coming online
- **Offline Pending** -- Resource is in the process of going offline

### Resource Health Checks

- **LooksAlive**: Lightweight poll (default every 5 seconds). Quick check -- e.g., is the process running?
- **IsAlive**: Deep health check (default every 60 seconds). Thorough validation -- e.g., can we connect to the service?

Both check intervals are configurable per resource type.

### Resource Dependencies

Resources within a group can have AND/OR dependency relationships:
- Resource A depends on Resource B means A cannot come online until B is online
- Typical chain: Generic Service -> Network Name -> IP Address -> Physical Disk
- OR dependencies: Resource A depends on (IP1 OR IP2) for multi-subnet clustering

```powershell
Get-ClusterResourceDependency -Resource "SQL Server (MSSQLSERVER)"
```

---

## Cluster Networks

### Network Roles

| Role Value | Name | Purpose |
|---|---|---|
| 0 | None | Not used for cluster communication |
| 1 | Cluster Only | Internal cluster heartbeat only |
| 2 | Client Access Only | Client connections only (no heartbeat) |
| 3 | All (Cluster + Client) | Both -- acceptable for small clusters, not ideal |

### Network Priority

When multiple cluster networks exist, the cluster uses them in priority order based on metric (lower = higher priority):

```powershell
Get-ClusterNetwork | Sort-Object Metric | Select-Object Name, State, Role, Metric
(Get-ClusterNetwork "Cluster Network 1").Metric = 1000
```

### Multi-Subnet Clustering

Multi-subnet clustering places nodes in different IP subnets for stretch/geo clusters:
- OR dependencies on IP Address resources allow a network name to respond on multiple subnets
- `RegisterAllProvidersIP` on the Network Name resource: 1 = register all IPs (multi-subnet), 0 = register only the online IP
- `HostRecordTTL` controls DNS TTL for the cluster name (lower = faster failover DNS propagation)

```powershell
# Stretch cluster WAN tuning
(Get-Cluster).CrossSubnetDelay = 2000
(Get-Cluster).CrossSubnetThreshold = 10
(Get-Cluster).RouteHistoryLength = 20
```

### Live Migration Network

For Hyper-V clusters, live migration traffic is configured separately from cluster heartbeat and CSV traffic:
- Configured in Hyper-V settings, not cluster settings
- Dedicated high-bandwidth network recommended (10 GbE+)
- Supports compression and SMB Direct (RDMA)
- Priority: SMB Direct > TCP/IP with compression > TCP/IP uncompressed
