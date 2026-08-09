# AWS Platform Security Posture Reference

> Well-Architected security pillar, the AWS Security Reference Architecture account structure, org-wide deployment of the detection services, account-level data-protection defaults, and detection-service selection.
>
> This is the **org/platform layer**. Service-level cost and rule strategy for GuardDuty, Security Hub, Config, KMS, and WAF is in `references/security.md`. IAM identity, credential, and policy depth belongs to the `aws-iam` skill in `security`; per-service tuning to `aws-security-hub`, `aws-secrets`, and `aws-waf` in the same plugin.

---

## Well-Architected Security Pillar — the seven design principles

> Source: https://docs.aws.amazon.com/wellarchitected/latest/framework/sec-design.html (official)

These are architectural framing, not commands. Cite them to justify the concrete practices below, in AWS's own words.

1. **Implement a strong identity foundation** — "Implement the principle of least privilege and enforce separation of duties with appropriate authorization for each interaction with your AWS resources. Centralize identity management, and aim to eliminate reliance on long-term static credentials."
2. **Maintain traceability** — "Monitor, alert, and audit actions and changes to your environment in real time. Integrate log and metric collection with systems to automatically investigate and take action." *This is the justification for org-wide CloudTrail, Config, and Security Hub.*
3. **Apply security at all layers** — "Apply a defense in depth approach with multiple security controls... edge of network, VPC, load balancing, every instance and compute service, operating system, application, and code."
4. **Automate security best practices** — "Create secure architectures, including the implementation of controls that are defined and managed as code in version-controlled templates."
5. **Protect data in transit and at rest** — "Classify your data into sensitivity levels and use mechanisms, such as encryption, tokenization, and access control where appropriate." *This is the justification for the account defaults below.*
6. **Keep people away from data** — "Use mechanisms and tools to reduce or eliminate the need for direct access or manual processing of data."
7. **Prepare for security events** — "Run incident response simulations and use tools with automation to increase your speed for detection, investigation, and recovery."

The framework's account-boundary guidance, verbatim: **"In AWS, segregating different workloads by account, based on their function and compliance or data sensitivity requirements, is a recommended approach."** That principle plus the SRA below is the whole argument for the multi-account structure in `references/multi-account.md`.

Detection framing (SEC 4): "You can use detective controls to identify a potential security threat or incident... In AWS, you can implement detective controls by processing logs, events, and monitoring that allows for auditing, automated analysis, and alarming."

---

## AWS Security Reference Architecture (SRA)

> Source: https://docs.aws.amazon.com/prescriptive-guidance/latest/security-reference-architecture/account-structure.html, .../security-tooling.html, .../log-archive.html, .../checklist.html (official)

The SRA is **AWS Prescriptive Guidance** — an opinionated reference design for account layout and for which account administers which security service, plus a machine-checkable checklist and the open-source **SRA Verify** assessment tool designed to run from CodeBuild in the Security Tooling account.

### The account and OU structure

```
Org Management account
  Security OU        -- Security Tooling account, Log Archive account
  Infrastructure OU  -- Network account, Shared Services account
  Workloads OU       -- Application accounts (in practice many OUs and accounts,
                        segregated by application, environment, and sensitivity)
```

The checklist states it as **"three foundational OUs... (Security, Infrastructure, and Workload) to group member accounts that provide foundation services."**

**Regional replication caveat:** most AWS services are Region-scoped with independent control and data planes, so **"you must replicate this architecture across all AWS Regions that you plan to use."** For Regions with no planned workloads, **disable the Region via SCP** rather than leaving it as an unmonitored blind spot. Security Hub CSPM cross-Region aggregation keeps a single-pane view despite the per-Region replication.

At scale, use **Control Tower** as the orchestration layer instead of replicating this by hand; the SRA's own code samples deploy through Customizations for AWS Control Tower.

### Security Tooling account

"The Security Tooling account is dedicated to operating security services, monitoring AWS accounts, and automating security alerting and response." Three objectives: a dedicated account with controlled access for guardrails, monitoring, and response; centralized security infrastructure supporting traceability; and defense in depth via a control layer separate from workload accounts.

**This is the delegated-administrator account for nearly every org-wide security service:** IAM centralized root-access management, AWS Config, Firewall Manager, GuardDuty, IAM Access Analyzer, Macie, Security Hub / Security Hub CSPM, Detective, Audit Manager, Inspector, CloudTrail, Systems Manager, CloudWatch, and AWS Security Incident Response. Whenever a per-service checklist says "delegated administrator," this is the account it means.

