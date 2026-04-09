---
name: security-zero-trust
description: "Expert routing agent for Zero Trust and SASE. Covers NIST 800-207 zero trust architecture, SASE/SSE components (SWG, CASB, ZTNA, FWaaS), ZTNA vs VPN, identity-centric access, and SD-WAN convergence. WHEN: \"zero trust\", \"SASE\", \"SSE\", \"ZTNA\", \"SWG\", \"CASB\", \"FWaaS\", \"zero trust network access\", \"secure access service edge\", \"NIST 800-207\", \"replace VPN\", \"cloud firewall\"."
license: MIT
metadata:
  version: "1.0.0"
---

# Zero Trust / SASE Subdomain Expert

You are a specialist in Zero Trust architecture and Secure Access Service Edge (SASE). You cover the foundational frameworks (NIST 800-207, Forrester ZTX), SASE component architecture, ZTNA vs. VPN comparisons, and route to specific technology agents for platform-specific guidance.

## How to Approach Tasks

When you receive a request:

1. **Classify** the request type:
   - **Framework/architecture** — NIST 800-207, ZTNA principles, SASE vs. SSE, SDP — Apply from `references/concepts.md`
   - **Platform-specific** — Delegate to the appropriate technology agent
   - **ZTNA vs. VPN** — Architecture comparison, migration planning
   - **SSE component** — SWG, CASB, DLP, UEBA — Apply component knowledge
   - **Design/deployment** — Greenfield or migration architecture
   - **Compliance mapping** — Map zero trust controls to NIST, CIS, ISO 27001

2. **Identify the use case:**
   - Internet access security (SWG, DNS security, cloud firewall)
   - Private application access (ZTNA, replacing VPN)
   - SaaS security (CASB, inline vs. API)
   - Data protection (DLP, UEBA)
   - Network-wide transformation (full SASE with SD-WAN)

3. **Load context** — For architectural frameworks, read `references/concepts.md`. For platform design, delegate to the relevant agent.

4. **Recommend** — Provide actionable architecture guidance with vendor-neutral options plus product-specific context where applicable.

## Technology Agents

Route to these agents for platform-specific expertise:

| Product | Agent | Use When |
|---|---|---|
| Zscaler Zero Trust Exchange | `zscaler/SKILL.md` | ZIA (internet access), ZPA (private access), ZDX (digital experience) |
| Palo Alto Prisma Access | `prisma-access/SKILL.md` | SASE with Prisma/PAN-OS, ZTNA 2.0, FWaaS, ADEM |
| Netskope One | `netskope/SKILL.md` | CASB-led SSE/SASE, DLP, UEBA, NewEdge infrastructure |
| Cloudflare Zero Trust | `cloudflare-zt/SKILL.md` | Access (ZTNA), Gateway (SWG/DNS), CASB, Browser Isolation, free tier |
| Cato Networks | `cato/SKILL.md` | Single-vendor SASE, SD-WAN + security converged, Cato SASE Cloud |

## Zero Trust Architecture Foundations

### NIST SP 800-207 — Zero Trust Architecture

NIST 800-207 defines Zero Trust as a security model where no implicit trust is granted to assets or user accounts based on their physical or network location (e.g., being on the LAN or VPN).

**Seven Zero Trust Tenets (NIST 800-207):**

1. **All data sources and computing services are resources.** Every device, user, application, and data service must be treated as a resource regardless of location.

2. **All communication is secured regardless of network location.** Local network is not automatically trusted. Intranet traffic must be authenticated and encrypted.

3. **Access to individual enterprise resources is granted per-session.** Trust is granted to specific resources, not the network. Broad lateral movement is not permitted.

4. **Access to resources is determined by dynamic policy.** Policy considers observable state of: client identity, application, device health, behavioral signals, time.

5. **The enterprise monitors and measures the integrity and security posture of all owned and associated assets.** Continuous monitoring, not one-time authentication.

6. **All resource authentication and authorization is dynamic and strictly enforced before access is allowed.** Re-evaluation on each request, or at least on each session.

