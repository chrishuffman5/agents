---
name: firewall
description: "Cross-platform comparison and architecture guidance for all firewall and NGFW technologies: NGFW architecture, zone-based design, policy design, NAT, HA patterns, and platform selection. Use for \"firewall comparison\", \"NGFW selection\", \"firewall architecture\", \"zone design\", \"security policy\", \"firewall migration\", \"firewall HA\", \"rule ordering\". Do NOT use for panos-, fortios-, cisco-ftd-, cisco-asa-, checkpoint-, sophos-firewall-, pfsense-, or opnsense-specific configuration -- use that technology's own skill. Do NOT use for IDS/IPS signature tuning, NAC, or zero-trust identity platforms (standalone Snort, Cisco ISE, Zscaler) -- that is the security plugin."
license: MIT
---

# Firewall / NGFW

This skill covers all firewall and next-generation firewall technologies, providing cross-platform expertise in NGFW architecture, stateful inspection, zone-based policy design, NAT, high availability, and platform selection. Sibling technology skills provide deep implementation details.

## When to Use This Skill vs. a Technology Skill

**Use this skill when the question is cross-platform or architectural:**
- "Which NGFW should I deploy for our data center?"
- "How do I design zones for a three-tier application?"
- "Compare PAN-OS vs FortiOS for our branch offices"
- "What does a good firewall rule structure look like?"
- "Plan a firewall migration from ASA to FTD"
- "NGFW vs traditional firewall -- what's the difference?"

**Route to a technology skill when the question is platform-specific:**
- "Configure App-ID policy on PAN-OS" --> the `panos` skill
- "FortiGate SD-WAN health check tuning" --> the `fortios` skill
- "FTD packet-tracer output interpretation" --> the `cisco-ftd` skill
- "ASA multiple context mode setup" --> the `cisco-asa` skill

## How to Approach Tasks

1. **Classify** the request:
   - **Platform selection** -- Load `references/concepts.md` for fundamentals, then compare platforms below
   - **Architecture / Design** -- Apply zone-based design principles, defense in depth
   - **Migration** -- Identify source and target platforms, map feature gaps
   - **Troubleshooting** -- Identify the platform, consult the technology skill
   - **Policy design** -- Apply cross-platform best practices below, then route for implementation

2. **Gather context** -- Environment size, existing infrastructure, licensing, compliance requirements, team expertise, traffic patterns, HA requirements

3. **Analyze** -- Apply firewall-specific reasoning. Consider traffic flows, inspection depth, performance requirements, and operational maturity.

4. **Recommend** -- Provide platform-specific guidance with trade-offs, not a single answer

5. **Qualify** -- State assumptions about scale, traffic, and environment

## NGFW vs Traditional Firewall

| Capability | Traditional / Stateful | Next-Generation (NGFW) |
|---|---|---|
| Packet filtering | L3/L4 ACLs | L3/L4 ACLs |
| Stateful inspection | Yes | Yes |
| Application identification | No (port-based only) | Yes (App-ID, AppControl, AppID) |
| User identity-based policy | No | Yes (AD, SAML, IdP integration) |
| Intrusion prevention (IPS) | Separate appliance | Integrated, inline |
| URL filtering | Separate proxy | Integrated |
| SSL/TLS decryption | No | Yes (forward proxy, inbound) |
| Malware sandboxing | No | Integrated (WildFire, FortiSandbox, AMP) |
| Threat intelligence feeds | No | Yes (inline, cloud-based) |

**Key insight**: An NGFW without security profiles enabled (IPS, AV, URL filtering) is just an expensive stateful firewall. The value is in the inspection stack, not the hardware.

## Platform Comparison

### Palo Alto Networks (PAN-OS)

**Strengths:**
- App-ID is the gold standard for application identification -- continuous reclassification, not just first-packet detection
- Single-pass parallel processing (SP3) -- all inspection in one pass, hardware-separated data and management planes
- Panorama provides mature centralized management with device groups, templates, and template variables
- WildFire is the most comprehensive cloud sandbox with phishing verdict support
- Content-ID provides unified threat inspection (AV + IPS + URL + file blocking)
- Best Practice Assessment (BPA) and IronSkillet provide prescriptive baselines

**Considerations:**
- Higher cost per unit (hardware and licensing)
- Subscription-heavy model (Advanced Threat Prevention, Advanced URL Filtering, WildFire, DNS Security are all separate)
- Panorama required for multi-device management (no on-box multi-device)

