# Cloud VMs Architecture Reference

## Instance Type Families

### AWS EC2

| Family | Purpose | Examples |
|--------|---------|---------|
| General Purpose | Balanced compute/memory/network | t3, t4g, m5, m6i, m7g |
| Compute Optimized | High CPU-to-memory ratio | c5, c6i, c7g, hpc7g |
| Memory Optimized | Large in-memory datasets | r5, r6i, x2idn, u-6tb1 |
| Storage Optimized | High sequential I/O, NVMe | i3, i4i, d3, h1 |
| Accelerated | GPU, FPGA, Inferentia | p4, g5, f1, inf2, trn1 |

### Azure VMs

| Family | Purpose | Examples |
|--------|---------|---------|
| B-series | Burstable, dev/test | B1s, B2ms, B4ms |
| D-series | General purpose | D2s_v5, D4s_v5, D16s_v5 |
| E-series | Memory optimized | E4s_v5, E8s_v5, E64s_v5 |
| F-series | Compute optimized | F4s_v2, F8s_v2, F32s_v2 |
| N-series | GPU workloads | NC6s_v3, NV6, ND96asr_A100_v4 |
| L-series | Storage optimized | L8s_v3, L16s_v3 |
| M-series | Memory extreme, SAP HANA | M128ms, M416ms_v2 |

### Google Compute Engine

| Family | Purpose | Examples |
|--------|---------|---------|
| e2 | Cost-optimized general purpose | e2-micro, e2-standard-4 |
| n2/n2d | Balanced (Intel/AMD) | n2-standard-4, n2d-highmem-8 |
| n4 | Latest Intel | n4-standard-4, n4-highcpu-16 |
| c3/c3d | Compute optimized | c3-standard-4, c3d-highcpu-16 |
| m3 | Memory optimized | m3-megamem-64, m3-ultramem-32 |
| a2/a3 | GPU (A100/H100) | a2-highgpu-1g, a3-highgpu-8g |
| g2 | GPU (L4) | g2-standard-4, g2-standard-48 |

---

## Storage

### AWS EBS Volume Types

| Type | Use Case | Max IOPS | Max Throughput |
|------|----------|----------|----------------|
| gp3 | General purpose SSD (default) | 16,000 | 1,000 MiB/s |
| gp2 | General purpose SSD (legacy) | 16,000 | 250 MiB/s |
| io2 | Provisioned IOPS, databases | 256,000 | 4,000 MiB/s |
| st1 | Throughput HDD, big data | 500 | 500 MiB/s |
| sc1 | Cold HDD, infrequent access | 250 | 250 MiB/s |

### Azure Managed Disk Types

| Type | Use Case | Max IOPS |
|------|----------|----------|
| Standard HDD | Dev/test, infrequent access | 2,000 |
| Standard SSD | Web servers, light apps | 6,000 |
| Premium SSD | Production workloads | 20,000 |
| Premium SSD v2 | Flexible IOPS/throughput | 80,000 |
| Ultra Disk | Mission-critical, sub-ms latency | 160,000 |

### GCP Persistent Disk Types

| Type | Use Case | Max IOPS |
|------|----------|----------|
| pd-standard | HDD, sequential workloads | varies by size |
| pd-balanced | Balanced SSD (default) | 80,000 |
| pd-ssd | Performance SSD | 100,000 |
| pd-extreme | Highest IOPS | 120,000 |
| Hyperdisk Extreme | Provisioned IOPS | 350,000 |

### Ephemeral Storage

- **AWS Instance Store** -- NVMe physically attached to host. Data lost on stop/terminate. Cannot be detached or reattached.
- **Azure Temp Disk** -- Local SSD on host. Data lost on deallocate/resize. Size varies by VM family.
- **GCP Local SSD** -- 375 GB NVMe each, up to 24 per instance. Data lost on stop/terminate.

All ephemeral storage is unsuitable for persistent data. Use for caches, scratch space, and temporary processing only.

---

## Networking

### Virtual Networks

