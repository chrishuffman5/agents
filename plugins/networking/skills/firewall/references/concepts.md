# Firewall Fundamentals Reference

## Stateful Inspection

Stateful firewalls maintain a **session table** (connection table) that tracks the state of every active network conversation. Once a connection is established and permitted, subsequent packets in that flow are forwarded based on the session table entry without re-evaluating the full policy rulebase.

**Session table entry components:**
- Source IP, destination IP, source port, destination port, protocol (5-tuple or 6-tuple with zone)
- Connection state (TCP: SYN_SENT, ESTABLISHED, FIN_WAIT; UDP: pseudo-state based on traffic)
- NAT translation mappings
- Application identification (NGFW platforms)
- Byte/packet counters
- Timeouts (application-specific idle timeouts)

**Key behaviors:**
- New connections: full policy evaluation (slow path)
- Existing connections: session table lookup only (fast path)
- Return traffic: automatically permitted based on session state (no explicit rule needed for replies)
- Session aging: idle sessions are removed after application-specific timeouts

## UTM vs NGFW

| Feature | UTM (Unified Threat Management) | NGFW (Next-Generation Firewall) |
|---|---|---|
| Target market | SMB | Mid-market to enterprise |
| Inspection model | Multiple engines chained (multi-pass) | Single-pass or tightly integrated |
| Application ID | Basic or none | Deep application identification |
| Performance impact | Higher (multiple passes) | Lower (integrated inspection) |
| Management | All-in-one GUI | Centralized management platforms |
| Examples | FortiGate (historically), Sophos | Palo Alto PA, FortiGate (modern), Cisco FTD |

**Note:** The UTM/NGFW distinction has blurred. Modern FortiGate is both UTM and NGFW. Palo Alto coined "NGFW" to differentiate from traditional UTM by emphasizing application identification as the policy foundation rather than port numbers.

## Zone-Based Design Theory

### Zone Purpose
A security zone groups interfaces that share the same trust level and security policy requirements. Zones provide a logical abstraction that decouples policy from physical interfaces.

### Inter-Zone Traffic Flow
Traffic between zones passes through the firewall's policy engine. Traffic within a zone may be implicitly permitted (PAN-OS, most platforms) or requires an explicit policy depending on configuration.

### Zone Protection
Zone protection profiles defend the zone perimeter against:
- **Reconnaissance:** Port scans and host sweeps
- **Flood attacks:** SYN flood (with SYN cookies), UDP flood, ICMP flood
- **Packet-based attacks:** IP spoofing, IP fragmentation, malformed packets, TCP/IP header anomalies

## Rule Ordering Theory

All major firewall platforms evaluate rules **top-down, first-match**. The first rule that matches a packet's criteria determines the action. This has critical implications:

1. **More specific rules must be above more general rules** -- A broad "permit all internal traffic" rule above a specific "deny finance-to-dev" rule will shadow the deny rule
2. **Deny rules for known threats should be first** -- Dynamic block lists, threat intel feeds
3. **Allow rules should have security profiles** -- No "naked" allow rules without IPS/AV
4. **Explicit deny-all at the bottom** -- With logging, for audit trail
5. **Rule shadowing** -- A rule is shadowed when all traffic matching it also matches an earlier rule. The shadowed rule is never evaluated.

### Panorama Layering (PAN-OS)
PAN-OS with Panorama adds a three-tier rulebase:
1. Pre-rules (Panorama-managed, evaluated first)
2. Local rules (device-managed)
3. Post-rules (Panorama-managed, evaluated last)
4. Default rules (intrazone allow, interzone deny)

## NAT Types

### Source NAT (SNAT)
Translates the source IP address of outbound traffic:
- **Dynamic IP and Port (PAT/NAPT):** Many-to-one; most common for internet access
- **Dynamic IP:** Many-to-many without port translation
- **Static:** One-to-one; bidirectional (inbound and outbound)

### Destination NAT (DNAT)
Translates the destination IP address of inbound traffic:
- Used for publishing internal servers to the internet
- Static mapping: public IP -> private server IP

### U-Turn NAT (Hairpin NAT)
When internal clients access internal servers using the server's public (external) IP:
- Requires both DNAT (translate public IP to server private IP) AND SNAT (translate client IP to firewall IP)
- Without SNAT, return traffic goes directly from server to client, bypassing the firewall (asymmetric routing)

