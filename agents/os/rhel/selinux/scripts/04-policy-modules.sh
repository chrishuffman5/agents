#!/usr/bin/env bash
# ============================================================================
# SELinux - Policy Module Inventory
#
# Version : 1.0.0
# Targets : RHEL 8+ with SELinux enabled
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. Policy Module Summary
#   2. Custom and Local Modules
#   3. Per-Domain Permissive Modules
#   4. Booleans Changed from Default
#   5. Recent Policy Changes
#   6. Policy Integrity
# ============================================================================
set -euo pipefail

RED='\033[0;31m'; YELLOW='\033[0;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

header() { echo -e "\n${BOLD}${CYAN}== $1 ==${RESET}"; }
ok()     { echo -e "  ${GREEN}[OK]${RESET}    $1"; }
warn()   { echo -e "  ${YELLOW}[WARN]${RESET}  $1"; }
fail()   { echo -e "  ${RED}[FAIL]${RESET}  $1"; }
info()   { echo -e "  ${CYAN}[INFO]${RESET}  $1"; }

# -- 1. Policy Module Summary ------------------------------------------------
header "Policy Module Summary"

FULL_LIST=$(semodule -lfull 2>/dev/null || semodule -l 2>/dev/null)

TOTAL=$(echo "$FULL_LIST" | grep -c "." || echo "0")
BASE=$(echo "$FULL_LIST" | grep -c "^100 " || echo "0")
CONTRIB=$(echo "$FULL_LIST" | grep -c "^200 " || echo "0")
LOCAL=$(echo "$FULL_LIST" | grep -cE "^[3-9][0-9]{2} " || echo "0")
DISABLED=$(echo "$FULL_LIST" | grep -c "disabled" || echo "0")

info "Total loaded modules: $TOTAL"
info "  Priority 100 (base):    $BASE"
info "  Priority 200 (contrib): $CONTRIB"
info "  Priority 300+ (local):  $LOCAL"
if [[ "$DISABLED" -gt 0 ]]; then
  warn "  Disabled modules: $DISABLED"
fi

# -- 2. Custom and Local Modules ---------------------------------------------
header "Custom and Local Policy Modules (Priority 300+)"

LOCAL_MODULES=$(echo "$FULL_LIST" | grep -E "^[3-9][0-9]{2} " || echo "")

if [[ -z "$LOCAL_MODULES" ]]; then
  ok "No custom/local policy modules installed"
else
  info "Custom modules:"
  printf "  %-9s %-25s %-10s %s\n" "Priority" "Module Name" "Version" "Status"
  printf "  %-9s %-25s %-10s %s\n" "--------" "-------------------------" "---------" "------"
  echo "$LOCAL_MODULES" | while IFS= read -r line; do
    PRI=$(echo "$line" | awk '{print $1}')
    MOD=$(echo "$line" | awk '{print $2}')
    VER=$(echo "$line" | awk '{print $3}')
    STATUS=$(echo "$line" | grep -o "disabled" || echo "active")
    printf "  %-9s %-25s %-10s %s\n" "$PRI" "$MOD" "${VER:-n/a}" "$STATUS"
  done
fi

AUTOGEN=$(echo "$LOCAL_MODULES" | grep -iE "\blocal\b|mypol|audit2allow|tmp_" | \
  awk '{print $2}' || echo "")
if [[ -n "$AUTOGEN" ]]; then
  echo
  warn "Possible audit2allow auto-generated modules (review these):"
  echo "$AUTOGEN" | while IFS= read -r mod; do
    warn "  - $mod"
  done
fi

# -- 3. Per-Domain Permissive Modules ----------------------------------------
header "Per-Domain Permissive Modules"

PERM_MODULES=$(semodule -lfull 2>/dev/null | grep "permissive_" || echo "")

if [[ -z "$PERM_MODULES" ]]; then
  ok "No per-domain permissive modules active"
else
  warn "Per-domain permissive modules (these domains bypass enforcement):"
  echo "$PERM_MODULES" | while IFS= read -r line; do
    DOMAIN=$(echo "$line" | awk '{print $2}' | sed 's/^permissive_//')
    warn "  - $DOMAIN"
  done
  echo
  info "To remove: semanage permissive -d <domain>"
fi

# -- 4. Booleans Changed from Default ----------------------------------------
header "Booleans Changed from Default"

CHANGED=$(semanage boolean -l --noheading 2>/dev/null | \
  awk '{ if ($3 != $4) print }' || echo "")

if [[ -z "$CHANGED" ]]; then
  ok "All booleans at default values"
else
  COUNT=$(echo "$CHANGED" | wc -l)
  info "Booleans modified from default ($COUNT):"
  echo
  printf "  %-45s %-10s %-10s\n" "Boolean Name" "Current" "Default"
  printf "  %-45s %-10s %-10s\n" "---------------------------------------------" "-------" "-------"
  echo "$CHANGED" | while IFS= read -r line; do
    NAME=$(echo "$line" | awk '{print $1}')
    CURR=$(echo "$line" | awk '{print $3}')
    DEFT=$(echo "$line" | awk '{print $4}')
    printf "  %-45s %-10s %-10s\n" "$NAME" "$CURR" "$DEFT"
  done
fi

# -- 5. Recent Policy Changes ------------------------------------------------
header "Recent Policy Changes"

info "SELinux-related RPM changes (last 30 days):"
rpm -qa --queryformat "%{INSTALLTIME:date} %{NAME}-%{VERSION}\n" 2>/dev/null | \
  grep -iE "selinux|setroubleshoot|policycoreutils|container-selinux|udica" | \
  sort -k1,3 -r | head -15 | while IFS= read -r line; do
    info "  $line"
  done

echo
info "Recent policy load events:"
ausearch -m MAC_POLICY_LOAD -ts today 2>/dev/null | \
  grep "^type=MAC_POLICY_LOAD" | head -5 | \
  awk '{print "  " $0}' || ok "No policy load events today"

# -- 6. Policy Integrity -----------------------------------------------------
header "Policy Integrity"

POLICY_FILE=$(ls /etc/selinux/targeted/policy/policy.* 2>/dev/null | tail -1)
if [[ -n "$POLICY_FILE" ]]; then
  info "Active policy file: $POLICY_FILE"
  info "Policy file size: $(du -sh "$POLICY_FILE" | cut -f1)"
  info "Policy last modified: $(stat -c '%y' "$POLICY_FILE" | cut -d'.' -f1)"

  KERNEL_VER=$(cat /sys/fs/selinux/policyvers 2>/dev/null || echo "unknown")
  info "Kernel policy version: $KERNEL_VER"
else
  warn "No compiled policy file found in expected location"
fi

echo
echo -e "${BOLD}Policy module inventory complete.${RESET}"
