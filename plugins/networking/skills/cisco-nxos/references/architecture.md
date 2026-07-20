# NX-OS Architecture Reference

## Modular Architecture

NX-OS runs on a microkernel with processes communicating via internal message bus:

Key processes: `sysmgr` (lifecycle), `bgp`, `ospf`, `l2fm` (L2 forwarding), `rib`, `fib_mgr`, `stp`, `nve` (VXLAN), `nxapi`, `grpc`

Non-Stop Forwarding: hardware continues forwarding when control processes restart. Graceful Restart maintains neighbor adjacencies during supervisor failover.

## VXLAN/EVPN Configuration Pattern

```
feature bgp
feature nv overlay
feature vn-segment-vlan-based
nv overlay evpn

fabric forwarding anycast-gateway-mac 0001.0001.0001

vlan 100
  vn-segment 10100

vrf context TENANT-A
  vni 50001
  rd auto
  address-family ipv4 unicast
    route-target both auto evpn

interface nve1
  no shutdown
  host-reachability protocol bgp
  source-interface loopback0
  member vni 10100
    ingress-replication protocol bgp
  member vni 50001 associate-vrf

interface Vlan100
  vrf member TENANT-A
  ip address 10.100.0.1/24
  fabric forwarding mode anycast-gateway
  ip arp suppression

router bgp 65001
  address-family l2vpn evpn
    advertise-pip
  neighbor 10.0.0.100
    remote-as 65001
    update-source loopback0
    address-family l2vpn evpn
      send-community extended
```

### Symmetric IRB
- Both ingress and egress VTEPs route
- Per-VRF L3 VNI carries inter-subnet traffic
- Avoids ARP suppression complexity of asymmetric IRB

### Multi-Site VXLAN EVPN
- BGP EVPN multi-site Border Gateway (BGW) connects fabrics
- Each site has local RRs; BGWs peer between sites
- DF election handles BUM for multi-homed segments

## ACI Mode vs Standalone

Standalone: CLI/NX-API managed, full protocol support
ACI: APIC-managed via OPFlex, policy model (Tenants > App Profiles > EPGs > Contracts)
Mode switch requires OS reinstall (destructive)

## NX-API

Three interfaces: NX-API CLI (HTTP POST with CLI), NX-API REST (DME object model), NX-API JSON-RPC

Enable: `feature nxapi`, `nxapi https port 443`, `nxapi sandbox` (dev UI)

## Nexus Dashboard Services

NDFC: fabric provisioning (Day-0 discovery, Day-1 VLAN/VNI/VRF, Day-2 compliance)
NDI: telemetry analytics, anomaly detection
NDO: multi-site policy orchestration

## Streaming Telemetry

```
feature grpc
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

Paths: `sys/intf`, `sys/bgp`, `sys/nve`, `sys/evpn`, `sys/ch` (chassis hardware)

## VDCs (Nexus 7000/7700 Only)

VDCs partition a physical chassis into multiple logical devices. Nexus 9000 does not support VDCs; uses VRF and VXLAN for multi-tenancy instead.

## FEX (Fabric Extender)

FEX extends parent switch to satellite ToR units. FEX ports appear as local ports. No local switching on FEX. Supported on Nexus 5600/7000 and select 9300 models.
