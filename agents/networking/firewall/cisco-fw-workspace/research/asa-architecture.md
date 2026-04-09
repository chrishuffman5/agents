# Cisco ASA Architecture — Deep Technical Reference

## Overview

The Cisco Adaptive Security Appliance (ASA) is a stateful firewall platform that predates FTD. ASA runs the **LINA engine** exclusively — the same code base that serves as the LINA component inside FTD. ASA does not include Snort; it relies on ACLs, stateful inspection, MPF (Modular Policy Framework), and optional add-on modules for advanced inspection.

ASA remains relevant in 2024–2026 for:
- Multi-context deployments (FTD does not support security contexts)
- High-density VPN concentrator deployments (per-connection VPN performance)
- Environments already running ASA where FTD migration is not yet justified
- Platforms that cannot run FTD (older hardware, licensing scenarios)

---

## ASA Packet Processing — Order of Operations

The ASA processes each new connection through the following sequence (for existing connections, the connection table is checked first, bypassing most steps):

```
[Ingress Interface]
       |
1.  Interface ACL (inbound) — permit/deny based on src/dst IP, port, protocol
       |
2.  Existing connection table check
    - If match → skip steps 3-8; go directly to egress
    - No match → continue
       |
3.  AAA (if auth-proxy configured) — user authentication check
       |
4.  NAT table lookup
    - Un-translate destination (DNAT/static NAT)
    - Mark for source translation on egress
       |
5.  Route lookup / forwarding decision
       |
6.  ACL check on translated addresses (if NAT changes the real address)
       |
7.  Inspection engine (MPF):
    - Class-map traffic matching
    - Policy-map action application
    - Application inspection (DNS, HTTP, FTP, SIP, H.323, SMTP, etc.)
    - Connection limits, rate limiting, TCP normalization
       |
8.  Connection created in state table
       |
   [ Egress Processing ]
       |
9.  Egress interface ACL (outbound) — if configured
       |
10. NAT translation (apply source NAT, DNAT finalization)
       |
11. Crypto map check (if VPN policy matches, encrypt and send)
       |
[Egress Interface / VPN Endpoint]
```

**Key principle**: For established connections, the ASA uses the connection table for fast forwarding — ACL and inspection do NOT re-run on every packet. This is fundamentally different from stateless packet filters.

---

## Security Levels

ASA interfaces are assigned **security levels** from 0 (lowest, typically outside/internet) to 100 (highest, typically inside/trusted).

### Default Traffic Rules Based on Security Level

| Traffic Direction | Default Behavior |
|---|---|
| Higher → Lower security (e.g., inside→outside) | Permitted by default; NAT may apply |
| Lower → Higher security (e.g., outside→inside) | **Denied** unless explicitly permitted by ACL |
| Same-level → Same-level | **Denied** unless `same-security-traffic permit inter-interface` is configured |

### Interface Security Level Assignment

```
interface GigabitEthernet0/1
 nameif inside
 security-level 100
 ip address 10.1.1.1 255.255.255.0
!
interface GigabitEthernet0/0
 nameif outside
 security-level 0
 ip address 203.0.113.1 255.255.255.0
!
interface GigabitEthernet0/2
 nameif dmz
 security-level 50
 ip address 172.16.1.1 255.255.255.0
```

Security levels drive implicit permit/deny logic. Explicit ACLs override security-level defaults.

---

## Interface Modes

### Routed Mode

- ASA acts as a Layer 3 router
- Each interface in a different IP subnet
- NAT typically required between inside and outside zones
- Supports all ASA features (VPN, ACL, MPF, failover, clustering)
- **Default mode** for all ASA deployments

### Transparent Mode

- ASA acts as a Layer 2 bridge (bump-in-the-wire)
- No IP addresses on data interfaces — management IP on a **BVI** (Bridge Virtual Interface)
- Layer 2 bridge groups pair interfaces (up to 250 interfaces per bridge group)
- Traffic is switched at L2; ASA applies security policy transparently
- Supports ACLs, MPF inspection, ARP inspection
- Does **not** support: NAT, routing protocols, DHCP server, VPN termination
- Useful for inserting ASA into existing networks without IP renumbering

