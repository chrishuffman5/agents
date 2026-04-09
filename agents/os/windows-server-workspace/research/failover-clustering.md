# Windows Server Failover Clustering (WSFC) — Deep-Dive Research
## For Opus Writer Agent: Feature Sub-Agent Generation

---

## PART 1: CLUSTER ARCHITECTURE

### 1.1 Core Services and Processes

**Cluster Service (clussvc.exe)**
The Cluster Service is the central Windows service (NT SERVICE\ClusSvc) responsible for all cluster coordination. It runs on every cluster node and performs:
- Node membership tracking and quorum management
- Cluster database replication (CLUSDB) across nodes
- Resource group management and failover orchestration
- Health monitoring of nodes and resources
- Network heartbeat management
- Communication with Resource Host Subsystem (RHS)

The service depends on: Server, Workstation, Remote Registry, and the cluster network driver (netft.sys — the NetFT virtual adapter that underpins cluster communication).

**Resource Host Subsystem (rhs.exe)**
rhs.exe runs as a separate process (one or more instances) to host resource DLLs. This isolation means a failing resource DLL does not crash clussvc.exe itself. Key behaviors:
- Each resource runs within an rhs.exe process; if RHS crashes, the Cluster Service detects it and restarts or marks resources as failed
- Separate RHS processes can be configured per resource to further isolate unstable resources (`SeparateMonitor` resource property)
- RHS communicates with clussvc via RPC
- Resource DLLs implement the Cluster Resource API: Open, Close, Online, Offline, Terminate, LooksAlive, IsAlive callbacks

**Cluster Network Driver (netft.sys)**
NetFT (Network Fault Tolerant) is a virtual network adapter that provides the abstraction layer for cluster internal communication. It handles:
- Cross-subnet cluster heartbeats via UDP port 3343
- Automatic failover of cluster communication across multiple NICs
- Internal cluster network binding

### 1.2 Cluster Database (CLUSDB)

CLUSDB is the cluster configuration database, stored in the Windows registry hive at:
- Path: `C:\Windows\Cluster\CLUSDB` (binary hive file)
- Registry path when loaded: `HKLM\Cluster`

Key characteristics:
- Replicated to all active cluster nodes using the Global Update Manager (GUM) protocol
- Transactions are synchronous — a write must be acknowledged by a quorum of nodes before completing
- Contains: resource definitions, group configurations, network settings, quorum configuration, node properties, cluster properties
- Backed up via: `Get-ClusterLog`, Volume Shadow Copy, or `reg save HKLM\Cluster`
- Can be queried directly: `reg query HKLM\Cluster`
- Disaster recovery: If CLUSDB is corrupt on all nodes, forced start with `/fixquorum` flag required, then restore from backup

**CLUSDB Structure (key hive paths):**
```
HKLM\Cluster\
  Nodes\          — per-node properties, node weight, vote status
  Groups\         — resource group definitions, preferred owners, failover policy
  Resources\      — individual resource entries, type, dependencies, parameters
  ResourceTypes\  — registered resource type DLLs and their properties
  Networks\       — cluster network definitions, role (internal/client/both)
  NetInterfaces\  — per-node network interface bindings
  Quorum\         — witness configuration, quorum type
  Parameters\     — global cluster parameters (cluster name, description, etc.)
```

### 1.3 Global Update Manager (GUM)

GUM is the protocol that ensures CLUSDB consistency across all nodes:
- All CLUSDB writes go through the GUM coordinator (one node elected as GUM master, typically the node that owns the quorum resource or has lowest node ID)
- GUM uses two-phase commit: PREPARE phase (all nodes acknowledge they can apply the update), COMMIT phase (update applied)
- If a node does not acknowledge within the timeout, the node is considered unresponsive and may be evicted
- GUM operations are logged in the cluster log as `[GUM]` entries
- GUM master changes when the current GUM master fails or leaves the cluster

### 1.4 Heartbeat Mechanism

The cluster heartbeat is the primary mechanism for node liveness detection:

**Intra-subnet heartbeat:**
- UDP port 3343 (cluster communication port)
- Default heartbeat interval: 1000ms (1 second), configurable via `CrossSubnetDelay` (actually `SameSubnetDelay` = 1000ms by default)
- Default missed heartbeat threshold before node considered down: 5 (`SameSubnetThreshold`)
- Effective detection time: ~5 seconds on same subnet

**Cross-subnet heartbeat:**
- `CrossSubnetDelay` = 1000ms default (increased from same subnet in older versions)
- `CrossSubnetThreshold` = 5 default
- Stretch clusters may need tuning: higher thresholds for WAN latency

**Cluster network priority:**
- Cluster evaluates all networks in priority order for heartbeats
- If a heartbeat fails on the primary network, tried on secondary networks
- If ALL networks show node unresponsive, node is marked Down

**Network quarantine:**
- When a node loses connectivity briefly and rejoins, it enters a quarantine period before being fully trusted
- `QuarantineDuration` controls how long a node stays quarantined (default 7200 seconds / 2 hours)
- `QuarantineThreshold` controls number of failures before quarantine triggers (default 3)

**PowerShell heartbeat parameters:**
```powershell
# View current heartbeat settings
Get-Cluster | Select-Object SameSubnetDelay, SameSubnetThreshold, CrossSubnetDelay, CrossSubnetThreshold

# Adjust for high-latency environments
(Get-Cluster).CrossSubnetDelay = 2000
(Get-Cluster).CrossSubnetThreshold = 10
```

### 1.5 Cluster Shared Volumes (CSV) Architecture

CSVs allow multiple cluster nodes to simultaneously access the same NTFS or ReFS volume from different nodes, critical for Hyper-V live migration and SQL Server FCI.

**CSV I/O Modes:**

1. **Direct I/O (normal mode):**
   - Each node communicates directly with the storage device
   - Node that owns the CSV partition manages metadata operations
   - Other nodes access the CSV directly but route metadata to the coordinator
   - Highest performance mode

2. **Redirected I/O:**
   - All I/O redirected through the CSV coordinator node over the cluster network
   - Triggered by: storage errors, BitLocker enabling on CSV, storage driver issues, backup operations (VSS), maintenance mode
   - Significantly slower than direct I/O — SMB3 traffic on cluster network
   - State viewable: `Get-ClusterSharedVolume | Select Name, State`

3. **CSV Cache:**
   - Block-level read cache on each node in memory (separate from Windows cache)
   - Reduces IOPS to storage for frequently read data
   - Configured per-cluster: `(Get-Cluster).BlockCacheSize = 1024` (MB)
   - Only available on Windows Server editions (not Standard in all versions)

**CSV Coordinator Node:**
- One node per CSV volume acts as coordinator (owns the CSV disk resource)
- Coordinator handles: NTFS metadata, lock management, VSS coordination
- `Get-ClusterSharedVolume` shows `OwnerNode` for each CSV

**CSV Namespace:**
- All nodes access CSV at the same path: `C:\ClusterStorage\Volume1`, `C:\ClusterStorage\Volume2`, etc.
- Symlink from `C:\ClusterStorage` → cluster-managed virtual directory
- Applications use same path regardless of which node accesses the volume

**CSV vs Non-CSV Clustered Disks:**
- Non-CSV disk resources: owned by one node at a time, mounted only on that node
- CSV volumes: accessible by all nodes simultaneously (Hyper-V VMs, Scale-Out File Server)

---

## PART 2: QUORUM MODELS

### 2.1 Quorum Fundamentals

Quorum prevents split-brain: the condition where two partitions of a cluster each believe they are the authoritative cluster, potentially causing data corruption. The cluster can only operate when a quorum of votes is present.

**Vote calculation:**
- Each cluster node has 1 vote (or 0 if dynamic quorum removes it)
- Witness contributes 1 additional vote
- Quorum achieved when: (votes present) > (total possible votes) / 2
- For N total votes, need floor(N/2) + 1 to achieve quorum

### 2.2 Quorum Models

**Node Majority (no witness):**
- Requires odd number of nodes
- Best for: 3-node, 5-node, 7-node clusters where any witness would be problematic
- 3-node: survives 1 node failure (2 of 3 votes remain)
- 5-node: survives 2 node failures (3 of 5 votes remain)
- Not recommended for even-node counts (symmetric failure scenarios)

**Node and Disk Majority (Disk Witness):**
- Witness disk is a small shared disk (minimum 512MB, typically 1GB)
- Disk must be in a resource group owned by one node at a time
- Traditional choice for 2-node clusters and even-node clusters
- Disadvantage: storage is a single point of failure for quorum
- Disk witness provides 1 vote; the node owning the disk group holds this vote
- Disk witness stores quorum log at root of witness disk

**Node and File Share Majority (File Share Witness):**
- A UNC file share on a server outside the cluster acts as tiebreaker
- Best for: 2-node clusters where a shared disk is not available, multi-site clusters
- File share must be accessible from all nodes
- Does not store data from the cluster, just a small metadata file
- File share server should NOT be a cluster member node
- File share host should have high availability (e.g., a DFS namespace target, another server)

**Cloud Witness (introduced Windows Server 2016):**
- Uses Azure Blob Storage as the witness
- Requires: Azure subscription, Storage Account (general purpose), storage account key or SAS token
- No Azure VM required — just blob storage API accessibility
- Resilient to datacenter-level failures
- Ideal for: multi-site clusters, clusters where a file share witness location is unavailable
- Configuration: `Set-ClusterQuorum -CloudWitness -AccountName <name> -AccessKey <key>`
- Blob container name: `msft-cloud-witness` (auto-created)
- Blob name: cluster name (one blob per cluster)
- Cost: minimal Azure blob storage costs only

**USB Witness (introduced Windows Server 2019):**
- USB drive connected to a node or external device
- Adds flexibility for physical environments
- Limited to specific deployment scenarios

### 2.3 Dynamic Quorum

Dynamic quorum (enabled by default since Windows Server 2012) allows the cluster to adjust node vote counts automatically:
- As nodes leave cleanly (graceful shutdown, pause-drain), the cluster reduces their vote to 0
- This allows a smaller surviving set to still meet quorum
- Example: 4-node cluster, node 4 goes offline — cluster adjusts to treat it as 3-node, allowing 2 survivors to maintain quorum (without dynamic quorum, losing 2 of 4 nodes loses quorum)
- `NodeWeight` property tracks current vote (1 = voting, 0 = not voting)
- `DynamicQuorum` cluster property enables/disables this behavior

**Dynamic Witness:**
- Witness vote is dynamically added/removed based on cluster state
- If cluster has odd votes, witness vote is removed (not needed)
- If cluster has even votes, witness vote is added (tiebreaker needed)
- Prevents the witness from being the vote that tips quorum the wrong way

### 2.4 Quorum Loss and Recovery

**When quorum is lost:**
- All cluster resources immediately go offline (ungraceful stop)
- Cluster service stops on all remaining nodes
- Windows Event ID 1146 logged: "The cluster quorum resource failed"

**Forced quorum start (last resort):**
```powershell
# Force start cluster ignoring quorum — use only to recover, then fix quorum
Start-ClusterNode -FixQuorum

# Legacy net.exe approach:
# net start clussvc /fixquorum
```

**After forced start:**
1. Identify why quorum was lost (network partition, witness failure, simultaneous node failures)
2. Restore missing nodes or reconfigure witness
3. Restart cluster service normally on all nodes before returning to production
4. `Stop-ClusterNode` on forced-start node, verify quorum configuration, restart normally

**Quorum investigation events:**
- Event ID 1177: "The cluster lost the connection to cluster node"
- Event ID 1146: "The cluster quorum resource failed"
- Event ID 1135: "Cluster node was removed from the active failover cluster membership"
- Event ID 1069: "Cluster resource failed" (includes quorum resource failures)

---

## PART 3: RESOURCE MODEL

### 3.1 Resource Types

**Built-in resource types:**

