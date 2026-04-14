# VMware NSX Architecture Reference

## NSX Manager Cluster Internals

### Cluster Roles

Each NSX Manager node runs all three roles simultaneously:
- **Management Plane (MP)**: REST API, GUI, policy processing, configuration storage
- **Control Plane (CP)**: Computes realized state from desired state, pushes to transport nodes
- **Central Control Plane (CCP)**: Distributes logical routing and switching tables to hosts

### Cluster Sizing

| Deployment | Appliance Size | vCPU | RAM | Disk | Max Hosts |
|---|---|---|---|---|---|
| Lab | Small | 4 | 16 GB | 300 GB | 10 |
| Small production | Medium | 6 | 24 GB | 300 GB | 64 |
| Large production | Large | 12 | 48 GB | 300 GB | 256+ |

### VIP and Load Balancing

- Single VIP configured for API/GUI access across the cluster
- VIP owned by the current leader node (Raft leader election)
- If leader fails, VIP migrates to new leader within seconds
- API clients should use the VIP, not individual node IPs

### Certificate Management

- NSX Manager uses self-signed certificates by default
- Replace with CA-signed certificates for production (recommended)
- NSX 4.2.1+: Auto-renewal of internal platform certificates
- Certificate replacement via API: `PUT /api/v1/node/services/http?action=apply_certificate`

## Transport Node Lifecycle

### Host Transport Node Preparation

1. NSX VIB installation on ESXi host (via vCenter cluster-level preparation or manual)
2. Transport Zone association (overlay and/or VLAN)
3. TEP IP assignment (IP pool or DHCP)
4. N-VDS or VDS migration (VDS is current standard for NSX 4.x)
5. Transport node state transitions: `NOT_PREPARED -> IN_PROGRESS -> SUCCESS`

### TEP (Tunnel Endpoint)

- Each host transport node has one or more TEP IPs
- TEP used for Geneve encapsulation between hosts
- TEP IP must be routable between all hosts in the same transport zone
- Best practice: dedicated VLAN and subnet for TEP traffic
- MTU on TEP VLAN: 9000+ (Geneve adds ~54 bytes overhead)

### TEP Communication

```
Host-A (TEP: 192.168.100.1) <-- Geneve tunnel --> Host-B (TEP: 192.168.100.2)
  VM-1 (10.1.1.10)                                    VM-2 (10.1.2.20)
  Segment: web-segment (VNI: 72001)                    Segment: app-segment (VNI: 72002)
```

Traffic between VM-1 and VM-2 (different segments):
1. VM-1 sends packet to default gateway (T1 DR on Host-A)
2. T1 DR routes packet, determines destination is on Host-B
3. Host-A encapsulates in Geneve with VNI 72002, sends to Host-B TEP
4. Host-B decapsulates, delivers to VM-2

### Edge Transport Node Architecture

Edge nodes provide centralized services that cannot run distributed:

**Edge VM sizes:**
| Size | vCPU | RAM | Use Case |
|---|---|---|---|
| Small | 2 | 4 GB | Lab only |
| Medium | 4 | 8 GB | Small production |
| Large | 8 | 32 GB | Standard production |
| Extra Large | 16 | 64 GB | High throughput |

**Bare-metal Edge:**
- Physical server running NSX Edge software directly
- No hypervisor overhead -- wire-speed performance
- Required for environments needing >40 Gbps north-south throughput
- Supports SR-IOV for datapath acceleration

### Edge Cluster

- Group of 2-8 Edge nodes for HA and load distribution
- T0 and T1 Service Routers placed on Edge cluster members
- T0 Active-Active: ECMP across all Edge nodes in the cluster
- T0 Active-Standby: Primary on one Edge, standby on another with BFD failover

## DFW Pipeline

### Packet Processing Order

When a VM sends a packet, the DFW processes it in this order:

1. **vNIC egress**: Packet leaves VM vNIC
2. **Spoofguard check**: Validate source MAC/IP against allowed bindings
3. **DFW rule evaluation**: Top-down, first-match through security policies
4. **Service Insertion**: If a rule redirects to a partner service (IDS/IPS appliance)
5. **Distributed Router**: If the packet needs routing (T1 DR in kernel)
6. **Geneve encapsulation**: If destination is on a remote host

### DFW Rule Evaluation

