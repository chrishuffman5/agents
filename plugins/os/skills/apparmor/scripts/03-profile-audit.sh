#!/usr/bin/env bash
# ============================================================================
# AppArmor - Profile Inventory and Audit
#
# Version : 1.0.0
# Targets : Ubuntu 20.04+ with AppArmor enabled
# Safety  : Read-only. No modifications to system configuration.
# ============================================================================
set -euo pipefail

RED='\033[0;31m'; YELLOW='\033[0;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

header() { echo -e "\n${BOLD}${CYAN}== $1 ==${RESET}"; }
ok()     { echo -e "  ${GREEN}[OK]${RESET}    $1"; }
warn()   { echo -e "  ${YELLOW}[WARN]${RESET}  $1"; }
info()   { echo -e "  ${CYAN}[INFO]${RESET}  $1"; }

PROFILE_DIR="/etc/apparmor.d"
SNAP_PROFILE_DIR="/var/lib/snapd/apparmor/profiles"
DISABLE_DIR="${PROFILE_DIR}/disable"
LOCAL_DIR="${PROFILE_DIR}/local"

echo -e "${BOLD}AppArmor Profile Audit Report${RESET}"
echo "Generated: $(date)"
echo "Host: $(hostname -f 2>/dev/null || hostname)"

AA_STATUS=$(sudo aa-status 2>/dev/null || echo "")
if [[ -z "$AA_STATUS" ]]; then
    echo -e "  ${RED}[FAIL]${RESET}  Cannot run aa-status. Is AppArmor enabled?"
    exit 1
fi

ENFORCE_COUNT=$(echo "$AA_STATUS" | grep 'profiles are in enforce mode' | awk '{print $1}' || echo "0")
COMPLAIN_COUNT=$(echo "$AA_STATUS" | grep 'profiles are in complain mode' | awk '{print $1}' || echo "0")
COMPLAIN_LIST=$(echo "$AA_STATUS" | awk '/in complain mode:$/,/^$/' | \
    grep -v 'in complain mode:' | grep -v '^$' | sed 's/^[[:space:]]*//' || true)

# -- Profile Inventory -------------------------------------------------------
header "Profile Inventory"

TOTAL_LOADED=$(( ENFORCE_COUNT + COMPLAIN_COUNT ))
DISK_COUNT=$(find "$PROFILE_DIR" -maxdepth 1 -type f ! -name '*.dpkg-*' ! -name '*.orig' 2>/dev/null | wc -l)
DISABLED_COUNT=$(find "$DISABLE_DIR" -type f 2>/dev/null | wc -l || echo "0")
LOCAL_COUNT=$(find "$LOCAL_DIR" -maxdepth 1 -type f 2>/dev/null | wc -l || echo "0")

echo -e "  Enforce: ${GREEN}${ENFORCE_COUNT}${RESET}  Complain: ${YELLOW}${COMPLAIN_COUNT}${RESET}  Loaded: ${BOLD}${TOTAL_LOADED}${RESET}"
echo "  On disk: ${DISK_COUNT}  Disabled: ${DISABLED_COUNT}  Local mods: ${LOCAL_COUNT}"

# -- Disabled Profiles -------------------------------------------------------
header "Disabled Profiles"

if [[ "$DISABLED_COUNT" -gt 0 ]]; then
    warn "${DISABLED_COUNT} profile(s) disabled:"
    find "$DISABLE_DIR" -type f 2>/dev/null | while read -r f; do echo "    - $(basename "$f")"; done
else
    ok "No disabled profiles"
fi

# -- Complain Mode -----------------------------------------------------------
if [[ "$COMPLAIN_COUNT" -gt 0 ]]; then
    header "Profiles in Complain Mode"
    warn "${COMPLAIN_COUNT} profile(s) in complain mode (not enforced):"
    echo "$COMPLAIN_LIST" | grep -v '^$' | head -20 | while read -r p; do echo "    - $p"; done
fi

# -- Custom vs Shipped -------------------------------------------------------
header "Custom vs Shipped Profiles"

