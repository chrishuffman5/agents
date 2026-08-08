#!/usr/bin/env bash
# ============================================================================
# AWS CLI - VPC / Subnet / Security Group / EC2 provisioning
#
# Purpose : Provision a VPC with a public and a private subnet, internet
#           gateway, route table, security group, and one EC2 instance.
# Version : 1.1.0
# Targets : AWS CLI v2
# Safety  : Creates real, billable resources. Use --cleanup to tear down.
#
# Usage:
#   ./01-aws-provision.sh                 # provision
#   ./01-aws-provision.sh --cleanup       # delete everything tagged Project=$PROJECT
#   SSH_CIDR=203.0.113.4/32 ./01-aws-provision.sh   # optionally open port 22 to one address
#
# Requirements:
#   - AWS CLI v2, authenticated. Prefer `aws login`, `aws sso login`, or an
#     assume-role profile over static access keys (see references/auth.md).
#   - KEY_NAME below must be an existing EC2 key pair if SSH_CIDR is set.
#
# Notes:
#   - AWS_PAGER="" is set because CLI v2 pipes ALL output through a pager.
#   - Availability zones are discovered, not derived from the region name:
#     AZ letter suffixes map to different physical zones per account.
#   - Port 22 stays closed unless SSH_CIDR is supplied; the instance is
#     reachable through `aws ssm start-session` with an SSM-enabled role.
# ============================================================================
set -euo pipefail
export AWS_PAGER=""

# -- Configuration -----------------------------------------------------------
REGION="${AWS_REGION:-us-east-1}"
PROJECT="${PROJECT:-demo}"
VPC_CIDR="10.0.0.0/16"
PUB_CIDR="10.0.1.0/24"
PRIV_CIDR="10.0.2.0/24"
KEY_NAME="${KEY_NAME:-my-key}"
INSTANCE_TYPE="${INSTANCE_TYPE:-t3.micro}"
SSH_CIDR="${SSH_CIDR:-}"              # empty = do not open port 22 at all
AMI_NAME_FILTER="al2023-ami-2023*-x86_64"
# ----------------------------------------------------------------------------

log() { echo "[$(date -u +%H:%M:%S)] $*"; }

tag() {
  aws ec2 create-tags --region "$REGION" --resources "$1" \
    --tags Key=Name,Value="${PROJECT}-${2}" Key=Project,Value="$PROJECT"
}

# -- Identity guardrail ------------------------------------------------------
# get-caller-identity requires no permissions and cannot be denied by policy.
preflight() {
  local arn
  arn=$(aws sts get-caller-identity --region "$REGION" --query Arn -o text)
  case "$arn" in
    *:root)
      echo "Refusing to provision as the account root user ($arn)." >&2
      echo "Use an IAM Identity Center profile or an assumed role instead." >&2
      exit 1
      ;;
  esac
  log "Identity: $arn"
}

