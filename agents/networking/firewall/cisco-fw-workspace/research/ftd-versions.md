# Cisco FTD Version Reference

## Version Lifecycle Summary

| Version | Status (as of Apr 2026) | FMC Alignment | Notes |
|---|---|---|---|
| 7.0.x | End of Sale/Life (EOL announced) | FMC 7.0 | Last version supporting ASA 5500-X |
| 7.1.x | End of Sale/Life (EOL announced) | FMC 7.1 | Short-lived release |
| 7.2.x | End of Sale Nov 2025; TAC support until ~2026 | FMC 7.2 | cdFMC support until Oct 2026 |
| 7.3.x | End of Sale/Life (EOL announced) | FMC 7.3 | Short-lived release |
| 7.4.x | Active maintenance | FMC 7.4 | Long-term release; recommended for stable deployments |
| 7.6.x | Active; recommended release | FMC 7.6 | Snort 3 default; major platform expansion |
| 7.7.x | Current / Latest (7.7.10 as of Aug 2025) | FMC 7.7 | Latest; ZTNA, platform migrations |
| 10.0 | Planned (2H 2025) | FMC 10.0 | Version numbering change (9.24.1 for ASA concurrent) |

> Note: Cisco re-aligns FTD and FMC major version numbers. Both must be at the same or FMC higher version. FMC must always be upgraded before managed FTD devices.

---

## FTD 7.2

### Status
- **End-of-Sale date**: November 18, 2025
- **TAC support**: Continues until end-of-support date per EoL bulletin
- **cdFMC support**: Until October 31, 2026
- **Classification**: Maintenance/legacy release

### Key Features Introduced or Matured in 7.2

- **Snort 3 improvements**: Port scan detection moved from Snort engine to LINA engine (better accuracy for distributed scans involving multiple scanners/targets)
- **FXOS 2.12** alignment for Firepower 4100/9300
- **FMC Virtual for AWS/Azure/GCP** — cloud-hosted FMC management
- **Integrated ASDM-style interface improvements** in FDM
- Snort 3 available but Snort 2 still default for upgraded devices; Snort 3 default for new installs (7.0 behavior continued)
- **Platform support**: Firepower 1000, 2100 series still supported; ASA 5500-X **not** supported on 7.2+

### End of Life Impact

- Cannot register new FTD 7.2 devices to cdFMC after Nov 2025
- Customers should plan upgrade path to 7.4+ or 7.6+
- FMC 7.2 reaches similar EOL milestones concurrently

---

## FTD 7.4

### Status
- **Active, long-term maintenance release**
- Recommended for environments requiring stability before moving to 7.6+

### Key New Features in 7.4

**Security and Detection**
- **Encrypted Visibility Engine (EVE) Enhancement**: Malware blocking in TLS-encrypted sessions without decryption — identifies malware patterns in encrypted traffic metadata
- **Cisco Secure Dynamic Attributes Connector (CSDAC)** built into FMC: Dynamic cloud-based attributes (AWS tags, Azure resource groups, vCenter annotations) usable in ACP rules — replaces static IP-based rules for cloud workloads

**Access and Identity**
- **Clientless Zero Trust Application Access (ZTAA)**: Users access internal applications via browser-based portal without requiring AnyConnect/Secure Client installation; web-proxied access to internal HTTP/HTTPS resources
- **Azure AD + ISE Integration**: Access policies can reference Azure AD user/group membership via ISE as AAA proxy
- **Policy-Based Routing (PBR) with User Identity**: Route traffic based on user identity, AD group, or Cisco Security Group Tags (SGTs)

**Scalability and Hardware**
- **Multi-Instance on Secure Firewall 3100**: Container instances on 3100 hardware (previously only 4100/9300)
- **IPv6 cloud expansion**: BGP IPv6 graceful restart, EIGRPv6, VxLAN VTEP, PKI/OCSP over IPv6

**Management and Observability**
- **OpenConfig Streaming Telemetry**: Model-driven telemetry for integration with network management stacks (Grafana, Prometheus, etc.)
- **SD-WAN Summary Dashboard**: Consolidated branch/WAN visibility across FMC
- **Public Cloud Target Failover**: Active/standby failover pairs across AWS, Azure, GCP (following clustering HA for cloud in earlier releases)

**VPN**
- Continued IKEv2 site-to-site improvements
- Route-based VPN (VTI) enhancements

### Platform Support in 7.4

- Secure Firewall 1000 series (1010, 1120, 1140, 1150)
- Secure Firewall 2100 series (2110, 2120, 2130, 2140) — **last version; deprecated in 7.6+**
- Secure Firewall 3100 series (3105, 3110, 3120, 3130, 3140)
- Firepower 4100 series (4110, 4112, 4115, 4120, 4125, 4140, 4145, 4150)
- Firepower 9300 (SM-24, SM-36, SM-40, SM-44, SM-48, SM-56 modules)
- FTDv (virtual): VMware, KVM, Hyper-V, AWS, Azure, GCP, OCI
- **NOT supported**: ASA 5500-X series (dropped at 7.0 boundary)

