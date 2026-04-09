#!/usr/bin/env bash
# ============================================================================
# Ubuntu - Package Audit (apt + snap)
#
# Purpose : Package inventory including upgradable, held, auto-removable,
#           residual config, PPAs, ESM counts, and snap packages.
# Version : 1.0.0
# Targets : Ubuntu 20.04+
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. APT Package Summary
#   2. Held Packages
#   3. Auto-removable Packages
#   4. Residual Config Packages
#   5. Package Sources / PPAs
#   6. ESM (Ubuntu Pro) Package Info
#   7. Snap Packages
# ============================================================================
set -euo pipefail

SEP="$(printf '=%.0s' {1..70})"

section() { echo ""; echo "$SEP"; echo "  $1"; echo "$SEP"; }

# -- Section 1: apt Package Summary ----------------------------------------
section "SECTION 1 - APT Package Summary"
echo "  Total installed packages:"
dpkg -l | grep -c '^ii' | sed 's/^/  Count: /'
echo ""
echo "  Upgradable packages:"
apt list --upgradable 2>/dev/null | grep -v '^Listing' | sed 's/^/  /' \
    | head -30 || echo "  None (or apt update needed)"

# -- Section 2: Held Packages ----------------------------------------------
section "SECTION 2 - Held Packages"
held=$(apt-mark showhold 2>/dev/null)
if [[ -n "$held" ]]; then
    echo "$held" | sed 's/^/  [HOLD] /'
else
    echo "  No packages on hold"
fi

# -- Section 3: Auto-removable Packages ------------------------------------
section "SECTION 3 - Auto-removable Packages"
echo "  Packages eligible for autoremove:"
apt list --auto-removable 2>/dev/null | grep -v '^Listing' | sed 's/^/  /' \
    | head -20 || echo "  None"

# -- Section 4: Residual Config Packages ------------------------------------
section "SECTION 4 - Residual Config Packages (rc state)"
rc_packages=$(dpkg -l | awk '/^rc/{print $2}')
if [[ -n "$rc_packages" ]]; then
    echo "  Packages removed but with config remaining:"
    echo "$rc_packages" | sed 's/^/  /'
    echo ""
    echo "  Remove with: dpkg -l | awk '/^rc/{print \$2}' | xargs apt purge -y"
else
    echo "  No residual config packages found"
fi

# -- Section 5: PPAs and Extra Sources --------------------------------------
section "SECTION 5 - Package Sources / PPAs"
echo "  Active sources:"
grep -r "^deb " /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null \
    | grep -v ':#' | sed 's/^/  /'

# Check deb822 format sources
if ls /etc/apt/sources.list.d/*.sources &>/dev/null 2>&1; then
    echo ""
    echo "  deb822 format sources:"
    for f in /etc/apt/sources.list.d/*.sources; do
        echo "    $f"
    done
fi

# -- Section 6: ESM Package Counts -----------------------------------------
section "SECTION 6 - ESM (Ubuntu Pro) Package Info"
if command -v pro &>/dev/null; then
    echo "  ESM-eligible packages from 'pro security-status':"
    pro security-status 2>/dev/null | head -30 | sed 's/^/  /' \
        || echo "  Run: pro security-status"
else
    echo "  [INFO] ubuntu-advantage-tools not installed"
fi

# -- Section 7: Snap Packages ----------------------------------------------
section "SECTION 7 - Snap Packages"
if command -v snap &>/dev/null; then
    echo "  Installed snaps:"
    snap list 2>/dev/null | sed 's/^/  /'
    echo ""
    echo "  Disabled (old) revisions consuming disk:"
    snap list --all 2>/dev/null | awk '/disabled/{print "  "$0}' \
        || echo "  None"
    echo ""
    echo "  Snap refresh schedule:"
    snap get system refresh.timer 2>/dev/null | sed 's/^/  /' \
        || echo "  (default schedule)"
else
    echo "  [INFO] snapd not installed"
fi

echo ""
echo "$SEP"
echo "  Package Audit Complete - $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "$SEP"
