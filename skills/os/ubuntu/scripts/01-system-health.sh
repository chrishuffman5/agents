#!/usr/bin/env bash
# ============================================================================
# Ubuntu - System Health Dashboard
#
# Purpose : Comprehensive system health overview including OS version,
#           kernel, uptime, Ubuntu Pro/ESM status, Livepatch, and
#           reboot-required indicator.
# Version : 1.0.0
# Targets : Ubuntu 20.04+
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. OS Identity and Version
#   2. Uptime and Reboot Status
#   3. Ubuntu Pro and ESM Status
#   4. Livepatch Status
#   5. Hardware Summary
# ============================================================================
set -euo pipefail

SEP="$(printf '=%.0s' {1..70})"

section() {
    echo ""
    echo "$SEP"
    echo "  $1"
    echo "$SEP"
}

# -- Section 1: OS Identity and Version ------------------------------------
section "SECTION 1 - OS Identity and Version"

echo "  Hostname     : $(hostname -f 2>/dev/null || hostname)"
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    echo "  Distro       : ${PRETTY_NAME:-unknown}"
    echo "  VERSION_ID   : ${VERSION_ID:-unknown}"
    echo "  Codename     : ${UBUNTU_CODENAME:-${VERSION_CODENAME:-unknown}}"
fi
echo "  Kernel       : $(uname -r)"
echo "  Architecture : $(uname -m)"
echo "  LSB Release  : $(lsb_release -ds 2>/dev/null || echo 'lsb_release not found')"

# -- Section 2: Uptime and Reboot Status -----------------------------------
section "SECTION 2 - Uptime and Reboot Status"

echo "  Uptime       : $(uptime -p 2>/dev/null || uptime)"
echo "  Last Boot    : $(who -b 2>/dev/null | awk '{print $3, $4}' || echo 'unknown')"

if [[ -f /var/run/reboot-required ]]; then
    echo "  [WARN] REBOOT REQUIRED"
    if [[ -f /var/run/reboot-required.pkgs ]]; then
        echo "  Packages requiring reboot:"
        sed 's/^/    /' /var/run/reboot-required.pkgs
    fi
else
    echo "  [OK]   No reboot required"
fi

# -- Section 3: Ubuntu Pro / ESM Status ------------------------------------
section "SECTION 3 - Ubuntu Pro and ESM Status"

if command -v pro &>/dev/null; then
    pro_status=$(pro status 2>/dev/null || echo "  Unable to query Pro status")
    echo "$pro_status" | head -20 | sed 's/^/  /'
elif command -v ua &>/dev/null; then
    ua status 2>/dev/null | head -20 | sed 's/^/  /' || echo "  Unable to query UA status"
else
    echo "  [INFO] ubuntu-advantage-tools not installed"
    echo "  Install: apt install ubuntu-advantage-tools"
fi

# -- Section 4: Livepatch Status -------------------------------------------
section "SECTION 4 - Livepatch Status"

if command -v canonical-livepatch &>/dev/null; then
    lp_status=$(canonical-livepatch status 2>/dev/null || echo "  Unable to query Livepatch")
    echo "$lp_status" | sed 's/^/  /'
else
    echo "  [INFO] Livepatch not installed"
    echo "  Enable with: pro enable livepatch"
fi

# -- Section 5: Hardware Summary -------------------------------------------
section "SECTION 5 - Hardware Summary"

echo "  CPU Model    : $(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs || echo 'unknown')"
echo "  CPU Cores    : $(nproc)"
echo "  Total RAM    : $(free -h | awk '/^Mem:/{print $2}')"
echo "  Swap         : $(free -h | awk '/^Swap:/{print $2}')"

virt=$(systemd-detect-virt 2>/dev/null || echo "unknown")
echo "  Virtualization: $virt"

echo ""
echo "$SEP"
echo "  System Health Check Complete - $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "$SEP"
