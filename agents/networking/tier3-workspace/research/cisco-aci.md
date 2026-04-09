# Cisco ACI Deep Dive

## Overview

Cisco Application Centric Infrastructure (ACI) is Cisco's software-defined networking (SDN) solution for data center fabrics. It centralizes automation, visibility, and policy enforcement across physical and virtual environments. ACI decouples application requirements from the underlying network infrastructure using a policy-driven model, where the application defines the network — not the other way around.

ACI is built on three pillars:
1. **Application Policy Infrastructure Controller (APIC)** — the centralized policy engine
2. **Spine-leaf fabric** — a Clos-topology fabric using Nexus 9000 switches
3. **Policy model** — tenants, VRFs, BDs, EPGs, contracts, filters, and L3Outs

---

## Architecture

### Spine-Leaf Fabric (CLOS Topology)

ACI uses a two-tier spine-leaf fabric built on Nexus 9000 series switches operating in ACI mode. Every leaf switch connects to every spine switch — no direct leaf-to-leaf or spine-to-spine links exist. This provides:
- Predictable, consistent latency across the fabric
- Equal-cost multipath (ECMP) for all traffic
- Horizontal scalability by adding leaf or spine nodes

**Leaf switches** connect servers, storage, service appliances, and external networks. They are the policy enforcement points — all access policies, port policies, and VLAN mappings are applied at the leaf level.

**Spine switches** serve as the backbone interconnect. They carry VXLAN-encapsulated traffic between leaves and run the IS-IS routing protocol for the fabric underlay. Spines do not connect directly to endpoints.

### Nexus 9000 in ACI Mode

Nexus 9000 switches run in one of two modes:
- **NX-OS standalone mode** — traditional CLI-driven operation
- **ACI mode** — switches become fabric nodes managed entirely by APIC; direct CLI access is limited to read-only diagnostics

In ACI mode, switches register to the APIC cluster on boot, receive configuration via OpFlex protocol, and maintain a local copy of policies for resilience during APIC outages. The switch-level configuration is derived from the APIC policy model — administrators do not configure interfaces or VLANs directly on individual switches.

**Supported platforms:**
- Nexus 9300-FX/EX/GX leaf series — 1/10/25/100 GbE access
- Nexus 9500 modular spine series — 100/400 GbE backbone
- Nexus 9336C-FX2 — commonly used as both leaf and spine in smaller fabrics

### APIC Cluster

The APIC is the centralized management, policy, and automation engine. It is deployed as a cluster of physical or virtual appliances:
- **Minimum deployment**: 3 APICs (odd number for quorum)
- **Production recommendation**: 3 physical APICs in separate availability zones
- Up to 9 APICs can be clustered for scale

APIC does not sit in the data path. It distributes policies to fabric nodes via OpFlex. If all APICs go offline, existing policies continue to be enforced by the fabric switches. New policy changes require at least one APIC to be reachable.

APIC functions:
- Policy repository and REST API endpoint
- GUI, CLI, and API access for operators
- Fabric discovery and inventory
- Health monitoring and fault management
- Image management and firmware upgrades

---

## OpFlex Protocol

OpFlex is an open, declarative southbound protocol developed by Cisco for communication between APIC and fabric nodes. Unlike OpenFlow (which is imperative), OpFlex uses an intent-based approach — APIC declares desired policy state and nodes implement it locally.

Key characteristics:
- JSON-RPC based, runs over TCP
- Nodes pull policies from APIC and report state back
- Decentralized enforcement — each node processes its policy copy independently
- Enables ACI to scale without bottlenecking policy delivery

OpFlex is also used in ACI Virtual Edge (AVE) and Cisco ACI Virtual Pod for extending policy to virtualized environments.

---

## Policy Model

The ACI policy model is object-oriented and hierarchical. Everything in ACI is an object in the Management Information Tree (MIT).

### Tenants

The top-level administrative container. A tenant provides:
- Namespace isolation for policies, VRFs, and BDs
- Multi-tenancy in shared or dedicated modes
- Built-in tenants: `common` (shared), `infra` (fabric), `mgmt` (management)

### VRFs (Virtual Routing and Forwarding)

