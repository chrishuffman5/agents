# Operational Best Practices — IOS-XE and NX-OS

---

## IOS-XE Best Practices

### Campus Network Design: SD-Access vs. Traditional

#### Traditional Three-Tier Campus

```
Core (Layer 3)
  └── Distribution (Layer 3 — SVIs, HSRP/VRRP, STP root)
       └── Access (Layer 2 — VLANs, PortFast, BPDU Guard)
```

**When to Use Traditional Design**
- Brownfield environments with existing non-Catalyst-9000 hardware
- Smaller campuses (< 500 users) where SD-Access ROI is limited
- Sites with no Catalyst Center investment
- Environments where SGT policy is not required

**Traditional Design Recommendations**
- Use Layer 3 distribution (routed access is optional but improves convergence)
- Terminate all VLANs at distribution, not core
- Run RSTP (Rapid PVST+) with distribution as STP root
- Deploy HSRP/VRRP at distribution for default gateway redundancy
- Keep STP domain bounded — no VLANs spanning multiple distribution blocks

#### SD-Access Fabric Design

```
Catalyst Center (Management Plane)
  └── LISP Map Server / Map Resolver (Control Plane Node — usually WLC or dedicated)
       ├── Border Nodes (External: connects to non-fabric; Default: connects to Internet)
       └── Edge Nodes (VTEP + SGT enforcement)
            └── Endpoints (users, IoT, servers)
```

**SD-Access Deployment Stages**
1. **Discovery**: Catalyst Center discovers existing infrastructure via SNMP/SSH
2. **Design**: Site hierarchy, IP address pools, AAA settings
3. **Policy**: SSID profiles, SGT group definition, contract definition
4. **Provision**: Push fabric config to edge/border/control nodes
5. **Assurance**: Monitor fabric health, path trace, client 360

**Border Node Types**
| Border Type      | Purpose                                                  |
|-----------------|----------------------------------------------------------|
| Default Border   | Default route for fabric (Internet, cloud egress)        |
| External Border  | Connects to non-fabric L3 domains (WAN, DC)              |
| Internal Border  | Connects to fusion router or another fabric domain       |

---

### Spanning Tree Best Practices (IOS-XE)

#### STP Mode Selection

```
! Rapid PVST+ (recommended for most campus deployments)
spanning-tree mode rapid-pvst

! MST (recommended for very large VLAN counts > 100 VLANs)
spanning-tree mode mst
spanning-tree mst configuration
  name CAMPUS-MST
  revision 1
  instance 1 vlan 1-200
  instance 2 vlan 201-400
```

#### Root Bridge Placement

```
! Set distribution switch as root for all active VLANs
! Primary root (Distribution-1)
spanning-tree vlan 1-1000 priority 4096
spanning-tree vlan 1001-4094 priority 8192

! Secondary root (Distribution-2)
spanning-tree vlan 1-1000 priority 8192
spanning-tree vlan 1001-4094 priority 4096
```

> Never rely on default priority (32768). Explicitly configure root placement.

#### BPDU Guard (Access Ports)

```
! Global PortFast with BPDU Guard (preferred)
spanning-tree portfast default
spanning-tree portfast bpduguard default

! Per-interface (if not set globally)
interface GigabitEthernet1/0/1
  spanning-tree portfast
  spanning-tree bpduguard enable
```

> BPDU Guard: Immediately err-disables port if BPDU received. Appropriate for all end-user access ports.

#### Root Guard

```
! Apply on uplink-facing ports that should NEVER become STP root
interface GigabitEthernet1/0/48
  spanning-tree guard root
```

> Root Guard: Puts port in `root-inconsistent` state if superior BPDU received. Apply on distribution → core uplinks.

#### Loop Guard

```
! Global loop guard (prevents ports from becoming designated if BPDUs stop)
spanning-tree loopguard default

! Per-interface
interface GigabitEthernet1/0/48
  spanning-tree guard loop
```

> Loop Guard: Prevents unidirectional link failures from creating loops. Use on all non-edge ports.

#### STP Verification

```
show spanning-tree summary totals
show spanning-tree vlan 100 detail
show spanning-tree inconsistentports
debug spanning-tree events
```

---

### FHRP — HSRP / VRRP Best Practices

#### HSRP (Hot Standby Router Protocol)

