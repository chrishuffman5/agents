#!/usr/bin/env bash
# ============================================================================
# Ubuntu 22.04 - Active Directory Integration Assessment
#
# Purpose : Assess adsys status, SSSD configuration, realm connectivity,
#           AD domain membership, GPO application, and 22.04 features.
# Version : 22.1.0
# Targets : Ubuntu 22.04 LTS (Jammy Jellyfish)
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. OS Version Check
#   2. adsys Service Status
#   3. SSSD Configuration
#   4. Realm / Domain Membership
#   5. AD Connectivity
#   6. GPO / adsys Policy Status
#   7. 22.04 Feature Status (Wayland & nftables)
# ============================================================================
set -euo pipefail

SEP="$(printf '=%.0s' {1..70})"

section() { echo ""; echo "$SEP"; echo "  $1"; echo "$SEP"; }

section "SECTION 1 - OS Version Check"
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    echo "  OS: ${PRETTY_NAME:-unknown}"
    echo "  Version ID: ${VERSION_ID:-unknown}"
    if [[ "${VERSION_ID:-}" != "22.04" ]]; then
        echo "  [WARN] This script targets Ubuntu 22.04, detected ${VERSION_ID}"
    else
        echo "  [OK]   Running on target version 22.04"
    fi
fi

section "SECTION 2 - adsys Service Status"
if command -v adsysctl &>/dev/null; then
    echo "  [OK]   adsys is installed"
    ADSYS_VERSION=$(dpkg -l adsys 2>/dev/null | grep "^ii" | awk '{print $3}')
    echo "  Version: ${ADSYS_VERSION:-unknown}"

    if systemctl is-active --quiet adsysd 2>/dev/null; then
        echo "  [OK]   adsysd daemon is running"
    else
        ADSYS_STATE=$(systemctl is-active adsysd 2>/dev/null || echo "unknown")
        echo "  [FAIL] adsysd is ${ADSYS_STATE}"
        echo "  Start: systemctl start adsysd"
        echo "  Enable: systemctl enable adsysd"
    fi

    systemctl status adsysd 2>/dev/null | grep -E "(Active:|Main PID:)" | sed 's/^/    /'
else
    echo "  [INFO] adsys not installed"
    echo "  Install: apt install adsys"
    echo "  Note: adsys provides GPO-like AD policy management (22.04 feature)"
fi

section "SECTION 3 - SSSD Configuration"
if command -v sssd &>/dev/null; then
    SSSD_VERSION=$(sssd --version 2>/dev/null | head -1 || dpkg -l sssd 2>/dev/null | grep "^ii" | awk '{print $3}')
    echo "  SSSD version: ${SSSD_VERSION:-unknown}"

    if systemctl is-active --quiet sssd 2>/dev/null; then
        echo "  [OK]   SSSD is running"
    else
        echo "  [FAIL] SSSD is $(systemctl is-active sssd 2>/dev/null || echo 'not running')"
    fi

    if [[ -f /etc/sssd/sssd.conf ]]; then
        echo "  [OK]   /etc/sssd/sssd.conf present"
        DOMAINS=$(grep "^\[domain/" /etc/sssd/sssd.conf 2>/dev/null | sed 's/\[domain\///;s/\]//' || true)
        if [[ -n "${DOMAINS}" ]]; then
            echo "  Configured domains:"
            echo "${DOMAINS}" | sed 's/^/    - /'
        fi
        ID_PROVIDER=$(grep "id_provider" /etc/sssd/sssd.conf 2>/dev/null | head -1 | awk -F= '{print $2}' | tr -d ' ' || echo "unknown")
        echo "  ID provider: ${ID_PROVIDER}"

        if grep -q "KCM" /etc/sssd/sssd.conf 2>/dev/null; then
            echo "  [OK]   KCM credential cache configured (22.04 default)"
        fi
    else
        echo "  [WARN] /etc/sssd/sssd.conf not found"
    fi
else
    echo "  [INFO] SSSD not installed"
    echo "  Install: apt install sssd sssd-ad"
fi

section "SECTION 4 - Realm / Domain Membership"
if command -v realm &>/dev/null; then
    REALM_LIST=$(realm list 2>/dev/null)
    if [[ -n "${REALM_LIST}" ]]; then
        echo "  [OK]   Joined to domain(s):"
        echo "${REALM_LIST}" | sed 's/^/    /'
    else
        echo "  [WARN] Not joined to any domain"
        echo "  To join: realm join --user=Administrator example.com"
        echo "  Prerequisites: apt install realmd sssd-ad oddjob-mkhomedir adcli"
    fi

    PERMITTED=$(realm list 2>/dev/null | grep "permitted-logins\|permitted-groups" || true)
    if [[ -n "${PERMITTED}" ]]; then
        echo "  Login permissions:"
        echo "${PERMITTED}" | sed 's/^/    /'
    fi
