#!/usr/bin/env bash
# ============================================================================
# SLES - Journal Analysis
#
# Purpose : Analyze systemd journal for errors, OOM events, AppArmor
#           denials, Btrfs warnings, network events, SSH failures,
#           and boot performance.
# Version : 1.0.0
# Targets : SLES 15 SP5+
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. Journal Disk Usage
#   2. Boot Analysis
#   3. Failed Units
#   4. Critical/Error Messages (24h)
#   5. Kernel Errors
#   6. OOM Events
#   7. AppArmor Denials
#   8. Btrfs Warnings/Errors
#   9. Wicked/NetworkManager Events
#  10. SSH Login Failures
#  11. Boot Time Analysis
# ============================================================================
set -euo pipefail

SEP="$(printf '=%.0s' {1..70})"

section() {
    echo ""
    echo "$SEP"
    echo "  $1"
    echo "$SEP"
}

echo "$SEP"
echo "  SLES Journal Analysis - $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "$SEP"

# ── Section 1: Journal Disk Usage ──────────────────────────────────────────
section "SECTION 1 - Journal Disk Usage"

journalctl --disk-usage 2>/dev/null | sed 's/^/  /'

# ── Section 2: Boot Analysis ──────────────────────────────────────────────
section "SECTION 2 - Recent Boots"

journalctl --list-boots 2>/dev/null | tail -5 | sed 's/^/  /' || echo "  journalctl not available"

# ── Section 3: Failed Units ──────────────────────────────────────────────
section "SECTION 3 - Failed systemd Units"

failed=$(systemctl --failed --no-legend 2>/dev/null)
if [[ -n "$failed" ]]; then
    echo "$failed" | sed 's/^/  /'
else
    echo "  No failed units"
fi

# ── Section 4: Critical/Error Messages ─────────────────────────────────────
section "SECTION 4 - Critical/Error Messages (last 24h)"

journalctl --since "24 hours ago" -p err..crit --no-pager 2>/dev/null \
    | tail -50 | sed 's/^/  /' || echo "  None found"

# ── Section 5: Kernel Errors ──────────────────────────────────────────────
section "SECTION 5 - Kernel Errors (last boot)"

journalctl -k -b -p err..crit --no-pager 2>/dev/null \
    | tail -30 | sed 's/^/  /' || echo "  None found"

# ── Section 6: OOM Events ────────────────────────────────────────────────
section "SECTION 6 - OOM Events (last 7 days)"

journalctl --since "7 days ago" -k --no-pager 2>/dev/null \
    | grep -i "oom\|killed process\|out of memory" \
    | tail -20 | sed 's/^/  /' || echo "  None found"

# ── Section 7: AppArmor Denials ──────────────────────────────────────────
section "SECTION 7 - AppArmor Denials (last 24h)"

journalctl --since "24 hours ago" --no-pager 2>/dev/null \
    | grep -i "apparmor.*DENIED" \
    | tail -20 | sed 's/^/  /' || echo "  None found"

# ── Section 8: Btrfs Warnings/Errors ────────────────────────────────────
section "SECTION 8 - Btrfs Warnings/Errors (last 7 days)"

journalctl --since "7 days ago" -k --no-pager 2>/dev/null \
    | grep -i "btrfs" | grep -iv "debug" \
    | tail -20 | sed 's/^/  /' || echo "  None found"

# ── Section 9: Wicked/NetworkManager Events ──────────────────────────────
section "SECTION 9 - Network Daemon Events (last 24h)"

journalctl --since "24 hours ago" \
    -u wickedd.service -u wicked.service -u NetworkManager.service \
    --no-pager 2>/dev/null \
    | tail -30 | sed 's/^/  /' || echo "  None found"

# ── Section 10: SSH Login Failures ───────────────────────────────────────
section "SECTION 10 - SSH Login Failures (last 24h)"

journalctl --since "24 hours ago" -u sshd.service --no-pager 2>/dev/null \
    | grep -i "fail\|invalid\|refused" \
    | tail -20 | sed 's/^/  /' || echo "  None found"

# ── Section 11: Boot Time Analysis ──────────────────────────────────────
section "SECTION 11 - Boot Time Analysis"

echo "  Overall boot time:"
systemd-analyze 2>/dev/null | sed 's/^/    /' || echo "    Not available"

echo ""
echo "  Slowest boot services (top 10):"
systemd-analyze blame 2>/dev/null | head -10 | sed 's/^/    /' || echo "    Not available"

echo ""
echo "$SEP"
echo "  Journal Analysis Complete - $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "$SEP"
