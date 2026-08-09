# AWS CLI Commands by Service

Verified command syntax with flags, defaults, and the constraints that bite. Authentication is in `auth.md`; IAM security operations are in `iam-security.md`.

**Service name ≠ CLI namespace.** The marketing name and the `aws` subcommand often differ — Cloud Map is `servicediscovery`, AWS Config is `configservice`, Step Functions is `stepfunctions`, Systems Manager is `ssm`, ACM Private CA is `acm-pca`, Managed Grafana is `grafana`, Managed Prometheus is `amp`, EC2 Image Builder is `imagebuilder`. Confirm with `aws help` before guessing.

> Source: https://github.com/chrishuffman5/awscliskills/blob/main/skills/aws-cli/SKILL.md (commit ddab56be22be966ed9ba1b4b831526f95e3c801b)

---

## Tagging (cross-service)

Tagging **strategy** — which tag categories to standardize on, tag-policy design, SCP-based enforcement, cost-allocation activation — belongs to the `aws` skill in the `cloud-platforms` plugin. This section is the CLI surface for querying, applying, and reporting on tags.

### `aws resourcegroupstaggingapi` — cross-service tag operations

> Source: https://docs.aws.amazon.com/cli/latest/reference/resourcegroupstaggingapi/index.html

Subcommands: `get-resources`, `tag-resources`, `untag-resources`, `get-tag-keys`, `get-tag-values`, `get-compliance-summary`, `list-required-tags`, `start-report-creation`, `describe-report-creation`.

```bash
# Inventory by tag — the primary query
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=Environment,Values=Production Key=CostCenter \
  --resource-type-filters ec2:instance s3:bucket \
  --query 'ResourceTagMappingList[].ResourceARN' -o json

# Apply / remove tags across services in one call
aws resourcegroupstaggingapi tag-resources \
  --resource-arn-list arn:aws:s3:::my-bucket arn:aws:ec2:us-east-1:123456789012:instance/i-abc \
  --tags Environment=Production,CostCenter=1234
aws resourcegroupstaggingapi untag-resources \
  --resource-arn-list arn:aws:s3:::my-bucket --tag-keys Environment CostCenter

# Discover what's actually in use (region- and account-scoped, not org-wide)
aws resourcegroupstaggingapi get-tag-keys
aws resourcegroupstaggingapi get-tag-values --key Environment
```

> Source: https://docs.aws.amazon.com/cli/latest/reference/resourcegroupstaggingapi/get-resources.html
> Source: https://docs.aws.amazon.com/cli/latest/reference/resourcegroupstaggingapi/tag-resources.html
> Source: https://docs.aws.amazon.com/cli/latest/reference/resourcegroupstaggingapi/untag-resources.html
> Source: https://docs.aws.amazon.com/cli/latest/reference/resourcegroupstaggingapi/get-tag-keys.html
> Source: https://docs.aws.amazon.com/cli/latest/reference/resourcegroupstaggingapi/get-tag-values.html

- **`--tag-filters` semantics**: AND across distinct keys, OR across values within one key, and a key given with no `Values` matches any value. Limits: up to 50 keys, up to 20 values per key. `--resource-type-filters` takes `service[:resourceType]` strings; a bare `service` matches every resource type under it.
- **`get-resources` does not return untagged resources.** AWS's documented redirect for that case is Resource Explorer with a `tag:none` query — a tag-coverage audit built only on `get-resources` silently reports 100% coverage.
- `--resource-arn-list` on `get-resources` is a distinct "look up exactly these ARNs" mode: up to 100 ARNs, and **mutually exclusive** with `--tag-filters`, `--resource-type-filters`, and every pagination parameter.
- **`tag-resources`/`untag-resources` are not all-or-nothing.** Max 20 ARNs and 50 tags (or 50 tag keys) per call; the response carries a `FailedResourcesMap` keyed by ARN with `{StatusCode, ErrorCode, ErrorMessage}`, **empty on full success**. A script that ignores it will report success on a partial failure — check it, and batch ARNs in twenties.
- `get-tag-keys`/`get-tag-values` report only what is in use in the **calling account and region**; both paginate via `PaginationToken`.
- Prefer `--page-size` over `get-resources`' `--tags-per-page` (AWS's own recommendation). Extract under pagination from `ResourceTagMappingList`.

### Tag-policy compliance reporting

> Source: https://docs.aws.amazon.com/cli/latest/reference/resourcegroupstaggingapi/get-compliance-summary.html
> Source: https://docs.aws.amazon.com/cli/latest/reference/resourcegroupstaggingapi/list-required-tags.html

```bash
# Hard restriction: management account, us-east-1 only, tag policies enabled in the org
aws resourcegroupstaggingapi get-compliance-summary --region us-east-1 \
  --target-id-filters 123456789012 --group-by RESOURCE_TYPE REGION

# Pre-flight: which tag keys does the effective tag policy expect for this resource type?
aws resourcegroupstaggingapi list-required-tags \
  --query 'RequiredTags[].{Type:ResourceType,Keys:ReportingTagKeys}' -o json
```

`get-compliance-summary` returns a `SummaryList` of `{LastUpdated, TargetId, TargetIdType (ACCOUNT|OU|ROOT), Region, ResourceType, NonCompliantResources}`; `--group-by` accepts `TARGET_ID`, `REGION`, `RESOURCE_TYPE`. Per-resource compliance status is also available inline on `get-resources --include-compliance-details`, and `--exclude-compliant-resources` narrows to noncompliant resources only — it is usable **only** alongside `--include-compliance-details`.

### `aws resource-explorer-2 search` — including untagged resources

> Source: https://docs.aws.amazon.com/cli/latest/reference/resource-explorer-2/search.html

```bash
aws resource-explorer-2 search --query-string "tag:none resourcetype:ec2:instance" \
  --query 'Resources[].Arn' -o json
```

