# FortiOS Features Deep Reference

## 1. Firewall Policies

### Policy Types

**IPv4 Policies (`config firewall policy`)**
- Primary policy type for IPv4 traffic
- Parameters: srcintf, dstintf, srcaddr, dstaddr, service, action, schedule
- UTM profiles: av-profile, webfilter-profile, ips-sensor, application-list, ssl-ssh-profile
- Inspection mode: flow-based (default in 7.x) or proxy-based (per-policy)
- NGFW mode: policy-based NGFW for application/URL category-based policies

**IPv6 Policies (`config firewall policy6`)**
- Separate policy table for IPv6 traffic
- Same structure as IPv4 policies
- Can reference IPv6 address objects

**Multicast Policies (`config firewall multicast-policy`)**
- Controls multicast traffic forwarding
- Applies to traffic with multicast destination addresses

**Proxy Policies (`config firewall proxy-policy`)**
- Used with ZTNA access proxy
- Also used with explicit web proxy
- Operates at L7 with full proxy inspection

**Local-in Policies (`config firewall local-in-policy`)**
- Control traffic destined to the FortiGate itself (management traffic)
- Restrict which IPs can reach admin services (GUI, SSH, SNMP)

**DoS Policies (`config firewall DoS-policy`)**
- Rate limiting for anomaly detection
- Applied per interface
- Controls: TCP/UDP/ICMP/SCTP flood thresholds, syn-proxy

### Policy Lookup Order
1. Local-in policies (traffic to FortiGate)
2. DoS policies (early drop before policy lookup)
3. Firewall policy table (top-to-bottom, first match wins)
4. Implicit deny (last rule)

### NGFW Policy Mode
Two modes per VDOM (`config system settings → set ngfw-mode`):
- **Profile-based (default)**: Traditional UTM model; security profiles attached to policies
- **Policy-based NGFW**: Policies can match on application signatures and URL categories directly without separate profiles; simpler for application-centric design

---

## 2. UTM Inspection Modes

### Flow-Based Inspection
**How it works:**
- Handled entirely by the IPS engine (no proxy buffering)
- Single-pass architecture: packets inspected as they flow through
- IPS engine applies DFA (Direct Filter Approach) pattern matching in real time
- Protocol decoders identify traffic type for correct security module selection
- Packets are not held/reassembled; scanning is streaming

**Characteristics:**
- Lower latency; higher throughput
- Less RAM consumption
- Cannot inspect all content types (e.g., chunked HTTP may be less thorough)
- AV scanning: signature-based with limited file reconstruction

**SSL Deep Inspection (flow-based):**
- Must select "Inspect All Ports" option (IPS engine cannot determine protocol under SSL without this)
- Flow-based SSL inspection performed by IPS engine + SP/SoC processor

**When to use:**
- High-throughput environments
- Latency-sensitive applications
- When hardware acceleration (NP offloading) is desired
- Most enterprise deployments in 7.x default to flow-based

### Proxy-Based Inspection
**How it works:**
- Traffic is buffered and fully reconstructed by the proxy
- FortiGate terminates client connection, acts as MITM
- Content cached in memory (files, web pages) for thorough scanning
- Multiple protocol proxies: HTTP, HTTPS, FTP, SMTP, POP3, IMAP, NNTP

**Characteristics:**
- Higher latency (buffering overhead)
- More thorough detection: catches evasion techniques like chunked encoding
- Full file reconstruction enables better AV scanning (full file hash comparison)
- Supports more granular web filtering features (safe search enforcement, YouTube restriction)
- More RAM and CPU intensive

**SSL Inspection (proxy-based):**
- Full SSL/TLS proxy: FortiGate re-signs certificates with its own CA
- Clients must trust FortiGate CA certificate
- Enables complete decryption and re-encryption
- Better at detecting certificate-based evasion

**When to use:**
- Environments requiring maximum detection (financial, healthcare)
- Data Loss Prevention (DLP) enforcement (needs full content)
- Web proxy deployments (explicit proxy)
- SMTP/POP3/IMAP email scanning
- Compliance-driven environments where thoroughness is required

### Per-Policy Inspection Mode (since FortiOS 6.2)
- Each policy can independently use flow-based or proxy-based inspection
- Set at policy level: `set inspection-mode flow` or `set inspection-mode proxy`
- Allows granular control: high-trust traffic → flow; sensitive traffic → proxy

