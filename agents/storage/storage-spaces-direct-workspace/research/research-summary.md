# Storage Spaces Direct Research Summary

## Research Scope and Methodology

This research covers Windows Storage Spaces Direct (S2D) as a hyper-converged storage platform, sourced from Microsoft Learn official documentation, Microsoft TechCommunity blogs, and third-party technical references. Information is current as of April 2026, reflecting Windows Server 2025, Azure Local 23H2, and the most recent S2D capabilities.

---

## What S2D Is

Storage Spaces Direct is a software-defined storage (SDS) technology built into Windows Server Datacenter edition and Azure Local (formerly Azure Stack HCI). It takes 2–16 commodity servers with internal drives and creates a single, highly available, software-managed storage pool — eliminating the need for external SANs or specialized storage fabrics.

S2D is the storage engine underpinning Microsoft's hyper-converged infrastructure (HCI) strategy and is the core of Azure Local.

---

## Architecture Key Points

The S2D stack layers from hardware up:

1. **Networking** — Ethernet NICs (10 Gbps minimum; 25 Gbps+ with RDMA recommended)
2. **Failover Clustering** — Standard Windows failover cluster as the foundation
3. **Software Storage Bus** — Software-defined fabric that makes every server's drives visible cluster-wide; replaces physical SAN fabrics
4. **Storage Bus Layer (SBL) Cache** — Automatic server-side caching: fastest drives (NVMe/SSD) cache writes to slower drives (SSD/HDD)
5. **Storage Pool** — Single unified pool of all cluster drives; one per cluster
6. **Storage Spaces** — Virtual disks with resiliency: two-way mirror, three-way mirror, or erasure coding (parity)
7. **ReFS** — Mandatory filesystem; purpose-built for virtualization with checksums, VHDX acceleration, and real-time tiering
8. **CSV** — Cluster Shared Volumes unify all volumes under `C:\ClusterStorage\` on every node
9. **Scale-Out File Server** (converged only) — SMB3 NAS layer for separate compute clusters

The key innovation is the **Software Storage Bus**: instead of a physical SAN fabric, S2D creates a software fabric over standard Ethernet, using SMB3/SMB Direct (RDMA) for inter-node storage I/O.

---

## Feature Evolution Summary

| Version | Key Additions |
|---------|--------------|
| Windows Server 2016 | S2D launch: core SBL cache, storage pool, mirroring, parity, ReFS/CSV, SoFS, Storage QoS, fault domains, SMB Direct |
| Windows Server 2019 | Nested resiliency (2-node), performance history (1-year retention), scale to 4 PB / 400 TB per server |
| Windows Server 2022 | SMB east-west encryption (AES-128/256), SMB compression, simplified nested resiliency creation |
| Windows Server 2025 | Thin provisioning, NVMe-OF initiator (+90% IOPS), ReFS deduplication/compression, rack-local reads |
| Azure Stack HCI 22H2 | Thin provisioning (ahead of WS2025), volume resiliency modification, fixed-to-thin conversion, Storage Replica compression |
| Azure Local 23H2 | Azure Arc-enabled OS, Azure Lifecycle Manager, cloud-based deployment and monitoring, Arc VM management |

---

## Resiliency Options Summary

| Type | Copies | Efficiency | Min Nodes | Use Case |
|------|--------|-----------|-----------|---------|
| Two-way mirror | 2 | ~50% | 2 | 2-node clusters |
| Three-way mirror | 3 | ~33% | 3 | All-flash performance clusters |
| Mirror-accelerated parity | 1.5–2x | varies | 4+ | General purpose, large file servers |
| Nested two-way mirror | 4 | 25% | 2 (exactly) | 2-node max resilience |
| Nested MAP | 4 (varies) | 35–40% | 2 (exactly) | 2-node balanced resilience |

---

## Best Practices Summary

### Hardware
- Use validated hardware with SDDC Premium qualification
- All servers identical (manufacturer, model, drives)
- Cache drives: 32 GB minimum, 3+ DWPD endurance, must have power-loss protection
- SSDs must have power-loss protection (no consumer SSDs)
- Number of capacity drives = whole multiple of cache drives
- Use RDMA (iWARP preferred for ease; RoCE for maximum performance)
- 25 Gbps NICs for 4+ node clusters; minimum 10 Gbps for 2–3 node
- Define fault domains before enabling S2D

### Configuration
- One storage pool per cluster
- Run cluster validation (Test-Cluster) before S2D deployment
- Set 64 KB interleave for SQL Server workloads (default 256 KB)
- Enable Storage QoS policies to prevent VM I/O monopolization
- Configure CSV in-memory read cache for Hyper-V VDI workloads
- Always use storage maintenance mode before node patching

### Monitoring
- Use Windows Admin Center for graphical cluster and storage health dashboards
- Use `Get-HealthFault` and `Get-StorageJob` for automated health checking
- Monitor pool capacity: alert at 80%, critical at 90%
- Performance history (WS2019+) provides 1 year of metric retention; query with `Get-ClusterPerf`

---

## Diagnostics Summary

### Diagnostic Command Hierarchy

```
Get-StorageSubSystem          # Entry point: S2D subsystem health
  Get-StoragePool             # Pool health, capacity, read-only state
    Get-PhysicalDisk          # Drive health, operational state, poolability
    Get-VirtualDisk           # Virtual disk health, resiliency, detach reason
