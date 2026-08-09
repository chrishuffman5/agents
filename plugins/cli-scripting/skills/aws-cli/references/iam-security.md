# IAM Security Operations via the CLI

Least privilege, credential hygiene, and the CLI commands that enforce them. Policy-language design and org-wide IAM architecture belong to the `aws-iam` skill in the `security` plugin; this file covers what a scripter runs.

---

## The posture, in AWS's order

> Source: https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html

The current official best-practices page leads with credentials, not passwords. In its own order:

1. **Require human users to use federation with an identity provider** so they get temporary credentials by assuming roles. IAM Identity Center is the named service for centralized access.
2. **Require workloads to use temporary credentials with IAM roles.** On AWS compute (EC2, Lambda, ECS), the platform delivers the role's credentials automatically — "no need to distribute long lived credentials for an IAM user to your workloads running on AWS." Off AWS: **IAM Roles Anywhere** (X.509), `sts:AssumeRoleWithSAML`, `sts:AssumeRoleWithWebIdentity` (the OIDC mechanism GitHub Actions uses), IoT Core mutual TLS, or ECS Anywhere / EKS Hybrid Nodes / SSM Hybrid Activations.
3. **Require MFA**, and prefer **phishing-resistant MFA — passkeys and security keys — "wherever possible,"** not only TOTP apps.
4. **Update access keys only when long-term credentials are truly required** (see the narrow legitimate list below).
5. **Protect root user credentials.**
6. **Apply least-privilege permissions**, iteratively: broad while exploring, narrowed as the use case matures.
7. **Start with AWS managed policies, then move to least privilege.** AWS managed policies "might not grant least-privilege permissions for your specific use cases because they are available for use by all AWS customers" — graduate to customer-managed policies.
8. **Use IAM Access Analyzer to generate least-privilege policies from activity.**
9. **Regularly review and remove unused users, roles, permissions, policies, and credentials** using last-accessed information.
10. **Use policy conditions to further restrict access** (e.g. require TLS).
11. **Verify public and cross-account access with Access Analyzer** before granting it.
12. **Validate policies** with Access Analyzer's 100+ policy checks.
13. **Establish guardrails across accounts with SCPs and RCPs** — with the explicit caveat that "No permissions are granted by SCPs and RCPs"; they only cap the ceiling. From the CLI, their only visible effect is an API call denied despite an allowing identity policy.
14. **Use permissions boundaries to delegate permissions management.**

Older "AWS IAM best practices" writeups that lead with password policy and root MFA are out of step with this ordering.

### Zero trust, stated honestly

> Source: https://docs.aws.amazon.com/prescriptive-guidance/latest/strategy-zero-trust-architecture/faq.html
> Source: https://docs.aws.amazon.com/prescriptive-guidance/latest/strategy-zero-trust-architecture/zero-trust-principles.html
> Source: https://docs.aws.amazon.com/prescriptive-guidance/latest/strategy-zero-trust-architecture/components.html

AWS defines zero trust as "a conceptual model and an associated set of mechanisms that focus on providing security controls around digital assets that do not solely or fundamentally depend on traditional network controls or network perimeters." There is no zero-trust checkbox in IAM, and the prescriptive-guidance pages never mention the AWS CLI.

Three of the six official principles are what CLI/IAM mechanics actually implement: **verify and authenticate** (continuous verification "ideally on each request" — what short-lived STS credentials give you, since a compromised session token self-expires while a static key does not), **least privilege access** (named mechanisms: just-in-time provisioning, RBAC, regular access reviews), and **automation and orchestration** ("automating access provisioning and deprovisioning processes" — the justification for scripting key rotation and unused-credential cleanup). Micro-segmentation, continuous monitoring/analytics, and the authorization enforcement-point layer are network, SIEM, and application concerns.

AWS names IAM as the foundation of a zero-trust architecture. Its zero-trust FAQ's service list is: AWS Verified Access, IAM, Amazon VPC, VPC Lattice, Amazon Verified Permissions, Amazon API Gateway, GuardDuty — IAM Identity Center is not named individually there. Claim that these mechanics implement zero-trust *principles*; do not claim they make an account zero trust.

---

## Access keys: when they are legitimate, and what to use instead

