#!/usr/bin/env bash
# ============================================================================
# RHEL - Service Health
#
# Purpose : Audit systemd service health including failed units, enabled
#           services, timer units, service crash events, and automatic
#           restart configuration.
# Version : 1.0.0
# Targets : RHEL 8+
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. systemd Overview
#   2. Failed Units
#   3. Enabled Services
#   4. Timer Units
#   5. Service Crash Events
#   6. Restart Configuration Audit
#   7. Resource Usage (Top Services)
# ============================================================================
set -euo pipefail

SEP="$(printf '=%.0s' {1..70})"
section() { echo ""; echo "$SEP"; echo "  $1"; echo "$SEP"; }

echo "RHEL Service Health Report"
echo "Generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "Hostname:  $(hostname -f 2>/dev/null || hostname)"

# ── Section 1: systemd Overview ─────────────────────────────────────────────
section "1. systemd Overview"

echo "  systemd version: $(systemctl --version | head -1)"
echo "  Default target:  $(systemctl get-default 2>/dev/null)"
echo "  System state:    $(systemctl is-system-running 2>/dev/null || echo 'unknown')"

echo ""
echo "  Unit counts:"
total_loaded=$(systemctl list-units --no-pager --no-legend 2>/dev/null | wc -l)
total_active=$(systemctl list-units --state=active --no-pager --no-legend 2>/dev/null | wc -l)
total_failed=$(systemctl list-units --state=failed --no-pager --no-legend 2>/dev/null | wc -l)
echo "    Loaded: $total_loaded"
echo "    Active: $total_active"
echo "    Failed: $total_failed"

# ── Section 2: Failed Units ─────────────────────────────────────────────────
section "2. Failed Units"

failed_output=$(systemctl --failed --no-pager --no-legend 2>/dev/null)
if [[ -z "$failed_output" ]]; then
    echo "  [OK]   No failed units"
else
    echo "  [WARN] Failed units detected:"
    echo "$failed_output" | sed 's/^/    /'

    echo ""
    echo "  Recent logs for failed units:"
    echo "$failed_output" | awk '{print $1}' | while read -r unit; do
        echo "    --- $unit ---"
        journalctl -u "$unit" -n 5 --no-pager -q 2>/dev/null | sed 's/^/      /'
        echo ""
    done
fi

# ── Section 3: Enabled Services ─────────────────────────────────────────────
section "3. Enabled Services"

echo "  Enabled service units:"
systemctl list-unit-files --type=service --state=enabled --no-pager --no-legend 2>/dev/null | sed 's/^/    /'

enabled_count=$(systemctl list-unit-files --type=service --state=enabled --no-pager --no-legend 2>/dev/null | wc -l)
echo ""
echo "  Total enabled services: $enabled_count"

# ── Section 4: Timer Units ──────────────────────────────────────────────────
section "4. Timer Units"

echo "  Active timers:"
systemctl list-timers --all --no-pager 2>/dev/null | sed 's/^/    /'

timer_count=$(systemctl list-timers --all --no-pager --no-legend 2>/dev/null | wc -l)
echo ""
echo "  Total timers: $timer_count"

# ── Section 5: Service Crash Events ─────────────────────────────────────────
section "5. Service Crash Events (Last 7 Days)"

echo "  Core dumps:"
if command -v coredumpctl &>/dev/null; then
    core_count=$(coredumpctl list --since "7 days ago" --no-pager 2>/dev/null | tail -n +2 | wc -l)
    if [[ "$core_count" -gt 0 ]]; then
        echo "  [WARN] $core_count core dump(s) in last 7 days:"
        coredumpctl list --since "7 days ago" --no-pager 2>/dev/null | tail -10 | sed 's/^/    /'
    else
        echo "  [OK]   No core dumps in last 7 days"
    fi
else
    echo "  [INFO] coredumpctl not available"
fi

echo ""
echo "  Services with start-limit-hit (last 7 days):"
start_limit=$(journalctl --since "7 days ago" --no-pager -q 2>/dev/null | grep -i "start-limit-hit\|start request repeated" | sort -u || true)
if [[ -n "$start_limit" ]]; then
    echo "$start_limit" | head -10 | sed 's/^/    /'
else
    echo "    None detected"
fi

# ── Section 6: Restart Configuration Audit ──────────────────────────────────
section "6. Restart Configuration Audit"

echo "  Services with Restart= configured:"
for unit_file in /usr/lib/systemd/system/*.service /etc/systemd/system/*.service; do
    [[ -f "$unit_file" ]] || continue
    restart_val=$(grep "^Restart=" "$unit_file" 2>/dev/null | head -1 | awk -F= '{print $2}')
    if [[ -n "$restart_val" && "$restart_val" != "no" ]]; then
        unit_name=$(basename "$unit_file")
        restart_sec=$(grep "^RestartSec=" "$unit_file" 2>/dev/null | head -1 | awk -F= '{print $2}')
        echo "    $unit_name: Restart=$restart_val RestartSec=${restart_sec:-default}"
    fi
done 2>/dev/null | head -30

echo ""
echo "  Services without restart policy (custom units only):"
custom_no_restart=0
for unit_file in /etc/systemd/system/*.service; do
    [[ -f "$unit_file" ]] || continue
    if ! grep -q "^Restart=" "$unit_file" 2>/dev/null; then
        unit_name=$(basename "$unit_file")
        echo "    $unit_name: No Restart= configured"
        ((custom_no_restart++)) || true
    fi
done 2>/dev/null | head -10
if [[ "$custom_no_restart" -eq 0 ]]; then
    echo "    All custom services have restart policies"
fi

# ── Section 7: Resource Usage (Top Services) ────────────────────────────────
section "7. Resource Usage (Top Services by Memory)"

echo "  Top 15 services by memory (from systemd-cgtop snapshot):"
if command -v systemd-cgtop &>/dev/null; then
    systemd-cgtop -b -n 1 --order=memory 2>/dev/null | head -17 | sed 's/^/    /'
else
    echo "    [INFO] systemd-cgtop not available"
    echo "    Fallback: top processes by memory"
    ps -eo pid,comm,%mem --sort=-%mem 2>/dev/null | head -16 | sed 's/^/    /'
fi

echo ""
echo "$SEP"
echo "  Service Health Report Complete - $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "$SEP"