Get-StorageJob                # Active repair/rebuild jobs
Get-HealthFault               # Automated Health Service alerts
Get-ClusterPerf               # Performance history (WS2019+)
Get-SDDCDiagnosticInfo        # Full diagnostic bundle collection
```

### Key Repair Commands

| Situation | Command |
|-----------|---------|
| Drive with old/stale metadata | `Reset-PhysicalDisk` then `Repair-VirtualDisk` |
| Virtual disk degraded/incomplete | `Repair-VirtualDisk` |
| Virtual disk detached (policy) | `Connect-VirtualDisk` |
| Virtual disk No Redundancy | Set `DiskRecoveryAction = 1`, repair, reset to 0 |
| Virtual disk DRT log full | Set `DiskRunChkDsk 7`, run Data Integrity Scan, reset to 0 |
| Pool read-only (quorum restored) | `Set-StoragePool -IsReadOnly $false` |
| Optimize uneven data distribution | `Optimize-StoragePool` |

### Critical Event IDs to Monitor

| Event ID | Log | Meaning |
|----------|-----|---------|
| 311 | StorageSpaces-Driver | DRT log full — integrity scan required |
| 5120 | FailoverClustering | CSV I/O timeout — investigate network/storage |
| 1135 | FailoverClustering | Node removed from cluster membership |
| 5, 134 | ReFS | Volume mount failure or write failure |

---

## Azure Local vs. Windows Server S2D

The key distinction is deployment context:

- **Windows Server S2D**: Part of Windows Server Datacenter edition. Supports both hyperconverged and converged (Scale-Out File Server) topologies. Manual deployment. On-premises only.
- **Azure Local**: Purpose-built HCI OS using S2D as its storage layer. Hyperconverged only. Cloud-connected (Azure Arc mandatory in 23H2). Managed via Azure portal and Azure Lifecycle Manager. Access to Azure cloud services (Azure Monitor, AKS, Arc VMs, Azure Backup).

For new HCI deployments, Azure Local (23H2+) is the recommended platform. For organizations requiring converged topology or no cloud connectivity, Windows Server 2022/2025 S2D remains the choice.

---

## Source Documents

This research is compiled in four detailed documents in this workspace:

| File | Contents |
|------|---------|
| `architecture.md` | Full S2D stack, SBL cache, storage pool, virtual disks, fault domains, SMB Direct, ReFS, CSV, Hyper-V integration, Azure Local architecture |
| `features.md` | Version-by-version feature breakdown: WS2016, WS2019, WS2022, WS2025, Azure Stack HCI 22H2/23H2; nested resiliency detail with PowerShell examples; performance history |
| `best-practices.md` | Hardware selection guide, network design, cache configuration, volume sizing, fault domain planning, Windows Admin Center monitoring, performance tuning, maintenance procedures |
| `diagnostics.md` | Full diagnostic command reference: Get-StorageSubSystem, Get-PhysicalDisk, Get-VirtualDisk, Get-StoragePool; health state tables; event logs; repair workflows; performance counters |

---

## Primary References

- [Storage Spaces Direct overview](https://learn.microsoft.com/en-us/windows-server/storage/storage-spaces/storage-spaces-direct-overview) — Microsoft Learn
- [S2D Hardware Requirements](https://learn.microsoft.com/en-us/windows-server/storage/storage-spaces/storage-spaces-direct-hardware-requirements) — Microsoft Learn
- [Nested Resiliency](https://learn.microsoft.com/en-us/windows-server/storage/storage-spaces/nested-resiliency) — Microsoft Learn
- [Performance History](https://learn.microsoft.com/en-us/windows-server/storage/storage-spaces/performance-history) — Microsoft Learn
- [Fault Domain Awareness](https://learn.microsoft.com/en-us/windows-server/failover-clustering/fault-domains) — Microsoft Learn
- [S2D Troubleshooting](https://learn.microsoft.com/en-us/windows-server/storage/storage-spaces/troubleshooting-storage-spaces) — Microsoft Learn
- [Health and Operational States](https://learn.microsoft.com/en-us/windows-server/storage/storage-spaces/storage-spaces-states) — Microsoft Learn
- [Troubleshoot S2D Performance](https://learn.microsoft.com/en-us/troubleshoot/windows-server/backup-and-storage/troubleshoot-performance-issues-storage-spaces-direct) — Microsoft Learn
- [What's new in Azure Local 23H2](https://learn.microsoft.com/en-us/azure/azure-local/whats-new) — Microsoft Learn
- [PrivateCloud.DiagnosticInfo module](https://github.com/PowerShell/PrivateCloud.DiagnosticInfo) — GitHub/PowerShell
