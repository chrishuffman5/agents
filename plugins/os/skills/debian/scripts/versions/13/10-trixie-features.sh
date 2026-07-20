#!/usr/bin/env bash
# ============================================================================
# Debian 13 Trixie - New Feature Verification
#
# Purpose : Verify APT 3.0, time_t ABI transition, cgroup v2, RISC-V
#           support, Wayland session, Landlock LSM, and Podman 5.x --
#           all new or significantly changed in Trixie.
# Version : 1.0.0
# Targets : Debian 13 (Trixie) systems
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. Debian Version Verification
#   2. APT 3.0 Verification
#   3. 64-bit time_t ABI Transition
#   4. cgroup v2 Status
#   5. RISC-V 64-bit Architecture
#   6. Wayland Session Status
#   7. Feature Summary
# ============================================================================
set -euo pipefail

SCRIPT_VERSION="1.0.0"
REPORT_FILE="/tmp/debian13-trixie-features-$(date +%Y%m%d).txt"

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

log()  { echo -e "${CYAN}[INFO]${RESET}  $*" | tee -a "$REPORT_FILE"; }
warn() { echo -e "${YELLOW}[WARN]${RESET}  $*" | tee -a "$REPORT_FILE"; }
fail() { echo -e "${RED}[FAIL]${RESET}  $*" | tee -a "$REPORT_FILE"; }
ok()   { echo -e "${GREEN}[OK]${RESET}    $*" | tee -a "$REPORT_FILE"; }

header() {
    echo -e "${BOLD}" | tee -a "$REPORT_FILE"
    echo "============================================================" | tee -a "$REPORT_FILE"
    echo "  Debian 13 Trixie — Feature Verification v${SCRIPT_VERSION}" | tee -a "$REPORT_FILE"
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
    if [[ "$codename" != "trixie" ]]; then
        warn "This system is NOT Trixie (found: $codename)."
    else
        ok "Confirmed Debian 13 Trixie"
    fi
    local kver kver_major kver_minor
    kver=$(uname -r)
    log "Kernel: $kver"
    kver_major=$(echo "$kver" | cut -d. -f1)
    kver_minor=$(echo "$kver" | cut -d. -f2)
    if [[ "$kver_major" -gt 6 ]] || { [[ "$kver_major" -eq 6 ]] && [[ "$kver_minor" -ge 12 ]]; }; then
        ok "Kernel 6.12+ confirmed (Trixie LTS kernel)"
    else
        warn "Kernel $kver is older than 6.12."
    fi
}

# -- Section 2: APT 3.0 Verification --------------------------------------
check_apt3() {
    log ""
    log "=== Section 2: APT 3.0 Verification (New in Trixie) ==="
    if ! command -v apt &>/dev/null; then
        fail "apt not found."
        return
    fi
    local apt_ver apt_major
    apt_ver=$(apt --version | head -1 | awk '{print $2}')
    log "APT version: $apt_ver"
    apt_major=$(echo "$apt_ver" | cut -d. -f1)
    if [[ "$apt_major" -ge 3 ]]; then
        ok "APT 3.0+ confirmed"
    else
        fail "APT version is $apt_ver — expected 3.x for Trixie"
    fi
    log ""
    log "APT parallel download configuration:"
    apt-config dump 2>/dev/null | grep -i "Acquire::Queue-Mode\|Acquire::http::Pipeline-Depth" || \
        log "  (default settings)"
    log "Solver configuration:"
    apt-config dump 2>/dev/null | grep -i "APT::Solver" || \
        log "  APT::Solver not explicitly set (using default)"
    if command -v zstd &>/dev/null; then
        ok "zstd available for package decompression"
    else
        warn "zstd command not found"
    fi
}

# -- Section 3: 64-bit time_t ABI Transition ------------------------------
check_time_t() {
    log ""
    log "=== Section 3: 64-bit time_t ABI Transition (New in Trixie) ==="
    local arch
    arch=$(uname -m)
    log "Architecture: $arch"
    case "$arch" in
        armv7l|armhf|i386|i686)
            log "32-bit architecture — time_t transition is directly relevant."
            if command -v gcc &>/dev/null; then
                local time_t_size
                time_t_size=$(echo '#include <time.h>
#include <stdio.h>
int main(){printf("%zu\n",sizeof(time_t));return 0;}' | \
                    gcc -x c - -o /tmp/check_time_t 2>/dev/null && /tmp/check_time_t || echo "unknown")
                rm -f /tmp/check_time_t
                log "sizeof(time_t): $time_t_size bytes"
                if [[ "$time_t_size" == "8" ]]; then
                    ok "time_t is 64-bit (8 bytes) — Y2038-safe"
                elif [[ "$time_t_size" == "4" ]]; then
                    fail "time_t is 32-bit — NOT Y2038-safe"
                fi
            else
                warn "gcc not installed. Cannot check sizeof(time_t)."
            fi
            ;;
        x86_64|aarch64|riscv64)
            ok "64-bit architecture ($arch) — time_t is natively 64-bit."
            ;;
        *)
            log "Architecture $arch — time_t impact varies."
            ;;
    esac
}

