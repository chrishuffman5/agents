# Cisco IOS-XE Version Reference

## Version Numbering Scheme

### Format: `AA.BB.CC` (e.g., 17.12.3)

| Component | Meaning                                                     |
|-----------|-------------------------------------------------------------|
| `AA`      | Major train (16 = 2017-era, 17 = current generation)        |
| `BB`      | Release within train; groups of 3 form a "release family"   |
| `CC`      | Rebuild / maintenance number (bug fixes, security patches)  |

### Train Names (17.x)

Each group of three releases shares a city code name:

| Releases        | Train Name   | Type                                |
|-----------------|--------------|-------------------------------------|
| 17.1–17.3       | Amsterdam     | Feature → Standard Maintenance      |
| 17.4–17.6       | Bengaluru     | Feature → Standard Maintenance      |
| 17.7–17.9       | Cupertino     | Feature → Extended Maintenance (LTS)|
| 17.10–17.12     | Dublin        | Feature → Extended Maintenance (LTS)|
| 17.13–17.15     | Eindhoven     | Feature → Extended Maintenance (LTS)|
| 17.16–17.18     | Fuentes       | Feature → Standard / Feature        |

### Release Type Designators

| Suffix | Type                  | Description                                          |
|--------|-----------------------|------------------------------------------------------|
| None   | Standard Maintenance  | Regular release; bug fixes + features                |
| (ED)   | Early Deployment      | First in a new feature family; early adopter         |
| (GD)   | General Deployment    | Stable, recommended for most deployments             |
| (LD)   | Limited Deployment    | Mature, approaching end of new feature addition      |
| LTS    | Long-Term Support     | Extended Maintenance releases (every 3rd minor)      |

### Extended Maintenance vs. Standard Maintenance

- **Extended Maintenance (LTS)**: 3rd release in each city family (e.g., 17.9, 17.12, 17.15, 17.18...)
  - 48 months of software maintenance support
  - Recommended for production deployments requiring long-term stability
- **Standard Maintenance**: 1st and 2nd releases in each city family
  - 12 months of maintenance support after next release
  - Used for feature access before LTS stabilization

---

## Release: 17.12.x (Dublin LTS)

**Status**: Extended Maintenance — Security support ends December 2026

### Overview

17.12.x is the LTS release in the Dublin family (17.10–17.12). It represents the "Dublin" cycle's mature, long-term supported release. Widely deployed in production campus and branch environments.

### Key Features Introduced in 17.12.x

**Programmability & Automation**
- Enhanced NETCONF candidate datastore support
- RESTCONF PATCH improvements for atomic operations
- gNMI ON_CHANGE telemetry for interfaces and routing tables
- `show running-config | format restconf-json` and `netconf-xml` translation

**Security**
- Control Plane Policing (CoPP) template enhancements for Catalyst 9000
- MACsec improvements on Catalyst 9300/9400
- FIPS 140-3 compliance on select platforms
- TLS 1.3 support for management plane

**Routing / Switching**
- BGP EVPN VXLAN for campus (Catalyst 9300/9400/9500)
- SR-MPLS (Segment Routing) enhancements
- Enhanced OSPF fast-reroute (LFA/rLFA)
- PBR-based ECMP improvements

**Wireless (Catalyst 9800)**
- Wi-Fi 6E (802.11ax) extended band support
- mDNS Service Discovery improvements
- Fabric wireless scalability enhancements (16K APs per controller pair)

**Platform Enhancements**
- StackWise Virtual enhanced DAD (Dual Active Detection)
- Catalyst 9600X support with enhanced QoS pipeline
- USB 3.0 boot support on Catalyst 9300

### Recommended Builds (17.12.x)

| Platform         | Recommended Build |
|-----------------|-------------------|
| Catalyst 9300   | 17.12.4           |
| Catalyst 9400   | 17.12.4           |
| Catalyst 9500   | 17.12.4           |
| Catalyst 9800   | 17.12.5           |
| ISR 4000        | 17.12.3           |
| ASR 1000        | 17.12.3           |

---

## Release: 17.16.x (Standard Maintenance)

**Status**: Standard Maintenance — active

### Overview

17.16.x is the first release in the "Fuentes" family. Standard Maintenance release introducing new platform features. Not recommended as a long-term production baseline unless specific features are required.

### Key Features Introduced in 17.16.x

**Security**
- Phase 1 legacy protocol deprecation warnings begin (17.16+)
- SNMPv2c deprecation warnings added
- Telnet disabled by default on new installations
- Enhanced AAA with RADIUS CoA (Change of Authorization) improvements

**SD-Access**
- Catalyst Center 2.3.7 integration enhancements
- SD-Access Border Node multi-site scaling improvements
- SDA wireless fabric — AP join optimization

**Routing**
- BGP graceful restart enhancements
- EVPN Type-5 route improvements for campus deployments
- OSPF LSA throttle tuning per area

**Programmability**
- YANG Suite integration improvements
- OpenConfig BGP model extended coverage
- Streaming telemetry dial-in mode improvements

**Catalyst 9800 Wireless**
- Wi-Fi 7 (802.11be) EHT (Extremely High Throughput) initial support
- MLO (Multi-Link Operation) support on supported APs
- 6 GHz UNII-5/UNII-7 regulatory updates

---

## Release: 17.18.x (Current)

**Status**: Standard Maintenance — current; future LTS candidate

### Overview

17.18.x is the third release in the Fuentes family and is positioned as the Extended Maintenance (LTS) release for this cycle. This makes 17.18 the recommended long-term deployment target replacing 17.12 LTS as platforms age onto newer code.

### Key Features Introduced in 17.18.x

