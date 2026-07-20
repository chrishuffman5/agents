---
name: secrets
description: "Routing agent for Secrets & Certificate Management. Delegates to specialist agents for HashiCorp Vault, Azure Key Vault, AWS Secrets Manager, CyberArk, Doppler, Infisical, 1Password, SOPS, and PKI/certificate tooling. WHEN: \"secrets management\", \"secret rotation\", \"certificate management\", \"PKI\", \"key vault\", \"HSM\", \"envelope encryption\", \"credential storage\". Do NOT use for platform-specific questions -- use the `vault`, `azure-key-vault`, `aws-secrets`, `cyberark`, `doppler`, `infisical`, `1password-secrets`, `sops`, or `pki` skill."
license: MIT
---

# Secrets & Certificate Management

This skill covers Secrets & Certificate Management. It classifies incoming requests and points to the appropriate technology-specific sibling skill, or answers directly when the question spans multiple tools or requires foundational knowledge.

## How to Approach Tasks

When you receive a request:

1. **Classify** the request:
   - **Tool-specific** — Read the matching sibling skill
   - **Cross-tool comparison** — Answer here using `references/concepts.md`
   - **Architecture/design** — Load `references/concepts.md` and answer directly
   - **Migration** — Identify source and target, load both sibling skills

2. **Load context** — For foundational questions, read `references/concepts.md`

3. **Identify the technology** — See the routing table below

4. **Read** — Load the matching sibling skill

5. **Cross-cutting concerns** — Secret sprawl, governance, compliance, and multi-cloud patterns are answered here, not in sibling skills

## Technology Routing Table

| If the request involves... | Read |
|---|---|
| HashiCorp Vault, Vault Agent, Vault Operator, HCP Vault, VSO | `vault` |
| Azure Key Vault, Azure Managed HSM, Key Vault references | `azure-key-vault` |
| AWS Secrets Manager, AWS KMS, Parameter Store context | `aws-secrets` |
| CyberArk PAM, PVWA, CPM, PSM, PTA, Conjur, Secrets Hub | `cyberark` |
| Doppler, Doppler CLI, Doppler integrations | `doppler` |
| Infisical, Infisical self-hosted, Infisical operator | `infisical` |
| 1Password, 1Password Connect, 1Password Service Accounts | `1password-secrets` |
| SOPS, age encryption, encrypted git files | `sops` |
| PKI, certificates, Let's Encrypt, cert-manager, Venafi, DigiCert, EJBCA, smallstep | `pki` |

## Secrets Management Fundamentals

Before delegating, ensure you understand the problem scope. Key concepts:

### What Is a Secret?

A secret is any credential or sensitive value that grants access to a resource:
- Passwords and API keys
- TLS/SSH private keys and certificates
- Database connection strings
- OAuth client secrets and JWT signing keys
- Encryption keys

### Secret Lifecycle

Every secret has a lifecycle that must be managed:

```
Generate → Store → Distribute → Rotate → Revoke → Audit
```

- **Generation** — Cryptographically random, adequate entropy, algorithm-appropriate length
- **Storage** — Encrypted at rest, access-controlled, audited
- **Distribution** — Encrypted in transit, least-privilege access, no plaintext in logs/env vars
- **Rotation** — Automated preferred, zero-downtime, versioned (AWSPREVIOUS/AWSCURRENT pattern)
- **Revocation** — Immediate effect, cascades to dependent systems
- **Audit** — Who accessed what secret, when, from where

### Secret Sprawl — The Core Problem

Organizations accumulate secrets in:
- Hardcoded in source code (critical risk — scan with `git-secrets`, `truffleHog`, `gitleaks`)
- Environment variables without lifecycle management
- Config files checked into version control
- Shared spreadsheets or wikis
- Multiple tools without a single source of truth

A secrets management strategy must address sprawl before optimizing tooling.

### Choosing a Secrets Manager

