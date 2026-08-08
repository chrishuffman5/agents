---
name: aws-cli
description: "AWS CLI v2 command syntax and scripting: secure authentication (aws login, Identity Center SSO, assume-role profiles, instance/task roles), output formats, JMESPath queries, pagination, waiters, IAM operations, S3, Lambda, RDS, CloudFormation, ECS, EKS, CloudWatch, SSM, Route 53, STS, VPC networking. WHEN: \"aws \", \"AWS CLI\", \"aws configure\", \"aws sso\", \"aws login\", \"aws ec2\", \"aws s3\", \"aws lambda\", \"aws iam\", \"aws cloudformation\", \"aws ssm\", \"aws ecs\", \"aws eks\", \"aws rds\", \"aws cloudwatch\", \"aws route53\", \"aws sts\". Do NOT use for AWS architecture, service selection, multi-account strategy, or FinOps — that's the `cloud-platforms` plugin. Do NOT use for IAM policy design, SCP/permission-set architecture, or org-wide IAM strategy — that's the `aws-iam` skill in the `security` plugin. This skill covers command syntax and scripting the CLI, not deciding what to provision."
license: MIT
---

# AWS CLI v2

The `aws` client for every AWS service. This skill owns CLI mechanics: authenticating without long-lived secrets, shaping output for scripts, waiting on async operations, and writing commands that survive contact with a real account.

## Routing

| Request | Load |
|---|---|
| Sign-in, profiles, SSO, assume-role, credential precedence, `credential_process`, env vars | `references/auth.md` |
| Least privilege, key rotation, credential audit, Access Analyzer, policy simulation, boundaries | `references/iam-security.md` |
| Output formats, `--query`/JMESPath, pagination, pager, waiters, retry and config settings | `references/core.md` |
| Per-service command syntax (IAM, S3, Lambda, RDS, CloudFormation, ECS, EKS, CloudWatch, SSM, Route 53, STS, VPC) | `references/commands.md` |
| Idempotent create, batch loops, provisioning and teardown scripts | `references/patterns.md` |

Always verify identity before any mutating command: `aws sts get-caller-identity`. It requires no permissions and cannot be denied by policy, so it is the one reliable "which account and principal am I?" probe.

## Authenticate without long-lived keys

AWS publishes an explicit, ordered recommendation list for how the CLI should obtain credentials. Work top-down and stop at the first row that applies. The last two rows carry AWS's own "(Not recommended)" label.

| Rank | Method | How |
|---|---|---|
| 1 | Console credentials as short-term credentials | `aws login` (CLI ≥ 2.32.0) |
| 2 | IAM Identity Center workforce short-term credentials | `aws configure sso` + `aws sso login` |
| 3 | IAM user short-term credentials | `aws sts get-session-token` / `aws configure mfa-login` |
| 4 | Role on an EC2 instance or container | instance profile / ECS task role, no config at all |
| 5 | Assume a role for elevated access | `role_arn` + `source_profile` / `credential_source` profile |
| 6 | IAM user long-term access keys | **(Not recommended)** |
| 7 | Credentials in external storage via `credential_process` | **(Not recommended)** — only as secure as the external store |

The IAM best-practices page states the same posture from the identity side: require human users to use federation with temporary credentials, and require workloads to use IAM roles. IAM Identity Center is the service AWS names for centralized human access.

```bash
# Humans, no Identity Center in the account (root, IAM user, or console federation)
aws login                                  # browser PKCE flow, no keys created
aws login --profile dev                    # named profile
aws login --remote                         # headless/SSH: prints URL, prompts for pasted code
aws logout --all                           # clear every login-backed profile

# Humans, Identity Center account (the primary path when it exists)
aws configure sso                          # writes an [sso-session] block + profile
aws sso login --sso-session my-sso         # one login covers every profile on that session
aws sso logout                             # signs out of ALL sso profiles; no --profile flag

# Workloads
#   EC2 / Lambda / ECS: attach a role. No credential config, no keys, auto-rotated.
#   Off-AWS CI: sts:AssumeRoleWithWebIdentity (OIDC) or IAM Roles Anywhere (X.509).
```