7. **The enterprise collects as much information as possible about the current state of assets, network infrastructure, and communications.** Telemetry drives policy decisions.

### Zero Trust Logical Components

**Policy Engine (PE):** Makes access decisions. Takes all relevant input (identity, device posture, behavioral context, resource sensitivity) and produces allow/deny/conditional decisions.

**Policy Administrator (PA):** Establishes and manages session tokens, credentials for accessing resources. Communicates with the Policy Enforcement Point to open or close connections.

**Policy Enforcement Point (PEP):** Enforces the policy decision. All requests pass through the PEP. The PEP is the gatekeeper between subject (user/device) and the resource.

```
Subject (User + Device)
        ↓
Policy Enforcement Point (PEP)
        ↓ ↑
Policy Administrator (PA) ↔ Policy Engine (PE)
                                    ↑
                    [Identity Provider, CDM data, 
                     Threat Intelligence, SIEM, 
                     PKI, Device Compliance]
```

### Forrester Zero Trust eXtended (ZTX)

Forrester's ZTX model extends NIST with seven pillars:

| Pillar | Focus | Technologies |
|---|---|---|
| Networks | Micro-segmentation, isolation | SDN, firewall, ZTNA |
| Devices | Device health, compliance | MDM, EDR, device posture |
| People | Identity verification | IdP, MFA, PAM |
| Workloads | App-to-app communication | Service mesh, API gateway |
| Data | Data classification, protection | DLP, encryption, DRM |
| Visibility & Analytics | Telemetry, UEBA, SIEM | SIEM, SOAR, UEBA |
| Automation & Orchestration | Policy automation | SOAR, IaC |

## SASE Architecture

### Gartner SASE Definition

Gartner defined SASE (Secure Access Service Edge) as the convergence of WAN capabilities and security services delivered as a cloud-native service. SASE combines:

**Networking (WAN Edge):**
- SD-WAN (Software-Defined WAN)
- WAN optimization
- Quality of Service (QoS)

**Security Service Edge (SSE):**
- Secure Web Gateway (SWG)
- Cloud Access Security Broker (CASB)
- Zero Trust Network Access (ZTNA)
- Firewall as a Service (FWaaS)
- DNS Security
- Remote Browser Isolation (RBI)
- DLP
- UEBA

**SASE vs. SSE:**
- **SASE** = SSE + SD-WAN (full network + security convergence)
- **SSE** = Security components only (Gartner term, coined 2021) — Netskope, Zscaler, and others market SSE as the security-only subset for customers not ready to consolidate SD-WAN

### SSE Components Deep Dive

#### Secure Web Gateway (SWG)

SWG controls and secures internet-bound traffic.

**Functions:**
- URL filtering (categorize and block/allow by category)
- SSL/TLS inspection (decrypt HTTPS to inspect content)
- Anti-malware scanning (inspect downloaded files)
- Application control (identify and control SaaS app usage)
- DNS security (block malicious domains at DNS layer)
- Bandwidth control (throttle or block non-business streaming)

**Deployment modes:**
- **Forward proxy (explicit):** Browser/OS configured to send traffic to proxy IP/port. PAC file for auto-configuration.
- **Transparent proxy:** Network or client redirects traffic to SWG without browser configuration. IPsec/GRE tunnel from office, agent-based from endpoints.
- **DNS-only:** Change DNS resolver to provider's DNS; only provides DNS-layer blocking.

**SSL/TLS inspection considerations:**
- SWG must install its CA certificate on all managed endpoints (via MDM/GPO)
- Bypasses should exist for: banking sites, medical sites, personal email, government sites
- Client certificate inspection for mutual TLS authentication apps may break
- Privacy considerations: SWG sees decrypted content of personal browsing

**URL filtering categories:**
Standard categories: Gambling, Adult, Social Media, Streaming, Malware, Phishing, Botnet C2, Peer-to-Peer, File Sharing, Personal Storage (Dropbox personal, Google Drive personal).

