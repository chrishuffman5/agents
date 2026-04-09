# Juniper Junos Deep Dive

## Overview

Juniper Networks' Junos OS is one of the most stable and feature-rich network operating systems in the industry. It powers Juniper's entire hardware portfolio — from MX series routing platforms to QFX data center switches, EX campus switches, and SRX security gateways. Junos is known for its single code base, consistent CLI, and unique commit model that separates candidate configuration from active configuration.

Current production releases: **24.4R** (feature), **24.2R** (LTS candidate). Junos Evolved (Junos EVO) is the next-generation variant built on a Linux microservices architecture.

---

## Architecture

### OS Foundation

**Junos OS (Classic)**:
- Built on **FreeBSD** (hardened, modified)
- Monolithic kernel with Juniper extensions
- Routing Engine (RE) and Packet Forwarding Engine (PFE) separation
- RE handles control plane (routing protocols, management, CLI)
- PFE handles data plane (forwarding, MPLS, QoS)

**Junos OS Evolved (Junos EVO)**:
- Built on **Linux** (Ubuntu-based)
- Microservices architecture — routing protocols, management, and daemons run as independent processes
- Full in-service software upgrade (ISSU) support
- Higher resiliency: process crashes are isolated, not system-wide
- Available on: QFX5220, QFX5240, PTX10000 series, ACX7000 series
- Same CLI surface as classic Junos (configuration hierarchy, commit model)

### Routing Engine (RE) and PFE Separation

Junos enforces strict separation:
- **Routing Engine**: runs JunOS processes (rpd, mgd, chassisd), holds routing tables (inet.0, inet6.0, mpls.0), and manages the CLI
- **Packet Forwarding Engine**: ASICs that perform line-rate forwarding based on forwarding table pushed from RE
- RE failure does not interrupt forwarding (Nonstop Forwarding / Graceful Restart)
- Dual RE platforms provide RE redundancy with automatic failover

---

## Commit Model

The Junos commit model is a fundamental differentiator from IOS-style platforms.

### Candidate vs Active Configuration

- **Active configuration**: the currently running configuration; stored in `/config/juniper.conf`
- **Candidate configuration**: the working copy you edit; not active until committed
- Changes made in `edit` mode modify the candidate config only
- A `commit` activates the candidate, making it the new active config
- The previous active config becomes `rollback 0` (or rollback 1 after next commit)

### Rollback History

Junos stores up to 50 rollback configurations:
- `rollback 0` = current active (equivalent to `load override /config/juniper.conf`)
- `rollback 1` = previous active (before last commit)
- `rollback 49` = oldest stored configuration
- Recent configs stored in `/config/` (flash); older ones in `/var/db/config/` (disk)

### Key Commit Commands

```bash
commit                          # activate candidate config
commit confirmed 5              # activate with 5-minute auto-rollback if not re-confirmed
commit check                    # validate syntax without activating
commit and-quit                 # commit and exit config mode
rollback 1                      # load rollback configuration 1 into candidate
rollback 0                      # discard all pending changes (reload current active)
show | compare rollback 1       # diff current candidate vs rollback 1
```

### Commit Safety Features

- **`commit confirmed`**: activates config temporarily; requires a follow-up `commit` within the specified time, otherwise auto-rolls back — prevents being locked out
- **Commit synchronize**: on dual-RE platforms, syncs config to backup RE
- **Rescue configuration**: a manually saved config for factory-like recovery: `request system configuration rescue save`

---

## Platform Families

### MX Series (Routing)

Enterprise and service provider routing platforms:
- **MX204**: 1U fixed, 400 GbE, suitable for edge/peering
- **MX204/480/960/10003**: modular chassis with MPC line cards (100/400 GbE)
- **MX2008/2010/2020**: large carrier-class chassis
- Features: full Internet routing tables, MPLS/LDP/RSVP, L2/L3 VPN, Segment Routing, BFD, PTP/IEEE 1588

### QFX Series (Data Center Switching)

- **QFX5110/5120**: 1U ToR leaf switches, 10/25/100 GbE
- **QFX5220**: 1U, 100/400 GbE, runs Junos EVO
- **QFX5240**: 400 GbE leaf/spine, Junos EVO
- **QFX10002/10008/10016**: modular spine/core switches; high-density 100/400 GbE
- Full EVPN-VXLAN, L3VPN, MPLS, BGP, IS-IS, OSPF support
- Apstra-qualified devices for intent-based fabric management

### EX Series (Campus Switching)

- **EX2300**: entry-level PoE access switch
- **EX3400**: stackable campus access (Virtual Chassis)
- **EX4300/4400**: mid-range access/distribution
- **EX4650**: 25/100 GbE aggregation
- Aruba Mist integration for AI-driven wired assurance and zero-touch provisioning

