# AWS Tagging and Inventory Governance Reference

> Tag strategy, exact tag-policy semantics, the enforcement-layer stack, cost allocation tags, and org-scale inventory tooling. This is the strategy layer — **the CLI command surface (`resourcegroupstaggingapi`, `resource-explorer-2 search`, `ec2 create-tags`, `--tag-specifications`) belongs to the `aws-cli` skill in `cli-scripting`.** Both skills take the same stance: tag on create, enforce with SCPs, never rely on after-the-fact remediation.

---

## What a Tag Is, and Its Hard Limits

> Source: https://docs.aws.amazon.com/tag-editor/latest/userguide/tagging.html and https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/Using_Tags.html (official)

"Tags are key and value pairs that act as metadata for organizing your AWS resources." A key is required; a value is optional. **Both keys and values are case sensitive.**

| Restriction | Value |
|---|---|
| Maximum tags per resource | **50** |
| Maximum key length | **128 Unicode characters (UTF-8)** |
| Maximum value length | **256 Unicode characters (UTF-8)** |
| Allowed characters across all AWS services | letters (`a-z`, `A-Z`), numbers (`0-9`), spaces, and `+ - = . _ : / @` |
| `aws:` prefix | Reserved for AWS. Customer-uneditable, and **does not count against the 50-tag limit** |
| Uniqueness | Each key must be unique per resource, with exactly one value |

Two more that shape design:

- **"Do not store personally identifiable information (PII) or other confidential or sensitive information in tags."** Tags are administrative metadata visible in billing and inventory surfaces, not a data store.
- **Tags are not a targeting mechanism for destructive operations** — you cannot terminate, stop, or delete a resource by tag alone; the resource identifier is always required.

Known documentation discrepancy: the `aws ec2 create-tags` CLI reference states a 127-character key maximum. **Treat 128 as authoritative** — it is repeated consistently across the EC2 User Guide restrictions page, the cost-allocation-tag documentation, and the Resource Groups Tagging API reference.

Note for IAM resources specifically: IAM prevents tag keys that differ only in case (`CostCenter` versus `costcenter`) on users and roles, even though tags are case-sensitive everywhere else.

---

## Tag Categories

> Source: https://docs.aws.amazon.com/tag-editor/latest/userguide/tag-categories.html (official)

Verbatim framing: "Companies that are most effective in their use of tags typically create business-relevant tag groupings to organize their resources along technical, business, and security dimensions. Companies that use automated processes to manage their infrastructure also include additional, automation-specific tags."

| Category | AWS's example keys |
|---|---|
| **Technical** | `Name`, `Application ID`, `Application Role`, `Cluster`, `Environment`, `Version` |
| **Automation** | `Date/Time` (start/stop/delete/rotate), `Opt in/Opt out` (include in an automated activity), `Security` (encryption or flow-log requirements needing extra scrutiny) |
| **Business** | `Project`, `Owner`, `Cost Center/Business Unit`, `Customer` |
| **Security** | `Confidentiality` (data classification level), `Compliance` (which framework the workload must satisfy) |

Cite the **Tag Editor "Tagging categories" page** for this grid, not the tagging whitepaper — the current 2023 whitepaper edition is organized by adoption stage and stakeholder need, not by these four categories.

### Building the dictionary

> Source: https://docs.aws.amazon.com/whitepapers/latest/tagging-best-practices/defining-needs-and-use-cases.html and .../building-your-tagging-strategy.html (official)

Build the schema in a **cross-functional workshop**, not unilaterally. AWS names the stakeholders and what each needs: **Finance and Line of Business** (map cost to value — commonly mandating `CostCenter` and `BusinessUnit`), **Governance and Compliance** (data classification, audit scope, criticality), **Operations and Development** (lifecycle stage, backup/patching/observability ownership), and **InfoSec/SecOps** (define and manage controls). Stakeholders "define and validate the keys for mandatory tags" and "recommend the scope for optional tags."

The strategy document must answer six questions verbatim: what use cases need to be addressed; who is responsible for tagging; how tags are enforced (proactive versus reactive, and what automation); how effectiveness is measured; how often the strategy is reviewed; and who drives improvements.