| Resource Type | Description | Key Properties |
|---|---|---|
| Physical Disk | Cluster disk resource, one owner at a time | DiskSignature, DiskIdGuid |
| IP Address | IPv4/IPv6 cluster IP | Address, SubnetMask, Network |
| IPv6 Address | IPv6 cluster endpoint | Address, PrefixLength |
| Network Name | Cluster/role network name (DNS) | Name, DnsName, RegisterAllProvidersIP |
| File Share | SMB file share resource | ShareName, Path, ShareSubDirectories |
| Generic Application | Wraps any .exe as a cluster resource | CommandLine, CurrentDirectory |
| Generic Script | Wraps VBScript/PowerShell as resource | ScriptFilepath |
| Generic Service | Wraps Windows service as resource | ServiceName, StartupParameters |
| DFS Replicated Folder | DFS-R folder resource | ReplicationGroupName |
| NFS Share | NFS exported share | — |
| Virtual Machine | Hyper-V VM (most common in guest clusters) | VmId |
| Virtual Machine Configuration | Hyper-V VM configuration | VmId |
| Scale-Out File Server | SOFS role resource | — |
| Distributed Network Name | ANS/SOFS distributed name | — |
| Cloud Witness | Cloud witness resource | AccountName, EndpointInfo |
| Storage QoS Policy | Storage QoS integration | PolicyId |
| MSDTC | Distributed Transaction Coordinator | — |
| SQL Server | SQL Server FCI resource | InstanceName |

### 3.2 Resource States

Resources cycle through these states:
- **Online** — resource is running and providing service
- **Offline** — resource is stopped; not in failed state
- **Failed** — resource attempted to come online or stay online and failed
- **Online Pending** — resource is in the process of coming online
- **Offline Pending** — resource is in the process of going offline
- **Inherited** — resource state is controlled by its group

**Resource health checks:**
- **LooksAlive** — lightweight poll (default every 5 seconds) — quick check, e.g., is the process running
- **IsAlive** — deeper health check (default every 60 seconds) — thorough check, e.g., can we connect to the service
- Both configured per resource type and can be customized

### 3.3 Resource Groups (Roles)

Resource groups (called "Roles" in the GUI) are the unit of failover. A group contains related resources that move together:
- Groups have preferred owners (ordered list of nodes that should own the group)
- Groups have possible owners (nodes that the group can fail over to)
- Failover policy: maximum failures (default 3) in a period (default 6 hours) before the group is left in Failed state
- Failback policy: whether to fail back to preferred owner when it returns, and when (immediate or windowed)

**Resource dependencies:**
- Resources within a group can have dependency relationships (AND/OR logic)
- Resource A depends on Resource B means A cannot come online until B is online
- Dependency chain example: Generic Service → Network Name → IP Address → Physical Disk
- OR dependencies: Resource A depends on (IP1 OR IP2) — useful for multi-subnet clustering
- View: `Get-ClusterResourceDependency -Resource "SQL Server (MSSQLSERVER)"`

### 3.4 Failover Policies

Per-group failover configuration:
```powershell
# View group failover settings
Get-ClusterGroup "SQL Server (MSSQLSERVER)" | Select-Object *

# Key properties:
# FailoverThreshold    — max failures before leaving in failed state (default 3)
# FailoverPeriod       — time window for counting failures, in hours (default 6)
# AutoFailbackType     — 0=Prevent, 1=Allow, 2=Allow with window
# FailbackWindowStart  — hour (0-23) failback window opens
# FailbackWindowEnd    — hour (0-23) failback window closes

# Set aggressive failover (10 failures per 1 hour)
(Get-ClusterGroup "SQL Server (MSSQLSERVER)").FailoverThreshold = 10
(Get-ClusterGroup "SQL Server (MSSQLSERVER)").FailoverPeriod = 1
```

**Restart policies (per resource):**
- `RestartAction`: 0 = Do not restart, 1 = Restart, 2 = Restart and fail over
- `RestartThreshold`: number of restarts allowed within `RestartPeriod`
- `RestartPeriod`: time window (ms) for counting restarts
- `RetryPeriodOnFailure`: time to wait before retrying (ms)

---

## PART 4: CLUSTER NETWORKS

### 4.1 Network Roles

Each cluster network adapter has a role classification:

| Role Value | Name | Purpose |
|---|---|---|
| 0 | None | Not used for cluster communication |
| 1 | Cluster Only | Used only for internal cluster communication (heartbeat) |
| 2 | Client Access Only | Used only for client connections (not heartbeat) |
| 3 | All (Cluster and Client) | Used for both — less ideal, acceptable for small clusters |

**Best practice:** Dedicate separate NICs for cluster heartbeat (Role=1) and client access (Role=2).

### 4.2 Network Priority

When multiple cluster networks are available, the cluster uses them in priority order:
```powershell
# View network priority
Get-ClusterNetwork | Sort-Object Metric | Select-Object Name, State, Role, Metric

# Set network metric (lower = higher priority)
(Get-ClusterNetwork "Cluster Network 1").Metric = 1000
(Get-ClusterNetwork "Cluster Network 2").Metric = 2000
```

### 4.3 Multi-Subnet Clustering

Multi-subnet clustering allows nodes in different IP subnets to be members of the same cluster (stretch/geo clusters or multi-site clusters):
- OR dependencies on IP Address resources allow the same network name to respond on multiple subnets
- Each subnet has its own IP Address resource; clients in each subnet use the local IP
- DNS registration: cluster registers all IP addresses with DNS; clients use the closest (via TTL and DNS scavenging)
- `RegisterAllProvidersIP` on Network Name resource: 1 = register all IPs (multi-subnet), 0 = register only online IP
- `HostRecordTTL` property controls DNS TTL for cluster name (lower = faster failover DNS propagation)

**Cross-subnet heartbeat tuning for WAN:**
```powershell
# For stretch clusters with high latency
(Get-Cluster).CrossSubnetDelay = 2000      # ms between heartbeats
(Get-Cluster).CrossSubnetThreshold = 10   # missed beats before node marked down
(Get-Cluster).RouteHistoryLength = 20     # network route cache size
```

### 4.4 Live Migration Network

For Hyper-V clusters, live migration traffic is separate from cluster heartbeat and CSV traffic:
- Configured in Hyper-V settings, not cluster settings
- Should use a dedicated high-bandwidth network (10Gbps recommended)
- Compression and SMB Direct (RDMA) supported for live migration
- Priority: SMB Direct > TCP/IP with compression > TCP/IP uncompressed

---

## PART 5: BEST PRACTICES — CLUSTER DESIGN

### 5.1 Hardware Requirements

**Minimum requirements:**
- All nodes must pass cluster validation (`Test-Cluster`)
- Shared storage visible to all nodes (for traditional clusters) or local storage (S2D)
- Windows Server edition with Failover Clustering feature
- Server Core or Desktop Experience — both supported

**Hardware consistency:**
- Identical hardware is strongly recommended (same CPU generation, same NIC models)
- Mixed hardware is supportable but complicates updates and may trigger validation warnings
- BIOS/UEFI versions should match across nodes
- NIC firmware and drivers must be identical across nodes
- Validate with: `Test-Cluster -Node node1,node2 -Include "Storage","Network","System Configuration"`

**Maximum nodes:**
- Windows Server 2016: 64 nodes
- Windows Server 2019: 64 nodes
- Windows Server 2022: 64 nodes
- Windows Server 2025: 64 nodes

### 5.2 Network Design

- Minimum 2 networks per node: one for client access, one for cluster communication
- Dedicated cluster heartbeat NIC: no default gateway, no DNS registration, static IP
- Recommended: teamed NICs for client access (LBFO or Switch Embedded Teaming)
- Switch Embedded Teaming (SET): required for S2D, integrates with Hyper-V vSwitch
- Disable NetBIOS and LMHOSTS lookup on cluster-only heartbeat NICs
- SMBDirect (RDMA) NICs improve CSV and live migration performance dramatically

### 5.3 Storage Design

**Traditional shared storage (SAN/NAS):**
- Fibre Channel: lowest latency, most enterprise deployments
- iSCSI: cost-effective, requires dedicated NIC or VLAN separation from cluster traffic
- Shared SAS: for small deployments, directly attached
- All nodes must see all shared disks via same disk signature/GUID
- Multipath I/O (MPIO) required: `Install-WindowsFeature Multipath-IO`
- MPIO policy: Round Robin or Least Queue Depth recommended

**Storage Spaces Direct (S2D):**
- Introduced Windows Server 2016, hyper-converged storage built into Windows
- Requires: Windows Server Datacenter edition (or Azure Stack HCI)
- Local NVMe/SSD/HDD disks, no shared storage required
- Minimum 2 nodes, up to 16 nodes per S2D cluster
- Cache tier: NVMe or SSD, capacity tier: SSD or HDD
- Resilience types: 2-way mirror, 3-way mirror, dual parity (erasure coding)
- Network: RDMA required for production (25GbE or 100GbE recommended)

### 5.4 Anti-Affinity and Workload Separation

```powershell
# Set anti-affinity for VM groups (Hyper-V)
# Prevents two critical VMs from running on same node
$group1 = Get-ClusterGroup "VM1"
$group2 = Get-ClusterGroup "VM2"

# Anti-affinity via cluster group sets (2019+) or properties
$group1.AntiAffinityClassNames = "CriticalVMs"
$group2.AntiAffinityClassNames = "CriticalVMs"

# Preferred owners — order matters (first = most preferred)
Set-ClusterOwnerNode -Group "SQL Server Role" -Owners "Node1","Node2","Node3"

# Possible owners (restrict which nodes can host)
Set-ClusterOwnerNode -Resource "SQL Server" -Owners "Node1","Node2"
```

### 5.5 Maintenance and Drain Operations

```powershell
# Drain node before maintenance (moves all roles off gracefully)
Suspend-ClusterNode -Name "Node2" -Drain

# Resume node after maintenance
Resume-ClusterNode -Name "Node2" -Failback Immediate

# Check drain status
Get-ClusterNode | Select-Object Name, State, DrainStatus

# Pause without draining (for quick reboots with no failover)
Suspend-ClusterNode -Name "Node2"  # no -Drain flag
```

---

## PART 6: CLUSTER-AWARE UPDATING (CAU)

### 6.1 CAU Overview

CAU automates the process of applying Windows Updates to cluster nodes while maintaining availability. It orchestrates drain, update, restart, and resume operations.

**CAU Modes:**
- **Self-updating mode:** CAU is configured as a cluster role; updates run automatically on a schedule without external coordinator
- **Remote-updating mode:** CAU is invoked from a remote machine (typically for one-off update runs)

### 6.2 CAU Configuration

```powershell
# Install CAU feature on all cluster nodes
Install-WindowsFeature RSAT-Clustering-AutomatedUnattendedUpdates

# Add CAU cluster role (self-updating)
Add-CauClusterRole -ClusterName "Cluster1" `
    -DaysOfWeek Saturday `
    -IntervalWeeks 2 `
    -StartTime "02:00" `
    -EnableFirewallRules `
    -Force

# View CAU cluster role configuration
Get-CauClusterRole -ClusterName "Cluster1"

# Invoke manual CAU run (remote-updating mode)
Invoke-CauRun -ClusterName "Cluster1" -CauPluginName Microsoft.WindowsUpdatePlugin `
    -MaxFailedNodes 1 `
    -MaxRetriesPerNode 3 `
    -RequireAllNodesConnected `
    -Force

# Preview what would be updated without applying
Invoke-CauScan -ClusterName "Cluster1" -CauPluginName Microsoft.WindowsUpdatePlugin
```

### 6.3 CAU Plug-ins

- **Microsoft.WindowsUpdatePlugin** (default): Uses Windows Update / WSUS
- **Microsoft.HotfixPlugin**: Applies hotfixes from a hotfix root folder (CAB/MSP files)
- Custom plugins: implementable via PowerShell module

### 6.4 CAU Run Profiles

```powershell
# Export current CAU settings as XML profile
Export-CauConfigurationProfile -ClusterName "Cluster1" -FilePath "C:\CAU\profile.xml"

