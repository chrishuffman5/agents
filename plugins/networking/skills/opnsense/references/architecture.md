# OPNsense Architecture Reference

## HardenedBSD Base

OPNsense uses HardenedBSD, a security-hardened fork of FreeBSD:

### Security Features
- **SafeStack** -- Compiler-based separation of safe and unsafe stack regions; protects against stack-based control-flow attacks
- **W^X (Write XOR Execute)** -- Memory pages cannot be simultaneously writable and executable; prevents code injection
- **ASLR (Address Space Layout Randomization)** -- Randomizes process memory layout; stronger implementation than stock FreeBSD
- **PIE (Position-Independent Executables)** -- All system binaries compiled as PIE; required for ASLR effectiveness
- **CFI (Control Flow Integrity)** -- Forward-edge CFI protection on key system binaries; prevents function pointer hijacking
- **RELRO (Relocation Read-Only)** -- ELF binary hardening; GOT (Global Offset Table) marked read-only after relocation

### Patch Management
- HardenedBSD team tracks security patches independently from FreeBSD
- Often patches applied faster than upstream FreeBSD stable branch
- OPNsense release cycle: bi-annual major (January, July) + monthly minor/security releases

## MVC/API Architecture

### Framework
- **Language**: PHP 8.x
- **MVC Framework**: Phalcon (C-extension PHP framework; high performance)
- **Configuration Store**: XML file (`/conf/config.xml`)
- **Database**: No SQL database; configuration is XML-based with in-memory processing
- **Web Server**: Lighttpd (lightweight HTTP server)

### API Design Principles
- **REST conventions**: GET (read), POST (create/action), PUT (update), DELETE (remove)
- **Authentication**: API key + API secret pair; HMAC-based authentication
- **Per-user keys**: Generated in System > Access > Users; each key inherits user's privilege group
- **Response format**: JSON
- **Versioning**: API endpoints are versioned; backward compatibility maintained within major versions

### API Coverage (26.1)
| Domain | Endpoints |
|---|---|
| Firewall rules | `/api/firewall/filter/*` |
| Firewall aliases | `/api/firewall/alias/*` |
| NAT | `/api/firewall/source_nat/*`, `/api/firewall/destination_nat/*` |
| Interfaces | `/api/interfaces/*` |
| Routing | `/api/routes/*` |
| VPN (IPsec) | `/api/ipsec/*` |
| VPN (OpenVPN) | `/api/openvpn/*` |
| VPN (WireGuard) | `/api/wireguard/*` |
| DHCP | `/api/dhcpv4/*`, `/api/dhcpv6/*` |
| DNS (Unbound) | `/api/unbound/*` |
| IDS/IPS (Suricata) | `/api/ids/*` |
| Certificates | `/api/trust/*` |
| Users | `/api/auth/*` |
| High Availability | `/api/carp/*` |
| Diagnostics | `/api/diagnostics/*` |

### Configuration Lifecycle
1. API call modifies configuration in memory
2. Changes written to `/conf/config.xml`
3. **Apply** endpoint called to reload affected service
4. Service reads updated configuration and applies

```
POST /api/firewall/filter/addRule -> modifies config
POST /api/firewall/filter/apply   -> reloads pf rules
```

## Suricata v8 Integration

### Inline Mode (divert sockets)
OPNsense 26.1 introduces true inline IPS using FreeBSD divert sockets:

- **divert(4)** -- FreeBSD kernel mechanism that redirects packets to userspace and allows modified packets to be reinjected
- **Packet flow**: pf rule diverts matching traffic to Suricata -> Suricata inspects -> Suricata returns verdict (pass, drop, or modified packet) -> pf continues processing
- **Advantages over NFQUEUE**: Native FreeBSD mechanism; no Linux compatibility layer; lower overhead; supports packet modification

### Detection and Prevention
- **Rule matching**: Multi-pattern matching engine (Hyperscan on x86_64)
- **Protocol parsers**: HTTP, TLS, DNS, SMTP, FTP, SSH, SMB, NFS, DCERPC, and more
- **File extraction**: Extract files from HTTP/FTP/SMTP streams for external analysis
- **Flow tracking**: Per-flow state machine for stateful inspection

