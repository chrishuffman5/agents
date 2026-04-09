# Arista EOS Versions

## Release Naming Convention

Every EOS release carries a version number in the format `4.MAJOR.MINOR[F|M]`:

| Suffix | Meaning | Behavior |
|---|---|---|
| **F** | Feature release | Contains new features/functionality; full TAC support |
| **M** | Maintenance release | Bug fixes only; no new features; full TAC support |

**Lifecycle pattern**: A major train starts with F releases (new features added), then transitions to M releases (stabilization/bug fixes), and eventually reaches End of Software Support (EoSS) after 36 months from initial posting.

**Recommendation**: Most production deployments target a recent M release of a supported train for maximum stability. Use the latest F release only when a specific new feature is required.

---

## EOS Lifecycle Policy

- **Support window**: 36 months per major software train from initial posting date
- **TAC support**: Available throughout the full 36-month window for both F and M releases
- **After EoSS**: No new patches, no TAC-initiated bug fixes; customers must upgrade

### Lifecycle Phases

1. **Feature Phase** — F releases; new capabilities added per release
2. **Maintenance Phase** — M releases; only bug fixes and stability improvements
3. **End of Software Support (EoSS)** — No further patches; TAC recommends upgrade

---

## EOS 4.35.x — Current Recommended Train

**Status**: Active — Current recommended train (as of early 2026)
**Support window**: 36 months from initial posting (~2025–2028)
**Release type progression**: 4.35.0F → 4.35.1F → 4.35.2F → ... → 4.35.xM

### New Features in EOS 4.35

| Feature | Description |
|---|---|
| **Cluster Load Balancing** | Optimizes load balancing for GPU cluster RoCE traffic; TOR monitors RoCE flows between GPU servers and spine uplinks |
| **Measured Boot** | Tamper-detection using TPM PCRs; cryptographic hashes of boot components stored for integrity verification |
| **Adjacency Sharing** | FEC deduplication in hardware; reduces ECMP FEC consumption for large-scale ECMP deployments |
| **BGP Monitoring Protocol (BMP)** | RFC 7854 BMP support for BGP session monitoring |
| **IPFIX Enhancements** | Extended IPFIX flow export capabilities |
| **QoS Improvements** | DSCP, ECN, and VLAN matching for traffic classification |
| **Enhanced Connectivity Monitoring** | Improved proactive health monitoring tools |
| **Campus SKU PoE** | Extended PoE support on CCS-710XP (fanless ARM platform) |
| **gNMI Persistence** | gNMI Set operations saved to startup-config (introduced 4.28, matured 4.35) |
| **OpenConfig Expansion** | Additional OpenConfig path coverage for interface and BGP state |

### 4.35 Platform Support

All major Arista hardware platforms are supported under 4.35.x:
- Fixed ToR: 7050X4, 7060X5, 7060CX2, 7060DX4, 7060PX4
- Spine/aggregation: 7280R3, 7300X3, 7500R3, 7800R4
- Campus: 720XP, 756 series
- CloudEOS: Virtual EOS for cloud deployments (AWS, Azure, GCP)

---

## EOS 4.34.x

**Status**: Active support
**Notable features**: Enhanced EVPN multihoming (ESI-LAG improvements), expanded gNMI paths, MPLS SR-TE improvements, extended platform coverage for 7800R4 series

---

## EOS 4.33.x

**Status**: Active support
**Notable features**: EVPN Multihoming (ESI) enhancements, BGP additional paths, improved PIM SSM, extended OpenConfig support

---

## EOS 4.32.x

**Status**: Active support
**Notable features**: EVPN Type-5 with Gateway-IP, VXLAN multi-site (DCI) improvements, sFlow extended counters

---

## EOS 4.31.x

**Status**: Active support (transitioning to maintenance)
**Notable features**: BGP Link State (BGP-LS), EVPN service insertion, multi-AS EVPN improvements

---

## EOS 4.30.x — End of Support April 2026

**Status**: APPROACHING END OF SUPPORT
**EoSS Date**: April 14, 2026
**Action required**: Customers on 4.30.x should plan immediate upgrade to 4.33.x or 4.35.x

EOS 4.30 represents 36 months from initial posting in April 2023. After April 14, 2026, no further software support is provided for this train.

---

## EOS 4.29.x

**Status**: Maintenance phase (likely approaching or past EoSS)
**Note**: No new features; bug fixes only; evaluate upgrade to current train

---

## EOS 4.28.x

**Status**: End of Software Support reached April 18, 2025
**Action**: Upgrade required — no patches or TAC-initiated bug fixes available

---

## Platform Hardware Reference

### Fixed-Configuration Data Center Switches

#### 7050X Series — ToR Leaf

| Spec | Details |
|---|---|
| Form Factor | 1RU fixed |
| Role | ToR leaf, access layer |
| Port Density | 48x25G + 8x100G (typical) |
| ASIC | Broadcom Trident3/Tomahawk3 variants |
| Buffer | Shallow to deep buffer options |
| Use Case | Standard server ToR, dual-connected hosts |

