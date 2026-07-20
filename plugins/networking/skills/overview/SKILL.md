---
name: overview
description: "Top-level entry point for all networking technologies -- routing/switching, firewalls, DNS, VPN, SD-WAN, wireless, DC fabric, cloud networking, IPAM, automation, and monitoring -- for cross-platform or architectural questions. Use for \"network architecture\", \"firewall rule\", \"routing protocol\", \"VLAN design\", \"BGP peering\", \"OSPF area\", \"VPN tunnel\", \"DNS resolution\", \"load balancer\", \"SD-WAN\", \"network segmentation\", \"EVPN-VXLAN\", \"ACL\", \"NAT\" when no specific technology is named or the question spans multiple technologies. Do NOT use for single-vendor config or CLI syntax -- use the specific technology skill (e.g. `panos`, `cisco-ios-xe`, `bind`) or a category skill (`firewall`, `dns`, etc.) for comparisons. Do NOT use for cloud IAM/compute architecture beyond VPC/VNet -- that's the `cloud-platforms` plugin. Do NOT use for Kubernetes networking (CNI, ingress, mesh) -- that's the `containers` plugin."
license: MIT
---

# Networking

This skill routes across all networking technologies and disciplines, covering network architecture, routing protocols, switching, firewall design, DNS, VPN, load balancing, SD-WAN, and network automation. Sibling category and technology skills provide deep implementation details.

## When to Use This Skill vs. a Subcategory Skill

**Use this skill when the question is cross-platform or architectural:**
- "Design a campus network for 500 users"
- "Compare OSPF vs BGP for my WAN"
- "How should I segment my network?"
- "What firewall should I use?"
- "Troubleshoot intermittent connectivity"
- "Plan a site-to-site VPN between Azure and on-prem"

**Route to a subcategory skill when the question is technology-specific:**
- "Configure BGP on Arista EOS" --> the `arista-eos` skill
- "PAN-OS security policy best practices" --> the `panos` skill
- "BIND zone file syntax" --> the `bind` skill
- "WireGuard peer configuration" --> the `wireguard` skill
- "F5 iRule for header rewrite" --> the `f5-bigip` skill
- "Cisco SD-WAN application-aware routing" --> the `cisco-sdwan` skill

## How to Approach Tasks

1. **Classify** the request:
   - **Architecture / Design** -- Apply the Network Design Principles below, then route to the relevant category skill's `references/` for platform-specific patterns
   - **Technology selection** -- Compare options within the relevant subcategory
   - **Troubleshooting** -- Identify the layer (L1-L7), then consult the appropriate technology skill
   - **Configuration** -- Consult the specific technology skill
   - **Automation** -- Route to the network automation subcategory

2. **Gather context** -- Network size, topology, existing equipment, traffic patterns, compliance requirements, team expertise, budget

3. **Analyze** -- Apply networking principles. Consider the OSI model, traffic flows, failure domains, and operational complexity.

4. **Recommend** -- Provide specific, actionable guidance with trade-offs

5. **Qualify** -- State assumptions about topology, scale, and traffic patterns

## Network Design Principles

### OSI Model Application

| Layer | Focus | Common Issues |
|---|---|---|
| L1 Physical | Cabling, optics, power | Cable faults, SFP compatibility, PoE budget |
| L2 Data Link | VLANs, STP, LLDP, LACP | Broadcast storms, STP loops, VLAN mismatch |
| L3 Network | IP routing, subnetting, BGP/OSPF | Route leaks, MTU mismatch, asymmetric routing |
| L4 Transport | TCP/UDP, port numbers, NAT | NAT exhaustion, TCP retransmissions, firewall state table |
| L7 Application | DNS, HTTP, TLS, application protocols | DNS resolution, certificate errors, application performance |

### Three-Tier vs Spine-Leaf Architecture

| Architecture | Best For | Trade-offs |
|---|---|---|
| Three-tier (core/distribution/access) | Campus networks, <10K endpoints | Simple, well-understood, STP-dependent |
| Spine-leaf (Clos fabric) | Data centers, high east-west traffic | Predictable latency, no STP, requires VXLAN/EVPN |
| Collapsed core | Small sites, <500 endpoints | Cost-effective, fewer devices, single failure domain |

### IP Addressing Strategy

- Use RFC 1918 private addressing internally (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16)
- Size subnets for growth but avoid /8 broadcast domains
- Summarize routes at boundaries to reduce routing table size
- Document the IP plan in an IPAM tool (NetBox, Infoblox)
- Reserve space for future VPN, IoT, guest, and management networks

### Network Segmentation

| Method | Granularity | Use Case |
|---|---|---|
| VLANs + ACLs | Subnet-level | Basic segmentation, campus networks |
| VRF (Virtual Routing and Forwarding) | Routing-table-level | Multi-tenant, compliance isolation |
| Firewall zones | Zone-level | Security boundary enforcement |
| VXLAN/EVPN | Overlay network | Data center fabric, stretch VLANs without STP |
| Micro-segmentation | Workload-level | Zero trust, east-west traffic control |

