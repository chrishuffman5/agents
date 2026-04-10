# AWS CLI Scripting Patterns

Idempotent patterns, batch operations, infrastructure scripting.

---

## Idempotent Create Patterns

### Check-Before-Create

```bash
# VPC — check if exists by tag
EXISTING_VPC=$(aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=prod-vpc" \
  --query 'Vpcs[0].VpcId' -o text)

if [[ "$EXISTING_VPC" == "None" ]]; then
  VPC_ID=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 --query 'Vpc.VpcId' -o text)
  aws ec2 create-tags --resources "$VPC_ID" --tags Key=Name,Value=prod-vpc
else
  VPC_ID="$EXISTING_VPC"
  echo "VPC already exists: $VPC_ID"
fi

# S3 bucket
if ! aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
  aws s3api create-bucket --bucket "$BUCKET_NAME" --region us-east-1
else
  echo "Bucket $BUCKET_NAME already exists"
fi

# Lambda function
if ! aws lambda get-function --function-name "$FUNC_NAME" &>/dev/null; then
  aws lambda create-function --function-name "$FUNC_NAME" \
    --runtime python3.12 --handler index.handler \
    --role "$ROLE_ARN" --zip-file fileb://function.zip
else
  aws lambda update-function-code --function-name "$FUNC_NAME" --zip-file fileb://function.zip
fi

# SSM parameter
if ! aws ssm get-parameter --name "$PARAM_NAME" &>/dev/null; then
  aws ssm put-parameter --name "$PARAM_NAME" --value "$VALUE" --type String
fi

# Security group by name
EXISTING_SG=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=web-sg" "Name=vpc-id,Values=$VPC_ID" \
  --query 'SecurityGroups[0].GroupId' -o text 2>/dev/null || echo "None")
```

---

## Error Handling

```bash
#!/usr/bin/env bash
set -euo pipefail
trap 'echo "ERROR on line $LINENO. Cleaning up..."; cleanup' ERR

# Suppress errors for existence checks
if aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
  echo "Bucket exists"
fi

# Capture exit code
if ! aws lambda get-function --function-name "$FUNC" &>/dev/null; then
  echo "Function not found, creating..."
fi
```

---

## Batch Operations

```bash
# Stop all running instances in a VPC
aws ec2 describe-instances \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].InstanceId' -o text | \
xargs -r aws ec2 stop-instances --instance-ids

# Delete all log groups matching a prefix
aws logs describe-log-groups --log-group-name-prefix /test/ \
  --query 'logGroups[].logGroupName' -o text | \
tr '\t' '\n' | while read -r lg; do
  echo "Deleting: $lg"
  aws logs delete-log-group --log-group-name "$lg"
done

# Parallel S3 bucket cleanup
aws s3api list-buckets --query 'Buckets[?starts_with(Name,`dev-`)].Name' -o text | \
tr '\t' '\n' | xargs -P 4 -I {} aws s3 rb s3://{} --force

# Tag all untagged EC2 instances
aws ec2 describe-instances \
  --query 'Reservations[].Instances[?!not_null(Tags[?Key==`env`])].InstanceId' -o text | \
tr '\t' '\n' | while read -r id; do
  [[ -z "$id" || "$id" == "None" ]] && continue
  aws ec2 create-tags --resources "$id" --tags Key=env,Value=unknown
done

# Load SSM parameters into environment
while IFS=$'\t' read -r name value; do
  var=$(echo "$name" | sed 's|/app/prod/||' | tr '/' '_' | tr '[:lower:]' '[:upper:]')
  export "$var=$value"
done < <(aws ssm get-parameters-by-path --path /app/prod/ --recursive --with-decryption \
  --query 'Parameters[].[Name,Value]' -o text)
```

---

## Infrastructure Provisioning Pattern

