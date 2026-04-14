# Nutanix AHV Architecture Reference

## Node Architecture

Each Nutanix node runs three software layers: the AHV hypervisor (KVM/QEMU + OVS), the Controller VM (CVM) for storage services, and user VMs. This hyperconverged model eliminates separate SAN/NAS infrastructure.

### AHV Hypervisor Layer

AHV is KVM/QEMU plus a Nutanix management layer. Unlike raw KVM, AHV bundles storage (DSF), networking (OVS), and orchestration (Prism/Acropolis) into a single integrated platform. The hypervisor is intentionally thin -- it runs the KVM kernel module, QEMU for device emulation, and OVS for networking. All storage intelligence lives in the CVM.

### Controller VM (CVM)

Each AHV host runs exactly one CVM. The CVM is a dedicated VM with reserved CPU and memory (typically 8-12 vCPUs, 32-48 GB RAM on production nodes) that user VMs cannot consume.

The CVM handles all storage I/O. User VMs issue iSCSI or NFS I/O to the local CVM's virtual IP. The CVM manages actual disk access via the Distributed Storage Fabric.

### CVM Service Stack

| Service | Role |
|---------|------|
| Stargate | Data I/O engine -- reads, writes, erasure coding, compression, deduplication |
| Cassandra | Metadata store -- distributed key-value ring for DSF block maps |
| Zookeeper | Cluster coordination -- leader election, configuration consistency |
| Curator | Background tasks -- garbage collection, rebalancing, EC scheduling, tiering |
| Acropolis | VM lifecycle management -- interfaces with KVM/QEMU on the AHV host |
| Genesis | Process manager -- starts/stops services, handles rolling upgrades |
| Prism | Web UI and REST API server (Prism Element on each cluster) |

All services run as processes within the CVM. Monitor with `genesis status`. Restart individual services with `genesis restart <service_name>`.

---

## Distributed Storage Fabric (DSF)

### Data Locality

AHV places VM data on the same node where the VM runs. Write path: data goes to local CVM storage first, then replicates to one or more remote CVMs (depending on RF). Read path: served locally without crossing the network.

Data locality is disrupted by VM migration. After migration, the VM reads from the previous host's storage over the network. Curator background processes re-converge data to the new host over time.

### Replication Factor

| RF | Copies | Node Failures Tolerated | Minimum Nodes |
|----|--------|------------------------|---------------|
| RF2 | 2 | 1 | 3 |
| RF3 | 3 | 2 | 5 (recommended) |

RF is set per storage container. RF3 doubles write I/O compared to RF2 and consumes 3x raw capacity. Use RF3 for production databases and critical workloads where a second failure during rebuild would be catastrophic.

### Storage Tiers

| Tier | Media | Role |
|------|-------|------|
| P0 | NVMe / SSD | Hot data -- random I/O, active working set |
| P1 | HDD | Cold data -- sequential access, bulk storage |
| P2 | S3-compatible | Archive -- Intelligent Tiering extension |

Curator promotes and demotes data between tiers based on access frequency. The hot tier should hold at least 20% of the active working set.

### Data Efficiency

| Feature | Behavior |
|---------|----------|
| Inline compression | LZ4 (fast, default) or ZSTD (high ratio) applied on first write |
| Post-process dedup | Fingerprints computed inline; dedup map applied post-process by Curator |
| Erasure Coding (EC-X) | Background re-encoding of cold data (e.g., 4+2 parity across 6 nodes) |
| Zero detection | All-zero blocks skipped entirely -- never written to disk |
| Snapshots | Redirect-on-write (ROW) -- instantaneous, no data copy overhead |
| Clones | Space-efficient linked clones via block map sharing |

EC-X reduces capacity overhead from 2x (RF2) to approximately 1.25-1.5x for cold data. It runs as a low-priority Curator background task and does not affect write performance.

### Storage Containers