### SRX Series (Security/Firewall)

- **SRX300/380**: branch firewalls with integrated routing, VPN, UTM
- **SRX1500/4200/4600**: mid-range security gateways
- **SRX5000 series**: carrier-grade chassis firewalls (up to 2 Tbps)
- Features: stateful firewall, IPS, application identification (AppID), UTM (antivirus, antispam, web filtering), IPsec/SSL VPN

---

## BGP Configuration

### eBGP Example

```bash
set protocols bgp group EXTERNAL type external
set protocols bgp group EXTERNAL peer-as 65002
set protocols bgp group EXTERNAL neighbor 192.168.1.2
set protocols bgp group EXTERNAL export SEND-ROUTES
set policy-options policy-statement SEND-ROUTES term 1 from protocol direct
set policy-options policy-statement SEND-ROUTES term 1 then accept
```

### iBGP Full Mesh / Route Reflector

```bash
# Route Reflector configuration
set protocols bgp group INTERNAL type internal
set protocols bgp group INTERNAL local-address 10.0.0.1
set protocols bgp group INTERNAL cluster 10.0.0.1
set protocols bgp group INTERNAL neighbor 10.0.0.2
set protocols bgp group INTERNAL neighbor 10.0.0.3
```

### BGP Additional-Paths

```bash
set protocols bgp group INTERNAL family inet unicast add-path send path-count 6
```

---

## OSPF and IS-IS

### OSPF

```bash
set protocols ospf area 0.0.0.0 interface ge-0/0/0.0
set protocols ospf area 0.0.0.0 interface lo0.0 passive
set protocols ospf export REDISTRIBUTE-DIRECT
```

### IS-IS (Preferred for Large-Scale Fabrics)

```bash
set protocols isis interface ge-0/0/0.0 level 2 metric 10
set protocols isis interface lo0.0 passive
set protocols isis level 2 wide-metrics-only
```

IS-IS is preferred over OSPF in data center fabrics due to protocol efficiency and no flooding scope limitations.

---

## MPLS / L3VPN

Junos is a reference implementation for MPLS L3VPN:

```bash
# Enable MPLS on interface
set protocols mpls interface ge-0/0/0.0
set protocols ldp interface ge-0/0/0.0

# L3VPN instance
set routing-instances CUST-A instance-type vrf
set routing-instances CUST-A interface ge-0/1/0.0
set routing-instances CUST-A route-distinguisher 65001:100
set routing-instances CUST-A vrf-target target:65001:100
set routing-instances CUST-A protocols bgp group CE type external
set routing-instances CUST-A protocols bgp group CE neighbor 10.100.1.2 peer-as 65100
```

Junos supports: LDP, RSVP-TE, Segment Routing (SR-MPLS, SRv6), L2VPN (VPLS, EVPN-VPWS), L3VPN (RFC 4364).

---

## EVPN-VXLAN

Junos provides native EVPN-VXLAN support across QFX platforms, used in data center leaf-spine fabrics.

### Leaf Configuration (EVPN Type 2/3)

```bash
# Underlay BGP
set protocols bgp group UNDERLAY type external
set protocols bgp group UNDERLAY family inet unicast

# EVPN overlay
set protocols bgp group OVERLAY type internal
set protocols bgp group OVERLAY family evpn signaling

# VXLAN VNI
set interfaces vtep unit 0 family inet
set vlans VLAN10 vlan-id 10
set vlans VLAN10 vxlan vni 10010

# EVPN instance
set routing-instances EVPN instance-type evpn
set routing-instances EVPN vlan-list VLAN10
set routing-instances EVPN vtep-source-interface lo0.0
```

### ERB (Edge-Routed Bridging) vs CRB

- **ERB**: Distributed Layer 3 gateways at each leaf; each leaf routes traffic locally; preferred by Apstra designs
- **CRB (Centrally Routed Bridging)**: routing occurs at spine; simpler but spine is a bottleneck

Apstra's native reference design uses ERB with EVPN VLAN-Aware mode.

---

## Apstra 6.0 (Intent-Based DC Fabric)

Juniper Apstra (formerly Apstra, acquired 2021) is an intent-based networking platform for data center fabric automation.

### Architecture

- **Apstra Server**: centralized controller VM (or cluster) — stores design intent, renders device configs, monitors telemetry
- **Apstra Agents**: lightweight agents installed on switches (or agentless via NETCONF/gNMI)
- **Blueprints**: design documents that capture the complete fabric intent — topology, routing, services, policies

### Key Concepts

