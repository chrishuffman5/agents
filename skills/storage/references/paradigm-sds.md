# Software-Defined Storage Patterns

## When to Choose Software-Defined Storage

Software-defined storage (Ceph, MinIO, GlusterFS) decouples the storage control plane from hardware, running on commodity servers. Choose SDS when:

- **Cost optimization** is paramount — use commodity hardware instead of proprietary arrays
- **Scale-out architecture** is needed — grow from TBs to PBs by adding nodes
- **Multi-protocol** unified storage on a single platform (Ceph: block + file + object)
- **Open-source preference** to avoid vendor lock-in
- **Cloud-native / Kubernetes** environments need native CSI integration
- **S3-compatible object storage** is needed on-premises (MinIO)

## When to Avoid SDS

- **Team lacks Linux/distributed systems expertise** — SDS is operationally demanding
- **Sub-millisecond latency required** — Enterprise all-flash arrays outperform SDS at the low end
- **Small scale (< 50 TB)** — Operational overhead exceeds hardware cost savings
- **Vendor support SLA required** — Open-source support varies; commercial support adds cost

## Technology Comparison

| Feature | Ceph | MinIO | GlusterFS |
|---|---|---|---|
| **Storage Types** | Block (RBD), File (CephFS), Object (RGW) | Object only (S3-compatible) | File only (FUSE, NFS, SMB) |
| **Architecture** | CRUSH-based, distributed, no single point of failure | Erasure-coded, server pools | Brick-based, trusted storage pool |
| **Scaling** | Add OSDs (hundreds of nodes) | Add server pools | Add bricks/nodes |
| **Data Protection** | Replication (2x/3x) or erasure coding | Erasure coding (configurable k+m) | Replication (2x/3x), geo-replication |
| **Kubernetes** | Rook-Ceph operator (mature) | MinIO Operator (Helm) | CSI driver available |
| **Performance** | Good (latency ~1-5ms block, tunable) | Excellent for object (designed for throughput) | Moderate (FUSE overhead for native mount) |
| **Operational Complexity** | High (CRUSH maps, PG tuning, balancing) | Low-moderate (simpler architecture) | Moderate (heal, split-brain) |
| **Licensing** | LGPL 2.1 / 3.0 | AGPL 3.0 (since Feb 2026, was Apache 2.0) | GPL 3.0 |
| **Commercial Support** | Red Hat Ceph Storage, IBM, SUSE | MinIO commercial subscription | Red Hat Gluster (winding down) |

## Architecture Patterns

### Ceph Cluster Architecture

```
┌─────────────────────────────────────────────────┐
│                 Ceph Clients                     │
│  RBD (block)  │  CephFS (file)  │  RGW (S3/Swift)│
└──────┬────────┴────────┬────────┴───────┬───────┘
       │                 │                │
┌──────▼─────────────────▼────────────────▼───────┐
│              RADOS (Reliable Autonomous          │
│              Distributed Object Store)           │
│  ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐      │
│  │ OSD │ │ OSD │ │ OSD │ │ OSD │ │ OSD │ ...   │
│  └─────┘ └─────┘ └─────┘ └─────┘ └─────┘      │
│                                                  │
│  ┌─────┐ ┌─────┐ ┌─────┐                       │
│  │ MON │ │ MON │ │ MON │  (odd number, 3+ for   │
│  └─────┘ └─────┘ └─────┘   quorum)              │
│                                                  │
│  ┌─────┐ ┌─────┐                               │
│  │ MGR │ │ MGR │  (active/standby, dashboard)   │
│  └─────┘ └─────┘                                │
└─────────────────────────────────────────────────┘
```

### MinIO Deployment Pattern

```
MinIO Server Pool (erasure-coded)
┌────────────────────────────────────────────┐
│  Node 1      Node 2      Node 3     Node 4│
│  ┌──────┐   ┌──────┐   ┌──────┐   ┌──────┐│
│  │Drive1│   │Drive1│   │Drive1│   │Drive1││
│  │Drive2│   │Drive2│   │Drive2│   │Drive2││
│  │Drive3│   │Drive3│   │Drive3│   │Drive3││
│  │Drive4│   │Drive4│   │Drive4│   │Drive4││
│  └──────┘   └──────┘   └──────┘   └──────┘│
│         EC: 8 data + 4 parity              │
└────────────────────────────────────────────┘
```

## Key Decision Criteria

| Criterion | Choose Ceph | Choose MinIO | Choose GlusterFS |
|---|---|---|---|
| **Need block storage** | Yes (RBD) | No | No |
| **Need S3 compatibility** | Yes (RGW, slower) | Yes (native, fast) | No |
| **Need shared filesystem** | Yes (CephFS) | No | Yes (native) |
| **Kubernetes primary** | Rook-Ceph | MinIO Operator | Less common |
| **Team expertise** | Linux + distributed systems | S3/object storage | Linux + NFS/SMB |
| **Scale** | PB-scale, hundreds of nodes | PB-scale, simpler | TB-scale, tens of nodes |

## Anti-Patterns

1. **"Ceph on 3 nodes for production"** — Minimum viable Ceph is 3 MON + 3 OSD nodes. But production needs 5+ OSD nodes for proper failure domain separation and rebuild performance.
2. **"MinIO for block storage"** — MinIO is object-only. If you need block volumes, use Ceph or an enterprise array.
3. **"SDS without dedicated storage network"** — SDS replication traffic will saturate your production network. Always use a dedicated storage/replication network.
4. **"Ignoring the license change"** — MinIO switched from Apache 2.0 to AGPL 3.0 (Feb 2026). Evaluate compliance implications before deploying.