**"Implementing a tagging strategy is a process of iteration and improvement. Start small with your immediate priority and grow the tagging schema as you need to."** Formalize ownership in a RACI or shared-responsibility matrix.

Namespaced keys are AWS's own worked convention — e.g. `example-inc:cost-allocation:CostCenter`, `example-inc:data:classification` (Public/Private/Confidential/Restricted), `example-inc:compliance:framework` (PCI-DSS/HIPAA), `example-inc:incident-management:escalationpath`. The payoff is tag-driven control deployment: an S3 bucket tagged `data:classification=Private` can automatically trigger the `s3-bucket-public-read-prohibited` Config rule and gate Macie scanning.

### Reactive versus proactive governance

> Source: https://docs.aws.amazon.com/prescriptive-guidance/latest/tagging-best-practices/best-practice-tagging.html (official)

The cleanest official framing, both verbatim:

- **"*Reactive governance* means finding resources that are not properly tagged. You can use tools such as the Resource Groups Tagging API, AWS Config rules, and custom scripts."**
- **"*Proactive governance* means that users are not allowed to create any untagged resources. You can use tools such as AWS CloudFormation, AWS Service Catalog, tag policies in AWS Organizations, or IAM resource-level permissions."**

Every enforcement decision below is really a choice about which of these two modes a given requirement needs.

---

## Tag Policies — Exact Semantics

> Source: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_tag-policies.html and .../orgs_manage_policies_tag-policies-enforcement.html (official)

Tag policies "standardize the tags attached to the AWS resources in your organization's accounts... including the preferred case treatment of tag keys and tag values." They require an **all-features organization**. Authoring happens in **AWS Organizations**; compliance reporting surfaces in **AWS Resource Groups (Tag Editor)**.

### The one fact everyone gets wrong

Tag policies expose two capabilities with **fundamentally different blocking behavior**:

1. **Basic compliance rules** — validate tag *value* and tag *key capitalization*.
2. **Required tag key** — validate that a mandatory key is present.

AWS's own Important callout, verbatim:

> "Basic compliance rules do not enforce tag compliance on resources that are created without tags. This capability does not enforce missing tag keys. **You cannot use this capability to ensure that required or mandatory tag keys are configured at resource creation.** Use reporting mode in 'Required tag keys' to enforce required tag keys for resources created by IaC tools such as CloudFormation, Terraform, and Pulumi. **Use SCPs to prevent IAM users and roles in target accounts from creating certain resource types if the request doesn't include the specified tags.**"

Stated precisely:

- `enforced_for` on basic compliance rules blocks a tagging operation **only when the tag is present and has a noncompliant value or capitalization**. It has **no power to make a tag exist**.
- Making a tag mandatory at creation requires an **SCP** (next section), or IaC-side validation.
- **Capitalization enforcement is an exact string match** — with it on, `CostCenter`, `costCenter`, and `Costcenter` are three distinct keys.
- **"Untagged resources or tags that aren't defined in the tag policy aren't evaluated for compliance with the tag policy."**

Canonical enforced policy shape:

```json
{
    "tags": {
        "CostCenter": {
            "tag_key": {"@@assign": "CostCenter"},
            "tag_value": {"@@assign": ["HR", "Legal"]},
            "enforced_for": {"@@assign": ["ec2:ALL_SUPPORTED"]}
        }
    }
}
```

### Reporting mode and its two gaps

> Source: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_tag-policies-report-tagging-compliance.html (official)

Without `enforced_for` a policy runs report-only. Two documented gaps matter:

1. **"Untagged resources don't appear as non-compliant in results."** The report only evaluates resources that have had at least one user-defined tag at some point. **A resource with zero tags is invisible to tag-policy reporting entirely** — AWS's documented remedy is a **Resource Explorer `tag:none` query** (see Inventory below).
2. **"The AWS Resource Groups console does not currently support reporting for required tag keys when evaluating compliance for an account."** Resources missing a required key will not appear as noncompliant and will not mark the account noncompliant. **Use the organization-wide compliance report instead.**

Selecting only "mark tags as required for reporting" treats any case variant as compliant; selecting only capitalization reports case compliance across all tagged resources. **You need both selected to get an exact-match missing-required-tag report.**