> Source: https://docs.aws.amazon.com/IAM/latest/UserGuide/security-creds-programmatic-access.html
> Source: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html

AWS's decision table for programmatic access:

| Who needs it | Recommendation | How |
|---|---|---|
| IAM user or root, interactive development | **(Recommended)** console credentials as temporary credentials | `aws login` |
| Workforce identity | IAM Identity Center temporary credentials | `aws configure sso` + `aws sso login` |
| Any workload / IAM role | temporary credentials | `sts:AssumeRole*` family, instance profiles, task roles |
| IAM user, static keys | **(Not recommended)** long-term access keys | last resort |

The **only** legitimate long-term-key use cases named by the best-practices page: workloads structurally unable to assume a role (e.g. a WordPress plugin), third-party AWS clients that don't support Identity Center and aren't hosted on AWS, AWS CodeCommit SSH/service-specific credentials (as a supplement to Identity Center, and avoidable entirely with `git-remote-codecommit`), and Amazon Keyspaces testing where the SigV4 plugin's temporary credentials aren't feasible. "Convenience" and "legacy scripts" are not on the list.

Official alternatives checklist: never embed keys in code or repos (use Secrets Manager); use IAM roles wherever possible, and **IAM Roles Anywhere** for off-AWS machines; use `aws login` or AWS CloudShell instead of local static keys; never create long-term keys for human users; never store long-term keys on AWS compute — attach a role.

Mechanics worth knowing: **maximum 2 access keys per IAM user** (by design, so rotation can overlap). The secret is shown **only once, at creation** — there is no retrieve-again API. The shared credentials file stores keys **in plaintext**. Access key ID prefixes are a free audit heuristic: **`AKIA…` is long-term** (IAM user or root), **`ASIA…` is temporary** (STS-issued). Grepping a config dump or CI environment for `AKIA` finds the problem.

### Rotation — the documented safe order

> Source: https://docs.aws.amazon.com/IAM/latest/UserGuide/id-credentials-access-keys-update.html

```bash
aws iam create-access-key --user-name "$USER"                       # 1. second key, active immediately
#    update every app / CI secret to the new key
aws iam get-access-key-last-used --access-key-id "$OLD_KEY"         # 2. confirm the old key has gone quiet
aws iam update-access-key --user-name "$USER" \
  --access-key-id "$OLD_KEY" --status Inactive                      # 3. DEACTIVATE first — reversible
#    verify nothing broke; flip back to Active if it did, fix the consumer, retry from step 2
aws iam delete-access-key --user-name "$USER" --access-key-id "$OLD_KEY"   # 4. only after a safe wait
```

Never jump from step 1 to step 4. Deactivation is reversible; deletion is not.

### IAM Roles Anywhere (on-prem and other clouds)

> Source: https://docs.aws.amazon.com/rolesanywhere/latest/userguide/introduction.html
> Source: https://docs.aws.amazon.com/rolesanywhere/latest/userguide/credential-helper.html

Workloads outside AWS get temporary credentials using the *same* IAM roles and policies as native workloads, authenticating with X.509 certificates from a CA you register as a **trust anchor**. Three objects: trust anchor (the registered CA), role (must trust the Roles Anywhere service principal, tied to a trust anchor through `aws:SourceArn` in its trust policy), and profile (which roles a trust anchor may assume, plus an optional session policy that only narrows). All resources are regional and must share an account and region. **The trust boundary is account-level**: absent extra conditions in a role's trust policy, any certificate from any trust anchor in the account can assume any role in it.

AWS ships an `aws_signing_helper` binary that speaks the `credential_process` contract:

```ini
[profile developer]
credential_process = ./aws_signing_helper credential-process --certificate /path/cert.pem --private-key /path/key.pem --trust-anchor-arn arn:aws:rolesanywhere:<region>:<acct>:trust-anchor/<id> --profile-arn arn:aws:rolesanywhere:<region>:<acct>:profile/<id> --role-arn arn:aws:iam::<acct>:role/<role>
region = <region>
```