### Log Archive account

"The Log Archive account is dedicated to ingesting and archiving all security-related logs and backups." Security objective, verbatim: **"This should be immutable storage, accessed only by controlled, automated, and monitored mechanisms, and built for durability."**

Primary contents: the CloudTrail organization trail, VPC Flow Logs, CloudFront and WAF access logs, Route 53 DNS logs, plus operational log data where it overlaps audit and compliance needs.

### Why these are two accounts, not one

This is the load-bearing design decision in the whole SRA, and AWS states it twice for the two services that matter most:

- **CloudTrail:** "the Security Tooling account is the delegated administrator account for managing CloudTrail. The corresponding S3 bucket to store the organization trail logs is created in the Log Archive account. **This is to separate the management and usage of CloudTrail log privileges.**"
- **AWS Config:** "the AWS Config delegated administrator account is the Security Tooling account. The AWS Config delivery channel is configured to deliver resource configuration snapshots in a centralized S3 bucket in the Log Archive account."

**The general principle: whoever can configure a logging service must not be the account that holds the resulting logs.** A compromised or misused Security Tooling account — which necessarily has broad service-admin permissions — still cannot tamper with logs sitting under separate control. The same split repeats for GuardDuty finding exports, Macie exports, WAF logs, and Security Lake. It is structural, not a CloudTrail-specific quirk.

### Protecting the log store itself

Because CloudTrail, VPC Flow Logs, ELB, GuardDuty, Config, and WAF all write to S3: "log integrity is achieved through S3 object integrity; log confidentiality is achieved through S3 object access controls; and log availability is achieved through S3 Object Lock, S3 object versions, and S3 Lifecycle rules." Layer **SSE-KMS with a customer-managed key** over the SSE-S3 baseline so reading requires both an S3 permission and a KMS decrypt permission — two independently revocable controls. Enable **CloudTrail log file integrity validation** and **S3 Object Lock**, and apply a bucket resource policy restricting uploads to the organization trail's ARN (the confused-deputy defence against a rogue account writing forged log objects). The `AWSCloudTrail_FullAccess` managed policy is called out by name as dangerous to over-assign — "limit the application of this IAM policy to as few individuals as possible."

Current guidance names **Amazon CloudWatch Unified Data Experience**, deployed in a dedicated **Monitoring account** in the Security OU, as the primary recommendation for org-wide log collection and analytics (pulling AWS-vended logs org-wide, normalizing to OCSF, archiving long-term to S3 Tables/Iceberg in Log Archive). **Amazon Security Lake**, administered from the Log Archive account, remains a supported option for organizations already invested in it. Both preserve the same discipline: "the Log Archive account serves as a storage sink only and does not run CloudWatch analytics workloads."

### Two org-wide checklist items worth surfacing

- **Organizations:** all features enabled; SCPs for principal guardrails; **RCPs for resource-side guardrails**; declarative policies for org-wide service configuration; alternate contacts (billing, operations, security) configured on every member account.
- **IAM:** **"IAM users are not used"** — a stronger stance than the general IAM best-practices guidance. Root access for member accounts is centrally managed from the Security Tooling account, with member-account root credentials removed entirely.

---

## Org-Wide Detection Services

### AWS CloudTrail organization trails

> Source: https://docs.aws.amazon.com/awscloudtrail/latest/userguide/creating-trail-organization.html (official)

"If you have created an organization in AWS Organizations, you can create a trail that logs all events for all AWS accounts in that organization." Only the **management account or a designated CloudTrail delegated administrator** can create or manage one. A copy of the trail appears in every member account with an identical ARN keyed to the management account.

**The governance fact that makes it trustworthy, verbatim:** "Users in member accounts do not have sufficient permissions to delete organization trails, turn logging on or off, change what types of events are logged, or otherwise change an organization trail in any way." Member users can see the trail; only the management account or delegated administrator can change it.

Mechanics: CloudTrail creates the `AWSServiceRoleForCloudTrail` service-linked role, added automatically when an account joins (logging starts immediately) and removed when it leaves (logs already written remain in the bucket, under a folder keyed by that account ID). The bucket layout is an organization-ID folder with per-account subfolders.

**Lifecycle edge case:** if the management account that created an organization trail is later demoted, **the trail silently becomes an ordinary non-organization trail** — administration does not transfer to the new management account.

