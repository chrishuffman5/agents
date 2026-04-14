#!/usr/bin/env bash
# ============================================================================
# SELinux - AVC Denial Analysis
#
# Version : 1.0.0
# Targets : RHEL 8+ with SELinux enabled
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. AVC Denial Summary
#   2. Top Denied Source Domains
#   3. Top Denied Target Types
#   4. Top Denied Object Classes
#   5. Top Denied Permissions
#   6. audit2why Analysis
#   7. Suggested Fixes
#   8. Permissive vs Enforcing Activity
# ============================================================================
set -euo pipefail

RED='\033[0;31m'; YELLOW='\033[0;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

header() { echo -e "\n${BOLD}${CYAN}== $1 ==${RESET}"; }
ok()     { echo -e "  ${GREEN}[OK]${RESET}    $1"; }
warn()   { echo -e "  ${YELLOW}[WARN]${RESET}  $1"; }
fail()   { echo -e "  ${RED}[FAIL]${RESET}  $1"; }
info()   { echo -e "  ${CYAN}[INFO]${RESET}  $1"; }

HOURS="${1:-24}"
info "Analyzing AVC denials from the last ${HOURS} hours..."

# -- Collect AVC Data --------------------------------------------------------
TMPFILE=$(mktemp /tmp/selinux-avc-XXXXXX.log)
trap 'rm -f "$TMPFILE"' EXIT

TS=$(date -d "${HOURS} hours ago" "+%m/%d/%Y %H:%M:%S" 2>/dev/null || echo "")
if [[ -n "$TS" ]]; then
  ausearch -m AVC -ts "$TS" 2>/dev/null > "$TMPFILE" || true
else
  ausearch -m AVC -ts today 2>/dev/null > "$TMPFILE" || true
fi

TOTAL=$(grep -c "^type=AVC" "$TMPFILE" 2>/dev/null || echo "0")

# -- 1. Summary --------------------------------------------------------------
header "AVC Denial Summary (last ${HOURS}h)"

if [[ "$TOTAL" -eq 0 ]]; then
  ok "No AVC denials found in the specified timeframe."
  exit 0
fi

if [[ "$TOTAL" -lt 10 ]]; then
  warn "Total AVC denials: $TOTAL"
elif [[ "$TOTAL" -lt 100 ]]; then
  warn "Total AVC denials: $TOTAL -- elevated activity"
else
  fail "Total AVC denials: $TOTAL -- significant SELinux activity!"
fi

# -- 2. Top Denied Source Domains --------------------------------------------
header "Top Denied Source Domains"

echo "  Count  Domain"
echo "  -----  ----------------------------------------"
grep "^type=AVC" "$TMPFILE" | \
  grep -oP 'scontext=\S+:\S+:\K[^:]+' | \
  sort | uniq -c | sort -rn | head -10 | \
  awk '{ printf "  %-6s %s\n", $1, $2 }'

# -- 3. Top Denied Target Types ----------------------------------------------
header "Top Denied Target Types"

echo "  Count  Target Type"
echo "  -----  ----------------------------------------"
grep "^type=AVC" "$TMPFILE" | \
  grep -oP 'tcontext=\S+:\S+:\K[^:]+' | \
  sort | uniq -c | sort -rn | head -10 | \
  awk '{ printf "  %-6s %s\n", $1, $2 }'

# -- 4. Top Denied Object Classes -------------------------------------------
header "Top Denied Object Classes"

echo "  Count  Object Class"
echo "  -----  ----------------------------------------"
grep "^type=AVC" "$TMPFILE" | \
  grep -oP 'tclass=\K\S+' | \
  sort | uniq -c | sort -rn | head -10 | \
  awk '{ printf "  %-6s %s\n", $1, $2 }'

# -- 5. Top Denied Permissions -----------------------------------------------
header "Top Denied Permissions"

echo "  Count  Permission"
echo "  -----  ----------------------------------------"
grep "^type=AVC" "$TMPFILE" | \
  grep -oP 'denied \{ \K[^}]+' | \
  tr ' ' '\n' | grep -v '^$' | \
  sort | uniq -c | sort -rn | head -10 | \
  awk '{ printf "  %-6s %s\n", $1, $2 }'

# -- 6. audit2why Analysis --------------------------------------------------
header "audit2why Analysis (Top 5 Unique Denial Patterns)"

grep "^type=AVC" "$TMPFILE" | \
  grep -oP 'scontext=\S+ tcontext=\S+ tclass=\S+' | \
  sort -u | head -5 | while IFS= read -r pattern; do
    echo -e "\n  ${YELLOW}Pattern: $pattern${RESET}"
    SAMPLE=$(grep "^type=AVC" "$TMPFILE" | grep -F "$pattern" | head -1)
    if [[ -n "$SAMPLE" ]]; then
      echo "$SAMPLE" | audit2why 2>/dev/null | sed 's/^/    /' || \
        echo "    (audit2why not available or no explanation)"
    fi
  done

# -- 7. Suggested Fixes -----------------------------------------------------
header "Suggested Fixes (audit2allow)"

echo -e "  ${YELLOW}NOTE: Review all suggestions before applying. Never blindly execute.${RESET}\n"

info "Checking for applicable boolean fixes..."
cat "$TMPFILE" | audit2allow 2>/dev/null | grep -E "^#" | head -20 | sed 's/^/  /' || true

UNFIXED=$(cat "$TMPFILE" | audit2allow 2>/dev/null | grep -v "^#" | grep -v "^$" | wc -l || echo "0")
if [[ "$UNFIXED" -gt 0 ]]; then
  echo
  warn "Denials not covered by booleans ($UNFIXED rules needed):"
  cat "$TMPFILE" | audit2allow 2>/dev/null | grep -v "^#" | grep -v "^$" | head -20 | sed 's/^/    /'
  echo
  info "To generate a policy module (review before installing):"
  echo "    ausearch -m AVC -ts today | audit2allow -M myfix"
  echo "    cat myfix.te   # REVIEW THIS FILE"
  echo "    semodule -i myfix.pp"
fi

# -- 8. Permissive vs Enforcing Activity -------------------------------------
header "Permissive-Mode Activity"

PERMISSIVE_AVC=$(grep "^type=AVC" "$TMPFILE" | grep -c "permissive=1" || echo "0")
ENFORCING_AVC=$(grep "^type=AVC" "$TMPFILE" | grep -c "permissive=0" || echo "0")

info "Denials in enforcing mode (blocked): $ENFORCING_AVC"
if [[ "$PERMISSIVE_AVC" -gt 0 ]]; then
  warn "Denials in permissive mode (allowed but logged): $PERMISSIVE_AVC"
  info "These would be blocked if enforcing were applied to those domains."
fi

echo
echo -e "${BOLD}AVC analysis complete.${RESET}"