---

## 3. SSL Inspection

### Deep Inspection (Full SSL/TLS Inspection)
- FortiGate acts as SSL proxy (man-in-the-middle)
- Client connects to FortiGate; FortiGate connects to server
- FortiGate re-signs server certificate using its own CA certificate
- CA certificate must be deployed to all clients (via GPO, MDM, or user acceptance)
- Enables full decryption of encrypted traffic for UTM scanning
- Certificate pinning may cause failures for apps expecting specific server certificates
- Exemptions configurable: specific URLs, certificate categories, common pinning exceptions

**Configuration:**
```
config firewall ssl-ssh-profile
    edit "deep-inspection"
        set inspect-all enable
        set ssl-anomaly-log enable
        set ssl-exemptions-log enable
        config ssl
            set inspect-all enable
            set client-certificate collect
        end
        config https
            set ports 443
            set status deep-inspection
        end
        config certwhitelist
            # Add exemptions here
        end
    next
end
```

### Certificate Inspection
- FortiGate inspects the SSL certificate only (does not decrypt traffic)
- Checks: certificate validity, revocation (OCSP/CRL), trusted CA
- No content visibility; application may be identified by SNI (Server Name Indication)
- Lower CPU overhead; no client-side CA deployment needed
- Suitable for: environments with legal/privacy restrictions on decryption, or where only cert validation is required

### SSL Exemptions
Categories that are typically exempted from deep inspection:
- Sites with certificate pinning (banking apps, OS update services)
- Sites using mutual TLS (client certificate authentication)
- FortiGuard provides a list of known certificate-pinning sites for automatic exemption

---

## 4. Application Control

- Uses FortiGuard Application Signature Database (ISDB - Internet Service Database)
- Identifies applications regardless of port (protocol/behavior-based detection)
- Deep packet inspection at L7
- Policy actions: allow, block, monitor, quarantine, rate limit
- Application categories: streaming, social media, P2P, gaming, business productivity
- Override capabilities: allow blocked categories, block allowed categories, per-app actions
- ISDB (Internet Service DB): pre-built objects combining application + IP + port; used in SD-WAN and firewall policies for accurate steering

**Key CLI:**
```
config application list
    edit "app-control"
        set comment "Application Control Profile"
        config entries
            edit 1
                set category 2    # Category ID
                set action block
            next
        end
    next
end
```

---

## 5. IPS (Intrusion Prevention System)

- Signature-based detection from FortiGuard IPS subscription
- Protocol decoders for accurate inspection of protocol anomalies
- Actions: allow, monitor, block, reset, quarantine
- Severity levels: critical, high, medium, low, info
- Custom signatures: `config ips custom`
- Anomaly detection: rate-based policies for DoS protection
- IPS sensors can be tuned per policy to disable false-positive signatures
- IPS bypass: specific signatures can be set to pass if causing operational issues

**Key CLI:**
```
config ips sensor
    edit "default"
        config entries
            edit 1
                set rule <signature-id>
                set action block
                set status enable
            next
        end
    next
end
```

---

## 6. Web Filtering

**FortiGuard Web Filtering:**
- URL categorization via FortiGuard cloud (real-time rating) or local cache
- 80+ categories covering explicit content, social media, phishing, malware, etc.
- DNS-based filtering: blocks DNS queries for malicious domains
- YouTube/Safe Search enforcement (requires SSL inspection for HTTPS)

**URL Filter (local):**
- Custom allow/block list by URL, wildcard, or regex
- Processed before FortiGuard category lookup

**Content Filter:**
- Keyword blocking in HTTP/HTTPS body content (proxy-mode only)
- Blocks pages containing specified words/patterns

**Web Rating Override:**
- Allow admins to override FortiGuard category for specific URLs
- Useful for incorrectly categorized sites

**Key config:**
```
config webfilter profile
    edit "webfilter"
        config ftgd-wf
            config filters
                edit 1
                    set category 62    # Explicit content
                    set action block
                next
            end
        end
        set web-content-log enable
        set web-filter-activex-log enable
    next
end
```

---

## 7. Antivirus

**Scanning modes:**
- **Flow-based AV**: streaming signature scan; no full file buffering; faster but less thorough
- **Proxy-based AV**: full file reconstruction; supports archived file scanning (ZIP, RAR, etc.); hash-based detection; cloud submission to FortiSandbox

