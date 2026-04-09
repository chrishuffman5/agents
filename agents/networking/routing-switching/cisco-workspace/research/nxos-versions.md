# Cisco NX-OS Version Reference

## Version Numbering Scheme

### Format: `AA.BB(CC)T`

| Component | Meaning                                                     |
|-----------|-------------------------------------------------------------|
| `AA`      | Major release (10 = current generation)                     |
| `BB`      | Minor release within the major train                        |
| `(CC)`    | Maintenance release number                                  |
| `T`       | Release type: **F** (Feature) or **M** (Maintenance)        |

### Release Type Conventions

| Type | Name               | Characteristics                                           |
|------|--------------------|-----------------------------------------------------------|
| `F`  | Feature Release    | New features introduced; shorter support lifecycle        |
| `M`  | Maintenance Release| Bug fixes and security patches; extended support lifecycle|

### Release Lifecycle Policy

- **F (Feature) releases**: Supported for approximately 9 months after the next release
- **M (Maintenance) releases**: Long-term supported; recommended for production
  - Cisco recommends qualifying on the latest M release
  - M releases receive security patches for 3+ years
- Typical flow: `10.6(1)F` → `10.6(2)F` → `10.6(3)M` (hypothetical) or `10.7(1)F`

### Upgrade Path Rules

- Can upgrade from any M release directly to the next M release
- F releases may have intermediate upgrade requirements
- Always check the NX-OS Software Upgrade and Downgrade Guide for your specific version pair
- Nexus 9000 supports ISSU (In-Service Software Upgrade) between compatible releases

---

## Release: 10.4(7)M (Prior Maintenance)

**Status**: Prior Maintenance — still deployed; approaching end of active maintenance

### Overview

10.4(7)M was the final maintenance release of the 10.4 train for Nexus 9000. It represents a stable, long-running baseline for environments that deferred upgrades. The 10.4 train was an important release that introduced Cloud Scale ASIC support improvements and enhanced VXLAN EVPN capabilities.

### Key Features in 10.4.x Train

**VXLAN / EVPN**
- VXLAN BGP EVPN multi-site enhancements (Type-5 route improvements)
- EVPN Route Type 2 (MAC/IP) host route redistribution improvements
- Symmetric IRB stability improvements for large-scale deployments
- EVPN L3VNI per-VRF anycast gateway optimizations

**BGP**
- BGP Additional Paths (RFC 7911) for EVPN
- BGP Graceful Restart timer tuning
- BGP route refresh improvements

**vPC**
- vPC Fabric Peering (eliminates dedicated vPC peer-link cable requirement)
- vPC Peer-Switch enhancements for STP
- vPC + VXLAN co-existence improvements

**Programmability**
- gRPC dial-out telemetry improvements
- NX-API REST DME model coverage expansion
- YANG model updates for VXLAN operational data

**Security**
- MACsec on 10/25/40/100G ports on supported Nexus 9000 line cards
- Control Plane Policing (CoPP) template improvements

### Platform Support (10.4.x)

- Nexus 9200, 9300, 9300-EX, 9300-FX, 9300-FX2, 9300-FX3, 9300-GX, 9300-GX2
- Nexus 9500 (all line cards: -EX, -FX, -GX)
- Nexus 9500R (R-series with 400G)
- Nexus 3000 (3100, 3200, 3500)

---

## Release: 10.5(5)M (Current Recommended Maintenance)

**Status**: Current Recommended — production baseline as of early 2026

**Release Date**: March 16, 2026

### Overview

10.5(5)M is the current recommended Maintenance release for Nexus 9000. It is the stable, production-hardened release recommended by Cisco TAC for new deployments and upgrades from 10.4.x. Consolidates fixes from 10.5(1)F through 10.5(4)M.

### Key Features Introduced in 10.5.x Train

**VXLAN / EVPN**
- EVPN multi-site BGP policy enhancements (inter-site Type-5 filtering)
- Selective Q-in-VNI mapping for service provider environments
- Enhanced EVPN ARP suppression with stale entry management
- VXLAN Flood-and-Learn co-existence with EVPN (migration scenarios)
- NVE interface BFD support for fast VTEP failure detection

**Routing**
- BGP EVPN RT (Route Target) import/export auto-derivation enhancements
- OSPF Fast Convergence improvements (SPF throttle tuning)
- IS-IS as VXLAN EVPN underlay improvement
- VRF Lite with EVPN seamless integration
- Route Leaking between VRFs via BGP EVPN Type-5

