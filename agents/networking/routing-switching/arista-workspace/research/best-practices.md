# Arista DC Fabric Design Best Practices

## Spine-Leaf Architecture Overview

The modern Arista data center fabric is built on a Clos (spine-leaf) topology providing:
- Predictable, consistent latency (any host to any host = fixed hop count)
- Horizontal scalability (add leaf pairs without restructuring)
- Non-blocking fabric with ECMP load balancing
- Active-active multi-path utilization (no STP blocking)

### Standard 2-Tier (Leaf-Spine)

```
        SPINE1          SPINE2
          |  \          /  |
          |   ----------   |
       LEAF1A  LEAF1B   LEAF2A  LEAF2B
         |        |       |       |
       Server  Server   Server  Server
```

- **Spine**: Pure L3 IP fabric nodes; no tenant VLANs; all routed interfaces
- **Leaf**: ToR switches; VTEP function; server-facing L2 + L3 gateway (SVIs)
- **MLAG pairs**: Leaf pairs share VTEP IP and provide active-active redundancy to servers
- **Oversubscription**: Typical 3:1 or 4:1 (downlinks:uplinks); adjust for GPU/HPC (often 1:1)

### Spine Sizing Guidelines

| Fabric Size | Spine Count | Leaf Pairs | Notes |
|---|---|---|---|
| Small (<20 leaf pairs) | 2 spines | Up to 20 pairs | Standard 2-spine; no redundant spines beyond 2 needed |
| Medium (20-48 leaf pairs) | 2-4 spines | 20-48 pairs | 4 spines for more bandwidth; each leaf uplinks to all spines |
| Large (>48 leaf pairs) | 4+ spines or 3-tier | 48+ pairs | Consider super-spine for mega-scale |
| AI/GPU cluster | 2-8 spines | As needed | Full mesh or 1:1 oversubscription; RoCE requires low latency |

---

## BGP Underlay Design

### eBGP Underlay (Recommended)

The preferred modern design uses eBGP for the IP underlay (point-to-point routed links between leaves and spines). Each leaf has a unique ASN; spines share an ASN (or each spine has a unique ASN in some designs).

**Advantages over OSPF underlay:**
- Policy control (route filtering, prefix-list based)
- Built-in loop prevention (no need for OSPF stub/filtering)
- Scales to very large fabrics without LSDB concerns
- Consistent with EVPN overlay (one protocol stack to manage)

### ASN Assignment Models

#### Model 1: Unique ASN Per Leaf (Recommended)

```
Spine ASN: 65100 (shared)
Leaf1 ASN: 65101
Leaf2 ASN: 65102
Leaf3 ASN: 65103
...
```

- AS-path loop prevention naturally prevents routing loops
- Simplest to understand and troubleshoot
- Requires 4-byte ASN space for large fabrics (use 65000.x notation)

#### Model 2: Shared Leaf ASN (Requires allowas-in or as-path override)

```
Spine ASN: 65100
All Leafs: 65101
```

- Simpler ASN management
- Requires `allowas-in` or `bgp allowas-in` to accept routes with own ASN in path
- Less preferred due to reduced loop protection

### eBGP Underlay Configuration Pattern

```
! SPINE
router bgp 65100
   router-id 10.255.0.1
   no bgp default ipv4-unicast
   maximum-paths 4 ecmp 4
   
   neighbor LEAF peer group
   neighbor LEAF send-community
   neighbor LEAF maximum-routes 12000
   
   ! Add leaf neighbors (point-to-point link IPs)
   neighbor 10.0.1.1 peer group LEAF
   neighbor 10.0.1.1 remote-as 65101
   neighbor 10.0.1.3 peer group LEAF
   neighbor 10.0.1.3 remote-as 65102
   
   address-family ipv4
      neighbor LEAF activate

! LEAF
router bgp 65101
   router-id 10.255.1.1
   no bgp default ipv4-unicast
   maximum-paths 4 ecmp 4
   
   neighbor SPINE peer group
   neighbor SPINE remote-as 65100
   neighbor SPINE send-community
   neighbor SPINE maximum-routes 12000
   neighbor 10.0.1.0 peer group SPINE   ! Spine1
   neighbor 10.0.1.2 peer group SPINE   ! Spine2 (if 4 spines, add 2 more)
   
   address-family ipv4
      neighbor SPINE activate
      network 10.255.1.1/32   ! Loopback0 (router-id)
      network 10.255.2.1/32   ! Loopback1 (VTEP)
```

