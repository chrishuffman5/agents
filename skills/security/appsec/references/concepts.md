# AppSec Concepts Reference

Deep reference for Application Security fundamentals: OWASP Top 10 2021, secure SDLC, shift-left security, DevSecOps pipeline topology, threat modeling, and ASVS control mapping.

---

## OWASP Top 10 2021 — Detailed Analysis

### A01: Broken Access Control (up from #5)

**What it is:** Restrictions on authenticated users are not properly enforced. Users can act outside their intended permissions.

**Common vulnerabilities:**
- Horizontal privilege escalation: accessing other users' records via IDOR (Insecure Direct Object Reference)
- Vertical privilege escalation: accessing admin functions as a regular user
- Missing function-level access control: API endpoints unprotected because UI hides them
- CORS misconfiguration: allowing origins that should not have access
- JWT tampering: altering token claims when signature is not verified
- Path traversal: `../../etc/passwd` reaching files outside web root
- Force browsing to authenticated pages without authentication check

**Detection approach:**
- DAST: authenticated scanning with multiple user roles, comparing responses
- SAST: data flow analysis from user-controlled input to authorization checks
- Manual: test every API endpoint with a lower-privileged token

**Remediation patterns:**
- Deny by default: explicitly grant, never implicitly allow
- Centralize access control logic — do not replicate per endpoint
- Log access control failures, alert on repeated failures (A09 connection)
- Use immutable, server-side session state for permissions — do not trust client-supplied role claims

---

### A02: Cryptographic Failures (formerly "Sensitive Data Exposure")

**What it is:** Failures in cryptography (or its absence) that expose sensitive data.

