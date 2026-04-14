#!/usr/bin/env bash
# ============================================================================
# SLES - System Health Dashboard
#
# Purpose : Comprehensive system health overview including OS version,
#           kernel, uptime, SUSEConnect registration, registered modules,
#           enabled repositories, and hardware summary.
# Version : 1.0.0
# Targets : SLES 15 SP5+
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. OS Identity and Version
#   2. Uptime and Boot Time
#   3. Hardware Summary
#   4. SUSEConnect Registration Status
#   5. Registered Modules and Extensions
#   6. Repository Status
#   7. Failed Units and Reboot Status
#   8. FIPS Mode
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
echo "  Kernel       : $(uname -r)"
echo "  Architecture : $(uname -m)"

if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    echo "  NAME         : ${NAME:-unknown}"
    echo "  VERSION_ID   : ${VERSION_ID:-unknown}"
    echo "  VERSION      : ${VERSION:-unknown}"
    echo "  PRETTY_NAME  : ${PRETTY_NAME:-unknown}"
fi

echo "  Kernel cmdline: $(cat /proc/cmdline 2>/dev/null | head -c 200)"

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

# ── Section 4: SUSEConnect Registration Status ──────────────────────────────
section "SECTION 4 - SUSEConnect Registration Status"

if command -v SUSEConnect &>/dev/null; then
    SUSEConnect --status 2>/dev/null | head -40 | sed 's/^/  /' \
        || echo "  [WARN] SUSEConnect failed -- system may not be registered"
else
    echo "  [WARN] SUSEConnect not installed"
fi

# ── Section 5: Registered Modules and Extensions ────────────────────────────
section "SECTION 5 - Registered Modules and Extensions"

if command -v SUSEConnect &>/dev/null; then
    SUSEConnect --list-extensions 2>/dev/null | grep -E "Activated|Not Activated" | head -40 \
        | sed 's/^/  /' || echo "  Unable to list extensions"
fi

# ── Section 6: Repository Status ────────────────────────────────────────────
section "SECTION 6 - Repository Status"

if command -v zypper &>/dev/null; then
    echo "  Enabled repositories:"
    zypper repos --details 2>/dev/null | head -60 | sed 's/^/    /' \
        || echo "    Unable to list repos"
else
    echo "  [WARN] zypper not found"
fi

# ── Section 7: Failed Units and Reboot Status ──────────────────────────────
section "SECTION 7 - Failed Units and Reboot Status"

echo "  Failed systemd units:"
failed=$(systemctl --failed --no-legend 2>/dev/null)
if [[ -n "$failed" ]]; then
    echo "$failed" | sed 's/^/    /'
else
    echo "    None"
fi

echo ""
echo "  Reboot required:"
if [ -f /run/reboot-needed ]; then
    echo "    YES -- /run/reboot-needed exists"
elif command -v zypper &>/dev/null; then
    zypper needs-rebooting 2>/dev/null && echo "    YES (zypper)" || echo "    NO"
else
    echo "    Unable to determine"
fi

echo ""
echo "  Last 5 boots:"
journalctl --list-boots 2>/dev/null | tail -5 | sed 's/^/    /' || echo "    journalctl not available"

# ── Section 8: FIPS Mode ───────────────────────────────────────────────────
section "SECTION 8 - FIPS Mode"

if [ -f /proc/sys/crypto/fips_enabled ]; then
    fips=$(cat /proc/sys/crypto/fips_enabled)
    [ "$fips" = "1" ] && echo "  FIPS: ENABLED" || echo "  FIPS: disabled"
else
    echo "  FIPS: unknown"
fi

echo ""
echo "$SEP"
echo "  System Health Check Complete - $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "$SEP"