### iBGP Overlay with Route Reflectors (EVPN)

For the EVPN overlay, use iBGP with spines as Route Reflectors (RR). This keeps EVPN overlay independent from the underlay and avoids eBGP multihop complexity.

However, the more common modern pattern is **eBGP for both underlay and overlay** (using loopback-to-loopback eBGP multihop for EVPN). Both patterns work; pick one consistently.

**eBGP Overlay (most common in greenfield):**
```
! Loopback-based eBGP EVPN peers
neighbor SPINE-EVPN remote-as 65100
neighbor SPINE-EVPN update-source Loopback0
neighbor SPINE-EVPN ebgp-multihop 3
neighbor SPINE-EVPN send-community extended

address-family evpn
   neighbor SPINE-EVPN activate
```

The `ebgp-multihop 3` value accounts for the possibility of MLAG leaf needing to reach a spine loopback through the peer-link (3 hops: peer-link + underlay physical + loopback).

---

## VXLAN EVPN Overlay Design

### VNI Allocation

| Type | Range | Notes |
|---|---|---|
| L2 VNI (MAC-VRF) | 10000-49999 | One per VLAN; match VLAN number for clarity |
| L3 VNI (IP-VRF) | 50000-59999 | One per tenant VRF |

**Allocation convention:**
```
VLAN 100 → VNI 10100
VLAN 200 → VNI 10200
VRF TENANT-A → VNI 50001
VRF TENANT-B → VNI 50002
```

### Route Target Design

Use `rd auto` and `route-target both <VNI>:<VNI>` for simplicity. For multi-AS fabrics, use explicit RTs with a consistent schema:

```
! Auto RD/RT (simplest, single-AS)
vlan 100
   rd auto
   route-target both 100:100

! Explicit (multi-AS or complex policy)
vlan 100
   rd 10.255.1.1:10100
   route-target import 100:100
   route-target export 100:100
```

### ARP Suppression

Always enable ARP suppression in EVPN fabrics. It:
- Eliminates BUM (Broadcast, Unknown unicast, Multicast) flooding for ARP
- Reduces CPU load on VTEPs
- Improves convergence after VM migration

ARP suppression is automatic when `redistribute learned` is configured under `vlan X` in BGP and SVIs exist with `ip address virtual`.

---

## MLAG vs EVPN Multihoming

### MLAG (Multi-Chassis Link Aggregation)

**Use when:**
- Existing Arista-only infrastructure
- Simpler operational model preferred
- Broad feature compatibility required
- Teams familiar with MLAG operations

**Limitations:**
- Arista-proprietary
- Peer-link is a single point of contention (bandwidth, spanning)
- Split-brain scenarios require careful peer-keepalive design
- Maximum 2 switches per MLAG domain

**Configuration summary:** See `features.md` — MLAG section.

### EVPN Multihoming (ESI-LAG)

**Use when:**
- Multi-vendor environment
- New greenfield deployment targeting standards-based design
- More than 2 switches need to serve a single endpoint
- Eliminating peer-link overhead is desirable

**Advantages:**
- RFC standards-based (RFC 7432, RFC 8365)
- No peer-link required (eliminates bandwidth bottleneck)
- Scales beyond 2 nodes per segment
- Integrates natively with EVPN control plane

**Tradeoffs:**
- More complex configuration
- Requires EVPN-capable underlay (not compatible with OSPF-only underlay)
- Less operational experience in many organizations vs MLAG

---

## MTU Recommendations

VXLAN adds 50 bytes of overhead (14 Ethernet + 20 IP + 8 UDP + 8 VXLAN). To support 1500-byte inner frames:

| Link Type | Recommended MTU | Notes |
|---|---|---|
| Server-facing (access) | 9000 or 1500 | Match server NIC MTU |
| Leaf-spine uplinks | **9214** | Allows full VXLAN overhead plus inner jumbo frames |
| MLAG peer-link | **9214** | Must match leaf-spine uplinks |
| Loopback interfaces | N/A | No MTU setting needed |
| Management interfaces | 1500 | Standard; no jumbo needed |

