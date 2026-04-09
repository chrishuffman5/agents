# Arista EOS Features — Deep Dive

## VXLAN / EVPN

### Overview

VXLAN (RFC 7348) encapsulates L2 frames in UDP/IP packets (destination port 4789), enabling L2 and L3 overlay networks across any IP underlay. EVPN (RFC 7432, RFC 8365) provides a BGP-based control plane for VXLAN, replacing flood-and-learn with a distributed database of MAC/IP bindings.

**Key terms:**
- **VTEP** (Virtual Tunnel Endpoint): The device performing VXLAN encap/decap (typically a leaf switch)
- **VNI** (VXLAN Network Identifier): 24-bit segment identifier mapping to VLANs or VRFs
- **IRB** (Integrated Routing and Bridging): Gateway function at the VTEP
- **Symmetric IRB**: Both ingress and egress VTEPs route; uses an L3 VNI per VRF
- **Asymmetric IRB**: Only ingress VTEP routes; all VLANs must be present on all VTEPs

---

### EVPN Route Types

| Type | Name | Purpose |
|---|---|---|
| Type-1 | Ethernet Auto-Discovery | Fast convergence, ESI split-horizon filtering |
| Type-2 | MAC/IP Advertisement | Advertises MAC and MAC+IP bindings; enables ARP suppression |
| Type-3 | Inclusive Multicast | VTEP discovery; builds BUM flood lists |
| Type-4 | Ethernet Segment | Designated Forwarder election for multihomed segments |
| Type-5 | IP Prefix | Advertises IP prefixes (routes) into EVPN; used for external connectivity |

---

### VXLAN Interface Configuration

```
! VTEP loopback — source interface for VXLAN tunnels
interface Loopback1
   description VTEP
   ip address 10.0.254.3/32

! VXLAN interface
interface Vxlan1
   vxlan source-interface Loopback1
   vxlan udp-port 4789
   ! VLAN-to-L2VNI mappings
   vxlan vlan 100 vni 10100
   vxlan vlan 200 vni 10200
   ! VRF-to-L3VNI mapping (symmetric IRB)
   vxlan vrf TENANT-A vni 50001
   vxlan vrf TENANT-B vni 50002
   ! MLAG: share VTEP IP with peer
   vxlan virtual-router encapsulation mac-address mlag-system-id
```

### BGP EVPN Address Family

```
router bgp 65101
   router-id 10.0.255.3
   no bgp default ipv4-unicast
   maximum-paths 4 ecmp 4

   ! EVPN overlay peer group (loopback-to-loopback, eBGP multihop)
   neighbor SPINE-EVPN peer group
   neighbor SPINE-EVPN remote-as 65100
   neighbor SPINE-EVPN update-source Loopback0
   neighbor SPINE-EVPN ebgp-multihop 3
   neighbor SPINE-EVPN send-community extended
   neighbor 10.0.255.1 peer group SPINE-EVPN
   neighbor 10.0.255.2 peer group SPINE-EVPN

   ! Activate EVPN address family
   address-family evpn
      neighbor SPINE-EVPN activate

   ! L2 VNI EVPN configuration per VLAN
   vlan 100
      rd auto
      route-target both 100:100
      redistribute learned

   vlan 200
      rd auto
      route-target both 200:200
      redistribute learned

   ! L3 VNI EVPN configuration per VRF (symmetric IRB)
   vrf TENANT-A
      rd 10.0.255.3:50001
      route-target import evpn 50001:50001
      route-target export evpn 50001:50001
      redistribute connected
      redistribute static

   vrf TENANT-B
      rd 10.0.255.3:50002
      route-target import evpn 50002:50002
      route-target export evpn 50002:50002
      redistribute connected
```

### ARP Suppression

ARP suppression uses EVPN Type-2 (MAC+IP) routes to answer ARP requests locally, eliminating BUM flooding for ARP.

