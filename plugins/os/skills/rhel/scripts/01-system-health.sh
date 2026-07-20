#!/usr/bin/env bash
# ============================================================================
# RHEL - System Health Dashboard
#
# Purpose : Comprehensive system health overview including OS version,
#           kernel, uptime, subscription status, registered repos,
#           Insights registration, and hardware summary.
# Version : 1.0.0
# Targets : RHEL 8+
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. OS Identity and Version
#   2. Uptime and Boot Time
#   3. Hardware Summary
#   4. Subscription Status
#   5. Repository Status
#   6. Insights Registration
# ============================================================================
set -euo pipefail

SEP="$(printf '=%.0s' {1..70})"

section() {
    echo ""
    echo "$SEP"
    echo "  $1"
    echo "$SEP"
}

# ── Section 1: OS Identity and Version ──────────────────────────────────────
section "SECTION 1 - OS Identity and Version"

echo "  Hostname     : $(hostname -f 2>/dev/null || hostname)"
echo "  Release      : $(cat /etc/redhat-release 2>/dev/null || echo 'unknown')"
echo "  Kernel       : $(uname -r)"
echo "  Architecture : $(uname -m)"

if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    echo "  NAME         : ${NAME:-unknown}"
    echo "  VERSION_ID   : ${VERSION_ID:-unknown}"
    echo "  PLATFORM_ID  : ${PLATFORM_ID:-unknown}"
fi

echo "  RPM Release  : $(rpm -q redhat-release 2>/dev/null || echo 'not installed')"

# ── Section 2: Uptime and Boot Time ─────────────────────────────────────────
section "SECTION 2 - Uptime and Boot Time"

uptime_str=$(uptime -p 2>/dev/null || uptime)
echo "  Uptime       : $uptime_str"

boot_time=$(who -b 2>/dev/null | awk '{print $3, $4}')
echo "  Last Boot    : ${boot_time:-unknown}"

uptime_days=$(awk '{printf "%.1f", $1/86400}' /proc/uptime 2>/dev/null || echo "0")
if (( $(echo "$uptime_days > 90" | bc -l 2>/dev/null || echo 0) )); then
    echo "  [WARN] Server has not rebooted in ${uptime_days} days -- check patch compliance"
elif (( $(echo "$uptime_days > 30" | bc -l 2>/dev/null || echo 0) )); then
    echo "  [INFO] ${uptime_days} days uptime -- verify patching cadence"
else
    echo "  [OK]   Uptime: ${uptime_days} days"
fi

# ── Section 3: Hardware Summary ─────────────────────────────────────────────
section "SECTION 3 - Hardware Summary"

cpu_model=$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | awk -F: '{print $2}' | xargs)
cpu_count=$(nproc 2>/dev/null || echo "unknown")
total_mem=$(free -h 2>/dev/null | awk '/^Mem:/ {print $2}')

echo "  CPU Model    : ${cpu_model:-unknown}"
echo "  CPU Cores    : ${cpu_count}"
echo "  Total RAM    : ${total_mem:-unknown}"

if [[ -f /sys/hypervisor/type ]]; then
    echo "  Hypervisor   : $(cat /sys/hypervisor/type)"
elif grep -q "^flags.*hypervisor" /proc/cpuinfo 2>/dev/null; then
    echo "  Hypervisor   : Virtual machine detected"
else
    echo "  Hypervisor   : Bare metal (or no hypervisor flags)"
fi

if command -v dmidecode &>/dev/null; then
    manufacturer=$(dmidecode -s system-manufacturer 2>/dev/null || echo "unknown")
    product=$(dmidecode -s system-product-name 2>/dev/null || echo "unknown")
    echo "  Manufacturer : $manufacturer"
    echo "  Product      : $product"
fi

# ── Section 4: Subscription Status ──────────────────────────────────────────
section "SECTION 4 - Subscription Status"

if command -v subscription-manager &>/dev/null; then
    sub_status=$(subscription-manager status 2>/dev/null || echo "  Unable to query subscription status")
    echo "$sub_status" | sed 's/^/  /'

    echo ""
    sub_identity=$(subscription-manager identity 2>/dev/null || true)
    if [[ -n "$sub_identity" ]]; then
        echo "$sub_identity" | head -5 | sed 's/^/  /'
    fi
else
    echo "  [WARN] subscription-manager not found"
fi

# ── Section 5: Repository Status ────────────────────────────────────────────
section "SECTION 5 - Repository Status"

if command -v dnf &>/dev/null; then
    echo "  Enabled repositories:"
    dnf repolist 2>/dev/null | sed 's/^/    /' || echo "    Unable to list repos"
    echo ""
    repo_count=$(dnf repolist 2>/dev/null | tail -n +2 | wc -l)
    echo "  Total enabled repos: $repo_count"
else
    echo "  [WARN] dnf not found"
fi

# ── Section 6: Insights Registration ────────────────────────────────────────
section "SECTION 6 - Insights Registration"

if command -v insights-client &>/dev/null; then
    insights_status=$(insights-client --status 2>/dev/null || echo "Unable to query")
    echo "  $insights_status"
else
    echo "  [INFO] insights-client not installed"
    echo "  Install: dnf install insights-client && insights-client --register"
fi

echo ""
echo "$SEP"
echo "  System Health Check Complete - $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "$SEP"