**Configuration:**
```
! On all fabric-facing interfaces
interface Ethernet1
   mtu 9214
   no switchport
   
! Default system MTU (applies to all interfaces unless overridden)
system l1
   unsupported speed action error
   
! Or set globally
default interface-mtu 9214  ! Platform-dependent command
```

---

## BFD (Bidirectional Forwarding Detection)

BFD provides sub-second link failure detection independent of routing protocol hello timers.

### Recommended BFD Settings

```
! BFD for BGP (fabric links)
router bgp 65101
   neighbor SPINE bfd

! BFD timers (fabric links — 300ms detection)
router bfd
   interval 100 min-rx 100 multiplier 3   ! 300ms detection

! BFD multihop (for loopback-based EVPN sessions)
router bfd
   multihop interval 300 min-rx 300 multiplier 3

! Per-interface BFD
interface Ethernet1
   bfd interval 100 min-rx 100 multiplier 3
   bfd echo
```

**Note:** BFD must be enabled consistently across all devices in the fabric. A device without BFD on a link will not participate in fast failover.

---

## Management Network Design

### Out-of-Band Management

Always use a dedicated out-of-band management network:

```
! Dedicated management VRF
vrf instance management

! Management interface
interface Management1
   description OOB-Management
   vrf management
   ip address 192.168.0.11/24

! Management default route
ip route vrf management 0.0.0.0/0 192.168.0.1

! Restrict services to management VRF
management ssh
   vrf management

management api http-commands
   protocol https
   no shutdown
   vrf management
      no shutdown

! NTP via management VRF
ntp server vrf management 192.168.0.10
```

### Management Plane Hardening

```
! Disable Telnet
management telnet
   shutdown

! SSH only, modern ciphers
management ssh
   authentication mode keyboard-interactive
   cipher aes128-ctr aes256-ctr
   mac hmac-sha2-256 hmac-sha2-512
   idle-timeout 60

! Restrict SNMP
snmp-server community <community> ro
snmp-server host 192.168.0.20 version 3 auth <user>
snmp-server group NOC v3 priv read all

! Banner
banner login
   Authorized access only. All activity is monitored.
EOF
```

---

## EOS Image Upgrade with CloudVision

### Recommended CVP-Managed Upgrade Workflow

1. **Upload image to CVP image repository**
   - Upload `EOS-4.35.2F.swi` (or `.swix` bundle with extensions) via CVP GUI

2. **Create Image Bundle**
   - Navigate: CVP → Provisioning → Image Management → Add Bundle
   - Select EOS image + any required extension files

3. **Assign bundle to container or device**
   - Container-level assignment applies to all devices in container
   - Device-level overrides container

4. **Review and create Change Control**
   - CVP generates upgrade tasks
   - Group into a Change Control; select Series execution for MLAG pairs

5. **MLAG ISSU (Series execution)**
   - CVP upgrades first MLAG peer
   - Traffic fails over to second peer
   - First peer comes up on new EOS
   - CVP upgrades second peer
   - Traffic rebalances

6. **Validate post-upgrade**
   - CloudVision streams show operational state
   - `show version` on each device
   - `show mlag detail` to verify MLAG re-establishes
   - `show bgp evpn summary` to verify EVPN peers

### Rollback

CloudVision maintains pre-change configuration snapshots. If an upgrade causes issues:
- Access the Change Control in CVP
- Click Rollback
- Select affected devices
- Execute rollback Change Control

---

## AVD for Automated Fabric Deployment

AVD (Arista Validated Designs) is the gold-standard for IaC DC fabric automation. Use AVD to eliminate manual per-device configuration.

### AVD Deployment Flow

```
                    YAML Intent
                        |
                  [eos_designs role]
                        |
               Structured Data Model (per device)
                        |
                [eos_cli_config_gen role]
                        |
               EOS CLI Config Files (per device)
                        |
         [cv_deploy role] OR [eos_config_deploy_eapi]
                        |
              CVaaS Static Config Studio  OR  eAPI
```

### Key AVD Design Principles