| Dimension | Consideration |
|---|---|
| Deployment model | SaaS vs. self-hosted vs. cloud-native |
| Compliance requirements | FedRAMP, PCI-DSS, FIPS 140-3, SOC 2 |
| Dynamic vs. static secrets | Dynamic secrets (short-lived, auto-generated) reduce exposure |
| Scale | Number of secrets, request throughput, replication needs |
| Developer experience | SDK support, CI/CD integrations, onboarding friction |
| Cost | Licensing model (per-secret, per-user, per-request, open source) |
| Existing cloud footprint | Azure → AKV, AWS → SM/KMS, multi-cloud → Vault/CyberArk |

### Dynamic vs. Static Secrets

**Static secrets** are long-lived credentials stored and retrieved:
- Lower complexity, higher risk from long exposure windows
- Require scheduled rotation

**Dynamic secrets** are generated on-demand with a TTL:
- HashiCorp Vault database engine: generates DB credentials valid for N minutes
- AWS IAM roles (STS): temporary credentials for apps
- Significantly reduces blast radius when compromised
- Prefer dynamic secrets wherever the target system supports it

### Envelope Encryption

The foundational pattern for cloud key management:

```
Plaintext Data → encrypt with Data Encryption Key (DEK)
Data Encryption Key → encrypt with Key Encryption Key (KEK / Master Key)
Encrypted DEK stored alongside encrypted data
KEK lives in HSM or cloud KMS — never leaves
```

Used by: AWS KMS, Azure Key Vault, GCP KMS, HashiCorp Transit engine. Enables key rotation without re-encrypting all data — only re-encrypt the DEK.

### HSM (Hardware Security Module)

A physical device designed to store cryptographic keys and perform operations:
- Keys never leave the HSM in plaintext
- FIPS 140-3 Level 3 certification means tamper-evident + tamper-resistant
- Cloud equivalents: AWS CloudHSM, Azure Managed HSM, GCP Cloud HSM
- Shared HSM pools: Azure Key Vault Premium, AWS KMS (AWS-managed HSM backing)
- Required for: PCI-DSS Level 1, some FedRAMP High, certain financial regulations

## Cross-Cutting Patterns

### Zero-Trust Secret Distribution

Applications should never have long-lived static credentials. Use platform identity instead:
- **Kubernetes** — Projected service account tokens + CSI driver / Vault Agent / ESO
- **AWS EC2/ECS/Lambda** — IAM instance/task/execution roles (STS temporary creds)
- **Azure** — Managed Identity (system-assigned or user-assigned)
- **GCP** — Workload Identity

### External Secrets Operator (ESO)

Kubernetes-native way to sync secrets from external stores (Vault, AWS SM, AKV, GCP SM, 1Password, Doppler, Infisical) into Kubernetes Secrets. Preferred over vendor-specific operators when using multiple backends.

### GitOps and Secrets

Secrets and GitOps are inherently in tension — git repos are not secret stores. Approaches:
- **SOPS** — Encrypt secrets files, store encrypted in git, decrypt at deploy time
- **Sealed Secrets** — Kubernetes-specific, encrypt with cluster public key
- **External Secrets Operator** — Reference secrets in git, fetch at runtime from vault
- **Vault + ArgoCD/Flux** — ArgoCD Vault Plugin or Vault sidecar injection

### Audit and Compliance

All secrets managers should provide:
- Access logs with caller identity, timestamp, secret identifier
- Immutable audit trail (write-once, tamper-evident)
- Alerts on anomalous access patterns
- Secret inventory and age reporting

## Common Anti-Patterns

| Anti-Pattern | Risk | Remedy |
|---|---|---|
| Hardcoded credentials in source | Critical — exposed in git history | Rotate immediately, use pre-commit hooks |
| Secrets in environment variables | Exposed in process list, logs | Use secrets manager with in-memory injection |
| Shared service accounts | No individual accountability | Per-application credentials with machine identity |
| No secret rotation | Long exposure window after breach | Automate rotation, enforce max age |
| No audit logging | Breach undetectable | Enable audit on all secret stores |
| Over-broad IAM policies | Blast radius too wide | Least privilege, per-app credentials |
| Self-rolled encryption | Crypto errors, key management failures | Use proven KMS/secrets manager |

## Reference Files

- `references/concepts.md` — Deep dive: rotation patterns, envelope encryption, HSMs, PKI fundamentals, X.509, ACME protocol. Load for foundational architecture questions.
