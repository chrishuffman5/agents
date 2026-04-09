#!/usr/bin/env bash
# ============================================================================
# Ubuntu - Livepatch Status
#
# Purpose : Canonical Livepatch service assessment including kernel version,
#           Pro subscription status, applied patches, and HWE kernel stack.
# Version : 1.0.0
# Targets : Ubuntu 20.04+
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. Kernel Version
#   2. Ubuntu Pro Subscription
#   3. Livepatch Service Status
#   4. Applied Livepatch Details
#   5. HWE Kernel Stack
# ============================================================================
set -euo pipefail

SEP="$(printf '=%.0s' {1..70})"

section() { echo ""; echo "$SEP"; echo "  $1"; echo "$SEP"; }

# -- Section 1: Kernel Version ---------------------------------------------
section "SECTION 1 - Kernel Version"
echo "  Running kernel  : $(uname -r)"
echo "  Architecture    : $(uname -m)"
echo ""
echo "  All installed kernels:"
dpkg -l 'linux-image-*' 2>/dev/null | awk '/^ii/{print "  "$2, $3}' \
    || echo "  Unable to list kernels"
echo ""
echo "  Reboot required:"
if [[ -f /var/run/reboot-required ]]; then
    echo "  [WARN] YES -- kernel or other package requires reboot"
    cat /var/run/reboot-required.pkgs 2>/dev/null | sed 's/^/    /' || true
else
    echo "  [OK]   No reboot required"
fi

# -- Section 2: Ubuntu Pro Status -------------------------------------------
section "SECTION 2 - Ubuntu Pro Subscription"
if command -v pro &>/dev/null; then
    pro status 2>/dev/null | grep -E 'livepatch|esm|subscription|Account|Contract|Machine' \
        | sed 's/^/  /' || echo "  Run: pro status"
else
    echo "  [WARN] ubuntu-advantage-tools not installed"
    echo "  Livepatch requires Ubuntu Pro -- install: apt install ubuntu-advantage-tools"
fi

# -- Section 3: Livepatch Service -------------------------------------------
section "SECTION 3 - Livepatch Service Status"
if command -v canonical-livepatch &>/dev/null; then
    echo "  Livepatch status:"
    canonical-livepatch status 2>/dev/null | sed 's/^/  /' \
        || echo "  Unable to query -- is Livepatch enabled?"
    echo ""
    echo "  Livepatch daemon:"
    systemctl status snap.canonical-livepatch.canonical-livepatchd.service \
        2>/dev/null | head -10 | sed 's/^/  /' \
        || echo "  Livepatch daemon service not found"
else
    echo "  [INFO] canonical-livepatch not installed"
    echo "  Enable with: pro enable livepatch"
fi

# -- Section 4: Applied Patches ---------------------------------------------
section "SECTION 4 - Applied Livepatch Details"
if command -v canonical-livepatch &>/dev/null; then
    echo "  Detailed patch status:"
    canonical-livepatch status --verbose 2>/dev/null | sed 's/^/  /' \
        || echo "  Unable to query verbose status"
else
    echo "  [INFO] No Livepatch data available (not installed)"
fi

# -- Section 5: HWE Kernel Stack -------------------------------------------
section "SECTION 5 - HWE Kernel Stack"
echo "  HWE kernel packages:"
dpkg -l linux-generic-hwe-* linux-image-generic-hwe-* 2>/dev/null \
    | awk '/^ii/{print "  [installed] "$2, $3}' || echo "  No HWE kernel installed (using GA kernel)"

echo ""
echo "  Current kernel vs HWE availability:"
apt-cache policy linux-generic-hwe-$(lsb_release -sr 2>/dev/null || echo "22.04") \
    2>/dev/null | head -5 | sed 's/^/  /' || echo "  Cannot determine HWE availability"

echo ""
echo "$SEP"
echo "  Livepatch Status Check Complete - $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "$SEP"
