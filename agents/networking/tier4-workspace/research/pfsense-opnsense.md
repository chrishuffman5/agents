# pfSense + OPNsense Deep Dive

## Overview

pfSense (Netgate) and OPNsense are the two dominant open-source firewall distributions. Both are FreeBSD-based, GUI-driven, and support extensive feature sets rivaling commercial firewalls. They have diverged significantly in architecture and philosophy: pfSense leans commercial/enterprise with Netgate hardware; OPNsense is community-driven, API-first, and uses HardenedBSD for stronger security.

---

# PART 1 — pfSense

## pfSense Editions and Versioning

- **pfSense Plus** — Commercial edition from Netgate; optimized for Netgate hardware; subscription-based for non-Netgate installs. Current: **25.11** (November 2025), **25.11.1** (maintenance release).
- **pfSense CE (Community Edition)** — Free, open-source; runs on commodity hardware. Most recent: **2.8.x** (community-supported). CE lags behind Plus by several releases.
- **FreeBSD base** — Both Plus and CE run on FreeBSD; userland and kernel tune-ups from Netgate on top.
- Version scheme for Plus: `YY.MM` (year.month); CE retains `X.Y` versioning.

## 25.11 Key Changes

- Recommended secure server certificate lifetime lowered to **200 days** (from 398 days) — aligns with evolving CA/Browser Forum standards.
- OpenSSL updated; removes support for weak certificate properties (SHA-1, legacy TLS cipher suites).
- **IPv6 stability fix** — resolves oversized packet + TCP Segmentation Offload (TSO) interaction that could terminate connections originating from the firewall.
- Over **26 fixes and improvements** in 25.11.1 maintenance release.
- WireGuard implementation improvements and stability fixes.

## FreeBSD Base

- pfSense builds on **FreeBSD** (stable branch); inherits pf (packet filter) firewall, CARP, PF_INET6, and network stack.
- **pf** is the underlying packet filter for all firewall rules and NAT; pfSense wraps it with a PHP/HTML GUI.
- ZFS support for root filesystem (recommended for Netgate hardware).
- **poudriere** used internally for package builds.

---

## Web GUI

pfSense's administration interface (WebGUI) runs HTTPS on port 443 by default:

- **Dashboard** — Customizable widgets: interface status, traffic graphs, CARP status, gateway status, firewall logs.
- **Status Pages** — Real-time views for firewall states, DHCP leases, routing table, traffic graphs per interface.
- **Diagnostics** — Packet capture (tcpdump wrapper), traceroute, ping, DNS lookup, ARP table, NDP table.
- **System Logs** — Multi-category logging (firewall, DHCP, VPN, system, DNS resolver) with search and filter.
- Configuration backed up as XML; versioned config history; Netgate Global Config Sync for cloud backup.

---

## Firewall Rules

- Rules defined **per interface**, evaluated top-down; first match wins.
- Stateful inspection via pf; connection state tracked for TCP/UDP/ICMP.
- **Source/Destination** — single host, alias (group), network, FQDN (resolved at rule load).
- **Aliases** — named groups of IPs, networks, or ports; single alias reference in rules; updated via API or import.
- **Floating Rules** — applied across all interfaces; supports bidirectional match and `quick` keyword for early exit.
- **Schedule-based Rules** — apply rules during defined time windows.
- **Advanced Options** — TCP flags, OS fingerprinting, max connections, gateway override per rule.

---

## NAT

- **Port Forward (Destination NAT)** — inbound; maps external port to internal host:port; auto-creates associated firewall rule.
- **Outbound NAT** — four modes: Automatic, Hybrid, Manual, Disabled. Manual mode: full control over NAT rules evaluated top-down.
- **1:1 NAT** — Static bidirectional mapping of external IP to internal IP; no port restriction.
- **NAT Reflection** — Allows internal hosts to reach port forwards by internal name; modes: NAT+proxy, pf, disabled.
- pfSense transparently handles NAT state for ClusterXL-equivalent CARP failover.

---

## VPN

### OpenVPN
- SSL/TLS-based VPN; client-to-site and site-to-site modes.
- Multiple concurrent servers and clients; full PKI via pfSense's integrated CA manager.
- IPv4/IPv6 dual-stack tunnel; push routes, DNS, and custom options to clients.
- **OpenVPN Client Export** package generates platform-specific configuration bundles.

### WireGuard
- Built into pfSense Plus (since 2.5); modern cryptography (Curve25519, ChaCha20-Poly1305, BLAKE2s).
- Site-to-site and road warrior modes.
- Configured via GUI or API; peers managed as firewall aliases.
- Lower CPU overhead and faster handshake than OpenVPN.

