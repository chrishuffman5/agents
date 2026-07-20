#!/usr/bin/env bash
# ============================================================================
# Ubuntu - Network Diagnostics
#
# Purpose : Network subsystem assessment including Netplan config, backend
#           status, UFW firewall, DNS (resolvectl), and listening ports.
# Version : 1.0.0
# Targets : Ubuntu 20.04+
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. Network Interfaces
#   2. Netplan Configuration
#   3. Network Backend Status
#   4. UFW Firewall Status
#   5. DNS Configuration (resolvectl)
#   6. Listening Ports
#   7. Basic Connectivity
# ============================================================================
set -euo pipefail

SEP="$(printf '=%.0s' {1..70})"

section() { echo ""; echo "$SEP"; echo "  $1"; echo "$SEP"; }

# -- Section 1: Interface Summary -------------------------------------------
section "SECTION 1 - Network Interfaces"
ip addr show 2>/dev/null | sed 's/^/  /'
echo ""
echo "  Routing table:"
ip route show 2>/dev/null | sed 's/^/  /'

# -- Section 2: Netplan Configuration ---------------------------------------
section "SECTION 2 - Netplan Configuration"
if ls /etc/netplan/*.yaml &>/dev/null 2>&1; then
    for f in /etc/netplan/*.yaml; do
        echo "  File: $f"
        cat "$f" | sed 's/^/    /'
        echo ""
    done
else
    echo "  [INFO] No netplan configuration files found"
fi

# -- Section 3: Backend Status ----------------------------------------------
section "SECTION 3 - Network Backend Status"
echo "  systemd-networkd:"
systemctl is-active systemd-networkd 2>/dev/null | sed 's/^/    Status: /'
if command -v networkctl &>/dev/null; then
    networkctl 2>/dev/null | head -10 | sed 's/^/    /'
fi
echo ""
echo "  NetworkManager:"
systemctl is-active NetworkManager 2>/dev/null | sed 's/^/    Status: /'
if command -v nmcli &>/dev/null; then
    nmcli -t -f NAME,STATE,TYPE,DEVICE connection show 2>/dev/null \
        | head -10 | sed 's/^/    /'
fi

# -- Section 4: UFW Firewall Status ----------------------------------------
section "SECTION 4 - UFW Firewall Status"
if command -v ufw &>/dev/null; then
    sudo ufw status verbose 2>/dev/null | sed 's/^/  /' \
        || echo "  Unable to query UFW (may need sudo)"
else
    echo "  [INFO] UFW not installed"
fi

# -- Section 5: DNS / systemd-resolved -------------------------------------
section "SECTION 5 - DNS Configuration (resolvectl)"
if command -v resolvectl &>/dev/null; then
    resolvectl status 2>/dev/null | head -30 | sed 's/^/  /'
else
    echo "  [INFO] resolvectl not available"
    echo "  /etc/resolv.conf:"
    cat /etc/resolv.conf | sed 's/^/    /'
fi

# -- Section 6: Listening Ports ---------------------------------------------
section "SECTION 6 - Listening Ports"
echo "  TCP listening:"
ss -tlnp 2>/dev/null | sed 's/^/  /'
echo ""
echo "  UDP listening:"
ss -ulnp 2>/dev/null | sed 's/^/  /'

# -- Section 7: Connectivity Check -----------------------------------------
section "SECTION 7 - Basic Connectivity"
for target in 8.8.8.8 1.1.1.1 ubuntu.com; do
    if ping -c1 -W2 "$target" &>/dev/null; then
        echo "  [OK]   $target reachable"
    else
        echo "  [FAIL] $target unreachable"
    fi
done

echo ""
echo "$SEP"
echo "  Network Diagnostics Complete - $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "$SEP"
