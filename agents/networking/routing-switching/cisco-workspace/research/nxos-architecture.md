# Cisco NX-OS Architecture — Technical Deep Dive

## Overview

NX-OS is Cisco's data center-optimized operating system, purpose-built for the Nexus switching platform. Unlike IOS XE's campus heritage, NX-OS was designed from inception for high-density, high-throughput data center environments with emphasis on multi-tenancy, non-stop forwarding, and programmability.

---

## Modular Architecture

NX-OS runs on a microkernel-based OS with all major functions implemented as separate processes that communicate via an internal message bus. This design enables process restarts without impacting forwarding.

### Core Components

```
┌─────────────────────────────────────────────────────────┐
│                   Management Plane                       │
│  CLI / SSH / NX-API / NETCONF / RESTCONF / gNMI         │
├─────────────────────────────────────────────────────────┤
│                   Control Plane                          │
│  BGP  OSPF  ISIS  PIM  STP  LACP  VRRP  HSRP  IGMP     │
├─────────────────────────────────────────────────────────┤
│                   System Software Bus                    │
│         (Sysmgr, Syslog, Error Manager, AAA)            │
├──────────────────────────┬──────────────────────────────┤
│   Forwarding Manager     │   Hardware Abstraction Layer  │
│   (FIB programming)      │   (HAL / HDL)                 │
├──────────────────────────┴──────────────────────────────┘
│              ASIC / NPU (Data Plane)                     │
│         Cloud Scale ASIC (Nexus 9000)                    │
└─────────────────────────────────────────────────────────┘
```

### Key Processes

| Process       | Function                                              |
|--------------|-------------------------------------------------------|
| `sysmgr`      | Process lifecycle manager (restart/monitor processes) |
| `bgp`         | BGP routing process                                   |
| `ospf`        | OSPF routing process                                  |
| `l2fm`        | Layer 2 Forwarding Manager (MAC tables)               |
| `rib`         | Routing Information Base                              |
| `fib_mgr`     | FIB programming to hardware                           |
| `stp`         | Spanning Tree Protocol                                |
| `nve`         | Network Virtualization Edge (VXLAN)                   |
| `mrib`        | Multicast Routing Information Base                    |
| `nxapi`       | NX-API server process                                 |
| `grpc`        | gRPC/gNMI server for telemetry                        |

### Non-Stop Forwarding (NSF) and Graceful Restart

- Hardware continues to forward traffic when control processes restart
- Graceful Restart (GR) for BGP, OSPF, ISIS maintains neighbor adjacencies during supervisor failover
- Stateful Switchover (SSO): active → standby supervisor failover in < 30 seconds with checkpoint sync

---

## Virtual Device Contexts (VDCs)

VDCs allow a single physical Nexus 7000/7700 chassis to be partitioned into multiple logical devices, each with its own:
- Separate CLI context and configuration
- Independent routing and switching instances
- Dedicated management interface
- Resource allocation (interfaces, memory, CPU)

### VDC Support

| Platform    | VDC Support       | Max VDCs  |
|------------|-------------------|-----------|
| Nexus 7000  | Yes (M/F2 modules) | 4 per chassis |
| Nexus 7700  | Yes               | 4 per chassis |
| Nexus 9000  | No (standalone)   | N/A       |
| Nexus 5600  | No                | N/A       |

> Note: Nexus 9000 does not support VDCs but achieves multi-tenancy via VRF and VXLAN.

### VDC Configuration (Nexus 7000)

```
! Create a VDC
vdc TENANT-A
  allocate interface Ethernet2/1-8
  limit-resource vlan minimum 128 maximum 1024
  limit-resource vrf minimum 2 maximum 32
  limit-resource monitor-session minimum 0 maximum 2

! Switch to VDC context
switchto vdc TENANT-A

! Return to default VDC
switchback
```

---

## VXLAN / EVPN Architecture

### Why VXLAN?

Traditional 802.1Q VLANs are limited to 4094 segments. VXLAN uses a 24-bit VNI, supporting 16 million virtual networks. It encapsulates Layer 2 frames in UDP/IP, enabling Layer 2 extension over Layer 3 fabrics.

### BGP EVPN Control Plane

BGP EVPN (RFC 7432) is the control plane for VXLAN, replacing flood-and-learn with distributed, signaled MAC/IP learning.

#### EVPN Route Types

| Type | Name                    | Purpose                                          |
|------|-------------------------|--------------------------------------------------|
| 1    | Ethernet Auto-Discovery | Multi-homing fast convergence                    |
| 2    | MAC/IP Advertisement    | Advertise MAC + IP binding (host routes)         |
| 3    | Inclusive Multicast     | BUM traffic (Broadcast/Unknown/Multicast) setup  |
| 4    | Ethernet Segment        | Multi-homing segment advertisement               |
| 5    | IP Prefix Route         | L3 prefix advertisement (Type-5 = inter-subnet)  |

