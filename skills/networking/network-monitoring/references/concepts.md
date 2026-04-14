# Network Monitoring Fundamentals Reference

## SNMP (Simple Network Management Protocol)

### Protocol Architecture
- **Manager** -- NMS software that polls agents and receives traps
- **Agent** -- Software on the monitored device responding to polls and sending traps
- **MIB (Management Information Base)** -- Hierarchical tree of OIDs defining available data points

### SNMP Versions

| Version | Authentication | Encryption | Community String | Use Case |
|---|---|---|---|---|
| v1 | Community (cleartext) | None | Read/Write | Legacy only; avoid |
| v2c | Community (cleartext) | None | Read/Write | Isolated mgmt networks |
| v3 | USM (username/auth) | DES/AES | N/A (username-based) | Production standard |

### SNMPv3 Security Levels
- **noAuthNoPriv** -- Username only; no authentication or encryption
- **authNoPriv** -- Username + authentication (MD5/SHA); no encryption
- **authPriv** -- Username + authentication + encryption (DES/AES-128/AES-256)

### Key OIDs
| OID | Description |
|---|---|
| 1.3.6.1.2.1.1.1.0 | sysDescr -- Device description |
| 1.3.6.1.2.1.1.3.0 | sysUpTime -- Uptime in hundredths of seconds |
| 1.3.6.1.2.1.1.5.0 | sysName -- Hostname |
| 1.3.6.1.2.1.2.2.1.* | ifTable -- Interface table (status, counters) |
| 1.3.6.1.2.1.31.1.1.* | ifXTable -- Extended interface table (64-bit counters) |
| 1.3.6.1.4.1.* | enterprises -- Vendor-specific OIDs |

### SNMP Operations
- **GET** -- Retrieve a single OID value
- **GET-NEXT** -- Retrieve the next OID in the tree (table walks)
- **GET-BULK** (v2c/v3) -- Retrieve multiple OIDs efficiently (replaces repeated GET-NEXT)
- **SET** -- Write a value to an OID (requires write community/credentials)
- **TRAP** -- Unsolicited notification from agent to manager (link down, threshold exceeded)
- **INFORM** (v2c/v3) -- Acknowledged trap (retransmitted until manager acknowledges)

### SNMP Polling Considerations
- **Polling interval**: 5 minutes is standard for capacity; 60 seconds for availability
- **Bulk walks**: Use GET-BULK for tables; dramatically reduces polling time
- **64-bit counters**: Use ifXTable (ifHCInOctets/ifHCOutOctets) for high-speed interfaces (1 Gbps+); 32-bit counters wrap too quickly
- **Timeout and retry**: 2-5 second timeout, 1-3 retries; excessive retries increase load
- **SNMP scalability**: A single NMS poller typically handles 500-2,000 devices depending on OID count and interval

## Flow Protocols

### NetFlow v5
- Cisco proprietary; fixed 7-tuple flow key (src/dst IP, src/dst port, protocol, ToS, ingress interface)
- Fixed record format; no extensibility
- Widely supported but limited to IPv4
- Sampled or unsampled

### NetFlow v9
- Template-based; flexible record format
- Supports IPv6, MPLS labels, BGP AS numbers
- Templates define field types and lengths; collector must decode via template
- Cisco proprietary but widely supported

### IPFIX (IP Flow Information Export)
- IETF standard (RFC 7011); evolved from NetFlow v9
- Template-based with enterprise-specific information elements
- Variable-length fields, structured data types
- Vendor-neutral; recommended for new deployments

### sFlow
- Sampling-based protocol (RFC 3176)
- Samples 1 in N packets (configurable rate)
- Includes packet header sample + interface counters
- Lower device overhead than NetFlow (no per-flow state)
- Multi-vendor; common on switches (Arista, HP/Aruba, Dell, Brocade)

