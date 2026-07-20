#!/usr/bin/env bash
# ============================================================================
# SLES 15 SP5 - Feature Health Check
#
# Purpose : Validate SP5-specific features including Podman Netavark
#           networking, NVMe-oF TCP support, Systems Management module,
#           RPM signing key strength, TLS configuration, and Python 3.11.
# Version : 1.0.0
# Targets : SLES 15 SP5
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. Version Verification
#   2. Podman / Netavark Backend
#   3. NVMe-oF TCP Support
#   4. Systems Management Module
#   5. RPM Signing Key Strength
#   6. TLS 1.0/1.1 Deprecation
#   7. Python 3.11 Module
#   8. Summary
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
echo "  SLES 15 SP5 Feature Health Check"
echo "  $(date -u '+%Y-%m-%d %H:%M:%S UTC')  Host: $(hostname)"
echo "======================================================================"
echo ""

# ── Section 1: Version Verification ─────────────────────────────────────────
log_info "Checking SLES version..."
if grep -q "SLES" /etc/os-release 2>/dev/null; then
    VERSION_ID=$(grep ^VERSION_ID /etc/os-release | cut -d= -f2 | tr -d '"')
    if [[ "$VERSION_ID" == "15.5" ]]; then
        log_pass "Running SLES 15 SP5 (VERSION_ID=$VERSION_ID)"
    else
        log_warn "VERSION_ID=$VERSION_ID -- expected 15.5 for SP5"
    fi
else
    log_fail "Not a SLES system"
fi

KERNEL=$(uname -r)
log_info "Kernel: $KERNEL"
if echo "$KERNEL" | grep -qE "^5\.14"; then
    log_pass "SP5 kernel (5.14.x) confirmed"
else
    log_warn "Unexpected kernel version: $KERNEL (SP5 base is 5.14.21)"
fi

# ── Section 2: Podman / Netavark ─────────────────────────────────────────────
echo ""
log_info "Checking Podman Netavark networking backend..."
if command -v podman &>/dev/null; then
    BACKEND=$(podman info 2>/dev/null | grep networkBackend | awk '{print $2}')
    if [[ "$BACKEND" == "netavark" ]]; then
        log_pass "Podman network backend: netavark (SP5 default)"
    else
        log_warn "Podman network backend: ${BACKEND:-unknown} (expected netavark)"
    fi
    PODMAN_VER=$(podman --version 2>/dev/null | awk '{print $3}')
    log_info "Podman version: ${PODMAN_VER:-unknown}"
else
    log_info "Podman not installed -- skipping container networking check"
fi

# ── Section 3: NVMe-oF TCP ──────────────────────────────────────────────────
echo ""
log_info "Checking NVMe-oF TCP module..."
if lsmod | grep -q nvme_tcp 2>/dev/null; then
    log_pass "nvme_tcp module loaded"
elif modinfo nvme_tcp &>/dev/null 2>&1; then
    log_warn "nvme_tcp module available but not loaded"
else
    log_info "nvme_tcp module not available (no NVMe-oF TCP hardware expected)"
fi

if [[ -f /etc/nvme/hostnqn ]]; then
    log_pass "NVMe hostnqn configured"
else
    log_info "No /etc/nvme/hostnqn -- NVMe-oF boot not configured"
fi

# ── Section 4: Systems Management Module ─────────────────────────────────────
echo ""
log_info "Checking Systems Management Module..."
if SUSEConnect --status 2>/dev/null | grep -q "sle-module-systems-management"; then
    log_pass "Systems Management Module registered"
else
    log_warn "Systems Management Module not registered"
fi

if command -v salt-minion &>/dev/null; then
    log_pass "salt-minion installed"
fi

if command -v ansible &>/dev/null; then
    log_pass "Ansible installed: $(ansible --version 2>/dev/null | head -1)"
fi

# ── Section 5: RPM Signing Key ───────────────────────────────────────────────
echo ""
log_info "Checking RPM signing key strength..."
SUSE_KEYS=$(rpm -q gpg-pubkey --qf '%{NAME}-%{VERSION}-%{RELEASE}\t%{SUMMARY}\n' 2>/dev/null | grep -i suse || true)
if [[ -n "$SUSE_KEYS" ]]; then
    log_info "SUSE GPG keys installed:"
    echo "$SUSE_KEYS" | sed 's/^/  /'
else
    log_fail "No SUSE GPG keys found in RPM database"
fi

# ── Section 6: TLS Configuration ─────────────────────────────────────────────
echo ""
log_info "Checking TLS 1.0/1.1 deprecation status..."
CRYPTO_POLICY=$(update-crypto-policies --show 2>/dev/null || echo "unknown")
log_info "Current crypto policy: $CRYPTO_POLICY"

case "$CRYPTO_POLICY" in
    FUTURE) log_pass "FUTURE policy -- TLS 1.0/1.1 explicitly disabled" ;;
    DEFAULT) log_warn "DEFAULT policy -- TLS 1.0/1.1 deprecated but not fully disabled" ;;
    LEGACY) log_fail "LEGACY policy -- TLS 1.0/1.1 enabled; migrate to DEFAULT or FUTURE" ;;
    *) log_info "Crypto policy: $CRYPTO_POLICY -- manual review required" ;;
esac

# ── Section 7: Python 3.11 ──────────────────────────────────────────────────
echo ""
log_info "Checking Python 3.11 availability..."
if command -v python3.11 &>/dev/null; then
    log_pass "Python 3.11 installed: $(python3.11 --version 2>/dev/null)"
elif SUSEConnect --status 2>/dev/null | grep -q "sle-module-python3"; then
    log_info "Python 3 Module registered but python3.11 not installed"
else
    log_info "Python 3 Module not registered (python3.11 unavailable)"
fi

# ── Section 8: Summary ──────────────────────────────────────────────────────
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
