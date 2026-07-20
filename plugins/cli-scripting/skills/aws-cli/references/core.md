# AWS CLI Core Reference

Authentication, output formats, JMESPath queries, pagination, and waiters.

---

## Authentication and Configuration

### Interactive Setup
```bash
aws configure                        # set default credentials
aws configure --profile prod         # named profile
aws configure list                   # show active config sources
aws configure get region             # get single value
aws configure set output table       # set single value
```

### Configuration Files
```ini
# ~/.aws/credentials
[default]
aws_access_key_id = AKIAIOSFODNN7EXAMPLE
aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY

[prod]
aws_access_key_id = AKIAI44QH8DHBEXAMPLE
aws_secret_access_key = je7MtGbClwBF/2Zp9Utk/h3yCo8nvbEXAMPLEKEY

# ~/.aws/config
[default]
region = us-east-1
output = json

[profile prod]
region = us-west-2
output = table
cli_pager =
```

### Environment Variables
```bash
export AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
export AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
export AWS_SESSION_TOKEN=AQoDYXdzEJr...       # temp creds only
export AWS_DEFAULT_REGION=us-east-1
export AWS_DEFAULT_OUTPUT=json
export AWS_PROFILE=prod
```

### SSO Authentication
```bash
aws configure sso                            # configure SSO
aws sso login --profile my-sso-profile       # login via browser
aws s3 ls --profile my-sso-profile           # use after login
aws sso logout                               # logout
```

### Assume Role (STS)
```bash
creds=$(aws sts assume-role \
  --role-arn arn:aws:iam::123456789012:role/DeployRole \
  --role-session-name deploy-session \
  --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' -o text)

export AWS_ACCESS_KEY_ID=$(echo "$creds" | awk '{print $1}')
export AWS_SECRET_ACCESS_KEY=$(echo "$creds" | awk '{print $2}')
export AWS_SESSION_TOKEN=$(echo "$creds" | awk '{print $3}')
```

### Instance Profile
```bash
# No config needed on EC2 with IAM instance profile
aws sts get-caller-identity    # verify identity
```

---

## Output Formats and JMESPath

### Output Formats
```bash
aws iam list-users --output json    # default — full JSON
aws iam list-users --output table   # human-readable
aws iam list-users --output text    # tab-delimited (scripting)
aws iam list-users --output yaml    # YAML
```

### JMESPath (--query)
```bash
# Single field
aws sts get-caller-identity --query 'Account' -o text

# Multiple fields
aws sts get-caller-identity --query '[Account, Arn, UserId]' -o text

# Flatten nested arrays
aws ec2 describe-instances --query 'Reservations[].Instances[].InstanceId' -o text

# Filter by value
aws ec2 describe-instances --query 'Reservations[].Instances[?State.Name==`running`].InstanceId' -o text

# Named projection
aws ec2 describe-instances \
  --query 'Reservations[].Instances[].{ID:InstanceId,Type:InstanceType,State:State.Name}' -o table

# sort_by
aws ec2 describe-images --owners amazon \
  --filters "Name=name,Values=amzn2-ami-hvm-*-x86_64-gp2" \
  --query 'sort_by(Images, &CreationDate)[-1].[ImageId,Name]' -o text

# max_by
aws ec2 describe-images --owners amazon \
  --filters "Name=name,Values=amzn2-ami-hvm-*-x86_64-gp2" \
  --query 'max_by(Images, &CreationDate).ImageId' -o text

# length (count)
aws iam list-users --query 'length(Users)'

# contains
aws iam list-roles --query 'Roles[?contains(RoleName, `lambda`)].RoleName' -o text

# starts_with
aws s3api list-buckets --query 'Buckets[?starts_with(Name, `prod-`)].Name' -o text

# Combining filter + projection
aws lambda list-functions \
  --query 'Functions[?Runtime==`python3.12`].{Name:FunctionName,Memory:MemorySize}' -o table

# Nested field from stack outputs
aws cloudformation describe-stacks --stack-name my-stack \
  --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerUrl`].OutputValue' -o text
```

### Capture for Scripting
```bash
BUCKET_REGION=$(aws s3api get-bucket-location --bucket my-bucket --query 'LocationConstraint' -o text)
ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' -o text)
VPC_ID=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 --query 'Vpc.VpcId' -o text)
```

---

## Pagination

```bash
# Auto-pagination (default in CLI v2) — retrieves ALL pages
aws s3api list-objects-v2 --bucket my-bucket

# Limit total items
aws s3api list-objects-v2 --bucket my-bucket --max-items 100

# Items per API call
aws s3api list-objects-v2 --bucket my-bucket --page-size 50

# Single page only
aws s3api list-objects-v2 --bucket my-bucket --no-paginate

# Resume from token
aws s3api list-objects-v2 --bucket my-bucket --starting-token eyJNYXJrZXIi...
```

---

## Waiters

Replace sleep loops with waiters. They poll the API until the desired state.

```bash
# EC2
aws ec2 wait instance-running --instance-ids i-0123456789abcdef0
aws ec2 wait instance-terminated --instance-ids i-0123456789abcdef0
aws ec2 wait vpc-available --vpc-ids vpc-0a1b2c3d
aws ec2 wait subnet-available --subnet-ids subnet-0a1b2c3d
aws ec2 wait nat-gateway-available --nat-gateway-ids nat-0a1b2c3d

# RDS
aws rds wait db-instance-available --db-instance-identifier my-db
aws rds wait db-snapshot-available --db-snapshot-identifier my-snap
aws rds wait db-cluster-available --db-cluster-identifier my-cluster

# Lambda
aws lambda wait function-active --function-name my-func
aws lambda wait function-updated --function-name my-func

# CloudFormation
aws cloudformation wait stack-create-complete --stack-name my-stack
aws cloudformation wait stack-update-complete --stack-name my-stack
aws cloudformation wait stack-delete-complete --stack-name my-stack

# ECS
aws ecs wait services-stable --cluster my-cluster --services my-svc
aws ecs wait tasks-running --cluster my-cluster --tasks arn:aws:ecs:...

# EKS
aws eks wait cluster-active --name my-cluster
aws eks wait nodegroup-active --cluster-name my-cluster --nodegroup-name workers
```