#### BGP EVPN Configuration (Nexus 9000)

```
! Enable required features
feature bgp
feature nv overlay
feature vn-segment-vlan-based
nv overlay evpn

! Underlay (OSPF or IS-IS)
router ospf UNDERLAY
  router-id 10.0.0.1

interface loopback0
  ip address 10.0.0.1/32
  ip ospf UNDERLAY area 0

! BGP EVPN
router bgp 65001
  router-id 10.0.0.1
  address-family l2vpn evpn
    advertise-pip

  neighbor 10.0.0.100  ! Route Reflector
    remote-as 65001
    update-source loopback0
    address-family l2vpn evpn
      send-community extended
      route-reflector-client  ! On RR only
```

### VXLAN Data Plane

```
! Create VLAN-to-VNI mapping
vlan 100
  vn-segment 10100

vlan 200
  vn-segment 10200

! L3 VNI for VRF routing
vrf context TENANT-A
  vni 50001
  rd auto
  address-family ipv4 unicast
    route-target both auto evpn

! NVE (Network Virtualization Edge) Interface
interface nve1
  no shutdown
  host-reachability protocol bgp
  source-interface loopback0
  member vni 10100
    ingress-replication protocol bgp
  member vni 10200
    ingress-replication protocol bgp
  member vni 50001 associate-vrf  ! L3 VNI
```

### Symmetric IRB (Integrated Routing and Bridging)

Symmetric IRB is the recommended forwarding model for VXLAN EVPN:
- Both ingress and egress VTEPs perform routing (symmetric L3 operation)
- Uses per-VRF L3 VNI to carry routed traffic between VTEPs
- Avoids ARP suppression complexity of asymmetric IRB

```
! Anycast gateway (same IP/MAC on all leaf switches)
fabric forwarding anycast-gateway-mac 0001.0001.0001

interface Vlan100
  vrf member TENANT-A
  ip address 10.100.0.1/24
  fabric forwarding mode anycast-gateway
  ip arp suppression  ! EVPN-based ARP suppression
```

### Multi-Site VXLAN EVPN

- Connects multiple VXLAN fabric sites via a BGP EVPN multi-site Border Gateway (BGW)
- Each site has local Route Reflectors; BGWs peer between sites
- Supports stretched VLANs and inter-site L3 routing
- DF (Designated Forwarder) election handles BUM traffic for multi-homed segments

---

## ACI Mode vs. Standalone NX-OS

### Standalone NX-OS

- Standard CLI-managed Nexus OS
- Supports all protocols: BGP, OSPF, VXLAN/EVPN, vPC, etc.
- Management via CLI, NX-API, NETCONF, gNMI, Nexus Dashboard (DCNM)
- Full operator control of protocol behavior and policy

### ACI Mode (Application Centric Infrastructure)

- Nexus 9000 series only (specific APIC-compatible SKUs)
- APIC (Application Policy Infrastructure Controller) manages entire fabric
- Uses OPFlex protocol (southbound from APIC to leaf/spine)
- Policy model: Tenants > Application Profiles > EPGs > Contracts
- **Cannot run standalone NX-OS features** when in ACI mode — requires OS reinstall to switch modes

### Switching Between ACI and NX-OS Mode

```
! On Nexus 9000: to switch to standalone (destructive — erases config)
write erase
reload

! Boot with NX-OS image (not ACI image)
! ACI image: aci-n9000-dk9.X.X.X.bin
! NX-OS image: nxos64-cs.X.X.X.bin
```

---

## NX-API

NX-API provides programmatic access to NX-OS via HTTP/HTTPS, supporting three interfaces:

### 1. NX-API CLI

Sends NX-OS CLI commands as HTTP POST requests; returns output in JSON, XML, or text.

```bash
curl -s -X POST \
  -H "Content-Type: application/json" \
  -u admin:password \
  https://10.0.0.1/ins \
  -d '{
    "ins_api": {
      "version": "1.0",
      "type": "cli_show",
      "chunk": "0",
      "sid": "1",
      "input": "show interface brief",
      "output_format": "json"
    }
  }'
```

### 2. NX-API REST (Object Model)

REST API operating on the NX-OS DME (Data Management Engine) object model.

```bash
# Get all VLANs
GET https://10.0.0.1/api/mo/sys/bd.json?rsp-subtree=children

# Create VLAN 100
POST https://10.0.0.1/api/mo/sys/bd.json
{
  "bdEntity": {
    "children": [{"l2BD": {"attributes": {"fabEncap": "vlan-100", "name": "PROD"}}}]
  }
}
```

### 3. NX-API JSON-RPC

JSON-RPC 2.0 compliant interface for batch command execution.

