# Network Security Concepts Reference

## IDS vs. IPS

### Intrusion Detection System (IDS)

Passively monitors network traffic and generates alerts when suspicious patterns are detected. Does not block traffic. Deployed via SPAN/mirror port or network TAP.

**Pros:**
- No impact on network performance or availability
- Safe to deploy -- cannot cause outages
- Can analyze traffic after the fact (retrospective)

**Cons:**
- Cannot block attacks in real time
- Alert-only -- requires human or SOAR response
- Alert volume can cause fatigue without proper tuning

### Intrusion Prevention System (IPS)

Deployed inline in the traffic path. Can drop packets, reset connections, or enforce policy in real time.

**Pros:**
- Active blocking of known threats
- Reduces attacker dwell time for detected threats

**Cons:**
- Single point of failure if not configured with bypass/fail-open
- Adds latency (typically 10-100 microseconds for software IPS)
- False positive can block legitimate traffic -- tuning is critical before enabling inline blocking

### Network Security Monitor (NSM)

Focused on rich metadata capture and behavioral analysis rather than alerting. Zeek is the canonical NSM tool. NSM provides the context needed for threat hunting and forensic investigation.

**IDS vs. NSM distinction:**
- IDS answers: "Was this traffic malicious?"
- NSM answers: "What happened on this network?" -- even without a signature match

### Deployment Decision Framework

```
Is blocking required?
  Yes --> Deploy inline IPS (Suricata/Snort NFQ or AF_PACKET inline)
  No  --> Deploy passive IDS

Is forensic investigation a requirement?
  Yes --> Add Zeek for metadata-rich logging alongside IDS

What is the throughput?
  < 1 Gbps   --> Single Suricata instance with AF_PACKET
  1-10 Gbps  --> Suricata with PF_RING or multi-queue AF_PACKET
  > 10 Gbps  --> Zeek cluster + Suricata with DPDK or AF_PACKET workers
```

## Detection Taxonomy

### By Detection Method

**Signature-based detection:**
- Matches known byte patterns, protocol fields, or network behaviors
- Fast and deterministic -- low false positive rate for covered threats
- Blind to zero-days and obfuscated variants of known attacks
- Rule formats: Suricata rules, Snort rules, YARA (file-based)

**Protocol anomaly detection:**
- Compares observed protocol behavior against RFC specification
- Detects protocol violations that may indicate exploitation or evasion
- Suricata and Zeek both implement deep protocol parsers

**Behavioral/statistical anomaly:**
- Establishes a baseline and alerts on deviations
- Examples: unusual DNS query volume, new service on a host, beaconing regularity
- Higher false positive rate; requires tuning period
- Zeek scripting is the primary implementation mechanism

**Heuristic/ML-based:**
- ML models trained on labeled traffic to classify malicious vs. benign
- Increasingly available in commercial products
- Requires good training data; can be fooled by adversarial inputs

**Threat intelligence-based:**
- Matches network indicators (IP, domain, URL, hash) against external threat intel feeds
- Suricata IP/domain reputation lists (datasets), Zeek Intelligence Framework
- Only covers known-bad indicators -- no coverage for novel infrastructure

### By Traffic Direction

**Ingress (inbound):**
- Internet-origin attacks: exploitation, scanning, DDoS, phishing payloads
- Highest volume of noise; most rule coverage available

**Egress (outbound):**
- C2 beaconing, data exfiltration, DNS tunneling
- Often undermonitored; attacker activity post-compromise is primarily egress

**Lateral (east-west):**
- Attacker movement within the network after initial compromise
- Requires internal sensors or micro-segmentation visibility
- Most forensically important traffic for incident response

## Network Visibility Architecture

### The Visibility Problem

Modern enterprise networks have multiple visibility challenges:

1. **Encryption** -- 80-95% of traffic is TLS. Payload inspection is limited without decryption.
2. **East-west blindness** -- North-south sensors at the perimeter miss internal lateral movement.
3. **Cloud workloads** -- Cloud-native traffic may bypass on-premise sensors entirely.
4. **High throughput** -- 10/40/100 Gbps segments exceed software sensor capacity without tuning.
5. **Ephemeral workloads** -- Containers and VMs spin up and down faster than agent deployment cycles.

### Visibility Coverage Model

Layer these data sources for comprehensive coverage:

| Layer | Data Source | Coverage |
|---|---|---|
| Perimeter | Suricata/Snort inline + Zeek | North-south ingress/egress |
| Internal core | Zeek on core switch SPAN | East-west between VLANs/subnets |
| Data center | Micro-segmentation (Illumio/Guardicore) | Workload-to-workload |
| Wireless | NAC + wireless controller logs | Client network access |
| Cloud | VPC flow logs + cloud-native IDS | Cloud workload traffic |
| DNS | Recursive resolver logging | All DNS activity |
| DHCP | DHCP server logs | IP-to-MAC-to-hostname mapping |

### Traffic Access Methods