### No-NAT / Identity NAT
Explicitly prevents NAT for specific traffic (typically VPN traffic that should not be translated):
- Placed above translation rules in the NAT rulebase
- Critical for site-to-site VPN where traffic selectors match pre-NAT addresses

### NAT and Security Policy Interaction
On PAN-OS: security policy matches **pre-NAT IP addresses** but **post-NAT zones**. This is a critical distinction when writing rules for DNAT scenarios -- the destination address in the security rule must be the original (pre-NAT) public IP, not the translated private IP.

On FortiOS and FTD/ASA: NAT operates on the same lookup but the interaction differs. Always test with packet-tracer (FTD/ASA) or `test security-policy-match` (PAN-OS) or flow debug (FortiOS) to verify behavior.

## High Availability Patterns

### Active/Passive
- One device processes all traffic; the other is synchronized and idle
- Failover: passive takes over active IP/MAC addresses; clients do not reconnect
- Session state replicated: active sessions survive failover (TCP, VPN, NAT xlate)
- Simplest HA model; recommended for most deployments

### Active/Active
- Both devices process traffic simultaneously
- Requires: Asymmetric routing support or session owner redirection
- More complex: session ownership must be tracked; HA3 (PAN-OS) or equivalent link needed for packet forwarding
- Use cases: Environments with asymmetric routing or when single-device throughput is insufficient

### Clustering
- Multiple devices (2-16) act as a single logical firewall
- Load balanced via spanned EtherChannel (Cisco) or ECMP routing (FortiOS FGSP)
- Control/master node handles management; data nodes process traffic
- Session state shared across all nodes
- Use cases: Highest throughput requirements, scale-out architecture

### HA Design Rules
1. **Identical hardware and software** -- HA peers must match model and firmware version
2. **Dedicated HA links** -- Heartbeat and sync must not share production interfaces
3. **Backup heartbeat** -- Configure a secondary HA1/heartbeat path to prevent split-brain
4. **Disable preemption** -- Avoid unnecessary failovers when primary recovers; let ops decide
5. **Monitor interfaces and paths** -- Failover should trigger on interface down AND destination unreachable
6. **Test failover regularly** -- Untested HA is not HA

## NGFW Feature Categories

### Application Identification
The ability to identify applications regardless of port, protocol, or encryption:
- **PAN-OS App-ID:** Continuous reclassification, protocol decoder + signatures + heuristics
- **FortiOS Application Control:** FortiGuard app signatures + ISDB (Internet Service Database)
- **FTD AppID:** Snort-based application identification within ACP rules

### Intrusion Prevention (IPS)
Signature-based and anomaly-based detection of exploits and attacks:
- Vendor-specific signature databases (Talos, FortiGuard, Palo Alto)
- Severity-based actions (critical=block, high=block, medium=alert)
- Custom signatures for internal application protection
- Zero-day coverage via ML (SnortML on FTD 7.6+, inline deep learning on PAN-OS 10.2+)

### URL Filtering
Category-based web access control:
- Cloud-based URL categorization databases (PAN-DB, FortiGuard, Cisco Talos)
- Real-time categorization of unknown URLs (PAN-OS Advanced URL Filtering)
- Actions: allow, alert, block, continue (user override), override (password)
- Custom categories for allow/block lists

### SSL/TLS Inspection
Decrypt encrypted traffic for full inspection:
- **Forward proxy (outbound):** Firewall acts as MITM, re-signs certificates with internal CA
- **Inbound inspection:** Firewall holds server's private key, decrypts without re-signing
- **No-decrypt rules:** Exclude certificate-pinned apps, privacy-sensitive categories
- **Performance impact:** CPU-intensive; hardware SSL offload varies by platform
- **Requirement:** Internal CA certificate must be trusted by all clients

### Malware Sandboxing
Cloud or on-premises analysis of unknown files:
- **PAN-OS WildFire:** Cloud sandbox with benign/grayware/malicious/phishing verdicts
- **FortiOS FortiSandbox:** On-premises or cloud sandbox; inline or monitoring mode
- **FTD AMP for Networks:** Cloud lookup (SHA-256) + Threat Grid sandbox