**Design > Blueprint > Rendered Config:**
1. Operator defines intent in a Blueprint (rack types, link roles, ASN pools, VXLAN VNI pools)
2. Apstra renders vendor-specific configurations automatically
3. Configurations are pushed to devices via NETCONF or gNMI
4. Apstra continuously validates the running state against the intent (telemetry-driven)

**Vendor-Agnostic:**
Apstra 6.0 supports:
- Juniper (Junos OS and Junos EVO: QFX5100, QFX5220, QFX5240, QFX10000, EX4400)
- Arista EOS
- Cisco NX-OS
- SONiC (Dell, Edgecore/Accton)

**Device Roles:**
- **Spine / Superspine**: IP forwarders; no VXLAN termination
- **Leaf (EVPN)**: VTEP endpoints; terminate VXLAN; distributed L3 gateway
- **Access**: VLAN-based devices without EVPN

### Apstra Probes (Analytics)

Apstra includes an analytics engine with pre-built probes for:
- BGP session state monitoring
- EVPN Type-3 route validation
- Interface utilization anomaly detection
- MTU mismatch detection
- Hardware health (CPU, memory, temperature)

Probes use a streaming telemetry pipeline and raise anomalies in the Apstra dashboard.

### Apstra 6.0 Notable Features

- Qualified support for Junos EVO 24.2R2 and 24.4R2
- Enhanced blueprint diff views for change management workflows
- Improved multi-vendor interoperability testing
- gNMI telemetry support extended to additional platforms

---

## Mist Integration (Wired Assurance)

Juniper Mist provides cloud-based AI-driven network management for EX series campus switches:
- **Zero-Touch Provisioning (ZTP)**: EX switches claim into Mist organization automatically
- **Wired Assurance**: per-port SLE (Service Level Expectation) metrics — throughput, PoE health, VLAN mismatches
- **Marvis AI Engine**: natural language troubleshooting ("Why can't user X access the network?")
- **Dynamic port profiles**: auto-configures ports based on connected device type
- EX4400 and EX2300/3400 fully Mist-managed

---

## NETCONF and PyEZ

### NETCONF

Junos has native NETCONF support (RFC 6241):
```python
from ncclient import manager
with manager.connect(host='192.168.1.1', username='admin', password='Juniper1') as m:
    config = m.get_config(source='running')
    print(config)
```

### PyEZ (Python library for Junos)

Juniper's official Python library for device automation:
```python
from jnpr.junos import Device
from jnpr.junos.utils.config import Config

dev = Device(host='192.168.1.1', user='admin', passwd='Juniper1')
dev.open()

cu = Config(dev)
cu.load('set interfaces ge-0/0/0 description "Uplink"', format='set')
cu.pdiff()    # show diff
cu.commit()

dev.close()
```

PyEZ supports: configuration management, operational commands, YAML/Jinja2 templates, table/view abstractions for structured operational data.

---

## Junos 24.4R Version Features

- **SRv6 enhancements**: improved uSID (micro-SID) support for SRv6 L3VPN
- **EVPN Type-5 scale improvements**: higher prefix scale for EVPN IP-Prefix routes on QFX platforms
- **BGP Flowspec**: enhanced BGP Flowspec with additional match/action terms
- **IS-IS Segment Routing extensions**: refined SR-TE path computation
- **Junos EVO**: 24.4R2 qualified for Apstra fabric automation
- **Security**: updated TLS certificate management, JunOS PKI improvements
- **OpenConfig telemetry**: expanded gNMI path support for enhanced monitoring

---

## CLI Quick Reference

```bash
# Configuration hierarchy navigation
edit interfaces ge-0/0/0
set description "Server uplink"
set unit 0 family inet address 10.1.1.1/24
show | compare                  # show pending changes

# Commit operations
commit check
commit confirmed 10
commit

# Rollback
rollback 1
show | compare rollback 2

# Show commands
show route
show bgp summary
show ospf neighbor
show isis adjacency
show evpn database
show mpls lsp
show interfaces terse
show chassis hardware

# Delete configuration
delete interfaces ge-0/0/1 description
```

---

## Summary

Junos is a premier network operating system combining enterprise-grade stability with carrier-class scale. Its commit model, consistent CLI across all platforms, and robust EVPN-VXLAN/MPLS implementation make it a strong choice for complex network environments. Apstra extends Junos into intent-based automation, enabling consistent data center fabric management across multiple vendors.

**Best for**: Large-scale routing (service provider/enterprise WAN), EVPN-VXLAN data center fabrics, organizations that value CLI consistency, automation-first environments with Apstra.

**Consider alternatives when**: Cisco ACI ecosystem lock-in is acceptable, cost is a primary concern for SMB deployments, or the team lacks Junos expertise.
