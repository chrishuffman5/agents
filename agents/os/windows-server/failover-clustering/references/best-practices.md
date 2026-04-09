# Failover Clustering Best Practices Reference

## Cluster Design

### Hardware Requirements

All nodes must pass cluster validation (`Test-Cluster`) before production deployment.

**Hardware consistency** is strongly recommended:
- Identical CPU generation, NIC models, BIOS/UEFI versions, NIC firmware, and drivers across all nodes
- Mixed hardware is supportable but complicates updates and may trigger validation warnings
- Validate with: `Test-Cluster -Node node1,node2 -Include "Storage","Network","System Configuration"`

**Maximum nodes per cluster**: 64 (all versions 2016-2025)

**Edition requirements**:
- Standard edition: Basic Failover Clustering (2 VMs on the cluster)
- Datacenter edition: Unlimited VMs, Storage Spaces Direct, Storage Replica, Shielded VMs, Network Controller

### Network Design

Minimum two networks per node: one for client access, one for cluster heartbeat.

**Dedicated heartbeat NIC configuration**:
- No default gateway assigned
- No DNS registration
- Static IP address on a separate subnet
- Disable NetBIOS and LMHOSTS lookup
- Cluster network role set to 1 (Cluster Only)

**NIC teaming recommendations**:
- Switch Embedded Teaming (SET) for Hyper-V environments -- integrates with vSwitch, supports RDMA and SR-IOV
- SET is required for Storage Spaces Direct deployments
- Legacy LBFO teaming is acceptable for non-Hyper-V clusters but cannot be used with RDMA

**RDMA/SMB Direct NICs** dramatically improve CSV and live migration performance. Use 25 GbE or 100 GbE RDMA adapters for production hyper-converged deployments.

### Storage Design

**Traditional shared storage (SAN/NAS)**:
- Fibre Channel: Lowest latency, most common in enterprise deployments
- iSCSI: Cost-effective, requires dedicated NIC or VLAN separation from cluster traffic
- Shared SAS: For small deployments with directly attached storage
- All nodes must see all shared disks via the same disk signature/GUID
- Multipath I/O (MPIO) is required: `Install-WindowsFeature Multipath-IO`
- MPIO policy: Round Robin or Least Queue Depth recommended

**Storage Spaces Direct (S2D)**:
- Hyper-converged storage built into Windows Server, no shared storage needed
- Requires Windows Server Datacenter edition (or Azure Stack HCI)
- Uses local NVMe, SSD, and HDD disks on each node
- Minimum 2 nodes, maximum 16 nodes per S2D cluster
- Cache tier: NVMe or SSD; capacity tier: SSD or HDD
- Resilience types: 2-way mirror (2+ nodes), 3-way mirror (3+ nodes), dual parity (4+ nodes)
- Network: RDMA required for production (25 GbE or 100 GbE recommended)
- Enable with: `Enable-ClusterStorageSpacesDirect`

---

## Cluster-Aware Updating (CAU) Best Practices

### Configuration Recommendations

Configure CAU in self-updating mode for automated, scheduled patching:

```powershell
Add-CauClusterRole -ClusterName "Cluster1" `
    -DaysOfWeek Saturday `
    -IntervalWeeks 2 `
    -StartTime "02:00" `
    -EnableFirewallRules `
    -MaxFailedNodes 1 `
    -MaxRetriesPerNode 3 `
    -RequireAllNodesConnected `
    -Force
```

**Key settings**:
- Schedule updates during maintenance windows (weekends, off-hours)
- Set `MaxFailedNodes` to 1 for production clusters -- stops the run if one node fails to update rather than risking the entire cluster
- Set `RequireAllNodesConnected` to prevent updates when a node is already down
- Use pre/post update scripts for application-specific preparation and validation

### CAU Plug-in Selection

