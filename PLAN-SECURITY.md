# Security Domain — Agent Library Inventory

Comprehensive inventory of security technologies, versions, and proposed agent hierarchy. Expanded from PLAN.md Section 3 with full research.

---

## 1. Identity & Access Management (IAM)

### On-Premises Directory & Federation

- **Windows Active Directory (AD DS)**
  - Windows Server 2016 (functional level 2016)
  - Windows Server 2019 (functional level 2016)
  - Windows Server 2022 (functional level 2016)
  - Windows Server 2025 (functional level 10 — new 32K DB pages, NTLM deprecated, RC4 disabled, SMB signing required)

- **Active Directory Federation Services (ADFS)**
  - Server 2016, 2019, 2022, 2025 (maintenance mode — Microsoft recommends migration to Entra ID)

- **Active Directory Certificate Services (AD CS)**
  - Server 2016, 2019, 2022, 2025
  - Critical: ESC1-ESC16 vulnerability knowledge required

### Cloud Identity

- **Microsoft Entra ID (Azure AD)** — managed
  - Tiers: Free, P1, P2, Governance add-on
  - Key areas: Conditional Access, PIM, Identity Protection, B2B/B2C, hybrid identity (Connect/Cloud Sync), passwordless/passkeys, app registrations

- **Okta** — managed (Identity Engine platform)
  - Universal Directory, SSO (7,000+ OIN integrations), Adaptive MFA, Lifecycle Management, Identity Governance, Workflows, API Access Management, Identity Threat Protection

- **Auth0** — managed (by Okta, CIAM-focused)
  - Tenants, Organizations, Actions, Connections, RBAC, Attack Protection, Adaptive MFA, Universal Login, Auth0 for AI Agents

- **Keycloak** — 26.x (open source, Apache 2.0)
  - Realms, identity brokering, LDAP/AD federation, OIDC/SAML, fine-grained authz, Organizations (GA 26.0), Quarkus-based

- **Ping Identity** — managed (PingOne platform)
  - PingFederate (on-prem federation), PingAccess, PingDirectory, DaVinci orchestration, PingOne Protect

### Additional IAM (recommended additions)

- **AWS IAM + IAM Identity Center** — managed (every AWS environment)
- **Google Cloud IAM + Cloud Identity** — managed (every GCP environment)
- **SailPoint IdentityNow** — managed (IGA leader — access certifications, lifecycle, SOD)
- **CyberArk PAM** — see Secrets section (PAM + identity governance)
- **Saviynt** — managed (converged IGA + PAM + CIEM)

---

## 2. Endpoint Security / EDR

- **CrowdStrike Falcon** — managed
  - Tiers: Go (~$60), Pro (~$100), Enterprise (~$185), Elite (~$225), Complete (MDR)
  - Falcon sensor, RTR, IOA/IOC, Falcon Insight XDR, OverWatch managed hunting, CQL, Charlotte AI agents, LogScale SIEM

- **Microsoft Defender for Endpoint** — managed
  - Plan 1 (in M365 E3): NGAV, ASR rules, device control
  - Plan 2 (in M365 E5): + EDR, automated investigation, advanced hunting (KQL), threat analytics, vulnerability management

- **SentinelOne Singularity** — managed
  - Tiers: Core (~$70), Control (~$120), Complete (~$180), Enterprise (~$230)
  - Storyline tech, autonomous response, 1-click rollback, Purple AI, Deep Visibility, Ranger network discovery

- **Carbon Black (Broadcom)** — managed
  - Endpoint Standard (CB Defense successor), Enterprise EDR (CB Response successor)
  - Solr/Lucene query, process tree, watchlists
  - Note: Broadcom acquisition creating product uncertainty

### Additional EDR (recommended additions)

- **Palo Alto Cortex XDR** — managed (cross-domain XDR, XQL query language)
- **Elastic Defend** — tied to Elastic Stack 8.x/9.x (open-source core, KQL/EQL)
- **Sophos Intercept X** — managed (deep learning, CryptoGuard, MDR)
- **Wazuh** — open source (HIDS/EDR, FIM, compliance)

---

## 3. SIEM & Security Analytics

- **Splunk Enterprise**
  - 9.4.x (current 9.x line)
  - 10.0 (major release — FIPS 140-3, SPL2, Edge Processor)
  - Splunk ES 8.2/8.3 (Enterprise Security)
  - SPL query language, CIM normalization, indexer clustering, SmartStore

