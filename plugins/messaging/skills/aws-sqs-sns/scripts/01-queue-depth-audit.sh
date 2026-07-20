#!/usr/bin/env bash
# Purpose:        Depth and in-flight audit across all SQS queues, with DLQ accumulation flagged - the account-wide backlog map
# Applies to:     AWS SQS via AWS CLI v2 (read-only IAM: sqs:ListQueues, sqs:GetQueueAttributes)
# Read-only:      yes
# Inputs:         AWS credentials/profile and region in the environment
# Interpretation: visible growing = producers outpacing consumers (scale consumers or fix their errors). not_visible
#                 (in-flight) pinned high = consumers receiving but not deleting - handler failures burning through
#                 receive counts toward the redrive policy. ANY depth on a *-dlq/*-dead* queue = failed messages
#                 accumulating; a DLQ nobody drains is deferred data loss - inspect, fix the cause, redrive.
# Next step:      For DLQ buildup: sample messages (ReceiveMessage without delete), fix the poison cause, then redrive to source

set -euo pipefail

for url in $(aws sqs list-queues --query 'QueueUrls[]' --output text); do
    name="${url##*/}"
    attrs=$(aws sqs get-queue-attributes --queue-url "$url" \
        --attribute-names ApproximateNumberOfMessages ApproximateNumberOfMessagesNotVisible ApproximateNumberOfMessagesDelayed \
        --query 'Attributes' --output json)
    visible=$(echo "$attrs"  | grep -o '"ApproximateNumberOfMessages": *"[0-9]*"'          | grep -o '[0-9]*' | tail -1)
    inflight=$(echo "$attrs" | grep -o '"ApproximateNumberOfMessagesNotVisible": *"[0-9]*"' | grep -o '[0-9]*' | tail -1)
    delayed=$(echo "$attrs"  | grep -o '"ApproximateNumberOfMessagesDelayed": *"[0-9]*"'    | grep -o '[0-9]*' | tail -1)
    flag=""
    case "$name" in *dlq*|*DLQ*|*dead*) [[ "${visible:-0}" -gt 0 ]] && flag="<<< DLQ BUILDUP";; esac
    printf '%-60s visible=%-8s inflight=%-8s delayed=%-6s %s\n' "$name" "${visible:-0}" "${inflight:-0}" "${delayed:-0}" "$flag"
done | sort -t= -k2 -rn