#### 7060X Series — High-Density Leaf/Spine

| Spec | Details |
|---|---|
| Form Factor | 1RU/2RU fixed |
| Role | Leaf or spine |
| Port Density | 64x100G or 32x400G (7060DX4) |
| ASIC | Broadcom Tomahawk3/Tomahawk4 |
| Throughput | 12.8Tbps+ |
| Use Case | High-density spine, large-scale leaf, GPU cluster TOR |

#### 7260X Series

| Spec | Details |
|---|---|
| Form Factor | 1RU/2RU |
| Port Density | 64x100G or mix of 25G/100G |
| Use Case | Flexible spine or high-density leaf with deep buffering |

---

### Aggregation and Spine Platforms

#### 7280R Series — Universal Spine/Aggregation

| Spec | Details |
|---|---|
| Form Factor | Fixed 1RU/2RU |
| Role | Spine, DCI edge, Internet peering |
| Routing Table | Full internet table support (>1M routes) |
| Buffer | Deep buffers (Jericho2/Jericho2c ASIC) |
| Features | INT (In-band Network Telemetry), sFlow, VXLAN |
| Use Case | Large-scale spine, service provider edge, DCI |

#### 7300X Series — Modular High-Density

| Spec | Details |
|---|---|
| Form Factor | 4-slot and 8-slot modular chassis |
| Role | High-density spine or aggregation |
| Capacity | Highest 10/40/100G density in modular form |
| Use Case | Leaf/spine and spline topologies, large campus core |

---

### Modular Core Platforms

#### 7500R Series — Universal Spine

| Spec | Details |
|---|---|
| Form Factor | Modular chassis |
| Throughput | Up to 230Tbps |
| Port Types | High-density 400G and 100G |
| Routing | Internet-scale tables |
| Features | MACsec, VXLAN, MPLS, DCI |
| Use Case | Large DC spine, DCI, service provider core |

#### 7800R4 Series — Core/Edge

| Spec | Details |
|---|---|
| Form Factor | Modular chassis |
| Throughput | 460Tbps with MACsec |
| Routes | 2.5M+ routes |
| Port Density | Highest 400G/100G density |
| Use Case | Core, hyper-scale spine, carrier-class deployments |

---

### Campus Platforms

#### 720XP Series — PoE Campus Access

| Spec | Details |
|---|---|
| Form Factor | 1RU fixed |
| PoE | Up to 60W per port (PoE++) |
| Uplinks | 10G/25G/100G |
| Use Case | Campus access layer, wireless AP, IP phone, IoT |
| Features | Cognitive campus analytics, EOS full feature set |

#### 756 Series

| Spec | Details |
|---|---|
| Form Factor | Fixed |
| Role | Campus aggregation/distribution |
| Use Case | Multi-Gigabit campus distribution |

#### CCS-710XP

| Spec | Details |
|---|---|
| CPU | ARM (fanless design) |
| Form Factor | Compact/fanless |
| Use Case | Remote/branch office, silent deployments, space-constrained environments |

---

## Version Selection Guide

| Scenario | Recommended Version |
|---|---|
| New greenfield deployment | Latest 4.35.xF or first 4.35.xM |
| Existing stable production | Stay on supported M release; plan upgrade to 4.33.xM or 4.35.xM |
| Running 4.30.x | Upgrade immediately — EoSS April 14, 2026 |
| Running 4.28.x | Critical: EoSS passed April 18, 2025 — upgrade required |
| GPU/AI cluster | 4.35.x for Cluster Load Balancing features |
| CloudVision managed | Check CVP/CVaaS compatibility matrix before upgrading |

---

## CVP / CVaaS Version Compatibility

CloudVision has its own lifecycle independent of EOS:
- CVaaS: Continuously updated SaaS (no customer-managed upgrade)
- CVP on-prem: Independent release train; check compatibility matrix
- Static Configuration Studio (used by AVD cv_deploy): Requires CVaaS or CVP 2024.1.0+
- EOS device support in CVP: Generally supports all EOS trains within their active support window

---

## Sources

- [EOS Life Cycle Policy - Arista](https://www.arista.com/en/support/product-documentation/eos-life-cycle-policy)
- [End of Software Support Advisories - Arista](https://www.arista.com/en/support/advisories-notices/endofsupport)
- [EOS 4.35.2F Overview - Arista](https://www.arista.com/en/um-eos/eos-overview)
- [EOS 4.35.2F Transfer of Information - Arista](https://www.arista.com/en/support/toi/eos-4-35-2f)
- [Arista 7050X Series](https://www.arista.com/en/products/7050x-series)
- [Arista 7800R4 Series Specifications](https://www.arista.com/en/products/7800r4-series/specifications)
- [EOS/EOL Schedule and Product Lifecycle](https://www.it-server-room.com/en/arista-networks-eos-eol-schedule-and-product-lifecycle/)