# Pre/post update scripts
$params = @{
    ClusterName = "Cluster1"
    PreUpdateScript = "\\fileserver\scripts\pre-update.ps1"
    PostUpdateScript = "\\fileserver\scripts\post-update.ps1"
    CauPluginName = "Microsoft.WindowsUpdatePlugin"
}
Invoke-CauRun @params
```

### 6.5 CAU Status and Results

```powershell
# Check last CAU run results
Get-CauReport -ClusterName "Cluster1" -Last | Format-List

# Get all historical CAU reports
Get-CauReport -ClusterName "Cluster1" | Select-Object RunStartTime, RunResult, UpdatesInstalled

# Check if CAU run is currently in progress
Get-CauRun -ClusterName "Cluster1"

# Stop an in-progress CAU run
Stop-CauRun -ClusterName "Cluster1" -Force
```

---

## PART 7: HIGH AVAILABILITY PATTERNS

### 7.1 Active/Passive

Single resource group (role) running on one node; second node(s) are standby:
- SQL Server FCI: one active instance, automatic failover to passive
- File Server role: one active owner, failover on failure
- Simplest pattern, guaranteed resource availability for workload

### 7.2 Active/Active

Multiple roles, each owned by different nodes:
- Node 1 runs SQL Instance A, Node 2 runs SQL Instance B
- Both nodes are active (utilizing capacity)
- On failure, surviving node hosts both instances
- Requires N+1 capacity planning: surviving node must handle 100% of failed node's load

### 7.3 N+1 Capacity Planning

Always plan with one node failure in mind:
- If cluster has N nodes and M resources, surviving N-1 nodes must be able to run all M resources
- CPU and memory on each node should support additional load
- Storage IOPS per node must handle additional workloads post-failover

### 7.4 Stretch Clusters (Multi-Site)

Nodes in two or more physical sites, connected via WAN:
- Site awareness introduced Windows Server 2016: cluster knows which nodes are in which site
- Storage replication between sites required (Storage Replica feature)
- Quorum: typically file share witness in a third site or cloud witness
- Failover priority: prefer same-site resources; cross-site failover if site fails

```powershell
# Set node site awareness (Windows Server 2016+)
Get-ClusterNode | Where-Object {$_.Name -in @("Node1","Node2")} | 
    Set-ClusterFaultDomain -Parent "SiteA"

# View fault domain hierarchy
Get-ClusterFaultDomain | Format-Table Name, Type, Parent
```

### 7.5 Cluster Sets (Windows Server 2019+)

Cluster sets group multiple clusters under a single management namespace:
- Master cluster hosts a management cluster set resource
- Member clusters join the cluster set
- Workloads (VMs) can live migrate across clusters within the set
- Shared namespaces via SOFS referrals
- Use case: large-scale hyper-converged deployments, multi-cluster management

```powershell
# Create cluster set
New-ClusterSet -Name "MyClusterSet" -NamespaceRoot "\\ClusterSetSMBShare" -CimSession "ManagementCluster"

# Add member cluster
Add-ClusterSetMember -ClusterName "Cluster1" -CimSession "ManagementCluster"

# List member clusters
Get-ClusterSetMember -CimSession "ManagementCluster"
```

### 7.6 Always On Availability Groups (SQL Integration)

SQL Server Always On AGs can run on Windows Server Failover Clusters (WSFC) or without a cluster (Basic AGs with Pacemaker on Linux). On WSFC:
- Each AG is a cluster resource of type "SQL Server Availability Group"
- The cluster provides the health monitoring; SQL Server manages the data replication
- Automatic failover requires: synchronous replica, at least 3 AGs or a quorum witness
- Readable secondaries for read-scale offloading
- Supports up to 9 secondary replicas (SQL Server 2019+), up to 8 synchronous

---

## PART 8: DIAGNOSTICS

### 8.1 Cluster Validation

`Test-Cluster` performs comprehensive validation across these categories:

| Category | Tests |
|---|---|
| Inventory | Node inventory, driver information |
| Network | NIC configuration, DNS, routing, binding order |
| Storage | Disk access, SCSI-3 persistent reservations, MPIO, failover |
| System Configuration | OS version consistency, hotfix level, domain membership |
| Hyper-V Configuration | (if Hyper-V role installed) virtual switch config |
| Storage Spaces Direct | (if S2D) disk eligibility, network requirements |

```powershell
# Full validation (pre-deployment — all tests, may interrupt storage)
Test-Cluster -Node "Node1","Node2","Node3" -ReportName "C:\ClusterValidation\report"

# Partial validation (safe on running cluster — skip storage disruption)
Test-Cluster -Node "Node1","Node2" -Include "Network","System Configuration","Inventory"

# Storage-only validation
Test-Cluster -Node "Node1","Node2" -Include "Storage"

# Results are saved as HTML report
# Open: $env:TEMP\Validation Report <date>.htm
```

**Common validation failures:**

| Failure | Resolution |
|---|---|
| NIC driver mismatch | Update NIC drivers to match version across nodes |
| DNS not resolving node names | Check DNS registration, firewall, forwarders |
| Disk not visible on all nodes | Check SAN zoning, iSCSI initiator, MPIO configuration |
| SCSI-3 reservation failure | Storage does not support persistent reservations; use S2D or update firmware |
| OS version mismatch | Rolling cluster upgrade to bring to same level |
| Domain membership different | All nodes must be in same or trusted domain |
| NTP not synchronized | Configure same NTP source on all nodes |

### 8.2 Cluster Logging

**Generating cluster debug logs:**
```powershell
# Generate cluster log on all nodes (saves to C:\Windows\Cluster\Reports\)
Get-ClusterLog -Destination "C:\ClusterLogs" -TimeSpan 60  # last 60 minutes

# Generate on specific node
Get-ClusterLog -Node "Node1" -Destination "C:\ClusterLogs" -TimeSpan 30

# Include crash dump information
Get-ClusterLog -Destination "C:\ClusterLogs" -UseLocalTime -SkipClusterState

# Enable verbose cluster logging temporarily
(Get-Cluster).ClusterLogLevel = 5   # 0=Off, 1=Error, 2=Warn, 3=Info, 4=Verbose, 5=Debug
```

**Cluster event channels:**
- `Microsoft-Windows-FailoverClustering/Operational` — standard operational events
- `Microsoft-Windows-FailoverClustering/Diagnostic` — verbose diagnostic events
- `Microsoft-Windows-FailoverClustering-Manager/Admin` — cluster manager events
- `Microsoft-Windows-FailoverClustering/DiagnosticVerbose` — extremely detailed trace

```powershell
# Query cluster event channel
Get-WinEvent -LogName "Microsoft-Windows-FailoverClustering/Operational" -MaxEvents 100 |
    Where-Object {$_.Level -le 3} |  # Error (1), Critical (2), Warning (3)
    Format-Table TimeCreated, Id, Message -Wrap

# Enable diagnostic channel (disabled by default)
wevtutil sl Microsoft-Windows-FailoverClustering/Diagnostic /e:true /q:true
```

**Critical Event IDs:**

| Event ID | Source | Description |
|---|---|---|
| 1069 | FailoverClustering | Cluster resource failed |
| 1135 | FailoverClustering | Node removed from cluster membership |
| 1146 | FailoverClustering | Cluster quorum resource lost |
| 1177 | FailoverClustering | Lost communication with cluster node |
| 1196 | FailoverClustering | Cluster IP address resource failed |
| 1222 | FailoverClustering | Failed to create Kerberos principal for cluster name |
| 1254 | FailoverClustering | Cluster CSV node is in redirected mode |
| 1561 | FailoverClustering | S2D — disk ineligible |
| 5120 | FailoverClustering | CSV is unavailable (device error) |
| 5142 | FailoverClustering | CSV blocked due to transient error |
| 5145 | FailoverClustering | CSV file system check required |

### 8.3 Troubleshooting Workflows

**Resource fails to come online:**
1. Check `Get-ClusterResource | Where State -ne 'Online'` — identify which resources are failed
2. Review cluster event log for Event ID 1069 — note the resource name and error details
3. Check `Get-ClusterLog -TimeSpan 5` and search for `[RHS]` and the resource name
4. If Generic Service: verify service account, service binary path, service dependencies
5. If IP Address: verify IP not conflicting (ping from outside cluster), verify network role
6. If Physical Disk: check disk in `Get-Disk`, verify MPIO, check disk errors in event log
7. Force resource online for investigation: `Start-ClusterResource -Name "Resource Name"`
8. Review application event log on the node currently owning the resource

**Unexpected failover — heartbeat/network analysis:**
1. Check system event log for Event 1135 (node removed) — note timestamp and removed node
2. Check `Get-ClusterLog` on the removed node around the time of failure
3. Look for `[Rcm]` and `[Netft]` entries in cluster log for network events
4. Verify NIC statistics: `Get-NetAdapterStatistics` for errors/drops
5. Check if heartbeat network had packet loss at time of failure
6. Review `SameSubnetThreshold` and `SameSubnetDelay` vs observed network latency
7. Check for anti-virus or firewall blocking UDP 3343

**Split-brain investigation:**
1. Both partitions believe they are authoritative — check which partition has quorum
2. Partition with quorum: services remain online
3. Partition without quorum: cluster service should have stopped (if healthy)
4. If both running: emergency — verify witness accessibility from both sites
5. Recovery: stop cluster service on partition without quorum, fix network, rejoin

**CSV I/O errors (Event 5120/5142):**
1. Check `Get-ClusterSharedVolume` — identify which CSVs are redirected
2. Check storage path: `Get-PhysicalDisk | Select DeviceId, HealthStatus, OperationalStatus`
3. Check MPIO status: `Get-MSDSMSupportedHW`, `Get-MSDSMGlobalDefaultLoadBalancePolicy`
4. Look for disk errors in System event log (Disk/Ntfs source)
5. Check network for CSV redirected I/O: `Get-SmbMultichannelConnection`
6. If redirected: identify why with `Get-ClusterSharedVolume | Select Name, State, StateInfo`
7. Potential causes: VSS snapshot in progress, BitLocker enabling, firmware issue

**Node isolation (cannot communicate):**
1. Verify node can ping other nodes on all cluster networks
2. Check cluster network binding: `Get-NetAdapter`, `Get-ClusterNetworkInterface`
3. Verify Windows Firewall rules: `Get-NetFirewallRule | Where DisplayName -like '*Cluster*'`
4. Check DNS resolution: `nslookup <nodename>` from each node
5. Verify cluster service running: `Get-Service ClusSvc`
6. Review if quarantine triggered: check cluster log for `[QM]` quarantine manager entries

---

## PART 9: VERSION-SPECIFIC CHANGES

### Windows Server 2016 — Key WSFC Changes

1. **Rolling Cluster OS Upgrade (RCOU):**
   - Upgrade cluster nodes one at a time from 2012 R2 to 2016 without downtime
   - Cluster operates in mixed-OS mode during upgrade
   - New features not available until all nodes upgraded and cluster functional level updated
   - `Update-ClusterFunctionalLevel` to complete upgrade after all nodes running 2016

2. **Cloud Witness:**
   - New quorum witness type using Azure Blob Storage
   - Eliminates need for a physical file share witness for geographically distributed clusters
   - `Set-ClusterQuorum -CloudWitness -AccountName <storageAccount> -AccessKey <key>`

3. **Site-Aware Clusters (Fault Domain Awareness):**
   - Cluster knows physical topology: sites, racks, nodes
   - Quorum prefers partitions that span more fault domains
   - `Get-ClusterFaultDomain`, `Set-ClusterFaultDomain`
   - Sites: `New-ClusterFaultDomain -Name "SiteA" -Type Site`

4. **VM Resiliency (Isolated VM Start):**
   - When storage unavailable, VMs continue running on last known state
   - `ResiliencyDefaultPeriod` and `ResiliencyLevel` cluster properties
   - Isolated VMs in "Running – Critical" state while storage recovers

5. **Storage Spaces Direct (S2D):**
   - Hyper-converged storage built on local disks
   - `Enable-ClusterStorageSpacesDirect`
   - ReFS volume support on CSV

6. **Workgroup and Multi-Domain Clusters:**
   - Clusters can be formed without Active Directory (certificate-based auth)
   - Nodes can be in different domains

### Windows Server 2019 — Key WSFC Changes

1. **Cluster Sets:**
   - Group multiple clusters under one management namespace
   - Live migration between clusters in the set
   - `New-ClusterSet`, `Add-ClusterSetMember`

2. **USB Witness:**
   - USB drive as quorum witness (new witness type)
   - Requires the USB device be accessible from all nodes

3. **Improved Cross-Domain and Workgroup Clusters:**
   - Better support for clusters spanning multiple AD domains
   - Improvements to certificate-based authentication for workgroup clusters

4. **Cluster Hardening:**
   - Cluster name object (CNO) now created without local administrator privileges on target OUs (if pre-staged)
   - Improved Kerberos integration for cluster network names

5. **Faster VM Failover:**
   - Improved VM checkpoint and state restoration speeds
   - VM failover times reduced for guest clusters

6. **Kubernetes Integration:**
   - Windows Server containers support in cluster environments
   - Foundation for Windows-based Kubernetes nodes

### Windows Server 2022 — Key WSFC Changes

1. **Cluster-Aware Updating Improvements:**
   - Simplified CAU run profiles
   - Better integration with Windows Update for Business
   - Improved reporting and logging

2. **Azure Arc Integration:**
   - Clusters registered with Azure Arc for cloud management visibility
   - Arc-enabled monitoring for cluster health in Azure Monitor
   - Policy enforcement via Azure Policy on cluster resources

3. **Improved Stretched Clusters:**
   - Better support for Active-Active stretched cluster configurations
   - Storage Replica improvements: compression, performance improvements
   - Reduced failover times in stretched cluster scenarios

4. **SMB over QUIC:**
   - SMB file shares accessible over HTTPS/QUIC protocol without VPN
   - Enables cluster file share resources over internet-facing connections (with proper security)

5. **Network ATC (Automated NIC Teaming and Configuration):**
   - Simplified network configuration for cluster nodes
   - `Install-NetworkATC`, intent-based networking configuration
   - Eliminates manual NIC configuration for cluster, storage, management traffic

6. **Adjustable Quorum Thresholds:**
   - Improved cluster dynamic quorum behavior for edge cases

### Windows Server 2025 — Key WSFC Changes

1. **NVMe over Fabrics (NVMe-oF) Support:**
   - Storage Spaces Direct with NVMe-oF targets
   - Lower latency storage fabric for cluster storage

2. **Delegated Managed Service Account (dMSA) for Cluster:**
   - Improved cluster service account management
   - Reduced Kerberos ticket management overhead

3. **Improved Cluster Health Service:**
   - More granular fault reporting
   - Better integration with Windows Admin Center for cluster health visualization

4. **Enhanced S2D Performance:**
   - Mirror-accelerated parity improvements
   - Better tiering logic for NVMe + SSD + HDD configurations

5. **Cluster API Improvements:**
   - REST API for cluster management (complement to PowerShell and WMI)
   - Better programmability for automation platforms

---

## PART 10: POWERSHELL DIAGNOSTIC SCRIPTS

### Script 01 — Cluster Health Overview

```powershell
<#
.SYNOPSIS
    Comprehensive cluster health status overview for Windows Server Failover Clustering.
