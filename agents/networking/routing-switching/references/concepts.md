# Routing & Switching Fundamentals

## BGP (Border Gateway Protocol)

### Path Selection (Decision Process)

BGP selects the best path using these attributes in order (first match wins):

| Priority | Attribute | Preference | Notes |
|---|---|---|---|
| 1 | Weight (Cisco) | Highest wins | Local to router, not advertised. Default 0; locally originated = 32768 |
| 2 | Local Preference | Highest wins | Advertised within iBGP AS. Default 100 |
| 3 | Locally originated | Prefer local | Routes originated by this router (network/aggregate/redistribute) |
| 4 | AS Path length | Shortest wins | Count of AS numbers in path. Can be manipulated with AS-path prepending |
| 5 | Origin | IGP > EGP > Incomplete | i (IGP via network cmd) > e (EGP) > ? (redistribute) |
| 6 | MED (Multi-Exit Discriminator) | Lowest wins | Suggests preferred entry point to neighboring AS. Only compared within same neighbor AS by default |
| 7 | eBGP over iBGP | eBGP preferred | External routes preferred over internal |
| 8 | Lowest IGP metric to next-hop | Closest exit | Hot-potato routing -- exit AS as quickly as possible |
| 9 | Oldest eBGP path | Prefer established | Stability -- prefer the path that has been stable longest |
| 10 | Lowest Router ID | Tiebreaker | Deterministic final tiebreaker |
| 11 | Lowest neighbor IP | Final tiebreaker | If Router IDs tie |

### eBGP vs iBGP

| Aspect | eBGP | iBGP |
|---|---|---|
| Peers | Different AS numbers | Same AS number |
| TTL | 1 (unless multihop) | 255 (loopback peering) |
| Next-hop behavior | Changes to self | Preserved (must set `next-hop-self` or use RR) |
| AS-path loop prevention | Rejects routes with own AS in path | No AS-path filtering (uses other mechanisms) |
| Full mesh requirement | No | Yes, unless Route Reflectors or Confederations used |
| Admin distance | 20 | 200 |

### BGP Communities

Communities are 32-bit tags attached to routes for policy signaling:

| Community | Meaning |
|---|---|
| `no-export` | Do not advertise outside the AS |
| `no-advertise` | Do not advertise to any peer |
| `local-as` | Do not advertise outside the local confederation sub-AS |
| Extended communities | Used for EVPN Route Target (import/export), VPN, etc. |
| Large communities | 96-bit (ASN:value1:value2) for 4-byte ASN environments |

### Route Reflectors

Route Reflectors (RR) eliminate the iBGP full-mesh requirement:
- RR reflects routes from one iBGP client to another
- Cluster-ID prevents loops within a cluster
- Originator-ID prevents loops between clusters
- RR does NOT modify routes (no next-hop change, no AS-path modification)
- Deploy at least 2 RRs per cluster for redundancy
- In DC fabrics, spines commonly serve as RRs for EVPN overlay

## OSPF (Open Shortest Path First)

### Area Types

| Area Type | External Routes | Summary Routes | Use Case |
|---|---|---|---|
| Backbone (Area 0) | Allowed | Allowed | Core -- all areas must connect to Area 0 |
| Standard | Allowed | Allowed | Normal areas with full LSDB |
| Stub | Blocked (default route injected) | Allowed | Reduces LSDB by removing external routes |
| Totally Stubby | Blocked | Blocked (single default) | Minimal LSDB -- only intra-area + default |
| NSSA | Type-7 LSAs allowed | Allowed | Stub area that needs to redistribute external routes |
| Totally NSSA | Type-7 LSAs allowed | Blocked (single default) | Most restrictive NSSA variant |

### LSA Types

| LSA Type | Name | Originated By | Scope |
|---|---|---|---|
| 1 | Router LSA | Every router | Intra-area (within originating area) |
| 2 | Network LSA | DR on multi-access segment | Intra-area |
| 3 | Summary LSA | ABR | Inter-area (area to area) |
| 4 | ASBR Summary | ABR | Advertises ASBR reachability across areas |
| 5 | External LSA | ASBR | Domain-wide (external routes redistributed into OSPF) |
| 7 | NSSA External | ASBR in NSSA | NSSA area only (converted to Type-5 at ABR) |

### DR/BDR Election

On multi-access segments (Ethernet), OSPF elects a Designated Router (DR) and Backup DR (BDR):
- Highest priority wins (default 1; priority 0 = never DR)
- If priority ties, highest Router ID wins
- Election is non-preemptive -- DR does not change unless it fails
- All routers form adjacency only with DR/BDR (reduces adjacency count from N*(N-1)/2 to 2*(N-1))
- Point-to-point links do not elect DR/BDR -- configure `ip ospf network point-to-point` on fabric links

### OSPF Design Guidelines

- Keep Area 0 as the backbone; all traffic between areas transits Area 0
- Use stub/totally stubby areas for branch sites to minimize LSDB
- Summarize at ABR boundaries to reduce inter-area flooding
- Use point-to-point network type on all point-to-point links (avoids DR election delay)
- BFD for sub-second failure detection instead of tuning hello/dead timers

## STP (Spanning Tree Protocol)

### STP Variants

