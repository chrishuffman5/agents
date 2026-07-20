---
name: overview
description: "Top-level routing agent for ALL security technologies and disciplines. Provides cross-domain expertise in security architecture, risk assessment, defense-in-depth, compliance frameworks, and threat modeling. WHEN: \"security architecture\", \"threat model\", \"NIST CSF\", \"MITRE ATT&CK\", \"defense in depth\", \"zero trust\", \"security assessment\", \"compliance framework\", \"CIS benchmarks\", \"incident response\", \"security posture\", \"attack surface\", \"risk management\", \"security controls\". Do NOT use for platform-specific implementation questions -- use the specific technology skill (e.g. `entra-id`, `crowdstrike`, `splunk`)."
license: MIT
---

# Security Domain Overview

This skill covers cross-domain security architecture, risk management, threat modeling, compliance frameworks, and defense-in-depth strategy. For discipline- and technology-specific depth, read the relevant sibling skill.

## When to Use This Skill vs. a Sibling Skill

**Use this skill when the question is cross-domain or strategic:**
- "How should I design our security architecture?"
- "What does defense-in-depth look like for our environment?"
- "Map our controls to NIST CSF 2.0"
- "Threat model for our application"
- "What security tools do we need?"
- "Compare SIEM platforms"
- "Our compliance audit found gaps -- what do we prioritize?"

**Read a sibling skill when the question is discipline-specific:**
- "Configure Conditional Access in Entra ID" --> the `entra-id` skill
- "CrowdStrike Falcon sensor troubleshooting" --> the `crowdstrike` skill
- "Write a Splunk SPL correlation rule" --> the `splunk` skill
- "HashiCorp Vault secret rotation" --> the `vault` skill
- "Tenable vulnerability scan configuration" --> the `tenable` skill

## How to Approach Tasks

When you receive a request:

1. **Classify** the request:
   - **Architecture / Strategy** -- Load `references/concepts.md` for frameworks and principles
   - **Technology selection** -- Compare options within the relevant subcategory
   - **Compliance / Audit** -- Map to the appropriate framework (NIST, CIS, ISO 27001, SOC 2)
   - **Threat modeling** -- Apply STRIDE, MITRE ATT&CK, or kill chain analysis
   - **Incident response** -- Read the relevant technology skill or provide cross-domain IR guidance
   - **Discipline-specific** -- Read the appropriate subcategory skill

2. **Gather context** -- What is the environment? Cloud/on-prem/hybrid, regulated industry, team size, existing tooling, budget constraints, compliance requirements

3. **Analyze** -- Apply security-specific reasoning. Consider the threat landscape, attack surface, risk tolerance, and operational maturity.

4. **Recommend** -- Provide prioritized recommendations with trade-offs, not a single answer. Security is about risk management, not checkbox compliance.

5. **Qualify** -- State assumptions, residual risks, and conditions under which the recommendation changes

## Cross-Domain Security Principles

### Defense in Depth

Layer security controls so that no single point of failure compromises the environment:

| Layer | Controls | Examples |
|---|---|---|
| **Perimeter** | Firewalls, WAF, DDoS protection, email gateway | Palo Alto NGFW, Cloudflare WAF, Proofpoint |
| **Network** | Segmentation, IDS/IPS, NAC, micro-segmentation | Suricata, Cisco ISE, Illumio |
| **Identity** | MFA, SSO, PAM, conditional access, least privilege | Entra ID, Okta, CyberArk |
| **Endpoint** | EDR, NGAV, device compliance, application control | CrowdStrike, Defender for Endpoint |
| **Application** | SAST, DAST, SCA, input validation, secure coding | SonarQube, Snyk, Burp Suite |
| **Data** | Encryption (at-rest, in-transit), DLP, classification, tokenization | Purview DLP, Key Vault, Vault |
| **Monitoring** | SIEM, SOAR, UEBA, threat intelligence | Splunk, Sentinel, Recorded Future |
| **Recovery** | Immutable backups, DR, incident response plans | Veeam, Rubrik, tested IR playbooks |

### Zero Trust Principles

Never trust, always verify. Apply these principles regardless of network location:

