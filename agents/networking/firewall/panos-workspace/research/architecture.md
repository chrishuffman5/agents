# PAN-OS Architecture: Deep Technical Reference

## Single-Pass Parallel Processing (SP3)

SP3 is the foundational architectural design of all Palo Alto Networks NGFWs. It combines two complementary innovations:

### Single-Pass Software
Each packet is processed **once** through the entire security inspection stack. Networking functions, policy lookup, App-ID classification, Content-ID inspection, and threat signature matching all happen in a single traversal of the packet. This is fundamentally different from legacy firewalls that chain separate inspection modules (each rescanning the same stream), which multiplies latency and CPU cost.

- Uniform signature matching: one scan engine processes vulnerability, virus, and spyware signatures simultaneously rather than running separate AV and IPS engines sequentially.
- Result: significantly lower latency and higher throughput than multi-pass architectures.

### Parallel Processing Hardware
Separate physical hardware planes prevent resource contention:

**Data Plane (Dataplane)**
- Dedicated CPU cores and memory isolated from management functions.
- **Network Processor**: handles forwarding, routing lookups, NAT, MAC lookup, QoS, traffic shaping.
- **Security Processor**: hardware acceleration for SSL/TLS decryption, IPsec encryption/decryption.
- **Security Matching Processor**: signature matching for threats, viruses, URL lookups.
- High-speed 1 Gbps buses interconnect the three processor types.

**Management Plane (Control Plane)**
- Entirely separate CPU and memory.
- Handles device management, GUI/CLI/API access, configuration management, logging, reporting, and routing protocol (BGP/OSPF) control plane processing.
- Heavy administrative activity (large reports, log searches) does not degrade packet forwarding.

---

## Packet Flow: Ingress to Egress

The complete packet flow through PAN-OS proceeds in the following stages:

### Stage 1: Ingress
- Packet arrives on physical or logical interface.
- Layer 2/3 parsing; VLAN tag processing.
- **Flow lookup**: the firewall performs a 6-tuple lookup (src IP, dst IP, src port, dst port, protocol, ingress security zone) to determine if this packet belongs to an existing session.

### Stage 2: Session Lookup (Fast Path vs. Slow Path)
- **Fast Path (existing session)**: if a matching session is found in the session table, the packet is forwarded with minimal processing — security policy re-evaluation is not needed per packet.
- **Slow Path (new session)**: no existing session found, full policy evaluation required. This is where App-ID, Content-ID, and policy matching occur.

### Stage 3: App-ID (Slow Path — First Packet / Application Identification)
- Protocol decoder applied to determine base protocol (HTTP, SSL, DNS, etc.).
- Application signatures applied to traffic stream.
- Heuristics used for evasive or encrypted applications.
- App-ID runs continuously; the application identification may be updated mid-session as more data is observed (e.g., HTTP first identified as web-browsing, then reclassified as facebook).

### Stage 4: Content-ID / Security Profiles
- Once application is identified, security profiles attached to the matching security policy rule are applied:
  - Antivirus scanning
  - Anti-spyware detection
  - Vulnerability protection (IPS)
  - URL filtering
  - File blocking
  - WildFire analysis
  - Data filtering

### Stage 5: Policy Evaluation
- Security policy rules evaluated **top-down, first-match**.
- NAT rules also evaluated top-down; first match wins.
- **Critical distinction**: Security policy is matched using **pre-NAT IP addresses** but **post-NAT zones**. NAT translation only occurs at egress.

### Stage 6: Forwarding / Egress
- Route lookup, egress interface selection.
- NAT translation applied (source/destination IP and port rewritten).
- QoS marking and shaping.
- Packet transmitted.

---

## Session Management

The session table is the core state database of PAN-OS:

- Sessions are identified by the 6-tuple key.
- Each session entry tracks: application, security policy matched, threat inspection results, byte/packet counters, NAT translations, session flags.
- **Session aging**: sessions time out based on application-specific timeouts defined in App-ID (e.g., HTTP default 3600s, TCP half-closed 120s).
- **Session synchronization in HA**: the active device replicates session state to the passive/peer device so that existing sessions survive failover without dropping.
- **Accelerated aging**: under high session table load, PAN-OS can accelerate aging of idle sessions to free table capacity.
- `show session all` / `show session id <id>` are critical CLI commands for troubleshooting.

---

## Zone-Based Architecture

Security zones are the foundational construct for policy enforcement:

- Every interface is assigned to exactly one zone.
- **Zone types**: Layer 3, Layer 2, Virtual Wire (vwire), Tap, Tunnel, External (used for inter-vsys traffic).
- Traffic **within a zone** (intrazone): permitted by default (intrazone-default allow rule at bottom of rulebase).
- Traffic **between zones** (interzone): denied by default (interzone-default deny rule).
- Zone protection profiles can be applied to a zone to defend against reconnaissance, floods (SYN, UDP, ICMP), and spoofed IP attacks.
- **Protection Profile vs. Security Policy**: zone protection is perimeter-level, security policy is per-flow session enforcement.

---

## Security Policy Evaluation Order