**vPC**
- vPC Fabric Peering over routed links (no dedicated peer-link)
- vPC + VXLAN peer-link traffic optimization
- vPC consistency check improvements reducing false peer-link failures
- Auto-recovery enhancements for vPC domain split-brain scenarios

**Programmability**
- gNMI ON_CHANGE subscription for interface operational data
- NX-API REST bulk operation improvements
- Enhanced OpenConfig model support (interfaces, BGP, VLAN)
- YANG model versioning improvements

**Security / Management**
- AAA RADIUS/TACACS+ improvements
- SSH key rotation support
- Control Plane Policing (CoPP) customization templates
- RBAC (Role-Based Access Control) fine-grained permission model updates

**Platform-Specific**
- Nexus 9300-GX2 (400G fixed) full feature support
- Nexus 9500 with -GX line cards VXLAN feature parity
- Nexus 9808 chassis support improvements

---

## Release: 10.6(1)F (Current Feature Release)

**Status**: Current Feature Release — for environments needing latest capabilities

**Release Date**: August 13, 2025

### Overview

10.6(1)F introduces new capabilities beyond the 10.5 train. Used by operators needing specific new features before an M release stabilizes. Not recommended for conservative production environments.

### New Features in 10.6(1)F

**VXLAN / EVPN**
- EVPN Type-2 route for IPv6 host advertisements
- VXLAN EVPN with IPv6 underlay (IPv6 NVE source interface)
- Multi-site BGW (Border Gateway) scale improvements (up to 1M routes)
- EVPN route reflector anycast address support

**Advanced Fabric**
- SRv6 (Segment Routing over IPv6) initial support on Nexus 9000
- VxLAN Integrated Routing and Bridging (IRB) with IPv6 tenant support
- MPLS over VXLAN (for DC-WAN gateway scenarios)

**Routing**
- BGP CT (Color-Extended Community) for Flex-Algo integration
- OSPFV3 multi-topology support
- BFD hardware offload improvements on -GX ASICs

**Telemetry**
- Streaming telemetry path coverage expansion for EVPN operational data
- gNMI SUBSCRIBE improvements for sub-30 second intervals
- Nexus Dashboard Insights integration improvements

**Security**
- MACsec 256-bit AES GCM support on 400G ports
- Enhanced CoPP for gRPC/gNMI control plane traffic class

**Sustainability**
- Power telemetry streaming (per-line-card power consumption)
- Thermal sensor streaming telemetry

---

## Release: 10.6(2)F (Latest Feature Release)

**Status**: Latest Feature — December 14, 2025

### New Features Beyond 10.6(1)F

- Further SRv6 micro-segment (uSID) support
- EVPN multi-homing (ESI-based) stability improvements
- NDFC (Nexus Dashboard Fabric Controller) 12.x integration
- Expanded 400G ZR/ZR+ coherent optics support
- Enhanced ISSU support for 10.6(2)F → 10.6(x)M path

---

## Platform Support Matrix

### Nexus 9000 Series

| Platform         | Form Factor       | Max Ports         | ASIC Generation       | Notes                          |
|-----------------|-------------------|-------------------|-----------------------|--------------------------------|
| N9K-C9232C       | Fixed 32x100G     | 32x QSFP28        | Cloud Scale           | Spine, compact                 |
| N9K-C9236C       | Fixed 36x100G     | 36x QSFP28        | Cloud Scale           | ToR / spine                    |
| N9K-C9272Q       | Fixed 72x40G      | 72x QSFP+         | Cloud Scale           | Leaf                           |
| N9K-C9300-FX3    | Fixed 48x25G+6x100G| Enhanced          | Cloud Scale FX3       | High-density leaf              |
| N9K-C9300-GX     | Fixed 48x100G     | 48x QSFP28        | Cloud Scale GX        | 100G leaf, -GX ASIC            |
| N9K-C9300-GX2    | Fixed 64x400G     | 64x QSFP-DD       | Cloud Scale GX2       | 400G ToR/leaf                  |
| N9K-C9500        | Modular chassis   | Up to 512x100G    | FX/GX line cards      | Core/spine, 4/8/16-slot        |
| N9K-C9808        | Modular chassis   | Up to 576x400G    | GX2 line cards        | Ultra-scale spine              |

