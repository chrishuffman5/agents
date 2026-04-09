# CLI Reference — IOS-XE and NX-OS Combined

---

## IOS-XE CLI Reference

### Privilege Levels and Modes

| Mode                         | Prompt                   | Description                                  |
|-----------------------------|--------------------------|----------------------------------------------|
| User EXEC                   | `switch>`                | View-only, limited commands (privilege 1)    |
| Privileged EXEC             | `switch#`                | Full show/clear commands (privilege 15)      |
| Global Configuration        | `switch(config)#`        | Device-wide configuration                   |
| Interface Configuration     | `switch(config-if)#`     | Per-interface configuration                  |
| Router Configuration        | `switch(config-router)#` | Routing protocol configuration               |
| Line Configuration          | `switch(config-line)#`   | Console/VTY line configuration               |

### IOS-XE Show Commands — Routing

```
# IP Routing Table
show ip route
show ip route 10.0.0.0 255.0.0.0 longer-prefixes
show ip route vrf TENANT-A
show ip route summary
show ip route bgp                          # BGP-learned routes only
show ip route ospf                         # OSPF-learned routes only
show ip cef 10.0.1.1                       # CEF adjacency lookup
show ip cef detail                         # Full CEF table

# BGP
show bgp summary                           # IOS-XE 17.x preferred
show ip bgp summary
show bgp ipv4 unicast neighbors 10.0.0.1
show bgp ipv4 unicast 10.0.0.0/8
show bgp l2vpn evpn summary                # EVPN BGP summary
show bgp l2vpn evpn route-type 2          # MAC/IP routes

# OSPF
show ip ospf neighbor
show ip ospf database
show ip ospf database router
show ip ospf interface brief
show ip ospf statistics

# IS-IS
show isis neighbors
show isis database
show isis topology
```

### IOS-XE Show Commands — Interfaces

```
# Interface Status
show interfaces
show interfaces GigabitEthernet1/0/1
show interfaces GigabitEthernet1/0/1 counters
show interfaces GigabitEthernet1/0/1 counters errors
show interfaces status                     # All ports: speed/duplex/VLAN
show interfaces trunk                      # Trunk interfaces and allowed VLANs
show interfaces summary                    # Compact traffic summary
show ip interface brief                    # IP address + line/protocol status

# Detailed counters
show interfaces GigabitEthernet1/0/1 | include rate|error|reset
show interfaces counters errors            # Error counters all interfaces
```

### IOS-XE Show Commands — Layer 2

```
# VLANs
show vlan
show vlan brief
show vlan id 100

# Spanning Tree
show spanning-tree
show spanning-tree vlan 100
show spanning-tree vlan 100 detail
show spanning-tree interface GigabitEthernet1/0/1
show spanning-tree summary                 # Per-VLAN STP state summary
show spanning-tree inconsistentports       # Root-guard, BPDU-guard violations

# MAC Address Table
show mac address-table
show mac address-table dynamic
show mac address-table vlan 100
show mac address-table address 0000.1111.2222
show mac address-table count

# CDP
show cdp neighbors
show cdp neighbors detail
show cdp interface

# LLDP
show lldp neighbors
show lldp neighbors detail
```

### IOS-XE Show Commands — Security / ACLs

```
# Access Lists
show access-lists
show access-lists PERMIT-WEB
show ip access-lists PERMIT-WEB

# Port Security
show port-security
show port-security interface GigabitEthernet1/0/1
show port-security address

# DHCP Snooping
show ip dhcp snooping
show ip dhcp snooping binding
show ip dhcp snooping statistics

# Dynamic ARP Inspection
show ip arp inspection
show ip arp inspection vlan 100
show ip arp inspection statistics

# CoPP (Control Plane Policing)
show policy-map control-plane
show policy-map control-plane class class-default
```

### IOS-XE Show Commands — Platform and Hardware

```
# Platform Status
show platform
show platform hardware
show platform resources
show platform software status control-processor brief
show platform software memory
show version

# CPU and Memory
show processes cpu sorted
show processes cpu history
show processes memory sorted
show memory platform

# Environment
show environment all
show environment temperature
show environment power
show environment fan

# TCAM (Ternary Content Addressable Memory)
show platform tcam utilization
show platform resources
show sdm prefer                            # SDM template active

# Interface Hardware
show platform hardware fed switch 1 fwd-asic drops exceptions
show platform hardware fed switch 1 fwd-asic resource utilization
```