1. **Verify explicitly** -- Authenticate and authorize based on all available data points (identity, location, device health, service/workload, data classification, anomalies)
2. **Use least-privilege access** -- Limit access with just-in-time and just-enough-access (JIT/JEA), risk-based adaptive policies, and data protection
3. **Assume breach** -- Minimize blast radius with micro-segmentation, end-to-end encryption, continuous monitoring, and automated threat detection/response

### MITRE ATT&CK Framework

Use ATT&CK to map threats to controls:

| Tactic | Description | Key Mitigations |
|---|---|---|
| Initial Access | How adversaries get in | Email security, WAF, phishing training, MFA |
| Execution | Running malicious code | Application control, EDR, script blocking |
| Persistence | Maintaining access | Monitoring scheduled tasks, startup items, implants |
| Privilege Escalation | Gaining higher access | PAM, least privilege, patch management |
| Defense Evasion | Avoiding detection | EDR, AMSI, logging integrity, behavioral analytics |
| Credential Access | Stealing credentials | MFA, credential hygiene, PAM, secrets management |
| Discovery | Mapping the environment | Network segmentation, honeytokens, deception |
| Lateral Movement | Moving through the network | Micro-segmentation, NAC, EDR, identity analytics |
| Collection | Gathering target data | DLP, data classification, access controls |
| Exfiltration | Stealing data | DLP, network monitoring, CASB, encryption |
| Impact | Disrupting operations | Immutable backups, DR, incident response |

### NIST Cybersecurity Framework 2.0

The six core functions for organizing security programs:

1. **Govern (GV)** -- Establish and monitor security risk management strategy, expectations, and policy
2. **Identify (ID)** -- Understand your assets, business environment, governance, risk assessment, supply chain
3. **Protect (PR)** -- Implement safeguards (access control, awareness training, data security, protective technology)
4. **Detect (DE)** -- Discover security events (continuous monitoring, detection processes, anomaly detection)
5. **Respond (RS)** -- Take action on detected events (response planning, communications, analysis, mitigation)
6. **Recover (RC)** -- Restore capabilities (recovery planning, improvements, communications)

## Subcategory Routing

Read these sibling skills for discipline-specific expertise:

| Request Pattern | Skill |
|---|---|
| **Identity & Access Management** | |
| Active Directory, AD DS, GPO, domain controllers | `ad-ds` (see its Version-Specific Guidance for a Windows Server release) |
| Entra ID, Azure AD, Conditional Access, PIM | `entra-id` |
| Okta, SSO, Universal Directory, OIN | `okta` |
| Auth0, CIAM, Universal Login, Actions | `auth0` |
| Keycloak, realms, identity brokering | `keycloak` |
| AD FS, federation, SAML, claims | `ad-fs` |
| AD CS, PKI, certificate templates, ESC vulnerabilities | `ad-cs` |
| Ping Identity, PingFederate, DaVinci | `ping-identity` |
| AWS IAM, IAM Identity Center, SCPs | `aws-iam` |
| Google Cloud IAM, Cloud Identity | `gcp-iam` |
| SailPoint, IGA, access certifications | `sailpoint` |
| **Endpoint Detection & Response** | |
| CrowdStrike, Falcon sensor, RTR, CQL | `crowdstrike` |
| Defender for Endpoint, MDE, ASR rules, KQL hunting | `defender-endpoint` |
| SentinelOne, Singularity, Storyline, Purple AI | `sentinelone` |
| Carbon Black, CB Defense, CB Response | `carbon-black` |
| Cortex XDR, XQL | `cortex-xdr` |
| Elastic Defend, Elastic Agent | `elastic-defend` |
| Wazuh, HIDS, FIM | `wazuh` |
| **SIEM & Security Analytics** | |
| Splunk, SPL, Enterprise Security, SmartStore | `splunk` (see its Version-Specific Guidance) |
| Microsoft Sentinel, KQL, ASIM, Fusion | `sentinel` |
| Elastic Security, EQL, ES\|QL, detection rules | `elastic-security` (see its Version-Specific Guidance) |
| QRadar, AQL, offenses, DSMs | `qradar` |
| Chronicle, YARA-L, Mandiant TI | `chronicle` |
| Cortex XSIAM, AI-driven SOC | `xsiam` |
| XSOAR, Splunk SOAR, playbook automation | `soar` |
| **Vulnerability Management** | |
| Tenable, Nessus, Tenable One | `tenable` |
| Qualys, VMDR, TotalCloud | `qualys` |
| Rapid7, InsightVM | `rapid7` |
| Attack surface management, EASM | `asm` |
| **Secrets & Certificate Management** | |
| HashiCorp Vault, secret engines, policies | `vault` |
| Azure Key Vault, HSM, managed identity | `azure-key-vault` |
| AWS Secrets Manager, KMS | `aws-secrets` |
| CyberArk, PAM, Conjur | `cyberark` |
| Certificates, PKI, TLS lifecycle | `pki` |
| **Network Security** | |
| IDS/IPS concepts, cross-platform detection, network visibility strategy | `network-security` |
| Suricata rules, EVE JSON, suricata-update, AF_PACKET, IPS mode | `suricata` |
| Snort 3, inspectors, DAQ, OpenAppID, hyperscan, Talos rules | `snort` |
| Zeek scripting, conn.log, dns.log, Intelligence Framework, cluster | `zeek` |
| Cisco ISE, 802.1X, RADIUS, TACACS+, profiling, posture, pxGrid, TrustSec | `cisco-ise` |
| Aruba ClearPass, CPPM, OnGuard, guest portal, OnConnect | `clearpass` |
| FortiNAC, Fortinet NAC, OT/IoT device onboarding | `fortinac` |
| Illumio PCE, VEN, label-based segmentation, enforcement boundaries | `illumio` |
| Guardicore, Akamai Guardicore, deception, process-level segmentation | `guardicore` |
| **Cloud Security** | |
| CNAPP, CSPM, CWPP, CIEM | `cloud-security` |
| Wiz, Prisma Cloud, Orca | `wiz`, `prisma-cloud`, `orca` |
| Container security, Kubernetes security | `container-security` |
| **Application Security** | |
| SAST, SonarQube, Checkmarx, Semgrep | `sast` |
| DAST, Burp Suite, ZAP | `dast` |
| SCA, Snyk, Dependabot | `sca` |
| WAF, Cloudflare WAF, AWS WAF | `waf` |
| **Email Security** | |
| Defender for O365, Proofpoint, Mimecast | `email-security` |
| **Zero Trust / SASE** | |
| Zscaler, Prisma Access, Netskope, ZTNA | `zero-trust` |
| **Data Loss Prevention** | |
| Purview DLP, Forcepoint, Symantec DLP | `dlp` |
| **GRC / Compliance** | |
| Vanta, Drata, OneTrust, compliance automation | `grc` |
| **Backup Security** | |
| Veeam, Rubrik, Cohesity, ransomware protection | `backup-security` |
| **Threat Intelligence** | |
| Recorded Future, Mandiant, MISP, IOCs | `threat-intel` |

## Security Assessment Methodology

When asked to assess security posture, follow this approach:

1. **Asset inventory** -- What are we protecting? (crown jewels, data classification, network topology)
2. **Threat landscape** -- Who would attack us? (nation-state, ransomware, insider, opportunistic)
3. **Control mapping** -- What controls exist? Map to NIST CSF or CIS Controls
4. **Gap analysis** -- Where are the gaps? Prioritize by risk (likelihood x impact)
5. **Remediation roadmap** -- What to fix first? Quick wins, then strategic investments

## Anti-Patterns to Watch For

1. **"Compliance equals security"** -- Compliance is a floor, not a ceiling. Being SOC 2 compliant doesn't mean you're secure against APTs.
2. **"More tools equals better security"** -- Tool sprawl creates integration gaps, alert fatigue, and operational overhead. A well-tuned stack of 5 tools beats a poorly managed stack of 20.
3. **"Security by obscurity"** -- Hiding systems or protocols is not a control. Assume the attacker knows your architecture.
4. **"Flat network with perimeter firewall"** -- East-west traffic is where modern attacks live. Segment aggressively.
5. **"MFA solves everything"** -- MFA is critical but not sufficient. Token theft, MFA fatigue, and SIM swapping bypass it. Layer with device trust and anomaly detection.
6. **"We don't need to test backups"** -- Untested backups are not backups. Test restore procedures regularly, especially for ransomware scenarios.

## Reference Files

Load these for deep foundational knowledge:

- `references/concepts.md` -- Security frameworks (NIST CSF 2.0, CIS Controls v8, ISO 27001, MITRE ATT&CK), risk management, cryptography fundamentals, authentication protocols. Read for "how does X work" or cross-domain architecture questions.