### Rule Management
- **Rule sources**: Emerging Threats Open/Pro, OISF Suricata, abuse.ch, custom
- **SID management**: Enable/disable/suppress individual rules by SID
- **Auto-update**: Scheduled rule downloads with automatic Suricata reload
- **Categories**: Rules organized by threat category; enable/disable entire categories

### Logging
- **EVE JSON**: Primary structured log format; one JSON object per event
- **Event types**: alert, dns, http, tls, files, flow, smtp, ssh, stats
- **SIEM integration**: Forward via syslog to ELK Stack, Graylog, Splunk, Wazuh

## Unbound DNS Resolver

### Architecture
- Recursive DNS resolver (not forwarder by default)
- **DNSSEC validation**: Enabled by default; validates chain of trust from root
- Full resolver: contacts authoritative servers directly (bypasses upstream forwarders)
- Can be configured as forwarder to upstream resolvers with DoT/DoH

### DNS Privacy
- **DNS-over-TLS (DoT)**: Encrypt DNS queries to upstream resolvers (port 853)
- **DNS-over-HTTPS (DoH)**: Encrypt DNS queries over HTTPS (port 443)
- Both prevent ISP/network operator DNS snooping

### Blocklists (26.1)
- Integrated DNS-based blocking for ad, malware, and tracking domains
- **Source selection**: Choose which blocklist sources from the GUI
- Response for blocked domains: NXDOMAIN or redirect to block page
- Complementary to (not replacement for) Suricata IDS/IPS

### Advanced Features
- **Host Overrides**: Custom A/AAAA/CNAME records for internal hosts
- **Domain Overrides**: Forward specific domains to designated DNS servers (split-DNS)
- **DNS64**: Synthesize AAAA records from A records for IPv6 transition
- **Access Control**: Define which clients can use the resolver
- **Custom options**: Pass arbitrary Unbound configuration directives

## FRRouting (FRR) Plugin

### Architecture
FRR is a suite of routing protocol daemons:
- **zebra**: Routing table manager; interfaces with kernel routing table
- **bgpd**: BGP (Border Gateway Protocol) daemon
- **ospfd / ospf6d**: OSPF v2 (IPv4) and v3 (IPv6) daemons
- **ripd / ripngd**: RIP v2 and RIPng daemons
- **bfdd**: BFD (Bidirectional Forwarding Detection) daemon
- **staticd**: Static route manager

### BGP Capabilities
- eBGP and iBGP with full route processing
- Route maps for policy-based route manipulation
- Prefix lists for route filtering
- Community manipulation (standard, extended, large)
- Route reflector and confederation support
- BFD integration for fast peer failure detection
- ECMP (Equal Cost Multi-Path) routing

### OSPF Capabilities
- Multi-area OSPF with area types (backbone, stub, NSSA, totally stub)
- Virtual links for non-contiguous backbone
- Route redistribution between OSPF and other protocols
- OSPFv3 for IPv6 routing

### Management
- **GUI**: OPNsense plugin pages for each protocol
- **vtysh**: FRR unified CLI shell for direct daemon interaction
- **API**: FRR plugin exposes API endpoints for programmatic management

### Use Cases
- Multi-site dynamic routing with OSPF/BGP
- ISP peering with eBGP
- SD-WAN underlay routing
- Datacenter fabric routing (EVPN/VXLAN with bgpd)

## Zenarmor (Sensei) DPI

### Architecture
- Runs as a plugin on OPNsense; uses netmap for high-performance packet capture
- L7 application identification engine (proprietary; 1000+ application signatures)
- Cloud-based URL categorization for web filtering
- Local analytics engine for reporting

### Capabilities
- **Application identification**: Identify applications regardless of port or encryption
- **Web filtering**: Category-based (social media, streaming, gambling, adult, etc.)
- **Threat intelligence**: Cloud-sourced feeds for malware, botnet, C2 domains
- **Per-user visibility**: Bandwidth usage and policy violation reports per user/IP
- **Policy enforcement**: Block or rate-limit by application or category

