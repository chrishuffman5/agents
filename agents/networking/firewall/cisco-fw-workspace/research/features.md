# Cisco FTD and ASA Feature Reference

## FTD Features

### Access Control Policy (ACP)

The ACP is the primary security policy on FTD. It controls which traffic is allowed or blocked and specifies what inspection to apply.

**Structure**:
- **Rules**: Ordered list of permit/deny/trust rules; first match wins
- **Default action**: Applied when no rule matches (Intrusion Prevention or Block)
- **Rule actions**:
  - `Allow` — permit traffic; may apply IPS, file, and malware policy
  - `Trust` — permit without further deep inspection (LINA handles only)
  - `Block` — deny immediately; no further processing
  - `Block with Reset` — deny + send TCP RST
  - `Interactive Block` — present block page (HTTP only) with option for user override
  - `Monitor` — log but do not enforce; allow traffic to continue for rule evaluation

**ACP deployment to engines**:
- L3/L4 rules deployed as ACL to LINA
- L7 application/URL/user rules deployed as Snort rules to Snort engine
- Combined rules compile into both LINA ACL and Snort configuration

**Rule matching criteria**:
- Source/destination networks (host, subnet, range, object group)
- Source/destination ports/protocols
- VLAN tags
- Security zones (logical grouping of interfaces)
- Applications (Layer 7 AppID — requires Snort inspection)
- URL categories and reputations (requires URL Filtering license)
- Users and groups (requires Identity Policy integration)
- File types (for file policy attachment)

**ACP and Zone/Interface awareness**: Rules use **Security Zones** or **Interface Groups** for directional matching. Zone assignments are made per interface in the device configuration.

---

### Prefilter Policy

Prefiltering is evaluated **before** the ACP — it is the first check after LINA's initial packet handling.

**Purpose**: Offload simple L3/L4 trust/block decisions from Snort, improving performance by avoiding expensive deep inspection for known-good traffic.

**Rule actions**:
- `Fastpath`: Trust the connection; bypass Snort entirely. LINA handles all subsequent packets in the flow at hardware speed. No IPS, no file inspection, no URL filtering.
- `Block`: Deny at prefilter stage; never reaches ACP or Snort
- `Analyze`: Send to ACP for full processing (default for unmatched traffic)

**Match criteria**: Only outer-header L3/L4 information (no application, no URL, no user)

**Tunnel rules**: Prefilter can also define tunnel handling (GRE, IP-in-IP encapsulation) and determine whether to inspect the outer header, inner header, or both.

**When to use FastPath**:
- High-volume trusted traffic (e.g., backup jobs, internal replication)
- Traffic that does not need threat inspection (well-known internal services)
- Reducing Snort load on high-throughput paths

---

### IPS Policy (Snort 3)

The IPS Policy (Intrusion Policy) defines which Snort rules are active and how they are applied.

**Snort 3 Policy Structure**:
- Based on **base policies** (Talos-provided):
  - `Connectivity over Security`: Minimal rules; prioritizes connectivity
  - `Balanced Security and Connectivity`: Default for most deployments
  - `Security over Connectivity`: Maximum rules; aggressive blocking
  - `Maximum Detection`: All rules enabled; highest false-positive rate
- Custom policies override base policy settings
- **Inspectors**: Replace Snort 2 preprocessors (HTTP inspector, SMTP inspector, etc.)

**Rule management in Snort 3**:
- Rules organized in **rule groups** (by vulnerability class, protocol, attack type)
- Talos signature updates via SRU (Snort Rule Update) pushed from FMC
- **Custom local rules**: Can be written in Snort 3 syntax (`.rules` file upload)
  - Snort 3 format: `alert tcp any any -> any 80 (msg:"Custom HTTP Alert"; content:"malicious"; sid:9000001;)`
- **Rule actions**: Generate Event, Drop and Generate Event, Pass, Drop (no event)

**Snort 3 SnortML (7.6+)**:
- Machine learning exploit detection layer
- Detects exploit patterns from entire vulnerability classes, not just known CVEs
- Zero-day protection beyond signature-based detection
- Integrates with existing IPS policy without separate configuration

**Performance**:
- Snort 3 multi-threading scales detection across CPU cores
- Regex offloading reduces CPU overhead for pattern matching
- Reload (not restart) on policy deploy — minimal traffic disruption

---

### Malware and File Policy

File policies attached to ACP rules define how file transfers are handled.

