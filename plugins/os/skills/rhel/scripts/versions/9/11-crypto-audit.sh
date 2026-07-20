#!/usr/bin/env bash
# ============================================================================
# RHEL 9 - Cryptography and Deprecated Algorithm Audit
#
# Purpose : Audit system crypto policy, OpenSSL 3.0 and FIPS status,
#           SSH key types, deprecated algorithm detection, and SHA-1
#           certificate usage in the system trust store.
# Version : 1.0.0
# Targets : RHEL 9.x
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. System Crypto Policy
#   2. OpenSSL Version and FIPS Status
#   3. System FIPS Mode
#   4. SSH Key Types in Use
#   5. Deprecated Algorithm Detection
#   6. SHA-1 Certificate Check
# ============================================================================
set -euo pipefail

SEP="$(printf '=%.0s' {1..70})"
section() { echo ""; echo "$SEP"; echo "  $1"; echo "$SEP"; }
ok()   { echo "  [OK]   $1"; }
warn() { echo "  [WARN] $1"; }
fail() { echo "  [FAIL] $1"; }
info() { echo "  [INFO] $1"; }

echo "RHEL 9 Cryptography Audit"
echo "Generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "Hostname:  $(hostname -f 2>/dev/null || hostname)"
echo "Kernel:    $(uname -r)"

# ── Section 1: System Crypto Policy ─────────────────────────────────────────
section "1. System Crypto Policy"

if command -v update-crypto-policies &>/dev/null; then
    current_policy=$(update-crypto-policies --show 2>/dev/null)
    ok "Current crypto policy: $current_policy"

    case "$current_policy" in
        DEFAULT*)  info "SHA-1 disabled, TLS 1.0/1.1 disabled, DES/RC4 disabled" ;;
        FIPS*)     ok "FIPS policy active -- strong algorithm enforcement" ;;
        LEGACY*)   warn "LEGACY policy: SHA-1, TLS 1.0/1.1 enabled -- insecure for production" ;;
        FUTURE*)   ok "FUTURE policy: stricter than DEFAULT (RSA >= 3072)" ;;
        *)         info "Custom or unknown policy: $current_policy" ;;
    esac

    if echo "$current_policy" | grep -q ":"; then
        sub=$(echo "$current_policy" | cut -d: -f2-)
        warn "Sub-policy active: $sub -- review for security implications"
    fi
else
    fail "update-crypto-policies command not found"
fi

# Custom modules
if ls /etc/crypto-policies/policies/modules/ &>/dev/null; then
    mods=$(ls /etc/crypto-policies/policies/modules/ 2>/dev/null | tr '\n' ' ')
    [[ -n "$mods" ]] && info "Active policy modules: $mods" || info "No custom policy modules"
fi

# ── Section 2: OpenSSL Version and FIPS Status ──────────────────────────────
section "2. OpenSSL Version and FIPS Status"

if command -v openssl &>/dev/null; then
    openssl_version=$(openssl version)
    ok "OpenSSL: $openssl_version"

    if echo "$openssl_version" | grep -q "OpenSSL 3\."; then
        ok "OpenSSL 3.x detected (expected for RHEL 9)"
    else
        warn "OpenSSL version may not be 3.x -- check installation"
    fi

    echo ""
    info "OpenSSL Providers:"
    openssl list -providers 2>/dev/null | sed 's/^/    /'

    if openssl list -providers 2>/dev/null | grep -qi "fips.*active\|name: fips"; then
        ok "FIPS provider is active"
    else
        info "FIPS provider not active (expected unless FIPS mode enabled)"
    fi
else
    fail "openssl command not found"
fi

# ── Section 3: System FIPS Mode ─────────────────────────────────────────────
section "3. System FIPS Mode"

if [[ -r /proc/sys/crypto/fips_enabled ]]; then
    fips_val=$(cat /proc/sys/crypto/fips_enabled)
    if [[ "$fips_val" == "1" ]]; then
        ok "FIPS mode ENABLED (kernel fips_enabled=1)"
    else
        info "FIPS mode not enabled (fips_enabled=$fips_val)"
    fi
fi

if command -v fips-mode-setup &>/dev/null; then
    fips-mode-setup --check 2>&1 | sed 's/^/  /'
fi

# ── Section 4: SSH Key Types ────────────────────────────────────────────────
section "4. SSH Key Types in Use"