1. Rules are evaluated **top-to-bottom** within the rulebase.
2. **First match wins** — processing stops at the first matching rule.
3. Rule match criteria: source zone, destination zone, source address, destination address, source user, application, service/port.
4. Default rules at the bottom (intrazone-default allow, interzone-default deny) cannot be deleted but can be modified to enable logging.
5. **Panorama layering** adds pre-rulebase and post-rulebase rules managed at the Panorama level that sandwich device-local rules:
   - Panorama pre-rules (applied first)
   - Local device rules
   - Panorama post-rules
   - Default rules

**Rule shadowing** occurs when a broader rule above a specific rule matches traffic intended for the more specific rule below — the specific rule is never evaluated. Detection via `test security-policy-match` CLI command.

---

## NAT Rule Processing Order

NAT rules are evaluated **separately from security policy**, also top-down, first-match.

**Order of operations with NAT:**
1. Ingress — packet arrives with original (pre-NAT) source/destination.
2. Route lookup on pre-NAT destination to determine egress zone.
3. NAT rule lookup using pre-NAT addresses and zones — first match wins.
4. Security policy evaluated using **pre-NAT source and destination IPs** but **post-NAT zones** (critical for correct policy matching when destination NAT is in use).
5. Egress — NAT translation applied (addresses and ports rewritten on the wire).

**NAT types:**
- **Source NAT (SNAT)**: Dynamic IP and Port (DIPP/PAT), Dynamic IP, Static IP.
- **Destination NAT (DNAT)**: used for inbound service publishing; translates public IP to internal server IP.
- **U-Turn NAT** (hairpin): internal clients accessing internal servers via external (public) IP — requires both DNAT and SNAT in the same rule set so return traffic routes correctly back through the firewall.
- **No-NAT rules**: explicit rules that prevent NAT from being applied to specific traffic; evaluated before translation rules.

---

## Virtual Systems (vsys)

Virtual systems partition a single physical firewall into multiple independent logical firewalls:

- Each vsys has its own: interfaces, zones, security policies, NAT rules, App-ID/Content-ID settings, routing (virtual router), administrative accounts, and logs.
- **vsys1** is the default virtual system; most deployments use only vsys1.
- Multi-vsys requires a license on mid/low-range platforms; high-end platforms include multi-vsys by default.
- **Inter-vsys traffic**: uses two sessions (one per vsys). Traffic flows through a virtual interface called an "External Zone" that links two vsys. This is sometimes called "vsys-to-vsys" communication.
- Maximum vsys count varies by platform (e.g., PA-5200 supports up to 256 vsys with a license).
- Use cases: MSSPs, large enterprises with strict tenant isolation requirements.

---

## High Availability (HA)

### Active/Passive HA
- One firewall is **active** (processing all traffic); the other is **passive** (synchronized, ready to take over).
- Configuration sync: all policy, network config, certificates, and runtime state (sessions) are synchronized.
- **Failover triggers**: hardware failure, monitored link failure, monitored path failure, manual failover.
- **HA links**:
  - HA1 (control link): heartbeat, state sync, configuration sync. Uses management interface or dedicated HA interface.
  - HA2 (data link): session synchronization. Carries session table state.
  - HA3 (packet forwarding link): used in active/active only for asymmetric session ownership.
- **Preemption**: when re-enabled, the higher-priority firewall can reclaim active status after recovery. Best practice: disable preemption in most production environments to avoid unnecessary failovers.
- **Link monitoring**: failover triggered when a monitored interface goes down.
- **Path monitoring**: failover triggered when a monitored IP address becomes unreachable (ICMP probes).
- What does NOT sync in active/passive: management interface IP, HA interface settings, FQDN cache, master key.

### Active/Active HA
- Both firewalls are active and process traffic simultaneously.
- Each firewall independently maintains a session table; sessions are synchronized to the peer.
- **Session owner**: the firewall that processes the first packet of a new session becomes the session owner. The session is then synchronized to the peer (session setup peer).
- Requires asymmetric routing support; HA3 link used to forward packets to the correct session owner.
- More complex to configure and troubleshoot; use cases: asymmetric routing environments, load-sharing requirements.
- Floating IP addresses (virtual IPs) allow both devices to share IP addressing.

### HA Election
- **Device priority**: lower numerical value = higher priority = preferred active.
- **Preemptive**: if enabled, higher priority device will preempt and take over active role after recovering.
- Tie-breaker: if priorities are equal, the device with the higher mgmt IP becomes active.

---

## Log Forwarding

PAN-OS supports multiple log forwarding destinations configured via Log Forwarding Profiles attached to security policy rules:

- **Log types**: Traffic, Threat, URL Filtering, WildFire Submission, Data Filtering, Authentication, Tunnel Inspection, GTP, SCTP, HIP Match, GlobalProtect, System, Configuration, Correlation.
- **Destinations**: Panorama (managed log collectors), Cortex Data Lake, syslog servers (UDP/TCP/SSL), SNMP traps, email (SMTP), HTTP/HTTPS servers (webhooks).
- Traffic and Threat logs require explicit enablement per security policy rule (Log at Session Start / Log at Session End).
- **Syslog**: most common destination for SIEM integration; configurable format (BSD/IETF), custom log formats supported.
- **Cortex Data Lake**: cloud-native log storage, enables Cortex XDR/XSIAM integration.
- **HTTP log forwarding**: designed for low-frequency forwarding only; not suitable for high-volume environments (log loss risk).
- Log forwarding profiles are attached at the security policy rule level, allowing different rules to send logs to different destinations.
