#!/usr/bin/env bash
# ============================================================================
# Debian 12 Bookworm - Non-Free Firmware Audit
#
# Purpose : Audit non-free-firmware repo status, installed firmware packages,
#           missing firmware warnings, Secure Boot state, and OpenSSL 3.0
#           status -- all new or changed in Bookworm.
# Version : 1.0.0
# Targets : Debian 12 (Bookworm) systems
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. Debian Version Verification
#   2. non-free-firmware Repository (New in Bookworm)
#   3. Installed Firmware Packages
#   4. Missing Firmware Warnings
#   5. Secure Boot Status
#   6. OpenSSL 3.0 Status
#   7. Firmware Audit Summary
# ============================================================================
set -euo pipefail

SCRIPT_VERSION="1.0.0"
REPORT_FILE="/tmp/debian12-firmware-audit-$(date +%Y%m%d).txt"

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

log()  { echo -e "${CYAN}[INFO]${RESET}  $*" | tee -a "$REPORT_FILE"; }
warn() { echo -e "${YELLOW}[WARN]${RESET}  $*" | tee -a "$REPORT_FILE"; }
fail() { echo -e "${RED}[FAIL]${RESET}  $*" | tee -a "$REPORT_FILE"; }
ok()   { echo -e "${GREEN}[OK]${RESET}    $*" | tee -a "$REPORT_FILE"; }

header() {
    echo -e "${BOLD}" | tee -a "$REPORT_FILE"
    echo "============================================================" | tee -a "$REPORT_FILE"
    echo "  Debian 12 Bookworm — Firmware Audit Report v${SCRIPT_VERSION}" | tee -a "$REPORT_FILE"
    echo "  Generated: $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$REPORT_FILE"
    echo "  Host:      $(hostname -f 2>/dev/null || hostname)" | tee -a "$REPORT_FILE"
    echo "============================================================" | tee -a "$REPORT_FILE"
    echo -e "${RESET}" | tee -a "$REPORT_FILE"
}

# -- Section 1: Version Verification --------------------------------------
check_version() {
    log "=== Section 1: Debian Version Verification ==="
    local codename
    codename=$(grep VERSION_CODENAME /etc/os-release 2>/dev/null | cut -d= -f2 || echo "unknown")
    log "Codename: $codename"
    if [[ "$codename" != "bookworm" ]]; then
        warn "This system is NOT Bookworm (found: $codename)."
    else
        ok "Confirmed Debian 12 Bookworm"
    fi
}