Required flags: `--certificate`, `--private-key` (both may be `pkcs11:` URIs for an HSM/YubiKey, or a TPM-wrapped key / `handle:0x…`; omit `--private-key` when using `--cert-selector` against a Windows or macOS certificate store), `--profile-arn`, `--role-arn`, `--trust-anchor-arn`. `--session-duration` accepts 900–43200 seconds. Two other modes exist: `serve` vends credentials on `127.0.0.1:9911` in an IMDSv2-compatible shape with auto-refresh (any local process that can reach the loopback port gets the credentials — set `--hop-limit 1` to stop containers proxying them), and `update` writes credentials into `~/.aws/credentials` on a refresh loop (on disk, and concurrent runs can corrupt the file).

---

## Least-privilege tooling reachable from the CLI

> Source: https://docs.aws.amazon.com/IAM/latest/UserGuide/what-is-access-analyzer.html

Access Analyzer bundles six separately-enabled, separately-priced capabilities: **external access** (resources reachable from outside your zone of trust), **internal access** (which internal principals reach named critical resources), **unused access** (unused roles, access keys, console passwords, and service/action-level permissions — the capability that operationalizes best-practice #9), **policy validation** (100+ checks), **custom policy checks** (validate against your own standard, or detect whether an edit grants *new* access), and **policy generation from CloudTrail**.

The "zone of trust" is the account or organization designated when the analyzer is created; access inside it is never flagged. External-access analyzers are **regional** — create one per region for full coverage. New or changed policies are normally analyzed within ~30 minutes (up to 6 hours for multi-region S3 access points, up to 24 hours if CloudTrail delivery is delayed); force a check with `StartResourceScan`.

### Policy generation from activity

> Source: https://docs.aws.amazon.com/IAM/latest/UserGuide/access-analyzer-policy-generation.html
> Source: https://docs.aws.amazon.com/cli/latest/reference/accessanalyzer/start-policy-generation.html
> Source: https://docs.aws.amazon.com/cli/latest/reference/accessanalyzer/get-generated-policy.html

Reviews up to **90 days** of CloudTrail history for one IAM user or role and drafts a policy from the actions actually observed. Action-level fidelity where CloudTrail attributes actions (e.g. EC2); service-level only elsewhere, leaving you to pick actions per flagged service.

```bash
JOB=$(aws accessanalyzer start-policy-generation \
  --policy-generation-details '{"principalArn":"arn:aws:iam::111122223333:role/Admin"}' \
  --cloud-trail-details file://trail.json \
  --query jobId -o text)

aws accessanalyzer get-generated-policy --job-id "$JOB" \
  --include-resource-placeholders          # emits arn:aws:s3:::${BucketName}-style placeholders to fill in
aws accessanalyzer cancel-policy-generation --job-id "$JOB"
```

`trail.json` shape — `trails` and `accessRole` and `startTime` are required, `endTime` defaults to now:

```json
{ "accessRole": "arn:aws:iam::111122223333:role/service-role/AccessAnalyzerMonitorServiceRole",
  "startTime": "2026-02-13T00:30:00Z",
  "trails": [{ "allRegions": true, "cloudTrailArn": "arn:aws:cloudtrail:us-west-2:111122223333:trail/my-trail" }] }
```

`get-generated-policy` is a **job**, not a synchronous call: poll `jobDetails.status` until it leaves `IN_PROGRESS` (`SUCCEEDED` / `FAILED` / `CANCELED`) before reading `generatedPolicyResult.generatedPolicies[].policy`. `--include-service-level-template` adds statements derived from service-last-accessed data.

**Known gaps — never auto-attach a generated policy.** Data events are not covered (S3 object-level `GetObject`/`PutObject` never surfaces at action level). **`iam:PassRole` is never tracked by CloudTrail** and will never appear — add it by hand. AWS says explicitly: "Do not use policy generation for auditing purposes; use CloudTrail instead." AWS Control Tower organization trails are unsupported as the source.

### Credential report — account-wide inventory

> Source: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_getting-report.html

```bash
aws iam generate-credential-report                    # STARTED | INPROGRESS | COMPLETE
aws iam get-credential-report --query Content -o text | base64 -d > report.csv
```

One report per account; regenerating overwrites it. **4-hour cache**: a generation request within 4 hours of the last one returns the existing report instead of a fresh one.

CSV columns for scripted triage: `user, arn, user_creation_time, password_enabled, password_last_used, password_last_changed, password_next_rotation, mfa_active, access_key_1_active, access_key_1_last_rotated, access_key_1_last_used_date, access_key_1_last_used_region, access_key_1_last_used_service, access_key_2_* (same five), cert_1_active, cert_1_last_rotated, cert_2_active, cert_2_last_rotated, additional_credentials_info`. Screen for `mfa_active=false`, stale `access_key_N_last_rotated`, and `access_key_N_active=true` with an empty `last_used_date`.

Coverage gaps to state rather than assume away: the report covers passwords, **the first two access keys per user**, MFA devices, and X.509 signing certificates only — not service-specific credentials (CodeCommit git credentials, long-term service API keys). Use `list-service-specific-credentials` / `list-access-keys` for full visibility. Last-used timestamps collapse repeated use into one value (5-minute window for passwords, 15-minute for access keys), so they are not exact.

### Service last-accessed data

> Source: https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies_last-accessed-view-data.html

Finer-grained than the credential report, and applies to users, groups, roles, and policies:

```bash
JOB=$(aws iam generate-service-last-accessed-details --arn "$ARN" \
  --granularity ACTION_LEVEL --query JobId -o text)
aws iam get-service-last-accessed-details --job-id "$JOB"                 # poll JobStatus
aws iam get-service-last-accessed-details-with-entities --job-id "$JOB" --service-namespace s3
aws iam list-policies-granting-service-access --arn "$ARN" --service-namespaces s3
```

Retention is **400 days**. Action-level granularity exists only for a subset of services (S3 tracked since 2020-04-12; EC2, IAM, and Lambda since 2021-04-07; broader coverage since 2023-05-23) — everything else is service-level only. `list-policies-granting-service-access` is a live current-state lookup that **ignores resource-based policies, SCPs, permissions boundaries, and session policies**, so it can report a grant that is actually blocked. AWS's own caution: "You should not make permissions decisions based solely on the absence of tracking information."

### Policy simulation — dry-run authorization

> Source: https://docs.aws.amazon.com/cli/latest/reference/iam/simulate-principal-policy.html

```bash
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::123456789012:user/alejandro \
  --action-names s3:PutObject --resource-arns 'arn:aws:s3:::my-bucket/*'

# with a condition context value, e.g. testing an MFA- or time-gated policy without live-testing it
aws iam simulate-principal-policy --policy-source-arn "$ARN" --action-names dynamodb:CreateBackup \
  --context-entries ContextKeyName=aws:MultiFactorAuthPresent,ContextKeyValues=true,ContextKeyType=boolean
```

`--resource-arns` defaults to `*` if omitted. Other useful flags: `--caller-arn`, `--resource-policy`, `--policy-input-list` (extra ad-hoc policies layered in), `--permissions-boundary-policy-input-list`, `--policy-exclusion-list`. Output is an `EvaluationResults` array with `EvalDecision` (`allowed` | `explicitDeny` | `implicitDeny`) plus `MatchedStatements` identifying the deciding statement — ideal for CI policy checks.

Use `simulate-principal-policy` against a real identity's attached policies; note it **discloses that principal's real permissions to the caller**. Use `simulate-custom-policy` to test arbitrary policy JSON with no live identity involved — the safer option to expose to end users.

---

## Permissions boundaries

> Source: https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies_boundaries.html

A managed policy attached to a user or role that sets the *maximum* permissions an identity-based policy can grant. It never grants anything by itself. Effective permissions are the **intersection** of the identity-based policy and the boundary; an explicit `Deny` in either wins. If the identity policy allows `iam:CreateUser` but the boundary omits IAM entirely, the call is denied.

Interaction summary: SCPs ∩ boundary ∩ identity-based policy; session policies intersect too. A resource-based policy addressed to a *role session* ARN (rather than the role ARN) is granted directly to the session and is **not** limited by the boundary's implicit deny.

CLI-relevant use: attach with `iam:PutUserPermissionsBoundary` / `iam:PutRolePermissionsBoundary` (by policy ARN, like a managed policy). The standard guardrail for scripted identity provisioning is a condition on the delegate's own policy requiring `iam:PermissionsBoundary` to `StringEquals` a specific boundary ARN on `iam:CreateUser`/`iam:CreateRole` — the delegate then becomes structurally incapable of creating an identity without the boundary, and the CLI call fails otherwise. Also deny them `iam:DeleteUserPermissionsBoundary`.

Sharp edge from IAM's own docs: never combine a resource-based `Deny` + `NotPrincipal` with principals carrying a boundary — that combination denies any boundary-carrying principal regardless of the `NotPrincipal` values. Use `Condition: {"ArnNotEquals": {"aws:PrincipalArn": …}}` instead.

Boundary *design* (what a boundary should contain for an organization) is `security:aws-iam` territory.

---

## Root user

> Source: https://docs.aws.amazon.com/IAM/latest/UserGuide/root-user-best-practices.html
> Source: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_root-user.html
> Source: https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/sec_securely_operate_aws_account.html

"We strongly recommend you don't access the AWS account root user unless you have a task that requires root user credentials." A CLI skill should never instruct anyone to create root access keys — **for root programmatic access, use `aws login` with root credentials** instead.

- **MFA on root is required for all account types** (standalone, management, member); up to 8 devices can be registered, and AWS recommends registering more than one. Users must register MFA within 35 days of first console sign-in. Prefer FIDO security keys or hardware TOTP tokens.
- Split MFA custody from password custody across two people; use a group email address for the root account; restrict access to recovery email and phone separately.
- Organizations member accounts can have root credentials **deleted entirely** (new member accounts have none by default). Limited privileged tasks are then performed from the management or delegated-admin account via `sts:AssumeRoot`, with no standing root credentials anywhere.
- Deny root actions in member accounts with an SCP; alarm on root usage (CloudTrail logs root sign-in and `sts:AssumeRoot` distinctly; GuardDuty has a `RootCredentialUsage` finding).
- The tasks that genuinely require root are a fixed, short list: changing account settings on standalone accounts, closing a standalone account, restoring locked-out IAM administrator permissions, activating IAM access to Billing, GovCloud sign-up, EC2 RI Marketplace seller registration, KMS key recovery via Support, and fixing an S3/SQS resource policy that denies everyone. Everything else goes through Identity Center or a role.
- Well-Architected SEC01-BP02 rates failure to establish this as **High** risk, cross-referenced to CIS AWS Foundations v1.4.0 controls 1.4 (no root access keys), 1.5/1.6 (root MFA), and 1.7 (alarm on root usage).

Script guardrail: `aws sts get-caller-identity` returns an ARN of the form `arn:aws:iam::<account>:root` for a root session. Fail fast on it.

---

## Sources

- https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html
- https://docs.aws.amazon.com/IAM/latest/UserGuide/security-creds-programmatic-access.html
- https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html
- https://docs.aws.amazon.com/IAM/latest/UserGuide/id-credentials-access-keys-update.html
- https://docs.aws.amazon.com/IAM/latest/UserGuide/what-is-access-analyzer.html
- https://docs.aws.amazon.com/IAM/latest/UserGuide/access-analyzer-policy-generation.html
- https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_getting-report.html
- https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies_last-accessed-view-data.html
- https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies_boundaries.html
- https://docs.aws.amazon.com/IAM/latest/UserGuide/root-user-best-practices.html
- https://docs.aws.amazon.com/IAM/latest/UserGuide/id_root-user.html
- https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/sec_securely_operate_aws_account.html
- https://docs.aws.amazon.com/cli/latest/reference/iam/simulate-principal-policy.html
- https://docs.aws.amazon.com/cli/latest/reference/accessanalyzer/start-policy-generation.html
- https://docs.aws.amazon.com/cli/latest/reference/accessanalyzer/get-generated-policy.html
- https://docs.aws.amazon.com/cli/latest/reference/accessanalyzer/cancel-policy-generation.html
- https://docs.aws.amazon.com/rolesanywhere/latest/userguide/introduction.html
- https://docs.aws.amazon.com/rolesanywhere/latest/userguide/credential-helper.html
- https://docs.aws.amazon.com/prescriptive-guidance/latest/strategy-zero-trust-architecture/zero-trust-principles.html
- https://docs.aws.amazon.com/prescriptive-guidance/latest/strategy-zero-trust-architecture/components.html
- https://docs.aws.amazon.com/prescriptive-guidance/latest/strategy-zero-trust-architecture/faq.html

Fetched: 2026-08-08
