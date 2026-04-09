# Security Foundational Concepts

Cross-domain security knowledge that applies across all subcategories and technologies.

---

## Security Frameworks

### NIST Cybersecurity Framework 2.0 (CSF 2.0)

Released February 2024. Applies to all organizations, not just critical infrastructure.

**Six Core Functions:**

| Function | ID | Purpose | Key Categories |
|---|---|---|---|
| Govern | GV | Risk management strategy and oversight | Organizational Context, Risk Management Strategy, Roles & Responsibilities, Policy, Oversight, Supply Chain Risk |
| Identify | ID | Asset and risk understanding | Asset Management, Risk Assessment, Improvement |
| Protect | PR | Safeguard implementation | Identity Management & Access Control, Awareness & Training, Data Security, Platform Security, Technology Infrastructure Resilience |
| Detect | DE | Event discovery | Continuous Monitoring, Adverse Event Analysis |
| Respond | RS | Incident action | Incident Management, Incident Analysis, Incident Response Reporting & Communication, Incident Mitigation |
| Recover | RC | Restoration | Incident Recovery Plan Execution, Incident Recovery Communication |

**Implementation Tiers:** Partial (1), Risk Informed (2), Repeatable (3), Adaptive (4). Tiers describe rigor, not maturity level -- an organization at Tier 2 may be appropriately resourced for their risk.

### CIS Controls v8.1

18 prioritized security controls, organized into three Implementation Groups (IGs):

**IG1 (Essential Cyber Hygiene -- 56 safeguards):**
- CIS 1: Inventory and Control of Enterprise Assets
- CIS 2: Inventory and Control of Software Assets
- CIS 3: Data Protection
- CIS 4: Secure Configuration of Enterprise Assets and Software
- CIS 5: Account Management
- CIS 6: Access Control Management
- CIS 7: Continuous Vulnerability Management
- CIS 8: Audit Log Management
- CIS 9: Email and Web Browser Protections
- CIS 10: Malware Defenses
- CIS 11: Data Recovery
- CIS 13: Network Monitoring and Defense
- CIS 14: Security Awareness and Skills Training

**IG2 (adds 74 safeguards):** Controls 12, 15, 16 added; deeper implementation of IG1 controls.

**IG3 (adds 23 safeguards):** Controls 17, 18 added; full implementation depth.

### ISO 27001:2022

Information security management system (ISMS) standard. Key structure:
- **Clauses 4-10:** Management system requirements (context, leadership, planning, support, operation, performance evaluation, improvement)
- **Annex A:** 93 controls in 4 themes (Organizational, People, Physical, Technological)
- **ISO 27002:2022:** Implementation guidance for Annex A controls

### SOC 2 (Trust Services Criteria)

| Criteria | Description | Common Controls |
|---|---|---|
| Security (CC) | Protection against unauthorized access | Access controls, encryption, monitoring, incident response |
| Availability (A) | System availability per SLA | DR, backups, capacity planning, monitoring |
| Processing Integrity (PI) | Complete, valid, accurate processing | Input validation, QA, reconciliation |
| Confidentiality (C) | Confidential information protection | Encryption, access controls, data classification |
| Privacy (P) | Personal information handling | Consent, data minimization, retention, disposal |

Security (Common Criteria) is always in scope. Other criteria are optional based on the engagement.

---

## MITRE ATT&CK

### Enterprise Matrix (key techniques per tactic)

