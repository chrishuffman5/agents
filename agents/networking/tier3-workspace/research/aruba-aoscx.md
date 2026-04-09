# Aruba AOS-CX Deep Dive

## Overview

Aruba AOS-CX is HPE Aruba's modern, cloud-native network operating system for campus and data center switching. It was purpose-built from the ground up (not evolved from legacy ProCurve or ArubaOS) with a Linux foundation, a structured database-driven configuration model (OVSDB), and built-in programmability via a native REST API and on-box Python automation engine.

Current production version: **AOS-CX 10.15** (released 2025). AOS-CX runs on the CX switch portfolio from entry-level access (CX 6000) to high-performance data center (CX 10000).

---

## Architecture

### Linux Foundation

AOS-CX is built on a hardened Linux kernel:
- Full Linux user space provides a stable base for modern software practices
- Each network function (routing daemons, OVSDB, NAE agents) runs as isolated Linux processes
- Enables containerized applications and on-box Python execution
- Provides native SSH, REST API, and scripting support without additional software

### OVSDB Configuration Database

AOS-CX uses **OVSDB (Open vSwitch Database Management Protocol)** as its internal configuration and state database:
- All switch configuration is stored in a structured database schema
- CLI commands, REST API calls, and NETCONF operations all write to OVSDB
- Configuration changes are transactional — partial writes are not committed
- OVSDB schema is the single source of truth; hardware is programmed from the DB state
- Enables powerful state queries: e.g., query all interfaces with a specific VLAN configured

This database-driven approach makes AOS-CX fundamentally different from traditional command-line-configured switches. There is no "running config" vs "startup config" distinction — the OVSDB state is always the authoritative configuration.

### REST API

AOS-CX has a full-featured native REST API (v1 and v10.xx versioned endpoints):

```bash
# Authentication
POST https://<switch>/rest/v10.08/login
Content-Type: application/json
{"username": "admin", "password": "password"}

# Get all interfaces
GET https://<switch>/rest/v10.08/system/interfaces

# Configure interface description
PUT https://<switch>/rest/v10.08/system/interfaces/1%2F1%2F1
Content-Type: application/json
{"description": "Uplink to Core"}

# Get BGP neighbors
GET https://<switch>/rest/v10.08/system/vrfs/default/bgp_routers/65001/bgp_neighbors
```

The REST API supports full CRUD operations for all configuration objects. API documentation is available on-switch at `https://<switch>/rest/swagger-ui`.

**Ansible integration**: HPE provides an official Ansible collection (`hpe.aoscx`) that wraps REST API calls for automation playbooks.

**Terraform provider**: `hpe/aoscx` Terraform provider available for infrastructure-as-code deployments.

---

## Network Analytics Engine (NAE)

NAE is one of AOS-CX's most distinctive features — an on-box Python analytics engine that runs custom monitoring and automation scripts directly on the switch.

### Architecture

- NAE agents are Python scripts packaged with a manifest and deployed to the switch
- Each agent runs in an isolated sandbox with access to switch telemetry via NAE APIs
- Agents can monitor: interface counters, BGP session state, CPU/memory, OSPF adjacencies, MAC/ARP tables, PoE status, hardware health
- Agents can take **actions**: log events, send SYSLOG/REST alerts, trigger CLI commands, send webhooks to external systems

### Agent Lifecycle

1. **Develop**: Write Python script using NAE framework APIs
2. **Upload**: Push script to switch via REST or GUI
3. **Instantiate**: Create an agent instance with configurable parameters
4. **Monitor**: Agent runs continuously, raising alerts when conditions are met

### Example NAE Agent (Interface Utilization Monitor)

```python
import re
from cts import alerter

Manifest = {
    'Name': 'interface_utilization_monitor',
    'Description': 'Alert when interface utilization exceeds threshold',
    'Version': '1.0',
    'Parameters': [
        {'Name': 'threshold', 'Type': 'integer', 'Default': 80}
    ]
}

class Agent(NAEAgent):
    def __init__(self):
        uri = '/rest/v10.08/system/interfaces/{}?attributes=statistics'
        m1 = self.monitor(uri, 'Interface TX utilization', period=30)
        self.rule = Rule('High utilization rule')
        self.rule.condition('percent(sum({m1})) >= {}', [m1], params=[self.params['threshold']])
        self.rule.action(self.high_utilization_action)

    def high_utilization_action(self, event):
        ActionSyslog('Interface utilization exceeded threshold: {}'.format(event))
        ActionCLI('show interface {}'.format(event.interface))
```

### Built-in NAE Agents

HPE provides a library of pre-built NAE agents on the Aruba Developer Hub:
- BGP session state monitor
- OSPF neighbor flap detection
- PoE power budget alerting
- STP topology change detection
- MAC address table exhaustion
- Interface error rate monitoring
- VRRP state change alerting
- COPP (Control Plane Policing) drop monitoring

