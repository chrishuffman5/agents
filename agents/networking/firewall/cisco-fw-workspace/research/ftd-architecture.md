# Cisco FTD Architecture — Deep Technical Reference

## Overview

Cisco Firepower Threat Defense (FTD) is a unified software image combining two distinct processing engines:
- **LINA** — the legacy ASA (Adaptive Security Appliance) kernel, handles L2-L4 packet processing
- **Snort** — the network analysis and intrusion prevention engine (Snort 2 or Snort 3), handles deep packet inspection

These two engines are tightly coupled within a single software image, unlike the older ASA + FirePOWER Services module architecture where they communicated over an internal backplane.

---

## Dual-Engine Architecture

### LINA Engine

LINA is the ASA code embedded within FTD. It is responsible for:

- **Layer 2 processing**: MAC-address lookup, ARP, VLAN tagging/untagging
- **Routing**: Static routes, OSPF, BGP, EIGRP, RIP, PBR (Policy-Based Routing added in 7.4)
- **NAT**: Network Address Translation (auto-NAT and manual/twice-NAT)
- **VPN termination**: IPsec IKEv2 site-to-site, AnyConnect/Secure Client remote access, SSL VPN
- **Prefilter policy**: Fast-path decisions at L3/L4 before Snort sees the packet
- **Access control enforcement (L3/L4 portion)**: Trust/Block decisions based on IP, port, protocol before escalating to Snort
- **Stateful connection tracking**: TCP state machine, UDP pseudo-states, ICMP tracking
- **Hardware bypass / failsafe**: Bypass inline interfaces on power failure (hardware-dependent)

LINA runs as a process within FTD and is accessed in the `system support diagnostic-cli` mode. LINA produces syslog messages starting with `%ASA-` identifiers.

### Snort Engine

Snort performs Layer 7 deep packet inspection. It is responsible for:

- **Security Intelligence (SI)**: IP, URL, and DNS reputation blacklist/whitelist lookups
- **SSL/TLS policy**: Decrypt-and-inspect or Do-Not-Decrypt decisions for HTTPS/other encrypted flows
- **URL filtering**: Category- and reputation-based filtering (requires license)
- **Application identification (AppID)**: Identifies Layer 7 applications for ACP enforcement
- **Identity policy**: User and group-based access enforcement (ISE, AD, LDAP)
- **Access Control Policy (L7 portion)**: Rule matching using application, URL, user identity
- **IPS (Intrusion Prevention)**: Snort rules evaluation, signature-based and anomaly detection
- **File/Malware policy**: AMP for Networks, file type blocking, SHA-256 cloud lookups

**Critical behavior**: Snort does NOT drop packets directly. It returns a verdict (drop/allow/trust) to LINA. LINA then acts on that verdict. This architecture means Snort failure can result in traffic either passing or dropping depending on the `Fail Open` vs `Fail Close` configuration.

---

## Packet Flow — Detailed

```
[Ingress Interface]
       |
   [ LINA Ingress Processing ]
   - L2 processing (ARP, MAC, VLAN)
   - Route lookup
   - Prefilter policy check
     - FastPath → bypass Snort entirely (trust rule)
     - Block → drop immediately
     - Analyze → send to Snort
   - NAT (un-translate destination)
   - VPN decrypt (if IPsec/SSL inbound)
   - L3/L4 ACL check (deny → drop; permit → continue)
       |
   [ Snort Inspection ] (if policy requires)
   1. Security Intelligence — IP reputation check
   2. SSL Policy — decrypt or passthrough decision
   3. Security Intelligence — URL/DNS check (post-decrypt)
   4. Identity Policy — user authentication/matching
   5. Access Control Policy — L7 app/URL/user rules
   6. File/Malware Policy — file inspection, AMP lookup
   7. IPS Policy — Snort rule evaluation
   → Returns verdict to LINA
       |
   [ LINA Egress Processing ]
   - Apply Snort verdict (drop or forward)
   - NAT (translate source/destination for outbound)
   - VPN encrypt (if IPsec/SSL outbound)
   - Route to egress interface
   - L2 rewrite (MAC, VLAN)
       |
[Egress Interface]
```

### FastPath Optimization

When the Prefilter policy has a **FastPath** (Trust) rule matching L3/L4 criteria, packets bypass Snort entirely. Subsequent packets in the same flow also get FastPath treatment via connection table lookup. This is the highest-performance path.

### Connection Reuse

Once a connection is established and permitted, LINA uses its connection table for subsequent packets in that flow. ACL and Snort re-evaluation occurs only for new connections, not for packets matching existing established sessions.

---

## Snort 3 vs Snort 2