# -- Cleanup -----------------------------------------------------------------
cleanup() {
  log "Cleanup: tearing down ${PROJECT} environment..."

  INST=$(aws ec2 describe-instances --region "$REGION" \
    --filters "Name=tag:Project,Values=$PROJECT" "Name=instance-state-name,Values=running,stopped,pending" \
    --query 'Reservations[].Instances[].InstanceId' -o text 2>/dev/null || echo "")

  if [[ -n "$INST" && "$INST" != "None" ]]; then
    log "Terminating instances: $INST"
    # shellcheck disable=SC2086
    aws ec2 terminate-instances --region "$REGION" --instance-ids $INST >/dev/null
    # shellcheck disable=SC2086
    aws ec2 wait instance-terminated --region "$REGION" --instance-ids $INST
  fi

  VPC=$(aws ec2 describe-vpcs --region "$REGION" \
    --filters "Name=tag:Project,Values=$PROJECT" \
    --query 'Vpcs[0].VpcId' -o text 2>/dev/null || echo "None")

  # --output text renders an absent value as the literal string "None".
  if [[ "$VPC" != "None" && -n "$VPC" ]]; then
    aws ec2 describe-security-groups --region "$REGION" \
      --filters "Name=vpc-id,Values=$VPC" \
      --query 'SecurityGroups[?GroupName!=`default`].GroupId' -o text | \
    tr '\t' '\n' | while read -r sg; do
      [[ -z "$sg" || "$sg" == "None" ]] && continue
      log "Deleting SG: $sg"
      aws ec2 delete-security-group --region "$REGION" --group-id "$sg" 2>/dev/null || true
    done

    aws ec2 describe-subnets --region "$REGION" \
      --filters "Name=vpc-id,Values=$VPC" \
      --query 'Subnets[].SubnetId' -o text | \
    tr '\t' '\n' | while read -r sub; do
      [[ -z "$sub" || "$sub" == "None" ]] && continue
      log "Deleting subnet: $sub"
      aws ec2 delete-subnet --region "$REGION" --subnet-id "$sub" 2>/dev/null || true
    done

    aws ec2 describe-route-tables --region "$REGION" \
      --filters "Name=vpc-id,Values=$VPC" \
      --query 'RouteTables[?Associations[0].Main!=`true`].RouteTableId' -o text | \
    tr '\t' '\n' | while read -r rtb; do
      [[ -z "$rtb" || "$rtb" == "None" ]] && continue
      log "Deleting route table: $rtb"
      aws ec2 delete-route-table --region "$REGION" --route-table-id "$rtb" 2>/dev/null || true
    done

    aws ec2 describe-internet-gateways --region "$REGION" \
      --filters "Name=attachment.vpc-id,Values=$VPC" \
      --query 'InternetGateways[].InternetGatewayId' -o text | \
    tr '\t' '\n' | while read -r igw; do
      [[ -z "$igw" || "$igw" == "None" ]] && continue
      log "Detaching/deleting IGW: $igw"
      aws ec2 detach-internet-gateway --region "$REGION" --internet-gateway-id "$igw" --vpc-id "$VPC" 2>/dev/null || true
      aws ec2 delete-internet-gateway --region "$REGION" --internet-gateway-id "$igw" 2>/dev/null || true
    done

    log "Deleting VPC: $VPC"
    aws ec2 delete-vpc --region "$REGION" --vpc-id "$VPC"
  fi

  log "Cleanup complete."
}

if [[ "${1:-}" == "--cleanup" ]]; then
  preflight
  cleanup
  exit 0
fi

preflight

# -- Section 0: Discover availability zones -----------------------------------
# AZ name suffixes are mapped per account, so "${REGION}a" is not a portable AZ.
AZS=()
while read -r az; do
  [[ -n "$az" ]] && AZS+=("$az")
done < <(aws ec2 describe-availability-zones --region "$REGION" \
  --filters "Name=state,Values=available" \
  --query 'AvailabilityZones[].ZoneName' -o text | tr '\t' '\n')