- **Microsoft Sentinel** — managed (Azure-native)
  - KQL query language, ASIM normalization, Fusion ML detection, UEBA
  - Migrating to Defender portal (mandatory July 2026)
  - Cost tiers: Pay-as-you-go (~$2.46/GB), commitment tiers (100-5000 GB/day)

- **Elastic Security** — tied to Elasticsearch
  - 8.18.x (current 8.x), 9.x (current)
  - EQL (event sequences), ES|QL (piped analytics), KQL (Kibana), Lucene
  - ECS normalization, 1,300+ prebuilt rules, ML anomaly detection
  - Self-managed or Elastic Cloud (Hosted/Serverless)

- **IBM QRadar** — 7.5.x on-prem (SaaS EOL Apr 2026 → Cortex XSIAM)
  - AQL query language, DSM normalization, offense management, Ariel DB
  - Note: SaaS/cloud divested to Palo Alto; on-prem continues

### Additional SIEM (recommended additions)

- **Google Security Operations (Chronicle)** — managed (YARA-L 2.0, Mandiant TI, unlimited retention)
- **Palo Alto Cortex XSIAM** — managed (AI-driven SOC, destination for QRadar SaaS migrants)
- **CrowdStrike Falcon LogScale** — managed (streaming SIEM, LQL query language)
- **Exabeam** — managed (UEBA-centric, acquired LogRhythm)
- **Wazuh** — open source (XDR/SIEM on OpenSearch)

### SOAR (sub-category of SIEM)

- **Palo Alto Cortex XSOAR** — managed (900+ integrations)
- **Splunk SOAR** — managed/on-prem (300+ integrations, 2,800+ actions)
- **Microsoft Sentinel Playbooks** — Azure Logic Apps-based
- **Tines** — managed (no-code automation)
- **Torq** — managed (hyperautomation)

---

## 4. Vulnerability Management

- **Tenable Nessus / Tenable.io / Tenable One**
  - Nessus 10.11.x (Professional ~$4,790/yr, Expert ~$6,790/yr)
  - Tenable One: unified exposure management (CVSS, EPSS, attack path analysis)

- **Qualys VMDR / TotalCloud**
  - TotalCloud 2.23.0 (current)
  - Cloud Agent, VMDR, Policy Compliance, WAS, Container Security, CSAM

- **Rapid7 InsightVM**
  - Console 8.18.0+ / release 26.x
  - Scan engines + Insight Agent, Active Risk Score, EPSS, Remediation Hub

### Additional Vulnerability Management

- **Snyk** — managed (developer-first: Code SAST, Open Source SCA, Container, IaC)
- **Wiz** — managed (agentless CNAPP, Security Graph, acquired by Google $32B)
- **Prisma Cloud / Cortex Cloud** — managed (CNAPP: CSPM, CWPP, CIEM, code-to-cloud)
- **Orca Security** — managed (agentless SideScanning CNAPP)
- **Microsoft Defender for Cloud** — managed (Azure-native CSPM, multi-cloud)
- **AWS Security Hub** — managed (AWS-native CSPM)

### Attack Surface Management (sub-category)

- **CrowdStrike Falcon Surface** — managed (EASM + endpoint correlation)
- **Palo Alto Cortex Xpanse** — managed (internet-scale asset discovery)
- **Microsoft Defender EASM** — managed
- **Censys ASM** — managed

---

## 5. Secrets & Certificate Management

### Secrets Management

- **HashiCorp Vault**
  - 1.21 (current — SPIFFE auth, KV v2 attribution, Secrets Operator CSI)
  - Community (BSL 1.1), Enterprise (self-hosted), HCP Vault Dedicated (SaaS)
  - Note: HCP Vault Secrets EOL Jul 2026

- **Azure Key Vault** — managed
  - Standard (software-protected), Premium (HSM-backed FIPS 140-3 Level 3)
  - API 2026-02-01: RBAC default, managed identity integration

- **AWS Secrets Manager / KMS** — managed
  - Automatic rotation (RDS, DocumentDB, Redshift, Lambda-based custom)
  - KMS: symmetric (AES-256), asymmetric (RSA, ECC), HMAC

- **CyberArk PAM / Conjur**
  - PAM v14.x (self-hosted), Privilege Cloud v14.1 (SaaS)
  - Conjur Enterprise 13.7 / OSS 1.21.1
  - Acquired Venafi (Oct 2024) — now includes Machine Identity Security

### Additional Secrets Management