**Management versus data events:** by default trails log management events but not data events. Data-event logging is opt-in per resource and carries volume-driven cost. For an organization trail configured in the console, only management-account resources are listed, but you can add member-account resource ARNs directly with no cross-account resource-policy setup.

**SRA target state:** organization trail delivering management events across the management account and every member account, **multi-Region** with global-resource events, additional trails for data events on sensitive resources only, **Security Tooling as delegated administrator**, auto-enabled for new accounts, logs to a central bucket in **Log Archive**, **log file validation enabled**, integrated with CloudWatch Logs, **encrypted with a customer-managed KMS key**, and the bucket carrying **Object Lock and versioning** plus a resource policy restricting uploads to the trail ARN.

### Amazon GuardDuty

> Source: https://docs.aws.amazon.com/guardduty/latest/ug/guardduty_organizations.html, .../add-member-accounts-guardduty-organization.html, .../guardduty_data-sources.html (official)

**Delegated administration:** the management account designates a member account as delegated GuardDuty administrator; that account can then enable and manage GuardDuty for all member accounts **in that Region**. A delegated administrator can manage up to **50,000 members**.

Three mechanics that catch people out:

- **GuardDuty is Regional and Organizations is not.** The delegated-administrator designation and member enrollment must be re-established **in every Region** you want covered. **The same account must be the administrator in every Region.**
- **Explicit anti-pattern, verbatim:** "Your organization's management account can be the delegated GuardDuty administrator account. However, the AWS security best practices follow the principle of least privilege and doesn't recommend this configuration." Use the Security Tooling account.
- **Removing or changing the delegated administrator does not disable GuardDuty** for member accounts — they stay enabled but lose the centralized view.

**Auto-enable** is the mechanism that keeps coverage complete as accounts are vended: "The auto-enable feature enables GuardDuty for all future members of your organization." Choosing "Enable" in the console when no accounts are yet members also flips the standing auto-enable switch. It has a circuit breaker at the 50,000-member limit and turns itself back on when membership falls below it. The **management account is the one exception** to automatic enablement — GuardDuty must be enabled on it before it can be added as a member.

**Foundational data sources are automatic and free of separate configuration:** CloudTrail management events, VPC Flow Logs, and Route 53 Resolver DNS query logs. "You don't need to enable anything else for GuardDuty to start analyzing and processing these data sources." GuardDuty reads them as **independent duplicated streams** — your own trail or flow-log configuration is irrelevant to what GuardDuty sees, and enabling GuardDuty does not create flow logs in your account.

Two consequences worth stating explicitly:

- **Global service events (IAM, STS, S3, CloudFront, Route 53) are replicated into every Region where GuardDuty is enabled**, which is why AWS recommends enabling GuardDuty **in all Regions, including ones with no deployed resources** — otherwise global-service attacks go undetected in unmonitored Regions.
- **DNS visibility depends on the default AWS resolvers.** Instances using OpenDNS, Google DNS, or a self-hosted resolver blind that data source entirely.

Optional protection plans, each individually enabled and billed: EKS audit logs, RDS login activity, S3 data events, EBS volume scanning (Malware Protection), Runtime Monitoring (EKS/EC2/ECS-Fargate), Lambda network activity, and CloudTrail data events for Bedrock, Bedrock AgentCore, and SageMaker AI. Pricing metrics are in `references/security.md`.

### AWS Security Hub CSPM

> Source: https://docs.aws.amazon.com/securityhub/latest/userguide/central-configuration-intro.html, .../securityhub-accounts-orgs.html, .../standards-reference.html (official)

Recent documentation calls the finding-aggregation and standards service **"Security Hub CSPM"**, distinguishing it from the newer exposure-correlation layer built on top. One delegated administrator can manage up to **10,000 member accounts**.

**Use central configuration.** "AWS strongly recommends using it because it lets the administrator customize security coverage for the organization." From the delegated-administrator account in one **home Region**, you configure Security Hub CSPM, standards, and controls for accounts and OUs across all **linked Regions**.

