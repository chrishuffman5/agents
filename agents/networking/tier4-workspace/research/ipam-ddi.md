# IPAM/DDI Deep Dive — Infoblox + EfficientIP

## Overview

DDI (DNS, DHCP, IPAM) solutions provide centralized management of the three foundational network services that every device depends on. Enterprise DDI platforms add automation, audit trails, security intelligence, and API integration layers on top of the core services. The two dominant enterprise vendors are **Infoblox** and **EfficientIP**.

---

# INFOBLOX

## NIOS Overview

**NIOS (Network Identity Operating System)** is Infoblox's on-premises DDI operating system. Current major version: **NIOS 9.0** (9.0.1 through 9.0.6 as of April 2025). Runs on dedicated Infoblox hardware appliances, virtual appliances (VMware, KVM, Hyper-V, AWS, Azure, GCP), or cloud-based deployments.

---

## Grid Architecture

The Infoblox Grid is the fundamental deployment unit for on-premises NIOS:

### Grid Master (GM)
- Single authoritative management node for the entire Grid.
- Holds the master copy of all configuration data; distributes to all Grid Members.
- Hosts the Grid Manager GUI (web-based) and WAPI (REST API).
- Supports Grid Master Candidate (GMC) for high availability — GMC takes over automatically if GM fails.

### Grid Members
- Distributed service nodes running DNS, DHCP, and/or IPAM services.
- Receive configuration from GM via encrypted Grid replication protocol.
- Service DNS and DHCP queries locally; upload data/logs to GM.
- Can be physical appliances (IB-810, IB-1410, IB-2210, IB-4030) or virtual (vNIOS).

### Grid Replication
- All configuration changes made on GM replicate to all Members automatically.
- Replication is **database-level** (not zone transfer); ensures exact configuration parity.
- Delta replication for incremental changes; full sync on Member join.

### Reporting Members
- Dedicated Grid Member nodes for analytics, reporting, and log aggregation.
- Offloads reporting workload from service members.
- Generates compliance reports, DNS activity reports, DHCP utilization trends.

---

## DDI Services — DNS

- **Authoritative DNS** — Primary and secondary zones; supports BIND-compatible zone format.
- **Recursive/Caching DNS** — Unbound-based resolver for client queries; configurable forwarders.
- **DNSSEC** — Sign zones with NSEC3 opt-out; automated key rollover (ZSK/KSK); validation of upstream responses.
- **Response Policy Zones (RPZ)** — DNS firewall mechanism; intercept and rewrite responses based on threat intelligence or custom rules.
  - Data sources: Infoblox threat feeds, custom RPZ zone, external DNSBL feeds.
  - Actions: NXDOMAIN (block), NODATA, wildcard redirect, passthru (whitelist).
- **DNS64** — IPv6 transition; synthesize AAAA records for IPv4-only destinations.
- **Split DNS** — Different zone views for internal vs. external clients.
- **Scavenging** — Automatic cleanup of stale DNS resource records.

---

## DDI Services — DHCP

- **DHCP v4 and v6** — ISC DHCPd-based; full scope/pool management.
- **DHCP Fingerprinting** — Identify device type from DHCP option patterns (DHCP fingerprint database); tag leases with device class (Windows PC, iPhone, Cisco IP phone, printer, etc.).
- **Failover Pairs** — DHCP failover between two Grid Members (RFC 3074); active/standby or load-balanced modes.
- **DHCP Lease History** — Full audit trail of IP-to-MAC bindings; query by IP, MAC, or time range.
- **Fixed Addresses** — MAC-to-IP reservations; can trigger DNS record creation automatically.
- **Flexible Network Discovery** — Integrates DHCP lease data with IPAM to automatically update IP records.

---

## IPAM

- **Hierarchical IP Space Management** — Networks organized in tree by container/network/range hierarchy.
- **Subnet Management** — Allocate, split, merge subnets; track utilization per subnet.
- **IP Address Tracking** — Record owner, location, device, purpose, and custom extensible attributes per IP.
- **Automated Sync** — DHCP lease data, DNS records, and router ARP tables automatically populate IPAM records.
- **Conflict Detection** — Real-time detection of duplicate IPs, overlapping ranges.
- **Network Discovery** — SNMP-based discovery of active hosts; imports into IPAM.
- **Extensible Attributes** — Custom metadata fields applied to any IPAM object; supports automation workflows.

