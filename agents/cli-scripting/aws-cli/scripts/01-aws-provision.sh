#!/usr/bin/env bash
# ============================================================================
# AWS CLI - Complete VPC/Subnet/EC2 Provisioning
#
# Purpose : Provision a complete VPC environment with public/private subnets,
#           internet gateway, NAT gateway, security groups, and EC2 instance.
# Version : 1.0.0
# Targets : AWS CLI v2
# Safety  : Creates new resources. Use --cleanup to tear down.
#
# Usage:
#   ./01-aws-provision.sh                # provision environment
#   ./01-aws-provision.sh --cleanup      # delete everything
#
# Requirements:
#   - AWS CLI v2 configured (aws configure)
#   - EC2 key pair already created (KEY_NAME below)
#
# Sections:
#   1. VPC
#   2. Internet Gateway
#   3. Subnets (Public + Private)
#   4. Route Tables
#   5. Security Group
#   6. EC2 Instance
#   7. Output Summary
# ============================================================================
set -euo pipefail

# -- Configuration -----------------------------------------------------------
REGION="us-east-1"
PROJECT="demo"
VPC_CIDR="10.0.0.0/16"
PUB_CIDR="10.0.1.0/24"
PRIV_CIDR="10.0.2.0/24"
AZ_A="${REGION}a"
AZ_B="${REGION}b"
KEY_NAME="my-key"
INSTANCE_TYPE="t3.micro"
# Use latest Amazon Linux 2023
AMI_QUERY="Name=al2023-ami-2023*-x86_64,Values=*"
# ----------------------------------------------------------------------------

log() { echo "[$(date -u +%H:%M:%S)] $*"; }

tag() {
  aws ec2 create-tags --region "$REGION" --resources "$1" \
    --tags Key=Name,Value="${PROJECT}-${2}" Key=Project,Value="$PROJECT"
}

find_resource() {
  local filter_name="$1" filter_value="$2" query="$3"
  local result
  result=$(aws ec2 describe-tags --region "$REGION" \
    --filters "Name=key,Values=Name" "Name=value,Values=${PROJECT}-${filter_value}" \
    --query "Tags[?ResourceType=='${filter_name}'].ResourceId | [0]" -o text 2>/dev/null || echo "None")
  echo "$result"
}

# -- Cleanup -----------------------------------------------------------------
cleanup() {
  log "Cleanup: tearing down ${PROJECT} environment..."

  # Find resources by tag
  INST=$(aws ec2 describe-instances --region "$REGION" \
    --filters "Name=tag:Project,Values=$PROJECT" "Name=instance-state-name,Values=running,stopped" \
    --query 'Reservations[].Instances[].InstanceId' -o text 2>/dev/null || echo "")

  if [[ -n "$INST" && "$INST" != "None" ]]; then
    log "Terminating instances: $INST"
    aws ec2 terminate-instances --region "$REGION" --instance-ids $INST
    aws ec2 wait instance-terminated --region "$REGION" --instance-ids $INST
  fi

  VPC=$(aws ec2 describe-vpcs --region "$REGION" \
    --filters "Name=tag:Project,Values=$PROJECT" \
    --query 'Vpcs[0].VpcId' -o text 2>/dev/null || echo "None")

  if [[ "$VPC" != "None" && -n "$VPC" ]]; then
    # Delete security groups (non-default)
    aws ec2 describe-security-groups --region "$REGION" \
      --filters "Name=vpc-id,Values=$VPC" \
      --query 'SecurityGroups[?GroupName!=`default`].GroupId' -o text | \
    tr '\t' '\n' | while read -r sg; do
      [[ -z "$sg" || "$sg" == "None" ]] && continue
      log "Deleting SG: $sg"
      aws ec2 delete-security-group --region "$REGION" --group-id "$sg" 2>/dev/null || true
    done

    # Delete subnets
    aws ec2 describe-subnets --region "$REGION" \
      --filters "Name=vpc-id,Values=$VPC" \
      --query 'Subnets[].SubnetId' -o text | \
    tr '\t' '\n' | while read -r sub; do
      [[ -z "$sub" || "$sub" == "None" ]] && continue
      log "Deleting subnet: $sub"
      aws ec2 delete-subnet --region "$REGION" --subnet-id "$sub" 2>/dev/null || true
    done

    # Delete route tables (non-main)
    aws ec2 describe-route-tables --region "$REGION" \
      --filters "Name=vpc-id,Values=$VPC" \
      --query 'RouteTables[?Associations[0].Main!=`true`].RouteTableId' -o text | \
    tr '\t' '\n' | while read -r rtb; do
      [[ -z "$rtb" || "$rtb" == "None" ]] && continue
      log "Deleting route table: $rtb"
      aws ec2 delete-route-table --region "$REGION" --route-table-id "$rtb" 2>/dev/null || true
    done

    # Detach and delete IGW
    aws ec2 describe-internet-gateways --region "$REGION" \
      --filters "Name=attachment.vpc-id,Values=$VPC" \
      --query 'InternetGateways[].InternetGatewayId' -o text | \
    tr '\t' '\n' | while read -r igw; do
      [[ -z "$igw" || "$igw" == "None" ]] && continue
      log "Detaching/deleting IGW: $igw"
      aws ec2 detach-internet-gateway --region "$REGION" --internet-gateway-id "$igw" --vpc-id "$VPC"
      aws ec2 delete-internet-gateway --region "$REGION" --internet-gateway-id "$igw"
    done

    log "Deleting VPC: $VPC"
    aws ec2 delete-vpc --region "$REGION" --vpc-id "$VPC"
  fi

  log "Cleanup complete."
}

