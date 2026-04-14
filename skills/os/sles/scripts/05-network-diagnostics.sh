#!/usr/bin/env bash
# ============================================================================
# SLES - Network Diagnostics
#
# Purpose : Network health assessment including Wicked/NetworkManager
#           status, interface configuration, routing table, DNS
#           resolution, firewall rules, and connectivity checks.
# Version : 1.0.0
# Targets : SLES 15 SP5+
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. Network Daemon Status
#   2. Interface Configuration
#   3. Routing Table
#   4. DNS Configuration
#   5. Firewall Status
#   6. Listening Ports
#   7. Interface Error Counters
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
echo "  SLES Network Diagnostics - $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "$SEP"

# ── Section 1: Network Daemon Status ────────────────────────────────────────
section "SECTION 1 - Network Daemon Status"

for svc in wickedd wicked NetworkManager; do
    status=$(systemctl is-active "$svc" 2>/dev/null || echo "not-found")
    enabled=$(systemctl is-enabled "$svc" 2>/dev/null || echo "not-found")
    printf "  %-20s active=%-12s enabled=%s\n" "$svc" "$status" "$enabled"
done

echo ""
if systemctl is-active wickedd &>/dev/null; then
    echo "  Active network manager: Wicked"
    echo "  Interface summary:"
    wicked show all 2>/dev/null | head -40 | sed 's/^/    /' || echo "    Unable to query wicked"
elif systemctl is-active NetworkManager &>/dev/null; then
    echo "  Active network manager: NetworkManager"
    echo "  Connection summary:"
    nmcli connection show 2>/dev/null | head -20 | sed 's/^/    /' || echo "    Unable to query nmcli"
else
    echo "  [WARN] No network manager detected as active"
fi

# ── Section 2: Interface Configuration ──────────────────────────────────────
section "SECTION 2 - Interface Configuration"

ip addr show 2>/dev/null | sed 's/^/  /'

echo ""
echo "  Wicked config files (if present):"
if [[ -d /etc/sysconfig/network ]]; then
    ls -la /etc/sysconfig/network/ifcfg-* 2>/dev/null | sed 's/^/    /' || echo "    No ifcfg files found"
fi

# ── Section 3: Routing Table ────────────────────────────────────────────────
section "SECTION 3 - Routing Table"

ip route show 2>/dev/null | sed 's/^/  /'
echo ""
echo "  Default gateway:"
ip route show default 2>/dev/null | sed 's/^/    /' || echo "    No default route"

# ── Section 4: DNS Configuration ────────────────────────────────────────────
section "SECTION 4 - DNS Configuration"

echo "  /etc/resolv.conf:"
cat /etc/resolv.conf 2>/dev/null | sed 's/^/    /' || echo "    Not found"

echo ""
echo "  DNS resolution test:"
for domain in scc.suse.com google.com; do
    result=$(host "$domain" 2>/dev/null | head -1 || echo "FAILED")
    echo "    $domain -> $result"
done

# ── Section 5: Firewall Status ──────────────────────────────────────────────
section "SECTION 5 - Firewall Status"

if command -v firewall-cmd &>/dev/null; then
    echo "  firewalld state: $(firewall-cmd --state 2>/dev/null || echo 'not running')"
    echo ""
    echo "  Active zones:"
    firewall-cmd --get-active-zones 2>/dev/null | sed 's/^/    /' || true
    echo ""
    echo "  Default zone rules:"
    firewall-cmd --list-all 2>/dev/null | sed 's/^/    /' || true
else
    echo "  firewall-cmd not found"
fi

# ── Section 6: Listening Ports ──────────────────────────────────────────────
section "SECTION 6 - Listening Ports"

echo "  TCP listeners:"
ss -tlnp 2>/dev/null | head -30 | sed 's/^/    /'
echo ""
echo "  UDP listeners:"
ss -ulnp 2>/dev/null | head -20 | sed 's/^/    /'

# ── Section 7: Interface Error Counters ─────────────────────────────────────
section "SECTION 7 - Interface Error Counters"

ip -s link show 2>/dev/null | awk '
    /^[0-9]+:/ { iface=$2; gsub(/:/, "", iface) }
    /errors/ { if ($0 ~ /[1-9]/) print "  [WARN] " iface ": " $0 }
' || echo "  Unable to check interface errors"

echo ""
echo "  Full interface statistics:"
ip -s link show 2>/dev/null | grep -E "^[0-9]+:|RX:|TX:|errors" | head -40 | sed 's/^/    /'

echo ""
echo "$SEP"
echo "  Network Diagnostics Complete - $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "$SEP"
