# PAN-OS Version Reference: Deep Technical Details

## Version Naming Conventions

PAN-OS uses a three-part versioning scheme: **Major.Minor.Maintenance** (e.g., 10.2.9).
- Major releases represent platform-level architectural shifts.
- Minor releases (feature releases) introduce new capabilities.
- Maintenance releases are bug-fix only with no new features.
- Each major release has a release codename (Nebula, Cosmos, Quasar, Orion, etc.).

**Support lifecycle (pre-12.1)**: ~36 months from GA release date.
**Support lifecycle (12.1 onward)**: 48 months (36 months Standard + 12 months Extended).

---

## PAN-OS 10.2 "Nebula"

**GA Date**: February 2022
**EOL Date**: September 30, 2026
**Status (as of 2026)**: In extended/limited support — migration planning required.

### Signature Features Introduced
- **Advanced Threat Prevention** (subscription required): Inline cloud-based deep learning for IPS — analyzes traffic patterns in real-time using cloud compute without local performance impact. First version to support inline deep learning for C2 detection and evasive threat prevention (Cobalt Strike-type attacks). 6x faster prevention with 48% more evasive threats detected vs. classic IPS.
- **Advanced URL Filtering**: Cloud-inline deep learning for real-time categorization of previously unseen URLs, including cloaked websites, CAPTCHA-gated phishing, and multi-step attacks.
- **AIOps for NGFW**: ML-based predictive intelligence for device health monitoring. Uses telemetry from thousands of deployments to predict disruptions up to 51% of the time before they affect operations.
- **Inline Cloud Analysis for Vulnerability Protection**: Zero-day exploit prevention via inline cloud analysis (Advanced Threat Prevention subscription).
- **Advanced Routing Engine**: Optional new routing engine replacing legacy routing — supports ECMP, faster BGP convergence, policy-based forwarding, and better large-scale routing table support. Enabled per-virtual-router.
- **Mobile Infrastructure Security**: 5G GTP security improvements (GTP-U, GTP-C protection profiles).
- **Selective/Partial Commit**: Introduced the ability to commit only the changes made by a specific administrator, reducing commit conflicts in multi-admin environments.

### Deprecated/Changed in 10.2
- SSL 3.0 and TLS 1.0 disabled by default in management interface.
- Python 2 removed from PAN-OS scripting environment.
- Classic routing engine remains but Advanced Routing Engine introduced as optional replacement.

### Key 10.2 Caveats
- Advanced Threat Prevention and Advanced URL Filtering are **separate subscriptions** from classic Threat Prevention and URL Filtering — not just feature upgrades.
- AIOps requires telemetry sharing to be enabled.
- Inline deep learning only works for traffic that traverses the firewall (not out-of-band/tap mode).

---

## PAN-OS 11.0

**GA Date**: November 2022 (feature release)
**EOL Date**: November 17, 2024 (short-lived; superseded quickly by 11.1)

### Notable Additions
- Expanded Cloud Identity Engine integration as primary User-ID source.
- User Context improvements: deeper attribute-based policy enforcement from cloud IdPs.
- Virtualization: improved CN-Series (Kubernetes) NGFW features.
- Management: enhanced diff/preview tools for Panorama config changes.

---

## PAN-OS 11.1 "Cosmos"

**GA Date**: May 2023
**EOL Date**: May 3, 2027
**Status (as of 2026)**: Active support — widely deployed production baseline.

