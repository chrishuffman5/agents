# AWS Security Reference

> IAM policy mechanics, KMS, Secrets Manager vs Parameter Store, encryption strategy, and the cost/rule strategy for GuardDuty, Security Hub, Config, and WAF. Prices are US East (N. Virginia) and PRICE-VOLATILE; quotas and evaluation semantics are structural facts.
>
> Org-wide deployment of these services (delegated admin, SRA account layout, auto-enable) is in `references/security-platform.md`. IAM identity/credential depth belongs to the `aws-iam` skill in `security`; CLI mechanics to the `aws-cli` skill in `cli-scripting`.

---

## IAM Architecture

### Least privilege in practice

1. Start with AWS managed policies during development, with CloudTrail and IAM Access Analyzer enabled.
2. After 30-90 days of real usage, generate a least-privilege policy from observed API calls with Access Analyzer policy generation.
3. Replace the managed policy with the generated one, then validate with Access Analyzer policy validation and the IAM Policy Simulator.
4. Use Access Analyzer's **unused access** analyzer on an ongoing basis to find roles, users, keys, and permissions nobody exercises.

### Policy size limits — inline is not a single number

> Source: https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_iam-quotas.html (official)

- **Customer managed policy: 6,144 characters.**
- **Inline policy, aggregate across all inline policies on the principal:** **2,048 characters for a user**, **10,240 for a role**, **5,120 for a group**.

Quoting a flat "2,048 inline" understates role capacity fivefold and produces bad advice about splitting policies. Prefer managed policies regardless — reusable, versioned, and independently attachable.

### Identity Center over IAM users

**Always use IAM Identity Center for human access to multiple accounts.** Never create IAM users for humans. Connect an external IdP (Okta, Entra ID, Google Workspace) via SAML 2.0 and SCIM, define permission sets, and assign them to groups per account; users get temporary credentials with no long-lived access keys. The AWS Security Reference Architecture checklist goes further and lists "IAM users are not used" as a target state outright. Permission-set strategy: `AdministratorAccess` for audited break-glass only, a power-user set for developers in non-production, read-only for audit and cost review, and custom scoped sets for everything else. Org-instance placement and delegated administration are in `references/multi-account.md`.

### Role patterns

- **Service roles** for every AWS service (EC2 instance profile, Lambda execution role, ECS task role). Never embed access keys.
- **Cross-account:** same-organization access often reads more simply as a resource-based policy; third-party access needs a cross-account role with an **external ID** to prevent the confused-deputy problem. Constrain trust with `aws:PrincipalOrgID`.
- **Role chaining** (assume role A, then role B) **caps the session at one hour** — confirmed verbatim, and it applies to console switching, CLI, and API, but not to the initial assumption from user credentials or to EC2 instance-profile credentials. Avoid deep chains.

### Policy evaluation — with RCPs

> Source: https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_evaluation-logic.html and https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_rcps.html (official)

```
1. An explicit Deny in ANY policy                         -> DENY (always wins)
2. Organizations SCP  (principal-side ceiling)            -> must ALLOW
3. Organizations RCP  (resource-side ceiling)             -> must ALLOW
4. Resource-based policy                                  -> may grant, including cross-account
5. Identity-based policy                                  -> must ALLOW
6. Permissions boundary                                   -> must ALLOW (intersection)
7. Session policy                                         -> must ALLOW
8. No explicit allow anywhere                             -> IMPLICIT DENY
```

The official model is more precisely a **union** of identity-based and resource-based policies within an account, **intersected** with the permissions boundary, the SCP, and the RCP. The linear list above is a usable teaching simplification, but the **RCP row is not optional** — AWS's evaluation-logic page now describes identity-based evaluation as intersecting with "service control policies (SCPs) and resource control policy (RCP)."

**RCP in one line:** an SCP bounds what *your* principals can do; an **RCP bounds what *any* principal — including external accounts and their root users — can do to *your* resources.** RCPs are the only org-wide lever that reaches external callers. Full mechanics, service coverage, and quotas in `references/multi-account.md`.

### Strategic conditions and ABAC

