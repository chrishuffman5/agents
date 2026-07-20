# AWS Security Reference

> IAM, KMS, Secrets Manager, GuardDuty, Security Hub, AWS Config, WAF. Prices are US East (N. Virginia).

---

## IAM Architecture

### Least Privilege Methodology

1. **Start broad, refine tight:**
   - Begin with AWS managed policies during development
   - Enable CloudTrail and IAM Access Analyzer
   - After 30-90 days, use Access Analyzer policy generation based on actual API calls
   - Replace managed policy with generated least-privilege policy

2. **Policy sizing:** Max 6,144 chars (managed), 2,048 chars (inline). Prefer managed policies (reusable, versionable).

3. **Audit tools:**
   - **IAM Access Analyzer:** generates least-privilege policies, validates, finds external access
   - **IAM Policy Simulator:** test "what would happen if" without actual API calls
   - **CloudTrail Lake:** query historical API usage per principal

### IAM Identity Center (SSO)

**Always use for human access to multiple AWS accounts.** Never create IAM users for humans when Identity Center is available.

- Connect external IdP (Okta, Azure AD, Google Workspace) via SAML 2.0 or SCIM
- Define Permission Sets assigned to groups/users per account
- Temporary credentials via SSO portal -- no long-lived access keys

**Permission Set strategy:**
- `AdministratorAccess` -- break-glass only, heavily audited
- `PowerUser` -- developers in dev/staging (no IAM changes)
- `ReadOnly` -- audit, security, cost review
- Custom per-role -- scoped to specific services and actions

### Roles -- Strategic Patterns

**Service roles:** Every AWS service gets a role (EC2 instance profile, Lambda execution role, ECS task role). Never embed access keys in code.

**Cross-account access:**
- Same-org: prefer resource-based policies (simpler, no role assumption)
- Third-party: cross-account roles with external ID (prevents confused deputy)
- Use `aws:PrincipalOrgID` condition to restrict trust to your organization

**Role chaining:** Assuming Role A then Role B. Session limited to 1 hour when chaining. Avoid deep chains.

### Policy Evaluation Order

```
1. Explicit Deny in any policy -> DENY (always wins)
2. Organizations SCP -> must ALLOW
3. Resource-based policy -> may grant access (even cross-account)
4. Identity-based policy -> must ALLOW
5. Permissions boundary -> must ALLOW (intersection)
6. Session policy -> must ALLOW
7. No explicit allow -> IMPLICIT DENY
```

### Strategic IAM Conditions

| Condition | Use Case |
|-----------|----------|
| `aws:SourceIp` | Restrict to corporate IP ranges |
| `aws:PrincipalOrgID` | Trust only your org |
| `aws:RequestedRegion` | Restrict to approved regions |
| `aws:PrincipalTag` | ABAC: tag-based access control |
| `aws:MultiFactorAuthPresent` | Require MFA for sensitive ops |
| `ec2:ResourceTag` | Instance-level control by tag |
| `s3:prefix` | S3 path-level access per team |

**ABAC:** Tag principals and resources, write policies using tag conditions. Scales better than per-resource ARN policies. Add resources without changing policies -- just tag them.

### SCPs (Service Control Policies)

SCPs set maximum permissions for all identities in an OU/account. They do not grant permissions.

**Essential SCPs:**
- Deny region usage outside approved regions (except global services)
- Deny root user actions except break-glass
- Deny `organizations:LeaveOrganization`
- Deny disabling GuardDuty/CloudTrail/Config
- Deny creating IAM users/access keys (force Identity Center)
- Deny public S3 access (enforce block-public-access)

**Design pattern:** Deny-list approach (allow `*` at root, add specific denies down the OU tree). Easier to maintain than allow-lists.

---

## KMS (Key Management Service)

### Key Types and Costs

| Key Type | Monthly | API Cost | Use Case |
|----------|---------|----------|----------|
| AWS owned | Free | Free | Default encryption (S3-SSE, EBS default). No control or audit. |
| AWS managed | Free | $0.03/10K | Per-service keys (aws/s3, aws/ebs). CloudTrail audit. Cannot manage. |
| Customer managed (CMK) | $1.00 | $0.03/10K | Full control: key policy, rotation, cross-account, deletion |
| Imported key material | $1.00 | $0.03/10K | Regulatory requirement to control key material |

### Envelope Encryption Pattern

1. Call KMS `GenerateDataKey` -> plaintext data key + encrypted data key
2. Encrypt data locally with plaintext key (fast, no KMS call per record)
3. Store encrypted data + encrypted data key together
4. To decrypt: KMS `Decrypt` encrypted data key -> plaintext key -> decrypt locally

One KMS call per operation, not per byte. Keeps costs low and performance high.

### Key Policies

- Key policy is **primary** access control for KMS keys (unlike most AWS resources)
- Default key policy allows account's IAM policies to control access
- Cross-account: key policy must allow external account AND external account needs IAM policy

### Automatic Rotation

- AWS managed keys: every year automatically
- Customer managed: configurable (90 days to 7 years, default 1 year)
- Rotation creates new key material; old retained for decryption. No re-encryption needed.

---

## Secrets Manager vs Parameter Store

| Feature | Secrets Manager | Parameter Store Standard | Parameter Store Advanced |
|---------|----------------|------------------------|------------------------|
| Cost | $0.40/secret/mo + $0.05/10K calls | **Free** (up to 10,000 params) | $0.05/param/mo |
| Auto rotation | Built-in Lambda rotation (RDS, Redshift, DocumentDB) | No | No |
| Max value | 64 KB | 4 KB | 8 KB |
| Cross-account | Native sharing | No | No |
| Throughput | 10,000 req/sec | 40 TPS (std), 1,000 TPS (high) | 1,000 TPS |