---

## FTD 7.6

### Status
- **Active; Cisco recommended release** (7.6.2 recommended as of 2025)
- Major platform and feature release

### Key New Features in 7.6

**Inspection and ML**
- **SnortML**: Machine learning-based exploit detection framework integrated into Snort 3. Detects entire vulnerability classes including zero-day exploits — extends beyond signature matching. First ML-based IPS capability in FTD
- **Snort 3 mandatory default**: New devices deployed on 7.6 use Snort 3 exclusively; no new Snort 2 deployments
- **QUIC Protocol Decryption**: Threat inspection of QUIC (UDP-based HTTP/3) encrypted traffic
- **EVE Exception List**: Selective block/allow control when Encrypted Visibility Engine (EVE) block is enabled
- **Simplified Do-Not-Decrypt Wizard**: Multi-step guided wizard for excluding traffic from SSL decryption without impacting existing decrypt policies

**AI and Cloud Management**
- **AI Assistant in FMC**: Conversational interface for retrieving policy information and configuration optimization recommendations
- **Policy Analyzer and Optimizer**: Cloud-delivered feature providing actionable policy recommendations (redundant rules, shadow rules, policy cleanup)
- **Cisco Security Cloud Integration**: Updated cloud onboarding leveraging unified Cisco Security Cloud platform

**Hardware — New Platforms**
- **Secure Firewall 1200 Series**: New enterprise-grade ARM-based appliances in three form factors (1210, 1220, 1240); replaces legacy 1000 series
- **Multi-Instance on Secure Firewall 4200**: Container instances now supported on 4200 hardware
- **Individual Interface Mode for 3100/4200 clustering**: Each cluster node gets dedicated traffic interfaces (vs. shared spanned EtherChannel) — simpler cabling for some designs

**SD-WAN and Connectivity**
- **SD-WAN Wizard**: Automated hub-and-spoke topology configuration wizard
- **Device Templates and Bulk Pre-Provisioning**: Low-touch deployment with template-based configuration at scale (for branch office rollouts)
- **AAA VRF Support**: Management traffic partitioned across VRFs
- **Accelerated DTLS**: Improved encrypted traffic management performance for AnyConnect DTLS sessions

**Identity and Zero Trust**
- **Passive Identity Agent**: Direct Active Directory integration for user-identity policies without ISE — queries AD for user-to-IP mappings
- **Azure AD Active Authorization**: SAML-based authentication with Azure AD group enforcement
- **Universal ZTNA** (in 7.6.4): Zero Trust Network Access without client software requirement

**Cloud Deployments**
- **AWS Multi-AZ Clustering**: FTDv cluster nodes in different AWS Availability Zones with autoscaling integration
- **AWS Dual-Arm GWLB Support**: Gateway Load Balancer integration improvement for egress inspection topologies

**Management UX**
- **Magnetic Framework UI**: Refreshed FMC interface using Cisco Magnetic design system
- **HA Upgrade Wizard improvement**: Reduced from 9 to 6 steps
- **FMC HA validation**: Pre-upgrade checks for HA consistency

### Platform Changes in 7.6

- **Deprecated/Dropped**: Firepower 2110, 2120, 2130, 2140 — cannot run 7.6+
- Secure Firewall 1200 series introduced
- Secure Firewall 3100, 4100, 4200, 9300: Full support
- FTDv: Continued support on all major hypervisors and cloud platforms
- **FMC 7.6**: Rate limit for REST API raised from 120 req/min to 300 req/min

---

## FTD 7.7

### Status
- **Current latest release** (7.7.10 as of August 31, 2025)
- Maintenance and stability release on top of 7.6 feature base

### Key Features in 7.7

**Zero Trust**
- **Universal ZTNA (fully integrated)**: Comprehensive zero trust access control for internal resources based on user identity, trust level, and posture assessment. Grants application-level access (not network-level) — sharply differentiated from remote access VPN
- ZTNA policy managed through **Cisco Secure Access** and **Security Cloud Control**
- Supported on: Secure Firewall 1150, 3100, 4100, 4200, FTDv
- **Not supported on**: Clustered devices, multi-instance containers, transparent mode

**Platform Migrations**
- Migration path from select Firepower 4100/9300 models to Secure Firewall 3100/4200 hardware (introduced in maintenance release 7.6.1, available in 7.7.10)

**CDO / Proxy Support**
- FMC Umbrella integration now works when FMC is behind a proxy server (added in 7.6.1, available in 7.7.10)

**Stability and Bug Fixes**
- 200+ resolved functional defects covering:
  - Memory optimization
  - VPN tunnel stability
  - Policy deployment reliability
  - Authentication system fixes
  - Cluster failover mechanisms

### Minimum Requirements for 7.7

- FMC must be on 7.7 or later to manage FTD 7.7 devices
- FXOS 2.x for chassis-based platforms (Firepower 4100/9300)
- Feature-specific requirements (e.g., ZTNA requires Cisco Secure Access subscription)

