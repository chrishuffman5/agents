# AWS CLI Authentication and Credentials

How the CLI decides who you are, and how to make that decision use temporary credentials.

---

## Recommendation order (AWS's own published ranking)

> Source: https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-authentication.html

The authentication chapter publishes an ordered "options are in order of recommendation" table:

1. **AWS Management Console credentials** — `aws login`. "(Recommended). Use short-term credentials by logging into the AWS CLI with your console credentials." For root, IAM users, or federation with IAM.
2. **IAM Identity Center workforce short-term credentials** — "Security best practice is to use AWS Organizations with IAM Identity Center."
3. **IAM user short-term credentials** — "more secure than long-term credentials. If your credentials are compromised, there is a limited time they can be used before they expire."
4. **IAM/Identity Center users on an EC2 instance** — instance metadata plus an attached role.
5. **Assume roles for permissions** — pair another method with a role assumption.
6. **IAM user long-term credentials** — **"(Not recommended)"**.
7. **External storage of credentials** (`credential_process` pointed at a vault) — **"(Not recommended)"**: "only as secure as the external location."

Row 7 is the surprising one: `credential_process` is not automatically a "secure" pattern in AWS's framing. It inherits the security of whatever it shells out to.

The IAM User Guide's best-practices page states the same posture from the identity side: require human users to use federation with temporary credentials (IAM Identity Center is the named mechanism for centralized access), and require workloads to use IAM roles.

> Source: https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html

---

## Credential and configuration precedence

> Source: https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html
> Source: https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-authentication.html

Published verbatim and identically on both pages, highest priority first:

1. Command line options (`--region`, `--output`, `--profile`)
2. Environment variables
3. Assume role (profile config or `sts assume-role`)
4. Assume role with web identity
5. AWS IAM Identity Center (config written by `aws configure sso`, activated by `aws sso login`)
6. Credentials file (`~/.aws/credentials`)
7. Custom process (`credential_process`)
8. Configuration file (`~/.aws/config`)
9. Container credentials (ECS task role)
10. EC2 instance profile credentials (IMDS)

The CLI resolves from the highest-precedence *fully specified* source and does not merge or partially fall back.

**Where `aws login` sits is undocumented.** The numbered list predates the feature and does not mention `login_session`. The one written statement is from the sign-in page's own troubleshooting section: credentials in the shared credentials file "[have] precedence over the login credentials." Do not assert a rank beyond that.

> Source: https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sign-in.html

Endpoint/region resolution follows a **separate** precedence chain (`--endpoint-url`, `AWS_ENDPOINT_URL`, per-service `endpoint_url` in a `services` section). Correct credential precedence does not guarantee the right endpoint. Also: a profile that assumes a role via `source_profile` does **not** inherit the source profile's `services`/`endpoint_url` configuration — only its credentials.

Diagnose everything with `aws configure list`, whose `TYPE` column names the winning source:

```
NAME       : VALUE                : TYPE                    : LOCATION
profile    : <not set>            : None                    : None
access_key : ****************ABCD : shared-credentials-file :
region     : us-west-2            : env                     : AWS_DEFAULT_REGION
```

This is a fixed-width human table, not structured output — `--query`/`--output` do not apply to `aws configure` subcommands. Scripts needing the resolved credentials programmatically should use `aws configure export-credentials --format process`, which emits JSON.

> Source: https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html

---

## `aws login` — console credentials, no access keys (CLI ≥ 2.32.0)

> Source: https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sign-in.html
> Source: https://docs.aws.amazon.com/cli/latest/reference/login/

Reuses an existing AWS Management Console sign-in (root, IAM user, or IAM-federated identity) to mint short-term CLI/SDK credentials through a browser OAuth 2.0 authorization-code-with-PKCE flow. No access keys are created or stored. This is AWS's documented replacement for creating root access keys.

**Use it when the account has no IAM Identity Center.** If Identity Center exists, the prerequisites page redirects you to `aws configure sso` instead.

```bash
aws login                          # default profile
aws login --profile dev            # named profile
aws login --remote                 # no local browser (SSH, firewalled callback port): prints a URL, prompts for a pasted code
aws logout [--profile dev | --all]
```