- **Doppler** — managed (centralized SaaS secrets, developer-friendly)
- **Infisical** — open source (MIT core, dynamic secrets, PKI, PAM)
- **1Password Secrets Automation** — managed (service accounts, Connect Server)
- **Mozilla SOPS** — open source (file-level encryption, GitOps-native)

### PKI / Certificate Management

- **Active Directory Certificate Services (AD CS)** — see IAM section
- **Let's Encrypt** — managed (ACME, 6-day short-lived certs, 45-day opt-in May 2026)
- **Venafi / CyberArk Machine Identity** — managed (TLS lifecycle, SPIFFE, quantum-ready)
- **DigiCert CertCentral / Trust Lifecycle Manager** — managed (vendor-agnostic TLM)
- **cert-manager** — 1.20.0 (CNCF graduated, Kubernetes TLS automation)
- **Keyfactor / EJBCA** — open source + enterprise (Common Criteria certified PKI)
- **smallstep (step-ca)** — open source (DevOps/internal PKI, OIDC auth)

---

## 6. Network Security

### IDS / IPS

- **Suricata** — 8.0.x (current), 7.0.x LTS (open source, multi-threaded)
- **Snort 3** — 3.12.x (Cisco Talos, Snort 2 EOL Jan 2026)
- **Zeek** — 8.x (passive network analysis, structured logs, not traditional IDS)

### Network Access Control (NAC)

- **Cisco ISE** — 3.x (22.4% mindshare, 802.1X, posture, TACACS+)
- **Aruba ClearPass** — 6.12.x (21.6% mindshare, device profiling)
- **FortiNAC** — managed (Fortinet ecosystem)

### Micro-segmentation

- **Illumio** — managed (workload-centric, real-time dependency mapping)
- **Akamai Guardicore** — managed (AI-powered east-west segmentation)

---

## 7. Cloud Security (CSPM / CNAPP)

- **Wiz** — managed (agentless CNAPP, Security Graph, Google acquisition)
- **Prisma Cloud / Cortex Cloud** — managed (Palo Alto, CSPM+CWPP+CIEM+DSPM)
- **Orca Security** — managed (agentless SideScanning)
- **Microsoft Defender for Cloud** — managed (Azure-native, multi-cloud)
- **AWS Security Hub** — managed (AWS-native)

### Container & Kubernetes Security (sub-category)

- **Aqua Security** — managed (full container lifecycle)
- **Sysdig Secure** — managed (CNAPP on Falco, runtime security)
- **Falco** — open source (CNCF graduated, kernel syscall monitoring)

---

## 8. Application Security

### SAST (Static Analysis)

- **SonarQube** — 2026.x (2026.1 LTA), SonarCloud (SaaS)
- **Checkmarx One** — 3.56 (multi-tenant SaaS, 35+ languages)
- **Semgrep** — 1.157+ (semantic pattern matching, open-source engine)
- **Snyk Code** — managed (AI-driven SAST)
- **Veracode** — managed (11x Gartner MQ Leader)

### DAST (Dynamic Analysis)

- **Burp Suite DAST** — 2025.12 (Docker-based CI/CD)
- **OWASP ZAP** — open source (YAML automation, Apache 2.0)
- **StackHawk** — managed (CI/CD-native, built on ZAP)

### SCA (Software Composition Analysis)

- **Snyk Open Source** — managed (developer workflows, automated fix PRs)
- **Dependabot** — managed (GitHub-native)
- **Mend (WhiteSource)** — managed (enterprise SCA + license compliance)
- **Black Duck (Synopsys)** — managed (binary analysis)

### WAF (Web Application Firewall)

- **Cloudflare WAF** — managed (CDN-integrated)
- **AWS WAF** — managed (CloudFormation/Terraform)
- **Akamai App & API Protector** — managed (premium WAAP)
- **F5 Advanced WAF** — appliance + SaaS

---

## 9. Email Security

- **Microsoft Defender for Office 365** — managed (Plan 1: Safe Links/Attachments, Plan 2: + AIR)
- **Proofpoint Email Protection** — managed (SEG, 83% of Fortune 100)
- **Mimecast** — managed (SEG, email continuity)
- **Abnormal AI** — managed (behavioral AI, API-based BEC detection)
- **Sublime Security** — managed (programmable, M365/Google Workspace)

---

## 10. Zero Trust / SASE / SSE

- **Zscaler Zero Trust Exchange** — managed (~40% Fortune 500, ZIA/ZPA/ZDX)
- **Palo Alto Prisma Access / SASE** — managed (SWG+ZTNA+FWaaS+CASB)
- **Netskope One** — managed (ZTNA+CASB+SWG+DLP, 75+ regions)
- **Cloudflare Zero Trust** — managed (global anycast, free tier)
- **Cato Networks** — managed (single-pass cloud engine, SD-WAN + security)