### IPsec
- IKEv1 (aggressive/main mode) and IKEv2 (standard for modern deployments).
- Pre-shared key or certificate (EAP, RSA) authentication.
- Phase 1 (IKE SA) and Phase 2 (IPsec SA) fully configurable from GUI.
- Mobile IPsec for iOS/Android/Windows native VPN clients.
- **strongSwan** as the underlying IKE daemon.

---

## Packages

pfSense's package system extends functionality via the Package Manager:

### pfBlockerNG
- DNS-based and IP-based blocking; DNSBL (DNS Block List) + IP feeds.
- Integrates with Unbound DNS Resolver; blocks ads, tracking, malware domains.
- GeoIP blocking via MaxMind; customizable block page.
- Python-based v3 (pfBlockerNG-devel); significant performance improvements.

### Suricata
- Full IDS/IPS; inline mode (blocks) or IDS mode (alerts only).
- Rules from Emerging Threats, Snort Community, or custom.
- Eve JSON logging; integration with ELK/Splunk.
- Multiple interfaces supported; per-interface rule sets.

### Snort
- Alternative IDS/IPS to Suricata; older but widely supported rule ecosystem.
- Inline (NFQUEUE) or promiscuous mode.

### HAProxy
- Layer 7 load balancer and reverse proxy; SSL termination, ACL-based routing.
- Health checks; sticky sessions; frontend/backend model.
- Widely used for publishing internal services with TLS.

### Squid
- HTTP/HTTPS proxy for web filtering and caching; integrates with SquidGuard for URL categorization.
- SSL inspection (bump) for HTTPS visibility.
- WCCP support for transparent proxy deployments.

---

## CARP High Availability

**CARP (Common Address Redundancy Protocol)** provides pfSense HA:

- **Virtual IPs (VIPs)** — Shared IP addresses floated between active and standby nodes; interfaces use CARP type VIP.
- **Master / Backup election** — Based on advertisement skew; lowest skew = master.
- **pfsync** — Synchronizes firewall state tables between nodes over a dedicated sync interface; connections survive failover.
- **Config Sync (XMLRPC)** — Primary pushes full configuration to secondary; keeps both nodes in sync.
- **Failover trigger** — CARP advertisement timeout; configurable preempt and demotion counters.
- Load balancing: NOT built into pfSense CARP (active/passive only); HAProxy or DNS load balancing used for multi-active.

---

## VLAN

- 802.1Q VLAN tagging supported on any physical interface.
- VLAN sub-interfaces created under Interfaces > VLANs.
- Each VLAN assigned as a pfSense interface; receives its own firewall rule tab, DHCP server, etc.
- Inter-VLAN routing through pfSense (acts as L3 gateway for each VLAN).
- VLAN filtering on Netgate hardware tested and supported; commodity NICs may vary.

---

## Traffic Shaping

### ALTQ (Legacy)
- BSD-native queuing disciplines: HFSC, PRIQ, CBQ, FAIRQ.
- Per-interface; flow classification via firewall rules with assigned queues.
- Limitation: does not work with multi-queue NICs or LAGG.

### Limiters (dummynet)
- Per-connection or per-IP bandwidth caps; download and upload separately.
- Used via firewall rule advanced options; does not require ALTQ.
- Simpler than ALTQ; less granular QoS but more compatible with modern NICs.

---

## Netgate Hardware

Netgate designs hardware purpose-built for pfSense Plus:

- **Netgate 1100 / 2100 / 4100** — SOHO/branch; ARM-based; fanless.
- **Netgate 6100 / 8200** — Mid-range; Intel Atom/Core; 2.5/10 GbE ports.
- **Netgate 4200 / 7100** — Enterprise; multi-core x86; SFP+ connectivity.
- **Netgate 1537 / 1541** — DC edge; dual PSU; up to 25 GbE.
- All ship pre-loaded with pfSense Plus; Netgate Global Support subscription available.

---

# PART 2 — OPNsense

## OPNsense Overview

OPNsense forked from pfSense CE in 2015, developed by Deciso (Netherlands). Philosophy: API-first, community-governed, security-hardened, modular plugin ecosystem. Current release: **26.1 "Witty Woodpecker"** (January 2026).

---

## 26.1 Key Features