### IOS-XE Show Commands — FHRP (HSRP / VRRP)

```
# HSRP
show standby
show standby brief
show standby vlan 100
show standby GigabitEthernet1/0/1 all

# VRRP
show vrrp
show vrrp brief
show vrrp interface GigabitEthernet1/0/1

# GLBP
show glbp
show glbp brief
```

### IOS-XE Show Commands — Wireless (Catalyst 9800)

```
show wireless summary
show ap summary
show ap dot11 5ghz summary
show wireless client summary
show wireless stats ap join summary
show wireless fabric summary
show wireless profile policy summary
```

### IOS-XE Configuration Modes Quick Reference

```
! Enter privilege mode
enable

! Global config
configure terminal

! Save configuration
write memory
copy running-config startup-config

! Interface configuration
interface GigabitEthernet1/0/1
  description Uplink-to-Core
  no switchport
  ip address 10.0.0.1 255.255.255.252
  no shutdown

! VLAN configuration
vlan 100
  name PRODUCTION
vlan 200
  name MANAGEMENT

! SVI (Layer 3 interface for VLAN)
interface Vlan100
  ip address 10.100.0.1 255.255.255.0
  ip helper-address 10.0.0.10
  no shutdown

! Trunk port
interface GigabitEthernet1/0/1
  switchport mode trunk
  switchport trunk allowed vlan 100,200,300
  switchport trunk native vlan 999
  spanning-tree portfast trunk

! Access port
interface GigabitEthernet1/0/2
  switchport mode access
  switchport access vlan 100
  spanning-tree portfast
  spanning-tree bpduguard enable
```

---

## NETCONF / YANG Examples (IOS-XE)

### Enable NETCONF and Connect

```bash
# Enable on device
# netconf-yang
# netconf-yang ssh port 830

# Connect with ncclient (Python)
from ncclient import manager

with manager.connect(
    host="192.168.1.1",
    port=830,
    username="admin",
    password="password",
    hostkey_verify=False
) as m:
    print(m.server_capabilities)
```

### NETCONF: Get Running Interface Config

```xml
<rpc message-id="101" xmlns="urn:ietf:params:xml:ns:netconf:base:1.0">
  <get-config>
    <source><running/></source>
    <filter type="subtree">
      <native xmlns="http://cisco.com/ns/yang/Cisco-IOS-XE-native">
        <interface>
          <GigabitEthernet/>
        </interface>
      </native>
    </filter>
  </get-config>
</rpc>
```

### NETCONF: Configure Interface Description

```xml
<rpc message-id="102" xmlns="urn:ietf:params:xml:ns:netconf:base:1.0">
  <edit-config>
    <target><running/></target>
    <config>
      <native xmlns="http://cisco.com/ns/yang/Cisco-IOS-XE-native">
        <interface>
          <GigabitEthernet>
            <name>1</name>
            <description>Configured by NETCONF</description>
          </GigabitEthernet>
        </interface>
      </native>
    </config>
  </edit-config>
</rpc>
```

### RESTCONF: Get BGP Summary

```bash
curl -s -u admin:password \
  -H "Accept: application/yang-data+json" \
  "https://192.168.1.1/restconf/data/Cisco-IOS-XE-bgp-oper:bgp-state-data/neighbors"
```

### RESTCONF: Configure VLAN

```bash
curl -X PUT \
  -u admin:password \
  -H "Content-Type: application/yang-data+json" \
  -d '{"Cisco-IOS-XE-native:vlan": {"vlan-list": [{"id": 100, "name": "PRODUCTION"}]}}' \
  "https://192.168.1.1/restconf/data/Cisco-IOS-XE-native:native/vlan"
```

---

## Catalyst Center (DNA Center) API Reference

### Authentication

```python
import requests

# Get token
response = requests.post(
    "https://catalyst-center/dna/system/api/v1/auth/token",
    auth=("admin", "password"),
    verify=False
)
token = response.json()["Token"]
headers = {"x-auth-token": token, "Content-Type": "application/json"}
```

### Common API Endpoints

