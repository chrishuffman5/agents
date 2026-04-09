#!/usr/bin/env bash
# ============================================================================
# SLES 15 SP6 - Feature Validation and SP7 Migration Prep
#
# Purpose : Validate SP6-specific features and detect SP7 deprecated
#           packages. Checks OpenSSL 3, cgroup v2, LUKS2 capability,
#           SSH key strength, FRRouting status, NFS over TLS, and
#           deprecated package detection.
# Version : 1.0.0
# Targets : SLES 15 SP6
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. Version Verification
#   2. OpenSSL 3.x Validation
#   3. cgroup v2 Unified Hierarchy
#   4. LUKS2 Capability
#   5. SSH Key Strength
#   6. FRRouting / Quagga Status
#   7. NFS over TLS
#   8. zypper search-packages
#   9. SP7 Deprecation Check
#  10. Summary
# ============================================================================
set -euo pipefail

PASS=0
FAIL=0
WARN=0

log_pass() { echo "[PASS] $*"; ((PASS++)); }
log_fail() { echo "[FAIL] $*"; ((FAIL++)); }
log_warn() { echo "[WARN] $*"; ((WARN++)); }
log_info() { echo "[INFO] $*"; }

echo "======================================================================"
echo "  SLES 15 SP6 Feature Validation and SP7 Migration Prep"
echo "  $(date -u '+%Y-%m-%d %H:%M:%S UTC')  Host: $(hostname)"
echo "======================================================================"
echo ""

# ── Section 1: Version Verification ─────────────────────────────────────────
log_info "Checking SLES version..."
if grep -q "SLES" /etc/os-release 2>/dev/null; then
    VERSION_ID=$(grep ^VERSION_ID /etc/os-release | cut -d= -f2 | tr -d '"')
    if [[ "$VERSION_ID" == "15.6" ]]; then
        log_pass "Running SLES 15 SP6 (VERSION_ID=$VERSION_ID)"
    else
        log_warn "VERSION_ID=$VERSION_ID -- expected 15.6 for SP6"
    fi
else
    log_fail "Not a SLES system"
fi

KERNEL=$(uname -r)
log_info "Kernel: $KERNEL"
if echo "$KERNEL" | grep -qE "^6\.4"; then
    log_pass "SP6 kernel (6.4.x) confirmed"
else
    log_warn "Kernel $KERNEL -- SP6 base is 6.4"
fi

# ── Section 2: OpenSSL 3.x ──────────────────────────────────────────────────
echo ""
log_info "Checking OpenSSL version..."
if command -v openssl &>/dev/null; then
    OPENSSL_VER=$(openssl version | awk '{print $2}')
    log_info "OpenSSL version: $OPENSSL_VER"
    if echo "$OPENSSL_VER" | grep -qE "^3\."; then
        log_pass "OpenSSL 3.x installed ($OPENSSL_VER)"
    else
        log_fail "OpenSSL $OPENSSL_VER -- SP6 requires OpenSSL 3.x"
    fi

    log_info "Active OpenSSL providers:"
    openssl list -providers 2>/dev/null | grep -E "name:|status:" | sed 's/^/  /' || true

    if openssl list -providers 2>/dev/null | grep -q "fips"; then
        log_pass "FIPS provider active"
    else
        log_info "FIPS provider not active (expected in non-FIPS deployments)"
    fi
else
    log_fail "openssl command not found"
fi

# ── Section 3: cgroup v2 ────────────────────────────────────────────────────
echo ""
log_info "Checking cgroup v2 unified hierarchy..."
if mount | grep -q "cgroup2 on /sys/fs/cgroup"; then
    log_pass "cgroup v2 unified hierarchy active"
else
    log_warn "cgroup v2 not detected as primary -- SP6 default is cgroup v2 unified"
fi

SYSTEMD_VER=$(systemctl --version 2>/dev/null | head -1 | awk '{print $2}')
log_info "systemd version: ${SYSTEMD_VER:-unknown}"
if [[ "${SYSTEMD_VER:-0}" -ge 254 ]]; then
    log_pass "systemd $SYSTEMD_VER >= 254 (SP6 version)"
else
    log_warn "systemd ${SYSTEMD_VER:-unknown} -- expected 254+ for SP6"
fi

# ── Section 4: LUKS2 Capability ──────────────────────────────────────────────
echo ""
log_info "Checking LUKS2 support..."
if command -v cryptsetup &>/dev/null; then
    CRYPTSETUP_VER=$(cryptsetup --version 2>/dev/null | awk '{print $2}')
    log_info "cryptsetup version: ${CRYPTSETUP_VER:-unknown}"
    if cryptsetup --help 2>&1 | grep -qi "luks2\|LUKS2"; then
        log_pass "LUKS2 supported by cryptsetup"
    else
        log_warn "LUKS2 support not confirmed"
    fi
else
    log_info "cryptsetup not installed"
fi