- **Full Firewall MVC/API** — Automation rules promoted to new MVC-based rules GUI; nearly all firewall configuration manageable via REST API.
- **Suricata v8 with Inline Inspection ("divert" mode)** — Uses FreeBSD `divert` sockets for true inline IPS with packet modification capability; significantly more efficient than prior NFQUEUE approach.
- **IPv6 Reliability Improvements** — Multiple IPv6 stability and feature improvements; router advertisements now fully MVC/API driven.
- **Default IPv6 Mode using Dnsmasq** — Client connectivity improved; Dnsmasq now default for DHCPv6/RA in client mode.
- **Unbound Blocklist Source Selection** — Users choose which blocklist sources to use from the GUI; no manual file management.
- **hostwatch (Host Discovery)** — Automatic host discovery service (enabled by default since 25.7.11); builds device inventory from passive traffic observation.
- **Shell Command Escaping Revamp** — Full audit and fix of shell command escaping across all plugins; security hardening.
- **Firewall NAT Rename** — "Port Forwarding" renamed to "Destination NAT" for terminology accuracy.
- **Firewall Rule Associations Removed** — Legacy associated rule links replaced by independent editable rules.

---

## HardenedBSD Base

- OPNsense uses **HardenedBSD** (security-hardened FreeBSD fork) instead of stock FreeBSD.
- Key HardenedBSD security features:
  - **SafeStack** — Compiler-based protection against stack-based control-flow attacks.
  - **Non-executable memory (W^X enforcement)** — Memory regions cannot be simultaneously writable and executable.
  - **ASLR (Address Space Layout Randomization)** — Stronger than stock FreeBSD's implementation.
  - **PIE (Position-Independent Executables)** — All system binaries compiled as PIE for ASLR effectiveness.
  - **CFI (Control Flow Integrity)** — Forward-edge CFI protection on key binaries.
  - **RELRO (Relocation Read-Only)** — ELF security hardening.
- Security patches tracked independently by HardenedBSD team; often faster than upstream FreeBSD.

---

## MVC/API Architecture

OPNsense's distinguishing characteristic is its **MVC (Model-View-Controller)** architecture:

- **Backend** — PHP 8.x MVC framework with Phalcon; all configuration stored in structured XML (`/conf/config.xml`).
- **REST API** — Nearly every configuration domain exposed as API endpoints; versioned and documented.
- **API Coverage (26.1)** — Firewall rules, NAT, aliases, interfaces, routing, VPN (IPsec, OpenVPN, WireGuard), DHCP, DNS (Unbound), IDS/IPS (Suricata), certificates, users, High Availability, and more.
- **Authentication** — API key + API secret (HMAC); per-user key generation from user management.
- **Format** — JSON request/response; RESTful HTTP methods (GET/POST/PUT/DELETE).

### Example API Calls
```bash
# List firewall aliases
curl -u "$KEY:$SECRET" https://fw.example.com/api/firewall/alias/searchItem

# Add a firewall rule
curl -X POST -u "$KEY:$SECRET" \
  -H "Content-Type: application/json" \
  -d '{"rule":{"type":"pass","interface":"lan","protocol":"tcp","source":{"net":"10.0.0.0/8"},"destination":{"net":"any"},"destination_port":"443"}}' \
  https://fw.example.com/api/firewall/filter/addRule

# Apply pending changes
curl -X POST -u "$KEY:$SECRET" \
  https://fw.example.com/api/firewall/filter/apply
```

---

## Suricata v8 Inline IPS

- OPNsense integrates **Suricata v8** as the primary IDS/IPS engine.
- **Inline mode via `divert`** — OPNsense 26.1 uses FreeBSD divert sockets; Suricata operates truly inline, able to drop and modify packets.
- **IDS mode** — Promiscuous capture; alerts only, no blocking.
- **Rule sources** — Emerging Threats Open/Pro, OISF Suricata Emerging Threats, custom rules, abuse.ch feeds.
- **EVE JSON logging** — Structured log output; integrates with ELK Stack, Graylog, Splunk via syslog.
- **Flow and file extraction** — Extract files from HTTP/FTP/SMTP for external analysis.
- Per-interface assignment; multiple Suricata instances possible.

---

## Unbound DNS

- **Unbound** is the default DNS resolver in OPNsense (recursive resolver with DNSSEC validation).
- **DNSSEC validation** enabled by default.
- **DNS-over-TLS (DoT)** and **DNS-over-HTTPS (DoH)** support for upstream queries.
- **Blocklists** — Integrated category-based DNS blocklists (26.1: source selection from GUI); DNSBL for ad/malware/tracking domains.
- **Host Overrides** — Local DNS records for internal hosts.
- **Domain Overrides** — Forward specific domains to internal DNS servers (split-DNS).
- **DNS64** — IPv6 transition mechanism; synthesize AAAA records for IPv4-only services.

---

## Zenarmor / Sensei DPI

- **Zenarmor** (formerly Sensei) is a commercial OPNsense plugin for advanced DPI.
- L7 application identification beyond Suricata's capabilities; identifies 1000+ applications.
- Web filtering with cloud-based categorization; social media, streaming, productivity controls.
- **Threat Intelligence feeds** from Zenarmor cloud; malware, botnet, C2 blocking.
- Analytics dashboard: per-user, per-application bandwidth and policy reports.
- Free tier available; Pro tier for advanced features and reporting.

