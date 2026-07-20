#!/usr/bin/env bash
# ============================================================================
# Rocky Linux / AlmaLinux - RHEL Compatibility Audit
#
# Purpose : RHEL ABI compatibility check, package signature verification,
#           kernel module compatibility, third-party repo conflict detection.
# Version : 1.0.0
# Targets : Rocky Linux 8+ / AlmaLinux 8+
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. Distro Compatibility Fingerprint
#   2. Package Signature Audit
#   3. Kernel and Module Compatibility
#   4. Third-Party Repo Conflict Detection
#   5. ABI and Binary Compatibility Summary
# ============================================================================
set -euo pipefail

SEP="$(printf '=%.0s' {1..70})"
section() { echo ""; echo "$SEP"; echo "  $1"; echo "$SEP"; }
pass() { echo "  [PASS] $1"; }
warn() { echo "  [WARN] $1"; }
fail() { echo "  [FAIL] $1"; }

# -- Section 1: Distro Compatibility Fingerprint ---------------------------
section "SECTION 1 - Distro Compatibility Fingerprint"

source /etc/os-release 2>/dev/null || true
echo "  Distro       : ${NAME:-unknown}"
echo "  Version      : ${VERSION_ID:-unknown}"
echo "  Platform     : ${PLATFORM_ID:-unknown}"
echo "  ID           : ${ID:-unknown}"
echo "  ID_LIKE      : ${ID_LIKE:-unknown}"
echo ""

echo "${ID_LIKE:-}" | grep -q 'rhel' && \
    pass "ID_LIKE contains 'rhel' — RHEL ecosystem compatible" || \
    warn "ID_LIKE does not contain 'rhel': ${ID_LIKE:-empty}"

PLAT="${PLATFORM_ID:-}"
[[ "$PLAT" =~ platform:el[0-9]+ ]] && \
    pass "PLATFORM_ID is EL-format: $PLAT" || \
    fail "Unexpected PLATFORM_ID: $PLAT"

[[ -f /etc/redhat-release ]] && \
    pass "redhat-release present: $(cat /etc/redhat-release)" || \
    fail "/etc/redhat-release missing — RHEL compatibility broken"

echo ""
echo "  Rocky/Alma Model:"
case "${ID:-unknown}" in
    rocky)     echo "  Compatibility Mode: Binary Clone (1:1 RHEL)" ;;
    almalinux) echo "  Compatibility Mode: ABI Compatible (may include independent fixes)" ;;
    *)         echo "  Compatibility Mode: Unknown (ID=${ID:-unknown})" ;;
esac

# -- Section 2: Package Signature Audit ------------------------------------
section "SECTION 2 - Package Signature Audit"

echo "  Checking for unsigned packages..."
UNSIGNED=$(rpm -qa --qf '%{NAME} %{SIGPGP:pgpsig}\n' 2>/dev/null | grep '(none)' | awk '{print $1}')
if [[ -z "$UNSIGNED" ]]; then
    pass "All installed packages are signed"
else
    UNSIGNED_COUNT=$(echo "$UNSIGNED" | wc -l)
    warn "$UNSIGNED_COUNT unsigned package(s) found:"
    echo "$UNSIGNED" | head -20 | sed 's/^/    /'
fi

echo ""
echo "  Packages NOT signed by distro key (third-party):"
DISTRO_KEY_PATTERN=""
case "${ID:-unknown}" in
    rocky)     DISTRO_KEY_PATTERN="Rocky" ;;
    almalinux) DISTRO_KEY_PATTERN="AlmaLinux" ;;
esac

if [[ -n "$DISTRO_KEY_PATTERN" ]]; then
    THIRD_PARTY=$(rpm -qa --qf '%{NAME}\t%{PACKAGER}\n' 2>/dev/null | \
        grep -v "$DISTRO_KEY_PATTERN" | grep -v "^gpg-pubkey" | head -20)
    [[ -n "$THIRD_PARTY" ]] && echo "$THIRD_PARTY" | sed 's/^/  /' || \
        echo "  All packages are signed by distro or trusted source"
fi

# -- Section 3: Kernel and Module Compatibility ----------------------------
section "SECTION 3 - Kernel and Module Compatibility"

