# Juniper Junos Architecture Reference

## OS Foundation

### Junos OS (Classic)

```
┌──────────────────────────────────────────────┐
│           Junos CLI / Configuration          │
├──────────────────────────────────────────────┤
│  mgd (management)  │  rpd (routing daemon)  │
│  chassisd (chassis) │  dpd, pfed (PFE mgmt) │
├──────────────────────────────────────────────┤
│     FreeBSD Kernel (hardened, modified)       │
├──────────────────────────────────────────────┤
│     ASICs: Memory (PFE data plane)           │
└──────────────────────────────────────────────┘
```

- Built on hardened FreeBSD with Juniper extensions
- Monolithic kernel; single code base across all platforms
- RE handles control plane: routing protocols, management, CLI
- PFE handles data plane: line-rate forwarding, MPLS label operations, QoS

### Junos OS Evolved

```
┌──────────────────────────────────────────────┐
│         Junos CLI (same as classic)          │
├──────────────────────────────────────────────┤
│  rpd │ mgd │ chassisd │ (microservices)      │
│  each runs as independent Linux process      │
├──────────────────────────────────────────────┤
│     Linux Kernel (Ubuntu-based)              │
├──────────────────────────────────────────────┤
│     ASICs (data plane)                       │
└──────────────────────────────────────────────┘
```

- Microservices architecture: process crashes isolated, not system-wide
- Full ISSU support; higher resiliency
- Platforms: QFX5220, QFX5240, PTX10000 series, ACX7000 series
- Same CLI surface, configuration hierarchy, and commit model as classic Junos
- Third-party container hosting via Docker/LXC

## Routing Engine and PFE Separation

- **Routing Engine (RE)**: runs Junos processes (rpd for routing, mgd for management, chassisd for chassis monitoring)
- **Routing tables**: inet.0 (IPv4 unicast), inet6.0 (IPv6), mpls.0 (MPLS), inet.2 (multicast RPF)
- **Packet Forwarding Engine (PFE)**: ASICs perform line-rate forwarding from forwarding table pushed by RE
- **Nonstop Forwarding (NSF)**: RE failure does not interrupt PFE forwarding
- **Graceful Restart**: neighbors maintain adjacency during RE switchover
- **Dual RE**: automatic failover; `set system commit synchronize` keeps both REs aligned

## Commit Model

### Candidate vs Active Configuration

- Active: running config in `/config/juniper.conf`
- Candidate: working copy; changes via `edit` mode
- `commit` promotes candidate to active
- Previous active becomes rollback 1; up to 50 rollbacks stored
- Recent configs in `/config/` (flash); older in `/var/db/config/` (disk)

### Safety Features

- `commit confirmed <minutes>`: auto-rolls back if not re-confirmed within timer
- `commit check`: validates syntax and semantics without activating
- `commit at <time>`: schedules commit for a specific time
- `commit synchronize`: syncs config to backup RE on dual-RE platforms
- `rescue configuration`: manually saved recovery config via `request system configuration rescue save`

### Configuration Hierarchy Navigation

```
edit protocols bgp group EXTERNAL   # enter hierarchy level
set peer-as 65002                   # set relative to current level
up                                  # go up one level
top                                 # return to root
show                                # display config at current level
show | compare                      # diff candidate vs active
wildcard delete interfaces ge-0/0/[0-3]  # wildcard operations
```

## Platform Families

### MX Series (Routing)

| Model | Form Factor | Capacity | Use Case |
|---|---|---|---|
| MX204 | 1U fixed | 400 GbE | Edge/peering |
| MX480 | 8-slot modular | 2.4 Tbps | Enterprise WAN core |
| MX960 | 12-slot modular | 6 Tbps | SP core/peering |
| MX10003 | 6-slot modular | 9.6 Tbps | SP core |
| MX2020 | 20-slot modular | 80 Tbps | Large carrier |

MPC line cards with 100/400 GbE. Full Internet routing tables, MPLS, SR-MPLS, SRv6, L2/L3 VPN, BFD, PTP/IEEE 1588.

### QFX Series (Data Center)

| Model | Ports | Junos Version | Role |
|---|---|---|---|
| QFX5110/5120 | 10/25/100 GbE | Classic | ToR leaf |
| QFX5220 | 100/400 GbE | Evolved | Leaf/spine |
| QFX5240 | 400 GbE | Evolved | Leaf/spine |
| QFX10002 | Modular 100/400 GbE | Classic | Spine/core |
| QFX10008/10016 | Modular | Classic | Large spine |

EVPN-VXLAN, L3VPN, MPLS, BGP, IS-IS, OSPF. Apstra-qualified for intent-based automation.

### EX Series (Campus)

| Model | Ports | Features |
|---|---|---|
| EX2300 | 12/24/48 1GbE PoE | Entry-level, Mist managed |
| EX3400 | 24/48 1GbE PoE | Virtual Chassis stacking |
| EX4300 | 24/48 1GbE/mGig PoE | Mid-range access |
| EX4400 | 24/48 mGig PoE++ | Mist managed, 25G uplinks |
| EX4650 | 48x 25GbE + 8x 100GbE | Aggregation |

### SRX Series (Security)

| Model | Throughput | Features |
|---|---|---|
| SRX300/380 | 1-5 Gbps | Branch: routing, VPN, UTM |
| SRX1500 | 9 Gbps | Mid-range |
| SRX4200/4600 | 20-100 Gbps | Enterprise DC |
| SRX5400/5600/5800 | 100 Gbps-2 Tbps | Carrier-grade chassis |