---

## FMC Version Alignment

### Rule: FMC >= FTD Version

The FMC must always run the **same or newer version** than the FTD devices it manages.

- You **cannot upgrade FTD past the FMC version**
- Even for maintenance (third-digit) releases: upgrade FMC first, then FTD
- FMC can manage FTD devices **up to two major versions older** in most cases (e.g., FMC 7.6 can manage FTD 7.4, 7.2 in some scenarios)

### FMC Version Naming

- FMC versions match FTD versions: FMC 7.4 manages FTD 7.4 and older
- cdFMC version is managed by Cisco (SaaS) — always current; can manage FTD 7.2+

### FMC 10.0 (Planned 2H 2025)

- Version number reset to 10.0 (from 7.x series)
- Concurrent with ASA 9.24.1 release
- Represents a significant platform milestone

---

## Platform Hardware Support Matrix

| Platform | Max FTD Version | Min FTD Version | Notes |
|---|---|---|---|
| ASA 5500-X series | 7.0.x | 6.x | EOL platform; no 7.1+ support |
| Firepower 1000 (1010/1120/1140/1150) | 7.7+ | 6.4 | Active |
| Firepower 2100 (2110/2120/2130/2140) | 7.4.x | 6.2 | Deprecated; no 7.6+ |
| Secure Firewall 1200 (1210/1220/1240) | 7.7+ | 7.6 | New ARM platform; introduced 7.6 |
| Secure Firewall 3100 (3105/3110/3120/3130/3140) | 7.7+ | 7.1 | Multi-instance from 7.4 |
| Firepower 4100 (4110/4112/4115/4120/4125/4140/4145/4150) | 7.7+ | 6.0 | FXOS chassis; multi-instance, clustering |
| Secure Firewall 4200 (4215/4225/4245) | 7.7+ | 7.4 | Multi-instance from 7.6; introduced 7.4 |
| Firepower 9300 (SM modules) | 7.7+ | 6.0 | FXOS chassis; multi-module clustering |
| FTDv (VMware/KVM/Hyper-V) | 7.7+ | 6.0 | Virtual appliance; performance tiers |
| FTDv (AWS/Azure/GCP/OCI) | 7.7+ | 6.4 | Cloud virtual; multi-AZ clustering (AWS) 7.6 |

### Key Hardware Notes

- **Firepower 4100/9300** require **FXOS** (Firepower eXtensible Operating System) for chassis management; FTD runs as a logical device
- **Secure Firewall 3100/4200** use a simplified FXOS (no Supervisor/chassis manager complexity of 4100/9300)
- **Secure Firewall 1000/1200 series** are integrated appliances with no FXOS chassis manager
- **ASA 5500-X** reached FTD EOL at 7.0 — any 5500-X running FTD cannot go beyond 7.0

---

## Sources

- [FTD 7.7.x Release Notes — Cisco](https://www.cisco.com/c/en/us/td/docs/security/secure-firewall/release-notes/threat-defense/770/threat-defense-release-notes-77.html)
- [FTD 7.6.x Release Notes — Cisco](https://www.cisco.com/c/en/us/td/docs/security/secure-firewall/release-notes/threat-defense/760/threat-defense-release-notes-76.html)
- [FTD 7.4.x Release Notes — Cisco](https://www.cisco.com/c/en/us/td/docs/security/secure-firewall/release-notes/threat-defense/740/threat-defense-release-notes-74.html)
- [What's New in 7.4 — Cisco Secure Firewall Docs](https://secure.cisco.com/secure-firewall/v7.4/docs/whats-new-in-74)
- [What's New in 7.6 — Cisco Secure Firewall Docs](https://secure.cisco.com/secure-firewall/v7.6/docs/whats-new-in-76)
- [FTD 7.7.10 Devicebase Detail](https://devicebase.net/en/cisco-firepower-4100-series-firewall/updates/cisco-secure-firewall-threat-defense-release-notes-version-7-7-x/7lk)
- [FTD 7.2 EOL Announcement — Cisco](https://www.cisco.com/c/en/us/products/collateral/security/firepower-ngfw/ftd-ftdv-7-2-fmc-fmcv-fxos-2-12-eol.html)
- [Cisco NGFW Software Release Bulletin — Cisco](https://www.cisco.com/c/en/us/products/collateral/security/firewalls/bulletin-c25-743178.html)
- [FMC New Features by Release — Cisco](https://www.cisco.com/c/en/us/td/docs/security/secure-firewall/roadmap/management-center-new-features-by-release.html)
- [Threat Defense Compatibility Guide — Cisco](https://www.cisco.com/c/en/us/td/docs/security/secure-firewall/compatibility/threat-defense-compatibility.html)
- [FMC/FTD Upgrade Matrix Discussion — Cisco Community](https://community.cisco.com/t5/network-security/fmc-ftd-upgrade-matrix-question/td-p/4777326)
