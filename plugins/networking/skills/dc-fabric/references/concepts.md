# DC Fabric Concepts Reference

## Spine-Leaf (CLOS) Topology

### Architecture

The spine-leaf topology is a two-tier CLOS fabric where every leaf switch connects to every spine switch. No direct leaf-to-leaf or spine-to-spine links exist.

```
        [Spine-1]  [Spine-2]  [Spine-3]  [Spine-4]
           |  \  /  |  \  /  |  \  /  |
           |   \/   |   \/   |   \/   |
           |   /\   |   /\   |   /\   |
           |  /  \  |  /  \  |  /  \  |
        [Leaf-1] [Leaf-2] [Leaf-3] [Leaf-4] [Leaf-5]
          |  |     |  |     |  |     |  |     |  |
        Servers  Servers  Servers  Servers  Servers
```

**Properties:**
- Predictable latency: any server-to-server path traverses exactly one spine hop (leaf -> spine -> leaf)
- ECMP: traffic is load-balanced across all available spine paths
- Horizontal scaling: add leaf switches for more ports, add spine switches for more bandwidth
- No STP: all links are routed (L3) in the underlay -- no spanning tree loops

### Sizing Formula

- Maximum leaf switches in a 2-tier fabric = spine port count (radix)
- A spine with 64 ports supports up to 64 leaf switches
- If more leaves are needed, add a super-spine tier (3-tier CLOS)

### Three-Tier CLOS (Super-Spine)

When leaf count exceeds single-spine radix:
- Group leaves into pods (each pod has its own spine layer)
- Super-spines interconnect pods
- Each pod spine connects to every super-spine
- Scales to thousands of leaf switches

## Overlay vs Underlay

### Underlay Network

The physical network infrastructure that provides IP connectivity between VTEPs (Virtual Tunnel Endpoints):
- Layer 3 routed fabric using eBGP, OSPF, or IS-IS
- Responsible for: IP reachability between leaf loopbacks, ECMP load balancing, fast convergence
- Does not carry tenant traffic directly -- only encapsulated overlay traffic
- MTU must accommodate overlay encapsulation overhead (minimum 9214 bytes)

**Underlay protocol selection:**

| Protocol | Advantages | Disadvantages |
|---|---|---|
| eBGP | Policy control, AS-path loop prevention, scales well, no full-mesh adjacency needed | More configuration (unique ASN per leaf or per tier) |
| OSPF | Simpler configuration, single area for small fabrics | LSDB scaling issues, flooding storms at large scale |
| IS-IS | Fast convergence, efficient flooding, ACI default | Less familiar to many operators |

**ACI underlay**: IS-IS auto-provisioned by APIC. Operators do not configure the underlay manually.
**NSX underlay**: Not managed by NSX. Physical switches must be configured independently with proper MTU, routing, and ECMP.

### Overlay Network

Virtual networks tunneled over the underlay using VXLAN or Geneve encapsulation:
- Decouples logical network topology from physical switch topology
- Enables workload mobility without changing physical network
- Supports multi-tenancy with isolated virtual networks (VNIs)
- Carries L2 and L3 tenant traffic inside tunneled frames

### VXLAN Encapsulation

```
[Outer Ethernet (14B)] [Outer IP (20B)] [Outer UDP (8B)] [VXLAN Header (8B)] [Inner Ethernet Frame]
                                          dst port 4789     VNI (24-bit)
```

- 50 bytes overhead per frame
- 24-bit VNI: supports 16 million virtual networks (vs 4094 VLANs)
- UDP source port: hash of inner frame headers (enables ECMP in underlay)
- VTEP: the leaf switch (or hypervisor) that performs encapsulation/decapsulation

### Geneve Encapsulation (NSX)

NSX 3.0+ replaced VXLAN with Geneve (Generic Network Virtualization Encapsulation):
- Variable-length options field for carrying metadata (security tags, flow IDs)
- Same basic structure as VXLAN but extensible
- Used exclusively by NSX; not interoperable with VXLAN VTEPs without gateway translation

## EVPN Control Plane

BGP EVPN (RFC 7432) provides a signaled control plane for overlay networks, replacing flood-and-learn:

### Route Types

| Type | Name | Purpose |
|---|---|---|
| Type-1 | Ethernet Auto-Discovery | Multi-homing convergence, aliasing, mass withdrawal |
| Type-2 | MAC/IP Advertisement | Distributes MAC and MAC+IP bindings; enables ARP suppression |
| Type-3 | Inclusive Multicast | VTEP discovery; BUM traffic replication list |
| Type-4 | Ethernet Segment | Designated Forwarder election for multi-homed hosts |
| Type-5 | IP Prefix Route | L3 prefix advertisement for inter-subnet routing |

