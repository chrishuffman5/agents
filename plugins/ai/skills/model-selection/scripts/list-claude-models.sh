#!/usr/bin/env bash
# list-claude-models.sh — read-only inventory of Claude models available to your API key.
#
# Why: model IDs, context limits, and capability flags in any written catalog go stale.
# The Models API (GET /v1/models) is the authoritative live source and returns
# max_input_tokens, max_tokens, and a capabilities object per model
# (per https://platform.claude.com/docs/en/about-claude/models/overview).
#
# Read-only: performs GET requests only. No writes, no inference, no billing beyond
# a metadata request.
#
# Usage:
#   ANTHROPIC_API_KEY=sk-ant-... ./list-claude-models.sh          # table
#   ANTHROPIC_API_KEY=sk-ant-... ./list-claude-models.sh --raw    # raw JSON
#
# Optional overrides (defaults are the common first-party values; confirm against the
# current API reference if your org uses a different host or API version):
#   ANTHROPIC_BASE_URL   default https://api.anthropic.com
#   ANTHROPIC_VERSION    default 2023-06-01
#
# Sources:
#   https://platform.claude.com/docs/en/about-claude/models/overview
# Fetched: 2026-08-05

set -euo pipefail

BASE_URL="${ANTHROPIC_BASE_URL:-https://api.anthropic.com}"
API_VERSION="${ANTHROPIC_VERSION:-2023-06-01}"

if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
  echo "error: ANTHROPIC_API_KEY is not set" >&2
  exit 1
fi

for bin in curl jq; do
  command -v "$bin" >/dev/null 2>&1 || { echo "error: $bin is required" >&2; exit 1; }
done

fetch_page() {
  # $1 = optional after_id cursor
  url="${BASE_URL}/v1/models?limit=100"
  [ -n "${1:-}" ] && url="${url}&after_id=$1"
  curl -sS --fail-with-body \
    -H "x-api-key: ${ANTHROPIC_API_KEY}" \
    -H "anthropic-version: ${API_VERSION}" \
    "$url"
}

all='{"data":[]}'
cursor=""
while :; do
  page="$(fetch_page "$cursor")"
  all="$(jq -s '{data: (.[0].data + .[1].data)}' <(printf '%s' "$all") <(printf '%s' "$page"))"
  has_more="$(printf '%s' "$page" | jq -r '.has_more // false')"
  [ "$has_more" = "true" ] || break
  cursor="$(printf '%s' "$page" | jq -r '.last_id // empty')"
  [ -n "$cursor" ] || break
done

if [ "${1:-}" = "--raw" ]; then
  printf '%s\n' "$all" | jq .
  exit 0
fi

printf '%s\n' "$all" | jq -r '
  ["MODEL_ID","DISPLAY_NAME","MAX_INPUT","MAX_OUTPUT","CREATED"],
  ["--------","------------","---------","----------","-------"],
  (.data[] | [
     .id,
     (.display_name // "-"),
     (.max_input_tokens // "-" | tostring),
     (.max_tokens // "-" | tostring),
     (.created_at // "-")
   ])
  | @tsv' | column -t -s "$(printf '\t')"

echo
echo "Capability flags per model (empty means the field was not returned):"
printf '%s\n' "$all" | jq -r '.data[] | "  \(.id): \(.capabilities // {} | to_entries | map(select(.value == true) | .key) | join(", "))"'

echo
echo "Note: this lists models your organization can call today. Pricing, retirement dates,"
echo "and cloud (Bedrock/Vertex) model IDs are NOT in this response — see the skill's"
echo "references/ tables and re-verify against the cited vendor pages."
