#!/usr/bin/env bash
# list-models.sh — read-only: enumerate the model IDs and capability fields your API key can see.
#
# Why: model IDs and capability envelopes move. Never hardcode a matrix — ask the API.
# The response includes max_input_tokens, max_tokens, and capabilities per model.
#
# Usage:  ANTHROPIC_API_KEY=sk-ant-... ./list-models.sh
#
# Read-only: issues a single GET. Consumes no tokens and creates nothing.
#
# Source: https://platform.claude.com/docs/en/about-claude/models/overview
# Fetched: 2026-08-05

set -euo pipefail

: "${ANTHROPIC_API_KEY:?Set ANTHROPIC_API_KEY first}"
BASE_URL="${ANTHROPIC_BASE_URL:-https://api.anthropic.com}"

response=$(curl -sS -w '\n%{http_code}' "${BASE_URL}/v1/models?limit=100" \
  -H "x-api-key: ${ANTHROPIC_API_KEY}" \
  -H "anthropic-version: 2023-06-01")

status=$(printf '%s' "$response" | tail -n1)
body=$(printf '%s' "$response" | sed '$d')

if [ "$status" != "200" ]; then
  echo "HTTP ${status}" >&2
  printf '%s\n' "$body" >&2
  exit 1
fi

if command -v jq >/dev/null 2>&1; then
  printf '%s\n' "$body" | jq -r '
    "id\tmax_input_tokens\tmax_tokens",
    (.data[]? | [.id, (.max_input_tokens // "-"), (.max_tokens // "-")] | @tsv)
  ' | column -t -s "$(printf '\t')" 2>/dev/null || printf '%s\n' "$body" | jq '.data'
else
  printf '%s\n' "$body"
  echo >&2 "(install jq for a formatted table)"
fi