```json
POST https://10.0.0.1/ins
{
  "jsonrpc": "2.0",
  "method": "cli",
  "params": {
    "cmd": "show version",
    "version": 1.2
  },
  "id": 1
}
```

### Enable NX-API

```
! Enable NX-API
feature nxapi

! Configure HTTP/HTTPS
nxapi http port 80
nxapi https port 443
nxapi ssl protocols TLSv1.2

! Sandbox (developer UI at https://device/#!/)
nxapi sandbox
```

---

## Nexus Dashboard (Formerly DCNM)

Nexus Dashboard is the centralized management, orchestration, and analytics platform for NX-OS fabrics.

### Services on Nexus Dashboard

| Service                       | Function                                            |
|------------------------------|-----------------------------------------------------|
| Nexus Dashboard Fabric Controller (NDFC) | Fabric provisioning, VXLAN EVPN automation |
| Nexus Dashboard Insights (NDI) | Telemetry analytics, anomaly detection            |
| Nexus Dashboard Orchestrator (NDO) | Multi-site/multi-fabric policy orchestration  |

### NDFC (Formerly DCNM)

- Deploys and manages VXLAN EVPN fabrics end-to-end
- Day-0: fabric discovery, switch registration, underlay provisioning
- Day-1: VLAN/VNI/VRF creation, BGP EVPN policy
- Day-2: Change management, compliance, backup/restore

---

## Streaming Telemetry (gRPC / gNMI)

### Enable gRPC Telemetry

```
! Enable gRPC
feature grpc
grpc port 50051

! Configure dial-out telemetry
telemetry
  destination-group 100
    ip address 10.0.0.50 port 50051 protocol gRPC encoding GPB
  sensor-group 200
    path sys/intf depth unbounded
    path sys/bgp depth unbounded
  subscription 300
    dst-grp 100
    snsr-grp 200 sample-interval 30000
```

### Telemetry Data Sources

| Path                           | Data                            |
|--------------------------------|---------------------------------|
| `sys/intf`                     | Interface statistics            |
| `sys/bgp`                      | BGP peer state and prefixes     |
| `sys/nve`                      | VXLAN NVE interface state       |
| `sys/evpn`                     | EVPN table data                 |
| `sys/eps`                      | BGP EVPN routes                 |
| `sys/ch`                       | Chassis hardware (PSU, fans)    |

### gNMI Support

```
! Enable gNMI
feature gnmi
gnmi port 9339
```

---

## OPFlex (ACI Mode Only)

OPFlex is the southbound protocol between the APIC and NX-OS leaf/spine switches in ACI mode.

- Cisco/IETF standards-based policy protocol (RFC-like, open standard)
- Carries intent-based policy (EPGs, Contracts, Filters) from APIC to switches
- Replaces traditional CLI-driven configuration in ACI deployments
- Transport: TCP over in-band or out-of-band management

---

## Fabric Extender (FEX)

FEX (Fabric Extender) technology extends a parent Nexus switch to satellite rack-top units.

### Supported Configurations

| Parent Switch   | FEX Models                    | Max FEX per Switch |
|----------------|-------------------------------|--------------------|
| Nexus 5600      | 2232PP, 2248PQ, 2348TQ, 2232TM | 24                |
| Nexus 7000      | 2232PP, 2248TQ, 2348TQ         | 24                |
| Nexus 9300 (select) | 2300 series                | 8                 |

### FEX Operation

- FEX ports appear as local ports on the parent switch
- All traffic forwarded to parent for switching/routing decisions
- No local switching on FEX — pure satellite
- Managed as extension of parent switch (no separate management)

```
! Associate FEX to parent uplink
interface Ethernet1/1
  switchport mode fex-fabric
  fex associate 101

fex 101
  pinning max-links 1
  description FEX101-TOR
```

---

## References

- VXLAN BGP EVPN Design Guide: https://www.cisco.com/c/en/us/td/docs/dcn/whitepapers/cisco-vxlan-bgp-evpn-design-and-implementation-guide.html
- NX-OS VXLAN Config Guide 10.6(x): https://www.cisco.com/c/en/us/td/docs/dcn/nx-os/nexus9000/106x/configuration/vxlan/cisco-nexus-9000-series-nx-os-vxlan-configuration-guide-release-106x/
- NX-API REST SDK 10.5(x): https://developer.cisco.com/docs/cisco-nexus-3000-and-9000-series-nx-api-rest-sdk-user-guide-and-api-reference/latest/
- Nexus 9000 vPC Best Practices: https://www.cisco.com/c/en/us/support/docs/switches/nexus-9000-series-switches/218333-understand-and-configure-nexus-9000-vpc.html
- Telemetry VXLAN EVPN: https://pubhub.devnetcloud.com/media/nx-os/docs/telemetryvxlan/Telemetry-Deployment-VXLAN-EVPN.pdf
