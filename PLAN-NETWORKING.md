# Networking Domain — Agent Library Inventory

Comprehensive inventory of networking technologies, versions, and proposed agent hierarchy. Expanded from PLAN.md Section 4 with full research.

---

## 1. Routing & Switching

### Enterprise / Campus

- **Cisco IOS-XE**
  - 17.12.x (Dublin LTS — security support ends Dec 2026, tech support ends Dec 2028)
  - 17.16.x (Standard Maintenance, 12-month support)
  - 17.18.x (current Standard Maintenance)
  - 26.x (new versioning scheme for next-gen Catalyst — emerging)
  - Platforms: Catalyst 9200/9300/9400/9500/9600 (campus), ISR 1000/4000 (routing), ASR 1000 (WAN edge)
  - Key areas: NETCONF/RESTCONF/YANG, SD-Access (LISP+VXLAN), Catalyst Center, Model-Driven Telemetry, Zero-Touch Provisioning, Guest Shell Python, EEM

- **Aruba AOS-CX**
  - 10.13.x (Long-Term Release)
  - 10.14.x (Short-Supported Release)
  - 10.15.x (current SSR — 1-year support)
  - Platforms: CX 6000/6100 (access), 6200/6300 (campus), 8000/8325/8360/8400 (core/DC), 10000 (DC SmartFabric)
  - Key areas: Linux-based, REST API, Network Analytics Engine (NAE), Aruba Central, VSX active-active, EVPN-VXLAN, Dynamic Segmentation with ClearPass

### Data Center

- **Cisco NX-OS**
  - 10.4(7)M (prior maintenance)
  - 10.5(5)M (current recommended maintenance)
  - 10.6(1)F (current feature release)
  - Platforms: Nexus 9000 (spine/leaf), Nexus 7000 (core), Nexus 5600/3000 (ToR/access)
  - Key areas: VxLAN/EVPN, NX-API, ACI integration mode, Nexus Dashboard, streaming telemetry

- **Arista EOS**
  - 4.35.2F (current — 36-month support per train)
  - 4.30 EoS April 2026
  - Platforms: 7050/7060/7280/7300/7500/7800 (DC spine/leaf/core), 720XP/756 (campus)
  - Key areas: Linux-based (full bash/Python), eAPI (JSON-RPC), CloudVision (CVP/CVaaS), Studios, Pathfinder, streaming telemetry, EVPN-VXLAN, MLAG

- **Juniper Junos**
  - 24.2Rx (LTS — 3-year support)
  - 24.4Rx (current LTS candidate)
  - 25.4R1 (latest Junos Evolved)
  - Support model: even-numbered = 3yr, odd = 2yr
  - Platforms: MX (carrier/edge), QFX (DC switching), EX (campus), SRX (security)
  - Junos Evolved (Linux-based): PTX, ACX, QFX 5000-series, some MX
  - Key areas: MPLS, SR-MPLS, SRv6, EVPN-VXLAN, Apstra 6.0 (intent-based DC fabric), Mist AI, NETCONF (native first-class), commit/rollback config model, PyEZ

### Cloud-Managed

- **Cisco Meraki**
  - MX 19.2.7 / 26.1.3 (security appliances)
  - MS 18.1.6 (switches)
  - MR 32.2.2 (wireless APs)
  - Platforms: MX (SD-WAN/security), MS (switches), MR (Wi-Fi), MG (cellular), MV (cameras), MT (IoT)
  - Key areas: 100% cloud-managed (no CLI), Dashboard REST API v1, AutoVPN, webhooks, RBAC

---

## 2. Firewall / Next-Generation Firewall

- **Palo Alto PAN-OS**
  - 10.2 (EOL Sep 2026 — plan migration)
  - 11.1 (EOL ~May 2027)
  - 11.2 (EOL ~May 2027)
  - 12.1 "Orion" (current recommended — new 48-month support policy: 3yr standard + 1yr extended)
  - Platforms: PA-400/800/1400/3400/5400/7500, PA-5500 (Gen 5, PQC-capable), VM-Series, CN-Series, Cloud NGFW
  - Key areas: App-ID, Content-ID, User-ID, Device-ID, WildFire, Panorama, Strata Cloud Manager, AIOps, Prisma Access tie-in, IoT Security, PQC readiness (12.1)