### Signature Features vs. 10.2
- **Quantum-Safe VPN (Phase 1)**: First PAN-OS release to introduce post-quantum IKEv2 extensions — hybrid key exchange using classical ECDH combined with post-quantum key encapsulation mechanisms (ML-KEM / CRYSTALS-Kyber). Addresses "harvest now, decrypt later" attack vectors for VPN tunnels.
- **App-ID Cloud Engine**: Cloud-based App-ID service that provides continuous, near-real-time App-ID updates from Palo Alto Networks without requiring a content update installation. Devices opt into the cloud engine for faster signature delivery than the traditional weekly content update cycle.
- **Advanced DNS Security**: Enhanced DNS-layer threat prevention; detects DNS tunneling, DNS-based C2 with inline machine learning models. Works with Advanced Threat Prevention license.
- **Advanced WildFire**: Improved cloud sandbox capabilities for evasive malware using deeper behavioral analysis.
- **ADEM (Autonomous Digital Experience Management) for NGFW**: Application performance monitoring integrated directly into PAN-OS — provides end-user experience visibility, synthetic monitoring, and rapid problem identification without requiring a separate probe.
- **Local Deep Learning for Advanced Threat Prevention**: On-device ML model inference for malware detection — complements cloud-based inline analysis with local processing for latency-sensitive deployments.
- **Virtual System Support Improvements**: CN-Series firewall gains vsys support.
- **GlobalProtect**: Mobile users get improved split tunneling controls, enhanced HIP (Host Information Profile) checks.
- **Changes to Default Behavior**: TLS 1.1 disabled by default for management plane; stricter certificate validation by default.

### Cloud Identity Engine in 11.1
- CIE becomes the **recommended primary** User-ID source for cloud-managed or hybrid environments.
- Direct integration with Azure AD, Okta, Ping Identity without requiring on-premises User-ID agents.
- Group mapping from cloud IdPs natively supported — eliminates LDAP agent requirement for Azure AD environments.
- Token-based authentication context (device compliance, risk score) can be used in policy.

---

## PAN-OS 11.2 "Quasar"

**GA Date**: March 2024
**EOL Date**: May 2, 2027
**Status (as of 2026)**: Current stable feature release; recommended for new deployments.

### Signature Features vs. 11.1
- **Quantum-Safe VPN (Phase 2 / Full PQC)**: Extended post-quantum VPN from 11.1's hybrid approach to full PQC algorithm support. Introduces PQC-only IKEv2 configurations. Supports NIST PQC finalists (ML-KEM, ML-DSA, SLH-DSA) for IPsec.
- **PA-400R Series (Rugged NGFWs)**: New hardware form factors for industrial/OT environments — hardened chassis, extended operating temperature ranges, designed for factory floors, utilities, and harsh environments.
- **CN-Series Enhancements**: Advanced Threat Prevention support in Kubernetes-native deployments; User-ID integration for container workloads.
- **PAN-OS Dataplane Support for 11.0/11.1/11.2**: Unified dataplane driver compatibility confirmed across 11.x family.
- **Enhanced ADEM Integration**: ADEM features matured; SaaS application visibility expanded.
- **Advanced DNS Security Expansion**: Additional threat intelligence feeds and updated ML models for DNS-based threat detection.
- **Panorama Features**: Improved change management workflow — better filtering of pending changes by admin, template, or device group scope.
- **Management Improvements**: Commit performance optimizations for large Panorama deployments managing thousands of devices.

### Notable 11.2 Behavioral Changes
- App-ID Cloud Engine enabled by default on supported platforms.
- Stricter validation of TLS certificates in management connections.

---

## PAN-OS 12.1 "Orion"

**GA Date**: August 28, 2025
**EOL Date**: August 2029 (48-month lifecycle)
  - Standard Support ends: ~August 2028 (36 months)
  - Extended Support ends: ~August 2029 (12 additional months)
**Status (as of 2026)**: Current major release; first release under new 48-month support policy.

### 48-Month Support Policy Details
This is a fundamental change from prior versions. Starting with 12.1:
- **Standard Support (36 months)**: Full support — software/content updates, all bug fixes, vulnerability fixes, maintenance releases.
- **Extended Support (12 months)**: Focused end-of-life migration support — Priority 1 stability issues only, Critical and High severity CVE fixes only. No new features.
- Prior releases (10.2, 11.1, 11.2) remain on the ~36-month total lifecycle.

### Post-Quantum Cryptography Features
12.1 is the first release with a **comprehensive PQC platform** rather than individual PQC features:

- **Quantum Readiness Dashboard**: Centralized visibility into cryptographic usage across the enterprise. Inventories all TLS, IPsec, and SSH sessions and identifies which are using classical-only algorithms vs. quantum-safe algorithms.
- **Cipher Translation for Legacy Apps**: Translates classical cipher suites to PQC-safe equivalents for legacy applications that cannot be upgraded. The firewall acts as a PQC proxy, negotiating quantum-safe ciphers externally while maintaining classical negotiation with internal legacy endpoints.
- **PQC Traffic Inspection**: 5th-generation quantum-optimized NGFWs (including PA-5500 Series) can decrypt and inspect PQC-encrypted traffic at line rate — requires quantum-optimized hardware acceleration.
- **Full NIST Standard Suite**:
  - FIPS 203: ML-KEM (Module Lattice Key Encapsulation Mechanism — replaces Kyber)
  - FIPS 204: ML-DSA (Module Lattice Digital Signature Algorithm — replaces Dilithium)
  - FIPS 205: SLH-DSA (Stateless Hash-Based Digital Signature Algorithm — replaces SPHINCS+)
  - Pre-standard: HQC, Classic McEliece, BIKE, FrodoKEM

### PA-5500 Series Hardware
- New data center NGFW platform purpose-built for PQC workloads.
- Up to 4x performance improvement over previous PA-5200 generation.
- 400 Gbps interfaces (QSFP-DD).
- Quantum-optimized hardware accelerators enabling high-throughput PQC traffic inspection.
- Designed for large-scale data center and carrier-class deployments.

### AI-Driven Security Features in 12.1
- AI Security posture management integrated into management plane.
- Expanded inline ML threat detection across all content inspection categories.
- AI-assisted policy recommendations based on traffic telemetry.

### Key Differences: 12.1 vs. 11.x
| Dimension | 11.x (Cosmos/Quasar) | 12.1 (Orion) |
|-----------|---------------------|--------------|
| PQC Support | Hybrid key exchange (VPN only) | Full PQC platform, all protocols |
| Hardware | PA-400R (ruggedized) | PA-5500 (data center, 400G) |
| Support Lifecycle | ~36 months | 48 months (36+12) |
| Quantum Dashboard | None | Yes — enterprise-wide crypto inventory |
| Cipher Translation | Not available | Yes — PQC proxy for legacy apps |
| Traffic Inspection | Up to 400G (PA-7000) | PQC-accelerated inspection at line rate |

---

## Migration Considerations Between Major Versions

### 10.2 → 11.x Migration
- **Upgrade path**: 10.2 → 11.0 (if needed as intermediate) → 11.1 or 11.2 directly. Check the official upgrade path matrix — direct 10.2 → 11.2 is supported on most platforms.
- **Content subscription changes**: If using Classic Threat Prevention + Classic URL Filtering, features remain compatible. Migration to Advanced Threat Prevention requires separate license procurement.
- **Advanced Routing Engine**: If 10.2 deployment used the Advanced Routing Engine, validate routing configuration compatibility in 11.x (some BGP attribute handling changed).
- **App-ID changes**: Each major release ships with updated App-IDs. Run `show application-command-change` and review App-ID impact reports before committing upgrades in production. Policy rules using `application-default` services may be affected by App-ID reclassifications.

### 11.x → 12.1 Migration
- **Hardware compatibility**: Not all 10.x/11.x-era hardware supports 12.1. Check the compatibility matrix — older PA-220, PA-820 models may not support 12.1.
- **PQC configuration**: New PQC-related features require explicit enablement; no automatic migration of existing IPsec/VPN tunnels to PQC algorithms.
- **Certificate infrastructure**: 12.1's stricter certificate handling may surface legacy self-signed cert issues in decryption policies.
- **Python and automation**: Review custom scripts/API integrations for deprecated API endpoints.

### General Upgrade Best Practices
1. Always upgrade Panorama before firewalls (Panorama must be same or newer than managed firewalls).
2. Upgrade WF-500 appliances before firewalls that forward to them.
3. In HA pairs: upgrade passive (secondary) first for active/passive; disable preemption before starting.
4. For active/passive: suspend active → upgrade passive → unsuspend passive (making it active) → upgrade original active → re-enable preemption if desired.
5. Always download and install the target version's dynamic content updates (App+Threat, AV, WildFire) after the software upgrade.
6. Review release notes for "Changes to Default Behavior" section before upgrading — these often cause unexpected policy or connectivity changes.
7. Use the PAN-OS upgrade readiness checks: `request system software check` and validate licenses.