**Best for:** Organizations that prioritize application visibility, security depth, and are willing to invest in the subscription model. Strong in regulated industries.

### Fortinet (FortiOS)

**Strengths:**
- FortiASIC hardware acceleration (NP7, SP5) delivers high throughput at lower price points
- Security Fabric integrates FortiGate with FortiSwitch, FortiAP, FortiClient EMS, FortiSandbox, FortiManager, FortiAnalyzer
- SD-WAN is built into FortiOS -- no separate license or appliance for branch SD-WAN
- ZTNA built into the platform (access proxy + FortiClient EMS tags)
- FortiManager + FortiAnalyzer provide centralized management and SOC capabilities
- Strong price/performance ratio, especially mid-range and branch platforms
- Per-policy inspection mode (flow-based or proxy-based) allows tuning throughput vs. inspection depth

**Considerations:**
- Flow-based vs proxy-based inspection creates confusion -- flow-based is less thorough for some content types
- NP offloading restrictions (proxy-mode, ALGs, PPPoE traffic cannot be hardware-accelerated)
- Frequent firmware releases require careful version selection; community guidance often diverges from official recommendations

**Best for:** Organizations looking for converged networking + security (NGFW + SD-WAN + LAN/WLAN) at competitive price points. Strong in distributed branch deployments.

### Cisco Secure Firewall (FTD)

**Strengths:**
- Snort 3 IPS engine with Talos threat intelligence -- one of the deepest IPS signature sets
- SnortML (7.6+) provides machine learning-based zero-day exploit detection
- Dual-engine architecture (LINA + Snort) gives strong L3/L4 performance with deep L7 inspection
- FMC provides centralized management with deep event correlation
- CDO/cdFMC offers cloud-delivered management with no on-premises FMC required
- Prefilter policy allows hardware-speed trusted traffic bypass while still inspecting everything else
- Cisco ecosystem integration (ISE, Secure Client, Umbrella, XDR)