**File inspection modes**:
- `Detect Files`: Log file transfers (by file type) without blocking
- `Block Files`: Block specified file types immediately
- `Malware Cloud Lookup`: Query AMP cloud for SHA-256 hash verdict
- `Block Malware`: Block files with malware verdict from AMP cloud
- `Spero Analysis`: Lightweight machine learning pre-analysis
- `Dynamic Analysis` (Threat Grid): Submit samples to sandboxing environment

**Supported protocols for file inspection**: HTTP, HTTPS (when decrypted), FTP, SMB, SMTP, IMAP, POP3

**AMP for Networks vs AMP for Endpoints**:
- AMP for Networks: In-line file inspection via FTD file policy
- AMP for Endpoints: Agent-based endpoint protection (separate product, can share threat intelligence with FMC)

---

### SSL/TLS Decryption Policy

Enables FTD to inspect encrypted traffic by decrypting, inspecting, and re-encrypting.

**SSL policy actions**:
- `Decrypt - Resign`: Intercept outbound HTTPS; FTD re-signs certificate with its own CA (requires CA certificate deployed to endpoints/browsers)
- `Decrypt - Known Key`: Decrypt inbound HTTPS to servers where FTD holds the private key (reverse proxy scenario)
- `Do Not Decrypt`: Pass encrypted traffic without inspection
- `Block`: Block encrypted connections

**Rule matching criteria**:
- Source/destination (networks, zones)
- URL category/reputation
- Certificate DN attributes
- Cipher suites, TLS versions
- Certificate validity status (self-signed, expired, unknown CA)

**QUIC decryption (7.6+)**: Extends decryption capability to HTTP/3 over QUIC protocol.

**Do-Not-Decrypt Wizard (7.6+)**: Simplified multi-step wizard for defining decryption exclusions for outbound connections (e.g., banking, healthcare, privacy-sensitive categories).

**Operational considerations**:
- Requires FTD to be provisioned with a trusted CA certificate (for Decrypt-Resign)
- Certificate pinning in client applications will break with Decrypt-Resign
- Performance impact: Decryption is CPU-intensive; hardware SSL offload varies by platform
- Must whitelist (Do-Not-Decrypt): Online banking, medical, privacy-sensitive sites

---

### Identity Policy

Controls user-based access by mapping IP addresses to user identities.

**Identity sources**:
- **Passive Identity (AD Agent / TS Agent)**: User-IP mapping derived from AD login events
- **Active Authentication (HTTP/HTTPS captive portal)**: FTD prompts user to authenticate
- **ISE/ISE-PIC integration**: Cisco Identity Services Engine provides user+device context including Security Group Tags
- **Azure AD (7.4+)**: Azure AD user/group attributes via ISE or SAML
- **Passive Identity Agent (7.6+)**: Direct AD integration without ISE; FTD queries AD domain controllers directly

**Uses in ACP**:
- Reference users/groups in ACP rules: "Block access to social media for Sales group"
- User-based NAT: Translate based on user identity
- PBR with user identity (7.4+): Route based on user or SGT

---

### NAT (Network Address Translation)

FTD supports the same NAT architecture as ASA (LINA-based):

**Auto-NAT (Object NAT)**:
- Defined within a network object
- Automatically placed in Section 2 of NAT table
- Source-only translation (cannot simultaneously translate both source and destination in a single rule)
- Best for: Static PAT (port forwarding), simple dynamic PAT (hide NAT)

```
object network WEBSERVER
 host 10.1.1.10
 nat (inside,outside) static 203.0.113.10
```

**Manual NAT (Twice NAT)**:
- Defined in global NAT configuration
- Placed in Section 1 (pre-auto) or Section 3 (post-auto via `after-auto`)
- Can translate both source AND destination in a single rule
- Best for: Complex translation scenarios, policy NAT, VPN hairpinning

```
nat (inside,outside) source static INTERNAL_NET INTERNAL_NET destination static VPN_POOL VPN_POOL
```

**NAT rule table processing order**:
1. **Section 1** (Manual NAT, pre-auto): First match wins; stops evaluation
2. **Section 2** (Auto-NAT): Object-based NAT; automatically ordered by address specificity
3. **Section 3** (Manual NAT, post-auto / `after-auto`): Catch-all manual rules

**NAT exempt for VPN (identity NAT)**:
```
nat (inside,outside) source static INSIDE_NET INSIDE_NET destination static REMOTE_VPN REMOTE_VPN no-proxy-arp route-lookup
```
Prevents VPN traffic from being NAT'd before encryption.

---

### FlexConfig (CLI Pass-Through)

FlexConfig allows deploying ASA CLI commands directly to FTD's LINA engine — bypassing FMC's GUI for features not yet surfaced in the FMC interface.