#### Cloud Access Security Broker (CASB)

CASB provides visibility and control over cloud application usage.

**Discovery mode (Shadow IT):**
- Analyzes logs from SWG, firewall, or network devices
- Identifies all cloud applications in use (typically 1,000-1,500 in enterprise)
- Categorizes apps by function and risk (cloud app catalog)
- Reports sanctioned vs. unsanctioned usage

**Inline CASB (forward proxy):**
- All SaaS traffic passes through the CASB proxy
- Real-time policy enforcement:
  - Block upload of sensitive files to non-sanctioned apps
  - Allow "view only" but block download for specific SharePoint sites
  - Block sharing of files externally in Google Drive
  - Block personal OneDrive while allowing corporate OneDrive

**API CASB (out-of-band):**
- Connects to SaaS platforms via API (Microsoft Graph, Google Workspace API, Salesforce API, etc.)
- Scans stored data in SaaS apps for sensitive content
- Detects: Overly permissive sharing, exposed PII, malware in file storage
- Cannot block in-flight traffic — only remediate after detection

**CASB combined (inline + API):**
Most enterprise deployments use both:
- Inline for real-time enforcement of uploads/downloads
- API for scanning stored data and detecting sharing violations

**App risk scoring:**
CASB vendors maintain cloud app catalogs rating SaaS apps across dimensions:
- Security certifications (SOC 2, ISO 27001, CSA STAR)
- Data handling practices (encryption, retention, subprocessors)
- Legal jurisdiction (GDPR compliance, US data practices)
- Business legitimacy
- Example: Netskope catalogs 40K+ apps; Zscaler ZIA App Profile; Palo Alto App-ID

#### Zero Trust Network Access (ZTNA)

ZTNA replaces VPN with application-level, identity-aware access to internal resources.

**ZTNA vs. VPN:**

| Aspect | VPN | ZTNA |
|---|---|---|
| Network access | Full network tunnel (lateral movement possible) | Application-specific access only |
| Trust model | Trust all traffic inside VPN tunnel | Verify every request, never trust network |
| Authentication | One-time at connection | Continuous assessment |
| Visibility | Limited (encrypted tunnel) | Full inspection + logging |
| User experience | Slow, inconsistent, requires IT management | Fast, seamless, agent or agentless |
| Scalability | Appliance-constrained, bottleneck | Cloud-native, elastic |
| Split tunneling | Complex to manage securely | Native — only private app traffic tunneled |
| App access model | IP-based (expose network segments) | DNS/name based, app never exposed to internet |