# ── Section 5: SSH Key Strength ──────────────────────────────────────────────
echo ""
log_info "Checking SSH key strength (OpenSSH 9.6 requires RSA >= 2048 bits)..."
SSH_VER=$(ssh -V 2>&1 | head -1)
log_info "SSH version: $SSH_VER"

WEAK_KEYS=0
if [[ -d /etc/ssh ]]; then
    for key in /etc/ssh/ssh_host_*_key.pub; do
        [[ -f "$key" ]] || continue
        INFO=$(ssh-keygen -l -f "$key" 2>/dev/null || true)
        BITS=$(echo "$INFO" | awk '{print $1}')
        TYPE=$(echo "$INFO" | awk '{print $4}')
        if [[ "$TYPE" == "(RSA)" && "${BITS:-0}" -lt 2048 ]]; then
            log_fail "Weak host key: $key ($BITS-bit RSA)"
            ((WEAK_KEYS++))
        else
            log_pass "Host key OK: $key ($BITS-bit ${TYPE:-unknown})"
        fi
    done
fi

if [[ $WEAK_KEYS -eq 0 ]]; then
    log_pass "No weak RSA host keys detected"
fi

# ── Section 6: FRRouting / Quagga ────────────────────────────────────────────
echo ""
log_info "Checking FRRouting / Quagga status..."
if rpm -q quagga &>/dev/null 2>&1; then
    log_warn "Quagga is installed -- migrate to FRRouting"
    if systemctl is-active zebra &>/dev/null || systemctl is-active bgpd &>/dev/null; then
        log_fail "Quagga daemons are running -- schedule migration to FRR"
    fi
fi

if rpm -q frr &>/dev/null 2>&1; then
    log_pass "FRRouting installed"
    if systemctl is-active frr &>/dev/null; then
        log_pass "frr service is active"
    else
        log_info "frr installed but not running"
    fi
else
    log_info "FRRouting not installed (not required if dynamic routing not in use)"
fi

# ── Section 7: NFS over TLS ─────────────────────────────────────────────────
echo ""
log_info "Checking NFS over TLS capability..."
if rpm -q nfs-kernel-server &>/dev/null 2>&1 || rpm -q nfs-client &>/dev/null 2>&1; then
    if systemctl is-active rpc-tlsd &>/dev/null; then
        log_pass "rpc-tlsd is active -- NFS over TLS enabled"
    else
        log_info "rpc-tlsd not running -- NFS over TLS not configured (optional)"
    fi
else
    log_info "NFS not installed"
fi

# ── Section 8: zypper search-packages ────────────────────────────────────────
echo ""
log_info "Checking zypper search-packages (SP6 feature)..."
if zypper help search-packages &>/dev/null 2>&1; then
    log_pass "zypper search-packages command available"
else
    log_warn "zypper search-packages not available"
fi

# ── Section 9: SP7 Deprecation Check ────────────────────────────────────────
echo ""
log_info "=== SP7 Deprecation Check ==="
DEPRECATED_FOUND=0

for pkg in php7 php74 php7-cli php7-fpm; do
    if rpm -q "$pkg" &>/dev/null 2>&1; then
        log_warn "DEPRECATED (SP7): $pkg -- migrate to PHP 8.x"
        ((DEPRECATED_FOUND++))
    fi
done

for pkg in java-1_8_0-ibm java-11-ibm java-17-ibm; do
    if rpm -q "$pkg" &>/dev/null 2>&1; then
        log_warn "DEPRECATED (SP7): $pkg -- migrate to OpenJDK"
        ((DEPRECATED_FOUND++))
    fi
done

if rpm -q openldap2 &>/dev/null 2>&1; then
    log_warn "DEPRECATED (SP7): openldap2 -- migrate to 389 Directory Server"
    ((DEPRECATED_FOUND++))
    if systemctl is-active slapd &>/dev/null; then
        log_fail "OpenLDAP slapd is running -- migration required before SP7"
    fi
fi

if rpm -q ceph-common &>/dev/null 2>&1; then
    log_warn "DEPRECATED (SP7): ceph-common -- will require external repo in SP7"
    ((DEPRECATED_FOUND++))
fi

if [[ $DEPRECATED_FOUND -eq 0 ]]; then
    log_pass "No SP7-deprecated packages detected"
else
    log_warn "$DEPRECATED_FOUND deprecated package(s) found -- plan migration before SP7"
fi

# ── Section 10: Summary ─────────────────────────────────────────────────────
echo ""
echo "======================================================================"
echo "  Summary: PASS=$PASS  WARN=$WARN  FAIL=$FAIL"
if [[ $FAIL -gt 0 ]]; then
    echo "  STATUS: ACTION REQUIRED"
    exit 1
elif [[ $WARN -gt 0 ]]; then
    echo "  STATUS: REVIEW RECOMMENDED"
    exit 0
else
    echo "  STATUS: HEALTHY"
    exit 0
fi