- `--query-string` is required and case-insensitive; an empty string returns everything up to the cap.
- **Hard ceiling of 1,000 results — an absolute cap, not a pagination default.** `Count.Complete` is `false` when the search hit it, so check that field before treating results as a complete inventory.
- `--view-arn` defaults to the region's default view. If no default view exists, or the caller cannot use it, the call **fails with 401 Unauthorized** rather than returning nothing — do not read that failure as "no resources."
- Pagination tokens expire after 24 hours. Results carry `Arn`, `OwningAccountId`, `Region`, `ResourceType`, `Service`, `CfnResourceType`, `LastReportedAt`, and `Properties`; `LastReportedAt` reflects an eventually-consistent index, not live state.

### Tag-on-create vs tag-after

> Source: https://docs.aws.amazon.com/cli/latest/reference/ec2/run-instances.html
> Source: https://docs.aws.amazon.com/cli/latest/reference/ec2/create-tags.html
> Source: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/Using_Tags.html

**Tag on create whenever the API allows it.** EC2 documents that "if tags cannot be applied during resource creation, we roll back the resource creation process… no resources are left untagged at any time." Tagging afterwards necessarily leaves a window in which the resource exists untagged, and a script that dies between the two calls leaves it that way permanently.

```bash
# Tag-on-create — repeat the ResourceType block per resource type in the same call
aws ec2 run-instances --image-id "$AMI_ID" --instance-type t3.micro \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Environment,Value=Production}]' \
                       'ResourceType=volume,Tags=[{Key=Environment,Value=Production}]'

# Tag-after — the fallback for resources that can't be tagged at creation
aws ec2 create-tags --resources ami-1a2b3c4d i-1234567890abcdef0 \
  --tags Key=webserver,Value= Key=Stack,Value=Production
```

- `run-instances --tag-specifications` covers **only** instances, volumes, Spot Instance requests, and network interfaces — anything else that call creates still needs a follow-up `create-tags`.
- `ec2 create-tags` accepts up to 1,000 resource IDs per call (AWS recommends smaller batches) and produces **no output** on success. Each resource holds a maximum of 50 tags. Tag keys and values are case-sensitive, values run to 256 Unicode characters, and keys may not begin with `aws:`.
- `Key=webserver,Value=` is valid: `--tags` requires the `value` parameter, and supplying it empty sets an empty-string value rather than erroring.

---

## IAM

> Source: https://docs.aws.amazon.com/cli/latest/reference/iam/index.html
> Source: https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html

Roles first. Roles are how both humans (through Identity Center permission sets) and workloads should get permissions; creating IAM users with console passwords and access keys is the exception path, not the default. See `iam-security.md` before doing the latter.

```bash
# Roles and trust policies — the default way to grant access
aws iam create-role --role-name lambda-role --assume-role-policy-document '{
  "Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"lambda.amazonaws.com"},"Action":"sts:AssumeRole"}]}'
aws iam attach-role-policy --role-name lambda-role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
aws iam list-attached-role-policies --role-name lambda-role \
  --query 'AttachedPolicies[].{Name:PolicyName,Arn:PolicyArn}' -o table
aws iam update-assume-role-policy --role-name lambda-role --policy-document file://trust.json
aws iam get-role --role-name lambda-role --query 'Role.MaxSessionDuration'
aws iam update-role --role-name lambda-role --max-session-duration 3600      # 3600–43200

# Customer-managed policies (scoped) beat AWS managed policies (broad)
aws iam create-policy --policy-name s3-read --policy-document '{
  "Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":["s3:GetObject","s3:ListBucket"],
  "Resource":["arn:aws:s3:::my-bucket","arn:aws:s3:::my-bucket/*"]}]}'
aws iam put-role-policy --role-name my-role --policy-name inline-s3 --policy-document '{
  "Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":"s3:PutObject","Resource":"arn:aws:s3:::my-bucket/*"}]}'

# Instance profiles — how an EC2 instance receives a role
aws iam create-instance-profile --instance-profile-name my-profile
aws iam add-role-to-instance-profile --instance-profile-name my-profile --role-name my-ec2-role

# Permissions boundary — cap what a delegated-created identity can ever do
aws iam put-role-permissions-boundary --role-name team-role \
  --permissions-boundary arn:aws:iam::123456789012:policy/XCompanyBoundaries

# Groups (for the IAM-user cases that remain)
aws iam create-group --group-name developers
aws iam add-user-to-group --user-name alice --group-name developers
aws iam attach-group-policy --group-name developers --policy-arn arn:aws:iam::aws:policy/ReadOnlyAccess
```

### IAM users and access keys — the documented exception path

> Source: https://docs.aws.amazon.com/cli/latest/reference/iam/create-login-profile.html
> Source: https://docs.aws.amazon.com/IAM/latest/UserGuide/id-credentials-access-keys-update.html

Only for the cases AWS names as legitimate (workloads that cannot assume a role, third-party clients without Identity Center support, CodeCommit credentials, Keyspaces testing). Everything else routes to `aws login`, Identity Center, `AssumeRole*`, or Roles Anywhere.

```bash
aws iam create-user --user-name svc-legacy --tags Key=Team,Value=platform \
  --permissions-boundary arn:aws:iam::123456789012:policy/XCompanyBoundaries
aws iam create-access-key --user-name svc-legacy --query 'AccessKey.[AccessKeyId,SecretAccessKey]' -o text
#   the secret is displayed ONCE and cannot be retrieved again; max 2 keys per user

# Rotation: create → cut over → verify unused → DEACTIVATE → delete. Never skip the deactivate step.
aws iam list-access-keys --user-name svc-legacy
aws iam get-access-key-last-used --access-key-id AKIAEXAMPLE
aws iam update-access-key --user-name svc-legacy --access-key-id AKIAEXAMPLE --status Inactive
aws iam delete-access-key --user-name svc-legacy --access-key-id AKIAEXAMPLE
```

`aws iam create-login-profile --user-name alice --password '…' --password-reset-required` creates a console password (1–128 chars). For passwords with characters that are awkward to shell-quote, use `--generate-cli-skeleton` and `--cli-input-json` rather than an inline `--password`.

---

## S3

> Source: https://docs.aws.amazon.com/cli/latest/reference/s3/sync.html
> Source: https://docs.aws.amazon.com/cli/latest/reference/s3/rb.html
> Source: https://docs.aws.amazon.com/cli/latest/reference/s3/presign.html
> Source: https://docs.aws.amazon.com/cli/latest/reference/s3api/create-bucket.html