else
    echo "  [INFO] realmd not installed"
fi

if command -v klist &>/dev/null; then
    echo ""
    echo "  Kerberos ticket cache:"
    klist 2>/dev/null | head -5 | sed 's/^/    /' || echo "    No tickets (not authenticated)"
fi

section "SECTION 5 - AD Connectivity"
DOMAIN=""
if [[ -f /etc/sssd/sssd.conf ]]; then
    DOMAIN=$(grep "^\[domain/" /etc/sssd/sssd.conf | head -1 | sed 's/\[domain\///;s/\]//' || true)
fi
if [[ -z "${DOMAIN}" ]] && command -v realm &>/dev/null; then
    DOMAIN=$(realm list 2>/dev/null | grep "realm-name\|domain-name" | head -1 | awk '{print $NF}' || true)
fi

if [[ -n "${DOMAIN}" ]]; then
    echo "  Testing connectivity to domain: ${DOMAIN}"
    if command -v host &>/dev/null; then
        SRV=$(host -t SRV "_ldap._tcp.${DOMAIN}" 2>/dev/null | head -3 || echo "DNS lookup failed")
        echo "  LDAP SRV records:"
        echo "${SRV}" | sed 's/^/    /'
    fi

    DC=$(host -t SRV "_ldap._tcp.${DOMAIN}" 2>/dev/null | awk '{print $NF}' | head -1 | tr -d '.' || true)
    if [[ -n "${DC}" ]]; then
        if timeout 3 bash -c "echo > /dev/tcp/${DC}/389" 2>/dev/null; then
            echo "  [OK]   LDAP port 389 reachable on ${DC}"
        else
            echo "  [FAIL] Cannot reach LDAP port 389 on ${DC}"
        fi
        if timeout 3 bash -c "echo > /dev/tcp/${DC}/88" 2>/dev/null; then
            echo "  [OK]   Kerberos port 88 reachable on ${DC}"
        else
            echo "  [FAIL] Cannot reach Kerberos port 88 on ${DC}"
        fi
    fi
else
    echo "  [INFO] No domain detected -- skipping connectivity tests"
fi

section "SECTION 6 - GPO / adsys Policy Status"
if command -v adsysctl &>/dev/null && systemctl is-active --quiet adsysd 2>/dev/null; then
    echo "  Applied policies:"
    adsysctl policy show 2>/dev/null | head -20 | sed 's/^/    /' \
        || echo "    Unable to retrieve policy status"

    POLICY_ERRORS=$(journalctl -u adsysd --since "24 hours ago" 2>/dev/null | grep -ic "error\|fail" || echo "0")
    if [[ "${POLICY_ERRORS}" -gt 0 ]]; then
        echo "  [WARN] ${POLICY_ERRORS} policy-related errors in last 24h"
        echo "  View: journalctl -u adsysd --since '24 hours ago' | grep -i error"
    else
        echo "  [OK]   No policy errors in last 24 hours"
    fi
else
    echo "  [INFO] adsys not running -- GPO policy check skipped"
    echo "  Install: apt install adsys && systemctl enable --now adsysd"
fi

section "SECTION 7 - 22.04 Feature Status (Wayland & nftables)"

# Wayland
if [[ -n "${DISPLAY:-}" ]] || [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
    SESSION_TYPE="${XDG_SESSION_TYPE:-unknown}"
    echo "  Display session: ${SESSION_TYPE}"
    if [[ "${SESSION_TYPE}" == "wayland" ]]; then
        echo "  [OK]   Wayland session (22.04 default)"
    else
        echo "  [INFO] X11 session (fallback or NVIDIA)"
    fi
else
    echo "  Display session: server/headless"
fi

# nftables
echo ""
if command -v nft &>/dev/null; then
    echo "  [OK]   nftables installed"
    echo "  Version: $(nft --version 2>/dev/null | head -1)"
    if systemctl is-active --quiet nftables 2>/dev/null; then
        echo "  [OK]   nftables.service is active"
    fi
    IPTABLES_BACKEND=$(update-alternatives --query iptables 2>/dev/null | grep "Value:" | awk '{print $2}' || echo "unknown")
    echo "  iptables backend: ${IPTABLES_BACKEND}"
    if echo "${IPTABLES_BACKEND}" | grep -q "nft"; then
        echo "  [OK]   iptables using nftables backend (22.04 default)"
    fi
fi

echo ""
echo "$SEP"
echo "  AD Integration Assessment Complete - $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "$SEP"
echo ""
echo "  Quick setup (if not yet configured):"
echo "  apt install realmd sssd sssd-ad adsys oddjob-mkhomedir adcli krb5-user"
echo "  realm join --user=Administrator example.com"
echo "  systemctl enable --now adsysd"