```
! Enable per-VLAN on VXLAN interface
interface Vxlan1
   vxlan vlan 100 vni 10100
   !
   ! ARP suppression requires VLAN SVI to be configured
   
interface Vlan100
   ip address virtual 10.1.100.1/24
   arp aging timeout 14400
```

ARP suppression is automatically active when:
1. `redistribute learned` is configured under `vlan X` in BGP
2. MAC+IP (Type-2) routes are being exchanged with EVPN peers

---

### SVI / Anycast Gateway (Symmetric IRB)

```
! Shared virtual MAC for all SVIs (anycast gateway)
ip virtual-router mac-address 00:1c:73:00:00:01

! SVI with virtual IP (anycast gateway)
interface Vlan100
   description TENANT-A VL100
   vrf TENANT-A
   ip address virtual 10.1.100.1/24
   ip virtual-router address 10.1.100.1

interface Vlan200
   description TENANT-A VL200
   vrf TENANT-A
   ip address virtual 10.1.200.1/24
   ip virtual-router address 10.1.200.1

! Enable IP routing in VRF
ip routing vrf TENANT-A
```

---

### Type-5 Routes (IP Prefix Advertisement)

Type-5 routes advertise external (non-locally-attached) prefixes into EVPN. Used for:
- External routers injecting prefixes into the EVPN fabric
- Default route advertisement
- Aggregated route advertisement (summarization)

```
router bgp 65101
   vrf TENANT-A
      ! Redistribute from border leaf into EVPN
      redistribute connected
      redistribute bgp route-map EXPORT_TO_EVPN
      
      ! Type-5 requires Gateway-IP (optional, for next-hop resolution)
      ! route-target import/export configured as shown above
```

---

### EVPN Multihoming (ESI-LAG)

EVPN Multihoming (MH) is the standards-based alternative to MLAG for VTEP redundancy. Uses Ethernet Segment Identifiers (ESI) to identify multihomed links.

```
! Define ESI on multihomed port-channel
interface Port-Channel1
   evpn ethernet-segment
      identifier 0011:1111:1111:1111:1111
      route-target import 11:11:11:11:11:11
   lacp system-id 1111.1111.1111

! EVPN MH uses Type-1 and Type-4 routes for:
! - Fast convergence (Type-1 mass withdrawal)
! - Designated Forwarder (DF) election (Type-4)
! - Split-horizon filtering (Type-1 ESI label)
```

**EVPN MH vs MLAG:**
- ESI-LAG is standards-based, works across different vendors
- MLAG is Arista-proprietary but simpler to configure
- ESI-LAG scales better (no peer-link bandwidth constraint)
- MLAG has broader EOS feature compatibility in older releases

---

### Multi-Site EVPN (DCI)

For connecting multiple EVPN fabrics (data center interconnect), EOS supports:

1. **EVPN Gateway (Type-5 re-origination)**: Border Gateways (BGWs) re-originate Type-5 routes between sites
2. **EVPN stitching**: BGWs stitch L2VNIs and L3VNIs across fabric boundaries
3. **DCI with VXLAN**: Extend VXLAN tunnels between sites via BGWs

```
! Border Gateway configuration
router bgp 65101
   vrf TENANT-A
      ! Import from remote site BGW
      neighbor REMOTE-BGW peer group
      neighbor REMOTE-BGW remote-as 65201
      address-family evpn
         neighbor REMOTE-BGW activate
         neighbor REMOTE-BGW domain remote
      
   ! Re-originate Type-2 as Type-5 across DCI
   address-family evpn
      domain identifier 100:100
```

---

## MLAG — Multi-Chassis Link Aggregation

### MLAG Architecture

MLAG allows two switches to act as a single logical switch for downstream LAG connections. The pair presents one LACP system MAC to connected devices.

