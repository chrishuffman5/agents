#!/usr/bin/env bash
# ============================================================================
# SLES - Performance Baseline
#
# Purpose : Capture system performance baseline including CPU, memory,
#           disk I/O, Btrfs filesystem usage, network stats, and
#           saptune tuning status.
# Version : 1.0.0
# Targets : SLES 15 SP5+
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. CPU Information
#   2. Memory Overview
#   3. Disk Usage and Btrfs
#   4. Disk I/O Statistics
#   5. Network Interface Stats
#   6. Load and Process Overview
#   7. vmstat Snapshot
#   8. saptune Status
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
echo "  SLES Performance Baseline - $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "$SEP"

# ── Section 1: CPU Information ──────────────────────────────────────────────
section "SECTION 1 - CPU Information"

lscpu 2>/dev/null | grep -E "Architecture|CPU\(s\)|Thread|Core|Socket|Model name|MHz|NUMA" \
    | sed 's/^/  /'

# ── Section 2: Memory Overview ──────────────────────────────────────────────
section "SECTION 2 - Memory Overview"

free -h 2>/dev/null | sed 's/^/  /'
echo ""
grep -E "MemTotal|MemFree|MemAvailable|SwapTotal|SwapFree|HugePages" /proc/meminfo 2>/dev/null \
    | sed 's/^/  /'

# ── Section 3: Disk Usage and Btrfs ────────────────────────────────────────
section "SECTION 3 - Disk Usage"

df -h --exclude-type=tmpfs --exclude-type=devtmpfs 2>/dev/null | sed 's/^/  /'

echo ""
echo "  Btrfs filesystem usage:"
for mp in $(findmnt -t btrfs -n -o TARGET 2>/dev/null); do
    echo "    Mount: $mp"
    btrfs filesystem df "$mp" 2>/dev/null | sed 's/^/      /' || true
    echo ""
done

# ── Section 4: Disk I/O Statistics ──────────────────────────────────────────
section "SECTION 4 - Disk I/O Statistics"

if command -v iostat &>/dev/null; then
    iostat -xd 1 1 2>/dev/null | sed 's/^/  /'
else
    echo "  iostat not available (install sysstat)"
    echo "  Fallback: /proc/diskstats"
    cat /proc/diskstats 2>/dev/null \
        | awk 'NF>10 {print $3, "reads:"$4, "writes:"$8}' \
        | grep -v "^loop\|^ram" | head -20 | sed 's/^/  /'
fi

# ── Section 5: Network Interface Stats ──────────────────────────────────────
section "SECTION 5 - Network Interface Stats"

ip -s link show 2>/dev/null | grep -E "^[0-9]|RX:|TX:|bytes" | head -40 | sed 's/^/  /'

# ── Section 6: Load and Process Overview ────────────────────────────────────
section "SECTION 6 - Load and Process Overview"

echo "  Load Average: $(cat /proc/loadavg)"
echo ""

echo "  Top CPU Processes:"
ps aux --sort=-%cpu 2>/dev/null | head -11 | sed 's/^/    /'
echo ""

echo "  Top Memory Processes:"
ps aux --sort=-%mem 2>/dev/null | head -11 | sed 's/^/    /'

# ── Section 7: vmstat Snapshot ──────────────────────────────────────────────
section "SECTION 7 - vmstat Snapshot"

vmstat -w 1 3 2>/dev/null | sed 's/^/  /' || echo "  vmstat not available"

# ── Section 8: saptune Status ──────────────────────────────────────────────
section "SECTION 8 - saptune Status"

if command -v saptune &>/dev/null; then
    saptune status 2>/dev/null | sed 's/^/  /' || echo "  saptune status failed"
else
    echo "  saptune not installed"
fi

echo ""
echo "$SEP"
echo "  Performance Baseline Complete - $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "$SEP"