- **Microsoft.WindowsUpdatePlugin** (default): Uses Windows Update or WSUS. Best for standard monthly patching.
- **Microsoft.HotfixPlugin**: Applies hotfixes from a file share (CAB/MSP files). Use when updates must be staged offline or when WSUS is not available.

### Monitoring CAU

```powershell
# Preview available updates without applying
Invoke-CauScan -ClusterName "Cluster1" -CauPluginName Microsoft.WindowsUpdatePlugin

# Check last run result
Get-CauReport -ClusterName "Cluster1" -Last | Format-List

# Check if a run is in progress
Get-CauRun -ClusterName "Cluster1"

# Stop a problematic run
Stop-CauRun -ClusterName "Cluster1" -Force
```

---

## High Availability Patterns

### Active/Passive

One resource group (role) runs on a single active node; remaining nodes are standby:
- SQL Server FCI: One active instance with automatic failover to the passive node
- File Server role: One active owner, failover on failure
- Simplest pattern with guaranteed resource availability

### Active/Active

Multiple roles distributed across nodes, each owned by different nodes:
- Example: Node 1 runs SQL Instance A, Node 2 runs SQL Instance B
- Both nodes are actively utilized
- On failure, the surviving node hosts both instances
- Requires N+1 capacity: the surviving node must handle 100% of the failed node's workload

### N+1 Capacity Planning

Always plan for at least one node failure:
- If the cluster has N nodes and M resource groups, the surviving N-1 nodes must run all M groups
- CPU and memory on each node should support the additional load of a failover
- Storage IOPS per node must handle additional workloads post-failover
- Test by draining a node (`Suspend-ClusterNode -Name "Node2" -Drain`) and measuring resource utilization on surviving nodes

### Stretch Clusters (Multi-Site)

Nodes in two or more physical sites connected via WAN:
- Site awareness (2016+): Cluster knows which nodes are in which site via fault domains
- Storage replication between sites required (Storage Replica feature, Datacenter edition)
- Quorum: Use a cloud witness or file share witness in a third site to break site-level ties
- Failover priority: Prefer same-site resources; cross-site failover only when the entire site fails

```powershell
# Configure site-aware fault domains (2016+)
New-ClusterFaultDomain -Name "SiteA" -Type Site
New-ClusterFaultDomain -Name "SiteB" -Type Site
Get-ClusterNode -Name "Node1","Node2" | Set-ClusterFaultDomain -Parent "SiteA"
Get-ClusterNode -Name "Node3","Node4" | Set-ClusterFaultDomain -Parent "SiteB"

# View fault domain hierarchy
Get-ClusterFaultDomain | Format-Table Name, Type, Parent
```

### Cluster Sets (2019+)

Cluster sets group multiple independent clusters under a single management namespace:
- A master cluster hosts the cluster set management resource
- Member clusters join the set and expose their workloads
- Workloads (VMs) can live migrate across clusters within the set
- Shared namespaces via Scale-Out File Server (SOFS) referrals
- Use case: Large-scale hyper-converged deployments requiring more than 16 S2D nodes

```powershell
New-ClusterSet -Name "MyClusterSet" -NamespaceRoot "\\ClusterSetSMBShare" -CimSession "ManagementCluster"
Add-ClusterSetMember -ClusterName "Cluster1" -CimSession "ManagementCluster"
```

---

## Anti-Affinity and Workload Separation

Prevent critical VMs or roles from running on the same node:

```powershell
# Set anti-affinity class (groups with the same class name avoid co-locating)
(Get-ClusterGroup "VM1").AntiAffinityClassNames = "CriticalVMs"
(Get-ClusterGroup "VM2").AntiAffinityClassNames = "CriticalVMs"

# Configure preferred owners (order matters: first = most preferred)
Set-ClusterOwnerNode -Group "SQL Server Role" -Owners "Node1","Node2","Node3"

# Restrict possible owners (which nodes CAN host the resource)
Set-ClusterOwnerNode -Resource "SQL Server" -Owners "Node1","Node2"
```

