#!/usr/bin/env bash
# ============================================================================
# Ubuntu - Journal Analysis
#
# Purpose : Analyze systemd journal for critical errors, boot issues, OOM
#           events, AppArmor denials, and SSH authentication events.
# Version : 1.0.0
# Targets : Ubuntu 20.04+
# Safety  : Read-only. No modifications to system configuration.
#
# Usage   : ./03-journal-analysis.sh [hours]   (default: 24)
#
# Sections:
#   1. Failed Systemd Units
#   2. Critical and Error Messages
#   3. Boot Analysis
#   4. OOM Events
#   5. AppArmor Denials
#   6. SSH Authentication Events
# ============================================================================
set -euo pipefail

SEP="$(printf '=%.0s' {1..70})"
HOURS="${1:-24}"

section() { echo ""; echo "$SEP"; echo "  $1"; echo "$SEP"; }

section "SECTION 1 - Failed Systemd Units"
echo "  Failed units:"
systemctl --failed --no-legend 2>/dev/null | sed 's/^/  /' \
    || echo "  Unable to list failed units"

section "SECTION 2 - Critical and Error Messages (last ${HOURS}h)"
echo "  Priority: critical (crit/alert/emerg):"
journalctl -p 2 --since "${HOURS} hours ago" --no-pager -q 2>/dev/null \
    | head -30 | sed 's/^/  /' || echo "  None found"
echo ""
echo "  Priority: error (err):"
journalctl -p 3 --since "${HOURS} hours ago" --no-pager -q 2>/dev/null \
    | grep -v ': error:$' | head -40 | sed 's/^/  /' || echo "  None found"

section "SECTION 3 - Boot Analysis"
echo "  Boot log summary:"
journalctl --list-boots --no-pager 2>/dev/null | tail -5 | sed 's/^/  /'
echo ""
echo "  Last boot critical messages:"
journalctl -b -p 3 --no-pager -q 2>/dev/null | head -20 | sed 's/^/  /' \
    || echo "  None found"

section "SECTION 4 - OOM Events (last ${HOURS}h)"
echo "  Out-of-memory kill events:"
journalctl -k --since "${HOURS} hours ago" --no-pager -q 2>/dev/null \
    | grep -i 'out of memory\|oom.kill\|killed process' \
    | head -20 | sed 's/^/  /' || echo "  None found"

section "SECTION 5 - AppArmor Denials (last ${HOURS}h)"
echo "  AppArmor denial events:"
journalctl -k --since "${HOURS} hours ago" --no-pager -q 2>/dev/null \
    | grep -i 'apparmor.*denied\|apparmor.*audit' \
    | head -20 | sed 's/^/  /' || echo "  None found"

section "SECTION 6 - SSH Authentication Events (last ${HOURS}h)"
echo "  Failed SSH logins:"
journalctl -u ssh --since "${HOURS} hours ago" --no-pager -q 2>/dev/null \
    | grep -i 'failed password\|invalid user\|authentication failure' \
    | tail -20 | sed 's/^/  /' || echo "  None found"
echo ""
echo "  Successful logins:"
journalctl -u ssh --since "${HOURS} hours ago" --no-pager -q 2>/dev/null \
    | grep 'Accepted' | tail -10 | sed 's/^/  /' || echo "  None found"

echo ""
echo "$SEP"
echo "  Journal Analysis Complete - $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "$SEP"
