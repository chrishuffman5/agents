# Dell Unity XT Architecture

## Hardware Models

| Model | Drive Slots | Target |
|---|---|---|
| 380 / 380F | Up to 500 | SMB / ROBO |
| 480 / 480F | Up to 500 | Midrange general purpose |
| 680 / 680F | Up to 1,000 | Performance-intensive |
| 880 / 880F | Up to 1,500 | Large enterprise |

F suffix = All-Flash Array (AFA). Intel Xeon Skylake processors. 480F+ models: two M.2 SSDs per SP (SATA boot + NVMe metadata).

## Dual Storage Processor (SP) Controllers

Active-active. Each SP: independent CPU, RAM, network adapters, connected via high-speed midplane. Front-end: iSCSI, FC, FCoE, 10/25 GbE NAS. Back-end: 12Gb SAS to DAEs.

**Ownership/Failover**: Each resource has an owning (home) SP and secondary (failover) SP. On failure, surviving SP takes over within seconds. Auto trespass-back on recovery. ALUA for block: owning SP paths optimized, secondary non-optimized but usable. System cache: NVRAM-backed write-back per SP.

## Storage Pools

### Dynamic Pools (Mapped RAID) — Recommended
RAID at extent level across all drives. No dedicated hot spares (distributed ~1 per 32 drives). Supports RAID 5, 6, 1/0. Max widths: RAID 5 12+1, RAID 6 14+2, RAID 1/0 4+4. Drives added one at a time; auto-rebalance.

### Traditional Pools
Fixed RAID sets (legacy VNX behavior). Dedicated hot spares required. Supported for compatibility only.

### Pool Characteristics
Single pool can contain multiple drive tiers. Thin provisioning default. Inline data reduction on AFA. Tracks subscribed vs consumed capacity.

## FAST VP (Fully Automated Storage Tiering)

Automated tiering within a pool based on I/O activity.

| Tier | Drive Type | Purpose |
|---|---|---|
| Extreme Performance | SAS Flash SSD | Hottest data |
| Performance | NL-SAS/SAS HDD | Warm data |
| Capacity | NL-SAS HDD | Cold/archive |

AFA pools: single tier, FAST VP tiering not applicable (data reduction and FAST Cache still operate).

How it works: Monitors I/O at 256 MB granularity, hourly analysis, moves data during configured window (default 22:00-06:00 UTC). Policies per storage object: Start High then Auto-tier (default), Auto-tier, Highest Available, Lowest Available.

## FAST Cache

Secondary SSD cache. 64 KB granularity. Not for AFA pools. Caches reads and write-behind data. Added in mirrored SSD pairs. Concurrent with FAST VP.

## Block Storage (SAN)

Protocols: FC (8/16/32 Gb), iSCSI (10/25 GbE), FCoE. Objects: LUNs (thin by default), Consistency Groups (write-order consistent), VMFS datastores, vVols. Copy-on-write snapshots, writable thin clones.

## File Storage (NAS)

NAS servers: logical file service entities. Up to 12 per system. Each has network interfaces, AD/LDAP/NIS, DNS. Protocols: SMB 1/2/3, NFSv3/v4.0/v4.1, FTP, SFTP. Multiprotocol supported. Auto-failover to peer SP. Fail-Safe Networking (FSN) for switch redundancy.

## UnityVSA

Community Edition: 4 TB free. Professional Edition: up to 50 TB licensed. Deployed as OVA on ESXi. Two virtual SPs for HA (PE). Same features as physical (except no FC, no FAST Cache, no hardware RAID). Replication supported between VSA and physical Unity.

## Unisphere Management

HTML5 GUI. RBAC: Administrator, Storage Administrator, Operator, VM Administrator. UEMCLI (SSH-based CLI). REST API. CloudIQ / APEX AIOps integration with ProSupport contract.

## Current Feature Set (OE 5.x)

Inline dedup + compression (AFA), async/sync replication, cloud tiering (Azure/AWS/ECS), VMware vVols, NDMP backup, REST API, Ansible integration. OE 5.5: TLS 1.2 enforcement. No new feature development — sustaining mode.