**Components:**
- **MLAG Domain**: Identified by a shared domain-id
- **Peer Link**: Port-channel carrying MLAG control traffic and backup data traffic
- **Peer-keepalive**: Layer 3 path (usually management network) for peer health detection
- **MLAG Interfaces**: Port-channels on both peers with matching MLAG IDs

### Full MLAG Configuration Example

```
! === SWITCH A (peer 1) ===

! Peer-keepalive interface (management network recommended)
interface Management1
   ip address 192.168.1.1/24

! Peer-link port-channel
interface Port-Channel1
   description MLAG-Peer-Link
   switchport mode trunk
   switchport trunk group MLAGPEER

interface Ethernet1
   description Peer-Link-Member
   channel-group 1 mode active

interface Ethernet2
   description Peer-Link-Member
   channel-group 1 mode active

! MLAG VLAN (for control traffic SVI)
vlan 4094
   trunk group MLAGPEER

interface Vlan4094
   description MLAG-Peer-Link-SVI
   ip address 10.255.252.0/31
   no autostate

! MLAG Configuration
mlag configuration
   domain-id DC1-LEAFPAIR1
   local-interface Vlan4094
   peer-address 10.255.252.1
   peer-link Port-Channel1
   peer-address heartbeat 192.168.1.2 vrf default
   reload-delay mlag 300
   reload-delay non-mlag 330

! Host-facing MLAG port-channel
interface Port-Channel5
   description Server1-LAG
   switchport mode trunk
   switchport trunk allowed vlan 100,200
   mlag 5

interface Ethernet5
   description Server1-LinkA
   channel-group 5 mode active
```

### MLAG with VXLAN

When MLAG and VXLAN are combined, both MLAG peers share a single VTEP IP (Loopback1):

```
! Both peers must have IDENTICAL Loopback1 address
interface Loopback1
   description VTEP-Shared
   ip address 10.0.254.3/32   ! Identical on both peers!

! MLAG system ID used as virtual router MAC in VXLAN
interface Vxlan1
   vxlan source-interface Loopback1
   vxlan virtual-router encapsulation mac-address mlag-system-id
   vxlan vlan 100 vni 10100
   vxlan vrf TENANT vni 50001
```

**Rules:**
- Loopback1 address must be identical on both MLAG peers
- VLAN-VNI mappings must be identical on both peers
- Only the MLAG peer receiving a packet performs VXLAN encapsulation
- Packets from the peer-link are never VXLAN-encapsulated (split horizon)

### MLAG ISSU Procedure

```
! Pre-upgrade check
show mlag config-sanity
show mlag detail

! Stage software image
copy sftp://server/EOS-4.35.2F.swi flash:EOS-4.35.2F.swi

! Verify STP restartability
show spanning-tree detail

! Initiate ISSU on first peer
reload issu upgrade flash:EOS-4.35.2F.swi
! Traffic switches to second peer during upgrade

! After first peer is up, repeat on second peer
! show version to confirm
```

---

## Routing

### BGP

#### eBGP Underlay (Spine-Leaf)

```
! === LEAF ===
router bgp 65101
   router-id 10.0.255.3
   no bgp default ipv4-unicast
   maximum-paths 4 ecmp 4
   
   neighbor SPINE peer group
   neighbor SPINE remote-as 65100
   neighbor SPINE send-community
   neighbor SPINE maximum-routes 12000
   
   ! Physical interface neighbors
   neighbor 10.0.1.0 peer group SPINE   ! Spine1
   neighbor 10.0.1.2 peer group SPINE   ! Spine2
   
   address-family ipv4
      neighbor SPINE activate
      network 10.0.255.3/32   ! Advertise loopback0
      network 10.0.254.3/32   ! Advertise VTEP loopback1
```

#### iBGP Overlay with Route Reflectors

For iBGP EVPN overlays, spines act as route reflectors:

```
! === SPINE (Route Reflector) ===
router bgp 65000
   router-id 10.0.255.1
   
   neighbor LEAF-EVPN peer group
   neighbor LEAF-EVPN remote-as 65000
   neighbor LEAF-EVPN update-source Loopback0
   neighbor LEAF-EVPN route-reflector-client
   neighbor LEAF-EVPN send-community extended
   
   address-family evpn
      neighbor LEAF-EVPN activate
```

#### BGP Route Manipulation

```
! Prefix list
ip prefix-list PL-LOOPBACKS permit 10.0.255.0/24 le 32
ip prefix-list PL-DEFAULT permit 0.0.0.0/0

! Route map
route-map RM-CONNECTED-TO-BGP permit 10
   match ip address prefix-list PL-LOOPBACKS

! Apply in BGP
router bgp 65101
   address-family ipv4
      redistribute connected route-map RM-CONNECTED-TO-BGP
```

#### BGP Timers and BFD

```
router bgp 65101
   neighbor SPINE timers 3 9     ! Keepalive 3s, hold 9s
   neighbor SPINE bfd            ! BFD for fast failover
   
! BFD global config
router bfd
   multihop interval 300 min-rx 300 multiplier 3
```

### OSPF

```
router ospf 1
   router-id 10.0.255.3
   passive-interface default
   no passive-interface Ethernet1
   no passive-interface Ethernet2
   network 10.0.0.0/8 area 0.0.0.0
   max-lsa 12000

interface Ethernet1
   ip ospf network point-to-point
   ip ospf area 0.0.0.0
```

### VRFs

```
! Define VRF
vrf instance TENANT-A
vrf instance TENANT-B

! Enable routing per VRF
ip routing vrf TENANT-A
ip routing vrf TENANT-B

! Route leaking (from VRF to global or between VRFs)
router bgp 65101
   vrf TENANT-A
      neighbor 10.1.1.1 remote-as 65200
      address-family ipv4
         neighbor 10.1.1.1 activate
         redistribute connected
```

### Static Routing

```
! Default route
ip route 0.0.0.0/0 10.0.0.1

! VRF static route
ip route vrf TENANT-A 0.0.0.0/0 10.1.100.254

! Floating static (administrative distance)
ip route 0.0.0.0/0 10.0.0.1 200   ! AD 200 (lower priority)
```

---

## Security

### ACLs (Access Control Lists)

```
! Standard IPv4 ACL
ip access-list MGMT-ACCESS
   10 permit ip 10.0.0.0/8 any
   20 permit ip 192.168.0.0/16 any
   30 deny ip any any log

! Extended IPv4 ACL
ip access-list extended FILTER-INTERNET
   10 permit tcp 10.0.0.0/8 any established
   20 permit icmp any any
   30 deny ip any any log

! Apply to interface
interface Ethernet1
   ip access-group FILTER-INTERNET in

! Apply to VTY lines
management ssh
   ip access-group MGMT-ACCESS in
```

### CoPP — Control Plane Policing

EOS implements CoPP to protect the CPU from high-rate traffic:

```
! View default CoPP policies
show policy-map copp

! Custom CoPP policy
policy-map type copp CUSTOM-COPP
   class copp-system-cvx
      police rate 2000 bps burst-size 2000 byte
   class copp-system-l3-dest-miss
      police rate 10000 bps burst-size 10000 byte action drop

! Apply (typically pre-configured; be careful modifying)
system control-plane
   service-policy copp input CUSTOM-COPP
```

### TACACS+ and RADIUS

```
! TACACS+
tacacs-server host 10.0.0.100
   key 7 <encrypted-key>
   timeout 5
   
aaa group server tacacs+ TACACS-SERVERS
   server 10.0.0.100
   
aaa authentication login default group TACACS-SERVERS local
aaa authorization commands all default group TACACS-SERVERS local
aaa accounting commands all default start-stop group TACACS-SERVERS

! RADIUS
radius-server host 10.0.0.101
   key 7 <encrypted-key>

aaa group server radius RADIUS-SERVERS
   server 10.0.0.101
   
aaa authentication login default group RADIUS-SERVERS local
```

