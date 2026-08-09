# AWS Multi-Account Organization Reference

> AWS Organizations, OU taxonomy, management-account rules, SCPs vs RCPs, Control Tower, delegated administration, IAM Identity Center placement. This is the org-topology layer: decisions made once, centrally, by whoever owns the landing zone.
>
> CLI mechanics (`aws organizations ...`, `aws configure sso`, `aws sso login`) belong to the `aws-cli` skill in `cli-scripting`. IAM policy authoring depth belongs to the `aws-iam` skill in `security`.

---

## Why Multiple Accounts

> Source: https://docs.aws.amazon.com/whitepapers/latest/organizing-your-aws-environment/organizing-your-aws-environment.html and https://docs.aws.amazon.com/controltower/latest/userguide/aws-multi-account-landing-zone.html (official)

"Your cloud resources and data are contained in an AWS account, which acts as an isolation boundary for identity and access management... By default, no access is allowed between accounts."

AWS's directive is unambiguous and applies from early adoption, not only at enterprise scale: **"We recommend using several accounts to separate your workloads, rather than relying on a single account."** The only stated exception is a single account used purely to experiment and learn before planning the first production workloads.

Seven independent reasons, from the Control Tower guide's own list: **security controls** (different applications need different policies; an account boundary makes an audit conversation concrete), **isolation** (an account is a unit of blast-radius containment), **many teams** (accounts stop teams interfering with each other), **data isolation** (limits who can reach a sensitive datastore), **business process** (per business unit or product), **billing** (the only mechanism that truly separates cost and transfer charges), and **quota allocation** (service quotas are per-account, so splitting gives each workload clean headroom).

**Account count is free** — "AWS charges are based on resource usage, not the number of accounts." Never under-provision accounts to save money.

The sizing unit is the **workload**: "a set of components that collectively deliver business value." One account per workload environment (dev, test, prod) is the default granularity.

---

## Organization Structure and Feature Sets

> Source: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_getting-started_concepts.html (official)

Two feature sets:

- **All features** (recommended and the default) — central policies (SCPs, RCPs, declarative policies), consolidated billing, and delegation. **Required for SCPs and RCPs to exist at all.**
- **Consolidated billing only** — shared billing, no service integrations, no policies.

Upgrading requires every invited member account to approve via an `ENABLE_ALL_FEATURES` handshake.

Hierarchy: one **root** (created automatically, contained in the management account), **organizational units** nested beneath it, and accounts placed in the root or in an OU. Policies attached to a node flow down to every OU and account beneath it. Each account belongs to exactly one OU; each OU has exactly one parent.

**The asymmetry that shapes every design decision:** an **authorization policy** (SCP or RCP) applied to the root applies to every OU and **member** account — **it does not apply to the management account**. A **declarative policy** applied to the root *does* apply to everything including the management account.

### OU design question

> Source: https://docs.aws.amazon.com/whitepapers/latest/organizing-your-aws-environment/aws-organizations.html (official)

Verbatim, and the only design rule that matters: **"OUs are not meant to mirror your own organization's reporting structure. Instead, OUs are intended to group accounts that have common overarching security policies and operational needs. The primary question to ask yourself is: How likely will the group need a set of similar policies?"**

### Quotas that constrain design

> Source: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_reference_limits.html (official)

| Item | Limit |
|---|---|
| Accounts per organization | **10 default**, adjustable (only from the management account) up to **50,000** on qualification |
| OUs per organization | **2,000** |
| **OU nesting depth** | **5 levels including the root** |
| SCPs per organization / RCPs per organization | 10,000 / **2,000** |
| **SCPs attached per root, OU, or account** | **10 each** (minimum 1 once SCPs are enabled) |
| **RCPs attached per root, OU, or account** | **5 each** — the auto-attached, non-detachable `RCPFullAWSAccess` counts toward the 5 |
| Max SCP document size / max RCP document size | **10,240 characters / 5,120 characters** |
| Tag / backup / declarative / Security Hub policies per org | 1,000 each; 10 attachable per entity |
| Concurrent account creations / closures | 5 / 3 |
| Account closures per 30 days | 250 (orgs under 1,250 accounts), 20% (1,250-5,000), 1,000 max (over 5,000) — not adjustable |
| Minimum account age before removal | 4 days |