echo "  Running Kernel   : $(uname -r)"
echo "  Installed Kernels:"
rpm -qa 'kernel' --qf '  %{VERSION}-%{RELEASE}.%{ARCH}\n' 2>/dev/null | sort

echo ""
echo "  Kernel Variant:"
uname -r | grep -q 'rt\.' && echo "  Variant: Real-time (kernel-rt)" || \
    echo "  Variant: Standard"

echo ""
echo "  Loaded Third-Party Kernel Modules:"
if [[ -d /sys/module ]]; then
    UNSIGNED_MODS=$(cat /proc/modules 2>/dev/null | \
        awk '$NF ~ /\(OE\)/ || $NF ~ /\(O\)/{print $1}')
    [[ -n "$UNSIGNED_MODS" ]] && {
        warn "Out-of-tree or unsigned kernel modules loaded:"
        echo "$UNSIGNED_MODS" | sed 's/^/    /'
    } || pass "No out-of-tree kernel modules detected"
fi

echo ""
echo "  kABI Whitelist Package:"
rpm -q kernel-abi-stablelists 2>/dev/null || rpm -q kernel-abi-whitelists 2>/dev/null || \
    echo "  kernel-abi-stablelists: not installed"

echo ""
echo "  kmod Packages (third-party driver modules):"
rpm -qa 'kmod-*' 2>/dev/null | sort | sed 's/^/  /' || echo "  None installed"

# -- Section 4: Third-Party Repo Conflict Detection ------------------------
section "SECTION 4 - Third-Party Repo Conflict Detection"

echo "  Checking for potential repo conflicts..."
echo ""

PRIORITY_REPOS=$(grep -l 'priority=' /etc/yum.repos.d/*.repo 2>/dev/null)
[[ -n "$PRIORITY_REPOS" ]] && {
    echo "  Repos with priority set (conflict management active):"
    for f in $PRIORITY_REPOS; do
        echo "    $(basename $f): $(grep 'priority=' $f)"
    done
} || echo "  No priority settings found in repo files"

echo ""
echo "  DNF Extras (packages installed but not in any enabled repo):"
dnf list extras 2>/dev/null | tail -n +3 | wc -l | \
    xargs -I{} echo "  {} package(s) installed outside enabled repos"
dnf list extras 2>/dev/null | tail -n +3 | head -10 | sed 's/^/  /'

# -- Section 5: ABI and Binary Compatibility Summary -----------------------
section "SECTION 5 - ABI and Binary Compatibility Summary"

echo "  Compatibility Model for ${NAME:-this distro}:"
case "${ID:-unknown}" in
    rocky)
        echo "  Type    : Binary Clone — 1:1 with RHEL ${VERSION_ID:-unknown}"
        echo "  Policy  : Bug-for-bug compatibility with RHEL"
        echo "  Source  : UBI containers, cloud RHEL instances, srpmproc tooling"
        echo "  Build   : Peridot (open-source, RESF)"
        ;;
    almalinux)
        echo "  Type    : ABI Compatible — applications run without recompilation"
        echo "  Policy  : May include fixes ahead of RHEL release cycle"
        echo "  Source  : UBI containers, cloud RHEL instances, CentOS Stream signals"
        echo "  Build   : ALBS (AlmaLinux Build System)"
        ;;
    *)
        warn "Unknown distro ${ID:-unknown} — cannot determine compatibility model"
        ;;
esac

echo ""
echo "  RHEL Compatibility Indicators:"
rpm -q redhat-release 2>/dev/null && warn "redhat-release installed (unusual on Rocky/Alma)" || \
    pass "redhat-release absent (expected)"

rpm -q rocky-release 2>/dev/null   && pass "rocky-release present" || true
rpm -q almalinux-release 2>/dev/null && pass "almalinux-release present" || true

echo ""
echo "  RHEL Application Compatibility:"
echo "  ISV software certified for RHEL ${VERSION_ID%%.*} should run on this system."
case "${ID:-unknown}" in
    rocky) echo "  For strict binary cert validation, use Rocky's bug-for-bug policy." ;;
    almalinux) echo "  AlmaLinux ABI: application interfaces preserved; some bugs may be fixed." ;;
esac

echo ""
echo "$SEP"
echo "  Compatibility audit complete"
echo "$SEP"
