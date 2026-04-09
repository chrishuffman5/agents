# Hyper-V Best Practices Reference

## VM Configuration

### CPU Right-Sizing

- **vCPU-to-pCore ratio**: Keep total vCPU allocation across all running VMs below 4:1 per physical core for production workloads (OLTP, web). Up to 8:1 is acceptable for dev/test or light workloads.
- **Virtual NUMA alignment**: Assign vCPUs that fit within a single NUMA node's logical processor count. A host with two 16-core sockets (32 pCores, 64 HT threads) has 32 logical processors per NUMA node. VMs with <=32 vCPUs can be fully NUMA-aligned.
- **Hyper-threading awareness**: Hyper-V exposes logical processors (HT threads). Avoid allocating more vCPUs than physical cores for latency-sensitive workloads -- HT sharing causes execution interference.
- **NUMA topology exposure**: For large VMs, set virtual NUMA nodes explicitly:
  ```powershell
  Set-VMProcessor -VMName "BigVM" -MaximumCountPerNumaNode 16 -MaximumCountPerNumaSocket 32
  ```
- **CPU compatibility for live migration**: When migrating between hosts with different CPU models, enable Processor Compatibility Mode:
  ```powershell
  Set-VMProcessor -VMName "VM1" -CompatibilityForMigrationEnabled $true
  ```
  This limits exposed CPU features to a common baseline, allowing migration at the cost of some advanced instruction availability.

### Memory Allocation

- **Dynamic Memory for variable workloads**: Web servers, app servers, and batch processors benefit from DM. Set Minimum RAM to the OS idle requirement and Maximum to the workload peak.
- **Static Memory for databases**: SQL Server, Oracle, and other systems that manage their own memory caches should use static memory. The DM balloon driver competes with the application's internal memory management, causing unpredictable performance.
- **Avoid overcommit in production**: Never configure total Maximum RAM across all VMs to exceed physical RAM minus OS reservation (typically 1-4 GB). Overcommit triggers Smart Paging, which severely degrades performance.
- **Memory weight for critical VMs**: Set weight 9000-10000 for production VMs, 5000 for standard, 1000-2000 for dev/test. Higher weight gets preferential allocation when host memory is scarce.
- **Buffer percentage**: 20% is standard. For bursty workloads (task schedulers, batch jobs), increase to 30-40% to provide headroom for sudden demand spikes.

### Disk Configuration

- **Use VHDX for all new disks**. VHD is legacy and limited to 2 TB.
- **SCSI over IDE**: Gen2 VMs always use SCSI. Gen1 boot disks use IDE slot 0; additional data disks should use the SCSI controller.
- **Fixed vs Dynamic on SSD/NVMe**: On all-flash storage, dynamic VHDX overhead is negligible. On spinning disk or mixed HDD/SSD, fixed VHDX avoids fragmentation and guarantees sequential layout.
- **CSV placement**: In clustered environments, place VHDX files on Cluster Shared Volumes to enable live migration and quick failover.
- **Separate volumes**: Do not co-locate VHDX files and the host OS on the same volume. Use dedicated volumes for VM storage.
- **VHDX block size**: Default 32 MB for dynamic (can be set to 2 MB for smaller VMs). Rarely needs tuning.

---

## Checkpoint Best Practices

### Standard vs Production Checkpoints

| Feature | Standard | Production (default 2016+) |
|---|---|---|
| Mechanism | Saved state (memory snapshot) | VSS in guest / file system freeze |
| Application consistency | No (crash-consistent) | Yes |
| Suitable for production | No | Yes (with caveats) |

```powershell
Set-VM -VMName "VM1" -CheckpointType Production
# Options: Standard, Production, ProductionOnly, Disabled
```

### Performance Impact

When a checkpoint is created:
1. A differencing VHDX (.avhdx) is created
2. All writes go to the differencing disk
3. Reads that miss the avhdx fall through to the parent VHDX (I/O chain lengthens)
4. Deep chains (>3 checkpoints) measurably increase latency