find "$PROFILE_DIR" -maxdepth 1 -type f ! -name '*.dpkg-*' ! -name '*.orig' 2>/dev/null | \
    sort | while read -r f; do
    PKG=$(dpkg -S "$f" 2>/dev/null | cut -d: -f1 || true)
    [[ -z "$PKG" ]] && echo -e "    ${CYAN}[CUSTOM]${RESET}  $(basename "$f")"
done

# -- Unmerged Package Updates ------------------------------------------------
header "Unmerged Profile Updates"

DPKG_NEW=$(find "$PROFILE_DIR" -name '*.dpkg-new' 2>/dev/null || true)
if [[ -n "$DPKG_NEW" ]]; then
    warn "Unmerged updates found:"
    echo "$DPKG_NEW" | while read -r f; do echo "    $f"; done
else
    ok "No unmerged profile updates"
fi

# -- Unconfined Network-Listening Processes -----------------------------------
header "Unconfined Network-Listening Processes"

SS_OUTPUT=$(ss -tlnp 2>/dev/null || netstat -tlnp 2>/dev/null || echo "")
if [[ -n "$SS_OUTPUT" ]]; then
    echo "$SS_OUTPUT" | grep -oP 'pid=\K\d+' 2>/dev/null | sort -u | while read -r pid; do
        [[ -z "$pid" ]] && continue
        PROC_AA=$(cat "/proc/${pid}/attr/current" 2>/dev/null || echo "unconfined")
        if echo "$PROC_AA" | grep -q 'unconfined'; then
            COMM=$(cat "/proc/${pid}/comm" 2>/dev/null || echo "unknown")
            EXE=$(readlink -f "/proc/${pid}/exe" 2>/dev/null || echo "unknown")
            printf "    ${YELLOW}%-20s${RESET} PID:%-6s %s\n" "$COMM" "$pid" "$EXE"
        fi
    done
fi

# -- Snap Profile Coverage ---------------------------------------------------
header "Snap Profile Coverage"

if command -v snap &>/dev/null; then
    snap list 2>/dev/null | tail -n +2 | awk '{print $1, $NF}' | \
        while read -r snap_name confinement; do
        SNAP_PROFILES=$(ls "${SNAP_PROFILE_DIR}"/snap."${snap_name}".* 2>/dev/null | wc -l || echo "0")
        case "$confinement" in
            strict)  printf "    ${GREEN}%-25s${RESET} strict  (%d profiles)\n" "$snap_name" "$SNAP_PROFILES" ;;
            classic) printf "    ${YELLOW}%-25s${RESET} classic (no AppArmor)\n" "$snap_name" ;;
            devmode) printf "    ${RED}%-25s${RESET} devmode (not enforced)\n" "$snap_name" ;;
            *)       printf "    ${CYAN}%-25s${RESET} %s (%d profiles)\n" "$snap_name" "$confinement" "$SNAP_PROFILES" ;;
        esac
    done
else
    info "snap command not available"
fi

# -- Local Customizations ----------------------------------------------------
header "Local Profile Customizations"

if [[ "$LOCAL_COUNT" -gt 0 ]]; then
    find "$LOCAL_DIR" -maxdepth 1 -type f 2>/dev/null | sort | while read -r f; do
        RULES=$(grep -v '^\s*#' "$f" 2>/dev/null | grep -cv '^\s*$' || echo "0")
        printf "    %-40s  %3d rule(s)\n" "$(basename "$f")" "$RULES"
    done
else
    info "No local customizations. Add rules to $LOCAL_DIR/<profile-name>"
fi

# -- Summary -----------------------------------------------------------------
header "Audit Summary"

echo "  Enforce: ${ENFORCE_COUNT}  Complain: ${COMPLAIN_COUNT}  Disabled: ${DISABLED_COUNT}  Local: ${LOCAL_COUNT}"
[[ "$COMPLAIN_COUNT" -gt 0 ]] && warn "${COMPLAIN_COUNT} profile(s) in complain -- review and enforce when stable"
[[ "$DISABLED_COUNT" -gt 0 ]] && warn "${DISABLED_COUNT} profile(s) disabled -- ensure this is intentional"

echo
echo -e "${BOLD}Profile audit complete.${RESET}"
