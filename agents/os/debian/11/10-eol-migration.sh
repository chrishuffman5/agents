#!/usr/bin/env bash
# ============================================================================
# Debian 11 Bullseye - EOL Migration Readiness
#
# Purpose : Assess upgrade readiness and surface blockers before dist-upgrade
#           from Bullseye to Bookworm or Trixie.
# Version : 1.0.0
# Targets : Debian 11 (Bullseye) systems approaching EOL June 2026
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. Debian Version Verification
#   2. EOL Timeline
#   3. APT Sources Configuration
#   4. Held Packages
#   5. Deprecated Features
#   6. Kernel and HWE Stack
#   7. Migration Recommendations
# ============================================================================
set -euo pipefail

SCRIPT_VERSION="1.0.0"
EOL_DATE="2026-06-01"
REPORT_FILE="/tmp/debian11-eol-report-$(date +%Y%m%d).txt"

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

log()  { echo -e "${CYAN}[INFO]${RESET}  $*" | tee -a "$REPORT_FILE"; }
warn() { echo -e "${YELLOW}[WARN]${RESET}  $*" | tee -a "$REPORT_FILE"; }
fail() { echo -e "${RED}[FAIL]${RESET}  $*" | tee -a "$REPORT_FILE"; }
ok()   { echo -e "${GREEN}[OK]${RESET}    $*" | tee -a "$REPORT_FILE"; }

header() {
    echo -e "${BOLD}" | tee -a "$REPORT_FILE"
    echo "============================================================" | tee -a "$REPORT_FILE"
    echo "  Debian 11 Bullseye — EOL Migration Report v${SCRIPT_VERSION}" | tee -a "$REPORT_FILE"
    echo "  Generated: $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$REPORT_FILE"
    echo "  Host:      $(hostname -f 2>/dev/null || hostname)" | tee -a "$REPORT_FILE"
    echo "============================================================" | tee -a "$REPORT_FILE"
    echo -e "${RESET}" | tee -a "$REPORT_FILE"
}

# -- Section 1: Debian Version Verification --------------------------------
check_version() {
    log "=== Section 1: Debian Version Verification ==="
    if [[ ! -f /etc/debian_version ]]; then
        fail "Not a Debian system. Exiting."
        exit 1
    fi
    local deb_ver codename
    deb_ver=$(cat /etc/debian_version)
    codename=$(grep VERSION_CODENAME /etc/os-release 2>/dev/null | cut -d= -f2 || echo "unknown")
    log "Debian version file: $deb_ver"
    log "Codename: $codename"
    if [[ "$codename" != "bullseye" ]]; then
        warn "This system is NOT Bullseye (found: $codename)."
    else
        ok "Confirmed Debian 11 Bullseye"
    fi
}

# -- Section 2: EOL Timeline ----------------------------------------------
check_eol_timeline() {
    log ""
    log "=== Section 2: EOL Timeline ==="
    local today eol_epoch today_epoch days_remaining
    today=$(date +%Y-%m-%d)
    log "Today:    $today"
    log "EOL Date: $EOL_DATE"
    eol_epoch=$(date -d "$EOL_DATE" +%s 2>/dev/null || echo 0)
    today_epoch=$(date +%s)
    if [[ "$eol_epoch" -gt 0 ]]; then
        days_remaining=$(( (eol_epoch - today_epoch) / 86400 ))
        if [[ "$days_remaining" -le 0 ]]; then
            fail "EOL PASSED. This system is unsupported. Upgrade immediately."
        elif [[ "$days_remaining" -le 90 ]]; then
            fail "CRITICAL: Only $days_remaining days until EOL. Begin upgrade now."
        elif [[ "$days_remaining" -le 180 ]]; then
            warn "WARNING: $days_remaining days until EOL. Plan upgrade within 60 days."
        else
            log "Days until EOL: $days_remaining"
        fi
    fi
}

# -- Section 3: APT Sources Configuration ---------------------------------
check_sources() {
    log ""
    log "=== Section 3: APT Sources Configuration ==="
    local bullseye_count next_count
    bullseye_count=$(grep -rci "bullseye" /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null | \
        awk -F: '{sum+=$2} END{print sum}')
    next_count=$(grep -rci "bookworm\|trixie" /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null | \
        awk -F: '{sum+=$2} END{print sum}')
    log "Bullseye references in sources: $bullseye_count"
    log "Bookworm/Trixie references in sources: $next_count"
    if [[ "$next_count" -gt 0 ]] && [[ "$bullseye_count" -gt 0 ]]; then
        warn "Mixed sources detected. Review before upgrade."
    elif [[ "$next_count" -gt 0 ]]; then
        ok "Sources already point to newer release."
    else
        warn "Sources still reference bullseye. Update before dist-upgrade."
    fi
}

