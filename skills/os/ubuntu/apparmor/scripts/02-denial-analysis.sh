#!/usr/bin/env bash
# ============================================================================
# AppArmor - Denial Analysis
#
# Version : 1.0.0
# Targets : Ubuntu 20.04+ with AppArmor enabled
# Safety  : Read-only. No modifications to system configuration.
#
# Usage   : ./02-denial-analysis.sh [HOURS]  (default: 24)
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

echo -e "${BOLD}AppArmor Denial Analysis${RESET}"
echo "Generated: $(date)"
echo "Host: $(hostname -f 2>/dev/null || hostname)"
echo "Time window: Last ${HOURS} hours"

# -- Collect Denial Lines -----------------------------------------------------
DENIAL_LINES=$(journalctl --since="${HOURS} hours ago" 2>/dev/null | \
    grep 'apparmor="DENIED"' || true)

DENIAL_COUNT=0
if [[ -n "$DENIAL_LINES" ]]; then
    DENIAL_COUNT=$(echo "$DENIAL_LINES" | wc -l)
fi

# -- 1. Denial Count ---------------------------------------------------------
header "Denial Summary"

if [[ "$DENIAL_COUNT" -eq 0 ]]; then
    ok "No AppArmor denials found in the last ${HOURS} hours"
    exit 0
fi

fail "${DENIAL_COUNT} total denial event(s) found"

# -- 2. Top Denied Profiles --------------------------------------------------
header "Top Denied Profiles"

echo "$DENIAL_LINES" | grep -oP 'profile="\K[^"]+' | \
    sort | uniq -c | sort -rn | head -10 | \
    while read -r count profile; do
        printf "  %5d  %s\n" "$count" "$profile"
    done

# -- 3. Top Denied Operations ------------------------------------------------
header "Top Denied Operations"

echo "$DENIAL_LINES" | grep -oP 'operation="\K[^"]+' | \
    sort | uniq -c | sort -rn | head -10 | \
    while read -r count op; do
        printf "  %5d  %s\n" "$count" "$op"
    done

# -- 4. Top Denied Paths -----------------------------------------------------
header "Top Denied Paths"

PATH_LINES=$(echo "$DENIAL_LINES" | grep -oP 'name="\K[^"]+' || true)
if [[ -n "$PATH_LINES" ]]; then
    echo "$PATH_LINES" | sort | uniq -c | sort -rn | head -15 | \
        while read -r count path; do
            printf "  %5d  %s\n" "$count" "$path"
        done
else
    info "No path-based denials (denials may be capability or network)"
fi

# -- 5. Top Denied Capabilities ----------------------------------------------
header "Top Denied Capabilities"

CAP_LINES=$(echo "$DENIAL_LINES" | grep 'operation="capable"' || true)
if [[ -n "$CAP_LINES" ]]; then
    echo "$CAP_LINES" | grep -oP 'capname="\K[^"]+' | \
        sort | uniq -c | sort -rn | head -10 | \
        while read -r count cap; do
            printf "  %5d  %s\n" "$count" "$cap"
        done
else
    info "No capability denials found"
fi

# -- 6. User Namespace Denials -----------------------------------------------
header "User Namespace Denials (Ubuntu 24.04+)"

USERNS_LINES=$(echo "$DENIAL_LINES" | grep 'userns' || true)
if [[ -n "$USERNS_LINES" ]]; then
    USERNS_COUNT=$(echo "$USERNS_LINES" | wc -l)
    warn "${USERNS_COUNT} user namespace denial(s) detected"
    echo "$USERNS_LINES" | grep -oP 'profile="\K[^"]+' | \
        sort | uniq -c | sort -rn | \
        while read -r count profile; do
            printf "  %5d  %s\n" "$count" "$profile"
            echo "         Fix: add 'userns,' to profile or connect snap interface"
        done
else
    info "No user namespace denials found"
fi

# -- 7. Recent Denial Messages ------------------------------------------------
header "Last 10 Denial Messages (Parsed)"

echo "$DENIAL_LINES" | tail -10 | while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    PROFILE=$(echo "$line" | grep -oP 'profile="\K[^"]+' || echo "unknown")
    OPER=$(echo "$line" | grep -oP 'operation="\K[^"]+' || echo "unknown")
    NAME=$(echo "$line" | grep -oP 'name="\K[^"]+' || echo "")
    COMM=$(echo "$line" | grep -oP 'comm="\K[^"]+' || echo "unknown")
    MASK=$(echo "$line" | grep -oP 'denied_mask="\K[^"]+' || echo "")
    echo -e "  ${CYAN}$(echo "$line" | awk '{print $1,$2,$3}')${RESET}  ${YELLOW}${PROFILE}${RESET}  ${OPER}  ${NAME}  denied=${MASK}"
done

# -- 8. Suggested Remediation ------------------------------------------------
header "Suggested Remediation"

PROFILES_WITH_DENIALS=$(echo "$DENIAL_LINES" | grep -oP 'profile="\K[^"]+' | sort -u)

if [[ -n "$PROFILES_WITH_DENIALS" ]]; then
    while IFS= read -r profile; do
        [[ -z "$profile" ]] && continue
        PROFILE_COUNT=$(echo "$DENIAL_LINES" | grep -c "profile=\"${profile}\"" || echo "0")
        echo -e "  ${YELLOW}${profile}${RESET} (${PROFILE_COUNT} denial(s))"

        if echo "$profile" | grep -q '^snap\.'; then
            SNAP_NAME=$(echo "$profile" | sed 's/snap\.\([^.]*\)\..*/\1/')
            echo "    Snap: snap connections $SNAP_NAME / sudo snap connect ${SNAP_NAME}:<iface> :<iface>"
        else
            PROFILE_DOTTED=$(echo "$profile" | tr '/' '.')
            echo "    Fix: sudo aa-complain /etc/apparmor.d/${PROFILE_DOTTED} && sudo aa-logprof"
        fi
    done <<< "$PROFILES_WITH_DENIALS"
fi

echo -e "${BOLD}Workflow:${RESET} aa-complain <profile> -> exercise app -> aa-logprof -> aa-enforce <profile>"
