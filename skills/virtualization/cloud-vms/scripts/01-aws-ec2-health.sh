#!/usr/bin/env bash
# ============================================================================
# AWS EC2 - Instance Health Dashboard
#
# Purpose : Comprehensive EC2 health report including instance inventory,
#           status checks, EBS volume status, security group audit,
#           and recent CloudWatch alarms.
# Version : 1.0.0
# Targets : AWS CLI v2 with configured credentials
# Safety  : Read-only. No modifications to AWS resources.
#
# Sections:
#   1. Account and Region
#   2. Instance Inventory
#   3. Instance Status Checks
#   4. EBS Volume Status
#   5. Unattached Volumes
#   6. Security Group Audit
#   7. Elastic IP Usage
# ============================================================================
set -euo pipefail

SEP="$(printf '=%.0s' {1..70})"

section() {
    echo ""
    echo "$SEP"
    echo "  $1"
    echo "$SEP"
}

REGION="${AWS_DEFAULT_REGION:-$(aws configure get region 2>/dev/null || echo 'us-east-1')}"

# ── Section 1: Account and Region ──────────────────────────────────────────
section "SECTION 1 - Account and Region"

ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text 2>/dev/null || echo "unknown")
IDENTITY=$(aws sts get-caller-identity --query 'Arn' --output text 2>/dev/null || echo "unknown")

echo "  Account ID : $ACCOUNT_ID"
echo "  Identity   : $IDENTITY"
echo "  Region     : $REGION"

# ── Section 2: Instance Inventory ──────────────────────────────────────────
section "SECTION 2 - Instance Inventory"

echo "  Name                          | Instance ID         | Type          | State    | Public IP"
echo "  ------------------------------|---------------------|---------------|----------|----------------"

aws ec2 describe-instances \
  --query 'Reservations[].Instances[].[Tags[?Key==`Name`].Value|[0],InstanceId,InstanceType,State.Name,PublicIpAddress]' \
  --output text 2>/dev/null | \
  while IFS=$'\t' read -r name id type state ip; do
    printf "  %-31s | %-19s | %-13s | %-8s | %s\n" \
      "${name:-<unnamed>}" "$id" "$type" "$state" "${ip:-none}"
  done || echo "  [ERROR] Unable to list instances"

echo ""
running=$(aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].InstanceId' \
  --output text 2>/dev/null | wc -w || echo "0")
stopped=$(aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=stopped" \
  --query 'Reservations[].Instances[].InstanceId' \
  --output text 2>/dev/null | wc -w || echo "0")
echo "  Running: $running | Stopped: $stopped"

# ── Section 3: Instance Status Checks ─────────────────────────────────────
section "SECTION 3 - Instance Status Checks"

aws ec2 describe-instance-status \
  --query 'InstanceStatuses[].[InstanceId,InstanceState.Name,SystemStatus.Status,InstanceStatus.Status]' \
  --output text 2>/dev/null | \
  while IFS=$'\t' read -r id state sys inst; do
    status="OK"
    [[ "$sys" != "ok" || "$inst" != "ok" ]] && status="DEGRADED"
    printf "  %-19s | State: %-8s | System: %-8s | Instance: %-8s | %s\n" \
      "$id" "$state" "$sys" "$inst" "$status"
  done || echo "  [INFO] No running instances or unable to query status"

# ── Section 4: EBS Volume Status ───────────────────────────────────────────
section "SECTION 4 - EBS Volume Status"

aws ec2 describe-volumes \
  --query 'Volumes[].[VolumeId,State,VolumeType,Size,Attachments[0].InstanceId]' \
  --output text 2>/dev/null | \
  while IFS=$'\t' read -r vid state vtype size attached; do
    printf "  %-22s | %-10s | %-6s | %4s GB | Attached: %s\n" \
      "$vid" "$state" "$vtype" "$size" "${attached:-none}"
  done || echo "  [ERROR] Unable to list volumes"

# ── Section 5: Unattached Volumes ──────────────────────────────────────────
section "SECTION 5 - Unattached Volumes (Cost Review)"

unattached=$(aws ec2 describe-volumes \
  --filters "Name=status,Values=available" \
  --query 'Volumes[].[VolumeId,Size,VolumeType,CreateTime]' \
  --output text 2>/dev/null)

if [[ -n "$unattached" ]]; then
    echo "$unattached" | while IFS=$'\t' read -r vid size vtype created; do
        printf "  [WARN] %-22s | %4s GB | %-6s | Created: %s\n" "$vid" "$size" "$vtype" "$created"
    done
else
    echo "  [OK] No unattached volumes found"
fi

# ── Section 6: Security Group Audit ────────────────────────────────────────
section "SECTION 6 - Security Groups with 0.0.0.0/0 Ingress"

aws ec2 describe-security-groups \
  --filters "Name=ip-permission.cidr,Values=0.0.0.0/0" \
  --query 'SecurityGroups[].[GroupId,GroupName]' \
  --output text 2>/dev/null | \
  while IFS=$'\t' read -r gid gname; do
    echo "  [REVIEW] $gid ($gname) -- has open ingress rules"
  done || echo "  [OK] No security groups with 0.0.0.0/0 ingress found"

# ── Section 7: Elastic IP Usage ────────────────────────────────────────────
section "SECTION 7 - Elastic IP Usage"

aws ec2 describe-addresses \
  --query 'Addresses[].[PublicIp,AllocationId,InstanceId,AssociationId]' \
  --output text 2>/dev/null | \
  while IFS=$'\t' read -r ip alloc instance assoc; do
    status="associated"
    [[ -z "$instance" || "$instance" == "None" ]] && status="UNASSOCIATED (billing)"
    printf "  %-15s | %-28s | Instance: %-19s | %s\n" \
      "$ip" "$alloc" "${instance:-none}" "$status"
  done || echo "  [INFO] No Elastic IPs allocated"

echo ""
echo "$SEP"
echo "  AWS EC2 Health Check Complete - $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "$SEP"
