#!/usr/bin/env bash
# ============================================================================
# Bash - curl-based REST API Client
#
# Purpose : Generic REST API client using curl with authentication,
#           pagination, retry logic, and JSON output via jq.
# Version : 1.0.0
# Targets : Bash 4.0+, requires curl and jq
# Safety  : Read-only by default (GET). Other methods require -m flag.
#
# Usage:
#   ./04-api-client.sh -u https://api.github.com -e /users/octocat
#   ./04-api-client.sh -u $URL -t $TOKEN -e /repos -p --jq '.[] | .name'
# ============================================================================
set -euo pipefail

# ── Defaults ─────────────────────────────────────────────────────────────────
BASE_URL=""
ENDPOINT=""
TOKEN=""
API_KEY=""
METHOD="GET"
DATA=""
PAGINATE=false
PAGE_SIZE=100
MAX_PAGES=50
MAX_RETRIES=3
RETRY_DELAY=2
JQ_FILTER="."
OUTPUT_FILE=""
VERBOSE=false

# ── Prerequisites ────────────────────────────────────────────────────────────
for cmd in curl jq; do
  command -v "$cmd" &>/dev/null || { echo "Required: $cmd" >&2; exit 1; }
done

# ── Usage ────────────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  -u, --url URL           Base URL (required)
  -e, --endpoint PATH     API endpoint (required)
  -t, --token TOKEN       Bearer token
  -k, --api-key KEY       API key (X-API-Key header)
  -m, --method METHOD     HTTP method (default: GET)
  -d, --data JSON         Request body (JSON string)
  -p, --paginate          Auto-paginate (page/per_page params)
      --page-size N       Items per page (default: 100)
      --max-pages N       Maximum pages (default: 50)
      --retries N         Max retries (default: 3)
      --jq FILTER         jq filter for output (default: .)
  -o, --output FILE       Save output to file
  -v, --verbose           Verbose output
  -h, --help              Show help

Examples:
  $(basename "$0") -u https://api.github.com -e /users/octocat
  $(basename "$0") -u \$URL -t \$TOKEN -e /orgs/microsoft/repos -p
  $(basename "$0") -u \$URL -e /items -m POST -d '{"name":"test"}'
EOF
  exit "${1:-0}"
}

# ── Parse args ───────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case $1 in
    -u|--url)        BASE_URL="$2"; shift 2 ;;
    -e|--endpoint)   ENDPOINT="$2"; shift 2 ;;
    -t|--token)      TOKEN="$2"; shift 2 ;;
    -k|--api-key)    API_KEY="$2"; shift 2 ;;
    -m|--method)     METHOD="${2^^}"; shift 2 ;;
    -d|--data)       DATA="$2"; shift 2 ;;
    -p|--paginate)   PAGINATE=true; shift ;;
    --page-size)     PAGE_SIZE="$2"; shift 2 ;;
    --max-pages)     MAX_PAGES="$2"; shift 2 ;;
    --retries)       MAX_RETRIES="$2"; shift 2 ;;
    --jq)            JQ_FILTER="$2"; shift 2 ;;
    -o|--output)     OUTPUT_FILE="$2"; shift 2 ;;
    -v|--verbose)    VERBOSE=true; shift ;;
    -h|--help)       usage 0 ;;
    *)               echo "Unknown: $1" >&2; usage 1 ;;
  esac
done

[[ -n "$BASE_URL" ]]  || { echo "Error: --url required" >&2; usage 1; }
[[ -n "$ENDPOINT" ]]  || { echo "Error: --endpoint required" >&2; usage 1; }

# ── Build curl args ──────────────────────────────────────────────────────────
build_curl_args() {
  local url="$1"
  local -a args=(-s -S -w "\n%{http_code}" --max-time 30)

  # Auth
  [[ -n "$TOKEN" ]]  && args+=(-H "Authorization: Bearer $TOKEN")
  [[ -n "$API_KEY" ]] && args+=(-H "X-API-Key: $API_KEY")

  # Headers
  args+=(-H "Accept: application/json")
  args+=(-H "User-Agent: BashAPIClient/1.0")

  # Method and body
  args+=(-X "$METHOD")
  if [[ -n "$DATA" ]]; then
    args+=(-H "Content-Type: application/json" -d "$DATA")
  fi

  args+=("$url")
  printf '%s\n' "${args[@]}"
}

# ── Request with retry ───────────────────────────────────────────────────────
do_request() {
  local url="$1"
  local attempt=0
  local response http_code body delay

  while true; do
    ((attempt++))
    $VERBOSE && echo "[DEBUG] $METHOD $url (attempt $attempt)" >&2

    # Read curl args into array
    local -a curl_args=()
    while IFS= read -r arg; do curl_args+=("$arg"); done < <(build_curl_args "$url")

    response=$(curl "${curl_args[@]}" 2>/dev/null) || true
    http_code=$(echo "$response" | tail -1)
    body=$(echo "$response" | sed '$d')

    $VERBOSE && echo "[DEBUG] HTTP $http_code" >&2

    # Success
    if [[ "$http_code" =~ ^2 ]]; then
      echo "$body"
      return 0
    fi

    # Retry on transient errors
    if [[ "$http_code" =~ ^(429|500|502|503|504)$ ]] && ((attempt < MAX_RETRIES)); then
      delay=$((RETRY_DELAY * attempt))
      echo "[WARN] HTTP $http_code, retrying in ${delay}s..." >&2
      sleep "$delay"
      continue
    fi

    echo "[ERROR] HTTP $http_code: $body" >&2
    return 1
  done
}

# ── Paginated request ────────────────────────────────────────────────────────
do_paginated() {
  local page=1
  local all_items="[]"

  while ((page <= MAX_PAGES)); do
    local sep="?"
    [[ "$ENDPOINT" == *"?"* ]] && sep="&"
    local url="${BASE_URL}${ENDPOINT}${sep}page=${page}&per_page=${PAGE_SIZE}"

    $VERBOSE && echo "[DEBUG] Page $page: $url" >&2

    local body
    body=$(do_request "$url") || return 1

    local count
    count=$(echo "$body" | jq 'if type == "array" then length else 0 end' 2>/dev/null || echo 0)

    if [[ "$count" -eq 0 ]]; then
      break
    fi

    all_items=$(echo "$all_items" "$body" | jq -s '.[0] + .[1]')
    $VERBOSE && echo "[DEBUG] Page $page: $count items (total: $(echo "$all_items" | jq length))" >&2

    if ((count < PAGE_SIZE)); then
      break
    fi

    ((page++))
  done

  echo "$all_items"
}

# ── Execute ──────────────────────────────────────────────────────────────────
if $PAGINATE; then
  result=$(do_paginated)
else
  result=$(do_request "${BASE_URL}${ENDPOINT}")
fi

# ── Apply jq filter and output ───────────────────────────────────────────────
output=$(echo "$result" | jq "$JQ_FILTER" 2>/dev/null || echo "$result")

if [[ -n "$OUTPUT_FILE" ]]; then
  mkdir -p "$(dirname "$OUTPUT_FILE")"
  echo "$output" > "$OUTPUT_FILE"
  echo "Output saved to: $OUTPUT_FILE" >&2
else
  echo "$output"
fi
