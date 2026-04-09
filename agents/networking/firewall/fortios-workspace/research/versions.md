# FortiOS Version Reference

## Version Lifecycle Overview

| Version | GA Release | End of Engineering Support (EOES) | End of Support (EOS) | Status |
|---------|-----------|----------------------------------|----------------------|--------|
| 7.0 | 2021-03-30 | 2024-03-30 | 2025-09-30 | EOL/EOS approaching |
| 7.2 | 2022-03-31 | 2025-03-31 | 2026-09-30 | Post-EOES |
| 7.4 | 2023-05-11 | 2027-05-11 | 2028-11-11 | Supported |
| 7.6 | 2024-07-25 | 2028-07-25 | 2030-01-25 | Current recommended |

**EOES definition:** After EOES, Fortinet only produces maintenance builds for industry-wide critical issues and PSIRT (Product Security Incident Response Team) vulnerabilities. No new feature development or standard bug fixes.

**EOS definition:** Full end of support; no maintenance builds of any kind.

**EOS formula:** Approximately 54 months after GA release.

---

## FortiOS 7.2 (GA: March 2022)

### Lifecycle Status (as of April 2026)
- Past EOES (March 31, 2025)
- EOS: September 30, 2026
- Recommendation: Plan migration to 7.4 or 7.6; no new features; only critical PSIRT patches
- Latest stable release: 7.2.13+

### Key Features Introduced in 7.2
**Security Services:**
- Inline Sandbox: real-time in-network malware prevention (not just detection)
- Inline CASB (Cloud Access Security Broker): integrates with FortiClient for inline ZTNA traffic inspection
- Outbreak Detection Service: immediate alerts with automated threat hunting scripts
- SOC-as-a-Service: tier-one analysis offload to Fortinet experts
- Dedicated IPS mode: migrate from standalone hardware IPS to FortiGate NGFW
- Advanced Device Protection: automatic OT/IoT device discovery and segmentation

**Networking:**
- HTTP/3.0 support: first NGFW to inspect HTTP/3 (QUIC-based) traffic
- SD-WAN VRF segmentation over single overlay: L3 VPN segmentation with multiple VRFs on hub-spoke
- BGP extended community route target matching in route maps
- MOS (Mean Opinion Score) tracking for voice/video quality measurement in SD-WAN
- SD-Branch: 5G Wireless WAN + SD-WAN + NGFW + LAN in single solution

**ZTNA:**
- Universal ZTNA enforcement across all work locations (office and remote)
- Unified ZTNA policy GUI (single pane for access proxy rules)
- SSL VPN web portal integration into ZTNA access proxy settings
- Improved service portal management

**Management:**
- Enhanced zero-touch provisioning for large deployments
- AIOps integration via FortiManager for AI-driven network operations
- Digital Experience Monitoring (DEM) via FortiMonitor
- FortiManager integration: per-device ADOM meta variables

**Identity:**
- Cloud-based authentication services
- FIDO-based passwordless MFA

### 7.2 Upgrade Notes
- Major upgrade from 6.4: requires intermediate stop at 7.0.x before going to 7.2
- Policy changes: inspection mode per policy introduced (flow/proxy selectable per policy since 6.2; matured in 7.x)
- SD-WAN: significant schema changes from 6.4 to 7.0; use FortiConverter for cross-version migrations

---

## FortiOS 7.4 (GA: May 2023)

### Lifecycle Status (as of April 2026)
- Active support, well within EOES window (May 2027)
- EOS: November 2028
- Recommendation: Stable production choice; mature codebase; many bug fixes available
- Latest recommended: 7.4.11+ (per Fortinet community guidance)