| Tactic | ID | Common Techniques |
|---|---|---|
| Reconnaissance | TA0043 | Active scanning, phishing for information, search open sources |
| Resource Development | TA0042 | Acquire infrastructure, develop capabilities, obtain credentials |
| Initial Access | TA0001 | Phishing (T1566), exploit public-facing app (T1190), valid accounts (T1078), supply chain (T1195) |
| Execution | TA0002 | Command/scripting interpreter (T1059), scheduled task (T1053), user execution (T1204) |
| Persistence | TA0003 | Account manipulation (T1098), boot/logon autostart (T1547), scheduled task (T1053) |
| Privilege Escalation | TA0004 | Abuse elevation control (T1548), access token manipulation (T1134), exploitation (T1068) |
| Defense Evasion | TA0005 | Impair defenses (T1562), masquerading (T1036), obfuscation (T1027), indicator removal (T1070) |
| Credential Access | TA0006 | Brute force (T1110), OS credential dumping (T1003), steal/forge Kerberos tickets (T1558) |
| Discovery | TA0007 | Account discovery (T1087), network scanning (T1046), permission groups (T1069) |
| Lateral Movement | TA0008 | Remote services (T1021), pass the hash (T1550.002), exploitation of remote services (T1210) |
| Collection | TA0009 | Data from local system (T1005), email collection (T1114), screen capture (T1113) |
| C2 | TA0011 | Application layer protocol (T1071), encrypted channel (T1573), proxy (T1090) |
| Exfiltration | TA0010 | Exfil over C2 (T1041), exfil over web service (T1567), automated exfiltration (T1020) |
| Impact | TA0040 | Data encrypted for impact (T1486), inhibit system recovery (T1490), defacement (T1491) |

### MITRE D3FEND

Defensive countermeasure knowledge graph that maps to ATT&CK:
- **Harden** -- Reduce attack surface (application hardening, credential hardening, platform hardening)
- **Detect** -- Identify attacks (file analysis, identifier analysis, message analysis, network traffic analysis, process analysis)
- **Isolate** -- Limit blast radius (execution isolation, network isolation)
- **Deceive** -- Misdirect adversaries (decoy environments, decoy objects)
- **Evict** -- Remove adversary presence (credential eviction, process eviction)

---

## Cryptography Fundamentals

### Symmetric Encryption

| Algorithm | Key Size | Status | Use Case |
|---|---|---|---|
| AES-256-GCM | 256-bit | Current standard | Data at rest, TLS 1.3, disk encryption |
| AES-256-CBC | 256-bit | Acceptable | Legacy systems (prefer GCM for authenticated encryption) |
| ChaCha20-Poly1305 | 256-bit | Current standard | TLS 1.3 (mobile/embedded where AES-NI unavailable) |
| 3DES | 168-bit | Deprecated | Legacy only -- do not use for new systems |

### Asymmetric Encryption

| Algorithm | Key Size | Status | Use Case |
|---|---|---|---|
| RSA | 2048+ | Current (3072+ recommended) | TLS, code signing, email encryption |
| ECDSA (P-256/P-384) | 256/384-bit | Current standard | TLS, SSH, code signing |
| Ed25519 | 256-bit | Current standard | SSH keys, modern signatures |
| ML-KEM (Kyber) | N/A | Post-quantum (NIST standardized 2024) | Future TLS, hybrid key exchange |
| ML-DSA (Dilithium) | N/A | Post-quantum (NIST standardized 2024) | Future digital signatures |

### Hashing

| Algorithm | Output | Status | Use Case |
|---|---|---|---|
| SHA-256 | 256-bit | Current standard | Integrity verification, digital signatures |
| SHA-384/512 | 384/512-bit | Current standard | High-security contexts |
| SHA-3 (Keccak) | Variable | Current standard | When SHA-2 diversity needed |
| bcrypt | Variable | Current standard | Password hashing (cost factor 12+) |
| Argon2id | Variable | Current standard | Password hashing (memory-hard, preferred) |
| MD5 | 128-bit | Broken | Never for security (acceptable for non-security checksums) |
| SHA-1 | 160-bit | Deprecated | Do not use for new systems |

### TLS

Current standard: **TLS 1.3** (RFC 8446, August 2018)