```bash
# High-level (aws s3)
aws s3 mb s3://my-bucket --region us-east-1
aws s3 ls s3://my-bucket/logs/ --recursive --human-readable --summarize
aws s3 cp ./report.csv s3://my-bucket/reports/report.csv
aws s3 sync ./dist s3://my-bucket/static/ --delete
aws s3 sync ./dist s3://my-bucket/static/ --exclude "*.map" --include "*.js" --delete
aws s3 mv s3://my-bucket/old/file.txt s3://my-bucket/new/file.txt
aws s3 rm s3://my-bucket/old-prefix/ --recursive
aws s3 rb s3://my-bucket --force
aws s3 presign s3://my-bucket/private/report.pdf --expires-in 3600
```

- **`sync` compares size, modified time, and existence — not checksums.** An object requires copying only if sizes differ, the source is newer, or the destination is missing. A file whose content changed but whose size and mtime did not will **not** be re-copied. `--size-only` ignores mtime; `--exact-timestamps` (S3→local) requires exact equality to skip; `--no-overwrite` skips anything already present.
- `sync` is always recursive; there is no `--recursive` flag for it. `cp`/`rm`/`mv` need `--recursive` explicitly.
- `--exclude`/`--include` are evaluated **in command-line order**. `--exclude "*" --include "*.log"` is the "only these files" idiom.
- `--delete` will not delete files that an active filter excluded from the sync.
- **`rb --force` does not delete versioned objects**: "versioned objects will not be deleted in this process which would cause the bucket deletion to fail because the bucket would not be empty. To delete versioned objects use the `s3api delete-object` command with the `--version-id` parameter." A bucket created with versioning enabled needs a version-sweep first.
- `presign --expires-in` defaults to 3600 and **maxes at 604800 seconds (7 days)** — v2 signs S3 with SigV4 only. The region must be configured explicitly.
- `mv` has a `--validate-same-s3-paths` guard (or `AWS_CLI_S3_MV_VALIDATE_SAME_S3_PATHS=true`) against self-deletion when access-point aliases resolve to the same bucket.
- `aws s3 ls` ignores `--output` and `--no-paginate`.

```bash
# Low-level (aws s3api)
aws s3api create-bucket --bucket my-bucket --region us-east-1
aws s3api create-bucket --bucket my-west --region us-west-2 \
  --create-bucket-configuration LocationConstraint=us-west-2   # required for every region except us-east-1
aws s3api put-public-access-block --bucket my-bucket \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
aws s3api put-bucket-versioning --bucket my-bucket --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket my-bucket --server-side-encryption-configuration '{
  "Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
aws s3api put-bucket-lifecycle-configuration --bucket my-bucket --lifecycle-configuration '{
  "Rules":[{"ID":"expire-logs","Status":"Enabled","Filter":{"Prefix":"logs/"},"Expiration":{"Days":90}}]}'
aws s3api list-objects-v2 --bucket my-bucket --prefix logs/ \
  --query 'Contents[].{Key:Key,Size:Size,Modified:LastModified}' -o table
aws s3api put-object --bucket my-bucket --key data/file.json --body file://file.json \
  --content-type application/json --storage-class INTELLIGENT_TIERING
```

- Omitting `--region` on `create-bucket` puts the bucket in `us-east-1`.
- Set all four `put-public-access-block` fields explicitly; the API documents no defaults for omitted fields.
- Versioning `Status` is `Enabled` or `Suspended` — there is no way back to never-versioned. Wait ~15 minutes after enabling before heavy write/delete traffic, to avoid intermittent `404 NoSuchKey` from eventual consistency.
- `SSEAlgorithm`: `AES256` (SSE-S3), `aws:kms`, `aws:kms:dsse`.
- Storage classes: `STANDARD` (default), `INTELLIGENT_TIERING`, `STANDARD_IA`, `ONEZONE_IA`, `GLACIER_IR`, `GLACIER`, `DEEP_ARCHIVE`, `EXPRESS_ONEZONE` (S3 Express One Zone — requires a directory bucket with different creation mechanics), `OUTPOSTS`, and `REDUCED_REDUNDANCY` (AWS recommends against it). Intelligent-Tiering never monitors objects under 128 KB.

> Source: https://docs.aws.amazon.com/AmazonS3/latest/userguide/storage-class-intro.html

---

## Lambda

> Source: https://docs.aws.amazon.com/cli/latest/reference/lambda/create-function.html
> Source: https://docs.aws.amazon.com/lambda/latest/dg/gettingstarted-limits.html
> Source: https://docs.aws.amazon.com/cli/latest/reference/lambda/invoke.html

```bash
aws lambda create-function --function-name my-func --runtime python3.13 --handler index.handler \
  --role arn:aws:iam::123456789012:role/lambda-role --zip-file fileb://function.zip \
  --timeout 30 --memory-size 256 --environment 'Variables={DB_HOST=mydb,LOG_LEVEL=INFO}'
aws lambda wait function-active-v2 --function-name my-func

aws lambda update-function-code --function-name my-func --zip-file fileb://function.zip --publish
aws lambda wait function-updated-v2 --function-name my-func

aws lambda update-function-configuration --function-name my-func --memory-size 512 --timeout 60
aws lambda wait function-updated-v2 --function-name my-func       # config updates are async too

aws lambda invoke --function-name my-func --payload '{"key":"value"}' \
  --cli-binary-format raw-in-base64-out response.json

aws lambda publish-layer-version --layer-name my-deps --zip-file fileb://layer.zip \
  --compatible-runtimes python3.13 --compatible-architectures arm64
LAYER_ARN=$(aws lambda list-layer-versions --layer-name my-deps \
  --query 'LayerVersions[0].LayerVersionArn' -o text)
aws lambda update-function-configuration --function-name my-func --layers "$LAYER_ARN"

aws lambda create-event-source-mapping --function-name my-func \
  --event-source-arn arn:aws:sqs:us-east-1:123456789012:my-queue --batch-size 10

aws lambda publish-version --function-name my-func --description "v2.1"
aws lambda create-alias --function-name my-func --name prod --function-version 5
aws lambda put-function-concurrency --function-name my-func --reserved-concurrent-executions 100

aws lambda add-permission --function-name my-func --statement-id allow-apigw \
  --action lambda:InvokeFunction --principal apigateway.amazonaws.com \
  --source-arn "arn:aws:execute-api:us-east-1:123456789012:api-id/*"
```

