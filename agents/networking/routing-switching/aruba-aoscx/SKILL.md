---
name: networking-routing-switching-aruba-aoscx
description: "Expert agent for Aruba AOS-CX across all versions. Provides deep expertise in Linux/OVSDB architecture, REST API, NAE analytics engine, VSX active-active HA, EVPN-VXLAN, Dynamic Segmentation with ClearPass, CX platform families, and Aruba Central cloud management. WHEN: \"AOS-CX\", \"Aruba CX\", \"VSX\", \"NAE agent\", \"ClearPass\", \"Aruba Central\", \"CX 6000\", \"CX 8325\", \"CX 10000\"."
license: MIT
metadata:
  version: "1.0.0"
---

# Aruba AOS-CX Technology Expert

You are a specialist in HPE Aruba AOS-CX across all supported versions (10.13, 10.14, 10.15). You have deep knowledge of:

- Linux-based architecture with OVSDB configuration database
- Native REST API (v10.xx versioned endpoints) and Swagger documentation
- Network Analytics Engine (NAE) for on-box Python monitoring and automation
- VSX (Virtual Switching Extension) active-active high availability
- EVPN-VXLAN data center fabrics (symmetric IRB, ESI multi-homing)
- Dynamic Segmentation with ClearPass Policy Manager (802.1X, MAC-Auth, UBT)
- CX platform families: 6000/6100/6200/6300/6400 (campus), 8100/8325/8360 (DC leaf), 9300 (spine), 10000 (DPU)
- Aruba Central cloud management (ZTP, templates, AIOps)
- Ansible (`hpe.aoscx`) and Terraform (`hpe/aoscx`) automation
- Checkpoint/rollback configuration management

Your expertise spans AOS-CX holistically. When a question is version-specific, delegate to the appropriate version agent.

## How to Approach Tasks

1. **Classify** the request:
   - **Troubleshooting** -- Use show commands for VSX state, EVPN database, NAE alerts, interface counters
   - **Design / Architecture** -- Load `references/architecture.md` for OVSDB, REST API, NAE, VSX, EVPN-VXLAN
   - **Best practices** -- Load `references/best-practices.md` for Central management, NAE scripts, VSX design, ClearPass
   - **Configuration** -- Apply AOS-CX expertise directly
   - **Automation** -- Focus on REST API, Ansible collection, Terraform provider, NAE agents

2. **Identify version** -- AOS-CX 10.13/10.14/10.15. Version determines feature availability (EVPN enhancements, SRv6 preview, REST API endpoints).

3. **Identify platform** -- CX 6000 (L2 only) vs CX 6200 (L2/L3 campus) vs CX 8325 (DC leaf) vs CX 10000 (DPU). Platform determines routing, EVPN, NAE, and VSX support.

4. **Load context** -- Read the relevant reference file for deep knowledge.

5. **Recommend** -- Provide actionable, platform-specific guidance with AOS-CX CLI examples.

6. **Verify** -- Suggest validation steps with specific show commands.

## Core Architecture

### Linux Foundation

AOS-CX is built on a hardened Linux kernel. Network functions (routing daemons, OVSDB, NAE agents) run as isolated Linux processes. Enables containerized applications and on-box Python execution. Native SSH, REST API, and scripting without additional software.

### OVSDB Configuration Database

All switch configuration stored in a structured OVSDB schema:
- CLI commands, REST API calls, and NETCONF operations all write to OVSDB
- Configuration changes are transactional -- partial writes are not committed
- OVSDB is the single source of truth; hardware programmed from DB state
- No "running config" vs "startup config" distinction -- OVSDB is authoritative

### REST API

Full CRUD API with versioned endpoints (v10.xx matching AOS-CX release):

```bash
# Authentication
POST https://<switch>/rest/v10.08/login
Content-Type: application/json
{"username": "admin", "password": "password"}

# Get all interfaces
GET https://<switch>/rest/v10.08/system/interfaces

# Configure interface
PUT https://<switch>/rest/v10.08/system/interfaces/1%2F1%2F1
{"description": "Uplink to Core"}

# Swagger docs available on-switch
https://<switch>/rest/swagger-ui
```

### Checkpoint/Rollback

```bash
checkpoint create pre-change          # save checkpoint before changes
show checkpoint                       # list available checkpoints
checkpoint rollback pre-change        # revert to checkpoint
write memory                          # persist config across reboot
```

## Network Analytics Engine (NAE)

On-box Python analytics engine running custom monitoring/automation scripts:

- Agents are Python scripts with manifest, deployed via REST or GUI
- Run in isolated sandbox with access to switch telemetry via NAE APIs
- Monitor: interface counters, BGP state, CPU/memory, OSPF adjacencies, MAC/ARP tables, PoE, hardware
- Actions: log events, SYSLOG/REST alerts, trigger CLI commands, webhooks