Never write `aws iam create-access-key` into a default workflow, and never create access keys for the root user — `aws login` with root console credentials is AWS's documented replacement for root programmatic access. Creating an IAM user with a console password and an access key is a documented exception (workloads that structurally cannot assume a role, third-party clients without Identity Center support, CodeCommit credentials, Keyspaces testing), not the default example. See `references/iam-security.md` before writing one.

`aws login` and `aws configure sso` are different paths: `aws login` reuses AWS Management Console sign-in for accounts *without* Identity Center; if Identity Center exists, use it instead.

## Credential precedence is the top source of "wrong account" bugs

Highest wins; the CLI takes the first fully-specified source and does not merge or fall back:

command-line options → environment variables → assume role → assume role with web identity → IAM Identity Center → `~/.aws/credentials` → `credential_process` → `~/.aws/config` → container credentials (ECS task role) → EC2 instance profile (IMDS)

Diagnose with `aws configure list` — the `TYPE` column names the winning source (`env`, `shared-credentials-file`, `login`, `config-file`). AWS has **not** published where `aws login` credentials rank; the one documented fact is that stale static keys in `~/.aws/credentials` shadow a profile's `login_session`, which is exactly why `aws login` "succeeds" and then returns `ExpiredToken`.

## Least privilege by default

Grant the permissions a task needs, then narrow. AWS managed policies are a starting point and are explicitly not least-privilege; graduate to customer-managed policies scoped to the actual use case.

```bash
# What does this principal actually use? (CloudTrail-derived draft policy, then hand-review)
aws accessanalyzer start-policy-generation \
  --policy-generation-details '{"principalArn":"arn:aws:iam::111122223333:role/Admin"}' \
  --cloud-trail-details file://trail.json          # {accessRole, startTime, trails:[{cloudTrailArn, allRegions}]}
aws accessanalyzer get-generated-policy --job-id "$JOB_ID"   # poll status until it leaves IN_PROGRESS

# Will this call be allowed? (no live blast radius)
aws iam simulate-principal-policy --policy-source-arn arn:aws:iam::111122223333:user/alice \
  --action-names s3:PutObject --resource-arns arn:aws:s3:::my-bucket/*

# Account-wide credential hygiene snapshot (cached up to 4 hours)
aws iam generate-credential-report && aws iam get-credential-report --query Content --output text | base64 -d
```

Never auto-attach a generated policy. Policy generation skips data events entirely and never sees `iam:PassRole`, because CloudTrail does not record it. Absence from last-accessed data is not proof a permission is unused — AWS says so explicitly.

Zero trust, in AWS's own words, is "a conceptual model and an associated set of mechanisms," not a product or a checkbox. The honest claim for a CLI user is that short-lived credentials, least-privilege policies, and scripted credential lifecycle implement zero-trust *principles* — not that running them makes an account zero trust.

## Output and `--query` for scripting

```bash
export AWS_PAGER=""                        # or --no-cli-pager per command
```
CLI v2 pipes **all** output through the OS pager (`less`/`more`) by default — new in v2, and a real hazard in scripts and CI. Kill it with `AWS_PAGER=""`, `cli_pager =` in the profile, or `--no-cli-pager`.