### Multiple Context Mode

- ASA partitioned into multiple independent **security contexts** (virtual firewalls)
- Each context has: its own interfaces, ACLs, NAT, routing table, firewall rules
- System context (admin context) manages the physical chassis
- User contexts act as independent firewalls — separate management, separate configuration
- Supports both routed and transparent mode per context (not mixed in same ASA)
- Use cases: Service providers, multi-tenant environments, DMZ segmentation on single hardware
- **FTD does NOT support security contexts** — this is the primary reason to retain ASA in multi-tenant deployments
- Context limits vary by hardware: ASA 5545-X supports up to 50 contexts; ASA 5585-X supports up to 250

---

## Failover (High Availability)

### Active/Standby Failover

- Most common HA configuration
- **Active unit**: Processes all traffic; owns active IP and MAC addresses
- **Standby unit**: Identical hardware; synchronized; takes over when active fails
- **Failover link**: Dedicated interface for heartbeat and state replication (recommended: at least 100Mbps)
- **Stateful failover**: Active unit replicates:
  - Connection state table (TCP/UDP sessions)
  - NAT xlate table
  - ARP table
  - VPN tunnel state (IKE SAs, IPsec SAs)
  - Routing tables
- After failover: standby becomes active using same IP/MAC — clients do not reconnect
- VPN sessions survive failover without user reconnection (stateful VPN failover)
- Supported in both routed and transparent modes; single-context and multi-context

**Failover triggers**:
- Interface failure (configurable: N interfaces down triggers failover)
- Hardware failure
- ASA process crash
- Manual failover (`no failover active`)

### Active/Active Failover

- Both ASA units process traffic simultaneously (load sharing)
- **Requires multi-context mode**
- Security contexts divided into **two failover groups**
  - Group 1 active on ASA-1, standby on ASA-2
  - Group 2 active on ASA-2, standby on ASA-1
- Each failover group can independently fail over
- Result: Both units handling traffic, each as active for different contexts
- **VPN is only supported on the admin context** in active/active mode (a significant limitation for many designs)
- More complex configuration than active/standby; mainly used for load distribution across contexts

---

## Clustering

### ASA Clustering on Firepower 4100/9300

- Multiple ASA logical devices (on FXOS chassis) grouped as a single logical ASA
- Up to 16 nodes (e.g., 16 × 1 module, 8 × 2 modules, 4 × 4 modules)
- **Control node**: Handles management plane, routing protocol elections
- **Data nodes**: Forward traffic; share state via Cluster Control Link (CCL)
- Traffic load balanced via **Spanned EtherChannel** across all nodes
- Connection state replicated across nodes via CCL — sessions survive individual node failure

**VPN in Clustering**:
- **Centralized VPN mode**: All VPN connections go to control node only — no scalability benefit for VPN
- **Distributed VPN mode (IKEv2 S2S only)**: VPN connections distributed across data nodes — scales VPN capacity; requires premium VPN licensing

### Site-to-Site VPN in Clustering
- Distributed S2S IPsec IKEv2 VPN distributes sessions across cluster members
- Cannot distribute AnyConnect/remote access VPN across cluster (centralized to control node)

---

## Modular Policy Framework (MPF)

MPF is ASA's traffic-processing framework for applying quality-of-service, inspection, and connection controls. The three components are:

**1. Class-Map** — Traffic classifier
```
class-map MATCH_HTTP
 match port tcp eq 80
```

Common match criteria:
- `match access-list <acl_name>` — most flexible, L3/L4 matching
- `match port tcp eq <port>` — destination port
- `match default-inspection-traffic` — matches default inspection ports for all inspections

**2. Policy-Map** — Actions for matched traffic
```
policy-map GLOBAL_POLICY
 class MATCH_HTTP
  inspect http
 class inspection_default
  inspect dns
  inspect ftp
  inspect h323 h225
  inspect sip
```

