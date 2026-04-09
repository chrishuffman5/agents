# Sophos Firewall Deep Dive — v22 / XGS / Xstream

## Overview

Sophos Firewall is Sophos's next-generation firewall platform, available as physical appliances (XGS Series), virtual machines (XGV), and cloud instances (AWS/Azure/GCP). Version **v22** was released in December 2025 as a major milestone focused on "Secure by Design" — hardened kernel, containerized services, and CIS benchmark-aligned health checks. Managed via local WebAdmin, Sophos Central (cloud), or API.

---

## v22 Major Features

### Hardened Kernel
- Upgraded to **Linux kernel 6.6+** (Long Term Support), replacing the prior 4.x kernel.
- Mitigations built into the OS for known CPU side-channel vulnerabilities: Spectre, Meltdown, L1TF (L1 Terminal Fault), MDS (Microarchitectural Data Sampling), Retbleed, ZenBleed, Downfall.
- **Hardened usercopy** — prevents exploitation of kernel/user space copy operations.
- **KASLR (Kernel Address Space Layout Randomization)** — randomizes kernel memory layout to defeat memory-based exploits.
- **Stack canaries** — compile-time protection against stack buffer overflow attacks.
- **Tighter process isolation** — reduced blast radius if a service is compromised.

### Containerized Services Architecture
- Services such as IPS (Intrusion Prevention System), DPI, and others now run as **isolated containers** ("apps") on the firewall platform.
- Enables independent update, restart, and scaling of individual services without rebooting the entire OS.
- Aligns with the modular design philosophy introduced by the Xstream architecture.
- Reduces attack surface — compromise of one containerized service does not automatically cascade to others.

### CIS Health Check
- New **Health Check** feature (accessible via WebAdmin dashboard) evaluates dozens of configuration settings.
- Compares configuration against **CIS (Center for Internet Security) benchmarks** and Sophos best practices.
- Categorizes findings as: Critical, High, Medium, Low risk.
- Provides actionable remediation recommendations for each finding.
- Exportable report for compliance documentation and audit purposes.

### XDR Linux Sensor Integration
- **Sophos XDR Linux Sensor** embedded in v22 for remote integrity monitoring.
- Real-time detection of: unauthorized configuration changes, malicious program execution attempts, file tampering, rule export events.
- Integrates with Sophos Central XDR for unified threat hunting across firewall and endpoints.

---

## XGS Hardware Series

Sophos XGS appliances are purpose-built with dedicated **Xstream Flow Processors** (FPGAs) alongside general-purpose CPUs:

| Model Range | Target | Throughput (FW/NGFW) | Key Interfaces |
|---|---|---|---|
| XGS 87 / 107 / 116 / 126 / 136 | SOHO/Branch | 3–7 Gbps FW | 4–8x GbE copper |
| XGS 2100 / 2300 | SMB | 15–20 Gbps FW | 8x GbE, 2x SFP+ |
| XGS 3100 / 3300 | Mid-market | 30–50 Gbps FW | 8x GbE, 4x SFP+, expansion |
| XGS 4300 / 4500 | Enterprise | 80–100 Gbps FW | 4x SFP+, 2x QSFP+, modular |
| XGS 5500 / 6500 | DC/Carrier | 170–320 Gbps FW | 8x QSFP+, 2x QSFP28 |

- **Xstream Flow Processor** — dedicated hardware for TLS 1.3 decryption/re-encryption at line rate; offloads CPU for FastPath packet forwarding.
- All models support HA active/passive and active/active (SD-WAN with load balancing) configurations.
- **Zero-touch deployment** via Sophos Central — pre-register serial number, ship to site, unit phones home and self-configures.

---

## Xstream Architecture

Xstream is the data plane architecture introduced in v18 and significantly enhanced through v22:

### Three Processing Lanes

1. **TLS Inspection Lane** — Hardware-accelerated TLS 1.3 decrypt/re-encrypt using the dedicated Flow Processor; applies full DPI to HTTPS without CPU bottleneck. Supports certificate pinning bypass lists, category exclusions, and per-rule inspection policies.

2. **FastPath Lane** — Trusted, already-inspected traffic (e.g., returning flows that passed full DPI on first packet) is offloaded to hardware FastPath. No further processing; line-rate forwarding. Dramatically reduces CPU load for established sessions.

