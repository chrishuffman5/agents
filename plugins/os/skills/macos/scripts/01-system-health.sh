#!/bin/bash
# ============================================================================
# macOS - System Health Overview
# Version : 1.0.0
# Targets : macOS 14+ (Sonoma and later)
# Safety  : Read-only. No modifications to system configuration.
# ============================================================================

set -euo pipefail

SEP="$(printf '=%.0s' {1..70})"

section() {
    echo ""
    echo "$SEP"
    echo "  $1"
    echo "$SEP"
}

# -- Section 1: OS Version ---------------------------------------------------
section "SECTION 1 - OS Identity and Version"

echo "  Hostname     : $(scutil --get ComputerName 2>/dev/null || hostname)"
echo "  Local Host   : $(scutil --get LocalHostName 2>/dev/null || echo 'unknown')"

SW_VERS=$(sw_vers 2>/dev/null || echo "sw_vers not available")
echo "$SW_VERS" | sed 's/^/  /'

echo "  Kernel       : $(uname -r)"
echo "  Architecture : $(uname -m)"

# -- Section 2: Hardware Summary ----------------------------------------------
section "SECTION 2 - Hardware Summary"

CHIP=$(uname -m)
if [[ "$CHIP" == "arm64" ]]; then
    echo "  Platform     : Apple Silicon"
    MODEL=$(system_profiler SPHardwareDataType 2>/dev/null | awk -F': ' '/Model Name/{print $2}' || echo "unknown")
    CPU=$(system_profiler SPHardwareDataType 2>/dev/null | awk -F': ' '/Chip/{print $2}' || echo "unknown")
    echo "  Model        : ${MODEL:-Unknown}"
    echo "  Chip         : ${CPU:-Unknown}"
else
    echo "  Platform     : Intel"
    MODEL=$(system_profiler SPHardwareDataType 2>/dev/null | awk -F': ' '/Model Name/{print $2}' || echo "unknown")
    CPU=$(system_profiler SPHardwareDataType 2>/dev/null | awk -F': ' '/Processor Name/{print $2}' || echo "unknown")
    echo "  Model        : ${MODEL:-Unknown}"
    echo "  Processor    : ${CPU:-Unknown}"
fi

MEMORY=$(system_profiler SPHardwareDataType 2>/dev/null | awk -F': ' '/Memory/{print $2}' || echo "unknown")
SERIAL=$(system_profiler SPHardwareDataType 2>/dev/null | awk -F': ' '/Serial Number \(system\)/{print $2}' || echo "unknown")
echo "  Memory       : ${MEMORY:-Unknown}"
echo "  Serial       : ${SERIAL:-Unknown}"

# -- Section 3: Rosetta 2 ----------------------------------------------------
section "SECTION 3 - Rosetta 2 Status"

if [[ "$CHIP" == "arm64" ]]; then
    if /usr/bin/pgrep -q oahd 2>/dev/null; then
        echo "  [OK]   Rosetta 2 daemon (oahd) is running"
    elif arch -x86_64 /usr/bin/true 2>/dev/null; then
        echo "  [OK]   Rosetta 2 is installed (daemon not currently active)"
    else
        echo "  [INFO] Rosetta 2 is not installed"
        echo "         Install: softwareupdate --install-rosetta --agree-to-license"
    fi
else
    echo "  [INFO] N/A - Intel Mac (Rosetta 2 is for Apple Silicon only)"
fi

# -- Section 4: SIP Status ---------------------------------------------------
section "SECTION 4 - System Integrity Protection"

SIP_STATUS=$(csrutil status 2>&1)
if echo "$SIP_STATUS" | grep -q "enabled"; then
    echo "  [OK]   $SIP_STATUS"
else
    echo "  [WARN] $SIP_STATUS"
fi

# -- Section 5: Boot Volume --------------------------------------------------
section "SECTION 5 - Boot Volume"

diskutil info / 2>/dev/null | awk -F':' '
    /Volume Name|File System Personality|Volume UUID|Disk Identifier/{
        gsub(/^[ \t]+|[ \t]+$/, "", $2)
        printf "  %-24s: %s\n", $1, $2
    }' || echo "  Unable to query boot volume"

# -- Section 6: Uptime and Last Boot -----------------------------------------
section "SECTION 6 - Uptime and Last Boot"

echo "  Uptime       : $(uptime 2>/dev/null | sed 's/.*up /up /' | sed 's/,.*//')"
echo ""
echo "  Recent reboots:"
last reboot 2>/dev/null | head -3 | sed 's/^/    /' || echo "    Unable to query reboot history"

echo ""
echo "$SEP"
echo "  System health check complete - $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "$SEP"
