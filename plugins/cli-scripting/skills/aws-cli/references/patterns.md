# AWS CLI Scripting Patterns

Idempotent creates, batch operations, provisioning, and teardown.

---

## Script preamble

> Source: https://docs.aws.amazon.com/cli/latest/userguide/cli-usage-pagination.html
> Source: https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-envvars.html

```bash
#!/usr/bin/env bash
set -euo pipefail
export AWS_PAGER=""              # v2 pages ALL output by default
export AWS_REGION="${AWS_REGION:-us-east-1}"   # AWS_REGION, not AWS_DEFAULT_REGION — portable across AWS SDKs

# Fail fast on the wrong identity, and never run provisioning as root
CALLER=$(aws sts get-caller-identity --query Arn -o text)
[[ "$CALLER" == *":root" ]] && { echo "refusing to run as the account root user"; exit 1; }
ACCOUNT_ID=$(aws sts get-caller-identity --query Account -o text)
echo "running as $CALLER in ${AWS_REGION}"
```

`get-caller-identity` needs no permissions and cannot be denied by policy, so it always answers. Prefer a `role_arn`/`source_profile` profile over exporting credentials by hand — the CLI then caches and refreshes the assumed-role session for you (`auth.md`).

---

## Idempotent create

> Source: https://docs.aws.amazon.com/cli/latest/userguide/cli-usage-output-format.html

Existence checks depend on `--output text` rendering an absent value as the literal string `None`, so compare against `"None"` and not the empty string. The `|| echo "None"` fallback covers the separate case of the command itself failing.

```bash
# VPC — find by tag
EXISTING_VPC=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=prod-vpc" \
  --query 'Vpcs[0].VpcId' -o text 2>/dev/null || echo "None")
if [[ "$EXISTING_VPC" == "None" ]]; then
  VPC_ID=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 \
    --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=prod-vpc}]' \
    --query 'Vpc.VpcId' -o text)
  aws ec2 wait vpc-available --vpc-ids "$VPC_ID"
else
  VPC_ID="$EXISTING_VPC"
fi

# S3 bucket — every region except us-east-1 needs LocationConstraint
if ! aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
  if [[ "$AWS_REGION" == "us-east-1" ]]; then
    aws s3api create-bucket --bucket "$BUCKET_NAME" --region us-east-1
  else
    aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$AWS_REGION" \
      --create-bucket-configuration "LocationConstraint=$AWS_REGION"
  fi
  aws s3api put-public-access-block --bucket "$BUCKET_NAME" \
    --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
  aws s3api put-bucket-versioning --bucket "$BUCKET_NAME" --versioning-configuration Status=Enabled
fi

# Lambda — create or update
if ! aws lambda get-function --function-name "$FUNC_NAME" &>/dev/null; then
  aws lambda create-function --function-name "$FUNC_NAME" --runtime "$RUNTIME" \
    --handler index.handler --role "$ROLE_ARN" --zip-file fileb://function.zip
  aws lambda wait function-active-v2 --function-name "$FUNC_NAME"
else
  aws lambda update-function-code --function-name "$FUNC_NAME" --zip-file fileb://function.zip
  aws lambda wait function-updated-v2 --function-name "$FUNC_NAME"
fi

# SSM parameter
aws ssm get-parameter --name "$PARAM_NAME" &>/dev/null || \
  aws ssm put-parameter --name "$PARAM_NAME" --value "$VALUE" --type String

# Security group by name within a VPC
EXISTING_SG=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=web-sg" "Name=vpc-id,Values=$VPC_ID" \
  --query 'SecurityGroups[0].GroupId' -o text 2>/dev/null || echo "None")
```

Where an API offers a native idempotency token, use it instead of a check-then-create race: `--client-token` on `ecs create-service`, `ec2 run-instances`, and `ec2 create-route-table`; `--caller-reference` on `route53 create-hosted-zone`.

---

## Error handling

> Source: https://docs.aws.amazon.com/cli/latest/reference/ecs/wait/services-stable.html (waiter timeout exit code)
> Source: https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html (`output = off`)

```bash
trap 'echo "ERROR on line $LINENO"; cleanup' ERR

# Existence probes must not trip set -e
if aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then echo "exists"; fi
if ! aws lambda get-function --function-name "$FUNC" &>/dev/null; then echo "creating…"; fi

# Capture stderr for a real diagnostic instead of a bare exit code
if ! ERR=$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block "$CIDR" 2>&1 >/dev/null); then
  echo "subnet creation failed: $ERR" >&2
  exit 1
fi
```