---

## VSX (Virtual Switching Extension)

VSX is Aruba's active-active high availability solution for aggregation and core switches, replacing legacy MLAG and stacking architectures.

### Architecture

VSX creates a logical pair from two physical switches:
- **Primary switch**: holds the VSX configuration; synchronizes state to secondary
- **Secondary switch**: operates independently but shares logical identity with primary
- **ISL (Inter-Switch Link)**: a high-speed link between VSX peers for control plane synchronization and forwarding path redundancy
- **Keepalive link**: an out-of-band link (often management interface) for peer health monitoring

**Key difference from traditional MLAG:**
- Both VSX switches have independent control planes and routing instances
- Layer 3 is NOT shared — each switch maintains its own routing table
- Layer 2 is logically shared — LAGs span both switches for host dual-homing
- This allows BGP ECMP from hosts with a single LAG to two physically separate gateways

### VSX Configuration

```bash
# On Primary:
vsx
    system-mac 00:00:00:aa:bb:cc
    inter-switch-link lag 99
    keepalive peer 192.168.254.2 source 192.168.254.1 vrf mgmt
    role primary
    
# LAG with VSX
interface lag 10 multi-chassis
    no shutdown
    description "Dual-homed server LAG"
    lacp mode active
    vlan trunk native 1 allowed 10,20,30
```

### VSX + EVPN-VXLAN

VSX pairs integrate with EVPN-VXLAN for active-active data center fabric access:
- Both VSX switches share a common **Logical VTEP** (anycast gateway IP/MAC)
- The logical VTEP IP is distributed via BGP EVPN to all fabric VTEPs
- Traffic destined for the VSX pair can be delivered to either switch
- ESI (Ethernet Segment Identifier) multi-homing is used for EVPN-aware host attachment

```bash
# Logical VTEP for VSX EVPN
interface loopback 1
    ip address 10.0.1.1/32     # unique per-switch
interface loopback 2
    ip address 10.0.1.3/32     # shared VSX VTEP (same on both peers)

vsx
    active-forwarding
```

---

## EVPN-VXLAN for Data Center

AOS-CX provides full EVPN-VXLAN support on CX 8000 and 10000 series switches.

### Underlay (BGP or OSPF)

```bash
# OSPF underlay
router ospf 1
    router-id 10.0.0.1
    passive-interface default
    no passive-interface uplink-1
interface uplink-1
    ip ospf 1 area 0
    ip ospf network point-to-point
```

### EVPN Overlay (MP-BGP)

```bash
# BGP EVPN overlay
router bgp 65001
    bgp router-id 10.0.0.1
    neighbor 10.0.0.254 remote-as 65000
    address-family l2vpn evpn
        neighbor 10.0.0.254 activate
        neighbor 10.0.0.254 send-community extended

# VXLAN interface
interface vxlan 1
    source ip 10.0.0.1
    no shutdown

# VNI mapping
evpn
    vni 10010
        rd 10.0.0.1:10010
        route-target import 65001:10010
        route-target export 65001:10010
```

### Symmetric IRB (Distributed L3 Gateway)

AOS-CX supports symmetric IRB for distributed L3 forwarding:
- Each leaf has an IRB (Integrated Routing and Bridging) interface per VNI
- Anycast gateway MAC/IP shared across all leaves
- Traffic routed locally at each leaf without hair-pinning to a central gateway

---

## Dynamic Segmentation (ClearPass Integration)

Dynamic Segmentation is Aruba's policy-driven access control mechanism integrating AOS-CX with ClearPass Policy Manager (CPPM).

### How It Works

1. Device connects to CX switch port
2. Switch sends 802.1X or MAC-Auth request to ClearPass
3. ClearPass authenticates device (LDAP, AD, certificate, profiling)
4. ClearPass returns a role assignment (VLAN, QoS, ACL, or UBT tunnel)
5. Switch enforces the policy dynamically

### Enforcement Modes

**Distributed (local enforcement):**
- Switch enforces VLAN assignment, ACLs, or rate limiting directly
- Simple, no overlay tunnel required
- Best for wired access deployments

**Centralized (User-Based Tunneling / UBT):**
- Switch creates a GRE tunnel to an Aruba gateway/controller
- All user traffic is tunneled to the gateway for centralized policy enforcement
- Supports VPN-like segmentation without changing IP addressing
- Best for converged wired+wireless environments

```bash
# 802.1X with ClearPass
aaa authentication port-access dot1x authenticator
    aaa-server-group CLEARPASS

interface 1/1/1
    aaa authentication port-access dot1x authenticator
        cached-reauth-enable
        max-eapol-requests 2
```

