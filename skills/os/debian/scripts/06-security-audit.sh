#!/usr/bin/env bash
# ============================================================================
# Debian - Security Audit
#
# Purpose : AppArmor status, user accounts, sudo config, SSH settings,
#           SUID/SGID binaries, debsecan CVE summary, recent logins,
#           listening ports, check-support-status.
# Version : 1.0.0
# Targets : Debian 11+ (Bullseye and later)
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. AppArmor Status
#   2. User Accounts
#   3. sudo Configuration
#   4. SSH Configuration
#   5. SUID/SGID Binaries
#   6. debsecan CVE Summary
#   7. Recent Logins
#   8. Listening Ports
#   9. check-support-status
# ============================================================================
set -euo pipefail

echo "=== DEBIAN SECURITY AUDIT ==="
echo "Date: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo ""

echo "--- AppArmor Status ---"
if command -v aa-status &>/dev/null; then
    aa-status 2>/dev/null || apparmor_status 2>/dev/null || echo "AppArmor command failed"
else
    echo "AppArmor tools not installed"
fi
echo ""

echo "--- SELinux Status ---"
if command -v sestatus &>/dev/null; then
    sestatus 2>/dev/null
else
    echo "SELinux not installed (AppArmor is Debian default)"
fi
echo ""

echo "--- User Accounts ---"
echo "Users with login shell:"
grep -v '^#' /etc/passwd | awk -F: '$7 !~ /nologin|false/ && $3 >= 1000 {print $1, $3, $6, $7}'
echo ""
echo "Users with UID 0:"
awk -F: '$3 == 0 {print $1}' /etc/passwd
echo ""
echo "Users with empty password:"
awk -F: '$2 == "" {print $1}' /etc/shadow 2>/dev/null || echo "(requires root)"
echo ""

echo "--- sudo Configuration ---"
echo "sudoers members:"
getent group sudo 2>/dev/null || grep 'sudo' /etc/group
echo ""
if [ -f /etc/sudoers ]; then
    grep -v '^#' /etc/sudoers | grep -v '^$' | grep -v '^Defaults' | head -20
fi
ls -la /etc/sudoers.d/ 2>/dev/null
echo ""

echo "--- SSH Configuration ---"
if [ -f /etc/ssh/sshd_config ]; then
    echo "Key SSH settings:"
    grep -E '^(PermitRootLogin|PasswordAuthentication|PubkeyAuthentication|Port|PermitEmptyPasswords|X11Forwarding|AllowTcpForwarding|UsePAM)' \
        /etc/ssh/sshd_config 2>/dev/null | grep -v '^#' || echo "None found (check includes)"
fi
echo ""

echo "--- SUID/SGID Binaries ---"
find /usr/bin /usr/sbin /bin /sbin -perm /4000 -o -perm /2000 2>/dev/null | sort
echo ""

echo "--- World-Writable Files (spot check /etc) ---"
find /etc -maxdepth 2 -perm -002 -type f 2>/dev/null | head -20 || echo "None"
echo ""

echo "--- debsecan CVE Summary ---"
if command -v debsecan &>/dev/null; then
    total=$(debsecan --suite "$(lsb_release -cs 2>/dev/null || echo bookworm)" 2>/dev/null | wc -l)
    fixable=$(debsecan --suite "$(lsb_release -cs 2>/dev/null || echo bookworm)" --only-fixed 2>/dev/null | wc -l)
    echo "Total CVEs affecting this system: $total"
    echo "CVEs with available fixes: $fixable"
    echo ""
    echo "Top CVEs with fixes (first 10):"
    debsecan --suite "$(lsb_release -cs 2>/dev/null || echo bookworm)" --only-fixed 2>/dev/null | head -10
else
    echo "debsecan not installed (apt-get install debsecan)"
fi
echo ""

echo "--- Last Logins ---"
last -n 20 2>/dev/null
echo ""

echo "--- Failed Login Attempts (last 24h) ---"
journalctl --since "24 hours ago" -u ssh -u sshd --no-pager 2>/dev/null | \
    grep -c 'Failed\|Invalid\|refused' | xargs echo "Failed SSH attempts:"
echo ""

echo "--- Listening Ports (security view) ---"
ss -tlnp 2>/dev/null
echo ""

echo "--- check-support-status ---"
if command -v check-support-status &>/dev/null; then
    check-support-status 2>/dev/null
else
    echo "debian-security-support not installed (apt-get install debian-security-support)"
fi