When a checkpoint is deleted:
1. The avhdx must merge into the parent VHDX
2. Merge happens in the background and consumes I/O
3. During merge, the chain remains active and may slow the VM

### Recommendations

- **Dev/test**: Checkpoints are excellent for saving state before risky operations
- **Production**: Use Production checkpoints sparingly; delete after use (avoid long-lived chains)
- **Never use Standard checkpoints for production databases**: Standard checkpoints restore a crash-consistent state, not application-consistent
- **Checkpoint file location**: Place on fast storage separate from VM data if possible:
  ```powershell
  Set-VM -VMName "VM1" -SnapshotFileLocation "E:\Checkpoints\"
  ```

---

## Host Configuration

### Server Core for Hyper-V Hosts

Microsoft recommends Hyper-V hosts run Server Core (no Desktop Experience):
- Reduced attack surface (fewer binaries, fewer patches)
- Lower memory overhead (1-2 GB less than Desktop Experience)
- Fewer reboots required for updates
- Fully manageable via PowerShell, RSAT, and Windows Admin Center from remote workstations

### Anti-Virus Exclusions

Configure AV exclusions on the Hyper-V host for host-side file paths (not inside VMs):

| Exclusion | Pattern |
|---|---|
| Virtual disk files | `*.vhdx`, `*.vhd`, `*.avhdx`, `*.vhds`, `*.avhd` |
| VM config files | `*.vmcx`, `*.vmrs`, `*.vmgs` |
| Checkpoint files | `*.vsv`, `*.bin` |
| VM directories | Entire VM directory tree |
| Hyper-V process | `vmwp.exe` (VM Worker Process) |

### Dedicated NICs and Network Segmentation

Separate physical NICs (or SET-team groups) for each traffic type:

| Traffic Type | Bandwidth | Notes |
|---|---|---|
| VM network traffic | 10 GbE+ (25/40/100 GbE) | Can share with management if necessary |
| Management (RDP, admin) | 1 GbE minimum | Dedicated recommended |
| Live Migration | 10 GbE+ | Use RDMA (SMB Direct) for speed |
| CSV / Storage (SMB/iSCSI) | 10 GbE+ with RDMA preferred | Separate from VM traffic |
| Cluster heartbeat | 1 GbE | Dedicated crossover or separate switch |

```powershell
# Restrict live migration to a specific network
Set-VMMigrationNetwork -ComputerName "HV-HOST01" -Subnet "192.168.10.0/24" -Priority 1
```

### NUMA-Aware VM Placement

```powershell
# View physical NUMA topology
Get-VMHostNumaNode | Select-Object NodeId, MemoryAvailable, MemoryTotal, ProcessorsAvailable

# View VM NUMA placement
Get-VM | ForEach-Object {
    $vm = $_
    Get-VMNumaNodeStatus -VM $vm | Select-Object @{n="VM";e={$vm.Name}}, NodeId, MemoryAssigned, ProcessorCount
}
```

Strategy:
- Place large VMs first (most NUMA-constrained)
- Group related VMs on the same NUMA node to reduce cross-node traffic
- Monitor NUMA hot-plug warnings in the event log

---

## Live Migration Configuration

### Performance Options

| Option | Best For | Mechanism |
|---|---|---|
| SMBTransport | RDMA NICs, 10 GbE+ | SMB Direct; fastest on high-bandwidth networks |
| Compression | Slower networks, no RDMA | CPU-based compression; reduces network usage |
| TCP (default) | Fallback | Uncompressed TCP; slowest |

```powershell
Set-VMHost -VirtualMachineMigrationPerformanceOption SMBTransport
Set-VMHost -MaximumVirtualMachineMigrations 4 -MaximumStorageMigrations 2
```

### Authentication