echo "  Host Keys:"
for keyfile in /etc/ssh/ssh_host_*_key.pub; do
    [[ -f "$keyfile" ]] || continue
    keytype=$(ssh-keygen -l -f "$keyfile" 2>/dev/null | awk '{print $4}' | tr -d '()')
    keybits=$(ssh-keygen -l -f "$keyfile" 2>/dev/null | awk '{print $1}')
    keyname=$(basename "$keyfile")

    if echo "$keytype" | grep -qi "dsa"; then
        fail "$keyname: $keytype ($keybits bits) -- DSA is deprecated"
    elif echo "$keytype" | grep -qi "ed25519\|ecdsa"; then
        ok "$keyname: $keytype ($keybits bits)"
    else
        info "$keyname: $keytype ($keybits bits)"
    fi
done

# Effective sshd config
if command -v sshd &>/dev/null; then
    echo ""
    info "SSHD effective algorithm configuration:"
    for setting in hostkeyalgorithms pubkeyacceptedalgorithms kexalgorithms ciphers macs; do
        val=$(sshd -T 2>/dev/null | grep "^$setting " | awk '{$1=""; print $0}' | xargs)
        if [[ -n "$val" ]]; then
            info "  $setting: ${val:0:80}..."
            if echo "$val" | grep -qi "ssh-rsa[^-]"; then
                warn "  -> ssh-rsa (SHA-1) present -- consider removing"
            fi
        fi
    done
fi

# ── Section 5: Deprecated Algorithm Detection ──────────────────────────────
section "5. Deprecated Algorithm Detection"

info "Scanning SSH configs for weak algorithms:"

for cfg in /etc/ssh/sshd_config /etc/ssh/ssh_config /etc/ssh/sshd_config.d/*.conf /etc/ssh/ssh_config.d/*.conf; do
    [[ -f "$cfg" ]] || continue
    if grep -qiE "ciphers.*3des|ciphers.*rc4|ciphers.*des-cbc" "$cfg" 2>/dev/null; then
        warn "$cfg: contains weak cipher (3DES/RC4/DES)"
    fi
    if grep -qiE "macs.*md5|macs.*sha1[^2]" "$cfg" 2>/dev/null; then
        warn "$cfg: contains MD5 or SHA-1 MAC"
    fi
    if grep -qiE "KexAlgorithms.*diffie-hellman-group1\b" "$cfg" 2>/dev/null; then
        warn "$cfg: DH Group 1 (768-bit) present"
    fi
done
ok "SSH config deprecated algorithm scan complete"

# Quick TLS check on common ports
echo ""
info "TLS protocol check on local listening ports:"
for port in 443 8443 636 993; do
    if ss -tlnp 2>/dev/null | grep -q ":$port "; then
        tls_info=$(timeout 3 openssl s_client -connect "localhost:$port" -brief 2>/dev/null | head -3 || true)
        if [[ -n "$tls_info" ]]; then
            info "  Port $port: $tls_info"
        fi
    fi
done

# ── Section 6: SHA-1 Certificate Check ──────────────────────────────────────
section "6. SHA-1 Certificate Check (System Trust Store)"

CA_BUNDLE="/etc/pki/tls/certs/ca-bundle.crt"
SHA1_COUNT=0

if [[ -r "$CA_BUNDLE" ]]; then
    info "Scanning $CA_BUNDLE for SHA-1 signed certificates..."

    # Quick grep-based check (faster than splitting)
    while IFS= read -r line; do
        if echo "$line" | grep -qi "sha1WithRSAEncryption\|sha1WithECDSA"; then
            ((SHA1_COUNT++)) || true
        fi
    done < <(openssl crl2pkcs7 -nocrl -certfile "$CA_BUNDLE" 2>/dev/null | \
             openssl pkcs7 -print_certs -noout -text 2>/dev/null | \
             grep "Signature Algorithm" || true)

    if [[ "$SHA1_COUNT" -gt 0 ]]; then
        warn "$SHA1_COUNT SHA-1 signed certificate(s) found in trust store"
        info "These certificates may be rejected by RHEL 9 DEFAULT policy"
    else
        ok "No SHA-1 signed certificates found in system trust store"
    fi
else
    info "CA bundle not found at $CA_BUNDLE"
fi

echo ""
echo "$SEP"
echo "  Cryptography Audit Complete - $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "$SEP"
