#!/usr/bin/env bash
# ============================================================================
# SELinux - Context Audit
#
# Version : 1.0.0
# Targets : RHEL 8+ with SELinux enabled
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. Process Context Audit
#   2. File Context Integrity Check
#   3. Port Context and User Mapping Audit
#   4. Container SELinux Status
# ============================================================================
set -euo pipefail

RED='\033[0;31m'; YELLOW='\033[0;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

header() { echo -e "\n${BOLD}${CYAN}== $1 ==${RESET}"; }
ok()     { echo -e "  ${GREEN}[OK]${RESET}    $1"; }
warn()   { echo -e "  ${YELLOW}[WARN]${RESET}  $1"; }
fail()   { echo -e "  ${RED}[FAIL]${RESET}  $1"; }
info()   { echo -e "  ${CYAN}[INFO]${RESET}  $1"; }

if [[ "$(getenforce 2>/dev/null)" == "Disabled" ]]; then
  fail "SELinux is disabled. This script requires SELinux to be active."
  exit 1
fi

# -- 1. Process Context Audit ------------------------------------------------
header "Process Context Audit"

info "User processes in unconfined_t:"
UNCONFINED=$(ps -eZ 2>/dev/null | grep "unconfined_t" | grep -v "^system_u" | awk '{print $NF}' | sort -u | head -10)
[[ -z "$UNCONFINED" ]] && ok "No user processes in unconfined_t" || echo "$UNCONFINED" | while read -r p; do warn "  $p"; done

info "System services in unconfined_t:"
UNCONF_SYS=$(ps -eZ 2>/dev/null | grep "system_r" | grep "unconfined_t" | awk '{print $NF}' | sort -u | head -10)
[[ -z "$UNCONF_SYS" ]] && ok "All system services in confined domains" || echo "$UNCONF_SYS" | while read -r p; do warn "  $p"; done

INITRC=$(ps -eZ 2>/dev/null | grep -c "initrc_t" || echo "0")
(( INITRC > 0 )) && warn "$INITRC process(es) in initrc_t" || ok "No processes in initrc_t"

# -- 2. File Context Integrity Check -----------------------------------------
header "File Context Integrity Check"

info "Checking key directories for context mismatches..."
DIRS=("/etc/httpd" "/var/www" "/etc/nginx" "/etc/ssh" "/var/log" "/usr/sbin")
MISMATCH=0

for dir in "${DIRS[@]}"; do
  [[ -e "$dir" ]] || continue
  if command -v matchpathcon &>/dev/null; then
    BAD=$(find "$dir" -maxdepth 2 2>/dev/null | xargs matchpathcon -V 2>/dev/null | grep -v "verified$" | head -5 || true)
    if [[ -n "$BAD" ]]; then
      warn "Mismatches in $dir:"
      echo "$BAD" | sed 's/^/    /'
      MISMATCH=1
    fi
  fi
done
(( MISMATCH == 0 )) && ok "No file context mismatches in checked directories"

# -- 3. Port Context and User Mapping ----------------------------------------
header "Port Context & User Mapping Audit"

info "Custom port labels:"
CUSTOM_PORTS=$(semanage port -l -C 2>/dev/null || echo "")
[[ -z "$CUSTOM_PORTS" || "$CUSTOM_PORTS" == *"No"* ]] && ok "No custom port labels" || echo "$CUSTOM_PORTS" | while read -r l; do info "  $l"; done

info "Listening TCP ports without labels:"
ss -tlnpH 2>/dev/null | awk '{print $4}' | grep -oP ':\K[0-9]+$' | sort -un | while read -r port; do
  PTYPE=$(semanage port -l 2>/dev/null | grep -E "\btcp\b" | awk -v p="$port" '{for(i=3;i<=NF;i++){gsub(",","",$i);if($i==p){print $1;exit}}}')
  [[ -z "$PTYPE" ]] && warn "  Port $port/tcp -- no SELinux label"
done

info "Custom login mappings:"
CUSTOM_LOGINS=$(semanage login -l -C 2>/dev/null || echo "")
[[ -z "$CUSTOM_LOGINS" || "$CUSTOM_LOGINS" == *"No"* ]] && ok "No custom login mappings" || echo "$CUSTOM_LOGINS" | while read -r l; do info "  $l"; done

# -- 4. Container SELinux Status ----------------------------------------------
header "Container SELinux Status"

rpm -q container-selinux &>/dev/null 2>&1 && ok "container-selinux installed" || warn "container-selinux not installed"

if command -v podman &>/dev/null; then
  RUNNING=$(podman ps -q 2>/dev/null | wc -l || echo "0")
  info "Running containers: $RUNNING"
  if (( RUNNING > 0 )); then
    podman ps --format '{{.Names}}' 2>/dev/null | while read -r name; do
      LABEL=$(podman inspect --format '{{.ProcessLabel}}' "$name" 2>/dev/null || echo "unknown")
      info "  $name -- $LABEL"
    done
  fi
fi

echo
echo -e "${BOLD}Context audit complete.${RESET}"
