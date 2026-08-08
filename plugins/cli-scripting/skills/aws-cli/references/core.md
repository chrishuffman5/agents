# AWS CLI Core Mechanics

Output formats, JMESPath queries, pagination, the client-side pager, waiters, and the config settings that matter for scripting. Authentication lives in `auth.md`.

---

## Output formats

> Source: https://docs.aws.amazon.com/cli/latest/userguide/cli-usage-output.html
> Source: https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html

| Value | Use |
|---|---|
| `json` | Default. The only safe format for aggregate `--query` expressions. |
| `yaml` | Human-readable structured output (new in v2). |
| `yaml-stream` | Streams YAML incrementally — faster handling of very large responses (new in v2). |
| `text` | Tab-delimited. The scripting format for single-value capture. |
| `table` | Human-readable ASCII table. |
| `off` | Suppresses all stdout. "Useful in automation scripts and CI/CD pipelines where you only need to check the command's exit code" — replaces `> /dev/null`. |

Set per command with `--output`/`-o`, per profile with `output`, or globally with `AWS_DEFAULT_OUTPUT`.

---

## Client-side pager

> Source: https://docs.aws.amazon.com/cli/latest/userguide/cli-usage-pagination.html
> Source: https://docs.aws.amazon.com/cli/latest/userguide/cliv2-migration-changes.html

**AWS CLI v2 pipes all output through the OS default pager (`less` on Linux/macOS, `more` on Windows) by default.** This is a v1→v2 behavior change and it is the single most script-hostile default in the CLI.

Program selection precedence: `cli_pager` config setting → `AWS_PAGER` env var → `PAGER` env var. Disable with any of:

```bash
aws … --no-cli-pager        # one command
export AWS_PAGER=""         # whole script / CI job  ← do this at the top of every script
```
```ini
[profile prod]
cli_pager =
```

The docs do not state that the pager is skipped automatically when stdout is not a terminal. In practice a pager will not engage against a captured or piped stream, but since AWS documents no such guarantee, set `AWS_PAGER=""` defensively in anything meant to be run unattended.

---

## `--query` (JMESPath)

> Source: https://docs.aws.amazon.com/cli/latest/userguide/cli-usage-filter.html

**Server-side vs client-side.** `--filter`/`--filters`/service-specific flags are applied by the API before data leaves AWS: faster, less bandwidth. `--query` receives the *full* response and filters locally: slower on large datasets, but more expressive. Narrow server-side first, refine with `--query`.

### The pagination interaction (the trap)

> "If you specify `--output text`, the output is paginated *before* the `--query` filter is applied, and the AWS CLI runs the query once on *each page* of the output… If you specify `--output json`, `--output yaml`, or `--output yaml-stream` the output is completely processed as a single, native structure before the `--query` filter is applied."

Consequences on any multi-page result:

- `--query 'X[0]'` with `--output text` returns the first item **of every page**, not of the result set.
- `--query 'length(X)'` or `sum(X[].Size)` with `--output text` emits **one partial value per page**. A bucket-sizing query against a 5,000-object bucket returns five partial sums, not one total.
- `sort_by(...)[-1]` with `--output text` sorts within each page independently.

Rule: any indexing, `length()`, `sum()`, `max_by`, or `sort_by` spanning the full result set must use `--output json` and be reduced with `jq` — or be re-reduced in shell (`| awk '{s+=$1} END {print s}'`). Single-scalar extractions from a single-object response (`sts get-caller-identity --query Account`) are unaffected.

> Source (corroborating worked example, community): https://github.com/chrishuffman5/awscliskills/blob/main/skills/aws-cli/s3/storage-sizing.md — documents `sum(Contents[].Size)` emitting one partial sum per 1000-object page, and a `Contents[*].Size --output text | awk` idiom that reads only the first field.

### Null rendering

> Source: https://docs.aws.amazon.com/cli/latest/userguide/cli-usage-output-format.html

"Notice how the AWS CLI outputs `None` as the value for keys that don't exist." When a `--query` expression *names* a key that resolves to null on a given record, `--output text` renders the literal four-character string `None`. A bare `--output text` walk with no `--query` instead leaves an empty tab-separated field. Existence checks must compare against `"None"`:

