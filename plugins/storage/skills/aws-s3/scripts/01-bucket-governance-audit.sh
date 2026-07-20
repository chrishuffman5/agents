#!/usr/bin/env bash
# Purpose:        Per-bucket governance audit - region, versioning, encryption, and public-access-block in one table
# Applies to:     AWS S3 via AWS CLI v2 (read-only IAM: s3:ListAllMyBuckets, s3:GetBucket*)
# Read-only:      yes
# Inputs:         AWS credentials/profile in the environment (AWS_PROFILE=__PROFILE__)
# Interpretation: Versioning 'None' on buckets holding anything you'd miss = no undelete. Encryption is default-on
#                 (SSE-S3) since 2023, but KMS-required workloads should show aws:kms here. Any 'false' in the
#                 public-access-block column is a finding unless the bucket intentionally serves public content.
# Next step:      02-lifecycle-versioning-audit.sh - versioned buckets without lifecycle rules are silent cost bombs

set -euo pipefail

for bucket in $(aws s3api list-buckets --query 'Buckets[].Name' --output text); do
    region=$(aws s3api get-bucket-location --bucket "$bucket" --query 'LocationConstraint' --output text 2>/dev/null || echo "?")
    versioning=$(aws s3api get-bucket-versioning --bucket "$bucket" --query 'Status' --output text 2>/dev/null || echo "None")
    encryption=$(aws s3api get-bucket-encryption --bucket "$bucket" \
        --query 'ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm' \
        --output text 2>/dev/null || echo "NONE")
    pab=$(aws s3api get-public-access-block --bucket "$bucket" \
        --query 'PublicAccessBlockConfiguration.[BlockPublicAcls,BlockPublicPolicy]' \
        --output text 2>/dev/null | tr '\t' '/' || echo "NOT-SET")
    printf '%-45s %-15s %-10s %-10s %s\n' "$bucket" "${region:-us-east-1}" "$versioning" "$encryption" "$pab"
done