---

## WireGuard

- Native WireGuard kernel module support (via HardenedBSD/FreeBSD kernel module).
- GUI configuration and API-managed; site-to-site and road warrior.
- **Kernel-space WireGuard** — significantly faster than userspace implementations.
- Multi-peer support; DNS push; IPv4/IPv6 dual-stack.
- Killswitch/routing integration for full-tunnel road warrior setups.

---

## FRR — BGP, OSPF, and More

- **FRRouting (FRR)** plugin provides dynamic routing protocol support.
- **BGP** — eBGP and iBGP; route maps, prefix lists, community manipulation; suitable for SD-WAN, datacenter, or ISP connectivity.
- **OSPF / OSPFv3** — Internal dynamic routing for multi-site OPNsense deployments; area design, redistribution.
- **RIP** — Legacy support.
- **BFD** — Bidirectional Forwarding Detection for fast failure detection.
- **EVPN/VXLAN** — Advanced datacenter routing (via FRR bgpd with L2VPN EVPN support).
- FRR configuration via OPNsense GUI or vtysh CLI; API-managed via FRR plugin API endpoints.

---

## Host Discovery

- **hostwatch** service (enabled by default in 26.1) passively monitors network traffic to discover hosts.
- Builds a device inventory: MAC address, IP, hostname (via reverse DNS), first/last seen timestamps.
- Populates the **Device List** in the GUI; useful for asset management and anomaly detection.
- Works per-interface; can trigger alerts on new unknown hosts.
- Complements DHCP lease tables with visibility into statically-addressed devices.

---

## Plugin Ecosystem

OPNsense community maintains an extensive plugin repository:

| Plugin | Function |
|---|---|
| os-acme-client | Let's Encrypt certificate automation |
| os-cicap | ICAP server for virus scanning |
| os-clamav | ClamAV antivirus (mail/proxy) |
| os-freeradius | FreeRADIUS 802.1X / RADIUS server |
| os-git-backup | Push configs to Git repository |
| os-haproxy | HAProxy load balancer |
| os-mdnsrepeater | mDNS across VLANs |
| os-netdata | Real-time system monitoring |
| os-nginx | Nginx reverse proxy / WAF |
| os-tayga | IPv6 NAT64 gateway |
| os-telegraf | Metrics collection to InfluxDB |
| os-tinc | Overlay VPN mesh |
| os-wazuh-agent | SIEM agent for Wazuh |
| os-zerotier | ZeroTier overlay network |

---

## pfSense vs OPNsense Comparison

| Dimension | pfSense Plus | OPNsense |
|---|---|---|
| License | Commercial (Netgate hardware) / subscription | Apache 2.0 / BSD |
| Base OS | FreeBSD | HardenedBSD |
| API Coverage | Partial (fauxapi plugin, limited native) | Near-complete REST API (MVC) |
| Release Cycle | Quarterly (Plus); slower (CE) | Bi-annual major + monthly minor |
| IDS/IPS | Suricata / Snort (packages) | Suricata v8 inline (core) |
| GUI Framework | PHP/Bootstrap (legacy) | PHP/Phalcon MVC |
| Community | Large, Netgate-backed forums | Active, community-driven; Deciso commercial support |
| Hardware | Netgate-optimized; commodity supported | Any x86_64 hardware; Deciso appliances |
| Dynamic Routing | FRR via package | FRR via plugin (well-integrated) |
| Security Posture | Standard FreeBSD hardening | HardenedBSD (SafeStack, ASLR, CFI, PIE) |
| ZTNA | No built-in ZTNA | No built-in ZTNA (plugins available) |
| Best For | Small/medium businesses, Netgate hardware buyers | API-driven automation, security-focused orgs, enterprises |

---

## References

- [pfSense Plus 25.11 Release Notes](https://docs.netgate.com/pfsense/en/latest/releases/25-11.html)
- [pfSense Plus 25.11.1 Release Notes](https://docs.netgate.com/pfsense/en/latest/releases/25-11-1.html)
- [OPNsense 26.1 "Witty Woodpecker"](https://docs.opnsense.org/releases/CE_26.1.html)
- [OPNsense Roadmap](https://opnsense.org/roadmap/)
- [pfSense Plus 25.11 Forum Announcement](https://forum.netgate.com/topic/199540/now-available-pfsense-plus-25.11-release)
- [OPNsense vs pfSense 2026 Comparison — DiyMediaServer](https://diymediaserver.com/post/2026/opnsense-vs-pfsense-homelab-2026/)