TLS 1.3 improvements over 1.2:
- Removed insecure algorithms (RC4, 3DES, SHA-1, static RSA, DHE)
- 1-RTT handshake (0-RTT optional with replay risk)
- Only AEAD cipher suites (AES-GCM, ChaCha20-Poly1305)
- Encrypted SNI extension (ECH) emerging

**Minimum acceptable:** TLS 1.2 with strong cipher suites. TLS 1.0 and 1.1 are deprecated (RFC 8996).

---

## Authentication Protocols

### OAuth 2.0 / OpenID Connect (OIDC)

OAuth 2.0 is authorization (delegated access). OIDC adds authentication (identity layer on top of OAuth 2.0).

**Key flows:**
- **Authorization Code + PKCE** -- Web apps, SPAs, native apps (recommended for all)
- **Client Credentials** -- Machine-to-machine, no user context
- **Device Code** -- Input-constrained devices (CLI tools, smart TVs)
- **Implicit** -- Deprecated. Never use for new applications.
- **Resource Owner Password** -- Deprecated. Legacy migration only.

**Token types:**
- **Access token** -- Short-lived (5-60 min), authorizes API access
- **Refresh token** -- Longer-lived, used to obtain new access tokens. Rotate on use.
- **ID token** -- JWT containing user claims. Issued by OIDC provider.

### SAML 2.0

XML-based federation protocol. Still widely used in enterprise SSO.

- **SP-initiated flow** -- User visits service provider (SP), redirected to identity provider (IdP) for authentication
- **IdP-initiated flow** -- User starts at IdP, selects application. Less secure (no request context for validation).
- **Assertion** -- XML document containing authentication statement, attribute statement, authorization decision

### Kerberos

Ticket-based authentication used by Active Directory:

1. **AS-REQ/AS-REP** -- Client authenticates to KDC, receives Ticket Granting Ticket (TGT)
2. **TGS-REQ/TGS-REP** -- Client presents TGT, requests Service Ticket (ST)
3. **AP-REQ/AP-REP** -- Client presents ST to service for access

**Common attacks:** Kerberoasting (request STs for offline cracking), AS-REP roasting (accounts without pre-auth), Golden Ticket (forged TGT with KRBTGT hash), Silver Ticket (forged ST with service account hash), Pass-the-Ticket.

### FIDO2 / WebAuthn / Passkeys

Phishing-resistant authentication using public-key cryptography:
- **Authenticator** creates key pair; private key never leaves the device
- **Relying party** stores public key; authentication is origin-bound (phishing-resistant)
- **Passkeys** are discoverable FIDO2 credentials synced across devices (iCloud Keychain, Google Password Manager, Microsoft accounts)

---

## Risk Management

### Risk Assessment Process

1. **Identify assets** -- What are we protecting? (data, systems, reputation, IP)
2. **Identify threats** -- What could go wrong? (threat modeling, ATT&CK mapping)
3. **Identify vulnerabilities** -- Where are we weak? (scanning, pen testing, architecture review)
4. **Assess likelihood** -- How probable is exploitation? (threat intelligence, exposure analysis)
5. **Assess impact** -- What is the business damage? (financial, regulatory, reputational, operational)
6. **Calculate risk** -- Risk = Likelihood x Impact (qualitative or quantitative)
7. **Prioritize treatment** -- Accept, mitigate, transfer, or avoid

### Risk Treatment Options

| Option | When to Use | Example |
|---|---|---|
| **Mitigate** | Risk exceeds tolerance, controls are cost-effective | Deploy EDR, enable MFA, segment network |
| **Transfer** | Risk is quantifiable, insurance is available | Cyber insurance, managed security services |
| **Accept** | Risk is within tolerance, controls are too costly | Low-impact, low-likelihood vulnerability on air-gapped system |
| **Avoid** | Risk is unacceptable, activity can be eliminated | Decommission vulnerable legacy system |

---

## Identity and Access Management Concepts

### Principle of Least Privilege