1. **Single source of truth**: All fabric intent lives in YAML files in Git
2. **Idempotent**: Re-running AVD is safe; only actual changes are pushed
3. **Peer review via Git**: Configuration changes go through PR review before deployment
4. **Change Control gates**: cv_deploy creates CVaaS Change Controls for approval before execution
5. **Fabric-wide consistency**: AVD enforces consistent MTU, BGP timers, naming conventions

### AVD Best Practice Settings

```yaml
# group_vars/DC1_FABRIC.yaml

# MTU
p2p_uplinks_mtu: 9214
overlay_mtu: 9214

# BGP
bgp_peer_groups:
  evpn_overlay_peers:
    bfd: true
    ebgp_multihop: 3
  ipv4_underlay_peers:
    send_community: all
    bfd: true

# BFD
bfd_multihop:
  interval: 300
  min_rx: 300
  multiplier: 3

# EVPN
evpn_import_pruning: true       # Only import routes for local VNIs
evpn_overlay_bgp_rtc: true      # Route Target Constraint (scalability)

# MLAG settings
mlag_interfaces_speed: 100gfull
mlag_peer_link_allowed_vlans: "2-4094"

# Spanning tree (MSTP for MLAG fabrics)
spanning_tree_mode: mstp
spanning_tree_priority: 4096
```

---

## Key Design Checklist

### Pre-Deployment

- [ ] MTU set to 9214 on all spine-leaf fabric links and peer-links
- [ ] BFD enabled on all BGP sessions (underlay and overlay)
- [ ] Management VRF configured; OOB management accessible
- [ ] NTP synchronized across all devices (critical for log correlation and telemetry)
- [ ] TACACS+/RADIUS configured for centralized authentication
- [ ] sFlow or streaming telemetry enabled for visibility
- [ ] EOS software version matches across all fabric nodes

### BGP/EVPN

- [ ] `no bgp default ipv4-unicast` to prevent accidental IPv4 AF activation
- [ ] `send-community extended` on all EVPN neighbors
- [ ] `maximum-paths` set appropriately for ECMP
- [ ] Route-target import/export consistent across all VTEPs for each VNI
- [ ] `rd auto` or explicit RD per VNI
- [ ] `redistribute learned` under each `vlan` in BGP (enables Type-2 advertisement)

### MLAG

- [ ] Domain-id identical on both peers
- [ ] Peer-link is a port-channel (not a single link)
- [ ] Loopback1 (VTEP) address identical on both peers
- [ ] `reload-delay` configured to prevent traffic blackholing during reboot
- [ ] Peer-keepalive path uses management network (not peer-link)
- [ ] `show mlag config-sanity` passes before go-live

### CloudVision

- [ ] All devices streaming telemetry to CVaaS/CVP
- [ ] Image bundles defined for current EOS version
- [ ] Change control approval workflow defined
- [ ] At least one administrator account created with service token for API access
- [ ] Compliance check baseline established post-initial deployment

---

## Sources

- [Layer 3 Leaf-Spine (BGP) - Arista ATD Lab Guides](https://labguides.testdrive.arista.com/2025.1/data_center/l3ls-bgp/)
- [Fabric Variables - Arista AVD collection](https://avd.arista.com/3.8/roles/eos_designs/doc/fabric-variables.html)
- [L2 and L3 EVPN - Symmetric IRB with MLAG - ATD Lab](https://labguides.testdrive.arista.com/2025.1/data_center/l2_l3_evpn_symm_mlag/)
- [Arista BGP EVPN - Configuration Example](https://overlaid.net/2019/01/27/arista-bgp-evpn-configuration-example/)
- [Arista Design Guide: Layer 3 Leaf & Spine](http://allvpc.net/Arista_L3LS_Design_Deployment_Guide.pdf)
- [Arista Design Guide: DCI with VXLAN](https://www.arista.com/assets/data/pdf/Whitepapers/Arista_Design_Guide_DCI_with_VXLAN.pdf)
- [VXLAN with MLAG Configuration Guide - Arista Community](https://arista.my.site.com/AristaCommunity/s/article/vxlan-with-mlag-configuration-guide)
- [Overview - Arista AVD eos_designs role](https://avd.arista.com/3.8/roles/eos_designs/index.html)
- [Arista Spine-Leaf BGP EVPN Best Practice - Arista Community](https://eos.arista.com/forum/spine-leaf-bgp-evpn-best-practice/)
