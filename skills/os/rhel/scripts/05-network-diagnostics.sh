#!/usr/bin/env bash
# ============================================================================
# RHEL - Network Diagnostics
#
# Purpose : Assess network configuration including NetworkManager connections,
#           nmcli output, firewalld zones and rules, DNS config, and
#           listening ports.
# Version : 1.0.0
# Targets : RHEL 8+
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. NetworkManager Status
#   2. Interface and IP Configuration
#   3. Routing Table
#   4. DNS Configuration
#   5. Firewalld Status
#   6. Listening Ports and Connections
#   7. Connectivity Test
# ============================================================================
set -euo pipefail

SEP="$(printf '=%.0s' {1..70})"
section() { echo ""; echo "$SEP"; echo "  $1"; echo "$SEP"; }

echo "RHEL Network Diagnostics"
echo "Generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "Hostname:  $(hostname -f 2>/dev/null || hostname)"

# ── Section 1: NetworkManager Status ────────────────────────────────────────
section "1. NetworkManager Status"

if command -v nmcli &>/dev/null; then
    nmcli general status 2>/dev/null | sed 's/^/  /'
    echo ""
    echo "  Active connections:"
    nmcli connection show --active 2>/dev/null | sed 's/^/    /'
    echo ""
    echo "  Device status:"
    nmcli device status 2>/dev/null | sed 's/^/    /'
else
    echo "  [WARN] nmcli not found"
fi

# ── Section 2: Interface and IP Configuration ───────────────────────────────
section "2. Interface and IP Configuration"

ip addr show 2>/dev/null | sed 's/^/  /'

echo ""
echo "  Interface statistics:"
ip -s link show 2>/dev/null | grep -E "^\d+:|RX|TX" | sed 's/^/    /'

# ── Section 3: Routing Table ────────────────────────────────────────────────
section "3. Routing Table"

ip route show 2>/dev/null | sed 's/^/  /'

default_gw=$(ip route show default 2>/dev/null | awk '{print $3}' | head -1)
if [[ -n "$default_gw" ]]; then
    echo ""
    echo "  Default gateway: $default_gw"
else
    echo ""
    echo "  [WARN] No default gateway configured"
fi

# ── Section 4: DNS Configuration ────────────────────────────────────────────
section "4. DNS Configuration"

echo "  /etc/resolv.conf:"
cat /etc/resolv.conf 2>/dev/null | grep -v "^#\|^$" | sed 's/^/    /'

if command -v resolvectl &>/dev/null; then
    echo ""
    echo "  resolvectl status:"
    resolvectl status 2>/dev/null | head -20 | sed 's/^/    /'
fi

echo ""
echo "  /etc/nsswitch.conf hosts line:"
grep "^hosts:" /etc/nsswitch.conf 2>/dev/null | sed 's/^/    /'

# ── Section 5: Firewalld Status ─────────────────────────────────────────────
section "5. Firewalld Status"

if command -v firewall-cmd &>/dev/null; then
    fw_state=$(firewall-cmd --state 2>/dev/null || echo "not running")
    echo "  Firewalld state: $fw_state"

    if [[ "$fw_state" == "running" ]]; then
        echo ""
        echo "  Default zone: $(firewall-cmd --get-default-zone 2>/dev/null)"
        echo ""
        echo "  Active zones:"
        firewall-cmd --get-active-zones 2>/dev/null | sed 's/^/    /'
        echo ""
        echo "  Default zone rules:"
        firewall-cmd --list-all 2>/dev/null | sed 's/^/    /'
    fi
else
    echo "  [INFO] firewall-cmd not found"
    echo "  Checking nftables directly:"
    nft list ruleset 2>/dev/null | head -30 | sed 's/^/    /' || echo "    nft not available"
fi

# ── Section 6: Listening Ports and Connections ──────────────────────────────
section "6. Listening Ports and Connections"

echo "  TCP listening:"
ss -tlnp 2>/dev/null | sed 's/^/    /'

echo ""
echo "  UDP listening:"
ss -ulnp 2>/dev/null | sed 's/^/    /'

echo ""
established=$(ss -t state established 2>/dev/null | tail -n +2 | wc -l)
echo "  Established TCP connections: $established"

echo ""
echo "  Socket summary:"
ss -s 2>/dev/null | sed 's/^/    /'

# ── Section 7: Connectivity Test ────────────────────────────────────────────
section "7. Connectivity Test"

if [[ -n "${default_gw:-}" ]]; then
    if ping -c 2 -W 3 "$default_gw" &>/dev/null; then
        echo "  [OK]   Gateway $default_gw reachable"
    else
        echo "  [WARN] Gateway $default_gw unreachable"
    fi
fi

# Test DNS resolution
if command -v dig &>/dev/null; then
    dns_result=$(dig +short +timeout=3 redhat.com A 2>/dev/null | head -1)
    if [[ -n "$dns_result" ]]; then
        echo "  [OK]   DNS resolution working (redhat.com -> $dns_result)"
    else
        echo "  [WARN] DNS resolution failed for redhat.com"
    fi
elif command -v getent &>/dev/null; then
    if getent ahosts redhat.com &>/dev/null; then
        echo "  [OK]   Name resolution working (redhat.com)"
    else
        echo "  [WARN] Name resolution failed for redhat.com"
    fi
fi

echo ""
echo "$SEP"
echo "  Network Diagnostics Complete - $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "$SEP"