- **Fortinet FortiOS**
  - 7.2 (approaching EOES — still supported)
  - 7.4 (EOES May 2026, EOS Nov 2027)
  - 7.6 (current recommended — EOES ~2027)
  - Platforms: FortiGate 40F–7000 series, FortiGate-VM, G-Series (SD-WAN optimized)
  - Key areas: Security Fabric (50+ products), ASIC acceleration (NP7, SP5/SoC5), SD-WAN native, ZTNA, FortiSASE, FortiManager/FortiAnalyzer, FortiGuard AI, FortiAI assistant (7.6), FortiClient unified agent

- **Cisco Secure Firewall Threat Defense (FTD)**
  - 7.2, 7.4 (maintained)
  - 7.6, 7.7 (current)
  - Management: FMC v10, FDM v10 (on-box), Cloud-Delivered FMC (CDO)
  - Platforms: Secure Firewall 1000/2100/3100/4100/4200, Firepower 9300, FTDv
  - Key areas: Snort 3 IPS engine, App visibility, AMP for Networks, Encrypted Traffic Analytics (ETA), Cisco XDR integration, migration from ASA via Firepower Migration Tool

- **Cisco ASA**
  - 9.20 (last version for Firepower 2100)
  - 9.22, 9.24 (current)
  - 9.16–9.19 End-of-Sale announced Nov 2025
  - Key areas: Legacy VPN-heavy deployments, ASDM management, migration path to FTD

- **Check Point**
  - R81.20 "Titan" (supported through Nov 2026)
  - R82 (current recommended)
  - Platforms: Quantum Security Gateways (3600–28000 series), Quantum Maestro (hyperscale), Quantum Spark (SMB), CloudGuard (cloud)
  - Key areas: SmartConsole/SmartCenter, Multi-Domain Management, Infinity architecture, ThreatCloud AI (40+ AI engines), Autonomous Threat Prevention, IoT Protect, CloudGuard WAF/CSPM, Harmony (endpoint/SASE)

- **Sophos Firewall**
  - v21 (Oct 2024 — still supported)
  - v22 (current — Dec 2025)
  - Platforms: XGS Desktop (87w/107w/127w/136w), XGS rackmount series, Virtual (AWS/Azure/VMware/Hyper-V)
  - Note: XG Series hardware EOL March 2025 — XGS required for v21+
  - Key areas: Xstream architecture (TLS 1.3 inspection, FastPath), Synchronized Security (heartbeat with endpoint), Sophos Central management, ZTNA gateway, SD-WAN, v22 containerized services, AI/ML anti-malware, CIS benchmark health check

- **pfSense**
  - Plus 25.11.1 (current — Jan 2026)
  - CE 2.8.1 (Sep 2025)
  - FreeBSD-based, Netgate hardware (1100/2100/4200/6100/8200)
  - Key areas: pfBlockerNG, Suricata/Snort IDS/IPS, HAProxy, OpenVPN, WireGuard, CARP HA

- **OPNsense**
  - 26.1 "Witty Woodpecker" (current — Jan 2026)
  - Release cadence: two major per year (Jan + Jul)
  - HardenedBSD-based, full MVC/API architecture
  - Key areas: Suricata v8 inline IPS, REST API, Unbound DNS, Zenarmor/Sensei DPI, Host Discovery, WireGuard, FRR (BGP/OSPF), plugin ecosystem

---

## 3. Load Balancing / Application Delivery

- **F5 BIG-IP**
  - 17.1.3 (prior branch)
  - 17.5.x (current — latest 17.5.1.2)
  - Modules: LTM, GTM/DNS, ASM/Advanced WAF, APM, AFM
  - Key areas: iRules, iControl REST, BIG-IQ management, F5 Distributed Cloud (SaaS ADC/WAF)

- **NGINX**
  - OSS 1.29.x (current)
  - Plus R34 (EOS Apr 2026), R35 (current — Nov 2024)
  - R33+: mandatory JWT licensing
  - R35 features: post-quantum crypto, OCSP stapling in stream module
  - Key areas: Reverse proxy, L7 LB, API gateway, Ingress Controller for K8s, NGINX Unit, Management Suite

