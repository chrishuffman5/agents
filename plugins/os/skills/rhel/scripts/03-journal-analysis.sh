#!/usr/bin/env bash
# ============================================================================
# RHEL - Journal Analysis
#
# Purpose : Analyze journalctl for critical/error patterns, boot analysis,
#           failed systemd units, recent crashes, and OOM events.
# Version : 1.0.0
# Targets : RHEL 8+
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. Journal Storage Status
#   2. Boot Analysis
#   3. Critical and Error Messages (Last 24h)
#   4. Failed Systemd Units
#   5. Recent Crash Events
#   6. OOM Killer Events
#   7. Authentication Failures
# ============================================================================
set -euo pipefail

SEP="$(printf '=%.0s' {1..70})"
section() { echo ""; echo "$SEP"; echo "  $1"; echo "$SEP"; }

echo "RHEL Journal Analysis"
echo "Generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "Hostname:  $(hostname -f 2>/dev/null || hostname)"

# ── Section 1: Journal Storage Status ───────────────────────────────────────
section "1. Journal Storage Status"

journalctl --disk-usage 2>/dev/null | sed 's/^/  /'
echo ""

storage_mode=$(grep -E "^Storage=" /etc/systemd/journald.conf 2>/dev/null | awk -F= '{print $2}')
echo "  Storage mode: ${storage_mode:-auto (default)}"

if [[ -d /var/log/journal ]]; then
    echo "  [OK]   Persistent journal directory exists"
else
    echo "  [WARN] /var/log/journal does not exist -- journal is volatile"
    echo "         Create: mkdir -p /var/log/journal && systemd-tmpfiles --create --prefix /var/log/journal"
fi

echo ""
echo "  Boot history:"
journalctl --list-boots 2>/dev/null | tail -5 | sed 's/^/    /'

# ── Section 2: Boot Analysis ────────────────────────────────────────────────
section "2. Boot Analysis"

if command -v systemd-analyze &>/dev/null; then
    systemd-analyze 2>/dev/null | sed 's/^/  /'
    echo ""
    echo "  Slowest units (top 10):"
    systemd-analyze blame 2>/dev/null | head -10 | sed 's/^/    /'
else
    echo "  [INFO] systemd-analyze not available"
fi

# ── Section 3: Critical and Error Messages (Last 24h) ──────────────────────
section "3. Critical and Error Messages (Last 24h)"

error_count=$(journalctl --since "24 hours ago" -p err --no-pager -q 2>/dev/null | wc -l)
crit_count=$(journalctl --since "24 hours ago" -p crit --no-pager -q 2>/dev/null | wc -l)

echo "  Critical messages (24h): $crit_count"
echo "  Error messages (24h):    $error_count"

if [[ "$crit_count" -gt 0 ]]; then
    echo ""
    echo "  Recent critical messages:"
    journalctl --since "24 hours ago" -p crit --no-pager -q 2>/dev/null | tail -15 | sed 's/^/    /'
fi

if [[ "$error_count" -gt 0 ]]; then
    echo ""
    echo "  Recent error messages (last 20):"
    journalctl --since "24 hours ago" -p err --no-pager -q 2>/dev/null | tail -20 | sed 's/^/    /'
fi

# ── Section 4: Failed Systemd Units ─────────────────────────────────────────
section "4. Failed Systemd Units"

failed_units=$(systemctl --failed --no-pager --no-legend 2>/dev/null)
if [[ -z "$failed_units" ]]; then
    echo "  [OK]   No failed units"
else
    echo "  [WARN] Failed units detected:"
    echo "$failed_units" | sed 's/^/    /'
    echo ""
    echo "  Use 'journalctl -u <unit>' to investigate each failure"
fi

# ── Section 5: Recent Crash Events ──────────────────────────────────────────
section "5. Recent Crash Events"

if command -v coredumpctl &>/dev/null; then
    core_count=$(coredumpctl list --no-pager 2>/dev/null | tail -n +2 | wc -l)
    if [[ "$core_count" -gt 0 ]]; then
        echo "  [WARN] $core_count core dump(s) recorded:"
        coredumpctl list --no-pager 2>/dev/null | tail -10 | sed 's/^/    /'
    else
        echo "  [OK]   No core dumps recorded"
    fi
else
    echo "  [INFO] coredumpctl not available"
fi

# Check for kernel panics
panic_count=$(journalctl -k --since "7 days ago" --no-pager -q 2>/dev/null | grep -ci "panic\|oops\|bug:" || echo 0)
if [[ "$panic_count" -gt 0 ]]; then
    echo ""
    echo "  [WARN] $panic_count kernel panic/oops/BUG events in last 7 days"
    journalctl -k --since "7 days ago" --no-pager -q 2>/dev/null | grep -i "panic\|oops\|bug:" | tail -5 | sed 's/^/    /'
else
    echo "  [OK]   No kernel panics in last 7 days"
fi

# ── Section 6: OOM Killer Events ────────────────────────────────────────────
section "6. OOM Killer Events"

oom_count=$(journalctl -k --since "7 days ago" --no-pager -q 2>/dev/null | grep -ci "oom\|killed process" || echo 0)
if [[ "$oom_count" -gt 0 ]]; then
    echo "  [WARN] $oom_count OOM events in last 7 days:"
    journalctl -k --since "7 days ago" --no-pager -q 2>/dev/null | grep -i "oom\|killed process" | tail -10 | sed 's/^/    /'
else
    echo "  [OK]   No OOM killer events in last 7 days"
fi

# ── Section 7: Authentication Failures ──────────────────────────────────────
section "7. Authentication Failures (Last 24h)"

auth_fail=$(journalctl --since "24 hours ago" -u sshd --no-pager -q 2>/dev/null | grep -ci "failed\|invalid" || echo 0)
echo "  SSH authentication failures (24h): $auth_fail"

if [[ "$auth_fail" -gt 20 ]]; then
    echo "  [WARN] High number of SSH failures -- possible brute force"
    journalctl --since "24 hours ago" -u sshd --no-pager -q 2>/dev/null | grep -i "failed\|invalid" | tail -10 | sed 's/^/    /'
fi

echo ""
echo "$SEP"
echo "  Journal Analysis Complete - $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "$SEP"
