#!/usr/bin/env bash
# ============================================================================
# Debian - System Health Dashboard
#
# Purpose : Comprehensive system health overview including OS version,
#           kernel, uptime, APT sources, security repo, reboot status,
#           and package counts.
# Version : 1.0.0
# Targets : Debian 11+ (Bullseye and later)
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. OS Identity and Version
#   2. Uptime and Reboot Status
#   3. APT Sources Configuration
#   4. Security Repository Check
#   5. Hardware Summary
#   6. Package Counts
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
    echo "  Codename     : ${VERSION_CODENAME:-unknown}"
fi
echo "  Debian Ver   : $(cat /etc/debian_version 2>/dev/null || echo 'N/A')"
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

# -- Section 3: APT Sources Configuration ----------------------------------
section "SECTION 3 - APT Sources Configuration"

echo "  == /etc/apt/sources.list =="
grep -v '^#' /etc/apt/sources.list 2>/dev/null | grep -v '^$' || echo "  (empty or absent)"
echo ""
echo "  == /etc/apt/sources.list.d/ =="
for f in /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources 2>/dev/null; do
    [ -f "$f" ] || continue
    echo "  -- $f --"
    grep -v '^#' "$f" | grep -v '^$' || echo "  (empty)"
done

# -- Section 4: Security Repository Check ----------------------------------
section "SECTION 4 - Security Repository Check"

if grep -qr 'security.debian.org' /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null; then
    echo "  [OK]   security.debian.org is configured"
    grep -rh 'security.debian.org' /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null | \
        grep -v '^#' | sed 's/^/  /'
else
    echo "  [WARN] security.debian.org NOT found in sources"
    echo "         Security updates may not be applied"
fi

# -- Section 5: Hardware Summary -------------------------------------------
section "SECTION 5 - Hardware Summary"

echo "  CPU Model    : $(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs || echo 'unknown')"
echo "  CPU Cores    : $(nproc)"
echo "  Total RAM    : $(free -h | awk '/^Mem:/{print $2}')"
echo "  Swap         : $(free -h | awk '/^Swap:/{print $2}')"

virt=$(systemd-detect-virt 2>/dev/null || echo "unknown")
echo "  Virtualization: $virt"

# -- Section 6: Package Counts --------------------------------------------
section "SECTION 6 - Package Counts"

echo "  Installed    : $(dpkg --get-selections 2>/dev/null | grep -c ' install$') packages"
echo "  Held         : $(dpkg --get-selections 2>/dev/null | grep -c ' hold$' || echo 0) packages"
echo "  Last Update  : $(stat /var/lib/apt/lists/ 2>/dev/null | grep Modify | sed 's/Modify: //' || echo 'Unknown')"

echo ""
echo "$SEP"
echo "  System Health Check Complete - $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "$SEP"