Stateful firewall, IPS, AppID, UTM (antivirus, antispam, web filtering), IPsec/SSL VPN.

## MPLS Architecture

### Label Distribution Protocols

- **LDP**: autodiscovery, downstream unsolicited, liberal label retention
- **RSVP-TE**: traffic engineering with ERO (Explicit Route Object), CSPF, fast-reroute (FRR)
- **Segment Routing SR-MPLS**: source routing with SRGB/SRLB, prefix/adjacency SIDs, TI-LFA FRR
- **SRv6**: IPv6 extension headers; micro-SID (uSID) for reduced header overhead

### L3VPN (RFC 4364)

```
set routing-instances <name> instance-type vrf
set routing-instances <name> route-distinguisher <ASN:nn>
set routing-instances <name> vrf-target target:<ASN:nn>
set routing-instances <name> protocols bgp group CE neighbor <IP> peer-as <ASN>
```

PE-CE protocols supported: BGP, OSPF, Static, RIP, IS-IS.

### L2VPN

- **VPLS**: multipoint L2 over MPLS; BGP or LDP signaling
- **EVPN-VPWS**: point-to-point L2 with EVPN control plane
- **EVPN-MPLS**: full EVPN with MPLS data plane (SP use case)

## EVPN-VXLAN Data Center

### Route Types

| Type | Name | Purpose |
|---|---|---|
| 1 | Ethernet Auto-Discovery | Multi-homing, aliasing, mass withdrawal |
| 2 | MAC/IP Advertisement | MAC and IP learning |
| 3 | Inclusive Multicast | BUM traffic distribution (ingress replication) |
| 4 | Ethernet Segment | DF election for multi-homing |
| 5 | IP Prefix | L3 prefix advertisement (inter-VNI routing) |

### ERB vs CRB

**ERB (Edge-Routed Bridging)**:
- Distributed L3 gateway at every leaf
- Each leaf routes inter-VLAN traffic locally
- Preferred by Apstra reference designs
- Better east-west performance; no spine bottleneck

**CRB (Centrally Routed Bridging)**:
- L3 routing at spine only; leaves are L2 only
- Simpler leaf configuration
- Spine becomes bottleneck for inter-VLAN traffic

### VLAN-Aware vs VLAN-Based

- **VLAN-Aware**: single EVPN instance handles multiple VLANs; one RD/RT for the entire bundle; Apstra default
- **VLAN-Based**: one EVPN instance per VLAN; finer-grained control; more operational overhead

## Apstra 6.0 (Intent-Based DC Fabric)

### Architecture

- **Apstra Server**: centralized controller (VM or cluster) storing design intent, rendering device configs, monitoring telemetry
- **Apstra Agents**: lightweight agents on switches (or agentless via NETCONF/gNMI)
- **Blueprints**: design documents capturing complete fabric intent (topology, routing, services, policies)

### Workflow: Design > Blueprint > Rendered Config

1. Define intent in Blueprint: rack types, link roles, ASN pools, VXLAN VNI pools
2. Apstra renders vendor-specific configurations automatically
3. Push configs via NETCONF or gNMI
4. Continuous telemetry-driven validation: running state vs intent

### Vendor Support

Junos OS/EVO (QFX5100-5240, QFX10000, EX4400), Arista EOS, Cisco NX-OS, SONiC (Dell, Edgecore).

### Device Roles

- **Spine / Superspine**: IP forwarders; no VXLAN termination
- **Leaf (EVPN)**: VTEP endpoints; terminate VXLAN; distributed L3 gateway
- **Access**: VLAN-based devices without EVPN

### Apstra Probes (Analytics)

Pre-built probes: BGP session state, EVPN Type-3 route validation, interface utilization anomaly, MTU mismatch, hardware health (CPU, memory, temperature). Streaming telemetry pipeline raises anomalies in dashboard.

### Apstra 6.0 Features

- Qualified support for Junos EVO 24.2R2 and 24.4R2
- Enhanced blueprint diff views for change management
- Improved multi-vendor interoperability
- gNMI telemetry extended to additional platforms

## Mist Integration (Wired Assurance)

- **ZTP**: EX switches claim into Mist organization automatically at boot
- **Wired Assurance**: per-port SLE metrics (throughput, PoE health, VLAN mismatches)
- **Marvis AI**: natural language troubleshooting ("Why can't user X access the network?")
- **Dynamic port profiles**: auto-configures ports based on connected device type (LLDP/MAC profiling)
- Supported platforms: EX2300, EX3400, EX4300, EX4400 (fully Mist-managed)

## NETCONF and PyEZ

### NETCONF (RFC 6241)

Native NETCONF support. Operations: `<get-config>`, `<edit-config>`, `<commit>`, `<lock>`, `<validate>`, `<discard-changes>`. Supports candidate and running datastores. Port 830 (SSH subsystem).

### PyEZ

Juniper's official Python library:
- Configuration management (load, commit, diff, rollback)
- Operational commands (RPC calls)
- YAML/Jinja2 template rendering
- Table/View abstractions for structured operational data
- Supports SSH and NETCONF transports

### gNMI

gRPC Network Management Interface for streaming telemetry. Supported on Junos EVO platforms. Get, Set, Subscribe operations. OpenConfig path support.