| Condition key | Use |
|---|---|
| `aws:SourceIp` | Restrict to corporate ranges |
| `aws:PrincipalOrgID` | Trust only your organization |
| `aws:RequestedRegion` | Constrain to approved Regions |
| `aws:PrincipalTag` | ABAC on the caller |
| `aws:ResourceTag` / `ec2:ResourceTag` | ABAC on the target resource |
| `aws:RequestTag` / `aws:TagKeys` | **Force tags at resource creation** (see `references/tagging-governance.md`) |
| `aws:MultiFactorAuthPresent` | Require MFA for sensitive operations |

ABAC scales better than per-ARN policies: tag principals and resources, write policies against tags, and add resources without editing policies.

---

## KMS

> Source: https://aws.amazon.com/kms/pricing/ and https://docs.aws.amazon.com/kms/latest/developerguide/rotate-keys.html (official)

| Key type | Monthly | API | Use |
|---|---|---|---|
| AWS owned | Free | Free | Service defaults. No control, no audit trail. |
| AWS managed | Free | $0.03 per 10,000 requests | Per-service keys (`aws/s3`, `aws/ebs`). CloudTrail-audited, not manageable. |
| Customer managed (CMK) | **$1.00** (prorated hourly) | $0.03 per 10,000 requests | Full control: key policy, rotation, cross-account, scheduled deletion |
| Imported key material | $1.00 | $0.03 per 10,000 requests | Regulatory requirement to own the key material |

**Rotation is not free.** Per AWS's pricing page: "The first and second rotation of the key adds $1/month (prorated hourly) in cost. This price increase is capped at the second rotation, and any subsequent rotations will not be billed." A CMK with automatic rotation enabled and two or more rotations elapsed costs **about $3/month, not $1**. At thousands of keys that is a real line item — budget it explicitly rather than folding it into the $1 row.

**Rotation mechanics:** AWS managed keys rotate automatically about every 365 days and are not configurable. Customer managed keys default to a 365-day rotation period, and `RotationPeriodInDays` accepts **90 to 2,560 days** (roughly 90 days to 7 years). Rotation only creates new key material — old material is retained to decrypt existing ciphertext, and no re-encryption is required.

**Envelope encryption:** call `GenerateDataKey` for a plaintext plus encrypted data key, encrypt locally with the plaintext key, store the ciphertext alongside the encrypted data key, and call `Decrypt` on the data key when reading. One KMS call per operation, not per byte.

**Key policy is the primary access control for KMS keys** — unlike most AWS resources, IAM alone is not sufficient. Cross-account access requires both the key policy to allow the external account and that account's IAM policy to allow the call.

---

## Secrets Manager vs Parameter Store

> Source: https://aws.amazon.com/secrets-manager/pricing/, https://aws.amazon.com/systems-manager/pricing/, https://docs.aws.amazon.com/general/latest/gr/ssm.html (official)

| Feature | Secrets Manager | Parameter Store Standard | Parameter Store Advanced |
|---|---|---|---|
| Cost | **$0.40 per secret per month + $0.05 per 10,000 API calls** | **Free**, up to **10,000 parameters** | **$0.05 per parameter per month**, up to 100,000 |
| Automatic rotation | Built-in Lambda rotation (RDS, Redshift, DocumentDB) | No | No |
| Max value | 64 KB | **4 KB** | **8 KB** |
| Cross-account sharing | Native | No | Yes |
| Throughput | High | 40 TPS default across `GetParameter`/`GetParameters`/`GetParametersByPath`; up to 10,000/1,000/100 TPS respectively with higher throughput enabled | Same higher-throughput ceilings |

**Decision rules:** credentials that must rotate -> Secrets Manager. Non-rotating API keys and tokens under 4 KB -> Parameter Store Standard (free). Non-secret configuration -> Parameter Store Standard with hierarchical paths. Needs cross-account sharing or values over 4 KB -> Secrets Manager or Parameter Store Advanced.

**Cache in the application.** Both bill per API call; use the caching clients (`aws-secretsmanager-caching`, the Parameters and Secrets Lambda extension) rather than reading on every request. Deployment-safety features for configuration values live in AppConfig — see `references/operations.md`.

---

## S3 Encryption Strategy

> Source: https://docs.aws.amazon.com/AmazonS3/latest/userguide/default-bucket-encryption.html (official)

