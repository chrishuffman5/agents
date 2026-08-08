# AWS Operational Excellence Reference

> Well-Architected operational-excellence principles, deployment strategies and rollback, observability architecture and SLOs, and the Systems Manager configuration-management surface. Architecture and selection level.
>
> IaC template authoring belongs to `devops:cloudformation` and `devops:terraform`. EKS day-2 operations belong to the `containers` plugin.

---

## Well-Architected Operational Excellence Pillar

> Source: https://docs.aws.amazon.com/wellarchitected/latest/operational-excellence-pillar/operational-excellence.html (official)

**Definition, verbatim:** "Operational excellence (OE) is a commitment to build software correctly while consistently delivering a great customer experience. The operational excellence pillar contains best practices for organizing your team, designing your workload, operating it at scale, and evolving it over time." Its goal is "to get new features and bug fixes into customers' hands quickly and reliably."

### Design principles

- **Organize teams around business outcomes** — "The right operating model uses people, process, and technology capabilities to scale, optimize for productivity, and differentiate through agility, responsiveness, and adaptation."
- **Implement observability for actionable insights** — "Establish key performance indicators (KPIs) and leverage observability telemetry to make informed decisions and take prompt action when business outcomes are at risk."
- **Safely automate where possible** — "you can employ automation safety by configuring guardrails, including rate control, error thresholds, and approvals."
- **Make frequent, small, reversible changes** — "Automated deployment techniques together with smaller, incremental changes reduces the blast radius and allows for faster reversal when failures occur."
- **Refine operations procedures frequently** — "Hold regular reviews and validate that all procedures are effective."
- **Anticipate failure** — "Maximize operational success by driving failure scenarios to understand the workload's risk profile... Test the effectiveness of your procedures and your team's response against these simulated failures." (This is the game-days principle.)
- **Learn from all operational events and metrics** — share lessons across teams.
- **Use managed services** — "Reduce operational burden by using AWS managed services where possible."

Four best-practice areas: **Organization, Prepare, Operate, Evolve.**

---

## Deployment Strategies

### The taxonomy

> Source: https://docs.aws.amazon.com/whitepapers/latest/practicing-continuous-integration-continuous-delivery/deployment-methods.html (official)

| Method | Impact of a failed deployment | Deploy time | Zero downtime | No DNS change | Rollback | Deployed to |
|---|---|---|---|---|---|---|
| Deploy in place (all-at-once) | Downtime | 1x | No | Yes | Re-deploy | Existing instances |
| Rolling | One batch out of service; prior successful batches keep the new version | 2x | Yes | Yes | Re-deploy | Existing instances |
| Immutable | Minimal | 4x | Yes | Yes | Re-deploy | New instances |
| Traffic splitting | Minimal | 4x | Yes | Yes | Re-route and terminate new instances | New instances |
| Blue/green | Minimal | 4x | Yes | **No** | Switch back to the old environment | New instances |

- **All-at-once / in-place** — "replaces all the code in one deployment action. It requires downtime because all servers in the fleet are updated at once... the only way to restore operations is to redeploy the code on all servers again."
- **Rolling** — "the fleet is divided into portions so that all of the fleet isn't upgraded at once... two software versions, new and old, are running on the same fleet." Zero downtime; a failure affects only the updated portion. **Canary in this whitepaper's sense is a rolling variant**: deploy to a very small cohort first, watch the error rate, then gradually raise the percentage.
- **Immutable and blue/green** — start an entirely new set of servers. Blue/green is an immutable deployment that shifts traffic once the new environment passes tests, and **"Crucially the old environment, that is the 'blue' environment, is kept idle in case a rollback is needed."**

**Terminology warning:** this whitepaper's "canary" means a rolling deployment with a small initial cohort; CodeDeploy's Lambda and ECS "canary" configurations below are a traffic-percentage mechanism. Same idea, different literal knob — be explicit about which you mean.

### CodeDeploy deployment configurations

> Source: https://docs.aws.amazon.com/codedeploy/latest/userguide/deployment-configurations.html (official)

A deployment configuration is "a set of rules and success and failure conditions used by CodeDeploy during a deployment," and its shape differs by compute platform.

**EC2/On-Premises** — governs minimum healthy hosts:

- `CodeDeployDefault.AllAtOnce` — in place, deploy to as many instances as possible at once; succeeds if even one succeeds. Blue/green: reroute all traffic at once.
- `CodeDeployDefault.HalfAtATime` — up to half the fleet at a time; succeeds if at least half succeed.
- `CodeDeployDefault.OneAtATime` — one instance at a time. **The default when no configuration is specified.**
- A **zonal configuration** (healthy hosts per Availability Zone) is available only in a custom configuration — no predefined configuration exposes it.

**ECS** — traffic shifts to a new task set:

| Configuration | Behavior |
|---|---|
| `ECSLinear10PercentEvery1Minutes` / `Every3Minutes` | Shift 10% every 1 or 3 minutes until complete |
| `ECSCanary10Percent5Minutes` / `15Minutes` | Shift 10%, then the remaining 90% after 5 or 15 minutes |
| `ECSAllAtOnce` | Shift all traffic at once |

**If the ECS service uses a Network Load Balancer, only `ECSAllAtOnce` is supported.**

**Lambda** — the same vocabulary applied to traffic-weighted version aliases: `LambdaCanary10Percent5Minutes` / `10Minutes` / `15Minutes` / `30Minutes`, `LambdaLinear10PercentEvery1Minute` / `2Minutes` / `3Minutes` / `10Minutes`, and `LambdaAllAtOnce`.

Custom canary and linear configurations exist for EC2, ECS, and Lambda — but **CloudFormation-managed ECS blue/green deployments cannot use custom configurations**, only the predefined set.

### ECS blue/green

> Source: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/deployment-type-bluegreen.html (official)

"A blue/green deployment is a release methodology that reduces downtime and risk by running two identical production environments called blue and green. With Amazon ECS blue/green deployments, you can validate new service revisions before directing production traffic to them."

Key terms: **bake time** — the window both revisions run after the shift, during which "the blue revision is kept running until the bake time expires"; **listener, rule, and target group** — the ELB constructs implementing the shift; **lifecycle hooks** — Lambda functions or pause points at defined stages (for example "after production traffic shift") for automated validation. For services fronted by a load balancer or Service Connect, ECS manages the shift; for **headless services** it replaces tasks outright with no traffic shift to manage.

**Explicit trade-off:** blue/green **temporarily runs both revisions simultaneously, which may double resource usage during deployments** — a cost consideration rolling deployments do not carry.

### Lambda traffic shifting

> Source: https://docs.aws.amazon.com/lambda/latest/dg/configuring-alias-routing.html (official)

"You can use a weighted alias to split traffic between two different versions of the same function... This is known as a canary deployment. **Canary deployments differ from blue/green deployments by exposing the new version to only a portion of requests rather than switching all traffic at once.**" That is AWS's own canonical distinction between the two terms.

Constraints: an alias points to **at most two published versions** (never `$LATEST`), and both must share the same execution role and dead-letter-queue configuration. **The split is probabilistic, not a hard router** — "at low traffic levels, you might see a high variance between the configured and actual percentage of traffic on each version," so a canary on a low-traffic function proves less than it appears to.

Managed orchestration path: AWS SAM's `AutoPublishAlias` publishes a new version and updates the alias on each code change; `DeploymentPreference: Type: Linear10PercentEvery2Minutes` (or any predefined CodeDeploy Lambda configuration) selects the shift shape; the CodeDeploy deployment group manages the rollout and rollback.

### Route 53 weighted routing for deployment cutover

> Source: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/routing-policy-weighted.html (official)

"With weighted routing, you can link multiple resources to a single domain name... and choose how much traffic goes to each resource. **This can be useful for load balancing and testing new versions of software.**" Traffic share is weight divided by the sum of weights in the group; **setting a weight to 0 stops routing to that record entirely** — the controlled cutover and rollback lever. Weighted records work in a **private hosted zone** too, extending the pattern to internal traffic. Safety valve: if all nonzero-weighted records are unhealthy, Route 53 falls back to zero-weighted records that have health checks.