### Key Features Introduced in 7.4
**Security Fabric & Management:**
- Hybrid Mesh Firewall: unified management of diverse firewall deployments via FortiManager
- FortiManager + FortiSASE integration: unified policy management for cloud and on-premises
- AI/ML capabilities on FortiGate 7080F and similar high-end platforms
- FortiAnalyzer event correlation mapped to MITRE ATT&CK framework
- FortiSOAR ML-driven playbook recommendations and no-code playbook creation
- FortiNDR Cloud with 365-day data retention and built-in response playbooks

**ZTNA Enhancements:**
- Two ZTNA policy types: Full ZTNA Policy (under Proxy Policy) and Simple ZTNA Policy (regular Firewall Policy)
- User-based risk scoring for continuous access evaluation
- Continuous monitoring of application access sessions
- Improved ZTNA tag management and EMS connector stability

**SD-WAN:**
- Automated overlay orchestration improvements
- Redesigned SD-WAN monitoring map for global WAN status
- IPv6 support for SD-WAN segmentation over single overlay
- FortiAP integration with FortiSASE: secure micro-branch deployments
- SD-WAN performance analytics enhancements

**OT/ICS Security:**
- OT dashboard aligned with MITRE ATT&CK for ICS
- OT-specific threat analysis playbooks
- Enhanced OT device profiling and segmentation

**Application Security:**
- FortiDevSec runtime application security testing (SAST, DAST, SCA)

**FortiClient/EMS:**
- Enhanced EDR capabilities
- ZTNA continuous posture assessment improvements

### 7.4 Upgrade Notes
- Direct upgrade path from 7.2.x is supported (no intermediate stop required for most builds)
- Verify specific model upgrade path via docs.fortinet.com/upgrade-tool
- SD-WAN Orchestrator deprecated in 7.4 management; replaced by SD-WAN overlay templates in FortiManager
- Review ZTNA policy migration if using proxy-based policies from 7.2

---

## FortiOS 7.6 (GA: July 2024)

### Lifecycle Status (as of April 2026)
- Current recommended version for new deployments
- Active feature development track
- EOES: July 2028; EOS: January 2030
- Latest sub-releases include 7.6.5, 7.6.6

### Key Features Introduced in 7.6

**FortiAI (Generative AI Integration):**
- FortiAI replaces and extends "Fortinet Advisor" branding
- Natively integrated into FortiAnalyzer (central data lake) and FortiManager (management console)
- Natural language queries for threat investigation and remediation
- RAG (Retrieval-Augmented Generation) for accurate general questions
- Enhanced VPN operations diagnostics via AI assistant
- SD-WAN overlay configuration using FortiAI (FortiManager 7.6.2)

**SD-WAN Enhancements (20+ new capabilities):**
- SD-WAN Manager section in FortiManager for centralized SD-WAN config
- ADVPN 2.0 enhancements: overlay placeholders for spoke-to-spoke shortcuts (7.6.1)
- Enhanced shortcut triggering for distinct underlay paths (7.6.4)
- SD-WAN Setup wizard for guided deployment (7.6.1)
- Multi-hub support up to 4 hubs in overlay templates
- Traffic segmentation over single overlays with VRF support
- BGP deployment on loopback interfaces
- Passive TCP metrics monitoring (7.6.1)
- Fabric Overlay Orchestrator topology dashboard for hub devices (7.6.3)
- FortiTelemetry integration for app/network performance monitoring (7.6.3)
- IPv6 health-check protocols: HTTP and TWAMP (7.6.5)
- Speed test dynamic QoS application and automatic retry (7.6.5)
- Dead spoke detection: hubs suppress routes and adjust BGP metrics (7.6.5)
- IKE bandwidth negotiation for hub-to-spoke traffic shaping (7.6.4)
- Hybrid strategy support for SD-WAN service rules

**SASE Expansion:**
- Additional DLP capabilities for SASE platform
- Remote Browser Isolation (RBI) integration
- Digital Experience Monitoring (DEM) enhancements
- SASE Sovereign support (FortiSASE 91G/901G models)
- Integrated SSE + SD-WAN managed as SaaS