| Method | Key management | Cost | Use |
|---|---|---|---|
| SSE-S3 (AES-256) | AWS | Free | The floor on every bucket. Sufficient for most data. |
| SSE-KMS (AWS managed key) | AWS managed | $0.03 per 10,000 requests | When you need a per-request audit trail |
| SSE-KMS (CMK) | Your key policy | $1+/month plus requests | Regulatory key control, independently revocable access, cross-account |
| SSE-C | You supply the key per request | You manage | Rare; operationally heavy |
| Client-side | You encrypt before upload | Yours | End-to-end encryption requirements |

**"Starting January 5, 2023, all new object uploads to Amazon S3 are automatically encrypted at no additional cost"** with SSE-S3. The question is no longer "is it encrypted at rest" — it is whether you need a second, independently revocable control (SSE-KMS with a CMK requires both an S3 read permission and a KMS decrypt permission). **Always enable S3 Bucket Keys with SSE-KMS** — it cuts KMS request costs dramatically by deriving short-lived bucket-level keys.

### Encryption in transit

| Layer | Enforcement |
|---|---|
| S3 | Bucket policy with the `aws:SecureTransport` condition |
| ALB/NLB | HTTPS listener with an ACM certificate (public certs are free) |
| CloudFront to origin | Origin protocol policy: HTTPS only |
| RDS | `rds.force_ssl` parameter plus CA validation |
| ElastiCache | In-transit encryption, set at cluster creation |
| Service to service | PrivateLink / VPC endpoints |

---

## GuardDuty

> Source: https://aws.amazon.com/guardduty/pricing/ (official)

GuardDuty's foundational sources — CloudTrail management events, VPC Flow Logs, and Route 53 Resolver DNS query logs — are consumed automatically as independent streams the moment it is enabled; you do not configure them.

| Source / plan | Current billing metric |
|---|---|
| CloudTrail management events | **$4.00 per million events** |
| VPC Flow Logs | **Tiered per GB: $1.00/GB first 500 GB, $0.50/GB next 2,000 GB, $0.25/GB beyond** |
| **DNS query logs** | **Now billed per GB on the same tiers as flow logs — no longer per million queries** |
| S3 data events (S3 Protection) | $0.80 per million events (first 500M tier) |
| EKS audit logs (EKS Protection) | $1.60 per million events (first 100M tier) |
| **Lambda Protection** | **A share of the same tiered per-GB flow-log pricing — not a per-million-events rate** |
| **EC2 Runtime Monitoring** | **Tiered per vCPU per MONTH: $1.50/vCPU-month first 500 vCPUs, $0.75 beyond — not an hourly rate** |
| **Malware Protection** | EBS scanning $0.03/GB; S3 scanning ~$0.09/GB plus $0.215 per 1,000 objects; AWS Backup scanning $0.05/GB |
| **RDS Protection** | $1.00 per vCPU-month (provisioned instances); $0.25 per ACU-month (Aurora Serverless v2) |

Three of these are **metric changes, not price drift** — DNS logs, Lambda Protection, and EC2 Runtime Monitoring are billed on a different unit than older material states, so a cost estimate built on the old metrics will be wrong by more than a rounding error.

**Cost management:** start with foundational sources, add protection plans per workload, and use the 30-day free trial to size the bill. Route findings through EventBridge to SNS for alerting, Lambda for auto-remediation, and Security Hub for correlation.

---

## Security Hub

> Source: https://aws.amazon.com/security-hub/pricing/ (official)

**The per-check pricing model is gone.** Security Hub is now priced through a consolidated, resource-based **Essentials plan at $3.75 per resource unit per month**, pay-as-you-go, where a resource unit counts per asset class — for example 1 EC2 instance or Azure VM = 1 unit, 12 Lambda functions = 1 unit, 18 container images = 1 unit, 125 IAM users or roles = 1 unit. The Essentials plan **consolidates Security Hub, Amazon Inspector, and CSPM into a single per-resource price**. A 30-day unlimited free trial is available, and an **Extended plan** adds per-solution pricing across endpoint, identity, email, network, and data categories via third-party integrations.

