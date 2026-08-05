#!/usr/bin/env bash
# count-tokens.sh — read-only: pre-flight the input token count of a Messages request body.
#
# Why: /v1/messages/count_tokens is FREE, does not consume Messages rate limit, and has its
# own RPM pool (Start 2,000/min, Build 4,000/min, Scale 8,000/min). Use it before sizing cost
# or context, especially when migrating across the Claude 4.7 tokenizer boundary (~30% more
# tokens for the same text on Opus 4.7+/Fable 5/Mythos 5).
#
# Usage:  ANTHROPIC_API_KEY=sk-ant-... ./count-tokens.sh request.json
#         cat request.json | ANTHROPIC_API_KEY=sk-ant-... ./count-tokens.sh -
#
# request.json takes the same structured inputs as Messages (model, system, messages, tools,
# images, PDFs, thinking blocks). Caveats: the result is an ESTIMATE that includes Anthropic
# system-added tokens you are not billed for; server-tool counts reflect only the first
# sampling call; prior-turn thinking blocks are ignored; cache_control is ignored.
#
# Read-only: generates no completion and stores nothing.
#
# Source: https://platform.claude.com/docs/en/build-with-claude/token-counting
# Fetched: 2026-08-05

set -euo pipefail

: "${ANTHROPIC_API_KEY:?Set ANTHROPIC_API_KEY first}"
BASE_URL="${ANTHROPIC_BASE_URL:-https://api.anthropic.com}"

payload_file="${1:?Usage: count-tokens.sh <request.json|->}"
if [ "$payload_file" = "-" ]; then
  payload=$(cat)
else
  [ -r "$payload_file" ] || { echo "Cannot read ${payload_file}" >&2; exit 1; }
  payload=$(cat "$payload_file")
fi

curl -sS "${BASE_URL}/v1/messages/count_tokens" \
  -H "x-api-key: ${ANTHROPIC_API_KEY}" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d "$payload"
echo