**Physical TAP:**
- Hardware device placed between two network devices
- Passive optical or copper tap -- completely transparent to the network
- Produces a copy of all traffic to monitoring port
- Gold standard: lossless, no impact on production, cannot fail (passive)
- Use for: high-value segments where packet loss is unacceptable

**SPAN/Mirror Port:**
- Switch software feature that copies traffic from one or more ports to a monitoring port
- Convenience: no hardware required
- Limitations: switch CPU impact at high utilization; oversubscription drops mirrored packets; cannot guarantee lossless
- Use for: lower-priority segments, development environments

**Inline (bump-in-wire):**
- Sensor physically placed between two network devices
- All traffic passes through the sensor
- Requires bypass/fail-open capability for high availability
- Hardware bypass cards (Napatech, Silicom) provide fail-open at line rate
- Use for: internet edge where active blocking is required

**Network Broker / Packet Broker:**
- Purpose-built appliance (Gigamon, Ixia/Keysight) that aggregates traffic from multiple TAPs/SPANs
- Filters, deduplicates, and load-balances traffic to monitoring tools
- Essential for large-scale deployments feeding multiple sensors
- Reduces cost by sharing tap feeds across multiple tools

## East-West vs. North-South Traffic

### North-South Traffic

Traffic entering or leaving the network perimeter (internet-facing).

**Characteristics:**
- Highest threat exposure -- direct internet contact
- Most security investment historically concentrated here
- Rich rule coverage in commercial and open-source rulesets

**Detection priority:** Exploitation attempts, phishing payloads, scanning, DDoS, exfiltration to internet C2.

### East-West Traffic

Traffic moving laterally within the network, between internal systems.

**Characteristics:**
- Often 70-80% of total network traffic volume
- Historically undermonitored -- trusted because "internal"
- Where most dwell time and damage occurs post-breach
- Requires internal sensors or micro-segmentation visibility

**Detection priority:** Lateral movement (SMB, WMI, RDP, SSH), credential relay (NTLM, Kerberos anomalies), internal reconnaissance (port scans, LDAP enumeration), ransomware propagation (SMB lateral, shadow copy deletion).

### The Attacker's East-West Playbook

Understanding attacker patterns for east-west detection:

1. **Initial foothold** -- External-facing system compromised (north-south event)
2. **Local reconnaissance** -- Arp scan, net commands, LDAP queries
3. **Credential theft** -- LSASS dump, Kerberoasting, NTLM capture
4. **Lateral movement** -- Pass-the-hash, pass-the-ticket, RDP, SMB, WMI
5. **Privilege escalation** -- Domain controller targeting, ACL abuse
6. **Objectives** -- Ransomware staging, data collection, persistence

Detection at steps 2-5 requires east-west visibility. Without it, initial access (step 1) is the only detection opportunity.

## Network Forensics

### Forensic Evidence Sources

**Full packet capture (PCAP):**
- Complete record of all network conversations
- Maximum evidence quality; allows session reconstruction
- Storage intensive: 1 Gbps continuous = ~450 GB/hour
- Practical approach: capture on high-value segments with rolling 24-72 hour retention

**Flow data (NetFlow/IPFIX/sFlow):**
- Metadata about conversations: src/dst IP, port, protocol, bytes, packets, timestamps
- 50-100x more storage-efficient than PCAP
- Cannot reconstruct sessions or recover payloads
- Suitable for long-term retention and anomaly detection

**Zeek logs:**
- Structured, application-layer metadata
- More detail than flow data; less storage than PCAP
- Best balance for most organizations: rich forensic value at manageable storage cost
- Typical storage: 1-5% of PCAP volume

**IDS/IPS alert logs:**
- High-signal events with rule context
- Incomplete record: only captures matched traffic, not background traffic
- Essential for timeline construction but insufficient alone for investigation

### Network Forensics Methodology

**Phase 1: Scoping**
- Define time window of interest
- Identify known-compromised IP addresses/hostnames
- Establish initial indicators (malware domain, C2 IP, suspicious process)

**Phase 2: Connection Analysis**
- Review Zeek conn.log for all connections to/from affected hosts
- Look for new external connections post-compromise (beaconing intervals, new destinations)
- Identify internal connections from compromised host (lateral movement candidates)

**Phase 3: Protocol Deep-Dive**
- DNS: New domains queried post-compromise? High-entropy domain names? DNS TXT queries (data exfil)?
- HTTP/HTTPS: Unusual user agents? POSTs to new destinations? Large response sizes?
- SMB: New share access? Named pipe usage (lateral movement tool indicators)?
- Kerberos/NTLM: Service ticket requests (Kerberoasting)? NTLM on non-domain hosts?

**Phase 4: Timeline Correlation**
- Merge network timeline with endpoint telemetry (EDR process tree, file system events)
- Attacker activity across network and endpoint logs should align in time
- Gaps in endpoint logging often filled by network evidence

**Phase 5: IOC Extraction**
- Document new IOCs for blocking and threat intelligence sharing
- File hashes (Zeek files.log, Suricata file-store)
- Network IOCs: C2 IPs, domains, URLs, JA3 hashes, certificate fingerprints

