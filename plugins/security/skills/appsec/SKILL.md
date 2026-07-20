---
name: appsec
description: "Expert routing agent for Application Security (AppSec). Covers OWASP Top 10, secure SDLC, DevSecOps pipelines, threat modeling, and ASVS. Routes to SAST, DAST, SCA, and WAF technology agents. WHEN: \"application security\", \"AppSec\", \"OWASP\", \"secure SDLC\", \"DevSecOps\", \"shift-left\", \"threat modeling\", \"ASVS\", \"vulnerability scanning\", \"security pipeline\". Do NOT use for tool-specific questions -- use the `sast`, `dast`, `sca`, or `waf` skill."
license: MIT
---

# Application Security (AppSec)

This skill covers Application Security across the full software development lifecycle. It provides deep knowledge of secure development practices, industry frameworks, and the tooling ecosystem that enables DevSecOps.

Your coverage spans:

- OWASP Top 10 and ASVS (Application Security Verification Standard)
- Secure SDLC design and implementation
- Shift-left security and developer enablement
- DevSecOps pipeline integration
- Threat modeling methodologies (STRIDE, PASTA, LINDDUN)
- SAST, DAST, SCA, and WAF tooling ecosystems
- Security testing strategy: when to use which tool type

## How to Approach Tasks

When you receive a request:

1. **Classify the domain** -- Determine which AppSec subdomain applies:
   - **SAST** (Static Analysis) -- Source code scanning, IDE integration, CI/CD gates
   - **DAST** (Dynamic Analysis) -- Runtime scanning, API testing, authenticated scans
   - **SCA** (Software Composition Analysis) -- Dependencies, CVEs, license compliance
   - **WAF** (Web Application Firewall) -- Runtime protection, rule management, bot defense
   - **Concepts/Strategy** -- Load `references/concepts.md` for foundational guidance

2. **Identify tooling** -- Determine if the user is working with a specific tool. Read the relevant sibling skill for implementation depth.

3. **Apply framework context** -- Map issues to OWASP Top 10 2021 categories, CWE IDs, or ASVS levels where relevant.

4. **Recommend** -- Provide actionable guidance with pipeline integration examples and remediation patterns.

## SAST Routing

Read `sast` for general SAST questions, or directly to:

| Tool | Agent | Best For |
|---|---|---|
| SonarQube / SonarCloud | `sonarqube` | Quality gates, multi-language, enterprise CI/CD |
| Checkmarx One | `checkmarx` | Enterprise unified AppSec, CxQL custom rules |
| Semgrep | `semgrep` | Custom rules, OSS engine, fast CI scanning |
| Snyk Code | `snyk-code` | AI-powered, IDE-first, unified Snyk platform |
| Veracode | `veracode` | Binary analysis, compliance, eLearning |

**SAST trigger keywords:** static analysis, code scanning, SAST, source code review, security hotspot, taint analysis, custom rules, quality gate, pipeline scan.

## DAST Routing

Read `dast` for general DAST questions, or directly to:

| Tool | Agent | Best For |
|---|---|---|
| Burp Suite | `burp-suite` | Manual pen testing, enterprise DAST, extensions |
| OWASP ZAP | `zap` | Open source, automation framework, API scanning |
| StackHawk | `stackhawk` | CI/CD-native DAST, developer-focused |

**DAST trigger keywords:** dynamic analysis, DAST, runtime scanning, fuzzing, intercepting proxy, authenticated scan, API security testing, crawling, active scan.

## SCA Routing

Read `sca` for general SCA questions, or directly to:

| Tool | Agent | Best For |
|---|---|---|
| Snyk Open Source | `snyk-oss` | Auto-fix PRs, reachability, license compliance |
| Dependabot | `dependabot` | GitHub-native, version updates, security alerts |
| Mend | `mend` | Enterprise SCA, license compliance, Renovate |
| Black Duck | `black-duck` | Binary analysis, SOUP lists, export compliance |

**SCA trigger keywords:** software composition analysis, SCA, open source vulnerabilities, dependency scanning, CVE, license compliance, SBOM, supply chain, transitive dependencies.

## WAF Routing

Read `waf` for general WAF questions, or directly to:

| Tool | Agent | Best For |
|---|---|---|
| Cloudflare WAF | `cloudflare-waf` | Managed rulesets, bot management, API shield |
| AWS WAF | `aws-waf` | AWS-native, WebACLs, marketplace rules |
| Akamai App & API Protector | `akamai-waf` | WAAP, adaptive security, enterprise CDN |
| F5 Advanced WAF | `f5-waf` | BIG-IP, credential stuffing, DataSafe |

**WAF trigger keywords:** web application firewall, WAF, WAAP, managed rules, rate limiting, bot protection, DDoS mitigation, IP reputation, rule tuning, false positives.

## Core AppSec Concepts

### OWASP Top 10 2021 Quick Reference

| Rank | Category | Key CWEs |
|---|---|---|
| A01 | Broken Access Control | CWE-22, CWE-284, CWE-285, CWE-639 |
| A02 | Cryptographic Failures | CWE-259, CWE-327, CWE-331 |
| A03 | Injection | CWE-79, CWE-89, CWE-917 |
| A04 | Insecure Design | CWE-73, CWE-183, CWE-209 |
| A05 | Security Misconfiguration | CWE-16, CWE-611 |
| A06 | Vulnerable & Outdated Components | CWE-1104 |
| A07 | Identification & Authentication Failures | CWE-287, CWE-297, CWE-384 |
| A08 | Software & Data Integrity Failures | CWE-345, CWE-494, CWE-829 |
| A09 | Security Logging & Monitoring Failures | CWE-117, CWE-223, CWE-778 |
| A10 | Server-Side Request Forgery | CWE-918 |

### Secure SDLC Integration Points

```
Requirements  →  Design  →  Development  →  Build  →  Test  →  Deploy  →  Operate
     |               |            |            |         |          |          |
  Threat          ASVS        IDE SAST      SAST CI   DAST/     WAF       DIEM/
  Modeling      Controls    (Snyk/Semgrep)  Gate      Pen Test  Deploy    Monitor
```

**Shift-Left Principle:** Move security checks as early as possible. IDE plugins catch issues before commit. Pre-commit hooks enforce baseline. CI gates block merges. This reduces remediation cost by 10-100x vs. finding issues in production.

### DevSecOps Pipeline Stages

1. **Pre-commit:** Secret scanning (detect-secrets, git-secrets), linting with security rules
2. **Pull Request:** SAST (Semgrep/SonarQube PR decoration), SCA (Snyk/Dependabot alerts)
3. **Build:** Full SAST scan, dependency audit, container image scanning
4. **Test:** DAST against deployed test environment, API security tests
5. **Release gate:** Security quality gate must pass (policy enforcement)
6. **Deploy:** WAF rules provisioned/updated, RASP if applicable
7. **Runtime:** WAF monitoring, DAST scheduled scans, threat intelligence feeds

### Tool Type Selection Guide

| Scenario | Recommended Approach |
|---|---|
| Finding vulnerabilities in code you write | SAST |
| Finding vulnerabilities in running application | DAST |
| Finding vulnerabilities in libraries you use | SCA |
| Blocking attacks in production | WAF |
| Compliance audit (PCI DSS, SOC 2) | SAST + SCA + WAF combination |
| Developer security training feedback loop | IDE SAST (Snyk Code, SonarLint) |
| Third-party binary with no source | Veracode (binary analysis) or Black Duck |
| API security testing | DAST with API schema (ZAP/Burp) |
| Supply chain security | SCA + SBOM generation |

### Threat Modeling for Applications

Use STRIDE per-component:

- **Spoofing** -- Authentication bypass, session hijacking → A07
- **Tampering** -- Input manipulation, SQL injection → A03, A08
- **Repudiation** -- Audit log bypass → A09
- **Information Disclosure** -- Data exposure, crypto failures → A02
- **Denial of Service** -- Resource exhaustion, rate limiting → WAF mitigation
- **Elevation of Privilege** -- Access control bypass → A01

### ASVS Verification Levels

- **Level 1:** Opportunistic security, automated testing sufficient. All software should meet L1.
- **Level 2:** Standard security for applications handling sensitive data. Requires manual verification for some controls.
- **Level 3:** Critical applications (finance, healthcare, safety-critical). Requires penetration testing and architectural review.

## Reference Files

- `references/concepts.md` -- Deep dive on OWASP Top 10 2021 detail, secure SDLC phases, shift-left patterns, DevSecOps toolchain topology, threat modeling methodologies, ASVS control mapping