| Variant | Standard | Instances | Convergence | Use Case |
|---|---|---|---|---|
| STP (802.1D) | IEEE | 1 (all VLANs) | 30-50 seconds | Legacy -- avoid |
| RSTP (802.1w) | IEEE | 1 (all VLANs) | <6 seconds | Single-instance rapid convergence |
| PVST+ | Cisco | Per VLAN | 30-50 seconds | Legacy per-VLAN STP -- avoid |
| Rapid PVST+ | Cisco | Per VLAN | <6 seconds | Recommended for campus with per-VLAN root placement |
| MST (802.1s) | IEEE | Configurable (groups of VLANs) | <6 seconds | Large VLAN counts; maps VLANs to instances |

### Key STP Features

**PortFast**: Skip listening/learning states on access ports. Apply only to end-host ports.
**BPDU Guard**: Err-disable port if BPDU received. Pair with PortFast on access ports.
**Root Guard**: Prevent a port from becoming root port. Apply on distribution-to-core uplinks.
**Loop Guard**: Prevent unidirectional link failures from creating loops. Apply on non-edge ports.
**BPDU Filter**: Suppress BPDUs on a port. Use with extreme caution -- can create loops.

### STP Root Placement

- Place root bridge at distribution layer (not access)
- Set explicit priority (do not rely on default 32768)
- Primary root: priority 4096; Secondary root: priority 8192
- For Rapid PVST+, load-balance by making one distribution switch root for even VLANs, the other for odd VLANs

## VLAN Design

### VLAN Architecture Principles

- Keep broadcast domains bounded -- maximum ~500 hosts per VLAN for performance
- Use /24 subnets for standard VLANs; /22 for larger segments
- Separate VLANs by function: data, voice, management, IoT, guest, server
- Use a dedicated native VLAN (e.g., VLAN 999) on trunks -- never use VLAN 1
- Prune unnecessary VLANs from trunks to reduce broadcast scope

### VLAN Types

| VLAN Type | Purpose | Notes |
|---|---|---|
| Data VLAN | User workstation traffic | Primary production traffic |
| Voice VLAN | VoIP phone traffic | QoS marked, separate from data |
| Management VLAN | Switch/router management | Restricted access, ACL-protected |
| Native VLAN | Untagged traffic on trunks | Change from default VLAN 1 for security |
| Guest VLAN | Untrusted guest access | Isolated, internet-only, no internal access |
| IoT VLAN | IoT devices | Segmented, firewall-controlled |

## ECMP (Equal-Cost Multi-Path)

ECMP load-balances traffic across multiple equal-cost paths:
- Hash-based forwarding (5-tuple: src/dst IP, protocol, src/dst port)
- Deterministic per-flow (same flow always takes same path)
- Configure `maximum-paths` in BGP/OSPF to enable
- Typical DC fabric: 64-128 ECMP paths
- Resilient hashing: minimizes flow redistribution when a path is added/removed

## VRF (Virtual Routing and Forwarding)

VRF creates isolated routing tables on a single device:
- Each VRF has its own RIB and FIB
- Interfaces are assigned to a VRF; traffic cannot cross VRF boundaries without route leaking or a firewall
- VRF-lite: VRF without MPLS labels (simple L3 segmentation)
- Use cases: multi-tenancy, compliance isolation, management separation
- In EVPN fabrics, each tenant VRF maps to an L3 VNI

## EVPN-VXLAN Fundamentals

### VXLAN Encapsulation

VXLAN (RFC 7348) encapsulates L2 frames in UDP/IP:
- Outer Ethernet (14B) + Outer IP (20B) + Outer UDP (8B) + VXLAN header (8B) = 50 bytes overhead
- UDP destination port 4789
- VNI (24-bit): 16 million virtual networks (vs 4094 VLANs)
- VTEP (Virtual Tunnel Endpoint): device performing encap/decap

### EVPN Control Plane

BGP EVPN (RFC 7432) replaces flood-and-learn with signaled MAC/IP learning:

| Route Type | Name | Purpose |
|---|---|---|
| Type-1 | Ethernet Auto-Discovery | Multi-homing fast convergence, mass withdrawal |
| Type-2 | MAC/IP Advertisement | Distributes MAC and MAC+IP bindings; enables ARP suppression |
| Type-3 | Inclusive Multicast | VTEP discovery; BUM traffic flood list setup |
| Type-4 | Ethernet Segment | DF election for multi-homed segments (ESI-LAG) |
| Type-5 | IP Prefix Route | L3 prefix advertisement; inter-subnet routing across fabric |

### Symmetric IRB

Symmetric IRB is the recommended forwarding model for VXLAN EVPN:
- Both ingress and egress VTEPs perform routing
- Per-VRF L3 VNI carries routed traffic between VTEPs
- Anycast gateway: same IP and MAC on every leaf for seamless VM mobility
- ARP suppression: EVPN answers ARP locally from Type-2 MAC+IP bindings, eliminating BUM flooding

### Multi-Site EVPN

For data center interconnect (DCI):
- Border Gateways (BGW) connect separate EVPN fabrics
- Type-5 route re-origination between sites
- Each site has local Route Reflectors; BGWs peer between sites
- Stretched VLANs and inter-site L3 routing supported
