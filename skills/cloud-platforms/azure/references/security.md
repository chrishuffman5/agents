# Azure Security Reference

> Prices are US East, pay-as-you-go unless noted. Verify at https://azure.microsoft.com/pricing/.

## 1. Microsoft Entra ID (Formerly Azure AD)

### License Tiers

| Feature | Free | P1 ($6/user/mo) | P2 ($9/user/mo) |
|---------|------|-----------------|-----------------|
| Basic SSO, MFA (security defaults) | Yes | Yes | Yes |
| **Conditional Access** | No | Yes | Yes |
| App Proxy (publish on-prem apps) | No | Yes | Yes |
| Dynamic Groups | No | Yes | Yes |
| **Privileged Identity Management (PIM)** | No | No | Yes |
| **Identity Protection** (risk-based) | No | No | Yes |
| Access Reviews | No | No | Yes |

**P1 is essential for production** -- Conditional Access alone justifies it. Enables "require MFA from untrusted networks," "block legacy auth," "require compliant devices."

**P2 for governance-heavy organizations** -- PIM (just-in-time admin), Identity Protection, Access Reviews for compliance.

**Tip:** P1 included in Microsoft 365 E3, P2 in E5. No standalone license needed if users already have these.

### Managed Identities

**Always prefer managed identities over service principals with client secrets.**

| Aspect | Managed Identity | Service Principal + Secret |
|--------|-----------------|---------------------------|
| Credential management | None (Azure handles rotation) | Manual rotation, leakage risk |
| Security risk | Minimal (no extractable credential) | Secret leakage, forgotten rotation |
| Works with | Azure resources only | Any environment |

- **System-assigned:** Tied to resource lifecycle. Use for 1:1 identity (VM accessing Key Vault).
- **User-assigned:** Independent lifecycle. Use for shared identity (fleet of VMs accessing same storage).
- **Code:** `DefaultAzureCredential` auto-discovers identity at runtime.
- **External systems:** Use Workload Identity Federation (OIDC) for GitHub Actions, on-prem.

### Conditional Access Baseline Policies

Every production tenant should have:

1. **Require MFA for all users** -- non-negotiable.
2. **Block legacy authentication** -- POP3, IMAP, SMTP basic auth bypass MFA.
3. **Require MFA for admin roles** -- Global Admin, Exchange Admin, etc.
4. **Require compliant or hybrid-joined device** -- for sensitive applications.
5. **Block high-risk locations** -- use named locations for trusted networks.
6. **Session controls** -- enforce sign-in frequency based on risk.

### Entra ID B2C

Customer-facing identity (not employee):
- Separate tenant with customizable flows. Social providers + local accounts.
- First 50K MAU free for MFA. $0.00325/auth beyond.

---

## 2. Azure Key Vault

### SKU Comparison

| Feature | Standard | Premium |
|---------|----------|---------|
| Software-protected keys | Yes | Yes |
| HSM-protected keys (FIPS 140-2 L2) | No | Yes |
| Managed HSM | No | Separate ($3.20/hr per unit) |

### Pricing

- Secret operations: $0.03/10K transactions.
- RSA 2048 key operations: $0.03/10K (Standard) or $1/10K (Premium HSM).
- Typical app with 1M secret reads/month: ~$3.

### Best Practices

1. **Access with managed identity.** Assign Key Vault Secrets User or Crypto User roles via RBAC. No credentials.
2. **RBAC over access policies.** Finer-grained control, integrates with PIM.
3. **Soft-delete + purge protection.** Enabled by default. Retains 7-90 days. Essential for DR.
4. **Secret rotation.** Integrate Event Grid + Functions for automatic rotation.
5. **Certificate management.** Auto-renew from DigiCert/GlobalSign. Let's Encrypt via community solutions.
6. **Network restriction.** Private Endpoint + firewall rules in production. Deny public access.
7. **Separate vaults per environment.** Production secrets must never share a vault with dev/test.

### Key Vault References in App Service / Functions

```
@Microsoft.KeyVault(SecretUri=https://myvault.vault.azure.net/secrets/MySecret/)
@Microsoft.KeyVault(VaultName=myvault;SecretName=MySecret)
```

Pulls secret at runtime via managed identity. No secrets in App Settings, ARM templates, or CI/CD.

---

## 3. Microsoft Defender for Cloud

### Workload Protection Plans

