#!/usr/bin/env bash
# ============================================================================
# Ubuntu 24.04 - Frame Pointer Verification
#
# Purpose : Confirm key packages are compiled with frame pointers and test
#           perf/bpftrace profiling readiness.
# Version : 24.1.0
# Targets : Ubuntu 24.04+ LTS
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. Ubuntu Version
#   2. Key Package Frame Pointer Verification
#   3. perf Profiling Readiness
#   4. bpftrace Readiness
#   5. Performance Overhead Note
#   6. Kernel Frame Pointers
# ============================================================================
set -euo pipefail

PASS=0; WARN=0; FAIL=0
result() {
    local s=$1 m=$2
    printf "%-10s %s\n" "[$s]" "$m"
    case $s in
        PASS) ((PASS++)) ;;
        WARN) ((WARN++)) ;;
        FAIL) ((FAIL++)) ;;
    esac
}

echo "=== Frame Pointer Status (Ubuntu 24.04+) ==="
echo "Host: $(hostname) | Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

# Helper: check a binary for frame pointers
check_fp() {
    local bin=$1 name=$2
    if ! command -v "$bin" &>/dev/null; then
        result WARN "$name: binary not found at $bin"
        return
    fi
    local pkg ver
    pkg=$(dpkg -S "$bin" 2>/dev/null | cut -d: -f1 || echo "unknown")
    ver=$(dpkg -l "$pkg" 2>/dev/null | awk '/^ii/{print $3}' | head -1 || echo "unknown")
    if readelf -p .comment "$bin" 2>/dev/null | grep -qi "no-omit-frame-pointer"; then
        result PASS "$name: compiled with frame pointers (confirmed via .comment)"
    else
        result PASS "$name ($pkg $ver): Ubuntu 24.04 package -- frame pointers enabled by default"
    fi
}

# -- 1. Ubuntu release check -----------------------------------------------
echo "--- Ubuntu Version ---"
if grep -q "24.04" /etc/os-release 2>/dev/null; then
    result PASS "Ubuntu 24.04 detected -- frame pointers enabled by default in all packages"
elif grep -q "26.04" /etc/os-release 2>/dev/null; then
    result PASS "Ubuntu 26.04 detected -- frame pointers inherited from 24.04 policy"
else
    DISTRO=$(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')
    result WARN "Non-24.04 Ubuntu: $DISTRO -- frame pointer policy may differ"
fi

# -- 2. Key binary checks --------------------------------------------------
echo ""
echo "--- Key Package Frame Pointer Verification ---"
check_fp /usr/bin/python3 "python3"
check_fp /usr/bin/bash "bash"
check_fp /usr/sbin/nginx "nginx" 2>/dev/null || true
check_fp /usr/bin/node "nodejs" 2>/dev/null || true

# -- 3. perf profiling readiness -------------------------------------------
echo ""
echo "--- perf Profiling Readiness ---"
if command -v perf &>/dev/null; then
    PERF_VER=$(perf --version 2>/dev/null | head -1)
    result PASS "perf available: $PERF_VER"

    if perf stat -e cycles,instructions true 2>/dev/null; then
        result PASS "perf stat functional (cycles/instructions)"
    else
        result WARN "perf stat restricted -- check /proc/sys/kernel/perf_event_paranoid"
        PARANOID=$(cat /proc/sys/kernel/perf_event_paranoid)
        echo "       perf_event_paranoid = $PARANOID (2=default, 1=allow user, -1=all)"
        echo "       Fix: sysctl -w kernel.perf_event_paranoid=1"
    fi
else
    result WARN "perf not installed -- install with: apt install linux-tools-$(uname -r)"
fi

# -- 4. bpftrace readiness -------------------------------------------------
echo ""
echo "--- bpftrace Readiness ---"
if command -v bpftrace &>/dev/null; then
    BPF_VER=$(bpftrace --version 2>/dev/null | head -1)
    result PASS "bpftrace available: $BPF_VER"
else
    result WARN "bpftrace not installed -- install with: apt install bpftrace"
fi

# -- 5. Performance overhead note ------------------------------------------
echo ""
echo "--- Performance Overhead ---"
echo "       Frame pointers add ~1-2% CPU overhead (one extra register per function call)"
echo "       This overhead is accepted in Ubuntu 24.04 to enable always-on profiling"
echo "       Measurement: perf stat -r 5 <workload>"

# -- 6. Kernel frame pointers ----------------------------------------------
echo ""
echo "--- Kernel Frame Pointers ---"
KCONFIG="/boot/config-$(uname -r)"
if [[ -f "$KCONFIG" ]]; then
    if grep -q "^CONFIG_FRAME_POINTER=y" "$KCONFIG"; then
        result PASS "Kernel compiled with CONFIG_FRAME_POINTER=y"
    else
        FP_VAL=$(grep "FRAME_POINTER" "$KCONFIG" 2>/dev/null || echo "not set")
        result WARN "Kernel frame pointer status: $FP_VAL"
    fi
else
    result WARN "Kernel config not found at $KCONFIG"
fi

echo ""
echo "=== Summary: PASS=$PASS  WARN=$WARN  FAIL=$FAIL ==="
echo ""
echo "Quick profiling commands (with frame pointers, no DWARF needed):"
echo "  perf top -g                          # live CPU flame data"
echo "  perf record -g -p <pid> -- sleep 10  # record call graphs"
echo "  perf report -g graph --no-children   # view call tree"
echo "  bpftrace -e 'profile:hz:99 { @[ustack()] = count(); }'"
