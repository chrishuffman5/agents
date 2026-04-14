# PAN-OS Architecture Reference

## SP3 (Single-Pass Parallel Processing)

### Data Plane
Dedicated CPU cores and memory isolated from management:
- **Network Processor**: Forwarding, routing lookups, NAT, MAC lookup, QoS, traffic shaping
- **Security Processor**: Hardware acceleration for SSL/TLS decryption, IPsec encryption
- **Security Matching Processor**: Signature matching for threats, viruses, URL lookups
- High-speed interconnects between processors

### Management Plane
Separate CPU and memory for: GUI/CLI/API access, configuration management, logging, reporting, routing protocol control plane (BGP/OSPF). Heavy admin activity does not degrade packet forwarding.

## Packet Flow Stages

### Stage 1: Ingress
Packet arrives on interface. L2/L3 parsing, VLAN tag processing.

### Stage 2: Session Lookup
6-tuple lookup (src IP, dst IP, src port, dst port, protocol, ingress zone):
- **Fast Path (existing session)**: Forward with minimal processing -- no policy re-evaluation
- **Slow Path (new session)**: Full policy evaluation required

### Stage 3: App-ID (Slow Path)
Protocol decoder -> application signatures -> heuristics -> continuous reclassification. Application may be updated mid-session as more data is observed.

### Stage 4: Content-ID
Security profiles applied: AV scanning, anti-spyware, vulnerability protection (IPS), URL filtering, file blocking, WildFire analysis, data filtering.

### Stage 5: Policy Evaluation
Security policy rules evaluated top-down, first-match. NAT rules also top-down, first-match.
**Critical**: Security policy matches pre-NAT IP addresses but post-NAT zones.

### Stage 6: Forwarding/Egress
Route lookup, egress interface, NAT translation applied, QoS, packet transmitted.

## Session Management

Session table: core state database.
- Sessions identified by 6-tuple key
- Each entry tracks: application, matched policy, threat results, counters, NAT xlate, flags
- **Session aging**: Application-specific timeouts (HTTP 3600s, TCP half-closed 120s)
- **HA session sync**: Active device replicates session state to passive peer
- **Accelerated aging**: Under high load, idle sessions aged faster
- Key commands: `show session all`, `show session id <id>`, `show session info`

## Zone Types

| Type | Description |
|---|---|
| Layer 3 | Standard routed zone |
| Layer 2 | Switched zone |
| Virtual Wire (vwire) | Bump-in-the-wire, no IP addresses |
| Tap | Passive monitoring (SPAN port) |
| Tunnel | VPN tunnel zones |
| External | Inter-vsys traffic |

- Intrazone traffic: permitted by default
- Interzone traffic: denied by default
- Zone protection profiles: perimeter defense (floods, scans, spoofing)

## Virtual Systems (vsys)

- Partition a physical firewall into independent logical firewalls
- Each vsys: own interfaces, zones, policies, NAT, routing, admin accounts, logs
- vsys1 is default; most deployments use only vsys1
- Multi-vsys requires license on mid/low-range platforms
- Inter-vsys traffic uses External Zone and two sessions (one per vsys)

## High Availability

### Active/Passive
- Active processes all traffic; passive synchronized and ready
- **HA1 (control link)**: Heartbeat, state sync, configuration sync
- **HA2 (data link)**: Session table synchronization
- **HA3 (packet forwarding)**: Active/active only, asymmetric session ownership
- Failover triggers: hardware failure, link failure, path failure, manual
- What does NOT sync: mgmt IP, HA interface settings, FQDN cache, master key

### Active/Active
- Both firewalls active, processing traffic simultaneously
- Session owner: firewall processing first packet owns the session
- HA3 link forwards packets to correct session owner
- More complex; use for asymmetric routing environments

### HA Election
- Lower device priority number = higher priority = preferred active
- Preemptive: if enabled, higher priority device reclaims active after recovery
- Best practice: disable preemption in production

## Log Forwarding

Log types: Traffic, Threat, URL, WildFire, Data Filtering, Authentication, Tunnel, GTP, SCTP, HIP Match, GlobalProtect, System, Config, Correlation.

Destinations: Panorama, Cortex Data Lake, syslog (UDP/TCP/SSL), SNMP, email, HTTP/HTTPS webhooks.

- Traffic/Threat logs require explicit enablement per security policy rule
- Log forwarding profiles attached at the rule level
- HTTP log forwarding: low-frequency only (log loss risk at high volume)
