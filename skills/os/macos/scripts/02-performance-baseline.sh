#!/bin/bash
# ============================================================================
# macOS - Performance Baseline
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

echo "$SEP"
echo "  macOS PERFORMANCE BASELINE"
echo "  $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "$SEP"

# -- Section 1: CPU Load -----------------------------------------------------
section "SECTION 1 - CPU Load"

LOAD=$(uptime | awk -F'load averages:' '{print $2}')
echo "  Load Averages (1m / 5m / 15m): $LOAD"

CORES=$(sysctl -n hw.ncpu 2>/dev/null || echo "unknown")
echo "  Logical CPUs : $CORES"

if [[ "$(uname -m)" == "arm64" ]]; then
    P_CORES=$(sysctl -n hw.perflevel0.physicalcpu 2>/dev/null || echo "?")
    E_CORES=$(sysctl -n hw.perflevel1.physicalcpu 2>/dev/null || echo "?")
    echo "  P-cores      : $P_CORES"
    echo "  E-cores      : $E_CORES"
fi

# -- Section 2: Memory -------------------------------------------------------
section "SECTION 2 - Memory"

MEMSIZE=$(sysctl -n hw.memsize 2>/dev/null || echo "0")
MEMSIZE_GB=$(( MEMSIZE / 1073741824 ))
echo "  Total RAM    : ${MEMSIZE_GB} GB"

echo ""
echo "  vm_stat snapshot:"
vm_stat 2>/dev/null | head -15 | sed 's/^/    /'

echo ""
echo "  Memory pressure (sysctl):"
VM_PRESSURE=$(sysctl -n kern.memorystatus_vm_pressure_level 2>/dev/null || echo "unknown")
case "$VM_PRESSURE" in
    1) echo "    Level: Normal (no pressure)" ;;
    2) echo "    Level: Warning (memory pressure)" ;;
    4) echo "    Level: Critical (severe pressure)" ;;
    *) echo "    Level: $VM_PRESSURE" ;;
esac

# -- Section 3: Swap Usage ---------------------------------------------------
section "SECTION 3 - Swap Usage"

sysctl vm.swapusage 2>/dev/null | sed 's/^/  /' || echo "  Unable to query swap"

SWAP_DIR="/private/var/vm"
if [[ -d "$SWAP_DIR" ]]; then
    SWAP_FILES=$(ls "$SWAP_DIR"/swapfile* 2>/dev/null | wc -l | tr -d ' ')
    echo "  Swap files   : $SWAP_FILES"
fi

# -- Section 4: Disk I/O -----------------------------------------------------
section "SECTION 4 - Disk I/O (iostat snapshot)"

iostat -d -c 3 2>/dev/null | head -10 | sed 's/^/  /' || echo "  iostat not available"

# -- Section 5: Top Processes by CPU -----------------------------------------
section "SECTION 5 - Top Processes by CPU"

ps aux 2>/dev/null | sort -nrk 3 | head -10 | awk '{printf "  %-8s %-6s %5s%% %5s%%  %s\n", $1, $2, $3, $4, $11}' || echo "  Unable to list processes"

# -- Section 6: Top Processes by Memory --------------------------------------
section "SECTION 6 - Top Processes by Memory"

ps aux 2>/dev/null | sort -nrk 4 | head -10 | awk '{printf "  %-8s %-6s %5s%% %5s%%  %s\n", $1, $2, $3, $4, $11}' || echo "  Unable to list processes"

# -- Section 7: Thermal (Apple Silicon) --------------------------------------
section "SECTION 7 - Thermal Status"

if [[ "$(uname -m)" == "arm64" ]]; then
    echo "  Note: Full thermal data requires: sudo powermetrics --samplers cpu_power,thermal -n 1"
    # Attempt non-sudo thermal check
    THERMAL=$(pmset -g therm 2>/dev/null || echo "")
    if [[ -n "$THERMAL" ]]; then
        echo "$THERMAL" | sed 's/^/  /'
    else
        echo "  Unable to query thermal state without elevated privileges"
    fi
else
    echo "  Intel Mac - thermal data via: sudo powermetrics --samplers thermal -n 1"
    pmset -g therm 2>/dev/null | sed 's/^/  /' || echo "  Unable to query thermal state"
fi

echo ""
echo "$SEP"
echo "  Performance baseline complete - $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "$SEP"