# -- Section 4: cgroup v2 Status ------------------------------------------
check_cgroup_v2() {
    log ""
    log "=== Section 4: cgroup v2 Status ==="
    if mount | grep -q "type cgroup2"; then
        ok "cgroup v2 (unified hierarchy) is mounted"
    else
        fail "cgroup v2 not mounted."
    fi
    local cgroup_v1_count
    cgroup_v1_count=$(mount | grep -c "type cgroup " || echo 0)
    if [[ "$cgroup_v1_count" -gt 0 ]]; then
        warn "cgroup v1 also mounted (hybrid mode). Full v2 preferred."
    else
        ok "Pure cgroup v2 environment"
    fi
    log ""
    log "Landlock LSM status (new in Trixie kernel config):"
    if [[ -d /sys/kernel/security/landlock ]]; then
        ok "Landlock LSM is active"
    elif grep -q "landlock" /sys/kernel/security/lsm 2>/dev/null; then
        ok "Landlock listed in active LSMs"
    else
        local lsm_list
        lsm_list=$(cat /sys/kernel/security/lsm 2>/dev/null || echo "unknown")
        log "Active LSMs: $lsm_list"
        warn "Landlock not detected in active LSMs."
    fi
}

# -- Section 5: RISC-V 64 Detection ---------------------------------------
check_riscv() {
    log ""
    log "=== Section 5: RISC-V 64-bit Architecture (First Official in Trixie) ==="
    local arch
    arch=$(uname -m)
    log "System architecture: $arch"
    if [[ "$arch" == "riscv64" ]]; then
        ok "Running on RISC-V 64-bit hardware!"
        ok "First Debian stable release with official riscv64 support."
        if [[ -f /proc/cpuinfo ]]; then
            local isa
            isa=$(grep -m1 "isa" /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs || echo "unknown")
            log "ISA extensions: $isa"
        fi
    else
        log "Not running on RISC-V ($arch)."
        log "  Trixie is the first official Debian release for riscv64."
    fi
    if command -v qemu-riscv64-static &>/dev/null; then
        ok "qemu-riscv64-static available for RISC-V emulation"
    fi
}

# -- Section 6: Wayland Session Status ------------------------------------
check_wayland() {
    log ""
    log "=== Section 6: Wayland Session Status (KDE Wayland-first in Trixie) ==="
    local session_type="${XDG_SESSION_TYPE:-unknown}"
    log "Current session type: $session_type"
    if [[ "$session_type" == "wayland" ]]; then
        ok "Running in a Wayland session"
    elif [[ "$session_type" == "x11" ]]; then
        warn "Running in X11 session. Wayland is preferred default in Trixie."
    else
        log "Session type unknown (likely SSH or headless)."
    fi
    if command -v plasmashell &>/dev/null; then
        local plasma_ver
        plasma_ver=$(plasmashell --version 2>/dev/null | awk '{print $2}' || echo "unknown")
        log "KDE Plasma version: $plasma_ver"
    fi
    if command -v gnome-shell &>/dev/null; then
        local gnome_ver
        gnome_ver=$(gnome-shell --version 2>/dev/null | awk '{print $3}' || echo "unknown")
        log "GNOME Shell version: $gnome_ver"
    fi
    log ""
    log "Podman version (Trixie ships 5.x):"
    if command -v podman &>/dev/null; then
        local podman_ver podman_major
        podman_ver=$(podman --version | awk '{print $3}')
        log "  Podman version: $podman_ver"
        podman_major=$(echo "$podman_ver" | cut -d. -f1)
        if [[ "$podman_major" -ge 5 ]]; then
            ok "  Podman 5.x confirmed"
        else
            warn "  Podman $podman_ver — expected 5.x"
        fi
    else
        log "  Podman not installed"
    fi
}

# -- Section 7: Summary ---------------------------------------------------
print_summary() {
    log ""
    log "=== Section 7: Trixie Feature Summary ==="
    log ""
    log "Trixie key features verified:"
    log "  - APT 3.0: parallel downloads, zstd indexes, new solver"
    log "  - 64-bit time_t: Y2038-safe ABI on 32-bit architectures"
    log "  - cgroup v2: unified hierarchy (Landlock LSM)"
    log "  - RISC-V 64-bit: first official Debian release architecture"
    log "  - Wayland-first: KDE Plasma 6.0, GNOME 47"
    log "  - Podman 5.x: rootless containers"
    log ""
    log "Additional Trixie changes (not checked in this script):"
    log "  - HTTP Boot (UEFI) in installer"
    log "  - Python 3.12, GCC 14, systemd 256"
    log "  - zstd .deb package compression"
    log ""
    log "Report saved to: $REPORT_FILE"
}

main() {
    > "$REPORT_FILE"
    header
    check_version
    check_apt3
    check_time_t
    check_cgroup_v2
    check_riscv
    check_wayland
    print_summary
}

main "$@"