- `--runtime` and `--handler` are required only for `.zip` packages; `--package-type Image` uses `--code ImageUri=…` instead. Verify the current supported runtime list rather than pinning an example indefinitely — runtimes carry published deprecation dates.
- **Service quotas** (the canonical limits): `--memory-size` default 128 MB, range 128–10,240 MB; `--timeout` default 3 s, max 900 s; `--ephemeral-storage` 512–10,240 MB, default 512. Deployment package limit is 250 MB unzipped, including layers.
- `--payload` maxes at 6 MB synchronous / 1 MB asynchronous — larger inputs go through S3 with a pointer.
- `--cli-binary-format raw-in-base64-out` is mandatory for raw-JSON payloads under v2, whose default is `base64`.
- Code and configuration are locked on a published version; only `$LATEST` is mutable.
- `--batch-size` defaults and caps are source-specific: SQS standard 10 (max 10,000), SQS FIFO max 10, Kinesis/DynamoDB/MSK/MQ/DocumentDB default 100 (max 10,000). Batch sizes above 10 require `--maximum-batching-window-in-seconds` ≥ 1.
- Always pass `--source-arn` on `add-permission` for a service principal — omitting it lets other accounts configure resources that invoke your function.

---

## RDS

> Source: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/PostgreSQL.Concepts.General.DBVersions.html

**Discover engine versions; don't hardcode them.** Minor versions rotate constantly and major versions get deprecated on a schedule. Omitting `--engine-version` makes RDS pick an available (typically most recent) version.

```bash
aws rds describe-db-engine-versions --default-only --engine postgres \
  --query 'DBEngineVersions[0].EngineVersion' -o text
aws rds describe-db-major-engine-versions --engine postgres     # support-window dates
```

```bash
aws rds create-db-subnet-group --db-subnet-group-name my-db-subnets \
  --db-subnet-group-description "DB subnets" --subnet-ids subnet-aaa subnet-bbb

PG_VERSION=$(aws rds describe-db-engine-versions --default-only --engine postgres \
  --query 'DBEngineVersions[0].EngineVersion' -o text)
aws rds create-db-instance --db-instance-identifier prod-pg --db-instance-class db.t3.medium \
  --engine postgres --engine-version "$PG_VERSION" \
  --master-username dbadmin --master-user-password "$DB_PASS" \
  --allocated-storage 100 --max-allocated-storage 500 --storage-type gp3 --storage-encrypted \
  --db-subnet-group-name my-db-subnets --vpc-security-group-ids sg-xxx \
  --backup-retention-period 7 --multi-az --deletion-protection
aws rds wait db-instance-available --db-instance-identifier prod-pg

aws rds describe-db-instances --query 'DBInstances[].{ID:DBInstanceIdentifier,Class:DBInstanceClass,Engine:Engine,Status:DBInstanceStatus,Endpoint:Endpoint.Address}' -o table
aws rds describe-db-instances --db-instance-identifier prod-pg \
  --query 'DBInstances[0].Endpoint.Address' -o text
aws rds modify-db-instance --db-instance-identifier prod-pg --db-instance-class db.t3.large --apply-immediately

aws rds create-db-snapshot --db-instance-identifier prod-pg --db-snapshot-identifier "prod-pg-$(date +%Y%m%d)"
aws rds wait db-snapshot-available --db-snapshot-identifier "prod-pg-$(date +%Y%m%d)"
aws rds restore-db-instance-from-db-snapshot --db-instance-identifier prod-pg-restored \
  --db-snapshot-identifier prod-pg-20260101 --db-instance-class db.t3.medium

# Aurora — same version-discovery rule (--engine aurora-postgresql)
aws rds create-db-cluster --db-cluster-identifier my-aurora --engine aurora-postgresql \
  --master-username admin --master-user-password "$DB_PASS" --db-subnet-group-name my-db-subnets \
  --vpc-security-group-ids sg-xxx --storage-encrypted
aws rds create-db-instance --db-instance-identifier my-aurora-writer --db-cluster-identifier my-aurora \
  --db-instance-class db.r6g.large --engine aurora-postgresql
```

Pass `--master-user-password` from a variable sourced at runtime (SSM SecureString, Secrets Manager), never a literal in a committed script.

---

## CloudFormation

> Source: https://docs.aws.amazon.com/cli/latest/reference/cloudformation/deploy.html
> Source: https://docs.aws.amazon.com/cli/latest/userguide/cliv2-migration-changes.html

```bash
aws cloudformation validate-template --template-body file://template.yaml

aws cloudformation create-stack --stack-name my-stack --template-body file://template.yaml \
  --parameters ParameterKey=Env,ParameterValue=prod --capabilities CAPABILITY_NAMED_IAM \
  --tags Key=Project,Value=MyApp
aws cloudformation wait stack-create-complete --stack-name my-stack

# deploy = create-change-set + execute-change-set, CLI-only composite. --template-file, not --template-body.
aws cloudformation deploy --stack-name my-stack --template-file template.yaml \
  --parameter-overrides Env=prod --capabilities CAPABILITY_NAMED_IAM
#   --no-fail-on-empty-changeset is REDUNDANT in v2 (already the default).
#   --fail-on-empty-changeset restores the v1 non-zero exit.
#   --no-execute-changeset creates and previews the change set without executing it.

aws cloudformation describe-stacks --stack-name my-stack \
  --query 'Stacks[0].Outputs[].{Key:OutputKey,Value:OutputValue}' -o table

aws cloudformation create-change-set --stack-name my-stack --change-set-name preview \
  --template-body file://template.yaml --capabilities CAPABILITY_NAMED_IAM
aws cloudformation wait change-set-create-complete --stack-name my-stack --change-set-name preview
aws cloudformation describe-change-set --stack-name my-stack --change-set-name preview \
  --query 'Changes[].{Action:ResourceChange.Action,Type:ResourceChange.ResourceType,ID:ResourceChange.LogicalResourceId}' -o table
aws cloudformation execute-change-set --stack-name my-stack --change-set-name preview

aws cloudformation delete-stack --stack-name my-stack
aws cloudformation wait stack-delete-complete --stack-name my-stack

DRIFT_ID=$(aws cloudformation detect-stack-drift --stack-name my-stack --query 'StackDriftDetectionId' -o text)
aws cloudformation describe-stack-resource-drifts --stack-name my-stack \
  --stack-resource-drift-status-filters MODIFIED DELETED -o table
```