---

## WAPI (REST API)

WAPI (Web API) is Infoblox's RESTful API for NIOS:

- **Authentication** — HTTP Basic Auth or session cookie; HTTPS only.
- **Base URL**: `https://<grid-master>/wapi/v<version>/`
- **Current version**: 2.13+ (NIOS 9.0).
- **Resources** — Every DDI object accessible: network, host record, A/AAAA/PTR/CNAME records, DHCP range, fixed address, zone, view, RPZ rule, Grid member configuration.

```bash
# Get all networks
curl -k -u admin:password "https://gm.example.com/wapi/v2.12/network"

# Create an A record
curl -k -u admin:password -X POST "https://gm.example.com/wapi/v2.12/record:host" \
  -H "Content-Type: application/json" \
  -d '{"name":"server01.corp.example.com","ipv4addrs":[{"ipv4addr":"10.1.1.50"}]}'

# Search leases by MAC address
curl -k -u admin:password \
  "https://gm.example.com/wapi/v2.12/lease?hardware=aa:bb:cc:dd:ee:ff"

# Get next available IP in subnet
curl -k -u admin:password \
  "https://gm.example.com/wapi/v2.12/network/ZG5z.../next_available_ip"
```

---

## BloxOne DDI (SaaS)

**BloxOne DDI** is Infoblox's cloud-native DDI delivered as SaaS:

- Hosted in Infoblox cloud; no hardware or VM to manage.
- **On-Premises Data Connectors (OPDC)** — Lightweight agents deployed on-premises; proxy DNS/DHCP traffic to cloud-hosted service.
- **Universal DDI** — New (2025/2026) unified management portal combining NIOS Grid management and BloxOne DDI in a single interface.
  - Manage NIOS Grid members directly within Infoblox Portal.
  - Single API surface for both on-prem and cloud DDI.
- **Recent additions (Q2 FY26)** — Microsoft DNS/DHCP management, AWS and GCP Cloud IPAM discovery, external authoritative DNS zones.

---

## BloxOne Threat Defense (DNS Security)

- **DNS-layer security** — Blocks malicious domains via RPZ at DNS resolution time; no traffic redirection required.
- **Threat feeds** — Infoblox curated threat intelligence: malware, ransomware C2, DGA (Domain Generation Algorithm) detection, data exfiltration domains.
- **DGA Detection** — ML-based identification of algorithmically generated domain names used by malware for C2.
- **DNS tunneling detection** — Statistical analysis of DNS query patterns to detect covert data channels.
- **PDNS (Passive DNS)** — Historical DNS data for threat hunting; track domain resolution history.
- **Lookalike domain detection** — Homograph and typosquatting identification for brand protection.
- Managed from Infoblox Cloud Services Portal (CSP); integrates with SIEM and SOAR platforms.

---

## NetMRI (Network Change and Configuration Management)

- Infoblox NetMRI provides network automation and change management on top of DDI:
- **Device discovery and inventory** — SNMP-based; vendor-agnostic.
- **Configuration backup** — Scheduled capture of device configurations; diff comparison.
- **Compliance checking** — Policy rules evaluated against device configs; automated remediation.
- **Change automation** — Script execution across device fleet; uses Perl/Python and Infoblox's CCS scripting language.
- Now positioned as part of Infoblox's broader network automation portfolio.

---

# EFFICIENTIP

## SOLIDserver DDI Overview

EfficientIP's **SOLIDserver** is the integrated DDI appliance suite:

- Available as: physical appliances (hardware), virtual appliances (VMware, KVM, Hyper-V), cloud (AWS, Azure, GCP), and SaaS.
- Unified management console: **SOLIDserver EfficientIP Manager**.
- Architecture: primary + secondary appliance pairs; replicated database.

---

## IPAM Management

- **Smart IPAM** — Dynamic IP management with automated lifecycle; IPs automatically reserved, allocated, and released via integrations with DHCP and DNS.
- **VLAN / VRF Management** — Track VLAN-to-subnet mappings and VRF instances alongside IP addressing.
- **Extensible Custom Fields** — Tag IP objects with custom metadata for automation and CMDB integration.
- **Bulk Import** — CSV and Excel import for migrating existing IP spreadsheets.
- **Time-to-Live Tracking** — Monitor when IP assignments are due for review or renewal.
- **Network Discovery** — SNMP and ping-based discovery feeds IPAM automatically.