Output formats: `json` (default), `yaml`, `yaml-stream` (incremental, for large responses), `text` (tab-delimited), `table`, and `off` (suppresses stdout entirely — use it in CI when only the exit code matters, instead of `> /dev/null`).

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
VPC_ID=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 --query 'Vpc.VpcId' -o text)
```

Three `--query` traps that silently corrupt scripted output:

- **`--output text` paginates before `--query` runs**, applying the query once per page. `json`/`yaml`/`yaml-stream` process the whole response as one structure first. Any aggregate — `[0]`, `length()`, `sum()`, `sort_by` across the full result — must use JSON output (pipe to `jq`), never `text`. A `sum(Contents[].Size)` over a large bucket emits one partial sum *per 1000-object page*.
- **Missing values render as the literal string `None`** when `--query` names a key that turns out to be null. Compare against `"None"`, not the empty string. A bare `--output text` walk instead leaves an empty tab-separated field.
- **Mismatched `--page-size` and `--max-items`** can produce missing or duplicated items. Use the same value for both, or fetch everything and slice locally.

Filter server-side first (`--filters`, service-specific flags — applied before data leaves AWS), then refine client-side with `--query`.

## Waiters, never sleep

`aws <service> wait <condition>` polls the API correctly; sleep loops are fragile and wasteful.

```bash
aws ec2 wait instance-running --instance-ids i-0123456789abcdef0
aws ec2 wait vpc-available --vpc-ids "$VPC_ID"
aws rds wait db-instance-available --db-instance-identifier my-db
aws cloudformation wait stack-create-complete --stack-name my-stack
aws ecs wait services-stable --cluster prod --services my-api      # 15s interval, 40 attempts, exit 255 on timeout
aws lambda wait function-active-v2 --function-name my-func         # 1s/300 via GetFunction; the non-v2 form is 5s/60
aws eks wait addon-active --cluster-name prod --addon-name vpc-cni
aws route53 wait resource-record-sets-changed --id "$CHANGE_ID"    # 30s interval, 60 attempts
```

Wait on everything asynchronous: `create-addon`, `create-change-set` (`cloudformation wait change-set-create-complete`, before describing or executing it), `update-function-configuration`, and `change-resource-record-sets`. A waiter that times out exits 255 — check it under `set -e`.

## Never hardcode a service version

Engine and Kubernetes versions age out of support on a fixed clock, so a pinned literal in a script becomes a hard failure. Discover instead:

```bash
aws eks describe-cluster-versions --query 'clusterVersions[?defaultVersion].clusterVersion' -o text
aws rds describe-db-engine-versions --default-only --engine postgres \
  --query 'DBEngineVersions[0].EngineVersion' -o text