### Retention Recommendations

| Data Type | Minimum Retention | Recommended |
|---|---|---|
| IDS/IPS alerts | 90 days | 1 year |
| Flow data | 90 days | 1 year |
| Zeek logs | 30 days | 90 days |
| PCAP (full) | 24-72 hours | 7 days (high-value segments) |
| DNS logs | 30 days | 90 days |

## Protocol Analysis Reference

### Key Protocols for Detection

**DNS:**
- C2 tunneling: high-entropy subdomains, unusually long query strings, TXT record queries
- DGA (Domain Generation Algorithm): many NX domains from single host
- Fast-flux: rapidly changing A records for same domain
- DNS-over-HTTPS: bypasses traditional DNS monitoring

**HTTP/HTTPS:**
- C2 beaconing: regular interval connections to same destination
- Exfiltration: large POST requests, encoded data in URIs or headers
- Malware staging: executable downloads (MIME type, file extension mismatches)
- Domain fronting: TLS SNI differs from HTTP Host header

**SMB:**
- Lateral movement: new share connections (C$, ADMIN$, IPC$) from non-administrative hosts
- Ransomware: mass file rename/access events
- Named pipes: used by many lateral movement tools (Cobalt Strike, Metasploit)

**Kerberos:**
- Kerberoasting: AS-REQ for service tickets with RC4 encryption from unusual hosts
- Pass-the-ticket: service ticket usage from unexpected source IP
- Golden/silver ticket: anomalous ticket lifetimes, encryption types

**NTLM:**
- Pass-the-hash: NTLM authentication from unexpected source
- NTLM relay: authentication forwarding to different target
- Should be largely absent in modern environments (negotiate Kerberos)

## NAC Concepts

### Why NAC

Network Access Control enforces "who is allowed to connect before they connect." Traditional network security assumes internal devices are trusted. NAC addresses:
- Rogue device access (unauthorized devices, visitors)
- Unmanaged device risk (BYOD, IoT, OT)
- Non-compliant device access (out-of-patch, no EDR)
- Guest network segmentation

### 802.1X Authentication

Port-based network access control standard. Three components:

1. **Supplicant** -- The device requesting access (configured with 802.1X client)
2. **Authenticator** -- The network switch or wireless AP enforcing access
3. **Authentication Server** -- RADIUS server (ISE, ClearPass, NPS) making the decision

Authentication methods:
- **EAP-TLS** -- Certificate-based; most secure; requires PKI infrastructure
- **PEAP** -- Password-based inside TLS tunnel; common for user authentication
- **EAP-FAST** -- Cisco proprietary; faster re-authentication
- **MAB (MAC Auth Bypass)** -- Fallback for non-802.1X devices; authenticates by MAC address (spoofable)

### NAC Deployment Phases

1. **Visibility only** -- Deploy in monitor mode; build device inventory; no enforcement yet
2. **Profiling** -- Classify devices by type (workstation, phone, printer, IoT, OT)
3. **Policy development** -- Define access policies per device category
4. **Pilot enforcement** -- Enable enforcement on low-risk segments first
5. **Full enforcement** -- Roll out to all segments with exception process in place

## Micro-Segmentation Concepts

### Traditional vs. Micro-Segmentation

**Traditional segmentation:**
- VLAN/firewall-based; perimeter between network zones
- Course-grained: entire VLANs can communicate freely within the zone
- Static: policy changes require firewall rule modifications

**Micro-segmentation:**
- Policy at the workload level; independent of network topology
- Fine-grained: specific workload-to-workload allow/deny rules
- Dynamic: policy follows the workload (VM migration, cloud bursting)
- Enforces least-privilege between workloads -- even if they share a subnet

### Application Dependency Mapping

Before writing micro-segmentation policy, map what communicates with what:

1. **Discovery phase** -- Deploy agents/sensors in monitor mode; capture all flow data
2. **Application grouping** -- Group workloads by application tier (web, app, DB)
3. **Dependency visualization** -- Identify all inter-workload communication paths
4. **Policy draft** -- Translate observed (and required) connections to allow rules
5. **Ring-fencing** -- Start with coarse ring-fence (block everything else); refine inward

### Enforcement Boundaries

A key concept in Illumio and similar platforms: rather than writing all allow rules first, define an enforcement boundary that isolates a group of workloads, then open only required paths. This:
- Limits blast radius of compromised workloads
- Simplifies policy: deny-by-default within boundary, explicit allows only
- Aligns with zero trust "assume breach" principle

### East-West Segmentation Value

Micro-segmentation directly limits lateral movement:
- Ransomware cannot spread between segmented workloads via SMB
- Compromised workload cannot initiate connections to unrelated application tiers
- Provides visibility into all attempted (and blocked) east-west connections
- MITRE ATT&CK mitigations: T1021 (Remote Services), T1570 (Lateral Tool Transfer), T1210 (Exploitation of Remote Services)
