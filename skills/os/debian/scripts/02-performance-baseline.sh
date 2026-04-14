#!/usr/bin/env bash
# ============================================================================
# Debian - Performance Baseline
#
# Purpose : CPU, memory, swap, disk I/O, network, and top process snapshot
#           for performance baselining and capacity planning.
# Version : 1.0.0
# Targets : Debian 11+ (Bullseye and later)
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. CPU
#   2. Memory
#   3. Swap Usage
#   4. Disk I/O
#   5. Disk Space
#   6. Network Interfaces
#   7. Top Processes by CPU
#   8. Top Processes by Memory
#   9. vmstat Snapshot
# ============================================================================
set -euo pipefail

echo "=== DEBIAN PERFORMANCE BASELINE ==="
echo "Date: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo ""

echo "--- CPU ---"
lscpu | grep -E 'Model name|Socket|Core|Thread|CPU MHz|CPU max|NUMA'
echo ""
echo "Load average:"
cat /proc/loadavg
echo ""

echo "--- Memory ---"
free -h
echo ""
cat /proc/meminfo | grep -E '^(MemTotal|MemFree|MemAvailable|Buffers|Cached|SwapTotal|SwapFree):'
echo ""

echo "--- Swap Usage ---"
if swapon --show 2>/dev/null | grep -q .; then
    swapon --show
else
    echo "No swap configured"
fi
echo ""

echo "--- Disk I/O (iostat snapshot) ---"
if command -v iostat &>/dev/null; then
    iostat -x 1 2 2>/dev/null | tail -n +4 || true
else
    echo "iostat not available (install sysstat)"
fi
echo ""

echo "--- Disk Space ---"
df -hT --exclude-type=tmpfs --exclude-type=devtmpfs --exclude-type=overlay \
   --exclude-type=squashfs 2>/dev/null || df -hT
echo ""

echo "--- Network Interfaces ---"
ip -s link show 2>/dev/null | grep -E '^[0-9]+:|RX:|TX:' | head -40
echo ""

echo "--- Top 10 Processes by CPU ---"
ps aux --sort=-%cpu | head -12
echo ""

echo "--- Top 10 Processes by Memory ---"
ps aux --sort=-%mem | head -12
echo ""

echo "--- vmstat snapshot ---"
vmstat 1 3
