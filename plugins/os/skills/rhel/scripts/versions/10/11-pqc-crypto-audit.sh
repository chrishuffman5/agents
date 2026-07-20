#!/usr/bin/env bash
# ============================================================================
# RHEL 10 - Post-Quantum Cryptography (PQC) Audit
#
# Purpose : Audit PQC availability in OpenSSL and OpenSSH, test ML-KEM
#           and ML-DSA key generation, check FIPS mode interaction with
#           PQC, and report crypto policy PQC sub-policy status.
# Version : 1.0.0
# Targets : RHEL 10.x
# Safety  : Read-only. No modifications to system configuration.
#           Temporary test keys created in /tmp and removed immediately.
#
# Sections:
#   1. OpenSSL Version and Providers
#   2. ML-KEM (Kyber) Key Encapsulation
#   3. ML-DSA (Dilithium) Signatures
#   4. OpenSSH PQC Key Exchange
#   5. FIPS Mode and PQC Interaction
#   6. Crypto Policy PQC Sub-Policy
#   7. PQC Package Inventory
# ============================================================================
set -euo pipefail

SEP="$(printf '=%.0s' {1..70})"
section() { echo ""; echo "$SEP"; echo "  $1"; echo "$SEP"; }
ok()   { echo "  [OK]   $1"; }
warn() { echo "  [WARN] $1"; }
fail() { echo "  [FAIL] $1"; }
info() { echo "  [INFO] $1"; }

echo "RHEL 10 Post-Quantum Cryptography Audit"
echo "Generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "Hostname:  $(hostname -f 2>/dev/null || hostname)"

PQC_KEM_FOUND=false
PQC_SIG_FOUND=false

# ── Section 1: OpenSSL Version and Providers ────────────────────────────────
section "1. OpenSSL Version and Providers"

if command -v openssl &>/dev/null; then
    OPENSSL_VER=$(openssl version)
    ok "OpenSSL: $OPENSSL_VER"

    echo ""
    info "Loaded providers:"
    openssl list -providers 2>/dev/null | grep -E 'name:|status:' | sed 's/^/    /' || \
        warn "Could not list providers"

    if openssl list -providers 2>/dev/null | grep -qi 'oqs\|quantum'; then
        ok "OQS (Open Quantum Safe) provider detected"
    else
        info "OQS provider not detected -- PQC may be in default provider (OpenSSL 3.x)"
    fi
else
    fail "OpenSSL not found"
fi

# ── Section 2: ML-KEM (Kyber) Key Encapsulation ────────────────────────────
section "2. ML-KEM (Kyber) Key Encapsulation Availability"

for alg in ML-KEM-512 ML-KEM-768 ML-KEM-1024; do
    if openssl list -kem-algorithms 2>/dev/null | grep -qi "$alg"; then
        ok "$alg available"
        PQC_KEM_FOUND=true
    else
        warn "$alg NOT available"
    fi
done

if [[ "$PQC_KEM_FOUND" == "true" ]]; then
    echo ""
    info "Test ML-KEM-768 key generation:"
    if openssl genpkey -algorithm ML-KEM-768 -out /tmp/mlkem-test-$$.pem 2>/dev/null; then
        ok "ML-KEM-768 key generation: SUCCESS"
        rm -f /tmp/mlkem-test-$$.pem
    else
        fail "ML-KEM-768 key generation FAILED"
    fi
fi

# ── Section 3: ML-DSA (Dilithium) Signatures ───────────────────────────────
section "3. ML-DSA (Dilithium) Signature Availability"

for alg in ML-DSA-44 ML-DSA-65 ML-DSA-87; do
    if openssl list -signature-algorithms 2>/dev/null | grep -qi "$alg"; then
        ok "$alg available"
        PQC_SIG_FOUND=true
    else
        warn "$alg NOT available"
    fi
done

if [[ "$PQC_SIG_FOUND" == "true" ]]; then
    echo ""
    info "Test ML-DSA-65 sign/verify:"
    if openssl genpkey -algorithm ML-DSA-65 -out /tmp/mldsa-test-$$.pem 2>/dev/null; then
        openssl pkey -in /tmp/mldsa-test-$$.pem -pubout -out /tmp/mldsa-pub-$$.pem 2>/dev/null
        echo "test data" > /tmp/pqc-test-$$.txt
        if openssl dgst -sign /tmp/mldsa-test-$$.pem -out /tmp/pqc-sig-$$.bin /tmp/pqc-test-$$.txt 2>/dev/null && \
           openssl dgst -verify /tmp/mldsa-pub-$$.pem -signature /tmp/pqc-sig-$$.bin /tmp/pqc-test-$$.txt 2>/dev/null; then
            ok "ML-DSA-65 sign + verify: SUCCESS"
        else
            fail "ML-DSA-65 sign/verify FAILED"
        fi
        rm -f /tmp/mldsa-test-$$.pem /tmp/mldsa-pub-$$.pem /tmp/pqc-test-$$.txt /tmp/pqc-sig-$$.bin
    else
        fail "ML-DSA-65 key generation FAILED"
    fi
fi