---

## Aruba Central Cloud Management

Aruba Central provides SaaS-based management for AOS-CX switches:

**Capabilities:**
- **Zero-Touch Provisioning (ZTP)**: switches claim into Central organization at boot using serial number
- **Template Groups**: push configuration templates to groups of switches
- **Topology Visualization**: automatic discovery and mapping of the network
- **AIOps**: AI-powered anomaly detection and root cause analysis
- **DX (Dynamic Authorization)**: push ClearPass policies via Central
- **Firmware Management**: centralized firmware staging and upgrade orchestration
- **Audit Logs**: change tracking for compliance

**Central API:**
Central exposes a REST API for third-party integration and automation:
```bash
POST https://internal-apigw.central.arubanetworks.com/oauth2/token
GET  https://internal-apigw.central.arubanetworks.com/monitoring/v1/switches
```

---

## Platform Families

### CX 6000 Series (Entry-Level Access)

- **CX 6000-12G / 24G / 48G**: Small/medium branch access switches
- Layer 2 only (no L3 routing)
- 1 GbE access ports with PoE+ options
- Managed via Aruba Central or local CLI
- Best for: SMB branch offices, retail, small campus

### CX 6100 Series

- Layer 2/3 access switches
- 1/2.5/10 GbE options
- PoE++ (90W per port)
- Supports 802.1X, ACLs, VRRP
- VSX capable

### CX 6200 Series

- Mid-range access/aggregation
- 10/25 GbE uplinks
- Full routing: OSPF, BGP, PBR, VRRP
- NAE, REST API
- VSX capable

### CX 6300 Series (Aggregation/Distribution)

- 10/25/40/100 GbE
- Full L3 feature set
- Suitable for building distribution or campus aggregation

### CX 6400 Series (Modular Core)

- Modular chassis: 2-slot and 6-slot
- Line cards: 25/100/400 GbE
- Redundant management modules and power supplies
- Enterprise campus core

### CX 8100 / 8325 / 8360 (Data Center Leaf)

- 1U/2U fixed ToR switches
- 10/25/100 GbE server-facing; 100 GbE uplinks
- Full EVPN-VXLAN, VSX, NAE
- AOS-CX 10.xx feature set

### CX 9300 (Spine)

- 100/400 GbE spine switch
- High-density for large-scale EVPN-VXLAN fabrics

### CX 10000 (Distributed Services Switch)

- **Unique architecture**: includes an integrated AMD Pensando DPU (Data Processing Unit) per line card
- Offloads stateful firewall, NAT, and micro-segmentation to the DPU — line-rate policy enforcement without dedicated firewall appliances
- Supports Aruba Fabric Composer for unified data center fabric management
- Integrates with Pensando Policy and Services Manager (PSM)
- Ideal for: large-scale east-west traffic with stateful security requirements

---

## AOS-CX 10.15 Features

- **EVPN Multihoming enhancements**: improved ESI multi-homing interoperability with VSX
- **BGP route dampening**: prevents BGP route flaps from propagating
- **IPv6 segment routing (SRv6) preview**: early SRv6 support on CX 9300/10000
- **Enhanced NAE framework**: new API endpoints for hardware health and buffer statistics monitoring
- **REST API v10.15**: additional endpoints for VSX state, EVPN RD/RT, and segment information
- **Aruba Central integration**: improved template compliance checking and push notifications
- **QoS enhancements**: DSCP remarking and policing improvements on CX 6300+
- **Security**: 802.1X concurrent authentication with MAC-Auth fallback per-port
- **PoE improvements**: per-port power budgeting and priority on CX 6100/6200 series

---

## CLI Quick Reference

```bash
# View running configuration
show running-config

# Interface configuration
interface 1/1/1
    no shutdown
    description "Server uplink"
    vlan access 10

# VLAN
vlan 10
    name "Production"

# Show commands
show interface 1/1/1
show vlan
show ip route
show bgp summary
show evpn summary
show vsx status
show nae agents

# Save configuration
write memory
checkpoint create pre-upgrade

# Rollback
checkpoint rollback pre-upgrade
```

---

## Summary

AOS-CX is a strong contender in both campus and data center switching, offering modern software architecture with practical automation capabilities. The NAE engine provides unprecedented on-box intelligence without requiring external tools, and VSX delivers robust active-active HA. The CX 10000's DPU integration represents a forward-looking direction for distributed stateful security at the switch level.

**Best for**: HPE/Aruba-centric environments, automation-first teams, data center EVPN-VXLAN fabrics, Dynamic Segmentation with ClearPass.

**Consider alternatives when**: Deep Cisco or Juniper ecosystem integration is required, hardware cost is a concern for small deployments, or team expertise is heavily invested in competitor platforms.