if [[ "${1:-}" == "--cleanup" ]]; then
  cleanup
  exit 0
fi

# -- Section 1: VPC ----------------------------------------------------------
log "Creating VPC ($VPC_CIDR)"
VPC_ID=$(aws ec2 create-vpc --region "$REGION" --cidr-block "$VPC_CIDR" \
  --query 'Vpc.VpcId' -o text)
aws ec2 modify-vpc-attribute --region "$REGION" --vpc-id "$VPC_ID" \
  --enable-dns-hostnames '{"Value":true}'
tag "$VPC_ID" vpc
log "  VPC: $VPC_ID"

# -- Section 2: Internet Gateway ----------------------------------------------
log "Creating Internet Gateway"
IGW_ID=$(aws ec2 create-internet-gateway --region "$REGION" \
  --query 'InternetGateway.InternetGatewayId' -o text)
aws ec2 attach-internet-gateway --region "$REGION" \
  --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID"
tag "$IGW_ID" igw
log "  IGW: $IGW_ID"

# -- Section 3: Subnets -------------------------------------------------------
log "Creating subnets"
PUB_SUB=$(aws ec2 create-subnet --region "$REGION" --vpc-id "$VPC_ID" \
  --cidr-block "$PUB_CIDR" --availability-zone "$AZ_A" \
  --query 'Subnet.SubnetId' -o text)
aws ec2 modify-subnet-attribute --region "$REGION" --subnet-id "$PUB_SUB" \
  --map-public-ip-on-launch
tag "$PUB_SUB" public-subnet
log "  Public:  $PUB_SUB ($AZ_A)"

PRIV_SUB=$(aws ec2 create-subnet --region "$REGION" --vpc-id "$VPC_ID" \
  --cidr-block "$PRIV_CIDR" --availability-zone "$AZ_B" \
  --query 'Subnet.SubnetId' -o text)
tag "$PRIV_SUB" private-subnet
log "  Private: $PRIV_SUB ($AZ_B)"

# -- Section 4: Route Table ---------------------------------------------------
log "Creating route table"
RTB_ID=$(aws ec2 create-route-table --region "$REGION" --vpc-id "$VPC_ID" \
  --query 'RouteTable.RouteTableId' -o text)
aws ec2 create-route --region "$REGION" --route-table-id "$RTB_ID" \
  --destination-cidr-block 0.0.0.0/0 --gateway-id "$IGW_ID"
aws ec2 associate-route-table --region "$REGION" \
  --route-table-id "$RTB_ID" --subnet-id "$PUB_SUB"
tag "$RTB_ID" public-rt
log "  Route table: $RTB_ID"

# -- Section 5: Security Group ------------------------------------------------
log "Creating security group"
SG_ID=$(aws ec2 create-security-group --region "$REGION" \
  --group-name "${PROJECT}-web-sg" --description "Web server SG" \
  --vpc-id "$VPC_ID" --query 'GroupId' -o text)
aws ec2 authorize-security-group-ingress --region "$REGION" --group-id "$SG_ID" \
  --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --region "$REGION" --group-id "$SG_ID" \
  --protocol tcp --port 80 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --region "$REGION" --group-id "$SG_ID" \
  --protocol tcp --port 443 --cidr 0.0.0.0/0
tag "$SG_ID" web-sg
log "  SG: $SG_ID"

# -- Section 6: EC2 Instance --------------------------------------------------
log "Finding latest Amazon Linux 2023 AMI"
AMI_ID=$(aws ec2 describe-images --region "$REGION" --owners amazon \
  --filters "Name=name,Values=al2023-ami-2023*-x86_64" "Name=state,Values=available" \
  --query 'sort_by(Images, &CreationDate)[-1].ImageId' -o text)
log "  AMI: $AMI_ID"

log "Launching EC2 instance ($INSTANCE_TYPE)"
INSTANCE_ID=$(aws ec2 run-instances --region "$REGION" \
  --image-id "$AMI_ID" --instance-type "$INSTANCE_TYPE" \
  --key-name "$KEY_NAME" --subnet-id "$PUB_SUB" \
  --security-group-ids "$SG_ID" \
  --query 'Instances[0].InstanceId' -o text)
tag "$INSTANCE_ID" web-server
log "  Instance: $INSTANCE_ID"

log "Waiting for instance to be running..."
aws ec2 wait instance-running --region "$REGION" --instance-ids "$INSTANCE_ID"

PUBLIC_IP=$(aws ec2 describe-instances --region "$REGION" --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' -o text)

# -- Section 7: Output Summary ------------------------------------------------
log "=========================================="
log "Provisioning complete!"
log "  VPC:          $VPC_ID"
log "  Public Sub:   $PUB_SUB"
log "  Private Sub:  $PRIV_SUB"
log "  Security Grp: $SG_ID"
log "  Instance:     $INSTANCE_ID"
log "  Public IP:    $PUBLIC_IP"
log "  SSH:          ssh -i ~/.ssh/${KEY_NAME}.pem ec2-user@${PUBLIC_IP}"
log "  Cleanup:      $0 --cleanup"
log "=========================================="