```
! Distribution-1 (Active for even VLANs)
interface Vlan100
  ip address 10.100.0.2 255.255.255.0
  standby version 2
  standby 1 ip 10.100.0.1             ! Virtual IP
  standby 1 priority 110              ! Higher = active
  standby 1 preempt delay minimum 30  ! Wait 30s before preempting
  standby 1 authentication md5 key-string HSRP-KEY
  standby 1 track 1 decrement 20      ! Track uplink; decrement priority if fails

! Distribution-2 (Standby for even VLANs)
interface Vlan100
  ip address 10.100.0.3 255.255.255.0
  standby version 2
  standby 1 ip 10.100.0.1
  standby 1 priority 90
  standby 1 preempt delay minimum 30
```

> Use HSRPv2 — supports IPv6 and millisecond timers. Load-balance by making Dist-1 active for even VLANs and Dist-2 active for odd VLANs.

#### VRRP (Vendor-Neutral Alternative)

```
interface Vlan100
  ip address 10.100.0.2 255.255.255.0
  vrrp 1 ip 10.100.0.1
  vrrp 1 priority 110
  vrrp 1 preempt
  vrrp 1 authentication md5 key-string VRRP-KEY
  vrrp 1 timers advertise 1000        ! 1-second intervals
```

---

### Security Hardening (IOS-XE)

#### Management Plane Hardening

```
! Disable unused services
no service finger
no service pad
no service udp-small-servers
no service tcp-small-servers
no ip bootp server
no ip http server                      ! Use HTTPS only
ip http secure-server
no cdp run                             ! Disable CDP globally if not needed
no lldp run                            ! Disable LLDP globally if not needed

! SSH only (disable Telnet)
line vty 0 15
  transport input ssh
  exec-timeout 10 0
  privilege level 15
  login local
  access-class MGMT-ACL in

! Require strong SSH
ip ssh version 2
ip ssh time-out 60
ip ssh authentication-retries 3
ip ssh dh-min-size 2048

! Management ACL
ip access-list standard MGMT-ACL
  permit 10.0.0.0 0.0.255.255
  deny any log
```

#### AAA Configuration

```
aaa new-model
aaa authentication login default group tacacs+ local
aaa authorization exec default group tacacs+ local if-authenticated
aaa accounting exec default start-stop group tacacs+
aaa accounting commands 15 default start-stop group tacacs+

tacacs server PRIMARY-TACACS
  address ipv4 10.0.0.50
  key SECRET-KEY
  timeout 5

! Fallback to local on TACACS failure
aaa authentication login default group tacacs+ local
username admin privilege 15 secret STRONG-PASSWORD
```

#### Control Plane Policing (CoPP)

```
! IOS XE automatically applies CoPP template on Catalyst 9000 series
! Verify active template:
show policy-map control-plane

! Customize CoPP (example: rate-limit SNMP)
ip access-list extended CoPP-SNMP
  permit udp any any eq 161
  permit udp any any eq 162

class-map match-all COPP-SNMP
  match access-group name CoPP-SNMP

policy-map COPP-POLICY
  class COPP-SNMP
    police rate 100 pps
      conform-action transmit
      exceed-action drop

control-plane
  service-policy input COPP-POLICY
```

#### Additional Hardening

```
! Disable unused ports
interface range GigabitEthernet1/0/25 - 48
  shutdown
  switchport mode access
  switchport access vlan 999          ! Parking VLAN
  description UNUSED-PORT

! DHCP Snooping (trust only uplinks)
ip dhcp snooping
ip dhcp snooping vlan 100,200,300
interface GigabitEthernet1/0/48
  ip dhcp snooping trust

! Dynamic ARP Inspection
ip arp inspection vlan 100,200,300
interface GigabitEthernet1/0/48
  ip arp inspection trust

! IP Source Guard on access ports
interface GigabitEthernet1/0/1
  ip verify source
```

---

### IOS-XE Upgrade Procedures

#### Pre-Upgrade Checklist

```
1. Review release notes for your platform
2. Check Field Notices at https://www.cisco.com/c/en/us/support/web/tools/fn/fnshowcase/index.html
3. Verify current version: show version
4. Check available storage: dir flash: | include bytes
5. Backup configuration: copy running-config tftp://10.0.0.10/backup-$(hostname).cfg
6. Verify redundancy state: show redundancy states
7. Check stack health (stacked switches): show switch
```