```bash
#!/usr/bin/env bash
set -euo pipefail

REGION="us-east-1"
PROJECT="demo"
VPC_CIDR="10.0.0.0/16"
PUB_CIDR="10.0.1.0/24"
PRIV_CIDR="10.0.2.0/24"
KEY_NAME="my-key"
AMI_ID="ami-0123456789abcdef0"   # Get latest with describe-images
INSTANCE_TYPE="t3.micro"

tag() { aws ec2 create-tags --resources "$1" --tags Key=Name,Value="${PROJECT}-${2}" Key=Project,Value="$PROJECT"; }
log() { echo "[$(date -u +%H:%M:%S)] $*"; }

# 1. VPC
log "Creating VPC"
VPC_ID=$(aws ec2 create-vpc --cidr-block "$VPC_CIDR" --query 'Vpc.VpcId' -o text)
aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-hostnames '{"Value":true}'
tag "$VPC_ID" vpc

# 2. Internet Gateway
log "Creating Internet Gateway"
IGW_ID=$(aws ec2 create-internet-gateway --query 'InternetGateway.InternetGatewayId' -o text)
aws ec2 attach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID"
tag "$IGW_ID" igw

# 3. Subnets
log "Creating subnets"
PUB_SUB=$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block "$PUB_CIDR" \
  --availability-zone "${REGION}a" --query 'Subnet.SubnetId' -o text)
aws ec2 modify-subnet-attribute --subnet-id "$PUB_SUB" --map-public-ip-on-launch
tag "$PUB_SUB" public-subnet

PRIV_SUB=$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block "$PRIV_CIDR" \
  --availability-zone "${REGION}b" --query 'Subnet.SubnetId' -o text)
tag "$PRIV_SUB" private-subnet

# 4. Route table
log "Creating route table"
RTB_ID=$(aws ec2 create-route-table --vpc-id "$VPC_ID" --query 'RouteTable.RouteTableId' -o text)
aws ec2 create-route --route-table-id "$RTB_ID" --destination-cidr-block 0.0.0.0/0 --gateway-id "$IGW_ID"
aws ec2 associate-route-table --route-table-id "$RTB_ID" --subnet-id "$PUB_SUB"
tag "$RTB_ID" public-rt

# 5. Security group
log "Creating security group"
SG_ID=$(aws ec2 create-security-group --group-name "${PROJECT}-web-sg" \
  --description "Web SG" --vpc-id "$VPC_ID" --query 'GroupId' -o text)
aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 80 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 443 --cidr 0.0.0.0/0
tag "$SG_ID" web-sg

# 6. EC2 Instance
log "Launching EC2 instance"
INSTANCE_ID=$(aws ec2 run-instances --image-id "$AMI_ID" --instance-type "$INSTANCE_TYPE" \
  --key-name "$KEY_NAME" --subnet-id "$PUB_SUB" --security-group-ids "$SG_ID" \
  --query 'Instances[0].InstanceId' -o text)
tag "$INSTANCE_ID" web-server
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"

PUBLIC_IP=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' -o text)

log "=========================================="
log "Provisioning complete!"
log "  VPC:         $VPC_ID"
log "  Instance:    $INSTANCE_ID"
log "  Public IP:   $PUBLIC_IP"
log "  SSH:         ssh -i ~/.ssh/${KEY_NAME}.pem ec2-user@${PUBLIC_IP}"
log "=========================================="
```

---

## Cleanup Pattern

```bash
cleanup() {
  echo "Cleaning up..."
  aws ec2 terminate-instances --instance-ids "$INSTANCE_ID" 2>/dev/null || true
  aws ec2 wait instance-terminated --instance-ids "$INSTANCE_ID" 2>/dev/null || true
  aws ec2 delete-security-group --group-id "$SG_ID" 2>/dev/null || true
  aws ec2 delete-subnet --subnet-id "$PUB_SUB" 2>/dev/null || true
  aws ec2 delete-subnet --subnet-id "$PRIV_SUB" 2>/dev/null || true
  aws ec2 delete-route-table --route-table-id "$RTB_ID" 2>/dev/null || true
  aws ec2 detach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID" 2>/dev/null || true
  aws ec2 delete-internet-gateway --internet-gateway-id "$IGW_ID" 2>/dev/null || true
  aws ec2 delete-vpc --vpc-id "$VPC_ID" 2>/dev/null || true
}
trap cleanup EXIT SIGINT SIGTERM
```
