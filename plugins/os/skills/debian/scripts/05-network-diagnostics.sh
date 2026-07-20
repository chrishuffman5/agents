#!/usr/bin/env bash
# ============================================================================
# Debian - Network Diagnostics
#
# Purpose : Interfaces, routing, listening ports, DNS, nftables/iptables
#           rules, and connectivity tests to Debian infrastructure.
# Version : 1.0.0
# Targets : Debian 11+ (Bullseye and later)
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. Interfaces
#   2. Routing Table
#   3. Listening Ports
#   4. Active Connections
#   5. DNS Configuration
#   6. DNS Resolution Test
#   7. Firewall Rules (nftables / iptables)
# ============================================================================
set -euo pipefail

echo "=== NETWORK DIAGNOSTICS ==="
echo "Date: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo ""

echo "--- Interfaces ---"
ip addr show
echo ""

echo "--- Routing Table ---"
ip route show
ip -6 route show 2>/dev/null | head -20
echo ""

echo "--- ARP/Neighbor Cache ---"
ip neigh show 2>/dev/null
echo ""

echo "--- Listening Ports ---"
ss -tlnp 2>/dev/null || netstat -tlnp 2>/dev/null
echo ""
echo "UDP listening:"
ss -ulnp 2>/dev/null | head -20
echo ""

echo "--- Active Connections ---"
ss -tnp 2>/dev/null | head -30
echo ""

echo "--- DNS Configuration ---"
cat /etc/resolv.conf
echo ""
echo "systemd-resolved status:"
resolvectl status 2>/dev/null | head -30 || echo "systemd-resolved not active"
echo ""

echo "--- DNS Resolution Test ---"
for host in debian.org security.debian.org deb.debian.org; do
    result=$(getent hosts "$host" 2>/dev/null | awk '{print $1}' | head -1)
    echo "$host -> ${result:-FAILED}"
done
echo ""

echo "--- nftables Ruleset ---"
if command -v nft &>/dev/null; then
    nft list ruleset 2>/dev/null || echo "nftables: no rules loaded"
else
    echo "nft not available"
fi
echo ""

echo "--- iptables Rules ---"
if command -v iptables &>/dev/null; then
    iptables -L -n -v --line-numbers 2>/dev/null | head -60
    echo ""
    ip6tables -L -n -v --line-numbers 2>/dev/null | head -30
else
    echo "iptables not available"
fi
echo ""

echo "--- UFW Status (if installed) ---"
if command -v ufw &>/dev/null; then
    ufw status verbose 2>/dev/null
else
    echo "UFW not installed (not default on Debian)"
fi
echo ""

echo "--- Network Interface Statistics ---"
ip -s link 2>/dev/null | grep -E '^[0-9]|RX:|TX:' | head -40