#### Software Download and Staging

```
! Method 1: Copy from TFTP
copy tftp://10.0.0.10/cat9k_iosxe.17.18.01.SPA.bin flash:

! Method 2: HTTP/HTTPS (17.x)
copy https://10.0.0.10/images/cat9k_iosxe.17.18.01.SPA.bin flash:

! Verify MD5 hash
verify /md5 flash:cat9k_iosxe.17.18.01.SPA.bin

! Set boot variable
boot system flash:cat9k_iosxe.17.18.01.SPA.bin
```

#### ISSU (In-Service Software Upgrade) — Stacked Switches

```
! Verify ISSU support
show issu state detail

! Initiate ISSU (standby upgrades first, then active)
request platform software package install switch all file flash:cat9k_iosxe.17.18.01.SPA.bin

! Monitor progress
show install log detail
show install summary

! Commit (accept new version)
install commit
```

#### Post-Upgrade Verification

```
show version                           ! Confirm new version running
show logging | include %SYS            ! Check for boot errors
show processes cpu sorted              ! Verify stable CPU
show environment all                   ! Hardware health
show interfaces summary                ! Verify all interfaces up
```

---

## NX-OS Best Practices

### Data Center Fabric Design: Spine-Leaf VXLAN EVPN

#### Spine-Leaf Topology

```
┌──────────────┐         ┌──────────────┐
│   Spine-1    ├─────────┤   Spine-2    │  (Route Reflectors)
│  (N9K-C9508) │         │  (N9K-C9508) │
└──────┬───────┘         └───────┬──────┘
       │  ╲                   ╱  │
       │    ╲               ╱    │
┌──────┴───┐ ┌────────────┐ ┌───┴─────┐
│  Leaf-1  │ │   Leaf-2   │ │  Leaf-3 │  (VTEPs + anycast GW)
│ (vPC pair│ │ standalone │ │ (vPC pair│
│  with L2)│ │  servers)  │ │  with L4)│
└──────────┘ └────────────┘ └─────────┘
```

**Spine Role**
- L3 only — no L2 services, no VLANs, no VXLAN encapsulation
- BGP Route Reflectors for EVPN (iBGP with all leaves)
- Underlay: OSPF or IS-IS (IS-IS preferred for scale and fast convergence)
- No STP — pure IP fabric

**Leaf Role**
- VTEP — VXLAN encapsulation/decapsulation
- L2 services (VLANs) toward servers/endpoints
- Anycast gateway (same SVI IP/MAC across all leaves)
- BGP EVPN peer to spines (via RR)

#### Underlay Design

```
! IS-IS underlay on spine (preferred)
feature isis

router isis UNDERLAY
  net 49.0001.0000.0000.0001.00
  is-type level-2
  address-family ipv4 unicast
    bfd

interface Ethernet1/1
  description Leaf-1-Uplink
  no switchport
  ip address 10.0.0.0/31
  ip router isis UNDERLAY
  isis network point-to-point
  bfd interval 300 min_rx 300 multiplier 3
  no shutdown

interface loopback0
  ip address 10.0.0.10/32
  ip router isis UNDERLAY
```

#### BGP Route Reflector on Spine

```
router bgp 65001
  router-id 10.0.0.10
  log-neighbor-changes
  address-family l2vpn evpn
    retain route-target all

  ! Template for all leaves
  template peer LEAF-TEMPLATE
    remote-as 65001
    update-source loopback0
    address-family l2vpn evpn
      send-community extended
      route-reflector-client
      soft-reconfiguration inbound

  neighbor 10.0.0.1
    inherit peer LEAF-TEMPLATE
    description Leaf-1-A

  neighbor 10.0.0.2
    inherit peer LEAF-TEMPLATE
    description Leaf-1-B
```

---

### vPC (Virtual Port-Channel) Best Practices

#### vPC Domain Configuration

```
! Both vPC peers must have identical vPC domain ID
feature vpc

vpc domain 10
  peer-keepalive destination 192.168.1.2 source 192.168.1.1
    vrf management
  peer-gateway                          ! Proxy ARP for peer's MAC
  layer3 peer-router                    ! Route through peer (avoids orphan port issues)
  auto-recovery reload-delay 300        ! Wait 5 min after reload before auto-recovery
  delay restore 150                     ! 150s delay before restoring vPC ports after reload
  ip arp synchronize                    ! Sync ARP table with peer

! vPC peer-link (recommend 2x 100G port-channel)
interface port-channel 100
  description vPC-PEER-LINK
  switchport mode trunk
  switchport trunk allowed vlan all
  spanning-tree port type network
  vpc peer-link
```