```bash
VPC=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=prod-vpc" \
  --query 'Vpcs[0].VpcId' -o text 2>/dev/null || echo "None")
[[ "$VPC" == "None" ]] && echo "not found"
```
Note this sentinel arrives from two independent directions — the CLI's own null rendering, and the shell `|| echo "None"` fallback when the command itself fails. Both collapse to the same string, which is why the idiom works.

### Expression catalog

```bash
# Single field / multiple fields
aws sts get-caller-identity --query Account -o text
aws sts get-caller-identity --query '[Account, Arn, UserId]' -o text

# Flatten nested arrays
aws ec2 describe-instances --query 'Reservations[].Instances[].InstanceId' -o text

# Filter by value
aws ec2 describe-instances --query 'Reservations[].Instances[?State.Name==`running`].InstanceId' -o text

# Named projection (readable tables)
aws ec2 describe-instances \
  --query 'Reservations[].Instances[].{ID:InstanceId,Type:InstanceType,State:State.Name}' -o table

# Most recent / top N  (slice syntax; use JSON output for the aggregate)
aws ec2 describe-images --owners amazon --filters "Name=name,Values=al2023-ami-2023*-x86_64" \
  --query 'sort_by(Images, &CreationDate)[-1].[ImageId,Name]' -o text
aws ec2 describe-images --owners amazon --query 'reverse(sort_by(Images,&CreationDate))[:5].ImageId'

# Functions: length, contains, starts_with, not_null
aws iam list-users --query 'length(Users)'
aws iam list-roles --query 'Roles[?contains(RoleName, `lambda`)].RoleName' -o text
aws s3api list-buckets --query 'Buckets[?starts_with(Name, `prod-`)].Name' -o text
aws ec2 describe-volumes --query 'Volumes[?!not_null(Tags[?Value == `test`].Value)]'

# Piped expression — take the first result after a filter
aws ec2 describe-instances --query 'Reservations[].Instances[?State.Name==`running`] | [0].InstanceId' -o text

# Nested stack output
aws cloudformation describe-stacks --stack-name my-stack \
  --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerUrl`].OutputValue' -o text
```

---

## Pagination

> Source: https://docs.aws.amazon.com/cli/latest/userguide/cli-usage-pagination.html

```bash
aws s3api list-objects-v2 --bucket my-bucket                       # auto-paginates ALL pages (v2 default)
aws s3api list-objects-v2 --bucket my-bucket --max-items 100       # cap items printed; emits NextToken if truncated
aws s3api list-objects-v2 --bucket my-bucket --page-size 50        # items per API call, not total
aws s3api list-objects-v2 --bucket my-bucket --no-paginate         # one page only
aws s3api list-objects-v2 --bucket my-bucket --starting-token eyJNYXJrZXIi...
```

**Do not set different values for `--page-size` and `--max-items`**: "you can get unexpected results with missing or duplicated items," because the service need not return items in a stable order across separate calls. Use the same value for both, or fetch everything and slice locally. Default page size is service-specific (1000 for S3).

---

## Waiters

> Source: https://docs.aws.amazon.com/cli/latest/reference/ec2/wait/index.html
> Source: https://docs.aws.amazon.com/cli/latest/reference/rds/wait/index.html
> Source: https://docs.aws.amazon.com/cli/latest/reference/cloudformation/wait/index.html
> Source: https://docs.aws.amazon.com/cli/latest/reference/ecs/wait/index.html
> Source: https://docs.aws.amazon.com/cli/latest/reference/eks/wait/index.html
> Source: https://docs.aws.amazon.com/cli/latest/reference/lambda/wait/index.html
> Source: https://docs.aws.amazon.com/cli/latest/reference/route53/wait/resource-record-sets-changed.html

Every waiter polls at a fixed interval for a fixed number of attempts and **exits 255 on timeout** — which aborts a `set -e` script, as intended.

```bash
# EC2 (43 waiters). Resources return State: pending before they are usable — wait on creation too.
aws ec2 wait vpc-available    --vpc-ids "$VPC_ID"
aws ec2 wait subnet-available --subnet-ids "$SUBNET_ID"
aws ec2 wait security-group-exists --group-ids "$SG_ID"
aws ec2 wait instance-running --instance-ids "$ID"
aws ec2 wait instance-status-ok --instance-ids "$ID"      # running != reachable
aws ec2 wait instance-terminated --instance-ids "$ID"
aws ec2 wait nat-gateway-available --nat-gateway-ids "$NAT_ID"