3. **DPI Engine Lane** — Deep Packet Inspection for new/untrusted flows; runs IPS signatures (containerized in v22), application identification, malware scanning, web filtering. CPU-bound processing for complex inspection.

### Adaptive Traffic Routing
- Xstream intelligently routes each flow to the appropriate lane based on trust level, rule policy, and content.
- Previously inspected and approved flows graduate to FastPath automatically.
- Suspicious or unclassified traffic routed through full DPI.

---

## Firewall Rules

### Network Firewall Rules
- Standard 5-tuple matching (source zone, destination zone, source IP, destination IP, service/port).
- Application-aware matching — identify applications by deep inspection independent of port.
- **Security Profiles** attached per rule: IPS, web filter, application control, SSL inspection, QoS, traffic shaping.
- **User identity** matching via AD/LDAP SSO, RADIUS, or Captive Portal.
- Rules evaluated top-down; implicit deny at bottom.
- **Linked NAT rules** — NAT can be applied directly within a firewall rule (linked mode) or as a separate rule.

### Web Application Firewall (WAF / Reverse Proxy) Rules
- L7 protection for published web applications; distinct from network firewall rules.
- OWASP Top 10 protection, form hardening, cookie signing.
- URL and verb-based access control; geographic restrictions.
- Client authentication (form-based, NTLM, client certificate).
- Load balancing across backend servers with health checks.

---

## SSL/TLS Inspection

- Supports **TLS 1.0 through TLS 1.3** decryption.
- **Outbound (forward proxy)** — inspect user-initiated HTTPS; re-signs certificates with Sophos CA.
- **Inbound (reverse proxy / WAF mode)** — terminate TLS for published applications; applies WAF ruleset.
- **Inspection profiles** — configure which categories, source/destination networks, and users are inspected or excluded.
- **Certificate pinned sites** — bypass list for sites that use HPKP or break under re-signing.
- Hardware acceleration via Xstream Flow Processor makes TLS inspection viable at full throughput.
- **TLS 1.3 support** — decrypts and re-encrypts 1.3 sessions (requires active interception mode, not passive tap).

---

## Synchronized Security

Sophos Synchronized Security is the integration layer between Sophos Firewall and Sophos Endpoint (Intercept X):

### Security Heartbeat
- Sophos Endpoint Agent sends a continuous **heartbeat** to the Sophos Firewall over an encrypted channel.
- Heartbeat carries **health status**: Green (healthy), Yellow (potentially unwanted application / PUA detected), Red (active threat detected).
- Firewall makes **real-time policy decisions** based on endpoint health:
  - Red heartbeat: isolate the endpoint (block all traffic except to Sophos Central for remediation).
  - Yellow heartbeat: restrict access (e.g., block internet, allow only corporate apps).
  - Missing heartbeat: optionally restrict (configurable policy).

### Lateral Movement Protection
- When an endpoint is compromised (Red), **Synchronized Security automatically isolates it** from the network — no manual intervention.
- Other endpoints on the same VLAN cannot communicate with the isolated host.
- Prevents lateral movement of ransomware and APTs within the network.
- Isolation occurs in **seconds** — dramatically faster than manual SOC response.

### Active Threat Response
- SOC analysts using **Sophos MDR** or **Sophos XDR** can manually trigger Synchronized Security responses.
- Threat feed capability built into Sophos Firewall receives analyst signals from XDR.
- Expands Synchronized Security beyond automated endpoint events to human-in-the-loop SOC actions.

### Integration Scope
Synchronized Security works across: Sophos Firewall, Sophos Endpoint (Intercept X), Sophos Email, Sophos Mobile, Sophos Wireless.

---

## Sophos Central Cloud Management

Sophos Central is the unified SaaS management platform for all Sophos products:

- **Single Pane of Glass** — manage Firewall, Endpoint, Email, Mobile, Wireless, ZTNA from one console.
- **Firewall Group Policies** — deploy configuration templates across multiple firewalls simultaneously.
- **Firewall Reporting** — cloud-hosted log analysis, traffic dashboards, compliance reports; no on-prem log server required.
- **Firmware Management** — schedule firmware updates, view update history, rollback.
- **License Management** — view, assign, and renew licenses centrally.
- **Alert Center** — unified alerts from all Sophos products; correlate firewall events with endpoint detections.
- **API Access** — Sophos Central exposes REST API for programmatic management and SIEM integration.