- Requires CLI ≥ 2.32.0. Non-root IAM identities need the AWS managed policy `SignInLocalDevelopmentAccess`; root needs nothing extra.
- Writes `login_session = arn:aws:iam::<acct>:user/<name>` into the profile block in `~/.aws/config`.
- Cache: `~/.aws/login/cache` (`%USERPROFILE%\.aws\login\cache` on Windows), overridable with `AWS_LOGIN_CACHE_DIRECTORY`.
- Auto-refreshes every 15 minutes, up to the principal's session duration, hard-capped at 12 hours; then re-run `aws login`.
- Policy authors gate this with `signin:AuthorizeOAuth2Access` / `signin:CreateOAuth2Token`. Two resource ARNs separate same-device from cross-device use: `.../oauth2/public-client/localhost` and `.../oauth2/public-client/remote`. CloudTrail events: `AuthorizeOAuth2Access`, `CreateOauth2Token`.
- If an Organization has centralized root access and deleted a member account's root credentials, root login to that member account is denied — including via `aws login`.

**Troubleshooting**: `ExpiredToken`/`AccessDeniedException` right after a successful `aws login` almost always means stale static keys in `~/.aws/credentials` for the same profile are winning. `aws configure list --profile <name>` should show `TYPE: login`; anything else means remove the conflicting entry.

Bridge login credentials into tools that don't understand `login_session`:

```ini
[profile signin]
login_session = arn:aws:iam::012345678901:user/username
region = us-east-1

[profile process]
credential_process = aws configure export-credentials --profile signin --format process
region = us-east-1
```

---

## IAM Identity Center

> Source: https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sso.html
> Source: https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sso-concepts.html

Two configuration shapes exist. **Always generate the `sso-session` shape**; the legacy flat shape explicitly "[does not support] automated token refresh."

```ini
[profile dev]
sso_session = my-sso
sso_account_id = 111122223333
sso_role_name = SampleRole
region = us-west-2

[profile prod]
sso_session = my-sso
sso_account_id = 111122223333
sso_role_name = SampleRole2

[sso-session my-sso]
sso_region = us-east-1
sso_start_url = https://my-sso-portal.awsapps.com/start
sso_registration_scopes = sso:account:access
```

One `sso-session` block backs many profiles, so a single browser login covers every account/role pair on it.

```bash
aws configure sso                       # wizard: creates the sso-session block + a profile
aws configure sso-session               # wizard for just the [sso-session] block
aws sso login --sso-session my-sso      # or --profile <name>
aws sso logout                          # signs out of ALL sso profiles; no --profile/--all flags exist
```

- `sso_start_url` and `sso_region` are required in the `sso-session` block. `sso_account_id`/`sso_role_name` live on the profile and are unnecessary if the target service uses bearer authentication.
- **PKCE is the default browser flow since CLI 2.22.0**, and requires a browser on the same device. `--use-device-code` forces the older device-authorization grant for headless hosts.
- Since 2.22.0 the Identity Center **Issuer URL** is interchangeable with the Start URL at the wizard prompt.
- Vanity start URLs (e.g. `https://aws.mycompany.com`) are followed, and `sso_region` is derived from the redirect automatically.
- Token cache: `~/.aws/sso/cache`. Two tokens: an access token, checked hourly and refreshed silently using a refresh token. When the refresh token expires, the session is over — `aws sso login` again; there is no silent re-auth across an expired IdP session.
- Server-side session durations (not CLI settings): per-account permission-set session default 1 hour, configurable to 12; access-portal session default 8 hours, configurable to 90 days.
- SSO profiles never write anything into `~/.aws/credentials`. A working profile with no entry in that file is the tell that it's Identity-Center-backed.

Permission sets are Identity Center's analog of an IAM role: assigning one to a user/group in an account makes Identity Center create and manage a real IAM role there. Customer-managed policies referenced by a permission set must already exist, by identical name, in every target account or the assignment fails. Deep permission-set and org design belongs to the `aws-iam` skill in the `security` plugin.

