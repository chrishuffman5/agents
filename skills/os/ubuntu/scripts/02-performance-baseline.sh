#!/usr/bin/env bash
# ============================================================================
# Ubuntu - Performance Baseline
#
# Purpose : Capture CPU, memory, disk, and network baseline metrics for
#           comparison against future measurements.
# Version : 1.0.0
# Targets : Ubuntu 20.04+
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. CPU Utilization
#   2. Memory Utilization
#   3. Disk Utilization
#   4. Network Connections
# ============================================================================
set -euo pipefail

SEP="$(printf '=%.0s' {1..70})"

section() { echo ""; echo "$SEP"; echo "  $1"; echo "$SEP"; }

# -- Section 1: CPU --------------------------------------------------------
section "SECTION 1 - CPU Utilization"
echo "  Load Average (1/5/15 min):"
awk '{printf "    %s / %s / %s\n", $1, $2, $3}' /proc/loadavg
echo ""
echo "  Top 10 CPU-consuming processes:"
ps aux --sort=-%cpu | head -11 | awk 'NR==1{print "  "$0} NR>1{print "    "$0}'
echo ""
echo "  CPU governor:"
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null \
    | sed 's/^/    /' || echo "    not available (no cpufreq)"

# -- Section 2: Memory -----------------------------------------------------
section "SECTION 2 - Memory Utilization"
free -h | sed 's/^/  /'
echo ""
echo "  Top 10 memory-consuming processes:"
ps aux --sort=-%mem | head -11 | awk 'NR==1{print "  "$0} NR>1{print "    "$0}'
echo ""
echo "  OOM score adjustments (high values = first to kill):"
for pid in $(ls /proc | grep -E '^[0-9]+$' | head -20); do
    score=$(cat /proc/$pid/oom_score 2>/dev/null || continue)
    comm=$(cat /proc/$pid/comm 2>/dev/null || echo "?")
    [[ $score -gt 100 ]] && echo "    PID=$pid comm=$comm oom_score=$score"
done || true

# -- Section 3: Disk -------------------------------------------------------
section "SECTION 3 - Disk Utilization"
echo "  Filesystem usage:"
df -hT --exclude-type=tmpfs --exclude-type=devtmpfs --exclude-type=squashfs \
    2>/dev/null | sed 's/^/  /'
echo ""
echo "  Inode usage (filesystems >80% inode):"
df -i --exclude-type=tmpfs --exclude-type=squashfs 2>/dev/null \
    | awk 'NR==1{print "  "$0} NR>1 && $5!="100%" && int($5)>80{print "  [WARN] "$0}'
echo ""
if command -v iostat &>/dev/null; then
    echo "  I/O statistics (1-second sample):"
    iostat -xz 1 1 2>/dev/null | sed 's/^/  /' | tail -20
fi

# -- Section 4: Network ----------------------------------------------------
section "SECTION 4 - Network Connections"
echo "  Connection state summary:"
ss -s 2>/dev/null | sed 's/^/  /'
echo ""
echo "  Listening TCP/UDP services:"
ss -tlunp 2>/dev/null | sed 's/^/  /'

echo ""
echo "$SEP"
echo "  Performance Baseline Complete - $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "$SEP"
