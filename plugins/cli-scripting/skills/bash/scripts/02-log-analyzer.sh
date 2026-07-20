#!/usr/bin/env bash
# ============================================================================
# Bash - Log Analyzer
#
# Purpose : Parse log files, extract patterns, and generate summary reports
#           using grep, awk, sed, sort, and uniq.
# Version : 1.0.0
# Targets : Bash 4.0+, Linux/macOS
# Safety  : Read-only. Analyzes logs without modification.
#
# Usage:
#   ./02-log-analyzer.sh app.log
#   ./02-log-analyzer.sh -s 2 -l ERROR -n 20 app.log
# ============================================================================
set -euo pipefail

LOG_FILE=""
OUTPUT_DIR="."
SINCE=""
LEVEL_FILTER=""
TOP_N=10

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS] <logfile>

Options:
  -o, --output DIR    Output directory (default: .)
  -s, --since HOURS   Only analyze last N hours
  -l, --level LEVEL   Filter by level (ERROR|WARN|INFO)
  -n, --top N         Top entries to show (default: 10)
  -h, --help          Show help
EOF
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case $1 in
    -o|--output)  OUTPUT_DIR="$2"; shift 2 ;;
    -s|--since)   SINCE="$2"; shift 2 ;;
    -l|--level)   LEVEL_FILTER="${2^^}"; shift 2 ;;
    -n|--top)     TOP_N="$2"; shift 2 ;;
    -h|--help)    usage 0 ;;
    -*)           echo "Unknown: $1" >&2; usage 1 ;;
    *)            LOG_FILE="$1"; shift ;;
  esac
done

[[ -n "$LOG_FILE" ]] || { echo "Error: log file required" >&2; usage 1; }
[[ -f "$LOG_FILE" ]] || { echo "Error: not found: $LOG_FILE" >&2; exit 1; }

# ── Filter by time ───────────────────────────────────────────────────────────
filter_by_time() {
  if [[ -z "$SINCE" ]]; then
    cat "$LOG_FILE"
    return
  fi
  local cutoff
  cutoff=$(date -d "$SINCE hours ago" '+%Y-%m-%d %H:%M:%S' 2>/dev/null \
        || date -v-"${SINCE}H" '+%Y-%m-%d %H:%M:%S' 2>/dev/null \
        || echo "")
  if [[ -z "$cutoff" ]]; then
    cat "$LOG_FILE"
    return
  fi
  awk -v cutoff="$cutoff" '
    /^[0-9]{4}-[0-9]{2}-[0-9]{2}/ { ts = substr($0, 1, 19); if (ts >= cutoff) print; next }
    { print }
  ' "$LOG_FILE"
}

# ── Analyze ──────────────────────────────────────────────────────────────────
tmpfile=$(mktemp)
trap 'rm -f "$tmpfile"' EXIT

data=$(filter_by_time)
if [[ -n "$LEVEL_FILTER" ]]; then
  data=$(grep -E "\b${LEVEL_FILTER}\b" <<< "$data" || true)
fi
echo "$data" > "$tmpfile"
total=$(wc -l < "$tmpfile")

echo "============================================================"
echo "  LOG ANALYSIS REPORT"
printf "  File: %s\n" "$LOG_FILE"
printf "  Date: %s\n" "$(date '+%Y-%m-%d %H:%M:%S')"
printf "  Lines: %d\n" "$total"
[[ -n "$SINCE" ]] && printf "  Window: last %s hours\n" "$SINCE"
[[ -n "$LEVEL_FILTER" ]] && printf "  Filter: %s\n" "$LEVEL_FILTER"
echo "============================================================"

echo ""
echo "--- Level Summary ---"
awk '
  /\bERROR\b/ { err++ }
  /\bWARN\b/  { warn++ }
  /\bINFO\b/  { info++ }
  /\bDEBUG\b/ { dbg++ }
  END {
    printf "  %-8s %d\n", "ERROR",  err+0
    printf "  %-8s %d\n", "WARN",   warn+0
    printf "  %-8s %d\n", "INFO",   info+0
    printf "  %-8s %d\n", "DEBUG",  dbg+0
  }
' "$tmpfile"

echo ""
echo "--- Top Error Messages ($TOP_N) ---"
grep -E "\bERROR\b" "$tmpfile" 2>/dev/null \
  | sed 's/^[0-9-]* [0-9:]* //' \
  | sed 's/[0-9]\{4,\}/<NUM>/g' \
  | sort | uniq -c | sort -rn | head -"$TOP_N" \
  | awk '{printf "  %5d  %s\n", $1, substr($0, index($0,$2))}' \
  || echo "  (none)"

echo ""
echo "--- Errors by Hour ---"
grep -E "\bERROR\b" "$tmpfile" 2>/dev/null \
  | awk '{print substr($1,1,10), substr($2,1,2)":00"}' \
  | sort | uniq -c \
  | awk '{printf "  %-20s %d\n", $2" "$3, $1}' \
  || echo "  (none)"

echo ""
echo "--- Unique IPs ---"
grep -oE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' "$tmpfile" 2>/dev/null \
  | sort | uniq -c | sort -rn | head -"$TOP_N" \
  | awk '{printf "  %5d  %s\n", $1, $2}' \
  || echo "  (none)"

echo ""
echo "============================================================"