Containers are logical storage pools within a cluster. Each container has independent settings for RF, compression, dedup, and erasure coding. VMs are assigned to containers.

```bash
ncli container create name=prod-data replication-factor=3 \
    compression-enabled=true finger-print-on-write=PREFER_DEDUPE
```

---

## Networking

### Open vSwitch (OVS)

AHV uses OVS as its virtual switch. The default bridge is `br0`. Physical NICs are bonded and uplinked into OVS bridges. VM NICs connect via tap interfaces.

Bond modes: `active-backup` (failover), `balance-slb` (MAC hash load balancing), `LACP` (802.3ad with upstream switch cooperation).

### Networks and IPAM

An AHV network maps a VLAN ID to an OVS port group. Networks optionally include Prism-managed IPAM with IP pools, gateway, and DNS settings. VMs connect NICs to named networks.

### Flow Microsegmentation (Prism Central)

Flow provides stateful L4 microsegmentation enforced at the hypervisor vNIC level via OVS flow rules. No separate appliance required.

- **Security policies** -- Allow/deny rules by port, protocol, source/destination category
- **Categories** -- Tag-based VM grouping (not subnet-based)
- **App-centric model** -- Policies written in terms of tiers (web, app, db)
- **Quarantine mode** -- Instant VM isolation for forensics or remediation
- Policies follow VMs across host migrations

### VPCs (Overlay Networking)

VPCs provide VXLAN-based multi-tenant isolation through Prism Central. Each VPC has its own private IP space. External connectivity uses floating IPs or VPN attachments through virtual routers.

---

## Data Protection

### Protection Domains (Prism Element)

A Protection Domain is a named consistency group of VMs and volume groups that are snapshotted and replicated together.

| Mode | RPO | Mechanism |
|------|-----|-----------|
| Async DR | 1 hour minimum | Scheduled snapshot replication to remote cluster |
| NearSync | 1 minute (20-sec internal) | Shadow clone-based change tracking |
| Metro Availability | 0 (synchronous) | Synchronous write commit at both sites |

### NearSync

Captures lightweight "pits" every 20 seconds, merged into recovery points at the configured interval. More bandwidth-efficient than Metro for WAN links with latency above 5 ms.

### Metro Availability

Synchronous replication across two clusters (under 5 ms RTT recommended). Both sites maintain RF2. A witness VM (or Prism Central) arbitrates split-brain. Failover can be automatic (witness-triggered) or manual.

### Leap (DR Orchestration, Prism Central)

Leap orchestrates failover and failback across sites:
- **Recovery Plans** -- Ordered VM boot sequences with network mapping between source and target
- **One-click failover/failback** -- Prism Central drives the full sequence
- **Test failover** -- Non-disruptive DR test in isolated network bubble
- **Runbook automation** -- Pre/post-failover scripts via Calm integration

---

## Prism Management Planes

### Prism Element (PE)

Embedded in CVMs. Exposed at the cluster virtual IP on port 9440. Manages single-cluster operations: VM lifecycle, storage containers, networking, protection domains, alerts.

API: v2 REST API (resource-based GET/POST/PUT/DELETE).

### Prism Central (PC)

Separate scale-out VM deployment for multi-cluster management. Adds:
- Flow microsegmentation
- Calm automation and self-service
- Karbon Kubernetes management
- Multi-cluster analytics and capacity planning
- Leap DR orchestration
- Categories and cross-cluster policies

API: v3 REST API (intent-based). GET the current spec, modify the `spec` block, PUT the full object back. The `metadata` block must be preserved exactly.

### Key Internal Ports

| Port | Service |
|------|---------|
| 9440 | Prism Element/Central HTTPS |
| 2010 | Acropolis (CVM to AHV host) |
| 3260 | iSCSI (VM to local CVM) |
| 2049 | NFS (VM to local CVM) |
| 8776 | Inter-CVM DSF replication |
| 2009 | Stargate HTTP stats (diagnostics) |