A waiter that times out exits **255**, which `set -e` turns into a script abort — that is the desired behavior. `--output off` is the clean way to run a command purely for its exit code.

---

## Batch operations

> Source: https://docs.aws.amazon.com/cli/latest/userguide/cli-usage-filter.html (per-page `--query` evaluation under `--output text`)
> Source: https://docs.aws.amazon.com/cli/latest/reference/s3/rb.html (`--force` and versioned objects)

```bash
# Stop every running instance in a VPC
aws ec2 describe-instances \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].InstanceId' -o text | \
xargs -r aws ec2 stop-instances --instance-ids

# Delete log groups by prefix
aws logs describe-log-groups --log-group-name-prefix /test/ \
  --query 'logGroups[].logGroupName' -o text | tr '\t' '\n' | while read -r lg; do
  [[ -z "$lg" || "$lg" == "None" ]] && continue
  aws logs delete-log-group --log-group-name "$lg"
done

# Parallel bucket cleanup (rb --force does NOT remove versioned objects — sweep versions first)
aws s3api list-buckets --query 'Buckets[?starts_with(Name,`dev-`)].Name' -o text | \
tr '\t' '\n' | xargs -P 4 -I {} aws s3 rb s3://{} --force

# Tag untagged instances
aws ec2 describe-instances \
  --query 'Reservations[].Instances[?!not_null(Tags[?Key==`env`])].InstanceId' -o text | \
tr '\t' '\n' | while read -r id; do
  [[ -z "$id" || "$id" == "None" ]] && continue
  aws ec2 create-tags --resources "$id" --tags Key=env,Value=unknown
done

# Load SSM parameters into the environment
while IFS=$'\t' read -r name value; do
  var=$(echo "$name" | sed 's|/app/prod/||' | tr '/' '_' | tr '[:lower:]' '[:upper:]')
  export "$var=$value"
done < <(aws ssm get-parameters-by-path --path /app/prod/ --recursive --with-decryption \
  --query 'Parameters[].[Name,Value]' -o text)
```

**Aggregates need JSON, not text.** Any query that indexes, counts, or sums across a paginated result must use `--output json` — with `--output text` the query runs once per page and returns one partial answer per page (`core.md`).

```bash
# Wrong on any bucket over one page: emits one partial sum per 1000 objects
aws s3api list-objects-v2 --bucket "$B" --query 'sum(Contents[].Size)' -o text
# Right
aws s3api list-objects-v2 --bucket "$B" --output json | jq '[.Contents[].Size] | add'
```

---

## Provisioning

> Source: https://docs.aws.amazon.com/cli/latest/reference/ec2/create-vpc.html
> Source: https://docs.aws.amazon.com/cli/latest/reference/ec2/create-subnet.html
> Source: https://docs.aws.amazon.com/cli/latest/reference/ec2/run-instances.html
> Source: https://docs.aws.amazon.com/cli/latest/reference/ec2/wait/index.html

Same shape as `scripts/01-aws-provision.sh`, condensed. Discover AZs and AMIs rather than hardcoding them, tag everything for teardown, and wait on each async step.