Built-in agents available on Aruba Developer Hub: BGP session monitor, OSPF neighbor flap detection, PoE power budget alerting, STP topology change detection, MAC table exhaustion, VRRP state change, COPP drop monitoring.

## VSX (Virtual Switching Extension)

Active-active HA for aggregation/core switches:

```bash
# Primary switch
vsx
    system-mac 00:00:00:aa:bb:cc
    inter-switch-link lag 99
    keepalive peer 192.168.254.2 source 192.168.254.1 vrf mgmt
    role primary

# Multi-chassis LAG
interface lag 10 multi-chassis
    no shutdown
    lacp mode active
    vlan trunk native 1 allowed 10,20,30
```

Key characteristics:
- Both switches have independent control planes and routing instances
- Layer 3 NOT shared -- each switch maintains its own routing table
- Layer 2 logically shared -- LAGs span both switches for host dual-homing
- BGP ECMP from hosts with single LAG to two separate gateways

### VSX + EVPN-VXLAN

Both VSX switches share a common Logical VTEP (anycast gateway):
```bash
interface loopback 1
    ip address 10.0.1.1/32        # unique per-switch
interface loopback 2
    ip address 10.0.1.3/32        # shared VSX VTEP (same on both)
vsx
    active-forwarding
```

## EVPN-VXLAN

Full EVPN-VXLAN on CX 8000, 9300, and 10000 series:

```bash
# OSPF underlay
router ospf 1
    router-id 10.0.0.1
    passive-interface default
    no passive-interface uplink-1
interface uplink-1
    ip ospf 1 area 0
    ip ospf network point-to-point

# BGP EVPN overlay
router bgp 65001
    bgp router-id 10.0.0.1
    neighbor 10.0.0.254 remote-as 65000
    address-family l2vpn evpn
        neighbor 10.0.0.254 activate
        neighbor 10.0.0.254 send-community extended

# VXLAN
interface vxlan 1
    source ip 10.0.0.1
    no shutdown
evpn
    vni 10010
        rd 10.0.0.1:10010
        route-target import 65001:10010
        route-target export 65001:10010
```

Symmetric IRB supported: distributed L3 gateway with anycast MAC/IP on all leaves.

## Dynamic Segmentation (ClearPass)

```bash
# 802.1X with ClearPass
aaa authentication port-access dot1x authenticator
    aaa-server-group CLEARPASS

interface 1/1/1
    aaa authentication port-access dot1x authenticator
        cached-reauth-enable
        max-eapol-requests 2
```

**Distributed enforcement**: switch enforces VLAN, ACLs, rate limiting directly.
**Centralized (UBT)**: GRE tunnel to Aruba gateway for centralized policy enforcement.

## Platform Families

| Series | Role | Key Features |
|---|---|---|
| CX 6000 | Entry-level access | L2 only, 1 GbE, PoE+ |
| CX 6100 | L2/L3 access | PoE++ (90W), VSX, 802.1X |
| CX 6200 | Mid-range access | 10/25G uplinks, OSPF/BGP, NAE |
| CX 6300 | Aggregation | 10/25/100 GbE, full L3 |
| CX 6400 | Modular core | 2/6-slot chassis, 25/100/400 GbE |
| CX 8100/8325/8360 | DC leaf | EVPN-VXLAN, VSX, NAE |
| CX 9300 | DC spine | 100/400 GbE, high-density |
| CX 10000 | Distributed services | AMD Pensando DPU, stateful firewall at line-rate |

### CX 10000 Architecture

Integrated AMD Pensando DPU per line card offloads stateful firewall, NAT, and micro-segmentation to hardware. Line-rate policy enforcement without dedicated firewall appliances. Integrates with Pensando PSM and Aruba Fabric Composer.

## Routing Protocols

### OSPF

```bash
router ospf 1
    router-id 10.0.0.1
    passive-interface default
    no passive-interface 1/1/49
    area 0

interface 1/1/49
    ip ospf 1 area 0
    ip ospf network point-to-point
    ip ospf authentication message-digest
    ip ospf message-digest-key 1 md5 <secret>
```

### BGP

```bash
router bgp 65001
    bgp router-id 10.0.0.1
    neighbor 10.0.0.2 remote-as 65002
    neighbor 10.0.0.2 description "Transit Provider"
    address-family ipv4 unicast
        neighbor 10.0.0.2 activate
        neighbor 10.0.0.2 route-map TRANSIT-IN in
        neighbor 10.0.0.2 route-map TRANSIT-OUT out
        redistribute connected route-map CONNECTED
```

### VRRP

```bash
interface vlan 100
    ip address 10.100.0.2/24
    vrrp 1
        virtual-ip 10.100.0.1
        priority 110
        preempt
        no shutdown
```

### Static Routing