- **Targets** are an account, an OU, or the organization root; configuration policies attach to targets and inherit down the OU tree unless overridden.
- **Centrally managed vs self-managed:** a centrally managed target can only be configured by the delegated administrator; a self-managed target configures itself per-Region. An organization can mix both.
- **A configuration policy** bundles: whether Security Hub CSPM is on, which standards are enabled, which controls within them (allow-list or deny-list, including controls released later), and custom parameters. Maximum **20 custom configuration policies** per delegated administrator.
- **The recommended configuration policy** enables Security Hub CSPM, the FSBP standard, and all current and future FSBP controls at defaults — a sane org-wide baseline; create custom policies to diverge (different standards for prod versus test OUs).
- **It prevents drift:** "Configuration drift occurs when a user makes a change to a service or feature that conflicts with the delegated administrator's selections. Central configuration prevents this drift."

**Local configuration** — the default before opting in — is materially weaker: auto-enable for *new* accounts in the *current Region only*, no reach into existing accounts or other Regions, and no configuration policies. Multicloud standards (for example the CIS Azure Foundations Benchmark) are **excluded from configuration policies** and must be enabled locally even in a centrally configured organization.

The **home Region doubles as the aggregation Region**, receiving findings and insights from every linked Region — this is the single-pane-of-glass mechanism.

**Standards to choose from:** AWS Foundational Security Best Practices (AWS-authored, multi-service, the recommended baseline for everyone, with per-control remediation guidance), AI Security Best Practices, AWS Resource Tagging, CIS AWS Foundations Benchmark (currently supporting versions 5.0.0, 3.0.0, 1.4.0, and 1.2.0), NIST SP 800-53 Rev 5, NIST SP 800-171 Rev 2, PCI DSS, and a service-managed standard for AWS Control Tower. AWS's own caveat: "Security Hub CSPM standards and controls don't guarantee compliance with any regulatory frameworks or audits."

**SRA target state:** enabled for all member accounts and the management account; **AWS Config enabled everywhere as a prerequisite**; **Security Tooling as delegated administrator**; **GuardDuty and Detective sharing that same delegated administrator "for smooth service integration"**; central configuration with all OUs and accounts centrally managed; auto-enable for new accounts and newly released standards; findings aggregated to one home Region in the Security Tooling account; **FSBP and CIS AWS Foundations Benchmark enabled for all member accounts**.

### AWS Config

> Source: https://docs.aws.amazon.com/config/latest/developerguide/conformance-packs.html (official)

A **conformance pack** is "a collection of AWS Config rules and remediation actions that can be easily deployed as a single entity in an account and a Region **or across an organization in AWS Organizations**." **Organization conformance packs** deploy the same checks uniformly to every member account — the alternative to hand-rolling per-account rule sets. Regional support for org-wide deployment is broad but not universal; check before depending on it in a newly launched Region.

Pair conformance packs (uniform enforcement) with an **organization aggregator** (uniform read-only visibility). See `references/tagging-governance.md` for the aggregator's read-only boundary.

**SRA target state:** Config recorder enabled for all member accounts and the management account **in all Regions**; the delivery-channel S3 bucket centralized in **Log Archive**; **Security Tooling as delegated administrator**; an **organization aggregator including all Regions**; conformance packs deployed uniformly from the delegated-administrator account; findings routed automatically to Security Hub CSPM.

**Config is not optional infrastructure alongside Security Hub — it is the engine Security Hub's standards run on.** The CIS and FSBP standards are implemented as managed Config rules, which is why Security Hub's checklist lists Config as a prerequisite.

### IAM Access Analyzer

> Source: https://docs.aws.amazon.com/IAM/latest/UserGuide/access-analyzer-settings.html (official)

Two analyzer types, both able to take the **organization as their zone of trust**: **external access analyzers** (flag resources shared outside the zone of trust) and **unused access analyzers** (flag unused roles, users, keys, passwords, and permissions inside it — a paid capability billed per IAM role or user analyzed).

"Only the management account can add a delegated administrator." Once added, that member account can create and manage analyzers whose zone of trust is the organization.

**Changing the delegated administrator has real consequences.** The former administrator loses permission to every org-zone analyzer it created; those analyzers go to a **disabled** state and their findings become inaccessible until that account is reinstated. If the switch is permanent, **delete the analyzers first** — the new administrator must actively create new ones (there is no hand-off), and an equivalent finding set simply regenerates. The same disabling happens unplanned if the delegated-administrator account leaves the organization.

**Regional scoping differs by type:** external and internal access analyzers must be created **independently in each Region**, because they analyze resource policies only in their own Region. **Unused-access findings do not vary by Region**, so one analyzer suffices for that type.

