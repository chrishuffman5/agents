#!/usr/bin/env bash
# Purpose:        Redrive-policy audit - queues without DLQs and maxReceiveCount sanity across the account
# Applies to:     AWS SQS via AWS CLI v2 (read-only IAM: sqs:ListQueues, sqs:GetQueueAttributes)
# Read-only:      yes
# Inputs:         AWS credentials/profile and region in the environment
# Prereqs:        jq
# Interpretation: NO-DLQ on a work queue means poison messages retry forever - they cycle through visibility timeouts
#                 eating consumer capacity until retention expires them (silent loss). maxReceiveCount=1 dead-letters
#                 on the FIRST transient hiccup (too aggressive); 3-5 is the usual balance. Also check the DLQ itself
#                 has retention long enough to actually investigate (14 days max).
# Next step:      Add redrive policies to flagged queues; pair with 01-queue-depth-audit.sh to watch DLQ flow after the change

set -euo pipefail

for url in $(aws sqs list-queues --query 'QueueUrls[]' --output text); do
    name="${url##*/}"
    case "$name" in *dlq*|*DLQ*|*dead*) continue;; esac
    rp=$(aws sqs get-queue-attributes --queue-url "$url" \
        --attribute-names RedrivePolicy --query 'Attributes.RedrivePolicy' --output text 2>/dev/null)
    if [[ -z "$rp" || "$rp" == "None" ]]; then
        printf '%-60s %s\n' "$name" "NO-DLQ <<< poison messages will cycle until retention expiry"
    else
        maxrc=$(echo "$rp" | jq -r '.maxReceiveCount')
        target=$(echo "$rp" | jq -r '.deadLetterTargetArn' | awk -F: '{print $NF}')
        printf '%-60s dlq=%-40s maxReceiveCount=%s\n' "$name" "$target" "$maxrc"
    fi
done