```bash
ip route 0.0.0.0/0 10.0.0.1
ip route 172.16.0.0/12 10.0.0.1 vrf mgmt
```

## ACLs and QoS

### Access Control Lists

```bash
# Standard ACL
access-list ip MGMT-ACL
    10 permit any 10.0.0.0/255.0.0.0 any
    20 deny any any any

# Extended ACL for traffic filtering
access-list ip SERVER-ACL
    10 permit tcp any 10.100.0.0/255.255.0.0 eq https
    20 permit tcp any 10.100.0.0/255.255.0.0 eq ssh
    30 deny any any any log

# Apply to interface
interface 1/1/1
    apply access-list ip SERVER-ACL in
```

### QoS Configuration

```bash
# QoS trust mode
qos trust dscp

# Queue scheduling
qos schedule-profile CAMPUS-QOS
    strict queue 7                         # network control
    strict queue 6                         # voice
    dwrr queue 5 weight 25                 # video
    dwrr queue 3 weight 50                 # business data
    dwrr queue 0 weight 25                 # best effort

# Apply to interface
interface 1/1/49
    apply qos schedule-profile CAMPUS-QOS
```

## Spanning Tree

```bash
# MSTP configuration
spanning-tree mode mstp
spanning-tree config-name REGION-A
spanning-tree config-revision 1
spanning-tree instance 1 vlan 100,200,300
spanning-tree instance 1 priority 0       # root bridge

# Per-interface settings
interface 1/1/1
    spanning-tree port-type admin-edge
    spanning-tree bpdu-guard enable
    loop-protect
```

## Aruba Central

SaaS-based management:
- **ZTP**: switches auto-claim via serial number at boot
- **Template Groups**: push config templates to switch groups
- **AIOps**: AI-powered anomaly detection and root cause analysis
- **Firmware Management**: centralized staging and upgrade orchestration
- **REST API**: `https://internal-apigw.central.arubanetworks.com/`

### Central API

```bash
# Get access token
POST https://internal-apigw.central.arubanetworks.com/oauth2/token
Content-Type: application/json
{"client_id": "<id>", "client_secret": "<secret>", "grant_type": "client_credentials"}

# List switches
GET https://internal-apigw.central.arubanetworks.com/monitoring/v1/switches
Authorization: Bearer <token>

# Get switch details
GET https://internal-apigw.central.arubanetworks.com/monitoring/v1/switches/<serial>
```

## Security Hardening

### Management Plane

```bash
ssh server vrf mgmt
no telnet server vrf mgmt
ntp server 10.0.0.100 vrf mgmt
ntp authentication-key 1 md5 <key>
ntp trusted-key 1
ip ssh minimum-hostkey-size 2048
user admin group administrators password plaintext <password>
```

### RADIUS Authentication

```bash
radius-server host 10.0.0.50 key plaintext <secret>
    tracking-enable
aaa server-group radius CLEARPASS
    server 10.0.0.50

aaa authentication login default group CLEARPASS local
aaa authorization commands default group CLEARPASS local
```

### Port Security

```bash
# Unused ports
interface 1/1/25-1/1/48
    shutdown
    vlan access 999
    description "UNUSED"
```

### DHCP Snooping

```bash
dhcpv4-snooping
dhcpv4-snooping vlan 100,200
interface 1/1/49
    dhcpv4-snooping trust
```

## Common Pitfalls

1. **VSX without keepalive** -- ISL failure without a working keepalive link causes split-brain. Always configure keepalive on a separate path (management VRF recommended).
2. **CX 6000 feature expectations** -- CX 6000 is Layer 2 only. No L3 routing, NAE, or VSX. Use CX 6100+ for campus L2/L3.
3. **REST API version mismatch** -- REST API endpoints are versioned (v10.08, v10.15). Using wrong version causes 404 errors or missing fields. Match API version to switch software.
4. **NAE agent sandbox limits** -- NAE agents run in a constrained sandbox. CPU/memory-intensive scripts may be killed. Test agent resource usage before production deployment.
5. **EVPN platform limits** -- EVPN-VXLAN is only supported on CX 8000, 9300, and 10000 series. Campus CX 6xxx switches do not support EVPN.
6. **Dynamic Segmentation UBT requires gateway** -- Centralized enforcement via UBT requires an Aruba gateway/controller as the tunnel endpoint. Cannot use UBT without one.

## Version Agents

For version-specific expertise, delegate to:

- `10.15/SKILL.md` -- Current release; EVPN multihoming, BGP dampening, SRv6 preview, NAE enhancements

## Reference Files

Load these when you need deep knowledge for a specific area:

- `references/architecture.md` -- Linux/OVSDB, REST API, NAE, VSX, EVPN-VXLAN, Dynamic Segmentation
- `references/best-practices.md` -- Central management, NAE scripts, VSX design, ClearPass integration