Grant minimum access required for the task. Implementation approaches:
- **Role-Based Access Control (RBAC)** -- Permissions assigned to roles, users assigned to roles
- **Attribute-Based Access Control (ABAC)** -- Permissions based on attributes (user, resource, environment, action)
- **Just-In-Time (JIT) Access** -- Elevated access granted temporarily, auto-revoked
- **Just-Enough-Access (JEA)** -- Constrained administrative endpoints with limited command sets

### Identity Lifecycle

1. **Joiner** -- Provisioning: create accounts, assign baseline access, enable MFA
2. **Mover** -- Role change: adjust access, recertify permissions, update group memberships
3. **Leaver** -- Deprovisioning: disable accounts, revoke access, archive data, transfer ownership

Automation through Identity Governance and Administration (IGA) tools reduces orphaned accounts and access drift.

---

## Incident Response

### NIST SP 800-61 Rev 2 Phases

1. **Preparation** -- IR plan, team, tools, communication templates, playbooks
2. **Detection & Analysis** -- SIEM alerts, EDR detections, indicator analysis, severity classification
3. **Containment, Eradication, Recovery** -- Short-term containment (isolate), long-term containment (patch, harden), eradication (remove malware, persistence), recovery (restore, verify)
4. **Post-Incident Activity** -- Lessons learned, evidence preservation, metrics (MTTD, MTTR)

### Severity Classification

| Severity | Criteria | Response Time | Example |
|---|---|---|---|
| Critical (P1) | Active data breach, ransomware, complete service outage | Immediate (15 min) | Ransomware detonation, domain admin compromise |
| High (P2) | Confirmed compromise, significant service impact | 1 hour | Phishing with credential harvesting, lateral movement detected |
| Medium (P3) | Potential compromise, limited impact | 4 hours | Suspicious login from unusual location, malware blocked |
| Low (P4) | Informational, no confirmed impact | Next business day | Policy violation, failed brute force attempt |

---

## Network Security Concepts

### Network Segmentation

| Approach | Granularity | Implementation |
|---|---|---|
| VLANs + ACLs | Subnet-level | Switch-based, L3 firewall between VLANs |
| Firewall zones | Zone-level | NGFW with zone-based policies |
| Micro-segmentation | Workload-level | Software-defined (Illumio, Guardicore, NSX) |
| Zero Trust Network Access | Application-level | Identity-aware proxy (Zscaler ZPA, Cloudflare Access) |

### DNS Security

- **DNSSEC** -- Cryptographic signing of DNS records (prevents cache poisoning)
- **DNS over HTTPS (DoH) / DNS over TLS (DoT)** -- Encrypts DNS queries (privacy)
- **DNS filtering** -- Block known malicious domains (Cisco Umbrella, Cloudflare Gateway)
- **DNS sinkholing** -- Redirect malicious domain resolution to controlled IP (IR technique)

---

## Cloud Security Concepts

### Shared Responsibility Model

| Layer | IaaS | PaaS | SaaS |
|---|---|---|---|
| Data | Customer | Customer | Customer |
| Identity & Access | Customer | Customer | Customer |
| Application | Customer | Customer | Provider |
| OS | Customer | Provider | Provider |
| Network controls | Customer | Provider | Provider |
| Infrastructure | Provider | Provider | Provider |
| Physical | Provider | Provider | Provider |

### Cloud Security Posture Management (CSPM)

Automated discovery and remediation of cloud misconfigurations:
- Open storage buckets, overly permissive IAM policies, unencrypted resources
- Compliance mapping (CIS Benchmarks for AWS/Azure/GCP, SOC 2, PCI DSS)
- Drift detection from desired state

### Cloud Workload Protection Platform (CWPP)

Runtime protection for cloud workloads (VMs, containers, serverless):
- Vulnerability scanning, runtime threat detection, file integrity monitoring
- Container image scanning, Kubernetes admission control
- Serverless function protection
