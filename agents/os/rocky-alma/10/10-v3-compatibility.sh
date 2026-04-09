#!/usr/bin/env bash
# ============================================================================
# Rocky/AlmaLinux v10 - x86_64 ISA Level Compatibility Check
#
# Purpose : Determine CPU ISA level, detect build type (v2 vs v3), and
#           report hardware compatibility for Rocky 10 and AlmaLinux 10.
# Version : 1.0.0
# Targets : Rocky Linux 10 / AlmaLinux 10 (or pre-install assessment)
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. Architecture Detection
#   2. CPU Flag Detection (v1/v2/v3/v4)
#   3. ISA Level Determination
#   4. ld.so Cross-Check
#   5. Distro Build Type Detection
#   6. Compatibility Assessment
# ============================================================================
set -euo pipefail

echo "=== x86_64 ISA Level Compatibility Check ==="
echo "Date: $(date)"
echo ""

ARCH=$(uname -m)
echo "Architecture: $ARCH"
echo ""

if [ "$ARCH" != "x86_64" ]; then
    echo "[INFO] Non-x86_64 architecture detected: $ARCH"
    echo "[INFO] x86_64 ISA level requirements do not apply"
    echo "[INFO] Rocky 10 and AlmaLinux 10 support: aarch64, ppc64le, s390x"
    if [ "$ARCH" = "riscv64" ]; then
        echo "[INFO] RISC-V detected — Rocky 10 community tier supports riscv64"
        echo "[INFO] AlmaLinux 10 does not officially support riscv64"
    fi
    exit 0
fi

# --- CPU flag detection ---
echo "=== CPU Flag Detection ==="
CPU_FLAGS=$(grep -m1 "^flags" /proc/cpuinfo | cut -d: -f2)

has_flag() { echo "$CPU_FLAGS" | grep -qw "$1"; }

V1_FLAGS="lm cmov cx8 fpu fxsr mmx syscall sse2"
V2_FLAGS="cx16 lahf_lm popcnt sse4_1 sse4_2 ssse3"
V3_FLAGS="avx avx2 bmi1 bmi2 f16c fma abm movbe"
V4_FLAGS="avx512f avx512bw avx512cd avx512dq avx512vl"

echo ""
echo "--- v1 flags (universal x86_64) ---"
for flag in $V1_FLAGS; do
    if has_flag "$flag"; then echo "  [+] $flag"
    else echo "  [-] $flag MISSING"; fi
done

echo ""
echo "--- v2 flags (SSE4.2 era) ---"
V2_MISSING=()
for flag in $V2_FLAGS; do
    if has_flag "$flag"; then echo "  [+] $flag"
    else echo "  [-] $flag MISSING"; V2_MISSING+=("$flag"); fi
done

echo ""
echo "--- v3 flags (Haswell+, required for RHEL/Rocky/Alma 10 standard) ---"
V3_MISSING=()
for flag in $V3_FLAGS; do
    if has_flag "$flag"; then echo "  [+] $flag"
    else echo "  [-] $flag MISSING"; V3_MISSING+=("$flag"); fi
done

echo ""
echo "--- v4 flags (AVX-512, optional) ---"
V4_MISSING=()
for flag in $V4_FLAGS; do
    if has_flag "$flag"; then echo "  [+] $flag"
    else echo "  [-] $flag (not present)"; V4_MISSING+=("$flag"); fi
done

# --- ISA level determination ---
echo ""
echo "=== ISA Level Determination ==="

if [ ${#V2_MISSING[@]} -gt 0 ]; then
    ISA_LEVEL="x86_64-v1"
elif [ ${#V3_MISSING[@]} -gt 0 ]; then
    ISA_LEVEL="x86_64-v2"
elif [ ${#V4_MISSING[@]} -gt 0 ]; then
    ISA_LEVEL="x86_64-v3"
else
    ISA_LEVEL="x86_64-v4"
fi

echo "Detected ISA level: $ISA_LEVEL"

# --- ld.so cross-check ---
echo ""
echo "=== ld.so ISA Level Cross-Check ==="
if [ -x /lib64/ld-linux-x86-64.so.2 ]; then
    LD_OUTPUT=$(/lib64/ld-linux-x86-64.so.2 --help 2>&1 || true)
    echo "$LD_OUTPUT" | grep -E "x86-64-v[1-4]" | sed 's/^/  /'
else
    echo "  /lib64/ld-linux-x86-64.so.2 not found or not executable"
fi

# --- Distro build type detection ---
echo ""
echo "=== Distro Build Type Detection ==="
if [ -f /etc/almalinux-release ]; then
    DISTRO="almalinux"
    cat /etc/almalinux-release
elif [ -f /etc/rocky-release ]; then
    DISTRO="rocky"
    cat /etc/rocky-release
else
    DISTRO="unknown"
    echo "Cannot identify as AlmaLinux or Rocky Linux"
fi

BUILD_TYPE="unknown"
if [ "$DISTRO" = "almalinux" ]; then
    if rpm -qa | grep -q "almalinux.*v2\|v2.*almalinux" 2>/dev/null; then
        echo "[INFO] AlmaLinux x86_64_v2 build detected"
        BUILD_TYPE="almalinux-v2"
    elif dnf repolist 2>/dev/null | grep -q "v2"; then
        echo "[INFO] x86_64_v2 repos detected"
        BUILD_TYPE="almalinux-v2"
    else
        echo "[INFO] Standard AlmaLinux build (x86_64_v3 baseline)"
        BUILD_TYPE="almalinux-standard"
    fi
elif [ "$DISTRO" = "rocky" ]; then
    echo "[INFO] Rocky Linux — x86_64_v3 baseline only (no v2 builds)"
    BUILD_TYPE="rocky-standard"
fi

# --- Compatibility assessment ---
echo ""
echo "=== Compatibility Assessment ==="
echo "Hardware ISA level: $ISA_LEVEL"
echo ""

case "$ISA_LEVEL" in
    "x86_64-v1")
        echo "[FAIL] Hardware does not meet x86_64-v2 minimum"
        echo "       Cannot run Rocky 10, AlmaLinux 10, or RHEL 10"
        echo "       This hardware is end-of-life for EL10 deployment"
        ;;
    "x86_64-v2")
        echo "[WARN] Hardware meets x86_64-v2 but NOT x86_64-v3"
        echo ""
        echo "  Rocky Linux 10:           INCOMPATIBLE (requires x86_64_v3)"
        echo "  AlmaLinux 10 (standard):  INCOMPATIBLE (requires x86_64_v3)"
        echo "  AlmaLinux 10 (v2 build):  COMPATIBLE"
        echo ""
        echo "  To run EL10 on this hardware, use AlmaLinux 10 x86_64_v2 media:"
        echo "  https://almalinux.org/get-almalinux/"
        ;;
    "x86_64-v3"|"x86_64-v4")
        echo "[PASS] Hardware meets x86_64-v3 requirement"
        echo ""
        echo "  Rocky Linux 10:           COMPATIBLE"
        echo "  AlmaLinux 10 (standard):  COMPATIBLE"
        echo "  AlmaLinux 10 (v2 build):  COMPATIBLE (runs fine on v3+ hardware)"
        ;;
esac

if [ "$ISA_LEVEL" = "x86_64-v2" ] && [ ${#V3_MISSING[@]} -gt 0 ]; then
    echo ""
    echo "Missing x86_64-v3 flags: ${V3_MISSING[*]}"
    echo "CPU generation is likely pre-Haswell (pre-2013)"
fi

echo ""
echo "=== Done ==="
