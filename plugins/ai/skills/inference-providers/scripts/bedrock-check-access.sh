#!/usr/bin/env bash
# bedrock-check-access.sh — read-only: answer "is this AWS account actually entitled to invoke
# Anthropic models on Bedrock in this Region, and which inference profiles exist?"
#
# Why: on Bedrock, model access is enabled by default but gated by Marketplace auto-subscription
# (up to 15 minutes on first invoke), a one-time Anthropic first-time-use form, and Region
# availability. A first call that fails with AccessDeniedException is usually one of those, not IAM.
# Newer Claude models also cannot be invoked by base model ID at all — they require an inference
# profile ID. This script shows both facts without spending a single inference token.
#
# Usage:  ./bedrock-check-access.sh [region] [provider]
#         ./bedrock-check-access.sh us-west-2
#         ./bedrock-check-access.sh eu-central-1 anthropic
#
# Read-only: issues only List*/Get* calls. Invokes no model, creates no agreement, buys nothing.
# Requires: AWS CLI v2 (>= 2.27.42 for get-foundation-model-availability), credentials configured.
#
# Sources: https://docs.aws.amazon.com/bedrock/latest/userguide/model-access.html
#          https://docs.aws.amazon.com/bedrock/latest/userguide/inference-profiles-support.html
#          https://platform.claude.com/docs/en/api/claude-on-amazon-bedrock
# Fetched: 2026-08-05

set -uo pipefail

REGION="${1:-${AWS_REGION:-us-west-2}}"
PROVIDER="${2:-anthropic}"

command -v aws >/dev/null 2>&1 || { echo "aws CLI not found" >&2; exit 1; }

echo "== Caller identity =="
aws sts get-caller-identity --output table 2>&1 || {
  echo "Could not resolve caller identity — configure credentials first." >&2
  exit 1
}

echo
echo "== Foundation models from provider '${PROVIDER}' in ${REGION} =="
echo "(base model IDs; newer Claude models may be absent here and reachable only via a profile)"
models=$(aws bedrock list-foundation-models \
  --region "$REGION" \
  --by-provider "$PROVIDER" \
  --query "modelSummaries[*].modelId" \
  --output text 2>&1) || { echo "$models" >&2; models=""; }
if [ -n "$models" ]; then
  printf '%s\n' $models
else
  echo "(none returned — check Region and bedrock:ListFoundationModels permission)"
fi

echo
echo "== Inference profiles visible in ${REGION} =="
echo "(system-defined profile IDs are geography prefix + base model ID, e.g. us.anthropic....)"
aws bedrock list-inference-profiles \
  --region "$REGION" \
  --query "inferenceProfileSummaries[*].[inferenceProfileId,status,type]" \
  --output table 2>&1 || echo "(list-inference-profiles unavailable — needs bedrock:ListInferenceProfiles)"

echo
echo "== Entitlement per model (agreement / authorization / entitlement / region) =="
echo "All four must read AVAILABLE/AUTHORIZED before invocation reliably succeeds."
if [ -z "$models" ]; then
  echo "(no models to check)"
else
  for m in $models; do
    out=$(aws bedrock get-foundation-model-availability \
      --region "$REGION" \
      --model-id "$m" \
      --query "[agreementAvailability.status,authorizationStatus,entitlementAvailability,regionAvailability]" \
      --output text 2>&1)
    if [ $? -eq 0 ]; then
      printf '%-60s %s\n' "$m" "$out"
    else
      printf '%-60s %s\n' "$m" "(unavailable: $(printf '%s' "$out" | head -n1))"
    fi
  done
fi

echo
echo "Reminders:"
echo " - Anthropic models need a one-time first-time-use form per account/Org before first invoke"
echo "   (does not apply on the bedrock-mantle endpoint)."
echo " - First invoke in a fresh account can AccessDenied for up to 15 min while Marketplace"
echo "   auto-subscription propagates. Wait before rewriting IAM."
echo " - Inference profiles and Provisioned Throughput are mutually exclusive purchase paths."

# ## Sources
# - https://docs.aws.amazon.com/bedrock/latest/userguide/model-access.html
# - https://docs.aws.amazon.com/bedrock/latest/userguide/inference-profiles-support.html
# - https://docs.aws.amazon.com/bedrock/latest/userguide/cross-region-inference.html
# - https://docs.aws.amazon.com/bedrock/latest/userguide/prov-throughput.html
# - https://platform.claude.com/docs/en/api/claude-on-amazon-bedrock
#
# Fetched: 2026-08-05