Available actions:
- `inspect <protocol>` — application-layer inspection (protocol validation, embedded address translation)
- `set connection` — connection parameters (timeout, embryonic limits, TCP normalization)
- `police` — rate limiting
- `priority` — LLQ traffic queuing
- `drop` — discard matching traffic

**3. Service-Policy** — Binds policy to interface or globally
```
service-policy GLOBAL_POLICY global          ! Applies to all interfaces
service-policy INTERFACE_POLICY interface outside  ! Applies to one interface only
```

**Processing order**: Actions in a policy-map are applied in **predefined order** (not the order of class-maps within the policy). The order is: `set connection` → `inspect` → `police`.

Default inspection traffic (enabled in `class inspection_default` globally):
DNS, FTP, H.323, HTTP, ICMP, ICMP error, MGCP, NetBIOS, PPTP, RSH, RTSP, SIP, Skinny (SCCP), SNMP, SQLnet, SUNRPC, TFTP, XDMCP

---

## ASA 9.x Version Differences

### ASA 9.20

- **Released**: 2023
- New features:
  - Continued IKEv2 VPN enhancements
  - AnyConnect (Secure Client) certificate pinning improvements
  - BGP enhancements (additional address families)
  - Clustering improvements for Firepower 4100/9300
  - Distributed S2S VPN (IKEv2) in cluster mode — scales VPN sessions across cluster nodes
  - Enhanced SNMP MIBs for monitoring
  - TLS 1.3 support for management connections
- Platform: Continues support for Firepower 4100/9300, ASA 5500-X series

### ASA 9.22

- **Released**: 2024
- **Primarily a maintenance/patch release** — no major new features (per Cisco release notes)
- Security fixes and stability improvements
- Bug fixes for VPN, clustering, and interface handling
- Represents Cisco's shift to FTD for new feature development; ASA 9.x entering maintenance-only phase

### ASA 9.24

- **Released**: 2025 (release notes updated March 4, 2026)
- Concurrent milestone with planned FMC/FTD 10.0 release
- Security and platform maintenance
- Continued support for existing ASA deployments
- ASA 9.24.x represents the long-term sustaining release track for ASA-only deployments

### General ASA 9.x Policy (2023–2026)

Cisco has indicated that ASA 9.x is in a **sustaining engineering** mode:
- Security vulnerabilities addressed
- Critical bug fixes backported
- **No new feature development** planned for pure ASA code
- New firewall features exclusively developed for FTD
- ASA with FirePOWER Services (SFR module) is EOL; no new deployments

---

## ASDM (Adaptive Security Device Manager)

- Java-based GUI management application for ASA
- Can run as a web-launched applet or standalone launcher
- Provides all configuration capabilities equivalent to CLI
- ASDM runs locally on the ASA; administrator connects via HTTPS
- **Java dependency**: Requires compatible Java runtime; increasingly problematic with modern Java security policies
- **Not recommended** for complex environments; CLI or Cisco Defense Orchestrator preferred for scale
- ASDM version tracks ASA version (ASDM 7.20 aligns with ASA 9.20)

**ASDM access**:
```
http server enable
http 10.1.1.0 255.255.255.0 inside
asdm image disk0:/asdm-782.bin
```

---

## When ASA is the Right Choice vs FTD

### Use ASA When

| Requirement | Reason |
|---|---|
| **Multi-context (virtual firewalls)** | FTD does not and will not support security contexts; ASA multi-context is the only option |
| **Legacy hardware** | ASA 5500-X cannot run FTD 7.1+; still operational on ASA 9.x |
| **Complex multi-tenant service provider** | ASA contexts provide full policy isolation per tenant |
| **ASA-specific VPN features** | Some legacy VPN features (clientless WebVPN, certain DAP integrations) more mature on ASA |
| **Operational simplicity preference** | ASA CLI is simpler and more predictable for VPN-only use cases |
| **Regulatory/change freeze** | Stable ASA 9.x environment where FTD migration adds risk without benefit |