**FortiSandbox integration:**
- Suspicious files submitted to FortiSandbox for dynamic analysis
- Inline mode: blocks files until sandbox verdict received (adds latency)
- Monitoring mode: allows file, reports verdict asynchronously

**Protocols covered:** HTTP/S, FTP, SMTP, POP3, IMAP, IM

---

## 8. SD-WAN Deep Dive

### SD-WAN Zones
- Logical grouping of SD-WAN member interfaces
- Zones used in firewall policies instead of individual interfaces
- Simplifies policy management when WAN links change
- Default zones: virtual-wan-link (legacy), or custom named zones

### SD-WAN Members
```
config system sdwan
    config members
        edit 1
            set interface "wan1"
            set gateway 203.0.113.1
            set priority 10
            set cost 100
        next
        edit 2
            set interface "wan2"
            set gateway 198.51.100.1
            set priority 20
            set cost 200
        next
    end
end
```

### Performance SLA (Health Checks)
```
config system sdwan
    config health-check
        edit "ISP1-SLA"
            set server "8.8.8.8"
            set protocol ping          # ping, http, dns, tcp-echo, twamp
            set interval 500           # ms between probes
            set failtime 5             # consecutive failures before marking down
            set recoverytime 5         # consecutive successes before marking up
            set threshold-warning-latency 100    # ms
            set threshold-alert-latency 200      # ms
            set threshold-warning-jitter 30      # ms
            set threshold-alert-packetloss 5     # %
            config sla
                edit 1
                    set latency-threshold 100
                    set jitter-threshold 30
                    set packetloss-threshold 2
                next
            end
            set members 1 2           # Apply to members 1 and 2
        next
    end
end
```

**Health check protocols:**
- `ping`: ICMP echo; simplest and most compatible
- `http`: HTTP GET to server; more representative of web traffic
- `dns`: DNS query; validates DNS resolution path
- `tcp-echo`: TCP connect/echo; validates TCP connectivity
- `twamp`: Two-Way Active Measurement Protocol; ITU-T standard; best for voice quality
- `ftp`: FTP connection test

**MOS (Mean Opinion Score):** Calculated from latency, jitter, and packet loss; used for voice-quality SLA evaluation (TWAMP protocol preferred).

### SD-WAN Rules (Service Rules)
```
config system sdwan
    config service
        edit 1
            set name "Voice-Traffic"
            set mode manual               # manual, best-quality, lowest-cost, maximize-bandwidth
            set dst "voice-server"
            set src "internal"
            set priority-members 1        # Prefer member 1
            set backup-members 2          # Failover to member 2
            set health-check "ISP1-SLA"
            set sla-compare-method order
        next
        edit 2
            set name "Business-App"
            set mode best-quality
            set quality-link-cost-factor latency   # latency, jitter, packet-loss, mos, bandwidth
            set health-check "SLA-Check"
        next
    end
end
```

**SD-WAN Strategies:**
| Strategy | Description | Use Case |
|----------|-------------|----------|
| `manual` | Admin specifies preferred member; failover to backup | Known best path; specific ISP preference |
| `best-quality` | Dynamically selects member with best quality metric | Latency/jitter-sensitive apps (VoIP, video) |
| `lowest-cost (SLA)` | Selects lowest-cost member that meets SLA | Cost optimization while maintaining quality |
| `maximize-bandwidth` | Load balances across all SLA-compliant members | Bulk transfers; maximize aggregate throughput |

### ADVPN (SD-WAN Overlay)
- Dynamic IPsec tunnels between spokes via hub
- Hub maintains IPsec tunnels to all spokes (static)
- Spokes initiate shortcuts directly to other spokes on demand
- ADVPN 2.0 (7.6+): improved shortcut management for multiple underlay paths
- SD-WAN monitors ADVPN shortcut quality with dynamic ICMP probes
- BGP over ADVPN distributes spoke routes; hub reflects routes

**Shortcut trigger:** When a spoke needs to communicate with another spoke, it sends a request through the hub; the hub facilitates the shortcut negotiation; direct tunnel established.

---

## 9. ZTNA (Zero Trust Network Access)

### Architecture Overview
ZTNA provides per-application access control with continuous posture verification, replacing broad VPN network access.