- **HAProxy**
  - 3.0 LTS (EOL 2029-Q2)
  - 3.2 LTS (newest — EOL 2030-Q2)
  - 3.3 stable (current — Nov 2025, EOL 2027-Q1)
  - Key areas: L4/L7 LB, SSL offload, stick tables, rate limiting, Kubernetes Ingress Controller, Enterprise edition (ADFSPIP, UDP, CAPTCHA modules)

- **Citrix NetScaler ADC**
  - 14.1 (current — recommended 14.1-47.48+)
  - Form factors: MPX (hardware), VPX (VM), CPX (container), SDX (multi-tenant)
  - File-based licensing EOL April 2026 — migrating to LAS
  - Key areas: AppExpert, NetScaler Console (formerly ADM), Kubernetes Ingress Controller, dual-tier CPX

- **Envoy Proxy**
  - 1.38.x (current dev)
  - Envoy Gateway v1.5+ (Kubernetes Gateway API)
  - Key areas: xDS APIs (LDS/RDS/CDS/EDS/SDS), WASM extensions, service mesh data plane (Istio, Consul), Gateway API

- **AWS ALB / NLB / GWLB** — managed
  - ALB (L7): host/path/header routing, WAF integration, Cognito auth, HTTP/2
  - NLB (L4): static IP per AZ, weighted target groups (Blue/Green), ultra-low latency
  - GWLB (L3): GENEVE encapsulation, third-party appliance insertion

- **Azure Application Gateway** — managed
  - V2 SKU (Standard_v2, WAF_v2): autoscaling, zone-redundant, static VIP
  - V1 SKU EOL April 28, 2026
  - Key areas: WAF v2 (OWASP CRS 3.1), URL-based routing, Key Vault integration

---

## 4. SD-WAN

- **Cisco Catalyst SD-WAN**
  - SD-WAN Manager 20.18.x (current), 20.15.x (N-1 LTS), 20.12.x (N-2 LTS)
  - IOS-XE edge: 17.15.x (current), 17.14.x, 17.12.x
  - Architecture: SD-WAN Manager / Controller (vSmart) / Validator (vBond) / Catalyst WAN Edge
  - Key areas: Application-aware routing, AppQoE, Catalyst Center integration

- **Fortinet SD-WAN**
  - Tied to FortiOS (current 7.6.x)
  - Architecture: FortiGate as edge, FortiManager orchestration, FortiAnalyzer analytics
  - Key areas: SASE integration (FortiSASE), ZTNA, FortiAI assistant, FortiClient unified agent

- **VMware VeloCloud (Broadcom)**
  - 5.2.4 LTS (stable — EOGS Mar 2027)
  - 5.4.x (Edge EOGS Feb 2026, EOTG Feb 2027)
  - Hardware: Edge 4100 (10x 1G + 8x 10G), Edge 5100 (25G/40G)
  - Architecture: VeloCloud Edge / Orchestrator (VCO) / Gateway (VCG), DMPO
  - Note: Broadcom acquisition creating licensing/support concerns; some customers migrating

- **Versa Networks**
  - VersaONE SASE platform (VOS — Versa Operating System)
  - Architecture: Versa Director, Versa Analytics, VOS data plane
  - Key areas: Integrated SD-WAN + SSE/SASE, single-platform ZTNA/SWG/CASB/FWaaS

- **Aruba EdgeConnect (HPE)**
  - Orchestrator 9.5.2 (current)
  - Silver Peak heritage, integrated into HPE Aruba Networking portfolio
  - Key areas: SD-WAN + WAN optimization, zone-based firewall, application QoS, Aruba Central management

---

## 5. Wireless / Wi-Fi

- **Cisco Wireless**
  - Catalyst 9800 WLC on IOS-XE 17.15.x / 17.18.x
  - Wi-Fi 7: CW917x APs (802.11be, GCMP-256)
  - Key areas: DNA Spaces (location/IoT analytics), Cisco AI Network Analytics, Meraki Cloud Monitoring integration (from 17.12.3), DNA Essentials/Advantage licensing