Attachment limits count **only directly attached policies** — inherited parent policies do not consume a child's budget. That is what makes a layered root/OU/account policy design workable inside a 10-policy ceiling.

**Service ceilings can be lower than the org quota** and are the real constraint at scale: IAM Identity Center 7,000 accounts; Amazon Detective 1,200; Audit Manager 250 (increasable); Security Hub, Macie, Control Tower, Inspector, Firewall Manager, DevOps Guru 10,000; Service Catalog 15,000.

---

## The Management Account

> Source: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_best-practices_mgmt-acct.html and https://docs.aws.amazon.com/whitepapers/latest/organizing-your-aws-environment/aws-organizations.html (official)

AWS's six practices, with the two that are absolute stated first:

1. **Use the management account only for tasks that require it.** Verbatim: **"Store all of your AWS resources in other AWS accounts in the organization and keep them out of the management account."**
2. **Do not deploy workloads there.** Verbatim: **"Privileged operations can be performed within an organization's management account, and SCPs do not apply to the management account. That's why you should limit the cloud resources and data contained in the management account to only those that must be managed in the management account."**
3. **Limit who has access** to a small set of highly trusted individuals under least privilege.
4. **Review and track that access on a recurring cadence** — who can reach the email address, password, MFA device, and phone number. Root-account recovery must not depend on any one person being available. Use a **shared mailbox** for the management account's email, never an individual's inbox.
5. **Block inadvertent departures and closures with an SCP** (below).
6. **Delegate responsibilities outside the management account** so teams work in their own accounts.

The mechanical reason for all of it: **"SCPs don't affect users or roles in the management account. They affect only the member accounts in your organization."** The same exemption applies to RCPs. Anything in the management account sits outside every guardrail you write.

### The default departure-block SCP

> Source: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_security_default_controls.html (official)