#### vPC Keepalive (Heartbeat)

```
! Use dedicated management VRF for keepalive (not in-band)
vpc domain 10
  peer-keepalive destination 192.168.1.2 source 192.168.1.1 vrf management
  
! Or use dedicated L3 link
vpc domain 10
  peer-keepalive destination 10.0.99.2 source 10.0.99.1
```

> Keepalive uses UDP port 3200 via management. In-band keepalive is not recommended — if peer-link fails, keepalive must be reachable to distinguish peer failure from link failure.

#### vPC Best Practices Summary

| Best Practice                      | Rationale                                                   |
|-----------------------------------|-------------------------------------------------------------|
| Use dedicated management keepalive | Prevents false peer-failure detection                       |
| Enable `peer-gateway`             | Allows routing through peer MAC; prevents ARP issues        |
| Enable `auto-recovery`            | Restores vPC if peer unreachable after reload               |
| Set `delay restore 150`           | Prevents routing black-holes during reload                  |
| Match STP priorities on both peers | vPC peer-switch presents one STP identity                  |
| Use `spanning-tree port type network` on peer-link | Enables RSTP network port behavior    |
| Keep peer-link ≥ 40G total bandwidth | Avoids congestion during split-brain scenarios           |
| Synchronize NTP on both peers     | Consistent log timestamps for troubleshooting               |

#### vPC Troubleshooting

```
show vpc                               ! Overall vPC status
show vpc consistency-parameters global  ! Config consistency check
show vpc orphan-ports                  ! Ports only on one peer
show vpc peer-keepalive                ! Keepalive state
show vpc role                          ! Primary/secondary role

! Common issue: Consistency parameters mismatch
show vpc consistency-parameters interface po10
```

---

### ECMP in VXLAN Fabric

```
! Enable ECMP in underlay (critical for load balancing)
router bgp 65001
  address-family ipv4 unicast
    maximum-paths 64                   ! Up to 64 ECMP paths
    maximum-paths ibgp 64

! Or with OSPF underlay
router ospf UNDERLAY
  maximum-paths 64

! Verify ECMP paths
show ip route 10.0.0.10/32
! Expected: multiple "via" entries with different next-hops
```

#### Flow-Based Load Balancing

NX-OS uses 5-tuple (src IP, dst IP, protocol, src port, dst port) hashing for ECMP. VXLAN adds outer IP headers — ensure outer src UDP port varies per inner flow (enabled by default via entropy).

---

### NX-OS Security Hardening

#### Management Plane

```
! Disable insecure protocols
no feature telnet
feature ssh
ssh key rsa 2048
ssh login-attempts 3

! Management ACL
ip access-list MGMT-ACCESS
  permit tcp 10.0.0.0/24 any eq 22
  permit tcp 10.0.0.0/24 any eq 443
  deny ip any any log

! Apply to management interface
interface mgmt0
  ip address 192.168.0.1/24
  vrf member management
  ip access-group MGMT-ACCESS in

! VTY ACL
line vty
  exec-timeout 10
  session-limit 5
  access-class MGMT-ACCESS in
```

#### AAA and RBAC

```
aaa authentication login default group tacacs+ local
aaa authorization commands default group tacacs+ local
aaa accounting default group tacacs+

tacacs-server host 10.0.0.50
  key SECRET-KEY

! Custom roles
role name NETWORK-OPERATOR
  description Read-only network operators
  rule 1 permit read-write feature show
  rule 2 deny read-write

username operator role NETWORK-OPERATOR password STRONG-PASS
```

#### Control Plane Policing

```
! CoPP is enabled by default on Nexus 9000
! Verify
show policy-map system type control-plane

! Customize CoPP for specific traffic
policy-map type control-plane CUSTOM-COPP
  class copp-class-bgp
    police rate 5600 pps bc 200 ms conform transmit violate drop
  class copp-class-ospf
    police rate 2000 pps bc 200 ms conform transmit violate drop
  class copp-class-snmp
    police rate 100 pps conform transmit violate drop

system policy-map CUSTOM-COPP
```