**Where it sits versus CodeDeploy:** Route 53 shifts traffic **at the DNS layer** across anything with an IP or alias target (ALBs, CloudFront, S3 endpoints, EC2), making it the tool for **cross-stack, cross-service, or cross-Region** blue/green cutovers. CodeDeploy's Lambda and ECS shifting operates **within** one compute platform's own routing primitive and adds orchestration, alarms, and rollback machinery on top. Remember the DR caveat from `references/resilience-migration.md`: changing weights is a **control-plane** operation, so health-check-driven failover is more resilient for disaster scenarios than manual weight changes.

### Rollback

> Source: https://docs.aws.amazon.com/codedeploy/latest/userguide/deployments-rollback-and-redeploy.html (official)

**The framing that matters:** "CodeDeploy rolls back deployments by redeploying a previously deployed revision of an application as a new deployment. **These rolled-back deployments are technically new deployments, with new deployment IDs, rather than restored versions of a previous deployment.**" Rollback is forward motion — a fresh deploy of known-good code, not a magic revert. Everything that must be true for a deploy to succeed must also be true for a rollback.

- **Automatic rollback** is configured at the deployment-group or deployment level and triggers "when a deployment fails or when a monitoring threshold you specify is met" — that is, a CloudWatch alarm. SNS can notify on it. **This is the architecturally preferred default for production pipelines.**
- **Manual rollback** — create a new deployment targeting a previously deployed revision. The fallback for states automatic detection cannot characterize, when troubleshooting would cost more than redeploying to known-good.

---

## Observability Architecture

### CloudWatch cross-account observability

> Source: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-Unified-Cross-Account.html (official)

"With Amazon CloudWatch cross-account observability, you can monitor and troubleshoot applications that span multiple accounts within a Region. Seamlessly search, visualize, and analyze your metrics, logs, traces, Application Signals services and service level objectives (SLOs), Application Insights applications, and internet monitors in any of the linked accounts without account boundaries."

**This is the correct answer whenever a scenario asks for a centralized logging and monitoring strategy across many accounts** without granting cross-account IAM access to the underlying resources. It is a purpose-built read-only observability plane, not a permissions workaround.

Model: one or more **monitoring accounts** linked to many **source accounts**. Shareable telemetry: CloudWatch metrics (all namespaces or filtered), log groups (all or filtered), **X-Ray traces**, Application Signals services and SLOs, Application Insights applications, and Internet Monitor monitors. A **sink** is the monitoring account's attachment point (one per account per Region); an **observability link** is the source account's side. Configure through the console or the **Observability Access Manager (OAM)** API.

**Use Organizations to link, verbatim:** "We recommend that you use Organizations so that new AWS accounts created later in the organization are automatically onboarded to cross-account observability as source accounts."

Scale and gotchas: a monitoring account links up to **100,000 source accounts**; a source account shares with up to **5 monitoring accounts**. Telemetry-type negotiation is an intersection — if the monitoring account selects more types than the source shares, only the overlap is shared; **if the source selects more types than the monitoring account accepts, link creation fails and nothing is shared.** Pricing: no extra charge for logs, metrics, or Application Signals sharing; **the first trace copy is free**.

### SLAs and KPIs as monitored objects

> Source: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/WhatIsCloudWatch.html (official)

CloudWatch "monitors your Amazon Web Services (AWS) resources and the applications you run on AWS in real time, and offers many tools to give you system-wide observability of your application performance, operational health, and resource utilization."

Three primitives compose into an SLA/KPI architecture:

- **Metrics** — "collect and track key performance data at user-defined intervals." Many services report automatically; publish custom metrics for business KPIs.
- **Dashboards** — "a unified view of your resources and applications with visualizations of your metrics and logs in a single location," shareable across accounts and Regions.
- **Alarms** — "continuously monitor CloudWatch metrics against user-defined thresholds," which "can automatically alert you to breaches of the thresholds, and can also automatically respond to changes in your resources' behavior by triggering automated actions." **Alarms are what turn a KPI threshold into an operational event** — notification or auto-remediation — and are therefore the direct answer to "how do we operationalize an SLA."

Purpose-built layers above raw metrics:

- **CloudWatch Application Signals** — "automatically detect and monitor your applications' key performance indicators like latency, error rates, and request rates without manual instrumentation," including native **Service Level Objectives**: "define, track, and alert on specific reliability targets for your applications... by setting error budgets and monitoring SLO compliance over time." This is the primitive to name for a literal SLA/SLO requirement.
- **CloudWatch Synthetics** — scripted canaries simulating user behavior to catch degradation proactively.
- **CloudWatch RUM** — real-user session performance data.