if [[ ${#AZS[@]} -lt 2 ]]; then
  echo "Need at least 2 available AZs in $REGION, found ${#AZS[@]}." >&2
  exit 1
fi
AZ_A="${AZS[0]}"
AZ_B="${AZS[1]}"
log "Availability zones: $AZ_A, $AZ_B"

# -- Section 1: VPC ----------------------------------------------------------
log "Creating VPC ($VPC_CIDR)"
VPC_ID=$(aws ec2 create-vpc --region "$REGION" --cidr-block "$VPC_CIDR" \
  --query 'Vpc.VpcId' -o text)
aws ec2 wait vpc-available --region "$REGION" --vpc-ids "$VPC_ID"
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
PRIV_SUB=$(aws ec2 create-subnet --region "$REGION" --vpc-id "$VPC_ID" \
  --cidr-block "$PRIV_CIDR" --availability-zone "$AZ_B" \
  --query 'Subnet.SubnetId' -o text)
aws ec2 wait subnet-available --region "$REGION" --subnet-ids "$PUB_SUB" "$PRIV_SUB"
aws ec2 modify-subnet-attribute --region "$REGION" --subnet-id "$PUB_SUB" \
  --map-public-ip-on-launch
tag "$PUB_SUB" public-subnet
tag "$PRIV_SUB" private-subnet
log "  Public:  $PUB_SUB ($AZ_A)"
log "  Private: $PRIV_SUB ($AZ_B)"

# -- Section 4: Route Table ---------------------------------------------------
log "Creating route table"
RTB_ID=$(aws ec2 create-route-table --region "$REGION" --vpc-id "$VPC_ID" \
  --query 'RouteTable.RouteTableId' -o text)
# The VPC-local route already exists; only the default route needs adding.
aws ec2 create-route --region "$REGION" --route-table-id "$RTB_ID" \
  --destination-cidr-block 0.0.0.0/0 --gateway-id "$IGW_ID" >/dev/null
aws ec2 associate-route-table --region "$REGION" \
  --route-table-id "$RTB_ID" --subnet-id "$PUB_SUB" >/dev/null
tag "$RTB_ID" public-rt
log "  Route table: $RTB_ID"

# -- Section 5: Security Group ------------------------------------------------
log "Creating security group"
SG_ID=$(aws ec2 create-security-group --region "$REGION" \
  --group-name "${PROJECT}-web-sg" --description "Web server SG" \
  --vpc-id "$VPC_ID" --query 'GroupId' -o text)
aws ec2 wait security-group-exists --region "$REGION" --group-ids "$SG_ID"
aws ec2 authorize-security-group-ingress --region "$REGION" --group-id "$SG_ID" \
  --protocol tcp --port 80 --cidr 0.0.0.0/0 >/dev/null
aws ec2 authorize-security-group-ingress --region "$REGION" --group-id "$SG_ID" \
  --protocol tcp --port 443 --cidr 0.0.0.0/0 >/dev/null
if [[ -n "$SSH_CIDR" ]]; then
  log "  Opening port 22 to $SSH_CIDR"
  aws ec2 authorize-security-group-ingress --region "$REGION" --group-id "$SG_ID" \
    --protocol tcp --port 22 --cidr "$SSH_CIDR" >/dev/null
else
  log "  Port 22 left closed — use 'aws ssm start-session --target <instance-id>'"
fi
tag "$SG_ID" web-sg
log "  SG: $SG_ID"

# -- Section 6: EC2 Instance --------------------------------------------------
log "Finding latest Amazon Linux 2023 AMI"
AMI_ID=$(aws ec2 describe-images --region "$REGION" --owners amazon \
  --filters "Name=name,Values=${AMI_NAME_FILTER}" "Name=state,Values=available" \
  --query 'sort_by(Images, &CreationDate)[-1].ImageId' -o text)
log "  AMI: $AMI_ID"

log "Launching EC2 instance ($INSTANCE_TYPE)"
RUN_ARGS=(--region "$REGION" --image-id "$AMI_ID" --instance-type "$INSTANCE_TYPE"
          --subnet-id "$PUB_SUB" --security-group-ids "$SG_ID")
[[ -n "$SSH_CIDR" ]] && RUN_ARGS+=(--key-name "$KEY_NAME")

INSTANCE_ID=$(aws ec2 run-instances "${RUN_ARGS[@]}" \
  --query 'Instances[0].InstanceId' -o text)
tag "$INSTANCE_ID" web-server
log "  Instance: $INSTANCE_ID"

log "Waiting for instance to be running..."
aws ec2 wait instance-running --region "$REGION" --instance-ids "$INSTANCE_ID"

# Attach an instance profile instead of copying credentials onto the host, and
# enforce IMDSv2 (HttpTokens = required) with
# `aws ec2 modify-instance-metadata-options` — that is an EC2 instance setting,
# not an AWS CLI credential setting.

PUBLIC_IP=$(aws ec2 describe-instances --region "$REGION" --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' -o text)

# -- Section 7: Output Summary ------------------------------------------------
log "=========================================="
log "Provisioning complete!"
log "  Region:       $REGION"
log "  VPC:          $VPC_ID"
log "  Public Sub:   $PUB_SUB ($AZ_A)"
log "  Private Sub:  $PRIV_SUB ($AZ_B)"
log "  Security Grp: $SG_ID"
log "  Instance:     $INSTANCE_ID"
log "  Public IP:    $PUBLIC_IP"
if [[ -n "$SSH_CIDR" ]]; then
  log "  SSH:          ssh -i ~/.ssh/${KEY_NAME}.pem ec2-user@${PUBLIC_IP}"
else
  log "  Shell:        aws ssm start-session --target ${INSTANCE_ID}"
fi
log "  Cleanup:      $0 --cleanup"
log "=========================================="
