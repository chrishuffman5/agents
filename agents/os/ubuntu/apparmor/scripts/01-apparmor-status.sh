#!/usr/bin/env bash
# ============================================================================
# AppArmor - Status Overview
#
# Version : 1.0.0
# Targets : Ubuntu 20.04+ with AppArmor enabled
# Safety  : Read-only. No modifications to system configuration.
#
# Checks: module status, profile modes, process confinement, snap profiles,
#          recent denials, userns restriction, version info
# ============================================================================
set -euo pipefail

RED='\033[0;31m'; YELLOW='\033[0;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

header() { echo -e "\n${BOLD}${CYAN}== $1 ==${RESET}"; }
ok()     { echo -e "  ${GREEN}[OK]${RESET}    $1"; }
warn()   { echo -e "  ${YELLOW}[WARN]${RESET}  $1"; }
fail()   { echo -e "  ${RED}[FAIL]${RESET}  $1"; }
info()   { echo -e "  ${CYAN}[INFO]${RESET}  $1"; }

echo -e "${BOLD}AppArmor Status Report${RESET} — $(hostname) — $(date)"

# -- 1. AppArmor Module Status -----------------------------------------------
header "AppArmor Module Status"

if ! command -v aa-status &>/dev/null; then
    fail "aa-status not found. Install: sudo apt install apparmor-utils"; exit 1
fi
if sudo aa-status --enabled 2>/dev/null; then
    ok "AppArmor module is loaded and enabled"
else
    fail "AppArmor is NOT enabled"
    info "Enable with: sudo systemctl enable --now apparmor"
    exit 1
fi

# -- 2. Profile Summary ------------------------------------------------------
header "Profile Summary"

AA_STATUS=$(sudo aa-status 2>/dev/null)

TOTAL=$(echo "$AA_STATUS" | grep 'profiles are loaded' | awk '{print $1}' || echo "0")
ENFORCE=$(echo "$AA_STATUS" | grep 'profiles are in enforce mode' | awk '{print $1}' || echo "0")
COMPLAIN=$(echo "$AA_STATUS" | grep 'profiles are in complain mode' | awk '{print $1}' || echo "0")
KILL_MODE=$(echo "$AA_STATUS" | grep 'profiles are in kill mode' | awk '{print $1}' || echo "0")

echo -e "  Total profiles loaded:  ${BOLD}${TOTAL}${RESET}"
echo -e "  Enforce mode:           ${GREEN}${ENFORCE}${RESET}"
echo -e "  Complain mode:          ${YELLOW}${COMPLAIN}${RESET}"
if [[ "${KILL_MODE:-0}" -gt 0 ]] 2>/dev/null; then
    echo -e "  Kill mode:              ${RED}${KILL_MODE}${RESET}"
fi

# -- 3. Process Confinement ---------------------------------------------------
header "Process Confinement"

PROC_DEFINED=$(echo "$AA_STATUS" | grep 'processes have profiles defined' | awk '{print $1}' || echo "0")
PROC_ENFORCE=$(echo "$AA_STATUS" | grep 'processes are in enforce mode' | awk '{print $1}' || echo "0")
PROC_COMPLAIN=$(echo "$AA_STATUS" | grep 'processes are in complain mode' | awk '{print $1}' || echo "0")
PROC_UNCONFINED=$(echo "$AA_STATUS" | grep 'processes are unconfined but have' | awk '{print $1}' || echo "0")

echo -e "  Processes with profiles: ${BOLD}${PROC_DEFINED}${RESET}"
echo -e "  Processes enforced:      ${GREEN}${PROC_ENFORCE}${RESET}"
echo -e "  Processes in complain:   ${YELLOW}${PROC_COMPLAIN}${RESET}"

if [[ "${PROC_UNCONFINED:-0}" -gt 0 ]] 2>/dev/null; then
    warn "Unconfined but have a profile: ${PROC_UNCONFINED} (started before profile load?)"
fi

# -- 4. Profiles in Complain Mode ---------------------------------------------
if [[ "${COMPLAIN:-0}" -gt 0 ]] 2>/dev/null; then
    header "Profiles in Complain Mode (Review Needed)"
    echo "$AA_STATUS" | awk '/in complain mode:$/,/^$/' | \
        grep -v 'in complain mode:' | grep -v '^$' | head -20 | while read -r line; do
        [[ -n "$line" ]] && warn "$line"
    done
fi

# -- 5. Snap AppArmor Profiles -----------------------------------------------
header "Snap AppArmor Profiles"

SNAP_PROFILE_DIR="/var/lib/snapd/apparmor/profiles"
if [[ -d "$SNAP_PROFILE_DIR" ]]; then
    SNAP_COUNT=$(ls "$SNAP_PROFILE_DIR" 2>/dev/null | wc -l)
    info "Snap profiles directory: $SNAP_PROFILE_DIR"
    info "Total snap profiles: ${SNAP_COUNT}"
    if [[ "$SNAP_COUNT" -gt 0 ]]; then
        info "Installed snaps with profiles:"
        ls "$SNAP_PROFILE_DIR" | grep '^snap\.' | \
            sed 's/snap\.\([^.]*\)\..*/\1/' | sort -u | while read -r snap; do
            COUNT=$(ls "$SNAP_PROFILE_DIR" | grep -c "^snap\.${snap}\." || echo "0")
            echo "    - $snap ($COUNT profile(s))"
        done | head -15
    fi
else
    info "Snapd not installed or no snap profiles directory"
fi

# -- 6. Recent Denials --------------------------------------------------------
header "Recent Denials (Last 24 Hours)"

DENIAL_COUNT=$(journalctl --since="24 hours ago" 2>/dev/null | \
    grep -c 'apparmor="DENIED"' || echo "0")

if [[ "$DENIAL_COUNT" -eq 0 ]]; then
    ok "No AppArmor denials in the last 24 hours"
elif [[ "$DENIAL_COUNT" -lt 10 ]]; then
    warn "${DENIAL_COUNT} AppArmor denial(s) in the last 24 hours"
else
    fail "${DENIAL_COUNT} AppArmor denial(s) in the last 24 hours -- investigate!"
fi

if [[ "$DENIAL_COUNT" -gt 0 ]]; then
    info "Top profiles with denials:"
    journalctl --since="24 hours ago" 2>/dev/null | \
        grep 'apparmor="DENIED"' | \
        grep -oP 'profile="\K[^"]+' | \
        sort | uniq -c | sort -rn | head -5 | \
        while read -r cnt prof; do echo "    $cnt  $prof"; done
    info "Run 02-denial-analysis.sh for full details"
fi

# -- 7. Unprivileged User Namespace Restriction -------------------------------
header "Unprivileged User Namespace Restriction"

USERNS_FILE="/proc/sys/kernel/apparmor_restrict_unprivileged_userns"
if [[ -f "$USERNS_FILE" ]]; then
    RESTRICT_VAL=$(cat "$USERNS_FILE")
    if [[ "$RESTRICT_VAL" -eq 1 ]]; then
        ok "Unprivileged user namespace restriction is ACTIVE (value=1)"
    else
        warn "Unprivileged user namespace restriction is DISABLED (value=0)"
    fi
else
    info "User namespace restriction not available (pre-24.04 kernel)"
fi

# -- 8. AppArmor Version ------------------------------------------------------
header "AppArmor Version"

if command -v apparmor_parser &>/dev/null; then
    info "$(apparmor_parser --version 2>&1 | head -1)"
fi
info "Kernel: $(uname -r)"

echo
echo -e "${BOLD}AppArmor status check complete.${RESET}"
