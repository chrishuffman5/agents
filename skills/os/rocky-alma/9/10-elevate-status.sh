#!/usr/bin/env bash
# ============================================================================
# Rocky/AlmaLinux v9 - ELevate Status and Upgrade Path Assessment
#
# Purpose : Check ELevate tooling availability on EL9, assess upgrade path
#           readiness to v10, and run pre-upgrade assessment if leapp is
#           installed.
# Version : 1.0.0
# Targets : Rocky Linux 9 / AlmaLinux 9
# Safety  : Read-only (leapp preupgrade is read-only assessment).
#
# Sections:
#   1. Distro Identification
#   2. ELevate Repo Availability
#   3. leapp Package Status
#   4. EL10 Upgrade Data Check
#   5. leapp Pre-Upgrade Assessment
#   6. Disk Space Check
# ============================================================================
set -euo pipefail

PASS=0
WARN=0
INFO_COUNT=0

pass()  { echo "[PASS] $*"; ((PASS++)); }
warn()  { echo "[WARN] $*"; ((WARN++)); }
info()  { echo "[INFO] $*"; ((INFO_COUNT++)); }
fail()  { echo "[FAIL] $*"; }

echo "=== ELevate / Upgrade Path Status Check ==="
echo "Date: $(date)"
echo ""

# --- Distro identification ---
info "Distro identification"
if [ -f /etc/almalinux-release ]; then
    cat /etc/almalinux-release
    DISTRO="almalinux"
elif [ -f /etc/rocky-release ]; then
    cat /etc/rocky-release
    DISTRO="rocky"
else
    fail "Cannot identify distro as AlmaLinux or Rocky Linux"
    exit 1
fi

MAJOR_VER=$(rpm -E '%{rhel}')
info "RHEL compatibility level: $MAJOR_VER"

if [ "$MAJOR_VER" != "9" ]; then
    fail "This script is for EL9 systems only. Detected: EL$MAJOR_VER"
    exit 1
fi

# --- ELevate repo availability ---
echo ""
info "Checking ELevate repo availability..."
if dnf repolist all 2>/dev/null | grep -q "elevate"; then
    pass "ELevate repo is configured"
else
    warn "ELevate repo not found"
    if [ "$DISTRO" = "almalinux" ]; then
        info "To add ELevate repo for AlmaLinux 9:"
        info "  curl -O https://repo.almalinux.org/elevate/elevate-release-latest-el9.noarch.rpm"
        info "  rpm -ivh elevate-release-latest-el9.noarch.rpm"
    elif [ "$DISTRO" = "rocky" ]; then
        warn "Rocky Linux does not officially support in-place major version upgrades"
        info "Recommended: Deploy fresh Rocky 10 and migrate workloads"
    fi
fi

# --- leapp availability ---
echo ""
info "Checking leapp-upgrade package availability..."
if rpm -q leapp-upgrade &>/dev/null; then
    LEAPP_VER=$(rpm -q leapp-upgrade --qf '%{VERSION}')
    pass "leapp-upgrade installed: $LEAPP_VER"
    LEAPP_INSTALLED=true
else
    warn "leapp-upgrade not installed"
    LEAPP_INSTALLED=false
    if [ "$DISTRO" = "almalinux" ]; then
        info "Install with: dnf install -y leapp-upgrade leapp-data-almalinux"
    fi
fi

# --- EL10 upgrade data ---
echo ""
info "Checking for EL10 upgrade data..."
if [ "$DISTRO" = "almalinux" ]; then
    if rpm -q leapp-data-almalinux &>/dev/null; then
        DATA_VER=$(rpm -q leapp-data-almalinux --qf '%{VERSION}')
        pass "leapp-data-almalinux installed: $DATA_VER"
        if ls /etc/leapp/files/ 2>/dev/null | grep -q "10\|alma10"; then
            pass "EL10 leapp data files found — 9->10 upgrade path may be available"
        else
            warn "No EL10 leapp data files found in /etc/leapp/files/"
            warn "ELevate 9->10 support may not yet be available"
            info "Monitor: https://wiki.almalinux.org/elevate/"
        fi
    else
        warn "leapp-data-almalinux not installed"
    fi
fi

# --- leapp preupgrade ---
echo ""
if [ "$LEAPP_INSTALLED" = "true" ]; then
    info "leapp is installed — running preupgrade assessment (read-only)..."
    info "This may take several minutes..."
    echo ""
    if leapp preupgrade 2>&1; then
        pass "leapp preupgrade completed"
    else
        warn "leapp preupgrade reported issues — review /var/log/leapp/leapp-report.txt"
    fi
    echo ""
    info "Preupgrade report summary:"
    if [ -f /var/log/leapp/leapp-report.txt ]; then
        INHIBITORS=$(grep -c "^Risk Factor: inhibitor" /var/log/leapp/leapp-report.txt 2>/dev/null || echo 0)
        HIGH_RISK=$(grep -c "^Risk Factor: high" /var/log/leapp/leapp-report.txt 2>/dev/null || echo 0)
        echo "  Inhibitors (upgrade blockers): $INHIBITORS"
        echo "  High risk items: $HIGH_RISK"
        if [ "$INHIBITORS" -gt 0 ]; then
            warn "$INHIBITORS upgrade inhibitors found — must be resolved before upgrade"
            warn "Full report: /var/log/leapp/leapp-report.txt"
        else
            pass "No upgrade inhibitors found"
        fi
    else
        warn "/var/log/leapp/leapp-report.txt not found after preupgrade"
    fi
else
    info "leapp not installed — skipping preupgrade assessment"
fi

# --- Disk space ---
echo ""
info "Checking disk space for upgrade..."
VAR_FREE=$(df /var --output=avail -BG | tail -1 | tr -d 'G ')
ROOT_FREE=$(df / --output=avail -BG | tail -1 | tr -d 'G ')
info "/var free: ${VAR_FREE}G"
info "/ free: ${ROOT_FREE}G"
if [ "$VAR_FREE" -lt 2 ]; then
    warn "/var has less than 2GB free — leapp upgrade may fail"
else
    pass "/var has sufficient space (${VAR_FREE}G)"
fi
if [ "$ROOT_FREE" -lt 3 ]; then
    warn "/ has less than 3GB free — upgrade may fail"
else
    pass "/ has sufficient space (${ROOT_FREE}G)"
fi

# --- Summary ---
echo ""
echo "=== Summary ==="
echo "PASS: $PASS | WARN: $WARN"
if [ "$DISTRO" = "rocky" ]; then
    echo ""
    echo "NOTE: Rocky Linux does not provide an official in-place 9->10 upgrade."
    echo "Recommended: Deploy a fresh Rocky 10 instance and migrate workloads."
fi