> Source: https://docs.aws.amazon.com/singlesignon/latest/userguide/permissionsetsconcept.html
> Source: https://docs.aws.amazon.com/singlesignon/latest/userguide/howtocmp.html

---

## Assume-role profiles (prefer these over manual `sts assume-role`)

> Source: https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-role.html

A role-assuming profile needs `role_arn` plus **exactly one** of `source_profile` or `credential_source` — specifying both is an error.

```ini
[profile prodaccess]
role_arn = arn:aws:iam::123456789012:role/ProductionAccessRole
source_profile = default
role_session_name = alice-deploy        # optional; auto-generated as AWS-CLI-session-<epoch> if omitted
duration_seconds = 1800                 # 900 .. role's MaxSessionDuration (max 43200); default 3600

[profile instancecrossaccount]
role_arn = arn:aws:iam::222222222222:role/efgh
credential_source = Ec2InstanceMetadata # or Environment | EcsContainer
region = us-west-2
```

The CLI calls `sts:AssumeRole` in the background, **caches the result in `~/.aws/cli/cache`, and refreshes it transparently on expiry**. This is why a config-file profile beats the manual `aws sts assume-role` + `awk` + `export` pattern in scripts. If a session is revoked server-side the cache does not notice — clear it with `rm -r ~/.aws/cli/cache`.

`external_id` maps to `AssumeRole`'s `ExternalId` (third-party cross-account confused-deputy protection). `mfa_serial` (hardware serial or `arn:aws:iam::<acct>:mfa/<user>`) makes the CLI **prompt interactively for an OTP on every command that assumes the role** — unusable for unattended CI. If the trust policy requires MFA and the profile has no `mfa_serial`, the failure is a bare `AccessDenied` from `AssumeRole`.

**Role chaining caps the session at 1 hour, flat.**

> Source: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_manage-assume.html

"When you use role chaining, the role's session duration is limited to one hour. This applies to AWS Management Console role switching, AWS CLI, and API operations." A `duration_seconds` above 3600 on a chained hop fails outright rather than clamping. The cap does not apply to the initial assumption from user credentials, nor to EC2 instance-profile credentials. This is the usual cause of "credentials expired mid-deploy" in CI pipelines that chain a runner role into a deploy role.

Web identity (OIDC — GitHub Actions, EKS IRSA):

```ini
[profile web-identity]
role_arn = arn:aws:iam::123456789012:role/RoleNameToAssume
web_identity_token_file = /path/to/a/token
```

`AWS_ROLE_ARN`, `AWS_WEB_IDENTITY_TOKEN_FILE`, and `AWS_ROLE_SESSION_NAME` apply **only** to this provider — setting `AWS_ROLE_ARN` does not affect a `source_profile`/`role_arn` profile.

### STS session-duration reference

> Source: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_manage-assume.html
> Source: https://docs.aws.amazon.com/cli/latest/reference/sts/get-session-token.html

| Call | Range | Default |
|---|---|---|
| `assume-role`, `assume-role-with-saml`, `assume-role-with-web-identity` | 900s – role's `MaxSessionDuration` (1–12h, itself defaulting to 1h) | 3600s |
| Role chaining (any of the above from an assumed-role session) | 1 hour, fixed | 1 hour |
| `get-session-token` (IAM user) | 900 – 129600s | 43200s |
| `get-session-token` (root) | 900 – 3600s (silently reduced above 1h) | — |

Read and change a role's ceiling with `aws iam get-role --role-name <n>` and `aws iam update-role --role-name <n> --max-session-duration <3600..43200>`; the change affects only future assumptions. EC2 instance-profile credentials are not bound by `MaxSessionDuration` at all.

`get-session-token` exists for a narrow purpose: it returns credentials with the caller's *own* permissions, cannot be called with already-temporary credentials, and cannot call IAM or STS APIs (except `AssumeRole`/`GetCallerIdentity`). Its value is that **only `GetSessionToken` credentials carry MFA context** usable in `aws:MultiFactorAuthPresent` conditions on resource-based policies (S3/SQS/SNS). `AssumeRole` checks MFA once at assumption time and the resulting session is not individually MFA-flagged. Root cannot assume roles at all.