# -- Section 4: Held Packages ---------------------------------------------
check_held_packages() {
    log ""
    log "=== Section 4: Held Packages ==="
    local held
    held=$(apt-mark showhold 2>/dev/null)
    if [[ -z "$held" ]]; then
        ok "No held packages found."
    else
        fail "Held packages detected — these will block dist-upgrade:"
        echo "$held" | while IFS= read -r pkg; do fail "  HELD: $pkg"; done
        warn "Use 'apt-mark unhold <pkg>' when safe."
    fi
}

# -- Section 5: Deprecated Features ---------------------------------------
check_deprecated_features() {
    log ""
    log "=== Section 5: Deprecated Features ==="
    if command -v openssl &>/dev/null; then
        local ssl_ver
        ssl_ver=$(openssl version | awk '{print $2}')
        log "OpenSSL version: $ssl_ver"
        if [[ "$ssl_ver" == 1.1* ]]; then
            warn "OpenSSL 1.1.1 detected. Bookworm uses 3.0 — test applications."
        fi
    fi
    if command -v python3 &>/dev/null; then
        local py_ver
        py_ver=$(python3 --version 2>&1 | awk '{print $2}')
        log "Python version: $py_ver"
        if [[ "$py_ver" == 3.9* ]]; then
            warn "Python 3.9 detected. Bookworm ships 3.11, Trixie ships 3.12."
        fi
    fi
    if command -v iptables &>/dev/null; then
        local ipt_mode
        ipt_mode=$(update-alternatives --query iptables 2>/dev/null | grep "^Value:" | awk '{print $2}')
        log "iptables backend: ${ipt_mode:-unknown}"
        if [[ "$ipt_mode" == *"legacy"* ]]; then
            warn "iptables-legacy in use. Bookworm defaults to nftables."
        fi
    fi
    if dpkg -l libssl1.1 &>/dev/null 2>&1; then
        local rdeps
        rdeps=$(apt-cache rdepends libssl1.1 2>/dev/null | grep -v "libssl1.1" | grep "^  " | wc -l)
        warn "libssl1.1 has $rdeps reverse dependencies. These may break on upgrade."
    fi
}

# -- Section 6: Kernel and HWE Stack --------------------------------------
check_kernel_hwe() {
    log ""
    log "=== Section 6: Kernel and HWE Stack ==="
    local kver kver_major kver_minor
    kver=$(uname -r)
    log "Running kernel: $kver"
    kver_major=$(echo "$kver" | cut -d. -f1)
    kver_minor=$(echo "$kver" | cut -d. -f2)
    if [[ "$kver_major" -lt 5 ]] || { [[ "$kver_major" -eq 5 ]] && [[ "$kver_minor" -lt 10 ]]; }; then
        fail "Kernel $kver is older than 5.10 LTS. Upgrade kernel before migrating."
    else
        ok "Kernel version acceptable for migration."
    fi
}

# -- Section 7: Migration Recommendations ---------------------------------
print_summary() {
    log ""
    log "=== Section 7: Migration Recommendations ==="
    log ""
    log "Recommended upgrade path: Bullseye -> Bookworm -> Trixie (step-by-step)"
    log ""
    log "Pre-upgrade checklist:"
    log "  1. Update sources.list to bookworm"
    log "  2. Run: apt update && apt full-upgrade"
    log "  3. Resolve all held packages"
    log "  4. Test OpenSSL 3.0 compatibility for custom apps"
    log "  5. Migrate iptables-legacy rules to nftables syntax"
    log "  6. Audit Python virtualenvs for 3.9->3.11 compatibility"
    log "  7. Review AppArmor profiles post-upgrade"
    log ""
    log "Report saved to: $REPORT_FILE"
}

main() {
    > "$REPORT_FILE"
    header
    check_version
    check_eol_timeline
    check_sources
    check_held_packages
    check_deprecated_features
    check_kernel_hwe
    print_summary
}

main "$@"