.DESCRIPTION
    Retrieves cluster node status, resource group health, individual resource states,
    and recent cluster events. Designed for rapid health assessment.
.NOTES
    Version:    1.0
    Author:     WSFC Agent Library
    Read-only:  Yes — no cluster modifications made
    Requires:   FailoverClusters PowerShell module, cluster administrator rights
    Platform:   Windows Server 2016, 2019, 2022, 2025
#>

#Requires -Module FailoverClusters

param(
    [string]$ClusterName = ".",
    [int]$EventLookbackMinutes = 60,
    [switch]$IncludeDetailedNodeInfo
)

function Write-Section {
    param([string]$Title)
    Write-Host "`n$('=' * 60)" -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host "$('=' * 60)" -ForegroundColor Cyan
}

try {
    $cluster = Get-Cluster -Name $ClusterName -ErrorAction Stop
} catch {
    Write-Error "Failed to connect to cluster '$ClusterName': $_"
    exit 1
}

Write-Section "CLUSTER OVERVIEW"
$clusterProps = $cluster | Select-Object `
    Name,
    Domain,
    @{N='QuorumType';E={$_.QuorumType}},
    @{N='QuorumResource';E={$_.QuorumResourceName}},
    @{N='ClusterFunctionalLevel';E={$_.ClusterFunctionalLevel}},
    SharedVolumesRoot,
    BlockCacheSize,
    DynamicQuorum,
    SameSubnetDelay,
    SameSubnetThreshold,
    CrossSubnetDelay,
    CrossSubnetThreshold

$clusterProps | Format-List

Write-Section "CLUSTER NODES"
$nodes = Get-ClusterNode -Cluster $ClusterName
$nodeReport = $nodes | Select-Object `
    Name,
    State,
    @{N='NodeWeight';E={$_.NodeWeight}},
    @{N='DynamicWeight';E={$_.DynamicWeight}},
    @{N='StatusInformation';E={$_.StatusInformation}},
    DrainStatus,
    @{N='Groups';E={(Get-ClusterGroup -Cluster $ClusterName | Where-Object OwnerNode -eq $_.Name).Count}}

$nodeReport | Format-Table -AutoSize

# Highlight unhealthy nodes
$downNodes = $nodes | Where-Object { $_.State -ne 'Up' }
if ($downNodes) {
    Write-Host "`n[WARNING] Unhealthy Nodes Detected:" -ForegroundColor Red
    $downNodes | Select-Object Name, State, StatusInformation | Format-Table -AutoSize
}

Write-Section "CLUSTER GROUPS (ROLES)"
$groups = Get-ClusterGroup -Cluster $ClusterName
$groupReport = $groups | Select-Object `
    Name,
    State,
    OwnerNode,
    @{N='Priority';E={$_.Priority}},
    @{N='FailoverThreshold';E={$_.FailoverThreshold}},
    @{N='FailoverPeriod';E={$_.FailoverPeriod}},
    @{N='AutoFailback';E={$_.AutoFailbackType}}

$groupReport | Sort-Object State, Name | Format-Table -AutoSize

# Highlight failed groups
$failedGroups = $groups | Where-Object { $_.State -notin @('Online','Partially Online') }
if ($failedGroups) {
    Write-Host "`n[ALERT] Groups Not Fully Online:" -ForegroundColor Red
    $failedGroups | Select-Object Name, State, OwnerNode | Format-Table -AutoSize
}

Write-Section "CLUSTER RESOURCES"
$resources = Get-ClusterResource -Cluster $ClusterName
$resourceReport = $resources | Select-Object `
    Name,
    State,
    ResourceType,
    OwnerGroup,
    @{N='OwnerNode';E={$_.OwnerNode}},
    @{N='MonitoredCluster';E={$_.SeparateMonitor}}

$resourceReport | Sort-Object State, ResourceType, Name | Format-Table -AutoSize

# Highlight failed resources
$failedResources = $resources | Where-Object { $_.State -eq 'Failed' }
if ($failedResources) {
    Write-Host "`n[ALERT] Failed Resources:" -ForegroundColor Red
    $failedResources | Select-Object Name, ResourceType, OwnerGroup, OwnerNode | Format-Table -AutoSize
}

Write-Section "RECENT CLUSTER EVENTS (Last $EventLookbackMinutes Minutes)"
$since = (Get-Date).AddMinutes(-$EventLookbackMinutes)
try {
    $events = Get-WinEvent -ComputerName $cluster.Name `
        -LogName 'Microsoft-Windows-FailoverClustering/Operational' `
        -ErrorAction SilentlyContinue |
        Where-Object { $_.TimeCreated -ge $since -and $_.Level -le 3 } |
        Select-Object TimeCreated, Id, LevelDisplayName, Message |
        Sort-Object TimeCreated -Descending

    if ($events) {
        $events | Format-Table TimeCreated, Id, LevelDisplayName -AutoSize
        Write-Host "`nTop 5 Recent Error/Warning Events:" -ForegroundColor Yellow
        $events | Select-Object -First 5 | Format-List TimeCreated, Id, LevelDisplayName, Message
    } else {
        Write-Host "No errors or warnings in the last $EventLookbackMinutes minutes." -ForegroundColor Green
    }
} catch {
    Write-Warning "Could not retrieve cluster events: $_"
}

Write-Section "HEALTH SUMMARY"
$totalNodes   = $nodes.Count
$onlineNodes  = ($nodes | Where-Object State -eq 'Up').Count
$totalGroups  = $groups.Count
$onlineGroups = ($groups | Where-Object State -eq 'Online').Count
$totalRes     = $resources.Count
$onlineRes    = ($resources | Where-Object State -eq 'Online').Count

Write-Host "Nodes:     $onlineNodes/$totalNodes online" -ForegroundColor $(if ($onlineNodes -eq $totalNodes) {'Green'} else {'Red'})
Write-Host "Groups:    $onlineGroups/$totalGroups online" -ForegroundColor $(if ($onlineGroups -eq $totalGroups) {'Green'} else {'Yellow'})
Write-Host "Resources: $onlineRes/$totalRes online" -ForegroundColor $(if ($onlineRes -eq $totalRes) {'Green'} else {'Yellow'})
```

---

### Script 02 — Cluster Network Health

```powershell
<#
.SYNOPSIS
    Cluster network configuration and health analysis for WSFC.
.DESCRIPTION
    Reports on cluster networks, network interfaces per node, heartbeat configuration,
    live migration network assignment, and cross-subnet settings.
.NOTES
    Version:    1.0
    Author:     WSFC Agent Library
    Read-only:  Yes — no cluster modifications made
    Requires:   FailoverClusters PowerShell module
    Platform:   Windows Server 2016, 2019, 2022, 2025
#>

#Requires -Module FailoverClusters

param(
    [string]$ClusterName = "."
)

function Write-Section {
    param([string]$Title)
    Write-Host "`n$('=' * 60)" -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host "$('=' * 60)" -ForegroundColor Cyan
}

$roleNames = @{ 0='None'; 1='Cluster Only (Heartbeat)'; 2='Client Access Only'; 3='All (Cluster + Client)' }

try {
    $cluster = Get-Cluster -Name $ClusterName -ErrorAction Stop
} catch {
    Write-Error "Cannot connect to cluster '$ClusterName': $_"
    exit 1
}

Write-Section "CLUSTER HEARTBEAT SETTINGS"
$cluster | Select-Object `
    Name,
    SameSubnetDelay,
    SameSubnetThreshold,
    CrossSubnetDelay,
    CrossSubnetThreshold,
    RouteHistoryLength | Format-List

Write-Section "CLUSTER NETWORKS"
$networks = Get-ClusterNetwork -Cluster $ClusterName
$networks | Select-Object `
    Name,
    State,
    @{N='Role';E={ "$($_.Role) — $($roleNames[[int]$_.Role])" }},
    @{N='Metric (Priority)';E={$_.Metric}},
    Address,
    AddressMask,
    @{N='AutoMetric';E={$_.AutoMetric}},
    Description |
    Sort-Object Metric | Format-Table -AutoSize

