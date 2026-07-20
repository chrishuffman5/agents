#!/usr/bin/env bash
# Purpose:        Find obvious waste in one region - unattached EBS volumes, unassociated EIPs, stopped instances still on disk
# Applies to:     AWS via CLI v2 (read-only IAM: ec2:Describe*)
# Read-only:      yes
# Inputs:         __REGION__ (repeat per region; waste hides in forgotten regions)
# Interpretation: This is "delete waste" - the first and cheapest FinOps lever, before right-sizing or commitments.
#                 Unattached volumes bill full price for nothing; available-state EIPs bill hourly precisely because
#                 they're idle; long-stopped instances still pay for their EBS. Confirm ownership before deleting (a
#                 volume may be a detached-for-forensics snapshot source) - but most of this is genuinely abandoned.
# Next step:      Snapshot-then-delete unattached volumes with owner signoff; release idle EIPs; terminate dead instances

set -euo pipefail
REGION="__REGION__"

echo "== Unattached EBS volumes"
aws ec2 describe-volumes --region "$REGION" --filters Name=status,Values=available \
    --query 'Volumes[].[VolumeId,Size,VolumeType,CreateTime]' --output text | sort -k4 |
    awk '{printf "%-22s %sGiB %-8s created %s\n", $1, $2, $3, $4}'

echo
echo "== Unassociated Elastic IPs (billing while idle)"
aws ec2 describe-addresses --region "$REGION" \
    --query 'Addresses[?AssociationId==`null`].[PublicIp,AllocationId]' --output text || echo "none"

echo
echo "== Stopped instances (still paying for EBS)"
aws ec2 describe-instances --region "$REGION" --filters Name=instance-state-name,Values=stopped \
    --query 'Reservations[].Instances[].[InstanceId,InstanceType,StateTransitionReason]' --output text || echo "none"
