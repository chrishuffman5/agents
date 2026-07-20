#!/usr/bin/env bash
# ============================================================================
# RHEL - Performance Baseline
#
# Purpose : Capture CPU, memory, disk, and network performance metrics
#           as a baseline snapshot using sar, vmstat, iostat, free, and ss.
# Version : 1.0.0
# Targets : RHEL 8+
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. CPU Utilization
#   2. Memory Usage
#   3. Disk I/O
#   4. Network Interface Statistics
#   5. Load Average and Process Queue
#   6. Top Processes by Resource
# ============================================================================
set -euo pipefail

SEP="$(printf '=%.0s' {1..70})"
section() { echo ""; echo "$SEP"; echo "  $1"; echo "$SEP"; }

echo "RHEL Performance Baseline"
echo "Generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "Hostname:  $(hostname -f 2>/dev/null || hostname)"

# ── Section 1: CPU Utilization ──────────────────────────────────────────────
section "1. CPU Utilization (5-second snapshot)"

if command -v mpstat &>/dev/null; then
    mpstat -P ALL 5 1 2>/dev/null | sed 's/^/  /'
else
    echo "  [INFO] mpstat not available (install sysstat)"
    echo "  Fallback: top snapshot"
    top -b -n 1 | head -5 | sed 's/^/  /'
fi

# ── Section 2: Memory Usage ─────────────────────────────────────────────────
section "2. Memory Usage"

free -h 2>/dev/null | sed 's/^/  /'

echo ""
echo "  Key /proc/meminfo values:"
grep -E "MemTotal|MemFree|MemAvailable|Buffers|Cached|SwapTotal|SwapFree|Slab" /proc/meminfo 2>/dev/null | sed 's/^/    /'

swap_total=$(awk '/SwapTotal/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)
swap_free=$(awk '/SwapFree/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)
if [[ "$swap_total" -gt 0 ]] && [[ "$swap_free" -lt $((swap_total / 2)) ]]; then
    echo ""
    echo "  [WARN] Swap usage above 50% -- investigate memory pressure"
fi

# ── Section 3: Disk I/O ────────────────────────────────────────────────────
section "3. Disk I/O (5-second snapshot)"

if command -v iostat &>/dev/null; then
    iostat -xz 5 1 2>/dev/null | sed 's/^/  /'
else
    echo "  [INFO] iostat not available (install sysstat)"
fi

echo ""
echo "  Filesystem usage:"
df -hT 2>/dev/null | sed 's/^/    /'

# Check for near-full filesystems
df -hT 2>/dev/null | awk 'NR>1 {gsub(/%/,"",$6); if($6+0 >= 90) print "  [WARN] " $7 " is " $6 "% full"}' || true

# ── Section 4: Network Interface Statistics ──────────────────────────────────
section "4. Network Interface Statistics"

if command -v sar &>/dev/null; then
    sar -n DEV 5 1 2>/dev/null | sed 's/^/  /'
else
    echo "  Interface statistics (from /proc/net/dev):"
    cat /proc/net/dev 2>/dev/null | sed 's/^/    /'
fi

echo ""
echo "  Listening sockets:"
ss -tlnp 2>/dev/null | head -20 | sed 's/^/    /'

echo ""
echo "  Established connections: $(ss -t state established 2>/dev/null | wc -l)"

# ── Section 5: Load Average and Process Queue ───────────────────────────────
section "5. Load Average and Process Queue"

echo "  Load average : $(cat /proc/loadavg 2>/dev/null)"
echo "  CPU count    : $(nproc 2>/dev/null)"

if command -v vmstat &>/dev/null; then
    echo ""
    echo "  vmstat (5-second sample):"
    vmstat 5 2 2>/dev/null | sed 's/^/    /'
fi

# ── Section 6: Top Processes by Resource ────────────────────────────────────
section "6. Top Processes"

echo "  By CPU (top 10):"
ps -eo pid,ppid,cmd,%cpu,%mem --sort=-%cpu 2>/dev/null | head -11 | sed 's/^/    /'

echo ""
echo "  By Memory (top 10):"
ps -eo pid,ppid,cmd,%cpu,%mem --sort=-%mem 2>/dev/null | head -11 | sed 's/^/    /'

echo ""
echo "$SEP"
echo "  Performance Baseline Complete - $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "$SEP"