Reporting mode also functions as the shared source of truth for IaC-side enforcement: "You can use reporting with IaC tools such as CloudFormation, Terraform, and Pulumi to warn your developers or block deployments with missing required tags."

### Syntax, operators, inheritance

> Source: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_example-tag-policies.html (official)

A tag policy is JSON rooted at a fixed `"tags"` key. Per tag: a policy key (matched case-insensitively), a `tag_key` block (the required capitalization; lowercase if unspecified), an optional `tag_value` list (omit it and **any** value including none is compliant), an optional `enforced_for` list, and an optional `report_required_tag_for` list — a **separate field** from `enforced_for`.

- **Operators merge parent and child policies into an effective policy.** `@@assign` sets a value; `@@operators_allowed_for_child_policies: ["@@none"]` locks a setting so no policy lower in the tree can override it.
- **Wildcards:** `*` is allowed in tag values, **one wildcard per value** (`*@example.com` valid, `*@*.com` not). `ALL_SUPPORTED` works only in `enforced_for`, only for services that support it, and **cannot span services**.
- **Inheritance:** an account's binding effective policy is the merge of every tag policy from root down. Retrieve it via `Organizations:DescribeEffectivePolicy`.
- **AWS's recommended layering:** lock the key shape at the root with `@@operators_allowed_for_child_policies: ["@@none"]`, then let lower-level policies add acceptable values.
- **`enforced_for` is precise, not blanket.** AWS's own example makes a `Color` key noncompliant everywhere but names only `dynamodb:table` in `enforced_for` — so it is reported everywhere and blocked only on DynamoDB tables. Enforcement scope never implicitly follows report scope.

### Enforcement coverage caveat

> Source: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_supported-resources-enforcement.html (official)

Support is enumerated **per service and per resource type**, with separate columns for basic-compliance reporting, basic-compliance enforcement, required-tag-key reporting, and IaC enforcement. Confirmed enforcement-capable examples include `acm:certificate`, `lambda:function`, `secretsmanager:secret`, `ssm:document`, `dynamodb:table`, and `appmesh:mesh`. **Many resource types support reporting only** with no enforcement column checked at all — enforcement coverage is materially narrower than reporting coverage.

**Directive: never promise `enforced_for` works on an arbitrary resource type.** Check the supported-resources page (or the visual policy editor, which only lists enforceable types) first. Use the `ALL_SUPPORTED` wildcard per service rather than enumerating individual types.

Two interaction warnings AWS calls out: test on a single account before wider rollout, because a wrong policy locks users out of creating resources they need; and container-like services (EC2 Auto Scaling groups, EMR clusters) **auto-propagate tags to contained resources**, so a policy stricter for EC2 than for the parent construct can **block dynamic scaling and provisioning**.

---

## The Enforcement Stack

> Source: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/supported-iam-actions-tagging.html, https://docs.aws.amazon.com/config/latest/developerguide/required-tags.html, https://docs.aws.amazon.com/cfn-guard/latest/ug/what-is-guard.html, https://docs.aws.amazon.com/whitepapers/latest/tagging-best-practices/implementing-and-enforcing-tagging.html (official)

| Requirement | Right layer | Why |
|---|---|---|
| Block creation when a required tag key or value is missing | **SCP** with `aws:RequestTag`/`aws:TagKeys` (+ `ForAnyValue`) **on the create action** | The only mechanism that blocks before the resource exists, including for fully untagged requests |
| Standardize allowed values and capitalization for tags that are present | **Tag policy** `enforced_for` | Purpose-built, org-wide, per-resource-type — but cannot force presence |
| Find already-created resources missing required tags | **Config `required-tags`** rule, or the org-wide tag-policy compliance report | Detective only; Config supports Lambda-based remediation for manually managed resources |
| Stop IaC-authored resources from deploying untagged | **CloudFormation Guard** rules (wrapped in a CloudFormation Hook for server-side blocking), or Terraform/Pulumi-native validation | Shift-left; avoids the drift that post-deploy remediation creates |
| Find resources that were never tagged at all | **Resource Explorer** `tag:none` query | Tag policies and tag-based views both need an existing tag to evaluate |