- **Aruba Wireless (HPE)**
  - AOS 10.7.x (current — managed via Aruba Central 2.5.8)
  - Wi-Fi 7: 730 Series APs (AP-734/735/754/755, 802.11be, up to 28.8 Gbps, dual 10G, dual IoT radios)
  - Key areas: AirMatch (AI channel/power), ClearPass integration (RADIUS, UEBA, WPA2-MPSK), Aruba Central cloud management

- **Juniper Mist**
  - Mist AI microservices cloud (continuous updates)
  - Marvis AI (conversational assistant), Marvis Minis (client-to-cloud monitoring)
  - Wi-Fi 7 APs supported, Mist Edge for on-prem tunneling
  - Key areas: AI-driven wireless, Wired Assurance (EX switch integration), WAN Assurance

---

## 6. Data Center Fabric & SDN

- **Cisco ACI**
  - APIC 6.1(4) (current)
  - Key areas: EPG/contract policy model, Nexus 9000 spine-leaf fabric, Multi-Site Orchestrator, CloudACI (AWS/Azure/GCP extension), APIC-G5 hardware

- **VMware NSX (Broadcom)**
  - NSX 4.2.1 (current — dropped "NSX-T" branding)
  - Now bundled in VMware Cloud Foundation (VCF); standalone perpetual licenses discontinued
  - Key areas: Distributed firewall, micro-segmentation, T0/T1 gateways, NSX Federation, VCF 9 platform

- **Nokia SR Linux**
  - 25.3 (current — YY.N versioning)
  - Key areas: Unmodified Linux kernel, YANG-modeled, gNMI/gRPC, NDK for custom apps, container-native, Kubernetes integration, Containerlab reference NOS

### Emerging / Open NOS

- **SONiC**
  - ~2025.11 (two major releases/year: May + November)
  - Gartner predicts 40%+ of large DC operators (200+ switches) will run SONiC by 2026
  - Key areas: Redis-based architecture, SAI (Switch Abstraction Interface), Broadcom/Marvell/Mellanox ASIC support, 4,250+ contributors, Linux Foundation governance

- **DENT**
  - DentOS 3.0 "Cynthia" (latest)
  - Linux kernel + switchdev model (no SAI layer), targeted at enterprise edge/retail/branch
  - Amazon uses DENT for Just Walk Out retail technology

- **P4 Programmable Switches**
  - Intel Tofino hardware: end-of-life for new designs (ceased development 2023)
  - Tofino P4 software open-sourced Jan 2025 (open-p4studio)
  - P4 language active under P4 Language Consortium; continues via Broadcom Thor, Marvell ASICs

---

## 7. Cloud Networking

- **AWS VPC** — managed
  - VPCs, subnets, security groups, NACLs, IGW, NAT Gateway
  - Transit Gateway (hub-and-spoke multi-VPC/account), PrivateLink (cross-region support), Gateway Load Balancer
  - VPC Encryption Controls (enforce in-transit encryption within/across VPCs, GA Nov 2025)

- **Azure Virtual Network** — managed
  - VNets, NSGs, Azure Firewall Premium, Private Link, Front Door (CDN+WAF)
  - Virtual WAN, ExpressRoute (400 Gbps Direct ports announced 2026), VPN Gateway (up to 20 Gbps)

- **Google Cloud VPC** — managed
  - Global VPC (subnets regional), Shared VPC, Cloud NAT, Cloud Armor, Cloud Interconnect
  - Network Connectivity Center (static routes, IPv4/IPv6 filtering, Private Service Connect)

---

## 8. VPN

