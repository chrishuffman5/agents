# GCP Security Reference

> Verify current pricing at https://cloud.google.com/pricing.

## 1. IAM (Identity and Access Management)

### Resource Hierarchy

```
Organization (domain-level)
  └── Folders (business units, teams, environments)
      └── Projects (billing boundary, resource container)
          └── Resources (VMs, buckets, datasets)
```

- IAM policies **inherit down** the hierarchy. Org policies apply to all folders, projects, resources.
- **Deny policies:** Explicitly deny permissions (override allows). Evaluated before allow policies.
- Cannot grant permissions at a lower level that were denied higher.

### IAM Components

- **Members:** Google accounts, service accounts, groups, Workspace domains, Cloud Identity domains.
- **Roles:** Collections of permissions. Three types:
  - **Basic:** Owner, Editor, Viewer. Overly broad -- avoid in production.
  - **Predefined:** Granular, service-specific (e.g., `roles/bigquery.dataViewer`). Preferred.
  - **Custom:** Define your own permission set (unique GCP granularity).
- **Policy binding:** Member + role, optionally scoped with IAM Conditions (time, resource attributes).

### Service Accounts

Machine identities for services and applications:
- **User-managed** (you create) and **default** (auto-created, overly permissive -- disable defaults).
- **Key-based auth (JSON key file):** Avoid. Key management burden, rotation risk, leak exposure.
- **Workload Identity Federation:** Preferred. Authenticate external workloads (AWS, Azure, GitHub Actions, OIDC/SAML) without keys.
- **Workload Identity (GKE):** Maps K8s service accounts to GCP service accounts. Pods authenticate as GCP identities.
- **Service account impersonation:** Short-lived credentials, no key management.

### Organization Policies

Constraints enforced across hierarchy:
- Restrict VM external IPs, resource locations, OS login, service account key creation.
- Custom constraints with CEL expressions.
- Override at folder/project level if policy allows.

---

## 2. VPC Service Controls

Security perimeter around GCP resources to prevent data exfiltration:
- Define perimeter: resources inside communicate freely. Outside access blocked unless allowed.
- Access levels: specific IP ranges, device posture, identity attributes.
- Audit mode (dry run): test without enforcing.
- Protects against: compromised credentials exporting data, unauthorized API access, insider threats.
- For: regulated industries (finance, healthcare) where data must stay in designated projects.

---

## 3. Secret Manager

Centralized secret storage with versioning and access control:
- Automatic replication (multi-region) or user-managed.
- IAM-based access control (per-secret granularity).
- Every access logged in Cloud Audit Logs.
- Rotation: manual or automated with Cloud Functions.
- Pricing: $0.06/10K access + $0.06/active secret version/month.
- Secret versions: immutable, enable/disable/destroy independently.

---

## 4. Security Command Center (SCC)

### Standard Tier (Free)

- Asset inventory and search.
- Security Health Analytics (misconfiguration detection).
- Web Security Scanner.

### Premium Tier

- Event Threat Detection (crypto mining, IAM anomalies, data exfiltration).
- Container Threat Detection (suspicious GKE behavior).
- VM Threat Detection (kernel-level attacks).
- Compliance monitoring (CIS, PCI DSS, OWASP, NIST 800-53).
- Attack path simulation.

### Enterprise Tier

- Full Chronicle SIEM/SOAR.
- Google/Mandiant threat intelligence.
- Multi-cloud coverage (AWS, Azure).

---

## 5. Cloud KMS (Key Management)

| Protection | Key Version $/mo | Operation $/10K |
|-----------|-----------------|-----------------|
| Software | $0.06 | $0.03 |
| Cloud HSM (FIPS 140-2 L3) | $1.00 | HSM rates |
| External (Cloud EKM) | External pricing | External rates |

- CMEK: use KMS keys with GCP services (BigQuery, GCS, Compute Engine).
- Autokey: auto-create and manage CMEK keys per resource (reduces sprawl).

---

## 6. Identity-Aware Proxy (IAP)

Context-aware access to applications without VPN:
- Verify user identity and context (device, IP, time) before access.
- Integrates with Cloud Load Balancing, App Engine, Cloud Run.
- BeyondCorp zero-trust implementation.
- **No additional charge** for IAP itself.

---

## 7. Data Protection

- **Encryption at rest:** Default (Google-managed), CMEK, CSEK (customer-supplied raw key).
- **Encryption in transit:** TLS for all APIs. BoringSSL for inter-service on Google's network.
- **Confidential Computing:** Confidential VMs (AMD SEV), Confidential GKE Nodes (memory encrypted at hardware level).
- **DLP:** Discover, classify, redact sensitive data. $1.00-3.00/GB inspection, $1.00/GB de-identification.

---

## 8. Audit and Compliance

- **Cloud Audit Logs:** Admin Activity (always on, free), Data Access (opt-in, billable), System Event, Policy Denied.
- **Access Transparency:** Logs of Google admin access to your data (Enterprise feature).
- **Compliance certifications:** SOC 1/2/3, ISO 27001/27017/27018, PCI DSS, HIPAA (BAA), FedRAMP, HITRUST.
- **Assured Workloads:** Automated compliance for regulated workloads (IL4, CJIS, ITAR).
