#!/usr/bin/env bash
# openrouter-status.sh — read-only: show what an OpenRouter key can see and spend.
#
# Why: OpenRouter rate limits are account-global (extra keys do not raise them), insufficient
# balance surfaces as HTTP 402 rather than 429, and free ":free" model variants have their own
# per-minute/per-day caps tied to lifetime credits purchased. Check the key before blaming routing.
# The optional model filter shows the hosts and prices behind a slug so you can see what default
# price-weighted routing will pick from.
#
# Usage:  OPENROUTER_API_KEY=sk-or-... ./openrouter-status.sh
#         OPENROUTER_API_KEY=sk-or-... ./openrouter-status.sh anthropic/claude
#
# Read-only: two GETs. Runs no inference, consumes no credits, changes no settings.
#
# Sources: https://openrouter.ai/docs/api-reference/limits
#          https://openrouter.ai/docs/api-reference/overview
#          https://openrouter.ai/docs/quickstart
# Fetched: 2026-08-05

set -uo pipefail

: "${OPENROUTER_API_KEY:?Set OPENROUTER_API_KEY first}"
BASE_URL="${OPENROUTER_BASE_URL:-https://openrouter.ai/api/v1}"
FILTER="${1:-}"

command -v curl >/dev/null 2>&1 || { echo "curl not found" >&2; exit 1; }
HAS_JQ=0
command -v jq >/dev/null 2>&1 && HAS_JQ=1

fetch() {
  # $1 = path; prints body, returns non-zero on non-2xx
  local resp status body
  resp=$(curl -sS -w '\n%{http_code}' "${BASE_URL}$1" \
    -H "Authorization: Bearer ${OPENROUTER_API_KEY}") || return 1
  status=$(printf '%s' "$resp" | tail -n1)
  body=$(printf '%s' "$resp" | sed '$d')
  printf '%s' "$body"
  case "$status" in
    2*) return 0 ;;
    402) echo >&2 "HTTP 402 — credit balance exhausted (this is not a rate limit; retrying will not help)"; return 1 ;;
    *)   echo >&2 "HTTP ${status}"; return 1 ;;
  esac
}

echo "== Key status (GET /key) =="
if key=$(fetch "/key"); then
  if [ "$HAS_JQ" -eq 1 ]; then
    printf '%s\n' "$key" | jq '.data'
  else
    printf '%s\n' "$key"
  fi
else
  printf '%s\n' "${key:-}" >&2
fi

echo
if [ -n "$FILTER" ]; then
  echo "== Models matching '${FILTER}' (GET /models) =="
else
  echo "== Model catalog summary (GET /models) — pass a slug substring to filter =="
fi

if models=$(fetch "/models"); then
  if [ "$HAS_JQ" -eq 1 ]; then
    printf '%s\n' "$models" | jq -r --arg f "$FILTER" '
      "slug\tctx\tprompt$/tok\tcompletion$/tok",
      (.data[]?
       | select($f == "" or (.id | test($f; "i")))
       | [.id, (.context_length // "-"),
          (.pricing.prompt // "-"), (.pricing.completion // "-")]
       | @tsv)
    ' | { command -v column >/dev/null 2>&1 && column -t -s "$(printf '\t')" || cat; }
  else
    printf '%s\n' "$models"
    echo >&2 "(install jq for a formatted table)"
  fi
else
  printf '%s\n' "${models:-}" >&2
fi

echo
echo "Reminders:"
echo " - Rate limits are account-global: more keys or accounts do not raise them."
echo " - 402 = out of credits (never retry-able); 429 = rate limit (backoff applies)."
echo " - Budget/guardrail caps EXCLUDE BYOK spend unless you explicitly enable inclusion."
echo " - Log the response 'model' field per request — it names the host that actually served you."

# ## Sources
# - https://openrouter.ai/docs/quickstart
# - https://openrouter.ai/docs/api-reference/overview
# - https://openrouter.ai/docs/api-reference/limits
# - https://openrouter.ai/docs/use-cases/byok
#
# Fetched: 2026-08-05