### Layer 1 — SCPs: require tags at creation

Two condition keys, with exact semantics:

- **`aws:RequestTag/{key}`** — "To indicate that a particular tag key or tag key and value must be present in a request." `StringEquals` pins a key and value; `StringLike` with `*` requires only that the key be present with any value.
- **`aws:TagKeys`** — "To enforce the tag keys that are used in the request." `ForAllValues:StringEquals` requires every key in the request to come from an allow-list; `ForAnyValue:StringEquals` requires at least one listed key to be present.

**The critical directive, verbatim:** "To force users to specify tags when they create a resource, you must use the `aws:RequestTag` condition key or the `aws:TagKeys` condition key **with the `ForAnyValue` modifier**" — **on the resource-creating action itself**. Conditioning only `CreateTags` fails, because: "The `ec2:CreateTags` action is not evaluated if a user does not specify tags for the resource-creating action." A user who creates a resource with zero tags never triggers the tagging permission check at all.

Canonical org-wide deny (from the tagging whitepaper):

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "DenyRunInstanceWithNoCostCenterTag",
    "Effect": "Deny",
    "Action": "ec2:RunInstances",
    "Resource": ["arn:aws:ec2:*:*:instance/*"],
    "Condition": {"Null": {"aws:RequestTag/example-inc:cost-allocation:CostCenter": "true"}}
  }]
}
```

Companion pattern — scope tagging permission to the moment of creation only, so a principal cannot retag existing resources:

```json
{
  "Statement": [
    {"Effect": "Allow", "Action": ["ec2:RunInstances"], "Resource": "*"},
    {
      "Effect": "Allow",
      "Action": ["ec2:CreateTags"],
      "Resource": "arn:aws:ec2:us-east-1:111122223333:*/*",
      "Condition": {"StringEquals": {"ec2:CreateAction": "RunInstances"}}
    }
  ]
}
```

**Case-sensitivity gotcha, verbatim:** "the condition key is not case-sensitive and the condition value is case-sensitive. Therefore, to enforce the case-sensitivity of a tag key, use the `aws:TagKeys` condition key, where the tag key is specified as a value in the condition."

**Why this is airtight at the API level:** tag-on-create is atomic — EC2 documents that "If tags cannot be applied during resource creation, we roll back the resource creation process... no resources are left untagged at any time." Tag-after (a separate `create-tags` call) necessarily leaves a window in which the resource exists untagged, and a script failure between the two leaves it untagged permanently.

**Operational caveat:** "It is not possible to retrieve the effective service control policy that applies to a linked account by design." Document tagging requirements for developers separately, and grant CloudTrail read access so they can debug denials.

### Layer 2 — AWS Config `required-tags` (detective only)

Rule identifier **`REQUIRED_TAGS`**. "Checks if your resources have the tags that you specify... You can check up to **6 tags at a time**." Explicit non-preventative statement, verbatim: **"However, this rule does not prevent you from creating resources with incorrect tags."**

- Trigger type: **configuration changes**, not scheduled.
- Parameters: `tag1Key` through `tag6Key` (`tag1Key` defaults to `CostCenter`), each with an optional CSV `tagNValue` list of acceptable values.
- Resource coverage is a **fixed list**, not universal: ACM certificates, Auto Scaling groups, CloudFormation stacks, CodeBuild projects, DynamoDB tables, most EC2 resource types (instances, volumes, VPCs, subnets, security groups, route tables, network ACLs, ENIs, gateways, VPN connections), both ELB generations, RDS instances/snapshots/subnet groups/security groups/event subscriptions, the Redshift family, and S3 buckets.
- **Remediation caveat:** the AWS-managed `AWS-SetRequiredTags` SSM document "does not work as a remediation with this rule" — a custom SSM automation document is required.
- **Coverage caveat:** "AWS Config does not support recording associated tags for all resource types" — verify Config records tags for a resource type before depending on the rule for it.

Pair it with Lambda-based auto-remediation for manually managed resources. That pattern "works well for static workloads" but is "progressively less effective" once resources move to IaC — see the drift warning below.

### Layer 3 — CloudFormation Guard (shift-left, not server-side)

"AWS CloudFormation Guard is an open-source, general-purpose, **policy-as-code evaluation tool**" with a declarative DSL for validating structured JSON/YAML against rules.

AWS states its own scope boundary explicitly: **"Guard doesn't provide server-side enforcement. You can use the CloudFormation Hooks to perform server-side validation and enforcement, where you can block or warn an operation."** Guard alone is a local or CI-time linter; it becomes a blocking control only inside a CloudFormation Hook or a build step that fails the pipeline.

Worked tag rule (official, from the tagging whitepaper) — note it also asserts `PropagateAtLaunch`, because an Auto Scaling group tag does not reach launched instances without it:

```
let all_asgs = Resources.*[ Type == 'AWS::AutoScaling::AutoScalingGroup' ]

