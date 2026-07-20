# Storage Spaces Direct Architecture

## Overview

S2D clusters 2-16 servers with internal drives into a single software-defined pool. Supports hyperconverged (compute + storage same nodes) and converged (separate storage cluster via SoFS).

## Software Storage Bus

Software-defined fabric over Ethernet replacing physical SAN. Makes every server's drives visible cluster-wide. Uses SMB3 / SMB Direct (RDMA) for inter-node I/O. No specialized storage networking hardware required.

## SBL Cache

Server-side write-back cache using fastest drives. Writes go to cache first, destaged asynchronously. In hybrid configs: read caching also enabled. NVMe+SSD: read cache disabled (SSD reads already fast). Cache drives: 32 GB+, 3+ DWPD endurance, power-loss protection required.

Cache states (cluster log): `CacheDiskStateInitializedAndBound` (active), `CacheDiskStateNonHybrid` (all same type, disabled), `CacheDiskStateIneligibleDataPartition` (ineligible).

## Storage Pool

Single unified pool per cluster. All eligible drives auto-discovered. Max: 4 PB (WS2019+), 400 TB per server. Metadata distributed across all drives.

## Storage Tiers

When mixed media: Performance tier (fastest, hot data, mirror portions) and Capacity tier (slower, cold data, parity portions). ReFS real-time tiering moves data automatically.

## Virtual Disks and Resiliency

**Two-way mirror**: 2 copies, 1 failure tolerance, ~50% efficiency, 2+ nodes.
**Three-way mirror**: 3 copies, 2 failures, ~33% efficiency, 3+ nodes.
**Mirror-accelerated parity (MAP)**: mirror absorbs writes, parity stores cold. LRC erasure coding. Up to 2.4x more efficient than mirroring. 4+ nodes.
**Nested resiliency** (WS2019+, exactly 2 nodes): Nested two-way mirror (4 copies, 25% eff) or nested MAP (35-40% eff). Cannot convert existing volumes between types.

Interleave default: 256 KB. Use 64 KB for SQL Server.

## ReFS (Resilient File System)

Mandatory for S2D. Integrity streams (checksums on data + metadata). Accelerated VHDX operations (block cloning). Real-time tiering between hot/cold. No defrag needed. Up to 35 PB volumes. WS2025+: inline deduplication and compression.

## CSV (Cluster Shared Volumes)

Unified namespace: `C:\ClusterStorage\` on every node. Simultaneous access from all nodes. Live migration without storage I/O interruption. Redirected I/O fallback. Performance history stored in `ClusterPerformanceHistory` volume (ReFS, not CSV).

## Fault Domains

Hierarchy: Site > Rack > Chassis > Node. Must be defined BEFORE enabling S2D. Rack-fault-tolerant parity: min 4 racks, equal node counts. WS2025: rack-local reads (prefer closest healthy copy).

```powershell
New-ClusterFaultDomain -Type Rack -Name "Rack-A"
Set-ClusterFaultDomain -Name "Server01" -Parent "Rack-A"
```

## SMB Direct and RDMA

S2D uses SMB3 for inter-node storage traffic. SMB Direct leverages RDMA for kernel bypass, consistent low latency, ~15% throughput improvement.

**iWARP**: over standard TCP/IP, no special switch config, recommended for most.
**RoCE**: requires PFC on switches, higher performance, more complex.

SMB Multichannel: aggregates connections for bandwidth + NIC fault tolerance.
WS2022+: SMB Direct encryption (AES-128/256) for east-west traffic.

## Hyper-V Integration

Hyperconverged: VMs on CSV volumes. Live migration without data movement. ReFS block cloning for checkpoints. Storage QoS (min/max IOPS per VM). Hypervisor-embedded access to local storage = no network for local reads.

## Azure Local (Azure Stack HCI)

Purpose-built HCI OS using S2D. Hyperconverged only. 23H2: Azure Arc mandatory, Azure-based deployment, Lifecycle Manager for stack updates, Arc VM management. Cloud monitoring via Azure Monitor. Thin provisioning from 22H2.
