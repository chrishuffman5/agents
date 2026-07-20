# Sophos Firewall Architecture Reference

## XGS Hardware Platform

### Xstream Flow Processor
All XGS appliances include a dedicated FPGA-based Xstream Flow Processor alongside general-purpose CPUs:

- **TLS acceleration** -- Hardware decrypt/re-encrypt for TLS 1.3 at line rate; offloads CPU entirely for TLS operations
- **FastPath forwarding** -- Trusted traffic forwarded at wire speed without CPU involvement
- **Packet classification** -- Initial packet parsing and flow classification in hardware

### Hardware Tiers

| Model Range | Target | FW Throughput | NGFW Throughput | Key Interfaces |
|---|---|---|---|---|
| XGS 87-136 | SOHO/Branch | 3-7 Gbps | 1-3 Gbps | 4-8x GbE copper |
| XGS 2100-2300 | SMB | 15-20 Gbps | 5-8 Gbps | 8x GbE, 2x SFP+ |
| XGS 3100-3300 | Mid-market | 30-50 Gbps | 12-20 Gbps | 8x GbE, 4x SFP+, expansion |
| XGS 4300-4500 | Enterprise | 80-100 Gbps | 30-50 Gbps | 4x SFP+, 2x QSFP+, modular |
| XGS 5500-6500 | DC/Carrier | 170-320 Gbps | 70-130 Gbps | 8x QSFP+, 2x QSFP28 |

### Deployment Options
- **Physical** -- XGS appliances (purpose-built hardware)
- **Virtual** -- XGV images for VMware ESXi, Microsoft Hyper-V, KVM
- **Cloud** -- AWS, Azure, GCP marketplace images
- **HA** -- Active/passive and active/active (SD-WAN load balancing) on all form factors

## Xstream Architecture

### Three Processing Lanes

#### 1. TLS Inspection Lane
- Receives encrypted traffic identified for inspection by HTTPS inspection policy
- Xstream Flow Processor performs decrypt/re-encrypt in hardware (XGS)
- Decrypted payload handed to DPI Engine Lane for content inspection
- Supports TLS 1.0 through TLS 1.3
- **Certificate handling**: Re-signs with Sophos CA (outbound), imports server cert (inbound/WAF)
- **Bypass mechanisms**: Certificate-pinned sites, configured exclusion categories, specific source/destination exemptions

#### 2. FastPath Lane
- **Purpose**: Wire-speed forwarding for trusted traffic
- **Qualifying traffic**: Flows that have completed DPI inspection and been approved; flows matching FastPath-eligible rules
- **Behavior**: No further CPU processing; forwarded entirely by Flow Processor
- **Automatic graduation**: Flows transition from DPI to FastPath after initial inspection completes
- **Impact**: Dramatically reduces CPU utilization for bulk traffic (streaming, file transfers, established sessions)

#### 3. DPI Engine Lane
- **Purpose**: Full content inspection for new and untrusted flows
- **Processing**: IPS signatures, application identification, malware scanning (AV), web filtering, content policy
- **CPU-bound**: Runs on general-purpose processors
- **v22 containerization**: DPI services run as isolated containers; independent restart and update
- **Output**: Accept (graduate to FastPath for remaining flow), block (drop/reset), or continue monitoring

### Adaptive Routing Logic
```
New flow arrives
  -> Policy evaluation (which lane?)
  -> TLS encrypted? -> TLS Inspection Lane -> Decrypt -> DPI Engine Lane
  -> Unencrypted? -> DPI Engine Lane directly
  -> DPI verdict: Accept -> Graduate to FastPath
  -> DPI verdict: Block -> Drop/Reset
  -> Established flow already inspected -> FastPath Lane (no CPU)
```

## Synchronized Security

### Security Heartbeat Protocol
- Sophos Endpoint agent establishes a persistent encrypted channel to Sophos Firewall
- Heartbeat transmitted at regular intervals (configurable, default ~15 seconds)
- Each heartbeat carries the endpoint's current health status

### Health Status Levels

| Status | Meaning | Typical Firewall Response |
|---|---|---|
| Green | Healthy; no threats detected | Full network access per policy |
| Yellow | PUA detected or minor issue | Restricted access (configurable) |
| Red | Active threat (malware, ransomware) | Isolate: block all except remediation |
| Missing | Agent not communicating | Optionally restrict (configurable) |

### Lateral Movement Protection
When an endpoint reports Red:
1. Firewall immediately restricts all traffic from that endpoint's IP
2. Other Sophos-managed endpoints on the same network segment also block communication with the compromised host
3. Only traffic to Sophos Central for remediation is permitted
4. Isolation persists until endpoint returns to Green or admin overrides

### Integration Scope
Synchronized Security connects: Sophos Firewall, Sophos Endpoint (Intercept X), Sophos Email, Sophos Mobile, Sophos Wireless. Each product contributes telemetry; firewall enforces network-level policy decisions.