### VPC Flow Logs
- Cloud-native flow records from AWS, Azure, GCP virtual networks
- Similar fields to NetFlow (src/dst IP, port, protocol, action, bytes)
- Cloud-specific metadata: VPC ID, subnet, security group, ENI
- Published to cloud storage or streaming services

### Flow Collection Architecture
```
[Routers/Switches] --> NetFlow/sFlow --> [Flow Collector] --> [Flow Analytics Platform]
[Cloud VPCs] --> VPC Flow Logs --> [Cloud Storage] --> [Flow Analytics Platform]
```

### Flow Enrichment
Raw flows become useful when enriched with:
- **BGP AS path** -- Source and destination AS; transit path
- **Geographic data** -- GeoIP lookup for location context
- **Device metadata** -- Hostname, site, role tags
- **Application mapping** -- Port-to-application (beyond IANA port registry)
- **Custom tags** -- Business unit, customer, cost center

## Synthetic Monitoring

### Concept
Active probes that simulate user transactions from controlled vantage points. Measures what the user would experience, independent of actual user traffic.

### Test Types

#### Network Layer Tests
- **ICMP Ping** -- Basic reachability and round-trip time
- **TCP Connect** -- Port reachability and connection time
- **Traceroute** -- Hop-by-hop path discovery and per-hop latency
- **MTU Path Discovery** -- Detect MTU mismatches along the path

#### Application Layer Tests
- **HTTP/HTTPS** -- Availability, response code, response time, SSL certificate validity
- **DNS** -- Resolution time, answer correctness, DNSSEC validation
- **Page Load** -- Full browser render including JS/CSS/images (headless browser)
- **Web Transaction** -- Multi-step scripted user journeys (login, navigate, submit)
- **API** -- REST/GraphQL endpoint testing with response assertions
- **Voice/RTP** -- MOS score, jitter, packet loss for VoIP quality

#### BGP Tests
- **BGP Route** -- Prefix visibility, AS path, route changes
- **BGP Hijack Detection** -- Unexpected origin AS or path changes

### Agent Types
- **Cloud agents** -- Vendor-hosted in global data centers; external perspective
- **Enterprise agents** -- Customer-deployed in internal networks; internal perspective
- **Endpoint agents** -- Installed on user devices; real user path measurement

### Path Visualization
- Combines traceroute-like probing with BGP route data
- Shows every hop from source to destination including ISP routers
- Identifies specific hops introducing latency, loss, or path changes
- Historical comparison detects path changes correlating with performance issues

## Alerting Theory

### Alert Lifecycle
1. **Detection** -- Metric crosses threshold or anomaly detected
2. **Notification** -- Alert delivered to appropriate responder
3. **Acknowledgment** -- Responder confirms receipt
4. **Investigation** -- Root cause analysis
5. **Resolution** -- Issue fixed; alert clears
6. **Documentation** -- Post-incident review

### Threshold Strategies

#### Static Thresholds
- Fixed values (CPU > 90%, interface > 80%)
- Simple to configure; predictable behavior
- **Problem**: Does not account for normal variation; generates false positives during peaks

#### Dynamic Baselines
- Learn normal patterns over time (hourly, daily, weekly)
- Alert when deviation exceeds N standard deviations
- **Advantage**: Adapts to normal variation; fewer false positives
- **Problem**: Requires learning period; may miss slow degradation (baseline shifts)

#### Rate of Change
- Alert on rapid metric changes (delta/second or delta/minute)
- Catches sudden failures independent of absolute value
- **Example**: Interface utilization jumps from 20% to 95% in 2 minutes

#### Composite Conditions
- Multiple metrics combined with AND/OR logic
- **Example**: CPU > 80% AND memory > 90% AND for > 10 minutes
- Dramatically reduces noise; requires deeper understanding of failure modes

### Alert Fatigue
Alert fatigue is the single biggest operational problem in network monitoring:

**Causes:**
- Too many non-actionable alerts
- Missing deduplication (same issue generates 50 alerts)
- No dampening (flapping interfaces generate rapid fire alerts)
- Missing correlation (device down -> 20 interface alerts + 10 service alerts)