Org-wide SLA dashboards and alarms are built on the same monitoring-account/source-account link model above, not a separate mechanism: "From the central account, you can view metrics, logs, and traces from source accounts across your organization... set up alarms that watch metrics from multiple accounts."

### AWS X-Ray

> Source: https://docs.aws.amazon.com/xray/latest/devguide/aws-xray.html (official)

"AWS X-Ray is a service that collects data about requests that your application serves... For any traced request to your application, you can see detailed information not only about the request and response, but also about calls that your application makes to downstream AWS resources, microservices, databases, and web APIs."

X-Ray builds a **trace map**: "shows the client, your front-end service, and backend services that your front-end service calls... Use the trace map to identify bottlenecks, latency spikes, and other issues."

**Selection line:** X-Ray answers **distributed request tracing and service-map visualization across microservices**; CloudWatch answers metrics, logs, and alarms. They compose rather than compete — X-Ray traces are one of the telemetry types CloudWatch cross-account observability centralizes. Architecturally, client SDKs send segment documents to a local daemon over UDP which batches and uploads, keeping the application's hot path off the tracing backend; several services (Lambda among them) emit trace data or run the daemon for you.

---

## Systems Manager as the Configuration Surface

### Parameter Store vs AppConfig vs Secrets Manager

> Source: https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-parameter-store.html (official)

AWS's own comparison table:

| Feature | Parameter Store | AWS AppConfig | AWS Secrets Manager |
|---|---|---|---|
| Use cases | Static configuration; key-value storage without deployment or validation | Frequently changed application configuration; zero-downtime deployments; runtime experiments | Credentials or any other secrets; encrypted data requiring automatic rotation, cross-account access, or fine-grained audit logging |
| Typical data | Approved AMI IDs, environment variables, endpoint URLs, resource identifiers, tuning parameters | Feature flags, operational toggles, tunable parameters, allow/deny lists | Database credentials, API keys, OAuth tokens, private keys and certificates |
| Encryption | Optional with `SecureString` and KMS | AWS managed at rest; optional customer managed key | KMS at rest (AWS or customer managed) |
| Credential rotation | None | Not applicable | Automatic, with native database integrations |
| Cost | Standard tier free; advanced tier and higher throughput billed | Per configuration request | Per secret per month and per API call |
| Deployment | Versioning without pre-deployment validation or automatic rollback | **Gradual rollout, pre-deployment validation, and automatic rollback on CloudWatch alarms** | Versioning with staging labels |

Parameter types: `String`, `StringList`, `SecureString`. AWS's own guidance is explicit that `SecureString` does not substitute for Secrets Manager where rotation matters: "For secrets such as database credentials, API keys, or tokens, we recommend AWS Secrets Manager, which provides purpose built security controls including automatic rotation and cross-region replication."

**Tiers:** standard is free, capped at **10,000 parameters per account per Region**, **4 KB** max value, and **not shareable cross-account**. Advanced is billed, allows **100,000 parameters**, **8 KB** values, parameter policies, and **cross-account sharing**. Standard upgrades to advanced; **advanced does not downgrade**.

Composition worth knowing: Lambda reads via the Parameters and Secrets Lambda extension; ECS and Fargate inject parameters as environment variables; CloudFormation uses dynamic references; and **AppConfig can source its configuration from Parameter Store, Secrets Manager, or S3**, layering deployment safety on top of an existing value.

### AppConfig — the deployment-safety layer for configuration

> Source: https://docs.aws.amazon.com/appconfig/latest/userguide/what-is-appconfig.html (official)

"AWS AppConfig helps you safely change application behavior in production without redeploying code. Using feature flags and dynamic free-form configurations, you can control how your application runs in real time." Named use cases: A/B experimentation on production traffic, feature flags and toggles, application tuning, allow/block lists, centralized configuration storage.