Any cost model quoting "$0.0010 per check per account per Region" is describing a pricing scheme AWS no longer uses as its primary mechanism — rebuild the estimate on resource units.

Standards guidance is unchanged: enable **AWS Foundational Security Best Practices** everywhere as the baseline, add **CIS AWS Foundations Benchmark**, and add NIST/PCI DSS as compliance scope requires. Aggregate findings to one home Region. Org-wide enablement (central configuration, delegated administration, auto-enable) is in `references/security-platform.md`.

---

## AWS Config

> Source: https://aws.amazon.com/config/pricing/ (official)

- **Continuous recording configuration items: $0.003 per item.**
- **Periodic recording configuration items: $0.012 per item** — a distinct, pricier recording mode worth choosing deliberately.
- **Rule evaluations: $0.001 per evaluation** for the first 100,000.
- **Conformance pack evaluations are billed separately** at the same $0.001 per evaluation for the first 100,000.

**Conformance packs are the high-leverage deployment unit** — a YAML bundle of managed rules, custom rules, and remediation actions deployed as one entity to an account, a Region, or an entire organization. Prefer them over hand-assembled per-account rule sets.

Useful managed rules: `s3-bucket-public-read-prohibited`, `restricted-ssh`, `encrypted-volumes`, `rds-instance-public-access-check`, `iam-root-access-key-check`, `multi-region-cloudtrail-enabled`, `vpc-flow-logs-enabled`, `access-keys-rotated`, `required-tags`. Config rules trigger SSM Automation for remediation.

**Cost control:** limit recording to the resource types you actually govern. Config cost scales with change frequency, so chatty resource types dominate the bill.

---

## AWS WAF

> Source: https://aws.amazon.com/waf/pricing/ (official)

- Web ACL: **$5.00/month**
- Rules: **$1.00 per rule per month**
- Requests: **$0.60 per million inspected**
- **Common Bot Control: $10.00/month per web ACL + $1.00 per million requests, first 10 million requests per month free**
- **Targeted Bot Control: $10.00/month per web ACL + $10.00 per million requests, first 1 million requests per month free**

Both bot-control tiers share the same $10/month base fee; the difference is entirely in the marginal request rate and the free allowance. Material quoting "$25/month + $5/M" for Targeted is wrong on both numbers.

### Rule priority order

1. **Rate-based rules first.** Block IPs exceeding N requests per 5 minutes (2,000 is a reasonable start). This stops volumetric attacks before the expensive rules run.
2. **IP reputation** — `AWSManagedRulesAmazonIpReputationList`.
3. **Core rule set** — `AWSManagedRulesCommonRuleSet` (OWASP Top 10), initially in COUNT mode.
4. **Known bad inputs** — `AWSManagedRulesKnownBadInputsRuleSet`.
5. **Application-specific** — SQL, Linux/Windows, PHP, WordPress as applicable.
6. **Bot Control** — Targeted only when there is a demonstrated bot problem, given the 10x marginal rate.
7. **Custom rules** — geo-blocking, URI patterns, header filtering.

### Deployment pattern

Deploy every managed rule group in **COUNT** mode first, run 1-2 weeks, analyze logs, add targeted exceptions for false positives, then switch to **BLOCK** one rule group at a time. **Never deploy straight to BLOCK** — you will break legitimate traffic.

## Sources

- https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_iam-quotas.html
- https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use.html
- https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_evaluation-logic.html
- https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_rcps.html
- https://aws.amazon.com/kms/pricing/
- https://docs.aws.amazon.com/kms/latest/developerguide/rotate-keys.html
- https://docs.aws.amazon.com/kms/latest/APIReference/API_EnableKeyRotation.html
- https://aws.amazon.com/secrets-manager/pricing/
- https://aws.amazon.com/systems-manager/pricing/
- https://docs.aws.amazon.com/general/latest/gr/ssm.html
- https://docs.aws.amazon.com/AmazonS3/latest/userguide/default-bucket-encryption.html
- https://aws.amazon.com/guardduty/pricing/
- https://aws.amazon.com/security-hub/pricing/
- https://aws.amazon.com/config/pricing/
- https://aws.amazon.com/waf/pricing/

Fetched: 2026-08-08
