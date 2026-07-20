#!/usr/bin/env bash
# Purpose:        Bucket size and object count from CloudWatch storage metrics - capacity picture without listing objects
# Applies to:     AWS S3 via AWS CLI v2 + CloudWatch (read-only IAM: cloudwatch:GetMetricStatistics, s3:ListAllMyBuckets)
# Read-only:      yes
# Inputs:         __REGION__ - region whose buckets to measure (metrics live in the bucket's region)
# Interpretation: BucketSizeBytes here is the StandardStorage class only - re-run with other StorageType values
#                 (StandardIAStorage, GlacierStorage...) for tiered buckets, or use S3 Storage Lens for the full split.
#                 Metrics lag ~24-48h; zeros for a non-empty bucket usually mean wrong region, not empty. Sudden growth
#                 inflections in these daily metrics are your first lead on runaway writers or failed lifecycle rules.
# Next step:      Cross-reference the biggest buckets against 02-lifecycle-versioning-audit.sh flags

set -euo pipefail

REGION="__REGION__"
start=$(date -u -d '3 days ago' +%Y-%m-%dT00:00:00 2>/dev/null || date -u -v-3d +%Y-%m-%dT00:00:00)
end=$(date -u +%Y-%m-%dT00:00:00)

printf '%-45s %15s %15s\n' "bucket" "size_gb" "objects"
for bucket in $(aws s3api list-buckets --query 'Buckets[].Name' --output text); do
    size=$(aws cloudwatch get-metric-statistics --region "$REGION" \
        --namespace AWS/S3 --metric-name BucketSizeBytes \
        --dimensions Name=BucketName,Value="$bucket" Name=StorageType,Value=StandardStorage \
        --start-time "$start" --end-time "$end" --period 86400 --statistics Average \
        --query 'Datapoints | sort_by(@,&Timestamp)[-1].Average' --output text 2>/dev/null)
    count=$(aws cloudwatch get-metric-statistics --region "$REGION" \
        --namespace AWS/S3 --metric-name NumberOfObjects \
        --dimensions Name=BucketName,Value="$bucket" Name=StorageType,Value=AllStorageTypes \
        --start-time "$start" --end-time "$end" --period 86400 --statistics Average \
        --query 'Datapoints | sort_by(@,&Timestamp)[-1].Average' --output text 2>/dev/null)
    [[ "$size" == "None" || -z "$size" ]] && continue
    printf '%-45s %15.1f %15.0f\n' "$bucket" "$(echo "$size / 1073741824" | bc -l)" "${count:-0}"
done | sort -k2 -rn