## Subcategory Routing

| Request Pattern | Route To |
|---|---|
| **Routing & Switching** | |
| Cisco IOS-XE, Catalyst, ISR, ASR, SD-Access | the `cisco-ios-xe` skill |
| Cisco NX-OS, Nexus, VXLAN/EVPN data center | the `cisco-nxos` skill |
| Arista EOS, eAPI, CloudVision | the `arista-eos` skill |
| Juniper Junos, MX, QFX, EX, SRX, Apstra | the `juniper-junos` skill |
| Cisco Meraki, Dashboard, AutoVPN | the `meraki` skill |
| Aruba AOS-CX, CX switches, NAE | the `aruba-aoscx` skill |
| **Firewall / NGFW** | |
| Palo Alto PAN-OS, App-ID, Panorama | the `panos` skill |
| Fortinet FortiOS, FortiGate, Security Fabric | the `fortios` skill |
| Cisco FTD, Secure Firewall, Snort 3, FMC | the `cisco-ftd` skill |
| Cisco ASA, ASDM, legacy firewall | the `cisco-asa` skill |
| Check Point, SmartConsole, Quantum | the `checkpoint` skill |
| Sophos Firewall, XGS, Xstream | the `sophos-firewall` skill |
| pfSense, pfBlockerNG | the `pfsense` skill |
| OPNsense, Zenarmor | the `opnsense` skill |
| **DNS** | |
| Windows DNS Server, AD-integrated zones | the `windows-dns` skill |
| BIND, named.conf, zone files, DNSSEC | the `bind` skill |
| PowerDNS, DNSdist | the `powerdns` skill |
| Unbound, recursive resolver | the `unbound` skill |
| CoreDNS, Kubernetes DNS | the `coredns` skill |
| AWS Route 53, hosted zones, routing policies | the `route53` skill |
| Cloudflare DNS, proxy mode, 1.1.1.1 | the `cloudflare-dns` skill |
| Azure DNS, Private Resolver | the `azure-dns` skill |
| **VPN** | |
| IPsec, IKEv2, site-to-site VPN | the `ipsec` skill |
| WireGuard | the `wireguard` skill |
| OpenVPN | the `opnsense` or `pfsense` skill (OpenVPN server config; no standalone OpenVPN skill exists) |
| Cisco Secure Client (AnyConnect) | the `cisco-secure-client` skill |
| GlobalProtect (Palo Alto) | the `panos` skill (GlobalProtect is documented under its User-ID / VPN coverage; no standalone GlobalProtect skill exists) |
| **Load Balancing / ADC** | |
| F5 BIG-IP, iRules, LTM | the `f5-bigip` skill |
| NGINX, reverse proxy, Plus | the `nginx` skill |
| HAProxy | the `haproxy` skill |
| **SD-WAN** | |
| Cisco Catalyst SD-WAN | the `cisco-sdwan` skill |
| Fortinet SD-WAN | the `fortinet-sdwan` skill |
| **Wireless** | |
| Cisco Wireless, Catalyst 9800 WLC | the `cisco-wireless` skill |
| Aruba Wireless, AOS, Central | the `aruba-wireless` skill |
| Juniper Mist, Marvis AI | the `juniper-mist` skill |
| **Network Automation** | |
| Ansible Network, Terraform Network | the `network-automation` skill |
| NetBox, IPAM/DCIM | the `netbox` skill |

## Troubleshooting Methodology

1. **Define the problem** -- What exactly is failing? Who is affected? When did it start?
2. **Gather data** -- Ping, traceroute, interface counters, logs, SNMP, packet captures
3. **Isolate the layer** -- Start at L1 (physical), work up. Most problems are L1 (cable/optic) or L3 (routing/ACL).
4. **Form a hypothesis** -- Based on evidence, not guesses
5. **Test the hypothesis** -- Make ONE change, observe the result
6. **Document** -- Record the root cause and fix for future reference

## Anti-Patterns

1. **"Flat network"** -- No segmentation = unlimited blast radius. Segment by function, security zone, and compliance boundary.
2. **"Permit any any"** -- Overly permissive firewall rules defeat the purpose. Start deny-all, permit explicitly.
3. **"Static routes everywhere"** -- Use dynamic routing (OSPF/BGP) for anything beyond a simple stub network.
4. **"No documentation"** -- If it's not documented, it doesn't exist. Maintain network diagrams, IP plans, and change logs.
5. **"Spanning tree as a feature"** -- STP is a safety net, not an architecture. Design to minimize STP dependence.
6. **"DNS? Just use 8.8.8.8"** -- Internal DNS infrastructure matters. Don't rely solely on external resolvers for production.