| Plan | Cost (approx) | What It Protects |
|------|---------------|-----------------|
| **Free tier** | $0 | Security recommendations, Secure Score, asset inventory |
| **Defender for Servers P1** | $5/server/mo | MDE integration, FIM |
| **Defender for Servers P2** | $15/server/mo | P1 + vulnerability assessment, JIT access, 500 MB/day logs |
| **Defender for Containers** | $7/vCore/mo | AKS/EKS/GKE runtime, image scanning, admission control |
| **Defender for Storage** | $10/storage acct/mo | Malware scanning, anomaly detection |
| **Defender for SQL** | $15/instance/mo | SQL injection, vulnerability assessment |
| **Defender for Key Vault** | $0.02/10K transactions | Unusual access patterns |
| **Defender CSPM** | $5/server/mo | Attack path analysis, cloud security graph |

**Always enable free tier.** Servers P1 ($5/mo) is cost-effective for MDE integration. Enable selectively by risk profile: Servers and SQL first, then containers, then storage.

Defender for Storage with malware scanning can be expensive for high-volume blob -- enable only on accounts receiving external uploads.

### Just-In-Time (JIT) VM Access (P2)

- Locks SSH (22) and RDP (3389) via NSG rules.
- Users request temporary access (1-24 hours) to their IP.
- **Alternative:** Azure Bastion for browser-based access without public IPs.

### Azure Bastion

| SKU | Cost/mo | Features |
|-----|---------|----------|
| Developer | ~$5/day (per use) | Single connection, portal only |
| Basic | ~$140 | 25 sessions, portal SSH/RDP |
| Standard | ~$215 | Native client, shareable links, 50 sessions |
| Premium | ~$430 | Session recording, private-only |

Developer for small dev/test. Basic for most production. Standard for native client needs.

---

## 4. Azure Policy and Governance

### Policy Effects

| Effect | Behavior | Use Case |
|--------|----------|----------|
| Audit | Log non-compliance | Discovery phase |
| Deny | Block creation/modification | Enforce standards |
| DeployIfNotExists | Auto-remediate | Ensure diagnostics, NSGs exist |
| Modify | Change tags/properties at deploy | Tag enforcement |

### Essential Policies

1. Require tag and value on resource groups (cost allocation).
2. Allowed locations (data sovereignty).
3. Allowed VM size SKUs (prevent expensive N/M-series).
4. Storage accounts disable public access.
5. SQL servers use private endpoints.
6. Key Vault purge protection enabled.
7. AKS no container privilege escalation.

### Policy Initiatives

- **Azure Security Benchmark (ASB):** ~200 policies. Assign to all subscriptions as baseline.
- **CIS Azure Foundations, NIST 800-53, PCI-DSS, HIPAA:** Regulatory frameworks.
- Policy evaluation is free. Remediation may create billable resources.

### Management Groups

```
Root Management Group
├── Platform (Identity, Management, Connectivity)
├── Landing Zones
│   ├── Production (Prod-App1, Prod-App2)
│   └── Non-Production (Dev, Staging)
├── Sandbox (Experimentation)
└── Decommissioned
```

Policies and RBAC cascade to child subscriptions. Use Azure Landing Zones (ALZ) Terraform/Bicep modules for greenfield.

---

## 5. RBAC

### Critical Built-In Roles

| Role | What It Grants |
|------|---------------|
| Owner | Full control + RBAC assignment. Minimize. |
| Contributor | Full control, no RBAC delegation. |
| Reader | Read-only (not secrets/keys). |
| User Access Administrator | RBAC management only. |

**Prefer resource-specific roles:** `Storage Blob Data Reader`, `Key Vault Secrets User`, `AcrPull`, `SQL DB Contributor`.

### RBAC Best Practices

1. **Assign to groups, not individuals.** Reduces sprawl.
2. **Use PIM (P2) for privileged roles.** Just-in-time for Owner, Global Admin.
3. **Scope narrowly.** Resource group scope, not subscription-wide Contributor.
4. **Audit regularly.** Access Reviews (P2) or periodic manual review.

---

## 6. Network Security Hardening

### Zero Trust on Azure

1. **Identity:** Entra ID -- every request authenticated/authorized.
2. **Micro-segmentation:** NSGs + ASGs -- default-deny between subnets.
3. **Private connectivity:** Private Endpoints for all PaaS.
4. **Encryption:** TLS 1.2+ everywhere.
5. **Inspection:** Azure Firewall Premium for TLS inspection, IDPS.
6. **Monitoring:** Defender for Cloud + Sentinel for threat detection.

### Microsoft Sentinel (SIEM/SOAR)

- Pay-as-you-go: ~$2.46/GB/day. 100 GB/day commitment: ~$1.96/GB (20% savings).
- **Free sources:** Azure Activity Logs, Office 365 audit logs, Defender alerts.
- **Cost optimization:** Filter noise before ingestion. Basic Logs ($0.60/GB) for verbose logs. Archive after 90 days.
- Adopt when you have a dedicated security operations team. Defender alerts + Log Analytics may suffice for smaller teams.
