#!/usr/bin/env bash
# ============================================================================
# SLES - Security Audit
#
# Purpose : Security posture assessment including AppArmor status,
#           crypto policy, FIPS mode, SSH configuration, open ports,
#           SUID/SGID binaries, and password policy.
# Version : 1.0.0
# Targets : SLES 15 SP5+
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. AppArmor Status
#   2. Crypto Policy
#   3. FIPS Mode
#   4. SSH Configuration
#   5. Firewall Summary
#   6. SUID/SGID Binaries
#   7. Password Policy
#   8. Audit Framework
# ============================================================================
set -euo pipefail

SEP="$(printf '=%.0s' {1..70})"

section() {
    echo ""
    echo "$SEP"
    echo "  $1"
    echo "$SEP"
}

echo "$SEP"
echo "  SLES Security Audit - $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "$SEP"

# ── Section 1: AppArmor Status ──────────────────────────────────────────────
section "SECTION 1 - AppArmor Status"

if command -v aa-status &>/dev/null; then
    aa-status 2>/dev/null | sed 's/^/  /' || echo "  Unable to query AppArmor status"
else
    echo "  aa-status not found -- AppArmor may not be installed"
fi

echo ""
echo "  AppArmor service:"
systemctl is-active apparmor.service 2>/dev/null | sed 's/^/  /' || echo "  not-found"

echo ""
echo "  Recent AppArmor denials (last 24h):"
journalctl --since "24 hours ago" --no-pager 2>/dev/null \
    | grep -i "apparmor.*DENIED" \
    | tail -10 | sed 's/^/    /' || echo "    None found"

# ── Section 2: Crypto Policy ────────────────────────────────────────────────
section "SECTION 2 - Crypto Policy"

if command -v update-crypto-policies &>/dev/null; then
    policy=$(update-crypto-policies --show 2>/dev/null || echo "unknown")
    echo "  Current crypto policy: $policy"
    case "$policy" in
        FUTURE) echo "  [OK]   FUTURE -- strictest security" ;;
        FIPS)   echo "  [OK]   FIPS -- compliance mode" ;;
        DEFAULT) echo "  [INFO] DEFAULT -- standard security" ;;
        LEGACY) echo "  [WARN] LEGACY -- weak ciphers allowed" ;;
        *)      echo "  [INFO] Custom or unknown policy" ;;
    esac
else
    echo "  update-crypto-policies not available"
fi

# ── Section 3: FIPS Mode ───────────────────────────────────────────────────
section "SECTION 3 - FIPS Mode"

if [[ -f /proc/sys/crypto/fips_enabled ]]; then
    fips=$(cat /proc/sys/crypto/fips_enabled)
    if [[ "$fips" = "1" ]]; then
        echo "  FIPS: ENABLED"
    else
        echo "  FIPS: disabled"
    fi
else
    echo "  FIPS: unknown (proc file not found)"
fi

# ── Section 4: SSH Configuration ────────────────────────────────────────────
section "SECTION 4 - SSH Configuration"

echo "  SSH daemon status: $(systemctl is-active sshd 2>/dev/null || echo 'not-found')"
echo ""

if command -v sshd &>/dev/null; then
    echo "  Effective SSH configuration (key settings):"
    sshd -T 2>/dev/null | grep -E "^(permitrootlogin|passwordauthentication|pubkeyauthentication|protocol|maxauthtries|x11forwarding|allowtcpforwarding|ciphers|macs|kexalgorithms)" \
        | sort | sed 's/^/    /' || echo "    Unable to query sshd config"
fi

echo ""
echo "  Host key inventory:"
for key in /etc/ssh/ssh_host_*_key.pub; do
    [[ -f "$key" ]] || continue
    info=$(ssh-keygen -l -f "$key" 2>/dev/null || echo "unreadable")
    echo "    $key: $info"
done

# ── Section 5: Firewall Summary ─────────────────────────────────────────────
section "SECTION 5 - Firewall Summary"

if command -v firewall-cmd &>/dev/null; then
    state=$(firewall-cmd --state 2>/dev/null || echo "not running")
    echo "  firewalld: $state"
    echo ""
    echo "  Open services/ports:"
    firewall-cmd --list-all 2>/dev/null | grep -E "services:|ports:" | sed 's/^/    /' || true
else
    echo "  firewall-cmd not found"
fi

# ── Section 6: SUID/SGID Binaries ──────────────────────────────────────────
section "SECTION 6 - SUID/SGID Binaries"

echo "  SUID binaries:"
find /usr/bin /usr/sbin /bin /sbin -perm -4000 -type f 2>/dev/null \
    | head -30 | sed 's/^/    /' || echo "    None found"

echo ""
echo "  SGID binaries:"
find /usr/bin /usr/sbin /bin /sbin -perm -2000 -type f 2>/dev/null \
    | head -20 | sed 's/^/    /' || echo "    None found"

# ── Section 7: Password Policy ──────────────────────────────────────────────
section "SECTION 7 - Password Policy"

echo "  /etc/login.defs key settings:"
grep -E "^(PASS_MAX_DAYS|PASS_MIN_DAYS|PASS_MIN_LEN|PASS_WARN_AGE|LOGIN_RETRIES|ENCRYPT_METHOD)" \
    /etc/login.defs 2>/dev/null | sed 's/^/    /' || echo "    Not found"

echo ""
echo "  PAM password quality (if pam_pwquality configured):"
grep -v "^#" /etc/security/pwquality.conf 2>/dev/null | grep -v "^$" \
    | sed 's/^/    /' || echo "    pwquality.conf not found or empty"

# ── Section 8: Audit Framework ──────────────────────────────────────────────
section "SECTION 8 - Audit Framework"

echo "  auditd status: $(systemctl is-active auditd 2>/dev/null || echo 'not-found')"
echo ""
if command -v auditctl &>/dev/null; then
    echo "  Audit rules count: $(auditctl -l 2>/dev/null | wc -l)"
    echo "  Audit status:"
    auditctl -s 2>/dev/null | head -10 | sed 's/^/    /' || true
else
    echo "  auditctl not found"
fi

echo ""
echo "$SEP"
echo "  Security Audit Complete - $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "$SEP"