**Decision rules:**
- Database credentials needing rotation: **Secrets Manager** (built-in rotation is worth it)
- API keys/tokens with manual rotation: **Parameter Store Standard** (free) if <4 KB
- Configuration values (non-secret): **Parameter Store Standard** with hierarchical paths (`/app/prod/db/host`)
- High throughput (>40 TPS): Secrets Manager or Parameter Store Advanced

**Caching is critical:** Both charge per API call. Use caching clients (`aws-secretsmanager-caching`, SDK built-in) to reduce calls.

---

## S3 Encryption Strategy

| Method | Key Management | Cost | Use Case |
|--------|---------------|------|----------|
| SSE-S3 (AES-256) | AWS manages all | Free | Default for all buckets. Sufficient for most. |
| SSE-KMS (AWS managed) | AWS managed key | $0.03/10K | When audit trail needed |
| SSE-KMS (CMK) | You control policy | $1/mo + $0.03/10K | Regulatory key control, cross-account |
| SSE-C | You provide key per request | Free (you manage) | Rare, complex operationally |
| Client-side | You encrypt before upload | Your cost | End-to-end encryption |

**Default:** SSE-S3 (enabled on all buckets since Jan 2023). Upgrade to SSE-KMS only for audit trails or key policies.

**S3 Bucket Keys with SSE-KMS:** Reduces KMS request costs up to 99%. S3 creates short-lived bucket-level key from your KMS key. Always enable with SSE-KMS.

### Encryption in Transit

| Layer | How to Enforce |
|-------|---------------|
| S3 | Bucket policy: `aws:SecureTransport` condition |
| ALB/NLB | HTTPS listener with ACM certificate (free) |
| CloudFront -> Origin | Origin protocol: HTTPS only |
| RDS | `rds.force_ssl` parameter |
| ElastiCache | In-transit encryption at cluster creation |
| Inter-service | PrivateLink / VPC endpoints |

**ACM:** Public certificates are free (ALB, CloudFront, API Gateway, NLB). Auto-renew 60 days before expiration. Cannot be exported.

---

## GuardDuty -- Threat Detection

Continuously monitors accounts using CloudTrail, VPC Flow Logs, DNS logs, and optional sources.

| Data Source | Price | Notes |
|-------------|-------|-------|
| CloudTrail management events | $4.00/M events | Always-on |
| VPC Flow Logs | $1.00/GB | Always-on |
| DNS query logs | $1.00/M queries | Always-on |
| S3 data events | $0.80/M events | Optional |
| EKS audit logs | $1.60/M events | Optional |
| Lambda network activity | $1.50/M events | Optional |
| EC2 Runtime Monitoring | $0.0015/vCPU/hr | Optional, agent-based |

**Cost management:** Start with foundational sources only. Enable optional protections selectively. Use 30-day free trial to estimate costs. Aggregate findings to central security account.

**Automation:** Route findings via EventBridge to SNS (alerts), Lambda (auto-remediation), Security Hub (dashboard).

---

## Security Hub -- CSPM

Aggregates findings from GuardDuty, Config, Inspector, Macie. Runs compliance checks.

**Standards:** AWS Foundational Security Best Practices (FSBP -- start here), CIS Benchmarks, PCI DSS, NIST 800-53.

**Cost:** $0.0010/check/account/region/month.

Enable FSBP in all accounts. Use cross-region aggregation. Integrate with Organizations for auto-enrollment.

---

## AWS Config -- Resource Compliance

Records resource configurations and evaluates against rules.

- Configuration items: $0.003/item
- Rule evaluations: $0.001/eval (first 100K)

**Cost control:** Limit recording to needed resource types. Config costs grow quickly with frequently changing resources.

**Key managed rules:** `s3-bucket-public-read-prohibited`, `restricted-ssh`, `encrypted-volumes`, `rds-instance-public-access-check`, `iam-root-access-key-check`, `multi-region-cloudtrail-enabled`, `vpc-flow-logs-enabled`, `access-keys-rotated`.

**Auto-remediation:** Config rules trigger SSM Automation: remove offending SG rules, encrypt unencrypted volumes, block public S3.

---

## WAF -- Web Application Firewall

Filters HTTP/HTTPS on ALB, CloudFront, API Gateway, AppSync, Cognito.

### Cost Structure

- Web ACL: $5.00/month
- Rules: $1.00/rule/month
- Requests: $0.60/M inspected
- Bot Control: $10/month + $1/M (common) or $25/month + $5/M (targeted)

### Rule Strategy (Priority Order)

1. **Rate-based rules (first):** Block IPs exceeding N requests/5 min. Start at 2,000. Stops volumetric attacks cheaply.
2. **IP reputation:** `AWSManagedRulesAmazonIpReputationList` -- blocks known malicious IPs. Free with WAF.
3. **Core rule set (CRS):** `AWSManagedRulesCommonRuleSet` -- OWASP Top 10. Start in COUNT mode.
4. **Known bad inputs:** `AWSManagedRulesKnownBadInputsRuleSet` -- Log4Shell, host header attacks.
5. **Application-specific:** SQL, Linux/Windows, PHP, WordPress as applicable.
6. **Bot Control (optional):** Targeted only if serious bot problem.
7. **Custom rules:** Geo-blocking, URI patterns, header filtering.

### Deployment Pattern

- Start all managed rules in **COUNT** mode
- Run 1-2 weeks; analyze logs
- Identify false positives; add targeted exceptions
- Switch to **BLOCK** rule by rule
- **Never deploy directly in BLOCK** -- you will break legitimate traffic