```bash
#!/usr/bin/env bash
set -euo pipefail
export AWS_PAGER=""
REGION="${AWS_REGION:-us-east-1}"
PROJECT="demo"

tag() { aws ec2 create-tags --resources "$1" --tags Key=Name,Value="${PROJECT}-${2}" Key=Project,Value="$PROJECT"; }
log() { echo "[$(date -u +%H:%M:%S)] $*"; }

mapfile -t AZS < <(aws ec2 describe-availability-zones --region "$REGION" \
  --filters "Name=state,Values=available" --query 'AvailabilityZones[].ZoneName' -o text | tr '\t' '\n')
[[ ${#AZS[@]} -lt 2 ]] && { echo "need at least 2 AZs in $REGION"; exit 1; }

VPC_ID=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 --query 'Vpc.VpcId' -o text)
aws ec2 wait vpc-available --vpc-ids "$VPC_ID"
aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-hostnames '{"Value":true}'
tag "$VPC_ID" vpc

IGW_ID=$(aws ec2 create-internet-gateway --query 'InternetGateway.InternetGatewayId' -o text)
aws ec2 attach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID"
tag "$IGW_ID" igw

PUB_SUB=$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block 10.0.1.0/24 \
  --availability-zone "${AZS[0]}" --query 'Subnet.SubnetId' -o text)
PRIV_SUB=$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block 10.0.2.0/24 \
  --availability-zone "${AZS[1]}" --query 'Subnet.SubnetId' -o text)
aws ec2 wait subnet-available --subnet-ids "$PUB_SUB" "$PRIV_SUB"
aws ec2 modify-subnet-attribute --subnet-id "$PUB_SUB" --map-public-ip-on-launch
tag "$PUB_SUB" public-subnet; tag "$PRIV_SUB" private-subnet

RTB_ID=$(aws ec2 create-route-table --vpc-id "$VPC_ID" --query 'RouteTable.RouteTableId' -o text)
aws ec2 create-route --route-table-id "$RTB_ID" --destination-cidr-block 0.0.0.0/0 --gateway-id "$IGW_ID"
aws ec2 associate-route-table --route-table-id "$RTB_ID" --subnet-id "$PUB_SUB"
tag "$RTB_ID" public-rt

AMI_ID=$(aws ec2 describe-images --owners amazon \
  --filters "Name=name,Values=al2023-ami-2023*-x86_64" "Name=state,Values=available" \
  --query 'sort_by(Images, &CreationDate)[-1].ImageId' -o text)

INSTANCE_ID=$(aws ec2 run-instances --image-id "$AMI_ID" --instance-type t3.micro \
  --subnet-id "$PUB_SUB" --security-group-ids "$SG_ID" \
  --iam-instance-profile Name=my-instance-profile \
  --query 'Instances[0].InstanceId' -o text)
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"
# IMDSv2 enforcement (HttpTokens = required) is an EC2 instance / launch-template setting applied
# with `aws ec2 modify-instance-metadata-options` — there is no CLI-side flag to "opt into IMDSv2".
```

Attach an instance profile rather than shipping credentials to the host. Reach the instance with `aws ssm start-session` instead of opening port 22 to the internet.

---

## Cleanup

> Source: https://docs.aws.amazon.com/cli/latest/reference/ec2/wait/index.html
> Source: https://docs.aws.amazon.com/cli/latest/reference/ec2/create-security-group.html

Tag-driven teardown survives a partially-failed run, because it rediscovers resources instead of relying on variables that may never have been set.

```bash
cleanup() {
  log "tearing down ${PROJECT}"
  INST=$(aws ec2 describe-instances \
    --filters "Name=tag:Project,Values=$PROJECT" "Name=instance-state-name,Values=running,stopped" \
    --query 'Reservations[].Instances[].InstanceId' -o text 2>/dev/null || echo "")
  if [[ -n "$INST" && "$INST" != "None" ]]; then
    aws ec2 terminate-instances --instance-ids $INST
    aws ec2 wait instance-terminated --instance-ids $INST
  fi
  # then, in dependency order: non-default security groups → subnets → non-main route tables
  #                            → detach + delete IGW → delete VPC
}
trap cleanup EXIT SIGINT SIGTERM
```

Teardown order matters: a VPC will not delete while subnets, non-default security groups, non-main route tables, or an attached internet gateway remain. Suffix each teardown call with `2>/dev/null || true` so one already-gone resource does not abort the rest.

---

## Sources

- https://docs.aws.amazon.com/cli/latest/userguide/cli-usage-output-format.html
- https://docs.aws.amazon.com/cli/latest/userguide/cli-usage-filter.html
- https://docs.aws.amazon.com/cli/latest/userguide/cli-usage-pagination.html
- https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-envvars.html
- https://docs.aws.amazon.com/cli/latest/reference/sts/get-caller-identity.html
- https://docs.aws.amazon.com/cli/latest/reference/ec2/create-vpc.html
- https://docs.aws.amazon.com/cli/latest/reference/ec2/create-subnet.html
- https://docs.aws.amazon.com/cli/latest/reference/ec2/run-instances.html
- https://docs.aws.amazon.com/cli/latest/reference/ec2/wait/index.html
- https://docs.aws.amazon.com/cli/latest/reference/ecs/wait/services-stable.html
- https://docs.aws.amazon.com/cli/latest/reference/s3/rb.html
- https://docs.aws.amazon.com/cli/latest/reference/s3api/create-bucket.html
- https://docs.aws.amazon.com/cli/latest/reference/lambda/wait/function-active-v2.html
- https://docs.aws.amazon.com/IAM/latest/UserGuide/root-user-best-practices.html

Fetched: 2026-08-08