**Solutions:**
- Every alert must have a documented response procedure
- Implement deduplication and dampening (require condition for N minutes)
- Use parent/child dependencies (device down suppresses interface alerts)
- Maintenance windows suppress alerts during planned changes
- Regular alert review: disable alerts with no action taken in 90 days
- Severity tiers: Critical (page), Warning (email), Info (dashboard only)

### Escalation Patterns
```
Tier 1: Auto-notification (email/Slack/Teams)
  -> Not acknowledged in 15 min ->
Tier 2: Page on-call engineer (PagerDuty/OpsGenie)
  -> Not acknowledged in 30 min ->
Tier 3: Page team lead + manager
```

## SNMP Trap and Syslog

### SNMP Traps
- Unsolicited notifications from device to NMS
- Common traps: linkDown, linkUp, coldStart, warmStart, authenticationFailure
- Enterprise-specific traps for vendor events (fan failure, power supply, BGP peer change)
- **INFORM** (v2c/v3): Acknowledged trap; retransmitted until NMS confirms receipt

### Syslog
- Text-based logging protocol (RFC 5424); UDP port 514 or TCP port 514/6514 (TLS)
- Severity levels: Emergency (0) through Debug (7)
- Facility codes: kernel, user, auth, local0-7
- Devices send logs in real-time; NMS correlates with device state
- Use cases: configuration change detection, authentication events, protocol state changes

## Network Topology Discovery

### Protocols
- **LLDP (Link Layer Discovery Protocol)** -- IEEE 802.1AB; vendor-neutral neighbor discovery
- **CDP (Cisco Discovery Protocol)** -- Cisco proprietary; widely deployed
- **SNMP-based**: Walk LLDP/CDP MIBs or ARP/MAC/routing tables to build topology
- **BGP Peering**: Discover routing peers from BGP neighbor tables

### Topology Map Types
- **Physical** -- Actual cable connections between devices (LLDP/CDP)
- **Logical** -- L3 routing relationships (routing table, BGP)
- **Application** -- Traffic flow paths between application tiers

## Monitoring at Scale

### Distributed Polling
- Deploy multiple poller instances across sites
- Each poller monitors local devices; reports back to central NMS
- Reduces WAN bandwidth for SNMP polling
- Provides monitoring resilience if WAN fails

### Data Storage Tiers
- **Hot storage** (1-30 days): Full resolution; fast queries; SSDs
- **Warm storage** (30-180 days): Reduced resolution (5-min averages); HDDs
- **Cold storage** (1-2+ years): Highly aggregated; compliance archive; object storage

### Capacity Planning Metrics
| Metric | Small (<500 devices) | Medium (500-5,000) | Large (5,000+) |
|---|---|---|---|
| Polling interval | 60s availability, 5m metrics | Same | Same (with distributed pollers) |
| Pollers | 1 | 1-3 | 5+ distributed |
| Flow records/day | <100M | 100M-1B | 1B+ |
| Storage (1 year) | <1 TB | 1-10 TB | 10-100+ TB |

## Integration Patterns

### NMS + Flow + Synthetic (Complete Stack)
- **NMS** (LibreNMS/PRTG/SolarWinds): Device health, availability, interface metrics
- **Flow** (Kentik/NTA): Traffic analysis, application visibility, DDoS
- **Synthetic** (ThousandEyes): User experience, path analysis, SaaS monitoring
- **Dashboard** (Grafana): Unified visualization across all data sources

### SIEM Integration
- Forward NMS alerts and syslog to SIEM (Splunk, ELK, Wazuh)
- Correlate network events with security events
- Network context enriches security investigations (what IPs were communicating, when, how much)

### ITSM Integration
- Auto-create incidents from critical alerts (ServiceNow, Jira Service Management)
- Link alert to affected CI in CMDB
- Track MTTR (Mean Time to Resolution) for network incidents