# RDS
aws rds wait db-instance-available --db-instance-identifier my-db
aws rds wait db-snapshot-available --db-snapshot-identifier my-snap   # db-snapshot-completed also exists
aws rds wait db-cluster-available  --db-cluster-identifier my-cluster

# CloudFormation
aws cloudformation wait stack-create-complete    --stack-name my-stack
aws cloudformation wait stack-update-complete    --stack-name my-stack
aws cloudformation wait stack-delete-complete    --stack-name my-stack
aws cloudformation wait change-set-create-complete --stack-name my-stack --change-set-name preview
#   also: stack-exists, stack-rollback-complete, stack-import-complete,
#         stack-refactor-create-complete / stack-refactor-execute-complete (stack refactoring)

# ECS — 15s interval, 40 attempts. --services is plural even for one service.
aws ecs wait services-stable --cluster prod --services my-api
aws ecs wait tasks-running --cluster prod --tasks "$TASK_ARN"
#   also: services-inactive, tasks-stopped for teardown

# EKS — create-addon is asynchronous; wait on it.
aws eks wait cluster-active   --name prod
aws eks wait nodegroup-active --cluster-name prod --nodegroup-name workers
aws eks wait addon-active     --cluster-name prod --addon-name vpc-cni
#   also: cluster-deleted, nodegroup-deleted, fargate-profile-active/-deleted

# Lambda
aws lambda wait function-active  --function-name my-func   # GetFunctionConfiguration, 5s x 60
aws lambda wait function-updated --function-name my-func
aws lambda wait function-active-v2  --function-name my-func  # GetFunction, 1s x 300
aws lambda wait function-updated-v2 --function-name my-func
#   also: function-exists, published-version-active

# Route 53 — 30s interval, 60 attempts; --id is the ChangeInfo.Id from change-resource-record-sets
aws route53 wait resource-record-sets-changed --id "$CHANGE_ID"
```

> Source: https://docs.aws.amazon.com/cli/latest/reference/lambda/wait/function-active-v2.html

The `-v2` Lambda waiters check the same field for the same target value as the originals; the differences are the polled API (`GetFunction` vs `GetFunctionConfiguration`) and poll granularity (1s × 300 vs 5s × 60 — identical 300-second worst case). AWS documents no rationale for introducing them, so choose on poll granularity versus API-call volume, not on any claimed bug fix.

---

## Config settings that matter for scripting

> Source: https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html
> Source: https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-retries.html

| Setting | Values / default | Env override | Flag |
|---|---|---|---|
| `output` | `json` (default) \| `yaml` \| `yaml-stream` \| `text` \| `table` \| `off` | `AWS_DEFAULT_OUTPUT` | `--output` |
| `region` | region code or `aws_global` | `AWS_REGION`, `AWS_DEFAULT_REGION` | `--region` |
| `cli_pager` | pager program; empty disables paging | `AWS_PAGER` | — |
| `cli_binary_format` | `base64` (v2 default) \| `raw-in-base64-out` (v1 behavior) | — | `--cli-binary-format` |
| `retry_mode` | `standard` (v2 default) \| `legacy` \| `adaptive` (experimental) | `AWS_RETRY_MODE` | — |
| `max_attempts` | integer; standard mode defaults to 3 total calls | `AWS_MAX_ATTEMPTS` | — |
| `parameter_validation` | `true` (default) \| `false` | — | — |
| `cli_timestamp_format` | `iso8601` (v2 default) \| `wire` | — | — |
| `cli_auto_prompt` | `on` \| `on-partial` | `AWS_CLI_AUTO_PROMPT` | `--cli-auto-prompt` |
| `ca_bundle` | path to a `.pem` | `AWS_CA_BUNDLE` | `--ca-bundle` |

Retry modes: **`standard`** (v2 default) retries a wide documented set of transient/throttling errors plus HTTP 5xx, 2 retries by default, exponential backoff capped at 20 seconds. **`legacy`** (v1 default) allows 4 retries — 9 for DynamoDB — over a narrower error list with uncapped backoff. **`adaptive`** adds client-side rate limiting via a token bucket that reacts to observed throttling, and is explicitly labeled experimental and "subject to change." Debug with `--debug 2> debug.txt` and grep for `retry`.

### S3 transfer tuning (per profile)

> Source: https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html

Directly relevant to scripted `aws s3 sync`/`cp` at scale:

```ini
[profile bulk]
s3 =
  max_concurrent_requests = 20      # default 10
  max_queue_size = 10000            # default 1000
  multipart_threshold = 64MB        # default 8MB
  multipart_chunksize = 16MB        # default 8MB, minimum 5MB
  max_bandwidth = 50MB/s            # default unlimited
  use_accelerate_endpoint = true    # default false
  addressing_style = path           # path | virtual | auto (default)