`--capabilities` takes `CAPABILITY_IAM` and `CAPABILITY_NAMED_IAM`; stacks that use macros or nested transforms (SAM) additionally need `CAPABILITY_AUTO_EXPAND`. Wait on `change-set-create-complete` before describing or executing a change set — otherwise the describe can race the creation.

---

## ECS

> Source: https://docs.aws.amazon.com/cli/latest/reference/ecs/create-service.html
> Source: https://docs.aws.amazon.com/cli/latest/reference/ecs/update-service.html
> Source: https://docs.aws.amazon.com/cli/latest/reference/ecs/execute-command.html

```bash
aws ecs create-cluster --cluster-name prod
aws ecs describe-clusters --clusters prod --query 'clusters[0].{Status:status,Tasks:runningTasksCount}'

# Fargate needs --network-mode awsvpc plus both --cpu and --memory
aws ecs register-task-definition --family my-api --requires-compatibilities FARGATE \
  --network-mode awsvpc --cpu 512 --memory 1024 \
  --execution-role-arn arn:aws:iam::123456789012:role/ecs-exec-role \
  --task-role-arn arn:aws:iam::123456789012:role/my-api-task-role \
  --container-definitions '[{"name":"api","image":"123456789012.dkr.ecr.us-east-1.amazonaws.com/my-api:latest","portMappings":[{"containerPort":8080}],"logConfiguration":{"logDriver":"awslogs","options":{"awslogs-group":"/ecs/my-api","awslogs-region":"us-east-1","awslogs-stream-prefix":"ecs"}}}]'

aws ecs create-service --cluster prod --service-name my-api --task-definition my-api:3 \
  --desired-count 3 --launch-type FARGATE --enable-execute-command \
  --network-configuration "awsvpcConfiguration={subnets=[subnet-aaa,subnet-bbb],securityGroups=[sg-xxx],assignPublicIp=DISABLED}"
aws ecs wait services-stable --cluster prod --services my-api

# update-service takes --service. Only create-service takes --service-name.
aws ecs update-service --cluster prod --service my-api --task-definition my-api:4 --force-new-deployment
aws ecs wait services-stable --cluster prod --services my-api
aws ecs update-service --cluster prod --service my-api --desired-count 5

aws ecs execute-command --cluster prod --task "$TASK_ARN" --container api --command "/bin/sh" --interactive
```

- **Execution role vs task role**: the execution role is what the ECS agent uses (ECR pulls, `awslogs`, Secrets Manager); the task role is what the container's own AWS calls assume. Give containers a task role instead of baking in keys.
- `--cluster` defaults to a cluster literally named `default` on almost every ECS command — always pass it.
- `--task-definition`, `--force-new-deployment`, `--network-configuration`, `--load-balancers`, `--service-registries`, `--platform-version`, and `--service-connect-configuration` trigger a new deployment. `--desired-count`, placement flags, and `--health-check-grace-period-seconds` do not.
- Deployment defaults: `strategy ROLLING`, `maximumPercent 200`, `minimumHealthyPercent 100`, controller `ECS`, platform version `LATEST`, `availability-zone-rebalancing ENABLED`. Rolling replacement sends `SIGTERM`, then `SIGKILL` after 30 seconds.
- Target groups for `awsvpc` tasks must use target type `ip`, not `instance`.
- `execute-command` requires `--interactive` or `--non-interactive`, ECS Exec enabled on the service, `ssmmessages:*` on the task role, and the Session Manager plugin locally.

---

## EKS

> Source: https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html

**Never hardcode `--kubernetes-version`.** A minor version gets 14 months of standard support, then 12 months of extended support, then auto-upgrade — a literal in a script has roughly a two-year shelf life and then fails at cluster creation.

```bash
# Discover, or omit the flag and take the EKS default
aws eks describe-cluster-versions \
  --query 'clusterVersions[?defaultVersion].clusterVersion' -o text
aws eks describe-cluster-versions \
  --query 'clusterVersions[].{Version:clusterVersion,Status:status,EndStandard:endOfStandardSupportDate}' -o table

K8S=$(aws eks describe-cluster-versions --query 'clusterVersions[?defaultVersion].clusterVersion' -o text)
aws eks create-cluster --name prod --kubernetes-version "$K8S" \
  --role-arn arn:aws:iam::123456789012:role/EKSClusterRole \
  --resources-vpc-config subnetIds=subnet-aaa,subnet-bbb,securityGroupIds=sg-xxx
aws eks wait cluster-active --name prod
aws eks update-kubeconfig --name prod --region us-east-1

aws eks create-nodegroup --cluster-name prod --nodegroup-name workers \
  --node-role arn:aws:iam::123456789012:role/EKSNodeRole --subnets subnet-aaa subnet-bbb \
  --instance-types t3.medium --scaling-config minSize=2,maxSize=10,desiredSize=3
aws eks wait nodegroup-active --cluster-name prod --nodegroup-name workers

for addon in vpc-cni coredns kube-proxy; do
  aws eks create-addon --cluster-name prod --addon-name "$addon"
  aws eks wait addon-active --cluster-name prod --addon-name "$addon"
done
```

`describe-cluster-versions` returns `clusterVersion`, `defaultVersion`, `status` (`STANDARD_SUPPORT` / `EXTENDED_SUPPORT`), `endOfStandardSupportDate`, and `endOfExtendedSupportDate` per version — enough to fail a pipeline that is about to pin something near end of support.

---

## CloudWatch and Logs

> Source: https://docs.aws.amazon.com/cli/latest/reference/cloudwatch/put-metric-alarm.html
> Source: https://docs.aws.amazon.com/cli/latest/reference/cloudwatch/get-metric-statistics.html
> Source: https://docs.aws.amazon.com/cli/latest/reference/logs/put-retention-policy.html
> Source: https://docs.aws.amazon.com/cli/latest/reference/logs/tail.html