rule tags_asg_automation_EnvironmentId when %all_asgs !empty {
    let required_tags = %all_asgs.Properties.Tags.*[
        Key == 'example-inc:automation:EnvironmentId' ]
    %required_tags[*] {
        PropagateAtLaunch == 'true'
        Value IN ['Prod', 'Dev', 'Test', 'Sandbox']
    }
}
```

**Why IaC-managed resources need this layer instead of Config remediation, verbatim:** "When using IaC, it's currently recommended to manage any tagging requirements as part of the IaC templates, implement AWS CloudFormation hooks, and publish AWS CloudFormation Guard rule sets that can be used by automation." Retroactively auto-tagging an IaC-managed resource introduces **drift** — CloudFormation sees the tag as an out-of-band modification against the template.

Free grouping key worth knowing: every CloudFormation-created resource automatically receives `aws:cloudformation:stack-name`, `aws:cloudformation:stack-id`, and `aws:cloudformation:logical-id`. Being `aws:`-prefixed, they neither count against the 50-tag limit nor can be edited.

---

## Cost Allocation Tags

> Source: https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/cost-alloc-tags.html, .../aws-tags.html, .../activating-tags.html, .../custom-tags.html, .../cost-allocation-backfill.html (official)

Two types, activated **separately**: **AWS-generated** (AWS or an AWS Marketplace ISV creates and applies them; `aws:` prefix, e.g. `aws:createdBy`) and **user-defined** (you create and apply them; `user:` prefix in the cost allocation report). "You must activate both types of tags separately before they can appear in Cost Explorer or on a cost allocation report."

**Activation is a management-account-only capability inside an organization.** "Only the management account in an organization and single accounts that aren't members of an organization have access to the cost allocation tags manager in the Billing console." The whitepaper reinforces it: "Tags created for resources residing in individual accounts in AWS Organizations can be used for cost allocation only from the management account."

### Timing — the two-stage delay

Activation is per **key**, not per key-value pair. The precise latency, verbatim: **"it can take up to 24 hours for the tag keys to appear on your cost allocation tags page for activation. It can then take up to 24 hours for tag keys to activate."** Plan for roughly **48 hours** from applying a brand-new tag to having an activated, usable cost dimension — not the single 24-hour figure the top-level page quotes for already-activated tags becoming visible.

### Retroactivity

**Default behavior is not retroactive.** "Tags are not applied to resources that were created before the tags were created," and cost allocation tags "will only appear in billing reporting and cost tracking tools after they were activated."

**Backfill is the documented escape hatch:** "Management account users can request a backfill of cost allocation tags for **up to twelve months**." It retroactively applies the tag's current activation status across the chosen window — and can also retroactively *deactivate* a tag for alignment.

Its limit is precise and worth stating to anyone planning a chargeback cleanup: **backfill retroactively activates a key; it cannot invent tag data that was never applied.** AWS's own example — a `Project` tag attached in June 2023 and activated in November, backfilled from January — shows values appearing only for June through December; January through May stay unattributed because the tag did not exist on the resource then.

Hard constraints: **one backfill request at a time**, **one new request per 24 hours**, and downstream services (Cost Explorer, Data Exports, Cost and Usage Report) refresh once every 24 hours, so expect another day's lag after a successful backfill.

### AWS-generated tag mechanics

`aws:createdBy` records who or what created a resource (`Root`, `IAMUser`, `AssumedRole`, or `FederatedUser` plus identifier). It is **forward-only** — "AWS starts applying the tag to resources that are created after the AWS-generated tag is activated," so pre-existing resources never receive it. It is populated only in a fixed allow-list of 14 Regions and only for a fixed table of API events per service, and it is **best-effort**: "Issues with services that AWS-generated tag depends on, such as CloudTrail, can cause a gap in tagging."

### Other restrictions worth carrying

- **The maximum number of active tag keys for Billing and Cost Management reports is 500.**
- `aws:`-prefixed and `aws:marketplace:isv:`-prefixed tags do not count against the 50-tags-per-resource quota.
- "Null tag values will not appear in Cost Explorer and AWS Budgets."
- **Org-move gotcha:** "When an account moves to another organization as a member, previously activated cost allocation tags for that account lose their 'active' status and need to be activated again by the new management account."
- The `awsApplication` tag from Service Catalog AppRegistry is auto-added and auto-activated, but once manually deactivated it does **not** auto-reactivate.
- Non-ASCII characters require standard base-64 encoding by the customer — "Billing and Cost Management does not encode or decode your tag for you."

### The confusion to pre-empt

**Organizations account and OU tags are not usable for cost allocation.** "you cannot group or filter your cost in AWS Cost Explorer by OU" via account/OU tags — **AWS Cost Categories** is the documented mechanism for grouping cost by account or organizational structure. Tagging an Organizations resource (an account, an OU, a policy) is a different surface from tagging the workload resources inside that account, and only the latter feeds cost allocation reporting.

---

## Org-Scale Inventory Tooling

> Source: https://docs.aws.amazon.com/resource-explorer/latest/userguide/welcome.html, .../manage-aggregator-region.html, .../manage-service-multi-account.html, https://docs.aws.amazon.com/ARG/latest/userguide/gettingstarted-query.html, https://docs.aws.amazon.com/config/latest/developerguide/aggregate-data.html (official)

| Need | Tool | Why not the others |
|---|---|---|
| "What resources of type X exist anywhere in the org, searchable by tag, name, or ID, near real time" | **Resource Explorer** (aggregator index + multi-account search) | Resource Groups has no multi-account index; Config aggregators are oriented to configuration and compliance history, not fast search |
| "Group these tagged (or stack-created) resources so I can act on them as a unit" | **Resource Groups** | Resource Explorer finds resources but does not model them as an actionable group |
| "Central read-only compliance and configuration-drift view across every account and Region" | **AWS Config aggregator** | Resource Explorer evaluates no rules; Resource Groups tracks no history |
| **"Find resources that were never tagged at all"** | **Resource Explorer, `tag:none` query** | Tag-policy compliance reports and tag-filter queries both require at least one existing tag to evaluate |

### Resource Explorer

Search and discovery "using an internet search engine-like experience" over resource metadata — names, tags, IDs — enriched with detail from AWS Config and Cloud Control. **Enabled by default with no setup as of October 6, 2025**; search works immediately based on the caller's IAM permissions.

Mechanics that shape a rollout:

- Two index types: **Resource Explorer-owned indexes** giving immediate partial results, and **user-owned indexes** giving complete results with automatic updates. Complete results need `iam:CreateServiceLinkedRole` once (bundled in `AWSResourceExplorerFullAccess`); afterwards read-only access suffices.
- **Aggregator index:** every Region gets a local index holding only that Region's data. Promote exactly **one** Region's index to aggregator and Resource Explorer replicates the others into it. **Cross-region search only works from views in the aggregator Region**, and a Region with no local index contributes nothing regardless.
- **Multi-account search** is a separate configuration layered on top: activate Resource Explorer in org accounts, register an aggregator Region **consistent across the whole organization**, create an org- or OU-scoped view in that Region, and share it. Requires a service-linked role in the administrator account and Organizations trusted access.
- **"Resource Explorer supports only 1 delegated administrator"**, and **"Removing or changing the delegated administrator for your organization results in the removal of all multi-account views created in their account"** — a real risk when reshuffling delegated admins.
- Quick Setup can deploy it org- or OU-wide but **"does not deploy any resources in the management account"** (add that index manually) and caps at **50,000 CloudFormation stacks at a time**.
- **Eventually consistent** — cross-Region replication "can take some time" — and a single search call returns **at most 1,000 total results**.
- Pricing: setup and basic search are free; charges arise only from underlying API calls and optional add-on data sources.

### Resource Groups

A Resource Group is a **saved, named query, not an index**. Two query types:

- **`TAG_FILTERS_1_0`** — resource-type filters intersected with tag filters. Semantics: **"If you specify more than one tag key, only resources that match all tag keys, and at least one value of each specified tag key, are returned"** — AND across keys, OR across values within a key.
- **`CLOUDFORMATION_STACK_1_0`** — membership by stack. Documented limit: **only resources directly created by the named stack are members**. A child stack joins as a single opaque member, and resources created *indirectly* (EC2 instances launched by a stack-managed Auto Scaling group) are **not** members.

Scope is per-account and per-Region with no native multi-account aggregation — for org-wide inventory, use Resource Explorer or Config aggregators.

### AWS Config aggregators

An aggregator collects configuration **and compliance** data from multiple accounts and Regions, a single account across Regions, or an entire organization, into one account.

**Explicitly read-only, verbatim:** "Aggregators provide a *read-only view* into the source accounts and Regions... Aggregators do not provide mutating access into a source account or region. For example, this means that you cannot deploy rules through an aggregator or push snapshot files to a source account or region through an aggregator."

**No additional cost** beyond ordinary Config usage. Source-account authorization is required **unless the accounts are in AWS Organizations**, in which case org membership substitutes for it. Named use cases: compliance monitoring, change tracking, and resource-relationship analysis.

For tagging specifically, an aggregator is how you view `required-tags` rule compliance across every account and Region from one place. Pair **organization conformance packs** (uniform enforcement everywhere) with an **organization aggregator** (uniform visibility) — see `references/security-platform.md`.

## Sources

- https://docs.aws.amazon.com/tag-editor/latest/userguide/tagging.html
- https://docs.aws.amazon.com/tag-editor/latest/userguide/tag-categories.html
- https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/Using_Tags.html
- https://docs.aws.amazon.com/whitepapers/latest/tagging-best-practices/tagging-best-practices.html
- https://docs.aws.amazon.com/whitepapers/latest/tagging-best-practices/defining-needs-and-use-cases.html
- https://docs.aws.amazon.com/whitepapers/latest/tagging-best-practices/data-security-and-risk-management.html
- https://docs.aws.amazon.com/whitepapers/latest/tagging-best-practices/building-your-tagging-strategy.html
- https://docs.aws.amazon.com/whitepapers/latest/tagging-best-practices/implementing-and-enforcing-tagging.html
- https://docs.aws.amazon.com/whitepapers/latest/tagging-best-practices/building-a-cost-allocation-strategy.html
- https://docs.aws.amazon.com/prescriptive-guidance/latest/tagging-best-practices/best-practice-tagging.html
- https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_tag-policies.html
- https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_tag-policies-enforcement.html
- https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_tag-policies-report-tagging-compliance.html
- https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_supported-resources-enforcement.html
- https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_example-tag-policies.html
- https://docs.aws.amazon.com/organizations/latest/userguide/orgs_tagging_abac.html
- https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/supported-iam-actions-tagging.html
- https://docs.aws.amazon.com/config/latest/developerguide/required-tags.html
- https://docs.aws.amazon.com/cfn-guard/latest/ug/what-is-guard.html
- https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/cost-alloc-tags.html
- https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/aws-tags.html
- https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/activating-tags.html
- https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/custom-tags.html
- https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/cost-allocation-backfill.html
- https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/cost-allocation-tags-timeline.html
- https://docs.aws.amazon.com/resource-explorer/latest/userguide/welcome.html
- https://docs.aws.amazon.com/resource-explorer/latest/userguide/manage-aggregator-region.html
- https://docs.aws.amazon.com/resource-explorer/latest/userguide/manage-service-multi-account.html
- https://docs.aws.amazon.com/ARG/latest/userguide/gettingstarted-query.html
- https://docs.aws.amazon.com/config/latest/developerguide/aggregate-data.html

Fetched: 2026-08-08
