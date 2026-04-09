#!/usr/bin/env bash
# ============================================================================
# Debian - Journal Analysis
#
# Purpose : systemd journal disk usage, boot analysis, recent errors,
#           failed units, OOM kills, kernel errors, SSH auth failures.
# Version : 1.0.0
# Targets : Debian 11+ (Bullseye and later)
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. Journal Disk Usage
#   2. Boot Analysis
#   3. Recent Errors (24h)
#   4. Recent Critical Events
#   5. Failed systemd Units
#   6. OOM Kills (7 days)
#   7. Kernel Errors (24h)
#   8. SSH Auth Failures (24h)
# ============================================================================
set -euo pipefail

echo "=== JOURNAL ANALYSIS ==="
echo "Date: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo ""

echo "--- Journal Disk Usage ---"
journalctl --disk-usage 2>/dev/null || echo "N/A"
echo ""

echo "--- Boot Analysis ---"
echo "Current boot:"
journalctl --list-boots 2>/dev/null | tail -5
echo ""
echo "Boot time (systemd-analyze):"
systemd-analyze 2>/dev/null || echo "N/A"
echo ""
echo "Slowest units at boot:"
systemd-analyze blame 2>/dev/null | head -15 || echo "N/A"
echo ""

echo "--- Recent Errors (last 24h) ---"
journalctl --since "24 hours ago" -p err --no-pager 2>/dev/null | tail -50 || echo "None"
echo ""

echo "--- Recent Critical Events ---"
journalctl --since "24 hours ago" -p crit --no-pager 2>/dev/null | tail -20 || echo "None"
echo ""

echo "--- Failed systemd Units ---"
systemctl list-units --state=failed --no-pager 2>/dev/null
echo ""

echo "--- OOM Kills (last 7 days) ---"
journalctl --since "7 days ago" -k --no-pager 2>/dev/null | grep -i 'oom\|kill' | tail -20 || echo "None"
echo ""

echo "--- Kernel Errors (last 24h) ---"
journalctl --since "24 hours ago" -k -p err --no-pager 2>/dev/null | tail -30 || echo "None"
echo ""

echo "--- SSH Auth Failures (last 24h) ---"
journalctl --since "24 hours ago" -u ssh -u sshd --no-pager 2>/dev/null | \
    grep -i 'failed\|invalid\|refused' | tail -20 || echo "None"