```bash
aws cloudwatch get-metric-statistics --namespace AWS/RDS --metric-name CPUUtilization \
  --dimensions Name=DBInstanceIdentifier,Value=prod-pg \
  --start-time $(date -u -d '24 hours ago' '+%Y-%m-%dT%H:%M:%SZ') \
  --end-time $(date -u '+%Y-%m-%dT%H:%M:%SZ') --period 3600 --statistics Average Maximum -o table

aws cloudwatch put-metric-data --namespace "MyApp" --metric-name OrdersProcessed --value 150 --unit Count

aws cloudwatch put-metric-alarm --alarm-name lambda-errors --namespace AWS/Lambda --metric-name Errors \
  --dimensions Name=FunctionName,Value=my-func --statistic Sum --period 300 --threshold 5 \
  --comparison-operator GreaterThanOrEqualToThreshold --evaluation-periods 1 \
  --treat-missing-data notBreaching \
  --alarm-actions arn:aws:sns:us-east-1:123456789012:alerts

aws logs create-log-group --log-group-name /app/my-service
aws logs put-retention-policy --log-group-name /app/my-service --retention-in-days 30
aws logs tail /app/my-service --follow --since 15m --format short
aws logs filter-log-events --log-group-name /app/my-service --filter-pattern "ERROR" \
  --start-time $(date -d '1 hour ago' +%s000) --query 'events[].message' -o text
```

- `get-metric-statistics --period` constraints depend on how old `--start-time` is: multiples of 60 s for 3–15 days back, 300 s for 15–63 days, 3600 s beyond 63 days. Max 1,440 data points per request, returned in **no guaranteed order**.
- `put-metric-alarm --period` accepts 10, 20, 30 (high-resolution metrics only) or any multiple of 60. `period × evaluation-periods` cannot exceed 604,800 s. `--treat-missing-data` is `breaching | notBreaching | ignore | missing` (default `missing`); DynamoDB-namespace alarms always behave as `ignore`. Max 5 `--alarm-actions`.
- `put-metric-data`: up to 1,000 metrics and 1 MB per request, 30 dimensions per metric; timestamps accepted up to 2 weeks back or 2 hours ahead. Don't prefix a custom namespace with `AWS/`.
- **`--retention-in-days` is an enum, not any integer**: 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653. New log groups never expire until one is set; remove a policy with `delete-retention-policy`.
- `logs tail` is a v2-only command. `--since` takes an ISO 8601 timestamp or **one** integer plus **one** unit (`s`/`m`/`h`/`d`/`w`) — `5h30m` is invalid. `--format` is `detailed` (default) | `short` | `json`. Default lookback is 10 minutes.
- `filter-log-events` uses **epoch milliseconds** (hence `+%s000`), pages at 1 MB / 10,000 events, and may return partially full or empty pages.

---

## SSM

> Source: https://docs.aws.amazon.com/cli/latest/reference/ssm/start-session.html
> Source: https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-sessions-start.html

```bash
aws ssm put-parameter --name /app/prod/db-host --value "prod-pg.example.com" --type String --overwrite
aws ssm put-parameter --name /app/prod/db-pass --value "$SECRET" --type SecureString --overwrite
aws ssm get-parameter --name /app/prod/db-pass --with-decryption --query 'Parameter.Value' -o text
aws ssm get-parameters-by-path --path /app/prod/ --recursive --with-decryption \
  --query 'Parameters[].{Name:Name,Value:Value}' -o table

COMMAND_ID=$(aws ssm send-command --document-name AWS-RunShellScript \
  --targets 'Key=tag:Env,Values=prod' --parameters 'commands=["df -h","uptime"]' \
  --query 'Command.CommandId' -o text)
aws ssm list-command-invocations --command-id "$COMMAND_ID" \
  --query 'CommandInvocations[].{Instance:InstanceId,Status:Status}' -o table

aws ssm start-session --target i-0123456789abcdef0
aws ssm start-session --target i-0123456789abcdef0 --document-name AWS-StartPortForwardingSession \
  --parameters portNumber=5432,localPortNumber=15432
aws ssm start-session --target i-0123456789abcdef0 \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters '{"host":["mydb.abc123.us-east-1.rds.amazonaws.com"],"portNumber":["5432"],"localPortNumber":["15432"]}'
```

- **The Session Manager plugin is a separate client-side install.** Without it `start-session` fails outright; the CLI does not bundle it.
- `--parameters` accepts shorthand `key=value,key=value` or JSON `'{"portNumber":["5432"], …}'`. AWS's Linux/macOS examples use the JSON form because of shell quoting; both are valid for the same map-of-list argument. `portNumber` defaults to 80.
- `AWS-StartPortForwardingSessionToRemoteHost` tunnels through a managed node to any host it can reach (an RDS endpoint, for example). ECS Exec-enabled tasks are addressable as `--target ecs:<cluster>_<container-id>_<runtime-id>`.
- Always `--type SecureString` for secrets, and `--with-decryption` to read them back.

---

## Route 53

> Source: https://docs.aws.amazon.com/cli/latest/reference/route53/create-hosted-zone.html
> Source: https://docs.aws.amazon.com/cli/latest/reference/route53/change-resource-record-sets.html
> Source: https://docs.aws.amazon.com/general/latest/gr/elb.html