**ZTNA Enhancements:**
- UDP traffic destination support for ZTNA; connection over QUIC to FortiGate ZTNA gateway
- ZTNA web portal: end-user app access without FortiClient or client certificate checks
- Agentless web-based application access (7.6.1)
- HTTP2 connection handling improvements for access proxy

**FortiClient Unification:**
- Single agent includes: EDR, VPN, ZTNA, EPP (endpoint protection), DEM, NAC, SASE
- Reduces agent sprawl across endpoint capabilities

**Security Profile Enhancements (7.6.5):**
- Email protocol inspection re-enabled for 2GB RAM models (SMTP, POP3, IMAP)
- FortiSandbox timeout configuration for inline mode
- Post-Quantum Cryptography (PQC) for Agentless VPN
- TLS 1.3 hybrid PQC: SSL deep inspection supports X25519MLKEM768
- IPsec IKE negotiation on port 443 for UDP tunnels

**LAN Edge (7.6.5):**
- IPv6 management for FortiAP
- WPA3-SAE support in client mode on FWF G-series
- Automated certificate requests from EST/SCEP servers for FortiAPs
- Wi-Fi 7 Multi-Link Operation (MLO): simultaneous 2.4/5/6 GHz
- LoRaWAN gateway support on FortiAP 222KL
- 802.1X on virtual switches with explicit intra-switch-policy

**System (7.6.5):**
- NP7 denied session offloading (reduces CPU for dropped traffic)
- Quantum-resistant TLS on HTTPS management interface
- Federated upgrade reporting with per-device failure details
- Memory optimization for 2GB/4GB RAM platforms
- SNMP CGNAT monitoring OIDs

### 7.6 Upgrade Notes
- Upgrade path from 7.4: direct upgrade typically supported
- Upgrade path from 7.2: may require intermediate stop at 7.4.x; verify with upgrade tool
- Upgrade path from 6.4: must go through 7.0 → 7.2 → 7.4 → 7.6 in stages
- SSL VPN deprecation trajectory: Fortinet continues pushing ZTNA; SSL VPN still supported but ZTNA is strategic direction
- Default soft-switch interfaces removed in 7.6.5; review interface configurations before upgrade

---

## Firmware Upgrade Best Practices

### Using the Upgrade Path Tool
- URL: https://docs.fortinet.com/upgrade-tool
- Input: current version, target version, model number
- Tool calculates shortest tested upgrade path
- Never skip intermediate builds on major version jumps

### Upgrade Path Examples (common scenarios)
- 7.4.x → 7.6.x: Direct upgrade supported for most models
- 7.2.x → 7.6.x: 7.2.x → 7.4.x (latest) → 7.6.x
- 7.0.x → 7.6.x: 7.0.x → 7.2.x → 7.4.x → 7.6.x
- 6.4.x → 7.6.x: 6.4.x → 7.0.x → 7.2.x → 7.4.x → 7.6.x

### Federated Upgrade (FortiManager-managed)
- FortiManager can follow the upgrade path automatically for managed devices
- Each step in the path is downloaded and applied sequentially
- Available from FortiManager 7.4.1+

### FortiConverter Tool
- Purpose: configuration migration between FortiGate models or firmware versions with schema changes
- Use cases: hardware refresh, data center migration, major version upgrades with schema changes
- Available as: standalone software (annual license) or one-time Fortinet support service
- Particularly important for 6.x → 7.x migrations where SD-WAN schema changed significantly
- Does not convert all settings; manual review always required post-conversion

### Pre-Upgrade Checklist
1. Verify upgrade path via upgrade tool
2. Back up full configuration (encrypted)
3. Note current firmware, HA state, and active sessions
4. Review release notes for deprecated features and behavior changes
5. Test in staging/lab environment when possible
6. For HA clusters: upgrade secondary first, then primary (rolling upgrade)
7. Verify FortiGuard license validity post-upgrade
8. Review PSIRT advisories for target version