Organizations created **through the console after July 10, 2026** automatically enable SCPs and attach this policy at the root:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "DenyLeaveOrganizationAndCloseAccount",
            "Effect": "Deny",
            "Action": ["organizations:LeaveOrganization", "account:CloseAccount"],
            "Resource": "*"
        }
    ]
}
```

Organizations created via CLI, SDK, or CloudFormation — and every organization predating that date — must add it by hand. Attach it at the root.

---

## Recommended OU Taxonomy

> Source: https://docs.aws.amazon.com/whitepapers/latest/organizing-your-aws-environment/recommended-ous-and-accounts.html and the foundational/application/experimental/procedural/advanced-OU pages of the same whitepaper (official)

AWS's caveat first: "you might not need to establish all the recommended OUs... it is your organization's responsibility to define a customized OU structure that aligns with your distinct requirements."

### 1. Foundational OUs

**Security OU** — "Groups AWS accounts that apply security policies, governance and compliance controls across the organization."

- **Log Archive** — the consolidation point for CloudTrail, Config, and VPC Flow Logs. "We strongly recommend that you only house log data in this account." Other accounts get read-only roles into it; SCPs on the Security OU prevent modification or deletion of the logging buckets; enable S3 versioning. Control Tower creates this account and wires Config plus the CloudTrail organization trail into it automatically.
- **Security Tooling (Audit)** — the delegated-administrator home for Security Hub CSPM, GuardDuty, Macie, Detective, Inspector, Firewall Manager, IAM Access Analyzer, Audit Manager, and third-party SIEM tooling. Access restricted to authorized security and compliance personnel.
- **Keep this OU clean.** Verbatim: "maintain a clean security organizational unit (OU) that adheres to AWS Control Tower requirements. The security OU should contain only the essential security accounts designated by AWS Control Tower. For additional security-related accounts, create a separate OU outside the core security OU."

**Infrastructure OU** — shared infrastructure and networking. **Explicit rule: "No application accounts or application workloads are intended to exist within this OU."** Recommended accounts: **Network** (Transit Gateway, VPC sharing, Route 53 Resolver endpoints, IPAM, VPN, Direct Connect, centralized inspection), **Shared Services** (Service Catalog, Compute Optimizer, centralized IT services), **Identity** (IAM Identity Center delegated admin, Directory Service, centrally secured root credentials for managed accounts), **Backup** (AWS Backup delegated admin, backup KMS keys), **Operations Tooling** (SSM Change Manager/Explorer, CloudFormation StackSets, License Manager, AWS Health), and **Monitoring** ("only give read-only functionality... not intended to have the ability to make changes across account your AWS Organization"; CloudWatch cross-account observability hub, S3 Storage Lens delegated admin).

### 2. Application OUs

**Workloads OU** — business workloads, production and non-production, including shared application/data services such as a `data-lake-prod` account. Typical split into `Prod` and `Test` child OUs sharing a governance model.

### 3. Experimental OUs

**Sandbox OU** — free exploration, "typically disconnected from your internal networks and internal services." **"Sandbox accounts should not be promoted to any other type of account or environment within the Workloads OU."** Near-admin access inside a sandbox is normal, paired with a hard rule of **no access to corporate resources or non-public data/IP** — that line is what separates a sandbox from a development environment. Attach spend budgets and an instance scheduler; at thousands of per-builder sandboxes, consider a separate organization or an account-recycling process rather than exhausting the account quota.

### 4. Procedural OUs

- **Exceptions** — accounts needing a documented exception to Workloads-OU policy. "Normally, there should be a minimal number of accounts, if any, in this OU." SCPs here are account-level. If the same exception recurs, promote it into a proper child OU under Workloads instead.
- **Transitional** — a holding area for acquisitions, pre-existing accounts, insourced third-party accounts, and accounts being divested. Check inbound accounts against root-level SCPs before the move so you do not break them on arrival.
- **Policy Staging** — test org-wide policy changes (SCPs, tag policies, baseline IAM) before rollout. Recommended promotion path: Policy Staging -> temporarily apply to one production-target account -> apply to the real OU and retract the temporary application. Workload-specific IAM does not need to pass through here.
- **Suspended** — a holding pen for accounts whose use must stop. **Not the same as closing an account.** Use SCPs to block all but security/platform-team API usage, stop running resources, and tag with the reason and origin OU for audit and automation.

### 5. Advanced OUs

- **Individual Business Users** — direct AWS access for business teams outside the Workloads scope, scoped tightly with SCPs plus IAM.
- **Deployments** — CI/CD build and release orchestration, separated from workload accounts for three stated reasons: CI/CD's uniquely privileged role (write to artifact stores where workloads only read), the need to reach both prod and non-prod without ever granting prod access to non-prod, and a different toolchain and attack surface. Run CI and release-artifact CD stages in **production** Deployments accounts, not inside production workload accounts.
- **Business Continuity** — an optional near-air-gapped data bunker for ransomware and severe-disaster scenarios. "The Business Continuity OU does not replace normal disaster recovery plans of your workloads. It's an additional layer of protection." Controls: locked-down Backup Administrator role, AWS Backup Vault Lock in Compliance mode with at least 14-day retention, Backup Audit Manager review, and access mutually exclusive with regular-environment access. Most organizations do not need it — the Backup account in the Infrastructure OU is sufficient for normal cross-account DR.

### Production and non-production separation

Applies across Security, Infrastructure, Workloads, and Deployments. Core directive: **"We recommend that you isolate production workload environments and data in production accounts housed within production OUs."**

The **directional access rule**: "Generally, workloads deployed to your production environments should not depend on workloads contained in your non-production environments." The reverse is normal — non-production commonly reads production shared services (artifact repositories) — but should use **test data**, not production data.

Two supported non-production shapes: a single `NonProd` OU holding Dev and Test together when they share policy needs, or separate `Dev` and `Test` OUs when dev needs materially looser policy than a formally managed test environment. When a workload family needs distinct policy, add a **child OU** rather than applying policy account by account.

---

## SCPs and RCPs

> Source: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_authorization_policies.html, .../orgs_manage_policies_scps.html, .../orgs_manage_policies_rcps.html, .../orgs_manage_policies_scps_evaluation.html (official)

### The distinction

- **SCP — principal-centric.** Sets the maximum permissions for IAM principals in member accounts. "SCPs provide an ability to control which resources your identities can access."
- **RCP — resource-centric.** Sets the maximum permissions on resources in member accounts, **regardless of who is calling**. "RCPs provide an ability to control which identities can access your resources." **RCPs are the only lever that constrains external, non-organization principals** — an SCP cannot, because it only binds principals in your own organization.

Worked example that makes it concrete: Account A (in your org) owns a bucket whose bucket policy grants access to a user in external Account B. An **SCP on Account A does not constrain that external user. An RCP on Account A does.** Prefer the RCP form of a control whenever the resource must also be protected from third parties.

**Neither grants anything.** "No permissions are granted by an SCP" / "No permissions are granted by an RCP." Effective permissions are the intersection of SCP, RCP, identity-based policy, and resource-based policy.

### Mechanics and exemptions

Both require all-features mode. Both **exempt the management account entirely** and **never affect service-linked roles**. SCPs apply to all users and roles in an affected account **including the root user**, with a documented exception list: management-account actions, service-linked roles, registering for Enterprise Support as root, CloudFront private-content trusted-signer functionality, configuring reverse DNS for a Lightsail email server or EC2 instance as root, and a handful of legacy Amazon services.

RCP-specific: RCPs affect root users including **external-account** root users, **do not apply to AWS-managed KMS keys**, and only apply to services on the RCP-supported list — CloudFront, CloudWatch Logs, Cognito, Data Firehose, **DynamoDB**, DAX, **EC2 Auto Scaling**, ECR, EventBridge, AWS Health, **KMS**, MemoryDB, OpenSearch Service and Serverless, **S3**, **Secrets Manager**, **SQS**, **STS**, Sign-In, Transfer Family, WAFv2, and roughly two dozen more. **Check the list before promising an RCP will constrain a given service** — for everything else, SCPs remain your only guardrail.

### Inheritance and evaluation

Deny-by-default with two independent rules:

- **Allow rule** — a permission is allowed at an account only if there is an **explicit `Allow` at every level** from root through each OU in the direct path to the account. Any gap blocks it.
- **Deny rule** — **any single `Deny` anywhere in that chain** is sufficient. Deny always wins; a broader allow elsewhere never overrides it.

This is why AWS auto-attaches `FullAWSAccess` (allow-all) at every level when SCPs are enabled. Removing it without a replacement `Allow` blocks everything beneath that point.

### Deny-list versus allow-list

- **Deny-list (recommended default):** keep `FullAWSAccess` and layer `Deny` statements. "`Deny` statements are a powerful way to implement restrictions that should be true for a broader part of your organization or OUs because when they are applied at the root or the OU-level they affect all the accounts under it."
- **Allow-list:** replace `FullAWSAccess` with a named-service allow list. Applied at the **root** this becomes the ceiling for the whole organization even if lower OUs still carry `FullAWSAccess`, because effective permission is the intersection.
- **AWS's own caution, verbatim:** "Relying solely on allow statements and the implicit deny-by-default model can lead to unintended access, because broader or overlapping Allow statements can override more restrictive ones."

**Always stage.** Test new SCPs against an isolated OU, moving a few accounts in at a time, rather than attaching at the root. Use IAM service-last-accessed data or CloudTrail to find out what a candidate deny would actually break. The identical caution applies to RCPs — test on individual accounts first, promote up the tree, and watch CloudTrail `AccessDenied` events as the signal.

**Operational caveat for developers:** "It is not possible to retrieve the effective service control policy that applies to a linked account by design." Document your SCP restrictions separately and grant developers CloudTrail read access so they can diagnose denials.

### Common essential controls

Deny non-approved Regions; deny root actions outside break-glass; deny `organizations:LeaveOrganization` and `account:CloseAccount`; deny disabling GuardDuty, CloudTrail, or Config; deny creating IAM users and access keys (forcing Identity Center); deny making S3 buckets public. Express the last two as RCPs where the resource also needs protection from external principals.

---

## AWS Control Tower

> Source: https://docs.aws.amazon.com/controltower/latest/userguide/what-is-control-tower.html, .../how-controls-work.html, .../account-factory.html, .../aws-multi-account-landing-zone.html (official)

**What it is:** "AWS Control Tower offers a straightforward way to set up and govern an AWS multi-account environment, following prescriptive best practices. AWS Control Tower *orchestrates* the capabilities of several other AWS services, including **AWS Organizations, AWS Service Catalog, and AWS IAM Identity Center**, to build a landing zone in less than an hour." It is an opinionated automation layer, not a new primitive.

**Four features:** the **landing zone** (the enterprise-wide container of OUs, accounts, users, and resources subject to governance), **controls** (guardrails), **Account Factory** (a configurable account template built on Service Catalog provisioned products, letting teams self-serve accounts under central policy), and a **dashboard**.

**Controls demystified — the single most useful mapping:** "In AWS Control Tower preventive controls are implemented with **service control policies (SCPs) and resource control policies (RCPs)**. Detective controls are implemented with **AWS Config rules**. Proactive controls are implemented with **CloudFormation hooks**." A guardrail is not a fifth AWS primitive; it is Control Tower's managed authoring and rollout layer over those four.

- **Preventive** — blocks the action outright and logs the attempt in CloudTrail.
- **Detective** — detects an event after it occurs and logs it.
- **Proactive** — checks whether a CloudFormation-templated resource *would* comply before it is provisioned.

Three enforcement tiers: mandatory (unchangeable), strongly recommended, and elective.

**When to adopt it, verbatim:** **"If you are hosting more than a handful of accounts, it's beneficial to have an orchestration layer that facilitates account deployment and account governance."**

**What it creates versus what you add:** Control Tower auto-creates the **Security OU** (always) and optionally a **Sandbox OU**; it explicitly **does not create the Infrastructure OU or the Workloads OU** — you add those. Minimum recommendation is at least two environments/OUs, Production and Staging, plus an optional Sandbox. Nested OU hierarchies are supported and optional; both flat and hierarchical structures perform equivalently.

**Root clarification:** "The Root is not an OU. It is a container for the management account, and for all OUs and accounts in your organization... You cannot govern enrolled accounts at the Root level within AWS Control Tower. Instead, govern enrolled accounts within your OUs."

**Account Factory mechanics:** provisioning targets an OU with `AWSControlTowerBaseline` enabled; by default only Identity Center users in the `AWSAccountFactory` group can provision; the management account holds a trust relationship with the `AWSControlTowerExecution` role, and **enrolling a pre-existing account requires that role to already be present in it.**

Control Tower does not lock you out of Organizations — you can keep working directly in Organizations and register existing organizations and accounts, with changes reflected once you register and update the landing zone.

---

## Delegated Administration and Trusted Access

> Source: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_integrate_services.html and .../orgs_integrate_services_list.html (official)

Three distinct concepts, routinely conflated:

1. **Trusted access** — authorizes a *service* to act across the organization on your behalf by creating **service-linked roles** in member accounts as needed. Enabling it changes no user or role permissions. **Enable and disable it through the service's own console/CLI/API, not through raw Organizations calls**, so the service runs its own setup and cleanup; disabling via Organizations can leave stale configuration behind.
2. **Delegated administrator for a service** — registers a member account to administer that service org-wide; it receives the service's admin permissions plus Organizations read-only actions. Configured per service, independently of trusted access.
3. **Delegated administrator for Organizations itself** — delegates management of organization *policies* and their attachment to specific member accounts, via a resource-based delegation policy (max 40,000 characters).

Every account joining or created in an organization is auto-provisioned with the `AWSServiceRoleForOrganizations` service-linked role. **SCPs never affect service-linked roles, ever.**

### Support matrix for the services that matter

| Service | Trusted access | Delegated admin | Note |
|---|---|---|---|
| AWS Control Tower | Yes | **No** | No delegated-admin concept |
| AWS Config | Yes | Yes | Org aggregator plus organization conformance packs |
| AWS CloudTrail | Yes | Yes | Organization trail creation |
| Amazon GuardDuty | Yes | Yes | **One per organization**; auto-enable for new accounts |
| AWS Security Hub CSPM | Yes | Yes | Auto-enables for all accounts including new joiners |
| Amazon Macie | Yes | Yes | One per organization |
| Amazon Detective | Yes | Yes | **Requires GuardDuty already enabled on the same account** |
| Amazon Inspector | Yes | Yes | |
| AWS Firewall Manager | Yes | Yes | |
| AWS Backup | Yes | Yes | Org-wide or per-OU backup plans |
| IAM Identity Center | Yes | Yes | See below |
| IAM Access Analyzer | Yes | Yes | Organization zone of trust |
| AWS Systems Manager | Yes | Yes | Change Manager delegation called out explicitly |
| Amazon CloudWatch | Yes | Yes | |
| Resource Explorer | Yes | Yes | **Only 1 delegated administrator** |
| VPC IPAM / Reachability Analyzer | Yes | Yes | IPAM is one account org-wide |
| AWS RAM | Yes | **No** | Cross-account sharing without invitations |
| Service Quotas / AWS Artifact / Marketplace / Billing | Yes | **No** | |
| **Amazon EventBridge** | **No** | **No** | Cross-account event sharing exists but is configured independently, not via Organizations |
| Tag policies | Yes | **No** | A policy mechanism, not a delegatable service admin role |
| AWS Trusted Advisor | Yes | Yes | Requires a paid support plan on the management account |

### AWS's recommended delegation map

- **Security Tooling (Audit)** — Security Hub CSPM, GuardDuty, Macie (grouped "for ease of pivoting between these services"), Detective (must colocate with GuardDuty), Inspector, Firewall Manager, CloudTrail organization trail, Config aggregator, Audit Manager, IAM Access Analyzer.
- **Backup account** — AWS Backup and Organizations backup-policy administration.
- **Identity account** — IAM Identity Center; optionally Access Analyzer; centrally secured root credentials for managed accounts.
- **Network account** — Network Manager, IPAM, VPC Reachability Analyzer.
- **Operations Tooling** — Account Management, DevOps Guru, AWS Health, License Manager, SSM Change Manager/Explorer, CloudFormation StackSets.
- **Monitoring account** — AWS Health and S3 Storage Lens (a narrower, read-only slice).
- **Shared Services** — Service Catalog (Control Tower wires this for Account Factory) and Compute Optimizer.

Two operational cautions: several services (GuardDuty, Macie, Security Hub CSPM, Detective) allow **exactly one delegated administrator per organization**, and many delegations must be **repeated per Region** rather than being a single global setting.

---

## IAM Identity Center as the Access Layer

> Source: https://docs.aws.amazon.com/singlesignon/latest/userguide/what-is.html, .../organization-instances-identity-center.html, .../delegated-admin.html (official)

**Use an organization instance.** Verbatim: "An organization instance is the best practice. **It's the only instance that enables you to manage access to AWS accounts** and it is recommended for all production use of applications. An organization instance is deployed in the AWS Organizations management account." Account instances "are bound to the AWS account in which they are enabled" and exist "only to support isolated deployments of select AWS managed applications." Multi-account permission assignment is gated to organization instances.

This is a structural precondition, not a preference: an account instance in a member account **cannot** provision permission sets into sibling accounts. Only the organization instance can.

**Placement facts:** exactly one organization instance per Organizations management account; it must be enabled in the management account; instances enabled before November 15, 2023 are already organization instances. The org-instance owner can **centrally restrict whether member accounts may create their own account instances**. At creation you choose single-Region, multi-Region, or custom, plus the at-rest encryption key — **the primary Region cannot be changed afterward**, and permission sets, once enabled, cannot be disabled.

### Delegated administration of Identity Center

"Even though your IAM Identity Center instance must always reside in the management account, you can choose to delegate administration of IAM Identity Center to a member account" — this is what the whitepaper's **Identity account** is built around, and it minimizes how many people need management-account access at all.

AWS's documented best practices for the pattern:

- **A permission set that grants access *to* the management account can only be modified from the management account** — the delegated administrator cannot alter it.
- **Assign users, not groups, to management-account permission sets.** Group membership is typically controlled by IdP or directory admins who are not necessarily trusted with management-account access; assigning individuals prevents a group change silently granting that reach.
- **Active Directory placement is coupled to the delegated-admin account** — if AD is the identity source, the directory must live in the same member account as the Identity Center delegated administrator. Placing AD in the management account instead requires performing that setup from the management account.
- **Constrain the delegated admin's reach into the identity store when using an external IdP:** SCPs denying `identitystore:CreateGroupMembership` and `sso-directory:CreateBearerToken` from the delegated-admin account (with temporary carve-outs for SCIM setup and token rotation), so nobody can quietly add a user to an access-granting group or mint SCIM tokens outside the sync cycle. For locally managed users the equivalent controls go inline inside the Identity Center admin permission sets.
- **Split Identity Center configuration management from permission-set management** into distinct permission sets rather than one god-mode admin role.
- **Scope which accounts a delegated admin can touch** using permission-set tags plus account-list conditions.

## Sources

- https://docs.aws.amazon.com/organizations/latest/userguide/orgs_getting-started_concepts.html
- https://docs.aws.amazon.com/organizations/latest/userguide/orgs_reference_limits.html
- https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/consolidated-billing.html
- https://docs.aws.amazon.com/organizations/latest/userguide/orgs_best-practices_mgmt-acct.html
- https://docs.aws.amazon.com/organizations/latest/userguide/orgs_security_default_controls.html
- https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_authorization_policies.html
- https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps.html
- https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_rcps.html
- https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps_evaluation.html
- https://docs.aws.amazon.com/organizations/latest/userguide/orgs_integrate_services.html
- https://docs.aws.amazon.com/organizations/latest/userguide/orgs_integrate_services_list.html
- https://docs.aws.amazon.com/organizations/latest/userguide/orgs_delegate_policies.html
- https://docs.aws.amazon.com/whitepapers/latest/organizing-your-aws-environment/organizing-your-aws-environment.html
- https://docs.aws.amazon.com/whitepapers/latest/organizing-your-aws-environment/aws-organizations.html
- https://docs.aws.amazon.com/whitepapers/latest/organizing-your-aws-environment/recommended-ous-and-accounts.html
- https://docs.aws.amazon.com/whitepapers/latest/organizing-your-aws-environment/foundational-ous.html
- https://docs.aws.amazon.com/whitepapers/latest/organizing-your-aws-environment/security-ou-and-accounts.html
- https://docs.aws.amazon.com/whitepapers/latest/organizing-your-aws-environment/infrastructure-ou-and-accounts.html
- https://docs.aws.amazon.com/whitepapers/latest/organizing-your-aws-environment/application-ous.html
- https://docs.aws.amazon.com/whitepapers/latest/organizing-your-aws-environment/experimental-ous.html
- https://docs.aws.amazon.com/whitepapers/latest/organizing-your-aws-environment/procedural-ous.html
- https://docs.aws.amazon.com/whitepapers/latest/organizing-your-aws-environment/advanced-ous.html
- https://docs.aws.amazon.com/controltower/latest/userguide/what-is-control-tower.html
- https://docs.aws.amazon.com/controltower/latest/userguide/how-controls-work.html
- https://docs.aws.amazon.com/controltower/latest/userguide/account-factory.html
- https://docs.aws.amazon.com/controltower/latest/userguide/aws-multi-account-landing-zone.html
- https://docs.aws.amazon.com/singlesignon/latest/userguide/what-is.html
- https://docs.aws.amazon.com/singlesignon/latest/userguide/organization-instances-identity-center.html
- https://docs.aws.amazon.com/singlesignon/latest/userguide/delegated-admin.html

Fetched: 2026-08-08