```

Raise concurrency for many small files; raise `multipart_chunksize` for few very large ones. `use_dualstack_endpoint`, `payload_signing_enabled`, and `disable_s3_express_session_auth` apply to both `s3` and `s3api`.

---

## v1 → v2 behavior changes worth remembering

> Source: https://docs.aws.amazon.com/cli/latest/userguide/cliv2-migration-changes.html

- All output goes through a pager by default (above).
- Binary parameters are base64 by default (`cli_binary_format`) — `aws lambda invoke --payload` needs `--cli-binary-format raw-in-base64-out` for raw JSON.
- Timestamps render as ISO 8601 by default.
- S3 uses SigV4 exclusively, so presigned URLs cap at 604800 seconds (7 days).
- `us-east-1` resolves to the true regional endpoint `s3.us-east-1.amazonaws.com`, not the legacy global endpoint (`--region aws-global` forces the old behavior).
- Since 2.23.0, `aws s3` uploads compute a **CRC64NVME** checksum by default (v1 used CRC32); override with `--checksum-algorithm`.
- `--copy-props` controls which metadata and tags transfer on multipart copies; v2 transfers all tags plus some properties by default (v1 dropped them), at the cost of extra API calls.
- `cloudformation deploy` already exits 0 on an empty changeset — `--no-fail-on-empty-changeset` is redundant; `--fail-on-empty-changeset` restores v1 behavior.
- v2-only commands worth knowing: `aws logs tail`, `aws ecr get-login-password` (replaces the removed `aws ecr get-login`), `aws ddb put` / `aws ddb select`.

---

## Sources

- https://docs.aws.amazon.com/cli/latest/userguide/cli-usage-output.html
- https://docs.aws.amazon.com/cli/latest/userguide/cli-usage-output-format.html
- https://docs.aws.amazon.com/cli/latest/userguide/cli-usage-filter.html
- https://docs.aws.amazon.com/cli/latest/userguide/cli-usage-pagination.html
- https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html
- https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-retries.html
- https://docs.aws.amazon.com/cli/latest/userguide/cliv2-migration-changes.html
- https://docs.aws.amazon.com/cli/latest/reference/ec2/wait/index.html
- https://docs.aws.amazon.com/cli/latest/reference/rds/wait/index.html
- https://docs.aws.amazon.com/cli/latest/reference/cloudformation/wait/index.html
- https://docs.aws.amazon.com/cli/latest/reference/ecs/wait/index.html
- https://docs.aws.amazon.com/cli/latest/reference/ecs/wait/services-stable.html
- https://docs.aws.amazon.com/cli/latest/reference/eks/wait/index.html
- https://docs.aws.amazon.com/cli/latest/reference/lambda/wait/index.html
- https://docs.aws.amazon.com/cli/latest/reference/lambda/wait/function-active-v2.html
- https://docs.aws.amazon.com/cli/latest/reference/lambda/wait/function-updated-v2.html
- https://docs.aws.amazon.com/cli/latest/reference/route53/wait/resource-record-sets-changed.html
- https://docs.aws.amazon.com/cli/latest/reference/sts/get-caller-identity.html
- https://github.com/chrishuffman5/awscliskills/blob/main/skills/aws-cli/s3/storage-sizing.md (commit ddab56be22be966ed9ba1b4b831526f95e3c801b)

Fetched: 2026-08-08
