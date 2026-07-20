#!/usr/bin/env bash
# Purpose:        Find versioned buckets with no lifecycle rules and buckets with no noncurrent-version expiration - the S3 cost bombs
# Applies to:     AWS S3 via AWS CLI v2 (read-only IAM: s3:ListAllMyBuckets, s3:GetLifecycleConfiguration, s3:GetBucketVersioning)
# Read-only:      yes
# Inputs:         AWS credentials/profile in the environment
# Prereqs:        jq
# Interpretation: Versioning without NoncurrentVersionExpiration means every overwrite/delete accumulates forever -
#                 storage grows monotonically and invisibly (the console shows current versions only). Buckets flagged
#                 here need a lifecycle rule: expire noncurrent versions after N days + AbortIncompleteMultipartUpload
#                 (unfinished multiparts also bill silently).
# Next step:      Add lifecycle rules to flagged buckets; measure the win in Storage Lens / CloudWatch BucketSizeBytes after a cycle

set -euo pipefail

for bucket in $(aws s3api list-buckets --query 'Buckets[].Name' --output text); do
    versioning=$(aws s3api get-bucket-versioning --bucket "$bucket" --query 'Status' --output text 2>/dev/null || echo "None")
    lc=$(aws s3api get-bucket-lifecycle-configuration --bucket "$bucket" 2>/dev/null || echo '')

    if [[ -z "$lc" ]]; then
        rules=0; noncurrent="no"; multipart="no"
    else
        rules=$(echo "$lc" | jq '.Rules | length')
        noncurrent=$(echo "$lc" | jq -r '[.Rules[] | select(.NoncurrentVersionExpiration or .NoncurrentVersionTransitions)] | if length > 0 then "yes" else "no" end')
        multipart=$(echo "$lc" | jq -r '[.Rules[] | select(.AbortIncompleteMultipartUpload)] | if length > 0 then "yes" else "no" end')
    fi

    flag=""
    [[ "$versioning" == "Enabled" && "$noncurrent" == "no" ]] && flag="<<< COST RISK: versioned, no noncurrent expiration"
    printf '%-45s versioning=%-9s rules=%-3s noncurrent-exp=%-4s abort-multipart=%-4s %s\n' \
        "$bucket" "$versioning" "$rules" "$noncurrent" "$multipart" "$flag"
done