A VRF defines a layer-3 routing domain within a tenant. Multiple VRFs can coexist in a tenant with isolated routing tables. Inter-VRF communication requires contracts (shared services) or L3Outs with external routing.

### Bridge Domains (BDs)

Bridge Domains replace traditional VLANs. A BD is a layer-2 forwarding domain associated with one or more subnets:
- Subnets are defined on the BD (not the interface)
- ARP flooding, unicast routing, and unknown unicast handling are BD-level settings
- A BD can have multiple subnets (useful for secondary IPs)
- A BD belongs to exactly one VRF

### Endpoint Groups (EPGs)

EPGs are the core policy construct. An EPG is a logical grouping of endpoints that share the same security and forwarding policies. Endpoints can be:
- Physical servers connected to leaf ports
- Virtual machines via VMM integration (VMware vCenter, Microsoft SCVMM)
- Containers (Kubernetes/OpenShift via ACI CNI)

EPGs belong to an Application Profile, which belongs to a Tenant.

**Communication between EPGs is denied by default** — whitelisting via contracts is required.

### Contracts, Subjects, and Filters

Contracts define permitted communication between EPGs:
- **Filter**: specifies Layer 3/4 traffic (protocol, src/dst port)
- **Subject**: groups one or more filters; specifies directionality and QoS
- **Contract**: groups subjects; applied between a provider EPG and consumer EPG

A contract provider EPG offers a service; consumer EPGs access it. Contracts can be:
- **Standard**: bidirectional policy between two EPGs
- **vzAny**: applied to all EPGs in a VRF

### L3Outs (External Routed Networks)

L3Outs connect the ACI fabric to external Layer 3 networks (WAN routers, firewalls, internet). An L3Out:
- Defines a logical interface and external routing protocol (OSPF, BGP, EIGRP, static)
- Associates with an External EPG (ExtEPG) for policy classification
- Uses contracts to control traffic between fabric EPGs and external networks

L3Outs support VRF-Lite for multi-VRF external connectivity.

### Service Graphs

Service Graphs define how traffic should pass through service appliances (firewalls, load balancers) between EPGs. A service graph:
- Specifies function nodes (Go-Through, Go-To)
- Renders physical or virtual device clusters (ASA, F5, Palo Alto)
- Inserts services transparently (unmanaged) or with device package integration (managed)

Service Graph stitching is performed at the leaf level using VLAN stitching or PBR (Policy-Based Redirect).

---

## Fabric Discovery

ACI fabric discovery is automated:
1. APIC discovers spine switches via LLDP
2. Spines discover leaves via IS-IS and LLDP
3. Nodes register in APIC inventory with serial number, role, and topology position
4. APIC assigns node IDs and provisions base configuration

Discovery is zero-touch for fabric switches. Switches must be in the APIC node inventory before they can join the fabric.

---

## Micro-Segmentation (uSeg EPGs)

uSeg EPGs extend standard EPG segmentation by using VM attributes to assign workloads dynamically:
- VM name, operating system, tag, security group, vNIC, datacenter
- An endpoint can be moved from a base EPG to a uSeg EPG based on attribute matching
- Useful for granular workload isolation without changing IP addressing

uSeg is primarily used in VMware DVS and Cisco ACI Virtual Edge (AVE) environments.

---

## Multi-Site Orchestrator (MSO / Nexus Dashboard Orchestrator)

MSO (rebranded as Nexus Dashboard Orchestrator, or NDO, from release 3.2+) provides centralized policy management across multiple ACI sites:

**Capabilities:**
- Single pane of glass for multi-site ACI deployments
- Stretch schemas and templates: define EPGs, BDs, VRFs, and contracts once, push to multiple sites
- Inter-site contracts for east-west traffic across fabric boundaries
- Multi-Pod: single APIC cluster across geographically separated pods (single fabric domain)
- Multi-Site: separate APIC clusters per site, centrally orchestrated by NDO
- Site connectivity: VXLAN Multi-Site overlay using BGP EVPN on inter-site network (ISN)

**Supported site types:**
- ACI on-premises sites
- Cloud ACI sites (AWS, Azure)
- NDFC (Nexus Dashboard Fabric Controller) sites

---

## Cloud ACI (AWS and Azure)