### Nexus 7000 / 7700 Series

| Platform         | Form Factor       | VDC Support | Notes                           |
|-----------------|-------------------|-------------|---------------------------------|
| N7K-C7004        | 4-slot chassis    | Yes (4 VDC) | Legacy; End of Sale             |
| N7K-C7010        | 10-slot chassis   | Yes (4 VDC) | Legacy; still deployed widely   |
| N7K-C7718        | 18-slot chassis   | Yes (4 VDC) | High-density legacy core        |
| N77-C7702        | 2-slot compact    | Yes (4 VDC) | Nexus 7700 platform             |
| N77-C7706        | 6-slot chassis    | Yes (4 VDC) | Nexus 7700 mid-size             |
| N77-C7710        | 10-slot chassis   | Yes (4 VDC) | Nexus 7700 standard             |

> Nexus 7000: EoS announced; 7700 still in active production. NX-OS 8.4(x) is the final train.

### Nexus 5600 Series

| Platform         | Notes                                                     |
|-----------------|-----------------------------------------------------------|
| N56128P          | 128x10G + 8x40G, FEX support                             |
| N5624Q           | 24x40G, FEX support                                       |
| N5672UP          | 48x10G + 6x40G, FCoE support                             |

> Nexus 5600: EoS for most models. NX-OS 7.3(x) final train.

### Nexus 3000 Series

| Platform         | Notes                                                     |
|-----------------|-----------------------------------------------------------|
| N3K-C3548P-XL    | 48x10G, ultra-low latency                                 |
| N3K-C3172PQ      | 48x10G + 6x40G, Layer 2/3 campus/DC edge                 |
| N3K-C31108PC-V   | 48x10G + 6x100G, flexible ToR                            |
| N3K-C3264Q       | 64x40G spine for smaller fabrics                         |

> Nexus 3000: Shares NX-OS 10.4/10.5/10.6 releases (same software as 9000 for compatible platforms).

---

## Version Recommendation Matrix

| Use Case                         | Recommended Release     | Rationale                            |
|----------------------------------|-------------------------|--------------------------------------|
| New DC fabric deployment         | 10.5(5)M                | Current M release, production stable |
| Existing 10.4.x production       | Upgrade to 10.5(5)M     | Consolidates security fixes          |
| Needs SRv6 or 400G ZR features   | 10.6(2)F                | New features not in 10.5.x           |
| Nexus 7000 (legacy)              | 8.4(x) (final train)    | 9000 replacement recommended         |
| Lab / development                | 10.6(2)F                | Latest code for testing              |

---

## Upgrade Path Reference

```
10.4(7)M → 10.5(5)M     # Direct upgrade supported (verify ISSU support)
10.5(5)M → 10.6(1)F     # Direct upgrade supported
10.5(5)M → 10.6(2)F     # Direct upgrade supported
10.6(1)F → 10.6(2)F     # Direct upgrade supported

# ISSU eligibility: Check "show incompatibility nxos <image>" before upgrade
```

---

## References

- NX-OS Recommended Releases (Nexus 9000): https://www.cisco.com/c/en/us/td/docs/switches/datacenter/nexus9000/sw/recommended_release/b_Minimum_and_Recommended_Cisco_NX-OS_Releases_for_Cisco_Nexus_9000_Series_Switches.html
- NX-OS 10.5(5)M Release Notes: https://www.cisco.com/c/en/us/td/docs/dcn/nx-os/nexus9000/105x/release-notes/cisco-nexus-9000-nxos-release-notes-1055M.html
- NX-OS 10.6(1)F Release Notes: https://www.cisco.com/c/en/us/td/docs/dcn/nx-os/nexus9000/106x/release-notes/cisco-nexus-9000-nxos-release-notes-1061F.html
- NX-OS 10.6(2)F Release Notes: https://www.cisco.com/c/en/us/td/docs/dcn/nx-os/nexus9000/106x/release-notes/cisco-nexus-9000-nxos-release-notes-1062F.html
- NX-OS Upgrade Guide 10.6(x): https://www.cisco.com/c/en/us/td/docs/dcn/nx-os/nexus9000/106x/upgrade/cisco-nexus-9000-series-nx-os-software-upgrade-and-downgrade-guide-106x/