**Common vulnerabilities:**
- Transmitting data in cleartext (HTTP, unencrypted SMTP/FTP)
- Using weak/deprecated algorithms: MD5, SHA-1, DES, RC4, ECB mode
- Hardcoded keys or weak key generation (insufficient entropy)
- Not enforcing HTTPS (missing HSTS header)
- Storing passwords without proper hashing (bcrypt/scrypt/Argon2 required)
- Using deprecated padding (PKCS#1 v1.5 RSA) vulnerable to padding oracle attacks
- Insufficient key rotation

**Detection approach:**
- SAST: detecting hardcoded secrets, weak algorithm usage (CWE-327, CWE-328)
- SCA: libraries with known cryptographic vulnerabilities
- Secret scanning: API keys, certificates, passwords in source code

**Remediation patterns:**
- Enforce TLS 1.2+ everywhere; add HSTS with preload
- Use Argon2id for passwords (memory-hard); bcrypt as fallback
- Use AES-256-GCM for symmetric encryption
- Use RSA-OAEP or ECDH for key exchange
- Store only hashed passwords, never plaintext or reversibly encrypted
- Use a secrets manager (Vault, AWS Secrets Manager) — never environment variables for secrets in container definitions

---

### A03: Injection (merged with XSS from 2017)

**What it is:** User-supplied data is interpreted as commands or queries.

**Subtypes:**
- **SQL injection:** `' OR 1=1--` — use parameterized queries/ORMs
- **NoSQL injection:** MongoDB `$where` operator with user input
- **LDAP injection:** unescaped input in LDAP filters
- **OS Command injection:** `system()`, `exec()` with user input
- **XSS (Cross-Site Scripting):** reflected, stored, DOM-based — output encoding
- **Template injection:** SSTI in Jinja2, Twig, Freemarker
- **Log injection:** CRLF injection into log entries, log4shell (JNDI lookup injection)

**Detection approach:**
- SAST taint analysis: track user input from source (HTTP params, headers) to sink (DB query, shell execution)
- DAST: automated payload injection across all input vectors
- Manual: review every place where user data meets an interpreter

**Remediation patterns:**
- Parameterized queries / prepared statements: never concatenate user input into queries
- Use allowlist input validation, not denylist
- Escape output context-specifically (HTML, JavaScript, URL, CSS contexts differ)
- Use Content Security Policy (CSP) to mitigate XSS impact
- Apply principle of least privilege to database accounts

---

### A04: Insecure Design (new in 2021)

**What it is:** Missing or ineffective security controls at the design/architecture level. Cannot be fixed by perfect implementation — requires redesign.

**Common patterns:**
- No rate limiting on credential recovery flows (enables account enumeration or brute force)
- Storing sensitive data that was never needed in the first place
- Multi-factor authentication not required for administrative actions
- Trusting client-side data for business-critical decisions
- Not separating tenants adequately in multi-tenant systems
- Lack of defense in depth: single control at perimeter, nothing internally

**Remediation patterns:**
- Threat model during design phase, not after
- Apply ASVS L2 requirements as design checklist
- Use secure design patterns: secure defaults, fail secure, defense in depth
- Limit resource consumption per user (anti-automation controls)

---

### A05: Security Misconfiguration

**What it is:** Incorrect or incomplete security configuration, often default configs that are insecure.

**Common vulnerabilities:**
- Default credentials unchanged (admin/admin)
- Unnecessary features enabled (debug endpoints, stack traces in production)
- Missing security headers (X-Content-Type-Options, X-Frame-Options, CSP)
- Overly permissive CORS (`Access-Control-Allow-Origin: *` for authenticated APIs)
- Cloud storage publicly readable (S3 bucket, Azure Blob)
- XML External Entity (XXE) processing enabled in XML parsers
- Verbose error messages revealing internal structure

**Detection approach:**
- DAST: header scanning, error message analysis
- Infrastructure as Code scanning (KICS, Checkov, tfsec)
- Cloud security posture management (CSPM) tools

---

### A06: Vulnerable and Outdated Components

**What it is:** Using components (libraries, frameworks, OS) with known vulnerabilities.

**Detection approach:**
- SCA: continuous monitoring of dependency trees against vulnerability databases (NVD, OSV, GitHub Advisory)
- Container scanning: base image vulnerabilities
- SBOM generation for audit trail

**Remediation patterns:**
- Maintain SBOM (Software Bill of Materials) for all applications
- Automate dependency updates (Dependabot, Renovate, Snyk)
- Apply patches within SLA based on CVSS severity (Critical: 24h, High: 7d, Medium: 30d typical)
- Subscribe to security advisories for critical dependencies

---

### A07: Identification and Authentication Failures

**What it is:** Weaknesses in authentication or session management that allow attackers to impersonate users.

**Common vulnerabilities:**
- Permitting weak passwords or credential stuffing attacks (no account lockout)
- Using MD5/SHA1 for password hashing
- Weak password reset (security questions, predictable tokens)
- Exposing session IDs in URLs
- Not invalidating sessions on logout or after timeout
- Missing MFA for sensitive actions

---

### A08: Software and Data Integrity Failures (new in 2021)

**What it is:** Code and infrastructure that does not protect against integrity violations, including insecure deserialization and CI/CD pipeline attacks.

**Common vulnerabilities:**
- Insecure deserialization: Java ObjectInputStream, Python pickle with untrusted data
- Unsigned software updates (no signature verification)
- Untrusted CDN content without SRI (Subresource Integrity) hashes
- Compromised CI/CD pipeline (dependency confusion, malicious plugins)
- Using packages without pinned versions (supply chain attacks)

**Detection approach:**
- SCA with integrity verification
- SAST rules for unsafe deserialization sinks
- CI/CD pipeline security review (least privilege for build processes)

---

### A09: Security Logging and Monitoring Failures

**What it is:** Insufficient logging, detection, and response capability — enables attackers to operate undetected.

**What must be logged:**
- Authentication events (success and failure)
- Authorization failures (access control denials)
- Input validation failures (injection attempts)
- Application errors and exceptions
- High-value transactions

**Log quality requirements:**
- Sufficient context: user ID, IP, timestamp, action, outcome
- Tamper-evident: logs written to append-only storage, forwarded to SIEM
- Alerting on threshold violations: >5 auth failures per minute per IP
- Retention: PCI DSS requires 12 months, SOC 2 typically 90 days minimum accessible

---

### A10: Server-Side Request Forgery (SSRF)

**What it is:** The application fetches a remote resource based on user-supplied URL. Attackers redirect requests to internal services.

**Attack targets:**
- Cloud metadata APIs: `http://169.254.169.254/latest/meta-data/` (AWS IMDSv1)
- Internal services: databases, admin panels, Kubernetes API
- File system: `file:///etc/passwd`

**Detection approach:**
- SAST: track user-controlled input to HTTP client calls
- DAST: inject internal IP ranges and cloud metadata URLs

**Remediation:**
- Allowlist permitted URL schemes and destination hosts
- Disable redirects or re-validate destination after redirect
- Use IMDSv2 (token-required) for AWS EC2 metadata
- Network segmentation: application servers should not have unrestricted outbound access

---

## Secure SDLC Phases

### Phase 1: Requirements

Security activities:
- Define security requirements based on data classification and regulatory scope
- Apply ASVS level appropriate to the application risk tier
- Document abuse cases alongside use cases
- Identify compliance requirements (PCI DSS, HIPAA, GDPR, SOC 2)

Outputs: Security requirements document, risk tier classification.

### Phase 2: Design

Security activities:
- **Threat modeling** — STRIDE analysis per component and data flow
- Architecture review — authentication, authorization, encryption, data flow
- API design review — rate limiting, authentication, versioning
- Select security controls (authentication mechanism, encryption standards)

Outputs: Threat model document, security architecture decisions, data flow diagrams.

### Phase 3: Development

Security activities:
- IDE security plugins (SonarLint, Snyk IDE, Semgrep VS Code extension)
- Secure coding standards and training
- Code review with security checklist
- Pre-commit hooks: secret scanning, linting

Outputs: Secure code, developer security awareness.

### Phase 4: Build and CI

Security activities:
- SAST scan in CI pipeline (fail on new critical/high issues)
- SCA scan (block on known exploitable vulnerabilities)
- IaC scanning (Terraform, CloudFormation, Kubernetes manifests)
- Container image scanning
- SBOM generation

Quality gates: No new critical or high vulnerabilities. License compliance verified.

### Phase 5: Testing

Security activities:
- DAST against deployed test environment
- API security testing (OWASP API Security Top 10)
- Penetration testing (quarterly or per major release for L2/L3 apps)
- Security regression tests for previously found vulnerabilities

### Phase 6: Release

Security activities:
- Security sign-off from AppSec team (risk acceptance for open items)
- WAF rules reviewed and updated
- Secrets rotated in production
- Security release notes for any security-relevant changes

### Phase 7: Operations

Security activities:
- WAF monitoring and tuning (reduce false positives, detect new attack patterns)
- Scheduled DAST scans (weekly/monthly)
- Vulnerability management: SLA-driven patching of new CVEs
- Security incident response procedures
- Penetration testing cadence

---

## Shift-Left Security

**Principle:** Each step left in the SDLC where a vulnerability is found reduces remediation cost by roughly an order of magnitude.

| Where Found | Relative Cost | Method |
|---|---|---|
| Design/requirements | 1x | Threat model review |
| Development (IDE) | 6x | IDE SAST plugin |
| Build/CI | 15x | CI SAST/SCA gate |
| QA/testing | 45x | DAST, pen test |
| Production | 100x | WAF detection, incident response |

**Practical implementation:**
1. Start with IDE plugins — zero friction, immediate feedback
2. Add pre-commit secret scanning (detect-secrets, trufflehog)
3. Add SAST to PR checks (annotate diffs, not full report)
4. Add SCA to CI (fail on known exploitable CVEs)
5. Add DAST to test pipeline (weekly or per release)
6. Add WAF as last defense layer in production

**Common anti-patterns:**
- "We'll add security at the end" — integration cost becomes prohibitive
- Running full SAST reports without quality gates — alert fatigue, ignored results
- Blocking all high/medium SAST findings immediately — kills developer productivity; phase in over time
- No developer context in security findings — findings ignored without fix guidance

---

## DevSecOps Pipeline Topology

```
Developer Workstation
├── IDE Plugin (SonarLint / Snyk / Semgrep)     ← Real-time feedback
└── Pre-commit Hook (secrets scan, lint)          ← Before commit

Source Control (GitHub/GitLab/Azure DevOps)
├── PR Decoration (SAST diff scan)               ← Annotates PR with findings
├── Dependency Review (SCA)                       ← Blocks merge on exploitable CVEs
└── Secret Scanning (native + enhanced)           ← Push protection

CI Pipeline (Jenkins/GitHub Actions/GitLab CI)
├── Build Stage
│   ├── SAST Full Scan                           ← Full codebase analysis
│   ├── SCA Dependency Scan                      ← License + vulnerability check
│   ├── IaC Scan (KICS/Checkov/tfsec)           ← Infrastructure as code
│   └── Container Image Scan                     ← Base image + app layer
├── Quality Gate                                 ← Block on policy violations
└── SBOM Generation                              ← Artifact for compliance

Test Environment Deployment
├── DAST Automated Scan (ZAP/StackHawk)         ← Against running app
├── API Security Tests                           ← Schema-based testing
└── Smoke Security Tests                         ← Critical vulnerability regression

Production Deployment
├── WAF Rule Provisioning                        ← Cloudflare/AWS WAF/F5
├── Runtime Telemetry                            ← SIEM integration
└── Continuous Monitoring                        ← Scheduled DAST, SCA updates
```

### Tool Integration Patterns

**GitHub Actions example structure:**
```yaml
jobs:
  security:
    steps:
      - uses: actions/checkout@v4
      - name: SAST (Semgrep)
        uses: semgrep/semgrep-action@v1
        with:
          config: p/owasp-top-ten
      - name: SCA (Snyk)
        uses: snyk/actions/node@master
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
      - name: DAST (ZAP)
        uses: zaproxy/action-full-scan@v0.10.0
        with:
          target: 'https://test.example.com'
```

---

## Threat Modeling Methodologies

### STRIDE

Best for: Application and service threat modeling. Per-component analysis.

| Threat | Property Violated | Example |
|---|---|---|
| Spoofing | Authentication | Forged JWT, ARP spoofing |
| Tampering | Integrity | SQL injection, parameter manipulation |
| Repudiation | Non-repudiation | Deleting audit logs |
| Information Disclosure | Confidentiality | Directory traversal, verbose errors |
| Denial of Service | Availability | ReDoS, resource exhaustion |
| Elevation of Privilege | Authorization | IDOR, SSRF to metadata API |

**Process:**
1. Draw DFD (Data Flow Diagram) with trust boundaries
2. For each element and data flow, enumerate STRIDE threats
3. Rate each threat (likelihood × impact)
4. Mitigate, accept, transfer, or avoid

### PASTA (Process for Attack Simulation and Threat Analysis)

7-stage risk-centric methodology. Better for business risk alignment.

Stage 1: Define business objectives → Stage 2: Define technical scope → Stage 3: Application decomposition → Stage 4: Threat analysis → Stage 5: Vulnerability analysis → Stage 6: Attack enumeration → Stage 7: Risk/impact analysis

### LINDDUN

Privacy-focused threat modeling (complements STRIDE for GDPR/privacy requirements).

Threats: Linkability, Identifiability, Non-repudiation, Detectability, Disclosure, Unawareness, Non-compliance.

---

## ASVS Control Mapping

### ASVS v4.0 Chapter Summary

| Chapter | Topic | Key Controls |
|---|---|---|
| V1 | Architecture, Design, Threat Modeling | Documented security architecture, trust boundaries |
| V2 | Authentication | MFA, credential storage (Argon2), account lockout |
| V3 | Session Management | Secure/HttpOnly cookies, session invalidation |
| V4 | Access Control | Centralized enforcement, deny by default |
| V5 | Validation, Sanitization | Input validation, output encoding, injection prevention |
| V6 | Stored Cryptography | Approved algorithms, key management |
| V7 | Error Handling and Logging | No sensitive data in logs, audit trail completeness |
| V8 | Data Protection | Data classification, minimization, transit/rest encryption |
| V9 | Communication | TLS 1.2+, certificate validation, HSTS |
| V10 | Malicious Code | Code review, no backdoors, dependency integrity |
| V11 | Business Logic | Rate limiting, anti-automation, workflow integrity |
| V12 | Files and Resources | File type validation, malware scanning, safe parsing |
| V13 | API and Web Service | Authentication, schema validation, rate limiting |
| V14 | Configuration | Minimal attack surface, security headers, hardening |

### Mapping ASVS to Pipeline Controls

| ASVS Level | Pipeline Enforcement |
|---|---|
| L1 | Automated SAST + SCA in CI (basic ruleset) |
| L2 | Automated SAST + SCA + DAST + manual security review |
| L3 | All L2 + independent penetration test + formal threat model review |

### Common ASVS Mappings to OWASP Top 10

| OWASP 2021 | Primary ASVS Chapters |
|---|---|
| A01 Broken Access Control | V4 (Access Control) |
| A02 Cryptographic Failures | V6 (Cryptography), V9 (Communication) |
| A03 Injection | V5 (Validation), V7 (Error Handling) |
| A04 Insecure Design | V1 (Architecture), V11 (Business Logic) |
| A05 Security Misconfiguration | V14 (Configuration) |
| A06 Vulnerable Components | V10 (Malicious Code) |
| A07 Auth Failures | V2 (Authentication), V3 (Session) |
| A08 Integrity Failures | V8 (Data Protection), V10 (Malicious Code) |
| A09 Logging Failures | V7 (Error Handling and Logging) |
| A10 SSRF | V5 (Validation), V13 (API) |