```python
base = "https://catalyst-center/dna/intent/api/v1"

# Get all devices
GET  {base}/network-device
GET  {base}/network-device?managementIpAddress=10.0.0.1

# Get device detail
GET  {base}/network-device/{device_id}

# Get interface list for device
GET  {base}/interface/network-device/{device_id}

# Get site hierarchy
GET  {base}/site

# Get topology
GET  {base}/topology/physical-topology

# Get network health
GET  {base}/network-health

# PnP devices
GET  {base}/onboarding/pnp-device
POST {base}/onboarding/pnp-device/claim
```

---

## NX-OS CLI Reference

### NX-OS Show Commands — Routing

```
# IP Routing
show ip route
show ip route 10.0.0.0/8 longer-prefixes
show ip route vrf TENANT-A
show ip route summary
show ip route bgp
show ip route ospf
show ip cef                                # CEF FIB table

# BGP
show bgp summary
show bgp ipv4 unicast summary
show bgp ipv4 unicast neighbors
show bgp ipv4 unicast 10.0.0.0/24
show bgp l2vpn evpn summary
show bgp l2vpn evpn
show bgp l2vpn evpn route-type 2 0 0000.1111.2222 192.168.1.1
show bgp l2vpn evpn route-type 5

# OSPF
show ip ospf neighbors
show ip ospf database
show ip ospf interface brief
show ip ospf statistics

# Multicast
show ip pim neighbor
show ip mroute
show ip igmp snooping
```

### NX-OS Show Commands — VXLAN / NVE

```
# VXLAN / NVE Status
show nve peers
show nve peers detail
show nve interface nve1
show nve interface nve1 detail
show nve vni
show nve vni 10100 detail

# EVPN
show evpn evi
show evpn evi vni 10100 detail
show evpn mac evi 10100
show evpn mac ip evi 10100

# VXLAN Forwarding
show mac address-table vni 10100
show ip arp suppression-cache detail
show ip arp suppression-cache vlan 100
```

### NX-OS Show Commands — Layer 2

```
# VLANs
show vlan
show vlan brief
show vlan id 100
show vlan-mapping

# Spanning Tree
show spanning-tree
show spanning-tree vlan 100
show spanning-tree summary
show spanning-tree active
show spanning-tree inconsistentports

# MAC Address Table
show mac address-table
show mac address-table dynamic
show mac address-table vlan 100
show mac address-table count

# vPC
show vpc
show vpc brief
show vpc consistency-parameters global
show vpc consistency-parameters interface po10
show vpc peer-keepalive
show vpc role
show vpc orphan-ports
```

### NX-OS Show Commands — Interfaces

```
show interface
show interface brief
show interface Ethernet1/1
show interface Ethernet1/1 counters
show interface Ethernet1/1 counters errors
show interface status
show interface trunk
show ip interface brief
show interface port-channel 10
show lacp neighbor                         # LACP partner info
show port-channel summary
```

### NX-OS Show Commands — Platform / Hardware

```
show version
show module
show module 1                              # Specific line card
show hardware capacity
show system resources
show processes cpu
show processes memory
show environment                           # Power, fans, temperature
show environment power
show environment temperature
show environment fan

# TCAM
show hardware profile
show hardware access-list resource utilization
show system internal access-list resource utilization module 1
```

### NX-OS Checkpoint and Rollback

```
# Create a checkpoint (snapshot)
checkpoint BEFORE-CHANGE

# List checkpoints
show checkpoint summary
show checkpoint BEFORE-CHANGE

# Compare checkpoint with running config
show diff rollback-patch checkpoint BEFORE-CHANGE running-config

# Rollback to checkpoint
rollback running-config checkpoint BEFORE-CHANGE

# Rollback options
rollback running-config checkpoint BEFORE-CHANGE atomic    # All-or-nothing
rollback running-config checkpoint BEFORE-CHANGE best-effort  # Apply what's possible
rollback running-config checkpoint BEFORE-CHANGE stop-at-first-failure

# Delete checkpoint
no checkpoint BEFORE-CHANGE
```

> Maximum 10 user checkpoints per device. Atomic mode is safer for production rollbacks.

### NX-API Examples