---

### NX-OS Image Management and Upgrade

#### Pre-Upgrade Procedure

```
! 1. Capture health baseline
show system health
show version
show environment
show vpc
show bgp summary
show nve peers

! 2. Create checkpoint
checkpoint PRE-UPGRADE-$(date)

! 3. Backup config
copy running-config scp://10.0.0.10/backups/$(hostname)-pre-upgrade.cfg

! 4. Check upgrade compatibility
show incompatibility nxos bootflash:nxos64-cs.10.5.5.M.bin

! 5. Check ISSU compatibility
show install all impact nxos bootflash:nxos64-cs.10.5.5.M.bin

! 6. Stage software
copy scp://10.0.0.10/images/nxos64-cs.10.5.5.M.bin bootflash:
```

#### ISSU Upgrade (Non-Disruptive)

```
! Initiate ISSU
install all nxos bootflash:nxos64-cs.10.5.5.M.bin

! Monitor progress (in another session)
show install all status

! If Enhanced ISSU supported (N9K with 16G+ RAM):
install all nxos bootflash:nxos64-cs.10.5.5.M.bin enhanced
```

**ISSU Constraints**
- Requires same or compatible BIOS
- Not supported across major train boundaries (e.g., 9.x → 10.x)
- vPC: Only one peer upgraded at a time (maintain vPC connectivity)
- F-series line cards: May have ISSU limitations

#### Post-Upgrade Verification

```
show version                           ! Confirm new version
show module                            ! All modules online
show vpc                               ! vPC states restored
show bgp summary                       ! BGP sessions re-established
show nve peers                         ! VXLAN peers restored
show spanning-tree summary             ! STP stable
show logging last 100                  ! Check for errors
```

#### vPC Upgrade Sequence

```
# Step 1: Upgrade secondary vPC peer
install all nxos bootflash:nxos64-cs.10.5.5.M.bin   # On secondary

# Step 2: Verify vPC re-establishes after secondary reload
show vpc                               # Wait for "vPC Status: Up"

# Step 3: Upgrade primary vPC peer
install all nxos bootflash:nxos64-cs.10.5.5.M.bin   # On primary

# Step 4: Post-upgrade verification on both peers
show vpc
show bgp summary
show nve peers
```

---

### NX-OS Operational Monitoring

#### Key Metrics to Monitor

| Metric                         | Command                                  | Threshold       |
|-------------------------------|------------------------------------------|-----------------|
| CPU utilization               | `show processes cpu sorted`              | < 70% sustained |
| Memory utilization            | `show system resources`                  | < 80% used      |
| BGP peer state                | `show bgp summary`                       | All Established |
| NVE peer state                | `show nve peers`                         | All Up          |
| Interface errors              | `show interface counters errors`         | Zero or minimal |
| vPC consistency               | `show vpc consistency-parameters global` | All Pass        |
| Spanning tree topology changes| `show spanning-tree detail`              | Low count       |
| CoPP drop statistics          | `show policy-map system type control-plane` | Track trends  |

---

## References

- NX-OS vPC Best Practices: https://www.cisco.com/c/en/us/support/docs/switches/nexus-9000-series-switches/218333-understand-and-configure-nexus-9000-vpc.html
- VXLAN BGP EVPN Design Guide: https://www.cisco.com/c/en/us/td/docs/dcn/whitepapers/cisco-vxlan-bgp-evpn-design-and-implementation-guide.html
- NX-OS Upgrade Guide 10.6(x): https://www.cisco.com/c/en/us/td/docs/dcn/nx-os/nexus9000/106x/upgrade/cisco-nexus-9000-series-nx-os-software-upgrade-and-downgrade-guide-106x/
- IOS XE Device Hardening Guide: https://sec.cloudapps.cisco.com/security/center/resources/IOS_XE_hardening
- SD-Access Design Guide: https://www.cisco.com/c/en/us/td/docs/solutions/CVD/Campus/cisco-sda-design-guide.html
- IOS XE CoPP Config Guide: https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9300/software/release/17-12/configuration_guide/sec/b_1712_sec_9300_cg/configuring_control_plane_policing.html
- vPC Design Best Practices PDF: https://www.cisco.com/c/dam/en/us/td/docs/switches/datacenter/sw/design/vpc_design/vpc_best_practices_design_guide.pdf