---

## `credential_process` and `aws configure export-credentials`

> Source: https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sourcing-external.html
> Source: https://docs.aws.amazon.com/cli/latest/reference/configure/export-credentials.html

```ini
[profile developer]
credential_process = /opt/bin/awscreds-custom --username helen
```

The command must write this JSON to stdout:

```json
{ "Version": 1, "AccessKeyId": "...", "SecretAccessKey": "...",
  "SessionToken": "...", "Expiration": "<ISO8601 / RFC3339 timestamp>" }
```

- `Version` must be `1`. `Expiration` is called ISO8601 by the CLI guide and RFC3339 by the SDK reference guide — compatible in practice.
- **`Expiration` presence changes behavior**: absent → treated as long-term, never refreshed; present → treated as temporary and the process is re-run before expiry.
- **The CLI does not cache `credential_process` output** (unlike `role_arn` profiles). A process that hits a vault over the network is re-invoked on *every* AWS CLI command unless it caches internally.
- Path/argument syntax: quote a path containing spaces; **no environment-variable expansion, no `~` shorthand** — absolute paths only.
- Security: anyone who can write `~/.aws/config` can change what command runs, with the invoking user's privileges. Treat config-file permissions as seriously as credential-file permissions. The docs also warn never to write secrets to stderr, which SDKs and the CLI may capture and log.
- `AccountId` is documented in the SDK reference guide's version of the schema but not the CLI user guide's — optional, enables account-based endpoint routing.

```bash
aws configure export-credentials [--profile NAME] [--format process|env|env-no-export|powershell|windows-cmd|fish]
```

Resolves the profile's *current effective* credentials through the whole chain — SSO, `aws login`, assumed role, static keys, anything — and prints them in the requested shape. Default format is `process`, making this the canonical bridge from any CLI-resolvable source into a `credential_process`-consuming tool without writing a static key to disk. It ignores the global `--query`/`--output` flags; `--format` is the only shaping switch.

---

## Environment variables

> Source: https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-envvars.html

Within one invocation: **CLI flag > env var > profile value.**

| Variable | Notes |
|---|---|
| `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN` | No command-line equivalents. Session token only for temporary credentials. |
| `AWS_PROFILE` | Overridden by `--profile`. |
| `AWS_REGION` / `AWS_DEFAULT_REGION` | `--region` > `AWS_REGION` > `AWS_DEFAULT_REGION` > profile `region`. Set `AWS_REGION` for portability with other AWS SDKs. |
| `AWS_DEFAULT_OUTPUT`, `AWS_PAGER`, `AWS_CLI_AUTO_PROMPT` | Override `output`, `cli_pager`, `cli_auto_prompt`. |
| `AWS_RETRY_MODE`, `AWS_MAX_ATTEMPTS` | Override `retry_mode`, `max_attempts`. |
| `AWS_CONFIG_FILE`, `AWS_SHARED_CREDENTIALS_FILE` | Relocate the config/credentials files. Env-var only — no profile key, no flag. |
| `AWS_EC2_METADATA_DISABLED` | Stops the CLI asking IMDS for credentials or region. |
| `AWS_METADATA_SERVICE_NUM_ATTEMPTS`, `AWS_METADATA_SERVICE_TIMEOUT` | IMDS retries (default 1 attempt) and connect timeout (default 1s). |
| `AWS_ROLE_ARN`, `AWS_WEB_IDENTITY_TOKEN_FILE`, `AWS_ROLE_SESSION_NAME` | Web-identity provider only. |
| `AWS_CONTAINER_CREDENTIALS_RELATIVE_URI` / `_FULL_URI`, `AWS_CONTAINER_AUTHORIZATION_TOKEN[_FILE]` | Set automatically by ECS task roles / EKS Pod Identity; these back precedence rank 9. |

> Source: https://docs.aws.amazon.com/sdkref/latest/guide/feature-container-credentials.html

---

## Config files