| Feature | AWS | Azure | GCP |
|---------|-----|-------|-----|
| Network scope | VPC (regional) | VNet (regional) | VPC (global) |
| Subnet scope | Availability Zone | Regional | Regional |
| Default behavior | Default VPC per region | No default VNet | Default network (auto-mode) |
| Peering | VPC Peering (non-transitive) | VNet Peering | VPC Peering |
| Private connectivity | PrivateLink, VPN, Direct Connect | Private Endpoint, VPN, ExpressRoute | Private Service Connect, VPN, Interconnect |

### Firewall Models

| Feature | AWS Security Groups | Azure NSGs | GCP Firewall Rules |
|---------|-------------------|-----------|-------------------|
| Attachment | Per-ENI (up to 5 per instance) | Per-NIC or per-subnet | Per-network, targeted via tags |
| Statefulness | Stateful | Stateful | Stateful |
| Default inbound | Deny all | Deny all | Deny all (except default-allow rules) |
| Default outbound | Allow all | Allow all | Allow all |
| Rule format | Protocol/port/source | Priority/protocol/port/source/action | Priority/protocol/port/source/target-tags |

### Static IPs

- **AWS**: Elastic IP -- allocated to account, associated with ENI. Charges when unassociated.
- **Azure**: Public IP (Standard SKU) -- static allocation, zone-redundant. Must be explicitly associated.
- **GCP**: Static external address -- reserved per region. Charges when unattached.

---

## High Availability

### AWS

- **Availability Zones** -- Physically separate datacenters within a region.
- **Placement Groups** -- Cluster (low-latency), Spread (max 7 per AZ, separate hardware), Partition (isolated racks).
- **Auto Scaling Groups** -- Launch template-based, health checks via EC2 or ELB, scaling policies.

### Azure

- **Availability Sets** -- Fault domains + update domains within a datacenter.
- **Availability Zones** -- Physically separate datacenters within a region (99.99% SLA).
- **Proximity Placement Groups** -- Co-locate VMs for low latency.
- **VM Scale Sets (VMSS)** -- Auto-scaling group with flexible or uniform orchestration.

### GCP

- **Zones** -- Independent failure domains within a region.
- **Managed Instance Groups (MIG)** -- Auto-scaling, auto-healing, rolling updates via instance templates.
- **Sole-Tenant Nodes** -- Dedicated physical hosts for compliance and licensing.

---

## Instance Lifecycle States

### AWS

```
pending -> running -> stopping -> stopped -> (start again)
                   -> shutting-down -> terminated
```

`stop` always deallocates compute. EBS volumes persist. `terminate` is permanent.

### Azure

```
Creating -> Running -> Stopping -> Stopped -> Deallocating -> Deallocated -> (start again)
                    -> Deleting -> Deleted
```

`Stopped` (OS halted) still bills compute. `Deallocated` releases compute resources.

### GCP

```
PROVISIONING -> STAGING -> RUNNING -> STOPPING -> TERMINATED -> (start again)
                                                -> SUSPENDING -> SUSPENDED
```

`stop` always deallocates compute. `delete` is permanent. `suspend` preserves memory state.

---

## Identity and Access

| Feature | AWS | Azure | GCP |
|---------|-----|-------|-----|
| Instance identity | IAM Instance Profile (role) | Managed Identity (MSI) | Service Account |
| Metadata endpoint | `169.254.169.254` (IMDSv2) | `169.254.169.254` (header required) | `metadata.google.internal` (header required) |
| SSH key management | Key pairs (RSA/ED25519) | SSH keys at creation or extension | OS Login (IAM) or project metadata |
| Agentless access | SSM Session Manager | Serial Console, Run Command | IAP tunnel, Serial Console |

---

## Purchasing Models

| Model | AWS | Azure | GCP |
|-------|-----|-------|-----|
| On-demand | Per-second billing | Per-second billing | Per-second billing |
| Commitment | Reserved Instances, Savings Plans | Reserved VM Instances | Committed Use Discounts (CUDs) |
| Preemptible | Spot Instances (~70% discount) | Spot VMs (~80% discount) | Spot VMs (~60-80% discount) |
| Sustained use | None (use RI/SP) | None (use RI) | Sustained Use Discounts (auto) |