```bash
# NX-API CLI (show command)
curl -s -X POST \
  -H "Content-Type: application/json" \
  -u admin:password \
  https://10.0.0.1/ins \
  -d '{"ins_api":{"version":"1.0","type":"cli_show","chunk":"0","sid":"1","input":"show version","output_format":"json"}}'

# NX-API REST: Get VLANs
curl -s -u admin:password \
  -H "Accept: application/json" \
  "https://10.0.0.1/api/mo/sys/bd.json?rsp-subtree=children&rsp-subtree-class=l2BD"

# NX-API REST: Create VLAN 100
curl -X POST \
  -u admin:password \
  -H "Content-Type: application/json" \
  -d '{"l2BD":{"attributes":{"fabEncap":"vlan-100","name":"PRODUCTION","adminSt":"active"}}}' \
  "https://10.0.0.1/api/mo/sys/bd/bd-[vlan-100].json"

# NX-API REST: Get BGP peers
curl -s -u admin:password \
  "https://10.0.0.1/api/mo/sys/bgp/inst/dom-default/peer.json"
```

### NX-OS Configuration Quick Reference

```
! Feature enablement
feature bgp
feature ospf
feature pim
feature vn-segment-vlan-based
feature nv overlay
nv overlay evpn
feature nxapi
feature grpc
feature vpc
feature lacp
feature stp-bfd

! Save configuration
copy running-config startup-config
! or
write memory

! Configuration checkpoint (before changes)
checkpoint PRE-MAINTENANCE

! Configure interface
interface Ethernet1/1
  description Uplink-to-Spine1
  no switchport
  ip address 10.0.0.1/31
  ip ospf UNDERLAY area 0
  no shutdown

! Port-channel (vPC member)
interface port-channel 10
  switchport mode trunk
  switchport trunk allowed vlan 100,200
  vpc 10

interface Ethernet1/5
  channel-group 10 mode active

! VLAN
vlan 100
  name PRODUCTION
  vn-segment 10100

! SVI
interface Vlan100
  vrf member TENANT-A
  ip address 10.100.0.1/24
  fabric forwarding mode anycast-gateway
  no shutdown
```

---

## Cross-Platform Command Comparison

| Task                          | IOS-XE Command                         | NX-OS Command                          |
|------------------------------|----------------------------------------|----------------------------------------|
| Routing table                | `show ip route`                        | `show ip route`                        |
| BGP summary                  | `show bgp summary`                     | `show bgp summary`                     |
| Interface brief              | `show ip interface brief`              | `show ip interface brief`              |
| VLAN list                    | `show vlan brief`                      | `show vlan brief`                      |
| MAC table                    | `show mac address-table`               | `show mac address-table`               |
| Spanning tree                | `show spanning-tree`                   | `show spanning-tree`                   |
| CDP neighbors                | `show cdp neighbors detail`            | `show cdp neighbors detail`            |
| Save config                  | `write memory`                         | `copy run start`                       |
| Running config               | `show running-config`                  | `show running-config`                  |
| VXLAN peers                  | `show nve peers` (on XE)               | `show nve peers`                       |
| Checkpoint                   | N/A (use archive)                      | `checkpoint NAME`                      |
| Rollback                     | `configure replace`                    | `rollback running-config checkpoint`   |
| Process list                 | `show processes`                       | `show processes`                       |
| Hardware resources           | `show platform resources`              | `show hardware capacity`               |

---

## References

- IOS XE Programmability Config Guide 17.17: https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/prog/configuration/1717/b_1717_programmability_cg/
- NETCONF YANG IOS XE 16.x: https://www.cisco.com/c/en/us/support/docs/storage-networking/management/200933-YANG-NETCONF-Configuration-Validation.html
- NX-API REST SDK 10.5(x): https://developer.cisco.com/docs/cisco-nexus-3000-and-9000-series-nx-api-rest-sdk-user-guide-and-api-reference/latest/
- NX-OS Checkpoint/Rollback: https://developer.cisco.com/docs/cisco-nexus-3000-and-9000-series-nx-api-rest-sdk-user-guide-and-api-reference/latest/configuring-checkpoints-and-rollback/
- Catalyst Center API: https://www.cisco.com/c/en/us/products/collateral/cloud-systems-management/dna-center/nb-06-dna-center-data-sheet-cte-en.html