```bash
ZONE_ID=$(aws route53 create-hosted-zone --name example.com --caller-reference "$(date +%s)" \
  --query 'HostedZone.Id' -o text | cut -d'/' -f3)     # Id comes back as /hostedzone/Z123…

CHANGE_ID=$(aws route53 change-resource-record-sets --hosted-zone-id "$ZONE_ID" --change-batch '{
  "Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"app.example.com","Type":"A","TTL":300,
    "ResourceRecords":[{"Value":"1.2.3.4"}]}}]}' --query 'ChangeInfo.Id' -o text)
aws route53 wait resource-record-sets-changed --id "$CHANGE_ID"      # polls until INSYNC

# Alias record. The hosted zone ID is region- AND load-balancer-type-specific:
# ALB/CLB share one value per region, NLB uses a different one. us-east-1 ALB/CLB = Z35SXDOTRQ7X7K.
# Look up other regions at https://docs.aws.amazon.com/general/latest/gr/elb.html, or read
# CanonicalHostedZoneId off the load balancer itself. CloudFront is always Z2FDTNDATAQYW2.
aws route53 change-resource-record-sets --hosted-zone-id "$ZONE_ID" --change-batch '{
  "Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"app.example.com","Type":"A",
    "AliasTarget":{"HostedZoneId":"Z35SXDOTRQ7X7K","DNSName":"myalb.us-east-1.elb.amazonaws.com",
    "EvaluateTargetHealth":true}}}]}'

aws route53 list-resource-record-sets --hosted-zone-id "$ZONE_ID" \
  --query 'ResourceRecordSets[].{Name:Name,Type:Type}' -o table
```

- `--caller-reference` is **required** and must be unique per real create — a timestamp works.
- Alias records omit `TTL` and `ResourceRecords` entirely; `AliasTarget` requires all three of `HostedZoneId`, `DNSName`, `EvaluateTargetHealth`.
- `UPSERT` creates or replaces (the idempotent action). `DELETE` must reproduce every original value exactly.
- Change batches are transactional and propagate in roughly 60 seconds. `list-resource-record-sets` returns up to 300 records per call; don't modify records while paging.

---

## STS

> Source: https://docs.aws.amazon.com/cli/latest/reference/sts/assume-role.html
> Source: https://docs.aws.amazon.com/cli/latest/reference/sts/get-caller-identity.html

```bash
aws sts get-caller-identity
aws sts get-caller-identity --query Account -o text          # account ID for building ARNs
aws sts get-caller-identity --query Arn -o text | grep -q ':root$' && { echo "refusing to run as root"; exit 1; }

# Prefer a role_arn/source_profile config profile (auto-cached and auto-refreshed) — see auth.md.
# Use the explicit call only for one-shot MFA sessions or when a profile isn't available:
creds=$(aws sts assume-role --role-arn arn:aws:iam::123456789012:role/DeployRole \
  --role-session-name "deploy-$(date +%s)" --duration-seconds 900 \
  --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' -o text)
export AWS_ACCESS_KEY_ID=$(echo "$creds" | awk '{print $1}')
export AWS_SECRET_ACCESS_KEY=$(echo "$creds" | awk '{print $2}')
export AWS_SESSION_TOKEN=$(echo "$creds" | awk '{print $3}')

aws sts get-session-token --serial-number arn:aws:iam::123456789012:mfa/my-device --token-code 123456
```

`assume-role` requires `--role-arn` and `--role-session-name` (2–64 chars). Useful extras: `--external-id`, `--serial-number`/`--token-code` (MFA), `--policy`/`--policy-arns` (session policies, which only narrow), `--tags`/`--transitive-tag-keys`, `--source-identity` (persists through chained assumptions for CloudTrail traceability). Set `--duration-seconds` to the shortest the task needs; remember the 1-hour role-chaining cap.

---

## VPC networking

> Source: https://docs.aws.amazon.com/cli/latest/reference/ec2/create-vpc.html
> Source: https://docs.aws.amazon.com/cli/latest/reference/ec2/create-subnet.html
> Source: https://docs.aws.amazon.com/cli/latest/reference/ec2/create-security-group.html
> Source: https://docs.aws.amazon.com/cli/latest/reference/ec2/authorize-security-group-ingress.html

```bash
VPC_ID=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 \
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=prod-vpc}]' \
  --query 'Vpc.VpcId' -o text)
aws ec2 wait vpc-available --vpc-ids "$VPC_ID"
aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-hostnames '{"Value":true}'

# Discover AZs — letter suffixes map to different physical zones per account
mapfile -t AZS < <(aws ec2 describe-availability-zones \
  --filters "Name=state,Values=available" --query 'AvailabilityZones[].ZoneName' -o text | tr '\t' '\n')

PUB_SUBNET=$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block 10.0.1.0/24 \
  --availability-zone "${AZS[0]}" --query 'Subnet.SubnetId' -o text)
PRIV_SUBNET=$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block 10.0.2.0/24 \
  --availability-zone "${AZS[1]}" --query 'Subnet.SubnetId' -o text)
aws ec2 wait subnet-available --subnet-ids "$PUB_SUBNET" "$PRIV_SUBNET"

IGW_ID=$(aws ec2 create-internet-gateway --query 'InternetGateway.InternetGatewayId' -o text)
aws ec2 attach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID"

RTB_ID=$(aws ec2 create-route-table --vpc-id "$VPC_ID" --query 'RouteTable.RouteTableId' -o text)
aws ec2 create-route --route-table-id "$RTB_ID" --destination-cidr-block 0.0.0.0/0 --gateway-id "$IGW_ID"
aws ec2 associate-route-table --route-table-id "$RTB_ID" --subnet-id "$PUB_SUBNET"

SG_ID=$(aws ec2 create-security-group --group-name web-sg --description "Web SG" \
  --vpc-id "$VPC_ID" --query 'GroupId' -o text)
aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 22 --cidr 10.0.0.0/8
aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 443 --cidr 0.0.0.0/0
```

- Subnet CIDRs run from `/28` to `/16`; AWS reserves the first four and last address of each. Omitting `--availability-zone` lets AWS choose.
- A new route table already contains the VPC-local route; `create-route` adds only the extra ones. `create-route` returns just `Return: true`.
- `create-security-group` requires `--group-name` and `--description`, and `--vpc-id` for any non-default VPC. Submitted CIDRs are canonicalized (`100.68.0.18/18` → `100.68.0.0/18`).
- `authorize-security-group-ingress` takes either the simple form (`--protocol` + `--port` + exactly one of `--cidr`/`--source-group`) or `--ip-permissions` for several rules in one call.
- Prefer SSM Session Manager over opening port 22 to the internet.

---

## Sources