# Flag networks that are down
$downNetworks = $networks | Where-Object { $_.State -ne 'Up' }
if ($downNetworks) {
    Write-Host "`n[WARNING] Networks in non-Up state:" -ForegroundColor Red
    $downNetworks | Select-Object Name, State, Role | Format-Table -AutoSize
}

Write-Section "CLUSTER NETWORK INTERFACES (Per Node)"
$interfaces = Get-ClusterNetworkInterface -Cluster $ClusterName
$interfaces | Select-Object `
    Node,
    Name,
    Network,
    State,
    @{N='IPv4Address';E={$_.IPv4Addresses}},
    @{N='IPv6Address';E={$_.IPv6Addresses}},
    Adapter |
    Sort-Object Node, Network | Format-Table -AutoSize

# Flag failed interfaces
$failedIf = $interfaces | Where-Object { $_.State -ne 'Up' }
if ($failedIf) {
    Write-Host "`n[ALERT] Network Interfaces Not Up:" -ForegroundColor Red
    $failedIf | Select-Object Node, Name, Network, State | Format-Table -AutoSize
}

Write-Section "NETWORK ROLE ANALYSIS"
$heartbeatNets = $networks | Where-Object { $_.Role -in @(1,3) }
$clientNets    = $networks | Where-Object { $_.Role -in @(2,3) }
$unusedNets    = $networks | Where-Object { $_.Role -eq 0 }

Write-Host "Heartbeat-capable networks: $($heartbeatNets.Count)" -ForegroundColor Yellow
$heartbeatNets | Select-Object Name, @{N='Role';E={$roleNames[[int]$_.Role]}}, Metric | Format-Table -AutoSize

Write-Host "Client-access networks: $($clientNets.Count)" -ForegroundColor Yellow
$clientNets | Select-Object Name, @{N='Role';E={$roleNames[[int]$_.Role]}}, Metric | Format-Table -AutoSize

if ($unusedNets) {
    Write-Host "Unused networks (Role=None): $($unusedNets.Count)" -ForegroundColor Gray
    $unusedNets | Select-Object Name, @{N='Role';E={$roleNames[[int]$_.Role]}}, Metric | Format-Table -AutoSize
}

Write-Section "LIVE MIGRATION NETWORK CONFIGURATION"
Write-Host "Checking Hyper-V live migration network settings on each node..." -ForegroundColor Yellow
foreach ($node in (Get-ClusterNode -Cluster $ClusterName | Where-Object State -eq 'Up')) {
    try {
        $vmHost = Get-VMHost -ComputerName $node.Name -ErrorAction Stop
        Write-Host "`n[$($node.Name)] Live Migration:" -ForegroundColor Green
        $vmHost | Select-Object `
            VirtualMachineMigrationEnabled,
            UseAnyNetworkForMigration,
            MaximumVirtualMachineMigrations,
            MaximumStorageMigrations,
            VirtualMachineMigrationAuthenticationType | Format-List

        if (-not $vmHost.UseAnyNetworkForMigration) {
            Get-VMMigrationNetwork -ComputerName $node.Name |
                Select-Object Subnet, Priority | Format-Table
        }
    } catch {
        Write-Host "  [Hyper-V not available or accessible on $($node.Name)]" -ForegroundColor Gray
    }
}

Write-Section "IP RESOURCE NETWORK ASSIGNMENTS"
$ipResources = Get-ClusterResource -Cluster $ClusterName |
    Where-Object ResourceType -eq 'IP Address'

foreach ($ip in $ipResources) {
    $props = $ip | Get-ClusterParameter -ErrorAction SilentlyContinue
    $addr  = ($props | Where-Object Name -eq 'Address').Value
    $mask  = ($props | Where-Object Name -eq 'SubnetMask').Value
    $net   = ($props | Where-Object Name -eq 'Network').Value
    Write-Host "$($ip.Name): $addr / $mask on network '$net' [Group: $($ip.OwnerGroup)]"
}
```

---

### Script 03 — CSV Health

```powershell
<#
.SYNOPSIS
    Cluster Shared Volume (CSV) health, ownership, and I/O state monitoring.
.DESCRIPTION
    Reports CSV volume status, coordinator node ownership, redirected I/O state,
    free space, fault state, and backup mode detection.
.NOTES
    Version:    1.0
    Author:     WSFC Agent Library
    Read-only:  Yes — no cluster modifications made
    Requires:   FailoverClusters PowerShell module
    Platform:   Windows Server 2016, 2019, 2022, 2025
#>

#Requires -Module FailoverClusters

param(
    [string]$ClusterName = ".",
    [int]$FreeSpaceWarningPct = 20,
    [int]$FreeSpaceCriticalPct = 10
)

function Write-Section {
    param([string]$Title)
    Write-Host "`n$('=' * 60)" -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host "$('=' * 60)" -ForegroundColor Cyan
}

function Get-PercentColor {
    param([double]$Pct, [int]$WarnThreshold, [int]$CritThreshold)
    if ($Pct -le $CritThreshold) { return 'Red' }
    if ($Pct -le $WarnThreshold) { return 'Yellow' }
    return 'Green'
}

try {
    $cluster = Get-Cluster -Name $ClusterName -ErrorAction Stop
} catch {
    Write-Error "Cannot connect to cluster: $_"
    exit 1
}

Write-Section "CSV VOLUME STATUS"
$csvs = Get-ClusterSharedVolume -Cluster $ClusterName

if (-not $csvs) {
    Write-Host "No Cluster Shared Volumes found on cluster '$($cluster.Name)'." -ForegroundColor Yellow
    exit 0
}

foreach ($csv in $csvs) {
    $info = $csv.SharedVolumeInfo
    $stateInfo = $csv.StateInfo

    # Determine color based on state
    $stateColor = switch ($csv.State) {
        'Online'         { 'Green' }
        'Partial'        { 'Yellow' }
        'Unavailable'    { 'Red' }
        'No Access'      { 'Red' }
        default          { 'Yellow' }
    }

    Write-Host "`n--- $($csv.Name) ---" -ForegroundColor White

    foreach ($volInfo in $info) {
        $totalGB    = [math]::Round($volInfo.Partition.Size / 1GB, 2)
        $freeGB     = [math]::Round($volInfo.Partition.FreeSpace / 1GB, 2)
        $freePct    = if ($totalGB -gt 0) { [math]::Round(($freeGB / $totalGB) * 100, 1) } else { 0 }
        $spaceColor = Get-PercentColor -Pct $freePct -WarnThreshold $FreeSpaceWarningPct -CritThreshold $FreeSpaceCriticalPct

        Write-Host "  State:          " -NoNewline; Write-Host $csv.State -ForegroundColor $stateColor
        Write-Host "  Owner Node:     $($csv.OwnerNode)"
        Write-Host "  Mount Point:    $($volInfo.FriendlyVolumeName)"
        Write-Host "  Filesystem:     $($volInfo.Partition.Name)"
        Write-Host "  Total Size:     $totalGB GB"
        Write-Host "  Free Space:     " -NoNewline
        Write-Host "$freeGB GB ($freePct%)" -ForegroundColor $spaceColor
        Write-Host "  Redirected I/O: " -NoNewline

        $redirected = ($csv.StateInfo -ne $null -and $csv.StateInfo.ToString() -match 'Redirected') -or
                      ($volInfo.RedirectedIOReason -ne 0)

        if ($redirected) {
            Write-Host "YES — $($volInfo.RedirectedIOReason)" -ForegroundColor Red
        } else {
            Write-Host "No" -ForegroundColor Green
        }

        Write-Host "  Fault State:    $($volInfo.FaultState)"
        Write-Host "  Backup Mode:    $($volInfo.BackupState)"
    }
}

Write-Section "CSV REDIRECTED I/O SUMMARY"
$redirectedCSVs = $csvs | Where-Object {
    $_.SharedVolumeInfo | Where-Object { $_.RedirectedIOReason -ne 0 }
}

if ($redirectedCSVs) {
    Write-Host "[WARNING] CSVs with Redirected I/O:" -ForegroundColor Red
    foreach ($csv in $redirectedCSVs) {
        foreach ($volInfo in $csv.SharedVolumeInfo) {
            if ($volInfo.RedirectedIOReason -ne 0) {
                Write-Host "  $($csv.Name) — Reason: $($volInfo.RedirectedIOReason)" -ForegroundColor Yellow
            }
        }
    }
    Write-Host "`nRedirected I/O Reasons:"
    Write-Host "  1  = NotBlockedOrRedirected (direct I/O)"
    Write-Host "  2  = NoDiskConnectivity"
    Write-Host "  4  = FileSystemNotMounted"
    Write-Host "  8  = InMaintenance"
    Write-Host "  16 = VolumeTooBig"
    Write-Host "  32 = BitLockerInitializationInProgress"
    Write-Host "  64 = DiskTimeout"
} else {
    Write-Host "All CSVs operating in Direct I/O mode (no redirection)." -ForegroundColor Green
}

Write-Section "CSV FREE SPACE ANALYSIS"
$spaceIssues = @()
foreach ($csv in $csvs) {
    foreach ($volInfo in $csv.SharedVolumeInfo) {
        $totalGB = [math]::Round($volInfo.Partition.Size / 1GB, 2)
        $freeGB  = [math]::Round($volInfo.Partition.FreeSpace / 1GB, 2)
        $freePct = if ($totalGB -gt 0) { [math]::Round(($freeGB / $totalGB) * 100, 1) } else { 0 }

        if ($freePct -le $FreeSpaceWarningPct) {
            $spaceIssues += [PSCustomObject]@{
                CSV       = $csv.Name
                MountPoint = $volInfo.FriendlyVolumeName
                TotalGB   = $totalGB
                FreeGB    = $freeGB
                FreePct   = $freePct
                Severity  = if ($freePct -le $FreeSpaceCriticalPct) { 'CRITICAL' } else { 'WARNING' }
            }
        }
    }
}

if ($spaceIssues) {
    Write-Host "[ALERT] CSVs with low free space:" -ForegroundColor Red
    $spaceIssues | Sort-Object FreePct | Format-Table -AutoSize
} else {
    Write-Host "All CSVs have adequate free space (>$FreeSpaceWarningPct%)." -ForegroundColor Green
}

Write-Section "CSV OWNERSHIP DISTRIBUTION"
$csvs | Group-Object OwnerNode |
    Select-Object Count, @{N='OwnerNode';E={$_.Name}} |
    Sort-Object Count -Descending | Format-Table -AutoSize
```

---

### Script 04 — Resource Groups and Dependencies

```powershell
<#
.SYNOPSIS
    Cluster resource group status, dependency chains, preferred owners, and failover history.
.DESCRIPTION
    Analyzes resource group configuration including dependency trees, owner preferences,
    failover policy settings, and attempts to surface misconfigurations.
.NOTES
    Version:    1.0
    Author:     WSFC Agent Library
    Read-only:  Yes — no cluster modifications made
    Requires:   FailoverClusters PowerShell module
    Platform:   Windows Server 2016, 2019, 2022, 2025
#>

#Requires -Module FailoverClusters

param(
    [string]$ClusterName = ".",
    [string]$GroupFilter  = "*"
)

function Write-Section {
    param([string]$Title)
    Write-Host "`n$('=' * 60)" -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host "$('=' * 60)" -ForegroundColor Cyan
}

try {
    $cluster = Get-Cluster -Name $ClusterName -ErrorAction Stop
    $nodes   = Get-ClusterNode -Cluster $ClusterName
} catch {
    Write-Error "Cannot connect to cluster '$ClusterName': $_"
    exit 1
}

$groups    = Get-ClusterGroup -Cluster $ClusterName | Where-Object Name -like $GroupFilter
$resources = Get-ClusterResource -Cluster $ClusterName

Write-Section "RESOURCE GROUP STATUS"
$groups | Select-Object `
    Name,
    State,
    OwnerNode,
    Priority,
    @{N='FailoverThreshold';E={$_.FailoverThreshold}},
    @{N='FailoverPeriod (hrs)';E={$_.FailoverPeriod}},
    @{N='AutoFailback';E={
        switch ($_.AutoFailbackType) {
            0 { 'Prevent' }
            1 { 'Allow' }
            2 { 'Allow with Window' }
        }
    }},
    @{N='FailbackWindowStart';E={$_.FailbackWindowStart}},
    @{N='FailbackWindowEnd';E={$_.FailbackWindowEnd}} |
    Sort-Object State, Name | Format-Table -AutoSize

Write-Section "PREFERRED AND POSSIBLE OWNERS"
foreach ($group in $groups) {
    $preferred = (Get-ClusterOwnerNode -Group $group.Name -Cluster $ClusterName).OwnerNodes
    $groupRes  = $resources | Where-Object OwnerGroup -eq $group.Name

    Write-Host "`nGroup: $($group.Name) [$($group.State) on $($group.OwnerNode)]" -ForegroundColor White

    if ($preferred) {
        Write-Host "  Preferred Owners (ordered): $($preferred -join ' > ')" -ForegroundColor Yellow
    } else {
        Write-Host "  Preferred Owners: Any (none specified)" -ForegroundColor Gray
    }

    Write-Host "  Resources in group: $($groupRes.Count)"
    foreach ($res in $groupRes) {
        $possibleOwners = (Get-ClusterOwnerNode -Resource $res.Name -Cluster $ClusterName).OwnerNodes
        $ownerInfo = if ($possibleOwners.Count -eq $nodes.Count -or $possibleOwners.Count -eq 0) {
            "All nodes"
        } else {
            $possibleOwners -join ', '
        }
        Write-Host "    [$($res.State.ToString().PadRight(15))] $($res.Name) ($($res.ResourceType)) — Possible: $ownerInfo"
    }
}