Anti-affinity is a soft constraint -- if a failover occurs and no other node is available, anti-affinity is violated to keep the workload running. Design the cluster with enough nodes to honor anti-affinity even during a single-node failure.

---

## Node Drain and Maintenance Procedures

### Pre-Maintenance Drain

Always drain a node before performing maintenance to move all roles off gracefully:

```powershell
# Drain node (moves all roles to other nodes according to preferred owners)
Suspend-ClusterNode -Name "Node2" -Drain

# Check drain status
Get-ClusterNode | Select-Object Name, State, DrainStatus

# After maintenance, resume the node
Resume-ClusterNode -Name "Node2" -Failback Immediate
```

`-Failback Immediate` returns roles to the node immediately. Use `-Failback NoFailback` to leave roles on their current owners and only return them during the failback window.

### Pause Without Drain

For quick operations that do not require moving roles (e.g., a brief reboot where the node will return before failover thresholds trigger):

```powershell
Suspend-ClusterNode -Name "Node2"   # no -Drain flag
```

---

## Quorum Design Guidelines

| Cluster Size | Recommended Quorum Model |
|---|---|
| 2 nodes | Node + File Share Majority or Node + Cloud Witness |
| 3 nodes | Node Majority (no witness needed, but a witness adds tolerance) |
| 4 nodes | Node + Witness (disk, file share, or cloud) |
| 5+ nodes | Node Majority or Node + Witness for additional resilience |
| Multi-site | Cloud Witness in a third site (Azure region) |

**Always configure a witness** for production clusters, even with an odd number of nodes. The witness provides an additional failure tolerance margin.

**Cloud witness** is the preferred witness type for new deployments because:
- No dependency on shared storage or a separate file server
- Survives datacenter-level failures
- Minimal cost (Azure Blob Storage)
- Works across all network topologies

---

## SQL Server Integration (Always On Availability Groups)

SQL Server Always On AGs running on WSFC have specific cluster design requirements:

- Each AG is a cluster resource of type "SQL Server Availability Group"
- The cluster provides health monitoring; SQL Server manages data replication
- Automatic failover requires synchronous-commit replicas and quorum
- Supports up to 9 secondary replicas (SQL Server 2019+)
- Configure AG resource `HealthCheckTimeout` and `FailureConditionLevel` to control when the cluster considers the AG unhealthy

**Best practices for AG clusters**:
- Use cloud witness or file share witness (not disk witness) because AGs do not use shared storage
- Set `RegisterAllProvidersIP = 1` and `HostRecordTTL = 300` (or lower) on the AG listener network name for faster multi-subnet failover
- Configure the AG group's `FailoverThreshold` conservatively (default 3 in 6 hours) to prevent unnecessary failovers during transient issues
- Test failover regularly with `Invoke-Sqlcmd` or SSMS to validate end-to-end behavior

---

## Monitoring and Alerting

### Essential Monitoring Targets

| Check | Frequency | Alert Threshold |
|---|---|---|
| Node state | 1 minute | Any node not in "Up" state |
| Resource group state | 1 minute | Any group not "Online" |
| CSV free space | 15 minutes | Below 20% (warning), below 10% (critical) |
| CSV redirected I/O | 5 minutes | Any CSV in redirected mode |
| Quorum margin | 5 minutes | 1 or fewer votes above threshold |
| Cluster event log | Continuous | Event IDs 1069, 1135, 1146, 1177, 5120 |
| CAU run status | Daily | Failed or incomplete runs |

### Proactive Health Commands

```powershell
# Quick cluster health snapshot
Get-ClusterNode | Where-Object State -ne 'Up'
Get-ClusterGroup | Where-Object State -ne 'Online'
Get-ClusterResource | Where-Object State -eq 'Failed'
Get-ClusterSharedVolume | Where-Object { $_.SharedVolumeInfo.RedirectedIOReason -ne 0 }
```