- **Kerberos** (recommended): Both hosts in the same domain. Secure, no additional config.
- **CredSSP**: For non-domain or complex trust scenarios. Requires credential delegation setup.

```powershell
Set-VMHost -VirtualMachineMigrationAuthenticationType Kerberos
```

### Prerequisites

1. Both hosts in the same domain (Kerberos) or CredSSP configured
2. Firewall rules: TCP 6600 (live migration), TCP 445 (SMB), TCP 135 (RPC)
3. Processors compatible or Compatibility Mode enabled on the VM
4. Shared storage accessible from both hosts (for standard live migration) or sufficient bandwidth (for shared-nothing)

### Pre-Flight Testing

```powershell
Test-VMMigration -VMName "VM1" -DestinationHost "HV-HOST02"
```

---

## Hyper-V Replica Configuration

### Design Recommendations

- **Replication interval**: 30 seconds for critical VMs with low RPO requirements; 5 or 15 minutes for less critical workloads
- **Recovery points**: Enable additional recovery points (up to 24 hourly snapshots) for point-in-time recovery at the replica
- **Compression**: Enable for WAN links to reduce bandwidth consumption
- **Authentication**: Kerberos within the same domain; certificate-based for workgroup/DMZ scenarios

```powershell
Enable-VMReplication -VMName "VM1" -ReplicaServerName "DR-HOST" `
    -ReplicaServerPort 8080 -AuthenticationType Kerberos `
    -ReplicationFrequencySec 300 -CompressionEnabled $true
Start-VMInitialReplication -VMName "VM1"
```

### Failover Types

- **Planned failover**: Graceful. Synchronizes the final delta before switching. Zero data loss.
  ```powershell
  Start-VMFailover -VMName "VM1" -Prepare    # on primary
  Start-VMFailover -VMName "VM1"             # on replica
  Complete-VMFailover -VMName "VM1"          # on replica
  ```
- **Unplanned failover**: Primary is down. Potential data loss of up to one replication interval.
  ```powershell
  Start-VMFailover -VMName "VM1"             # on replica
  Complete-VMFailover -VMName "VM1"
  ```

### Extended Replication

Chain: Primary -> Replica -> Extended Replica (three-site). The extended replica is a replica of the replica, providing a third copy in a separate location.

---

## Monitoring Targets

### Essential Checks

| Check | Frequency | Alert Threshold |
|---|---|---|
| VM state | 1 minute | Any VM in unexpected state (Off, Saved, Paused) |
| Host CPU utilization | 5 minutes | >90% sustained (Guest + Hypervisor) |
| Memory pressure | 5 minutes | >150% (severe pressure; guest is paging) |
| VHDX disk latency | 5 minutes | >20 ms average read/write |
| vSwitch dropped packets | 5 minutes | Any non-zero count |
| Replication health | 15 minutes | State != Replicating or Health != Normal |
| Replication lag | 15 minutes | Lag > 2x replication frequency |
| Integration Services heartbeat | 1 minute | "Lost Communication" or "No Contact" |
| Checkpoint age | Daily | Any checkpoint older than 7 days |

### Quick Health Commands

```powershell
# VM state overview
Get-VM | Select-Object Name, State, CPUUsage, MemoryAssigned, Uptime | Format-Table -AutoSize

# Integration services heartbeat
Get-VM | ForEach-Object {
    $hb = Get-VMIntegrationService -VMName $_.Name -Name "Heartbeat" -ErrorAction SilentlyContinue
    [PSCustomObject]@{VM=$_.Name; State=$_.State; Heartbeat=$hb.PrimaryStatusDescription}
} | Format-Table -AutoSize

# Replication health
Get-VMReplication | Select-Object VMName, State, Health, LastReplicationTime | Format-Table -AutoSize

# Checkpoint inventory
Get-VM | Get-VMSnapshot -ErrorAction SilentlyContinue |
    Select-Object VMName, Name, SnapshotType, CreationTime | Format-Table -AutoSize
```