**Security (Major Focus)**
- **Legacy Protocol Phase-Out Phase 2**: Beginning with 17.18.2, IOS XE displays warning messages when configuring insecure features/protocols (telnet, SNMPv1/v2c, MD5 auth, DES/3DES)
- SSHv1 removal (hard deprecation)
- TLS 1.0/1.1 disabled by default
- Enhanced FIPS 140-3 compliance

**Programmability**
- gNMI gNOI (gRPC Network Operations Interface) for operational tasks
- Enhanced YANG library with 17.18-specific Cisco native models
- Improved OpenConfig platform model coverage (transceiver, fan, PSU)

**Routing & Forwarding**
- Segment Routing v6 (SRv6) enhancements for IOS XE
- BGP Additional-Paths improvements
- MPLS fast-reroute TI-LFA (Topology Independent LFA)

**SD-Access / Campus**
- Catalyst Center 2.3.7.x API v2 enhancements
- SD-Access multi-site inter-fabric routing improvements
- Campus EVPN IRB (Integrated Routing and Bridging) enhancements

**Catalyst 9800 (Wireless)**
- Wi-Fi 7 MLO (Multi-Link Operation) production support
- 6 GHz AFC (Automated Frequency Coordination) support
- Catalyst Center wireless assurance improvements

**Platform-Specific**
- Catalyst 9200CX compact switch support
- Catalyst 9300X (UPOE++ ports) expanded feature parity
- ASR 1000 400G port module support (ASR1001-HX)

---

## Platform Support Matrix

### Catalyst Campus Switches

| Platform       | Form Factor     | Max Stack | PoE          | Typical Use Case               |
|---------------|-----------------|-----------|--------------|-------------------------------|
| Catalyst 9200  | Fixed 24/48p    | 8         | Yes (UPOE+)  | Access layer, SMB              |
| Catalyst 9300  | Fixed 24/48p    | 8         | Yes (UPOE+)  | Access layer, enterprise       |
| Catalyst 9300X | Fixed 24/48p   | 8         | Yes (UPOE++) | Access, mGig, Wi-Fi 6E ready   |
| Catalyst 9400  | Modular         | SVL       | Yes (UPOE+)  | Distribution/core, high density|
| Catalyst 9500  | Fixed           | SVL       | No           | Collapsed core, ToR            |
| Catalyst 9500H | Fixed high-perf| SVL       | No           | High-density 40/100G spine     |
| Catalyst 9600  | Modular         | SVL       | No           | Core, data center edge         |
| Catalyst 9600X | Modular chassis | SVL      | No           | Core, high-density 100G        |

### Catalyst Wireless

| Platform       | Description                         | Key Capability               |
|---------------|-------------------------------------|------------------------------|
| Catalyst 9800-L| Fixed appliance (small campus)      | Up to 500 APs                |
| Catalyst 9800-40| Mid-range appliance                | Up to 2000 APs               |
| Catalyst 9800-80| High-end appliance                 | Up to 6000 APs               |
| Catalyst 9800-CL| Cloud/virtual (ESXi, KVM, AWS)     | Up to 6000 APs               |
| C9800 Embedded | Embedded in Catalyst 9300/9400     | Small/branch deployments     |

### Branch and WAN Routers

| Platform        | Description                        | Throughput    |
|----------------|-------------------------------------|---------------|
| ISR 1100-4G     | Branch router, 4 WAN ports          | ~1 Gbps       |
| ISR 1100-6G     | Branch router, 6 WAN ports          | ~2 Gbps       |
| ISR 4321        | Branch/SOHO, 2 WAN, 2 SFP           | ~100 Mbps     |
| ISR 4331        | Branch, 3 WAN, NIM slots            | ~300 Mbps     |
| ISR 4351        | Mid-branch, 3 WAN, NIM slots        | ~400 Mbps     |
| ISR 4431        | Enterprise branch                   | ~1 Gbps       |
| ISR 4451        | Large branch, SM/NIM modules        | ~2 Gbps       |
| ASR 1001-HX     | Edge aggregation                    | ~60 Gbps      |
| ASR 1002-HX     | Edge aggregation, RP + ESP          | ~100 Gbps     |
| ASR 1006-X      | Chassis, modular RP/ESP             | ~200+ Gbps    |

---

## Version Selection Decision Tree

```
Production deployment?
├── YES: Need support > 2 years?
│   ├── YES → Use current LTS (17.18.x as of 2026)
│   └── NO  → Use 17.16.x (Standard) if specific features needed
└── NO (lab/dev):
    └── Use latest available in training
```

### TAC Recommended Release Process

1. Check [Cisco Software Research](https://software.cisco.com/) for platform-specific recommendations
2. Review Field Notices and Security Advisories before upgrade
3. Test in staging with same config/topology
4. Use ISSU where supported for minimal disruption

---

## References

- IOS XE 17 Release List: https://www.cisco.com/c/en/us/support/ios-nx-os-software/ios-xe-17/products-release-notes-list.html
- Catalyst 9400 17.18 Release Notes: https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9400/software/release/17-18/release_notes/ol-17-18-9400.html
- Catalyst 9800 17.18.1 Release Notes: https://www.cisco.com/c/en/us/td/docs/wireless/controller/9800/17-18/release-notes/rn-17-18-9800.html
- ISR 1000 17.18 Release Notes: https://www.cisco.com/c/en/us/td/docs/routers/access/1100/release/17-18/isr1k-release-notes-xe-17-18-x.html
- IOS XE Naming Convention: https://community.cisco.com/t5/networking-knowledge-base/cisco-ios-and-ios-xe-naming-convention-for-routing-platforms/ta-p/4520161