> Source: https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html

Section-naming asymmetry, a frequent scripting bug: `~/.aws/config` uses `[default]` and `[profile user1]` (the word `profile` is required); `~/.aws/credentials` uses `[default]` and `[user1]` (the word `profile` must not appear). **If the same key exists in both files for one profile, the credentials file wins.**

Command family: `aws configure` (wizard), `configure set/get`, `configure list`, `configure list-profiles` (the format-stable way to enumerate profiles instead of grepping the files), `configure sso`, `configure sso-session`, `configure export-credentials`, `configure mfa-login` (prompts for MFA serial + OTP and writes short-term credentials to a profile; OTP devices only, no passkeys/U2F). There is no `unset` — remove a setting by editing the file.

---

## Secure storage: what AWS actually says

> Source: https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html
> Source: https://docs.aws.amazon.com/cli/latest/userguide/cli-authentication-user.html

AWS has no standalone "plaintext credentials are dangerous" essay. Instead, a boxed warning repeats verbatim wherever long-term IAM user credentials appear: "To avoid security risks, don't use IAM users for authentication when developing purpose-built software or working with real data. Instead, use federation with an identity provider such as AWS IAM Identity Center."

The framing is *don't use IAM users*, not *harden the file*. **Documented silences** worth knowing rather than filling in from folklore:

- No AWS CLI User Guide page gives filesystem-permission (`chmod`) guidance for `~/.aws/credentials` or `~/.aws/config`.
- No AWS CLI User Guide page states a rotation cadence for long-term access keys.
- `AWS_EC2_METADATA_V1_DISABLED` does **not** appear in the CLI v2 environment-variable reference. IMDSv2 enforcement (`HttpTokens = required`) is an EC2 instance/launch-template setting (`aws ec2 modify-instance-metadata-options`), not a CLI credential setting — the CLI transparently speaks whichever IMDS version the instance requires.

> Source: https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-metadata.html
> Source: https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-envvars.html

Container caveat, quoted from the ECS guide: "Containers are not a security boundary and the use of task IAM roles does not change this... For EC2, ECS Managed Instances, and ECS Anywhere container instances, there is no task isolation and containers can potentially access credentials for other tasks on the same container instance." Mitigate on EC2-backed container instances with `ECS_AWSVPC_BLOCK_IMDS=true` (awsvpc mode) or an iptables DROP to `169.254.169.254/32` (bridge mode). Fargate provides per-task isolation.

> Source: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-iam-roles.html

---

## Sources

- https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-authentication.html
- https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html
- https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sign-in.html
- https://docs.aws.amazon.com/cli/latest/reference/login/
- https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sso.html
- https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sso-concepts.html
- https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-role.html
- https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html
- https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-envvars.html
- https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-metadata.html
- https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sourcing-external.html
- https://docs.aws.amazon.com/cli/latest/userguide/cli-authentication-user.html
- https://docs.aws.amazon.com/cli/latest/reference/configure/export-credentials.html
- https://docs.aws.amazon.com/cli/latest/reference/configure/sso-session.html
- https://docs.aws.amazon.com/cli/latest/reference/sts/assume-role.html
- https://docs.aws.amazon.com/cli/latest/reference/sts/get-session-token.html
- https://docs.aws.amazon.com/cli/latest/reference/sts/assume-role-with-web-identity.html
- https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html
- https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_manage-assume.html
- https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use_switch-role-cli.html
- https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_update-role-settings.html
- https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_temp_control-access_getsessiontoken.html
- https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_mfa_configure-api-require.html
- https://docs.aws.amazon.com/singlesignon/latest/userguide/permissionsetsconcept.html
- https://docs.aws.amazon.com/singlesignon/latest/userguide/howtocmp.html
- https://docs.aws.amazon.com/sdkref/latest/guide/feature-container-credentials.html
- https://docs.aws.amazon.com/sdkref/latest/guide/feature-process-credentials.html
- https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-iam-roles.html
- https://aws.amazon.com/blogs/security/simplified-developer-access-to-aws-with-aws-login

Fetched: 2026-08-08