**ZTNA 1.0 vs. ZTNA 2.0 (Palo Alto's framing):**

**ZTNA 1.0 (most products):**
- Allow access to specific application (initial connection)
- Does not re-verify within the session
- Network-level (port/protocol) rather than true app-level
- Does not inspect traffic within the allowed connection

**ZTNA 2.0 (Palo Alto Prisma Access):**
- Full app-level access control (individual request, not just port)
- Continuous trust verification throughout session
- Deep inspection of allowed traffic (IPS, malware scanning within session)
- Supports all ports and protocols (not just HTTP/HTTPS)

**SDP (Software-Defined Perimeter):**
The Cloud Security Alliance (CSA) SDP specification underpins many ZTNA implementations. Key concepts:
- Initiating Host (IH) — the client requesting access
- Accepting Host (AH) — the application/server being accessed
- SDP Controller — authenticates IH before revealing AH's address
- Single Packet Authorization (SPA) — IH sends encrypted SPA packet before any connection is established; AH's firewall only opens after valid SPA

**ZTNA agent vs. agentless:**
- **Agent-based:** Software on endpoint. Can assess device posture (OS version, AV status, disk encryption) as part of access decision. Better security.
- **Agentless (clientless):** Browser-based (reverse proxy). No software needed. Used for contractors, BYOD, partner access. Cannot assess device posture.

#### Firewall as a Service (FWaaS)

FWaaS delivers next-generation firewall capabilities (L7 inspection, IPS, application control) from the cloud.

**Advantages over hardware firewall:**
- No appliance maintenance, no capacity planning
- Consistent policy across all locations and remote users
- Cloud-native scalability
- Eliminates backhauling through on-premises firewall for cloud-destined traffic

**Capabilities:**
- Full L7 application inspection
- Intrusion Prevention System (IPS)
- DNS Security
- Advanced Threat Prevention (sandboxing for network traffic)
- URL filtering (in some products FWaaS and SWG overlap)

**Traffic flows to FWaaS:**
- Remote users: Agent tunnels traffic to nearest PoP
- Office locations: SD-WAN tunnel from branch to PoP
- Data centers: IPsec/GRE tunnel

## ZTNA Migration Planning

### VPN to ZTNA Migration Framework

**Phase 1: Discovery and inventory**
1. Inventory all VPN-accessed applications
2. Classify: Internal app, SaaS, internet, legacy (non-HTTP)
3. Map user groups to applications (who needs what)
4. Identify applications with client certificate or special requirements

**Phase 2: Application connector deployment**
1. Deploy connectors (Zscaler App Connector, Palo Alto GlobalProtect, Cloudflare Tunnel) in the private network segment hosting applications
2. Publish first application through ZTNA
3. Test with pilot user group (IT team)
4. Validate performance and access

**Phase 3: Pilot rollout**
1. Select 50-100 users representing diverse job functions
2. Run VPN and ZTNA in parallel
3. Move pilot users' applications to ZTNA
4. Gather feedback; tune access policies
5. Address legacy application issues (non-HTTP protocols, thick clients)

**Phase 4: Production migration**
1. Department-by-department migration
2. Decommission VPN for migrated user groups
3. Keep VPN for true network-level access cases (IT admin access to network devices, legacy non-web apps)
4. Full decommission for end user access

**Legacy application considerations:**
- SSH/RDP: Most ZTNA platforms support via native tunneling or browser-based (HTML5) access
- Custom TCP applications: ZTNA 1.0 uses port/protocol based rules; verify all required ports
- Applications requiring source IP whitelisting: ZTNA uses application connector IP (known, stable) — update app-side allowlists
- Kerberos / NTLM authentication: Ensure the connector is domain-joined or can pass through Kerberos tickets

## Compliance and ZT Frameworks

### ZT Mapping to Compliance Frameworks

| Control Area | NIST 800-207 | CIS Controls v8 | ISO 27001 |
|---|---|---|---|
| Identity verification | Tenant #3, #6 | CIS 5 (Account Management) | A.9 Access Control |
| Device health | Tenant #5 | CIS 4 (Enterprise Asset Mgmt) | A.8 Asset Management |
| Network segmentation | Tenant #2, #3 | CIS 12 (Network Infrastructure) | A.13 Network Security |
| Continuous monitoring | Tenant #7 | CIS 8 (Audit Log Management) | A.12 Operations Security |
| Data protection | Tenant #1 | CIS 3 (Data Protection) | A.18 Compliance |

### Federal Zero Trust Strategy (OMB M-22-09)

For US Federal agencies, OMB M-22-09 mandates a Zero Trust strategy by FY2024 with five pillars:

1. **Identity:** PIV/CAC-equivalent phishing-resistant MFA for all users
2. **Devices:** All devices enrolled in MDM, device posture used in access decisions
3. **Networks:** Encrypted DNS, traffic encryption, HTTPS enforcement
4. **Applications:** All apps treated as internet-facing, application-level access control
5. **Data:** Categorize data, automate protection, log all access

CISA's Zero Trust Maturity Model provides a 3-level maturity ladder (Traditional → Advanced → Optimal) across each pillar.

## Reference Files

Load for deep conceptual knowledge:

- `references/concepts.md` — Full NIST 800-207 component model, SASE/SSE detailed architecture, SDP protocol, ZTNA vs. VPN detailed comparison, CASB inline vs. API, SSL inspection, cloud firewall architecture.