- **IPsec (IKEv2)**
  - Standard protocol (RFC 7296), implemented across Cisco ASA/FTD, PAN-OS, FortiOS, StrongSwan
  - Key areas: Phase 1/Phase 2 negotiation, PFS groups, crypto profiles, site-to-site and remote access
  - Common interop issues: PFS mismatch (FortiGate #1 Phase 2 failure), SHA-256 cert incompatibility

- **WireGuard**
  - ~4,000 LoC kernel module, ChaCha20-Poly1305 / Curve25519 / BLAKE2s
  - ~940 Mbps vs OpenVPN ~480 Mbps; <100ms handshake
  - Dominant modern VPN protocol (Mullvad went WireGuard-only Jan 2026)
  - Key areas: Simple configuration, no cipher negotiation, UDP-only

- **OpenVPN**
  - 2.6.x community, Access Server (commercial)
  - Key areas: TCP/443 fallback (bypasses restrictive firewalls), legacy cipher flexibility, broad client ecosystem

- **Cisco Secure Client (AnyConnect)**
  - v5.1.14.145 (MR14, Feb 2026)
  - Rebranded from AnyConnect; cloud-managed via Cisco XDR
  - Key areas: SSL/IPsec VPN, ZTA with Trusted Network Detection (TND), posture assessment, ISE integration, ARM64 Windows 11

- **GlobalProtect (Palo Alto)**
  - App versions 6.x (active)
  - Key areas: Always-on VPN, HIP checks, Prisma Access integration, Prisma Access Agent (PAA) emerging

---

## 9. Network Automation & Programmability

- **Ansible (Network)**
  - ansible.netcommon v8.4.0; cisco.ios v10.x; requires ansible-core 2.18+
  - Collections: cisco.ios, cisco.nxos, junipernetworks.junos, arista.eos
  - Connection plugins: network_cli, netconf, httpapi

- **Terraform (Network)**
  - Providers: CiscoDevNet/aci, cisco-open/meraki, Palo Alto, Fortinet, F5, Infoblox
  - Meraki provider: best-effort bug fixes post-Jan 2026

- **Nornir**
  - 3.x (Python-native network automation framework)
  - Plugins: nornir_netmiko, nornir_napalm, nornir_jinja2
  - vs. Ansible: no DSL, multi-threaded, faster for large device sets

- **NAPALM**
  - Drivers: IOS, IOS-XR, NX-OS, EOS, JunOS, FortiOS
  - Workflow: get_config → load_merge/replace_candidate → compare_config → commit_config → rollback

- **Netmiko**
  - SSH library for 100+ network platforms
  - Handles vendor-specific SSH quirks (prompts, paging, enable mode)

- **Batfish**
  - Open source (AWS-sponsored), pre-deployment config validation
  - Supports: Arista, Cisco (IOS/NX-OS/XR), F5, Juniper, Palo Alto

- **NetBox**
  - v4.5.5 (current — Mar 2026, requires Python 3.12–3.14)
  - IPAM + DCIM, REST API + GraphQL, plugin ecosystem
  - 4.5: Cable Profiles, ownership model, bearer auth tokens

- **Cisco NSO (Crosswork)**
  - NSO 6.3+ (current)
  - 1,000+ device library, 150+ non-Cisco NEDs, YANG-driven service models

- **Arista CloudVision**
  - CloudVision 2025.1 (current)
  - Studios, Pathfinder, full-state streaming telemetry, Leaf-Spine Stack management

---

## 10. Network Monitoring

- **SolarWinds NPM**
  - NPM 2025.2 (current)
  - Modules: NetPath, PerfStack, NCM (Network Configuration Manager), NTA (Network Traffic Analyzer)

- **PRTG**
  - Sensor-based licensing (free up to 100 sensors)
  - Auto-discovery, flexible alerting, SMB-focused

- **LibreNMS**
  - v25.11.0 (Nov 2025, open source)
  - 10,000+ device library, SNMP auto-discovery, REST API

- **Kentik**
  - SaaS network observability — managed
  - Flow analytics (NetFlow/IPFIX/sFlow), BGP, synthetic tests, DDoS detection, AI insights

- **ThousandEyes (Cisco)**
  - Cisco ThousandEyes Digital Experience Assurance (rebranded 2025)
  - AI Assistant, SD-WAN capacity planning, OpenTelemetry export
  - Synthetic tests: BGP, HTTP, DNS, path visualization across internet/cloud/enterprise

---

## 11. IPAM / DDI

- **Infoblox**
  - NIOS 9.0.6 (current — LTS release train introduced)
  - BloxOne (SaaS DDI + Threat Defense)
  - Key areas: Grid architecture, DDI (DNS/DHCP/IPAM), BloxOne Threat Defense, NetMRI

- **NetBox** — see Network Automation section (v4.5.5, IPAM + DCIM)

- **EfficientIP**
  - SOLIDserver DDI (managed versioning)
  - Key areas: DNS Guardian (DNS security/DDoS), IPAM, SaaS DDI, DNS Intelligence Center

- **phpIPAM**
  - v1.7 (current, open source)
  - PHP/MySQL-based, subnet management, VLAN/VRF tracking, REST API

---

## 12. Network Testing & Validation

- **Keysight (Ixia)**
  - IxNetwork, IxLoad — enterprise traffic generation
  - Stateful/stateless testing, RFC 2544/Y.1564, protocol emulation (BGP, ISIS, OSPF, SR)
  - Note: Keysight acquired Spirent (Oct 2025, $1.46B)

- **Containerlab**
  - v0.73 (current — Feb 2026)
  - Container-based network topology emulation
  - Supports: Nokia SR Linux, Arista cEOS, Cisco XRd/CSR, FRR
  - macOS (ARM+Intel), Windows WSL2, sudo-less operation

---

## 13. DNS

### On-Premises / Self-Hosted

- **Windows DNS Server**
  - Tied to Windows Server 2016, 2019, 2022, 2025
  - 2016/2019: DNS policies, response rate limiting (RRL), zone-level statistics, DNSSEC signing
  - 2022: DoH client-side only (DNS client queries upstream over DoH; server does NOT serve DoH to clients), full DNSSEC zone signing
  - 2025: Server-side DoH support (added Feb 2026 cumulative update, disabled by default, PowerShell-only — no GUI yet)
  - Key areas: AD-integrated zones, aging/scavenging, conditional forwarders, stub zones, GlobalNames zone, DNS policies (query/zone/recursion), PowerShell `DnsServer` module

- **BIND (ISC)**
  - 9.18.x ESV (Extended Support — latest 9.18.48, EOL ~Jan 2026)
  - 9.20.x (current production — latest 9.20.22, supported ~2028)
  - 9.21.x (development/preview)
  - 9.16 EOL
  - 9.20 additions: DNS-over-TLS (DoT) forwarding, DoT in `nsupdate`, PROXYv2 protocol support
  - Planned: RBTDB removal in 9.22 (next stable)
  - Key areas: DNSSEC (inline signing, KASP key management), DoH, DoT, Response Policy Zones (RPZ), RRL, views (split-horizon), TSIG, catalog zones, DLZ, `named.conf`, `rndc`

- **PowerDNS**
  - Authoritative Server: 5.0.3 (stable), 4.9.12 (maintenance), 5.1.0-alpha1 (Mar 2026)
  - Recursor: 5.4.0 (current — Mar 2026, adds DNS cookies for outgoing), 5.0-5.2 maintenance
  - DNSdist: load balancer / DoH+DoT frontend / DNS firewall
  - Key areas: Backend flexibility (MySQL, PostgreSQL, SQLite, LDAP), automatic DNSSEC signing, REST API, Lua scripting (Recursor), RPZ, EDNS Client Subnet, PowerDNS Admin (web UI)

- **Unbound**
  - 1.24.x (current — 1.24.1 Oct 2025, 1.24.2 patches)
  - Open-source recursive/caching resolver (NLnet Labs)
  - Key areas: DNSSEC validation (root trust anchor built-in), DoT, DoH, local zones, access control, prefetching, aggressive NSEC caching, serve-expired, module architecture (Python, dynlib, ipset)
  - Integrations: pfSense/OPNsense default resolver, Pi-hole upstream, Firewalla

- **CoreDNS**
  - 1.13.2 (current — Dec 2025), 1.12.3 (prior)
  - Kubernetes default DNS since K8s 1.13+
  - 1.13.2: initial DoH3 (DNS-over-QUIC/HTTP3) support
  - Key areas: Plugin architecture (Corefile config), `kubernetes` plugin (service discovery), `forward`, `cache`, `loop`, `loadbalance`, NodeLocal DNSCache integration, custom Go plugins

### Cloud-Managed DNS

- **Azure DNS** — managed
  - Public DNS zones, Private DNS zones, Azure DNS Private Resolver (inbound/outbound hybrid resolution)
  - DNSSEC: GA for public zones only (private zones NOT supported)
  - Alias records (point to Azure resources), Traffic Manager integration, Azure Firewall DNS Proxy

- **AWS Route 53** — managed
  - Hosted zones (public/private), 8 routing policies (simple, weighted, latency, failover, geolocation, geoproximity, multivalue, IP-based)
  - DNSSEC signing (KSK via AWS KMS, ZSK managed by Route 53)
  - Route 53 Resolver: inbound/outbound endpoints, DNS Firewall (managed domain lists: malware/phishing/DGA/tunneling)
  - Route 53 Global Resolver (Preview Nov 2025): anycast resolver with DoH/DoT, split-DNS
  - Route 53 Profiles: share DNS configs across VPCs/accounts
  - Application Recovery Controller: multi-region failover

- **Cloudflare DNS** — managed
  - Authoritative DNS (fastest globally, 300+ anycast cities), 1-click DNSSEC, proxy mode vs DNS-only
  - Foundation DNS (Enterprise): 3 anycast groups, per-account/per-zone KSK/ZSK rotation, advanced analytics
  - Public resolvers: 1.1.1.1 (DoH/DoT), 1.1.1.2 (malware blocking), 1.1.1.3 (Families — malware + adult content)
  - DNS Firewall (Enterprise): anycast DNS proxy with caching + DDoS protection
  - Secondary DNS / Multi-provider DNS
  - Note: `cloudflared proxy-dns` removed Feb 2026 — migrated to native DoH client support

---

## Agent Count Estimates

| Subcategory | Tech Agents | Version Agents | Total |
|-------------|-------------|----------------|-------|
| Routing & Switching (6 platforms) | ~6 | ~10 | ~16 |
| Firewall / NGFW (8 platforms) | ~8 | ~12 | ~20 |
| Load Balancing / ADC (7 platforms) | ~7 | ~4 | ~11 |
| SD-WAN (5 platforms) | ~5 | ~3 | ~8 |
| Wireless / Wi-Fi (3 platforms) | ~3 | ~2 | ~5 |
| Data Center Fabric & SDN (6 platforms) | ~6 | ~3 | ~9 |
| Cloud Networking (3 platforms) | ~3 | ~0 | ~3 |
| VPN (5 platforms) | ~5 | ~2 | ~7 |
| Network Automation (9 tools) | ~9 | ~2 | ~11 |
| Network Monitoring (5 platforms) | ~5 | ~2 | ~7 |
| IPAM / DDI (4 platforms) | ~4 | ~1 | ~5 |
| Network Testing (2 tools) | ~2 | ~0 | ~2 |
| DNS (8 platforms) | ~8 | ~8 | ~16 |
| **Totals** | **~71** | **~49** | **~120** |

---

## Implementation Priority

### Tier 1 — Build First (highest impact, broadest use)
1. **Firewall/NGFW**: PAN-OS, FortiOS, Cisco FTD/ASA (every network has firewalls)
2. **Routing/Switching**: Cisco IOS-XE, NX-OS, Arista EOS (core infrastructure)
3. **DNS**: Windows DNS, BIND, Route 53, Cloudflare (every network needs DNS)
4. **VPN**: IPsec, WireGuard, Cisco Secure Client (universal remote access)

### Tier 2 — Build Next (enterprise infrastructure)
5. **SD-WAN**: Cisco Catalyst SD-WAN, Fortinet SD-WAN (WAN modernization)
6. **Load Balancing**: F5 BIG-IP, NGINX, HAProxy (application delivery)
7. **Wireless**: Cisco Wireless, Aruba, Mist (campus networking)
8. **Network Automation**: Ansible Network, Terraform Network, NetBox (NetOps)

### Tier 3 — Expand (data center & cloud)
9. **DC Fabric**: Cisco ACI, VMware NSX (data center SDN)
10. **Cloud Networking**: AWS VPC, Azure VNet, GCP VPC (cloud networking)
11. **Routing/Switching**: Juniper Junos, Aruba AOS-CX, Meraki (additional vendors)
12. **DNS**: PowerDNS, Unbound, CoreDNS, Azure DNS (additional DNS platforms)

### Tier 4 — Complete (specialized)
13. **Firewall**: Check Point, Sophos, pfSense, OPNsense
14. **Monitoring**: SolarWinds, ThousandEyes, Kentik, LibreNMS
15. **IPAM/DDI**: Infoblox, EfficientIP
16. **Emerging**: SONiC, Containerlab, DENT
17. **LB/ADC**: Citrix NetScaler, Envoy, cloud LBs