### Use FTD When

| Requirement | Reason |
|---|---|
| **Next-generation IPS** | Snort 3 with Talos intelligence; SnortML (7.6+) — not available on ASA |
| **Application visibility and control (AVC)** | Layer 7 application identification and policy enforcement |
| **URL filtering** | Category/reputation-based URL filtering requires FTD + license |
| **SSL/TLS decryption** | Decrypt-and-inspect for encrypted traffic |
| **Malware/file inspection** | AMP for Networks, file type blocking, SHA-256 cloud lookup |
| **User identity-based policy** | Identity policies, ISE integration, Azure AD integration |
| **Zero Trust / ZTNA** | Available on FTD 7.4+ (clientless ZTAA) and 7.7+ (universal ZTNA) |
| **Cloud-native management** | cdFMC, CDO, Terraform, Ansible automation |
| **New hardware** | All new Cisco Secure Firewall hardware runs FTD only |

---

## ASA Clustering vs FTD Clustering

| Feature | ASA Clustering | FTD Clustering |
|---|---|---|
| Platform | Firepower 4100/9300 (FXOS) | Firepower 4100/9300, 3100, 4200 (FXOS) |
| Max nodes | 16 | 16 |
| VPN scaling | Distributed S2S IKEv2 (9.20+) | Centralized only (no distributed VPN) |
| Management | ASDM per-node or CDO | FMC (single logical device) |
| Context support | Yes (multiple contexts per cluster) | No (no contexts in FTD) |
| SnortML/IPS | Not available | Available (Snort 3) |

---

## Sources

- [ASA Routed and Transparent Mode — Cisco 9.20](https://www.cisco.com/c/en/us/td/docs/security/asa/asa920/configuration/general/asa-920-general-config/interface-routed-tfw.html)
- [ASA Multiple Context Mode — Cisco 9.20](https://www.cisco.com/c/en/us/td/docs/security/asa/asa920/configuration/general/asa-920-general-config/ha-contexts.html)
- [ASA Failover HA — Cisco 9.19](https://www.cisco.com/c/en/us/td/docs/security/asa/asa919/configuration/general/asa-919-general-config/ha-failover.html)
- [ASA Active/Active Failover — networkstraining.com](https://www.networkstraining.com/cisco-asa-active-active-failover-configuration/)
- [ASA Active/Standby Failover — networklessons.com](https://networklessons.com/cisco/asa-firewall/cisco-asa-firewall-active-standby-failover)
- [ASA Modular Policy Framework — Cisco 9.2](https://www.cisco.com/c/en/us/td/docs/security/asa/asa92/configuration/firewall/asa-firewall-cli/mpf-service-policy.html)
- [MPF Overview — INE](https://ine.com/blog/2009-04-19-understanding-modular-policy-framework)
- [ASA 9.20 Release Notes — Cisco](https://www.cisco.com/c/en/us/td/docs/security/asa/asa920/release/notes/asarn920.html)
- [ASA 9.22 Release Notes — Cisco](https://www.cisco.com/c/en/us/td/docs/security/asa/asa922/release/notes/asarn922.html)
- [ASA 9.24 Release Notes — Cisco](https://www.cisco.com/c/en/us/td/docs/security/asa/asa924/release/notes/asarn924.html)
- [ASA New Features by Release — Cisco](https://www.cisco.com/c/en/us/td/docs/security/asa/roadmap/asa_new_features.html)
- [ASA VPN CLI Guide 9.20 — Cisco](https://www.cisco.com/c/en/us/td/docs/security/asa/asa920/configuration/vpn/asa-920-vpn-config/vpn-params.html)
- [Multi-Context FTD Discussion — Cisco Community](https://community.cisco.com/t5/network-security/multi-context-ftd/td-p/3094439)
- [BRKSEC-2239 Platform Deep Dive CiscoLive 2025](https://www.ciscolive.com/c/dam/r/ciscolive/emea/docs/2025/pdf/BRKSEC-2239.pdf)