Write-Section "RESOURCE DEPENDENCY CHAINS"
foreach ($group in $groups) {
    $groupRes = $resources | Where-Object OwnerGroup -eq $group.Name
    Write-Host "`nGroup: $($group.Name)" -ForegroundColor White

    foreach ($res in $groupRes) {
        try {
            $deps = Get-ClusterResourceDependency -Resource $res.Name -Cluster $ClusterName -ErrorAction SilentlyContinue
            if ($deps -and $deps.DependencyExpression) {
                Write-Host "  $($res.Name) depends on: $($deps.DependencyExpression)" -ForegroundColor Yellow
            }
        } catch {
            # Resource may not support dependency queries
        }
    }
}

Write-Section "RESOURCE RESTART POLICIES"
foreach ($group in ($groups | Sort-Object Name)) {
    $groupRes = $resources | Where-Object OwnerGroup -eq $group.Name
    Write-Host "`nGroup: $($group.Name)" -ForegroundColor White

    foreach ($res in $groupRes) {
        try {
            $restartAction = switch ($res.RestartAction) {
                0 { 'Do Not Restart' }
                1 { 'Restart (no failover)' }
                2 { 'Restart then Failover Group' }
                default { $res.RestartAction }
            }
            Write-Host ("  {0,-40} RestartAction={1}, Threshold={2}, Period={3}ms" -f `
                $res.Name, $restartAction, $res.RestartThreshold, $res.RestartPeriod)
        } catch {
            Write-Host "  $($res.Name) — policy unavailable"
        }
    }
}

Write-Section "GROUPS WITH POTENTIAL ISSUES"
$issues = @()

foreach ($group in $groups) {
    # Check: group not on preferred owner
    $preferred = (Get-ClusterOwnerNode -Group $group.Name -Cluster $ClusterName).OwnerNodes
    if ($preferred -and $preferred.Count -gt 0 -and $group.State -eq 'Online') {
        if ($group.OwnerNode -ne $preferred[0]) {
            $issues += "Group '$($group.Name)' is on '$($group.OwnerNode)' but preferred owner is '$($preferred[0])'"
        }
    }

    # Check: group in failed state
    if ($group.State -eq 'Failed') {
        $issues += "Group '$($group.Name)' is in FAILED state"
    }

    # Check: no preferred owners configured (high risk)
    if ($preferred.Count -eq 0 -and $group.Name -notmatch 'Available Storage|Cluster Group') {
        $issues += "Group '$($group.Name)' has no preferred owner configured"
    }
}

if ($issues) {
    Write-Host "Issues Found:" -ForegroundColor Red
    $issues | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
} else {
    Write-Host "No configuration issues detected." -ForegroundColor Green
}
```

---

### Script 05 — Quorum and Witness Health

```powershell
<#
.SYNOPSIS
    Cluster quorum configuration, witness health, and node voting status.
.DESCRIPTION
    Reports quorum model, witness type and accessibility, node vote weights,
    dynamic quorum state, and calculates current quorum margin.
.NOTES
    Version:    1.0
    Author:     WSFC Agent Library
    Read-only:  Yes — no cluster modifications made
    Requires:   FailoverClusters PowerShell module
    Platform:   Windows Server 2016, 2019, 2022, 2025
#>

#Requires -Module FailoverClusters

param(
    [string]$ClusterName = "."
)

function Write-Section {
    param([string]$Title)
    Write-Host "`n$('=' * 60)" -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host "$('=' * 60)" -ForegroundColor Cyan
}

try {
    $cluster = Get-Cluster -Name $ClusterName -ErrorAction Stop
    $nodes   = Get-ClusterNode -Cluster $ClusterName
} catch {
    Write-Error "Cannot connect to cluster '$ClusterName': $_"
    exit 1
}

Write-Section "QUORUM CONFIGURATION"
$quorum = Get-ClusterQuorum -Cluster $ClusterName
$quorum | Select-Object Cluster, QuorumResource, QuorumType | Format-List

Write-Host "Dynamic Quorum Enabled: $($cluster.DynamicQuorum)" -ForegroundColor $(if ($cluster.DynamicQuorum -eq 1) {'Green'} else {'Yellow'})

Write-Section "WITNESS DETAILS"
switch ($quorum.QuorumType) {
    'NodeMajority' {
        Write-Host "Quorum Type: Node Majority (no witness)" -ForegroundColor Cyan
        Write-Host "No witness configured — relies entirely on node votes."
        if ($nodes.Count % 2 -eq 0) {
            Write-Host "[WARNING] Even number of nodes ($($nodes.Count)) with no witness — consider adding a witness." -ForegroundColor Yellow
        }
    }
    'NodeAndDiskMajority' {
        Write-Host "Quorum Type: Node and Disk Majority (Disk Witness)" -ForegroundColor Cyan
        $witnessRes = Get-ClusterResource -Cluster $ClusterName -Name $quorum.QuorumResource -ErrorAction SilentlyContinue
        if ($witnessRes) {
            Write-Host "Witness Disk Resource: $($witnessRes.Name)"
            Write-Host "Witness Disk State:    $($witnessRes.State)" -ForegroundColor $(if ($witnessRes.State -eq 'Online') {'Green'} else {'Red'})
            Write-Host "Witness Disk Owner:    $($witnessRes.OwnerNode)"
        } else {
            Write-Host "[ERROR] Witness disk resource not found!" -ForegroundColor Red
        }
    }
    'NodeAndFileShareMajority' {
        Write-Host "Quorum Type: Node and File Share Majority (File Share Witness)" -ForegroundColor Cyan
        $witnessRes = Get-ClusterResource -Cluster $ClusterName -Name $quorum.QuorumResource -ErrorAction SilentlyContinue
        if ($witnessRes) {
            $params   = $witnessRes | Get-ClusterParameter -ErrorAction SilentlyContinue
            $sharePath = ($params | Where-Object Name -eq 'SharePath').Value
            Write-Host "Witness Share Path: $sharePath"

            # Test file share accessibility
            if ($sharePath) {
                $accessible = Test-Path $sharePath -ErrorAction SilentlyContinue
                Write-Host "Share Accessible:   $accessible" -ForegroundColor $(if ($accessible) {'Green'} else {'Red'})
            }
            Write-Host "Witness Resource State: $($witnessRes.State)" -ForegroundColor $(if ($witnessRes.State -eq 'Online') {'Green'} else {'Red'})
        }
    }
    'Majority' {
        # Could be cloud witness in newer PowerShell versions
        Write-Host "Quorum Type: Majority (may include Cloud Witness)" -ForegroundColor Cyan
        $witnessRes = Get-ClusterResource -Cluster $ClusterName -Name $quorum.QuorumResource -ErrorAction SilentlyContinue
        if ($witnessRes) {
            Write-Host "Witness Resource: $($witnessRes.Name) [$($witnessRes.ResourceType)]"
            Write-Host "Witness State:    $($witnessRes.State)" -ForegroundColor $(if ($witnessRes.State -eq 'Online') {'Green'} else {'Red'})

            if ($witnessRes.ResourceType -eq 'Cloud Witness') {
                $params      = $witnessRes | Get-ClusterParameter
                $accountName = ($params | Where-Object Name -eq 'AccountName').Value
                $endpoint    = ($params | Where-Object Name -eq 'EndpointInfo').Value
                Write-Host "Azure Storage Account: $accountName"
                Write-Host "Endpoint:              $endpoint"
            }
        }
    }
}

Write-Section "NODE VOTE STATUS"
$voteData = foreach ($node in $nodes) {
    [PSCustomObject]@{
        NodeName      = $node.Name
        State         = $node.State
        NodeWeight    = $node.NodeWeight
        DynamicWeight = $node.DynamicWeight
        Vote          = if ($node.DynamicWeight -eq 1) { 'Voting' } else { 'NOT Voting (dynamic)' }
    }
}
$voteData | Format-Table -AutoSize

Write-Section "QUORUM MATH"
$activeVotes  = ($voteData | Where-Object { $_.DynamicWeight -eq 1 }).Count
$witnessVote  = if ($quorum.QuorumType -ne 'NodeMajority') { 1 } else { 0 }
$totalVotes   = $activeVotes + $witnessVote
$quorumNeeded = [math]::Floor($totalVotes / 2) + 1

Write-Host "Active Node Votes:    $activeVotes"
Write-Host "Witness Vote:         $witnessVote"
Write-Host "Total Possible Votes: $totalVotes"
Write-Host "Votes Needed (quorum): $quorumNeeded"
Write-Host "Current Quorum Margin: $($activeVotes + $witnessVote - $quorumNeeded) votes above threshold" -ForegroundColor $(
    if (($activeVotes + $witnessVote - $quorumNeeded) -le 1) {'Yellow'} else {'Green'}
)

# Can we survive one more failure?
$canSurviveOneFailure = ($activeVotes + $witnessVote - 1) -ge $quorumNeeded
Write-Host "Can survive 1 node failure: $canSurviveOneFailure" -ForegroundColor $(if ($canSurviveOneFailure) {'Green'} else {'Red'})
```

---

### Script 06 — CAU Status and Compliance

```powershell
<#
.SYNOPSIS
    Cluster-Aware Updating (CAU) status, last run results, and compliance check.
.DESCRIPTION
    Reports CAU cluster role configuration, last update run results, per-node
    update compliance, and upcoming scheduled runs.
.NOTES
    Version:    1.0
    Author:     WSFC Agent Library
    Read-only:  Yes — no cluster modifications made
    Requires:   FailoverClusters, ClusterAwareUpdating PowerShell modules
    Platform:   Windows Server 2016, 2019, 2022, 2025
#>

#Requires -Module FailoverClusters

param(
    [string]$ClusterName     = ".",
    [int]$ReportHistoryCount = 5
)

function Write-Section {
    param([string]$Title)
    Write-Host "`n$('=' * 60)" -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host "$('=' * 60)" -ForegroundColor Cyan
}

try {
    $cluster = Get-Cluster -Name $ClusterName -ErrorAction Stop
} catch {
    Write-Error "Cannot connect to cluster '$ClusterName': $_"
    exit 1
}

Write-Section "CAU CLUSTER ROLE"
try {
    $cauRole = Get-CauClusterRole -ClusterName $cluster.Name -ErrorAction Stop
    Write-Host "CAU Role Status: Configured" -ForegroundColor Green
    $cauRole | Select-Object `
        ClusterName,
        @{N='RunPlugins';E={$_.CauPluginName -join ', '}},
        @{N='Schedule';E={"$($_.DaysOfWeek) every $($_.IntervalWeeks) week(s)"}},
        StartTime,
        MaxFailedNodes,
        MaxRetriesPerNode,
        RequireAllNodesConnected,
        EnableFirewallRules | Format-List
} catch [Microsoft.FailoverClusters.Automation.ClusterCmdletException] {
    Write-Host "CAU Cluster Role: Not configured (self-updating mode not enabled)" -ForegroundColor Yellow
    Write-Host "To enable: Add-CauClusterRole -ClusterName $($cluster.Name) -DaysOfWeek Saturday -StartTime '02:00' -Force"
} catch {
    Write-Warning "Could not retrieve CAU role: $_"
}

Write-Section "CURRENT CAU RUN STATUS"
try {
    $currentRun = Get-CauRun -ClusterName $cluster.Name -ErrorAction Stop
    if ($currentRun) {
        Write-Host "CAU Run IN PROGRESS:" -ForegroundColor Yellow
        $currentRun | Select-Object `
            ClusterName, RunStartTime, CurrentOrMostRecentNode,
            NumberOfNodeJobs, NumberOfCompleted, NumberOfFailed | Format-List
    } else {
        Write-Host "No CAU run currently in progress." -ForegroundColor Green
    }
} catch {
    Write-Host "No active CAU run (or CAU module not available)." -ForegroundColor Gray
}

Write-Section "RECENT CAU RUN HISTORY (Last $ReportHistoryCount Runs)"
try {
    $reports = Get-CauReport -ClusterName $cluster.Name -ErrorAction Stop |
        Sort-Object RunStartTime -Descending |
        Select-Object -First $ReportHistoryCount

    if ($reports) {
        $reports | Select-Object `
            RunStartTime,
            RunEndTime,
            @{N='Duration';E={
                if ($_.RunEndTime) {
                    "$([math]::Round(($_.RunEndTime - $_.RunStartTime).TotalMinutes, 1)) min"
                } else { 'N/A' }
            }},
            @{N='Result';E={$_.RunResult}},
            @{N='UpdatesInstalled';E={$_.NodeResults.UpdatesInstalled | Measure-Object -Sum | Select-Object -ExpandProperty Sum}},
            @{N='NodesFailed';E={($_.NodeResults | Where-Object UpdateInstallResult -eq 'Failed').Count}} |
            Format-Table -AutoSize

        # Detailed results for most recent run
        $latest = $reports | Select-Object -First 1
        Write-Host "`nMost Recent Run — Per-Node Details:" -ForegroundColor Yellow
        if ($latest.NodeResults) {
            $latest.NodeResults | Select-Object `
                NodeName,
                UpdateInstallResult,
                UpdatesDownloaded,
                UpdatesInstalled,
                @{N='Rebooted';E={$_.NodeRebootRequired}} |
                Format-Table -AutoSize
        }
    } else {
        Write-Host "No CAU run history found." -ForegroundColor Yellow
    }
} catch {
    Write-Warning "Could not retrieve CAU history: $_"
}

Write-Section "PER-NODE UPDATE COMPLIANCE"
$nodes = Get-ClusterNode -Cluster $ClusterName | Where-Object State -eq 'Up'
foreach ($node in $nodes) {
    Write-Host "`n[$($node.Name)]" -ForegroundColor White
    try {
        # Use WMI to check for pending updates
        $session = New-CimSession -ComputerName $node.Name -ErrorAction Stop
        $lastBoot = (Get-CimInstance Win32_OperatingSystem -CimSession $session).LastBootUpTime
        $osInfo   = Get-CimInstance Win32_OperatingSystem -CimSession $session
        Write-Host "  OS:           $($osInfo.Caption) $($osInfo.BuildNumber)"
        Write-Host "  Last Reboot:  $lastBoot"
        Remove-CimSession $session
    } catch {
        Write-Host "  [Could not connect via CIM: $_]" -ForegroundColor Red
    }
}

Write-Section "CAU SCAN (AVAILABLE UPDATES)"
Write-Host "Running CAU scan to identify available updates..." -ForegroundColor Yellow
Write-Host "(This may take several minutes per node)" -ForegroundColor Gray
try {
    $scanResult = Invoke-CauScan -ClusterName $cluster.Name `
        -CauPluginName Microsoft.WindowsUpdatePlugin `
        -ErrorAction Stop
    if ($scanResult) {
        $scanResult | Group-Object NodeName | ForEach-Object {
            Write-Host "`n[$($_.Name)] — $($_.Count) update(s) available:" -ForegroundColor $(if ($_.Count -gt 0) {'Yellow'} else {'Green'})
            $_.Group | Select-Object Title, KBArticleIDs, DownloadSize | Format-Table -AutoSize
        }
    } else {
        Write-Host "All nodes are up to date." -ForegroundColor Green
    }
} catch {
    Write-Warning "CAU scan skipped or failed: $_"
}
```

---

### Script 07 — Cluster Validation Wrapper

```powershell
<#
.SYNOPSIS
    Runs cluster validation (Test-Cluster) and summarizes results.
.DESCRIPTION
    Executes Test-Cluster with configurable test categories, saves the HTML report,
    and parses results to surface warnings and failures. Safe to run on live clusters
    when using non-destructive test categories.
.NOTES
    Version:    1.0
    Author:     WSFC Agent Library
    Read-only:  Depends on parameters — Storage tests may briefly interrupt I/O
    Requires:   FailoverClusters PowerShell module, local admin on all nodes
    Platform:   Windows Server 2016, 2019, 2022, 2025
    WARNING:    Storage validation tests can briefly pause storage access.
                Use -SkipStorageTests on production clusters unless in maintenance.
#>

#Requires -Module FailoverClusters

param(
    [string[]]$Nodes,
    [string]$ClusterName      = ".",
    [string]$ReportPath       = "C:\ClusterValidation",
    [switch]$SkipStorageTests,
    [switch]$NetworkOnly,
    [switch]$SystemConfigOnly
)

function Write-Section {
    param([string]$Title)
    Write-Host "`n$('=' * 60)" -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host "$('=' * 60)" -ForegroundColor Cyan
}

# Ensure output directory exists
if (-not (Test-Path $ReportPath)) {
    New-Item -Path $ReportPath -ItemType Directory -Force | Out-Null
}

$reportFile = Join-Path $ReportPath ("ClusterValidation_{0:yyyyMMdd_HHmmss}" -f (Get-Date))

# Determine which nodes to test
if (-not $Nodes) {
    try {
        $clusterNodes = Get-ClusterNode -Cluster $ClusterName -ErrorAction Stop
        $Nodes = $clusterNodes.Name
    } catch {
        Write-Error "Could not get cluster nodes and no -Nodes parameter specified: $_"
        exit 1
    }
}

Write-Section "CLUSTER VALIDATION"
Write-Host "Nodes to validate: $($Nodes -join ', ')" -ForegroundColor Yellow
Write-Host "Report output:     $reportFile.htm"

# Build include list
$includeTests = @()
if ($NetworkOnly) {
    $includeTests = @('Network')
    Write-Host "Test scope: Network only" -ForegroundColor Yellow
} elseif ($SystemConfigOnly) {
    $includeTests = @('System Configuration')
    Write-Host "Test scope: System Configuration only" -ForegroundColor Yellow
} elseif ($SkipStorageTests) {
    $includeTests = @('Network', 'System Configuration', 'Inventory', 'Hyper-V Configuration')
    Write-Host "Test scope: All except Storage (safe for live cluster)" -ForegroundColor Yellow
} else {
    Write-Host "Test scope: Full validation (includes Storage — may briefly interrupt I/O)" -ForegroundColor Red
    Write-Host "Use -SkipStorageTests to exclude storage tests on live clusters." -ForegroundColor Yellow
    $proceed = Read-Host "Continue with full validation? (y/N)"
    if ($proceed -ne 'y') {
        Write-Host "Validation cancelled." -ForegroundColor Yellow
        exit 0
    }
}

Write-Host "`nStarting validation at $(Get-Date)..." -ForegroundColor Cyan

$testParams = @{
    Node       = $Nodes
    ReportName = $reportFile
    Verbose    = $true
}
if ($includeTests.Count -gt 0) {
    $testParams['Include'] = $includeTests
}

try {
    $result = Test-Cluster @testParams 2>&1
    Write-Host "Validation completed at $(Get-Date)." -ForegroundColor Green
} catch {
    Write-Error "Test-Cluster failed: $_"
}

Write-Section "VALIDATION RESULTS SUMMARY"
$htmlReport = "$reportFile.htm"

if (Test-Path $htmlReport) {
    Write-Host "HTML Report saved: $htmlReport" -ForegroundColor Green

    # Parse results from the report if possible
    $reportContent = Get-Content $htmlReport -Raw -ErrorAction SilentlyContinue

    if ($reportContent) {
        $warnings = ([regex]::Matches($reportContent, 'class="warn"')).Count
        $failures  = ([regex]::Matches($reportContent, 'class="fail"')).Count
        $successes = ([regex]::Matches($reportContent, 'class="pass"')).Count

        Write-Host "`nResult Counts:"
        Write-Host "  Passed:   $successes" -ForegroundColor Green
        Write-Host "  Warnings: $warnings"  -ForegroundColor $(if ($warnings -gt 0) {'Yellow'} else {'Green'})
        Write-Host "  Failed:   $failures"  -ForegroundColor $(if ($failures -gt 0) {'Red'} else {'Green'})

        if ($failures -gt 0) {
            Write-Host "`n[ALERT] Validation failures detected. Review $htmlReport for details." -ForegroundColor Red
        } elseif ($warnings -gt 0) {
            Write-Host "`n[WARNING] Validation warnings present. Review $htmlReport for details." -ForegroundColor Yellow
        } else {
            Write-Host "`nAll validation tests passed." -ForegroundColor Green
        }
    }

    # Open report in browser if interactive
    if ($host.Name -eq 'ConsoleHost' -and -not [Environment]::UserInteractive -eq $false) {
        $open = Read-Host "Open report in browser? (y/N)"
        if ($open -eq 'y') { Start-Process $htmlReport }
    }
} else {
    Write-Warning "Report file not found at expected location: $htmlReport"
}

Write-Section "COMMON VALIDATION ISSUES REFERENCE"
@'
FAILURE: "Could not validate disk..." — Check SAN zoning, iSCSI initiator, MPIO
FAILURE: "Node cannot be reached" — Firewall, DNS, WMI access
WARNING: "NIC driver version mismatch" — Update NIC drivers to same version
WARNING: "Not all nodes have same hotfix level" — Apply pending Windows Updates
FAILURE: "SCSI-3 Persistent Reservations not supported" — Replace storage or use S2D
WARNING: "Binding order not optimal" — Move cluster NIC to top of binding order
FAILURE: "Cannot resolve cluster name" — Check DNS, cluster name registration
'@ | Write-Host -ForegroundColor Gray
```

---

### Script 08 — Always On AG Cluster Health

```powershell
<#
.SYNOPSIS
    SQL Server Always On Availability Group cluster health check via WSFC.
.DESCRIPTION
    Inspects SQL Server Availability Group cluster resources, replica sync status,
    AG health state, and failover readiness for AGs hosted on Windows Server
    Failover Clustering.
.NOTES
    Version:    1.0
    Author:     WSFC Agent Library
    Read-only:  Yes — no cluster or SQL modifications made
    Requires:   FailoverClusters module; SqlServer module optional for deep SQL queries
    Platform:   Windows Server 2016, 2019, 2022, 2025 with SQL Server 2016+
#>

#Requires -Module FailoverClusters

param(
    [string]$ClusterName      = ".",
    [switch]$IncludeSQLDetail,
    [string]$SQLCredential    = $null
)

function Write-Section {
    param([string]$Title)
    Write-Host "`n$('=' * 60)" -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host "$('=' * 60)" -ForegroundColor Cyan
}

try {
    $cluster = Get-Cluster -Name $ClusterName -ErrorAction Stop
} catch {
    Write-Error "Cannot connect to cluster '$ClusterName': $_"
    exit 1
}

Write-Section "AG CLUSTER RESOURCES"
$allResources = Get-ClusterResource -Cluster $ClusterName
$agResources  = $allResources | Where-Object ResourceType -eq 'SQL Server Availability Group'
$sqlResources = $allResources | Where-Object ResourceType -eq 'SQL Server'
$sqlNetResources = $allResources | Where-Object ResourceType -eq 'SQL Server Network Name'
$sqlIPResources  = $allResources | Where-Object ResourceType -in @('IP Address','SQL IP Address')

if (-not $agResources) {
    Write-Host "No SQL Server Availability Group resources found on this cluster." -ForegroundColor Yellow
    Write-Host "`nSQL Server FCI resources found:" -ForegroundColor Yellow
    $sqlResources | Select-Object Name, State, OwnerGroup, OwnerNode | Format-Table -AutoSize
    exit 0
}

Write-Host "Found $($agResources.Count) AG resource(s):" -ForegroundColor Green
$agResources | Select-Object `
    Name,
    State,
    OwnerGroup,
    OwnerNode,
    @{N='RestartAction';E={$_.RestartAction}} |
    Format-Table -AutoSize

Write-Section "AG RESOURCE GROUPS"
$agGroups = foreach ($ag in $agResources) {
    Get-ClusterGroup -Cluster $ClusterName -Name $ag.OwnerGroup -ErrorAction SilentlyContinue
}

$agGroups | Select-Object `
    Name,
    State,
    OwnerNode,
    @{N='FailoverThreshold';E={$_.FailoverThreshold}},
    @{N='FailoverPeriod (hrs)';E={$_.FailoverPeriod}},
    @{N='AutoFailback';E={switch ($_.AutoFailbackType) {0{'Prevent'}; 1{'Allow'}; 2{'Windowed'}}}} |
    Format-Table -AutoSize

Write-Section "AG RESOURCE PARAMETERS"
foreach ($ag in $agResources) {
    Write-Host "`nAG Resource: $($ag.Name) [Group: $($ag.OwnerGroup)]" -ForegroundColor White
    $params = $ag | Get-ClusterParameter -ErrorAction SilentlyContinue
    if ($params) {
        $params | Select-Object Name, Value | Format-Table -AutoSize
    }

    # Check possible owners
    $possibleOwners = (Get-ClusterOwnerNode -Resource $ag.Name -Cluster $ClusterName).OwnerNodes
    Write-Host "  Possible Owners: $($possibleOwners -join ', ')"
}

Write-Section "SQL SERVER FCI RESOURCES (Co-located)"
if ($sqlResources) {
    $sqlResources | Select-Object Name, State, OwnerGroup, OwnerNode | Format-Table -AutoSize
} else {
    Write-Host "No standalone SQL Server FCI resources found (AGs may use listener-only mode)." -ForegroundColor Gray
}

Write-Section "AG LISTENER NETWORK RESOURCES"
$listenerIPs = $sqlIPResources | Where-Object {
    $group = $_.OwnerGroup
    $agGroups | Where-Object Name -eq $group
}

if ($listenerIPs) {
    Write-Host "AG Listener IP Resources:" -ForegroundColor Yellow
    foreach ($ip in $listenerIPs) {
        $params = $ip | Get-ClusterParameter -ErrorAction SilentlyContinue
        $addr   = ($params | Where-Object Name -eq 'Address').Value
        $mask   = ($params | Where-Object Name -eq 'SubnetMask').Value
        $net    = ($params | Where-Object Name -eq 'Network').Value
        Write-Host "  $($ip.Name): $addr/$mask on '$net' [$($ip.State)] — Group: $($ip.OwnerGroup)"
    }
}

Write-Section "SQL DEEP INSPECTION (via SqlServer Module)"
if ($IncludeSQLDetail) {
    if (-not (Get-Module -Name SqlServer -ListAvailable)) {
        Write-Warning "SqlServer PowerShell module not installed. Install with: Install-Module SqlServer"
    } else {
        Import-Module SqlServer

        foreach ($node in (Get-ClusterNode -Cluster $ClusterName | Where-Object State -eq 'Up')) {
            Write-Host "`n[Node: $($node.Name)]" -ForegroundColor White
            try {
                $sqlInstances = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server' -ErrorAction SilentlyContinue
                # Try to connect to each SQL instance
                $connParam = if ($SQLCredential) {
                    @{Credential = $SQLCredential; TrustServerCertificate = $true}
                } else {
                    @{TrustServerCertificate = $true}
                }

                # Query AG replica health via SMO
                $agQuery = @"
SELECT
    ag.name AS AGName,
    ar.replica_server_name AS ReplicaServer,
    ar.availability_mode_desc AS AvailabilityMode,
    ar.failover_mode_desc AS FailoverMode,
    ars.role_desc AS CurrentRole,
    ars.connected_state_desc AS ConnectionState,
    ars.synchronization_health_desc AS SyncHealth,
    ars.last_connect_error_description AS LastError
FROM sys.availability_groups ag
JOIN sys.availability_replicas ar ON ag.group_id = ar.group_id
JOIN sys.dm_hadr_availability_replica_states ars ON ar.replica_id = ars.replica_id
ORDER BY ag.name, ar.replica_server_name
"@
                $results = Invoke-Sqlcmd -ServerInstance $node.Name -Query $agQuery @connParam -ErrorAction Stop
                if ($results) {
                    Write-Host "  AG Replica Health:" -ForegroundColor Yellow
                    $results | Format-Table AGName, ReplicaServer, CurrentRole, AvailabilityMode, 
                                           SyncHealth, ConnectionState -AutoSize

                    # Flag unhealthy replicas
                    $unhealthy = $results | Where-Object { $_.SyncHealth -ne 'HEALTHY' }
                    if ($unhealthy) {
                        Write-Host "  [WARNING] Unhealthy replicas:" -ForegroundColor Red
                        $unhealthy | Select-Object AGName, ReplicaServer, SyncHealth, LastError | Format-Table -AutoSize
                    }
                }

                # AG database sync state
                $dbQuery = @"
SELECT
    ag.name AS AGName,
    db.name AS DatabaseName,
    drs.synchronization_state_desc AS SyncState,
    drs.synchronization_health_desc AS SyncHealth,
    drs.redo_queue_size AS RedoQueueKB,
    drs.log_send_queue_size AS SendQueueKB,
    drs.is_suspended AS IsSuspended
FROM sys.availability_groups ag
JOIN sys.availability_replicas ar ON ag.group_id = ar.group_id
JOIN sys.dm_hadr_database_replica_states drs ON ar.replica_id = drs.replica_id
JOIN sys.databases db ON drs.database_id = db.database_id
ORDER BY ag.name, db.name
"@
                $dbResults = Invoke-Sqlcmd -ServerInstance $node.Name -Query $dbQuery @connParam -ErrorAction Stop
                if ($dbResults) {
                    Write-Host "  AG Database Sync State:" -ForegroundColor Yellow
                    $dbResults | Format-Table AGName, DatabaseName, SyncState, SyncHealth, 
                                             RedoQueueKB, SendQueueKB, IsSuspended -AutoSize
                }

            } catch {
                Write-Host "  [SQL connection failed: $_]" -ForegroundColor Red
            }
        }
    }
} else {
    Write-Host "SQL deep inspection skipped. Run with -IncludeSQLDetail for AG replica/database sync status." -ForegroundColor Gray
}

Write-Section "FAILOVER READINESS SUMMARY"
foreach ($ag in $agResources) {
    $group = Get-ClusterGroup -Cluster $ClusterName -Name $ag.OwnerGroup -ErrorAction SilentlyContinue
    $ready = $ag.State -eq 'Online' -and $group.State -eq 'Online'
    $preferredOwners = (Get-ClusterOwnerNode -Group $ag.OwnerGroup -Cluster $ClusterName).OwnerNodes

    Write-Host "`nAG: $($ag.Name)" -ForegroundColor White
    Write-Host "  Resource State:    $($ag.State)" -ForegroundColor $(if ($ag.State -eq 'Online') {'Green'} else {'Red'})
    Write-Host "  Group State:       $($group.State)" -ForegroundColor $(if ($group.State -eq 'Online') {'Green'} else {'Red'})
    Write-Host "  Current Owner:     $($ag.OwnerNode)"
    Write-Host "  Preferred Owners:  $($preferredOwners -join ' > ')"
    Write-Host "  Failover-Ready:    $ready" -ForegroundColor $(if ($ready) {'Green'} else {'Red'})

    $possibleOwners = (Get-ClusterOwnerNode -Resource $ag.Name -Cluster $ClusterName).OwnerNodes
    $otherOwners = $possibleOwners | Where-Object { $_ -ne $ag.OwnerNode }
    if ($otherOwners) {
        Write-Host "  Failover Targets:  $($otherOwners -join ', ')" -ForegroundColor Yellow
    } else {
        Write-Host "  [WARNING] No failover targets available (only one possible owner)" -ForegroundColor Red
    }
}
```

---

## APPENDIX: QUICK REFERENCE

### Key PowerShell Commands

```powershell
# Core status
Get-Cluster | Format-List *
Get-ClusterNode
Get-ClusterGroup | Sort-Object State
Get-ClusterResource | Where-Object State -ne 'Online'
Get-ClusterSharedVolume | Select-Object Name, State, OwnerNode

# Quorum
Get-ClusterQuorum
Set-ClusterQuorum -CloudWitness -AccountName "" -AccessKey ""
Set-ClusterQuorum -FileShareWitness "\\server\share"
Set-ClusterQuorum -NodeMajority

# Node management
Suspend-ClusterNode -Name "" -Drain
Resume-ClusterNode -Name "" -Failback Immediate
Start-ClusterNode -FixQuorum   # EMERGENCY ONLY

# Failover
Move-ClusterGroup -Name "" -Node ""
Stop-ClusterResource -Name ""
Start-ClusterResource -Name ""

# Logging
Get-ClusterLog -Destination "C:\Logs" -TimeSpan 30
(Get-Cluster).ClusterLogLevel = 3

# Validation
Test-Cluster -Node "n1","n2" -Include "Network","System Configuration"
```

### Critical File/Path Reference

| Path | Description |
|---|---|
| `C:\Windows\Cluster\CLUSDB` | Cluster database binary hive |
| `C:\Windows\Cluster\Reports\` | Cluster log output directory |
| `C:\ClusterStorage\` | CSV namespace root |
| `HKLM:\Cluster\` | Cluster registry hive (when mounted) |
| `C:\Windows\System32\clussvc.exe` | Cluster Service binary |
| `C:\Windows\System32\rhs.exe` | Resource Host Subsystem binary |
| `%SystemRoot%\Cluster\clus*.log` | Cluster service debug logs |

### Cluster Ports Reference

| Port | Protocol | Purpose |
|---|---|---|
| 3343 | UDP | Cluster heartbeat |
| 3343 | TCP | Cluster communication |
| 445 | TCP | SMB (CSV redirected I/O, file share witness) |
| 135 | TCP | RPC endpoint mapper |
| Dynamic | TCP | RPC dynamic ports (cluster management) |
| 49152-65535 | TCP | RPC dynamic range |