**Considerations:**
- Dual-engine complexity (LINA + Snort) creates a steeper learning curve
- Policy deployment causes Snort reload/restart (Snort 3 minimizes disruption but it's not zero)
- FMC is a single point of management failure (unless HA FMC or cdFMC)
- No multi-context support (ASA is required for virtual firewalls)

**Best for:** Organizations deep in the Cisco ecosystem, or those needing best-in-class IPS with Talos intelligence. Strong for environments requiring ML-based threat detection.

### Cisco ASA

**Strengths:**
- Multiple security contexts (virtual firewalls) -- FTD does not support this
- Mature, well-understood platform with decades of operational knowledge
- Strong VPN concentrator (site-to-site and AnyConnect/Secure Client)
- Simpler operational model than FTD for VPN-only or firewall-only use cases
- Distributed site-to-site VPN in clustering mode (9.20+)

**Considerations:**
- No Snort, no application identification, no URL filtering, no IPS (beyond basic MPF inspection)
- ASA 9.x is in sustaining engineering mode -- no new features, security patches only
- All new Cisco firewall hardware runs FTD; ASA only on existing/legacy hardware
- ASDM (GUI) requires Java and is increasingly problematic on modern operating systems

**Best for:** Multi-tenant environments requiring security contexts, VPN concentrators where NGFW features are not needed, and legacy environments where migration risk outweighs benefit.

## Zone-Based Design Principles

Zones are the foundational construct for firewall policy. Every firewall platform uses zones (or zone-equivalent constructs like security levels on ASA).

### Standard Zone Taxonomy

| Zone | Purpose | Security Level | Examples |
|---|---|---|---|
| Untrust / Outside | Internet-facing | Lowest | ISP uplinks, public IP space |
| Trust / Inside | Internal user networks | Highest | User VLANs, endpoints |
| DMZ | Externally accessible servers | Medium | Web servers, email gateways, reverse proxies |
| Management | Out-of-band device management | Highest (isolated) | Firewall mgmt, switch mgmt, IPAM |
| Guest | Untrusted internal users | Low | Guest WiFi, BYOD |
| IoT / OT | Unmanaged or legacy devices | Low-Medium | Cameras, HVAC, SCADA, PLCs |
| VPN | Remote access and site-to-site | Medium-High | VPN tunnel termination zone |

### Design Rules

1. **One interface per zone** -- An interface belongs to exactly one zone
2. **Intrazone default allow** -- Traffic within a zone is typically permitted (PAN-OS default; FortiOS implicit)
3. **Interzone default deny** -- Traffic between zones is denied unless explicitly permitted
4. **Policy references pre-NAT addresses** -- On PAN-OS, security policy uses pre-NAT IPs but post-NAT zones (critical for DNAT scenarios)
5. **Minimize zone sprawl** -- More zones = more policy complexity. 5-8 zones covers most deployments.
6. **Zone protection profiles** -- Apply flood protection, reconnaissance detection, and spoofing prevention on perimeter zones

## Policy Design Best Practices

### Rule Structure (All Platforms)

1. **Deny known-bad first** -- Block lists, threat intelligence feeds, sanctioned country blocks at the top
2. **Specific allows above general allows** -- `Finance-to-DB` above `Internal-to-Servers`
3. **Application-based rules** -- Use App-ID / application signatures, not just port numbers
4. **Security profiles on every allow rule** -- IPS, AV, URL filtering, file blocking on all permitted traffic
5. **Explicit deny-all with logging** -- Last rule before implicit deny, with logging enabled for audit
6. **service: application-default** -- Restrict applications to their documented default ports (PAN-OS) or use ISDB objects (FortiOS)

### Anti-Patterns

1. **"application: any, service: any, action: allow"** -- This is a router, not a firewall
2. **Shadow rules** -- A broad rule above a specific rule makes the specific rule unreachable. Use `test security-policy-match` (PAN-OS) or policy hit counters to detect.
3. **No security profiles** -- An allow rule without IPS/AV/URL inspection provides no defense in depth
4. **Port-based rules on an NGFW** -- Defeats the purpose of application identification
5. **Overly complex NAT** -- Document every NAT rule. Use no-NAT (identity NAT) rules explicitly for VPN traffic.
6. **Ignoring rule hit counts** -- Rules with zero hits for 90+ days should be reviewed and likely removed

## High Availability Patterns

| Pattern | Platforms | Use Case | Complexity |
|---|---|---|---|
| Active/Passive | All platforms | Most production deployments | Low |
| Active/Active | PAN-OS, FortiOS (FGCP AA), ASA (multi-context) | Load sharing, asymmetric routing | High |
| Clustering | FTD (4100/9300, 3100, 4200), ASA (4100/9300), FortiOS (FGSP) | Scale-out performance | High |

### HA Best Practices (All Platforms)

- Dedicated physical links for heartbeat/sync -- never share with production traffic
- Disable preemption unless policy explicitly requires it (PAN-OS, FortiOS)
- Configure link monitoring AND path monitoring for failover triggers
- Upgrade passive/secondary first, verify, then fail over and upgrade the other
- Never upgrade both peers simultaneously
- Test failover procedures regularly in maintenance windows

## Migration Guidance

### ASA to FTD Migration

1. Use the **Firepower Migration Tool (FMT)** -- imports `show running-config`, converts ACLs, NAT, objects automatically
2. **Manual work required:** VPN (crypto maps to VTI/route-based), dynamic routing, HA, clientless WebVPN (no FTD equivalent), security contexts (no FTD equivalent)
3. Each ASA context becomes a separate FTD device
4. VPN load balancing not supported on FTD -- evaluate alternatives

### Cross-Platform Migration (PAN-OS <-> FortiOS <-> FTD)

1. Export source config and document all rules, objects, NAT, VPN, routing
2. Re-create objects and rules manually or use vendor migration tools (Palo Alto Expedition, Fortinet FortiConverter)
3. Map feature differences: App-IDs to FortiGuard app signatures, PAN-OS zones to FortiOS interfaces/zones, etc.
4. Test in parallel (tap mode or secondary path) before cutover
5. Validate rule hit counts for 30+ days post-migration to confirm policy completeness

## Technology Routing

| Request Pattern | Route To |
|---|---|
| PAN-OS, App-ID, Content-ID, Panorama, WildFire, GlobalProtect | the `panos` skill (see its `references/versions/` files for version specifics) |
| FortiOS, FortiGate, Security Fabric, FortiManager, VDOM, SD-WAN | the `fortios` skill (see its `references/versions/` files for version specifics) |
| Cisco FTD, Secure Firewall, Snort 3, FMC, CDO, Prefilter | the `cisco-ftd` skill (see `references/versions/7.6.md` for version specifics) |
| Cisco ASA, ASDM, security contexts, MPF, ASA VPN | the `cisco-asa` skill |

## Reference Files

- `references/concepts.md` -- Firewall fundamentals: stateful inspection, UTM vs NGFW, zone design theory, rule ordering, NAT types, HA patterns. Read for "how does X work" or cross-platform architecture questions.