# -- Section 2: non-free-firmware Repository -------------------------------
check_nonfree_firmware_repo() {
    log ""
    log "=== Section 2: non-free-firmware Repository (New in Bookworm) ==="
    local firmware_repo_count nonfree_count
    firmware_repo_count=$(grep -rci "non-free-firmware" /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null | \
        awk -F: '{sum+=$2} END{print sum+0}')
    log "non-free-firmware component references: $firmware_repo_count"
    if [[ "$firmware_repo_count" -gt 0 ]]; then
        ok "non-free-firmware component is enabled."
    else
        warn "non-free-firmware component NOT found in apt sources."
        warn "  Some hardware may lack firmware updates."
        warn "  To enable: add 'non-free-firmware' to sources.list components."
    fi
    nonfree_count=$(grep -rci " non-free" /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null | \
        awk -F: '{sum+=$2} END{print sum+0}')
    if [[ "$nonfree_count" -gt 0 ]]; then
        log "Legacy non-free component also present."
    fi
    if ls /etc/apt/sources.list.d/*.sources &>/dev/null 2>&1; then
        log "Found .sources files (deb822 format):"
        for f in /etc/apt/sources.list.d/*.sources; do
            log "  $f"
        done
    fi
}

# -- Section 3: Installed Firmware Packages --------------------------------
check_installed_firmware() {
    log ""
    log "=== Section 3: Installed Firmware Packages ==="
    local fw_packages
    fw_packages=$(dpkg-query -W -f='${Package}\t${Status}\n' 'firmware-*' 2>/dev/null | \
        grep "install ok installed" | awk '{print $1}' || true)
    if [[ -z "$fw_packages" ]]; then
        log "No firmware-* packages installed."
    else
        ok "Installed firmware packages:"
        echo "$fw_packages" | while IFS= read -r pkg; do
            local ver
            ver=$(dpkg-query -W -f='${Version}' "$pkg" 2>/dev/null || echo "unknown")
            ok "  $pkg ($ver)"
        done
    fi
    log ""
    log "Common firmware package status:"
    for pkg in firmware-linux firmware-linux-nonfree firmware-amd-graphics \
               firmware-iwlwifi firmware-realtek firmware-brcm80211; do
        if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed"; then
            ok "  INSTALLED: $pkg"
        else
            log "  not installed: $pkg"
        fi
    done
}

# -- Section 4: Missing Firmware Warnings ----------------------------------
check_missing_firmware() {
    log ""
    log "=== Section 4: Missing Firmware Warnings ==="
    if command -v dmesg &>/dev/null; then
        local fw_errors
        fw_errors=$(dmesg 2>/dev/null | grep -i "firmware.*failed\|failed to load firmware\|direct firmware load" || true)
        if [[ -n "$fw_errors" ]]; then
            fail "Firmware load failures detected in dmesg:"
            echo "$fw_errors" | while IFS= read -r line; do fail "  $line"; done
            warn "  Enable non-free-firmware repo and install matching firmware package."
        else
            ok "No firmware load failures in dmesg."
        fi
    fi
}

# -- Section 5: Secure Boot Status ----------------------------------------
check_secure_boot() {
    log ""
    log "=== Section 5: Secure Boot Status ==="
    local arch
    arch=$(uname -m)
    log "Architecture: $arch"
    if [[ "$arch" == "aarch64" ]]; then
        log "ARM64 system — Secure Boot support added in Bookworm for this arch."
    fi
    if command -v mokutil &>/dev/null; then
        local sb_state
        sb_state=$(mokutil --sb-state 2>/dev/null || echo "unknown")
        log "Secure Boot state: $sb_state"
        if echo "$sb_state" | grep -qi "enabled"; then
            ok "Secure Boot is ENABLED"
        elif echo "$sb_state" | grep -qi "disabled"; then
            warn "Secure Boot is DISABLED"
        fi
    else
        warn "mokutil not installed. Install with: apt install mokutil"
    fi
    if dpkg -l shim-signed &>/dev/null 2>&1; then
        ok "shim-signed installed: $(dpkg-query -W -f='${Version}' shim-signed 2>/dev/null)"
    else
        log "shim-signed not installed (required for Secure Boot with GRUB)"
    fi
}

# -- Section 6: OpenSSL 3.0 Status ----------------------------------------
check_openssl() {
    log ""
    log "=== Section 6: OpenSSL 3.0 Status (Bookworm Change) ==="
    if command -v openssl &>/dev/null; then
        local ssl_ver
        ssl_ver=$(openssl version)
        log "OpenSSL: $ssl_ver"
        if echo "$ssl_ver" | grep -q "^OpenSSL 3"; then
            ok "OpenSSL 3.x confirmed"
        else
            fail "Unexpected OpenSSL version: $ssl_ver"
        fi
    fi
    if ldconfig -p 2>/dev/null | grep -q "libssl.so.1.1"; then
        warn "libssl1.1 still present. Some packages may use deprecated ABI."
    else
        ok "libssl1.1 not found — clean OpenSSL 3.0 environment."
    fi
}

# -- Section 7: Summary ---------------------------------------------------
print_summary() {
    log ""
    log "=== Section 7: Firmware Audit Summary ==="
    log ""
    log "Key Bookworm firmware changes:"
    log "  - non-free-firmware is a NEW separate repo component"
    log "  - Official ISOs now bundle non-free firmware"
    log "  - ARM64 Secure Boot signing added"
    log ""
    log "Action items if firmware issues found:"
    log "  1. Add non-free-firmware to sources.list"
    log "  2. Run: apt update && apt install firmware-linux firmware-linux-nonfree"
    log "  3. For Wi-Fi: apt install firmware-iwlwifi or firmware-realtek"
    log "  4. For GPU: apt install firmware-amd-graphics or firmware-misc-nonfree"
    log "  5. Reboot after firmware install to reload kernel modules"
    log ""
    log "Report saved to: $REPORT_FILE"
}

main() {
    > "$REPORT_FILE"
    header
    check_version
    check_nonfree_firmware_repo
    check_installed_firmware
    check_missing_firmware
    check_secure_boot
    check_openssl
    print_summary
}

main "$@"