```

Or omit the version flag and let the service pick its current default. EKS minor versions get 14 months of standard support plus 12 months of extended support, then force-upgrade.

## Pitfalls

1. **Pager blocks or garbles script output** — v2 pages all output by default → set `AWS_PAGER=""` at the top of every script.
2. **`--query` + `--output text` returns duplicated or partial aggregates** — text output paginates before the query → use JSON output plus `jq` for anything aggregate.
3. **`aws login` succeeds but calls fail with `ExpiredToken`** — leftover static keys in `~/.aws/credentials` outrank `login_session` → `aws configure list`, then delete the stale entry.
4. **Role-chained session dies after an hour** — assuming a role *from* an assumed role caps the session at 1 hour flat, regardless of `--duration-seconds` → assume the target role directly from the base identity, or budget for one hour.
5. **`aws lambda invoke --payload` rejects raw JSON** — v2 defaults `cli_binary_format` to `base64` → add `--cli-binary-format raw-in-base64-out`.
6. **`aws s3 rb --force` fails on a versioned bucket** — `--force` does not delete versioned objects → delete versions with `s3api delete-object --version-id` first.
7. **Bucket lands in the wrong region** — `s3api create-bucket` defaults to `us-east-1`; every other region needs `--create-bucket-configuration LocationConstraint=<region>`.
8. **Presigned URL rejected as too long-lived** — v2 signs S3 with SigV4 only, capping `--expires-in` at 604800 seconds (7 days).
9. **`aws ecs update-service` errors on an unknown option** — `update-service` takes `--service`; only `create-service` takes `--service-name`.
10. **`--no-fail-on-empty-changeset` on `cloudformation deploy`** — redundant in v2, which already exits 0 on an empty changeset; `--fail-on-empty-changeset` restores the v1 behavior.
11. **`aws ssm start-session` does nothing** — the Session Manager plugin is a separate client-side install, not part of the CLI.
12. **Cross-region command hits the wrong region** — precedence is `--region` > `AWS_REGION` > `AWS_DEFAULT_REGION` > profile. Set `AWS_REGION` in scripts shared with other AWS SDKs.
13. **A hardcoded AZ suffix targets the wrong zone** — AZ letters map to different physical zones per account → discover with `aws ec2 describe-availability-zones`.
14. **Secrets land in plaintext** — use `--type SecureString` for SSM parameters, and never commit `~/.aws/credentials`; the shared credentials file stores keys unencrypted.

## Scripts

- `scripts/01-aws-provision.sh` — end-to-end VPC / subnets / IGW / route table / security group / EC2 provisioning with tag-driven teardown. Demonstrates pager safety, AZ discovery, AMI discovery, and waiter usage. Run with `--cleanup` to tear down.

## References

- `references/auth.md` — credential precedence, `aws login`, IAM Identity Center, assume-role profiles, `credential_process` and `export-credentials`, env vars, config-file mechanics, secure-storage guidance.
- `references/iam-security.md` — least-privilege tooling (Access Analyzer, credential report, service-last-accessed, policy simulation), access-key rotation, permissions boundaries, root-user rules, IAM Roles Anywhere.
- `references/core.md` — output formats, JMESPath catalog, pagination, pager, waiters, retry modes and scripting-relevant config settings.
- `references/commands.md` — per-service command reference with verified flags and defaults.
- `references/patterns.md` — idempotent create, batch operations, provisioning and cleanup patterns.

## Sources

- https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-authentication.html
- https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html
- https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sign-in.html
- https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sso.html
- https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html
- https://docs.aws.amazon.com/cli/latest/userguide/cli-usage-output.html
- https://docs.aws.amazon.com/cli/latest/userguide/cli-usage-output-format.html
- https://docs.aws.amazon.com/cli/latest/userguide/cli-usage-filter.html
- https://docs.aws.amazon.com/cli/latest/userguide/cli-usage-pagination.html
- https://docs.aws.amazon.com/cli/latest/userguide/cliv2-migration-changes.html
- https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html
- https://docs.aws.amazon.com/IAM/latest/UserGuide/root-user-best-practices.html
- https://docs.aws.amazon.com/IAM/latest/UserGuide/security-creds-programmatic-access.html
- https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_manage-assume.html
- https://docs.aws.amazon.com/IAM/latest/UserGuide/access-analyzer-policy-generation.html
- https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_getting-report.html
- https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies_last-accessed-view-data.html
- https://docs.aws.amazon.com/prescriptive-guidance/latest/strategy-zero-trust-architecture/faq.html
- https://docs.aws.amazon.com/cli/latest/reference/accessanalyzer/start-policy-generation.html
- https://docs.aws.amazon.com/cli/latest/reference/iam/simulate-principal-policy.html
- https://docs.aws.amazon.com/cli/latest/reference/sts/get-caller-identity.html
- https://docs.aws.amazon.com/cli/latest/reference/lambda/invoke.html
- https://docs.aws.amazon.com/cli/latest/reference/lambda/wait/function-active-v2.html
- https://docs.aws.amazon.com/cli/latest/reference/ecs/update-service.html
- https://docs.aws.amazon.com/cli/latest/reference/ecs/wait/services-stable.html
- https://docs.aws.amazon.com/cli/latest/reference/cloudformation/deploy.html
- https://docs.aws.amazon.com/cli/latest/reference/route53/wait/resource-record-sets-changed.html
- https://docs.aws.amazon.com/cli/latest/reference/s3/rb.html
- https://docs.aws.amazon.com/cli/latest/reference/s3/presign.html
- https://docs.aws.amazon.com/cli/latest/reference/s3api/create-bucket.html
- https://docs.aws.amazon.com/cli/latest/reference/ec2/wait/index.html
- https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html
- https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/PostgreSQL.Concepts.General.DBVersions.html
- https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-sessions-start.html
- https://github.com/chrishuffman5/awscliskills (commit ddab56be22be966ed9ba1b4b831526f95e3c801b)

Fetched: 2026-08-08