**Core components:**
- **FortiGate**: ZTNA gateway (access proxy); policy enforcement point
- **FortiClient**: endpoint agent; provides identity, posture telemetry
- **FortiClient EMS**: Endpoint Management Server; issues ZTNA tags based on posture rules
- **FortiGate EMS Connector**: real-time tag synchronization from EMS to FortiGate

### ZTNA Access Proxy Types
**HTTPS Access Proxy:**
- Proxies HTTP, HTTPS, SSH, RDP, SMB, FTP, and other TCP applications
- Client connects via HTTPS to FortiGate access proxy
- FortiGate authenticates, checks ZTNA tags, then proxies to backend server
- Supports single-sign-on (SAML, LDAP, local users)

**TCP Forwarding Access Proxy:**
- FortiClient establishes secure tunnel to FortiGate
- Specific TCP applications forwarded through the tunnel
- More flexible than HTTPS proxy for non-HTTP protocols

**UDP/QUIC ZTNA (7.6+):**
- UDP traffic destination support via ZTNA
- Connection over QUIC protocol to FortiGate ZTNA gateway

**Agentless Web Access (7.6.1+):**
- Access web applications without FortiClient
- Browser-based access via ZTNA web portal
- No client certificate requirement
- Reduced posture checking capabilities (no device-based checks)

### ZTNA Tags and Posture
**Tag types assigned by EMS:**
- OS version compliance
- Antivirus installed and up-to-date
- Running processes / software presence
- Domain membership
- Certificate presence
- Vulnerability assessment results
- Custom script results

**EMS → FortiGate sync:**
1. FortiGate establishes WebSocket connection to EMS via Fabric connector
2. EMS pushes ZTNA tags (IP + MAC address + tag set) to FortiGate in real time
3. FortiGate creates read-only dynamic address objects from ZTNA tags
4. ZTNA tags available as match criteria in proxy policies and ZTNA access rules

### Access Policy Configuration
```
# ZTNA Server (access proxy definition)
config firewall access-proxy
    edit "app-proxy"
        set vip "ztna-vip"
        set client-cert enable
        config api-gateway
            edit 1
                set url-map "/app1"
                set service "tcp"
                config realservers
                    edit 1
                        set ip 10.0.1.10
                        set port 80
                    next
                end
            next
        end
    next
end

# ZTNA proxy policy
config firewall proxy-policy
    edit 1
        set proxy access-proxy
        set access-proxy "app-proxy"
        set srcaddr "ZTNA-tag-compliant-devices"
        set dstaddr "app-proxy-vip"
        set action accept
        set utm-status enable
    next
end
```

### ZTNA vs VPN Comparison
| Aspect | ZTNA | SSL VPN |
|--------|------|---------|
| Access scope | Per-application | Full network |
| Posture check | Continuous | At connection time |
| Protocol | HTTPS/QUIC | TLS tunnel |
| Visibility | Per-app logging | Tunnel-level |
| Attack surface | Minimal (app only) | Full network segment |
| Device requirement | FortiClient (or agentless) | FortiClient or browser |

---

## 10. FortiClient and EMS

### FortiClient Agent Capabilities (7.6 unified agent)
- Endpoint Detection and Response (EDR)
- SSL VPN tunnel
- ZTNA access with posture tags
- Endpoint Protection Platform (EPP): antivirus, anti-exploit
- Digital Experience Monitoring (DEM): network path quality from endpoint perspective
- Network Access Control (NAC): compliance enforcement
- SASE: cloud-based security stack integration

### EMS (Endpoint Management Server)
- Central management for FortiClient deployments
- Pushes FortiClient profiles (VPN config, ZTNA rules, AV settings)
- Evaluates device posture against compliance rules
- Assigns ZTNA tags based on real-time posture assessment
- Vulnerability scanning and patch management
- FortiGate Fabric connector: EMS integrates as a fabric member

### Compliance Verification Workflow
1. FortiClient connects to EMS
2. EMS evaluates device against posture rules (OS version, AV status, etc.)
3. Tags assigned: `compliant`, `non-compliant`, custom tags
4. Tags synchronized to FortiGate via EMS Fabric connector
5. FortiGate firewall/proxy policies match against these tags
6. Access granted or denied based on current posture (continuous evaluation)