---

## DNS Service

- **Authoritative and recursive DNS** — Separate service roles; supports BIND-compatible zone management.
- **Multi-tenant DNS** — Separate DNS views per tenant or business unit.
- **DNSSEC** — Zone signing, key management, automated rollover.
- **Smart Architecture** — Distributed DNS caches close to users; centrally managed from SOLIDserver.
- **DNS Blast** — High-performance DNS appliance using hardware-accelerated processing; handles tens of millions of queries per second on dedicated hardware; 2M+ qps on virtual instances.

---

## DNS Guardian

DNS Guardian is EfficientIP's DNS security module:

- **DNS DDoS Protection** — Behavioral analysis to identify and mitigate volumetric DNS attacks; protects service continuity without blocking legitimate queries.
- **DNS Tunneling Detection** — Statistical analysis of query patterns (entropy, query length distribution, TTL anomalies) to detect covert channels used for data exfiltration.
- **Cache Poisoning Protection** — DNS transaction ID randomization; DNSSEC validation enforcement.
- **DGA Malware Detection** — ML-based identification of domain generation algorithm traffic.
- **Bot Detection** — Pattern recognition for bot-generated DNS query storms.
- **Countermeasures** — Automatic or manually triggered: query rate limiting, client blacklisting, sinkholing, selective blocking.
- Operates at the DNS Blast hardware level for maximum performance.

---

## SaaS DDI

- **EfficientIP Cloud DDI** — Fully SaaS-delivered DDI; EfficientIP manages infrastructure.
- **Hybrid Deployment** — Mix of cloud-managed and on-premises appliances; unified management.
- Suitable for organizations with limited on-prem infrastructure capacity.
- DNS Guardian available in SaaS mode.

---

## ITSM and Automation Integrations

EfficientIP SOLIDserver integrates with enterprise automation and ITSM tooling:

- **ServiceNow** — Native connector for IPAM request/fulfillment workflows; IP allocation triggered by ServiceNow tickets.
- **Ansible** — `EfficientIP.solidserver` Ansible collection for DNS/DHCP/IPAM automation.
- **Terraform** — `efficientip/solidserver` Terraform provider; manage networks, DNS zones, DHCP subnets as IaC.
- **Infoblox Competitive Migration** — EfficientIP provides migration tooling from Infoblox NIOS data export formats.
- **REST API** — Full API coverage of SOLIDserver configuration; JSON over HTTPS; OAuth2/Basic Auth.
- **IPAM webhook triggers** — Push notifications to external systems when IP allocations change.

---

## Infoblox vs EfficientIP Comparison

| Dimension | Infoblox NIOS / BloxOne | EfficientIP SOLIDserver |
|---|---|---|
| Architecture | Grid (GM + Members) + SaaS (BloxOne) | Primary/Secondary appliance + SaaS |
| Threat Defense | BloxOne Threat Defense (extensive) | DNS Guardian (strong DDoS/tunneling focus) |
| API | WAPI (mature, REST) + newer Universal DDI API | REST API + ecosystem connectors |
| IaC Support | Terraform + Ansible (mature ecosystem) | Terraform + Ansible |
| DNSSEC | Full (ZSK/KSK automation) | Full |
| DDoS Defense | RPZ + DNS security feeds | DNS Guardian (hardware-accelerated) |
| Multi-tenancy | Views + MDM-style domains | Multi-tenant architecture |
| Market Position | Dominant enterprise DDI | Strong European market; DDoS specialization |
| SaaS Option | BloxOne DDI (mature) | EfficientIP Cloud DDI |

---

## References

- [Infoblox NIOS DDI Product Page](https://www.infoblox.com/products/nios/)
- [NIOS 9.0 What's New](https://docs.infoblox.com/space/nios90/318210347)
- [Infoblox Universal DDI Q2 FY26 Innovations](https://www.infoblox.com/blog/company/november-2025-january-2026-innovations-whats-new-in-infoblox-ddi/)
- [BloxOne Threat Defense](https://infoblox-docs.atlassian.net/wiki/spaces/BloxOneThreatDefense/pages/35369418/What+s+New+in+Infoblox+Threat+Defense)
- [EfficientIP SOLIDserver DDI](https://efficientip.com/products/solidserver-ddi/)
- [EfficientIP DNS Guardian](https://efficientip.com/)
