#!/usr/bin/env bash
# ============================================================================
# RHEL - Security Audit
#
# Purpose : Audit security posture including SELinux mode, recent AVC
#           denials, user accounts, sudo config, SSH config, open ports,
#           and crypto policy.
# Version : 1.0.0
# Targets : RHEL 8+
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. SELinux Status
#   2. Crypto Policy
#   3. SSH Configuration
#   4. User Accounts Audit
#   5. sudo Configuration
#   6. Open Ports
#   7. FIPS Mode
#   8. Recent Security Events
# ============================================================================
set -euo pipefail

SEP="$(printf '=%.0s' {1..70})"
section() { echo ""; echo "$SEP"; echo "  $1"; echo "$SEP"; }

echo "RHEL Security Audit"
echo "Generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "Hostname:  $(hostname -f 2>/dev/null || hostname)"

# ── Section 1: SELinux Status ───────────────────────────────────────────────
section "1. SELinux Status"

if command -v getenforce &>/dev/null; then
    mode=$(getenforce 2>/dev/null)
    echo "  Mode: $mode"

    if [[ "$mode" == "Enforcing" ]]; then
        echo "  [OK]   SELinux is enforcing"
    elif [[ "$mode" == "Permissive" ]]; then
        echo "  [WARN] SELinux is permissive -- should be Enforcing in production"
    else
        echo "  [WARN] SELinux is disabled -- critical security layer missing"
    fi

    sestatus 2>/dev/null | sed 's/^/  /'
fi

# Recent AVC denials
echo ""
avc_count=$(ausearch -m AVC -ts today --raw 2>/dev/null | wc -l || echo 0)
echo "  AVC denials today: $avc_count"
if [[ "$avc_count" -gt 0 ]]; then
    ausearch -m AVC -ts today -i 2>/dev/null | tail -10 | sed 's/^/    /'
fi

# ── Section 2: Crypto Policy ───────────────────────────────────────────────
section "2. System Crypto Policy"

if command -v update-crypto-policies &>/dev/null; then
    policy=$(update-crypto-policies --show 2>/dev/null)
    echo "  Current policy: $policy"

    case "$policy" in
        DEFAULT*) echo "  [OK]   Secure defaults active" ;;
        FIPS*)    echo "  [OK]   FIPS policy active" ;;
        LEGACY*)  echo "  [WARN] LEGACY policy -- SHA-1 and TLS 1.0/1.1 enabled" ;;
        FUTURE*)  echo "  [OK]   FUTURE policy -- stricter than DEFAULT" ;;
        *)        echo "  [INFO] Custom policy: $policy" ;;
    esac
else
    echo "  [INFO] update-crypto-policies not available"
fi

# ── Section 3: SSH Configuration ────────────────────────────────────────────
section "3. SSH Configuration"

if command -v sshd &>/dev/null; then
    echo "  Key settings:"
    for setting in permitrootlogin passwordauthentication maxauthtries x11forwarding permitemptypasswords; do
        val=$(sshd -T 2>/dev/null | grep "^$setting " | awk '{print $2}')
        echo "    $setting = ${val:-unknown}"
    done

    echo ""
    echo "  Host key types:"
    for keyfile in /etc/ssh/ssh_host_*_key.pub; do
        [[ -f "$keyfile" ]] || continue
        keyinfo=$(ssh-keygen -l -f "$keyfile" 2>/dev/null)
        echo "    $keyinfo"
    done

    echo ""
    echo "  Drop-in configs:"
    ls /etc/ssh/sshd_config.d/ 2>/dev/null | sed 's/^/    /' || echo "    none"
else
    echo "  [INFO] sshd not installed"
fi

# ── Section 4: User Accounts Audit ──────────────────────────────────────────
section "4. User Accounts Audit"

echo "  Users with UID 0 (root-level):"
awk -F: '$3==0 {print "    " $1}' /etc/passwd

echo ""
echo "  Users with login shells:"
awk -F: '$7 !~ /nologin|false|shutdown|halt|sync/ {print "    " $1 " (" $7 ")"}' /etc/passwd

echo ""
echo "  Accounts with no password expiry:"
for user in $(awk -F: '$7 !~ /nologin|false/ && $3>=1000 {print $1}' /etc/passwd 2>/dev/null); do
    max_days=$(chage -l "$user" 2>/dev/null | grep "Maximum" | awk -F: '{print $2}' | xargs)
    if [[ "$max_days" == "99999" || "$max_days" == "-1" ]]; then
        echo "    $user (max days: $max_days)"
    fi
done

echo ""
echo "  Locked accounts:"
awk -F: '$2 ~ /^!|^\*/ {print "    " $1}' /etc/shadow 2>/dev/null | head -10 || true

# ── Section 5: sudo Configuration ───────────────────────────────────────────
section "5. sudo Configuration"

echo "  wheel group members:"
getent group wheel 2>/dev/null | awk -F: '{print "    " $4}' || echo "    unable to query"

echo ""
echo "  sudoers drop-in files:"
ls /etc/sudoers.d/ 2>/dev/null | sed 's/^/    /' || echo "    none"

echo ""
echo "  NOPASSWD rules:"
grep -rh "NOPASSWD" /etc/sudoers /etc/sudoers.d/ 2>/dev/null | grep -v "^#" | sed 's/^/    /' || echo "    none"

# ── Section 6: Open Ports ───────────────────────────────────────────────────
section "6. Open Ports"

echo "  TCP listening:"
ss -tlnp 2>/dev/null | tail -n +2 | sed 's/^/    /'

echo ""
echo "  UDP listening:"
ss -ulnp 2>/dev/null | tail -n +2 | sed 's/^/    /'

# ── Section 7: FIPS Mode ───────────────────────────────────────────────────
section "7. FIPS Mode"

if [[ -f /proc/sys/crypto/fips_enabled ]]; then
    fips_val=$(cat /proc/sys/crypto/fips_enabled)
    if [[ "$fips_val" == "1" ]]; then
        echo "  [OK]   FIPS mode: ENABLED"
    else
        echo "  [INFO] FIPS mode: DISABLED"
    fi
else
    echo "  [INFO] /proc/sys/crypto/fips_enabled not found"
fi

if command -v fips-mode-setup &>/dev/null; then
    fips-mode-setup --check 2>&1 | sed 's/^/  /'
fi

# ── Section 8: Recent Security Events ──────────────────────────────────────
section "8. Recent Security Events"

echo "  Failed login attempts (last 24h):"
lastb 2>/dev/null | head -10 | sed 's/^/    /' || echo "    unable to query"

echo ""
echo "  Recent sudo usage:"
journalctl _COMM=sudo --since "24 hours ago" --no-pager -q 2>/dev/null | tail -10 | sed 's/^/    /' || true

echo ""
echo "$SEP"
echo "  Security Audit Complete - $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "$SEP"