### ARP Suppression

EVPN Type-2 routes carry both MAC and IP bindings. When a host sends an ARP request, the local VTEP can answer from its EVPN database without flooding the ARP request across the fabric. This dramatically reduces BUM traffic.

### Symmetric IRB (Integrated Routing and Bridging)

The recommended forwarding model for VXLAN EVPN fabrics:
- Both ingress and egress VTEPs perform L3 routing
- Per-VRF L3 VNI carries inter-subnet traffic between VTEPs
- Anycast gateway: identical IP and MAC address configured on every leaf for seamless workload mobility
- No need for centralized routing at spine or border -- every leaf routes locally

## ACI Policy Model vs NSX Policy Model vs Open EVPN

### Cisco ACI

**Policy hierarchy**: Tenant > VRF > Bridge Domain > EPG > Contract

- **Tenant**: Top-level administrative isolation container
- **VRF**: L3 routing domain within a tenant
- **Bridge Domain (BD)**: L2 forwarding domain replacing VLANs; subnets defined on BD
- **EPG (Endpoint Group)**: Logical grouping of endpoints sharing security policy; communication between EPGs denied by default
- **Contract**: Defines permitted L3/L4 communication between provider and consumer EPGs
- **L3Out**: External routed network connection (BGP, OSPF, static to upstream)

**Key characteristic**: Whitelist model -- all inter-EPG traffic is denied unless explicitly permitted by a contract. This enforces zero-trust segmentation by default.

### VMware NSX

**Policy hierarchy**: T0 Gateway > T1 Gateway > Segment > DFW Groups/Rules

- **T0 Gateway**: North-south router connecting overlay to physical network (BGP/static)
- **T1 Gateway**: East-west router for inter-segment traffic within a tenant; connects to T0
- **Segment**: Logical switch (replaces VLAN) with Geneve VNI
- **DFW (Distributed Firewall)**: Kernel-level micro-segmentation on every hypervisor host
- **Groups**: Dynamic membership based on VM tags, names, OS, security tags
- **Context Profiles**: L7 application identification (App-ID, FQDN filtering)

**Key characteristic**: DFW runs in the hypervisor kernel at the vNIC level. Traffic is inspected before it enters the virtual switch -- no hairpinning to a central firewall needed. Scales horizontally with host count.

### Open EVPN (NX-OS / EOS)

**Configuration model**: VRF > VNI > Interface > ACL

- No centralized controller or policy abstraction layer
- Each leaf switch configured independently (or via automation: Ansible, Terraform, AVD)
- Segmentation via VRFs and ACLs applied at the leaf level
- No built-in micro-segmentation equivalent to ACI contracts or NSX DFW
- Maximum flexibility and no vendor lock-in, but higher operational burden

**Key characteristic**: Standards-based and multi-vendor. Best for organizations that prioritize operational transparency, already have strong automation practices, and do not need controller-driven policy abstraction.

## Multi-Site Fabric Patterns

### ACI Multi-Pod

- Single APIC cluster manages multiple pods (geographically separated spine-leaf groups)
- Pods connected via Inter-Pod Network (IPN) running OSPF + PIM/BGP
- Single administrative domain -- same tenant/EPG/contract model across all pods
- Use case: campus-scale DC or adjacent buildings on same campus

### ACI Multi-Site (NDO)

- Separate APIC clusters per site, centrally orchestrated by Nexus Dashboard Orchestrator (NDO)
- Inter-site connectivity via VXLAN over BGP EVPN on Inter-Site Network (ISN)
- Stretched schemas and templates push EPGs, BDs, VRFs, and contracts to multiple sites
- Independent failure domains -- one site's APIC outage does not affect others
- Use case: geographically distributed data centers

### NSX Federation

- Global Manager provides centralized policy across multiple sites
- Local Managers (per-site NSX Manager clusters) execute policy locally
- Stretched segments, groups, and gateway firewall policies across sites
- T0 VRF configuration at Global Manager level (NSX 4.2.1+)
- Use case: multi-DC NSX deployments requiring consistent security policy

### Open EVPN Multi-Site

- Border Gateways (BGW) connect separate EVPN fabrics
- EVPN Type-5 route re-origination at site boundaries
- Each site runs independent Route Reflectors; BGWs peer between sites
- No centralized controller -- automation must manage cross-site consistency
- Use case: multi-vendor DCI with maximum architectural independence