### Active Threat Response
- SOC analysts using Sophos MDR or XDR can manually push threat feed entries
- Firewall receives analyst signals and enforces corresponding blocks
- Extends automated response to human-driven threat hunting

## Sophos Central Cloud Management

### Architecture
- SaaS management platform hosted by Sophos
- Firewalls connect outbound to Central (HTTPS); no inbound ports required
- Central stores configuration templates, firmware images, reporting data

### Capabilities
- **Firewall Group Policies** -- Deploy configuration templates across multiple firewalls
- **Cloud Reporting** -- Log analysis, traffic dashboards, compliance reports
- **Firmware Management** -- Schedule updates, view history, rollback
- **License Management** -- View, assign, renew licenses
- **Alert Center** -- Unified alerts across all Sophos products
- **API Access** -- REST API for programmatic management and SIEM integration

### Zero-Touch Deployment
1. Admin registers appliance serial number in Sophos Central
2. Full configuration pre-built and assigned in Central
3. Non-technical staff connects WAN, LAN, powers on
4. Appliance obtains DHCP on WAN, contacts Central, downloads config
5. Fully operational within minutes; no on-site engineer required

## ZTNA Gateway

### Architecture
- ZTNA Gateway runs as a VM or on a dedicated Sophos Firewall
- Sits in front of internal applications; replaces traditional VPN
- Combined ZTNA + Intercept X agent on endpoints (no separate VPN client)

### Access Decisions
Based on three factors:
1. **User identity** -- SAML/OIDC integration with IdP (Azure AD, Okta, etc.)
2. **Device health** -- Security Heartbeat status must be Green (or Yellow, configurable)
3. **Application policy** -- Per-application authorization rules

### Micro-Segmentation
- Users access only specific authorized applications, not entire network segments
- Each application has its own access policy
- Red heartbeat automatically revokes all ZTNA access mid-session

### Management
Entirely from Sophos Central; no gateway-side configuration required.

## SD-WAN

### Capabilities
- **Performance-based routing** -- Monitor latency, jitter, packet loss per WAN link; dynamically reroute
- **Policy-based routing** -- Assign specific apps/user groups to preferred WAN links
- **WAN link load balancing** -- Active/active across multiple ISPs; weighted or round-robin
- **Traffic shaping / QoS** -- Per-application, per-user bandwidth allocation and prioritization
- **SD-WAN orchestration** -- Configure fabric and overlay tunnels from Sophos Central
- **VPN integration** -- SD-WAN policies apply over IPsec/SSL VPN tunnels between sites

## v22 Architecture Enhancements

### Containerized Services
- DPI, IPS, and other security services run as isolated containers
- Each container can be independently updated, restarted, and scaled
- Container isolation reduces blast radius of potential exploits
- `system service restart <service>` restarts individual services without OS reboot

### Hardened Kernel (Linux 6.6+ LTS)
- KASLR -- Randomized kernel memory layout
- Stack canaries -- Compile-time buffer overflow protection
- Hardened usercopy -- Protected kernel/user memory operations
- Tighter process isolation -- Reduced inter-process attack surface
- CPU side-channel mitigations -- Spectre, Meltdown, L1TF, MDS, Retbleed, ZenBleed, Downfall

### CIS Health Check
- Dashboard-accessible configuration audit
- Compares against CIS benchmarks and Sophos best practices
- Severity levels: Critical, High, Medium, Low
- Actionable remediation for each finding
- Exportable PDF for compliance documentation

### XDR Linux Sensor
- Embedded integrity monitoring agent
- Detects: unauthorized config changes, malicious execution attempts, file tampering, rule export events
- Reports to Sophos Central XDR for correlation with endpoint and email telemetry

## Firewall Rules Architecture

### Network Rules
- Zone-based: source zone, destination zone, source/destination IP, service/port
- Application-aware: DPI engine identifies application regardless of port
- Per-rule security profiles: IPS, web filter, app control, SSL inspection, QoS
- User identity matching: AD/LDAP SSO, RADIUS, Captive Portal
- Top-down evaluation; implicit deny at bottom

### WAF Rules
- Reverse proxy for published web applications
- OWASP Top 10 protection, form hardening, cookie signing
- URL/verb-based ACLs, geographic restrictions
- Client authentication: form-based, NTLM, client certificate
- Backend load balancing with health checks

### NAT
- **Linked NAT** -- NAT applied directly within a firewall rule (most common)
- **Standalone NAT** -- Separate NAT rules independent of firewall rules
- Source NAT (masquerade), destination NAT (DNAT), 1:1 NAT

## API Architecture

### Local Firewall API
- Base URL: `https://<firewall-ip>:4444/webconsole/APIController`
- XML-based request/response format
- Authentication: admin credentials in XML payload; returns session token
- Methods: GET, SET, ADD, REMOVE
- Covers: firewall rules, NAT, hosts/networks, users, VPN, services, zones

### Sophos Central API
- REST API with JSON format
- OAuth2 authentication with client credentials
- Endpoints for: device management, policy management, alerts, reporting
- Supports SIEM integration via event streaming