| Feature | Snort 2 | Snort 3 |
|---|---|---|
| Process model | Multiple processes, one per CPU core | Single multi-threaded process |
| Threading | Separate management + data threads per process | Single control thread + N detection threads |
| Memory model | Network maps loaded per-process (redundant) | Shared network maps across threads |
| Config format | Preprocessor-based (C-style) | Inspector-based (LUA scripting) |
| Rule format | Legacy Snort 2 rule syntax | Enhanced syntax + LUA scripting |
| Reload behavior | Full Snort restart on policy deploy | Reload (no restart) when possible — less disruption |
| SnortML | Not supported | Supported (7.6+) — ML-based exploit detection |
| Performance | Baseline | Significantly higher throughput with same resources |
| Custom rules | Text-format rule files | Text-format + LUA |
| Default engine | Pre-7.0 default | Default for new devices 7.0+, mandatory default 7.6+ |

**Snort 3 was introduced in FTD 6.7** (optional). It became **default for new devices in 7.0**. In **7.6, Snort 3 became the mandatory default** — new deployments cannot use Snort 2.

**Upgrade path**: Devices running Snort 2 can migrate to Snort 3 via FMC UI. Custom intrusion policies must be manually reviewed/re-mapped. Snort 2 custom rules need conversion.

---

## Deployment Modes

### Routed Mode (Default)

- FTD acts as a Layer 3 router/gateway
- Each interface in a separate IP subnet/zone
- NAT typically required between inside and outside
- Supports all FTD features (VPN, IPS, AVC, etc.)
- Most common production deployment

### Transparent Mode

- FTD acts as a Layer 2 bump-in-the-wire
- Bridge group interfaces — no IP addresses on data interfaces (management IP on BVI)
- No NAT required; traffic flows transparently
- Ideal for inserting FTD into existing networks without IP re-addressing
- Supports IPS, ACP, URL filtering in transparent mode
- Does NOT support VPN termination, DHCP server, or routing protocols natively
- Supports up to 250 bridge groups (hardware-dependent)

### Inline Sets (IPS Mode)

- Dedicated IPS deployment without full firewall functions
- Two interfaces paired in an inline set — acts as a bump on the wire
- Can operate in:
  - **Inline (active)**: Drop malicious traffic
  - **Tap mode**: Copy traffic for analysis; never drops — used for traffic profiling before going live
- Inline sets are independent of routed/transparent mode designation

### Passive (IDS Mode)

- Connected to SPAN/mirror port on a switch
- Traffic is copied to FTD for analysis only — no in-path enforcement
- FTD generates alerts/events but cannot block traffic
- Also supports ERSPAN (Encapsulated RSPAN) for distributed monitoring

---

## FMC (Firewall Management Center) Architecture

### On-Premises FMC

- Dedicated hardware appliance or virtual machine (FMCv)
- Central policy management for multiple FTD devices
- Manages: Access Control Policy, IPS Policy, NAT Policy, VPN, Platform Settings, FlexConfig
- **Requirement**: FMC version must be >= FTD version. FMC manages down to N-2 FTD versions in some cases.
- **Registration**: FTD registers to FMC via **sftunnel** — an encrypted tunnel over TCP **port 8305**
- **Communication**: Bidirectional; FMC pushes configs, FTD sends events/health data
- Stores all event/log data (intrusion events, connection events, file events, health events)
- FMCv form factors: VMware, KVM, Hyper-V, AWS, Azure, GCP, OCI

### sftunnel Registration Process

1. On FTD: `configure manager add <FMC_IP> <reg_key>` (reg_key is a one-time shared secret)
2. In FMC: Add device using same reg_key, specify NAT ID if behind NAT
3. sftunnel established over TCP 8305 (FTD initiates connection to FMC)
4. Certificate exchange; ongoing encrypted channel maintained
5. FMC pushes initial policy; FTD begins reporting events

### CDO / Cloud-Delivered FMC (cdFMC)

- **Cisco Defense Orchestrator (CDO)** is the SaaS platform (renamed Cisco Security Cloud Control in 2024)
- **cdFMC** (cloud-delivered FMC) runs as a SaaS offering within CDO
- FTD devices register to CDO, which provisions and connects them to cdFMC
- **No on-premises FMC hardware/VM required**
- Supports same policy types as on-premises FMC
- Requires FTD internet access to reach CDO/cdFMC (proxy support added in 7.6.1)
- Not suitable for air-gapped environments
- cdFMC manages FTD 7.2+ devices

### FDM (Firepower Device Manager)

- **On-box management** — web UI built into FTD itself
- No separate FMC required
- Suitable for small/single-device deployments
- Limitations vs FMC:
  - No multi-device management
  - No advanced correlation policies
  - No network discovery/asset mapping
  - Limited FlexConfig options
  - No multi-domain management
- FDM accessible via HTTPS on management interface (default port 443)
- CDO/Security Cloud Control can manage FDM-managed devices (limited policy sync)

---

## Policy Deployment Process (FMC)

When configuration changes are deployed from FMC to FTD:

**Phase 1 — Configuration Collection**
FMC collects all policy objects, rules, and settings relevant to the target device(s).

**Phase 2 — Package Build**
FMC compiles two separate configuration packages:
- **Snort configuration package**: IPS rules, network analysis policy, SI feeds, ACP L7 rules
- **LINA configuration package**: Interfaces, routing, NAT, VPN, prefilter, L3/L4 ACL

