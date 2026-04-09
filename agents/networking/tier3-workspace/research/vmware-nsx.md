# VMware NSX Deep Dive

## Overview

VMware NSX (now under Broadcom following the 2023 acquisition) is a network virtualization and security platform that provides software-defined networking for vSphere-based data centers and multi-cloud environments. NSX abstracts networking and security services from underlying hardware, delivering microsegmentation, logical switching/routing, load balancing, VPN, and firewall capabilities entirely in software.

Current version: **NSX 4.2.x** (latest patch: 4.2.3.1 as of early 2026). NSX is now distributed as part of VMware Cloud Foundation (VCF) under Broadcom's licensing model.

---

## Architecture

### NSX Manager Cluster

The NSX Manager is the management and control plane for NSX. It is deployed as a cluster of three virtual appliances for high availability:
- Each NSX Manager node runs both management and control plane functions
- Cluster state is synchronized across all three nodes via Raft consensus
- A Virtual IP (VIP) is configured for single-endpoint access
- Minimum: 1 node (lab only); Production: 3-node cluster

**Manager responsibilities:**
- REST API endpoint for all configuration
- Policy engine — translates intent to data plane configuration
- Certificate management (auto-renewal in NSX 4.2.1+)
- Integration with vCenter, Kubernetes, and cloud platforms
- Upgrade orchestration

In NSX 4.2, the Manager can be deployed as part of a VCF environment where it integrates with SDDC Manager for lifecycle management and VUM-based upgrades.

### Transport Nodes

Transport nodes are the hypervisors (ESXi or KVM hosts) or NSX Edge nodes that participate in the NSX overlay. On each transport node:
- The NSX kernel modules (VIBs) are installed
- A TEP (Tunnel Endpoint) is configured — a logical IP used for VXLAN/Geneve tunneling
- Traffic between VMs on different transport nodes is encapsulated with **Geneve** (NSX 3.0+ replaced VXLAN with Geneve)

**Types of transport nodes:**
- **Host Transport Nodes**: vSphere ESXi hosts running workload VMs
- **Edge Transport Nodes**: NSX Edge VMs or bare-metal appliances for North-South traffic and network services

Transport zones define which transport nodes can communicate. An overlay transport zone groups nodes in the same overlay network domain; a VLAN transport zone handles physical uplinks.

### N-VDS vs VDS

**N-VDS (NSX Virtual Distributed Switch)**: The original NSX-T virtual switch. Each host had a dedicated N-VDS separate from the standard vSphere VDS.

**VDS (vSphere Distributed Switch) with NSX integration** (NSX 3.2+): NSX now runs on top of the standard VDS instead of a separate N-VDS. This simplifies deployment — a single VDS handles both vSphere networking and NSX overlay. VDS-based deployment is the current best practice for NSX 4.x on vSphere 7+.

Benefits of VDS mode:
- Single switch for all vSphere networking
- Reduced operational complexity
- Consistent uplink management
- Supports vMotion without NSX-specific TEP migration

---

## Distributed Firewall (DFW)

The DFW is NSX's flagship micro-segmentation feature. It runs as a kernel module on every ESXi host transport node, enforcing firewall rules at the vNIC level of each VM — traffic is inspected before it even enters the network.

### Architecture

- Rules are pushed from NSX Manager to all hosts via the control plane
- Each vNIC has its own stateful firewall policy table
- No traffic needs to be hairpinned to a central firewall appliance
- Scales horizontally — more hosts = more DFW capacity

### Rule Organization

DFW rules are organized in a hierarchy:
1. **Policy** (formerly Security Policy): top-level container with a priority/sequence number
2. **Rule**: specifies Source, Destination, Service, Action (Allow/Drop/Reject), Direction, and Applied-To scope
3. **Applied-To**: scopes the rule to specific VMs, groups, or segments — reduces rule evaluation overhead

**Default rule**: The bottom of the DFW table has an implicit deny-all rule (or allow-all, operator configurable).

### Groups

Groups replace IP-based source/destination lists with dynamic, attribute-based membership:
- **Static members**: specific VMs, IPs, or segments
- **Dynamic members**: membership computed from VM tags, OS type, VM name pattern, security policy, or Kubernetes labels
- Groups update automatically as VMs are created, migrated, or decommissioned

Example group criteria:
```
Membership criteria: VM Tag = "Production" AND OS = "Linux"
```

