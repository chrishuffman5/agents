#!/usr/bin/env bash
# ============================================================================
# Ubuntu - Security Audit
#
# Purpose : Security posture assessment including AppArmor, user accounts,
#           sudo config, SSH hardening, unattended-upgrades, and needrestart.
# Version : 1.0.0
# Targets : Ubuntu 20.04+
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. AppArmor Status
#   2. User Accounts
#   3. Sudo Configuration
#   4. SSH Hardening Review
#   5. Listening Services
#   6. Unattended Upgrades Configuration
#   7. Services Requiring Restart
# ============================================================================
set -euo pipefail

SEP="$(printf '=%.0s' {1..70})"

section() { echo ""; echo "$SEP"; echo "  $1"; echo "$SEP"; }

# -- Section 1: AppArmor Status --------------------------------------------
section "SECTION 1 - AppArmor Status"
if command -v aa-status &>/dev/null; then
    aa-status 2>/dev/null | head -30 | sed 's/^/  /' \
        || echo "  Unable to query AppArmor (need root)"
else
    echo "  [WARN] AppArmor tools (apparmor-utils) not installed"
fi

# -- Section 2: User Accounts ----------------------------------------------
section "SECTION 2 - User Accounts"
echo "  Users with login shell:"
grep -E '/bin/(bash|sh|zsh|fish|dash)$' /etc/passwd \
    | awk -F: '{printf "  %-20s uid=%-6s shell=%s\n", $1, $3, $7}'
echo ""
echo "  Users with UID 0 (root equivalents):"
awk -F: '$3==0{print "  [WARN] "$1" has UID 0"}' /etc/passwd

echo ""
echo "  Password status for interactive users:"
awk -F: 'NR==FNR && $3>=1000 && $3<65534 {users[$1]=1} NR!=FNR && $1 in users \
    {printf "  %-20s status=%s\n", $1, $2}' /etc/passwd /etc/shadow 2>/dev/null \
    || echo "  (need root to read /etc/shadow)"

# -- Section 3: Sudo Configuration -----------------------------------------
section "SECTION 3 - Sudo Configuration"
echo "  /etc/sudoers (NOPASSWD entries):"
grep -r 'NOPASSWD' /etc/sudoers /etc/sudoers.d/ 2>/dev/null \
    | sed 's/^/  [WARN] /' || echo "  None found"
echo ""
echo "  Sudo group members:"
getent group sudo 2>/dev/null | sed 's/^/  /' || true
getent group admin 2>/dev/null | sed 's/^/  /' || true

# -- Section 4: SSH Hardening Review ---------------------------------------
section "SECTION 4 - SSH Hardening Review"
sshd_config="/etc/ssh/sshd_config"
checks=(
    "PermitRootLogin:PermitRootLogin no"
    "PasswordAuthentication:PasswordAuthentication no"
    "X11Forwarding:X11Forwarding no"
    "PermitEmptyPasswords:PermitEmptyPasswords no"
)
for check in "${checks[@]}"; do
    key="${check%%:*}"
    expected="${check#*:}"
    val=$(grep -iE "^${key}\s" "$sshd_config" 2>/dev/null | tail -1 | xargs || echo "not set")
    if [[ "$val" == "$expected" ]]; then
        echo "  [OK]   $val"
    else
        echo "  [WARN] $key = $val (expected: $expected)"
    fi
done

# -- Section 5: Listening Services ------------------------------------------
section "SECTION 5 - Listening Services"
ss -tlunp 2>/dev/null | sed 's/^/  /'

# -- Section 6: Unattended Upgrades ----------------------------------------
section "SECTION 6 - Unattended Upgrades Configuration"
conf="/etc/apt/apt.conf.d/50unattended-upgrades"
if [[ -f "$conf" ]]; then
    echo "  Key settings from $conf:"
    grep -E 'Automatic-Reboot|Mail|Remove-Unused|Origins-Pattern' "$conf" \
        | grep -v '^\s*//' | sed 's/^/  /'
else
    echo "  [WARN] $conf not found -- unattended-upgrades may not be configured"
fi
echo ""
echo "  unattended-upgrades service status:"
systemctl is-active unattended-upgrades 2>/dev/null | sed 's/^/  Status: /'

# -- Section 7: needrestart ------------------------------------------------
section "SECTION 7 - Services Requiring Restart"
if command -v needrestart &>/dev/null; then
    sudo needrestart -b 2>/dev/null | sed 's/^/  /' \
        || echo "  Run as root for full results"
else
    echo "  [INFO] needrestart not installed"
    echo "  Install: apt install needrestart"
fi

echo ""
echo "$SEP"
echo "  Security Audit Complete - $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "$SEP"