Cloud ACI extends ACI policy to public cloud environments:
- **AWS**: Cloud APIC deployed as an EC2 instance; VPCs map to ACI tenants; security groups and routing managed via ACI policy
- **Azure**: Cloud APIC deployed as a VM; VNets map to ACI tenants; NSGs and route tables managed via policy

Cloud ACI uses Cisco Catalyst 8000V (cloud router) for inter-site connectivity and IPsec tunnels between cloud VPCs/VNets and on-premises ACI fabric. NDO provides unified policy across on-prem + cloud.

---

## Troubleshooting

### Faults and Health Scores

ACI uses a health score system (0-100 scale, higher is healthier) for:
- Fabric nodes (switches, APICs)
- Tenants, EPGs, contracts
- Physical links and endpoints

Faults are surfaced in APIC GUI under `Fabric > Inventory > Health` and via REST API. Each fault has a severity (critical, major, minor, warning), a fault code, and a lifecycle (raised, raised-clearing, cleared).

Common troubleshooting commands:
```
fabric 101 show faults detail          # show faults on leaf 101
moquery -c faultInst -f 'fault.Inst.severity=="critical"'  # CLI object query
```

### Contract Hit Counts

Verifying if traffic is being allowed/denied by contracts:
- APIC GUI: `Tenants > [tenant] > Operational > EP Reachability`
- Per-leaf contract statistics: `show zoning-rule statistics`
- Atomic counter: monitors traffic between two EPGs at leaf level for packet counts

### ELAM (Embedded Logic Analyzer Module)

ELAM is a hardware-level packet capture tool on Nexus 9000 in ACI mode:
```
module asic 0 elam asic-type grn-d
  trigger reset
  trigger init in-select 6 out-select 0
  set outer ipv4 src_ip <src> dst_ip <dst>
  start
  report
```
ELAM captures the first matching packet through the ASIC pipeline and shows forwarding decisions, VXLAN encap, and policy hit results.

### Central CLI

APIC provides a centralized CLI to run commands across all fabric nodes:
```
fabric 101-105 show bgp summary
fabric 101 show endpoint detail
fabric 101 show vlan extended
```

### APIC 6.1 Features

- **Endpoint Security Groups (ESGs)**: Replaces EPG for segmentation in newer deployments; decouples security policy from forwarding domains; supports VM/container attribute-based assignment
- **Enhanced Inter-VRF shared services**: Improved traffic flow support across VRF domains
- **L3Out BGP multi-hop**: Extended eBGP multihop support for complex L3Out topologies
- **Fabric Wide System Settings**: Centralized fabric-level knobs for ARP gleaning, BD learning, and hardware proxy
- **APIC REST API enhancements**: Improved bulk operations and delta queries for large-scale automation
- **Multi-Pod enhancements**: Improved spine isolation and inter-pod redundancy
- **Telemetry streaming**: gRPC-based streaming telemetry to external collectors (AppDynamics, Thousand Eyes)

---

## Key CLI and API References

**APIC REST API base URL:**
```
https://<apic>/api/node/mo/uni.json
https://<apic>/api/node/class/faultInst.json
```

**Useful moquery patterns:**
```
moquery -c fvTenant                    # list all tenants
moquery -c fvAEPg                      # list all EPGs
moquery -c fvCEp -f 'fv.CEp.ip=="10.1.1.5"'  # find endpoint by IP
moquery -c vzFilter                    # list all filters
```

**APIC Python SDK (Cobra):**
```python
from cobra.mit.access import MoDirectory
from cobra.mit.session import LoginSession
ls = LoginSession('https://apic', 'admin', 'password')
md = MoDirectory(ls)
md.login()
```

---

## Summary

Cisco ACI is a mature, widely deployed SDN platform suited for enterprise and service provider data centers requiring policy-driven automation, micro-segmentation, and multi-cloud extension. Its learning curve is steep but the operational consistency across large multi-site deployments, combined with robust troubleshooting tools like ELAM and contract hit counts, makes it a strong choice for environments already invested in Cisco infrastructure.

**Best for**: Large enterprises, service providers, multi-data-center deployments, organizations requiring deep Cisco ecosystem integration.

**Consider alternatives when**: Teams lack ACI expertise, scale is small (<100 nodes), or multi-vendor fabric flexibility is required.