### Context Profiles

Context profiles (L7 policies) allow DFW rules to match on application layer attributes:
- Application ID (App-ID): identifies apps by traffic signature (not just port)
- FQDN/URL: filter based on domain names
- DNS: block or allow DNS queries by domain pattern
- TLS inspection (with NSX Gateway Firewall)

Context profiles require the NSX vDefend ATP (Advanced Threat Protection) add-on for full L7 IDS/IPS capability.

### vDefend Firewall (NSX 4.x)

In NSX 4.2, the DFW is marketed as **vDefend Distributed Firewall** as part of the vDefend security portfolio:
- **Turbo mode (SCRX)**: high-performance mode for DFW + Distributed IDS/IPS; uses deterministic resource allocation and higher packet processing pipelines within the ESXi hypervisor
- **Custom IDS/IPS signatures**: import Suricata-based signatures from third-party threat intel feeds
- **Gateway Firewall scale**: up to 2,500 rules per section with alarm notification when approaching limits

---

## T0 and T1 Gateways

NSX implements logical routing through Tier-0 (T0) and Tier-1 (T1) Gateway constructs.

### Tier-0 Gateway

The T0 Gateway provides North-South connectivity between the NSX overlay and the external physical network:
- Runs BGP and/or static routing with upstream physical routers
- Supports ECMP across multiple Edge nodes for load balancing
- VRF-Lite support: multiple T0 VRFs on a single T0 gateway for multi-tenancy
- In NSX 4.2, VRF configuration is supported at the Global Manager level for stretched T0 deployments

**Active-Active vs Active-Standby:**
- Active-Active: T0 with ECMP across Edge nodes (all nodes forward traffic); requires stateless services
- Active-Standby: T0 with a designated primary; failover via BFD

### Tier-1 Gateway

T1 Gateways provide East-West routing between logical segments and connect to a T0 for northbound traffic:
- Each T1 advertises connected subnets up to the T0 via a special "SR" (Service Router) component
- T1 can run on distributed routers (DR) in each host kernel for high-performance E-W routing
- T1 Gateways are the attachment point for NSX segments (logical switches)
- Multiple T1 gateways can connect to a single T0 — common pattern for tenant isolation

**T0/T1 data path:**
- VM to VM on same segment: routed in hypervisor kernel (distributed router), no Edge node involvement
- VM to external: routed through T1 DR → T1 SR (on Edge) → T0 SR (on Edge) → physical uplink

---

## Logical Switching and Segments

NSX Segments replace VLANs with Geneve-encapsulated overlay networks:
- Each segment has a unique VNI (VXLAN Network Identifier, 24-bit)
- BUM (Broadcast, Unknown unicast, Multicast) traffic uses Geneve with head-end replication or MTEP multicast
- Segments can be stretched across hosts in different racks transparently
- Segment profiles control MAC/IP learning, security, and QoS

---

## NSX Federation (Multi-Site)

NSX Federation provides centralized management of NSX deployments across geographically distributed sites:

**Components:**
- **Global Manager**: centralized management plane for all sites; accepts policy configuration
- **Local Managers**: per-site NSX Manager clusters; execute policy locally
- **Stretched objects**: Segments, Groups, and Gateway Firewall policies can be stretched across sites

**Capabilities:**
- Define security policies once, enforce consistently across all sites
- Stretched segments for workload mobility between sites
- Federated gateway firewall for inter-site traffic policy
- NSX 4.2.1 added VRF configuration at the Global Manager level for stretched T0 Gateways

Federation is the recommended architecture for multi-data-center NSX deployments, replacing per-site management silos.

---

## NSX Intelligence

NSX Intelligence is an analytics add-on that provides visibility into network flows and automated security recommendations:
- **Flow Visualization**: displays VM-to-VM traffic flows across the NSX overlay with L4 port/protocol annotation
- **Security Recommendations**: analyzes observed flows and suggests DFW rules to implement least-privilege micro-segmentation
- **Application Discovery**: identifies application topologies based on traffic patterns
- **Deployed as**: NSX Application Platform (NAPP) — a Kubernetes-based platform running on a dedicated cluster

NSX Intelligence is licensed separately (NSX Enterprise Plus or above).

---

## NSX ALB (Avi Networks)

NSX Advanced Load Balancer (NSX ALB), formerly Avi Networks, is the recommended load balancing solution for NSX environments:

