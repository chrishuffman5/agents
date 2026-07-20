#!/usr/bin/env bash
# ============================================================================
# Ubuntu 20.04 - EOL Readiness Assessment
#
# Purpose : Assess ESM status, Pro enrollment, upgrade readiness, ZFS/zsys
#           status, and migration blockers for Ubuntu 20.04 (past standard EOL).
# Version : 20.1.0
# Targets : Ubuntu 20.04 LTS (Focal Fossa)
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. OS Version Check
#   2. Ubuntu Pro / ESM Status
#   3. Kernel Version & HWE Status
#   4. Package Holds
#   5. PPA Compatibility
#   6. Upgrade Readiness
#   7. ZFS / zsys Status
# ============================================================================
set -euo pipefail

SEP="$(printf '=%.0s' {1..70})"

section() { echo ""; echo "$SEP"; echo "  $1"; echo "$SEP"; }

section "SECTION 1 - OS Version Check"
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    echo "  OS: ${PRETTY_NAME:-unknown}"
    echo "  Version ID: ${VERSION_ID:-unknown}"
    if [[ "${VERSION_ID:-}" != "20.04" ]]; then
        echo "  [WARN] This script targets Ubuntu 20.04, detected ${VERSION_ID}"
    else
        echo "  [OK]   Running on target version 20.04"
    fi
fi

section "SECTION 2 - Ubuntu Pro / ESM Status"
if command -v pro &>/dev/null; then
    PRO_STATUS=$(pro status 2>/dev/null || echo "error")
    if echo "${PRO_STATUS}" | grep -q "attached: yes" 2>/dev/null; then
        echo "  [OK]   System is attached to Ubuntu Pro"
        if echo "${PRO_STATUS}" | grep -q "esm-infra.*enabled"; then
            echo "  [OK]   ESM Infrastructure enabled"
        else
            echo "  [WARN] ESM Infrastructure not enabled -- run: pro enable esm-infra"
        fi
        if echo "${PRO_STATUS}" | grep -q "esm-apps.*enabled"; then
            echo "  [OK]   ESM Apps enabled"
        else
            echo "  [WARN] ESM Apps not enabled -- run: pro enable esm-apps"
        fi
    else
        echo "  [CRIT] System is NOT attached to Ubuntu Pro"
        echo "         Ubuntu 20.04 standard support ended April 2025"
        echo "         No security updates without ESM enrollment"
        echo "  Action: Visit https://ubuntu.com/pro for a token"
        echo "  Action: Run: pro attach <token>"
    fi
    pro status --format json 2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
acct = data.get('account', {})
if acct:
    print(f'  Account: {acct.get(\"name\", \"unknown\")}')
" 2>/dev/null || true
else
    echo "  [CRIT] ubuntu-advantage-tools (pro) not installed"
    echo "  Install: apt install ubuntu-advantage-tools"
fi

section "SECTION 3 - Kernel Version & HWE Status"
CURRENT_KERNEL=$(uname -r)
echo "  Running kernel: ${CURRENT_KERNEL}"
if echo "${CURRENT_KERNEL}" | grep -q "^5\.15\|generic-hwe"; then
    echo "  [OK]   Using HWE kernel (Hardware Enablement Stack)"
elif echo "${CURRENT_KERNEL}" | grep -q "^5\.4"; then
    echo "  [INFO] Using GA kernel 5.4"
    echo "  Consider HWE for newer hardware: apt install linux-generic-hwe-20.04"
fi

AVAILABLE=$(apt-cache policy linux-image-generic 2>/dev/null | grep Candidate | awk '{print $2}')
INSTALLED=$(apt-cache policy linux-image-generic 2>/dev/null | grep Installed | awk '{print $2}')
if [[ "${AVAILABLE}" != "${INSTALLED}" ]] && [[ -n "${AVAILABLE}" ]]; then
    echo "  [WARN] Kernel update available: ${AVAILABLE} (installed: ${INSTALLED})"
else
    echo "  [OK]   Kernel packages up to date"
fi

section "SECTION 4 - Package Holds (Potential Upgrade Blockers)"
HELD=$(apt-mark showhold 2>/dev/null)
if [[ -z "${HELD}" ]]; then
    echo "  [OK]   No packages on hold"
else
    echo "  [WARN] Held packages may block upgrade:"
    echo "${HELD}" | sed 's/^/    - /'
    echo "  To release: apt-mark unhold <package>"
fi

section "SECTION 5 - PPA Compatibility"
PPA_LIST=$(find /etc/apt/sources.list.d/ -name "*.list" -o -name "*.sources" 2>/dev/null | head -20)
if [[ -z "${PPA_LIST}" ]]; then
    echo "  [OK]   No additional PPAs found"
else
    echo "  [INFO] PPAs found -- verify compatibility before upgrading:"
    echo "${PPA_LIST}" | while read -r ppa_file; do
        echo "    - ${ppa_file}"
        grep -v "^#" "${ppa_file}" 2>/dev/null | grep -v "^$" | head -2 | sed 's/^/      /'
    done
    echo "  PPAs may not have 22.04 packages and can block do-release-upgrade"
fi

section "SECTION 6 - Upgrade Readiness Check"
if ! dpkg -l update-manager-core &>/dev/null; then
    echo "  [WARN] update-manager-core not installed"
    echo "  Install: apt install update-manager-core"
fi

ROOT_FREE=$(df -BG / | tail -1 | awk '{print $4}' | tr -d 'G')
echo "  Free disk space on /: ${ROOT_FREE}GB"
if [[ "${ROOT_FREE:-0}" -lt 5 ]]; then
    echo "  [CRIT] Insufficient disk space for upgrade (need 5GB+)"
else
    echo "  [OK]   Sufficient disk space for upgrade"
fi

echo ""
echo "  Recommended upgrade path:"
echo "    1. Enroll in Ubuntu Pro: pro attach <token>"
echo "    2. Enable ESM: pro enable esm-infra && pro enable esm-apps"
echo "    3. Upgrade to 22.04: do-release-upgrade"
echo "    4. Then optionally upgrade to 24.04: do-release-upgrade"

section "SECTION 7 - ZFS / zsys Status (20.04 Feature)"
if df -T / 2>/dev/null | grep -q zfs; then
    echo "  [INFO] System uses ZFS root filesystem"
    echo "  ZFS pool status:"
    zpool status 2>/dev/null | grep -E "(pool:|state:|status:)" | sed 's/^/    /'

    if command -v zsysctl &>/dev/null; then
        echo "  zsys states:"
        zsysctl state list 2>/dev/null | head -10 || echo "    Unable to list zsys states"
        echo "  [NOTE] zsys is deprecated. Not available on 22.04+"
    fi

    SNAP_COUNT=$(zfs list -t snapshot 2>/dev/null | wc -l)
    echo "  ZFS snapshots: ${SNAP_COUNT}"
else
    echo "  Root filesystem: $(df -T / | tail -1 | awk '{print $2}') (not ZFS)"
    echo "  [OK]   No ZFS-specific migration considerations"
fi

echo ""
echo "$SEP"
echo "  EOL Readiness Assessment Complete - $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "$SEP"