**Use cases**:
- `sysopt connection permit-vpn` — required after VPN configuration in some scenarios
- `tcp-map` for TCP normalization options not in FMC
- EIGRP configuration (some advanced options)
- Policy route-maps for complex PBR
- Legacy ASA features not yet native in FMC

**Risks**:
- FMC may overwrite FlexConfig settings during full policy deploy
- No validation in FMC UI — errors only visible during deploy
- Use sparingly; preference is native FMC features where possible

**Structure**: FlexConfig uses text objects (static CLI snippets) and SmartCLI objects (templated with variables).

---

### Encrypted Traffic Analytics (ETA)

ETA on FTD leverages the **Encrypted Visibility Engine (EVE)** — different from the broader Cisco ETA feature on IOS-XE switches.

**FTD EVE**:
- Analyzes patterns in encrypted traffic metadata (flow telemetry, TLS parameters, certificate attributes, packet length/timing patterns)
- Detects malware C2 communications, suspicious encrypted tunnels — **without decrypting traffic**
- EVE malware blocking in TLS sessions (7.4+): Can block connections identified as malicious based on EVE analysis
- EVE Exception List (7.6+): Allows selective blocking/allowing by EVE classification

**Network Discovery**:
- Passive host discovery via traffic analysis
- FTD identifies operating systems, applications, running services from network flows
- Builds network map in FMC (host profiles, application inventory)
- Used for: Vulnerability correlation, IPS rule tuning (OS-fingerprint-based rule selection), compliance reporting
- Does not require active scanning — purely passive observation

---

## ASA Features

### ACLs (Access Control Lists)

ASA ACLs are standard extended/named access lists applied to interfaces (inbound or outbound).

```
access-list OUTSIDE_IN extended permit tcp any host 203.0.113.10 eq 443
access-list OUTSIDE_IN extended deny ip any any log
access-group OUTSIDE_IN in interface outside
```

**Types**:
- Extended ACL: Source/destination IP, port, protocol matching
- Object-group ACL: Grouped objects for cleaner rule sets
- Time-based ACL: Time-range objects for scheduled access

**Key difference from FTD ACP**: ASA ACLs are L3/L4 only; no application awareness, no URL filtering, no user identity matching.

---

### NAT on ASA

Identical to FTD NAT (both use LINA). See FTD NAT section above — same Section 1/2/3 processing, same Auto-NAT vs Twice-NAT model.

---

### VPN

**Site-to-Site IKEv2 (Recommended)**:
```
crypto ikev2 policy 10
 encryption aes-256
 integrity sha256
 group 14
 prf sha256
 lifetime seconds 86400
!
crypto ipsec ikev2 ipsec-proposal AES256
 protocol esp encryption aes-256
 protocol esp integrity sha-256
```

**AnyConnect / Secure Client Remote Access**:
- Cisco AnyConnect rebranded as **Cisco Secure Client** in 2023
- SSL VPN (DTLS/TLS) and IPsec IKEv2 options
- **DTLS recommended**: Lower overhead than TLS; better throughput and latency
- IKEv2 with Secure Client also available — stronger performance than TLS
- Requires AnyConnect/Secure Client license (APEX or equivalent)
- Group policies define per-tunnel settings (split tunneling, DNS, posture, ACLs)
- Tunnel groups (connection profiles) define authentication method, group policy assignment

**DAP (Dynamic Access Policies)**:
- Evaluated at VPN session establishment time
- Aggregates attributes from AAA (LDAP, RADIUS, SAML) and endpoint posture
- Dynamically assigns access controls, ACLs, bookmarks, banner messages to a specific session
- Can restrict access based on: Device OS, certificate attributes, AD group membership, posture assessment
- DAP record with highest priority is applied; multiple records can be aggregated
- Supported on both ASA and FTD (via FMC in 7.0+)

**WebVPN (Clientless)**:
- Browser-based VPN access without client software
- Provides web portal for access to internal web applications, RDP, Citrix
- **ASA only** — clientless WebVPN is not supported on FTD
- FTD supports the newer **Clientless ZTAA** (7.4+) as a replacement approach

**VPN Load Balancing (ASA only)**:
- Multiple ASAs share remote access VPN session load
- Virtual cluster IP address; director node redirects new connections to least-loaded member
- Not supported in FTD

---

## Migration: Firepower Migration Tool (FMT)

### What the Tool Does

The Firepower Migration Tool (FMT) automates conversion of ASA configuration to FTD/FMC configuration:

**Input**: ASA `show running-config` output (text file)
**Output**: FMC configuration via API push, or exportable object sets

### What Converts Automatically

| ASA Feature | FTD/FMC Equivalent | FMT Support |
|---|---|---|
| Network objects | Network objects | Yes — automatic |
| Service objects | Port objects | Yes — automatic |
| Object groups | Object groups | Yes — automatic |
| Extended ACLs | Access Control Policy rules | Yes — automatic |
| NAT rules (static, dynamic) | FTD NAT rules | Yes — automatic |
| Interface configuration | FTD interface config | Yes (with manual mapping) |
| Static routes | Static routes | Yes — automatic |
| Management interface | Management interface | Yes — automatic mapping |

### What Requires Manual Work

| Feature | Issue |
|---|---|
| **Dynamic routing (OSPF, BGP, EIGRP)** | FMT cannot detect/migrate dynamic routing protocols; must be manually configured in FMC |
| **Site-to-site VPN (IKEv1/IKEv2)** | VPN crypto maps not migrated; must be rebuilt in FMC VPN wizard |
| **High Availability (HA)** | HA configuration not converted; configure HA in FMC after migration |
| **Clientless WebVPN** | No equivalent in FTD; requires re-architecture (ZTAA or other solution) |
| **VPN Load Balancing** | Not supported in FTD |
| **MPF inspection policies** | Complex MPF custom policies may require FlexConfig post-migration |
| **Security contexts** | Not supported in FTD; require separate FTD instances per context |
| **ACL + NAT interactions** | Complex NAT exemptions may need review |
| **Crypto ACLs** | Policy-based VPN ACLs not directly supported in FTD (route-based preferred) |
| **Time-based ACLs** | May need manual verification and re-creation |

### Migration Workflow

1. Generate ASA `show running-config` backup
2. Download FMT from Cisco Software Download
3. Load ASA config into FMT
4. FMT generates **pre-migration report** (what will migrate, what needs manual work)
5. Review and resolve flagged items
6. Select target FMC and destination device
7. FMT pushes migrated objects/rules to FMC via REST API
8. Review in FMC; manually add VPN, routing, HA configuration
9. Test and validate before cutover

---

## Sources

- [ACP Rule Actions — Cisco](https://www.cisco.com/c/en/us/support/docs/security/firepower-ngfw/212321-clarify-the-firepower-threat-defense-acc.html)
- [Prefilter Policy Configuration — Cisco](https://www.cisco.com/c/en/us/support/docs/security/firepower-management-center/212700-configuration-and-operation-of-ftd-prefi.html)
- [Snort 3 Configuration Guide 7.0 — Cisco](https://www.cisco.com/c/en/us/td/docs/security/firepower/70/snort3/config-guide/snort3-configuration-guide-v70/overview.html)
- [Custom Snort 3 Rules on FTD — Cisco](https://www.cisco.com/c/en/us/support/docs/security/secure-firewall-threat-defense/221881-configure-custom-local-snort-rules-in-sn.html)
- [NAT Rule Order Reference](https://traceroute.home.blog/2022/04/08/nat-rule-order/)
- [ASA NAT Practical Networking Guide](https://www.practicalnetworking.net/stand-alone/cisco-asa-nat/)
- [FTD DAP for AnyConnect — Cisco](https://www.cisco.com/c/en/us/td/docs/security/secure-firewall/management-center/device-config/710/management-center-device-config-71/vpn-dap.html)
- [FTD DAP Use Cases — Cisco](https://www.cisco.com/c/en/us/td/docs/security/secure-firewall/management-center/cluster/ftd_dap_usecases.html)
- [Migrate ASA to FTD Using FMT — Cisco](https://www.cisco.com/c/en/us/support/docs/security/secure-firewall-asa/222707-migrate-asa-to-firepower-threat-defense.html)
- [FMT Migration Guide — Cisco](https://www.cisco.com/c/en/us/td/docs/security/firepower/migration-tool/migration-guide/ASA2FTD-with-FP-Migration-Tool.html)
- [FMT FAQ — Cisco Community](https://community.cisco.com/t5/security-knowledge-base/firepower-migration-tool-faq/ta-p/4142053)
- [Access Control Policy — Cisco Secure Firewall Docs](https://secure.cisco.com/secure-firewall/v7.0/docs/access-control-policy)
- [FTD Dynamic Access Policy — Cisco 7.0](https://www.cisco.com/c/en/us/td/docs/security/firepower/70/configuration/guide/fpmc-config-guide-v70/firepower_threat_defense_dynamic_access_policies.html)