**Architecture:**
- **Avi Controller**: management cluster (3-node HA); interfaces with NSX Manager and vCenter
- **Service Engines (SEs)**: data plane VMs deployed automatically per application; scale horizontally
- **Avi CLI/API**: RESTful API for automation; Terraform provider available

**Features:**
- Layer 4-7 load balancing (TCP/UDP, HTTP/HTTPS)
- SSL/TLS termination and offload
- Web Application Firewall (WAF) with OWASP rule sets
- Application analytics: end-to-end latency, server health scores
- Autoscaling: SE pools scale up/down based on connection rate
- Multi-cloud: same controller manages SE pools in vSphere, AWS, Azure, and GCP
- Kubernetes integration: acts as ingress controller via AKO (Avi Kubernetes Operator)

In VCF environments, NSX ALB is the native load balancer replacing the deprecated NSX Edge load balancer.

---

## Broadcom Acquisition Impact

Broadcom completed the acquisition of VMware in late 2023. Key impacts for NSX:

**Licensing changes:**
- NSX is no longer sold standalone; it is bundled into **VMware Cloud Foundation (VCF)** SKUs
- VCF bundles: vSphere + vSAN + NSX + Aria (formerly vRealize) in per-core subscription pricing
- Legacy perpetual NSX-T licenses are still honored but no longer sold to new customers
- NSX ALB licensing is now included in specific VCF tiers

**Product changes:**
- NSX rebranded to reflect its security positioning: DFW → vDefend Distributed Firewall
- New vDefend portfolio: vDefend Distributed Firewall, vDefend Gateway Firewall, vDefend ATP, vDefend NDR
- Roadmap tightly aligned with VCF release cadence

**Operational impact:**
- Support now runs through Broadcom support portal (not VMware MyPortal)
- Documentation migrated to techdocs.broadcom.com
- Pricing model shift: organizations must evaluate total VCF cost vs standalone alternatives (Cisco ACI, Juniper Apstra)

---

## Troubleshooting

### Central CLI

NSX provides a unified CLI for troubleshooting across Manager and Edge nodes:
```bash
# On NSX Manager
get logical-switches
get transport-nodes
get logical-routers

# On Edge node
get interfaces
get route
get bgp neighbor summary
get firewall status
```

### NSX Manager REST API

All NSX configuration and operational state is accessible via REST API:
```bash
# Get all segments
GET https://<nsx-mgr>/api/v1/logical-switches

# Get firewall rules
GET https://<nsx-mgr>/policy/api/v1/infra/domains/default/security-policies

# Get transport node status
GET https://<nsx-mgr>/api/v1/transport-nodes/<id>/state
```

### Common Troubleshooting Steps

**DFW rule not matching:**
1. Check Applied-To scope — rule may not be scoped to the correct VM/group
2. Verify group membership: `GET /policy/api/v1/infra/domains/default/groups/<id>/members/virtual-machines`
3. Check rule statistics for hit counts in the NSX Manager UI (Security > Distributed Firewall > Rules > Stats)

**Overlay connectivity failure:**
1. Verify TEP connectivity: `ping ++netstack+vxlan <remote-tep-ip>` from ESXi host
2. Check transport node state: `get transport-node-realization-state <node-id>`
3. Verify segment VNI and VTEP bindings: `get logical-switch <ls-id>`

**Edge BGP not establishing:**
1. Check T0 uplink interface status
2. Verify BGP configuration on Edge SR: `get bgp neighbor`
3. Check physical router BGP config for matching AS and neighbor IP

**TEP HA with BFD (NSX 4.2.1):**
- TEP Groups provide redundancy across physical uplinks with BFD-based failover detection
- Configure via: Policy > System > TEP Groups

---

## Summary

NSX 4.2 is a mature, enterprise-grade network virtualization platform with deep vSphere integration. Its DFW micro-segmentation capability is industry-leading for VMware-centric environments. The Broadcom acquisition has created licensing uncertainty, but NSX remains the primary networking layer for VCF deployments.

**Best for**: vSphere-heavy enterprises, organizations requiring micro-segmentation without hardware changes, VMware Cloud Foundation deployments.

**Consider alternatives when**: Multi-hypervisor or bare-metal environments dominate, Broadcom licensing costs are prohibitive, or hardware-based performance is required.
