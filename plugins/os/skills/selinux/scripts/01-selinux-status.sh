#!/usr/bin/env bash
# ============================================================================
# SELinux - Status Overview
#
# Version : 1.0.0
# Targets : RHEL 8+ with SELinux enabled
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. SELinux Mode
#   2. Per-Domain Permissive Mode
#   3. Policy Information
#   4. Booleans Changed from Default
#   5. Recent AVC Denials
#   6. File Context Database
#   7. AVC Cache Statistics
# ============================================================================
set -euo pipefail

RED='\033[0;31m'; YELLOW='\033[0;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

header() { echo -e "\n${BOLD}${CYAN}== $1 ==${RESET}"; }
ok()     { echo -e "  ${GREEN}[OK]${RESET}    $1"; }
warn()   { echo -e "  ${YELLOW}[WARN]${RESET}  $1"; }
fail()   { echo -e "  ${RED}[FAIL]${RESET}  $1"; }
info()   { echo -e "  ${CYAN}[INFO]${RESET}  $1"; }

# -- 1. SELinux Mode ---------------------------------------------------------
header "SELinux Mode"

ENFORCE_MODE=$(getenforce 2>/dev/null || echo "Error")
CONFIG_MODE=$(grep -E "^SELINUX=" /etc/selinux/config 2>/dev/null | cut -d= -f2 || echo "unknown")
POLICY_TYPE=$(grep -E "^SELINUXTYPE=" /etc/selinux/config 2>/dev/null | cut -d= -f2 || echo "unknown")

case "$ENFORCE_MODE" in
  Enforcing)  ok  "Current mode: ${BOLD}Enforcing${RESET}" ;;
  Permissive) warn "Current mode: ${BOLD}Permissive${RESET} -- policy not enforced!" ;;
  Disabled)   fail "Current mode: ${BOLD}Disabled${RESET} -- SELinux inactive!" ;;
  *)          fail "Cannot determine mode: $ENFORCE_MODE" ;;
esac

info "Configured mode: $CONFIG_MODE"
info "Policy type: $POLICY_TYPE"

CONFIG_UPPER=$(echo "$CONFIG_MODE" | sed 's/./\U&/')
if [[ "$ENFORCE_MODE" != "$CONFIG_UPPER" ]]; then
  warn "Runtime mode ($ENFORCE_MODE) differs from configured mode ($CONFIG_MODE)"
fi

# -- 2. Per-Domain Permissive Mode -------------------------------------------
header "Per-Domain Permissive Mode"

PERM_DOMAINS=$(semanage permissive -l 2>/dev/null | grep -v "^Builtin\|^Customized\|^$" || echo "")
if [[ -z "$PERM_DOMAINS" ]]; then
  ok "No domains in permissive mode"
else
  warn "Domains in permissive mode (these bypass enforcement):"
  echo "$PERM_DOMAINS" | while read -r domain; do
    warn "  - $domain"
  done
fi

# -- 3. Policy Information ---------------------------------------------------
header "Policy Information"

POLICY_VERSION=$(cat /sys/fs/selinux/policyvers 2>/dev/null || echo "unknown")
info "Policy kernel version: $POLICY_VERSION"

if command -v semodule &>/dev/null; then
  LOADED_MODULES=$(semodule -l 2>/dev/null | wc -l)
  info "Loaded modules total: $LOADED_MODULES"

  BASE_MODS=$(semodule -lfull 2>/dev/null | grep -c "^100 " || echo "0")
  CONTRIB_MODS=$(semodule -lfull 2>/dev/null | grep -c "^200 " || echo "0")
  LOCAL_MODS=$(semodule -lfull 2>/dev/null | grep -cE "^[3-9][0-9]{2} " || echo "0")
  info "  Base modules (priority 100): $BASE_MODS"
  info "  Contrib modules (priority 200): $CONTRIB_MODS"
  info "  Local/custom modules (priority 300+): $LOCAL_MODS"
fi

# -- 4. Booleans Changed from Default ----------------------------------------
header "Booleans Changed from Default"

CHANGED_BOOLS=$(semanage boolean -l --noheading 2>/dev/null | \
  awk '{ if ($3 != $4) print $1, "current=" $3, "default=" $4 }' | head -30)

if [[ -z "$CHANGED_BOOLS" ]]; then
  ok "All booleans at default values"
else
  BOOL_COUNT=$(echo "$CHANGED_BOOLS" | wc -l)
  info "Booleans modified from default ($BOOL_COUNT):"
  echo "$CHANGED_BOOLS" | while IFS= read -r line; do
    echo "    $line"
  done
fi

# -- 5. Recent AVC Denials ---------------------------------------------------
header "Recent AVC Denials"

AVC_COUNT=$(ausearch -m AVC -ts today 2>/dev/null | grep -c "^type=AVC" || echo "0")
AVC_RECENT=$(ausearch -m AVC -ts recent 2>/dev/null | grep -c "^type=AVC" || echo "0")

if [[ "$AVC_COUNT" -eq 0 ]]; then
  ok "No AVC denials today"
elif [[ "$AVC_COUNT" -lt 10 ]]; then
  warn "AVC denials today: $AVC_COUNT (recent 10min: $AVC_RECENT)"
else
  fail "AVC denials today: $AVC_COUNT (recent 10min: $AVC_RECENT) -- investigate!"
fi

if [[ "$AVC_RECENT" -gt 0 ]]; then
  info "Top domains with recent denials:"
  ausearch -m AVC -ts recent 2>/dev/null | \
    grep -oP 'scontext=\S+:\S+:\K[^:]+' | \
    sort | uniq -c | sort -rn | head -5 | \
    while read -r cnt dom; do echo "    $cnt  $dom"; done
fi

# -- 6. File Context Database -------------------------------------------------
header "File Context Database"

FC_BASE=$(wc -l < "/etc/selinux/${POLICY_TYPE:-targeted}/contexts/files/file_contexts" 2>/dev/null || echo "0")
FC_LOCAL=$(wc -l < "/etc/selinux/${POLICY_TYPE:-targeted}/contexts/files/file_contexts.local" 2>/dev/null || echo "0")

info "Base file context rules: $FC_BASE"
if [[ "$FC_LOCAL" -gt 0 ]]; then
  info "Local file context rules (semanage fcontext): $FC_LOCAL"
else
  ok "No local file context overrides"
fi

# -- 7. AVC Cache Statistics --------------------------------------------------
header "AVC Cache Statistics"

if [[ -f /sys/fs/selinux/avc/cache_stats ]]; then
  head -2 /sys/fs/selinux/avc/cache_stats | while IFS= read -r line; do
    info "  $line"
  done
else
  warn "AVC cache stats not available"
fi

echo
echo -e "${BOLD}SELinux status check complete.${RESET}"