- Rules evaluated in security policy priority order (lower number = higher priority)
- Within a policy, rules evaluated top-down
- First match determines action (Allow, Drop, Reject)
- If no rule matches, default rule is applied
- Drop: silently discard packet
- Reject: send TCP RST or ICMP unreachable

### DFW Connection Tracking

DFW is stateful:
- First packet creates a connection tracking entry
- Subsequent packets in the same flow are fast-pathed (no rule re-evaluation)
- Connection table size per host: ~2 million entries (varies by host memory)
- Idle timeout: configurable per service (default TCP: 3600s, UDP: 120s)

### DFW Performance

- DFW throughput scales linearly with host count (each host processes its own traffic)
- Per-host throughput: ~100 Gbps for DFW-only (no IDS/IPS)
- With Turbo mode (SCRX) in NSX 4.x: deterministic resource allocation for higher sustained throughput
- IDS/IPS reduces throughput by ~40-50% depending on signature count

## T0/T1 Data Path Details

### Distributed Router (DR)

Every host transport node runs a copy of each T1 DR:
- Kernel-level routing: no packet leaves the host for east-west inter-segment traffic
- Routing table synchronized from NSX Manager via CCP
- ARP proxy: DR answers ARP requests on behalf of remote VMs (reduces BUM traffic)
- Anycast gateway: same gateway IP and MAC on every host for seamless vMotion

### Service Router (SR)

SR runs on Edge nodes for services that require centralization:
- NAT (source NAT, destination NAT)
- VPN (IPsec, L2VPN)
- Gateway Firewall
- DHCP server
- Load balancing (legacy; replaced by NSX ALB)
- DNS forwarding

### T0-to-Physical Peering

T0 SR on Edge node peers with physical routers:

```
Physical Router <-- BGP --> T0 SR (Edge-1)
                <-- BGP --> T0 SR (Edge-2)
                ECMP routing between Edge nodes
```

**BGP configuration on T0:**
- Local AS number assigned to T0
- Neighbor IP = physical router interface
- Route redistribution: T1 connected subnets, static routes, NAT IPs
- BFD for sub-second failover detection

## Geneve Encapsulation

### Frame Format

```
[Outer Ethernet] [Outer IP] [Outer UDP dst:6081] [Geneve Header] [Inner Ethernet Frame]
                                                   VNI (24-bit)
                                                   Options (variable length)
```

### Geneve vs VXLAN

| Aspect | VXLAN | Geneve |
|---|---|---|
| UDP port | 4789 | 6081 |
| Header | Fixed 8 bytes | Variable (options TLV) |
| Metadata | VNI only | VNI + extensible options |
| Used by | Cisco ACI, open EVPN | VMware NSX (3.0+) |

Geneve options carry NSX-specific metadata (security tags, flow IDs, context) that enable DFW to make policy decisions based on overlay context.

## Federation Architecture

### Global Manager Internals

- Separate NSX Manager appliance cluster (3 nodes)
- Manages "stretched" objects: segments, groups, gateway firewall policies
- Does NOT manage local-only objects (those stay on Local Managers)
- Pushes policy to Local Managers via REST API replication
- Active-Standby HA between Global Manager sites

### Location-Based Policy

Federation supports location-aware policy:
- A group can contain VMs from specific sites only
- DFW rules can apply to all sites or specific sites
- Enables site-specific security exceptions within a global policy framework

### Stretched Segment Implementation

- Same VNI used across all sites for a stretched segment
- BUM traffic replicated between sites via Edge nodes (RTEP -- Remote TEP)
- Latency-sensitive: stretched segments should be used only when workload mobility is required
- ARP suppression reduces cross-site BUM traffic

## NSX Intelligence

### Flow Visualization

- Collects NetFlow-like data from all host transport nodes
- Displays VM-to-VM traffic flows with L4 port/protocol annotation
- Identifies unprotected flows (traffic not covered by DFW rules)
- Provides security posture heat maps

### Security Recommendations

- Analyzes observed traffic patterns over time
- Suggests DFW rules to implement least-privilege micro-segmentation
- Recommendations include source/destination groups, services, and rule actions
- Review and approve recommendations before applying -- do not auto-apply

### Deployment

NSX Intelligence runs on NSX Application Platform (NAPP):
- Kubernetes-based platform on a dedicated cluster
- Minimum: 4 worker nodes with 16 vCPU / 64 GB RAM each
- Licensed separately (NSX Enterprise Plus or above)
