#!/usr/bin/env bash
# ============================================================================
# Debian - Service Health
#
# Purpose : Failed units, enabled/running services, timers, needrestart
#           status, service resource usage, recent crashes, journal errors.
# Version : 1.0.0
# Targets : Debian 11+ (Bullseye and later)
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. Failed Units
#   2. Enabled Services
#   3. Running Services
#   4. Timers
#   5. needrestart Status
#   6. Service Resource Usage
#   7. Recent Service Crashes (24h)
#   8. Journal Errors by Unit (24h)
# ============================================================================
set -euo pipefail

echo "=== DEBIAN SERVICE HEALTH ==="
echo "Date: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo ""

echo "--- Failed Units ---"
systemctl list-units --state=failed --no-pager 2>/dev/null
echo ""

echo "--- Failed Units (all including inactive) ---"
systemctl --failed --no-pager 2>/dev/null
echo ""

echo "--- All Enabled Services ---"
systemctl list-unit-files --state=enabled --type=service --no-pager 2>/dev/null | \
    grep -v '^$' | head -50
echo ""

echo "--- Running Services ---"
systemctl list-units --type=service --state=running --no-pager 2>/dev/null | head -40
echo ""

echo "--- Timers ---"
systemctl list-timers --no-pager 2>/dev/null
echo ""

echo "--- needrestart Status ---"
if command -v needrestart &>/dev/null; then
    needrestart -r l 2>/dev/null || echo "No services need restarting"
else
    echo "needrestart not installed (apt-get install needrestart)"
    echo "Services with deleted libraries (manual check):"
    lsof 2>/dev/null | grep 'DEL.*lib' | awk '{print $1}' | sort -u | head -20 || echo "lsof not available"
fi
echo ""

echo "--- Service Resource Usage (top 15 by memory) ---"
systemctl list-units --type=service --state=running --no-legend --no-pager 2>/dev/null | \
    awk '{print $1}' | \
    while read -r unit; do
        pid=$(systemctl show "$unit" -p MainPID --value 2>/dev/null)
        [ "$pid" = "0" ] || [ -z "$pid" ] && continue
        mem=$(ps -o rss= -p "$pid" 2>/dev/null | tr -d ' ')
        [ -z "$mem" ] && continue
        echo "$mem $unit"
    done | sort -rn | head -15 | \
    while read -r mem unit; do
        echo "$(( mem / 1024 ))MB $unit"
    done
echo ""

echo "--- Recent Service Crashes (last 24h) ---"
journalctl --since "24 hours ago" --no-pager 2>/dev/null | \
    grep -iE 'segfault|core dump|killed process|start-limit-hit|main process exited.*code=killed' | \
    tail -20 || echo "None"
echo ""

echo "--- Systemd Journal Errors by Unit (last 24h) ---"
journalctl --since "24 hours ago" -p err --no-pager 2>/dev/null | \
    grep '_SYSTEMD_UNIT=' | \
    sed 's/.*_SYSTEMD_UNIT=\([^ ]*\).*/\1/' | \
    sort | uniq -c | sort -rn | head -15 || \
journalctl --since "24 hours ago" -p err --no-pager 2>/dev/null | \
    awk '{print $5}' | sort | uniq -c | sort -rn | head -15 || echo "None"