The three safety controls are what justify it over bare Parameter Store: **validators** (syntactic and semantic checks before deployment), **deployment strategies** (gradual rollout over a defined window), and **monitoring with automatic rollback** — "AWS AppConfig integrates with Amazon CloudWatch to monitor application health. **If a configuration change triggers an alarm, AWS AppConfig automatically rolls back the change to minimize impact.**" That mirrors CodeDeploy's alarm-triggered rollback, applied to configuration data instead of code artifacts.

**Selection rule:** AppConfig whenever the change needs to be gradual, monitored, and auto-rollback-capable (feature flags, kill switches, operational toggles). Bare Parameter Store for static, infrequently changed configuration where that machinery is overhead.

### State Manager — drift enforcement

> Source: https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-state.html (official)

"State Manager is a secure and scalable configuration management service that automates the process of keeping your managed nodes and other AWS resources in a state that you define."

An **association** binds a desired state (for example "antivirus software must be installed and running") to a schedule (cron or rate, immediate or delayed) and to targets (tags, Resource Groups, node IDs, or all managed nodes in the account and Region). Combined with **Automation** runbooks it can also remediate non-node resources — enforcing security-group ingress and egress rules, deleting stale DynamoDB or EBS backups, correcting S3 bucket permissions.

**Versus Maintenance Windows**, in AWS's own framing: "Which one you choose depends on whether you need to automate system compliance [State Manager] or perform high-priority, time-sensitive tasks during periods you specify [Maintenance Windows]." State Manager is continuous compliance and drift correction; Maintenance Windows is the bounded-change-window tool.

Audience, verbatim: "State Manager is appropriate for any AWS customer that wants to improve the management and governance of their AWS resources and **reduce configuration drift**."

### Patch Manager

> Source: https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-patch.html (official)

"Patch Manager automates the process of patching managed nodes with both security-related updates and other types of updates" across EC2 fleets, edge devices, on-premises servers, and VMs, on Linux, macOS, and Windows Server. Windows application patching covers Microsoft-released applications only, and **Patch Manager does not support OS major-version upgrades** (RHEL 7 to 8, for example).

A **patch baseline** is the compliance contract: "you define what patch compliance means for managed nodes in your organization or account in a patch baseline... A managed node is patch compliant when it is up to date with all the patches that meet the approval criteria that you specify." AWS explicitly disclaims that compliant equals secure: "being compliant with a patch baseline doesn't mean that a managed node is necessarily secure... The overall security of a managed node is determined by many factors outside the scope of Patch Manager." Baselines auto-approve by classification and severity, or list explicit approved and rejected patch IDs. Operations are **`Scan`** (report only) or **`Scan and install`**.

**For an org-wide patching strategy, the answer is the Organizations-integrated patch policy:** "(Recommended) A patch policy configured in Quick Setup" — "a single patch policy can define patching schedules and patch baselines for an entire organization, including multiple AWS accounts and all AWS Regions those accounts operate in," optionally scoped to specific OUs. Every alternative method (Host Management via Quick Setup, a Maintenance Windows patch task, on-demand "Patch now") is scoped to a **single account and Region pair**.

Integrations that make patching a governance signal rather than a chore: findings feed **Security Hub CSPM** (patch compliance as a posture signal) and **AWS Config** (drift visibility), with actions recorded in **CloudTrail**.

## Sources

- https://docs.aws.amazon.com/wellarchitected/latest/operational-excellence-pillar/operational-excellence.html
- https://docs.aws.amazon.com/whitepapers/latest/practicing-continuous-integration-continuous-delivery/deployment-methods.html
- https://docs.aws.amazon.com/codedeploy/latest/userguide/deployment-configurations.html
- https://docs.aws.amazon.com/codedeploy/latest/userguide/deployments-rollback-and-redeploy.html
- https://docs.aws.amazon.com/AmazonECS/latest/developerguide/deployment-type-bluegreen.html
- https://docs.aws.amazon.com/lambda/latest/dg/configuring-alias-routing.html
- https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/routing-policy-weighted.html
- https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-Unified-Cross-Account.html
- https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/WhatIsCloudWatch.html
- https://docs.aws.amazon.com/xray/latest/devguide/aws-xray.html
- https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-parameter-store.html
- https://docs.aws.amazon.com/appconfig/latest/userguide/what-is-appconfig.html
- https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-state.html
- https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-patch.html

Fetched: 2026-08-08