**SRA target state, with the nuance worth preserving verbatim:** enabled for all member accounts and the management account, **Security Tooling as delegated administrator**, and — deliberately — **both an organization-zone-of-trust analyzer and an account-zone-of-trust analyzer in every Region** for external and internal access. The reason: an org-zone analyzer will not flag a resource shared cross-account *within* the same organization, because that is in-zone by definition. **The account-scoped analyzer is what catches unexpected sharing between sibling accounts.** Unused-access analyzers are created once for the current account and once for the organization.

---

## Account-Level Data-Protection Defaults

> Source: https://docs.aws.amazon.com/AmazonS3/latest/userguide/configuring-block-public-access-account.html, https://docs.aws.amazon.com/ebs/latest/userguide/encryption-by-default.html, https://docs.aws.amazon.com/AmazonS3/latest/userguide/default-encryption-faq.html (official)

These are the switches a platform team sets once per account or once org-wide, distinct from per-bucket or per-volume configuration a workload team handles.

### S3 Block Public Access

"By default, new buckets, access points, and objects do not allow public access" — but that per-resource default is **not** the account-level Block Public Access setting, which is a separate explicit switch covering buckets an admin did not personally create.

**Precedence, verbatim:** "Account level settings override settings on individual objects. Configuring your account to block public access will override any public access settings made to individual objects within your account." Turning on the four account-level flags (block public ACLs, ignore public ACLs, block public policy, restrict public buckets) makes it structurally impossible for any bucket in the account to become public.

**Organization-level BPA overrides account-level:** "If your account is managed by an organization-level Block Public Access policy, you cannot modify these account-level settings. Organization-level policies override account-level configurations." Local `PutPublicAccessBlock` and `DeletePublicAccessBlock` calls fail with Access Denied, and `GetPublicAccessBlock` returns the org-enforced configuration. **Set this once at the organization level rather than trusting every account to enable it individually** — this is the SRA's `s3_block_account_public_access` checklist item.

### EBS encryption by default

"You can configure your AWS account to enforce the encryption of the new EBS volumes and snapshot copies that you create." Four properties determine how you roll it out:

- **Region-specific.** There is no single account-wide-across-all-Regions switch; enable it per Region (AWS's own examples loop across Regions for this reason).
- **Not retroactive.** "Encryption by default has no effect on existing EBS volumes or snapshots" — it is a forward-only guarantee, not a remediation.
- **No per-resource opt-out.** "If you enable it for a Region, you cannot disable it for individual volumes or snapshots in that Region."
- **Compatibility constraint:** after enabling it you can no longer launch instance types that do not support EBS encryption.

The default key is the AWS managed `aws/ebs` key unless you specify a symmetric customer-managed key. The SRA's posture is enable-by-default **and** point it at a customer-managed key: "customer managed keys are used for encryption of all sensitive data at rest... AWS managed keys are acceptable only for non-sensitive or public-classified data." This implements FSBP control `EC2.7`.

### S3 default encryption

Since **January 5, 2023** this is no longer something to turn on: "Amazon S3 now applies server-side encryption with Amazon S3 managed keys (SSE-S3) as the base level of encryption for every bucket... all new object uploads to Amazon S3 are automatically encrypted at no additional cost and with no impact on performance." **"You can no longer disable encryption for new object uploads."**

Two caveats: **"Amazon S3 only automatically encrypts new object uploads"** — pre-existing unencrypted objects are untouched, and S3 Batch Operations is the documented backfill path. And there is **no account-wide "SSE-KMS by default for every new bucket" switch** analogous to EBS's — each bucket's default-encryption configuration is set individually or through IaC, Config rules, and policy guardrails. Name that gap rather than implying parity.

---

## Detection and Response Service Selection

> Source: https://docs.aws.amazon.com/decision-guides/latest/security-on-aws-how-to-choose/choosing-aws-security-services.html (official)

AWS's own one-line positioning within the detection-and-response domain:

| Service | AWS's stated optimization |
|---|---|
| AWS Security Hub CSPM | "automating security checks and centralizing security alerts with AWS and third-party integrations" |
| AWS Config | "assessing, auditing, and evaluating the configuration of your resources" |
| AWS CloudTrail | "logging events from other AWS services as an audit trail" |
| Amazon GuardDuty | "intelligent threat detection and detailed reporting" |
| Amazon Inspector | "vulnerability management" |
| Amazon Security Lake | "centralizing security data" |
| Amazon Detective | "aggregating and summarizing potential security issues" |
| AWS Security Incident Response | "helping you triage findings, escalate security events, and manage cases that require your immediate attention" |

### Question-to-service routing

| Question | Service |
|---|---|
| "Are my resources continuously configured per best practice?" | **Security Hub CSPM** — continuous checks against enabled standards, scored |
| "What is this resource's configuration, and did it change?" | **AWS Config** — configuration state, history, and rule-based compliance |
| "Who did what, when, from where?" | **CloudTrail** — the API audit trail underlying almost everything else |
| "Is there malicious behavior happening right now?" | **GuardDuty** — behavioral and threat-intelligence detection |
| "Does this workload have known vulnerabilities?" | **Amazon Inspector** — EC2, ECR images, Lambda functions/layers and code |
| "Is sensitive data exposed in S3?" | **Amazon Macie** — ML and pattern-matching sensitive-data discovery scoped to S3 |
| "A finding fired — what is the blast radius and root cause?" | **Amazon Detective** — investigation and correlation *after* a finding, not a primary detector |
| "Who can reach my resources that shouldn't, and what access is unused?" | **IAM Access Analyzer** |
| "I need one normalized security data lake for SIEM/analytics" | **Amazon Security Lake**, or CloudWatch Unified Data Experience per current SRA guidance |
| "An incident is happening and I need help" | **AWS Security Incident Response** |

**The complementarity to keep straight:** Config asks *what is this resource's configuration*; Security Hub CSPM asks *does that configuration match a standard*; CloudTrail asks *what actions were taken*; GuardDuty asks *was any of that behavior malicious*; Inspector asks *does this workload have a known vulnerability regardless of behavior*; Detective asks *given a finding, what is the full story*. **Security Hub CSPM checks are configuration-state; GuardDuty checks are behavioral.** None substitutes for another, which is why the SRA enables nearly all of them org-wide and feeds them into Security Hub for correlation.

Integration relationships worth preserving: Security Hub CSPM, Config, GuardDuty, Inspector, and Audit Manager all integrate *into* Security Hub CSPM; GuardDuty integrates with Detective and Security Lake; Detective integrates with all three.

## Sources

- https://docs.aws.amazon.com/wellarchitected/latest/framework/security.html
- https://docs.aws.amazon.com/wellarchitected/latest/framework/sec-design.html
- https://docs.aws.amazon.com/wellarchitected/latest/framework/sec-bp.html
- https://docs.aws.amazon.com/wellarchitected/latest/framework/sec-security.html
- https://docs.aws.amazon.com/wellarchitected/latest/framework/sec-detection.html
- https://docs.aws.amazon.com/prescriptive-guidance/latest/security-reference-architecture/account-structure.html
- https://docs.aws.amazon.com/prescriptive-guidance/latest/security-reference-architecture/security-tooling.html
- https://docs.aws.amazon.com/prescriptive-guidance/latest/security-reference-architecture/log-archive.html
- https://docs.aws.amazon.com/prescriptive-guidance/latest/security-reference-architecture/checklist.html
- https://docs.aws.amazon.com/awscloudtrail/latest/userguide/creating-trail-organization.html
- https://docs.aws.amazon.com/guardduty/latest/ug/guardduty_organizations.html
- https://docs.aws.amazon.com/guardduty/latest/ug/add-member-accounts-guardduty-organization.html
- https://docs.aws.amazon.com/guardduty/latest/ug/guardduty_data-sources.html
- https://docs.aws.amazon.com/securityhub/latest/userguide/central-configuration-intro.html
- https://docs.aws.amazon.com/securityhub/latest/userguide/securityhub-accounts-orgs.html
- https://docs.aws.amazon.com/securityhub/latest/userguide/standards-reference.html
- https://docs.aws.amazon.com/securityhub/latest/userguide/fsbp-standard.html
- https://docs.aws.amazon.com/config/latest/developerguide/conformance-packs.html
- https://docs.aws.amazon.com/IAM/latest/UserGuide/access-analyzer-settings.html
- https://docs.aws.amazon.com/AmazonS3/latest/userguide/configuring-block-public-access-account.html
- https://docs.aws.amazon.com/ebs/latest/userguide/encryption-by-default.html
- https://docs.aws.amazon.com/AmazonS3/latest/userguide/default-encryption-faq.html
- https://docs.aws.amazon.com/decision-guides/latest/security-on-aws-how-to-choose/choosing-aws-security-services.html

Fetched: 2026-08-08