---

## ZTNA Gateway

Sophos ZTNA (Zero Trust Network Access) replaces traditional VPN with identity and device-aware access:

- **Gateway Deployment** — ZTNA Gateway runs as a VM or on a dedicated Sophos Firewall; sits in front of internal applications.
- **Single Agent** — Combined ZTNA + Intercept X agent; no separate VPN client.
- **Identity-aware** — Access decisions based on: user identity (SAML/OIDC IdP), device health (Security Heartbeat), application policy.
- **Micro-segmentation** — Users access only the specific applications they're authorized for, not entire network segments.
- **Security Heartbeat Integration** — Compromised devices (Red heartbeat) automatically lose ZTNA access even mid-session.
- Managed entirely from Sophos Central; no gateway configuration required on-site.

---

## SD-WAN

- **Traffic Shaping and QoS** — per-application, per-user bandwidth allocation and prioritization.
- **WAN Link Load Balancing** — active/active across multiple ISPs; weighted or round-robin distribution.
- **Policy-based Routing** — route specific applications or user groups over preferred WAN links (e.g., VoIP over MPLS, web browsing over broadband).
- **Performance-based Routing** — dynamically switch WAN links based on measured latency, jitter, packet loss.
- **SD-WAN Orchestration** — configure SD-WAN fabric and overlay tunnels from Sophos Central.
- **Site-to-Site VPN Integration** — SD-WAN policies apply over IPsec/SSL VPN tunnels between sites.

---

## Zero-Touch Deployment

1. **Pre-registration** — Admin registers appliance serial number in Sophos Central before shipment.
2. **Site Configuration** — Full firewall configuration (policies, VLANs, VPN, users) pre-built and assigned in Sophos Central.
3. **Deployment** — Non-technical staff unboxes appliance, connects WAN and LAN cables, powers on.
4. **Auto-Provisioning** — Appliance connects to internet (DHCP on WAN), contacts Sophos Central, downloads and applies configuration.
5. **Operational** — Firewall fully configured within minutes; no on-site engineer required.

---

## API

Sophos Firewall exposes a REST API for programmatic management:

- **Base URL**: `https://<firewall-ip>:4444/webconsole/APIController`
- **Authentication**: XML-based login with credentials; session token returned.
- **Methods**: Supports GET (query), SET (modify), ADD (create), REMOVE (delete) operations.
- **Scope**: Nearly all configuration objects accessible via API — firewall rules, NAT, hosts/networks, users, VPN, services.
- **Use Cases**: Terraform provider, Ansible modules, SOAR integration, custom scripts.
- Sophos Central also provides its own REST API for central management operations and reporting.

---

## Common Admin Tasks

```bash
# Check system status (from console/SSH)
show system diagnostics

# Test firewall rule evaluation
show firewall rule matching src=10.1.1.10 dst=8.8.8.8 port=443

# View active connections
show connection detail

# Check IPS status
show ips status

# SD-WAN link status
show routing detail

# Restart a containerized service (v22+)
system service restart ips

# Check TLS inspection stats
show tls-inspection stats

# Heartbeat status for connected endpoints
show synchronized-security status

# Run CIS Health Check (WebAdmin only, or via API call)
# Dashboard > Health Check > Run Now
```

---

## References

- [Sophos Firewall v22 Security Enhancements — Sophos News](https://news.sophos.com/en-us/2025/11/05/faster-safer-stronger-sophos-firewall-v22-security-enhancements/)
- [Sophos Firewall v22 Now Available — Sophos News](https://news.sophos.com/en-us/2025/12/09/sophos-firewall-v22-is-now-available/)
- [v22 Architecture Update — TrueNetLab](https://truenetlab.com/en/blog/sophos-firewall-v22-health-check-architecture-update/)
- [Synchronized Security Overview](https://www.sophos.com/en-us/content/synchronized-security)
- [Sophos ZTNA Product Page](https://www.sophos.com/en-us/products/zero-trust-network-access)
- [Sophos Firewall Product Page](https://www.sophos.com/en-us/products/next-gen-firewall)