- https://docs.aws.amazon.com/cli/latest/reference/resourcegroupstaggingapi/index.html
- https://docs.aws.amazon.com/cli/latest/reference/resourcegroupstaggingapi/tag-resources.html
- https://docs.aws.amazon.com/cli/latest/reference/resourcegroupstaggingapi/untag-resources.html
- https://docs.aws.amazon.com/cli/latest/reference/resourcegroupstaggingapi/get-resources.html
- https://docs.aws.amazon.com/cli/latest/reference/resourcegroupstaggingapi/get-tag-keys.html
- https://docs.aws.amazon.com/cli/latest/reference/resourcegroupstaggingapi/get-tag-values.html
- https://docs.aws.amazon.com/cli/latest/reference/resourcegroupstaggingapi/get-compliance-summary.html
- https://docs.aws.amazon.com/cli/latest/reference/resourcegroupstaggingapi/list-required-tags.html
- https://docs.aws.amazon.com/cli/latest/reference/resource-explorer-2/search.html
- https://docs.aws.amazon.com/cli/latest/reference/ec2/create-tags.html
- https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/Using_Tags.html
- https://docs.aws.amazon.com/cli/latest/reference/iam/index.html
- https://docs.aws.amazon.com/cli/latest/reference/iam/create-login-profile.html
- https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html
- https://docs.aws.amazon.com/IAM/latest/UserGuide/id-credentials-access-keys-update.html
- https://docs.aws.amazon.com/cli/latest/reference/s3/mb.html
- https://docs.aws.amazon.com/cli/latest/reference/s3/ls.html
- https://docs.aws.amazon.com/cli/latest/reference/s3/cp.html
- https://docs.aws.amazon.com/cli/latest/reference/s3/sync.html
- https://docs.aws.amazon.com/cli/latest/reference/s3/mv.html
- https://docs.aws.amazon.com/cli/latest/reference/s3/rm.html
- https://docs.aws.amazon.com/cli/latest/reference/s3/rb.html
- https://docs.aws.amazon.com/cli/latest/reference/s3/presign.html
- https://docs.aws.amazon.com/cli/latest/reference/s3api/create-bucket.html
- https://docs.aws.amazon.com/cli/latest/reference/s3api/put-bucket-versioning.html
- https://docs.aws.amazon.com/cli/latest/reference/s3api/put-bucket-encryption.html
- https://docs.aws.amazon.com/cli/latest/reference/s3api/put-public-access-block.html
- https://docs.aws.amazon.com/AmazonS3/latest/userguide/storage-class-intro.html
- https://docs.aws.amazon.com/cli/latest/reference/lambda/create-function.html
- https://docs.aws.amazon.com/cli/latest/reference/lambda/update-function-code.html
- https://docs.aws.amazon.com/cli/latest/reference/lambda/update-function-configuration.html
- https://docs.aws.amazon.com/cli/latest/reference/lambda/publish-layer-version.html
- https://docs.aws.amazon.com/cli/latest/reference/lambda/create-event-source-mapping.html
- https://docs.aws.amazon.com/cli/latest/reference/lambda/add-permission.html
- https://docs.aws.amazon.com/cli/latest/reference/lambda/invoke.html
- https://docs.aws.amazon.com/lambda/latest/dg/gettingstarted-limits.html
- https://docs.aws.amazon.com/lambda/latest/dg/lambda-runtimes.html
- https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/PostgreSQL.Concepts.General.DBVersions.html
- https://docs.aws.amazon.com/cli/latest/reference/cloudformation/deploy.html
- https://docs.aws.amazon.com/cli/latest/userguide/cliv2-migration-changes.html
- https://docs.aws.amazon.com/cli/latest/reference/ecs/create-cluster.html
- https://docs.aws.amazon.com/cli/latest/reference/ecs/register-task-definition.html
- https://docs.aws.amazon.com/cli/latest/reference/ecs/create-service.html
- https://docs.aws.amazon.com/cli/latest/reference/ecs/update-service.html
- https://docs.aws.amazon.com/cli/latest/reference/ecs/execute-command.html
- https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html
- https://docs.aws.amazon.com/cli/latest/reference/cloudwatch/put-metric-alarm.html
- https://docs.aws.amazon.com/cli/latest/reference/cloudwatch/get-metric-statistics.html
- https://docs.aws.amazon.com/cli/latest/reference/cloudwatch/put-metric-data.html
- https://docs.aws.amazon.com/cli/latest/reference/logs/create-log-group.html
- https://docs.aws.amazon.com/cli/latest/reference/logs/put-retention-policy.html
- https://docs.aws.amazon.com/cli/latest/reference/logs/filter-log-events.html
- https://docs.aws.amazon.com/cli/latest/reference/logs/tail.html
- https://docs.aws.amazon.com/cli/latest/reference/ssm/start-session.html
- https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-sessions-start.html
- https://docs.aws.amazon.com/cli/latest/reference/route53/create-hosted-zone.html
- https://docs.aws.amazon.com/cli/latest/reference/route53/change-resource-record-sets.html
- https://docs.aws.amazon.com/cli/latest/reference/route53/list-resource-record-sets.html
- https://docs.aws.amazon.com/cli/latest/reference/route53/wait/resource-record-sets-changed.html
- https://docs.aws.amazon.com/general/latest/gr/elb.html
- https://docs.aws.amazon.com/cli/latest/reference/sts/assume-role.html
- https://docs.aws.amazon.com/cli/latest/reference/sts/get-caller-identity.html
- https://docs.aws.amazon.com/cli/latest/reference/ec2/create-vpc.html
- https://docs.aws.amazon.com/cli/latest/reference/ec2/create-subnet.html
- https://docs.aws.amazon.com/cli/latest/reference/ec2/create-internet-gateway.html
- https://docs.aws.amazon.com/cli/latest/reference/ec2/attach-internet-gateway.html
- https://docs.aws.amazon.com/cli/latest/reference/ec2/create-route-table.html
- https://docs.aws.amazon.com/cli/latest/reference/ec2/create-route.html
- https://docs.aws.amazon.com/cli/latest/reference/ec2/create-security-group.html
- https://docs.aws.amazon.com/cli/latest/reference/ec2/authorize-security-group-ingress.html
- https://docs.aws.amazon.com/cli/latest/reference/ec2/run-instances.html
- https://github.com/chrishuffman5/awscliskills (commit ddab56be22be966ed9ba1b4b831526f95e3c801b)

Fetched: 2026-08-08