**Phase 3 — Transfer**
Package is transferred to FTD over sftunnel.

**Phase 4 — Device-Side Processing**
- FTD unpacks the archive
- Snort config is validated locally — if invalid, deployment fails here
- LINA config is applied via ngfwManager process
- If LINA apply fails, rollback occurs

**Phase 5 — Snort Reload/Restart**
- If Snort config changed: Snort reload (Snort 3) or restart (Snort 2)
- Snort 3 reload causes minimal traffic disruption (new connections use new config)
- Snort 2 restart causes brief inspection gap (traffic may pass or drop depending on fail-open/close)

**Phase 6 — Verification**
FTD reports success or failure back to FMC over sftunnel.

---

## High Availability

### Active/Standby Failover

- Two identical FTD units (hardware or virtual)
- One unit is **Active** (processes all traffic); one is **Standby** (synchronized but silent)
- Stateful failover: Active unit replicates connection state, NAT xlate table, VPN tunnels, routing tables to standby
- **Failover link**: Dedicated interface (LAN-based) for heartbeat and state replication
- **Standby link**: Can be shared with failover link or separate
- Triggers for failover:
  - Interface failure count exceeds threshold
  - >50% of Snort instances down on active unit
  - Disk usage >90% on active
  - Active unit heartbeat failure
- FMC manages HA pair as a single logical device (configuration deployed to both)
- VPN sessions survive failover (stateful replication)

### Clustering (Firepower 4100/9300)

- Multiple FTD nodes grouped as a single logical device
- Supported on Firepower 4100/9300 chassis running FXOS
- Up to **16 nodes** per cluster
- **Control node** handles management-plane traffic; **data nodes** handle traffic
- Spanned EtherChannel for ingress load balancing across nodes
- Cluster Control Link (CCL): Dedicated interface for inter-node state sharing
- Session state shared across cluster via CCL
- FMC manages cluster as single device

### Multi-Instance (Firepower 3100, 4100, 4200, 9300)

- Multiple independent FTD container instances on a single chassis
- Each instance has its own: FTD software image, management IP, separate FMC registration
- FXOS chassis supervisor allocates CPU, memory, interfaces per instance
- Instance-level HA: Each instance can have its own active/standby pair (using separate physical chassis)
- Introduced for Firepower 4100/9300 in 6.4; expanded to Secure Firewall 3100 in 7.4; to 4200 in 7.6

---

## Sources

- [Cisco FTD Packet Flow — Todd Lammle](https://www.lammle.com/post/cisco-firepower-threat-defense-ftd-packet-flow/)
- [Cisco FTD Firewall Packet Flow — Network Interview](https://networkinterview.com/cisco-ftd-firewall-packet-flow/)
- [LINA Rules with Snort Features — Cisco](https://www.cisco.com/c/en/us/support/docs/security/secure-firewall-threat-defense/218196-understand-how-lina-rules-configured-wit.html)
- [Firepower Data Path Troubleshooting Overview — Cisco](https://www.cisco.com/c/en/us/support/docs/security/firepower-ngfw/214572-firepower-data-path-troubleshooting-ove.html)
- [Snort 3 vs Snort 2 — Cisco](https://cisco-apps.cisco.com/c/en/us/support/docs/security/firepower-ngfw/217617-comparing-snort-2-and-snort-3-on-firepow.html)
- [Snort 3 Major Differences — blog.snort.org](https://blog.snort.org/2020/08/snort-3-2-differences.html)
- [Inline Sets and Passive Interfaces — Cisco FMC 7.0](https://www.cisco.com/c/en/us/td/docs/security/firepower/70/configuration/guide/fpmc-config-guide-v70/inline_sets_and_passive_interfaces_for_firepower_threat_defense.html)
- [FTD Device Registration — Cisco](https://www.cisco.com/c/en/us/support/docs/security/firepower-ngfw/215540-configure-verify-and-troubleshoot-firep.html)
- [Deploy cdFMC in CDO — Cisco](https://www.cisco.com/c/en/us/support/docs/security/defense-orchestrator/218171-deploy-a-cloud-delivered-fmc-in-cdo.html)
- [Policy Deployment Troubleshooting — Cisco](https://www.cisco.com/c/en/us/support/docs/security/firepower-ngfw-virtual/215258-troubleshooting-firepower-threat-defense.html)
- [FTD HA Configuration — Cisco](https://www.cisco.com/c/en/us/support/docs/security/firepower-management-center/212699-configure-ftd-high-availability-on-firep.html)
- [Multi-Instance HA on Firepower 4100 — Cisco](https://www.cisco.com/c/en/us/support/docs/security/secure-firewall-management-center-virtual/221625-configure-ftd-multi-instance-high-availa.html)
- [BRKSEC-3533 CiscoLive 2025](https://www.ciscolive.com/c/dam/r/ciscolive/emea/docs/2025/pdf/BRKSEC-3533.pdf)