### Licensing
- **Free tier**: Basic application identification and limited categories
- **Pro tier**: Full category set, advanced reporting, cloud management
- **Enterprise tier**: Multi-device management, extended retention

## Host Discovery (hostwatch)

### Mechanism
- Passive monitoring of network traffic (ARP, DNS, DHCP, NDP)
- Builds device inventory without active scanning
- Per-interface monitoring; captures traffic on all monitored interfaces

### Data Collected
- MAC address
- IP address (IPv4 and IPv6)
- Hostname (via reverse DNS lookup or DHCP hostname option)
- First seen / Last seen timestamps
- Interface where device was discovered

### Use Cases
- Asset inventory for network visibility
- Detect rogue or unknown devices
- Complement DHCP lease tables (discovers statically addressed devices)
- Alert on new device appearance

## Plugin Ecosystem

### Plugin Architecture
- Plugins distributed as FreeBSD packages
- Install/remove via GUI (System > Firmware > Plugins) or CLI (`pkg install`)
- Plugin configuration integrates into OPNsense GUI and config.xml
- API endpoints provided by plugins follow same MVC/API pattern

### Core Plugins
| Plugin | Purpose | API |
|---|---|---|
| os-frr | Dynamic routing (BGP, OSPF, BFD) | Yes |
| os-haproxy | L7 load balancer / reverse proxy | Yes |
| os-nginx | Nginx reverse proxy / WAF | Yes |
| os-acme-client | Let's Encrypt automation | Yes |
| os-freeradius | 802.1X / RADIUS server | Yes |
| os-wireguard | WireGuard VPN (if not in base) | Yes |
| os-zerotier | ZeroTier overlay networking | Yes |
| os-telegraf | Metrics export to InfluxDB | Yes |
| os-netdata | Real-time monitoring dashboard | No (web only) |
| os-wazuh-agent | Wazuh SIEM integration | No |
| os-git-backup | Config versioning in Git | Yes |

### Plugin Development
- MVC pattern: Model (XML schema), View (Volt templates), Controller (PHP)
- API auto-generated from model schema
- Documentation: https://docs.opnsense.org/development/

## CARP / pfsync HA

### Same as pfSense (Shared Heritage)
OPNsense uses identical CARP/pfsync mechanism from FreeBSD:
- CARP protocol for VIP failover
- pfsync protocol for state table synchronization
- XMLRPC for configuration synchronization

### OPNsense-Specific Considerations
- HA configuration exposed via API (`/api/carp/*`)
- Plugin configurations must be manually verified for sync (not all plugins support config sync)
- FRR plugin: routing state not synced via pfsync; BGP/OSPF reconverges on failover
- Suricata state not synced; IDS/IPS re-inspects flows after failover

## WireGuard

### Kernel Module
- Native FreeBSD/HardenedBSD kernel module
- Kernel-space operation: significantly faster than userspace (wireguard-go)
- Cryptographic primitives: Curve25519 (DH), ChaCha20-Poly1305 (symmetric), BLAKE2s (hash), SipHash (hashtable)

### Configuration
- GUI: VPN > WireGuard
- API: `/api/wireguard/*`
- Per-instance: local port, private key, peers
- Per-peer: public key, allowed IPs, endpoint, keepalive

### Features
- Site-to-site and road warrior modes
- Multi-peer per instance
- IPv4/IPv6 dual-stack
- DNS push to peers
- Routing integration (kernel routes for allowed IPs)
- Killswitch: block all traffic except WireGuard tunnel

## IPv6 (26.1)

### Improvements in 26.1
- Multiple IPv6 stability and feature improvements
- Router advertisements fully MVC/API driven
- Dnsmasq default for DHCPv6/RA in client mode
- DNS64 support via Unbound

### Capabilities
- Full IPv6 firewall rules (pf supports IPv6 natively)
- DHCPv6 server and client
- SLAAC (Stateless Address Autoconfiguration) support
- IPv6 tunnel broker integration (6in4, 6to4, 6rd)
- NAT66 (IPv6-to-IPv6 translation)
- NPTv6 (Network Prefix Translation for IPv6)