# SLH-DSA check
for alg in SLH-DSA-SHA2-128s SLH-DSA-SHA2-256s; do
    if openssl list -signature-algorithms 2>/dev/null | grep -qi "$alg"; then
        ok "$alg (SLH-DSA/SPHINCS+) available"
    else
        info "$alg not available (optional)"
    fi
done

# ── Section 4: OpenSSH PQC Key Exchange ─────────────────────────────────────
section "4. OpenSSH PQC Key Exchange Algorithms"

if command -v ssh &>/dev/null; then
    ok "SSH: $(ssh -V 2>&1)"
    echo ""
    info "Available PQC key exchange algorithms:"
    ssh -Q kex 2>/dev/null | grep -iE 'kyber|mlkem|ntru|sntrup' | sed 's/^/    /' || \
        warn "No PQC KEX algorithms found"

    if ssh -Q kex 2>/dev/null | grep -qi 'mlkem\|kyber'; then
        ok "Hybrid PQC KEX (ML-KEM/Kyber) available for SSH"
    else
        warn "Hybrid PQC KEX not found -- SSH uses classical key exchange only"
    fi

    echo ""
    info "Current sshd KexAlgorithms:"
    if [[ -f /etc/ssh/sshd_config ]]; then
        grep -E '^KexAlgorithms' /etc/ssh/sshd_config 2>/dev/null | sed 's/^/    /' || \
            info "  KexAlgorithms not explicitly set (using defaults)"
        grep -r 'KexAlgorithms' /etc/ssh/sshd_config.d/ 2>/dev/null | sed 's/^/    /' || true
    fi
else
    fail "ssh binary not found"
fi

# ── Section 5: FIPS Mode and PQC ────────────────────────────────────────────
section "5. FIPS Mode and PQC Interaction"

if [[ -f /proc/sys/crypto/fips_enabled ]]; then
    FIPS_VAL=$(cat /proc/sys/crypto/fips_enabled)
    if [[ "$FIPS_VAL" == "1" ]]; then
        ok "FIPS mode: ENABLED"
        warn "PQC FIPS validation: CMVP validation for ML-KEM/ML-DSA may be pending"
        info "Check Red Hat security advisories for FIPS 140-3 PQC certification status"
    else
        info "FIPS mode: DISABLED"
        info "PQC algorithms available without FIPS restriction"
    fi
else
    warn "/proc/sys/crypto/fips_enabled not found"
fi

if command -v fips-mode-setup &>/dev/null; then
    fips-mode-setup --check 2>&1 | sed 's/^/  /'
fi

# ── Section 6: Crypto Policy PQC Sub-Policy ─────────────────────────────────
section "6. Crypto Policy PQC Sub-Policy"

if command -v update-crypto-policies &>/dev/null; then
    ok "Current crypto policy: $(update-crypto-policies --show 2>/dev/null)"

    if ls /usr/share/crypto-policies/policies/modules/ 2>/dev/null | grep -qi 'pq\|quantum'; then
        ok "PQ crypto policy module available"
        info "Available PQ modules:"
        ls /usr/share/crypto-policies/policies/modules/ 2>/dev/null | grep -iE 'pq|quantum' | sed 's/^/    /'
        info "Enable: update-crypto-policies --set DEFAULT:PQ"
    else
        warn "PQ crypto policy module not found"
        info "Install crypto-policies-pqc package if available"
    fi
else
    warn "update-crypto-policies not found"
fi

# ── Section 7: PQC Package Inventory ────────────────────────────────────────
section "7. PQC-Related Package Inventory"

PQC_PKGS=(openssl oqs-provider liboqs openssh openssh-server crypto-policies)
for pkg in "${PQC_PKGS[@]}"; do
    if rpm -q "$pkg" &>/dev/null; then
        VER=$(rpm -q --queryformat '%{VERSION}-%{RELEASE}' "$pkg" 2>/dev/null)
        ok "$pkg: $VER"
    else
        info "$pkg: not installed"
    fi
done

# ── Summary ─────────────────────────────────────────────────────────────────
echo ""
section "Summary"

if [[ "$PQC_KEM_FOUND" == "true" ]] && [[ "$PQC_SIG_FOUND" == "true" ]]; then
    ok "PQC algorithms (ML-KEM + ML-DSA) are available on this system"
    info "Recommended next steps:"
    info "  1. Enable PQC crypto sub-policy: update-crypto-policies --set DEFAULT:PQ"
    info "  2. Configure SSH KexAlgorithms to prefer hybrid PQC+classical"
    info "  3. Monitor Red Hat advisories for FIPS 140-3 PQC certification"
    info "  4. Evaluate long-lived TLS certificates for PQC migration timeline"
elif [[ "$PQC_KEM_FOUND" == "true" ]] || [[ "$PQC_SIG_FOUND" == "true" ]]; then
    warn "Partial PQC support -- some algorithms available, others missing"
    info "Check OpenSSL provider configuration and oqs-provider package"
else
    fail "No PQC algorithms detected"
    info "Ensure openssl >= 3.x and oqs-provider are installed"
fi

echo ""
echo "$SEP"
echo "  PQC Audit Complete - $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "$SEP"
