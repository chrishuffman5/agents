#!/usr/bin/env bash
# ============================================================================
# Ubuntu - Service Health
#
# Purpose : Service subsystem assessment including failed units, timers,
#           critical Ubuntu services, crash reports, and snap services.
# Version : 1.0.0
# Targets : Ubuntu 20.04+
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. Failed Systemd Units
#   2. Enabled Services
#   3. Systemd Timer Units
#   4. Critical Ubuntu Service Status
#   5. Crash Reports
#   6. Snap Services
#   7. Recent Service Restarts
# ============================================================================
set -euo pipefail

SEP="$(printf '=%.0s' {1..70})"

section() { echo ""; echo "$SEP"; echo "  $1"; echo "$SEP"; }

# -- Section 1: Failed Units -----------------------------------------------
section "SECTION 1 - Failed Systemd Units"
failed=$(systemctl --failed --no-legend 2>/dev/null)
if [[ -n "$failed" ]]; then
    echo "  [WARN] Failed units detected:"
    echo "$failed" | sed 's/^/  /'
else
    echo "  [OK]   No failed units"
fi

# -- Section 2: Enabled Services -------------------------------------------
section "SECTION 2 - Enabled Services"
echo "  All enabled services:"
systemctl list-unit-files --type=service --state=enabled --no-legend 2>/dev/null \
    | sed 's/^/  /' | head -40

# -- Section 3: Timer Units ------------------------------------------------
section "SECTION 3 - Systemd Timer Units"
echo "  Active timers:"
systemctl list-timers --all --no-legend 2>/dev/null | head -20 | sed 's/^/  /'

# -- Section 4: Critical Service Status ------------------------------------
section "SECTION 4 - Critical Ubuntu Service Status"
critical_services=(
    ssh
    cron
    ufw
    apparmor
    unattended-upgrades
    systemd-networkd
    systemd-resolved
    snapd
)
for svc in "${critical_services[@]}"; do
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
        state="[OK]   active"
    elif systemctl is-enabled --quiet "$svc" 2>/dev/null; then
        state="[WARN] enabled but inactive"
    else
        state="[INFO] not active/enabled"
    fi
    printf "  %-30s %s\n" "$svc" "$state"
done

# -- Section 5: Crash Reports ----------------------------------------------
section "SECTION 5 - Crash Reports (/var/crash/)"
if [[ -d /var/crash ]]; then
    crashes=$(ls -lt /var/crash/*.crash 2>/dev/null | head -10)
    if [[ -n "$crashes" ]]; then
        echo "  [WARN] Crash reports found:"
        ls -lh /var/crash/*.crash 2>/dev/null | sed 's/^/  /'
        echo ""
        echo "  Most recent crash summary:"
        newest=$(ls -t /var/crash/*.crash 2>/dev/null | head -1)
        if [[ -n "$newest" ]]; then
            echo "  File: $newest"
            strings "$newest" 2>/dev/null \
                | grep -E '^(Package|ProblemType|Uname|ExecutablePath):' \
                | sed 's/^/    /' || echo "  (unable to parse -- run as root)"
        fi
    else
        echo "  [OK]   No crash reports in /var/crash/"
    fi
else
    echo "  [INFO] /var/crash/ does not exist"
fi

# -- Section 6: Snap Services ----------------------------------------------
section "SECTION 6 - Snap Services"
if command -v snap &>/dev/null; then
    snap_services=$(snap services 2>/dev/null)
    if [[ -n "$snap_services" ]]; then
        echo "$snap_services" | sed 's/^/  /'
    else
        echo "  [INFO] No snap services or snapd not responding"
    fi
else
    echo "  [INFO] snapd not installed"
fi

# -- Section 7: Recent Service Restarts ------------------------------------
section "SECTION 7 - Recent Service Restarts (last 24h)"
echo "  Services that restarted in last 24 hours:"
journalctl --since "24 hours ago" --no-pager -q 2>/dev/null \
    | grep -E 'Started|Stopped|Restarting' \
    | grep -v 'session' \
    | tail -20 | sed 's/^/  /' || echo "  Unable to query journal"

echo ""
echo "$SEP"
echo "  Service Health Check Complete - $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "$SEP"