---

## 11. Data Loss Prevention (DLP)

- **Microsoft Purview DLP** — managed (M365-native, AI Copilot leak prevention)
- **Forcepoint DLP** — on-prem + SaaS (behavioral analytics, dynamic risk)
- **Symantec DLP (Broadcom)** — on-prem + SaaS (indexed document matching, OCR)
- **Digital Guardian (Fortra)** — agent-based (endpoint-first DLP)
- **Cyberhaven** — managed (data lineage tracking, next-gen)

---

## 12. Compliance / GRC

- **Vanta** — managed (400+ integrations, 35+ frameworks, AI policy agent)
- **Drata** — managed (1,200+ automated tests, 170+ integrations)
- **OneTrust** — managed (privacy + tech risk + third-party risk + AI governance)
- **ServiceNow GRC** — managed (on Now Platform)
- **Archer (RSA)** — on-prem + SaaS (traditional enterprise GRC)

---

## 13. Backup Security / Ransomware Protection

- **Veeam Data Platform** — v13.0 (current), v12.3 (LTS)
  - Immutable backups, Secure Restore with sandbox scanning

- **Rubrik Security Cloud** — CDM 9.4 (current)
  - AI-driven anomaly detection, zero trust data security architecture

- **Cohesity DataProtect** — Data Cloud 7.2 (EOL Jun 2026)
  - FortKnox cyber vault, instant mass restore

- **Commvault Cloud** — Innovation Release 11.42, LTS 11.40
  - Cloud Rewind, Unity Platform

---

## 14. Threat Intelligence

- **Recorded Future** — managed (AI-driven predictive analytics)
- **Mandiant Threat Intelligence (Google)** — managed (incident response expertise)
- **ThreatConnect** — managed (CAL ML, acquired by Dataminr)
- **MISP** — open source (threat sharing and correlation)

---

## Agent Count Estimates

| Subcategory | Tech Agents | Version Agents | Total |
|-------------|-------------|----------------|-------|
| IAM (on-prem + cloud + additional) | ~12 | ~15 | ~27 |
| EDR (core + additional) | ~8 | ~10 | ~18 |
| SIEM & SOAR | ~10 | ~12 | ~22 |
| Vulnerability Management + ASM | ~10 | ~10 | ~20 |
| Secrets + PKI/Certificates | ~12 | ~10 | ~22 |
| Network Security (IDS/NAC/micro-seg) | ~7 | ~8 | ~15 |
| Cloud Security (CSPM/CNAPP/K8s) | ~8 | ~5 | ~13 |
| Application Security (SAST/DAST/SCA/WAF) | ~12 | ~12 | ~24 |
| Email Security | ~5 | ~5 | ~10 |
| Zero Trust / SASE | ~5 | ~5 | ~10 |
| DLP | ~5 | ~5 | ~10 |
| GRC / Compliance | ~5 | ~3 | ~8 |
| Backup Security | ~4 | ~6 | ~10 |
| Threat Intelligence | ~4 | ~3 | ~7 |
| **Totals** | **~107** | **~109** | **~216** |

---

## Implementation Priority

### Tier 1 — Build First (highest impact, broadest use)
1. **IAM**: AD DS, Entra ID, Okta, AD CS (foundational to every environment)
2. **SIEM**: Splunk, Sentinel, Elastic Security (SOC backbone)
3. **EDR**: CrowdStrike, Defender for Endpoint, SentinelOne

### Tier 2 — Build Next (critical security functions)
4. **Secrets**: Vault, Azure Key Vault, AWS SM/KMS, CyberArk
5. **Vulnerability Management**: Tenable, Qualys, Rapid7
6. **Cloud Security**: Wiz, Defender for Cloud, Prisma Cloud

### Tier 3 — Expand (specialized domains)
7. **Application Security**: SonarQube, Snyk, Burp Suite, ZAP
8. **Zero Trust / SASE**: Zscaler, Prisma Access, Netskope
9. **Email Security**: Defender for O365, Proofpoint
10. **Network Security**: Suricata, Cisco ISE

### Tier 4 — Complete (niche / managed services)
11. **DLP**: Purview, Forcepoint
12. **GRC**: Vanta, Drata
13. **Backup Security**: Veeam, Rubrik
14. **Threat Intelligence**: Recorded Future, Mandiant, MISP