### MACsec

```
mac security
   license license-key
   profile MACsec-Profile-1
      cipher aes128-gcm
      key 01 7 <encrypted-key>
      
interface Ethernet1
   mac security profile MACsec-Profile-1
```

### sFlow

```
sflow sample dangerous 1024     ! 1:1024 sampling rate
sflow polling-interval 5        ! Export counters every 5 seconds
sflow destination 10.0.0.200    ! sFlow collector
sflow source-interface Loopback0
sflow run                        ! Enable sFlow

! Per-interface enable
interface Ethernet1
   sflow enable
```

---

## CloudVision — Operational Workflows

### Change Control Workflow

1. **Create configlets** or use AVD/Studios to generate configs
2. **Assign configlets to containers or devices** in CVP provisioning
3. **Tasks are generated** (each device with pending config change gets a task)
4. **Create Change Control**: Select tasks, choose parallel or series execution
5. **Review diff**: CloudVision shows designed vs. running configuration with highlighted changes
6. **Approve**: Change Control moves to approved state
7. **Execute**: CVP pushes configurations, monitors for errors
8. **Verify**: Post-change state validation
9. **Rollback if needed**: One-click rollback to pre-change state

### Config Drift Detection

CloudVision continuously compares running configuration against intended (designed) configuration:
- Drift alerts appear in the Compliance dashboard
- Per-device compliance scores show percentage of config in desired state
- Unauthorized changes (manual CLI edits) are flagged
- Configlet reconciliation resolves drift

### Network-Wide Visibility

- **Topology view**: Live topology map with link state, utilization, and fault overlays
- **Device timeline**: Historical configuration changes with diff view
- **Event log**: Audit trail of all CloudVision-initiated changes
- **Telemetry dashboards**: Per-device CPU, memory, BGP state, interface counters
- **Pathfinder**: End-to-end path visualization for traffic flows; WAN analytics

### Image Management

```
! CVP Image Management Workflow:
! 1. Upload EOS image to CVP image repository
! 2. Create Image Bundle (image + extensions)
! 3. Assign bundle to container or device
! 4. Task is generated for upgrade
! 5. Execute via Change Control (respects maintenance windows)
! 6. For MLAG pairs: ISSU upgrade (one peer at a time)
```

### Streaming Telemetry via CloudVision

CloudVision acts as a gNMI collector. All managed devices stream state continuously:
- Interface counters
- BGP session state
- CPU and memory
- MLAG state
- VXLAN state

Data is stored in CloudVision's time-series database and queryable via the UI or API.

---

## Sources

- [EOS 4.35.2F - Configuring EVPN - Arista](https://www.arista.com/en/um-eos/eos-configuring-evpn)
- [EOS 4.35.2F - EVPN Overview - Arista](https://www.arista.com/en/um-eos/eos-evpn-overview)
- [L2 and L3 EVPN - Symmetric IRB with MLAG - ATD Lab](https://labguides.testdrive.arista.com/2025.1/data_center/l2_l3_evpn_symm_mlag/)
- [EOS 4.35.2F - Multi-Chassis Link Aggregation - Arista](https://www.arista.com/en/um-eos/eos-multi-chassis-link-aggregation)
- [VXLAN Routing with MLAG - Arista Community](https://arista.my.site.com/AristaCommunity/s/article/vxlan-routing-with-mlag)
- [EOS 4.35.2F - VXLAN Configuration - Arista](https://www.arista.com/en/um-eos/eos-vxlan-configuration)
- [CVP Advanced Change Control - ATD Lab](https://labguides.testdrive.arista.com/2025.1/cloudvision_portal/cvp_adv_cc/)
- [L2 EVPN Services - Arista ATD Lab Guides](https://labguides.testdrive.arista.com/2025.3/data_center/l2_evpn/)
